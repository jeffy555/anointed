@echo off
setlocal EnableExtensions
rem Stop anything on port 8000, migrate, seed, start fresh backend.

set "JAVA_HOME=D:\Anointed\tools\jdk-17"
cd /d D:\Anointed\backend

echo === Stopping old API on port 8000 ===
powershell -NoProfile -Command ^
  "$p = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; ^
   foreach ($pid in $p) { if ($pid -gt 0) { Write-Host \"Killing PID $pid\"; Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue } }"
ping -n 3 127.0.0.1 >nul

echo.
echo === Database (.env) ===
findstr /b "DATABASE_URL GOOGLE_OAUTH" .env
echo.

echo === Migrate ===
call .venv\Scripts\python.exe -m alembic upgrade head
if errorlevel 1 exit /b 1

echo === Seed content (dev) ===
call .venv\Scripts\python.exe -m app.scripts.seed_content --questions-per-level 5 --publish
if errorlevel 1 exit /b 1

echo === Diagnostics ===
call .venv\Scripts\python.exe scripts\diagnose_auth.py
if errorlevel 1 exit /b 1

echo.
echo === Starting API ===
start "Anointed API" /D "D:\Anointed\backend" cmd /k .venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

ping -n 4 127.0.0.1 >nul
curl -sf http://localhost:8000/health || (
  echo ERROR: Backend did not start
  exit /b 1
)
echo.
echo SUCCESS — backend restarted. Phone APK must use this PC IP on port 8000.
exit /b 0
