@echo off
setlocal EnableExtensions
set "ROOT=D:\Anointed"
set "OUT=%ROOT%\dist\anointed-application-review.pdf"

echo === Generating application review PDF ===
python "%ROOT%\scripts\generate_application_review_pdf.py" --output "%OUT%"
if errorlevel 1 (
  echo Trying with py launcher...
  py -3 "%ROOT%\scripts\generate_application_review_pdf.py" --output "%OUT%"
)
if errorlevel 1 (
  echo Installing fpdf2...
  pip install -q fpdf2
  python "%ROOT%\scripts\generate_application_review_pdf.py" --output "%OUT%"
)
if errorlevel 1 exit /b 1

echo.
echo SUCCESS: %OUT%
