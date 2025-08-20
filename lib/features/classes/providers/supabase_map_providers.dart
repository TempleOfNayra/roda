import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/core/models/class_instance.dart';

// Provider for map bounds
final mapBoundsProvider = StateProvider<LatLngBounds?>((ref) => null);

// Provider for map center
final mapCenterProvider = StateProvider<LatLng>((ref) => 
  const LatLng(37.7749, -122.4194) // Default to SF
);

// Provider for search radius in meters
final searchRadiusProvider = StateProvider<double>((ref) => 10000); // 10km default

// Service for map-specific queries using PostGIS
class SupabaseMapService {
  final _client = SupabaseConfig.client;
  
  // Get classes within map bounds using PostGIS
  Future<List<ClassInstance>> getClassesInBounds({
    required LatLngBounds bounds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Create a polygon from the bounds for PostGIS query
      final southwest = bounds.southwest;
      final northeast = bounds.northeast;
      
      // Create WKT polygon string
      final polygon = '''
        POLYGON((
          ${southwest.longitude} ${southwest.latitude},
          ${southwest.longitude} ${northeast.latitude},
          ${northeast.longitude} ${northeast.latitude},
          ${northeast.longitude} ${southwest.latitude},
          ${southwest.longitude} ${southwest.latitude}
        ))
      ''';
      
      // Query using PostGIS ST_Within
      final response = await _client
          .rpc('get_classes_in_bounds', params: {
            'bounds_polygon': polygon,
            'start_date': (startDate ?? DateTime.now()).toIso8601String().split('T')[0],
            'end_date': (endDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().split('T')[0],
          });
      
      return _mapResponseToClasses(response);
    } catch (e) {
      Logger.debug('Error getting classes in bounds: $e');
      // Fallback to simpler query
      return _fallbackQuery(bounds, startDate, endDate);
    }
  }
  
  // Get classes near a point using PostGIS
  Future<List<ClassInstance>> getClassesNearPoint({
    required LatLng center,
    required double radiusMeters,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use PostGIS ST_DWithin for efficient geographic search
      final response = await _client
          .rpc('get_classes_near_point', params: {
            'center_lat': center.latitude,
            'center_lng': center.longitude,
            'radius_meters': radiusMeters,
            'start_date': (startDate ?? DateTime.now()).toIso8601String().split('T')[0],
            'end_date': (endDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().split('T')[0],
          });
      
      return _mapResponseToClasses(response);
    } catch (e) {
      Logger.debug('Error getting classes near point: $e');
      // Fallback to view query
      return _fallbackQueryNearPoint(center, radiusMeters, startDate, endDate);
    }
  }
  
  // Search classes along a route (future feature)
  Future<List<ClassInstance>> getClassesAlongRoute({
    required List<LatLng> routePoints,
    required double bufferMeters,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Create a LineString from route points
      final lineString = 'LINESTRING(${
        routePoints.map((p) => '${p.longitude} ${p.latitude}').join(', ')
      })';
      
      // Use PostGIS ST_Buffer to find classes near the route
      final response = await _client
          .rpc('get_classes_along_route', params: {
            'route_line': lineString,
            'buffer_meters': bufferMeters,
            'start_date': (startDate ?? DateTime.now()).toIso8601String().split('T')[0],
            'end_date': (endDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().split('T')[0],
          });
      
      return _mapResponseToClasses(response);
    } catch (e) {
      Logger.debug('Error getting classes along route: $e');
      return [];
    }
  }
  
  // Fallback query using the map_classes view
  Future<List<ClassInstance>> _fallbackQuery(
    LatLngBounds bounds,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      final response = await _client
          .from('map_classes')
          .select()
          .gte('scheduled_date', (startDate ?? DateTime.now()).toIso8601String().split('T')[0])
          .lte('scheduled_date', (endDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().split('T')[0]);
      
      // Filter in memory (less efficient but works)
      final classes = _mapResponseToClasses(response);
      // TODO: Filter by bounds using schedule template location
      return classes;
    } catch (e) {
      Logger.debug('Fallback query also failed: $e');
      return [];
    }
  }
  
  // Fallback query for near point
  Future<List<ClassInstance>> _fallbackQueryNearPoint(
    LatLng center,
    double radiusMeters,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      final response = await _client
          .from('map_classes')
          .select()
          .gte('scheduled_date', (startDate ?? DateTime.now()).toIso8601String().split('T')[0])
          .lte('scheduled_date', (endDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().split('T')[0]);
      
      // Filter by distance in memory
      final classes = _mapResponseToClasses(response);
      // final radiusKm = radiusMeters / 1000; // Unused - TODO: implement distance filtering
      
      // TODO: Filter by distance using schedule template location
      return classes;
    } catch (e) {
      Logger.debug('Fallback near point query failed: $e');
      return [];
    }
  }
  
  // Calculate distance between two points (Haversine formula)
  // ignore: unused_element
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180);
  
