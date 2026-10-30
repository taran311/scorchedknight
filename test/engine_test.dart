// Rules checks: fights, bosses, companions, the shop and saving. Run: flutter test

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/ammo.dart';
import 'package:scorchedknight/game/brews.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/mounts.dart';
import 'package:scorchedknight/game/rules.dart';
import 'package:scorchedknight/game/wilds.dart';
import 'package:scorchedknight/game/dungeons.dart';

/// Fights the current foe with plain attacks (and potions when low) until it's over.
SwingResult fightOut(GameEngine e) {
  late SwingResult r;
  var turns = 0;
  while (e.state.inBattle && turns++ < 300) {
    final k = e.state.knight;
    r = e.takeTurn(
      k.hp < maxHp(k) * .3 && e.whyNot(BattleAction.potion) == null
          ? BattleAction.potion
          : (e.whyNot(BattleAction.skill) == null ? BattleAction.skill : BattleAction.attack),
    );
  }
  return r;
}

void main() {
  test('a new knight starts at the Soot & Kettle, sooty, with no potions until Hob hands some over', () {
    final s = GameEngine.newGame(heroClass: HeroClass.knight);
    expect(s.knight.heroClass, HeroClass.knight);
    expect(s.knight.hp, maxHp(s.knight));
    expect(s.knight.potions, 0);
    GameEngine(s).takeHobsJob();
    expect(s.knight.potions, jobPotions);
    expect(s.inBattle, isFalse);
    expect(s.unlocked, 0);
    expect(sootFor(1), 1.0);
    expect(sootFor(30), 0.0);
    expect(shinesAt(30), isTrue);
  });

  test('every continent has foes, a boss and a level', () {
    expect(continents.length, mainLands + 12);
    for (var c = 0; c < continents.length; c++) {
      expect(foeIndexes(c), isNotEmpty);
      expect(foeAt(bossIndex(c)).boss, isTrue);
      for (final i in foeIndexes(c)) {
        expect(realmAt(i), c);
        expect(foeAt(i).boss, isFalse);
      }
    }
    expect(continents[mainLands - 1].boss.name, 'Vharrax the Ember King');
    // The side lands come after the road, so no foe on it moved.
    expect(continents[mainLands].name, 'Ravenmoor');
    expect(continents[mainLands + 1].name, 'The Howling Weald');
    expect(continents[mainLands + 2].name, 'The Silverwood');
    expect(continents[mainLands + 3].name, 'Deepforge Hold');
    expect(continents[mainLands + 4].name, 'The Isle of Mists');
    expect(continents[mainLands + 5].name, 'The Sunscale Jungle');
    expect(continents[mainLands + 6].name, 'The Shattered Sea');
    expect(continents[mainLands + 7].name, 'The Changeling Isle');
    expect(continents[mainLands + 8].name, 'The Skyreach Aeries');
    expect(continents[eastLand].name, 'The Blossom Isles');
    expect(continents[batLand].name, 'The Hollowdeep');
    expect(continents[frostLand].name, 'The Frostmarch');
  });

  test('the roads branch: choose your own way, and only the Ember Throne waits on one land', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final s = e.state..knight.level = 40;
    s.bossesDown.addAll({0, 2});
    // The Badlands and the Sands both open off the Thornwild, without the Gloomfen.
    expect(e.whyNotTravel(3), isNull);
    expect(e.whyNotTravel(4), isNull);
    expect(e.whyNotTravel(5), isNotNull);
    s.bossesDown.add(4);
    expect(e.whyNotTravel(5), isNull);
    expect(e.whyNotTravel(6), contains('Scorchmaw'));
  });

  test('places on the map: explored once, guards fought for, the Lost Isle last', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight..level = 40;
    // Only Cindervale's places show at first (the Lost Isle hides until the end).
    expect([for (final p in places) if (e.placeShown(p)) p.id], ['millcellar', 'scarecrow']);
    final gold = k.coins, potions = k.potions;
    expect(e.explorePlace('millcellar'), contains('miller'));
    expect(k.coins, greaterThan(gold));
    expect(k.potions, potions + 2);
    expect(e.whyNotExplore('millcellar'), 'Explored');
    // A guarded place is a fight; win it to claim it.
    expect(e.explorePlace('scarecrow'), isNull);
    expect(s.inBattle, isTrue);
    expect(encounterType(s.foe, s.rare).name, 'Old Stitchface');
    s.foeHp = 1;
    k.hp = maxHp(k);
    expect(e.takeTurn(BattleAction.skill).kill, isNotNull);
    expect(s.explored, contains('scarecrow'));
    expect(s.place, isNull);
    // Everywhere open and explored: the Lost Isle appears, with a legendary.
    s.bossesDown.addAll({for (var c = 0; c < continents.length; c++) c});
    s.day = false;
    for (final p in places.where((p) => !p.hidden)) {
      s.explored.add(p.id);
    }
    expect(e.placeShown(placeById('lostisle')!), isTrue);
    s.pendingLoot.clear();
    expect(e.explorePlace('lostisle'), isNotNull);
    expect(s.pendingLoot.single.rarity, Rarity.legendary);
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.explored, s.explored);
  });

  test('the side lands open off the road, and their worst only come out at night', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final s = e.state, k = s.knight..level = 25;
    final moor = mainLands, weald = mainLands + 1;
    expect(e.whyNotTravel(moor), contains('Bone Colossus'));
    s.bossesDown.add(1);
    expect(e.whyNotTravel(moor), isNull);
    expect(e.whyNotTravel(weald), isNotNull);
    s.bossesDown.add(2);
    expect(e.whyNotTravel(weald), isNull);
    // Opening a side land doesn't open the road.
    expect(s.unlocked, 0);
    expect(e.travel(moor), isTrue);
    // By day: never a vampire.
    s.day = true;
    for (var i = 0; i < 60; i++) {
      final f = e.explore();
      expect(f.night, isFalse, reason: '${f.name} came out by day');
      s.inBattle = false;
      s.rare = null;
    }
    // By night: mostly vampires.
    s.day = false;
    var night = 0;
    for (var i = 0; i < 60; i++) {
      if (e.explore().night) night++;
      s.inBattle = false;
      s.rare = null;
    }
    expect(night, greaterThan(25));
    // The Countess sleeps by day.
    s.wins[moor] = winsForBoss;
    s.day = true;
    expect(e.bossReady, isFalse);
    expect(e.challengeBoss(), isFalse);
    s.day = false;
    expect(e.challengeBoss(), isTrue);
    expect(encounterType(s.foe, s.rare).name, 'Countess Morwenna');
    // Side lands are as tough as the road's land they're level with, not the Ember Throne.
    expect(landTier(moor), lessThan(landTier(mainLands - 1)));
    expect(k.level, 25);
  });

  test('the Ashen Order: Sir Malric yields and rides off, until the last time', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state, k = s.knight;
    final at = foeIndexes(5).first;
    for (var met = 0; met < malricLands.length; met++) {
      s.pendingLoot.clear();
      e.travel(0);
      s
        ..inBattle = true
        ..foe = at
        ..rare = Rare(at, Aura.blazing, look: malricLook, name: malricName)
        ..foeLevel = 30
        ..foeMax = 10
        ..foeHp = 1;
      k.hp = maxHp(k);
      final r = e.takeTurn(BattleAction.skill);
      expect(r.kill, isNotNull);
      expect(s.malric, met + 1);
      // He always leaves Ashen steel, and a blueprint while you lack one.
      expect(s.mat(trophyKey(Trophy.ashenSteel)), (met + 1) * trophiesFromBoss);
      if (met < setPieceSlots.length) expect(r.kill!.blueprint, isNotNull);
    }
    expect(s.pendingLoot.any((g) => g.art == 'ashenseal'), isTrue);
    expect(setPieceSlots.every((slot) => s.mat(blueprintKey('ashen', slot)) == 1), isTrue);
    // He's gone for good: no more meetings.
    s.innRepaired = true;
    e.travel(0);
    for (var i = 0; i < 200; i++) {
      e.explore();
      expect(s.rare?.look, isNot(malricLook));
      s
        ..inBattle = false
        ..rare = null;
    }
  });

  test('Dunstan forges set pieces from blueprints, trophies, bars and gold', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(9));
    final s = e.state;
    s.knight
      ..coins = 5000
      ..level = 20;
    expect(e.whyNotForgePiece('nightblood', GearSlot.ring), 'Find the blueprint first');
    s.addMat(blueprintKey('nightblood', GearSlot.ring), 1);
    expect(e.whyNotForgePiece('nightblood', GearSlot.ring), contains('vampire fang'));
    s
      ..addMat(trophyKey(Trophy.fang), pieceTrophies)
      ..addMat(barKey(Metal.iron), pieceBars);
    final ring = e.forgePiece('nightblood', GearSlot.ring)!;
    expect(ring.gearSet, 'nightblood');
    expect(ring.rarity, Rarity.epic);
    expect(ring.level, 20);
    expect(s.mat(trophyKey(Trophy.fang)), 0);
    // The blueprint is kept.
    expect(s.mat(blueprintKey('nightblood', GearSlot.ring)), 1);
    // Forged sets never turn up as random drops.
    final loot = LootTable(Random(1));
    for (var i = 0; i < 3000; i++) {
      final g = loot.roll(HeroClass.ranger, 20, odds: const [0, 0, 50, 50, 0]);
      expect(gearSetById(g.gearSet)?.forged ?? false, isFalse);
    }
  });

  test('elves and dwarves: their trophies, the dwarves\' ore, and their sets\' tricks', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(21));
    final s = e.state, k = s.knight..level = 32;
    s.bossesDown.addAll({0, 1, 2, 3});
    expect(e.travel(mainLands + 2), isTrue);
    expect(e.travel(mainLands + 3), isTrue);
    // Fell the Thane: runesteel, a blueprint and ore.
    e.challengeBoss(); // not ready yet
    s.wins[mainLands + 3] = winsForBoss;
    expect(e.challengeBoss(), isTrue);
    s.foeHp = 1;
    k.hp = maxHp(k);
    final r = e.takeTurn(BattleAction.skill);
    expect(r.kill, isNotNull);
    expect(s.mat(trophyKey(Trophy.runesteel)), trophiesFromBoss);
    expect(r.kill!.blueprint, contains('Deepforge'));
    expect(s.mat(oreKey(Metal.iron)) + s.mat(oreKey(Metal.gold)), dwarfOre * 3);
    expect(s.pendingLoot.any((g) => g.art == 'runependant'), isTrue);
    // The full Silverleaf set: the first blow at you misses.
    final loot = LootTable(Random(2));
    k.gloves = false;
    for (final slot in setPieceSlots) {
      final piece = loot.setPiece('silverleaf', slot, k.heroClass, k.level);
      s.pendingLoot.add(piece);
      e.equipLoot(piece.id);
    }
    expect(activeSets(k.gear).any((x) => x.$1.id == 'silverleaf' && x.$2 == 3), isTrue);
    e.travel(mainLands + 2);
    e.explore();
    s.foeHp = s.foeMax = 1 << 30;
    final first = e.takeTurn(BattleAction.attack);
    expect(first.counter, 0);
  });

  test('elementals shrug off their own element, take double from its opposite, and leave cores', () {
    final ember = Rare(foeIndexes(5).first, Aura.blazing, look: Elemental.ember.look).type;
    expect(ember.name, 'Ember Elemental');
    expect(ember.element, 'burn');
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(31));
    final s = e.state, k = s.knight..level = 30;
    // Fire does nothing to an ember elemental; frost does twice as much.
    s
      ..inBattle = true
      ..foe = foeIndexes(5).first
      ..rare = Rare(foeIndexes(5).first, Aura.blazing, look: Elemental.ember.look)
      ..foeLevel = 30;
    final d = swingDamage(s, .5, hitRoll: .5);
    expect(d.burn + d.ignite, 0);
    s.rare = Rare(foeIndexes(5).first, Aura.frost, look: Elemental.frost.look);
    final d2 = swingDamage(s, .5, hitRoll: .5);
    expect(d2.burn + d2.ignite, greaterThan(0));
    s.inBattle = false;
    // Three cores make a rune of their element, tier II or better.
    k.coins = 10000;
    s.addMat(coreKey(Elemental.frost), 3);
    final roll = e.bindCores(Elemental.frost)!;
    expect(roll.info.stat, Stat.frost);
    expect(roll.tier, greaterThanOrEqualTo(2));
    expect(s.mat(coreKey(Elemental.frost)), 0);
    expect(e.bindCores(Elemental.frost), isNull);
  });

  test('weapons keep the elements; gold and XP stay on rings and charms; fire burns, venom builds, wounds bleed', () {
    // An old helm with fire and gold turns into plain damage and health.
    final helm = GearItem(id: 'h', name: 'Old helm', slot: GearSlot.helm, art: 'helm', rarity: Rarity.rare, level: 5, value: 10, stats: {Stat.burn: 4, Stat.fortune: 12, Stat.vigour: 10});
    expect(helm.stats.containsKey(Stat.burn), isFalse);
    expect(helm.stats.containsKey(Stat.fortune), isFalse);
    expect(helm.stat(Stat.damage), 4);
    expect(helm.stat(Stat.vigour), 19);
    // New drops: at most one element, and only on weapons.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    for (var i = 0; i < 300; i++) {
      final g = e.loot.roll(HeroClass.knight, 20);
      final els = g.stats.keys.where((st) => const {Stat.poison, Stat.burn, Stat.frost, Stat.bleed}.contains(st)).length;
      if (g.slot != GearSlot.weapon) expect(els, 0);
      if (g.rarity != Rarity.legendary) expect(els, lessThanOrEqualTo(1));
      if (g.slot != GearSlot.ring && g.slot != GearSlot.trinket) expect(g.stats.containsKey(Stat.fortune) || g.stats.containsKey(Stat.wisdom), isFalse);
    }
  });

  test('mounted, the fight opens with a free charge, then it\'s on foot', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(9));
    final s = e.state, k = s.knight;
    k.mount = mounts.first.id;
    e.explore();
    s.foeHp = s.foeMax = 100000;
    final r = e.openingCharge()!;
    expect(r.chargeHit, greaterThan(0));
    expect(s.foeHp, 100000 - r.chargeHit);
    expect(e.openingCharge(), isNull);
    expect(e.takeTurn(BattleAction.attack).chargeHit, 0);
  });

  test('the Faceless brace for whatever way you struck them last', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(41));
    final s = e.state, k = s.knight..level = 36;
    final isle = mainLands + 4;
    expect(e.whyNotTravel(isle), contains('Alpha'));
    s.bossesDown.add(mainLands + 1);
    expect(e.travel(isle), isTrue);
    expect(e.explore().mimic || s.rare != null, isTrue);
    s
      ..rare = null
      ..foe = lookIndex('facelessWanderer', isle)
      ..foeHp = s.foeMax = 1 << 30;
    k.hp = 1 << 20;
    // Same blow twice: the second one finds it braced.
    var first = 0, second = 0;
    for (var i = 0; i < 40; i++) {
      s.lastStyle = null;
      final a = e.takeTurn(BattleAction.attack);
      final b = e.takeTurn(BattleAction.attack);
      if (!a.miss && !b.miss) {
        first += a.damage.base;
        second += b.damage.base;
      }
      k.hp = 1 << 20;
    }
    expect(second, lessThan(first * .85));
    expect(s.lastStyle, 'blade');
  });

  test('lizardfolk regrow between blows, unless fire touches them', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(51));
    final s = e.state, k = s.knight..level = 30;
    final jungle = mainLands + 5;
    s.bossesDown.add(4);
    expect(e.travel(jungle), isTrue);
    e.explore();
    s
      ..rare = null
      ..foe = lookIndex('lizardGuard', jungle)
      ..foeMax = 10000
      ..foeHp = 5000;
    k.hp = 1 << 20;
    k.loadout.weapon?.enchant = null;
    final r = e.takeTurn(BattleAction.skill);
    expect(r.damage.burn, 0);
    expect(r.regrew, (10000 * regrowShare).round());
    // Fire stops it.
    k.loadout.weapon?.enchant = const EnchantRoll('flametongue', 3, 40);
    final r2 = e.takeTurn(BattleAction.skill);
    expect(r2.damage.burn + r2.damage.ignite, greaterThan(0));
    expect(r2.regrew, 0);
  });

  test('the Shattered Sea: the Kraken guards a sea-god\'s weapon, and the Leviathan its eye', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(61));
    final s = e.state, k = s.knight..level = 30;
    final sea = mainLands + 6;
    expect(e.whyNotTravel(sea), contains('Bone Colossus'));
    s.bossesDown.addAll({0, 1});
    expect(e.travel(sea), isTrue);
    // The Kraken's Reef: a fight, and Poseidon's weapon for your class.
    expect(e.explorePlace('krakenreef'), isNull);
    expect(encounterType(s.foe, s.rare).name, 'The Kraken');
    s.foeHp = 1;
    k.hp = maxHp(k);
    s.pendingLoot.clear();
    expect(e.takeTurn(BattleAction.attack).kill ?? e.takeTurn(BattleAction.attack).kill, isNotNull);
    expect(s.pendingLoot.any((g) => g.name == 'Poseidon\'s Bow'), isTrue);
    // The Leviathan: its eye, coral and a Tidecaller blueprint.
    e.travel(sea);
    s.wins[sea] = winsForBoss;
    expect(e.challengeBoss(), isTrue);
    expect(encounterType(s.foe, s.rare).name, 'The Leviathan');
    s.foeHp = 1;
    k.hp = maxHp(k);
    var r = e.takeTurn(BattleAction.attack);
    while (s.inBattle) {
      r = e.takeTurn(BattleAction.attack);
    }
    expect(r.kill?.blueprint ?? '', contains('Tidecaller'));
    expect(s.pendingLoot.any((g) => g.art == 'leviathaneye'), isTrue);
    expect(s.mat(trophyKey(Trophy.coral)), greaterThanOrEqualTo(trophiesFromBoss));
  });

  test('shapeshifters take another foe\'s shape, fight like it, and shift again when hurt', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(71));
    final s = e.state, k = s.knight..level = 40;
    final isle = mainLands + 7;
    expect(e.whyNotTravel(isle), contains('Leviathan'));
    s.bossesDown.add(mainLands + 6);
    expect(e.travel(isle), isTrue);
    e.explore();
    s
      ..rare = null
      ..foe = lookIndex('shifter', isle)
      ..foeMax = 100000
      ..foeHp = 100000;
    k.hp = 1 << 20;
    final r = e.takeTurn(BattleAction.attack);
    expect(r.shifted, isNotNull);
    expect(s.form, isNotNull);
    expect(realmAt(s.form!), isNot(isle));
    final shape = foeIn(s);
    expect(shape.look, foeAt(s.form!).look);
    expect(shape.shifts, isTrue);
    // Not again until it's badly hurt; then once more.
    expect(e.takeTurn(BattleAction.attack).shifted, isNull);
    s.foeHp = 40000;
    expect(e.takeTurn(BattleAction.attack).shifted, isNotNull);
    expect(s.shifts, 2);
    expect(e.takeTurn(BattleAction.attack).shifted, isNull);
    // It always leaves its shifting skin.
    s.foeHp = 1;
    KillResult? kill;
    for (var i = 0; i < 20 && kill == null; i++) {
      k.hp = 1 << 20;
      kill = e.takeTurn(BattleAction.attack).kill; // (a blow can miss now and then)
    }
    expect(kill, isNotNull);
    expect(s.mat(trophyKey(Trophy.skin)), greaterThanOrEqualTo(0));
    expect(s.form, isNull);
  });

  test('the Thousandfold wears your face, then the shapes of other lands\' bosses, and still counts as the boss', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(73));
    final s = e.state, k = s.knight..level = 42;
    final isle = mainLands + 7;
    s.bossesDown.add(mainLands + 6);
    e.travel(isle);
    s.wins[isle] = winsForBoss;
    expect(e.challengeBoss(), isTrue);
    expect(foeIn(s).look, 'thousandfold');
    s.foeHp = (s.foeMax * .5).round();
    k.hp = 1 << 20;
    final r = e.takeTurn(BattleAction.attack);
    expect(r.shifted, isNotNull);
    expect(foeIn(s).boss, isTrue);
    expect(foeAt(s.form!).boss, isTrue);
    s.foeHp = 1;
    late SwingResult end;
    do {
      end = e.takeTurn(BattleAction.attack);
    } while (s.inBattle);
    expect(end.kill?.boss, isTrue);
    expect(s.bossesDown, contains(isle));
    expect(s.pendingLoot.any((g) => g.art == 'mirrorheart'), isTrue);
  });

  test('the Skyreach Aeries: griffins, the Storm Roc, and the Skyborn set\'s updraft', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(81));
    final s = e.state, k = s.knight..level = 36;
    final aerie = mainLands + 8;
    expect(e.whyNotTravel(aerie), contains('Thane'));
    s.bossesDown.add(mainLands + 3);
    expect(e.travel(aerie), isTrue);
    // The full Skyborn set hits fliers 25% harder.
    final loot = LootTable(Random(3));
    k.gloves = false;
    for (final slot in setPieceSlots) {
      final piece = loot.setPiece('skyborn', slot, k.heroClass, k.level);
      s.pendingLoot.add(piece);
      e.equipLoot(piece.id);
    }
    e.explore();
    s
      ..rare = null
      ..foe = lookIndex('griffin', aerie)
      ..foeHp = s.foeMax = 1 << 30;
    expect(foeIn(s).aloft, isTrue);
    expect(seaBeasts, contains('griffin'));
    // The Storm Roc drops its plume, feathers and a blueprint.
    s.inBattle = false;
    s.wins[aerie] = winsForBoss;
    expect(e.challengeBoss(), isTrue);
    expect(foeIn(s).name, contains('Storm Roc'));
    s.foeHp = 1;
    k.hp = 1 << 20;
    late SwingResult r;
    do {
      r = e.takeTurn(BattleAction.attack);
    } while (s.inBattle);
    expect(r.kill?.blueprint, contains('Skyborn'));
    expect(s.pendingLoot.any((g) => g.art == 'stormfeather'), isTrue);
    expect(mountById('griffin')!.flying, isTrue);
  });

  test('elves slip some attacks and bolts; dwarves take no critical hits', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(91));
    final s = e.state, k = s.knight..level = 34;
    s.bossesDown.addAll({0, 2, 3});
    e.travel(mainLands + 2);
    e.explore();
    s
      ..rare = null
      ..foe = lookIndex('elfBlade', mainLands + 2)
      ..foeHp = s.foeMax = 1 << 30;
    k.hp = 1 << 20;
    var misses = 0;
    for (var i = 0; i < 200; i++) {
      if (e.takeTurn(BattleAction.attack).miss) misses++;
      k.hp = 1 << 20;
    }
    expect(misses, greaterThan(200 * (missChance + evasiveMiss * .6)));
    s.foe = lookIndex('dwarfAxe', mainLands + 3);
    for (var i = 0; i < 200; i++) {
      expect(swingDamage(s, i / 200, hitRoll: .5).crit, isFalse);
    }
  });

  test('the Bloodmoon Pelt: badly hurt, the wolf comes out once a fight', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(11));
    final s = e.state, k = s.knight..level = 20;
    k.trinket = LootTable(Random(1)).bossTrinket('bloodmoonpelt', 20);
    e.explore();
    s.foeHp = s.foeMax = 1 << 30;
    // A weak foe, so its blows nudge you under half without knocking you out.
    s.foeLevel = 1;
    var wolfed = 0, ended = 0;
    for (var i = 0; i < 80 && s.inBattle; i++) {
      // Hover just above half health, so the next blow tips you under.
      k.hp = s.wolfUsed ? maxHp(k) : (maxHp(k) * .52).round();
      final r = e.takeTurn(BattleAction.attack);
      if (r.wolfed) wolfed++;
      if (r.wolfEnded) ended++;
    }
    expect(wolfed, 1);
    expect(ended, 1);
    expect(s.wolfTurns, 0);
  });

  test('exploring starts a fight in the chosen continent, and a turn hits the foe', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    final f = e.explore();
    expect(e.state.inBattle, isTrue);
    expect(e.state.foeHp, e.state.foeMax);
    expect(realmAt(e.state.rare?.base ?? e.state.foe), 0);
    expect(f.name, isNotEmpty);
    final before = e.state.foeHp;
    e.takeTurn(BattleAction.skill); // Shield Bash never misses
    expect(e.state.foeHp < before || !e.state.inBattle, isTrue);
  });

  test('Hob\'s job: goblins only, timber then iron, no resting until the inn is patched up', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(21));
    final s = e.state;
    expect(s.innRepaired, isFalse);
    expect(e.whyNotRest, isNotNull);
    s.knight.hp = 10;
    expect(e.rest(), 0);
    expect(e.repairInn(), isFalse);
    // Nothing drops until you've said yes to Hob.
    expect(e.jobOffered, isTrue);
    s.knight.hp = 100000;
    e.explore();
    fightOut(e);
    expect(s.timber, 0);
    expect(e.takeHobsJob(), isTrue);
    expect(e.jobOffered, isFalse);
    var fights = 0;
    while (!e.innReady && fights++ < 40) {
      s.knight.hp = 100000;
      final f = e.explore();
      expect(f.look == 'goblin' || f.look == 'goblinChief', isTrue, reason: f.name);
      if (s.timber < timberNeeded) expect(f.look, 'goblin');
      fightOut(e);
    }
    expect(s.timber, timberNeeded);
    expect(s.ironScrap, ironNeeded);
    final coins = s.knight.coins;
    expect(e.repairInn(), isTrue);
    expect(s.innRepaired, isTrue);
    expect(s.knight.coins, coins + innRepairReward);
    expect(e.whyNotRest, isNull);
    // The rest of Cindervale opens up.
    final looks = <String>{};
    for (var i = 0; i < 40; i++) {
      looks.add(e.explore().look);
      while (s.inBattle) {
        e.takeTurn(BattleAction.flee);
      }
    }
    expect(looks.length, greaterThan(2));
    // An old save without the field finds the inn already repaired.
    final old = s.toJson()..remove('inn');
    expect(GameState.fromJson(old).innRepaired, isTrue);
  });

  test('a knight wins most early fights in Cindervale', () {
    for (final seed in [3, 4, 5]) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(seed));
      var wins = 0;
      for (var i = 0; i < 10; i++) {
        e.rest();
        e.explore();
        final r = fightOut(e);
        if (r.kill != null) wins++;
        for (final g in List.of(e.state.pendingLoot)) {
          e.sellLoot(g.id);
        }
      }
      expect(wins, greaterThanOrEqualTo(8), reason: 'seed $seed');
    }
  });

  test('skills, potions and commands are only offered when they can be used', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    expect(e.whyNot(BattleAction.attack), isNotNull); // no fight yet
    e.explore();
    expect(e.whyNot(BattleAction.attack), isNull);
    expect(e.whyNot(BattleAction.potion), isNotNull); // full health
    expect(e.whyNot(BattleAction.pet), isNotNull); // no companion yet
    expect(e.whyNot(BattleAction.skill), isNull);
    final r = e.takeTurn(BattleAction.skill);
    if (r.kill == null) expect(e.whyNot(BattleAction.skill), isNotNull); // resting after the bash
  });

  test('the boss waits for enough wins, and its first fall opens the road and brings a companion', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state;
    expect(e.challengeBoss(), isFalse);
    s.wins[0] = winsForBoss;
    s.knight
      ..level = 12
      ..hp = 10000;
    expect(e.challengeBoss(), isTrue);
    expect(foeAt(s.foe).boss, isTrue);
    s.foeHp = 1;
    final r = e.takeTurn(BattleAction.skill);
    expect(r.kill, isNotNull);
    expect(r.kill!.boss, isTrue);
    expect(s.bossesDown, contains(0));
    // Gorbo opens two roads at once: the Gloomfen and the Thornwild.
    expect(r.kill!.opened, [1, 2]);
    expect(s.knight.pets.containsKey(Pet.wolf.name), isTrue);
    expect(s.pendingLoot.any((g) => g.art == 'cyclopseye'), isTrue);
    expect(e.travel(1), isTrue);
    expect(e.travel(2), isTrue);
    expect(e.travel(3), isFalse);
  });

  test('a knockout ends the fight back at the Inn, healed and a little poorer', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state;
    s
      ..unlocked = 6
      ..continent = 6; // level 38 foes against a level 1 knight (the gate is skipped on purpose)
    s.knight.coins = 500;
    e.explore();
    final r = fightOut(e);
    expect(r.knockedOut, isTrue);
    expect(s.inBattle, isFalse);
    expect(s.knight.hp, maxHp(s.knight));
    expect(s.knight.coins, lessThan(500));
    expect(s.knockouts, 1);
  });

  test('fleeing ends the fight with nothing won', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(6));
    e.explore();
    final felled = e.state.foesFelled;
    var tries = 0;
    while (e.state.inBattle && tries++ < 50) {
      e.takeTurn(BattleAction.flee);
    }
    expect(e.state.inBattle, isFalse);
    expect(e.state.foesFelled, felled);
  });

  test('the merchant sells potions and armour, and never companions', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(7));
    final k = e.state.knight..coins = 1000;
    final before = k.potions;
    expect(e.purchase('potion'), isTrue);
    expect(k.potions, before + 1);
    expect(e.purchase('chainmail'), isTrue);
    expect(k.loadout.armour, 'chainmail');
    expect(e.purchase('wolf'), isFalse);
    expect(e.purchase('mount:nightmare'), isFalse);
  });

  test('the better armour and special bolts are forged from ore and gems, not bought', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(7));
    final s = e.state, k = s.knight..coins = 5000;
    expect(e.purchase('plate'), isFalse);
    expect(e.purchase('ammo:fire'), isFalse);
    // Seven lumps of iron ore make three bars (one lump left over).
    s.addMat(oreKey(Metal.iron), 7);
    expect(e.smelt(Metal.iron), 3);
    expect(s.mat(barKey(Metal.iron)), 3);
    expect(s.mat(oreKey(Metal.iron)), 1);
    expect(e.whyNotCraft('plate'), isNotNull);
    s.addMat(barKey(Metal.iron), 3);
    expect(e.craftArmour('plate'), isTrue);
    expect(k.loadout.armour, 'plate');
    expect(s.mat(barKey(Metal.iron)), 0);
    // A ruby makes a bundle of burning bolts.
    s.addMat(gemKey(Gem.ruby), 1);
    expect(e.fletch(Gem.ruby), isTrue);
    expect(k.ammo['fire'], ammoBundle);
    expect(e.fletch(Gem.ruby), isFalse);
    // Stock survives a save.
    s.addMat(gemKey(Gem.pearl), 2);
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.mat(gemKey(Gem.pearl)), 2);
    expect(back.mat(oreKey(Metal.iron)), 1);
  });

  test('Mags brews from reagents, drunk for a few fights (the mending draught heals every turn)', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(7));
    final s = e.state, k = s.knight..coins = 1000;
    expect(e.brew(Brew.might), isFalse); // no Ashbloom yet
    s.reagents[0] = 2;
    expect(e.brew(Brew.healing), isTrue);
    expect(brewOn(k, Brew.healing), isTrue);
    expect(e.brew(Brew.might), isFalse); // the Ashbloom went on the mending draught
    s.reagents[0] = 2;
    expect(e.brew(Brew.might), isTrue);
    expect(brewOn(k, Brew.might), isTrue);
    expect(s.reagents[0], 0);
    // It wears off a fight at a time.
    for (var i = 0; i < brewFights; i++) {
      e.explore();
      while (s.inBattle) {
        e.takeTurn(BattleAction.flee);
      }
    }
    expect(brewOn(k, Brew.might), isFalse);
    // The mending draught gives HP back every turn while it lasts.
    k.brews[Brew.healing.name] = 2;
    e.explore();
    s.foeHp = s.foeMax = 100000;
    k.hp = maxHp(k) ~/ 2;
    final r = e.takeTurn(BattleAction.attack);
    expect(r.regrown, greaterThan(0));
    while (s.inBattle) {
      e.takeTurn(BattleAction.flee);
    }
    // Reaper's Bane keeps you standing once.
    s.reagents[4] = 3;
    expect(e.brew(Brew.reaperbane), isTrue);
    expect(e.brew(Brew.reaperbane), isFalse);
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(brewOn(back.knight, Brew.reaperbane), isTrue);
  });

  test('golems are living stone wherever they walk', () {
    final f = Rare(foeIndexes(4).first, Metal.gold.aura, look: Metal.gold.golemLook).type;
    expect(f.name, 'Gold Golem');
    expect(f.stone, isTrue);
    expect(f.undead, isFalse);
  });

  test('a save survives a round trip, mid-fight included', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(8));
    e.explore();
    e.takeTurn(BattleAction.attack);
    final json = jsonEncode(e.state.toJson());
    final back = GameState.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
    expect(back.inBattle, e.state.inBattle);
    expect(back.foe, e.state.foe);
    expect(back.foeHp, e.state.foeHp);
    expect(back.mana, e.state.mana);
    expect(back.knight.heroClass, HeroClass.knight);
    expect(jsonEncode(back.toJson()), json);
  });

  test('a knight gathers mana by fighting and spends it on a rite', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(9));
    e.explore();
    expect(e.state.mana, startingMana(e.state.knight));
    expect(e.whyNot(BattleAction.cast), isNotNull); // Arcane Bolt needs 2
    e.state.mana = 5;
    final r = e.takeTurn(BattleAction.cast);
    expect(r.damage.spell?.id, 'arcanebolt');
    expect(e.state.mana, 3);
  });

  test('the crossbow outshoots the blade against a foe aloft', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(11));
    final s = e.state;
    s
      ..bossesDown.add(0)
      ..knight.level = 6;
    expect(e.travel(1), isTrue);
    var melee = 0, shots = 0, n = 0;
    while (n < 60) {
      e.explore();
      if (!encounterType(s.foe, s.rare).aloft) {
        e.takeTurn(BattleAction.flee);
        while (s.inBattle) {
          e.takeTurn(BattleAction.flee);
        }
        continue;
      }
      s.knight.hp = 100000;
      final a = e.takeTurn(BattleAction.attack), b = e.takeTurn(BattleAction.shoot);
      if (!a.miss) melee += a.damage.base;
      if (!b.miss) shots += b.damage.base;
      while (s.inBattle) {
        e.takeTurn(BattleAction.flee);
      }
      n++;
    }
    expect(shots, greaterThan(melee));
    s.knight.coins = 10000;
    expect(e.purchase('crossbow'), isTrue);
    expect(s.knight.crossbow, 1);
  });

  test('a save from before the Sunken Sands moves its lands and foes along', () {
    // An old hero, part way through the Cinderreach (then land 4), fighting its third foe.
    var oldFirstCinder = 0;
    for (var c = 0; c < 4; c++) {
      oldFirstCinder += continents[c].foes.length + 1;
    }
    final old = GameEngine.newGame(heroClass: HeroClass.knight).toJson()
      ..['v'] = 1
      ..['continent'] = 4
      ..['unlocked'] = 4
      ..['wins'] = [8, 8, 8, 8, 3, 0]
      ..['bosses'] = [0, 1, 2, 3]
      ..['battle'] = true
      ..['foe'] = oldFirstCinder + 2;
    final s = GameState.fromJson(old);
    expect(continents[s.continent].name, 'The Cinderreach');
    expect(s.wins[5], 3);
    expect(s.wins[4], 0);
    expect(s.bossesDown, {0, 1, 2, 3});
    expect(foeAt(s.foe).name, continents[5].foes[2].name);
    expect(s.unlocked, 5); // the Sands (4) are open behind them too
  });

  test('a continent needs its boss beaten and its level reached', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(12));
    final s = e.state;
    expect(e.whyNotTravel(1), isNotNull); // Gorbo still stands
    s.bossesDown.add(0);
    expect(e.travel(1), isFalse); // level 1, the Gloomfen wants 6
    s.knight.level = 6;
    expect(e.travel(1), isTrue);
  });

  test('a land\'s hazard bites every turn until Mags crafts its ward', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(13));
    final s = e.state;
    s
      ..bossesDown.add(0)
      ..knight.level = 6;
    s.knight.hp = maxHp(s.knight);
    e.travel(1);
    e.explore();
    s.knight.hp = 100000; // survive the foe, see the hazard
    final r = e.takeTurn(BattleAction.attack);
    if (s.inBattle) expect(r.hazard, greaterThan(0));
    while (s.inBattle) {
      e.takeTurn(BattleAction.flee);
    }
    expect(e.whyNotWard(1), isNotNull); // no Ashbloom yet
    s.reagents[0] = reagentsForWard;
    s.knight.coins = 10000;
    expect(e.craftWard(1), isTrue);
    expect(s.hazardIn(1), isFalse);
    expect(s.reagents[0], 0);
    e.explore();
    final r2 = e.takeTurn(BattleAction.attack);
    expect(r2.hazard, 0);
  });

  test('loot rolls for every class and slot', () {
    final t = LootTable(Random(10));
    for (final c in HeroClass.values) {
      for (var i = 0; i < 40; i++) {
        final g = t.roll(c, 1 + i, boss: i.isEven);
        expect(g.name, isNotEmpty);
        expect(g.value, greaterThan(0));
      }
    }
  });

  test('the Blossom Isles drop their own weapons, and only there', () {
    final t = LootTable(Random(12));
    const east = {'katana', 'wakizashi', 'naginata', 'kanabo', 'yumi', 'shuriken', 'shakujo', 'fan'};
    for (final c in HeroClass.values) {
      var found = false;
      for (var i = 0; i < 300; i++) {
        expect(east.contains(t.roll(c, 30).art), isFalse);
        if (east.contains(t.roll(c, 30, east: true, only: GearSlot.weapon).art)) found = true;
      }
      expect(found, isTrue, reason: '$c');
    }
  });

  test('the Hollowdeep: opened by the Gloomfen, and its Duskwing weapons drink from every blow', () {
    expect(openers(batLand), [1]);
    expect(landTrophyName(batLand), 'fang');
    final t = LootTable(Random(15));
    for (final c in HeroClass.values) {
      final dusk = t.batDrop(c, 25);
      double mean(GearItem Function() make) => [for (var i = 0; i < 60; i++) make().score].reduce((a, b) => a + b) / 60;
      expect(dusk.rarity, Rarity.epic);
      expect(dusk.slot, GearSlot.weapon);
      expect(dusk.stat(Stat.leech), greaterThan(0), reason: '$c');
      // Tuned to the same edge as the other one-per-hero farmed weapons.
      final d = mean(() => t.batDrop(c, 25)), e = mean(() => t.elfDrop(c, 25));
      expect(d, closeTo(e, e * .06), reason: '$c');
    }
    expect(t.bossTrinket('echostone', 25).name, 'The Echo Stone');
  });

  test('the Frostmarch: opened by Grimtusk, its Rimeforged weapons bring the mountain down', () {
    expect(openers(frostLand), [3]);
    expect(landTrophyName(frostLand), 'pelt');
    final t = LootTable(Random(18));
    for (final c in HeroClass.values) {
      double mean(GearItem Function() make) => [for (var i = 0; i < 60; i++) make().score].reduce((a, b) => a + b) / 60;
      final rime = t.frostDrop(c, 30);
      expect(rime.special, 'avalanche');
      expect(rime.stat(Stat.frost), greaterThan(0), reason: '$c');
      final d = mean(() => t.frostDrop(c, 30)), b = mean(() => t.batDrop(c, 30));
      expect(d, closeTo(b, b * .08), reason: '$c');
    }
    expect(specials['avalanche']!.stun, greaterThan(0));
    expect(t.bossTrinket('rimeheart', 30).name, 'The Rimeheart');
  });

  test('runes: a scroll offers three different ones to choose from, never a useless Wyrmslayer', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(16));
    final k = e.state.knight..level = 12;
    for (var i = 0; i < 40; i++) {
      k.scrolls = 1;
      final choices = e.enchantChoices(EnchantSlot.weapon, scroll: true);
      expect(choices.length, 3);
      expect(choices.map((r) => r.id).toSet().length, 3);
      expect(choices.any((r) => r.id == 'wyrmslayer'), isFalse);
      expect(k.scrolls, 0);
    }
    expect(e.enchantChoices(EnchantSlot.armour, scroll: true), isEmpty); // no scroll left
  });

  test('special shots: fire burns on, venom stacks, frost freezes now and then', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(17));
    final s = e.state, k = s.knight..level = 10;
    expect(e.travel(0), isTrue);
    var burned = 0, venomed = 0, froze = 0, stacks = 0;
    for (var fight = 0; fight < 30; fight++) {
      e.explore();
      if (!s.inBattle) continue;
      s.foeHp = s.foeMax = 100000; // a long fight, so the effects can show
      k.hp = 100000;
      final kind = AmmoType.values[fight % 3 == 0 ? 0 : (fight % 3 == 1 ? 4 : 3)];
      k.ammo[kind.name] = 5;
      k.ammoLoaded = kind.name;
      for (var i = 0; i < 4; i++) {
        final r = e.takeTurn(BattleAction.shoot);
        burned += r.burned;
        venomed += r.venomed;
        if (r.froze) froze++;
      }
      stacks = max(stacks, s.foeVenom);
      // The fight's state survives a save.
      final back = GameState.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, dynamic>());
      expect(back.foeVenom, s.foeVenom);
      expect(back.foeBurnTurns, s.foeBurnTurns);
      s.foeHp = 1;
      while (s.inBattle) {
        k.hp = 100000;
        e.takeTurn(BattleAction.attack);
      }
      expect(s.foeVenom, 0); // a new fight starts clean
    }
    expect(burned, greaterThan(0));
    expect(venomed, greaterThan(0));
    expect(stacks, greaterThan(1));
    expect(froze, greaterThan(0));
    expect(gemFor(AmmoType.frost), Gem.sapphire);
    expect(gemFor(AmmoType.venom), Gem.emerald);
  });

  test('legendary weapons each carry their own special, from their class\'s set', () {
    for (final e in legendSpecials.entries) {
      for (final id in e.value) {
        expect(specials[id], isNotNull, reason: id);
      }
      expect(legendSpecial('Some Blade', e.key), legendSpecial('Some Blade', e.key)); // always the same
    }
    // Across a class's legendaries, more than one special turns up.
    final t = LootTable(Random(18));
    final seen = <String>{};
    for (var i = 0; i < 600; i++) {
      final g = t.roll(HeroClass.knight, 30, odds: const [0, 0, 0, 0, 100], only: GearSlot.weapon);
      if (g.special != null) seen.add(g.special!);
    }
    // The knight's nine legendaries carry nine different specials.
    expect(seen, containsAll(['cleave', 'stormcall', 'hellgate', 'fatesroll', 'deadcharge', 'legion', 'wyrmcall', 'moonpack', 'nightswarm']));
    expect(LootTable(Random(1)).batDrop(HeroClass.ranger, 20).special, 'nightswarm');
  });

  test('the Roll of Fate comes up lucky or unlucky, and unlucky bites back', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(19));
    final s = e.state, k = s.knight..level = 10;
    k.loadout.weapon = GearItem(id: 'dice', name: 'Test dice blade', slot: GearSlot.weapon, art: 'longsword', rarity: Rarity.legendary, level: 10, heroClass: HeroClass.knight, special: 'fatesroll', value: 1, stats: const {Stat.damage: 20});
    expect(e.travel(0), isTrue);
    var lucky = 0, unlucky = 0, bitten = 0;
    for (var f = 0; f < 160; f++) {
      e.explore();
      if (!s.inBattle) continue;
      s.foeHp = s.foeMax = 100000;
      for (var i = 0; i < 4; i++) {
        k.hp = maxHp(k);
        final r = e.takeTurn(BattleAction.attack);
        if (r.damage.special?.name == 'Lucky!') lucky++;
        if (r.damage.special?.name == 'Unlucky!') {
          unlucky++;
          if (r.selfHurt > 0) bitten++;
        }
      }
      s.foeHp = 1;
      while (s.inBattle) {
        k.hp = 100000;
        e.takeTurn(BattleAction.attack);
      }
    }
    expect(lucky, greaterThan(unlucky));
    expect(unlucky, greaterThan(0));
    expect(bitten, unlucky);
  });

  test('Dunstan tempers a farmed weapon up to your level, for bars and gold', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(13));
    final k = e.state.knight..level = 20;
    k.loadout.weapon = e.loot.entDrop(HeroClass.knight, 8);
    final before = k.loadout.weapon!;
    final (metal, bars, gold) = e.temperCost(before);
    expect(metal, Metal.iron);
    expect(e.whyNotTemper(), isNotNull); // no bars yet
    e.state.addMat(barKey(Metal.iron), bars);
    k.coins = gold;
    expect(e.whyNotTemper(), isNull);
    final after = e.temper()!;
    expect(after.level, 20);
    expect(after.id, before.id);
    expect(after.stat(Stat.damage), greaterThan(before.stat(Stat.damage)));
    expect(k.coins, 0);
    expect(e.temperable, isNull); // it's at your level now
  });

  test('every class finds armour variants, with the same protection on offer', () {
    double best(HeroClass c) => [for (final b in armourVariants[c]!) for (final id in b.$2) armourTierById(id).reduction].reduce(max);
    for (final c in HeroClass.values) {
      expect(best(c), best(HeroClass.knight), reason: '$c');
      for (final b in armourVariants[c]!) {
        for (final id in b.$2) {
          expect(armourTierById(id).heroClass, c, reason: id);
        }
      }
    }
  });

  test('the Thornwild\'s relic is a whip (a bow for rangers)', () {
    final t = LootTable(Random(14));
    expect(t.relicWeapon(2, 20, HeroClass.knight).art, 'whip');
    expect(t.relicWeapon(2, 20, HeroClass.mage).art, 'whip');
    expect(t.relicWeapon(2, 20, HeroClass.ranger).art, 'heartbow');
    expect(t.relicWeapon(0, 20, HeroClass.mage).art, 'kingsfall');
    expect(offhandKindsFor('whip'), containsAll([OffhandKind.shield, OffhandKind.focus, OffhandKind.parrying]));
  });

  test('equipping keeps the old piece in the gear chest, to wear again later', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(11));
    final k = e.state.knight;
    final old = k.loadout.weapon!;
    final weapon = e.loot.roll(k.heroClass, 5, wielding: old, only: GearSlot.weapon);
    e.state.pendingLoot.add(weapon);
    final coins = k.coins;
    e.equipLoot(weapon.id);
    expect(k.loadout.weapon!.id, weapon.id);
    expect(k.stash.map((g) => g.id), contains(old.id));
    expect(k.coins, coins); // nothing sold
    expect(e.equipFromStash(old.id), isTrue);
    expect(k.loadout.weapon!.id, old.id);
    expect(k.stash.map((g) => g.id), contains(weapon.id));
    expect(e.sellFromStash(weapon.id), weapon.value);
    expect(k.stash, isEmpty);
    // The chest survives a save.
    k.stash.add(weapon);
    expect(GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>).knight.stash.single.id, weapon.id);
  });

  test('a pint at the Soot & Kettle: costs ${GameEngine.pintPrice} gold, one per fight, and saves', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(3));
    final s = e.state, k = s.knight;
    k.coins = 50;
    expect(e.whyNotPint, isNull);
    expect(e.havePint(), isNotEmpty);
    expect(s.pint, isTrue);
    expect(e.whyNotPint, isNotNull);
    expect(e.havePint(), isEmpty);
    expect(GameState.fromJson(s.toJson()).pint, isTrue);
    e.explore();
    fightOut(e);
    expect(s.pint, isFalse);
    k.coins = 1;
    expect(e.whyNotPint, 'Not enough gold');
  });

  group('the wilds', () {
    GameEngine ready() {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5), clock: () => DateTime(2026, 6, 1));
      e.state.knight.level = 8;
      e.state.knight.hp = maxHp(e.state.knight);
      return e;
    }

    test('open once the land\'s boss falls', () {
      final e = ready();
      expect(e.whyNotWild(0), isNotNull);
      expect(e.enterWild(0), isFalse);
      e.state.bossesDown.add(0);
      expect(e.enterWild(0), isTrue);
      expect(e.state.wild, 0);
      expect(e.whyNotWild(1), isNotNull);
    });

    test('a win goes into the pack, not your purse', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterWild(0);
      final coins = e.state.knight.coins;
      while (!e.state.inBattle) {
        e.state.wildEvent = null;
        e.stepWild();
        if (isWaystone(e.state.wildDepth)) e.state.wildDepth++;
      }
      e.state.foeHp = 1;
      final r = e.takeTurn(BattleAction.skill);
      expect(r.kill, isNotNull);
      expect(e.state.knight.coins, coins);
      expect(e.state.packGold, greaterThan(0));
      expect(e.state.pack, isNotEmpty);
      expect(e.state.pendingLoot, isEmpty);
      expect(e.state.wild, 0, reason: 'still out in the wilds');
    });

    test('home from a waystone keeps everything; running loses part of it', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterWild(0);
      final item = e.loot.roll(HeroClass.knight, 8);
      e.state
        ..wildDepth = waystoneEvery
        ..packGold = 100
        ..pack = [item];
      expect(e.leaveShare, 0);
      final coins = e.state.knight.coins;
      final safe = e.leaveWild()!;
      expect(safe.safe, isTrue);
      expect(e.state.knight.coins, coins + 100);
      expect(e.state.pendingLoot.single.id, item.id);
      expect(e.state.wild, isNull);

      e.state.pendingLoot.clear();
      e.enterWild(0);
      e.state
        ..wildDepth = 3
        ..packGold = 100;
      expect(e.leaveShare, fleeLoss);
      final ran = e.leaveWild()!;
      expect(ran.safe, isFalse);
      expect(ran.lost.gold, 40);
      expect(ran.gold, 60);
    });

    test('knocked out in the wilds: scavengers take most of the pack', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterWild(0);
      while (!e.state.inBattle) {
        e.state.wildEvent = null;
        e.stepWild();
      }
      e.state.packGold = 200;
      e.state.knight.hp = 1;
      e.state.foeHp = 99999;
      late SwingResult r;
      do {
        e.state.knight.hp = 1;
        r = e.takeTurn(BattleAction.attack);
      } while (e.state.inBattle);
      expect(r.knockedOut, isTrue);
      expect(r.packLoss!.gold, 150);
      expect(r.wildExit!.gold, 50);
      expect(e.state.wild, isNull);
    });

    test('a trip survives a save', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterWild(0);
      e.state
        ..wildDepth = 7
        ..packGold = 33
        ..wildEvent = WildEvent.chest.name
        ..pack = [e.loot.roll(HeroClass.knight, 8)];
      final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
      expect(back.wild, 0);
      expect(back.wildDepth, 7);
      expect(back.packGold, 33);
      expect(back.pack, hasLength(1));
      expect(back.wildEvent, 'chest');
    });

    test('a few knock-outs on a trail point you at the wilds', () {
      final e = ready()..state.bossesDown.add(0);
      expect(e.wildHint(1), isNull);
      e.state.struggle[1] = struggleHint;
      expect(e.wildHint(1), 0);
    });
  });

  test('relics: each part is a one-off quest in a different land, then the forge at its level', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(21), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight..level = 30;
    k.hp = maxHp(k);
    // No blueprint yet: the guardian's place stays hidden.
    expect(e.placeShown(placeById('emberpit')!), isFalse);
    s.bossesDown.addAll({0, 1, 2, 3, 4});
    expect(e.placeShown(placeById('emberpit')!), isTrue);
    // The guardian of the ember core.
    expect(e.explorePlace('emberpit'), isNull);
    s.foeHp = 1;
    e.takeTurn(BattleAction.skill);
    expect(hasRelicPart(s.relicParts, 0, 1), isTrue);
    expect(e.placeShown(placeById('emberpit')!), isTrue, reason: 'stays on the map, explored');
    // The hilt, at the bottom of the Tomb of Kings.
    e.enterDungeon('kingstomb');
    s.dungeonRoom = dungeonRooms;
    s.dungeonDoors
      ..clear()
      ..add(DoorClue.boss.name);
    e.openDoor(0);
    s.foeHp = 1;
    k.hp = maxHp(k);
    e.takeTurn(BattleAction.skill);
    expect(hasRelicPart(s.relicParts, 0, 2), isTrue);
    e.leaveDungeon();
    // The crown shard: Gorbo, risen.
    s.continent = 0;
    s.heroicWins[0] = heroicStops;
    e.exploreHeroic();
    s.foeHp = 1;
    k.hp = maxHp(k);
    e.takeTurn(BattleAction.skill);
    expect(relicPartsFound(s.relicParts, 0), 3);
    k.coins = 0;
    expect(e.whyNotForge(0), contains('gold'));
    k
      ..coins = 5000
      ..level = 20;
    expect(e.whyNotForge(0), contains('level'));
    k.level = 30;
    expect(e.forgeRelic(0), isNotNull);
  });

  group('dungeons', () {
    GameEngine ready() {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(9), clock: () => DateTime(2026, 6, 1));
      e.state.knight.level = 10;
      e.state.knight.hp = maxHp(e.state.knight);
      return e;
    }

    test('every dungeon\'s foes and boss live in its land', () {
      for (final d in dungeons) {
        for (final look in [...d.foes, d.boss.$2]) {
          expect(realmAt(lookIndex(look, d.land)), d.land, reason: '${d.name}: $look');
        }
      }
    });

    test('open once the land\'s boss falls, and one run at a time', () {
      final e = ready();
      expect(e.whyNotDungeon('warrens'), isNotNull);
      e.state.bossesDown.addAll([0, 1]);
      expect(e.enterDungeon('warrens'), isTrue);
      expect(e.state.dungeonDoors.length, inInclusiveRange(2, 3));
      expect(e.whyNotDungeon('ossuary'), isNotNull);
    });

    test('door by door to the boss, and its hoard', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterDungeon('warrens');
      var guard = 0;
      while (!e.dungeonCleared && guard++ < 200) {
        e.state.knight.hp = maxHp(e.state.knight);
        // Never a locked door without a key.
        final i = e.state.dungeonDoors.indexWhere((d) => d != DoorClue.locked.name || e.state.dungeonKey);
        final out = e.openDoor(i)!;
        if (out.$1.isFight) {
          expect(e.state.inBattle, isTrue);
          expect(e.state.dungeonFight, isTrue);
          e.state.foeHp = 1;
          final r = e.takeTurn(BattleAction.skill);
          expect(r.kill, isNotNull);
          if (out.$1 == RoomKind.boss) expect(r.kill!.hoard, isNotEmpty);
        }
      }
      expect(e.dungeonCleared, isTrue);
      expect(e.state.dungeonsDone, contains('warrens'));
      expect(e.state.dungeonPath.length, dungeonRooms + 1);
      expect(e.state.dungeonPath.last, RoomKind.boss.name);
      expect(e.state.pendingLoot, isNotEmpty);
      expect(e.leaveDungeon(), isTrue);
      expect(e.state.dungeon, isNull);
    });

    test('knocked out ends the run; fleeing bars the door and the run goes on', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterDungeon('warrens');
      e.state.dungeonDoors
        ..clear()
        ..addAll([DoorClue.growl.name, DoorClue.quiet.name]);
      e.openDoor(0);
      expect(e.state.inBattle, isTrue);
      for (var i = 0; i < 40 && e.state.inBattle; i++) {
        e.takeTurn(BattleAction.flee);
      }
      expect(e.state.inBattle, isFalse);
      expect(e.state.dungeon, 'warrens');
      expect(e.state.dungeonRoom, 0);
      expect(e.state.dungeonDoors, [DoorClue.quiet.name]);
      e.state.dungeonDoors
        ..clear()
        ..add(DoorClue.growl.name);
      e.openDoor(0);
      e.state.knight.hp = 1;
      for (var i = 0; i < 40 && e.state.inBattle; i++) {
        e.state.knight.hp = 1;
        e.takeTurn(BattleAction.pet);
      }
      expect(e.state.dungeon, isNull);
    });

    test('a locked door needs a key; a vault spends it', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterDungeon('warrens');
      e.state.dungeonDoors
        ..clear()
        ..add(DoorClue.locked.name);
      expect(e.whyNotDoor(0), isNotNull);
      e.state.dungeonKey = true;
      final coins = e.state.knight.coins;
      final out = e.openDoor(0)!;
      expect(out.$1, RoomKind.vault);
      expect(e.state.dungeonKey, isFalse);
      expect(e.state.knight.coins, greaterThan(coins));
      expect(e.state.pendingLoot, isNotEmpty);
    });

    test('a run in progress survives a save', () {
      final e = ready()..state.bossesDown.add(0);
      e.enterDungeon('warrens');
      e.state.dungeonKey = true;
      e.state.dungeonsDone.add('ossuary');
      final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
      expect(back.dungeon, 'warrens');
      expect(back.dungeonDoors, e.state.dungeonDoors);
      expect(back.dungeonKey, isTrue);
      expect(back.dungeonsDone, {'ossuary'});
    });
  });
}
