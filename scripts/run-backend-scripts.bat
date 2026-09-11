@echo off
setlocal EnableExtensions
rem Run backend maintenance scripts (migrate, seed, auth/DB diagnostics).

cd /d D:\Anointed\backend

if not exist ".venv\Scripts\python.exe" (
  echo ERROR: Create venv first: python -m venv .venv ^& pip install -r requirements-dev.txt
  exit /b 1
)

echo === alembic upgrade head ===
call .venv\Scripts\python.exe -m alembic upgrade head
if errorlevel 1 exit /b 1

echo.
echo === seed_content (5 questions/level) ===
call .venv\Scripts\python.exe -m app.scripts.seed_content --questions-per-level 5 --publish
if errorlevel 1 exit /b 1

echo.
echo === diagnose_auth ===
call .venv\Scripts\python.exe scripts\diagnose_auth.py
exit /b %ERRORLEVEL%
