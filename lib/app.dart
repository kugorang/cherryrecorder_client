/// 앱의 루트 위젯과 전반적인 테마, 라우팅 설정을 담당하는 파일입니다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'test_api_connection.dart'; // 테스트 스크린 임포트
import 'features/map/presentation/screens/map_screen.dart'; // 맵 스크린 임포트
import 'features/place_details/presentation/screens/place_detail_screen.dart'; // 상세 스크린 임포트 추가
import 'features/place_details/presentation/screens/memos_by_tag_screen.dart'; // 태그별 메모 스크린 임포트 추가
import 'features/chat/presentation/screens/chat_screen.dart'; // 채팅 스크린 임포트 추가
import 'package:logger/logger.dart';
import 'core/services/storage_service.dart'; // 스토리지 서비스 추가
import 'core/models/memo.dart'; // Memo 모델 임포트 추가

/// `CherryRecorderApp`은 애플리케이션의 최상위 상태 관리 위젯입니다.
///
/// `StatefulWidget`으로 구현되어 앱의 생명주기(life-cycle) 동안
/// 필요한 초기화 작업을 수행합니다.
class CherryRecorderApp extends StatefulWidget {
  /// 기본 생성자입니다.
  const CherryRecorderApp({super.key});

  @override
  State<CherryRecorderApp> createState() => _CherryRecorderAppState();
}

/// `CherryRecorderApp`의 상태를 관리하는 `State` 클래스입니다.
class _CherryRecorderAppState extends State<CherryRecorderApp> {
  /// 로컬 데이터 저장을 위한 서비스입니다.
  ///
  /// `_initializeStorageService` 메서드를 통해 비동기적으로 초기화됩니다.
  late Logger _logger;
  bool _storageInitialized = false;

  @override
  void initState() {
    super.initState();
    // 앱의 시스템 UI 스타일(상태바 등)을 설정합니다.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 상태바 배경을 투명하게 설정
        statusBarIconBrightness: Brightness.dark, // 상태바 아이콘을 어둡게 설정
      ),
    );

    // 디바이스의 화면 방향을 세로로 고정합니다.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _logger = Logger();

    // 로컬 스토리지 서비스를 비동기적으로 초기화합니다.
    _initializeStorageService();
  }

  /// 로컬 스토리지 서비스(`StorageService`)를 초기화합니다.
  ///
  /// 초기화가 완료되면 `_storageInitialized` 상태를 `true`로 변경하여
  /// `build` 메서드가 메인 앱 UI를 그리도록 합니다.
  Future<void> _initializeStorageService() async {
    try {
      _logger.d('스토리지 서비스 초기화 시작');
      await StorageService.instance.initialize();
      if (mounted) {
        // 위젯이 여전히 마운트 상태인지 확인
        setState(() {
          _storageInitialized = true;
        });
      }
      _logger.d('스토리지 서비스 초기화 완료: $_storageInitialized');
    } catch (e) {
      _logger.e('스토리지 서비스 초기화 오류: $e');
      // 사용자에게 오류를 알리는 로직 추가 가능
      if (mounted) {
        setState(() {
          // 초기화 실패 상태 표시 (선택적)
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 앱의 전반적인 디자인 테마를 정의합니다.
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFDE3B3B), // 체리색
        primary: const Color(0xFFDE3B3B),
        secondary: const Color(0xFF45AD4F), // 잎 색상 (녹색)
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDE3B3B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
      ),
    );

    // 스토리지 초기화 상태에 따라 다른 화면 표시
    if (!_storageInitialized) {
      // 초기화 중 로딩 화면 표시
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('데이터를 준비 중입니다...'),
              ],
            ),
          ),
        ),
      );
    }

    // 초기화 완료 후 메인 앱 UI 빌드
    return MaterialApp(
      title: '체리 레코더',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // 웹 특화 설정
      scrollBehavior: kIsWeb
          ? ScrollConfiguration.of(context).copyWith(
              physics: const ClampingScrollPhysics(), // 바운스 스크롤 방지
              dragDevices: {
                // 웹에서 드래그 가능 디바이스 설정
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            )
          : null,
      home: const SplashScreen(), // home 속성 사용
      onGenerateRoute: _generateRoute, // 커스텀 라우트 생성기 추가
    );
  }

  /// 동적으로 라우트를 생성하고 페이지 전환 애니메이션을 관리합니다.
  ///
  /// [settings]에는 `pushNamed`로 전달된 라우트 이름(`name`)과
  /// 인자(`arguments`)가 포함됩니다.
  ///
  /// 정의된 경로에 따라 적절한 화면 위젯을 생성하고,
  /// `PageRouteBuilder`를 사용하여 모든 페이지 전환에 일관된
  /// 슬라이드 애니메이션을 적용합니다.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    debugPrint('라우트 생성: ${settings.name}');

    Widget page;
    try {
      switch (settings.name) {
        case '/':
          page = const SplashScreen();
          break;
        case '/test':
          page = const ApiConnectionTest();
          break;
        case '/map':
          page = const MapScreen();
          break;
        case '/chat':
          page = const ChatScreen();
          break;
        case '/place_detail':
          _logger.d(
            'Arguments type for /place_detail: ${settings.arguments?.runtimeType}',
          );
          // Map으로 전달된 데이터를 처리
          if (settings.arguments is Map<String, dynamic>) {
            final placeData = settings.arguments as Map<String, dynamic>;
            page = PlaceDetailScreen(placeData: placeData);
          } else {
            // 타입이 일치하지 않는 경우 오류 처리
            _logger.e(
              'Invalid arguments type for /place_detail: Expected Map<String, dynamic>, got ${settings.arguments?.runtimeType}',
            );
            page = Scaffold(
              appBar: AppBar(title: const Text('오류')),
              body: const Center(child: Text('잘못된 장소 정보입니다.')),
            );
          }
          break;
        case '/memos_by_tag':
          // 태그별 메모 화면
          if (settings.arguments is String) {
            final tag = settings.arguments as String;
            page = MemosByTagScreen(
              tag: tag,
            );
          } else {
            _logger.e(
              'Invalid arguments type for /memos_by_tag: Expected String, got ${settings.arguments?.runtimeType}',
            );
            page = Scaffold(
              appBar: AppBar(title: const Text('오류')),
              body: const Center(child: Text('잘못된 태그 정보입니다.')),
            );
          }
          break;
        default:
          // 정의되지 않은 경로 처리
          _logger.w('정의되지 않은 라우트 요청: ${settings.name}');
          page = Scaffold(
            appBar: AppBar(title: const Text('오류')),
            body: Center(child: Text('잘못된 경로입니다: ${settings.name}')),
          );
      }
    } catch (e) {
      // 캐스팅 오류 또는 기타 라우팅 오류 처리
      _logger.e('라우트 생성 중 오류 발생 (${settings.name}): $e');
      page = Scaffold(
        appBar: AppBar(title: const Text('오류')),
        body: Center(child: Text('페이지를 로드할 수 없습니다.\n오류: $e')),
      );
    }

    // 웹과 앱 모두에서 일관된 페이지 전환 애니메이션 적용
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
