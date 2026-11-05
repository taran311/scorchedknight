// How ordinary fights feel along the whole road: turns and HP lost per fight, by level band and
// kind of fight. Run: ... tool/fightfeel.dart [games] [player]
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';

import 'road_audit.dart' as ra;

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 6, player = args.length > 1 ? args[1] : 'road';
  if (args.length > 2) ra.policy = args[2];
  var kos = 0, won = 0, fights = 0;
  final t = <String, List<double>>{};
  ra.onFight = (e, f, turns, lost, ko) {
    final lv = e.state.knight.level, band = lv < 6 ? '01-05' : lv < 12 ? '06-11' : lv < 20 ? '12-19' : lv < 30 ? '20-29' : '30+';
    final kind = f.boss ? 'boss' : (f.rare ? 'rare' : (f.pack ? 'pack' : 'common'));
    final v = t['$band $kind'] ??= [0, 0, 0, 0, 0];
    v[0]++;
    v[1] += turns;
    v[2] += ko ? 1 : lost;
    if (ko) v[3]++;
    if (lost > .4 || ko) v[4]++;
  };
  for (var seed = 1; seed <= games; seed++) {
    final a = ra.play(seed, player);
    kos += a.knockouts;
    fights += a.fights;
    if (a.won) won++;
  }
  print('won $won/$games, ${(kos / games).toStringAsFixed(1)} KOs/game, ${(fights / games).round()} fights/game');
  final keys = t.keys.toList()..sort();
  print('band  kind     fights  turns  hp-lost  ko%   big-hit%');
  for (final k in keys) {
    final v = t[k]!;
    print('${k.padRight(15)} ${v[0].round().toString().padLeft(6)} ${(v[1] / v[0]).toStringAsFixed(1).padLeft(6)} ${(100 * v[2] / v[0]).round().toString().padLeft(6)}% ${(100 * v[3] / v[0]).toStringAsFixed(1).padLeft(5)} ${(100 * v[4] / v[0]).toStringAsFixed(1).padLeft(6)}');
  }
}
