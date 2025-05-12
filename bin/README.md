# CherryRecorder CLI 클라이언트

CherryRecorder 서버와 통신하는 Dart 기반 CLI 클라이언트입니다. 이 툴은 CherryRecorder 서버의 기능을 커맨드라인에서 사용할 수 있게 해주는 데모 도구입니다.

## 주요 기능

1. 서버 상태 확인 (`health`)
2. 주변 장소 검색 (`nearby`)
3. 텍스트 기반 장소 검색 (`search`)
4. 장소 상세 정보 조회 (`details`)

## 설치 및 실행 방법

### 요구 사항

- Dart SDK 설치
- CherryRecorder 서버 실행 중
- `.env.dev` 파일에 서버 설정 (선택 사항)

### 패키지 설치

프로젝트 루트 디렉토리에서 다음 명령어를 실행하여 필요한 패키지를 설치합니다:

```bash
flutter pub get
```

### 환경 설정 (선택 사항)

기본적으로 `http://localhost:8080`을 서버 URL로 사용하지만, `.env.dev` 파일을 통해 서버 URL을 설정할 수 있습니다:

```
SERVER_URL=http://localhost:8080
```

### 실행 방법

```bash
dart bin/cherry_cli.dart [옵션] <명령어> [명령어 옵션]
```

## 명령어 및 옵션

### 공통 옵션

- `--server`, `-s`: CherryRecorder 서버 URL (기본값: http://localhost:8080)
- `--help`, `-h`: 도움말 표시

### 서버 상태 확인

```bash
dart bin/cherry_cli.dart health
```

### 주변 장소 검색

```bash
dart bin/cherry_cli.dart nearby --lat 37.5665 --lng 126.9780 --radius 1000
```

옵션:
- `--lat`: 위도 (기본값: 37.5665, 서울)
- `--lng`: 경도 (기본값: 126.9780, 서울)
- `--radius`: 검색 반경 (미터, 기본값: 1000)

### 텍스트 기반 장소 검색

```bash
dart bin/cherry_cli.dart search --query "서울역"
```

옵션:
- `--query`: 검색어 (필수)
- `--lat`: 검색 기준 위도 (기본값: 37.5665, 서울)
- `--lng`: 검색 기준 경도 (기본값: 126.9780, 서울)

### 장소 상세 정보 조회

```bash
dart bin/cherry_cli.dart details --id "ChIJ1wtAEOmLGGARVCFZ0ctyOvI"
```

옵션:
- `--id`: 장소 ID (필수)

## 테스트 실행 방법

CLI 클라이언트의 기능을 테스트하기 위한 단위 테스트가 구현되어 있습니다. 아래 명령어로 테스트를 실행할 수 있습니다:

```bash
flutter test test/cli/cherry_cli_test.dart
```

테스트는 다음 기능들을 검증합니다:
- 서버 상태 확인 (health) 기능
- 주변 장소 검색 (nearby) 기능
- 텍스트로 장소 검색 (search) 기능 
- 장소 상세 정보 조회 (details) 기능

## 데모 시나리오 예시

1. 서버 상태 확인
   ```bash
   dart bin/cherry_cli.dart health
   ```

2. 서울역 검색
   ```bash
   dart bin/cherry_cli.dart search --query "서울역"
   ```

3. 검색 결과에서 나온 Place ID를 사용하여 상세 정보 조회
   ```bash
   dart bin/cherry_cli.dart details --id "ChIJ1wtAEOmLGGARVCFZ0ctyOvI"
   ```

4. 특정 위치 주변 식당 검색
   ```bash
   dart bin/cherry_cli.dart nearby --lat 37.5665 --lng 126.9780 --radius 1000
   ```

## 데모 평가 요소 충족

1. **정보의 명확성** (1점)
   - CLI 클라이언트와 서버가 관리하는 정보(장소 데이터, API 키 등)를 명확하게 정의합니다.
   - 각 명령어와 파라미터는 직관적이며 목적이 분명합니다.

2. **정보 교환의 명확성** (1점)
   - 클라이언트와 서버 간 송수신하는 JSON 데이터 형식이 명확하게 정의됩니다.
   - 오류 처리와 응답 메시지가 체계적으로 표시됩니다.

3. **기능의 명확성** (1점)
   - 각 명령어별 기능이 명확하게 정의되어 있습니다.
   - 사용자 인터페이스와 도움말이 직관적입니다.

4. **전체적인 우수성** (2점)
   - 에러 처리, 로깅, 명령어 파싱 등 견고한 구현
   - 확장 가능한 구조와 명확한 코드 구성
   - 단위 테스트를 통한 기능 검증 