  // Map response to ClassInstance objects
  List<ClassInstance> _mapResponseToClasses(dynamic response) {
    if (response == null) return [];
    
    return (response as List).map<ClassInstance>((data) {
      // Parse location - commented out as values aren't used
      // double? latitude, longitude;
      // if (data['location'] != null) {
      //   final pointStr = data['location'] as String;
      //   final matches = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)').firstMatch(pointStr);
      //   if (matches != null) {
      //     longitude = double.parse(matches.group(1)!);
      //     latitude = double.parse(matches.group(2)!);
      //   }
      // }
      
      final scheduledDate = DateTime.parse(data['scheduled_date']);
      // DateTime startTime;
      
      // Compute startTime but don't use it (it's not used in the return statement)
      // if (data['start_datetime_utc'] != null) {
      //   startTime = DateTime.parse(data['start_datetime_utc']).toLocal();
      // } else {
      //   startTime = scheduledDate;
      // }
      
      return ClassInstance(
        id: data['id'],
        templateId: data['schedule_id'] ?? '',
        scheduledDate: scheduledDate,
        status: data['is_cancelled'] ? ClassStatus.cancelled : ClassStatus.scheduled,
        attendingStudentIds: List<String>.from(data['attending_student_ids'] ?? []),
        presentStudentIds: List<String>.from(data['present_student_ids'] ?? []),
        paymentConfirmations: {},
        notes: data['notes'],
      );
    }).toList();
  }
}

// Provider for map service
final supabaseMapServiceProvider = Provider((ref) => SupabaseMapService());

// Helper function to convert hex string to double (little-endian)
double _hexToDouble(String hex) {
  // Convert hex string to bytes
  final bytes = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  
  // Convert bytes to double (little-endian IEEE 754)
  final byteData = ByteData(8);
  for (int i = 0; i < 8; i++) {
    byteData.setUint8(i, bytes[i]);
  }
  return byteData.getFloat64(0, Endian.little);
}

