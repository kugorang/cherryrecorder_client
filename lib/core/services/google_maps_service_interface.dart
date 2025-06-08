/// Google Maps 관련 서비스의 동작을 정의하는 인터페이스(추상 클래스) 파일입니다.
///
/// 이 파일은 웹과 모바일(네이티브) 환경에서 Google Maps를 사용하는 방식이 다르기 때문에,
/// 플랫폼별 구현의 차이를 숨기고 일관된 API를 제공하기 위해 설계되었습니다.
///
/// **주요 역할:**
/// - `GoogleMapsServiceInterface` 추상 클래스를 통해 플랫폼 공통 기능을 정의합니다.
/// - 팩토리 함수 `getWebImplementation`, `getMobileImplementation`을 제공하여
///   실행 환경에 맞는 서비스 구현체를 생성하고 반환합니다.
///
/// 이를 통해 `GoogleMapsService`는 실제 구현에 대해 알 필요 없이
/// 이 인터페이스에만 의존하여 동작할 수 있습니다. (의존성 역전 원칙)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// 조건부 가져오기
import 'google_maps_service_mobile.dart';
// Web 구현체는 조건부로 가져온다
import 'google_maps_service_web.dart'
    if (dart.library.io) 'google_maps_service_stub.dart';

/// `GoogleMapsService`가 구현해야 할 기능을 정의한 추상 클래스입니다.
///
/// 플랫폼(웹, 모바일)에 따라 다른 방식으로 처리되어야 하는 지도 관련 로직을
/// 추상화하여, 서비스의 나머지 부분에서는 플랫폼에 구애받지 않고
/// 일관된 방식으로 지도를 다룰 수 있도록 합니다.
abstract class GoogleMapsServiceInterface {
  /// Google Maps 서비스를 초기화합니다.
  ///
  /// 플랫폼에 따라 필요한 API 키 설정, 스크립트 로딩 등 사전 준비 작업을 수행합니다.
  ///
  /// [webApiBaseUrl] : 웹 환경에서 사용할 백엔드 API의 기본 URL입니다.
  /// [androidApiBaseUrl] : 안드로이드 환경에서 사용할 백엔드 API의 기본 URL입니다.
  /// [webMapsApiKey] : 웹 환경에서 Google Maps JavaScript API를 사용하기 위한 API 키입니다.
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
  });

  /// 현재 플랫폼에 맞는 지도 위젯을 생성하여 반환합니다.
  ///
  /// 네이티브에서는 `GoogleMap` 위젯을, 웹에서는 웹뷰나 JS interop을 통해
  /// 렌더링된 지도를 위젯 형태로 반환할 수 있습니다.
  ///
  /// [initialPosition] : 지도가 처음 표시될 때의 중심 좌표입니다.
  /// [onMapCreated] : 지도 컨트롤러가 준비되었을 때 호출될 콜백 함수입니다.
  /// [markers] : 지도 위에 표시될 마커들의 집합입니다.
  /// [padding] : 지도 UI 요소(예: 현재위치 버튼)가 가려지지 않도록 지도 내부에 적용할 여백입니다.
  ///
  /// 이 외의 파라미터들은 `google_maps_flutter` 패키지의 `GoogleMap` 위젯과 동일한 역할을 합니다.
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
  });

  /// 현재 서비스 인스턴스에 설정된 Google Maps API 키를 반환합니다.
  String getApiKey();

  /// 현재 실행 환경에 맞는 백엔드 서버의 기본 URL을 반환합니다.
  ///
  /// [isWeb] : 현재 플랫폼이 웹인지 명시적으로 지정할 때 사용됩니다.
  String getServerUrl({bool? isWeb});
}

/// 웹 환경에 맞는 `GoogleMapsServiceInterface` 구현체를 생성하여 반환합니다.
///
/// [logger], [webMapsLoadedCompleter], [mapsApiKey]는 `GoogleMapsServiceWeb`의
/// 생성에 필요한 의존성들입니다.
GoogleMapsServiceInterface getWebImplementation({
  required Logger logger,
  required Completer<bool> webMapsLoadedCompleter,
  required String mapsApiKey,
}) {
  if (!kIsWeb) {
    throw UnsupportedError('Web implementation not available');
  }
  return GoogleMapsServiceWeb(
    logger: logger,
    webMapsLoadedCompleter: webMapsLoadedCompleter,
    mapsApiKey: mapsApiKey,
  );
}

/// 모바일(안드로이드, iOS) 환경에 맞는 `GoogleMapsServiceInterface` 구현체를 생성하여 반환합니다.
///
/// [logger], [webMapsLoadedCompleter], [envLoadCompleter]는 `GoogleMapsServiceMobile`의
/// 생성에 필요한 의존성들입니다.
GoogleMapsServiceInterface getMobileImplementation({
  required Logger logger,
  required Completer<bool> webMapsLoadedCompleter,
  required Completer<void> envLoadCompleter,
}) {
  return GoogleMapsServiceMobile(
    logger: logger,
    webMapsLoadedCompleter: webMapsLoadedCompleter,
    envLoadCompleter: envLoadCompleter,
  );
}
