@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Build a fresh phone APK and install via USB debugging.
rem Usage: deploy-phone-usb.bat [LAN_IP]
rem Always rebuilds — dist\anointed-phone-debug.apk is not reused.

set "JAVA_HOME=D:\Anointed\tools\jdk-17"
set "ANDROID_HOME=C:\Users\JEFFY\AppData\Local\Android\Sdk"
set "FLUTTER_ROOT=D:\Anointed\tools\flutter-win"
set "PATH=%FLUTTER_ROOT%\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
set "PKG=com.anointed.anointed"

echo === USB devices ===
"%ADB%" devices
echo.

set "PHONE_SERIAL="
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do (
  if /i "%%b"=="device" (
    echo %%a | findstr /i "emulator" >nul
    if errorlevel 1 (
      if not defined PHONE_SERIAL set "PHONE_SERIAL=%%a"
    )
  )
)

if not defined PHONE_SERIAL (
  echo ERROR: No physical phone detected.
  exit /b 1
)

echo Using phone: !PHONE_SERIAL!
echo.

echo === Building fresh phone APK ===
call "%~dp0build-phone-apk.bat" "%~1"
if errorlevel 1 exit /b 1

set "APK=D:\Anointed\dist\anointed-phone-debug.apk"
if not exist "%APK%" (
  echo ERROR: APK missing at %APK%
  exit /b 1
)

echo === Removing old install ===
"%ADB%" -s "!PHONE_SERIAL!" uninstall %PKG% >nul 2>&1

echo === Installing on phone !PHONE_SERIAL! ===
"%ADB%" -s "!PHONE_SERIAL!" install -r -d "%APK%"
if errorlevel 1 (
  echo INSTALL FAILED
  exit /b 1
)

"%ADB%" -s "!PHONE_SERIAL!" shell am start -n %PKG%/%PKG%.MainActivity
echo SUCCESS — fresh build installed on your phone.
