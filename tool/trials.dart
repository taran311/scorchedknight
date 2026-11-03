// Class, weapon and sustain trials from snapshots of the balance auto-player (tool/balance.dart).
// Run: dart run tool/trials.dart <land> [classes] [weapons] [sustain]
import 'dart:convert';
import 'dart:math';
import '../lib/game/arena.dart';
import '../lib/game/catalog.dart';
import '../lib/game/hall.dart';
import '../lib/game/engine.dart';
import '../lib/game/loot.dart';
import '../lib/game/models.dart';
import '../lib/game/rules.dart';
import '../lib/game/classes.dart';
import '../lib/game/crafting.dart';
import 'balance.dart';

/// Snapshots taken right after the boss of [land] falls.
List<String> snaps(int land, int n) {
  final out = <String>[];
  for (var i = 0; i < n; i++) {
    run('all', 3000 + i, Stats(), onBoss: (e, c) {
      if (c == land && out.length <= i) out.add(jsonEncode(e.state.toJson()));
    });
  }
  return out;
}

(double, double, int, int) trial(List<String> ss, void Function(GameEngine e) setup, BattleAction Function(GameEngine e) pick, {int fights = 60}) {
  var turns = 0, lost = 0.0, n = 0, kos = 0;
  for (final (i, snap) in ss.indexed) {
    final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(900 + i), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    setup(e);
    for (var f = 0; f < fights; f++) {
      k.hp = maxHp(k);
      k.potions = 0;
      for (var j = 0; j < 30 && !s.inBattle; j++) {
        e.explore();
      }
      if (s.encounter != null) e.resolveEncounter(0);
      if (!s.inBattle) continue;
      var t = 0;
      while (s.inBattle && t < 200) {
        brace(e);
        final r = e.takeTurn(pick(e));
        if (r.knockedOut) kos++;
        t++;
      }
      turns += t;
      lost += (maxHp(k) - k.hp) / maxHp(k);
      n++;
      s.pendingLoot.clear();
    }
  }
  return (turns / n, lost / n, kos, n);
}

/// Fights in a row with no rest and no potions, from full health, until knocked out (capped at
/// 30): kill speed and sustain in one number.
double gauntlet(List<String> ss, void Function(GameEngine e) setup, BattleAction Function(GameEngine e) pick) {
  var total = 0;
  for (var rep = 0; rep < 3; rep++) {
    for (final (i, snap) in ss.indexed) {
      final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(700 + i + 50 * rep), clock: () => DateTime(2026, 6, 1));
      final s = e.state, k = s.knight;
      setup(e);
      k.hp = maxHp(k);
      k.potions = 0;
      var won = 0;
      while (won < 30) {
        for (var j = 0; j < 30 && !s.inBattle; j++) {
          e.explore();
        }
        if (s.encounter != null) e.resolveEncounter(0);
        if (!s.inBattle) continue;
        var ko = false, t = 0;
        while (s.inBattle && t < 200) {
          brace(e);
          if (e.takeTurn(pick(e)).knockedOut) ko = true;
          t++;
        }
        s.pendingLoot.clear();
        if (ko) break;
        won++;
      }
      total += won;
    }
  }
  return total / (3 * ss.length);
}

/// The land's boss again, from full health with three potions (drunk under 40%): wins, and potions
/// used.
(double, double, double) bossTrial(List<String> ss, void Function(GameEngine e) setup, BattleAction Function(GameEngine e) pick) {
  var wins = 0, n = 0, pots = 0, turns = 0;
  for (final (i, snap) in ss.indexed) {
    for (var rep = 0; rep < 12; rep++) {
      final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(300 + i * 31 + rep), clock: () => DateTime(2026, 6, 1));
      final s = e.state, k = s.knight;
      setup(e);
      k.hp = maxHp(k);
      k.potions = 3;
      s.day = !continents[s.continent].boss.night;
      if (!e.challengeBoss()) continue;
      var ko = false, t = 0;
      while (s.inBattle && t < 200) {
        final a = k.hp < maxHp(k) * .4 && e.whyNot(BattleAction.potion) == null ? BattleAction.potion : pick(e);
        brace(e);
        if (e.takeTurn(a).knockedOut) ko = true;
        t++;
      }
      n++;
      turns += t;
      pots += 3 - k.potions;
      if (!ko) wins++;
    }
  }
  return (wins / n, pots / n, turns / n);
}

