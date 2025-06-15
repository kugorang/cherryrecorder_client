@echo off
setlocal enabledelayedexpansion

echo ===================================
echo CherryRecorder Client AAB Builder
echo ===================================

REM Check if key.properties exists
set "KEY_PROPERTIES=%~dp0android\key.properties"
if not exist "%KEY_PROPERTIES%" (
    echo ERROR: key.properties not found at %KEY_PROPERTIES%
    echo Please create android/key.properties with your keystore information:
    echo.
    echo storePassword=your-store-password
    echo keyPassword=your-key-password
    echo keyAlias=your-key-alias
    echo storeFile=../your-keystore.jks
    echo.
    pause
    exit /b 1
)

REM Check if .env.prod exists
set "ENV_FILE=%~dp0.env.prod"
if not exist "%ENV_FILE%" (
    echo ERROR: .env.prod not found!
    pause
    exit /b 1
)

echo Using environment: %ENV_FILE%

REM Clean previous builds
echo Cleaning previous builds...
call flutter clean

REM Get dependencies
echo Getting dependencies...
call flutter pub get

REM Build AAB
echo Building AAB file...
call flutter build appbundle --release --dart-define-from-file=.env.prod

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b %errorlevel%
)

REM Show output location
echo.
echo ===================================
echo Build completed successfully!
echo ===================================
echo AAB file location:
echo %~dp0build\app\outputs\bundle\release\app-release.aab
echo.
echo To upload to Google Play Console, use the file above.
echo.
pause
