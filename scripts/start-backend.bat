@echo off
setlocal EnableExtensions
rem Start the Anointed API on port 8000 (all interfaces so phones on Wi-Fi can connect).
rem Reads DATABASE_URL and GOOGLE_OAUTH_CLIENT_IDS from backend\.env

set "JAVA_HOME=D:\Anointed\tools\jdk-17"
cd /d D:\Anointed\backend

if not exist ".venv\Scripts\python.exe" (
  echo ERROR: Run once: python -m venv .venv ^& pip install -r requirements-dev.txt
  exit /b 1
)

echo === Database ===
findstr /b "DATABASE_URL" .env 2>nul
echo.

echo === Migrating ===
call .venv\Scripts\python.exe -m alembic upgrade head
if errorlevel 1 exit /b 1

echo === Starting API on http://0.0.0.0:8000 ===
echo Phone builds must use your PC LAN IP, e.g. http://192.168.1.x:8000
call .venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
