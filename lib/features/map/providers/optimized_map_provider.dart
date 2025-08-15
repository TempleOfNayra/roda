import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/features/teacher/providers/schedule_providers.dart';
import 'dart:math' as math;

// Provider for user's current position
final userPositionProvider = StateProvider<Position?>((ref) => null);

// Provider for map viewport bounds
final mapBoundsProvider = StateProvider<MapBounds?>((ref) => null);

class MapBounds {
  final double northEast_lat;
  final double northEast_lng;
  final double southWest_lat;
  final double southWest_lng;
  
  MapBounds({
    required this.northEast_lat,
    required this.northEast_lng,
    required this.southWest_lat,
    required this.southWest_lng,
  });
  
  // Calculate if a point is within bounds
  bool contains(double lat, double lng) {
    return lat >= southWest_lat && 
           lat <= northEast_lat && 
           lng >= southWest_lng && 
           lng <= northEast_lng;
  }
  
  // Get center point
  double get centerLat => (northEast_lat + southWest_lat) / 2;
  double get centerLng => (northEast_lng + southWest_lng) / 2;
  
  // Calculate rough radius in km
  double get radiusKm {
    const double earthRadius = 6371; // km
    
    // Calculate distance from center to corner
    final latDiff = (northEast_lat - southWest_lat) / 2;
    final lngDiff = (northEast_lng - southWest_lng) / 2;
    
    // Simple approximation
    final latDistance = latDiff * 111; // roughly 111km per degree latitude
    final lngDistance = lngDiff * 111 * math.cos(centerLat * math.pi / 180);
    
    return math.sqrt(latDistance * latDistance + lngDistance * lngDistance);
  }
}

// Optimized provider that only fetches classes within map bounds
final optimizedMapClassesProvider = FutureProvider<List<FullClassData>>((ref) async {
  final bounds = ref.watch(mapBoundsProvider);
  final userPosition = ref.watch(userPositionProvider);
  
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  final endDate = now.add(const Duration(days: 14)); // Only show next 2 weeks
  
  try {
    // First, get templates within bounds or near user
    Query<Map<String, dynamic>> templatesQuery = db
        .collection('schedule_templates')
        .where('isActive', isEqualTo: true);
    
    // If we have bounds, filter by approximate area
    if (bounds != null) {
      // Add some padding to bounds (about 10km)
      final padding = 0.1; // roughly 10km
      
      // Firestore doesn't support complex geo queries, but we can filter by rough bounds
      templatesQuery = templatesQuery
          .where('latitude', isGreaterThanOrEqualTo: bounds.southWest_lat - padding)
          .where('latitude', isLessThanOrEqualTo: bounds.northEast_lat + padding);
    } else if (userPosition != null) {
      // If no bounds but have user position, get within 50km radius
      // This is a rough box filter - proper distance filtering happens client-side
      final radiusDegrees = 0.45; // roughly 50km
      templatesQuery = templatesQuery
          .where('latitude', isGreaterThanOrEqualTo: userPosition.latitude - radiusDegrees)
          .where('latitude', isLessThanOrEqualTo: userPosition.latitude + radiusDegrees);
    }
    // If neither bounds nor position, limit to reasonable number
    else {
      templatesQuery = templatesQuery.limit(50);
    }
    
    final templatesSnapshot = await templatesQuery.get();
    
    if (templatesSnapshot.docs.isEmpty) {
      print('No templates found in area');
      return [];
    }
    
    // Filter templates client-side for precise bounds/distance
    final templates = <String, ScheduleTemplate>{};
    for (final doc in templatesSnapshot.docs) {
      final template = ScheduleTemplate.fromFirestore(doc);
      
      // Additional client-side filtering
      if (bounds != null) {
        // Check if template is within viewport
        if (template.latitude != null && template.longitude != null) {
          if (!bounds.contains(template.latitude!, template.longitude!)) {
            continue; // Skip templates outside viewport
          }
        }
      } else if (userPosition != null) {
        // Check distance from user
        if (template.latitude != null && template.longitude != null) {
          final distance = Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            template.latitude!,
            template.longitude!,
          ) / 1000; // Convert to km
          
          if (distance > 50) {
            continue; // Skip templates more than 50km away
          }
        }
      }
      
      templates[doc.id] = template;
    }
    
    if (templates.isEmpty) {
      print('No templates after filtering');
      return [];
    }
    
    print('Found ${templates.length} templates in area');
    
    // Now get instances for these templates
    final allInstances = <ClassInstance>[];
    final templateIds = templates.keys.toList();
    
    // Batch fetch instances (Firestore whereIn limit is 10)
    for (int i = 0; i < templateIds.length; i += 10) {
      final batch = templateIds.skip(i).take(10).toList();
      
      final instancesSnapshot = await db
          .collection('class_instances')
          .where('templateId', whereIn: batch)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('scheduledDate')
          .limit(20) // Limit instances per batch
          .get();
      
      for (final doc in instancesSnapshot.docs) {
        allInstances.add(ClassInstance.fromFirestore(doc));
      }
    }
    
    print('Found ${allInstances.length} instances in next 2 weeks');
    
    // Join instances with templates
    final fullClasses = <FullClassData>[];
    for (final instance in allInstances) {
      final template = templates[instance.templateId];
      if (template != null) {
        fullClasses.add(FullClassData(
          instance: instance,
          template: template,
        ));
      }
    }
    
    // Sort by date
    fullClasses.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    
    // Limit total results
    if (fullClasses.length > 100) {
      return fullClasses.take(100).toList();
    }
    
    return fullClasses;
  } catch (e) {
    print('Error fetching map data: $e');
    // Fall back to empty list on error
    return [];
  }
});

// Helper function to update map bounds when camera moves
void updateMapBounds(WidgetRef ref, double neLat, double neLng, double swLat, double swLng) {
  ref.read(mapBoundsProvider.notifier).state = MapBounds(
    northEast_lat: neLat,
    northEast_lng: neLng,
    southWest_lat: swLat,
    southWest_lng: swLng,
  );
}

// Helper function to update user position
void updateUserPosition(WidgetRef ref, Position position) {
  ref.read(userPositionProvider.notifier).state = position;
}