import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'place_summary.dart'; // PlaceSummary 임포트

/// 지도 화면 등에서 표시할 장소 정보 클래스
class Place {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final bool acceptsCreditCard;
  final List<String> photoReferences; // 장소 사진 참조 목록

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.acceptsCreditCard,
    this.photoReferences = const [], // 기본값은 빈 리스트
  });

  // PlaceSummary를 Place로 변환하는 팩토리 메서드
  factory Place.fromPlaceSummary(PlaceSummary summary) {
    return Place(
      id: summary.placeId,
      name: summary.name,
      address: summary.vicinity ?? '주소 정보 없음',
      location: summary.location,
      acceptsCreditCard: true, // 기본값으로 true 설정 (서버에서 제공하는 경우 수정 필요)
    );
  }

  /// JSON 객체(Map)에서 Place 인스턴스를 생성하는 팩토리 생성자.
  factory Place.fromJson(Map<String, dynamic> json) {
    // 위치 정보 파싱
    final locationData = json['location'] as Map<String, dynamic>;
    final latLng = LatLng(
      locationData['latitude'] as double,
      locationData['longitude'] as double,
    );

    // 사진 참조 목록 파싱
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

    return Place(
      id: json['id'] as String,
      name:
          (json['displayName']?['text'] as String?) ?? (json['name'] as String),
      address: json['formattedAddress'] as String,
      location: latLng,
      acceptsCreditCard: json['acceptsCreditCard'] as bool? ?? true,
      photoReferences: photos,
    );
  }
}