// Provider for upcoming classes for map with location data
final mapUpcomingClassesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    Logger.debug('🗺️ [MAP PROVIDER] FETCHING MAP CLASSES');
    Logger.debug('   - Date range: ${DateTime.now().toIso8601String().split('T')[0]} to ${DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0]}');
    
    // Fetch directly from map_classes view which has location data
    final startDate = DateTime.now().toIso8601String().split('T')[0];
    final endDate = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0];
    Logger.debug('🔍 [MAP PROVIDER] Query dates: $startDate to $endDate');
    
    final response = await SupabaseConfig.client
        .from('map_classes')
        .select('*')
        .gte('scheduled_date', startDate)
        .lte('scheduled_date', endDate)
        .order('scheduled_date', ascending: true);
    
    Logger.debug('📊 [MAP PROVIDER] Fetched ${response.length} classes from map_classes view');
    
    // Check for Claus group specifically
    final clausClasses = (response as List).where((c) => 
      c['group_name']?.toString().toLowerCase() == 'claus').toList();
    if (clausClasses.isNotEmpty) {
      Logger.debug('🎯 [MAP PROVIDER] Found ${clausClasses.length} Claus group classes!');
      Logger.debug('   First Claus class: ${clausClasses.first}');
    } else {
      Logger.debug('❌ [MAP PROVIDER] No Claus group classes found');
    }
    
    // Log first few classes for debugging
    for (int i = 0; i < response.length && i < 3; i++) {
      final classData = response[i];
      Logger.debug('🔍 [MAP PROVIDER] Class ${i+1}:');
      Logger.debug('   - Name: ${classData['name']}');
      Logger.debug('   - Group: ${classData['group_name']}');
      Logger.debug('   - Location Name: ${classData['location_name']}');
      Logger.debug('   - Location (raw): ${classData['location']?.toString().substring(0, 20) ?? 'null'}...');
      Logger.debug('   - Latitude: ${classData['latitude']}');
      Logger.debug('   - Longitude: ${classData['longitude']}');
      Logger.debug('   - Schedule ID: ${classData['schedule_id']}');
    }
    
    // Parse and add location coordinates to each class
    return (response as List).map<Map<String, dynamic>>((item) {
      // Parse location from PostGIS geography type
      double? latitude, longitude;
      
      // First check if latitude/longitude are already in the response (from view)
      if (item['latitude'] != null && item['longitude'] != null) {
        latitude = item['latitude']?.toDouble();
        longitude = item['longitude']?.toDouble();
        Logger.debug('📍 [MAP PROVIDER] Using coordinates from view: lat=$latitude, lon=$longitude');
      } 
      // Otherwise, try parsing from location field
      else if (item['location'] != null) {
        final locationStr = item['location'] as String;
        Logger.debug('🔧 [MAP PROVIDER] Parsing location string: $locationStr');
        
        // Handle WKB hex format (starts with 01010000)
        if (locationStr.startsWith('0101000020E610')) {
          // This is a WKB hex encoded POINT
          // We'll parse it directly from the hex
          try {
            // WKB structure for POINT with SRID 4326:
            // 01 = little endian
            // 01000020 = point type with SRID
            // E6100000 = SRID 4326
            // Then 16 hex chars for X (longitude) and 16 for Y (latitude)
            // Total minimum length = 18 (header) + 32 (coordinates) = 50
            if (locationStr.length >= 50) {
              // Skip the first 18 characters (header)
              // The next 16 chars are the X coordinate (longitude) 
              // The next 16 chars are the Y coordinate (latitude)
              final lonHex = locationStr.substring(18, 34);
              final latHex = locationStr.substring(34, 50);
              
              Logger.debug('Lon hex: $lonHex, Lat hex: $latHex');
              
              // Convert hex to bytes and then to double (little-endian)
              longitude = _hexToDouble(lonHex);
              latitude = _hexToDouble(latHex);
              
              Logger.debug('Parsed coordinates: lon=$longitude, lat=$latitude');
            } else {
              Logger.debug('Location string too short: ${locationStr.length} chars');
            }
          } catch (e) {
            Logger.debug('Error parsing WKB location: $e');
          }
        } 
        // Handle WKT format (POINT(lon lat))
        else if (locationStr.startsWith('POINT')) {
          final matches = RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(locationStr);
          if (matches != null) {
            longitude = double.tryParse(matches.group(1) ?? '');
            latitude = double.tryParse(matches.group(2) ?? '');
            Logger.debug('Parsed WKT coordinates: lon=$longitude, lat=$latitude');
          }
        }
      }
      
      return <String, dynamic>{
        ...item as Map<String, dynamic>,
        'latitude': latitude,
        'longitude': longitude,
      };
    }).toList();
  } catch (e) {
    Logger.debug('Error fetching map classes: $e');
    return [];
  }
});

// Unused providers - removed by DCM
// // Provider for classes in current map bounds
// final mapClassesProvider = FutureProvider<List<ClassInstance>>((ref) async {
//   final bounds = ref.watch(mapBoundsProvider);
//   if (bounds == null) return [];
//   
//   final service = ref.read(supabaseMapServiceProvider);
//   return service.getClassesInBounds(bounds: bounds);
// });

// // Provider for classes near user location
// final nearbyClassesProvider = FutureProvider<List<ClassInstance>>((ref) async {
//   final center = ref.watch(mapCenterProvider);
//   final radius = ref.watch(searchRadiusProvider);
//   
//   final service = ref.read(supabaseMapServiceProvider);
//   return service.getClassesNearPoint(
//     center: center,
//     radiusMeters: radius,
//   );
// });

