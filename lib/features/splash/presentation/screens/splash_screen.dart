import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

/// 앱 시작 시 표시되는 스플래시 화면 위젯.
class SplashScreen extends StatefulWidget {
  /// 기본 생성자.
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// [SplashScreen]의 상태 관리 클래스.
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 2초 후 메인 화면으로 자동 이동
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/map');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDE3B3B), // 체리색 배경
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 로고 이미지
              SvgPicture.asset(
                'assets/images/logo.svg',
                width: 120,
                height: 124,
              ),
              const SizedBox(height: 24),
              // 앱 이름
              const Text(
                '체리 레코더',
                style: TextStyle(
                  color: Colors.white, // 흰색 텍스트
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 하단 텍스트
              const Text(
                '나만의 혜택 기록장',
                style: TextStyle(
                  color: Colors.white70, // 밝은 흰색 텍스트
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
