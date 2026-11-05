// Can the two attacks alone win everything? Plays road games and, at each boss card, puts the
// boss to [n] tries fighting with only attack + bash (and potions) and [n] with every tool.
// Then, after the Ember King, every boss again at the end level.
// Run: dart --packages=.dart_tool/package_config.json run tool/cheese.dart [games] [tries]

import 'dart:convert';
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';

import 'road_audit.dart' as ra;

double odds(GameEngine e, RoadStep st, int n, String pol) {
  final was = ra.policy;
  ra.policy = pol;
  final w = ra.winOdds(e, st, n);
  ra.policy = was;
  return w ?? -1;
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 4, n = args.length > 1 ? int.parse(args[1]) : 16;
  final tab = <String, List<double>>{};
  ra.policy = 'smart';
  for (var seed = 1; seed <= games; seed++) {
    final a = ra.Audit('road', seed);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed), clock: () => DateTime(2026, 6, 1));
    final rng = Random(seed * 7 + 1), s = e.state;
    e.takeHobsJob();
    final tried = <String>{};
    var loops = 0;
    while (!s.won && loops++ < 8000) {
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
      final road = e.roadStep();
      if (road == null) break;
      final ready = road.kind == RoadKind.heroic || ((road.kind == RoadKind.boss || road.kind == RoadKind.side) && s.winsToBoss(road.land) == 0);
      if (ready && road.why == null && tried.add(road.title)) {
        final f = odds(e, road, n, 'smart'), m = odds(e, road, n, 'melee');
        if (f >= 0) {
          final key = road.title.replaceAll(RegExp(r' · .*'), '');
          (tab[key] ??= [0, 0, 0]);
          tab[key]![0] += f;
          tab[key]![1] += m;
          tab[key]![2] += 1;
        }
      }
      ra.take(e, road, rng, a);
      if (!s.day && !(e.whyNotTravel(road.land) == null && continents[road.land].boss.night)) e.rest();
    }
    print('game $seed: won ${s.won} at level ${s.knight.level}, ${a.knockouts} KOs');
    // Post-game: every main and side boss again.
    if (s.won) {
      for (var c = 0; c < continents.length; c++) {
        final st = RoadStep(RoadKind.boss, 'rematch', '', c);
        final f = odds(e, st, n, 'smart'), m = odds(e, st, n, 'melee');
        if (f < 0) continue;
        final key = 'END ${continents[c].boss.name}';
        (tab[key] ??= [0, 0, 0]);
        tab[key]![0] += f;
        tab[key]![1] += m;
        tab[key]![2] += 1;
      }
    }
  }
  print('\n${'step'.padRight(60)} smart melee');
  for (final e in tab.entries) {
    final v = e.value;
    print('${e.key.padRight(60)} ${(100 * v[0] / v[2]).round().toString().padLeft(4)}% ${(100 * v[1] / v[2]).round().toString().padLeft(4)}%');
  }
}
