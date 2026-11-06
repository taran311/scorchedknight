// The game as a PC app (the Windows build, for Steam): fullscreen by default, F11 or Alt+Enter
// to toggle it, and a way back to the desktop from Settings. The window itself answers on the
// "scorchedknight/window" channel (windows/runner/flutter_window.cpp).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Built for Steam (build_steam.bat passes --dart-define=SK_STEAM=true): the whole game is
/// yours (bought on Steam), and Steam Cloud keeps the save.
const steamBuild = bool.fromEnvironment('SK_STEAM');

/// Running as a PC app, not in a browser or on a phone.
bool get isDesktopApp => !kIsWeb && const {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}.contains(defaultTargetPlatform);

class Desktop extends ChangeNotifier {
  Desktop._();
  static final instance = Desktop._();

  static const _channel = MethodChannel('scorchedknight/window');
  static const _key = 'scorchedknight.fullscreen';

  bool fullscreen = false;

  /// Starts fullscreen (as PC games do) unless the player last chose a window; and listens for
  /// F11 and Alt+Enter.
  Future<void> init() async {
    if (!isDesktopApp) return;
    var want = true;
    try {
      want = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    } catch (_) {}
    await setFullscreen(want, keep: false);
    HardwareKeyboard.instance.addHandler(_keys);
  }

  bool _keys(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final k = e.logicalKey, alt = HardwareKeyboard.instance.isAltPressed;
    if (k == LogicalKeyboardKey.f11 || (alt && (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter))) {
      setFullscreen(!fullscreen);
      return true;
    }
    return false;
  }

  Future<void> setFullscreen(bool on, {bool keep = true}) async {
    if (!isDesktopApp) return;
    try {
      fullscreen = await _channel.invokeMethod<bool>('setFullscreen', on) ?? on;
    } catch (_) {
      return; // a runner without the window channel: stays as it is
    }
    if (keep) {
      try {
        await (await SharedPreferences.getInstance()).setBool(_key, fullscreen);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Back to the desktop, once [saveFirst] has written the hero away.
  Future<void> quit(Future<void> Function() saveFirst) async {
    try {
      await saveFirst();
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('quit');
    } catch (_) {
      SystemNavigator.pop();
    }
  }
}
