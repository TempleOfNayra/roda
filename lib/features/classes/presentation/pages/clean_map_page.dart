import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/features/classes/providers/supabase_map_providers.dart';
import 'package:roda/core/utils/venmo_helper.dart';
// import 'package:roda/debug_database.dart';
import 'package:roda/core/config/app_config.dart';
import 'dart:async';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/core/theme/roda_colors.dart';

// Group classes by location for map display
class LocationGroup {
  final String location;
  final double latitude;
  final double longitude;
  final List<SimpleClassData> classes;
  
  LocationGroup({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.classes,
  });
  
  bool get hasClasses => classes.any((c) => c.eventType == EventType.class_);
  bool get hasRodas => classes.any((c) => c.eventType == EventType.roda);
  
  SimpleClassData? get nextClass => classes
      .where((c) => c.eventType == EventType.class_)
      .firstOrNull;
      
  SimpleClassData? get nextRoda => classes
      .where((c) => c.eventType == EventType.roda)
      .firstOrNull;
}

// Provider that groups classes by location for map display
final mapLocationGroupsProvider = FutureProvider<Map<String, LocationGroup>>((ref) async {
  // Get classes with location data from the view
  final allClasses = await ref.watch(mapUpcomingClassesProvider.future);
  
  Logger.debug('Processing ${allClasses.length} classes for map display');
  
  final groups = <String, LocationGroup>{};
  
  for (final classData in allClasses) {
    // Skip if no location data
    if (classData['latitude'] == null || classData['longitude'] == null) {
      Logger.debug('Skipping class without location: ${classData['name']}');
      continue;
    }
    
    final locationKey = '${classData['location_name']}_${classData['latitude']}_${classData['longitude']}';
    
    // Create a simple class object with the data we need
    final classObj = SimpleClassData(
      id: classData['id'],
      scheduleId: classData['schedule_id'] ?? '',
      groupId: classData['group_id'],
      name: classData['name'] ?? 'Class',
      scheduledDate: DateTime.parse(classData['scheduled_date']),
      startTime: classData['start_datetime_utc'] != null 
          ? DateTime.parse(classData['start_datetime_utc']).toLocal()
          : DateTime.parse(classData['scheduled_date']),
      eventType: classData['event_type'] == 'roda' ? EventType.roda : EventType.class_,
      locationName: classData['location_name'] ?? 'Unknown Location',
      groupName: classData['group_name'] ?? '',
      teacherName: classData['teacher_name'] ?? '',
      price: classData['price']?.toDouble(),
      attendingCount: classData['registered_count'] ?? 0,
      attendingStudentIds: classData['attending_student_ids'] != null 
          ? List<String>.from(classData['attending_student_ids'])
          : [],
    );
    
    if (groups.containsKey(locationKey)) {
      groups[locationKey]!.classes.add(classObj);
    } else {
      groups[locationKey] = LocationGroup(
        location: classData['location_name'] ?? 'Unknown Location',
        latitude: classData['latitude'].toDouble(),
        longitude: classData['longitude'].toDouble(),
        classes: [classObj],
      );
    }
  }
  
  // Sort classes within each group by date
  for (final group in groups.values) {
    group.classes.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }
  
  Logger.debug('Created ${groups.length} location groups for map');
  
  return groups;
});

// Simple class data for map display
class SimpleClassData {
  final String id;
  final String scheduleId;
  final String? groupId;
  final String name;
  final DateTime scheduledDate;
  final DateTime startTime;
  final EventType eventType;
  final String locationName;
  final String groupName;
  final String teacherName;
  final double? price;
  final int attendingCount;
  final List<String> attendingStudentIds;
  
  SimpleClassData({
    required this.id,
    required this.scheduleId,
    this.groupId,
    required this.name,
    required this.scheduledDate,
    required this.startTime,
    required this.eventType,
    required this.locationName,
    required this.groupName,
    required this.teacherName,
    this.price,
    required this.attendingCount,
    List<String>? attendingStudentIds,
  }) : attendingStudentIds = attendingStudentIds ?? [];
}

class CleanMapPage extends ConsumerStatefulWidget {
  const CleanMapPage({super.key});

  @override
  ConsumerState<CleanMapPage> createState() => _CleanMapPageState();
}

