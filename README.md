# 🍒 CherryRecorder Client

[![CI/CD Pipeline](https://github.com/kugorang/cherryrecorder_client/actions/workflows/ci.yml/badge.svg)](https://github.com/kugorang/cherryrecorder_client/actions/workflows/ci.yml)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.32.2-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)

Flutter로 개발된 CherryRecorder 서비스의 크로스 플랫폼 클라이언트 애플리케이션입니다.

## 📱 프로젝트 소개

CherryRecorder는 위치 기반으로 개인의 혜택 정보를 기록하고 관리하는 서비스입니다. 주변 장소를 탐색하고, 특정 장소에서 받은 혜택이나 메모를 기록하여 나만의 혜택 지도를 만들 수 있습니다.

### 주요 기능

- 🗺️ **지도 기반 장소 탐색**: Google Maps를 활용한 실시간 주변 장소 확인
- 📍 **장소 상세 정보**: 선택한 장소의 정보 및 개인 메모 조회
- 📝 **메모 관리**: 장소별 혜택 정보 기록 (추가/수정/삭제)
- 🌐 **크로스 플랫폼**: 웹, Android, iOS 지원 (현재 웹과 Android 중점 개발)

## 🚀 시작하기

### 사전 요구사항

- Flutter SDK 3.32.2 이상
- Dart SDK 3.5.0 이상
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

1. `.vscode/launch.json.example`을 `.vscode/launch.json`으로 복사
2. 플레이스홀더를 실제 값으로 교체
3. VS Code의 "Run and Debug" 패널에서 원하는 구성 선택

**⚠️ 보안 주의**: `.vscode/launch.json`과 `android/local.properties`는 절대 커밋하지 마세요!

### 3. 필수 환경 변수

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `APP_ENV` | 실행 환경 | `dev` 또는 `prod` |
| `WEB_MAPS_API_KEY` | 웹용 Google Maps API 키 | `AIza...` |
| `WEB_API_BASE_URL` | 웹 환경 API 서버 URL | `http://localhost:8080` |
| `ANDROID_API_BASE_URL` | Android 환경 API 서버 URL | `http://10.0.2.2:8080` |

## 🏃‍♂️ 실행 방법

### 개발 환경

**웹 브라우저**
```bash
flutter run -d chrome \
  --dart-define=APP_ENV=dev \
  --dart-define=WEB_MAPS_API_KEY=YOUR_KEY \
  --dart-define=WEB_API_BASE_URL=http://localhost:8080
```

**Android 에뮬레이터**
```bash
flutter run --flavor dev \
  --dart-define=APP_ENV=dev \
  --dart-define=ANDROID_API_BASE_URL=http://10.0.2.2:8080
```

### 프로덕션 빌드

**웹 빌드**
```bash
flutter build web --release \
  --dart-define=APP_ENV=prod \
  --dart-define=WEB_MAPS_API_KEY=YOUR_PROD_KEY \
  --dart-define=WEB_API_BASE_URL=https://api.cherryrecorder.com
```

**Android APK 빌드**
```bash
flutter build apk --release --flavor prod \
  --dart-define=APP_ENV=prod \
  --dart-define=ANDROID_API_BASE_URL=https://api.cherryrecorder.com
```

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── app.dart                  # 루트 MaterialApp 설정
├── core/                     # 핵심 공통 모듈
│   ├── constants/           # 상수 정의
│   ├── database/            # 로컬 DB (SQLite/Hive)
│   ├── models/              # 데이터 모델
│   ├── network/             # API 통신
│   └── services/            # 공통 서비스
└── features/                # 기능별 모듈
    ├── map/                 # 지도 기능
    ├── memo_management/     # 메모 관리
    ├── place_details/       # 장소 상세
    └── splash/              # 스플래시 화면
```

## 🏗️ 아키텍처

- **디자인 패턴**: Clean Architecture 기반 Feature-first 구조
- **상태 관리**: Provider 패키지 (`ChangeNotifier`)
- **네트워크**: HTTP 패키지 + 커스텀 `ApiClient`
- **로컬 저장소**: SQLite (메모), Hive (캐시)
- **지도**: Google Maps Flutter 플러그인

## 🚀 CI/CD

### GitHub Actions 워크플로우

프로젝트는 자동화된 CI/CD 파이프라인을 사용합니다:

1. **경로 기반 스마트 빌드**: 변경된 파일에 따라 필요한 작업만 실행
2. **GitHub Pages 배포**: 웹 빌드 자동 배포
3. **Docker Hub 푸시**: 컨테이너 이미지 자동 빌드 및 배포

### 배포 환경

- **웹**: [GitHub Pages](https://kugorang.github.io/cherryrecorder_client/)
- **Docker**: `docker pull kugorang/cherryrecorder_client:latest`

## 🐳 Docker 지원

### 로컬에서 Docker 실행

```bash
# 이미지 빌드
docker build -t cherryrecorder-client .

# 컨테이너 실행
docker run -p 80:80 cherryrecorder-client
```

### Docker Compose (개발용)

```yaml
version: '3.8'
services:
  client:
    image: kugorang/cherryrecorder_client:latest
    ports:
      - "80:80"
    environment:
      - APP_ENV=dev
```

## 🧪 테스트

```bash
# 모든 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/widget_test.dart

# 커버리지 리포트 생성
flutter test --coverage
```

## 📝 코드 생성

Hive 어댑터 및 기타 코드 생성:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

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
