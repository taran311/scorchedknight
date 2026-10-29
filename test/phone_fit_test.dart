// Every screen on real phone sizes: nothing may overflow (Flutter's yellow-and-black stripes), and
// the buttons that matter must be on the screen without scrolling (the start button, the six
// places in town, each shop's Done, the map's Enter, the trail's next step, and the moves in a
// fight). Problems are gathered as it goes and reported together, so one run lists them all.
//
// Run: flutter test test/phone_fit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/controller.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart' show maxHp;
import 'package:scorchedknight/main.dart';
import 'package:scorchedknight/services/storage.dart';
import 'package:scorchedknight/ui/sign_in_screen.dart';
import 'package:scorchedknight/ui/theme.dart';

class MemoryStorage extends GameStorage {
  GameState? saved;
  @override
  Future<GameState?> load() async => saved;
  @override
  Future<void> save(GameState s, {int? at}) async => saved = s;
  @override
  Future<void> clear() async => saved = null;
}

const phones = <String, Size>{
  'small Android 360×640': Size(360, 640),
  'iPhone 390×844': Size(390, 844),
  'Pixel 412×915': Size(412, 915),
};

/// Lets animations run for a while (the town's ash never stops falling, so nothing "settles").
Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A hero partway through the game: Hob's roof mended, a few lands open, gold, ore and gems to
/// spend, so every shop has something to show.
Future<GameController> midGame() async {
  final c = GameController(storage: MemoryStorage());
  await c.load();
  c.chooseClass(HeroClass.knight);
  c.markTourSeen();
  c.takeHobsJob();
  final s = c.state, k = s.knight;
  s
    ..innRepaired = true
    ..unlocked = 3;
  k
    ..level = 15
    ..coins = 4000
    ..potions = 3;
  k.hp = maxHp(k);
  for (var i = 0; i < 4; i++) {
    s.reagents[i] = 8;
  }
  s.addMat(oreKey(Metal.iron), 9);
  s.addMat(barKey(Metal.iron), 4);
  s.addMat(gemKey(Gem.ruby), 2);
  return c;
}

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('every screen fits a $phone', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final problems = <String>[];
      var where = 'start';
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final first = d.exceptionAsString().split('\n').first;
        problems.add('$where: $first');
      };

      bool found(Finder f, String what) {
        if (f.evaluate().isNotEmpty) return true;
        problems.add('$where: couldn\'t find $what');
        return false;
      }

      /// [what] must be wholly on the screen, without scrolling.
      void onScreen(Finder f, String what) {
        if (!found(f, what)) return;
        final r = t.getRect(f.first), screen = Offset.zero & size;
        if (r.left < -.5 || r.top < -.5 || r.right > screen.right + .5 || r.bottom > screen.bottom + .5) {
          problems.add('$where: $what is off the screen (${r.left.round()},${r.top.round()} to ${r.right.round()},${r.bottom.round()} on ${size.width.round()}×${size.height.round()})');
        }
      }

      Future<void> tap(Finder f, String what, [int ms = 1200]) async {
        if (!found(f, what)) return;
        await t.tap(f.first, warnIfMissed: false);
        await settle(t, ms);
      }

      Future<void> back() async {
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        if (nav.canPop()) nav.pop();
        await settle(t, 800);
      }

      try {
        // ---- A new hero: the intro, then naming ----
        where = 'naming page';
        final fresh = GameController(storage: MemoryStorage());
        await fresh.load();
        await t.pumpWidget(ScorchedKnightApp(controller: fresh));
        await settle(t, 1500);
        await tap(find.text('Skip ›'), 'the intro\'s Skip', 800);
        onScreen(find.text('Walk to the Soot & Kettle'), 'the start button');

        // ---- Sign in ----
        where = 'sign-in screen';
        await t.pumpWidget(MaterialApp(theme: buildTheme(), home: SignInScreen(controller: await midGame())));
        await settle(t, 600);
        onScreen(find.text('Continue with Google'), 'Continue with Google');
        onScreen(find.text('Play without an account'), 'Play without an account');

        // ---- The town ----
        where = 'town';
        final c = await midGame();
        await t.pumpWidget(ScorchedKnightApp(controller: c));
        await settle(t, 1500);
        onScreen(find.text('Set out'), 'Set out');
        onScreen(find.textContaining('Soot & Kettle'), 'the Soot & Kettle');
        onScreen(find.text('Mags\' Stall'), 'Mags\' Stall');
        onScreen(find.text('$smithName\'s Forge'), 'the forge');
        onScreen(find.text('$mageName\'s Tower'), 'Old Wick\'s tower');
        onScreen(find.textContaining('Your Tent'), 'your tent');

        // ---- The three shops ----
        for (final (label, name) in const [('Mags\' Stall', 'Mags\' stall'), ('$smithName\'s Forge', 'the forge'), ('$mageName\'s Tower', 'Old Wick\'s tower')]) {
          where = name;
          await tap(find.text(label).last, name);
          onScreen(find.text('Done'), '$name\'s Done button');
          await tap(find.text('Done'), '$name\'s Done button', 600);
        }

        // ---- Your tent ----
        where = 'your tent';
        await tap(find.textContaining('Your Tent').last, 'your tent');
        await back();

        // ---- Settings ----
        where = 'settings';
        await tap(find.byTooltip('Settings'), 'the settings cog');
        await back();

        // ---- The map, the trail, a fight ----
        where = 'map';
        await tap(find.text('Set out'), 'Set out');
        onScreen(find.text('Enter'), 'the map\'s Enter');
        await tap(find.text('Enter'), 'Enter');
        where = 'trail';
        onScreen(find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Onward to')), 'the trail\'s next step');
        await tap(find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Onward to')), 'the trail\'s next step', 3000);
        where = 'battle';
        expect(c.state.inBattle, isTrue, reason: 'no fight started on a $phone');
        for (final move in const ['Attack', 'Potion', 'Flee']) {
          onScreen(find.text(move), 'the $move move');
        }
        // One blow from the win: the victory, the spoils, and back to town.
        c.state.foeHp = 1;
        await tap(find.text('Attack'), 'Attack', 6000);
        where = 'after the fight';
        await settle(t, 2000);
      } finally {
        FlutterError.onError = old;
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      }
      expect(problems, isEmpty, reason: '\n${problems.join('\n')}');
    });
  }
}
