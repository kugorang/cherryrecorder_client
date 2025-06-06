import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceDetail {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final String? formattedPhoneNumber;
  final LatLng location;
  final List<String>? photoReferences;
  final double? rating;
  final String? vicinity;
  final String? website;

  PlaceDetail({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    this.formattedPhoneNumber,
    required this.location,
    this.photoReferences,
    this.rating,
    this.vicinity,
    this.website,
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    if (result == null) {
      throw const FormatException('장소 상세 정보 결과가 없습니다.');
    }

    final geometry = result['geometry'];
    if (geometry == null || geometry['location'] == null) {
      throw const FormatException('위치 정보가 없습니다.');
    }

    List<String>? photos;
    if (result['photos'] != null && result['photos'] is List) {
      photos = (result['photos'] as List)
          .map((photo) => photo['photo_reference'] as String)
          .toList();
    }

    return PlaceDetail(
      placeId: result['place_id'] ?? '',
      name: result['name'] ?? '이름 없음',
      formattedAddress: result['formatted_address'],
      formattedPhoneNumber: result['formatted_phone_number'],
      location: LatLng(
        geometry['location']['lat'],
        geometry['location']['lng'],
      ),
      photoReferences: photos,
      rating: (result['rating'] as num?)?.toDouble(),
      vicinity: result['vicinity'],
      website: result['website'],
    );
  }
}
