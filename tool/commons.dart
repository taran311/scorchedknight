// Ordinary fights late on: turns, share of HP lost, knockouts, with only the two attacks and with
// every tool. For the road hero at the end, and for a hero dressed like a Blood Knight at rank 10
// with Kingsfall.
import 'dart:convert';
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/knight_classes.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';

import 'road_audit.dart' as ra;

GameState endState(int seed) {
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
  return s;
}

void bloodKnight(GameState s) {
  final k = s.knight, loot = LootTable(Random(3));
  final l = k.loadout..armour = setArmourId('nightblood');
  for (final slot in setPieceSlots) {
    if (slot == GearSlot.armour) continue;
    final raw = loot.setPiece('nightblood', slot, HeroClass.knight, k.level);
    final g = asLegendSetPiece(raw) ?? raw;
    if (slot == GearSlot.ring) { k.ring = g; } else { l.put(g); }
  }
  l.weapon = loot.relicWeapon(0, k.level, HeroClass.knight);
  l.offhand = null;
  k.classWins['nightblood'] = 150;
}

void run(String label, GameState base, List<int> lands, int n) {
  final json = jsonEncode(base.toJson());
  for (final pol in ['melee', 'smart']) {
    ra.policy = pol;
    final out = <String>[];
    for (final c in lands) {
      var turns = 0, lost = 0.0, kos = 0, potions = 0;
      for (var i = 0; i < n; i++) {
        final st = GameState.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
        final t = GameEngine(st, random: Random(i * 31 + c), clock: () => DateTime(2026, 6, 1));
        final k = st.knight;
        k.hp = maxHp(k);
        k.potions = 4;
        t.travel(c);
        t.explore();
        if (!st.inBattle) continue;
        var tu = 0, ko = false;
        while (st.inBattle && tu < 300) {
          final m = ra.choose(t);
          if (m == BattleAction.potion) potions++;
          final r = t.takeTurn(m);
          if (r.knockedOut) ko = true;
          tu++;
        }
        turns += tu;
        if (ko) kos++; else lost += 1 - k.hp / maxHp(k);
        if (st.encounter != null) t.resolveEncounter(0);
      }
      out.add('${continents[c].name.split(' ').last.padRight(10)} ${(turns / n).toStringAsFixed(1)}t ${(100 * lost / n).round()}%hp ${(100 * kos / n).toStringAsFixed(1)}%ko ${(potions / n).toStringAsFixed(2)}pot');
    }
    print('$label [$pol]\n  ${out.join('\n  ')}');
  }
  ra.policy = 'full';
}

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 200;
  final s = endState(1);
  print('road hero L${s.knight.level} maxHp ${maxHp(s.knight)}');
  final lands = [for (var c = 0; c < mainLands; c++) c];
  run('road hero', s, lands, n);
  bloodKnight(s);
  print('blood knight maxHp ${maxHp(s.knight)} weapon ${s.knight.loadout.weapon?.name} suit ${suitWorn(s.knight)} rank ${classRank(s.knight, 'nightblood')}');
  run('blood knight', s, lands, n);
}
