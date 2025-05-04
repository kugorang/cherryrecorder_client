import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'google_maps_service_interface.dart';

/// Google Maps API 관련 기능을 플랫폼별로 처리하는 서비스
class GoogleMapsService implements GoogleMapsServiceInterface {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  final Logger _logger = Logger();
  bool _isInitialized = false;
  bool _isEnvLoaded = false; // .env 로드 상태 추적

  // API 키 및 URL 변수
  String _webMapsApiKey = '';
  String _androidApiBaseUrl = 'http://10.0.2.2:8080'; // 기본값
  String _webApiBaseUrl = 'http://localhost:8080';
  String _serverBaseUrl = '';

  // 내부 상태 변수
  final Completer<void> _envLoadCompleter = Completer<void>(); // .env 로딩 완료 추적
  final Completer<bool> _webMapsLoadedCompleter = Completer<bool>();
  late GoogleMapsServiceInterface _platformImpl;

  factory GoogleMapsService() {
    return _instance;
  }

  // private 생성자
  GoogleMapsService._internal() {
    // 생성 시점에 바로 _serverBaseUrl 초기화 (기본값 사용)
    _serverBaseUrl = kIsWeb ? _webApiBaseUrl : _androidApiBaseUrl;
    // 플랫폼 구현체 초기화는 configure 대신 initialize에서 수행
  }

  @override
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
  }) async {
    if (_isInitialized) return;

    try {
      // 직접 전달 받은 환경 변수가 있다면 우선 사용
      if (webApiBaseUrl != null) _webApiBaseUrl = webApiBaseUrl;
      if (androidApiBaseUrl != null) _androidApiBaseUrl = androidApiBaseUrl;
      if (webMapsApiKey != null) _webMapsApiKey = webMapsApiKey;

      // 서버 기본 URL 설정
      _serverBaseUrl = kIsWeb ? _webApiBaseUrl : _androidApiBaseUrl;

      _isEnvLoaded = true;
      _envLoadCompleter.complete();

      _logger.i('GoogleMapsService: 설정 완료 - 서버 URL: $_serverBaseUrl');
      _logger.i(
        'Web Maps API Key: ${_webMapsApiKey.isEmpty ? "(비어있음)" : "설정됨"}',
      );

      // 플랫폼별 구현체 생성 (설정값 사용)
      if (kIsWeb) {
        _platformImpl = getWebImplementation(
          logger: _logger,
          webMapsLoadedCompleter: _webMapsLoadedCompleter,
          mapsApiKey: _webMapsApiKey, // 로드된 키 사용
        );
      } else {
        _platformImpl = getMobileImplementation(
          logger: _logger,
          webMapsLoadedCompleter: _webMapsLoadedCompleter,
          envLoadCompleter: _envLoadCompleter,
        );
      }

      _logger.i('GoogleMapsService: 초기화 시작');

      // 플랫폼별 초기화 실행
      if (kIsWeb) {
        await _platformImpl.initialize();
      } else {
        await _platformImpl.initialize();
      }
      _isInitialized = true;
      _logger.i('GoogleMapsService: 초기화 완료');
    } catch (e) {
      _logger.e('GoogleMapsService: 초기화 실패 - $e');
      _isInitialized = false;
      throw Exception('서비스 초기화 실패: $e');
    }
  }

  /// 서버 URL 획득 (이제 isWeb 파라미터 불필요)
  @override
  String getServerUrl({bool? isWeb}) {
    if (!_isEnvLoaded && !_envLoadCompleter.isCompleted) {
      _logger.w('getServerUrl 호출됨 - .env 아직 로드되지 않음');
      // 필요시 기본값 또는 에러 처리
    }

    // isWeb이 명시적으로 제공된 경우에만 해당 값 사용 (테스트 목적)
    if (isWeb != null) {
      return isWeb ? _webApiBaseUrl : _androidApiBaseUrl;
    }

    // 명시적으로 지정되지 않은 경우 현재 플랫폼 감지하여 올바른 URL 반환
    return kIsWeb ? _webApiBaseUrl : _androidApiBaseUrl;
  }

  /// API 키 획득 (현재 플랫폼에 맞는 API 키 반환)
  @override
  String getApiKey() {
    if (!_isEnvLoaded && !_envLoadCompleter.isCompleted) {
      _logger.w('getApiKey 호출됨 - .env 아직 로드되지 않음');
      return '';
    }
    return _webMapsApiKey;
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
    if (!_isInitialized) {
      // 초기화 전이면 로딩 인디케이터 표시
      _logger.w('GoogleMapsService.createMap 호출됨 - 아직 초기화되지 않음');
      return const Center(child: CircularProgressIndicator());
    }
    // 초기화 완료 후 플랫폼 구현체의 createMap 호출
    return _platformImpl.createMap(
      initialPosition: initialPosition,
      initialZoom: initialZoom,
      onMapCreated: onMapCreated,
      markers: markers,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      compassEnabled: compassEnabled,
      onTap: onTap,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      padding: padding,
    );
  }
}
