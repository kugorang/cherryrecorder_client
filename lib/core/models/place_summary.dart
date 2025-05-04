import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceSummary {
  final String placeId;
  final String name;
  final String? vicinity;
  final LatLng location;

  PlaceSummary({
    required this.placeId,
    required this.name,
    this.vicinity,
    required this.location,
  });

  factory PlaceSummary.fromJson(Map<String, dynamic> json) {
    // 서버 응답 키(name) 직접 사용, null 가능성 처리
    final name = json.containsKey('name') ? json['name'] : '이름 없음';

    // 서버 응답 키(vicinity) 직접 사용, null 가능성 처리
    final vicinity = json.containsKey('vicinity') ? json['vicinity'] : null;

    // location 데이터 유효성 확인 강화
    double latitude = 0.0;
    double longitude = 0.0;
    if (json.containsKey('location') && json['location'] is Map) {
      latitude = (json['location']['latitude'] ?? 0.0).toDouble();
      longitude = (json['location']['longitude'] ?? 0.0).toDouble();
    }

    return PlaceSummary(
      placeId: (json['placeId'] ?? '') as String, // 서버 응답 키 'placeId' 사용하도록 수정
      name: name as String, // 서버 응답 키 'name' 사용 결과
      vicinity: vicinity as String?, // 서버 응답 키 'vicinity' 사용 결과
      location: LatLng(latitude, longitude),
    );
  }

  @override
  String toString() {
    return 'PlaceSummary{placeId: $placeId, name: $name, vicinity: $vicinity, location: $location}';
  }
}
