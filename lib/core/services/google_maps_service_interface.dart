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

/// Google Maps 서비스의 인터페이스.
///
/// 이 인터페이스는 웹과 네이티브 환경 각각에 대한 Google Maps 관련 기능의
/// 추상화를 제공한다. 플랫폼별 구현체는 이 인터페이스를 따라야 한다.
abstract class GoogleMapsServiceInterface {
  /// Google Maps 서비스를 초기화한다.
  ///
  /// 플랫폼별 설정을 수행하고 필요한 API 키 등을 설정한다.
  /// 웹 환경에서는 [webMapsApiKey]를 사용하고, 네이티브 환경에서는
  /// 내부적으로 설정된 키나 [androidApiBaseUrl] 등을 사용할 수 있다.
  ///
  /// * [webApiBaseUrl]: 웹 환경에서 사용할 API 기본 URL (선택 사항).
  /// * [androidApiBaseUrl]: 안드로이드 환경에서 사용할 API 기본 URL (선택 사항).
  /// * [webMapsApiKey]: 웹 환경에서 사용할 Google Maps API 키 (선택 사항).
  ///
  /// 초기화 실패 시 [Exception]을 던질 수 있다.
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
  });

  /// 플랫폼에 맞는 지도 위젯을 생성하여 반환한다.
  ///
  /// * [initialPosition]: 지도의 초기 중심 좌표.
  /// * [initialZoom]: 지도의 초기 확대/축소 레벨 (기본값: 14.0).
  /// * [onMapCreated]: 지도가 생성된 후 호출될 콜백.
  /// * [markers]: 지도에 표시할 마커 세트 (기본값: 비어 있음).
  /// * [myLocationEnabled]: 현재 위치 표시 활성화 여부 (기본값: false).
  /// * [myLocationButtonEnabled]: 현재 위치 버튼 표시 활성화 여부 (기본값: false).
  /// * [zoomControlsEnabled]: 확대/축소 컨트롤 표시 활성화 여부 (기본값: true).
  /// * [compassEnabled]: 나침반 표시 활성화 여부 (기본값: true).
  /// * [onTap]: 지도를 탭했을 때 호출될 콜백.
  /// * [onCameraMove]: 카메라가 이동할 때 호출될 콜백.
  /// * [onCameraIdle]: 카메라 이동이 멈췄을 때 호출될 콜백.
  /// * [padding]: 지도 주변의 패딩 (기본값: EdgeInsets.zero).
  ///
  /// 반환값: 생성된 지도 [Widget].
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

  /// 현재 서비스 인스턴스에 설정된 API 키를 반환한다.
  ///
  /// 반환값: API 키 문자열.
  String getApiKey();

  /// 현재 서비스 인스턴스에 설정된 서버 URL을 반환한다.
  ///
  /// 주로 네이티브 환경에서 사용될 수 있으며, 웹 환경에서는 빈 문자열을 반환할 수 있다.
  /// * [isWeb]: 웹 환경 여부를 명시적으로 지정할 때 사용 (선택 사항).
  ///
  /// 반환값: 서버 URL 문자열.
  String getServerUrl({bool? isWeb});
}

// 웹 구현체 가져오기
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

// 모바일 구현체 가져오기
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
