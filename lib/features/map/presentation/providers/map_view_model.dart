import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/models/place_summary.dart';
import '../../../../core/services/google_maps_service.dart';

/// 지도 화면의 뷰모델
///
/// 주변 장소 데이터 조회, 지도 마커 관리, 검색 기능 등을 담당
class MapViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  late final ApiClient _apiClient;

  // --- 컨트롤러 ---
  GoogleMapController? _mapController;

  // --- 상태 변수 ---
  bool _isLoading = false;
  String? _errorMessage;
  final Set<Marker> _markers = {};
  List<PlaceSummary> _places = []; // 장소 목록 단일화
  String? _selectedPlaceId;
  LatLng _currentMapCenter = const LatLng(37.4979, 127.0276); // 기본 위치 (강남역)

  // --- 타이머 및 컨트롤러 ---
  Timer? _searchDebounce;
  Timer? _mapMoveDebounce;
  final ScrollController scrollController = ScrollController();

  // --- Public Getters ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<Marker> get markers => _markers;
  List<PlaceSummary> get placesToShow => _places; // 항상 _places를 사용
  String? get selectedPlaceId => _selectedPlaceId;
  LatLng get currentMapCenter => _currentMapCenter;
  bool get mapControllerReady => _mapController != null;

  // --- 지도 컨트롤러 설정 ---
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    _logger.i('🗺️ GoogleMapController 설정 완료');
  }

  /// 생성자: 네트워크 클라이언트 초기화
  MapViewModel() {
    final googleMapsService = GoogleMapsService();
    final serverUrl = googleMapsService.getServerUrl();
    _logger.i('MapViewModel API Client 초기화 - URL: $serverUrl');
    final httpClient = http.Client();
    _apiClient = ApiClient(client: httpClient, baseUrl: serverUrl);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapMoveDebounce?.cancel();
    scrollController.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  /// 초기 장소 로드 (앱 시작 또는 화면 진입 시 호출)
  Future<void> fetchInitialPlaces() async {
    _logger.d(
        '📍 fetchInitialPlaces 호출됨: 중심 위치 ${_currentMapCenter.latitude}, ${_currentMapCenter.longitude}');
    await fetchNearbyPlaces(_currentMapCenter);
  }

  /// 지도 이동이 멈추면 호출되는 디바운스 함수
  void onCameraIdle(LatLng center) {
    _currentMapCenter = center;
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 800), () {
      _logger.i('🗺️ 지도 이동 멈춤. 중심: $center. 주변 장소 다시 검색.');
      fetchNearbyPlaces(center);
    });
  }

  /// 주변 장소 데이터 가져오기
  Future<void> fetchNearbyPlaces(LatLng center) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _logger.i('🔍 주변 장소 요청 시작: ${center.latitude}, ${center.longitude}');
      final response = await _apiClient.post(
        ApiConstants.nearbySearchEndpoint,
        body: {
          'latitude': center.latitude,
          'longitude': center.longitude,
          'radius': 1500.0, // 1.5km 반경
        },
      ).timeout(const Duration(seconds: 15));

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 주변 장소 데이터 ${placesData.length}개 발견');

        if (placesData.isEmpty) {
          _places = [];
          _errorMessage = '주변 장소 정보를 찾을 수 없습니다.';
        } else {
          _places =
              placesData.map((data) => PlaceSummary.fromJson(data)).toList();
        }
        _createMarkers();
      } else {
        _logger.w('⚠️ 주변 장소 데이터 없음 또는 잘못된 형식: $response');
        _places = [];
        _errorMessage = '주변 장소 정보를 가져오는데 실패했습니다.';
      }
    } catch (e) {
      _logger.e('❌ 주변 장소 로드 오류: $e');
      _places = [];
      _errorMessage = e is TimeoutException ? '서버 응답 시간 초과' : '서버 연결 오류 발생';
    } finally {
      _setLoading(false);
    }
  }

  /// 디바운스를 적용하여 장소 검색을 수행
  void performSearchDebounced(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _logger.d('🔍 디바운스 후 검색 실행: "$query"');
      searchPlaces(query, _currentMapCenter);
    });
  }

  /// 텍스트 기반 장소 검색
  Future<void> searchPlaces(String query, LatLng center) async {
    if (query.isEmpty) {
      // 검색어 비면 현재 위치 기반으로 다시 검색
      fetchNearbyPlaces(center);
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      _logger.i(
          '🔍 장소 검색 요청 시작: "$query" at ${center.latitude}, ${center.longitude}');
      final response = await _apiClient.post(
        ApiConstants.textSearchEndpoint,
        body: {
          'query': query,
          'latitude': center.latitude,
          'longitude': center.longitude,
          'radius': 5000.0,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 검색된 장소 데이터 ${placesData.length}개 발견');
        _places =
            placesData.map((data) => PlaceSummary.fromJson(data)).toList();
        _createMarkers();
      } else {
        _logger.w('⚠️ 검색 결과 없음: $response');
        _places = [];
        _errorMessage = '검색된 장소가 없습니다.';
      }
    } catch (e) {
      _logger.e('❌ 장소 검색 오류: $e');
      _places = [];
      _errorMessage = e is TimeoutException ? '서버 응답 시간 초과' : '검색 중 오류 발생';
    } finally {
      _setLoading(false);
    }
  }

  /// 로딩 상태 설정 및 UI 업데이트
  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  /// 지도 마커 생성 및 업데이트
  void _createMarkers() {
    _markers.clear();
    for (final place in _places) {
      final isSelected = place.placeId == _selectedPlaceId;
      _markers.add(
        Marker(
          markerId: MarkerId(place.placeId),
          position: place.location,
          icon: isSelected
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow)
              : BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.vicinity,
          ),
          onTap: () {
            _logger.d('마커 탭: ${place.name}');
            onPlaceSelected(place.placeId);
          },
        ),
      );
    }
    // 마커가 업데이트되었으므로 UI 갱신
    notifyListeners();
  }

  /// 특정 장소를 지도 중앙으로 이동
  Future<void> moveCameraToPlace(String placeId) async {
    final place = _places.firstWhere((p) => p.placeId == placeId,
        orElse: () => throw Exception('Place not found'));
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(place.location),
    );
  }

  /// 장소 선택 시 호출
  void onPlaceSelected(String placeId) {
    _logger.i('🎯 장소 선택됨: $placeId');
    if (_selectedPlaceId == placeId) {
      // 이미 선택된 장소를 다시 탭한 경우
      _logger.d('이미 선택된 장소입니다.');
      return;
    }

    _selectedPlaceId = placeId;
    _createMarkers(); // 선택된 마커 색상 변경을 위해 마커 재생성
    moveCameraToPlace(placeId);
    // notifyListeners()는 _createMarkers()에서 호출됨
  }

  /// 선택 해제
  void clearSelection() {
    _selectedPlaceId = null;
    _createMarkers();
    // notifyListeners()는 _createMarkers()에서 호출됨
  }
}
