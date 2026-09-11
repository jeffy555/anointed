@echo off
setlocal EnableExtensions
rem Print debug keystore SHA-1 / SHA-256 for Google Cloud Console Android OAuth client.

set "KEYTOOL=D:\Anointed\tools\jdk-17\bin\keytool.exe"
set "KEYSTORE=%USERPROFILE%\.android\debug.keystore"

echo Package name for Google Console: com.anointed.anointed
echo.
echo Debug keystore fingerprints:
"%KEYTOOL%" -list -v -keystore "%KEYSTORE%" -alias androiddebugkey -storepass android -keypass android | findstr /i "SHA1 SHA256"
echo.
echo Add the SHA-1 to: Google Cloud Console ^> Credentials ^> Android OAuth client
pause
