import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/models/place_summary.dart';
import '../../../../core/services/google_maps_service.dart'; // GoogleMapsService 임포트

// Place 모델 정의 (MapScreen과 동일하게 사용)
class Place {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final bool acceptsCreditCard;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.acceptsCreditCard,
  });

  factory Place.fromPlaceSummary(PlaceSummary summary) {
    return Place(
      id: summary.placeId,
      name: summary.name,
      address: summary.vicinity ?? '주소 정보 없음',
      location: summary.location,
      acceptsCreditCard: true, // 기본값
    );
  }
}

class MapViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  late final ApiClient _apiClient;

  // --- 상태 변수 ---
  bool _isLoading = false;
  String? _errorMessage;
  final Set<Marker> _markers = {};
  List<Place> _nearbyPlaces = []; // 초기 주변 장소
  List<Place> _searchResults = []; // 검색 결과 (또는 지도 이동 결과)
  String? _selectedPlaceId;
  LatLng _currentMapCenter = const LatLng(37.4979, 127.0276); // 기본 위치 (강남역)

  // --- 타이머 및 컨트롤러 ---
  Timer? _searchDebounce;
  Timer? _mapMoveDebounce;
  // ScrollController는 UI에 두는 것이 적합할 수 있으나, 스크롤 로직을 위해 ViewModel에서 관리
  final ScrollController scrollController = ScrollController();

  // --- Public Getters ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<Marker> get markers => _markers;
  // 검색 결과가 있으면 검색 결과를, 없으면 주변 장소를 보여줌
  List<Place> get placesToShow =>
      _searchResults.isNotEmpty ? _searchResults : _nearbyPlaces;
  String? get selectedPlaceId => _selectedPlaceId;
  LatLng get currentMapCenter => _currentMapCenter; // 외부에서 읽을 필요는 없을 수 있음

  MapViewModel() {
    // GoogleMapsService를 직접 가져와서 플랫폼에 맞는 서버 URL 사용
    final googleMapsService = GoogleMapsService();
    final serverUrl = googleMapsService.getServerUrl(); // 자동으로 플랫폼 감지
    _logger.i('MapViewModel API Client 초기화 URL: $serverUrl');
    _apiClient = ApiClient(client: http.Client(), baseUrl: serverUrl);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapMoveDebounce?.cancel();
    scrollController.dispose();
    _apiClient.dispose(); // ApiClient 내부의 http.Client 해제
    super.dispose();
  }

  // --- Public Methods (기존 MapScreen의 로직 이동) ---

  /// 초기 장소 로드 (앱 시작 또는 화면 진입 시 호출)
  Future<void> fetchInitialPlaces() async {
    await _fetchNearbyPlaces(_currentMapCenter, isInitialLoad: true);
  }

  /// 주변 장소 가져오기
  Future<void> _fetchNearbyPlaces(
    LatLng center, {
    bool isInitialLoad = false,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners(); // 로딩 시작 알림

    try {
      _logger.i('🔍 주변 장소 요청 시작: ${center.latitude}, ${center.longitude}');
      final response = await _apiClient
          .post(
            ApiConstants.nearbySearchEndpoint,
            body: {
              'latitude': center.latitude,
              'longitude': center.longitude,
              'radius': 1500.0,
            },
          )
          .timeout(const Duration(seconds: 10));

      _logger.i('✅ 주변 장소 응답 받음');

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 주변 장소 데이터 ${placesData.length}개 발견');
        final placeSummaries =
            placesData.map((data) => PlaceSummary.fromJson(data)).toList();
        final places =
            placeSummaries.map((s) => Place.fromPlaceSummary(s)).toList();

        if (isInitialLoad) {
          _nearbyPlaces = places; // 초기 로드 시 nearby 저장
        }
        _searchResults = places; // 항상 최신 결과는 searchResults에 반영
        _createMarkers();
      } else {
        _logger.w('⚠️ 주변 장소 데이터 없음: $response');
        _searchResults = [];
        if (isInitialLoad) _nearbyPlaces = [];
        _createMarkers();
        _errorMessage = '주변 장소 정보를 찾을 수 없습니다.';
      }
    } catch (e) {
      _logger.e('❌ 주변 장소 로드 오류: $e');
      _searchResults = [];
      if (isInitialLoad) _nearbyPlaces = [];
      _createMarkers();
      // 사용자에게 보여줄 오류 메시지 설정 (timeout 등 포함)
      _errorMessage = e is TimeoutException ? '서버 응답 시간 초과' : '서버 연결 오류 발생';
    } finally {
      _setLoading(false);
      // notifyListeners(); // 로딩 종료 및 결과 반영
    }
  }

  /// 텍스트 기반 장소 검색
  Future<void> searchPlaces(String query, LatLng center) async {
    if (query.isEmpty) {
      // 검색어 비면 초기 주변 장소 목록 보여주기 (또는 현재 지도 중심 주변)
      _searchResults = _nearbyPlaces;
      _selectedPlaceId = null; // 선택 해제
      _createMarkers();
      notifyListeners();
      return;
    }

    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      _logger.i(
        '🔍 장소 검색 요청 시작: "$query" at ${center.latitude}, ${center.longitude}',
      );
      final response = await _apiClient
          .post(
            ApiConstants.textSearchEndpoint,
            body: {
              'query': query,
              'latitude': center.latitude,
              'longitude': center.longitude,
              'radius': 5000.0,
            },
          )
          .timeout(const Duration(seconds: 10));

      _logger.i('✅ 장소 검색 응답 받음');

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 검색된 장소 데이터 ${placesData.length}개 발견');
        final placeSummaries =
            placesData.map((data) => PlaceSummary.fromJson(data)).toList();
        _searchResults =
            placeSummaries.map((s) => Place.fromPlaceSummary(s)).toList();
        _createMarkers();
      } else {
        _logger.w('⚠️ 검색 결과 없음: $response');
        _searchResults = [];
        _createMarkers();
        _errorMessage = '"$query"에 대한 검색 결과가 없습니다.';
      }
    } catch (e) {
      _logger.e('❌ 장소 검색 오류: $e');
      _searchResults = [];
      _createMarkers();
      _errorMessage = e is TimeoutException ? '서버 응답 시간 초과' : '서버 연결 오류 발생';
    } finally {
      _setLoading(false);
      // notifyListeners(); // 로딩 종료 및 결과 반영
    }
  }

  /// 마커 생성 및 상태 업데이트
  void _createMarkers() {
    _markers.clear();
    final places = placesToShow; // getter 사용

    for (final place in places) {
      _markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: place.location,
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
          onTap: () => _onMarkerTapped(place.id),
        ),
      );
    }
    // notifyListeners(); // 마커 변경 알림 -> 로딩 종료 시 한 번만 호출하도록 변경
  }

  /// 마커 탭 이벤트 처리
  void _onMarkerTapped(String placeId) {
    _selectedPlaceId = placeId;
    notifyListeners(); // 선택 변경 알림
    // 스크롤은 UI 레이어에서 처리하거나, 콜백을 통해 요청할 수 있음
    _scrollToSelectedPlace(); // ViewModel에서 직접 처리 시도
  }

  /// 선택된 장소로 스크롤
  void _scrollToSelectedPlace() {
    if (_selectedPlaceId != null) {
      final index = placesToShow.indexWhere((p) => p.id == _selectedPlaceId);
      if (index != -1 && scrollController.hasClients) {
        scrollController.animateTo(
          index * 100.0, // 예상 높이, 실제 UI에 맞게 조정 필요
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// 검색어 입력 디바운스 처리
  void performSearchDebounced(String query, LatLng currentCenter) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(seconds: 1), () {
      _logger.i('⏳ 검색 디바운스 완료: "$query"');
      searchPlaces(query, currentCenter);
    });
  }

  /// 지도 카메라 이동 멈춤 시 호출될 메서드 (UI에서 호출)
  void onCameraIdle(String currentSearchQuery, LatLng mapCenter) {
    _currentMapCenter = mapCenter; // 현재 중심 업데이트
    if (_mapMoveDebounce?.isActive ?? false) _mapMoveDebounce!.cancel();
    _mapMoveDebounce = Timer(const Duration(seconds: 1), () {
      if (currentSearchQuery.isEmpty) {
        _logger.i('🗺️ 지도 이동 멈춤, 중심 기준 주변 장소 재검색');
        _fetchNearbyPlaces(_currentMapCenter); // 주변 장소 재검색
      } else {
        _logger.i('🗺️ 지도 이동 멈춤, 중심 기준 [$currentSearchQuery] 재검색');
        searchPlaces(currentSearchQuery, _currentMapCenter); // 현재 검색어 유지하며 재검색
      }
    });
  }

  /// 지도 카메라 이동 중 호출될 메서드 (UI에서 호출)
  void onCameraMove(LatLng target) {
    _currentMapCenter = target;
    // 이동 중에는 notifyListeners() 호출하지 않음 (성능 저하 방지)
  }

  /// 로딩 상태 설정 및 UI 업데이트 알림
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
