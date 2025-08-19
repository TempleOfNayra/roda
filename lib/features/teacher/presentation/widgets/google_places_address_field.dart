import 'package:flutter/material.dart';
import 'package:google_places_sdk/google_places_sdk.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:roda/core/utils/logger.dart';

const String googleApiKey = 'AIzaSyD0RWCliozfGpgzQX-cJDFFHV224-bNwGY';

class GooglePlacesAddressField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Function(String address, double? lat, double? lng)? onLocationSelected;
  final String? Function(String?)? validator;

  const GooglePlacesAddressField({
    super.key,
    required this.controller,
    this.label = 'Location',
    this.hint = 'Search for a place',
    this.onLocationSelected,
    this.validator,
  });

  @override
  State<GooglePlacesAddressField> createState() => _GooglePlacesAddressFieldState();
}

class _GooglePlacesAddressFieldState extends State<GooglePlacesAddressField> {
  final GooglePlaces _places = GooglePlaces();
  bool _isSearching = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlaces();
  }

  Future<void> _initializePlaces() async {
    await _places.initialize(googleApiKey);
    setState(() {
      _isInitialized = true;
    });
  }

  Future<List<PlaceSuggestion>> _searchPlaces(String query) async {
    if (query.isEmpty || query.length < 2 || !_isInitialized) return [];
    
    setState(() => _isSearching = true);
    
    try {
      Logger.debug('🔍 Searching Google Places for: "$query"');
      
      // Search for places
      final predictions = await _places.getAutoCompletePredictions(
        query,
        countryCodes: ['US'], // Limit to US for now
      );
      
      Logger.debug('📍 Found ${predictions.length} results');
      
      setState(() => _isSearching = false);
      
      return predictions.map((prediction) {
        return PlaceSuggestion(
          placeId: prediction.placeId ?? '',
          description: prediction.fullName ?? '',
          mainText: prediction.primaryText ?? '',
          secondaryText: prediction.secondaryText ?? '',
        );
      }).toList();
    } catch (e) {
      Logger.debug('❌ Google Places error: $e');
      setState(() => _isSearching = false);
      
      // Return the query itself as an option
      return [
        PlaceSuggestion(
          placeId: '',
          description: query,
          mainText: query,
          secondaryText: 'Use as typed',
        ),
      ];
    }
  }

  Future<void> _getPlaceDetails(PlaceSuggestion suggestion) async {
    if (suggestion.placeId.isEmpty) {
      // User typed address without selecting from Google
      widget.onLocationSelected?.call(suggestion.description, null, null);
      return;
    }
    
    try {
      Logger.debug('Getting details for place: ${suggestion.placeId}');
      
      final place = await _places.fetchPlaceDetails(
        suggestion.placeId,
        placeFields: [
          PlaceField.latLng,
          PlaceField.name,
          PlaceField.address,
        ],
      );
      
      final lat = place.latLng?.lat;
      final lng = place.latLng?.lng;
      
      Logger.debug('Got coordinates: $lat, $lng');
      
      widget.onLocationSelected?.call(
        suggestion.description,
        lat,
        lng,
      );
    } catch (e) {
      Logger.debug('Error getting place details: $e');
      widget.onLocationSelected?.call(suggestion.description, null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadFormField<PlaceSuggestion>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: _isSearching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onLocationSelected?.call('', null, null);
                      },
                    )
                  : null,
        ),
        maxLines: 2,
      ),
      suggestionsCallback: (pattern) async {
        return _searchPlaces(pattern);
      },
      itemBuilder: (context, PlaceSuggestion suggestion) {
        return ListTile(
          leading: Icon(
            suggestion.placeId.isNotEmpty ? Icons.place : Icons.edit_location,
            color: suggestion.placeId.isNotEmpty ? Colors.green : Colors.grey,
          ),
          title: Text(suggestion.mainText),
          subtitle: suggestion.secondaryText.isNotEmpty
              ? Text(
                  suggestion.secondaryText,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        );
      },
      onSuggestionSelected: (PlaceSuggestion suggestion) {
        widget.controller.text = suggestion.description;
        _getPlaceDetails(suggestion);
      },
      validator: widget.validator,
      noItemsFoundBuilder: (context) => ListTile(
        leading: const Icon(Icons.place, color: Colors.blue),
        title: Text('Use: "${widget.controller.text}"'),
        subtitle: const Text('Tap to use this address', style: TextStyle(fontSize: 12)),
        onTap: () {
          Navigator.of(context).pop();
          widget.onLocationSelected?.call(widget.controller.text, null, null);
        },
      ),
    );
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}