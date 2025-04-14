import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/models/place_summary.dart';

class MapViewModel extends ChangeNotifier {
  Position? _currentPosition;
  List<PlaceSummary> _nearbyPlaces = [];
  List<PlaceSummary> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  final Set<Marker> _markers = {};
  PlaceSummary? _selectedPlace;

  Position? get currentPosition => _currentPosition;
  List<PlaceSummary> get nearbyPlaces => _nearbyPlaces;
  List<PlaceSummary> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<Marker> get markers => _markers;
  PlaceSummary? get selectedPlace => _selectedPlace;

  Future<void> getCurrentLocation() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await fetchNearbyPlaces();
    } catch (e) {
      _error = '위치를 가져오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNearbyPlaces() async {
    if (_currentPosition == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final uri = Uri.parse(ApiConstants.nearbySearchEndpoint);
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiConstants.googleMapsApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location',
      };

      final body = jsonEncode({
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
            },
            'radius': 1500.0,
          },
        },
      });

      final response = await http.post(uri, headers: headers, body: body);

      // API 응답 로깅 (디버깅용)
      print("Places API Response Status: ${response.statusCode}");
      print("Places API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List places = data['places'] ?? [];
        _nearbyPlaces =
            places.map((place) => PlaceSummary.fromJson(place)).toList();
        _updateMarkers();
      } else {
        _error = '주변 장소를 가져오는데 실패했습니다: ${response.statusCode}';
      }
    } catch (e) {
      _error = '주변 장소를 가져오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final uri = Uri.parse(ApiConstants.textSearchEndpoint);
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiConstants.googleMapsApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location',
      };

      final body = jsonEncode({
        'textQuery': query,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': _currentPosition?.latitude ?? 37.5665,
              'longitude': _currentPosition?.longitude ?? 126.9780,
            },
            'radius': 50000.0,
          },
        },
      });

      final response = await http.post(uri, headers: headers, body: body);

      // API 응답 로깅 (디버깅용)
      print("Places API Response Status: ${response.statusCode}");
      print("Places API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List placesData = data['places'] ?? [];
        List<PlaceSummary> places =
            placesData.map((place) => PlaceSummary.fromJson(place)).toList();

        // 현재 위치 기반 거리순 정렬
        if (_currentPosition != null) {
          places.sort((a, b) {
            final distanceA = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              a.location.latitude,
              a.location.longitude,
            );
            final distanceB = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              b.location.latitude,
              b.location.longitude,
            );
            return distanceA.compareTo(distanceB);
          });
        }

        _searchResults = places;
        _updateMarkers();
      } else {
        _error = '검색 결과를 가져오는데 실패했습니다: ${response.statusCode}';
      }
    } catch (e) {
      _error = '장소 검색 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearchResults() {
    _searchResults = [];
    _selectedPlace = null;
    _updateMarkers();
    notifyListeners();
  }

  void _updateMarkers() {
    _markers.clear();
    final places = _searchResults.isNotEmpty ? _searchResults : _nearbyPlaces;

    for (final place in places) {
      _markers.add(
        Marker(
          markerId: MarkerId(place.placeId),
          position: place.location,
          infoWindow: InfoWindow(title: place.name, snippet: place.vicinity),
          onTap: () {
            _selectedPlace = place;
            notifyListeners();
          },
        ),
      );
    }
    notifyListeners();
  }
}
