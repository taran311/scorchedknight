// Screens: a new hero picks a path, lands at the Inn, opens the map and fights. Run: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/controller.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/main.dart';
import 'package:scorchedknight/services/storage.dart';
import 'package:scorchedknight/ui/trail_data.dart' show trailStops;

/// Keeps the save in memory, so tests never touch the browser's storage.
class MemoryStorage extends GameStorage {
  GameState? saved;
  @override
  Future<GameState?> load() async => saved;
  @override
  Future<void> save(GameState s, {int? at}) async => saved = s;
  @override
  Future<void> clear() async => saved = null;
}

/// Lets animations run for a while (the Inn's ash never stops falling, so nothing "settles").
Future<void> settle(WidgetTester t, [int ms = 3000]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a new knight is named and arrives at the Soot & Kettle', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 900));
    final c = GameController(storage: MemoryStorage());
    await c.load();
    await t.pumpWidget(ScorchedKnightApp(controller: c));
    await settle(t, 1500);
    expect(find.text('SCORCHED KNIGHT'), findsOneWidget); // the intro's title card
    await t.tap(find.text('Skip ›'));
    await settle(t, 800);
    expect(find.text('SCORCHED KNIGHT'), findsOneWidget); // the naming page
    await t.enterText(find.byType(TextField), 'Sir Cinders');
    await t.tap(find.text('Walk to the Soot & Kettle'));
    await settle(t, 1000);
    expect(c.state.knight.classChosen, isTrue);
    expect(c.state.settings.name, 'Sir Cinders');
    // Hob calls you straight over (the cutscene already told the story): talk him through, take his job.
    for (var i = 0; i < 30 && find.text('Thanks, Hob').evaluate().isEmpty && c.jobOffered; i++) {
      if (find.text('Accept quest').evaluate().isNotEmpty) {
        await t.tap(find.text('Accept quest'));
      } else if (find.text('Next  ›').evaluate().isNotEmpty) {
        await t.tap(find.text('Next  ›'));
      } else if (find.text('Skip  ››').evaluate().isNotEmpty) {
        await t.tap(find.text('Skip  ››'));
      }
      await settle(t, 400);
    }
    for (var i = 0; i < 10 && find.text('Thanks, Hob').evaluate().isNotEmpty; i++) {
      await t.tap(find.text('Thanks, Hob'), warnIfMissed: false);
      await settle(t, 400);
    }
    await settle(t, 600);
    expect(find.text('The Soot & Kettle'), findsWidgets);
    expect(find.text('Set out'), findsOneWidget);
  });

  testWidgets('from the map into a fight, and a turn plays out', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1400));
    final c = GameController(storage: MemoryStorage());
    await c.load();
    c.chooseClass(HeroClass.knight);
    c.markTourSeen();
    c.takeHobsJob(); // otherwise Hob stops you at the door to offer it
    await t.pumpWidget(ScorchedKnightApp(controller: c));
    await settle(t, 500);
    await t.tap(find.text('Set out'));
    await settle(t, 800);
    expect(find.text(continents.first.name), findsWidgets);
    // The map: into Cindervale, then along its trail to the first stop.
    await t.tap(find.text('Enter'));
    await settle(t, 800);
    await t.tap(find.byTooltip('Onward to ${trailStops[0][0]}'));
    await settle(t, 2500);
    expect(c.state.inBattle, isTrue);
    expect(c.busy, isFalse);
    final hp = c.state.foeHp;
    await t.tap(find.text('Attack'));
    await settle(t, 4000);
    expect(c.state.foeHp < hp || !c.state.inBattle, isTrue);
    expect(c.busy, isFalse);
  });
}
