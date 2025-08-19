import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_places_sdk/google_places_sdk.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/core/theme/form_theme.dart';

const String googleApiKey = 'AIzaSyD0RWCliozfGpgzQX-cJDFFHV224-bNwGY';

class StyledGooglePlacesField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String address, double? lat, double? lng)? onLocationSelected;
  final bool showValidationError;

  const StyledGooglePlacesField({
    super.key,
    required this.controller,
    this.onLocationSelected,
    this.showValidationError = false,
  });

  @override
  State<StyledGooglePlacesField> createState() => _StyledGooglePlacesFieldState();
}

class _StyledGooglePlacesFieldState extends State<StyledGooglePlacesField> {
  final GooglePlaces _places = GooglePlaces();
  bool _isSearching = false;
  bool _isInitialized = false;
  bool _hasValidLocation = false;

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
      setState(() => _hasValidLocation = true);
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
      
      Logger.debug('📍 Place details: ${place.address} at ($lat, $lng)');
      
      setState(() => _hasValidLocation = true);
      widget.onLocationSelected?.call(
        place.address ?? suggestion.description,
        lat,
        lng,
      );
    } catch (e) {
      Logger.debug('Error getting place details: $e');
      setState(() => _hasValidLocation = true);
      widget.onLocationSelected?.call(suggestion.description, null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadFormField<PlaceSuggestion>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: widget.controller,
        style: FormTheme.inputTextStyle,
        decoration: InputDecoration(
          hintText: 'Search for a place',
          hintStyle: FormTheme.placeholderStyle,
          filled: true,
          fillColor: CupertinoColors.tertiarySystemFill,
          contentPadding: FormTheme.fieldPadding,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.showValidationError && !_hasValidLocation
                  ? Colors.red
                  : Colors.transparent,
              width: widget.showValidationError && !_hasValidLocation ? 1 : 0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.showValidationError && !_hasValidLocation
                  ? Colors.red
                  : Colors.transparent,
              width: widget.showValidationError && !_hasValidLocation ? 1 : 0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.showValidationError && !_hasValidLocation
                  ? Colors.red
                  : CupertinoColors.activeBlue.withOpacity(0.5),
              width: 1,
            ),
          ),
          prefixIcon: Icon(
            CupertinoIcons.location,
            color: FormTheme.inputPlaceholderColor,
            size: 20,
          ),
          suffixIcon: _isSearching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CupertinoActivityIndicator(),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        CupertinoIcons.clear_circled_solid,
                        color: FormTheme.inputPlaceholderColor,
                        size: 18,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() => _hasValidLocation = false);
                        widget.onLocationSelected?.call('', null, null);
                      },
                    )
                  : null,
        ),
        onChanged: (value) {
          // Reset valid location when user types
          if (_hasValidLocation) {
            setState(() => _hasValidLocation = false);
          }
        },
      ),
      suggestionsCallback: (pattern) async {
        return _searchPlaces(pattern);
      },
      suggestionsBoxDecoration: SuggestionsBoxDecoration(
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        color: Theme.of(context).scaffoldBackgroundColor,
        constraints: const BoxConstraints(
          minHeight: 50,
          maxHeight: 250, // Fixed max height to prevent resizing
        ),
      ),
      itemBuilder: (context, PlaceSuggestion suggestion) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.systemGrey5,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                suggestion.placeId.isNotEmpty 
                    ? CupertinoIcons.location_solid 
                    : CupertinoIcons.location,
                color: suggestion.placeId.isNotEmpty 
                    ? CupertinoColors.activeBlue 
                    : FormTheme.inputPlaceholderColor,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      suggestion.mainText,
                      style: FormTheme.inputTextStyle.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (suggestion.secondaryText.isNotEmpty)
                      Text(
                        suggestion.secondaryText,
                        style: FormTheme.placeholderStyle.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      onSuggestionSelected: (PlaceSuggestion suggestion) {
        widget.controller.text = suggestion.description;
        _getPlaceDetails(suggestion);
      },
      noItemsFoundBuilder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No places found',
          style: FormTheme.placeholderStyle,
        ),
      ),
      hideOnLoading: true,
      hideOnEmpty: true,
      animationDuration: const Duration(milliseconds: 200),
      direction: AxisDirection.down,
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