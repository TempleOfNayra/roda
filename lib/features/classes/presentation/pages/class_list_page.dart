import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:roda/core/models/class_session_model.dart';

// Provider for upcoming events grouped by location
final upcomingEventsListProvider = FutureProvider<List<LocationGroup>>((ref) async {
  final now = DateTime.now();
  final endDate = now.add(const Duration(days: 30));
  
  // Query all scheduled classes
  final classesSnapshot = await FirebaseFirestore.instance
      .collection('classes')
      .where('status', isEqualTo: ClassStatus.scheduled.name)
      .get();
  
  print('Found ${classesSnapshot.docs.length} total classes');
  
  // Group by location
  final locationGroups = <String, LocationGroup>{};
  
  for (final doc in classesSnapshot.docs) {
    final data = doc.data();
    final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
    
    // Filter by date range
    if (scheduledDate.isBefore(now) || scheduledDate.isAfter(endDate)) {
      continue;
    }
    
    final location = data['location'] as String? ?? '';
    if (location.isEmpty) continue;
    
    // Create unique key for location
    final locationKey = location.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    
    // Parse event details
    final eventType = data['eventType'] as String;
    final startTime = data['startTime'] as String;
    final endTime = data['endTime'] as String;
    final groupName = data['groupName'] as String? ?? '';
    final teacherId = data['teacherId'] as String;
    
    final event = ClassEvent(
      id: doc.id,
      eventType: eventType == EventType.roda.name ? 'Roda' : 'Class',
      scheduledDate: scheduledDate,
      startTime: startTime,
      endTime: endTime,
      groupName: groupName,
      teacherId: teacherId,
    );
    
    // Add to location group
    if (!locationGroups.containsKey(locationKey)) {
      locationGroups[locationKey] = LocationGroup(
        location: location,
        events: [],
      );
    }
    
    locationGroups[locationKey]!.events.add(event);
  }
  
  // Sort events within each location by date
  for (final group in locationGroups.values) {
    group.events.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }
  
  // Convert to list and sort by location name
  final groupsList = locationGroups.values.toList()
    ..sort((a, b) => a.location.compareTo(b.location));
  
  print('Grouped into ${groupsList.length} locations');
  
  return groupsList;
});

class LocationGroup {
  final String location;
  final List<ClassEvent> events;
  
  LocationGroup({
    required this.location,
    required this.events,
  });
  
  ClassEvent? get nextClass => events.firstWhere(
    (e) => e.eventType == 'Class',
    orElse: () => ClassEvent.empty(),
  ).id.isNotEmpty ? events.firstWhere((e) => e.eventType == 'Class') : null;
  
  ClassEvent? get nextRoda => events.firstWhere(
    (e) => e.eventType == 'Roda',
    orElse: () => ClassEvent.empty(),
  ).id.isNotEmpty ? events.firstWhere((e) => e.eventType == 'Roda') : null;
  
  ClassEvent get nextEvent => events.first;
}

class ClassEvent {
  final String id;
  final String eventType;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final String groupName;
  final String teacherId;
  
  ClassEvent({
    required this.id,
    required this.eventType,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.groupName,
    required this.teacherId,
  });
  
  factory ClassEvent.empty() => ClassEvent(
    id: '',
    eventType: '',
    scheduledDate: DateTime.now(),
    startTime: '',
    endTime: '',
    groupName: '',
    teacherId: '',
  );
  
  String get formattedDate => DateFormat('EEE, MMM d').format(scheduledDate);
  String get formattedTime => '$startTime - $endTime';
}

class ClassListPage extends ConsumerWidget {
  const ClassListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes & Rodas'),
        centerTitle: true,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(upcomingEventsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No upcoming classes or rodas',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              return _buildLocationCard(context, location);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildLocationCard(BuildContext context, LocationGroup location) {
    final hasClasses = location.events.any((e) => e.eventType == 'Class');
    final hasRodas = location.events.any((e) => e.eventType == 'Roda');
    
    Color accentColor;
    IconData icon;
    if (hasClasses && hasRodas) {
      accentColor = Colors.purple;
      icon = Icons.celebration;
    } else if (hasRodas) {
      accentColor = Colors.orange;
      icon = Icons.music_note;
    } else {
      accentColor = Colors.blue;
      icon = Icons.sports_martial_arts;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor),
        ),
        title: Text(
          location.location,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${location.events.length} upcoming event${location.events.length > 1 ? 's' : ''}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Next class
                if (location.nextClass != null) ...[
                  _buildEventRow(
                    icon: Icons.sports_martial_arts,
                    iconColor: Colors.blue,
                    title: 'Next Class',
                    event: location.nextClass!,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Next roda
                if (location.nextRoda != null) ...[
                  _buildEventRow(
                    icon: Icons.music_note,
                    iconColor: Colors.orange,
                    title: 'Next Roda',
                    event: location.nextRoda!,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Show all events
                if (location.events.length > 2) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'All Events',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...location.events.map((event) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          event.eventType == 'Roda' ? Icons.music_note : Icons.sports_martial_arts,
                          size: 16,
                          color: event.eventType == 'Roda' ? Colors.orange : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.formattedDate,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.formattedTime,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        if (event.groupName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '• ${event.groupName}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required ClassEvent event,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.formattedDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  event.formattedTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                if (event.groupName.isNotEmpty)
                  Text(
                    event.groupName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}