@echo off
rem Adds the Android app to Scorched Knight (once), then makes it ours: name, icon, dark launch
rem screen, internet for cloud saves, Android 7.0+, release signing. Safe to run again.
cd /d "%~dp0\.."

if exist android\app\build.gradle.kts (
  echo Android project already there; re-applying Scorched Knight's settings.
) else (
  echo Creating the Android project...
  call flutter create --platforms=android --org com.scorchedknight --project-name scorchedknight .
  if errorlevel 1 (
    echo.
    echo flutter create failed. Is Flutter installed and on your PATH? Try: flutter doctor
    exit /b 1
  )
)

echo.
echo Applying Scorched Knight's Android settings...
call dart tool\android_patch.dart
if errorlevel 1 exit /b 1

echo.
echo Fetching packages...
call flutter pub get
echo.
echo Done. Next: see FIREBASE_SETUP.md, or plug in a phone and run: flutter run
