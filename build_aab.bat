@echo off
setlocal enabledelayedexpansion

echo ===================================
echo CherryRecorder Client AAB Builder
echo ===================================

REM Check if key.properties exists
set "KEY_PROPERTIES=%~dp0android\keystore.properties"
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

REM Kill any dart/flutter processes that might be locking files
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM flutter_tools.snapshot 2>nul
taskkill /F /IM java.exe 2>nul
taskkill /F /IM adb.exe 2>nul

REM Wait a moment for processes to terminate
ping -n 2 127.0.0.1 >nul

REM Try flutter clean first (it's safer)
echo Running flutter clean...
call flutter clean 2>nul

REM If build directory still exists, try to remove it
if exist build (
    echo Build directory still exists. Attempting manual removal...
    attrib -r -s -h build\*.* /s /d 2>nul
    rmdir /s /q build 2>nul
)

REM Final check
if exist build (
    echo.
    echo WARNING: Could not remove build directory.
    echo This may cause issues but we'll try to continue.
    echo TIP: Close any IDEs, file explorers, or terminals that might be using the build folder.
    echo.
)

REM Get dependencies
echo Getting dependencies...
call flutter pub get

REM Build AAB
echo Building AAB file for PROD flavor...
call flutter build appbundle --release --flavor prod --dart-define-from-file=.env.prod

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
echo %~dp0build\app\outputs\bundle\prodRelease\app-prod-release.aab
echo.
echo To upload to Google Play Console, use the file above.
echo.
pause
