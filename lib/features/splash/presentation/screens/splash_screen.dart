import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../map_view/presentation/screens/map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // 스플래시 화면 표시 시간 (예: 2초)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // TODO: 권한 확인 로직 추가 필요 (getCurrentLocation 등)
    // 현재는 바로 메인 화면으로 이동
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDE3B3B), // Figma 배경색
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 150, // 로고 크기는 Figma 비율에 맞게 조정 필요
            ),
            const SizedBox(height: 24),
            const Text(
              '나만의 혜택 기록장',
              style: TextStyle(
                fontFamily: 'Inter', // Figma 폰트 (pubspec.yaml에 추가 필요 시)
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
