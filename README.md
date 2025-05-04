# CherryRecorder Client

Flutter로 개발된 CherryRecorder 서비스의 클라이언트 애플리케이션입니다.

## 프로젝트 목표

주변 장소를 탐색하고, 특정 장소에 대한 사용자 메모(혜택 정보 등)를 기록하고 관리하는 기능을 제공합니다.

## 주요 기능

* **지도 기반 장소 탐색:** Google Maps를 사용하여 주변 장소를 확인하고 검색합니다.
* **장소 상세 정보:** 선택한 장소의 기본 정보 및 사용자가 기록한 메모를 조회합니다.
* **메모 관리:** 특정 장소에 대한 텍스트 메모를 추가, 수정, 삭제합니다. (현재 웹 환경에서는 지원되지 않음)
* **(예정) 챗봇 기능:** 장소 추천 등 다양한 상호작용을 위한 챗봇 인터페이스.

## 시작하기

Flutter 개발 환경 설정이 필요합니다. 자세한 내용은 [Flutter 공식 문서](https://docs.flutter.dev/)를 참고하세요.

## 환경 설정 (매우 중요)

이 프로젝트는 환경별 설정을 위해 **`--dart-define`** 컴파일 환경 변수를 사용합니다. `.env` 파일을 이용한 방식은 보안 문제로 인해 더 이상 사용하지 않습니다.

### 1. 필수 환경 변수

앱을 실행하거나 빌드할 때 다음 환경 변수들을 `--dart-define` 인수를 통해 반드시 주입해야 합니다:

* `APP_ENV`: 애플리케이션 환경 (`dev` 또는 `prod`). `main.dart`에서 환경 구분에 사용됩니다.
* `WEB_MAPS_API_KEY`: **웹 브라우저용** Google Maps API 키.
* `WEB_API_BASE_URL`: 웹 환경에서 접속할 CherryRecorder 서버의 기본 URL.
* `ANDROID_API_BASE_URL`: 안드로이드 환경에서 접속할 CherryRecorder 서버의 기본 URL.

### 2. API 키 관리

* **Google Maps API 키:**
    1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트를 생성하고 **반드시 웹용과 안드로이드용 API 키를 별도로 발급**받으세요.
    2. **웹 API 키:** `--dart-define=WEB_MAPS_API_KEY=YOUR_ACTUAL_WEB_KEY` 와 같이 빌드/실행 시점에 직접 전달합니다. (아래 `launch.json` 설정 참고)
    3. **안드로이드 API 키:**
        * `android/local.properties.example` 파일을 `android/local.properties`로 복사합니다.
        * `local.properties` 파일 안에 `maps.apiKey.dev=YOUR_DEV_ANDROID_KEY` 와 `maps.apiKey.prod=YOUR_PROD_ANDROID_KEY` 형식으로 개발/프로덕션용 안드로이드 키를 입력합니다.
        * `android/app/build.gradle.kts` 파일이 이 값을 읽어 빌드 시점에 안전하게 주입합니다.
* **⚠️ 보안 경고:** 절대 API 키를 소스 코드나 버전 관리 시스템(`.git`)에 직접 포함시키지 마세요. `local.properties` 파일은 `.gitignore`에 포함되어 있습니다.

### 3. VS Code 실행 구성 (`launch.json`)

개발 편의를 위해 `.vscode/launch.json` 파일을 사용하여 환경 변수를 미리 설정할 수 있습니다.

1. 프로젝트 루트의 `.vscode/launch.json.example` 파일을 `.vscode/launch.json`으로 복사합니다.
2. `.vscode/launch.json` 파일을 열어 `YOUR_..._HERE` 로 표시된 플레이스홀더들을 **실제 API 키와 프로덕션 URL로 교체**합니다.
3. **매우 중요:** `.vscode/launch.json` 파일은 민감한 정보를 포함하므로, **절대 버전 관리에 포함시키면 안 됩니다.** 프로젝트의 `.gitignore` 파일에 `.vscode/*` 규칙이 설정되어 있고, `launch.json`은 제외됩니다. (`launch.json.example` 파일만 버전 관리됩니다.)

이제 VS Code의 "Run and Debug" 패널에서 원하는 실행 구성(예: `Flutter Web (dev)`, `Flutter Android (dev)`)을 선택하여 앱을 실행할 수 있습니다.

## 폴더 구조

```markdown
lib/
├── main.dart             # 앱 진입점, 환경 설정 및 초기화
├── app.dart              # 루트 MaterialApp 위젯, 기본 라우팅
├── core/                 # 앱 전반에서 사용되는 공통 모듈
│   ├── constants/        # 상수 값 (API 엔드포인트 등)
│   ├── database/         # 로컬 데이터베이스 (sqflite) 헬퍼
│   ├── models/           # 공통 데이터 모델 (Memo 등)
│   ├── network/          # 네트워크 통신 (ApiClient)
│   └── services/         # 공통 서비스 (GoogleMapsService)
└── features/             # 기능별 모듈 (Clean Architecture 유사 구조)
    ├── chat/
    ├── map/
    ├── map_view/         # (기존 지도 관련 기능, 필요시 map으로 통합)
    ├── memo_management/  # 메모 생성/수정 관련
    ├── place_details/    # 장소 상세 및 메모 조회 관련
    └── splash/           # 스플래시 화면
```

* **`core`:** 특정 기능에 종속되지 않고 앱 전반에서 재사용될 수 있는 코드 (모델, 서비스, 유틸리티 등)를 포함합니다.
* **`features`:** 앱의 각 주요 기능(화면 단위 또는 기능 단위)을 독립적인 모듈로 구성합니다. 각 기능 폴더는 필요에 따라 `data`, `domain`, `presentation` 등의 하위 폴더를 가질 수 있습니다.

## 주요 아키텍처 및 참고 사항

* **상태 관리:** `provider` 패키지를 주로 사용합니다 (`ChangeNotifierProvider` 등).
* **네트워크 통신:** `http` 패키지와 이를 감싼 `ApiClient` 클래스(`lib/core/network/api_client.dart`)를 통해 서버와 통신합니다. 서버 기본 URL은 `--dart-define`으로 주입된 값을 사용합니다.
* **지도:** `google_maps_flutter` 패키지를 사용하며, 플랫폼별(웹/모바일) 구현 차이를 `GoogleMapsService`(`lib/core/services/google_maps_service.dart`)에서 일부 처리합니다.
* **로컬 데이터베이스:** `sqflite` 패키지를 사용하여 메모 데이터를 로컬에 저장합니다. (`lib/core/database/database_helper.dart`)
* **웹 환경 제약:** `sqflite`는 웹에서 직접 지원되지 않으므로, 현재 **웹 환경에서는 메모 관련 기능(조회, 추가, 수정, 삭제)이 비활성화**되어 있습니다. (`PlaceDetailViewModel`, `PlaceDetailScreen` 확인)

## 앱 실행 방법

VS Code `launch.json` 구성을 사용하거나, 터미널에서 아래 명령어를 사용하세요. (API 키와 URL을 실제 값으로 대체해야 합니다.)

**개발 환경:**

* **웹 (Chrome):**

    ```bash
    flutter run --dart-define=APP_ENV=dev --dart-define=WEB_MAPS_API_KEY=YOUR_DEV_WEB_KEY --dart-define=WEB_API_BASE_URL=http://localhost:8080 -d chrome
    ```

* **안드로이드:**

    ```bash
    flutter run --flavor dev --dart-define=APP_ENV=dev --dart-define=ANDROID_API_BASE_URL=http://10.0.2.2:8080
    ```

**프로덕션 환경 (예시):**

* **웹 (Chrome):**

    ```bash
    flutter run --dart-define=APP_ENV=prod --dart-define=WEB_MAPS_API_KEY=YOUR_PROD_WEB_KEY --dart-define=WEB_API_BASE_URL=YOUR_PROD_WEB_API_URL -d chrome
    ```

* **안드로이드:**

    ```bash
    flutter run --flavor prod --dart-define=APP_ENV=prod --dart-define=ANDROID_API_BASE_URL=YOUR_PROD_ANDROID_API_URL
    ```

**(참고)** 안드로이드 실행 시 `--flavor`는 `build.gradle.kts`에서 네이티브 리소스(API 키 등)를 구분하기 위해 사용되며, `--dart-define=APP_ENV`는 Flutter 코드 내에서 환경(개발/프로덕션)을 구분하기 위해 사용됩니다.

## 코드 생성

Hive 데이터베이스 어댑터를 생성하려면 다음 명령어를 실행하세요:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

이 명령은 `@HiveType`과 `@HiveField` 어노테이션이 있는 클래스에 대해 자동으로 어댑터 코드를 생성합니다.
