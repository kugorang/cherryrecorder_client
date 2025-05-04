import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart'; // SVG 로고 사용

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
      // 이 부분에서 context가 mounted 상태인지 확인
      if (!mounted) return;

      // 지도 화면으로 이동
      Navigator.pushReplacementNamed(context, '/map');
    });
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기를 기준으로 동적인 크기 계산
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFDE3B3B), // Figma 배경색 (체리색)
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // SVG 로고 이미지 표시 시도, 실패하면 플레이스홀더 표시
              SizedBox(width: 150, height: 150, child: _buildLogo()),
              const SizedBox(height: 20), // 로고와 텍스트 사이 간격
              // 앱 이름 텍스트
              Container(
                width: screenSize.width * 0.8, // 화면 너비의 80% 사용
                alignment: Alignment.center,
                child: const Text(
                  '나만의 혜택 기록장',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 로고 위젯 생성 (적절한 예외 처리 포함)
  Widget _buildLogo() {
    try {
      return SvgPicture.asset(
        'assets/images/logo.svg',
        width: 150,
        height: 150,
      );
    } catch (e) {
      // SVG 파일 로드 실패 시 기본 아이콘 표시
      return const Icon(Icons.location_on, size: 100, color: Colors.white);
    }
  }
}
