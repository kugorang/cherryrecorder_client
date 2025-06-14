# CherryRecorder Client Build Guide

## Environment Variables

### 웹 빌드에 필요한 환경 변수:
- `WEB_API_BASE_URL`: 백엔드 서버 URL
- `WEB_MAPS_API_KEY`: Google Maps API 키
- `APP_ENV`: 환경 설정 ('dev' 또는 'prod')

## 개발 환경 빌드

```bash
flutter build web --release \
  --dart-define=APP_ENV=dev \
  --dart-define=WEB_API_BASE_URL=http://localhost:8080 \
  --dart-define=WEB_MAPS_API_KEY=YOUR_DEV_API_KEY
```

## 프로덕션 빌드

```bash
flutter build web --release \
  --dart-define=APP_ENV=prod \
  --dart-define=WEB_API_BASE_URL=https://your-domain.com/api \
  --dart-define=WEB_MAPS_API_KEY=YOUR_PROD_API_KEY
```

## GitHub Pages 배포용 빌드

```bash
flutter build web --release \
  --base-href "/cherryrecorder_client/" \
  --dart-define=APP_ENV=prod \
  --dart-define=WEB_API_BASE_URL=https://your-domain.com/api \
  --dart-define=WEB_MAPS_API_KEY=YOUR_PROD_API_KEY
```

## 빌드 확인

빌드 후 브라우저 개발자 도구에서 다음을 확인하세요:
1. Network 탭에서 API 요청이 올바른 서버로 가는지 확인
2. Console에서 "API URL:" 로그 확인

## 주의사항

- `WEB_API_BASE_URL`이 설정되지 않으면 기본값인 `http://localhost:8080`이 사용됩니다
- 프로덕션 빌드 시 반드시 HTTPS URL을 사용하세요
- API 키는 절대 소스 코드에 하드코딩하지 마세요
