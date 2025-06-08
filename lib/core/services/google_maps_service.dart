/// Google Maps 관련 기능을 중앙에서 관리하고 제공하는 서비스 클래스입니다.
///
/// 이 클래스는 **싱글턴(Singleton)** 패턴으로 구현되어 앱 전체에서 단 하나의 인스턴스만
/// 존재하도록 보장합니다.
///
/// **주요 역할:**
/// 1. 플랫폼(웹/모바일)을 감지하여 적절한 `GoogleMapsServiceInterface` 구현체를 선택합니다.
/// 2. 앱 시작 시 `initialize` 메서드를 통해 플랫폼별 구현체를 초기화합니다.
/// 3. `createMap`, `getApiKey`, `getServerUrl`과 같은 공통 API를 제공하여,
///    앱의 다른 부분에서는 플랫폼 차이를 신경 쓰지 않고 지도 관련 기능을 사용할 수 있도록 합니다.
///
/// 이 클래스는 `GoogleMapsServiceInterface`에 의존하여 실제 동작을 위임함으로써
/// 플랫폼별 코드 분리와 테스트 용이성을 높입니다.
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'google_maps_service_interface.dart';

/// `GoogleMapsServiceInterface`를 구현한 메인 서비스 클래스입니다.
class GoogleMapsService implements GoogleMapsServiceInterface {
  /// 싱글턴 인스턴스를 위한 private 정적 변수입니다.
  static final GoogleMapsService _instance = GoogleMapsService._internal();

  /// 로깅을 위한 Logger 인스턴스입니다.
  final Logger _logger = Logger();

  /// 서비스 초기화 완료 여부를 나타내는 플래그입니다.
  bool _isInitialized = false;

  /// 웹 환경에서 사용할 Google Maps JavaScript API 키입니다.
  String _webMapsApiKey = '';

  /// 백엔드 서버의 기본 URL입니다.
  ///
  /// `--dart-define`을 통해 외부에서 주입받으며, 기본값은 개발 환경을 위한 localhost 주소입니다.
  final String _serverBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// 웹에서 Google Maps JavaScript API 스크립트 로딩 완료를 기다리기 위한 Completer입니다.
  final Completer<bool> _webMapsLoadedCompleter = Completer<bool>();

  /// 플랫폼별 실제 구현을 담을 변수입니다.
  late final GoogleMapsServiceInterface _platformImpl;

  /// 싱글턴 인스턴스를 반환하는 팩토리 생성자입니다.
  factory GoogleMapsService() {
    return _instance;
  }

  /// 외부에서 직접 인스턴스 생성을 막기 위한 private 내부 생성자입니다.
  ///
  /// 이 생성자에서 플랫폼을 확인하고 적절한 구현체(`_platformImpl`)를 선택합니다.
  GoogleMapsService._internal() {
    // kIsWeb 상수를 사용하여 컴파일 타임에 플랫폼을 확인하고 구현체를 선택합니다.
    if (kIsWeb) {
      _platformImpl = getWebImplementation(
        logger: _logger,
        webMapsLoadedCompleter: _webMapsLoadedCompleter,
        mapsApiKey: _webMapsApiKey, // 초기에는 비어있음
      );
    } else {
      // 모바일 구현체를 위한 이미 완료된 Completer 생성
      final envCompleter = Completer<void>();
      envCompleter.complete(); // 즉시 완료 처리

      _platformImpl = getMobileImplementation(
        logger: _logger,
        webMapsLoadedCompleter: _webMapsLoadedCompleter,
        envLoadCompleter: envCompleter,
      );
    }
  }

  @override
  Future<void> initialize({
    String? webApiBaseUrl, // deprecated - API_BASE_URL 환경변수 사용
    String? androidApiBaseUrl, // deprecated - API_BASE_URL 환경변수 사용
    String? webMapsApiKey,
  }) async {
    if (_isInitialized) {
      _logger.w('GoogleMapsService가 이미 초기화되었습니다.');
      return;
    }

    try {
      // API URL 로그 출력
      _logger.i('API URL: $_serverBaseUrl (플랫폼: ${kIsWeb ? "웹" : "모바일"})');

      // 웹 API 키가 주입된 경우, 내부 변수에 저장합니다.
      if (webMapsApiKey != null) {
        _webMapsApiKey = webMapsApiKey;
      }

      _logger
          .i('GoogleMapsService 초기화 시작... (플랫폼: ${kIsWeb ? 'Web' : 'Mobile'})');

      // 선택된 플랫폼 구현체의 초기화 메서드를 호출합니다.
      await _platformImpl.initialize(webMapsApiKey: _webMapsApiKey);

      _isInitialized = true;
      _logger.i('GoogleMapsService 초기화 완료.');
    } catch (e) {
      _logger.e('GoogleMapsService 초기화 실패: $e');
      _isInitialized = false;
      // 초기화 실패 시 예외를 다시 던져 상위에서 처리할 수 있도록 합니다.
      rethrow;
    }
  }

  @override
  String getServerUrl({bool? isWeb}) {
    // 모든 플랫폼에서 동일한 `_serverBaseUrl`을 사용하도록 통일되었습니다.
    return _serverBaseUrl;
  }

  @override
  String getApiKey() {
    if (!_isInitialized) {
      _logger.w('getApiKey: 서비스가 아직 초기화되지 않았습니다.');
      return '';
    }
    // 실제 API 키 반환 로직을 플랫폼 구현체에 위임합니다.
    return _platformImpl.getApiKey();
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
      _logger.w('createMap: 서비스가 아직 초기화되지 않았습니다. 로딩 위젯을 표시합니다.');
      // 초기화 전에는 로딩 인디케이터를 표시하여 사용자 경험을 향상시킵니다.
      return const Center(child: CircularProgressIndicator());
    }
    // 실제 지도 위젯 생성 로직을 플랫폼 구현체에 위임합니다.
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
