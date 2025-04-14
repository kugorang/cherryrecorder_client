class ApiConstants {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const String placesBaseUrl = 'https://places.googleapis.com/v1/places';
  static const String nearbySearchEndpoint = '$placesBaseUrl:searchNearby';
  static const String textSearchEndpoint = '$placesBaseUrl:searchText';
  static const String placeDetailsEndpoint = placesBaseUrl;
}
