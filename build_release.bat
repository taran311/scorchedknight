@echo off
rem Builds Scorched Knight for Google Play: android\app-release.aab, signed with your upload key.
rem Before each new upload, raise "version:" in pubspec.yaml (1.0.0+1 -> 1.0.1+2): the number
rem after the + must always go up, or Play refuses the file.
cd /d "%~dp0"

if not exist "android\key.properties" (
  echo No upload key yet. Make it once with:
  echo   powershell -ExecutionPolicy Bypass -File scripts\make_upload_key.ps1
  echo.
  pause
  exit /b 1
)

for /f "tokens=2 delims= " %%v in ('findstr /b "version:" pubspec.yaml') do set VERSION=%%v
echo Building Scorched Knight %VERSION% for Google Play...
echo.
call flutter build appbundle --release
if errorlevel 1 (
  echo.
  echo The build failed. Scroll up for the first error.
  pause
  exit /b 1
)

echo.
echo Done: build\app\outputs\bundle\release\app-release.aab
echo Upload it in Play Console: Test and release, then your track, then Create new release.
explorer build\app\outputs\bundle\release
pause
