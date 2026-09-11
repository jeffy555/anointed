@echo off
setlocal EnableExtensions
rem Export all level questions/answers to PDF files in dist\question-bank\
rem Requires Docker containers anointed-api + anointed-pg running.

set "ROOT=D:\Anointed"
set "OUT=%ROOT%\dist\question-bank"

echo === Checking Docker ===
docker ps --format "{{.Names}}" | findstr /c:"anointed-api" >nul
if errorlevel 1 (
  echo ERROR: Start the backend first ^(anointed-api container^).
  exit /b 1
)

echo === Installing PDF dependency in container ===
docker exec anointed-api pip install -q fpdf2
if errorlevel 1 exit /b 1

echo === Exporting 100 level PDFs + master ===
docker cp "%ROOT%\backend\app\scripts\export_questions_pdf.py" anointed-api:/app/app/scripts/export_questions_pdf.py
docker exec anointed-api python -m app.scripts.export_questions_pdf --output-dir /tmp/question-bank
if errorlevel 1 exit /b 1

if not exist "%OUT%" mkdir "%OUT%"
docker cp anointed-api:/tmp/question-bank/. "%OUT%\"
if errorlevel 1 exit /b 1

echo.
echo SUCCESS — PDFs written to:
echo   %OUT%
echo   anointed-all-levels.pdf  ^(all 2100 Q^&A in one file^)
echo   level-001.pdf … level-100.pdf  ^(one file per level^)
