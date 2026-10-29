@echo off
rem Runs Scorched Knight at http://localhost:5070 for your everyday Chrome to open.
rem (CalorieKnight uses 5050, so both can run at once.) Serving it this way, rather than
rem "flutter run -d chrome", keeps your hero: Chrome's throwaway debug profile would forget it.
rem It's a release build, so it plays smoothly; it rebuilds itself whenever a file in lib changes
rem (tool\dev.dart, about a minute, then refresh the page) and opens Chrome once it's ready.
rem "run_web.bat debug" runs the debug build instead: updates in seconds, but plays slower.
rem r, R and q still work here too. A log goes to .dart_tool\dev.log.
cd /d "%~dp0"
if not exist ".dart_tool" call flutter pub get
call dart tool\dev.dart %*
if errorlevel 1 (
  echo.
  echo Something went wrong. The log is in .dart_tool\dev.log
  pause
)
