// Every land's boss, main and side, from snapshots taken the moment the auto-player first
// challenges it: the win rate from full health with three potions, for a player who uses
// everything (choose 'all') and one who only swings. Expected tries = 1 / win rate.
// Run: dart run tool/bosses.dart [runs]
import 'dart:convert';
import 'dart:math';
import '../lib/game/catalog.dart';
import '../lib/game/engine.dart';
import '../lib/game/models.dart';
import 'balance.dart';
import 'trials.dart' show bossTrial, blade, trial;

void main(List<String> args) {
  final runs = args.isEmpty ? 8 : int.parse(args.first);
  braceSkill = args.firstWhere((a) => a.startsWith('brace='), orElse: () => 'brace=avg').substring(6);
  side = true;
  final at = List.generate(continents.length, (_) => <String>[]);
  for (var i = 0; i < runs; i++) {
    run('all', 5000 + i, Stats(), onChallenge: (e, c) => at[c].add(jsonEncode(e.state.toJson())));
  }
  print('land                    lvl  n   smart win  tries   blade win  tries   turns');
  for (var c = 0; c < continents.length; c++) {
    var ss = at[c];
    // Too few visits: the hero as they first faced the Ember King, sent there instead.
    if (ss.length < 6 && args.contains('late')) {
      ss = [
        for (final x in at[6])
          () {
            final m = GameState.fromJson(jsonDecode(x) as Map<String, dynamic>);
            m.continent = c;
            m.wins[c] = winsForBoss;
            return jsonEncode(m.toJson());
          }(),
      ];
    }
    if (ss.isEmpty) {
      print('${continents[c].name.padRight(22)}   -');
      continue;
    }
    final lvl = ss.map((x) => (jsonDecode(x) as Map<String, dynamic>)).map((m) => GameState.fromJson(m).knight.level).reduce((a, b) => a + b) / ss.length;
    if (args.contains('foes')) {
      final (t, lost, kos, n) = trial(ss, (_) {}, (e) => choose(e, 'all'), fights: 20);
      final (bt, blost, bkos, bn) = trial(ss, (_) {}, blade, fights: 20);
      print('${continents[c].name.padRight(22)} ${lvl.toStringAsFixed(0).padLeft(4)}  smart turns ${t.toStringAsFixed(1)} hp lost ${(lost * 100).round()}% ko ${(kos / n * 100).toStringAsFixed(1)}%   blade turns ${bt.toStringAsFixed(1)} hp lost ${(blost * 100).round()}% ko ${(bkos / bn * 100).toStringAsFixed(1)}%');
      continue;
    }
    final (sw, _, st) = bossTrial(ss, (_) {}, (e) => choose(e, 'all'));
    final (bw, _, _) = bossTrial(ss, (_) {}, blade);
    String t(double w) => w == 0 ? '  inf' : (1 / w).toStringAsFixed(2).padLeft(5);
    print('${continents[c].name.padRight(22)} ${lvl.toStringAsFixed(0).padLeft(4)} ${ss.length.toString().padLeft(2)}   ${(sw * 100).round().toString().padLeft(4)}%  ${t(sw)}   ${(bw * 100).round().toString().padLeft(4)}%  ${t(bw)}   ${st.toStringAsFixed(1)}');
  }
}
