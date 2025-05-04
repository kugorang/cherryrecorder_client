// Web interop를 위한 import
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'google_maps_service_interface.dart';

// @JS 어노테이션에 실제 JS 함수 이름 명시
@JS('loadGoogleMapsApi')
external JSPromise _loadGoogleMapsApi(JSString apiKey);

/// 웹 환경을 위한 [GoogleMapsServiceInterface] 구현체.
///
/// 웹 환경에서 Google Maps JavaScript API를 로드하고 상호작용하여
/// 지도 기능을 제공한다.
class GoogleMapsServiceWeb implements GoogleMapsServiceInterface {
  final Logger _logger;

  /// 웹 환경에서 Google Maps API 스크립트 로딩 완료 여부를 나타내는 Completer.
  ///
  /// 이 Completer는 외부(주로 앱 초기화 로직)에서 주입받아, 스크립트 로딩이
  /// 완료되거나 실패했을 때 상태를 전파하는 데 사용된다.
  final Completer<bool> _webMapsLoadedCompleter;
  String _mapsApiKey;
  bool _isScriptLoaded = false;

  /// [GoogleMapsServiceWeb] 인스턴스를 생성한다.
  ///
  /// * [logger]: 로깅을 위한 [Logger] 인스턴스.
  /// * [webMapsLoadedCompleter]: Google Maps API 로딩 상태를 관리하는 [Completer].
  /// * [mapsApiKey]: 사용할 Google Maps API 키.
  GoogleMapsServiceWeb({
    required Logger logger,
    required Completer<bool> webMapsLoadedCompleter,
    required String mapsApiKey,
  }) : _logger = logger,
       _webMapsLoadedCompleter = webMapsLoadedCompleter,
       _mapsApiKey = mapsApiKey;

  @override
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
  }) async {
    _logger.d('GoogleMapsService: 웹 환경용 초기화 시작');

    try {
      if (webMapsApiKey != null && webMapsApiKey.isNotEmpty) {
        _mapsApiKey = webMapsApiKey;
      }
      if (_mapsApiKey.isEmpty) {
        throw Exception('Google Maps API 키가 설정되지 않았습니다.');
      }

      if (kIsWeb) {
        await _loadGoogleMapsScript();
      }

      _logger.d('GoogleMapsService: 웹 환경용 초기화 완료');
      if (!_webMapsLoadedCompleter.isCompleted) {
        _webMapsLoadedCompleter.complete(true);
      }
    } catch (e) {
      _logger.e('GoogleMapsService: 웹 초기화 오류 - $e');
      if (!_webMapsLoadedCompleter.isCompleted) {
        _webMapsLoadedCompleter.completeError(e);
      }
      rethrow;
    }
  }

  /// Google Maps JavaScript API 스크립트를 동적으로 로드한다.
  ///
  /// 웹 환경에서만 실행되며, 이미 로드된 경우 다시 실행하지 않는다.
  /// `web/index.html`에 정의된 `loadGoogleMapsApi` JavaScript 함수를 호출한다.
  /// 스크립트 로드 성공 또는 실패(타임아웃 포함) 시 Completer를 완료시킨다.
  ///
  /// 로딩 타임아웃은 30초로 설정되어 있다.
  ///
  /// Throws: [TimeoutException] 스크립트 로드가 30초 내에 완료되지 않으면 발생한다.
  Future<void> _loadGoogleMapsScript() async {
    if (!kIsWeb || _isScriptLoaded) return;
    _logger.d('Google Maps JavaScript API 로드 시작');
    final completer = Completer<void>();
    try {
      await _loadGoogleMapsApi(_mapsApiKey.toJS).toDart;
      _isScriptLoaded = true;
      _logger.d('Google Maps API 스크립트 로드 완료 (Promise 변환)');
      completer.complete();
    } catch (e) {
      _logger.e('Google Maps 스크립트 로드 오류: $e (${e.runtimeType})');
      completer.completeError(e);
    }
    return Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          final error = TimeoutException('Google Maps API 로드 타임아웃');
          _logger.e(error);
          if (!completer.isCompleted) completer.completeError(error);
        }
      }),
    ]);
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
    _logger.d('웹 환경에서 표준 GoogleMap 위젯 생성 요청');

    if (!kIsWeb) {
      _logger.e('웹 구현체에서 웹이 아닌 환경으로 createMap 호출됨');
      return const Center(child: Text('웹 환경 오류'));
    }

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

  /// 웹 환경에서는 별도의 서버 URL을 사용하지 않으므로 항상 빈 문자열을 반환한다.
  @override
  String getServerUrl({bool? isWeb}) => '';
}
