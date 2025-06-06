import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'google_maps_service_interface.dart';

/// Google Maps API 관련 기능을 플랫폼별로 처리하는 서비스
///
/// 웹과 모바일 환경에서 각각 다른 구현체를 사용하여 Google Maps 관련 기능을 제공한다.
/// - 웹: JavaScript API 사용 (API 키 필요)
/// - 안드로이드: 네이티브 Maps SDK 사용 (매니페스트에 API 키 정의)
/// - iOS: 네이티브 Maps SDK 사용 (info.plist에 API 키 정의)
class GoogleMapsService implements GoogleMapsServiceInterface {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  final Logger _logger = Logger();
  bool _isInitialized = false;
  bool _isEnvLoaded = false;

  // API 키 및 URL 변수
  String _webMapsApiKey = '';
  // --dart-define을 통해 주입된 환경 변수 사용.
  // 개발 시 localhost를 기본값으로 사용하고, 프로덕션 빌드 시 HTTPS 주소를 주입.
  final String _serverBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // 내부 상태 변수
  final Completer<void> _envLoadCompleter = Completer<void>();
  final Completer<bool> _webMapsLoadedCompleter = Completer<bool>();
  late GoogleMapsServiceInterface _platformImpl;

  factory GoogleMapsService() {
    return _instance;
  }

  GoogleMapsService._internal() {
    // _serverBaseUrl은 final 변수로 선언 시점에 초기화됩니다.
  }

  /// 서비스 초기화
  ///
  /// 플랫폼별 구현체를 생성하고 초기화한다.
  /// - [webApiBaseUrl]: 웹 환경에서 사용할 API 서버 URL
  /// - [androidApiBaseUrl]: 안드로이드 환경에서 사용할 API 서버 URL
  /// - [webMapsApiKey]: 웹 환경에서 사용할 Google Maps API 키
  @override
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
  }) async {
    if (_isInitialized) return;

    try {
      // 직접 전달 받은 환경 변수가 있다면 우선 사용
      // 이 로직은 더 이상 필요 없으므로 제거하거나 주석 처리합니다.
      // if (webApiBaseUrl != null) _webApiBaseUrl = webApiBaseUrl;
      // if (androidApiBaseUrl != null) _androidApiBaseUrl = androidApiBaseUrl;
      if (webMapsApiKey != null) _webMapsApiKey = webMapsApiKey;

      // 서버 기본 URL은 이미 _serverBaseUrl에 설정되어 있습니다.
      _isEnvLoaded = true;
      _envLoadCompleter.complete();

      _logger.i('GoogleMapsService: 설정 완료 - 서버 URL: $_serverBaseUrl');

      // 웹 환경일 때만 API 키 관련 로그 출력
      if (kIsWeb) {
        _logger.i(
          'Web Maps API Key: ${_webMapsApiKey.isEmpty ? "(비어있음)" : "설정됨"}',
        );
      } else {
        _logger.i('Android 환경: API 키는 AndroidManifest.xml에서 관리됨');
      }

      // 플랫폼별 구현체 생성
      if (kIsWeb) {
        _platformImpl = getWebImplementation(
          logger: _logger,
          webMapsLoadedCompleter: _webMapsLoadedCompleter,
          mapsApiKey: _webMapsApiKey,
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
      await _platformImpl.initialize();

      _isInitialized = true;
      _logger.i('GoogleMapsService: 초기화 완료');
    } catch (e) {
      _logger.e('GoogleMapsService: 초기화 실패 - $e');
      _isInitialized = false;
      throw Exception('서비스 초기화 실패: $e');
    }
  }

  /// 서버 URL 획득
  ///
  /// [isWeb]이 명시적으로 제공된 경우에만 해당 값을 사용하고,
  /// 그렇지 않은 경우 현재 플랫폼에 맞는 URL을 반환한다.
  @override
  String getServerUrl({bool? isWeb}) {
    if (!_isEnvLoaded && !_envLoadCompleter.isCompleted) {
      _logger.w('getServerUrl 호출됨 - 환경 설정이 로드되지 않음');
    }

    // 이제 단일 소스 _serverBaseUrl만 반환합니다.
    // 안드로이드 에뮬레이터에서 localhost에 접근하려면 별도의 설정이 필요하지만,
    // 우선 URL 소스를 단일화합니다.
    return _serverBaseUrl;
  }

  /// API 키 획득 (현재 플랫폼에 맞는 API 키 반환)
  @override
  String getApiKey() {
    if (!_isEnvLoaded && !_envLoadCompleter.isCompleted) {
      _logger.w('getApiKey 호출됨 - 환경 설정이 로드되지 않음');
      return '';
    }

    // 플랫폼에 따라 다른 방식으로 처리
    if (kIsWeb) {
      // 웹에서는 _webMapsApiKey 반환
      return _webMapsApiKey;
    } else {
      // 안드로이드/iOS에서는 플랫폼 구현체에 위임
      if (_isInitialized) {
        return _platformImpl.getApiKey();
      }
      // 초기화 전이면 빈 문자열 반환
      _logger.w('getApiKey: 플랫폼 구현체가 초기화되지 않음');
      return '';
    }
  }

  /// 구글 맵 위젯 생성
  ///
  /// 플랫폼에 맞는 구글 맵 위젯을 생성하여 반환한다.
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
