// Turns the stock Flutter Android project into Scorched Knight's: its name, icon, dark launch
// screen, internet access (for cloud saves), the minimum Android version Firebase needs, and
// release signing from android/key.properties. Safe to run again: each change checks first.
//
// Run by tool/setup_android.bat after `flutter create`; or by hand: dart tool/android_patch.dart

import 'dart:io';

void main() {
  if (!Directory('android').existsSync()) {
    stderr.writeln('No android folder yet: run tool/setup_android.bat (it runs `flutter create` first).');
    exit(1);
  }
  _manifest();
  _gradle();
  _launchScreen();
  _icons();
  _gitignore();
  stdout.writeln('\nAndroid project ready. Plug in a phone (or start an emulator) and run: flutter run');
}

void _edit(String path, String Function(String) change, String what) {
  final f = File(path);
  if (!f.existsSync()) {
    stdout.writeln('  ! $path not found, skipped ($what)');
    return;
  }
  final before = f.readAsStringSync(), after = change(before);
  if (after != before) {
    f.writeAsStringSync(after);
    stdout.writeln('  ✓ $what');
  } else {
    stdout.writeln('  · $what (already done)');
  }
}

void _manifest() => _edit('android/app/src/main/AndroidManifest.xml', (s) {
  // The name under the icon.
  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Scorched Knight"');
  // Google sign-in opens a browser tab; with an empty task affinity it closes when you switch
  // apps (to a password manager, say), so drop it.
  s = s.replaceAll(RegExp(r'\s*android:taskAffinity=""'), '');
  // Cloud saves need the internet.
  if (!s.contains('android.permission.INTERNET')) {
    s = s.replaceFirst('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
  }
  return s;
}, 'AndroidManifest: name, internet, sign-in tab');

void _gradle() => _edit('android/app/build.gradle.kts', (s) {
  // Firebase's Android libraries need Android 7.0 (API 24) or later.
  s = s.replaceFirst(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = maxOf(24, flutter.minSdkVersion)');
  if (!s.contains('key.properties')) {
    // Release signing: from android/key.properties when it's there (see FIREBASE_SETUP.md, "Play
    // Store"), otherwise the debug key so `flutter run --release` still works.
    s = s.replaceFirst('plugins {', '''import java.util.Properties
import java.io.FileInputStream

// Release signing keys live in android/key.properties (never committed). See FIREBASE_SETUP.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {''');
    s = s.replaceFirst(RegExp(r'\n    buildTypes \{'), '''
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {''');
    s = s.replaceFirst('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")');
  }
  return s;
}, 'build.gradle.kts: Android 7.0+, release signing');

void _launchScreen() {
  // The moment before the game draws: the game's dark stone, not a white flash.
  for (final dir in ['drawable', 'drawable-v21']) {
    _edit('android/app/src/main/res/$dir/launch_background.xml', (s) {
      return s.replaceAll(RegExp(r'<item android:drawable="[^"]*" />'), '<item><color android:color="#14110D"/></item>');
    }, 'launch screen ($dir): dark');
  }
}

void _icons() {
  var n = 0;
  for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    final src = File('tool/android/res/mipmap-$d/ic_launcher.png');
    final dest = Directory('android/app/src/main/res/mipmap-$d');
    if (!src.existsSync() || !dest.existsSync()) continue;
    src.copySync('${dest.path}/ic_launcher.png');
    n++;
  }
  stdout.writeln(n > 0 ? '  ✓ app icon ($n sizes)' : '  ! app icon not copied');
}

void _gitignore() => _edit('android/.gitignore', (s) {
  for (final line in ['key.properties', '**/*.keystore', '**/*.jks']) {
    if (!s.split('\n').contains(line)) s = '${s.trimRight()}\n$line\n';
  }
  return s;
}, '.gitignore: keep signing keys out of git');
