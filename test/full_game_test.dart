// Plays the whole game, start to finish, through the engine: a sensible auto-player takes Hob's
// job, fights its way across every land, beats every boss and finally Vharrax, using everything
// the town offers along the way (Mags' potions and brews, Dunstan's forge, Old Wick's runes, bolts
// and wards). Every few fights the save goes through JSON and play carries on from the copy, so a
// field that doesn't survive saving shows up here. After every turn the hero's numbers are checked
// for anything impossible (negative gold, HP above the maximum, stock below zero).
//
// Run: flutter test test/full_game_test.dart

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scorchedknight/game/brews.dart';
import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';
import 'package:scorchedknight/game/spells.dart';

/// What one playthrough saw and did.
class Run {
  final seen = <String>{};
  int fights = 0, knockouts = 0, saves = 0;
  bool won = false;
  final bossLevels = <int, int>{};
}

/// Fails with a clear message if anything about the hero or the town is impossible.
void checkSane(GameEngine e, String when) {
  final s = e.state, k = s.knight;
  expect(k.hp, inInclusiveRange(0, maxHp(k)), reason: 'HP out of range $when');
  expect(k.coins, greaterThanOrEqualTo(0), reason: 'negative gold $when');
  expect(k.potions, greaterThanOrEqualTo(0), reason: 'negative potions $when');
  expect(s.mats.values.every((n) => n > 0), isTrue, reason: 'empty or negative crafting stock $when: ${s.mats}');
  expect(s.reagents.every((n) => n >= 0), isTrue, reason: 'negative reagents $when');
  expect(k.ammo.values.every((n) => n > 0), isTrue, reason: 'empty or negative bolts $when: ${k.ammo}');
  expect(k.brews.values.every((n) => n > 0), isTrue, reason: 'spent brew still listed $when: ${k.brews}');
  if (s.inBattle) {
    expect(s.foeHp, lessThanOrEqualTo(s.foeMax), reason: 'foe HP above its maximum $when');
    expect(s.mana, greaterThanOrEqualTo(0), reason: 'negative mana $when');
  }
}

/// The turn's move: drink at a third of HP, lean into the foe's weakness, use rites, the
/// companion and the class skill when they're ready, and the crossbow on foes aloft.
BattleAction choose(GameEngine e) {
  final k = e.state.knight, f = encounterType(e.state.foe, e.state.rare);
  if (k.hp < maxHp(k) * .35 && e.whyNot(BattleAction.potion) == null) return BattleAction.potion;
  bool rite() {
    for (final id in k.rites) {
      if (e.whyNotRite(id) == null) {
        k.preparedSpell = id;
        return true;
      }
    }
    return false;
  }

  if (f.kind.weakTo == AttackStyle.rite && rite()) return BattleAction.cast;
  if (!f.aloft && f.kind.resists != AttackStyle.blade && e.whyNot(BattleAction.skill) == null) return BattleAction.skill;
  if (f.kind.resists != AttackStyle.rite && rite()) return BattleAction.cast;
  if (e.whyNot(BattleAction.pet) == null) return BattleAction.pet;
  final blade = (f.aloft ? aloftMelee : 1) * triangle(f.kind, AttackStyle.blade);
  final bolt = crossbowShare(k) * (f.aloft ? aloftShot : 1) * triangle(f.kind, AttackStyle.bolt);
  return bolt > blade && e.whyNot(BattleAction.shoot) == null ? BattleAction.shoot : BattleAction.attack;
}

/// A side land worth a visit: open, its boss still up, and you're its level.
int? sideToDo(GameEngine e) {
  final s = e.state, k = s.knight;
  for (var i = mainLands; i < continents.length; i++) {
    if (e.whyNotTravel(i) == null && !s.bossesDown.contains(i) && k.level >= continents[i].minLevel + 2) return i;
  }
  return null;
}

