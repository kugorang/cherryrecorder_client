/// Flutter 애플리케이션의 메인 진입점 파일입니다.
///
/// 이 파일은 다음의 역할을 수행합니다:
/// 1. 앱 환경(development, production)을 설정합니다.
/// 2. 플랫폼별(웹, 안드로이드) API 기본 URL 및 API 키를 설정합니다.
/// 3. 핵심 서비스인 `GoogleMapsService`를 초기화합니다.
/// 4. `Provider`를 사용하여 앱 전역에서 사용될 ViewModel들을 설정합니다.
/// 5. 앱의 루트 위젯인 `CherryRecorderApp`을 실행합니다.
/// 6. 앱 초기화 과정에서 발생하는 모든 예외를 처리하고, 오류 발생 시 간단한 오류 화면을 표시합니다.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/place_details/presentation/providers/place_detail_view_model.dart';
import 'features/chat/presentation/providers/chat_view_model.dart';
import 'features/map/presentation/providers/map_view_model.dart';
import 'app.dart';
import 'package:logger/logger.dart';
import 'core/services/google_maps_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 전역에서 사용될 로거 인스턴스입니다.
final logger = Logger();

/// 앱의 현재 실행 환경을 나타냅니다.
///
/// 빌드 시 `--dart-define=APP_ENV=prod`와 같은 플래그를 통해 값을 주입할 수 있습니다.
/// 기본값은 'dev' (개발 환경)입니다.
const String environment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);

/// Flutter 애플리케이션의 메인 함수이자 시작점입니다.
///
/// 비동기 작업(`async`)으로 선언되어, 앱 실행에 필요한 사전 준비 작업들을
/// 순차적으로 수행한 후 `runApp`을 호출합니다.
Future<void> main() async {
  // Flutter 엔진과 위젯 바인딩을 초기화합니다. runApp 전에 반드시 호출되어야 합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // --- 패키지 정보 확인 ---
  // 앱의 패키지 이름, 버전 등 메타데이터를 확인하여 현재 빌드 Flavor(dev/prod)를 감지합니다.
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;
    final appName = packageInfo.appName;
    logger.i('패키지 이름: $packageName');
    logger.i('앱 이름: $appName');

    // 패키지 이름으로 Flavor 확인
    final isDev = packageName.endsWith('.dev');
    logger.i('현재 Flavor: ${isDev ? "dev" : "prod"}');

    if (!kIsWeb && !isDev && environment == 'dev') {
      logger.w('경고: 환경 설정은 dev이지만 앱은 dev Flavor로 빌드되지 않은 것 같습니다.');
    }
  } catch (e) {
    logger.e('패키지 정보 확인 중 오류: $e');
  }

  // --- 환경 변수 로드 ---
  // --dart-define을 통해 주입된 API 키 값을 로드합니다.
  // API URL은 이제 GoogleMapsService 내부에서 API_BASE_URL 환경 변수를 직접 읽습니다.
  const webMapsApiKey = String.fromEnvironment('WEB_MAPS_API_KEY');

  try {
    if (kIsWeb && webMapsApiKey.isEmpty) {
      logger.w('웹 환경에서 WEB_MAPS_API_KEY가 --dart-define으로 전달되지 않았습니다.');
    }

    // --- 핵심 서비스 초기화 ---
    // Google Maps 관련 API 통신을 담당하는 GoogleMapsService를 초기화합니다.
    final mapsService = GoogleMapsService();
    await mapsService.initialize(
      webMapsApiKey: webMapsApiKey,
    );
    logger.i('$environment 환경에서 앱 실행 중');
    logger.i('API Base URL: ${mapsService.getServerUrl()}');

    // --- 앱 실행 ---
    // MultiProvider를 사용하여 앱 전역에서 상태를 관리할 ViewModel들을 제공합니다.
    // 이렇게 제공된 ViewModel들은 앱 내의 어떤 위젯에서든 context를 통해 접근할 수 있습니다.
    runApp(
      MultiProvider(
        providers: [
          // 앱의 핵심 로직을 담당하는 서비스는 Provider.value로 제공합니다.
          Provider<GoogleMapsService>.value(value: mapsService),
          // UI 상태 변경을 알리는 ViewModel들은 ChangeNotifierProvider로 제공합니다.
          ChangeNotifierProvider(create: (_) => MapViewModel()),
          ChangeNotifierProvider(create: (_) => PlaceDetailViewModel()),
          ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ],
        child: const CherryRecorderApp(),
      ),
    );
  } catch (e, stackTrace) {
    // --- 예외 처리 ---
    // 초기화 과정에서 오류가 발생하면, 앱을 중단시키지 않고
    // 사용자에게 오류 내용을 보여주는 간단한 화면을 표시합니다.
    logger.e('앱 초기화 중 오류 발생 ($environment)', error: e, stackTrace: stackTrace);
    runApp(
      MaterialApp(
        // 간단한 오류 표시 앱
        home: Scaffold(
          body: Center(child: Text('앱 초기화 오류 ($environment): $e')),
        ),
      ),
    );
  }
}
