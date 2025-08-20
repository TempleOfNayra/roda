import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:roda/core/utils/logger.dart';

class GooglePlacesService {
  static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY'; // TODO: Add your API key
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  static Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$query&key=$_apiKey&types=establishment|geocode',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List;
        
        return predictions.map((p) => PlaceSuggestion(
          description: p['description'],
          placeId: p['place_id'],
        )).toList();
      }
      
      return [];
    } catch (e) {
      Logger.debug('Error searching places: $e');
      return [];
    }
  }

  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&key=$_apiKey&fields=name,formatted_address,geometry',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        
        if (result != null) {
          return PlaceDetails(
            name: result['name'] ?? '',
            address: result['formatted_address'] ?? '',
            latitude: result['geometry']['location']['lat'],
            longitude: result['geometry']['location']['lng'],
            placeId: placeId,
          );
        }
      }
      
      return null;
    } catch (e) {
      Logger.debug('Error getting place details: $e');
      return null;
    }
  }
}

class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({
    required this.description,
    required this.placeId,
  });
}

class PlaceDetails {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String placeId;

  PlaceDetails({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });
}