import 'package:flutter/cupertino.dart';
import 'package:google_places_sdk/google_places_sdk.dart';
import 'package:roda/core/theme/roda_colors.dart';

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
  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  final FocusNode _focusNode = FocusNode();
  bool _programmaticChange = false;

  @override
  void initState() {
    super.initState();
    _initializePlaces();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializePlaces() async {
    await _places.initialize(googleApiKey);
    setState(() {
      _isInitialized = true;
    });
  }

  void _onTextChanged() {
    // Skip if this was a programmatic change (from selecting a suggestion)
    if (_programmaticChange) {
      _programmaticChange = false;
      return;
    }
    
    if (widget.controller.text.length > 2) {
      _searchPlaces(widget.controller.text);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || query.length < 2 || !_isInitialized) return;
    
    setState(() => _isSearching = true);
    
    try {
      final predictions = await _places.getAutoCompletePredictions(
        query,
        countryCodes: ['US'],
      );
      
      setState(() {
        _isSearching = false;
        _suggestions = predictions
            .where((prediction) => 
                prediction.fullName != null && 
                prediction.fullName!.trim().isNotEmpty &&
                prediction.primaryText != null &&
                prediction.primaryText!.trim().isNotEmpty)
            .map((prediction) {
          return PlaceSuggestion(
            placeId: prediction.placeId ?? '',
            description: prediction.fullName!.trim(),
            mainText: prediction.primaryText!.trim(),
            secondaryText: (prediction.secondaryText ?? '').trim(),
          );
        }).toList();
        
        // Debug: Log what we got
        print('DEBUG: Got ${_suggestions.length} suggestions');
        for (var s in _suggestions) {
          print('  - mainText: "${s.mainText}" (${s.mainText.length} chars)');
        }
        
        _showSuggestions = _suggestions.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _suggestions = [
          PlaceSuggestion(
            placeId: '',
            description: query,
            mainText: query,
            secondaryText: 'Use as typed',
          ),
        ];
        _showSuggestions = true;
      });
    }
  }

  Future<void> _getPlaceDetails(PlaceSuggestion suggestion) async {
    print('🔍 [GooglePlaces] Getting place details for: ${suggestion.description}');
    print('   - Place ID: ${suggestion.placeId}');
    
    if (suggestion.placeId.isEmpty) {
      print('⚠️ [GooglePlaces] No placeId - calling callback with null coordinates');
      widget.onLocationSelected?.call(suggestion.description, null, null);
      return;
    }
    
    try {
      print('📍 [GooglePlaces] Fetching place details from Google...');
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
      
      print('✅ [GooglePlaces] Got coordinates: lat=$lat, lng=$lng');
      
      widget.onLocationSelected?.call(
        suggestion.description,
        lat,
        lng,
      );
    } catch (e) {
      print('❌ [GooglePlaces] Error fetching place details: $e');
      widget.onLocationSelected?.call(suggestion.description, null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          controller: widget.controller,
          focusNode: _focusNode,
          placeholder: widget.hint,
          padding: const EdgeInsets.all(12),
          maxLines: 2,
          decoration: BoxDecoration(
            color: RodaColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(
              CupertinoIcons.location,
              color: RodaColors.systemGrey,
              size: 20,
            ),
          ),
          suffix: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CupertinoActivityIndicator(radius: 10),
                )
              : widget.controller.text.isNotEmpty
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.clear_circled_solid,
                        color: RodaColors.systemGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        _programmaticChange = true;
                        widget.controller.clear();
                        widget.onLocationSelected?.call('', null, null);
                        setState(() {
                          _showSuggestions = false;
                          _suggestions = [];
                        });
                      },
                    )
                  : null,
          onTap: () {
            // Only show suggestions if we have text to search
            if (widget.controller.text.length > 2) {
              setState(() => _showSuggestions = true);
              _searchPlaces(widget.controller.text);
            }
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: RodaColors.systemBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: RodaColors.separator,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: RodaColors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                print('DEBUG: Building item $index: "${suggestion.mainText}"');
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _programmaticChange = true;
                    widget.controller.text = suggestion.description;
                    _getPlaceDetails(suggestion);
                    setState(() {
                      _showSuggestions = false;
                      _suggestions = [];
                    });
                    _focusNode.unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: index != _suggestions.length - 1
                          ? const Border(
                              bottom: BorderSide(
                                color: RodaColors.separator,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          suggestion.placeId.isNotEmpty
                              ? CupertinoIcons.location_solid
                              : CupertinoIcons.pencil,
                          color: suggestion.placeId.isNotEmpty
                              ? RodaColors.success
                              : RodaColors.systemGrey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.mainText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: RodaColors.textPrimary,
                                ),
                              ),
                              if (suggestion.secondaryText.isNotEmpty)
                                Text(
                                  suggestion.secondaryText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: RodaColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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