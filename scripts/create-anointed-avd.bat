@echo off
setlocal
set "SDK=C:\Users\JEFFY\AppData\Local\Android\Sdk"
echo no | "%SDK%\cmdline-tools\latest\bin\avdmanager.bat" create avd -n Anointed -k "system-images;android-36;google_apis;x86_64" -d pixel_6 --force
exit /b %ERRORLEVEL%
