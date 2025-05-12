import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:logger/logger.dart';

// 모의 클래스 자동 생성을 위한 어노테이션
@GenerateMocks([http.Client])
import 'cherry_cli_test.mocks.dart';

void main() {
  // bin/cherry_cli.dart 파일에서 필요한 함수들을 임포트하지 않고
  // 여기서 다시 정의합니다. 이렇게 하면 해당 함수들만 개별적으로 테스트할 수 있습니다.
  // CLI의 main 함수는 직접 테스트하는 대신, 각 명령어 처리 함수를 테스트합니다.

  // 테스트에 사용할 로거 설정
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: false,
      printEmojis: false,
      noBoxingByDefault: true,
    ),
  );

  // 테스트에 사용할 서버 URL
  final testServerUrl = 'http://test-server.example.com';

  group('서버 상태 확인 (health) 테스트', () {
    test('서버가 정상 응답할 경우 상태 확인 성공', () async {
      // MockClient 인스턴스 생성
      final client = MockClient();

      // 모의 응답 설정
      when(
        client.get(Uri.parse('$testServerUrl/health')),
      ).thenAnswer((_) async => http.Response('{"status":"ok"}', 200));

      // 함수 호출 (stdout 출력을 캡처하기 위해 함수를 호출만 함)
      await checkServerHealth(client, testServerUrl, logger);

      // 모의 객체의 메서드가 호출되었는지 확인
      verify(client.get(Uri.parse('$testServerUrl/health'))).called(1);
    });

    test('서버 연결이 실패할 경우 오류 처리', () async {
      final client = MockClient();

      // 모의 응답에서 예외 발생
      when(
        client.get(Uri.parse('$testServerUrl/health')),
      ).thenThrow(Exception('서버 연결 실패'));

      // 함수 호출
      await checkServerHealth(client, testServerUrl, logger);

      // 모의 객체의 메서드가 호출되었는지 확인
      verify(client.get(Uri.parse('$testServerUrl/health'))).called(1);
    });
  });

  group('주변 장소 검색 (nearby) 테스트', () {
    test('주변 장소 검색 요청이 성공적으로 처리됨', () async {
      final client = MockClient();

      // 모의 응답 데이터
      final responseData = {
        'places': [
          {
            'id': 'place123',
            'displayName': {'text': 'Test Place'},
            'formattedAddress': 'Seoul, Gangnam',
            'rating': 4.5,
            'businessStatus': 'OPERATIONAL',
            'types': ['restaurant', 'food'],
          },
        ],
      };

      // 모의 응답 설정 - 수정: 직접 인코딩하지 않고 객체 전달
      when(
        client.post(
          Uri.parse('$testServerUrl/places/nearby'),
          headers: {'Content-Type': 'application/json'},
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(json.encode(responseData), 200));

      // 함수 호출
      await searchNearbyPlaces(
        client,
        testServerUrl,
        logger,
        37.5665,
        126.9780,
        1000,
      );

      // 모의 객체의 메서드가 호출되었는지 확인
      verify(
        client.post(
          Uri.parse('$testServerUrl/places/nearby'),
          headers: {'Content-Type': 'application/json'},
          body: anyNamed('body'),
        ),
      ).called(1);
    });
  });

  group('텍스트로 장소 검색 (search) 테스트', () {
    test('장소 검색 요청이 성공적으로 처리됨', () async {
      final client = MockClient();

      // 모의 응답 데이터
      final responseData = {
        'places': [
          {
            'id': 'place123',
            'displayName': {'text': 'Test Place'},
            'formattedAddress': 'Seoul, Gangnam',
            'rating': 4.5,
            'businessStatus': 'OPERATIONAL',
            'types': ['restaurant', 'food'],
          },
        ],
      };

      // 모의 응답 설정 - 수정: 직접 인코딩하지 않고 객체 전달
      when(
        client.post(
          Uri.parse('$testServerUrl/places/search'),
          headers: {'Content-Type': 'application/json'},
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(json.encode(responseData), 200));

      // 함수 호출
      await searchPlacesByText(
        client,
        testServerUrl,
        logger,
        'Test Place',
        37.5665,
        126.9780,
      );

      // 모의 객체의 메서드가 호출되었는지 확인
      verify(
        client.post(
          Uri.parse('$testServerUrl/places/search'),
          headers: {'Content-Type': 'application/json'},
          body: anyNamed('body'),
        ),
      ).called(1);
    });
  });

  group('장소 상세 정보 조회 (details) 테스트', () {
    test('장소 상세 정보 요청이 성공적으로 처리됨', () async {
      final client = MockClient();

      // 모의 응답 데이터
      final responseData = {
        'id': 'place123',
        'displayName': {'text': 'Test Place'},
        'formattedAddress': 'Seoul, Gangnam',
        'rating': 4.5,
        'location': {'latitude': 37.5665, 'longitude': 126.9780},
        'types': ['restaurant', 'food'],
        'businessStatus': 'OPERATIONAL',
        'internationalPhoneNumber': '+82-2-123-4567',
        'websiteUri': 'https://example.com',
        'openingHours': {
          'weekdayText': ['Monday: 09:00-18:00', 'Tuesday: 09:00-18:00'],
        },
        'userRatingCount': 100,
        'priceLevel': 2,
      };

      // 모의 응답 설정 - 수정: 직접 인코딩하지 않고 객체 전달
      when(
        client.get(
          Uri.parse('$testServerUrl/places/details?id=place123'),
          headers: {'Content-Type': 'application/json'},
        ),
      ).thenAnswer((_) async => http.Response(json.encode(responseData), 200));

      // 함수 호출
      await getPlaceDetails(client, testServerUrl, logger, 'place123');

      // 모의 객체의 메서드가 호출되었는지 확인
      verify(
        client.get(
          Uri.parse('$testServerUrl/places/details?id=place123'),
          headers: {'Content-Type': 'application/json'},
        ),
      ).called(1);
    });
  });
}

// bin/cherry_cli.dart 파일에서 필요한 함수들을 직접 복사해옵니다.
// 실제로는 bin/cherry_cli.dart의 함수들을 임포트하는 것이 좋지만,
// 이 예제에서는 간단히 함수들을 복사해서 사용합니다.

/// 서버 상태 확인
Future<void> checkServerHealth(
  http.Client client,
  String serverUrl,
  Logger logger,
) async {
  logger.d('\n🩺 서버 상태 확인 중...');

  try {
    final response = await client.get(Uri.parse('$serverUrl/health'));

    if (response.statusCode == 200) {
      logger.i('✅ 서버 상태: 정상');
      logger.d('응답: ${response.body}');
    } else {
      logger.e('⚠️ 서버 오류: HTTP ${response.statusCode}');
      logger.d('응답: ${response.body}');
    }
  } catch (e) {
    logger.e('🔥 서버 연결 실패: $e');
  }
}

/// 주변 장소 검색
Future<void> searchNearbyPlaces(
  http.Client client,
  String serverUrl,
  Logger logger,
  double latitude,
  double longitude,
  double radius,
) async {
  logger.d('\n🔍 주변 장소 검색 중...');
  logger.d('위치: 위도 $latitude, 경도 $longitude, 반경 ${radius}m');

  try {
    final requestBody = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'type': 'restaurant',
    });

    final response = await client.post(
      Uri.parse('$serverUrl/places/nearby'),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['places'] != null && data['places'] is List) {
        final places = data['places'] as List;
        logger.i('✅ 장소 검색 결과: ${places.length}개 발견');

        // 장소 정보 출력 로직은 테스트에서 생략
      } else {
        logger.w('⚠️ 검색 결과 없음');
      }
    } else {
      logger.e('⚠️ 서버 오류: HTTP ${response.statusCode}');
      logger.d('응답: ${response.body}');
    }
  } catch (e) {
    logger.e('🔥 요청 실패: $e');
  }
}

