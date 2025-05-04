import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'google_maps_service_interface.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 네이티브(Android/iOS) 환경을 위한 [GoogleMapsServiceInterface] 구현체.
///
/// 네이티브 플랫폼에서 `google_maps_flutter` 플러그인을 직접 사용하여
/// 지도 기능을 제공한다.
class GoogleMapsServiceNative implements GoogleMapsServiceInterface {
  final Logger _logger;
  final String _mapsApiKey;
  final String _apiBaseUrl; // 네이티브 환경용 API 기본 URL

  /// [GoogleMapsServiceNative] 인스턴스를 생성한다.
  ///
  /// * [logger]: 로깅을 위한 [Logger] 인스턴스.
  /// * [mapsApiKey]: 사용할 Google Maps API 키 (네이티브 플랫폼 설정에 필요).
  /// * [apiBaseUrl]: 네이티브 환경에서 사용할 API 기본 URL.
  GoogleMapsServiceNative({
    required Logger logger,
    required String mapsApiKey,
    required String apiBaseUrl,
  }) : _logger = logger,
       _mapsApiKey = mapsApiKey,
       _apiBaseUrl = apiBaseUrl;

  /// 네이티브 환경에서는 별도의 비동기 초기화 로직이 필요하지 않다.
  ///
  /// 플러그인 설정 및 API 키는 빌드 시 또는 네이티브 코드 레벨에서 처리된다.
  @override
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl, // 필요 시 이 값을 내부 상태로 저장할 수 있음
    String? webMapsApiKey,
  }) async {
    _logger.d('GoogleMapsService: 네이티브 환경용 초기화 호출됨 (별도 작업 없음)');
    // 네이티브에서는 일반적으로 API 키 설정 등이 빌드 구성 또는
    // 네이티브 프로젝트 설정 파일(AndroidManifest.xml, Info.plist)에서 이루어진다.
    // 필요하다면 여기서 androidApiBaseUrl 등을 내부 상태로 저장할 수 있다.
    return Future.value();
  }

  /// 네이티브 환경에 맞는 [GoogleMap] 위젯을 생성하여 반환한다.
  ///
  /// 웹 구현과 동일한 파라미터를 받지만, 내부적으로 네이티브 플러그인을 사용한다.
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
    _logger.d('네이티브 환경에서 GoogleMap 위젯 생성 요청');

    if (kIsWeb) {
      _logger.e('네이티브 구현체에서 웹 환경으로 createMap 호출됨');
      return const Center(child: Text('네이티브 환경 오류'));
    }

    // 네이티브 환경에서는 google_maps_flutter 패키지의 표준 GoogleMap 위젯 사용
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: initialZoom,
      ),
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
      mapType: MapType.normal,
    );
  }

  @override
  String getApiKey() => _mapsApiKey;

  /// 네이티브 환경에서 설정된 API 기본 URL을 반환한다.
  @override
  String getServerUrl({bool? isWeb}) => _apiBaseUrl;
}
