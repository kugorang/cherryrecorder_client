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

/// 지도에 표시되는 장소 정보 모델
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

/// 지도 화면의 뷰모델
///
/// 주변 장소 데이터 조회, 지도 마커 관리, 검색 기능 등을 담당
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
  final ScrollController scrollController = ScrollController();

  // --- Public Getters ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<Marker> get markers => _markers;
  // 검색 결과가 있으면 검색 결과를, 없으면 주변 장소를 보여줌
  List<Place> get placesToShow =>
      _searchResults.isNotEmpty ? _searchResults : _nearbyPlaces;
  String? get selectedPlaceId => _selectedPlaceId;
  LatLng get currentMapCenter => _currentMapCenter;

  /// 생성자: 네트워크 클라이언트 초기화
  MapViewModel() {
    // GoogleMapsService를 통해 플랫폼에 맞는 서버 URL 사용
    final googleMapsService = GoogleMapsService();
    final serverUrl = googleMapsService.getServerUrl();

    _logger.i('MapViewModel API Client 초기화 - URL: $serverUrl');

    final httpClient = http.Client();
    _apiClient = ApiClient(client: httpClient, baseUrl: serverUrl);

    _logger.d('MapViewModel 생성 완료');
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
      '📍 fetchInitialPlaces 호출됨: 중심 위치 ${_currentMapCenter.latitude}, ${_currentMapCenter.longitude}',
    );
    await _fetchNearbyPlaces(_currentMapCenter, isInitialLoad: true);
  }

  /// 주변 장소 데이터 가져오기
  ///
  /// [center] 검색 중심 좌표
  /// [isInitialLoad] 초기 로드 여부 (true면 _nearbyPlaces에 저장)
  Future<void> _fetchNearbyPlaces(
    LatLng center, {
    bool isInitialLoad = false,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

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

      _logger.i(
        '✅ 주변 장소 응답 받음: ${response.toString().substring(0, min(100, response.toString().length))}...',
      );

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 주변 장소 데이터 ${placesData.length}개 발견');

        if (placesData.isEmpty) {
          _logger.w('⚠️ 서버에서 장소 데이터를 반환했지만 빈 목록임');
          _searchResults = [];
          if (isInitialLoad) _nearbyPlaces = [];
          _createMarkers();
          _errorMessage = '주변 장소 정보를 찾을 수 없습니다.';
          return;
        }

        // 첫 번째 장소 데이터 로그로 출력
        if (placesData.isNotEmpty) {
          _logger.d('🔍 첫 번째 장소 데이터 샘플: ${placesData[0]}');
        }

        final placeSummaries =
            placesData.map((data) => PlaceSummary.fromJson(data)).toList();
        final places =
            placeSummaries.map((s) => Place.fromPlaceSummary(s)).toList();

        _logger.d('🔄 PlaceSummary 변환 결과: ${placeSummaries.length}개');
        _logger.d('🔄 Place 변환 결과: ${places.length}개');

        // 첫 번째 변환된 장소 정보 로그
        if (places.isNotEmpty) {
          final place = places[0];
          _logger.d(
            '🏠 첫 번째 변환된 장소: ${place.name} (${place.id}) at ${place.location.latitude}, ${place.location.longitude}',
          );
        }

        if (isInitialLoad) {
          _nearbyPlaces = places; // 초기 로드 시 nearby 저장
          _logger.d('📋 초기 주변 장소로 ${_nearbyPlaces.length}개 저장됨');
        }
        _searchResults = places; // 항상 최신 결과는 searchResults에 반영
        _logger.d('🔍 검색 결과로 ${_searchResults.length}개 장소 저장됨');
        _createMarkers();
      } else {
        _logger.w('⚠️ 주변 장소 데이터 없음 또는 잘못된 형식: $response');
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
      _errorMessage = e is TimeoutException ? '서버 응답 시간 초과' : '서버 연결 오류 발생: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// 텍스트 기반 장소 검색
  ///
  /// [query] 검색어
  /// [center] 검색 중심 좌표
  Future<void> searchPlaces(String query, LatLng center) async {
    if (query.isEmpty) {
      // 검색어 비면 초기 주변 장소 목록 보여주기
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
    }
  }

  /// 마커 생성 및 상태 업데이트
  void _createMarkers() {
    _markers.clear();
    final places = placesToShow;

    _logger.d('🔄 마커 생성 시작: ${places.length}개 장소 데이터');

    if (places.isEmpty) {
      _logger.w('⚠️ 마커 생성 실패: 장소 데이터가 없음');
      notifyListeners();
      return;
    }

    for (final place in places) {
      _logger.d(
        '🏷️ 마커 생성: ${place.name} (ID: ${place.id}) at ${place.location.latitude}, ${place.location.longitude}',
      );
      _markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: place.location,
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
          onTap: () => _onMarkerTapped(place.id),
        ),
      );
    }

    _logger.d('✅ 마커 생성 완료: ${_markers.length}개 마커');
    notifyListeners();
  }

  /// 마커 탭 이벤트 처리
  void _onMarkerTapped(String placeId) {
    _selectedPlaceId = placeId;
    notifyListeners();
    _scrollToSelectedPlace();
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
  ///
  /// 검색어 입력 후 1초 동안 추가 입력이 없으면 검색 실행
  void performSearchDebounced(String query, LatLng currentCenter) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(seconds: 1), () {
      _logger.i('⏳ 검색 디바운스 완료: "$query"');
      searchPlaces(query, currentCenter);
    });
  }

  /// 지도 카메라 이동 멈춤 시 호출될 메서드
  ///
  /// [currentSearchQuery] 현재 검색창에 입력된 검색어
  /// [mapCenter] 현재 지도의 중심 좌표
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

  /// 지도 카메라 이동 중 호출될 메서드
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