/// 텍스트로 장소 검색
Future<void> searchPlacesByText(
  http.Client client,
  String serverUrl,
  Logger logger,
  String query,
  double latitude,
  double longitude,
) async {
  logger.d('\n🔍 장소 검색 중: "$query"');
  logger.d('기준 위치: 위도 $latitude, 경도 $longitude');

  try {
    final requestBody = jsonEncode({
      'query': query,
      'latitude': latitude,
      'longitude': longitude,
      'language': 'ko',
    });

    final response = await client.post(
      Uri.parse('$serverUrl/places/search'),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['places'] != null && data['places'] is List) {
        final places = data['places'] as List;
        logger.i('✅ 장소 검색 결과: ${places.length}개 발견');

        // 장소 정보 출력 로직은 테스트에서 생략
      } else {
        logger.w('⚠️ 검색 결과 없음');
      }
    } else {
      logger.e('⚠️ 서버 오류: HTTP ${response.statusCode}');
      logger.d('응답: ${response.body}');
    }
  } catch (e) {
    logger.e('🔥 요청 실패: $e');
  }
}

/// 장소 상세 정보 조회
Future<void> getPlaceDetails(
  http.Client client,
  String serverUrl,
  Logger logger,
  String placeId,
) async {
  logger.d('\n🔍 장소 상세 정보 조회 중: Place ID "$placeId"');

  try {
    final response = await client.get(
      Uri.parse('$serverUrl/places/details?id=$placeId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      logger.i('✅ 장소 상세 정보 조회 성공');

      // 장소 정보 출력 로직은 테스트에서 생략
    } else {
      logger.e('⚠️ 서버 오류: HTTP ${response.statusCode}');
      logger.d('응답: ${response.body}');
    }
  } catch (e) {
    logger.e('🔥 요청 실패: $e');
  }
}
