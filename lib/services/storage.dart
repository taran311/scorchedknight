// Saves the game on the device (shared_preferences: local storage in the browser, app storage on
// Android), with the time of each save so a cloud copy (services/cloud.dart) can be compared.

import 'dart:convert';

import 'package:flutter/foundation.dart' show Listenable;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';

class GameStorage {
  GameStorage({String slot = 'main'}) : _key = 'scorchedknight.save.v1.$slot', _timeKey = 'scorchedknight.savedAt.v1.$slot';
  final String _key, _timeKey;

  /// When the save on this device was last written (ms since 1970; 0 if never or unknown).
  int savedAt = 0;

  Future<GameState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      savedAt = prefs.getInt(_timeKey) ?? 0;
      if (raw == null) return null;
      return GameState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null; // no storage, or a corrupt save: start fresh
    }
  }

  /// Writes [s]; [at] keeps a given time (a save brought down from the cloud keeps its own).
  Future<void> save(GameState s, {int? at}) async {
    savedAt = at ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(s.toJson()));
      await prefs.setInt(_timeKey, savedAt);
    } catch (_) {
      // Private windows can refuse storage; the game still plays, it just won't be kept.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_timeKey);
    } catch (_) {}
    savedAt = 0;
  }
}

/// A save as it sits in the cloud: the game's JSON, when it was made, and a line to show
/// ("Sir Smudge · Knight, level 12").
class CloudCopy {
  const CloudCopy(this.json, this.savedAt, this.summary);
  final String json;
  final int savedAt;
  final String summary;
}

/// Somewhere a save can be kept online (services/cloud.dart, on Firebase). The game only needs
/// these few things from it, so it plays the same with or without one.
abstract class SaveCloud implements Listenable {
  bool get signedIn;
  Future<CloudCopy?> fetch();
  Future<bool> push(String json, int savedAt, String summary);
  void markSynced();
}