BattleAction blade(GameEngine e) => e.whyNot(BattleAction.skill) == null ? BattleAction.skill : BattleAction.attack;
BattleAction withRites(GameEngine e) {
  final k = e.state.knight;
  for (final id in k.rites) {
    if (e.whyNotRite(id) == null) {
      k.preparedSpell = id;
      return BattleAction.cast;
    }
  }
  return blade(e);
}

void main(List<String> args) {
  final land = int.parse(args.first);
  final ss = snaps(land, 6);
  final k0 = GameState.fromJson(jsonDecode(ss.first) as Map<String, dynamic>).knight;
  print('== snapshots after land $land boss, level ~${k0.level}');
  if (args.contains('arena')) {
    // Through the Colosseum from the snapshot: each bout from full health with three potions
    // (drunk under 40%), retried until won. Tries per bout, and potions used.
    final tries = List.filled(arenaBouts.length, 0), pots = List.filled(arenaBouts.length, 0), turns = List.filled(arenaBouts.length, 0);
    for (final (i, snap) in ss.indexed) {
      for (var rep = 0; rep < 4; rep++) {
        final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(4000 + i * 13 + rep), clock: () => DateTime(2026, 6, 1));
        final s = e.state, k = s.knight;
        s.unlocked = s.unlocked < arenaLand ? arenaLand : s.unlocked;
        for (var b = 0; b < arenaBouts.length; b++) {
          var t = 0;
          while (s.arenaWins == b && t < 20) {
            t++;
            k.hp = maxHp(k);
            k.potions = 3;
            e.startArenaBout();
            var n = 0;
            while (s.inBattle && n < 200) {
              final a = k.hp < maxHp(k) * .4 && e.whyNot(BattleAction.potion) == null ? BattleAction.potion : withRites(e);
              brace(e);
              e.takeTurn(a);
              n++;
            }
            pots[b] += 3 - k.potions;
            turns[b] += n;
            s.pendingLoot.clear();
          }
          tries[b] += t;
        }
      }
    }
    final runs = ss.length * 4;
    for (var b = 0; b < arenaBouts.length; b++) {
      print('  ${arenaBouts[b].name.padRight(28)} tries ${(tries[b] / runs).toStringAsFixed(2)}  potions/try ${(pots[b] / tries[b]).toStringAsFixed(1)}  turns/try ${(turns[b] / tries[b]).toStringAsFixed(1)}');
    }
  }
  if (args.contains('hall')) {
    // Through the Hall of the Slain: each wave from full health with four potions (drunk under
    // 40%), its warriors back to back, retried from the start of the wave until won; the War Cry
    // goes on the hotbar once it's won.
    final tries = List.filled(hallWaves.length, 0), pots = List.filled(hallWaves.length, 0);
    var skipped = 0;
    for (final (i, snap) in ss.indexed) {
      for (var rep = 0; rep < 4; rep++) {
        final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(6000 + i * 13 + rep), clock: () => DateTime(2026, 6, 1));
        final s = e.state, k = s.knight;
        // (A run that went round the Frostmarch can't reach the hall: not counted.)
        if (e.whyNotHall() != null) {
          skipped++;
          continue;
        }
        for (var w = 0; w < hallWaves.length; w++) {
          var t = 0;
          while (s.hallWaves == w && t < 20) {
            t++;
            k.hp = maxHp(k);
            k.potions = 4;
            if (k.earnedRites.contains('warcry') && !k.rites.contains('warcry')) k.rites = ['warcry', ...k.rites.take(2)];
            while (s.hallWaves == w) {
              if (e.startHallFight() == null) break;
              var n = 0;
              while (s.inBattle && n < 200) {
                final a = k.hp < maxHp(k) * .4 && e.whyNot(BattleAction.potion) == null ? BattleAction.potion : withRites(e);
                brace(e);
                e.takeTurn(a);
                n++;
              }
              s.pendingLoot.clear();
              if (s.hallStep == 0 && s.hallWaves == w) break; // knocked out: the wave starts over
            }
            pots[w] += 4 - k.potions;
          }
          tries[w] += t;
        }
      }
    }
    final runs = ss.length * 4 - skipped;
    for (var w = 0; w < hallWaves.length; w++) {
      print('  ${hallWaves[w].name.padRight(24)} tries ${(tries[w] / runs).toStringAsFixed(2)}  potions/try ${(pots[w] / tries[w]).toStringAsFixed(1)}');
    }
  }
  if (args.contains('sustain')) {
    for (final (label, setup) in <(String, void Function(GameEngine))>[('plain', (e) {}), ('nightblood suit', (e) {
      final k = e.state.knight;
      for (final slot in setPieceSlots) {
        final g = e.loot.setPiece('nightblood', slot, k.heroClass, k.level);
        if (slot == GearSlot.armour) {
          k.loadout.armour = g.art;
        } else if (slot == GearSlot.ring) {
          k.ring = g;
        } else {
          k.loadout.put(g);
        }
      }
    })]) {
      var gross = 0.0, net = 0.0, n = 0;
      final src = <String, double>{};
      final h = <String, double>{};
      for (final (i, snap) in ss.indexed) {
        final e = GameEngine(GameState.fromJson(jsonDecode(snap) as Map<String, dynamic>), random: Random(900 + i), clock: () => DateTime(2026, 6, 1));
        final s = e.state, k = s.knight;
        setup(e);
        final hs = heroStats(k);
        h['regen'] = (h['regen'] ?? 0) + hs.regen / maxHp(k);
        h['leech%'] = (h['leech%'] ?? 0) + hs.leech.toDouble();
        h['lifesteal'] = (h['lifesteal'] ?? 0) + hs.lifesteal.toDouble();
        for (var f = 0; f < 60; f++) {
          k.hp = (maxHp(k) * .6).round();
          for (var j = 0; j < 30 && !s.inBattle; j++) {
            e.explore();
          }
          if (s.encounter != null) e.resolveEncounter(0);
          if (!s.inBattle) continue;
          final hp0 = k.hp;
          var g = 0;
          while (s.inBattle) {
            brace(e);
            final r = e.takeTurn(withRites(e));
            g += r.counter ?? 0;
            src['blows (lifesteal+leech)'] = (src['blows (lifesteal+leech)'] ?? 0) + r.damage.heal / maxHp(k);
            src['healed (after bloodthirst)'] = (src['healed (after bloodthirst)'] ?? 0) + r.healed / maxHp(k);
            if (r.kill != null) {
              src['breath'] = (src['breath'] ?? 0) + r.kill!.breathed / maxHp(k);
              src['levelups'] = (src['levelups'] ?? 0) + r.kill!.levelUps;
            }
            src['rite drain'] = (src['rite drain'] ?? 0) + r.drained / maxHp(k);
            src['mend:${r.mendedFrom}'] = (src['mend:${r.mendedFrom}'] ?? 0) + r.mended / maxHp(k);
          }
          src['level-ups'] = (src['level-ups'] ?? 0) + 0;
          gross += g / maxHp(k);
          net += (hp0 - k.hp) / maxHp(k);
          n++;
          s.pendingLoot.clear();
        }
      }
      print('  $label: gross taken ${(gross / n * 100).round()}% of max HP a fight, healed back ${((gross - net) / n * 100).round()}%  · regen ${(h['regen']! / ss.length * 100).round()}% of HP, leech ${(h['leech%']! / ss.length).round()}%, lifesteal ${(h['lifesteal']! / ss.length).round()}/swing');
      print('     raw heals a fight: ${src.entries.where((e) => e.value > 0).map((e) => '${e.key} ${(e.value / n * 100).round()}%').join(', ')}');
    }
  }
  if (args.contains('weapons')) {
    const arts = ['dagger', 'shortsword', 'longsword', 'scimitar', 'falchion', 'rapier', 'axe', 'mace', 'flail', 'morningstar', 'halberd', 'glaive', 'spear', 'greataxe', 'greatsword', 'cleaver', 'hammer'];
    final rows = <String, (double, double, int, int)>{};
    final gaunt = <String, double>{};
    for (final art in arts) {
      void setup(GameEngine e) {
        final k = e.state.knight;
        k.rites = [];
        GearItem? w;
        for (var t = 0; t < 20000 && w == null; t++) {
          final g = e.loot.roll(k.heroClass, k.level, odds: const [0, 0, 0, 1, 0], only: GearSlot.weapon);
          if (g.art == art && g.rarity == Rarity.epic && g.enchant == null && (g.stats[Stat.leech] ?? 0) == 0) w = g;
        }
        k.loadout.weapon = w;
      }
      rows[art] = trial(ss, setup, blade);
      gaunt[art] = gauntlet(ss, setup, blade);
    }
    final bt = rows.values.map((r) => r.$1).reduce((a, b) => a + b) / rows.length, bl = rows.values.map((r) => r.$2).reduce((a, b) => a + b) / rows.length;
    for (final e in rows.entries) {
      print('  ${e.key.padRight(12)} turns ${(e.value.$1 / bt * 100).round().toString().padLeft(4)}%  hp lost ${(e.value.$2 / bl * 100).round().toString().padLeft(4)}%  both ${(e.value.$1 / bt * e.value.$2 / bl * 100).round().toString().padLeft(4)}  KO ${e.value.$3}/${e.value.$4}  gauntlet ${gaunt[e.key]!.toStringAsFixed(1)}');
    }
  }
  if (args.contains('classes')) {
    const classRites = {'drakesworn': ['wyrmflame', 'scaleward', 'dragonroar'], 'nightblood': ['crimsonthirst', 'bloodpact', 'nightveil'], 'deepforge': ['anvilward', 'moltenhammer', 'earthshaker']};
    print('  plain knight blade only: gauntlet ${gauntlet(ss, (e) => e.state.knight.rites = [], blade).toStringAsFixed(1)}; no pet: ${gauntlet(ss, (e) { e.state.knight.rites = []; e.state.knight.activePet = null; }, blade).toStringAsFixed(1)}');
    print('  rites: ${GameState.fromJson(jsonDecode(ss.first) as Map<String, dynamic>).knight.rites}');
    final plain = trial(ss, (e) {}, withRites);
    final pb = bossTrial(ss, (e) {}, withRites);
    print('     plain boss: won ${(pb.$1 * 100).round()}%, potions ${pb.$2.toStringAsFixed(1)}, turns ${pb.$3.toStringAsFixed(1)}');
    print('  plain knight (own kit, own rites): turns ${plain.$1.toStringAsFixed(2)} hp lost ${(plain.$2 * 100).round()}% KO ${plain.$3}/${plain.$4} gauntlet ${gauntlet(ss, (e) {}, withRites).toStringAsFixed(1)}');
    for (final set in classRites.keys) {
      for (final asClass in [false, true]) {
        void setup(GameEngine e) {
          final k = e.state.knight;
          for (final slot in setPieceSlots) {
            final g = e.loot.setPiece(set, slot, k.heroClass, k.level);
            switch (slot) {
              case GearSlot.armour:
                k.loadout.armour = g.art;
              case GearSlot.ring:
                k.ring = g;
              default:
                k.loadout.put(g);
            }
          }
          k.classWins[set] = asClass ? 150 : 0;
          if (asClass) k.rites = [...classRites[set]!];
        }
        {
          final e = GameEngine(GameState.fromJson(jsonDecode(ss.first) as Map<String, dynamic>), random: Random(1), clock: () => DateTime(2026, 6, 1));
          setup(e);
          final k = e.state.knight, h = heroStats(k);
          print('     stats: hp ${maxHp(k)} swing ${fullSwing(k)} DR ${(damageReduction(k) * 100).round()} dodge ${(dodgeChance(k) * 100).round()} parry ${(parryChance(k) * 100).round()} block ${(blockChance(k) * 100).round()} crit ${(critChance(k) * 100).round()} leech ${h.leech} lifesteal ${h.lifesteal} regen ${h.regen} thorns ${h.thorns} burn ${h.burn}');
        }
        final r = trial(ss, setup, withRites);
        final b = bossTrial(ss, setup, withRites);
        print('     boss: won ${(b.$1 * 100).round()}%, potions ${b.$2.toStringAsFixed(1)}, turns ${b.$3.toStringAsFixed(1)}');
        print('  $set ${asClass ? 'class r10  ' : 'suit, rank0'}: turns ${r.$1.toStringAsFixed(2)} hp lost ${(r.$2 * 100).round()}% KO ${r.$3}/${r.$4} gauntlet ${gauntlet(ss, setup, withRites).toStringAsFixed(1)}');
      }
    }
  }
}
