# CherryRecorder Client

Flutter 기반 크로스 플랫폼 위치 기록 및 실시간 채팅 애플리케이션

## 🚀 주요 기능

- **위치 기록**: Google Maps 기반 장소 검색 및 저장
- **실시간 채팅**: WebSocket 기반 채팅 (/ws 경로)
- **크로스 플랫폼**: Web, Android, iOS 지원
- **자동 배포**: GitHub Pages (Web) + Docker Hub

## 📋 시스템 요구사항

- Flutter 3.32.2+
- Dart SDK 3.7.0+
- Android Studio / VS Code
- Docker (선택사항)

## 🔧 빠른 시작

### 개발 환경 설정

```bash
# 의존성 설치
flutter pub get

# 개발 서버 실행
flutter run -d chrome --dart-define-from-file=.env.dev
```

### Docker를 사용한 실행

```bash
# Docker Hub에서 이미지 받기
docker pull kugorang/cherryrecorder_client:latest

# 실행 (포트 80)
docker run -d \
  --name cherryrecorder-client \
  -p 80:80 \
  kugorang/cherryrecorder_client:latest
```

## 🌐 환경 설정

### 개발 환경 (.env.dev)
```env
# 공통 설정
APP_ENV=dev

# 웹 환경 설정
WEB_API_BASE_URL=http://localhost:8080
WEB_MAPS_API_KEY=your_dev_maps_api_key
WS_URL=ws://localhost:33334

# 안드로이드 환경 설정
ANDROID_API_BASE_URL=http://10.0.2.2:8080
ANDROID_MAPS_API_KEY=your_android_maps_api_key
```

### 프로덕션 환경 (.env.prod)
```env
# 공통 설정
APP_ENV=prod

# 웹 환경 설정
WEB_API_BASE_URL=https://your-domain.com/api
WEB_MAPS_API_KEY=your_prod_maps_api_key
WS_URL=wss://your-domain.com/ws

# 안드로이드 환경 설정
ANDROID_API_BASE_URL=https://your-domain.com/api
ANDROID_MAPS_API_KEY=your_android_maps_api_key
```

## 🔗 API 연동

### 서버 API 호출
클라이언트는 다음 서버 엔드포인트를 사용합니다:

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/health` | 서버 상태 확인 |
| POST | `/places/nearby` | 주변 장소 검색 |
| POST | `/places/search` | 텍스트 기반 장소 검색 |
| GET | `/places/details/{placeId}` | 장소 상세정보 |

### WebSocket 연동
- 연결 URL: `wss://your-domain.com/ws` (프로덕션)
- 프로토콜: 텍스트 기반 메시지
- 닉네임 변경: `/nick <닉네임>` 명령어 사용

## 🏗️ 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── core/
│   ├── config/                 # 환경 설정
│   └── constants/              # 상수 정의
├── features/
│   ├── chat/                   # 채팅 기능
│   │   ├── domain/            # 도메인 모델
│   │   ├── presentation/      # UI 및 ViewModel
│   │   └── data/              # 데이터 소스
│   └── places/                 # 장소 검색 기능
└── shared/                     # 공통 컴포넌트
```

## 🚀 CI/CD

### GitHub Actions 워크플로우

1. **GitHub Pages 배포**
   - `main` 브랜치 푸시 시 자동 실행
   - Flutter 웹 빌드 및 GitHub Pages 배포
   - URL: `https://kugorang.github.io/cherryrecorder_client/`

2. **Docker Hub 배포**
   - Docker 이미지 빌드 및 푸시
   - nginx 리버스 프록시 포함
   - 이미지: `kugorang/cherryrecorder_client:latest`

### 필요한 GitHub Secrets
- `WEB_MAPS_API_KEY`: Google Maps API 키 (Web)
- `DOCKERHUB_USERNAME`: Docker Hub 사용자명
- `DOCKERHUB_TOKEN`: Docker Hub 액세스 토큰

### 필요한 GitHub Variables
- `SERVER_DOMAIN`: API 서버 도메인 (your-domain.com)

