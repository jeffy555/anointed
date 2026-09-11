@echo off
setlocal EnableExtensions
set "JAVA_HOME=D:\Anointed\tools\jdk-17"
set "ANDROID_HOME=C:\Users\JEFFY\AppData\Local\Android\Sdk"
set "FLUTTER_ROOT=D:\Anointed\tools\flutter-win"
set "PATH=%FLUTTER_ROOT%\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
set "ADB_SERIAL=emulator-5554"
set "PKG=com.anointed.anointed"
cd /d D:\Anointed\mobile

echo === Preflight ===
"%ADB%" devices
curl -sf http://localhost:8000/health || echo WARNING: backend not reachable on localhost:8000
echo.

"%ADB%" devices | findstr /c:"%ADB_SERIAL%" | findstr /c:"device" >nul
if errorlevel 1 (
  echo ERROR: Anointed emulator %ADB_SERIAL% is not running.
  echo Start the Anointed AVD, or use deploy-phone-usb.bat for your phone.
  exit /b 1
)

call flutter config --jdk-dir="%JAVA_HOME%"
call flutter pub get
if errorlevel 1 exit /b 1

set "GOOGLE_WEB_CLIENT_ID=534331923421-c28ata5t344743749pl7epediju17mju.apps.googleusercontent.com"
set "GOOGLE_ANDROID_CLIENT_ID=534331923421-hkmkr6udcsjdpnpmqtfmn9cn1c1hns88.apps.googleusercontent.com"

echo === Building debug APK ===
call flutter build apk --debug "--dart-define=API_BASE_URL=http://10.0.2.2:8000" "--dart-define=GOOGLE_SERVER_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID%" "--dart-define=GOOGLE_ANDROID_CLIENT_ID=%GOOGLE_ANDROID_CLIENT_ID%"
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)

echo === Installing on %ADB_SERIAL% ===
"%ADB%" -s %ADB_SERIAL% uninstall %PKG% >nul 2>&1
"%ADB%" -s %ADB_SERIAL% install -r -d build\app\outputs\flutter-apk\app-debug.apk
if errorlevel 1 exit /b 1

echo === Launching ===
"%ADB%" -s %ADB_SERIAL% shell am start -n %PKG%/%PKG%.MainActivity
echo SUCCESS - Anointed should be open on the emulator.
