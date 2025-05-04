// UI 스텁 구현 - 모바일 환경에서 사용
// dart:ui의 platformViewRegistry를 모방한 스텁 클래스

// 플랫폼 뷰 레지스트리 스텁
final PlatformViewRegistry platformViewRegistry = PlatformViewRegistry();

// 플랫폼 뷰 레지스트리 클래스 스텁
class PlatformViewRegistry {
  // ignore: avoid_annotating_with_dynamic
  dynamic registerViewFactory(String viewId, dynamic cb) {
    // 모바일에서는 작동하지 않음
    return null;
  }
}
