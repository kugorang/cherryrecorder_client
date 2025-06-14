# CherryRecorder Client

Flutter 기반 모바일 지도 서비스 클라이언트

## ✨ 주요 기능

- 📍 현재 위치 표시 및 추적
- 🔍 주변 장소 검색 (Google Places API)
- 📱 장소 상세 정보 및 사진 조회
- 💬 실시간 채팅 (WebSocket)
- 🌐 크로스 플랫폼 지원 (Web, Android, iOS)

## 🚀 빠른 시작

### 웹 버전
[GitHub Pages에서 실행](https://kugorang.github.io/cherryrecorder_client/)

### Docker
```bash
docker run -d -p 8080:80 kugorang/cherryrecorder_client:latest
```

## 🌐 서버 연결 설정

### `.env.prod`
```env
WEB_API_BASE_URL=https://your-domain.com/api
WEB_MAPS_API_KEY=your-web-maps-api-key
ANDROID_API_BASE_URL=https://your-domain.com/api
ANDROID_MAPS_API_KEY=your-android-maps-api-key
```

### `.env.dev`
```env
WEB_API_BASE_URL=http://localhost:8080
WEB_MAPS_API_KEY=your-web-maps-api-key
ANDROID_API_BASE_URL=http://10.0.2.2:8080
ANDROID_MAPS_API_KEY=your-android-maps-api-key
```

## 🔧 개발

### 설치
```bash
flutter pub get
```

### 실행
```bash
# 개발
flutter run --dart-define-from-file=.env.dev

# 빌드
flutter build web --release --dart-define-from-file=.env.prod
flutter build apk --release --dart-define-from-file=.env.prod
```

## 📡 API 연결

### REST API
```dart
// nginx 프록시 경유
https://your-domain.com/api/places/nearby
https://your-domain.com/api/places/details/{id}
```

### WebSocket
```dart
// nginx 프록시 경유
final ws = WebSocketChannel.connect(
  Uri.parse('wss://your-domain.com/ws')
);
```

## 🔄 CI/CD

### GitHub Secrets
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `WEB_MAPS_API_KEY`

### 자동 배포
- main push → GitHub Pages + Docker Hub

## 🔍 트러블슈팅

### CORS 오류
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

### Android 에뮬레이터
- `localhost` → `10.0.2.2`
- AndroidManifest.xml에 인터넷 권한 추가

### iOS
- Info.plist에 App Transport Security 설정

## 🏗 프로젝트 구조

```
lib/
├── core/
│   ├── constants/        # API 엔드포인트
│   └── network/          # HTTP 클라이언트
├── features/
│   ├── chat/            # 채팅 기능
│   └── map/             # 지도 기능
└── main.dart
```

## 📄 라이선스

BSD 3-Clause License

## 💬 지원

- [GitHub Issues](https://github.com/kugorang/cherryrecorder_client/issues)
- [라이브 데모](https://kugorang.github.io/cherryrecorder_client/)
