import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

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
  int _selectedDay = 1; // Monday
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);
  EventType _currentEventType = EventType.class_;
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

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      appBar: AppBar(
        title: const Text('Schedule Template'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Class'),
            Tab(text: 'Roda'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleForm(),
          _buildScheduleForm(),
        ],
      ),
    );
  }

  Widget _buildScheduleForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day Selection
            const Text(
              'Select Day',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildDaySelector(),
            const SizedBox(height: 16),
            
            // Time Selection
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector('Start Time', _startTime, (time) {
                    setState(() => _startTime = time);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSelector('End Time', _endTime, (time) {
                    setState(() => _endTime = time);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Location Field
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Enter the class location',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a location';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Price Field
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (USD)',
                hintText: 'e.g., 20.00',
                prefixText: '\$',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(height: 16),
            
            // Recurrence Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _currentEventType == EventType.class_ 
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _currentEventType == EventType.class_
                      ? 'Weekly Recurring Class'
                      : 'Weekly Recurring Roda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _currentEventType == EventType.class_ 
                        ? Colors.blue
                        : Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveSchedule,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        'Save ${_currentEventType == EventType.class_ ? "Class" : "Roda"} Schedule',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    
    return Wrap(
      spacing: 8,
      children: List.generate(7, (index) {
        final dayNum = index + 1;
        final isSelected = _selectedDay == dayNum;
        
        return ChoiceChip(
          label: Text(days[index]),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedDay = dayNum);
            }
          },
        );
      }),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          time.format(context),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');
      
      // TODO: Save to Supabase
      // For now, just show success message
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_currentEventType == EventType.class_ ? "Class" : "Roda"} schedule saved!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}