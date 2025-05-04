import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'google_maps_service_interface.dart';

/// 웹 파일이 모바일에서 사용되지 않도록 하는 스텁 클래스
class GoogleMapsServiceWeb implements GoogleMapsServiceInterface {
  GoogleMapsServiceWeb({
    required Logger logger,
    required Completer<bool> webMapsLoadedCompleter,
    required String mapsApiKey,
  }) {
    throw UnsupportedError('GoogleMapsServiceWeb는 웹 환경에서만 지원됩니다.');
  }

  @override
  Future<void> initialize({
    String? webApiBaseUrl,
    String? androidApiBaseUrl,
    String? webMapsApiKey,
  }) {
    throw UnsupportedError('GoogleMapsServiceWeb는 웹 환경에서만 지원됩니다.');
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
    throw UnsupportedError('GoogleMapsServiceWeb는 웹 환경에서만 지원됩니다.');
  }

  @override
  String getApiKey() {
    throw UnsupportedError('GoogleMapsServiceWeb는 웹 환경에서만 지원됩니다.');
  }

  @override
  String getServerUrl({bool? isWeb}) {
    throw UnsupportedError('GoogleMapsServiceWeb는 웹 환경에서만 지원됩니다.');
  }
}
