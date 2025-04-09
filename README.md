# cherryrecorder_client

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 폴더 구조

cherryrecorder_client/
├── android/                 # Android 네이티브 프로젝트
├── ios/                     # iOS 네이티브 프로젝트
├── lib/
│   ├── main.dart             # 앱 진입점, 초기화 로직
│   ├── core/                 # 공통 유틸리티, 상수, 모델, 서비스
│   │   ├── constants/        # 앱 전체 상수 (API URL, 색상 등)
│   │   ├── models/           # 공통 데이터 모델 (Place, Memo 등)
│   │   └── services/         # 공통 서비스 (LocationService, ApiService, DatabaseService)
│   ├── features/             # 기능별 모듈
│   │   ├── splash/           # 스플래시 화면 및 권한 처리 (S-01)
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           └── splash_screen.dart
│   │   ├── map_view/         # 지도 및 주변 장소 (F-01, F-02, S-02)
│   │   │   ├── data/         # API 호출, 데이터 소스
│   │   │   ├── domain/       # 이 기능에 특화된 모델 (필요시)
│   │   │   └── presentation/
│   │   │       ├── providers/  # 상태 관리 (Provider/Riverpod 사용 시)
│   │   │       ├── screens/
│   │   │       │   └── map_screen.dart
│   │   │       └── widgets/    # 지도 위젯, 검색 바, 장소 목록 아이템
│   │   ├── place_details/    # 장소 상세 및 메모 조회 (S-03, F-04)
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       ├── screens/
│   │   │       │   └── place_detail_screen.dart
│   │   │       └── widgets/    # 메모 목록, 메모 아이템
│   │   └── memo_management/  # 메모 추가/수정/삭제 (S-04, F-03)
│   │       ├── data/
│   │       ├── domain/       # 메모 모델 (core/models 와 중복될 수 있음)
│   │       └── presentation/
│   │           ├── providers/
│   │           ├── screens/
│   │           │   └── memo_edit_screen.dart
│   │           └── widgets/    # 메모 폼, 태그 입력
│   └── app.dart              # 루트 MaterialApp 위젯, 라우팅 설정
├── pubspec.yaml             # 프로젝트 메타데이터 및 의존성 관리
└──... (기타 설정 파일)