import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/presentation/widgets/google_places_address_field.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/core/utils/logger.dart';

class ScheduleTemplatesPage extends ConsumerStatefulWidget {
  const ScheduleTemplatesPage({super.key});

  @override
  ConsumerState<ScheduleTemplatesPage> createState() => _ScheduleTemplatesPageState();
}

class _ScheduleTemplatesPageState extends ConsumerState<ScheduleTemplatesPage> {
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  int _selectedDay = 1; // Monday
  DateTime _startTime = DateTime(2024, 1, 1, 18, 0);
  DateTime _endTime = DateTime(2024, 1, 1, 19, 30);
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String get _dayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[_selectedDay - 1];
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Schedule Class'),
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
                            color: CupertinoColors.systemGrey6,
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
                                color: CupertinoColors.systemGrey,
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
                            color: CupertinoColors.systemGrey6,
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
                            color: CupertinoColors.systemGrey6,
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
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Location Field with Google Places Autocomplete
                GooglePlacesAddressField(
                  controller: _locationController,
                  hint: 'Search for a place',
                  onLocationSelected: (address, lat, lng) {
                    _latitude = lat;
                    _longitude = lng;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Save Button
                CupertinoButton(
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _isLoading ? null : _saveSchedule,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text(
                          'Save Class Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
        color: CupertinoColors.systemBackground.resolveFrom(context),
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
                  scrollController: FixedExtentScrollController(initialItem: _selectedDay - 1),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _selectedDay = index + 1;
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
    DateTime tempTime = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
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
      
      // Create schedule in Supabase
      final scheduleData = {
        'teacher_id': user.id,
        'name': user.capoeiraName.isNotEmpty ? user.capoeiraName : user.fullName,
        'group_id': user.groupId ?? '',
        'event_type': 'class', // For now just classes, not rodas
        'recurrence_type': 'weekly',
        'day_of_week': _selectedDay,
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'location': _locationController.text,
        'timezone': 'America/New_York', // TODO: Get user's timezone
        'price': price,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      Logger.debug('Inserting schedule: $scheduleData');
      
      final response = await supabase
          .from('schedules')
          .insert(scheduleData)
          .select()
          .single();
      
      Logger.debug('Schedule template created with ID: ${response['id']}');
      
      // Create instances for the next 3 months (13 weeks)
      final scheduleId = response['id'];
      final now = DateTime.now();
      
      // Find next occurrence of selected day
      DateTime nextDate = now;
      while (nextDate.weekday != _selectedDay) {
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
      
      Logger.debug('Successfully created schedule and instances');
      
      // Reset form
      setState(() {
        _locationController.clear();
        _priceController.clear();
        _selectedDay = 1;
        _startTime = DateTime(2024, 1, 1, 18, 0);
        _endTime = DateTime(2024, 1, 1, 19, 30);
        _latitude = null;
        _longitude = null;
      });
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: Text('Class scheduled for $_dayName from ${_formatTime(_startTime)} to ${_formatTime(_endTime)}'),
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