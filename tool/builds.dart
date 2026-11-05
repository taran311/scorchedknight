// The one-affliction rule against the old (every kind at once), build by build: a late hero in each
// questline suit, holding a weapon whose wound-effects are plain, fire, venom, a bleed, or all three.
// For each: ordinary fights in the last two lands (turns, share of HP lost) and four late bosses
// (win rate, turns), the hero reading the foe's card (road_audit's 'smart').
// Run: dart --packages=.dart_tool/package_config.json run tool/builds.dart [commons] [bosses]
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/knight_classes.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';

import 'commons.dart' show endState;
import 'road_audit.dart' as ra;

GameState dressed(Map<String, dynamic> save, String? suit, Map<Stat, int> wound) {
  final s = GameState.fromJson(jsonDecode(jsonEncode(save)) as Map<String, dynamic>);
  final k = s.knight, loot = LootTable(Random(3));
  if (suit != null) {
    final l = k.loadout..armour = setArmourId(suit);
    for (final slot in setPieceSlots) {
      if (slot == GearSlot.armour) continue;
      final raw = loot.setPiece(suit, slot, HeroClass.knight, k.level);
      final g = asLegendSetPiece(raw) ?? raw;
      if (slot == GearSlot.ring) {
        k.ring = g;
      } else {
        l.put(g);
      }
    }
    k.classWins[suit] = 150;
  }
  final w = k.loadout.weapon!;
  for (final st in [Stat.burn, Stat.poison, Stat.bleed]) {
    w.stats.remove(st);
  }
  w.stats.addAll(wound);
  w.enchant = null;
  return s;
}

/// (turns, share of HP lost, KO share) over [n] ordinary fights in [lands]; (win share, turns) over
/// [n] tries at each boss.
(double, double, double) commons(GameState base, List<int> lands, int n) {
  final json = jsonEncode(base.toJson());
  var turns = 0, lost = 0.0, kos = 0, fights = 0;
  for (final c in lands) {
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
        if (t.takeTurn(ra.choose(t)).knockedOut) ko = true;
        tu++;
      }
      fights++;
      turns += tu;
      if (ko) {
        kos++;
      } else {
        lost += 1 - k.hp / maxHp(k);
      }
    }
  }
  return (turns / fights, lost / fights, kos / fights);
}

(double, double) bosses(GameState base, List<int> lands, int n) {
  final json = jsonEncode(base.toJson());
  var won = 0, turns = 0, tries = 0;
  for (final c in lands) {
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
      while (st.inBattle && tu < 400) {
        if (t.takeTurn(ra.choose(t)).knockedOut) ko = true;
        tu++;
      }
      turns += tu;
      if (!ko) won++;
    }
  }
  return (won / tries, turns / tries);
}

void main(List<String> args) {
  final nc = args.isNotEmpty ? int.parse(args[0]) : 120, nb = args.length > 1 ? int.parse(args[1]) : 40;
  ra.policy = 'smart';
  final cache = File('/tmp/sk_endstate.json');
  if (!cache.existsSync()) cache.writeAsStringSync(jsonEncode(endState(1).toJson()));
  final save = (jsonDecode(cache.readAsStringSync()) as Map).cast<String, dynamic>();
  final lv = (save['knight'] as Map)['level'];
  final v = 40;
  final wounds = <String, Map<Stat, int>>{
    'plain': {},
    'fire': {Stat.burn: v},
    'venom': {Stat.poison: v},
    'bleed': {Stat.bleed: v},
    'all3': {Stat.burn: v ~/ 2, Stat.poison: v ~/ 2, Stat.bleed: v ~/ 2},
  };
  final suits = args.contains("one") ? [null, "silverleaf"] : [null, "ashen", "nightblood", "moonfang", "sunscale", "drakesworn", "deepforge", "tidecaller", "silverleaf", "faceless", "changeling", "skyborn"];
  final late = [mainLands - 2, mainLands - 1];
  final bossLands = args.contains('all') ? [4, 5, 6, mainLands + 3] : [mainLands - 1];
  print('hero level $lv · commons in the last two lands ×$nc each · bosses ${bossLands.map((c) => continents[c].boss.name.split(',').first).join(', ')} ×$nb each');
  print('${'suit'.padRight(11)} ${'weapon'.padRight(6)} | common turns  HP lost      | boss win      boss turns');
  print('${''.padRight(18)} | old   new     old   new    | old   new     old   new');
  for (final suit in suits) {
    for (final e in wounds.entries.where((e) => args.contains('wounds') || e.key == 'plain' || e.key == 'all3')) {
      final r = <bool, ((double, double, double), (double, double))>{};
      for (final one in [false, true]) {
        oneAffliction = one;
        final s = dressed(save, suit, e.value);
        r[one] = (commons(s, late, nc), bosses(s, bossLands, nb));
      }
      oneAffliction = true;
      String f(double x) => x.toStringAsFixed(1).padLeft(4);
      String p(double x) => '${(100 * x).round()}%'.padLeft(4);
      final o = r[false]!, n = r[true]!;
      print('${(suit ?? '(own)').padRight(11)} ${e.key.padRight(6)} | ${f(o.$1.$1)}  ${f(n.$1.$1)}    ${p(o.$1.$2)}  ${p(n.$1.$2)}    | ${p(o.$2.$1)}  ${p(n.$2.$1)}    ${f(o.$2.$2)}  ${f(n.$2.$2)}');
    }
  }
}
