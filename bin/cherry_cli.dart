import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:args/args.dart';

/// CherryRecorder 서버와 통신하는 CLI 클라이언트
/// 데모용으로 제작된 간단한 CLI 인터페이스
void main(List<String> arguments) async {
  // 로거 설정 - ConsoleOutput 명시적으로 사용
  final logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      noBoxingByDefault: true,
    ),
    output: ConsoleOutput(),
    level: Level.trace, // 'verbose' 대신 'trace' 사용
  );

  // 명령줄 인자 파서 설정
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: '도움말 표시', negatable: false)
    ..addCommand(
      'health',
      ArgParser()..addFlag('help', abbr: 'h', help: '도움말 표시', negatable: false),
    )
    ..addCommand(
      'nearby',
      ArgParser()
        ..addOption('lat', help: '위도', defaultsTo: '37.5665')
        ..addOption('lng', help: '경도', defaultsTo: '126.9780')
        ..addOption('radius', help: '검색 반경 (미터)', defaultsTo: '1000')
        ..addFlag('help', abbr: 'h', help: '도움말 표시', negatable: false),
    )
    ..addCommand(
      'search',
      ArgParser()
        ..addOption('query', help: '검색어', mandatory: true)
        ..addOption('lat', help: '위도', defaultsTo: '37.5665')
        ..addOption('lng', help: '경도', defaultsTo: '126.9780')
        ..addFlag('help', abbr: 'h', help: '도움말 표시', negatable: false),
    )
    ..addCommand(
      'details',
      ArgParser()
        ..addOption('id', help: '장소 ID', mandatory: true)
        ..addFlag('help', abbr: 'h', help: '도움말 표시', negatable: false),
    )
    ..addOption(
      'server',
      help: '서버 URL',
      defaultsTo: 'http://localhost:8080',
      abbr: 's',
    );

  // 사용법 출력 함수
  void printGlobalUsage() {
    logger.d('''
┌─────────────────────────────────────────────────┐
│         CherryRecorder CLI 클라이언트           │
└─────────────────────────────────────────────────┘

CherryRecorder 서버와 통신하는 Dart 기반 CLI 클라이언트입니다.
이 도구는 장소 정보를 검색하고 관리하는 기능을 제공합니다.

사용법:
  dart bin/cherry_cli.dart [옵션] <명령어> [명령어 옵션]

기본 옵션:
  --server, -s   서버 URL (기본값: http://localhost:8080)
  --help, -h     도움말 표시

지원 명령어:
  health       서버 상태 확인
  nearby       주변 장소 검색
  search       텍스트로 장소 검색
  details      장소 상세 정보 조회

각 명령에 대한 자세한 정보:
  dart bin/cherry_cli.dart <명령어> --help

예제:
  dart bin/cherry_cli.dart health
  dart bin/cherry_cli.dart nearby --lat 37.5665 --lng 126.9780 --radius 1000
  dart bin/cherry_cli.dart search --query "서울역"
  dart bin/cherry_cli.dart details --id "ChIJ1wtAEOmLGGARVCFZ0ctyOvI"
''');
  }

  void printHealthUsage() {
    logger.d('''
┌─────────────────────────────────────────────────┐
│          서버 상태 확인 (health) 명령           │
└─────────────────────────────────────────────────┘

서버가 정상적으로 작동 중인지 확인합니다.
HTTP 상태 코드와 응답 메시지를 통해 서버 상태를 표시합니다.

사용법:
  dart bin/cherry_cli.dart [--server URL] health

옵션:
  --help, -h     도움말 표시

예제:
  dart bin/cherry_cli.dart health
  dart bin/cherry_cli.dart --server http://example.com:8080 health
''');
  }

  void printNearbyUsage() {
    logger.d('''
┌─────────────────────────────────────────────────┐
│          주변 장소 검색 (nearby) 명령           │
└─────────────────────────────────────────────────┘

지정된 위치(위도, 경도) 주변의 장소를 검색합니다.
검색 반경 내의 장소 목록을 표시합니다.

사용법:
  dart bin/cherry_cli.dart [--server URL] nearby [옵션]

옵션:
  --lat          위도 (기본값: 37.5665, 서울)
  --lng          경도 (기본값: 126.9780, 서울)
  --radius       검색 반경(미터) (기본값: 1000)
  --help, -h     도움말 표시

예제:
  dart bin/cherry_cli.dart nearby
  dart bin/cherry_cli.dart nearby --lat 37.5665 --lng 126.9780 --radius 1000
  dart bin/cherry_cli.dart nearby --lat 35.1799 --lng 129.0756 --radius 500
''');
  }

  void printSearchUsage() {
    logger.d('''
┌─────────────────────────────────────────────────┐
│          장소 검색 (search) 명령                │
└─────────────────────────────────────────────────┘

키워드를 기반으로 장소를 검색합니다.
검색 결과 목록과 각 장소의 Place ID를 표시합니다.

사용법:
  dart bin/cherry_cli.dart [--server URL] search --query <검색어> [옵션]

옵션:
  --query        검색어 (필수)
  --lat          검색 기준 위도 (기본값: 37.5665, 서울)
  --lng          검색 기준 경도 (기본값: 126.9780, 서울)
  --help, -h     도움말 표시

예제:
  dart bin/cherry_cli.dart search --query "서울역"
  dart bin/cherry_cli.dart search --query "맛집" --lat 37.5665 --lng 126.9780
''');
  }

  void printDetailsUsage() {
    logger.d('''
┌─────────────────────────────────────────────────┐
│          장소 상세 정보 (details) 명령          │
└─────────────────────────────────────────────────┘

특정 장소의 상세 정보를 조회합니다.
장소의 이름, 주소, 평점, 영업 상태 등의 정보를 표시합니다.

사용법:
  dart bin/cherry_cli.dart [--server URL] details --id <Place ID>

옵션:
  --id           장소 ID (필수)
  --help, -h     도움말 표시

예제:
  dart bin/cherry_cli.dart details --id "ChIJ1wtAEOmLGGARVCFZ0ctyOvI"
''');
  }

  // 인자 파싱
  ArgResults? argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    logger.e('명령어 파싱 오류: $e');
    printGlobalUsage();
    exit(1);
  }

  // 전역 도움말 옵션 확인
  if (argResults['help'] == true) {
    printGlobalUsage();
    exit(0);
  }

  // 명령어 확인
  final command = argResults.command;
  if (command == null) {
    printGlobalUsage();
    exit(0);
  }

  // 각 명령어별 도움말 확인
  if (command['help'] == true) {
    switch (command.name) {
      case 'health':
        printHealthUsage();
        break;
      case 'nearby':
        printNearbyUsage();
        break;
      case 'search':
        printSearchUsage();
        break;
      case 'details':
        printDetailsUsage();
        break;
    }
    exit(0);
  }

  // 서버 URL 설정
  final serverUrl = argResults['server'] as String;
  logger.i('🌐 서버 URL: $serverUrl');

  // HTTP 클라이언트 생성
  final client = http.Client();

  try {
    // 명령어에 따른 처리
    switch (command.name) {
      case 'health':
        await checkServerHealth(client, serverUrl, logger);
        break;
      case 'nearby':
        await searchNearbyPlaces(
          client,
          serverUrl,
          logger,
          double.parse(command['lat']),
          double.parse(command['lng']),
          double.parse(command['radius']),
        );
        break;
      case 'search':
        await searchPlacesByText(
          client,
          serverUrl,
          logger,
          command['query'],
          double.parse(command['lat']),
          double.parse(command['lng']),
        );
        break;
      case 'details':
        await getPlaceDetails(client, serverUrl, logger, command['id']);
        break;
      default:
        logger.e('지원하지 않는 명령어: ${command.name}');
        printGlobalUsage();
        exit(1);
    }
  } catch (e) {
    logger.e('오류 발생: $e');
    exit(1);
  } finally {
    client.close();
  }
}

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

        // 장소 정보 출력
        for (var i = 0; i < places.length; i++) {
          final place = places[i];

          // 서버 응답 형식에 맞게 필드 이름 수정
          if (place['name'] != null) {
            logger.d('\n${i + 1}. ${place['name']}');
          } else if (place['displayName'] != null &&
              place['displayName']['text'] != null) {
            // 이전 형식 지원
            logger.d('\n${i + 1}. ${place['displayName']['text']}');
          } else {
            logger.d('\n${i + 1}. [이름 없음]');
          }

          if (place['vicinity'] != null) {
            logger.d('   주소: ${place['vicinity']}');
          } else if (place['formattedAddress'] != null) {
            // 이전 형식 지원
            logger.d('   주소: ${place['formattedAddress']}');
          }

          if (place['rating'] != null) {
            logger.d('   평점: ${place['rating']}');
          }

          if (place['placeId'] != null) {
            logger.d('   Place ID: ${place['placeId']}');
          } else if (place['id'] != null) {
            // 이전 형식 지원
            logger.d('   Place ID: ${place['id']}');
          }

          if (place['location'] != null) {
            logger.d(
              '   위치: 위도 ${place['location']['latitude']}, 경도 ${place['location']['longitude']}',
            );
          }

          // 추가 정보 표시
          if (place['businessStatus'] != null) {
            logger.d('   영업 상태: ${place['businessStatus']}');
          }

          if (place['types'] != null &&
              place['types'] is List &&
              (place['types'] as List).isNotEmpty) {
            logger.d('   유형: ${(place['types'] as List).join(', ')}');
          }
        }
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
      'language': 'ko', // test_api_connection.dart에서처럼 언어 설정 추가
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

        // 장소 정보 출력
        for (var i = 0; i < places.length; i++) {
          final place = places[i];

          // 서버 응답 형식에 맞게 필드 이름 수정
          if (place['name'] != null) {
            logger.d('\n${i + 1}. ${place['name']}');
          } else if (place['displayName'] != null &&
              place['displayName']['text'] != null) {
            // 이전 형식 지원
            logger.d('\n${i + 1}. ${place['displayName']['text']}');
          } else {
            logger.d('\n${i + 1}. [이름 없음]');
          }

          if (place['vicinity'] != null) {
            logger.d('   주소: ${place['vicinity']}');
          } else if (place['formattedAddress'] != null) {
            // 이전 형식 지원
            logger.d('   주소: ${place['formattedAddress']}');
          }

          if (place['rating'] != null) {
            logger.d('   평점: ${place['rating']}');
          }

          if (place['placeId'] != null) {
            logger.d('   Place ID: ${place['placeId']}');
          } else if (place['id'] != null) {
            // 이전 형식 지원
            logger.d('   Place ID: ${place['id']}');
          }

          if (place['location'] != null) {
            logger.d(
              '   위치: 위도 ${place['location']['latitude']}, 경도 ${place['location']['longitude']}',
            );
          }

          // 추가 정보 표시
          if (place['businessStatus'] != null) {
            logger.d('   영업 상태: ${place['businessStatus']}');
          }

          if (place['types'] != null &&
              place['types'] is List &&
              (place['types'] as List).isNotEmpty) {
            logger.d('   유형: ${(place['types'] as List).join(', ')}');
          }
        }
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
    final requestUrl = '$serverUrl/places/details/$placeId';

    final response = await client.get(
      Uri.parse(requestUrl),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      logger.i('✅ 장소 상세 정보 조회 성공');

      // 장소 정보 출력 - API 응답 형식에 맞게 수정
      if (data['name'] != null) {
        logger.d('\n🏢 ${data['name']}');
      } else if (data['displayName'] != null &&
          data['displayName']['text'] != null) {
        logger.d('\n🏢 ${data['displayName']['text']}');
      } else {
        logger.d('\n🏢 [이름 없음]');
      }

      if (data['vicinity'] != null) {
        logger.d('📍 주소: ${data['vicinity']}');
      } else if (data['formattedAddress'] != null) {
        logger.d('📍 주소: ${data['formattedAddress']}');
      }

      if (data['rating'] != null) {
        logger.d('⭐ 평점: ${data['rating']}');
      }

      if (data['location'] != null) {
        logger.d(
          '🌐 위치: 위도 ${data['location']['latitude']}, 경도 ${data['location']['longitude']}',
        );
      }

      if (data['types'] != null && data['types'] is List) {
        logger.d('🏷️ 유형: ${(data['types'] as List).join(', ')}');
      }

      if (data['businessStatus'] != null) {
        logger.d('📊 영업 상태: ${data['businessStatus']}');
      }

      if (data['internationalPhoneNumber'] != null) {
        logger.d('📞 전화번호: ${data['internationalPhoneNumber']}');
      } else if (data['formatted_phone_number'] != null) {
        logger.d('📞 전화번호: ${data['formatted_phone_number']}');
      }

      if (data['websiteUri'] != null) {
        logger.d('🌐 웹사이트: ${data['websiteUri']}');
      } else if (data['website'] != null) {
        logger.d('🌐 웹사이트: ${data['website']}');
      }

      // 영업시간 정보 처리
      if (data['openingHours'] != null &&
          data['openingHours']['weekdayText'] is List) {
        logger.d('\n⏰ 영업시간:');
        for (var hours in data['openingHours']['weekdayText']) {
          logger.d('   $hours');
        }
      } else if (data['opening_hours'] != null &&
          data['opening_hours']['weekday_text'] is List) {
        logger.d('\n⏰ 영업시간:');
        for (var hours in data['opening_hours']['weekday_text']) {
          logger.d('   $hours');
        }
      }

      if (data['userRatingCount'] != null) {
        logger.d('👥 평가 수: ${data['userRatingCount']}');
      } else if (data['user_ratings_total'] != null) {
        logger.d('👥 평가 수: ${data['user_ratings_total']}');
      }

      if (data['priceLevel'] != null) {
        String priceLevel = '';
        final level = data['priceLevel'] as int;
        for (int i = 0; i < level; i++) {
          priceLevel += '💲';
        }
        logger.d('💰 가격대: $priceLevel');
      } else if (data['price_level'] != null) {
        String priceLevel = '';
        final level = data['price_level'] as int;
        for (int i = 0; i < level; i++) {
          priceLevel += '💲';
        }
        logger.d('💰 가격대: $priceLevel');
      }
    } else {
      logger.e('⚠️ 서버 오류: HTTP ${response.statusCode}');
      logger.d('응답: ${response.body}');
      logger.w('ℹ️ 참고: 장소 상세 정보 API가 현재 서버에서 지원되지 않을 수 있습니다.');
      logger.w('ℹ️ 데모 중에는 "nearby"와 "search" 명령어를 사용하는 것이 좋습니다.');
    }
  } catch (e) {
    logger.e('🔥 요청 실패: $e');
    logger.w('ℹ️ 참고: 장소 상세 정보 API가 현재 서버에서 지원되지 않을 수 있습니다.');
    logger.w('ℹ️ 데모 중에는 "nearby"와 "search" 명령어를 사용하는 것이 좋습니다.');
  }
}
