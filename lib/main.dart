import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/place_details/presentation/providers/place_detail_view_model.dart';
import 'features/chat/presentation/providers/chat_view_model.dart';
import 'features/map/presentation/providers/map_view_model.dart'; // MapViewModel 임포트
// dotenv import 제거
import 'app.dart'; // CherryRecorderApp 임포트
import 'package:logger/logger.dart';
import 'core/services/google_maps_service.dart'; // GoogleMapsService 임포트
// import 'package:flutter/services.dart'; // 앱 라이프사이클 불필요
// import 'core/services/storage_service.dart'; // StorageService 임포트 불필요

final logger = Logger();

// --dart-define=APP_ENV=dev 또는 --dart-define=APP_ENV=prod 로 빌드 시 주입
const String environment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);

/// 애플리케이션 메인 진입점 (단일 진입점)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // // 앱 종료 시 리소스 정리 (Hive 박스 닫기) - 더 이상 필요 없음
  // SystemChannels.lifecycle.setMessageHandler((msg) async {
  //   if (msg == AppLifecycleState.detached.toString()) {
  //     await StorageService.instance.closeBoxes();
  //     logger.i('앱 종료: 리소스 정리 완료');
  //   }
  //   return null;
  // });

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
  // Android API 키는 네이티브에서 처리

  // dotenv 로드 로직 완전 제거

  try {
    if (kIsWeb && webMapsApiKey.isEmpty) {
      logger.w('웹 환경에서 WEB_MAPS_API_KEY가 --dart-define으로 전달되지 않았습니다.');
      // 치명적 오류로 간주하고 앱 실행 중단 또는 기본값 사용 결정 필요
      // runApp(ErrorApp('웹 API 키가 설정되지 않았습니다.'));
      // return;
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
          ChangeNotifierProvider(
            create: (_) => MapViewModel(),
          ), // MapViewModel 추가
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

// // 간단한 오류 표시 앱 (예시)
// class ErrorApp extends StatelessWidget {
//   final String message;
//   const ErrorApp(this.message, {super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         body: Center(child: Text(message)),
//       ),
//     );
//   }
// }
