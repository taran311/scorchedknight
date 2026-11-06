@echo off
rem Builds Scorched Knight for Steam: a Windows build with the whole game unlocked (bought on
rem Steam), zipped ready for Steamworks (your app, then SteamPipe, then Builds / upload a depot).
rem Needs Visual Studio 2022 with "Desktop development with C++" (see docs\STEAM.md).
cd /d "%~dp0"

for /f "tokens=2 delims= " %%v in ('findstr /b "version:" pubspec.yaml') do set VERSION=%%v
echo Building Scorched Knight %VERSION% for Steam (Windows)...
echo.
call flutter build windows --release --dart-define=SK_STEAM=true
if errorlevel 1 (
  echo.
  echo The build failed. Scroll up for the first error.
  pause
  exit /b 1
)

set OUT=build\windows\x64\runner\Release
if not exist "build\steam" mkdir "build\steam"
if exist "build\steam\ScorchedKnight-windows.zip" del "build\steam\ScorchedKnight-windows.zip"
powershell -NoProfile -Command "Compress-Archive -Path '%OUT%\*' -DestinationPath 'build\steam\ScorchedKnight-windows.zip'"

echo.
echo Done. To try it: %OUT%\ScorchedKnight.exe
echo For Steam: build\steam\ScorchedKnight-windows.zip (upload it as the depot; launch option ScorchedKnight.exe)
explorer build\steam
pause
