import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 지도에 표시될 장소의 요약 정보를 담는 모델
class PlaceSummary {
  final String placeId;
  final String name;
  final String vicinity;
  final LatLng location;
  final List<String> photoReferences; // 사진 참조 목록 추가

  PlaceSummary({
    required this.placeId,
    required this.name,
    required this.vicinity,
    required this.location,
    this.photoReferences = const [], // 기본값은 빈 리스트
  });

  factory PlaceSummary.fromJson(Map<String, dynamic> json) {
    // 위치 정보 파싱 (새 형식과 기존 형식 모두 지원)
    double lat = 0.0;
    double lng = 0.0;

    // 새 형식 (loc.lat, loc.lng) 먼저 확인
    if (json.containsKey('loc') && json['loc'] is Map<String, dynamic>) {
      final locData = json['loc'] as Map<String, dynamic>;
      lat = (locData['lat'] as num?)?.toDouble() ?? 0.0;
      lng = (locData['lng'] as num?)?.toDouble() ?? 0.0;
    }
    // 기존 형식 (location.latitude, location.longitude) 확인
    else if (json.containsKey('location') &&
        json['location'] is Map<String, dynamic>) {
      final locationData = json['location'] as Map<String, dynamic>;
      lat = (locationData['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (locationData['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    // 사진 정보 파싱
    List<String> photos = [];
    if (json.containsKey('photos') && json['photos'] is List) {
      final photosData = json['photos'] as List;
      photos = photosData
          .map((photo) =>
              (photo is Map<String, dynamic> && photo.containsKey('name'))
                  ? photo['name'] as String
                  : null)
          .where((ref) => ref != null)
          .cast<String>()
          .toList();
    }

    // 서버 변환 형식과 Google API 원본 형식 모두 지원
    String placeId = '';
    String name = '이름 없음';
    String vicinity = '주소 정보 없음';

    // Place ID 파싱 (새 형식: id, 서버: placeId, Google: id)
    if (json.containsKey('id')) {
      placeId = json['id'] as String? ?? '';
    } else if (json.containsKey('placeId')) {
      placeId = json['placeId'] as String? ?? '';
    }

    // 장소 이름 파싱 (서버: name, Google: displayName.text)
    if (json.containsKey('name') && json['name'] != null) {
      name = json['name'] as String;
    } else if (json.containsKey('displayName') &&
        json['displayName'] is Map<String, dynamic> &&
        json['displayName']['text'] != null) {
      name = json['displayName']['text'] as String;
    }

    // 주소 파싱 (새 형식: addr, 서버: vicinity, Google: formattedAddress)
    if (json.containsKey('addr') && json['addr'] != null) {
      vicinity = json['addr'] as String;
    } else if (json.containsKey('vicinity') && json['vicinity'] != null) {
      vicinity = json['vicinity'] as String;
    } else if (json.containsKey('formattedAddress') &&
        json['formattedAddress'] != null) {
      vicinity = json['formattedAddress'] as String;
    }

    return PlaceSummary(
      placeId: placeId,
      name: name,
      vicinity: vicinity,
      location: LatLng(lat, lng),
      photoReferences: photos,
    );
  }

  /// 상세 화면으로 전달하기 위해 객체를 Map으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': placeId,
      'name': name,
      'address': vicinity,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'photos': photoReferences.map((ref) => {'name': ref}).toList(),
    };
  }

  @override
  String toString() {
    return 'PlaceSummary{placeId: $placeId, name: $name, vicinity: $vicinity, location: $location}';
  }
}
