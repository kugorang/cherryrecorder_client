class ApiConstants {
  // 클라이언트에 직접 API 키를 저장하지 않음
  // 모든 API 요청은 자체 서버를 통해 프록시됨

  // 서버 기본 URL은 ApiClient에서 .env 파일을 통해 관리하므로 여기서는 제거
  // static const String baseUrl = 'http://localhost:8080';

  // 엔드포인트 (상대 경로만 정의)
  static const String healthEndpoint = '/health'; // 서버 상태 확인 추가
  static const String nearbySearchEndpoint = '/places/nearby';
  static const String textSearchEndpoint = '/places/search';
  static const String placeDetailsEndpoint = '/places/details';
}
