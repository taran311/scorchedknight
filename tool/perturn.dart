// Damage per action at the end of a road game, against each main boss: attack, bash, each rite,
// a bolt. One action from a fresh fight, many times over.
import 'dart:convert';
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';

import 'road_audit.dart' as ra;

void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 1;
  final a = ra.Audit('road', seed);
  final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed), clock: () => DateTime(2026, 6, 1));
  final rng = Random(seed * 7 + 1), s = e.state;
  e.takeHobsJob();
  var loops = 0;
  while (!s.won && loops++ < 8000) {
    ra.inTown(e, careless: false);
    if (s.inBattle) { ra.fight(e, rng, a); continue; }
    if (!s.innRepaired) { e.travel(0); e.explore(); ra.fight(e, rng, a); continue; }
    final road = e.roadStep();
    if (road == null) break;
    ra.take(e, road, rng, a);
    if (!s.day && !(e.whyNotTravel(road.land) == null && continents[road.land].boss.night)) e.rest();
  }
  final k = s.knight;
  print('L${k.level} weapon ${k.loadout.weapon?.name} rites ${k.rites} crossbow ${k.crossbow} mana? suit ${suitWorn(k)}');
  final json = jsonEncode(s.toJson());
  for (final c in [0, 3, 5, 6, 7, 13]) {
    final row = <String, double>{};
    final acts = <String>['attack', 'skill', 'shoot', ...k.rites];
    for (final act in acts) {
      var sum = 0, hurt = 0;
      for (var i = 0; i < 200; i++) {
        final st = GameState.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
        final t = GameEngine(st, random: Random(i), clock: () => DateTime(2026, 6, 1));
        st.knight.hp = maxHp(st.knight);
        st.day = !continents[c].boss.night;
        t.travel(c);
        st.wins[c] = winsForBoss;
        if (!t.challengeBoss()) break;
        st.mana = 99;
        final before = st.foeHp, hp0 = st.knight.hp;
        BattleAction m;
        if (act == 'attack') m = BattleAction.attack;
        else if (act == 'skill') m = BattleAction.skill;
        else if (act == 'shoot') m = BattleAction.shoot;
        else { st.knight.preparedSpell = act; m = BattleAction.cast; }
        t.takeTurn(m);
        sum += before - st.foeHp;
        hurt += hp0 - st.knight.hp;
      }
      row[act] = sum / 200;
    }
    final f = continents[c].boss;
    print('${f.name.padRight(32)} kind ${f.kind.name.padRight(8)} aloft ${f.aloft} | ${row.entries.map((x) => '${x.key} ${x.value.round()}').join('  ')}');
  }
}
