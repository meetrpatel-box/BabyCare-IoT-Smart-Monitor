@echo off
REM Flutter Web Run Script
REM Saved for future reference - Child Psychology Guideline Testing
REM Flutter Location: R:\dev\flutter\bin\flutter.bat

echo ============================================
echo Flutter App - Child Psychology Test Run
echo ============================================
echo.

REM Navigate to the Flutter project directory
cd /d "%~dp0"

echo Running Flutter web app on Chrome...
echo Using Flutter from: R:\dev\flutter\bin\flutter.bat
echo.

REM Run Flutter on Chrome using full path
"R:\dev\flutter\bin\flutter.bat" run -d chrome

pause
