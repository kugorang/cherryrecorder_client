import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'google_maps_service_interface.dart';

/// 모바일 환경을 위한 Google Maps 서비스 구현
class GoogleMapsServiceMobile implements GoogleMapsServiceInterface {
  final Logger _logger;
  final Completer<bool> _webMapsLoadedCompleter;
  final Completer<void> _envLoadCompleter;

  // API 키를 저장할 필드 추가 -> 제거 (네이티브에서 처리)
  // String _mapsApiKey = "";
  bool _isInitializing = false;
  int _initRetryCount = 0;
  static const int _maxRetries = 3;

  GoogleMapsServiceMobile({
    required Logger logger,
    required Completer<bool> webMapsLoadedCompleter,
    required Completer<void> envLoadCompleter,
    // String? mapsApiKey, // 파라미터 제거
  }) : _logger = logger,
       _webMapsLoadedCompleter = webMapsLoadedCompleter,
       _envLoadCompleter = envLoadCompleter {
    // API 키 관련 로직 제거
    // if (mapsApiKey != null && mapsApiKey.isNotEmpty) {
    //   _mapsApiKey = mapsApiKey;
    // }
  }

  /// 위치 서비스와 권한 확인
  Future<bool> _checkLocationPermission() async {
    _logger.d('GoogleMapsService: 위치 권한 확인 중');

    // 위치 서비스가 활성화되어 있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('GoogleMapsService: 위치 서비스가 비활성화되어 있습니다.');
      return false;
    }

    // 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('GoogleMapsService: 위치 권한이 거부되었습니다.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w('GoogleMapsService: 위치 권한이 영구적으로 거부되었습니다.');
      return false;
    }

    _logger.d('GoogleMapsService: 위치 권한 확인 완료');
    return true;
  }

  @override
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
    // String? androidMapsApiKey, // 파라미터 제거
  }) async {
    if (_isInitializing) {
      _logger.d('GoogleMapsService: 이미 초기화 중입니다');
      return;
    }

    _isInitializing = true;
    _logger.d('GoogleMapsService: 모바일 환경용 초기화 시작');

    try {
      // 환경 변수 업데이트 로직 제거 (API 키 관련)
      // if (androidMapsApiKey != null && androidMapsApiKey.isNotEmpty) {
      //   _mapsApiKey = androidMapsApiKey;
      // }

      // 환경 변수 로드 완료 대기
      if (!_envLoadCompleter.isCompleted) {
        await _envLoadCompleter.future;
      }

      // 위치 권한 확인
      await _checkLocationPermission();

      // 모바일 환경에서는 초기화에 시간이 필요할 수 있으므로 지연 추가
      _logger.d('GoogleMapsService: 지도 서비스 초기화 전 지연 적용');
      await Future.delayed(const Duration(seconds: 2));

      // GoogleMap 컨트롤러 초기화를 위한 사전 준비 작업
      // 여기서 API 키 검증 등 필요한 작업 수행
      // API 키 검증 로직 제거
      // _logger.d(
      //   'GoogleMapsService: API 키 검증: ${_mapsApiKey.isEmpty ? "키 없음" : "키 있음"}',
      // );

      if (!_webMapsLoadedCompleter.isCompleted) {
        _webMapsLoadedCompleter.complete(true);
      }

      if (!_envLoadCompleter.isCompleted) {
        _envLoadCompleter.complete();
      }

      _isInitializing = false;
      _logger.d('GoogleMapsService: 모바일 환경용 초기화 완료');
    } catch (e) {
      _logger.e('GoogleMapsService: 모바일 초기화 오류 - $e');
      _isInitializing = false;

      // 초기화 실패 시 재시도 로직
      if (_initRetryCount < _maxRetries &&
          !_webMapsLoadedCompleter.isCompleted) {
        _initRetryCount++;
        _logger.w('GoogleMapsService: 초기화 재시도 ($_initRetryCount/$_maxRetries)');

        // 재시도 간격을 점점 늘림
        await Future.delayed(Duration(seconds: _initRetryCount * 2));
        await initialize();
      } else if (!_webMapsLoadedCompleter.isCompleted) {
        _webMapsLoadedCompleter.completeError('모바일 지도 초기화 실패: $e');
      }
    }
  }

  @override
  Widget createMap({
    required LatLng initialPosition,
    double initialZoom = 14.0,
    void Function(GoogleMapController)? onMapCreated,
    Set<Marker> markers = const {},
    bool myLocationEnabled = false,
    bool myLocationButtonEnabled = false,
    bool zoomControlsEnabled = true,
    bool compassEnabled = true,
    ArgumentCallback<LatLng>? onTap,
    CameraPositionCallback? onCameraMove,
    VoidCallback? onCameraIdle,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    _logger.d('GoogleMapsService: 모바일 지도 위젯 생성');

    void wrappedOnMapCreated(GoogleMapController controller) {
      _logger.d('GoogleMap 컨트롤러 생성됨');
      if (onMapCreated != null) {
        onMapCreated(controller);
      }
    }

    return GoogleMap(
      onMapCreated: wrappedOnMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: initialZoom,
      ),
      markers: markers,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      compassEnabled: compassEnabled,
      onTap: onTap,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      padding: padding,
      mapType: MapType.normal,
    );
  }

  // 부모 클래스로부터 API 키를 가져오기
  @override
  String getApiKey() => ""; // 모바일에서는 Flutter 코드 레벨에서 키를 반환할 필요 없음

  @override
  String getServerUrl({bool? isWeb}) => ""; // 인터페이스와 시그니처 통일
}
