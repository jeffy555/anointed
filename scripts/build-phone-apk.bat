@echo off
setlocal EnableExtensions
rem Build a debug APK for a physical Android phone on the same Wi-Fi as this PC.
rem Expo Go cannot run Flutter apps — sideload this APK or use deploy-phone-usb.bat.
rem Usage: build-phone-apk.bat [LAN_IP]
rem Example: build-phone-apk.bat 192.168.1.42

set "JAVA_HOME=D:\Anointed\tools\jdk-17"
set "ANDROID_HOME=C:\Users\JEFFY\AppData\Local\Android\Sdk"
set "FLUTTER_ROOT=D:\Anointed\tools\flutter-win"
set "PATH=%FLUTTER_ROOT%\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
cd /d D:\Anointed\mobile

set "API_HOST=%~1"
if "%API_HOST%"=="" call :detect_lan_ip
if "%API_HOST%"=="" goto :missing_ip

call :validate_ip "%API_HOST%"
if errorlevel 1 goto :invalid_ip

echo %API_HOST% | findstr /r "\.[0-9][0-9]*\.1$" >nul
if not errorlevel 1 (
  echo WARNING: %API_HOST% is usually your router, not this PC.
  echo Use the IPv4 from ipconfig ^(often 192.168.x.x where x is not 1^).
  echo.
)

set "API_URL=http://%API_HOST%:8000"
set "GOOGLE_WEB_CLIENT_ID=534331923421-c28ata5t344743749pl7epediju17mju.apps.googleusercontent.com"
set "GOOGLE_ANDROID_CLIENT_ID=534331923421-hkmkr6udcsjdpnpmqtfmn9cn1c1hns88.apps.googleusercontent.com"
echo === Phone APK build ===
echo API URL: %API_URL%
echo Ensure backend is running and phone is on the same Wi-Fi.
echo.

curl -sf http://localhost:8000/health || echo WARNING: backend not reachable on localhost:8000
echo.

call flutter config --jdk-dir="%JAVA_HOME%"
call flutter pub get
if errorlevel 1 exit /b 1

echo === Building debug APK for phone ===
call flutter build apk --debug "--dart-define=API_BASE_URL=%API_URL%" "--dart-define=GOOGLE_SERVER_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID%" "--dart-define=GOOGLE_ANDROID_CLIENT_ID=%GOOGLE_ANDROID_CLIENT_ID%"
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)

set "APK=build\app\outputs\flutter-apk\app-debug.apk"
set "OUT=D:\Anointed\dist\anointed-phone-debug.apk"
if not exist "D:\Anointed\dist" mkdir "D:\Anointed\dist"
copy /y "%APK%" "%OUT%" >nul

echo.
echo SUCCESS
echo APK: %OUT%
echo.
echo Install options:
echo   1. USB:  scripts\deploy-phone-usb.bat
echo   2. Manual: copy APK to phone and open it ^(enable Install unknown apps^)
echo   3. Share:  send anointed-phone-debug.apk via Drive/email/etc.
echo.
echo On first launch, phone must reach %API_URL%
echo Allow Windows Firewall inbound on port 8000 if requests fail.
exit /b 0

:validate_ip
powershell -NoProfile -Command "if ('%~1' -match '^\d{1,3}(\.\d{1,3}){3}$') { exit 0 } else { exit 1 }"
if errorlevel 1 exit /b 1
exit /b 0

:detect_lan_ip
rem Prefer a real Wi-Fi/Ethernet IPv4 address; skip WSL/Hyper-V virtual adapters.
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$n = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue ^| Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' -and $_.InterfaceAlias -notmatch 'vEthernet^|WSL^|Hyper-V^|VirtualBox^|VMware^|Loopback' } ^| Sort-Object -Property InterfaceMetric ^| Select-Object -First 1; if ($n) { $n.IPAddress }"`) do set "API_HOST=%%i"
if not "%API_HOST%"=="" exit /b 0
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue ^| Where-Object { $_.IPAddress -match '^(192\.168\.|^10\.|^172\.(1[6-9]^|2[0-9]^|3[0-1])\.)' } ^| Select-Object -First 1).IPAddress"`) do set "API_HOST=%%i"
exit /b 0

:invalid_ip
echo ERROR: Invalid LAN IP "%API_HOST%".
echo Pass your PC IPv4 ^(not the router^), for example:
echo   D:\Anointed\scripts\build-phone-apk.bat 192.168.1.42
exit /b 1

:missing_ip
echo ERROR: Could not detect your PC LAN IP.
echo.
echo Pass it explicitly ^(same Wi-Fi as your phone^):
echo   D:\Anointed\scripts\build-phone-apk.bat 192.168.1.42
echo.
echo Find it: run ipconfig and use "Wireless LAN adapter Wi-Fi" IPv4 Address.
exit /b 1
