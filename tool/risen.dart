// Each main land's boss, risen: the win rate from full health with three potions, for the hero as
// they first faced that land's boss (about the earliest a player meets it risen, since it rises a
// few levels past the land's own). Run: dart run tool/risen.dart [runs]
import 'dart:convert';
import 'dart:math';
import '../lib/game/catalog.dart';
import '../lib/game/engine.dart';
import '../lib/game/models.dart';
import '../lib/game/rules.dart';
import 'balance.dart';
import 'trials.dart' show blade;

void main(List<String> args) {
  final runs = args.isEmpty ? 8 : int.parse(args.first);
  final at = List.generate(continents.length, (_) => <String>[]);
  for (var i = 0; i < runs; i++) {
    run('all', 5000 + i, Stats(), onChallenge: (e, c) => at[c].add(jsonEncode(e.state.toJson())));
  }
  print('land                    lvl  n   smart win  tries   blade win  tries   turns');
  for (var c = 0; c < mainLands; c++) {
    final ss = at[c];
    if (ss.isEmpty) continue;
    (double, double) trial(BattleAction Function(GameEngine e) pick) {
      var wins = 0, n = 0, turns = 0;
      for (final (i, snap) in ss.indexed) {
        for (var rep = 0; rep < 12; rep++) {
          final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(700 + i * 31 + rep), clock: () => DateTime(2026, 6, 1));
          final s = e.state, k = s.knight;
          s.bossesDown.add(c);
          s.continent = c;
          k.level = max(k.level, e.risenLevel(c));
          k.hp = maxHp(k);
          k.potions = 3;
          e.exploreHeroic();
          var ko = false, t = 0;
          while (s.inBattle && t < 200) {
            final a = k.hp < maxHp(k) * .4 && e.whyNot(BattleAction.potion) == null ? BattleAction.potion : pick(e);
            if (e.takeTurn(a).knockedOut) ko = true;
            t++;
          }
          n++;
          turns += t;
          if (!ko) wins++;
        }
      }
      return (wins / n, turns / n);
    }

    final lvl = ss.map((x) => GameState.fromJson(jsonDecode(x) as Map<String, dynamic>).knight.level).reduce((a, b) => a + b) / ss.length;
    final (sw, st) = trial((e) => choose(e, 'all'));
    final (bw, _) = trial(blade);
    String t(double w) => w == 0 ? '  inf' : (1 / w).toStringAsFixed(2).padLeft(5);
    print('${continents[c].name.padRight(22)} ${lvl.toStringAsFixed(0).padLeft(4)} ${ss.length.toString().padLeft(2)}   ${(sw * 100).round().toString().padLeft(4)}%  ${t(sw)}   ${(bw * 100).round().toString().padLeft(4)}%  ${t(bw)}   ${st.toStringAsFixed(1)}');
  }
}
