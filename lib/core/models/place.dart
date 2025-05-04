import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'place_summary.dart'; // PlaceSummary 임포트

/// 지도 화면 등에서 표시할 장소 정보 클래스
class Place {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final bool acceptsCreditCard;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.acceptsCreditCard,
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
}
