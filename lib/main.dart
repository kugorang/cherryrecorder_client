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

final logger = Logger();

/// 앱 환경 설정 (dev 또는 prod)
/// --dart-define=APP_ENV=dev 또는 --dart-define=APP_ENV=prod 로 빌드 시 주입
const String environment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);

/// 애플리케이션 메인 진입점
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 현재 Flavor 및 패키지 정보 확인 ---
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

  // --- 환경 변수 읽기 (--dart-define 사용) ---
  const webApiBaseUrl = String.fromEnvironment(
    'WEB_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  const androidApiBaseUrl = String.fromEnvironment(
    'ANDROID_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  const webMapsApiKey = String.fromEnvironment('WEB_MAPS_API_KEY');

  try {
    if (kIsWeb && webMapsApiKey.isEmpty) {
      logger.w('웹 환경에서 WEB_MAPS_API_KEY가 --dart-define으로 전달되지 않았습니다.');
    }

    // --- GoogleMapsService 초기화 ---
    final mapsService = GoogleMapsService();
    await mapsService.initialize(
      webApiBaseUrl: webApiBaseUrl,
      androidApiBaseUrl: androidApiBaseUrl,
      webMapsApiKey: webMapsApiKey,
    );

    logger.i('$environment 환경에서 앱 실행 중');
    logger.i('API Base URL (Web): ${mapsService.getServerUrl(isWeb: true)}');
    logger.i(
      'API Base URL (Android): ${mapsService.getServerUrl(isWeb: false)}',
    );

    // 앱 실행 (Provider 설정과 함께)
    runApp(
      MultiProvider(
        providers: [
          Provider<GoogleMapsService>.value(value: mapsService),
          ChangeNotifierProvider(create: (_) => MapViewModel()),
          ChangeNotifierProvider(create: (_) => PlaceDetailViewModel()),
          ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ],
        child: const CherryRecorderApp(),
      ),
    );
  } catch (e, stackTrace) {
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
