import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geocoding/geocoding.dart';

class AddressSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Function(String address, double? lat, double? lng)? onLocationSelected;
  final String? Function(String?)? validator;

  const AddressSearchField({
    super.key,
    required this.controller,
    this.label = 'Location',
    this.hint = 'Enter address',
    this.onLocationSelected,
    this.validator,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final _debouncer = Debouncer(milliseconds: 500);
  bool _isSearching = false;

  Future<List<LocationSuggestion>> _searchAddresses(String query) async {
    if (query.length < 3) return [];
    
    setState(() => _isSearching = true);
    
    try {
      // Try to geocode the address, but don't fail if it doesn't work
      List<Location>? locations;
      try {
        print('🔍 Searching for: "$query"');
        locations = await locationFromAddress(query).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('⏱️ Geocoding timeout for: $query');
            return [];
          },
        );
        print('📍 Geocoding returned ${locations.length} results');
        if (locations.isNotEmpty) {
          print('   First result: Lat ${locations.first.latitude}, Lng ${locations.first.longitude}');
        }
      } catch (e) {
        // Geocoding failed, that's ok - user can still use the address
        print('❌ Geocoding failed for "$query": $e');
        locations = [];
      }
      
      setState(() => _isSearching = false);
      
      final suggestions = <LocationSuggestion>[];
      
      // Always add the query itself as the first suggestion
      suggestions.add(LocationSuggestion(
        address: query,
        latitude: locations.isNotEmpty == true ? locations.first.latitude : null,
        longitude: locations.isNotEmpty == true ? locations.first.longitude : null,
      ));
      
      // Add geocoded results if any
      if (locations.isNotEmpty) {
        try {
          final placemarks = await placemarkFromCoordinates(
            locations.first.latitude,
            locations.first.longitude,
          );
          
          for (final placemark in placemarks.take(3)) {
            final parts = <String>[];
            if (placemark.street != null && placemark.street!.isNotEmpty) {
              parts.add(placemark.street!);
            }
            if (placemark.locality != null && placemark.locality!.isNotEmpty) {
              parts.add(placemark.locality!);
            }
            if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
              parts.add(placemark.administrativeArea!);
            }
            if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
              parts.add(placemark.postalCode!);
            }
            
            final address = parts.join(', ');
            if (address != query && address.isNotEmpty) {
              suggestions.add(LocationSuggestion(
                address: address,
                latitude: locations.first.latitude,
                longitude: locations.first.longitude,
              ));
            }
          }
        } catch (e) {
          // Ignore placemark errors
        }
      }
      
      // Add common suggestions that match
      suggestions.addAll(_getCommonSuggestions(query));
      
      return suggestions;
    } catch (e) {
      print('Error searching addresses: $e');
      setState(() => _isSearching = false);
      
      // Always return the query itself as an option
      return [
        LocationSuggestion(address: query),
        ..._getCommonSuggestions(query),
      ];
    }
  }

  List<LocationSuggestion> _getCommonSuggestions(String query) {
    final suggestions = [
      'Community Center',
      'Local Park',
      'Beach',
      'Gym',
      'School',
      'Studio',
      'Recreation Center',
      'YMCA',
      'Sports Complex',
      'University Campus',
    ];
    
    return suggestions
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .map((s) => LocationSuggestion(address: s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadFormField<LocationSuggestion>(
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
        onChanged: (value) {
          // When text changes, clear coordinates if it doesn't match a geocoded address
          // This ensures we don't keep old coordinates for a new address
        },
        onSubmitted: (value) async {
          // Try to geocode when submitted
          if (value.isNotEmpty) {
            print('Attempting to geocode address: $value');
            try {
              final locations = await locationFromAddress(value).timeout(
                const Duration(seconds: 3),
                onTimeout: () {
                  print('Geocoding timeout for: $value');
                  return [];
                },
              );
              if (locations.isNotEmpty) {
                print('Geocoding successful! Lat: ${locations.first.latitude}, Lng: ${locations.first.longitude}');
                widget.onLocationSelected?.call(
                  value, 
                  locations.first.latitude, 
                  locations.first.longitude
                );
              } else {
                print('Geocoding returned no results for: $value');
                widget.onLocationSelected?.call(value, null, null);
              }
            } catch (e) {
              print('Geocoding error for "$value": $e');
              widget.onLocationSelected?.call(value, null, null);
            }
          }
        },
        onEditingComplete: () {
          // Let onSubmitted handle it
        },
      ),
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) return [];
        return _debouncer.run(() => _searchAddresses(pattern));
      },
      itemBuilder: (context, LocationSuggestion suggestion) {
        return ListTile(
          leading: Icon(
            suggestion.hasCoordinates ? Icons.location_on : Icons.place,
            color: suggestion.hasCoordinates ? Colors.green : Colors.grey,
          ),
          title: Text(suggestion.address),
          subtitle: suggestion.hasCoordinates
              ? const Text('Geocoded', style: TextStyle(color: Colors.green, fontSize: 12))
              : const Text('Use as typed', style: TextStyle(color: Colors.grey, fontSize: 12)),
        );
      },
      onSuggestionSelected: (LocationSuggestion suggestion) async {
        widget.controller.text = suggestion.address;
        
        // If suggestion has coordinates, use them
        if (suggestion.hasCoordinates) {
          widget.onLocationSelected?.call(
            suggestion.address,
            suggestion.latitude,
            suggestion.longitude,
          );
        } else {
          // Try to geocode the address
          print('Selected suggestion without coordinates, attempting to geocode: ${suggestion.address}');
          try {
            final locations = await locationFromAddress(suggestion.address).timeout(
              const Duration(seconds: 3),
              onTimeout: () => [],
            );
            if (locations.isNotEmpty) {
              print('Geocoding successful! Lat: ${locations.first.latitude}, Lng: ${locations.first.longitude}');
              widget.onLocationSelected?.call(
                suggestion.address,
                locations.first.latitude,
                locations.first.longitude,
              );
            } else {
              print('No geocoding results, using address without coordinates');
              widget.onLocationSelected?.call(suggestion.address, null, null);
            }
          } catch (e) {
            print('Geocoding error: $e');
            widget.onLocationSelected?.call(suggestion.address, null, null);
          }
        }
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
      hideOnEmpty: false,
      hideOnLoading: false,
    );
  }
}

class LocationSuggestion {
  final String address;
  final double? latitude;
  final double? longitude;

  LocationSuggestion({
    required this.address,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  Future<T> run<T>(Future<T> Function() action) async {
    _timer?.cancel();
    final completer = Completer<T>();
    _timer = Timer(Duration(milliseconds: milliseconds), () async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }
}