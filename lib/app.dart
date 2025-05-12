import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'test_api_connection.dart'; // 테스트 스크린 임포트
import 'features/map/presentation/screens/map_screen.dart'; // 맵 스크린 임포트
import 'features/place_details/presentation/screens/place_detail_screen.dart'; // 상세 스크린 임포트 추가
import 'package:logger/logger.dart';
import 'core/services/storage_service.dart'; // 스토리지 서비스 추가

class CherryRecorderApp extends StatefulWidget {
  const CherryRecorderApp({super.key});

  @override
  State<CherryRecorderApp> createState() => _CherryRecorderAppState();
}

class _CherryRecorderAppState extends State<CherryRecorderApp> {
  late Logger _logger;
  bool _storageInitialized = false;

  @override
  void initState() {
    super.initState();
    // 상태바 설정 (투명 상태바와 다크 아이콘)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // 디바이스 방향 고정 (세로 모드만)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _logger = Logger();

    // 스토리지 서비스 초기화 (async 함수 호출)
    _initializeStorageService();
  }

  // 스토리지 서비스 초기화 함수
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
    // 앱 테마 정의
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

  // 라우트 생성 함수
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
