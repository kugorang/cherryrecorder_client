# 🍒 CherryRecorder Client

[![CI/CD Pipeline](https://github.com/kugorang/cherryrecorder_client/actions/workflows/ci.yml/badge.svg)](https://github.com/kugorang/cherryrecorder_client/actions/workflows/ci.yml)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.24.2-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)
[![Google Play](https://img.shields.io/badge/Google%20Play-Available-green.svg)](https://play.google.com/store/apps/details?id=com.kugorang.cherryrecorder)

Flutter로 개발된 CherryRecorder 서비스의 크로스 플랫폼 클라이언트 애플리케이션입니다.

## 📱 프로젝트 소개

CherryRecorder는 위치 기반으로 개인의 혜택 정보를 기록하고 관리하는 서비스입니다. 주변 장소를 탐색하고, 특정 장소에서 받은 혜택이나 메모를 기록하여 나만의 혜택 지도를 만들 수 있습니다.

### 주요 기능

- 🗺️ **지도 기반 장소 탐색**: Google Maps를 활용한 실시간 주변 장소 확인
  - 지도-리스트 연동 스크롤 UI/UX
  - 거리순 정렬로 가장 가까운 5개 장소 표시
  - 수동 새로고침 버튼으로 서버 부하 최적화
- 📍 **장소 상세 정보**: 선택한 장소의 정보 및 개인 메모 조회
  - 장소별 메모 카드 시스템
  - 태그 기반 메모 분류 및 검색
  - 메모 추가/수정/삭제 화면 개선
- 📝 **메모 관리**: 장소별 혜택 정보 기록 (추가/수정/삭제)
  - 향상된 메모 작성 UI
  - 태그별 메모 조회 기능
  - 메모 카드 형식의 시각적 표현
- 💬 **실시간 채팅**: WebSocket 기반 실시간 대화 기능
  - 자동 재연결 로직
  - 프로덕션 환경에서 WSS(보안 WebSocket) 지원
  - 장소별 채팅방 분리
- 🌐 **크로스 플랫폼**: 웹, Android, iOS 지원 (현재 Android 출시)

## 🚀 시작하기

### 사전 요구사항

- Flutter SDK 3.24.2 이상
- Dart SDK 3.5.2 이상
- Android Studio 또는 VS Code
- Google Cloud Console 계정 (Maps API 키 발급용)

### 개발 환경 설정

1. **프로젝트 클론**
   ```bash
   git clone https://github.com/kugorang/cherryrecorder_client.git
   cd cherryrecorder_client
   ```

2. **의존성 설치**
   ```bash
   flutter pub get
   ```

3. **환경 설정** (아래 '환경 설정' 섹션 참조)

## ⚙️ 환경 설정

### 1. Google Maps API 키 설정

#### 웹용 API 키
- [Google Cloud Console](https://console.cloud.google.com/)에서 Maps JavaScript API 활성화
- 실행 시 `--dart-define=WEB_MAPS_API_KEY=YOUR_KEY` 형태로 전달

#### Android용 API 키
1. `android/local.properties.example`을 `android/local.properties`로 복사
2. 파일 내용 수정:
   ```properties
   maps.apiKey.dev=YOUR_DEV_ANDROID_KEY
   maps.apiKey.prod=YOUR_PROD_ANDROID_KEY
   ```

### 2. VS Code 실행 구성 (권장)

`.vscode/launch.json` 파일로 개발/프로덕션 환경을 쉽게 전환할 수 있습니다.

**⚠️ 보안 주의**: `.vscode/launch.json`과 `android/local.properties`는 절대 커밋하지 마세요!

### 3. 필수 환경 변수

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `APP_ENV` | 실행 환경 | `dev` 또는 `prod` |
| `API_BASE_URL` | API 서버 URL (통합) | `https://cherryrecorder.kugora.ng:58080` |
| `CHAT_SERVER_IP` | 채팅 서버 호스트 | `cherryrecorder.kugora.ng` |
| `CHAT_SERVER_PORT` | 채팅 서버 포트 | `33335` |
| `USE_WSS` | 보안 WebSocket 사용 여부 | `true` (프로덕션) |
| `WEB_MAPS_API_KEY` | 웹용 Google Maps API 키 | `AIza...` |

## 🏃‍♂️ 실행 방법

### 개발 환경

**웹 브라우저**
```bash
flutter run -d chrome \
  --dart-define=APP_ENV=dev \
  --dart-define=WEB_MAPS_API_KEY=YOUR_KEY \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=CHAT_SERVER_IP=localhost \
  --dart-define=CHAT_SERVER_PORT=33334
```

**Android 에뮬레이터**
```bash
flutter run --flavor dev \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=CHAT_SERVER_IP=10.0.2.2 \
  --dart-define=CHAT_SERVER_PORT=33334
```

### 프로덕션 빌드

**Android AAB 빌드 (Google Play Store용)**
```bash
flutter build appbundle --flavor prod \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://cherryrecorder.kugora.ng:58080 \
  --dart-define=CHAT_SERVER_IP=cherryrecorder.kugora.ng \
  --dart-define=CHAT_SERVER_PORT=33335 \
  --dart-define=USE_WSS=true
```

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── app.dart                  # 루트 MaterialApp 설정
├── core/                     # 핵심 공통 모듈
│   ├── constants/           # 상수 정의
│   ├── database/            # 로컬 DB (Hive)
│   ├── models/              # 데이터 모델
│   ├── network/             # API 통신 (ApiClient)
│   ├── services/            # 공통 서비스
│   └── utils/               # 유틸리티
└── features/                # 기능별 모듈 (Clean Architecture)
    ├── chat/                # 실시간 채팅
    │   └── presentation/
    │       ├── providers/   # ChatViewModel
    │       └── screens/     # ChatScreen
    ├── map/                 # 지도 기능
    │   └── presentation/
    │       ├── providers/   # MapViewModel
    │       ├── screens/     # MapScreen  
    │       └── widgets/     # PlaceListCard
    ├── place_details/       # 장소 상세
    │   └── presentation/
    │       ├── providers/   # PlaceDetailViewModel
    │       ├── screens/     # PlaceDetailScreen
    │       └── widgets/     # MemoCard
    └── splash/              # 스플래시 화면
```

## 🏗️ 아키텍처

- **디자인 패턴**: Clean Architecture 기반 Feature-first 구조
- **상태 관리**: Provider 패키지 (`ChangeNotifier` + ViewModels)
- **네트워크**: HTTP 패키지 + 커스텀 `ApiClient`
- **로컬 저장소**: Hive (메모 및 캐시)
- **지도**: Google Maps Flutter 플러그인
- **실시간 통신**: web_socket_channel

## 📲 배포

### Google Play Store
- **패키지 ID**: `com.kugorang.cherryrecorder`
- **스토어 링크**: [체리 레코더 - Google Play](https://play.google.com/store/apps/details?id=com.kugorang.cherryrecorder)
- **지원 기기**: Android 6.0 (API 23) 이상

### 버전 관리
- **현재 버전**: pubspec.yaml의 `version` 필드 참조
- **버전 형식**: `major.minor.patch+buildNumber`

## 🧪 테스트

```bash
# 모든 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/core/network/api_client_test.dart

# 커버리지 리포트 생성
flutter test --coverage
```

## 📝 코드 생성

Hive 어댑터 및 기타 코드 생성:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🚀 CI/CD

### GitHub Actions 워크플로우

프로젝트는 자동화된 CI/CD 파이프라인을 사용합니다:

1. **테스트 자동화**: 모든 PR에 대해 자동 테스트 실행
2. **코드 품질 검사**: Dart 코드 스타일 및 정적 분석
3. **자동 빌드**: main 브랜치 푸시 시 AAB 파일 생성

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 BSD 3-Clause 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 🙏 감사의 말

- Flutter 팀과 커뮤니티
- Google Maps Platform
- 모든 오픈소스 기여자들

---

Made with ❤️ by CherryRecorder Team
