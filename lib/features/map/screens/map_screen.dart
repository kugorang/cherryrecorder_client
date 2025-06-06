import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/models/place_detail.dart';
import '../../../core/models/place_summary.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/google_maps_service.dart';
import '../widgets/place_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final ApiClient _apiClient;
  final _logger = Logger();
  final _searchController = TextEditingController();

  GoogleMapController? _mapController;
  static const LatLng _defaultLocation = LatLng(37.5665, 126.9780); // 서울 중심
  Set<Marker> _markers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final googleMapsService = GoogleMapsService();
    final serverUrl = googleMapsService.getServerUrl();
    _logger.i('MapScreen - 서버 URL: $serverUrl');

    _apiClient = ApiClient(client: http.Client(), baseUrl: serverUrl);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  /// 장소 검색 API 호출 및 지도에 표시
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _markers = {};
    });

    try {
      final result = await _apiClient.post(
        ApiConstants.textSearchEndpoint,
        body: {'query': query, 'language': 'ko'},
      );

      if (result.containsKey('places') && result['places'] is List) {
        final places = result['places'] as List;
        if (places.isEmpty) {
          _showSnackBar('검색 결과가 없습니다.');
          return;
        }

        final markers = <Marker>{};
        LatLng? firstLocation;

        for (var i = 0; i < places.length; i++) {
          try {
            final place = PlaceSummary.fromJson(places[i]);
            markers.add(
              Marker(
                markerId: MarkerId(place.placeId),
                position: place.location,
                infoWindow: InfoWindow(
                  title: place.name,
                  snippet: place.vicinity,
                ),
                onTap: () {
                  _getPlaceDetails(place.placeId);
                },
              ),
            );

            if (i == 0) {
              firstLocation = place.location;
            }
          } catch (e) {
            _logger.e('장소 데이터 파싱 오류: ${places[i]}', error: e);
          }
        }

        setState(() {
          _markers = markers;
        });

        if (_mapController != null && firstLocation != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(firstLocation, 15),
          );
        }
      } else {
        _showSnackBar('장소를 찾을 수 없습니다.');
      }
    } catch (e) {
      final errorMessage = '장소 검색 중 오류 발생: $e';
      _logger.e(errorMessage, error: e);
      _showSnackBar(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 장소 상세 정보 API 호출 및 하단 시트에 표시
  Future<void> _getPlaceDetails(String placeId) async {
    // 상세 정보 로딩 시작 (UI 피드백)
    // 간단한 스낵바 또는 로딩 인디케이터를 여기서 보여줄 수 있음
    _showSnackBar('상세 정보를 불러오는 중...');

    try {
      final endpoint = '${ApiConstants.placeDetailsEndpoint}/$placeId';
      final result = await _apiClient.get(endpoint);

      final placeDetail = PlaceDetail.fromJson(result);

      // 하단 시트 표시
      _showPlaceDetailSheet(placeDetail);
    } catch (e) {
      final errorMessage = '상세 정보 조회 중 오류 발생: $e';
      _logger.e(errorMessage, error: e);
      _showSnackBar(errorMessage);
    }
  }

  /// 장소 상세 정보 하단 시트 표시
  void _showPlaceDetailSheet(PlaceDetail placeDetail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return PlaceDetailSheet(
              placeDetail: placeDetail,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 56,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: AppBar(
              title: const Text('장소 탐색'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '장소 또는 주소 검색',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  ),
                ),
                onSubmitted: (value) {
                  _searchPlaces(value);
                },
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
