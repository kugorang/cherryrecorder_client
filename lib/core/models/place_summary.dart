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
    return PlaceSummary(
      placeId: json['id'] as String,
      name: json['displayName']['text'] as String,
      vicinity: json['formattedAddress'] as String?,
      location: LatLng(
        json['location']['latitude'] as double,
        json['location']['longitude'] as double,
      ),
    );
  }

  @override
  String toString() {
    return 'PlaceSummary{placeId: $placeId, name: $name, vicinity: $vicinity, location: $location}';
  }
}
