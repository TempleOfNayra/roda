import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/presentation/widgets/google_places_address_field.dart';
import 'package:roda/features/teacher/presentation/widgets/teacher_search_field.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/features/groups/providers/schedule_providers.dart';
import 'package:roda/core/theme/roda_colors.dart';

class ScheduleTemplatesPage extends ConsumerStatefulWidget {
  final String groupId;
  final Map<String, dynamic>? scheduleToEdit;
  final String? groupLocationAddress;
  
  const ScheduleTemplatesPage({
    super.key, 
    required this.groupId,
    this.scheduleToEdit,
    this.groupLocationAddress,
  });

  @override
  ConsumerState<ScheduleTemplatesPage> createState() => _ScheduleTemplatesPageState();
}

class _ScheduleTemplatesPageState extends ConsumerState<ScheduleTemplatesPage> {
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _teacherController = TextEditingController();
  String _selectedTeacherId = '';
  int _selectedDay = 1; // Monday (1-6 for Mon-Sat, 0 for Sunday)
  DateTime _startTime = DateTime(2024, 1, 1, 18, 0);
  DateTime _endTime = DateTime(2024, 1, 1, 19, 30);
  bool _isLoading = false;
  // double? _latitude;  // TODO: Use for location-based features
  // double? _longitude; // TODO: Use for location-based features
  
