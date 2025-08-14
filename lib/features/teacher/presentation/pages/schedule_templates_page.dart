import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/presentation/widgets/google_places_address_field.dart';
import 'package:intl/intl.dart';

// Provider for schedule templates
final scheduleTemplatesProvider = StreamProvider<List<ScheduleTemplate>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('schedule_templates')
      .where('teacherId', isEqualTo: user.id)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ScheduleTemplate.fromFirestore(doc))
          .toList());
});

class ScheduleTemplatesPage extends ConsumerStatefulWidget {
  const ScheduleTemplatesPage({super.key});

  @override
  ConsumerState<ScheduleTemplatesPage> createState() => _ScheduleTemplatesPageState();
}

class _ScheduleTemplatesPageState extends ConsumerState<ScheduleTemplatesPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);
  double? _latitude;
  double? _longitude;
  EventType _currentEventType = EventType.class_;
  RecurrenceType _classRecurrence = RecurrenceType.weekly; // All classes are weekly
  RecurrenceType _rodaRecurrence = RecurrenceType.weekly; // Default for rodas
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentEventType = _tabController.index == 0 ? EventType.class_ : EventType.roda;
      });
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }
  
  Future<void> _selectTime(bool isStartTime) async {
    final initialTime = isStartTime ? _startTime : _endTime;
    DateTime tempTime = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);
    
    await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 260,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                height: 60,
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          if (isStartTime) {
                            _startTime = TimeOfDay(hour: tempTime.hour, minute: tempTime.minute);
                          } else {
                            _endTime = TimeOfDay(hour: tempTime.hour, minute: tempTime.minute);
                          }
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: tempTime,
                  minuteInterval: 15,
                  onDateTimeChanged: (DateTime newTime) {
                    tempTime = newTime;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _createScheduleTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');
      
      final db = FirebaseFirestore.instance;
      
      final recurrenceType = _currentEventType == EventType.class_ 
          ? _classRecurrence 
          : _rodaRecurrence;
      
      // Parse price from controller
      double? price;
      if (_priceController.text.isNotEmpty) {
        price = double.tryParse(_priceController.text);
      }
      
      // Create the template
      final template = ScheduleTemplate(
        id: '',
        teacherId: user.id,
        teacherName: user.capoeiraName.isNotEmpty ? user.capoeiraName : user.fullName,
        groupId: user.groupId ?? '',
        groupName: user.groupName ?? 'Independent',
        eventType: _currentEventType,
        recurrenceType: recurrenceType,
        dayOfWeek: _selectedDay,
        oneTimeDate: null,
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        location: _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
        price: price,
        createdAt: DateTime.now(),
      );
      
      final templateDoc = await db.collection('schedule_templates').add(template.toFirestore());
      
      // Create instances based on recurrence type
      final batch = db.batch();
      final now = DateTime.now();
      
      // All classes are weekly now
      // Find the next occurrence of the selected day
      DateTime nextDate = now;
      while (nextDate.weekday != _selectedDay) {
        nextDate = nextDate.add(const Duration(days: 1));
      }
      
      if (recurrenceType == RecurrenceType.weekly) {
        const instanceCount = 13; // 3 months of weekly classes
        for (int i = 0; i < instanceCount; i++) {
          final instanceDate = nextDate.add(Duration(days: i * 7));
          // Combine date with the start time to get proper datetime
          final scheduledDateTime = DateTime(
            instanceDate.year,
            instanceDate.month,
            instanceDate.day,
            _startTime.hour,
            _startTime.minute,
          );
          final instance = ClassInstance(
            id: '',
            templateId: templateDoc.id,
            scheduledDate: scheduledDateTime,
          );
          final docRef = db.collection('class_instances').doc();
          batch.set(docRef, instance.toFirestore());
        }
      } else if (recurrenceType == RecurrenceType.biweekly) {
        const instanceCount = 7; // 3 months worth of biweekly
        for (int i = 0; i < instanceCount; i++) {
          final instanceDate = nextDate.add(Duration(days: i * 14));
          // Combine date with the start time to get proper datetime
          final scheduledDateTime = DateTime(
            instanceDate.year,
            instanceDate.month,
            instanceDate.day,
            _startTime.hour,
            _startTime.minute,
          );
          final instance = ClassInstance(
            id: '',
            templateId: templateDoc.id,
            scheduledDate: scheduledDateTime,
          );
          final docRef = db.collection('class_instances').doc();
          batch.set(docRef, instance.toFirestore());
        }
      } else if (recurrenceType == RecurrenceType.monthly) {
        const instanceCount = 3; // 3 months
        for (int i = 0; i < instanceCount; i++) {
          // Calculate next month's same weekday
          DateTime instanceDate = DateTime(
            nextDate.year,
            nextDate.month + i,
            1,
          );
          // Find the first occurrence of the selected day in that month
          while (instanceDate.weekday != _selectedDay) {
            instanceDate = instanceDate.add(const Duration(days: 1));
          }
          // Find the correct week of month (1st, 2nd, 3rd, 4th)
          final weekOfMonth = ((nextDate.day - 1) ~/ 7);
          instanceDate = instanceDate.add(Duration(days: weekOfMonth * 7));
          // Combine date with the start time to get proper datetime
          final scheduledDateTime = DateTime(
            instanceDate.year,
            instanceDate.month,
            instanceDate.day,
            _startTime.hour,
            _startTime.minute,
          );
          final instance = ClassInstance(
            id: '',
            templateId: templateDoc.id,
            scheduledDate: scheduledDateTime,
          );
          final docRef = db.collection('class_instances').doc();
          batch.set(docRef, instance.toFirestore());
        }
      }
      
      await batch.commit();
      
      // Reset form
      setState(() {
        _locationController.clear();
        _priceController.clear();
        _selectedDay = 1;
        _startTime = const TimeOfDay(hour: 18, minute: 0);
        _endTime = const TimeOfDay(hour: 19, minute: 30);
        _latitude = null;
        _longitude = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _deleteTemplate(ScheduleTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: Text(
          'This will delete ALL ${template.eventType == EventType.class_ ? "classes" : "rodas"} '
          'on ${template.dayName} from ${template.startTime} to ${template.endTime}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final db = FirebaseFirestore.instance;
      
      print('🗑️ DELETING TEMPLATE: ${template.id}');
      print('   Location: ${template.location}');
      print('   Type: ${template.eventType}');
      
      // Soft delete the template
      print('   Step 1: Soft deleting template...');
      await db.collection('schedule_templates').doc(template.id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('   ✓ Template soft deleted');
      
      // Delete all instances
      print('   Step 2: Finding instances...');
      final instances = await db.collection('class_instances')
          .where('templateId', isEqualTo: template.id)
          .get();
      print('   Found ${instances.docs.length} instances to delete');
      
      if (instances.docs.isNotEmpty) {
        final batch = db.batch();
        for (final doc in instances.docs) {
          batch.delete(doc.reference);
          print('   - Will delete instance: ${doc.id}');
        }
        print('   Step 3: Committing batch delete...');
        await batch.commit();
        print('   ✓ All instances deleted');
      }
      
      print('🗑️ DELETION COMPLETE');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted template and ${instances.docs.length} instances'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ DELETION FAILED: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(scheduleTemplatesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Templates'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sports_martial_arts), text: 'Classes'),
            Tab(icon: Icon(Icons.music_note), text: 'Rodas'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Form section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GooglePlacesAddressField(
                    controller: _locationController,
                    label: 'Location',
                    hint: 'Search for a place',
                    onLocationSelected: (address, lat, lng) {
                      _latitude = lat;
                      _longitude = lng;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Price input field
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price (USD)',
                      hintText: 'e.g., 20.00',
                      prefixText: '\$',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Please enter a valid price';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Recurrence selection based on tab
                  if (_currentEventType == EventType.class_) ...[
                    // Classes are always weekly - no selection needed
                    // Classes are always weekly
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Weekly Recurring Class',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Dropdown for rodas (4 options)
                    DropdownButtonFormField<RecurrenceType>(
                      value: _rodaRecurrence,
                      decoration: const InputDecoration(
                        labelText: 'Recurrence',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        RecurrenceType.oneTime,
                        RecurrenceType.weekly,
                        RecurrenceType.biweekly,
                        RecurrenceType.monthly,
                      ].map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getRecurrenceLabel(type)),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _rodaRecurrence = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  
                  // Date selector for one-time events, Day selector for recurring
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: _selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Day',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(7, (i) => i + 1)
                              .map((day) => DropdownMenuItem(
                                    value: day,
                                    child: Text(_getDayName(day)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedDay = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(_startTime.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createScheduleTemplate,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text('Create ${_currentEventType == EventType.class_ ? 'Class' : 'Roda'} Schedule'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Templates list
          Expanded(
            child: templatesAsync.when(
              data: (templates) {
                final filtered = templates.where((t) => 
                  t.eventType == _currentEventType
                ).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentEventType == EventType.class_ 
                              ? Icons.sports_martial_arts 
                              : Icons.music_note,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_currentEventType == EventType.class_ ? 'class' : 'roda'} schedules',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final template = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          template.recurrenceType == RecurrenceType.oneTime
                              ? '${DateFormat('MMM d').format(template.oneTimeDate!)} ${template.startTime} - ${template.endTime}'
                              : '${template.dayName} ${template.startTime} - ${template.endTime}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(template.location),
                            Row(
                              children: [
                                Text(
                                  template.recurrenceLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                if (template.price != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• \$${template.price!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTemplate(template),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
  
  String _getRecurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.oneTime: return 'One Time';
      case RecurrenceType.daily: return 'Daily';
      case RecurrenceType.weekly: return 'Weekly';
      case RecurrenceType.biweekly: return 'Biweekly';
      case RecurrenceType.monthly: return 'Monthly';
    }
  }
  
}