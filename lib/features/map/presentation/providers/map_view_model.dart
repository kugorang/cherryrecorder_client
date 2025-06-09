/// 지도 화면의 상태와 비즈니스 로직을 관리하는 ViewModel 클래스입니다.
///
/// `ChangeNotifier`를 상속하여 UI에 상태 변경을 알립니다.
/// 이 클래스는 다음과 같은 주요 책임들을 가집니다:
/// - **상태 관리**: 로딩 상태, 에러 메시지, 지도 마커, 장소 목록 등 UI에 필요한 모든 상태를 관리합니다.
/// - **비즈니스 로직**:
///   - 사용자의 현재 위치를 가져오고 권한을 처리합니다.
///   - 서버 API와 통신하여 주변 장소 정보나 검색 결과를 가져옵니다.
///   - 가져온 장소 데이터를 바탕으로 지도 위에 마커를 생성하고 관리합니다.
///   - 사용자의 상호작용(지도 이동, 마커 탭, 리스트 스크롤)에 반응하여 상태를 업데이트합니다.
/// - **컨트롤러 관리**: `GoogleMapController`와 `ScrollController`를 관리합니다.
library;

import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/models/place_summary.dart';
import '../../../../core/services/google_maps_service.dart';
import 'package:location/location.dart';

/// 지도 화면의 상태와 로직을 담당하는 ViewModel.
///
/// 주변 장소 데이터 조회, 지도 마커 관리, 검색 기능 등을 담당
class MapViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  late final ApiClient _apiClient;
  final Location _location = Location();

  // --- 컨트롤러 ---
  GoogleMapController? _mapController;
  GoogleMapController? get mapController => _mapController;

  // --- 상태 변수 ---
  bool _isLoading = false;
  String? _errorMessage;
  Set<Marker> _markers = {};
  List<PlaceSummary> _places = []; // 장소 목록 단일화
  String? _selectedPlaceId;
  String? _selectedPlaceIdBeforeChange; // 스크롤 계산을 위한 이전 선택 ID
  LatLng _currentMapCenter = const LatLng(37.4979, 127.0276); // 기본 위치 (강남역)

  // --- 타이머 및 컨트롤러 ---
  Timer? _searchDebounce;
  Timer? _mapMoveDebounce;
  final ScrollController scrollController = ScrollController();

  // API 호출 제한을 위한 변수
  LatLng? _lastApiCallCenter; // 마지막으로 API를 호출한 중심 위치
  static const double _minDistanceForApiCall = 1.0; // 1km
  final bool _autoRefreshEnabled = false; // 자동 갱신 비활성화
  static const int _maxPlacesToShow = 5; // 표시할 최대 장소 개수

  // --- Public Getters ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<Marker> get markers => _markers;
  List<PlaceSummary> get placesToShow => _places; // 항상 _places를 사용
  String? get selectedPlaceId => _selectedPlaceId;
  String? get selectedPlaceIdBeforeChange => _selectedPlaceIdBeforeChange;
  LatLng get currentMapCenter => _currentMapCenter;
  bool get mapControllerReady => _mapController != null;
  bool get autoRefreshEnabled => _autoRefreshEnabled;

  // --- 지도 컨트롤러 설정 ---
  bool _isFirstMapCreation = true;

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    _logger.i('🗺️ GoogleMapController 설정 완료');

    // 처음 지도가 생성될 때 초기 위치 가져오기
    if (_isFirstMapCreation) {
      _isFirstMapCreation = false;
      // 지도가 완전히 준비된 후 초기화 (충분한 시간 확보)
      Future.delayed(const Duration(milliseconds: 1200), () {
        initializeAndFetchCurrentLocation();
      });
    } else if (_markers.isNotEmpty) {
      // 지도가 재생성된 경우 마커를 다시 생성
      _logger.d('지도 준비 완료, 마커 재생성');
      _createMarkers();
    }
  }

  /// `MapViewModel` 생성자.
  ///
  /// `ApiClient`를 초기화합니다.
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

  /// 앱 시작 시 사용자의 현재 위치를 가져오고 관련 데이터를 로드합니다.
  ///
  /// 1. 위치 서비스 활성화 여부를 확인하고, 비활성화 시 사용자에게 요청합니다.
  /// 2. 위치 권한을 확인하고, 권한이 없는 경우 사용자에게 요청합니다.
  /// 3. 권한이 허용되면 현재 위치를 가져와 지도를 해당 위치로 이동시킵니다.
  /// 4. 현재 위치 기반으로 주변 장소를 검색합니다.
  /// 5. 과정 중 실패하거나 권한이 거부되면 기본 위치(강남역)에서 검색을 수행합니다.
  Future<void> initializeAndFetchCurrentLocation() async {
    _setLoading(true);
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
      }
      if (!serviceEnabled) {
        _logger.w('위치 서비스 비활성화. 기본 위치로 진행.');
        await fetchInitialPlaces(); // 기본 위치(강남)로 장소 검색
        return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
      }
      if (permissionGranted != PermissionStatus.granted) {
        _logger.w('위치 권한 거부. 기본 위치로 진행.');
        await fetchInitialPlaces();
        return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        _logger.i('현재 위치 확인: $currentLocation');
        await centerOnLocation(currentLocation);
        _lastApiCallCenter = currentLocation; // API 호출 기준점 설정
        await fetchNearbyPlaces(currentLocation);
      } else {
        _logger.w('현재 위치 데이터 가져오기 실패. 기본 위치로 진행.');
        await fetchInitialPlaces();
      }
    } catch (e) {
      _logger.e('위치 파악 중 오류 발생', error: e);
      await fetchInitialPlaces(); // 오류 발생 시 기본 위치로 복구
    } finally {
      _setLoading(false);
    }
  }

  /// 지정된 위치로 카메라를 이동시킨다.
  Future<void> centerOnLocation(LatLng location) async {
    _currentMapCenter = location;
    if (_mapController != null) {
      await _mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(location, 15));
      _logger.d('카메라를 $location 으로 이동');
    } else {
      _logger.d('맵 컨트롤러가 아직 준비되지 않아 카메라 이동 스킵.');
    }
    notifyListeners();
  }

  /// 초기 장소 로드 (앱 시작 또는 화면 진입 시 호출)
  Future<void> fetchInitialPlaces() async {
    _logger.d(
        '📍 fetchInitialPlaces 호출됨: 중심 위치 ${_currentMapCenter.latitude}, ${_currentMapCenter.longitude}');
    _lastApiCallCenter = _currentMapCenter; // API 호출 기준점 설정
    await fetchNearbyPlaces(_currentMapCenter);
  }

  /// 지도 이동이 멈추면 호출되는 디바운스 함수
  void onCameraIdle(LatLng center) {
    _currentMapCenter = center;

    // 자동 갱신이 비활성화되어 있으면 API 호출하지 않음
    if (!_autoRefreshEnabled) {
      _logger.d('🗺️ 자동 갱신 비활성화됨. 지도 이동에 따른 API 호출 생략');
      return;
    }

    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 800), () {
      // 처음 호출이거나 최소 거리 이상 이동했을 때만 API 호출
      if (_lastApiCallCenter == null) {
        _logger.i('🗺️ 첫 API 호출. 중심: $center');
        _lastApiCallCenter = center;
        fetchNearbyPlaces(center);
      } else {
        final distance = _calculateDistance(_lastApiCallCenter!, center);
        if (distance >= _minDistanceForApiCall) {
          _logger.i(
              '🗺️ ${distance.toStringAsFixed(2)}km 이동. 주변 장소 다시 검색. 중심: $center');
          _lastApiCallCenter = center;
          fetchNearbyPlaces(center);
        } else {
          _logger.d(
              '🗺️ ${distance.toStringAsFixed(2)}km 이동. 최소 거리(${_minDistanceForApiCall}km) 미달로 API 호출 생략');
        }
      }
    });
  }

  /// 두 LatLng 지점 간의 거리를 계산 (Haversine 공식)
  double _calculateDistance(LatLng start, LatLng end) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((end.latitude - start.latitude) * p) / 2 +
        cos(start.latitude * p) *
            cos(end.latitude * p) *
            (1 - cos((end.longitude - start.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// 주변 장소 데이터 가져오기
  Future<void> fetchNearbyPlaces(LatLng center) async {
    _setLoading(true);
    _errorMessage = null;
    _selectedPlaceId = null; // 이전 선택 초기화

    try {
      _logger.i('🔍 주변 장소 요청 시작: ${center.latitude}, ${center.longitude}');

      // 재시도 로직 추가
      int retryCount = 0;
      late Map<String, dynamic> response;

      while (retryCount < 3) {
        try {
          response = await _apiClient.post(
            ApiConstants.nearbySearchEndpoint,
            body: {
              'latitude': double.parse(center.latitude.toStringAsFixed(6)),
              'longitude': double.parse(center.longitude.toStringAsFixed(6)),
              'radius': 500, // double → int로 변경
            },
          ).timeout(const Duration(seconds: 30)); // 타임아웃 15초 → 30초로 증가
          break; // 성공하면 루프 탈출
        } catch (e) {
          if (e is TimeoutException && retryCount < 2) {
            retryCount++;
            _logger.w('⏰ 타임아웃 발생, 재시도 $retryCount/3');
            await Future.delayed(const Duration(seconds: 2)); // 2초 대기 후 재시도
            continue;
          }
          rethrow; // 마지막 시도 실패 시 예외 전파
        }
      }

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 주변 장소 데이터 ${placesData.length}개 발견');

        if (placesData.isEmpty) {
          _places = [];
          _errorMessage = '주변 장소 정보를 찾을 수 없습니다.';
        } else {
          _places =
              placesData.map((data) => PlaceSummary.fromJson(data)).toList();

          // 장소를 5개로 제한
          if (_places.length > _maxPlacesToShow) {
            _logger.i('📍 장소 ${_places.length}개 중 $_maxPlacesToShow개만 표시');
            _places = _places.take(_maxPlacesToShow).toList();
          }

          // 가장 가까운 장소 찾아 자동 선택
          _findAndSelectNearestPlace(center);
        }
        _createMarkers();
      } else {
        _logger.w('⚠️ 주변 장소 데이터 없음 또는 잘못된 형식: $response');
        _places = [];
        _errorMessage = '주변 장소 정보를 가져오는데 실패했습니다.';
        _createMarkers();
      }
    } catch (e) {
      _logger.e('❌ 주변 장소 로드 오류: $e');
      _places = [];
      _errorMessage = e is TimeoutException
          ? '서버 응답 시간 초과. 잠시 후 다시 시도해주세요.'
          : '서버 연결 오류 발생';
      _createMarkers();
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
      fetchNearbyPlaces(center);
      return;
    }

    _setLoading(true);
    _errorMessage = null;
    _selectedPlaceId = null; // 이전 선택 초기화

    try {
      _logger.i(
          '🔍 장소 검색 요청 시작: "$query" at ${center.latitude}, ${center.longitude}');

      // 재시도 로직 추가
      int retryCount = 0;
      late Map<String, dynamic> response;

      while (retryCount < 3) {
        try {
          response = await _apiClient.post(
            ApiConstants.textSearchEndpoint,
            body: {
              'query': query,
              'latitude': double.parse(center.latitude.toStringAsFixed(6)),
              'longitude': double.parse(center.longitude.toStringAsFixed(6)),
              'radius': 5000, // double → int로 변경
            },
          ).timeout(const Duration(seconds: 30)); // 타임아웃 15초 → 30초로 증가
          break; // 성공하면 루프 탈출
        } catch (e) {
          if (e is TimeoutException && retryCount < 2) {
            retryCount++;
            _logger.w('⏰ 타임아웃 발생, 재시도 $retryCount/3');
            await Future.delayed(const Duration(seconds: 2)); // 2초 대기 후 재시도
            continue;
          }
          rethrow; // 마지막 시도 실패 시 예외 전파
        }
      }

      if (response.containsKey('places') && response['places'] is List) {
        final List placesData = response['places'];
        _logger.i('📍 검색된 장소 데이터 ${placesData.length}개 발견');
        _places =
            placesData.map((data) => PlaceSummary.fromJson(data)).toList();

        // 검색 결과도 5개로 제한
        if (_places.length > _maxPlacesToShow) {
          _logger.i('📍 검색 결과 ${_places.length}개 중 $_maxPlacesToShow개만 표시');
          _places = _places.take(_maxPlacesToShow).toList();
        }

        if (_places.isNotEmpty) {
          // 검색 결과의 첫 번째 장소로 지도 이동 및 선택
          final firstPlace = _places.first;
          await centerOnLocation(firstPlace.location);
          onPlaceSelected(firstPlace.placeId, moveCamera: false);
          // 검색 후 새로운 위치로 이동했으므로 API 호출 기준점 업데이트
          _lastApiCallCenter = firstPlace.location;
        }

        _createMarkers();
      } else {
        _logger.w('⚠️ 검색 결과 없음: $response');
        _places = [];
        _errorMessage = '검색된 장소가 없습니다.';
        _createMarkers();
      }
    } catch (e) {
      _logger.e('❌ 장소 검색 오류: $e');
      _places = [];
      _errorMessage =
          e is TimeoutException ? '서버 응답 시간 초과. 잠시 후 다시 시도해주세요.' : '검색 중 오류 발생';
      _createMarkers();
    } finally {
      _setLoading(false);
    }
  }

  /// 장소 목록에서 가장 가까운 장소를 찾아 선택하는 내부 함수
  void _findAndSelectNearestPlace(LatLng center) {
    if (_places.isEmpty) return;

    PlaceSummary? nearestPlace;
    double? minDistance;

    for (final place in _places) {
      final distance = _calculateDistance(center, place.location);
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearestPlace = place;
      }
    }

    if (nearestPlace != null) {
      // 카메라 이동 없이 가장 가까운 장소 선택
      onPlaceSelected(nearestPlace.placeId, moveCamera: false);
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
    final newMarkers = <Marker>{}; // 새로운 Set 생성
    _logger.d('🎯 마커 생성 시작. 선택된 장소: $_selectedPlaceId');

    for (final place in _places) {
      final isSelected = place.placeId == _selectedPlaceId;

      // 디버깅을 위한 로그 추가
      if (isSelected) {
        _logger.i('✅ 선택된 마커: ${place.name} (${place.placeId})');
      }

      newMarkers.add(
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

    // 완전히 새로운 Set으로 교체 (참조 변경)
    _markers = newMarkers;

    _logger.d('🎯 마커 생성 완료. 총 ${_markers.length}개');

    // 선택된 마커의 InfoWindow 표시
    if (_selectedPlaceId != null &&
        _selectedPlaceId!.isNotEmpty &&
        _mapController != null) {
      // 디버깅용 로그 추가
      _logger.d('InfoWindow 표시 시도 - selectedPlaceId: "$_selectedPlaceId"');
      _logger
          .d('현재 마커 ID 목록: ${_markers.map((m) => m.markerId.value).toList()}');

      // 선택된 placeId가 현재 places 목록에 실제로 존재하는지 확인
      final selectedPlaceExists =
          _places.any((place) => place.placeId == _selectedPlaceId);

      // 마커가 실제로 생성되었는지 확인
      final markerExists =
          _markers.any((marker) => marker.markerId.value == _selectedPlaceId);

      if (selectedPlaceExists && markerExists) {
        // 마커가 지도에 렌더링될 시간을 주기 위해 충분한 지연 추가
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (_mapController != null && _selectedPlaceId != null) {
            try {
              _mapController!.showMarkerInfoWindow(MarkerId(_selectedPlaceId!));
              _logger.d('✅ InfoWindow 표시 성공: $_selectedPlaceId');
            } catch (e) {
              _logger.e('❌ InfoWindow 표시 중 오류 발생', error: e);
              // 오류는 로그만 남기고 선택은 유지 (타이밍 이슈일 수 있음)
            }
          }
        });
      } else {
        _logger.w('선택된 장소가 목록에 없거나 마커가 생성되지 않음');
        _logger.w('장소 존재: $selectedPlaceExists, 마커 존재: $markerExists');
        // 존재하지 않는 선택 초기화
        _selectedPlaceId = null;
      }
    }

    // 마커가 업데이트되었으므로 UI 갱신
    notifyListeners();
  }

  /// 장소 선택 시 호출
  void onPlaceSelected(String placeId, {bool moveCamera = true}) {
    _logger.i('🎯 장소 선택됨: $placeId (카메라 이동: $moveCamera)');

    // 카메라 이동이 필요한 경우 (리스트 클릭 시 항상 카메라 이동)
    if (moveCamera) {
      try {
        final place = _places.firstWhere((p) => p.placeId == placeId);
        moveCameraToPlace(place.location);
      } catch (e) {
        _logger.e('선택된 장소를 찾을 수 없습니다: $placeId', error: e);
      }
    }

    // 이미 선택된 장소라면 마커 업데이트는 하지 않음
    if (_selectedPlaceId == placeId) {
      _logger.d('이미 선택된 장소입니다.');
      return;
    }

    // 상태 업데이트
    _selectedPlaceIdBeforeChange = _selectedPlaceId;
    _selectedPlaceId = placeId;
    _createMarkers(); // 선택된 마커 색상 변경을 위해 마커 재생성
    // notifyListeners()는 _createMarkers()에서 이미 호출됨
  }

  /// 특정 위치로 카메라 이동 (기존 moveCameraToPlace 리팩토링)
  Future<void> moveCameraToPlace(LatLng location) async {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, 16), // 확대 레벨 조정
    );
  }

  /// 선택 해제
  void clearSelection() {
    _selectedPlaceIdBeforeChange = _selectedPlaceId;
    _selectedPlaceId = null;
    _createMarkers();
    // notifyListeners()는 _createMarkers()에서 호출됨
  }

  /// 수동 새로고침
  Future<void> refreshNearbyPlaces() async {
    _lastApiCallCenter = _currentMapCenter;
    await fetchNearbyPlaces(_currentMapCenter);
  }
}