class _CleanMapPageState extends ConsumerState<CleanMapPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  LocationGroup? _selectedLocation;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Run database debug only in debug mode
    if (AppConfig.enableDebugMode) {
      // Debug removed
    }
    
    // Set up auto-refresh timer
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        Logger.debug('🔄 Auto-refreshing map data');
        // Invalidate the provider to force fresh data
        ref.invalidate(mapLocationGroupsProvider);
        ref.invalidate(mapUpcomingClassesProvider);
      },
    );
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      Logger.debug('Error getting location: $e');
    }
  }
  
  void _createMarkers(Map<String, LocationGroup> groups) {
    _markers.clear();
    
    for (final entry in groups.entries) {
      final locationKey = entry.key;
      final group = entry.value;
      
      // Determine marker color
      BitmapDescriptor markerIcon;
      if (group.hasClasses && group.hasRodas) {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      } else if (group.hasRodas) {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      } else {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }
      
      _markers.add(
        Marker(
          markerId: MarkerId(locationKey),
          position: LatLng(group.latitude, group.longitude),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: group.location,
            snippet: '${group.classes.length} upcoming event${group.classes.length > 1 ? 's' : ''}',
          ),
          onTap: () {
            setState(() {
              _selectedLocation = group;
            });
          },
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(mapLocationGroupsProvider);
    
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Map'),
      ),
      child: groupsAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: RodaColors.destructiveRed),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () => ref.refresh(mapLocationGroupsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (groups) {
          _createMarkers(groups);
          
          if (groups.isEmpty) {
            return Stack(
              children: [
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.calendar_badge_minus, size: 64, color: RodaColors.systemGrey),
                      SizedBox(height: 16),
                      Text(
                        'No upcoming classes or rodas',
                        style: TextStyle(fontSize: 18, color: RodaColors.systemGrey),
                      ),
                    ],
                  ),
                ),
                // Back button even when no data
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: RodaColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.back, color: RodaColors.black, size: 20),
                    ),
                  ),
                ),
              ],
            );
          }
          
          return Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  
                  if (_markers.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _fitAllMarkers();
                    });
                  }
                },
                onCameraIdle: () async {
                  // Refresh data when camera stops moving
                  ref.invalidate(mapUpcomingClassesProvider);
                  ref.invalidate(mapLocationGroupsProvider);
                },
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : const LatLng(40.7128, -74.0060),
                  zoom: 12,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapType: MapType.normal,
                onTap: (_) {
                  setState(() {
                    _selectedLocation = null;
                  });
                },
              ),
              
              // Back button - top left
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: Container(
                  decoration: const BoxDecoration(
                    color: RodaColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(CupertinoIcons.back, color: RodaColors.black, size: 20),
                  ),
                ),
              ),
              
              // My location button - top right
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: Container(
                  decoration: const BoxDecoration(
                    color: RodaColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: _getCurrentLocation,
                    child: const Icon(CupertinoIcons.location, color: RodaColors.black, size: 20),
                  ),
                ),
              ),
              
              // Legend - moved below back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: RodaColors.systemBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: RodaColors.systemGrey4,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.info_circle, size: 16, color: RodaColors.systemGrey),
                            const SizedBox(width: 4),
                            Text(
                              'Map Legend',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: RodaColors.label,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(RodaColors.activeBlue, 'Classes only'),
                        _buildLegendItem(RodaColors.secondary, 'Rodas only'),
                        _buildLegendItem(RodaColors.primary, 'Both'),
                      ],
                    ),
                ),
              ),
              
              // Bottom sheet for selected location
              if (_selectedLocation != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildLocationDetails(_selectedLocation!),
                ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildLocationDetails(LocationGroup location) {
    // Get next 4 upcoming classes/rodas
    final upcomingEvents = location.classes.take(4).toList();
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6, // Max 60% of screen
      ),
      decoration: const BoxDecoration(
        color: RodaColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: RodaColors.systemGrey4,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: RodaColors.systemGrey4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Location header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(CupertinoIcons.location_solid, color: RodaColors.destructiveRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.location,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${location.classes.length} upcoming events',
                        style: TextStyle(
                          fontSize: 12,
                          color: RodaColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _selectedLocation = null;
                    });
                  },
                  child: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
          ),
          
          Container(
            height: 1,
            color: RodaColors.separator,
          ),
          
          // Scrollable list of upcoming classes
          Flexible(
            child: upcomingEvents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No upcoming events',
                      style: TextStyle(color: RodaColors.systemGrey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: upcomingEvents.length,
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      color: RodaColors.separator,
                    ),
                    itemBuilder: (context, index) {
                      final classData = upcomingEvents[index];
                      return _buildClassListItem(classData);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClassListItem(SimpleClassData classData) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    final isRoda = classData.eventType == EventType.roda;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Event type icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isRoda ? RodaColors.secondary.withOpacity(0.1) : RodaColors.activeBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRoda ? CupertinoIcons.music_note : CupertinoIcons.sportscourt,
              color: isRoda ? RodaColors.secondary : RodaColors.activeBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group name and event type
                Text(
                  classData.groupName.isNotEmpty ? classData.groupName : (isRoda ? 'Roda' : 'Class'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                // Date and time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRoda ? RodaColors.secondary : RodaColors.activeBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isRoda ? 'RODA' : 'CLASS',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: RodaColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${dateFormat.format(classData.scheduledDate)} • ${timeFormat.format(classData.startTime)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: RodaColors.secondaryLabel,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Teacher name and price
                Row(
                  children: [
                    if (classData.teacherName.isNotEmpty)
                      Expanded(
                        child: Text(
                          'by ${classData.teacherName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: RodaColors.secondaryLabel,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (classData.price != null)
                      Text(
                        '\$${classData.price!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: RodaColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Register/Cancel/Pay buttons
          Consumer(
            builder: (context, ref, child) {
              final currentUser = ref.watch(currentUserProvider).value;
              final isRegistered = currentUser != null && 
                  classData.attendingStudentIds.contains(currentUser.id);
              
              if (!isRegistered) {
                // Show Register button
                return CupertinoButton(
                  onPressed: () => _handleRegister(classData, isRegistered),
                  color: isRoda ? RodaColors.secondary : RodaColors.activeBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderRadius: BorderRadius.circular(20),
                  child: const Text(
                    'Register',
                    style: TextStyle(fontSize: 13, color: RodaColors.white),
                  ),
                );
              } else {
                // Show Cancel and Pay buttons
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pay button
                    if (classData.price != null && classData.price! > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: RodaColors.success),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CupertinoButton(
                            onPressed: () => _handlePayment(classData),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            borderRadius: BorderRadius.circular(20),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.money_dollar, size: 16, color: RodaColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'Pay',
                                  style: TextStyle(fontSize: 13, color: RodaColors.success),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Cancel button
                    CupertinoButton(
                      onPressed: () => _handleRegister(classData, isRegistered),
                      color: RodaColors.destructiveRed,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      borderRadius: BorderRadius.circular(20),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 13, color: RodaColors.white),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
  
  void _handlePayment(SimpleClassData classData) async {
    // Get the group's Venmo handle - always fetch latest data
    if (classData.groupId == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Group information not available'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }
    
    final groupAsyncValue = ref.read(groupByIdProvider(classData.groupId!));
    
    final groupAsync = groupAsyncValue.when(
      data: (data) => data,
      loading: () => null,
      error: (_, __) => null,
    );
    
    if (groupAsync == null || groupAsync.venmoHandle == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Payment Unavailable'),
          content: const Text('Payment information not available for this class'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }
    
    final eventType = classData.eventType == EventType.roda ? 'Roda' : 'Class';
    final dateStr = DateFormat('MMM d').format(classData.scheduledDate);
    final note = '$eventType - $dateStr - ${classData.groupName}';
    
    final success = await VenmoHelper.launchVenmoPayment(
      venmoHandle: groupAsync.venmoHandle!,
      amount: classData.price,
      note: note,
    );
    
    if (!success && context.mounted) {
      // ignore: use_build_context_synchronously
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Venmo Error'),
          content: const Text('Could not open Venmo. Please install the Venmo app.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
  
  void _handleRegister(SimpleClassData classData, bool isRegistered) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('Please sign in to register for classes'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }
    
    Logger.debug('🎯 Registration: User ${currentUser.id} ${isRegistered ? "cancelling" : "registering"} for class ${classData.id}');
    
    try {
      // TODO: Update the class_instances to add/remove user registration
      // Need to implement with Supabase
      
      final action = isRegistered ? 'Cancelled registration for' : 'Successfully registered for';
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(isRegistered ? 'Registration Cancelled' : 'Registration Successful'),
          content: Text(
            '$action ${classData.eventType == EventType.roda ? "Roda" : "Class"} on ${DateFormat('MMM d').format(classData.scheduledDate)}',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      
      // Update the local instance data to reflect the change
      if (isRegistered) {
        classData.attendingStudentIds.remove(currentUser.id);
      } else {
        classData.attendingStudentIds.add(currentUser.id);
      }
      
      // Refresh the UI
      setState(() {});
    } catch (e) {
      Logger.debug('Error updating registration: $e');
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Registration Error'),
          content: Text('Failed to update registration: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
  
  // Unused method - kept for potential future use
  // ignore: unused_element
  Widget _buildEventCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required SimpleClassData classData,
  }) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: RodaColors.systemGrey4),
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
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RodaColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(classData.scheduledDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  timeFormat.format(classData.startTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: RodaColors.secondaryLabel,
                  ),
                ),
                if (classData.groupName.isNotEmpty)
                  Text(
                    classData.groupName,
                    style: TextStyle(
                      fontSize: 12,
                      color: RodaColors.tertiaryLabel,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _fitAllMarkers() {
    if (_markers.isEmpty) return;
    
    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;
    
    for (final marker in _markers) {
      minLat = minLat > marker.position.latitude ? marker.position.latitude : minLat;
      maxLat = maxLat < marker.position.latitude ? marker.position.latitude : maxLat;
      minLng = minLng > marker.position.longitude ? marker.position.longitude : minLng;
      maxLng = maxLng < marker.position.longitude ? marker.position.longitude : maxLng;
    }
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }
}