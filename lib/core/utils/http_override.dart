import 'dart:io';

/// 개발/테스트 목적으로 SSL 인증서 검증을 우회하는 클래스
///
/// ⚠️ 주의: 프로덕션 환경에서는 절대 사용하지 마세요!
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // 새로운 SecurityContext 생성
    final securityContext = SecurityContext(withTrustedRoots: true);

    // TLS 1.2만 사용하도록 설정 (TLS 1.3 비활성화)
    final client = super.createHttpClient(securityContext)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // 특정 호스트에 대해서만 인증서 검증을 우회
        if (host == 'cherryrecorder.kugora.ng') {
          print('⚠️ SSL 인증서 검증 우회: $host:$port');
          print('인증서 발급자: ${cert.issuer}');
          print('인증서 주체: ${cert.subject}');
          return true;
        }
        return false;
      }
      // 연결 타임아웃 설정
      ..connectionTimeout = const Duration(seconds: 30)
      // 유휴 타임아웃 설정
      ..idleTimeout = const Duration(seconds: 30);

    // User-Agent 헤더 추가로 호환성 개선
    client.userAgent = 'Flutter Android App';

    return client;
  }
}
