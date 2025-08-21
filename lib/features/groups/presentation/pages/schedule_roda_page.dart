import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/features/teacher/presentation/widgets/google_places_address_field.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

enum RecurrenceType {
  once('once', 'One-time event'),
  weekly('weekly', 'Weekly'),
  monthly('monthly_week', 'Monthly');

  final String value;
  final String displayName;

  const RecurrenceType(this.value, this.displayName);
}

class ScheduleRodaPage extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupLocationAddress;
  final double? groupLatitude;
  final double? groupLongitude;
  
  const ScheduleRodaPage({
    super.key,
    required this.groupId,
    this.groupLocationAddress,
    this.groupLatitude,
    this.groupLongitude,
  });

  @override
  ConsumerState<ScheduleRodaPage> createState() => _ScheduleRodaPageState();
}

class _ScheduleRodaPageState extends ConsumerState<ScheduleRodaPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  
  String _eventType = 'roda'; // Default to roda, can be 'batizado'
  RecurrenceType _recurrenceType = RecurrenceType.once;
  DateTime _selectedDate = DateTime.now();
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 3));
  
  // Weekly recurrence
  final Map<int, bool> _selectedWeekdays = {
    1: false, // Monday
    2: false, // Tuesday
    3: false, // Wednesday
    4: false, // Thursday
    5: false, // Friday
    6: true,  // Saturday (default)
    0: false, // Sunday
  };
  
  // Monthly recurrence
  int _weekOfMonth = 1; // 1st, 2nd, 3rd, 4th, or 5 for last
  int _dayOfWeek = 6; // Saturday by default
  
  bool _useGroupLocation = true;
  double? _latitude;
  double? _longitude;
  
  @override
  void initState() {
    super.initState();
    if (widget.groupLocationAddress != null) {
      _locationController.text = widget.groupLocationAddress!;
      _latitude = widget.groupLatitude;
      _longitude = widget.groupLongitude;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: RodaColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: RodaColors.surface.withValues(alpha: 0.95),
        middle: const Text('Schedule Event'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.xmark),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _scheduleRoda,
          child: const Text(
            'Schedule',
            style: TextStyle(
              color: RodaColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Type selector
              _buildSectionTitle('Event Type'),
              Container(
                decoration: BoxDecoration(
                  color: RodaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _eventType,
                  onValueChanged: (value) {
                    setState(() {
                      _eventType = value!;
                      // Update default name based on type
                      if (_nameController.text.isEmpty) {
                        _nameController.text = value == 'roda' ? 'Weekly Roda' : 'Batizado';
                      }
                    });
                  },
                  children: const {
                    'roda': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Roda'),
                    ),
                    'batizado': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Batizado'),
                    ),
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Name field
              _buildSectionTitle('Event Name'),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'e.g., Weekly Roda',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RodaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Recurrence section
              _buildSectionTitle('Recurrence'),
              _buildRecurrenceSelector(),
              
              const SizedBox(height: 16),
              
              // Recurrence details based on type
              _buildRecurrenceDetails(),
              
              const SizedBox(height: 24),
              
              // Time section
              _buildSectionTitle('Time'),
              _buildTimeSelectors(),
              
              const SizedBox(height: 24),
              
              // Location section
              _buildSectionTitle('Location'),
              _buildLocationSection(),
              
              const SizedBox(height: 24),
              
              // Price section
              _buildSectionTitle('Price (Optional)'),
              CupertinoTextField(
                controller: _priceController,
                placeholder: '\$0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RodaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Description section
              _buildSectionTitle('Description (Optional)'),
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: 'Add details about the roda...',
                maxLines: 4,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RodaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: RodaColors.textPrimary,
        ),
      ),
    );
  }
  
  Widget _buildRecurrenceSelector() {
    return Container(
      decoration: BoxDecoration(
        color: RodaColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoSlidingSegmentedControl<RecurrenceType>(
        groupValue: _recurrenceType,
        onValueChanged: (value) {
          setState(() {
            _recurrenceType = value!;
          });
        },
        children: Map.fromEntries(
          RecurrenceType.values.map((type) => 
            MapEntry(type, Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(type.displayName),
            ))
          ),
        ),
      ),
    );
  }
  
  Widget _buildRecurrenceDetails() {
    switch (_recurrenceType) {
      case RecurrenceType.once:
        return _buildDatePicker();
      case RecurrenceType.weekly:
        return _buildWeekdaySelector();
      case RecurrenceType.monthly:
        return _buildMonthlySelector();
    }
  }
  
  Widget _buildDatePicker() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showDatePicker(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RodaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RodaColors.divider),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.calendar, color: RodaColors.primary),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 16,
                color: RodaColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              CupertinoIcons.chevron_right,
              color: RodaColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeekdaySelector() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayIndices = [1, 2, 3, 4, 5, 6, 0]; // Match DateTime.weekday
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RodaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RodaColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final dayIndex = weekdayIndices[index];
          final isSelected = _selectedWeekdays[dayIndex] ?? false;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedWeekdays[dayIndex] = !isSelected;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? RodaColors.primary : RodaColors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? RodaColors.primary : RodaColors.divider,
                ),
              ),
              child: Center(
                child: Text(
                  weekdays[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? RodaColors.white : RodaColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildMonthlySelector() {
    final weeks = ['1st', '2nd', '3rd', '4th', 'Last'];
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showWeekPicker(weeks),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RodaColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RodaColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weeks[_weekOfMonth - 1],
                    style: const TextStyle(color: RodaColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: RodaColors.textHint,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showDayPicker(weekdays),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RodaColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RodaColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdays[_dayOfWeek],
                    style: const TextStyle(color: RodaColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: RodaColors.textHint,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimeSelectors() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start',
                style: TextStyle(
                  fontSize: 14,
                  color: RodaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showTimePicker(true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RodaColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RodaColors.divider),
                  ),
                  child: Text(
                    DateFormat('h:mm a').format(_startTime),
                    style: const TextStyle(
                      fontSize: 16,
                      color: RodaColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'End',
                style: TextStyle(
                  fontSize: 14,
                  color: RodaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showTimePicker(false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RodaColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RodaColors.divider),
                  ),
                  child: Text(
                    DateFormat('h:mm a').format(_endTime),
                    style: const TextStyle(
                      fontSize: 16,
                      color: RodaColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLocationSection() {
    return Column(
      children: [
        Row(
          children: [
            CupertinoSwitch(
              value: _useGroupLocation,
              onChanged: (value) {
                setState(() {
                  _useGroupLocation = value;
                  if (value && widget.groupLocationAddress != null) {
                    _locationController.text = widget.groupLocationAddress!;
                    _latitude = widget.groupLatitude;
                    _longitude = widget.groupLongitude;
                  }
                });
              },
              activeColor: RodaColors.primary,
            ),
            const SizedBox(width: 12),
            const Text(
              'Use group location',
              style: TextStyle(
                fontSize: 16,
                color: RodaColors.textPrimary,
              ),
            ),
          ],
        ),
        if (!_useGroupLocation) ...[
          const SizedBox(height: 12),
          GooglePlacesAddressField(
            controller: _locationController,
            onLocationSelected: (address, lat, lng) {
              // Handle location selection
              _locationController.text = address;
              _latitude = lat;
              _longitude = lng;
            },
          ),
        ],
      ],
    );
  }
  
  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: RodaColors.surface,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTimePicker(bool isStartTime) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: RodaColors.surface,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: isStartTime ? _startTime : _endTime,
                onDateTimeChanged: (time) {
                  setState(() {
                    if (isStartTime) {
                      _startTime = time;
                    } else {
                      _endTime = time;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showWeekPicker(List<String> weeks) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Week'),
        actions: List.generate(weeks.length, (index) => 
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _weekOfMonth = index + 1;
              });
              Navigator.pop(context);
            },
            child: Text(weeks[index]),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  
  void _showDayPicker(List<String> weekdays) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Day'),
        actions: List.generate(weekdays.length, (index) => 
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _dayOfWeek = index;
              });
              Navigator.pop(context);
            },
            child: Text(weekdays[index]),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  
  void _scheduleRoda() async {
    // Validate required fields
    if (_nameController.text.isEmpty) {
      _showError('Please enter an event name');
      return;
    }
    
    if (_recurrenceType == RecurrenceType.weekly) {
      final hasSelectedDay = _selectedWeekdays.values.any((selected) => selected);
      if (!hasSelectedDay) {
        _showError('Please select at least one day for weekly recurrence');
        return;
      }
    }
    
    if (!_useGroupLocation && _locationController.text.isEmpty) {
      _showError('Please enter a location');
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      final currentUser = ref.read(currentUserProvider).value;
      
      if (currentUser == null) {
        _showError('You must be logged in to schedule events');
        return;
      }
      
      // Prepare location data
      String? locationPoint;
      if (_latitude != null && _longitude != null) {
        locationPoint = 'POINT($_longitude $_latitude)';
      }
      
      // For weekly recurrence, we'll create multiple schedule entries (one for each day)
      // For monthly and once, we create a single entry
      
      if (_recurrenceType == RecurrenceType.weekly) {
        // Create a schedule for each selected weekday
        for (var entry in _selectedWeekdays.entries) {
          if (entry.value) {
            await _createScheduleEntry(
              supabase: supabase,
              teacherId: currentUser.id,
              dayOfWeek: entry.key,
              locationPoint: locationPoint,
            );
          }
        }
      } else if (_recurrenceType == RecurrenceType.monthly) {
        // Monthly recurrence - single entry with week_of_month
        await _createScheduleEntry(
          supabase: supabase,
          teacherId: currentUser.id,
          dayOfWeek: _dayOfWeek,
          weekOfMonth: _weekOfMonth,
          locationPoint: locationPoint,
          recurrenceType: 'monthly_week',
        );
      } else {
        // One-time event
        await _createScheduleEntry(
          supabase: supabase,
          teacherId: currentUser.id,
          dayOfWeek: _selectedDate.weekday % 7, // Convert to PostgreSQL DOW (0=Sunday)
          specificDate: _selectedDate,
          locationPoint: locationPoint,
          recurrenceType: 'once',
        );
      }
      
      // Success - go back
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
      
    } catch (e) {
      Logger.debug('Error scheduling event: $e');
      _showError('Failed to schedule event: ${e.toString()}');
    }
  }
  
  Future<void> _createScheduleEntry({
    required SupabaseClient supabase,
    required String teacherId,
    required int dayOfWeek,
    int? weekOfMonth,
    DateTime? specificDate,
    String? locationPoint,
    String recurrenceType = 'weekly',
  }) async {
    final scheduleData = {
      'group_id': widget.groupId,
      'teacher_id': teacherId,
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'event_type': _eventType, // 'roda' or 'batizado'
      'location': locationPoint,
      'location_name': _useGroupLocation ? widget.groupLocationAddress : _locationController.text.trim(),
      'location_address': _useGroupLocation ? widget.groupLocationAddress : _locationController.text.trim(),
      'recurrence_type': recurrenceType,
      'day_of_week': dayOfWeek,
      'start_time': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
      'end_time': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00',
      'price': _priceController.text.isEmpty ? null : double.tryParse(_priceController.text),
      'is_active': true,
    };
    
    // Add fields specific to recurrence type
    if (recurrenceType == 'monthly_week' && weekOfMonth != null) {
      scheduleData['week_of_month'] = weekOfMonth;
    }
    
    if (recurrenceType == 'once' && specificDate != null) {
      scheduleData['specific_date'] = specificDate.toIso8601String().split('T')[0];
    }
    
    // Insert into schedules table
    final response = await supabase
        .from('schedules')
        .insert(scheduleData)
        .select()
        .single();
    
    Logger.debug('Created schedule: ${response['id']}');
    
    // Generate instances for the next 3 months
    if (recurrenceType != 'once') {
      final startDate = DateTime.now();
      final endDate = DateTime.now().add(const Duration(days: 90));
      
      await supabase.rpc('generate_class_instances', params: {
        'p_schedule_id': response['id'],
        'p_start_date': startDate.toIso8601String().split('T')[0],
        'p_end_date': endDate.toIso8601String().split('T')[0],
      });
    } else {
      // For one-time events, create a single instance
      await supabase.from('class_instances').insert({
        'schedule_id': response['id'],
        'teacher_id': teacherId,
        'scheduled_date': specificDate!.toIso8601String().split('T')[0],
        'start_time': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
        'end_time': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00',
        'is_cancelled': false,
      });
    }
  }
  
  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}