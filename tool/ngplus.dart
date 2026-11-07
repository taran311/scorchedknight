// New Game+ put to the test: a road player beats the Ember King, starts New Game+, and plays the
// road again. Knockouts, fights and the level at each boss, first time round and second.
// Run: dart --packages=.dart_tool/package_config.json run tool/ngplus.dart [games]
import 'dart:io';
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/models.dart';

import 'road_audit.dart' as ra;

/// Plays the road from where [e] stands to the Ember King (or [cap] fights).
ra.Audit road(GameEngine e, int seed, {int cap = 2500}) {
  final a = ra.Audit('road', seed), s = e.state, rng = Random(seed * 7 + 1);
  var loops = 0;
  while (!s.won && a.fights < cap && loops++ < cap * 3) {
    ra.inTown(e, careless: false);
    if (s.inBattle) {
      ra.fight(e, rng, a);
      continue;
    }
    if (!s.innRepaired) {
      e.travel(0);
      e.explore();
      ra.fight(e, rng, a);
      continue;
    }
    final st = e.roadStep();
    if (st == null) break;
    ra.take(e, st, rng, a);
    if (!s.day && !(e.whyNotTravel(st.land) == null && continents[st.land].boss.night)) e.rest();
  }
  a.won = s.won;
  return a;
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 8;
  final perBoss = <String, List<int>>{};
  var kos = [0, 0], fights = [0, 0], won = [0, 0];
  final perGame = [<int>[], <int>[]];
  final winLevel = <String, List<int>>{};
  ra.onFight = (e, f, t, l, ko) {
    if (f.boss && !ko && e.state.ng > 0) (winLevel[f.name] ??= []).add(e.state.knight.level);
    if (!f.boss || !ko) return;
    (perBoss['${e.state.ng} ${f.name}'] ??= []).add(1);
  };
  for (var seed = 1; seed <= games; seed++) {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed), clock: () => DateTime(2026, 6, 1));
    e.takeHobsJob();
    for (var round = 0; round < 2; round++) {
      final a = road(e, seed + round * 100);
      kos[round] += a.knockouts;
      perGame[round].add(a.knockouts);
      fights[round] += a.fights;
      if (a.won) won[round]++;
      if (round == 0) {
        // HEIR=3 (the default): the three strongest pieces owned carried as heirlooms; HEIR=0: none.
        final take = int.parse(Platform.environment['HEIR'] ?? '3');
        // (The weapon you fight with, then the strongest pieces that aren't weapons: a top-scoring
        // two-hander would cost the knight their shield.)
        final worn = e.state.knight.loadout.weapon, rest = [for (final g in e.heirloomChoices) if (g.slot != GearSlot.weapon && g.slot != GearSlot.offhand) g];
        final picks = [if (worn != null && take > 0) worn, ...rest.take(take - (worn != null && take > 0 ? 1 : 0))];
        if (seed == 1) print('heirlooms: ${picks.map((g) => '${g.name} (${g.rarity.name} ${g.slot.name})').join(', ')}');
        if (!e.state.won || !e.newGamePlus(heirlooms: [for (final g in picks) g.id])) break;
        e.takeHobsJob();
      }
    }
  }
  for (var r = 0; r < 2; r++) {
    print('${r == 0 ? 'first time' : 'New Game+ '}: won ${won[r]}/$games · ${(fights[r] / games).round()} fights · ${(kos[r] / games).toStringAsFixed(1)} knockouts a game');
  }
  for (var r = 0; r < 2; r++) {
    final g = perGame[r]..sort();
    if (g.isNotEmpty) print('${r == 0 ? 'first' : 'NG+  '} knockouts: median ${g[g.length ~/ 2]} · quartiles ${g[g.length ~/ 4]}-${g[g.length * 3 ~/ 4]} · worst ${g.last}');
  }
  print('NG+ level at each boss win:');
  for (final e in winLevel.entries) {
    print('  ${e.key}: ${(e.value.reduce((a, b) => a + b) / e.value.length).toStringAsFixed(1)}');
  }
  final worst = perBoss.entries.toList()..sort((a, b) => b.value.length - a.value.length);
  print('most boss knockouts (per game):');
  for (final e in worst.take(10)) {
    print('  ${(e.value.length / games).toStringAsFixed(1)}  ${e.key.startsWith('0') ? 'first' : 'NG+  '} ${e.key.substring(2)}');
  }
}
