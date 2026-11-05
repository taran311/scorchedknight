// Bosses for a hero dressed like the user's: Blood Knight rank 10, legendary Nightblood, Kingsfall,
// at the end of a road game levelled to [level]. Turns and win rate per boss.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';

import 'commons.dart' show endState, bloodKnight;
import 'road_audit.dart' as ra;

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 40, level = args.length > 1 ? int.parse(args[1]) : 44, bk = !args.contains('road');
  // One hero for every comparison (a game played again under new rules ends with other gear).
  final cache = File('/tmp/sk_endstate.json');
  if (!cache.existsSync()) cache.writeAsStringSync(jsonEncode(endState(1).toJson()));
  final s = GameState.fromJson((jsonDecode(cache.readAsStringSync()) as Map).cast<String, dynamic>());
  while (s.knight.level < level) {
    s.knight.level++;
  }
  if (bk) bloodKnight(s);
  if (args.contains('generals')) s.generalsDown.addAll(emberGenerals);
  print('generals down: ${s.generalsDown.where(emberGenerals.contains).length} of ${emberGenerals.length}');
  for (final g in s.knight.gear) {
    while (g.hone < 3) {
      g.hone++;
    }
  }
  print('L${s.knight.level} hp ${maxHp(s.knight)} crit ${(critChance(s.knight) * 100).round()}% swing ${fullSwing(s.knight)}');
  final json = jsonEncode(s.toJson());
  for (final pol in ['melee', 'smart']) {
    ra.policy = pol;
    print('[$pol]');
    for (var c = 0; c < continents.length; c++) {
      var won = 0, turns = 0, tries = 0, quick = 0;
      for (var i = 0; i < n; i++) {
        final st = GameState.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
        final t = GameEngine(st, random: Random(i * 13 + c), clock: () => DateTime(2026, 6, 1));
        st.knight.hp = maxHp(st.knight);
        st.knight.potions = 4;
        st.day = !continents[c].boss.night;
        if (t.whyNotTravel(c) != null) break;
        t.travel(c);
        st.wins[c] = winsForBoss;
        if (!t.challengeBoss()) break;
        tries++;
        var tu = 0, ko = false;
        while (st.inBattle && tu < 300) {
          if (t.takeTurn(ra.choose(t)).knockedOut) ko = true;
          tu++;
        }
        turns += tu;
        if (!ko) won++;
        if (!ko && tu <= 4) quick++;
      }
      if (tries == 0) continue;
      print('  ${continents[c].boss.name.padRight(34)} ${(100 * won / tries).round().toString().padLeft(3)}%  ${(turns / tries).toStringAsFixed(1)} turns  ${(100 * quick / tries).round()}% won in 4 or fewer');
    }
  }
}
