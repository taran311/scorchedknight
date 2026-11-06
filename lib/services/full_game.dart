// The full game: the road from Cindervale to the Grimtusk Badlands, and the side lands that open
// from it, are free; one purchase on Google Play opens the rest for good (no subscription, no ads).
// The web is the free lands, with a way to the app. A hero who'd already gone further before the
// unlock existed keeps everything (see [grandfather]).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/engine.dart';
import 'full_game_stub.dart' if (dart.library.io) 'full_game_native.dart' as store;

/// The one-off product's id in Play Console (Monetise → Products → In-app products).
const fullGameProduct = 'full_game';

/// The game's page on Google Play.
const playStoreLink = 'https://play.google.com/store/apps/details?id=com.scorchedknight.scorchedknight';

class FullGame extends ChangeNotifier {
  FullGame._();
  static final instance = FullGame._();

  static const _key = 'scorchedknight.fullGame';

  /// Unlocked on this device.
  bool owned = false;

  /// The price in the player's currency, from Google Play ("£4.99"); null till the store answers.
  String? price;

  /// A purchase or restore under way.
  bool busy = false;

  /// The last thing that went wrong, to show.
  String? problem;

  /// This build can buy it (the Android app); the web can't.
  bool get canBuy => store.supported;

  Future<void> init() async {
    var have = false;
    try {
      have = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {}
    // Your own builds: the dev server on this computer, and an app built with
    // --dart-define=SK_FULL=true.
    if (kIsWeb && const {'localhost', '127.0.0.1'}.contains(Uri.base.host)) have = true;
    if (const bool.fromEnvironment('SK_FULL')) have = true;
    _set(have, keep: false);
    // (Not waited for: a slow Google Play mustn't hold the game's first screen up.)
    store.init(this).catchError((Object _) {
      problem = 'Couldn\'t reach Google Play just now';
      notifyListeners();
    });
  }

  void _set(bool v, {bool keep = true}) {
    owned = v;
    GameEngine.fullGame = v;
    if (v && keep) {
      SharedPreferences.getInstance().then((p) => p.setBool(_key, true)).catchError((_) => false);
    }
    notifyListeners();
  }

  /// Bought (or restored): the whole game, for good.
  Future<void> grant() async {
    busy = false;
    problem = null;
    _set(true);
  }

  /// A hero who'd already been past the free lands before the unlock existed (a tester, or the web
  /// game before it): theirs to keep.
  void grandfather(GameEngine e) {
    if (!owned && e.beyondFreeLands) _set(true);
  }

  Future<void> buy() async {
    if (owned || busy) return;
    problem = null;
    await store.buy(this);
  }

  Future<void> restore() async {
    problem = null;
    busy = true;
    notifyListeners();
    await store.restore(this);
    // (Google answers on the purchase stream if there's anything to restore; nothing, and nothing comes.)
    await Future<void>.delayed(const Duration(seconds: 3));
    if (busy && !owned) {
      busy = false;
      problem = 'No purchase found on this Google account';
    }
    notifyListeners();
  }

  /// The store's news, for the screens.
  void changed() => notifyListeners();
}
