import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roda/core/models/group_model.dart';
import 'package:roda/features/map/providers/map_providers.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/routing/routes.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  GoogleMapController? _mapController;
  
  static const _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco default
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    final nearbyGroups = ref.watch(nearbyGroupsProvider);
    final authState = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Classes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              _showGroupsList(context, nearbyGroups);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) {
              _mapController = controller;
              _centerOnUserLocation();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _buildMarkers(nearbyGroups),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _centerOnUserLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(AsyncValue<List<GroupModel>> nearbyGroups) {
    return nearbyGroups.when(
      data: (groups) {
        return groups.map((group) {
          return Marker(
            markerId: MarkerId(group.id),
            position: LatLng(
              group.location.latitude,
              group.location.longitude,
            ),
            infoWindow: InfoWindow(
              title: group.name,
              snippet: _getScheduleSnippet(group.schedule),
              onTap: () => _showGroupDetails(context, group),
            ),
          );
        }).toSet();
      },
      loading: () => {},
      error: (_, __) => {},
    );
  }

  String _getScheduleSnippet(List<ClassSchedule> schedule) {
    if (schedule.isEmpty) return 'No schedule set';
    
    final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final first = schedule.first;
    return '${days[first.dayOfWeek]} ${first.startTime}';
  }

  void _centerOnUserLocation() async {
    final location = await ref.read(locationServiceProvider).getCurrentLocation();
    
    if (location != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(location.latitude, location.longitude),
        ),
      );
    }
  }

  void _showGroupsList(
    BuildContext context,
    AsyncValue<List<GroupModel>> nearbyGroups,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Nearby Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: nearbyGroups.when(
                    data: (groups) {
                      if (groups.isEmpty) {
                        return const Center(
                          child: Text('No classes found nearby'),
                        );
                      }
                      
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _buildGroupCard(context, group);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Text('Error: $error'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupModel group) {
    return Card(
      child: InkWell(
        onTap: () => _showGroupDetails(context, group),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Teacher: ${group.teacherName}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      group.location.address,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildScheduleInfo(group.schedule),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleInfo(List<ClassSchedule> schedule) {
    if (schedule.isEmpty) {
      return const Text(
        'No schedule set',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      );
    }
    
    final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final scheduleText = schedule
        .map((s) => '${days[s.dayOfWeek]} ${s.startTime}-${s.endTime}')
        .join(', ');
    
    return Row(
      children: [
        const Icon(Icons.schedule, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            scheduleText,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showGroupDetails(BuildContext context, GroupModel group) {
    final authState = ref.read(authStateProvider);
    final isLoggedIn = authState.value != null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Teacher: ${group.teacherName}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.location_on, group.location.address),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.schedule,
                _getScheduleText(group.schedule),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoggedIn
                      ? () {
                          // TODO: Implement join group functionality
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Join group feature coming soon!'),
                            ),
                          );
                        }
                      : () {
                          Navigator.pop(context);
                          context.push(Routes.signUp);
                        },
                  child: Text(isLoggedIn ? 'Join Group' : 'Sign Up to Join'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  String _getScheduleText(List<ClassSchedule> schedule) {
    if (schedule.isEmpty) return 'No schedule set';
    
    final days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return schedule
        .map((s) => '${days[s.dayOfWeek]} ${s.startTime}-${s.endTime}')
        .join('\n');
  }
}