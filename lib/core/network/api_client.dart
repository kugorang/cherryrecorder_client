import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// 서버와의 모든 HTTP 통신을 처리하는 클라이언트 클래스.
///
/// 서버의 기본 URL([baseUrl])과 HTTP 통신을 위한 [client]를 주입받아 사용한다.
/// 인증 토큰 관리를 위한 메서드를 제공한다.
class ApiClient {
  /// HTTP 요청을 수행하는 클라이언트.
  final http.Client client;

  /// 통신할 서버의 기본 URL.
  late String baseUrl;

  /// 로깅을 위한 Logger 인스턴스.
  final Logger _logger = Logger();

  /// API 요청 시 사용할 인증 토큰. `null`일 경우 인증 헤더를 포함하지 않음.
  String? _authToken;

  /// [ApiClient] 생성자.
  ///
  /// [client]와 [baseUrl]은 필수 매개변수이다.
  ApiClient({required this.client, required String baseUrl}) {
    // 안드로이드 환경에서 localhost를 10.0.2.2로 변경 (에뮬레이터 지원)
    if (!kIsWeb && baseUrl.contains('localhost')) {
      this.baseUrl = baseUrl.replaceAll('localhost', '10.0.2.2');
      _logger.i('ApiClient 초기화: localhost를 10.0.2.2로 자동 변경 - ${this.baseUrl}');
    } else {
      this.baseUrl = baseUrl;
      _logger.i('ApiClient 초기화: $baseUrl');
    }
  }

  /// API 요청에 사용할 인증 토큰을 설정한다.
  ///
  /// [token]: 설정할 인증 토큰 문자열.
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// 설정된 인증 토큰을 제거한다.
  void clearAuthToken() {
    _authToken = null;
  }

  /// 현재 설정된 인증 토큰을 포함하는 기본 요청 헤더를 생성한다.
  ///
  /// 'Content-Type'과 'Accept' 헤더는 'application/json'으로 설정된다.
  /// [_authToken]이 설정되어 있으면 'Authorization: Bearer [token]' 헤더가 추가된다.
  /// @return 생성된 HTTP 요청 헤더 맵.
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 토큰이 있으면 인증 헤더 추가
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// 지정된 엔드포인트로 GET 요청을 수행한다.
  ///
  /// [endpoint]: 요청할 서버 API의 엔드포인트 경로.
  /// [queryParams]: URL에 추가할 쿼리 파라미터 (선택 사항).
  /// @return 서버 응답을 JSON으로 디코딩한 `Map<String, dynamic>`.
  /// @throws [Exception] 네트워크 오류 또는 서버 오류 발생 시.
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    // Base URL과 엔드포인트를 조합하여 전체 URL 생성
    final url = '$baseUrl$endpoint';
    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    _logger.d('GET Request URI: $uri');

