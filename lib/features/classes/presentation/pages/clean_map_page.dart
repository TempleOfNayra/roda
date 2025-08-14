import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:roda/features/teacher/providers/schedule_providers.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/debug_database.dart';
import 'package:roda/core/config/app_config.dart';
import 'dart:async';

// Group classes by location for map display
class LocationGroup {
  final String location;
  final double latitude;
  final double longitude;
  final List<FullClassData> classes;
  
  LocationGroup({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.classes,
  });
  
  bool get hasClasses => classes.any((c) => c.eventType == EventType.class_);
  bool get hasRodas => classes.any((c) => c.eventType == EventType.roda);
  
  FullClassData? get nextClass => classes
      .where((c) => c.eventType == EventType.class_)
      .firstOrNull;
      
  FullClassData? get nextRoda => classes
      .where((c) => c.eventType == EventType.roda)
      .firstOrNull;
}

// Provider that groups classes by location for map display
final mapLocationGroupsProvider = FutureProvider<Map<String, LocationGroup>>((ref) async {
  final allClasses = await ref.watch(mapUpcomingClassesProvider.future);
  
  final groups = <String, LocationGroup>{};
  
  for (final classData in allClasses) {
    // Skip if no coordinates
    if (classData.latitude == null || classData.longitude == null) continue;
    
    // Create location key
    final locationKey = '${classData.latitude!.toStringAsFixed(6)},${classData.longitude!.toStringAsFixed(6)}';
    
    if (!groups.containsKey(locationKey)) {
      groups[locationKey] = LocationGroup(
        location: classData.location,
        latitude: classData.latitude!,
        longitude: classData.longitude!,
        classes: [],
      );
    }
    
    groups[locationKey]!.classes.add(classData);
  }
  
  // Sort classes within each group by date
  for (final group in groups.values) {
    group.classes.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }
  
  return groups;
});

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
    // Run database debug
    runDebug();
    
    // Set up auto-refresh timer
    _refreshTimer = Timer.periodic(
      Duration(seconds: AppConfig.mapRefreshInterval),
      (_) {
        print('🔄 Auto-refreshing map data (every ${AppConfig.mapRefreshInterval}s)');
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
      print('Error getting location: $e');
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
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // Hide the app bar but keep safe area
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
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
                      Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No upcoming classes or rodas',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Back button even when no data
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
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
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              
              // My location button - top right
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.black87, size: 20),
                    onPressed: _getCurrentLocation,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              
              // Legend - moved below back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Map Legend',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.blue, 'Classes only'),
                        _buildLegendItem(Colors.orange, 'Rodas only'),
                        _buildLegendItem(Colors.purple, 'Both'),
                      ],
                    ),
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
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
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
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Location header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
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
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedLocation = null;
                    });
                  },
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Scrollable list of upcoming classes
          Flexible(
            child: upcomingEvents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No upcoming events',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: upcomingEvents.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
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
  
  Widget _buildClassListItem(FullClassData classData) {
    final dateFormat = DateFormat('EEE, MMM d');
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
              color: isRoda ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRoda ? Icons.music_note : Icons.sports_martial_arts,
              color: isRoda ? Colors.orange : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isRoda ? 'Roda' : 'Class',
                      style: TextStyle(
                        fontSize: 12,
                        color: isRoda ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(classData.scheduledDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${classData.startTime} - ${classData.endTime}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                if (classData.groupName.isNotEmpty)
                  Text(
                    classData.groupName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Register button
          ElevatedButton(
            onPressed: () => _handleRegister(classData),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRoda ? Colors.orange : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Register',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleRegister(FullClassData classData) {
    // TODO: Implement registration logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registered for ${classData.eventType == EventType.roda ? "Roda" : "Class"} on ${DateFormat('MMM d').format(classData.scheduledDate)}',
        ),
        backgroundColor: classData.eventType == EventType.roda ? Colors.orange : Colors.blue,
      ),
    );
  }
  
  Widget _buildEventCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required FullClassData classData,
  }) {
    final dateFormat = DateFormat('EEE, MMM d');
    
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
                    color: Colors.grey,
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
                  '${classData.startTime} - ${classData.endTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (classData.groupName.isNotEmpty)
                  Text(
                    classData.groupName,
                    style: TextStyle(
                      fontSize: 12,
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