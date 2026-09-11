@echo off
setlocal EnableExtensions
rem Force a clean reinstall on the Anointed emulator (fixes stale APK / hung adb).

set "JAVA_HOME=D:\Anointed\tools\jdk-17"
set "ANDROID_HOME=C:\Users\JEFFY\AppData\Local\Android\Sdk"
set "FLUTTER_ROOT=D:\Anointed\tools\flutter-win"
set "PATH=%FLUTTER_ROOT%\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
set "ADB_SERIAL=emulator-5554"
set "PKG=com.anointed.anointed"
cd /d D:\Anointed\mobile

echo === Target: %ADB_SERIAL% ===
"%ADB%" kill-server
"%ADB%" start-server
"%ADB%" devices
echo.

"%ADB%" devices | findstr /c:"%ADB_SERIAL%" | findstr /c:"device" >nul
if errorlevel 1 (
  echo ERROR: Start the Anointed emulator first ^(%ADB_SERIAL%^).
  exit /b 1
)

echo === Removing old install ===
"%ADB%" -s %ADB_SERIAL% uninstall %PKG% >nul 2>&1
echo.

call flutter config --jdk-dir="%JAVA_HOME%"
call flutter clean
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

echo === Installing fresh APK ===
"%ADB%" -s %ADB_SERIAL% install -r -d build\app\outputs\flutter-apk\app-debug.apk
if errorlevel 1 (
  echo INSTALL FAILED
  exit /b 1
)

echo === Launching ===
"%ADB%" -s %ADB_SERIAL% shell am start -n %PKG%/%PKG%.MainActivity
echo.
echo SUCCESS — build 1.0.0+2 with Parchment Codex map should be on the emulator.
echo Look for: cream background, "Level map" header, Genesis chapter cards.
