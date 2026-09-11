@echo off
setlocal EnableExtensions
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "ANDROID_HOME=C:\Users\JEFFY\AppData\Local\Android\Sdk"
set "PATH=D:\Anointed\tools\flutter-win\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
cd /d D:\Anointed\mobile

echo.
echo === Anointed deploy ===
echo Emulator:
"%ANDROID_HOME%\platform-tools\adb.exe" devices
echo API target: http://10.0.2.2:8000
echo.

flutter pub get
if errorlevel 1 exit /b 1

flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
exit /b %ERRORLEVEL%