  @override
  void initState() {
    super.initState();
    if (widget.scheduleToEdit != null) {
      _loadScheduleData();
    } else {
      // For new schedules
      if (widget.groupLocationAddress != null && widget.groupLocationAddress!.isNotEmpty) {
        // Prefill location with group's address
        _locationController.text = widget.groupLocationAddress!;
      }
      // Default teacher to current user
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser != null) {
        _selectedTeacherId = currentUser.id;
        _teacherController.text = currentUser.capoeiraName.isNotEmpty 
            ? currentUser.capoeiraName 
            : currentUser.fullName;
      }
    }
  }
  
  void _loadScheduleData() {
    final schedule = widget.scheduleToEdit!;
    _selectedDay = schedule['day_of_week'] ?? 1;
    _locationController.text = schedule['location_name'] ?? '';
    _descriptionController.text = schedule['description'] ?? '';
    
    // Load teacher info
    _selectedTeacherId = schedule['teacher_id'] ?? '';
    _teacherController.text = schedule['name'] ?? '';
    
    if (schedule['price'] != null) {
      _priceController.text = schedule['price'].toString();
    }
    
    if (schedule['start_time'] != null) {
      final startParts = (schedule['start_time'] as String).split(':');
      int minute = int.parse(startParts[1]);
      // Round to nearest 15-minute interval
      minute = ((minute / 15).round() * 15) % 60;
      _startTime = DateTime(2024, 1, 1, int.parse(startParts[0]), minute);
    }
    
    if (schedule['end_time'] != null) {
      final endParts = (schedule['end_time'] as String).split(':');
      int minute = int.parse(endParts[1]);
      // Round to nearest 15-minute interval
      minute = ((minute / 15).round() * 15) % 60;
      _endTime = DateTime(2024, 1, 1, int.parse(endParts[0]), minute);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  String get _dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[_selectedDay];
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.scheduleToEdit != null ? 'Edit Class' : 'Schedule Class'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Single row for Day, Time, and Price
                Row(
                  children: [
                    // Day dropdown
                    Expanded(
                      flex: 3,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showDayPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: RodaColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dayName.substring(0, 3),
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                              const Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: RodaColors.systemGrey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Start time
                    Expanded(
                      flex: 2,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showTimePicker(true),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: RodaColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${_startTime.hour > 12 ? _startTime.hour - 12 : _startTime.hour == 0 ? 12 : _startTime.hour}:${_startTime.minute.toString().padLeft(2, '0')}${_startTime.hour >= 12 ? 'p' : 'a'}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // End time
                    Expanded(
                      flex: 2,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showTimePicker(false),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: RodaColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${_endTime.hour > 12 ? _endTime.hour - 12 : _endTime.hour == 0 ? 12 : _endTime.hour}:${_endTime.minute.toString().padLeft(2, '0')}${_endTime.hour >= 12 ? 'p' : 'a'}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Price
                    Expanded(
                      flex: 2,
                      child: CupertinoTextField(
                        controller: _priceController,
                        placeholder: '20',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            '\$',
                            style: TextStyle(
                              fontSize: 14,
                              color: RodaColors.systemGrey,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: BoxDecoration(
                          color: RodaColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Teacher Selection Field
                TeacherSearchField(
                  controller: _teacherController,
                  initialTeacherId: _selectedTeacherId,
                  initialTeacherName: _teacherController.text,
                  onTeacherSelected: (teacherId, teacherName) {
                    setState(() {
                      _selectedTeacherId = teacherId;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Location Field with Google Places Autocomplete
                GooglePlacesAddressField(
                  controller: _locationController,
                  hint: 'Search for a place',
                  onLocationSelected: (address, lat, lng) {
                    // TODO: Store lat/lng for location-based features
                    // _latitude = lat;
                    // _longitude = lng;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Description Field (optional)
                CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: 'Class description (optional)',
                  padding: const EdgeInsets.all(12),
                  maxLines: 3,
                  decoration: BoxDecoration(
                    color: RodaColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                
                const SizedBox(height: 32),
                
                // Save Button
                CupertinoButton(
                  color: RodaColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _isLoading ? null : _saveSchedule,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: RodaColors.white)
                      : const Text(
                          'Save Class Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: RodaColors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDayPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: RodaColors.systemBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(initialItem: _selectedDay == 0 ? 6 : _selectedDay - 1),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      // Map picker index to database values: Mon=1, Tue=2, ..., Sat=6, Sun=0
                      _selectedDay = index == 6 ? 0 : index + 1;
                    });
                  },
                  children: const [
                    Text('Monday'),
                    Text('Tuesday'),
                    Text('Wednesday'),
                    Text('Thursday'),
                    Text('Friday'),
                    Text('Saturday'),
                    Text('Sunday'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimePicker(bool isStartTime) {
    final initialTime = isStartTime ? _startTime : _endTime;
    // Round minutes to nearest 15-minute interval for the picker
    int roundedMinute = (initialTime.minute / 15).round() * 15;
    if (roundedMinute == 60) {
      roundedMinute = 45; // If rounded to 60, use 45 instead
    }
    DateTime tempTime = DateTime(2000, 1, 1, initialTime.hour, roundedMinute);
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: RodaColors.systemBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      setState(() {
                        if (isStartTime) {
                          _startTime = tempTime;
                        } else {
                          _endTime = tempTime;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  minuteInterval: 15,  // Show only 0, 15, 30, 45
                  initialDateTime: tempTime,
                  onDateTimeChanged: (DateTime newTime) {
                    tempTime = newTime;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_locationController.text.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Information'),
          content: const Text('Please enter a location'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');
      
      final supabase = ref.read(supabaseClientProvider);
      
      // Parse price
      double? price;
      if (_priceController.text.isNotEmpty) {
        price = double.tryParse(_priceController.text);
      }
      
      // Format times as HH:MM
      final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';
      
      Logger.debug('Saving schedule: Day=$_selectedDay, Start=$startTimeStr, End=$endTimeStr, Location=${_locationController.text}');
      
      // Prepare schedule data
      final scheduleData = {
        'teacher_id': _selectedTeacherId.isNotEmpty ? _selectedTeacherId : user.id,
        'name': _teacherController.text.isNotEmpty ? _teacherController.text : (user.capoeiraName.isNotEmpty ? user.capoeiraName : user.fullName),
        'group_id': widget.groupId,  // Use the group ID from the group page
        'event_type': 'class', // For now just classes, not rodas
        'recurrence_type': 'weekly',
        'day_of_week': _selectedDay,
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'location_name': _locationController.text,  // Changed from 'location' to 'location_name'
        'location_address': _locationController.text, // Also store in location_address
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        // Don't set 'location' field - it will be set by database trigger if we have lat/lng
        'timezone': 'America/New_York', // TODO: Get user's timezone
        'price': price,
        'is_active': true,
      };
      
      Map<String, dynamic> response;
      
      if (widget.scheduleToEdit != null) {
        // Update existing schedule
        Logger.debug('Updating schedule: ${widget.scheduleToEdit!['id']}');
        scheduleData['updated_at'] = DateTime.now().toIso8601String();
        
        response = await supabase
            .from('schedules')
            .update(scheduleData)
            .eq('id', widget.scheduleToEdit!['id'])
            .select()
            .single();
            
        Logger.debug('Schedule updated with ID: ${response['id']}');
      } else {
        // Create new schedule
        Logger.debug('Inserting schedule: $scheduleData');
        scheduleData['created_at'] = DateTime.now().toIso8601String();
        
        response = await supabase
            .from('schedules')
            .insert(scheduleData)
            .select()
            .single();
            
        Logger.debug('Schedule template created with ID: ${response['id']}');
        
        // Create instances for new schedules only
        final scheduleId = response['id'];
        final now = DateTime.now();
        
        // Find next occurrence of selected day
        // Convert our day format (0=Sun, 1=Mon, ..., 6=Sat) to Dart's weekday (1=Mon, ..., 7=Sun)
        final targetWeekday = _selectedDay == 0 ? 7 : _selectedDay;
        DateTime nextDate = now;
        while (nextDate.weekday != targetWeekday) {
          nextDate = nextDate.add(const Duration(days: 1));
        }
        
        // Create 13 weekly instances
        final instances = <Map<String, dynamic>>[];
        for (int i = 0; i < 13; i++) {
          final instanceDate = nextDate.add(Duration(days: i * 7));
          final scheduledDateTime = DateTime(
            instanceDate.year,
            instanceDate.month,
            instanceDate.day,
            _startTime.hour,
            _startTime.minute,
          );
          
          instances.add({
            'schedule_id': scheduleId,
            'teacher_id': user.id,
            'scheduled_date': scheduledDateTime.toIso8601String(),
            'start_time': startTimeStr,
            'end_time': endTimeStr,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        
        Logger.debug('Creating ${instances.length} class instances');
        
        await supabase
            .from('class_instances')
            .insert(instances);
      }
      
      Logger.debug('Successfully saved schedule');
      
      // Invalidate the group schedules provider to refresh the list
      ref.invalidate(groupSchedulesProvider(widget.groupId));
      
      // Save values for success message before resetting
      final scheduledDay = _dayName;
      final scheduledStartTime = _formatTime(_startTime);
      final scheduledEndTime = _formatTime(_endTime);
      
      // Reset form
      setState(() {
        _locationController.clear();
        _priceController.clear();
        _descriptionController.clear();
        _selectedDay = 1;
        _startTime = DateTime(2024, 1, 1, 18, 0);
        _endTime = DateTime(2024, 1, 1, 19, 30);
        // _latitude = null;
        // _longitude = null;
      });
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(widget.scheduleToEdit != null ? 'Updated' : 'Success'),
            content: Text(widget.scheduleToEdit != null 
                ? 'Class updated for $scheduledDay from $scheduledStartTime to $scheduledEndTime'
                : 'Class scheduled for $scheduledDay from $scheduledStartTime to $scheduledEndTime'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to save schedule', e);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save schedule: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour == 0 ? 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}