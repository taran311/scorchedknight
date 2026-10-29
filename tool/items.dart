// Item balance at a glance: what each gear set's bonuses are worth, how strong each forged set's
// pieces come out against a random epic piece of the same slot, and every boss's trinket against a
// random legendary one. Scores use GearItem.score. Run: dart run tool/items.dart

import 'dart:math';
import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/loot.dart';

int score(Map<Stat, int> st) => GearItem(id: 'x', name: 'x', slot: GearSlot.ring, art: 'ring', rarity: Rarity.epic, level: 1, stats: st, value: 0).score;

void main() {
  const level = 30;
  final loot = LootTable(Random(1));
  print('== Gear sets (bonus score: two / three-extra) ==');
  for (final g in gearSets) {
    print('${g.id.padRight(12)} two ${score(g.two).toString().padLeft(3)}  three+ ${score(g.three).toString().padLeft(3)}  ${g.forged ? "forged" : "random"}  ${[if (g.cheaperSpells) 'cheaper spells', if (g.bloodthirst) 'bloodthirst', if (g.longWolf) 'longWolf', if (g.firstMiss) 'firstMiss', if (g.forgeheart) 'forgeheart', if (g.firstCrit) 'firstCrit', if (g.regrowth) 'regrowth', if (g.undertow) 'undertow', if (g.adapt) 'adapt', if (g.updraft) 'updraft', if (g.bushido) 'bushido'].join(',')}');
  }
  print('\n== Set pieces at level $level (avg score of 200 rolls, all three slots) vs random epic accessory ==');
  for (final f in forgedSets) {
    var t = 0;
    for (var i = 0; i < 200; i++) {
      for (final s in setPieceSlots) {
        t += loot.setPiece(f.id, s, HeroClass.knight, level).score;
      }
    }
    print('${f.id.padRight(12)} ${(t / 600).toStringAsFixed(1)}');
  }
  for (final slot in setPieceSlots) {
    var t = 0, n = 0;
    for (var i = 0; i < 3000; i++) {
      final g = loot.roll(HeroClass.knight, level, odds: const [0, 0, 0, 1, 0], only: slot);
      if (g.rarity == Rarity.epic) {
        t += g.score;
        n++;
      }
    }
    print('random epic ${slot.name.padRight(7)} ${(t / n).toStringAsFixed(1)}');
  }
  print('\n== Boss trinkets at level $level (avg score) ==');
  final arts = [for (final c in continents) c.prize, 'ashenseal', 'hiddenmask', 'cinderjack'];
  for (final a in arts) {
    var t = 0;
    String name = a;
    for (var i = 0; i < 200; i++) {
      final g = a == 'hiddenmask' ? loot.hiddenMask(level) : (a == 'cinderjack' ? loot.cinderJack(level) : loot.bossTrinket(a, level));
      t += g.score;
      name = g.name;
    }
    print('${name.padRight(28)} ${(t / 200).toStringAsFixed(1)}');
  }
  var t = 0, n = 0;
  for (var i = 0; i < 3000; i++) {
    final g = loot.roll(HeroClass.knight, level, odds: const [0, 0, 0, 0, 1], only: GearSlot.trinket);
    t += g.score;
    n++;
  }
  print('random legendary trinket       ${(t / n).toStringAsFixed(1)}');

  weaponRange(loot, level);
}

/// The weapon range: for each class, how many bases each weapon kind has and its average epic
/// score (anything far off the class average, or a kind with too many bases, stands out), then
/// every farmed signature weapon against the class's random epic and legendary weapons.
void weaponRange(LootTable loot, int level) {
  print('\n== Weapon range at level $level: random epic weapons by kind (bases, avg score) ==');
  for (final c in HeroClass.values) {
    for (final east in [false, true]) {
      final by = <String, List<int>>{}, names = <String, Set<String>>{};
      for (var i = 0; i < 6000; i++) {
        final g = loot.roll(c, level, odds: const [0, 0, 0, 1, 0], only: GearSlot.weapon, east: east);
        if (g.rarity != Rarity.epic || g.special != null) continue;
        (by[g.art] ??= []).add(g.score);
        (names[g.art] ??= {}).add(g.name.split(' ').where((w) => w[0] == w[0].toUpperCase()).last);
      }
      final all = [for (final l in by.values) ...l];
      final avg = all.reduce((a, b) => a + b) / all.length;
      print('${c.name}${east ? ' (Blossom Isles)' : ''}: ${by.length} kinds, average ${avg.toStringAsFixed(0)}');
      for (final e in (by.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
        final a = e.value.reduce((x, y) => x + y) / e.value.length;
        final flag = (a - avg).abs() / avg > .2 ? '  <-- ${(100 * (a - avg) / avg).round()}%' : '';
        print('   ${e.key.padRight(15)} ${(a).toStringAsFixed(0).padLeft(4)}$flag');
      }
    }
  }
  print('\n== Farmed weapons vs random (avg of 200) ==');
  for (final c in HeroClass.values) {
    double avg(GearItem Function() make) {
      var t = 0;
      for (var i = 0; i < 200; i++) {
        t += make().score;
      }
      return t / 200;
    }

    double rand(int r) {
      var t = 0, n = 0;
      for (var i = 0; i < 4000; i++) {
        final g = loot.roll(c, level, odds: [for (var k = 0; k < 5; k++) k == r ? 1 : 0], only: GearSlot.weapon);
        if (g.rarity.index == r) {
          t += g.score;
          n++;
        }
      }
      return t / n;
    }

    final rows = <(String, double)>[
      ('random epic', rand(3)),
      ('random legendary', rand(4)),
      ('ork', avg(() => loot.orkDrop(c, level))),
      ('ent', avg(() => loot.entDrop(c, level))),
      ('bone', avg(() => loot.boneDrop(c, level, armour: false))),
      ('elf (Thornbloom)', avg(() => loot.elfDrop(c, level))),
      for (final k in ['flame', 'frost', 'dawn', 'shadow']) ('arms: $k', avg(() => loot.elementArms(k, c, level))),
      ('rune', avg(() => loot.runeWeapon(c, level))),
      ('relic: Thornwild', avg(() => loot.relicWeapon(2, level, c))),
      if (c == HeroClass.knight) ('relic: Kingsfall', avg(() => loot.relicWeapon(0, level, c))),
    ];
    print(c.name);
    for (final (n, v) in rows) {
      print('   ${n.padRight(18)} ${v.toStringAsFixed(0).padLeft(4)}');
    }
  }
}