/// Between fights, in town: everything a careful player would do.
void inTown(GameEngine e, Run run) {
  final s = e.state, k = s.knight;
  // Spells on the hotbar, hardest-hitting first; training points into might, arcana, aim, vigour.
  final known = spellsKnown(k.level).map((x) => x.id).toSet();
  const pref = ['chainlightning', 'dragonfire', 'lifedrain', 'frostnova', 'spectralcharge', 'bloodbolt', 'arcanebolt'];
  k.rites = [for (final id in pref) if (known.contains(id)) id].take(riteSlots).toList();
  const plan = [Trait.might, Trait.arcana, Trait.aim, Trait.vigour];
  var i = 0;
  while (unspentPoints(k) > 0) {
    e.train(plan[i++ % plan.length]);
  }
  if (e.repairInn()) run.seen.add('inn repaired');
  // Sleep when hurt; otherwise, with a side land's night still to fight in, let the dark come.
  if (k.hp < maxHp(k) * .7 || sideToDo(e) == null) e.rest();
  if (e.buildHome()) run.seen.add('home built');
  // Mags: the first armour upgrade, potions, the crossbow, brews.
  for (final t in tiersFor(k.heroClass).skip(1).where((t) => !t.dropOnly && !isCrafted(t.id))) {
    if (!e.owns(t.id) && k.coins >= e.priceOf(t.id) * 1.2) e.purchase(t.id);
  }
  while (k.potions < 4 && k.coins > e.priceOf('potion') * 3) {
    e.purchase('potion');
  }
  if (k.coins > e.priceOf('crossbow') * 1.5) e.purchase('crossbow');
  // Old Wick: wards first (reagents are needed for them), then gems into bolts, then a rune.
  for (var w = 1; w < continents.length; w++) {
    if (e.craftWard(w)) run.seen.add('ward');
  }
  for (final g in Gem.values) {
    while (e.fletch(g)) {
      run.seen.add('fletched');
    }
  }
  if (k.coins > 1500) {
    final r = e.enchantOffer(EnchantSlot.weapon);
    if (r != null) {
      run.seen.add('enchanted');
      final cur = k.loadout.weapon?.enchant;
      if (cur == null || r.tier >= cur.tier) e.applyEnchant(EnchantSlot.weapon, r);
    }
  }
  // Mags' brews from what's left.
  for (final b in Brew.values) {
    if (b == Brew.healing && k.potions >= 4) continue;
    if (b != Brew.healing && brewOn(k, b)) continue;
    if (e.brew(b)) run.seen.add('brew:${b.name}');
  }
  // Dunstan: smelt everything, forge the best armour the bars allow.
  for (final m in Metal.values) {
    if (e.smelt(m) > 0) run.seen.add('smelted ${m.name}');
  }
  for (final t in tiersFor(k.heroClass).reversed) {
    if (isCrafted(t.id) && e.craftArmour(t.id)) {
      run.seen.add('forged ${t.id}');
      break;
    }
  }
  // Set pieces, from the blueprints the Ashen Order, the vampires and the werewolves left.
  for (final f in forgedSets) {
    for (final slot in setPieceSlots) {
      if (!k.gear.any((g) => g.gearSet == f.id && g.slot == slot) && e.forgePiece(f.id, slot) != null) run.seen.add('forged ${f.id} piece');
    }
  }
  // Caches and shrines on the map, as soon as they're reachable.
  for (final p in places) {
    if (p.kind != PlaceKind.guarded && e.whyNotExplore(p.id) == null && e.explorePlace(p.id) != null) run.seen.add('explored ${p.id}');
  }
  // Elemental cores into runes, if the rune beats what's on the weapon.
  for (final el in Elemental.values) {
    if (e.whyNotBind(el) == null && k.coins > 1000) {
      final r = e.bindCores(el)!;
      final cur = k.loadout.weapon?.enchant;
      if (cur == null || r.tier >= cur.tier) e.applyEnchant(EnchantSlot.weapon, r);
      run.seen.add('bound ${el.name}');
    }
  }
  // Relics, once all their parts are in.
  for (final c in relics.keys) {
    if (e.whyNotForge(c) == null && e.forgeRelic(c) != null) run.seen.add('relic forged');
  }
}

/// The spoils: wear what's better, sell the rest.
void takeLoot(GameEngine e) {
  final s = e.state, k = s.knight;
  for (final g in List.of(s.pendingLoot)) {
    final old = e.equippedFor(g);
    final usable = (g.heroClass == null || g.heroClass == k.heroClass) && e.whyNotWear(g) == null;
    final better = g.slot == GearSlot.armour ? armourTierById(g.art).reduction > armourTierById(k.loadout.armour).reduction : old == null || g.score > old.score;
    if (usable && better) {
      e.equipLoot(g.id);
    } else {
      e.sellLoot(g.id);
    }
  }
  for (final g in List.of(k.stash)) {
    e.sellFromStash(g.id);
  }
}

