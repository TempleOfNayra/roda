import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:roda/core/models/capoeira_group.dart';
// import 'package:roda/features/map/repositories/group_repository.dart';
import 'package:roda/features/map/services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// TODO: Implement with Supabase
// final groupRepositoryProvider = Provider<GroupRepository>((ref) {
//   return GroupRepository();
// });

// Unused - removed by DCM
// final userLocationProvider = FutureProvider<Position?>((ref) async {
//   final locationService = ref.watch(locationServiceProvider);
//   return locationService.getCurrentLocation();
// });

// Unused - removed by DCM
// // TODO: Implement with Supabase
// final nearbyGroupsProvider = StreamProvider<List<CapoeiraGroup>>((ref) {
  // final groupRepository = ref.watch(groupRepositoryProvider);
  // final userLocation = ref.watch(userLocationProvider);
  
  // return userLocation.when(
  //   data: (location) {
  //     if (location == null) {
  //       // Return all groups if location not available
  //       return groupRepository.getAllGroups();
  //     }
      
  //     // Get groups within 50km radius
  //     return groupRepository.getNearbyGroups(
  //       latitude: location.latitude,
  //       longitude: location.longitude,
  //       radiusInKm: 50,
  //     );
  //   },
  //   loading: () => Stream.value([]),
  //   error: (_, __) => groupRepository.getAllGroups(),
  // );
//   
//   return Stream.value([]); // Temporary empty stream
// });