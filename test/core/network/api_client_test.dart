import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cherryrecorder_client/core/network/api_client.dart'; // 실제 ApiClient 경로

// Mockito 코드 생성을 위한 어노테이션
@GenerateMocks([http.Client])
import 'api_client_test.mocks.dart'; // 생성될 모의 객체 파일

void main() {
  late MockClient mockClient;
  late ApiClient apiClient;
  const String testBaseUrl = 'http://test.com';
  const String testLocalhostUrl = 'http://localhost:8080';
  const String expectedAndroidUrl = 'http://10.0.2.2:8080';

  setUp(() {
    mockClient = MockClient();
    // 각 테스트 전에 ApiClient 초기화 (baseUrl은 테스트 케이스별로 다를 수 있음)
  });

  group('ApiClient Initialization', () {
    test('should use provided baseUrl if not localhost', () {
      apiClient = ApiClient(client: mockClient, baseUrl: testBaseUrl);
      expect(apiClient.baseUrl, testBaseUrl);
    });

    // 참고: 단위 테스트 환경은 기본적으로 non-web이므로, localhost 변환 로직 테스트 가능
    test('should convert localhost to 10.0.2.2 on non-web platforms', () {
      apiClient = ApiClient(client: mockClient, baseUrl: testLocalhostUrl);
      expect(apiClient.baseUrl, expectedAndroidUrl);
    });

    // 웹 환경을 명시적으로 테스트하기는 어려우나, 로직상 kIsWeb이 true면 변환 안 됨
    // test('should keep localhost on web platforms', () { ... });
  });

  group('ApiClient GET requests', () {
    setUp(() {
      // GET 테스트는 동일한 baseUrl 사용 가정
      apiClient = ApiClient(client: mockClient, baseUrl: testBaseUrl);
    });

    test(
      'returns data if the http call completes successfully (200)',
      () async {
        final uri = Uri.parse('$testBaseUrl/test');
        final expectedResponse = {'key': 'value'};
        when(mockClient.get(uri, headers: anyNamed('headers'))).thenAnswer(
          (_) async => http.Response(jsonEncode(expectedResponse), 200),
        );

        final result = await apiClient.get('/test');

        expect(result, equals(expectedResponse));
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test(
      'returns empty map for successful response with empty body (204)',
      () async {
        final uri = Uri.parse('$testBaseUrl/empty');
        when(
          mockClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('', 204)); // No Content

        final result = await apiClient.get('/empty');

        expect(result, isEmpty);
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test(
      'returns map with message for successful response with non-JSON body (200)',
      () async {
        final uri = Uri.parse('$testBaseUrl/text');
        const textResponse = 'OK';
        when(
          mockClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response(textResponse, 200));

        final result = await apiClient.get('/text');

        expect(result, equals({'message': textResponse, 'statusCode': 200}));
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test(
      'throws an exception if the http call completes with a server error (500)',
      () async {
        final uri = Uri.parse('$testBaseUrl/test');
        when(
          mockClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('Server error', 500));

        expect(() => apiClient.get('/test'), throwsException);
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );
    test(
      'throws exception with parsed message for error response with JSON body (400)',
      () async {
        final uri = Uri.parse('$testBaseUrl/json_error');
        final errorJson = {'message': 'Invalid request parameter'};
        when(
          mockClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response(jsonEncode(errorJson), 400));

        expect(
          () => apiClient.get('/json_error'),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains('Invalid request parameter'),
            ),
          ),
        );
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test(
      'throws exception with generic message for error response with non-JSON body (500)',
      () async {
        final uri = Uri.parse('$testBaseUrl/text_error');
        when(mockClient.get(uri, headers: anyNamed('headers'))).thenAnswer(
          (_) async => http.Response('Internal Server Error Text', 500),
        );

        expect(
          () => apiClient.get('/text_error'),
          throwsA(
            predicate(
              (e) => e is Exception && e.toString().contains('서버 오류 (500)'),
            ),
          ),
        );
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test('correctly handles query parameters', () async {
      final queryParams = {'param1': 'value1', 'param2': 'value2'};
      // Uri.replace는 Map<String, dynamic>을 받으므로 String으로 변환 불필요
      final uri = Uri.parse(
        '$testBaseUrl/query',
      ).replace(queryParameters: queryParams);
      when(
        mockClient.get(uri, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('{}', 200)); // 빈 JSON 응답

      await apiClient.get('/query', queryParams: queryParams);

      verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
    });
  });

  group('ApiClient POST requests', () {
    setUp(() {
      apiClient = ApiClient(client: mockClient, baseUrl: testBaseUrl);
    });
    final testBody = {'data': 'test'};
    final encodedBody = jsonEncode(testBody);

    test('sends correct body and returns data on success (201)', () async {
      final uri = Uri.parse('$testBaseUrl/post_test');
      final expectedResponse = {'id': 1};
      when(
        mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode(expectedResponse), 201),
      );

      final result = await apiClient.post('/post_test', body: testBody);

      expect(result, equals(expectedResponse));
      verify(
        mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
      ).called(1);
    });

    test('throws an exception on server error (400)', () async {
      final uri = Uri.parse('$testBaseUrl/post_test');
      when(
        mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
      ).thenAnswer((_) async => http.Response('Bad Request', 400));

      expect(
        () => apiClient.post('/post_test', body: testBody),
        throwsException,
      );
      verify(
        mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
      ).called(1);
    });
  });
}
