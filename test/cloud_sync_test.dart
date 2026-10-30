// Cloud saves: which hero wins when this device and the cloud disagree.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/controller.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/services/storage.dart';

class _Memory extends GameStorage {
  GameState? saved;
  @override
  Future<GameState?> load() async => saved;
  @override
  Future<void> save(GameState s, {int? at}) async {
    saved = s;
    savedAt = at ?? DateTime.now().millisecondsSinceEpoch;
  }
}

class _FakeCloud extends ChangeNotifier implements SaveCloud {
  CloudCopy? copy;
  int pushes = 0;
  bool _in = true;
  @override
  bool get signedIn => _in;
  set signedIn(bool v) {
    _in = v;
    notifyListeners();
  }

  @override
  Future<CloudCopy?> fetch() async => copy;
  @override
  Future<bool> push(String json, int savedAt, String summary) async {
    pushes++;
    copy = CloudCopy(json, savedAt, summary);
    return true;
  }

  @override
  void markSynced() {}
}

GameState _hero(int level) {
  final s = GameEngine.newGame(heroClass: HeroClass.knight);
  s.knight
    ..classChosen = true
    ..level = level;
  s.foesFelled = level * 5;
  return s;
}

void main() {
  test('nothing in the cloud yet: this device\'s hero goes up', () async {
    final store = _Memory()..saved = _hero(5);
    final cloud = _FakeCloud();
    final c = GameController(storage: store, cloud: cloud);
    await c.load();
    await c.syncWithCloud();
    expect(cloud.pushes, greaterThan(0));
    expect(cloud.copy!.summary, contains('level 5'));
  });

  test('a brand-new hero on this device takes the cloud save without asking', () async {
    final store = _Memory();
    final cloud = _FakeCloud()..copy = CloudCopy(jsonEncode(_hero(12).toJson()), 1000, 'Sir Smudge · Knight, level 12');
    final c = GameController(storage: store, cloud: cloud);
    await c.load();
    await c.syncWithCloud();
    expect(c.state.knight.level, 12);
    expect(c.cloudChoice, isNull);
  });

  test('real progress on both, cloud newer: the player is asked, and can pick either', () async {
    final store = _Memory()..saved = _hero(4);
    final cloud = _FakeCloud();
    final c = GameController(storage: store, cloud: cloud);
    await c.load();
    store.savedAt = 100;
    cloud.copy = CloudCopy(jsonEncode(_hero(9).toJson()), 200, 'Sir Smudge · Knight, level 9');
    await c.syncWithCloud();
    expect(c.cloudChoice, isNotNull);
    await c.keepDeviceSave();
    expect(c.state.knight.level, 4);
    expect(cloud.copy!.summary, contains('level 4'));
  });

  test('this device newer: it goes up over the cloud\'s', () async {
    final store = _Memory()..saved = _hero(7);
    final cloud = _FakeCloud();
    final c = GameController(storage: store, cloud: cloud);
    await c.load();
    store.savedAt = 500;
    cloud.copy = CloudCopy(jsonEncode(_hero(3).toJson()), 100, 'old');
    await c.syncWithCloud();
    expect(c.cloudChoice, isNull);
    expect(cloud.copy!.summary, contains('level 7'));
  });
}
