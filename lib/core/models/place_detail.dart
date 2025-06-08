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
    final Map<String, dynamic> data =
        json.containsKey('result') && json['result'] is Map
            ? json['result'] as Map<String, dynamic>
            : json;

    // 'place_id' 또는 'id' 키에서 장소 ID 파싱
    final String? placeId =
        data['place_id'] as String? ?? data['id'] as String?;

    // 'geometry' 또는 'location' 키에서 위치 정보 파싱
    final Map<String, dynamic>? geometryData =
        data['geometry'] as Map<String, dynamic>?;
    final Map<String, dynamic>? locationData = geometryData != null
        ? geometryData['location'] as Map<String, dynamic>?
        : data['location'] as Map<String, dynamic>?;

    if (placeId == null || locationData == null) {
      throw FormatException(
          '장소 상세 정보에 필수 필드(place_id/id, geometry/location)가 없습니다. 받은 데이터: $json');
    }

    final lat =
        locationData['lat'] as double? ?? locationData['latitude'] as double?;
    final lng =
        locationData['lng'] as double? ?? locationData['longitude'] as double?;

    if (lat == null || lng == null) {
      throw const FormatException('위치 정보(lat, lng)가 없습니다.');
    }

    List<String>? photos;
    if (data['photos'] != null && data['photos'] is List) {
      photos = (data['photos'] as List)
          .where((photo) => photo != null)
          .map((photo) {
            // 사진 데이터가 문자열인 경우 (단순 참조)
            if (photo is String) {
              return photo;
            }
            // 사진 데이터가 객체인 경우
            if (photo is Map<String, dynamic>) {
              // photo_reference 필드 확인
              if (photo.containsKey('photo_reference') &&
                  photo['photo_reference'] != null) {
                return photo['photo_reference'] as String;
              }
              // name 필드 확인 (새로운 API 형식)
              if (photo.containsKey('name') && photo['name'] != null) {
                return photo['name'] as String;
              }
            }
            return null;
          })
          .where((ref) => ref != null)
          .cast<String>()
          .toList();
    }

    return PlaceDetail(
      placeId: placeId,
      name: data['name'] as String? ??
          data['displayName']?['text'] as String? ??
          '이름 없음',
      formattedAddress: data['formatted_address'] as String? ??
          data['formattedAddress'] as String?,
      formattedPhoneNumber: data['formatted_phone_number'] as String?,
      location: LatLng(lat, lng),
      photoReferences: photos,
      rating: (data['rating'] as num?)?.toDouble(),
      vicinity: data['vicinity'] as String?,
      website: data['website'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'name': name,
      'formatted_address': formattedAddress,
      'formatted_phone_number': formattedPhoneNumber,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'photos':
          photoReferences?.map((ref) => {'photo_reference': ref}).toList(),
      'rating': rating,
      'vicinity': vicinity,
      'website': website,
    };
  }
}
