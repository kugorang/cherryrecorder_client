import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cherryrecorder_client/core/network/api_client.dart'; // 실제 ApiClient 경로

// Mockito 코드 생성을 위한 어노테이션 (http.Client 모의 객체 생성)
@GenerateMocks([http.Client])
import 'api_client_test.mocks.dart'; // 생성될 모의 객체 파일

void main() {
  late MockClient mockClient;
  late ApiClient apiClient;
  const String testBaseUrl = 'http://localhost:8080';
  const String expectedBaseUrl = 'http://10.0.2.2:8080'; // 안드로이드 변환 주소

  setUp(() {
    mockClient = MockClient();
    // Provide the base URL during ApiClient initialization
    apiClient = ApiClient(baseUrl: testBaseUrl, client: mockClient);
  });

  group('ApiClient GET requests', () {
    test(
      'returns data if the http call completes successfully (200)',
      () async {
        // Arrange
        final uri = Uri.parse('$expectedBaseUrl/test');
        final expectedResponse = {'key': 'value'};
        when(mockClient.get(uri, headers: anyNamed('headers'))).thenAnswer(
          (_) async => http.Response(jsonEncode(expectedResponse), 200),
        );

        // Act
        final result = await apiClient.get('/test');

        // Assert
        expect(result, equals(expectedResponse));
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test(
      'throws an exception if the http call completes with a server error (500)',
      () async {
        // Arrange
        final uri = Uri.parse('$expectedBaseUrl/test');
        when(
          mockClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('Server error', 500));

        // Act & Assert
        expect(() => apiClient.get('/test'), throwsException);
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );

    test(
      'throws an exception if the http call results in a network error',
      () async {
        // Arrange
        final uri = Uri.parse('$expectedBaseUrl/test');
        when(mockClient.get(uri, headers: anyNamed('headers'))).thenThrow(
          const SocketException('Network error'),
        ); // Simulate a network error

        // Act & Assert
        expect(() => apiClient.get('/test'), throwsA(isA<Exception>()));
        verify(mockClient.get(uri, headers: anyNamed('headers'))).called(1);
      },
    );
  });

  group('ApiClient POST requests', () {
    final Map<String, dynamic> testBody = {'data': 'test'};
    final String encodedBody = jsonEncode(testBody);

    test(
      'returns data if the http call completes successfully (201)',
      () async {
        // Arrange
        final uri = Uri.parse('$expectedBaseUrl/test');
        final expectedResponse = {'id': 1, 'data': 'test'};
        when(
          mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode(expectedResponse), 201),
        );

        // Act
        final result = await apiClient.post('/test', body: testBody);

        // Assert
        expect(result, equals(expectedResponse));
        verify(
          mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
        ).called(1);
      },
    );

    test(
      'throws an exception if the http call completes with a server error (400)',
      () async {
        // Arrange
        final uri = Uri.parse('$expectedBaseUrl/test');
        when(
          mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
        ).thenAnswer((_) async => http.Response('Bad request', 400));

        // Act & Assert
        expect(() => apiClient.post('/test', body: testBody), throwsException);
        verify(
          mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
        ).called(1);
      },
    );

    test(
      'throws an exception if the http call results in a network error',
      () async {
        // Arrange
        final uri = Uri.parse('$expectedBaseUrl/test');
        when(
          mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
        ).thenThrow(
          const SocketException('Network error'),
        ); // Simulate network error

        // Act & Assert
        expect(
          () => apiClient.post('/test', body: testBody),
          throwsA(isA<Exception>()),
        );
        verify(
          mockClient.post(uri, headers: anyNamed('headers'), body: encodedBody),
        ).called(1);
      },
    );
  });
}