/// One whole game, from a fresh hero to Vharrax's fall.
Run playThrough(int seed, {int maxFights = 4000}) {
  final run = Run();
  var e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed), clock: () => DateTime(2026, 6, 1));
  final rng = Random(seed + 1);
  e.takeHobsJob();
  var extra = 0;
  while (!e.state.won && run.fights < maxFights) {
    inTown(e, run);
    final s = e.state, k = s.knight;
    // The furthest land you're allowed into.
    var c = s.unlocked;
    while (c > 0 && e.whyNotTravel(c) != null) {
      c--;
    }
    // Now and then, off the road (once it's dark there).
    final side = sideToDo(e);
    if (side != null && run.fights % 2 == 0) c = side;
    e.travel(c);
    final raid = s.raid != null;
    final boss = !raid && e.bossReady && !s.bossesDown.contains(c) && k.level >= bossLevel(c) - 1 + extra;
    if (raid) {
      e.startRaid();
      run.seen.add('raid');
    } else if (boss) {
      e.challengeBoss();
    } else if (places.where((p) => p.kind == PlaceKind.guarded && e.whyNotExplore(p.id) == null && k.level >= continents[p.land].minLevel + 3).firstOrNull case final p?) {
      e.explorePlace(p.id);
      run.seen.add('guard ${p.id}');
    } else {
      e.explore();
    }
    run.fights++;
    final foe = encounterType(s.foe, s.rare);
    if (golemMetal(s.rare?.look) != null) run.seen.add('golem ${golemMetal(s.rare?.look)!.name}');
    if (hiddenRanks.containsKey(s.rare?.look)) run.seen.add(s.rare?.look == hiddenPrior ? 'the Veiled Prior' : 'the Hidden Ones');
    if (s.rare?.pack == true) run.seen.add('pack');
    if (s.rare?.look == malricLook) run.seen.add('Sir Malric');
    if (elementalOf(s.rare?.look) case final el?) run.seen.add('elemental ${el.name}');
    if (foe.night) run.seen.add('night foe');
    var turns = 0;
    while (s.inBattle) {
      final a = choose(e);
      final r = e.takeTurn(a, aim: a == BattleAction.shoot ? [bullseye, 1.0, graze][rng.nextInt(3)] : 1);
      turns++;
      checkSane(e, 'after turn $turns of fight ${run.fights} (${foe.name}, ${a.name})');
      if (r.knockedOut) {
        run.knockouts++;
        if (boss) extra++;
      }
      if (r.cheatedDeath) run.seen.add('cheated death');
      if (r.wolfed) run.seen.add('wolfform');
      if (r.shifted != null) run.seen.add('shifted');
      if (r.kill?.blueprint != null) run.seen.add('blueprint');
      expect(turns, lessThan(300), reason: 'fight ${run.fights} against ${foe.name} never ended');
    }
    if (boss && s.bossesDown.contains(c) && !run.bossLevels.containsKey(c)) {
      run.bossLevels[c] = k.level;
      extra = 0;
    }
    if (s.encounter != null) {
      e.resolveEncounter(rng.nextInt(2));
      run.seen.add('encounter');
    }
    takeLoot(e);
    checkSane(e, 'after fight ${run.fights}');
    // Every 25 fights: save, load, and carry on from the loaded copy.
    if (run.fights % 25 == 0) {
      final json = jsonEncode(e.state.toJson());
      final back = GameState.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
      expect(jsonEncode(back.toJson()), json, reason: 'the save changed on a round trip at fight ${run.fights}');
      e = GameEngine(back, random: Random(seed * 31 + run.fights), clock: () => DateTime(2026, 6, 1));
      run.saves++;
    }
  }
  run.won = e.state.won;
  return run;
}

void main() {
  const seeds = [1, 2, 3, 4];
  final runs = <int, Run>{};

  for (final seed in seeds) {
    test('a whole game, start to Vharrax (seed $seed)', () {
      final run = runs[seed] = playThrough(seed);
      expect(run.won, isTrue, reason: 'never beat Vharrax in ${run.fights} fights (bosses beaten: ${run.bossLevels})');
      expect(run.bossLevels.keys.toSet().containsAll({for (var c = 0; c < mainLands; c++) c}), isTrue, reason: 'skipped a boss');
      expect(run.saves, greaterThan(5));
      // A careful player should rarely be knocked out.
      expect(run.knockouts, lessThan(run.fights ~/ 50 + 10), reason: '${run.knockouts} knockouts in ${run.fights} fights');
      // ignore: avoid_print
      print('seed $seed: ${run.fights} fights, ${run.knockouts} knockouts, bosses at levels ${run.bossLevels.values.join(', ')}');
    });
  }

  test('across the runs, every part of the town gets used', () {
    final seen = {for (final s in seeds) ...?runs[s]?.seen};
    for (final thing in const [
      'inn repaired',
      'home built',
      'ward',
      'smelted iron',
      'smelted gold',
      'smelted obsidian',
      'fletched',
      'brew:might',
      'brew:barkskin',
      'golem iron',
      'golem gold',
      'golem obsidian',
      'the Hidden Ones',
      'pack',
      'raid',
      'encounter',
      'Sir Malric',
      'night foe',
      'blueprint',
      'explored millcellar',
      'elemental ember',
      'elemental frost',
      'elemental mire',
      'guard scarecrow',
    ]) {
      expect(seen, contains(thing), reason: 'no run ever got to "$thing" (saw: ${seen.toList()..sort()})');
    }
    expect(seen.any((x) => x.startsWith('forged ') && !x.endsWith(' piece')), isTrue, reason: 'no run ever forged armour');
    expect(seen.any((x) => x.endsWith(' piece')), isTrue, reason: 'no run ever forged a set piece');
  });
}
