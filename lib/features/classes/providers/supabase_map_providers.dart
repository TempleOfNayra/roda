import 'dart:math' as math;
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
      final radiusKm = radiusMeters / 1000;
      
      // TODO: Filter by distance using schedule template location
      return classes;
    } catch (e) {
      Logger.debug('Fallback near point query failed: $e');
      return [];
    }
  }
  
  // Calculate distance between two points (Haversine formula)
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
      // Parse location
      double? latitude, longitude;
      if (data['location'] != null) {
        final pointStr = data['location'] as String;
        final matches = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)').firstMatch(pointStr);
        if (matches != null) {
          longitude = double.parse(matches.group(1)!);
          latitude = double.parse(matches.group(2)!);
        }
      }
      
      final scheduledDate = DateTime.parse(data['scheduled_date']);
      DateTime startTime;
      
      if (data['start_datetime_utc'] != null) {
        startTime = DateTime.parse(data['start_datetime_utc']).toLocal();
      } else {
        startTime = scheduledDate;
      }
      
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

// Provider for upcoming classes for map with location data
final mapUpcomingClassesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    // Fetch directly from map_classes view which has location data
    final response = await SupabaseConfig.client
        .from('map_classes')
        .select('*')
        .gte('scheduled_date', DateTime.now().toIso8601String().split('T')[0])
        .lte('scheduled_date', DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0])
        .order('scheduled_date', ascending: true)
        .limit(100);
    
    Logger.debug('Fetched ${response.length} classes from map_classes view');
    
    // Parse and add location coordinates to each class
    return (response as List).map<Map<String, dynamic>>((item) {
      // Parse location from PostGIS geography type
      double? latitude, longitude;
      if (item['location'] != null) {
        final pointStr = item['location'] as String;
        final matches = RegExp(r'([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)').firstMatch(pointStr);
        if (matches != null) {
          longitude = double.tryParse(matches.group(1) ?? '');
          latitude = double.tryParse(matches.group(2) ?? '');
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

// Provider for classes in current map bounds
final mapClassesProvider = FutureProvider<List<ClassInstance>>((ref) async {
  final bounds = ref.watch(mapBoundsProvider);
  if (bounds == null) return [];
  
  final service = ref.read(supabaseMapServiceProvider);
  return service.getClassesInBounds(bounds: bounds);
});

// Provider for classes near user location
final nearbyClassesProvider = FutureProvider<List<ClassInstance>>((ref) async {
  final center = ref.watch(mapCenterProvider);
  final radius = ref.watch(searchRadiusProvider);
  
  final service = ref.read(supabaseMapServiceProvider);
  return service.getClassesNearPoint(
    center: center,
    radiusMeters: radius,
  );
});

// Create the stored procedures in Supabase
const String createStoredProcedures = '''
-- Get classes within a polygon boundary
CREATE OR REPLACE FUNCTION get_classes_in_bounds(
  bounds_polygon TEXT,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id UUID,
  schedule_id UUID,
  scheduled_date DATE,
  start_datetime_utc TIMESTAMPTZ,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  event_type TEXT,
  teacher_id UUID,
  group_id UUID,
  price DECIMAL,
  max_students INT,
  is_cancelled BOOLEAN,
  cancellation_reason TEXT,
  registered_count BIGINT,
  group_name TEXT,
  teacher_name TEXT
) AS \$\$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.schedule_id,
    mc.scheduled_date,
    mc.start_datetime_utc,
    mc.location,
    mc.location_name,
    mc.name,
    mc.event_type,
    mc.teacher_id,
    mc.group_id,
    mc.price,
    mc.max_students,
    mc.is_cancelled,
    mc.cancellation_reason,
    mc.registered_count,
    mc.group_name,
    mc.teacher_name
  FROM map_classes mc
  WHERE ST_Within(mc.location, ST_GeomFromText(bounds_polygon, 4326)::geography)
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
    AND NOT mc.is_cancelled;
END;
\$\$ LANGUAGE plpgsql;

-- Get classes near a point
CREATE OR REPLACE FUNCTION get_classes_near_point(
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id UUID,
  schedule_id UUID,
  scheduled_date DATE,
  start_datetime_utc TIMESTAMPTZ,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  event_type TEXT,
  teacher_id UUID,
  group_id UUID,
  price DECIMAL,
  max_students INT,
  is_cancelled BOOLEAN,
  cancellation_reason TEXT,
  registered_count BIGINT,
  group_name TEXT,
  teacher_name TEXT,
  distance FLOAT
) AS \$\$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.schedule_id,
    mc.scheduled_date,
    mc.start_datetime_utc,
    mc.location,
    mc.location_name,
    mc.name,
    mc.event_type,
    mc.teacher_id,
    mc.group_id,
    mc.price,
    mc.max_students,
    mc.is_cancelled,
    mc.cancellation_reason,
    mc.registered_count,
    mc.group_name,
    mc.teacher_name,
    ST_Distance(
      mc.location,
      ST_MakePoint(center_lng, center_lat)::geography
    ) as distance
  FROM map_classes mc
  WHERE ST_DWithin(
    mc.location,
    ST_MakePoint(center_lng, center_lat)::geography,
    radius_meters
  )
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
    AND NOT mc.is_cancelled
  ORDER BY distance;
END;
\$\$ LANGUAGE plpgsql;

-- Get classes along a route
CREATE OR REPLACE FUNCTION get_classes_along_route(
  route_line TEXT,
  buffer_meters DOUBLE PRECISION,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id UUID,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  scheduled_date DATE,
  distance FLOAT
) AS \$\$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.location,
    mc.location_name,
    mc.name,
    mc.scheduled_date,
    ST_Distance(
      mc.location,
      ST_GeomFromText(route_line, 4326)::geography
    ) as distance
  FROM map_classes mc
  WHERE ST_DWithin(
    mc.location,
    ST_Buffer(ST_GeomFromText(route_line, 4326)::geography, buffer_meters),
    0
  )
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
    AND NOT mc.is_cancelled
  ORDER BY distance;
END;
\$\$ LANGUAGE plpgsql;
''';