## 🐳 Docker 구성

### nginx 리버스 프록시
클라이언트 Docker 이미지는 nginx를 포함하여 API와 WebSocket 요청을 프록시합니다:

```nginx
# API 요청 프록시
location /api/ {
    proxy_pass http://cherryrecorder-server:8080/;
}

# WebSocket 프록시
location /ws {
    proxy_pass http://cherryrecorder-server:33334;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### Docker Compose 사용

```yaml
version: '3.8'
services:
  cherryrecorder-server:
    image: kugorang/cherryrecorder-server:latest
    environment:
      - GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}
    volumes:
      - ./server-history:/home/appuser/app/history

  cherryrecorder-client:
    image: kugorang/cherryrecorder-client:latest
    ports:
      - "80:80"
    depends_on:
      - cherryrecorder-server
```

## 📱 플랫폼별 빌드

### 웹
```bash
flutter build web --release \
  --dart-define-from-file=.env.prod \
  --base-href "/cherryrecorder_client/"
```

### Android AAB (Google Play 배포용)
```bash
# AAB 빌드 스크립트 사용 (Windows)
build_aab.bat

# 또는 직접 빌드
flutter build appbundle --release \
  --flavor prod \
  --dart-define-from-file=.env.prod
```

### Android APK (직접 설치용)
```bash
flutter build apk --release \
  --flavor prod \
  --dart-define-from-file=.env.prod
```

### iOS
```bash
flutter build ios --release \
  --dart-define-from-file=.env.prod
```

## 🔑 API 키 설정

### Google Maps API 키 필요 권한
- Maps JavaScript API (Web)
- Maps SDK for Android
- Maps SDK for iOS
- Places API

### 플랫폼별 설정
- **Web**: 환경 변수로 주입
- **Android**: `android/app/src/main/AndroidManifest.xml`
- **iOS**: `ios/Runner/AppDelegate.swift`

### Android 키 서명 설정
1. `android/keystore.properties` 파일 생성:
```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=your-key-alias
storeFile=../your-keystore.jks
```

2. 키스토어 파일을 `android/` 디렉토리에 저장

## 📦 주요 의존성

- `google_maps_flutter`: 지도 표시
- `web_socket_channel`: WebSocket 통신
- `flutter_secure_storage`: 안전한 데이터 저장
- `logger`: 로깅
- `uuid`: 고유 ID 생성

## 🐛 문제 해결

### 빌드 오류
```bash
# 캐시 정리
flutter clean
flutter pub get
```

### WebSocket Uri 타입 에러
`chat_view_model.dart`에서 WebSocket 연결시:
```dart
// 잘못된 코드
_channel = WebSocketChannel.connect(wsUrl); // String 타입

// 올바른 코드
_channel = WebSocketChannel.connect(wsUri); // Uri 타입
```

### 플랫폼별 이슈
- **Web**: CORS 에러 → 서버가 `https://kugorang.github.io` Origin 허용하는지 확인
- **Android**: 네트워크 권한 → `AndroidManifest.xml` 확인
- **iOS**: ATS 설정 → `Info.plist` 확인

### WebSocket 연결 실패
- 경로 확인: `/ws` (기존 `/ws/chat` 아님)
- 프로토콜: `wss://` (프로덕션), `ws://` (개발)
- 포트: 33334 (직접 연결시)

## 📄 라이센스

이 프로젝트는 BSD 3-Clause 라이센스 하에 배포됩니다.

## 👤 개발자

- **Kim Hyeonwoo** - [kugorang](https://github.com/kugorang)
- 이메일: ialskdji@gmail.com

## 🤝 기여

1. 프로젝트를 Fork 합니다
2. 기능 브랜치를 생성합니다 (`git checkout -b feature/AmazingFeature`)
3. 변경사항을 커밋합니다 (`git commit -m 'Add some AmazingFeature'`)
4. 브랜치에 푸시합니다 (`git push origin feature/AmazingFeature`)
5. Pull Request를 생성합니다