    try {
      // HTTP GET 요청
      final response = await client.get(uri, headers: _getHeaders());

      // 응답 처리
      return _processResponse(response);
    } catch (e) {
      // 네트워크 오류 또는 기타 예외 처리
      _logger.e('API GET 요청 오류 ($endpoint): $e');
      throw Exception('네트워크 오류가 발생했습니다.'); // 사용자 친화적 메시지
    }
  }

  /// 지정된 엔드포인트로 POST 요청을 수행한다.
  ///
  /// [endpoint]: 요청할 서버 API의 엔드포인트 경로.
  /// [body]: 요청 본문에 포함할 데이터 (Map 형태, JSON으로 인코딩됨, 선택 사항).
  /// @return 서버 응답을 JSON으로 디코딩한 `Map<String, dynamic>`.
  /// @throws [Exception] 네트워크 오류 또는 서버 오류 발생 시.
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    // Base URL과 엔드포인트를 조합하여 전체 URL 생성
    final url = '$baseUrl$endpoint';
    final uri = Uri.parse(url);
    _logger.d('POST Request URI: $uri');

    // 디버그 출력 추가 -> 로거 사용
    _logger.d('🌐 API 요청 POST: $url');
    if (body != null) {
      _logger.d('📦 요청 데이터: $body');
    }

    try {
      // HTTP POST 요청
      final response = await client.post(
        uri,
        headers: _getHeaders(),
        // 요청 본문을 JSON 문자열로 인코딩
        body: body != null ? jsonEncode(body) : null,
      );

      // 디버그 출력 추가
      _logger.d('📡 상태 코드: ${response.statusCode}');
      _logger.d('📄 응답 헤더: ${response.headers}');

      if (response.body.isNotEmpty) {
        if (response.body.length > 500) {
          _logger.d('📃 응답 데이터(일부): ${response.body.substring(0, 500)}...');
        } else {
          _logger.d('📃 응답 데이터: ${response.body}');
        }
      } else {
        _logger.d('📃 응답 데이터: 빈 응답');
      }

      // 응답 처리
      return _processResponse(response);
    } catch (e) {
      // 네트워크 오류 또는 기타 예외 처리
      _logger.e('API POST 요청 오류 ($endpoint): $e');
      _logger.d('❌ API 오류: $e');
      throw Exception('네트워크 오류가 발생했습니다: $e'); // 사용자 친화적 메시지
    }
  }

  /// 수신된 HTTP 응답을 처리하여 결과를 반환하거나 예외를 발생시킨다.
  ///
  /// 성공적인 응답(2xx)의 경우, 응답 본문을 JSON으로 디코딩하여 반환한다.
  /// 본문이 비어있으면 빈 Map을 반환한다.
  /// JSON 파싱 실패 시, 텍스트 응답으로 처리하여 Map으로 반환한다.
  /// 서버 오류(4xx, 5xx)의 경우, 오류 메시지를 포함하는 [Exception]을 발생시킨다.
  ///
  /// [response]: 처리할 [http.Response] 객체.
  /// @return 성공 시 디코딩된 JSON 데이터 또는 텍스트 메시지를 포함하는 Map.
  /// @throws [Exception] 서버 오류 응답 시.
  Map<String, dynamic> _processResponse(http.Response response) {
    // 성공적인 응답 (2xx 상태 코드)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 응답 본문이 비어있는 경우 빈 Map 반환
      if (response.body.isEmpty) {
        return {};
      }

      try {
        // 응답 본문을 JSON으로 디코딩하여 Map<String, dynamic>으로 반환
        return jsonDecode(utf8.decode(response.bodyBytes)); // UTF-8 디코딩 추가
      } catch (e) {
        // JSON 파싱 오류 - 텍스트 응답으로 처리
        _logger.w('JSON 파싱 오류: $e, 텍스트 응답으로 처리합니다.\n원본 응답: ${response.body}');
        // 텍스트 응답을 맵으로 변환하여 반환 (예: /health 엔드포인트 처리)
        return {'message': response.body, 'statusCode': response.statusCode};
      }
    } else {
      // 서버 오류 (4xx, 5xx 상태 코드)
      _logger.e('서버 오류 (${response.statusCode}): ${response.body}');

      // 서버 오류 메시지 파싱 시도
      String errorMessage = '서버 오류 (${response.statusCode})';
      if (response.body.isNotEmpty) {
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          // 서버 응답에서 에러 메시지 필드 추출 (서버 응답 형식에 맞게 조정 필요)
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          // JSON 파싱 실패 시 기본 에러 메시지 사용
          _logger.w('오류 응답 파싱 실패: $e');
        }
      }

      throw Exception(errorMessage);
    }
  }

  /// [ApiClient]가 사용하던 리소스(HTTP 클라이언트)를 해제한다.
  ///
  /// 이 [ApiClient] 인스턴스가 더 이상 필요하지 않을 때 호출해야 한다.
  void dispose() {
    client.close();
  }
}
