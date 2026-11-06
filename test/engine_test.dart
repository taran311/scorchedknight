// Rules checks: fights, bosses, companions, the shop and saving. Run: flutter test

import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scorchedknight/game/arena.dart';
import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/ammo.dart';
import 'package:scorchedknight/game/brews.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/encounters.dart';
import 'package:scorchedknight/game/enchants.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/tasks.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/mounts.dart';
import 'package:scorchedknight/game/rules.dart';
import 'package:scorchedknight/game/tarot.dart';
import 'package:scorchedknight/game/vault.dart';
import 'package:scorchedknight/game/wilds.dart';
import 'package:scorchedknight/game/dungeons.dart';
import 'package:scorchedknight/game/hall.dart';
import 'package:scorchedknight/game/nemesis.dart';
import 'package:scorchedknight/game/contracts.dart';
import 'package:scorchedknight/game/errands.dart';
import 'package:scorchedknight/game/knight_classes.dart';
import 'package:scorchedknight/game/spells.dart';

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

  test('before a boss, a weapon in the chest that suits it better is pointed out', () {
    final k = GameEngine.newGame(heroClass: HeroClass.knight).knight;
    k.loadout.weapon = GearItem(id: 'venom', name: 'Venom blade', slot: GearSlot.weapon, art: 'longsword', rarity: Rarity.rare, level: 10, value: 5, heroClass: HeroClass.knight, stats: {Stat.damage: 30, Stat.poison: 14});
    final fire = GearItem(id: 'fire', name: 'Fire blade', slot: GearSlot.weapon, art: 'longsword', rarity: Rarity.rare, level: 10, value: 5, heroClass: HeroClass.knight, stats: {Stat.damage: 30, Stat.burn: 14});
    k.stash.add(fire);
    final ent = foes.firstWhere((f) => f.ent && f.boss);
    final tip = betterWeaponFor(k, ent);
    expect(tip?.item.id, 'fire');
    expect(tip?.why, 'Weak to fire');
    // Against a foe that cares for neither, no tip: they hit it the same.
    final plain = foes.firstWhere((f) => !f.ent && !f.demon && !f.venomous && f.element == null && !f.stone && !f.undead && f.boss);
    expect(betterWeaponFor(k, plain), isNull);
  });

  test('no foe is both weak to and resistant to the same thing', () {
    final rares = [for (final a in Aura.values) for (var i = 0; i < foes.length; i++) Rare(i, a).type];
    for (final f in [...foes, ...rares]) {
      final (weak, shrug) = foeEdges(f);
      expect(weak.toSet().intersection(shrug.toSet()), isEmpty, reason: f.name);
    }
  });

  test('a foe well above you is tough, then deadly; a boss never counts', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    e.explore();
    final s = e.state;
    s.foeLevel = s.knight.level;
    expect(foeMenace(s), 0);
    s.foeLevel = s.knight.level + 3;
    expect(foeMenace(s), foeIn(s).boss ? 0 : 1);
    s.foeLevel = s.knight.level + 6;
    expect(foeMenace(s), foeIn(s).boss ? 0 : 2);
  });

  test('a strongbox turns up every $chestEvery wins, and its die decides: ambush, gold or gear', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(4));
    final s = e.state;
    var seen = 0;
    for (var i = 0; i < 200 && s.wins[0] < chestEvery * 2; i++) {
      s.knight.hp = maxHp(s.knight);
      e.explore();
      fightOut(e);
      if (s.encounter == 'chest') {
        seen++;
        s.encounter = null;
      } else {
        s.encounter = null;
      }
    }
    expect(seen, 2);
    // Roll it many times: every kind of outcome comes up, and an ambush is a real fight.
    final kinds = <String>{};
    for (var i = 0; i < 300 && kinds.length < 3; i++) {
      if (s.inBattle) fightOut(e);
      s.pendingLoot.clear();
      s.encounter = 'chest';
      final loot0 = s.pendingLoot.length;
      e.resolveEncounter(0);
      final roll = s.lastRoll!;
      if (roll <= chestAmbush) {
        expect(s.inBattle, isTrue);
        expect(s.foeLevel, greaterThanOrEqualTo(s.knight.level + chestAmbushLevels));
        kinds.add('ambush');
      } else if (roll >= chestGear) {
        expect(s.pendingLoot.length, loot0 + 1);
        kinds.add('gear');
      } else {
        kinds.add('gold');
      }
    }
    expect(kinds, {'ambush', 'gold', 'gear'});
  });

  test('Old Wick moves a rune off a stashed weapon onto the one in your hand, for a fee', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final k = e.state.knight;
    for (var i = 0; i < 200; i++) {
      final g = e.loot.roll(k.heroClass, k.level, odds: const [0, 0, 100, 0, 0]);
      if (g.slot == GearSlot.weapon) {
        k.stash.add(g..enchant = const EnchantRoll('flametongue', 2, 9));
        break;
      }
    }
    final spare = e.runedSpares.single;
    k.coins = 0;
    expect(e.whyNotMoveRune(spare), 'Not enough gold');
    k.coins = 1000;
    expect(e.moveRune(spare), isTrue);
    expect(k.coins, 1000 - e.runeMoveCost);
    expect(spare.enchant, isNull);
    expect(k.loadout.weapon!.enchant!.id, 'flametongue');
    expect(e.runedSpares, isEmpty);
  });

  test('Mags\' find of the day: one piece, the same all day, bought once, new tomorrow', () {
    var now = DateTime(2026, 10, 30, 21, 0);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(8), clock: () => now);
    final s = e.state, k = s.knight;
    final today = e.dailyDeal;
    expect(today.special, isNull);
    now = DateTime(2026, 10, 30, 23, 59);
    expect(identical(e.dailyDeal, today), isTrue);
    expect(e.untilNextDeal.inMinutes, 1);
    k.coins = 0;
    expect(e.whyNotDeal, 'Not enough gold');
    k.coins = 100000;
    final price = e.dealPrice;
    expect(e.buyDeal(), isTrue);
    expect(k.coins, 100000 - price);
    expect(s.pendingLoot.last.id, today.id);
    expect(e.buyDeal(), isFalse);
    // It saves.
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.deal!.id, today.id);
    expect(back.dealBought, isTrue);
    now = DateTime(2026, 10, 31, 0, 1);
    expect(e.dailyDeal.id, isNot(today.id));
    expect(e.whyNotDeal, isNull);
  });

  test('Cinder keys drop now and then, and the Ember Vault gives out all six of its pieces in time', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(11));
    final s = e.state, k = s.knight;
    // Keys turn up from ordinary fights.
    for (var i = 0; i < 300 && s.keys == 0; i++) {
      k.hp = maxHp(k);
      e.explore();
      // (Won fights: a starting knight in starting kit soon stops winning them.)
      s.foeHp = math.min(s.foeHp, 1);
      fightOut(e);
      s.encounter = null;
      s.pendingLoot.clear();
      s.nemesis = null;
    }
    expect(s.keys, greaterThan(0));
    expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).keys, s.keys);
    // A trip into the wilds is no bar to it (you're in town).
    s.keys = 1;
    s.wild = 0;
    expect(e.whyNotVault, isNull);
    s.wild = null;
    // No key, no door.
    s.keys = 0;
    expect(e.whyNotVault, isNotNull);
    expect(e.openVault(), isNull);
    // Low down, the vault keeps most of its pieces back however many keys you bring.
    s.keys = 40;
    k.level = 7;
    final kinds = <String>{};
    for (var i = 0; i < 40; i++) {
      final f = e.openVault()!;
      kinds.add(f.piece ? 'piece' : (f.item != null ? 'gear' : 'gold'));
      s.pendingLoot.clear();
    }
    expect(s.vaultFound.length, vaultPiecesOpen(7));
    expect(nextVaultPieceLevel(s.vaultFound.length, 7), 13);
    // Plenty of keys, high enough: every piece, each found once before any repeats.
    s.keys = 400;
    k.level = 40;
    for (var i = 0; i < 400 && s.vaultFound.length < vaultPieces.length; i++) {
      final f = e.openVault()!;
      expect(f.gold, greaterThan(0));
      kinds.add(f.piece ? 'piece' : (f.item != null ? 'gear' : 'gold'));
      if (f.piece) expect(vaultPieceNamed(f.item!.name), isNotNull);
      s.pendingLoot.clear();
    }
    expect(s.vaultFound.toSet(), {for (final p in vaultPieces) p.name});
    expect(kinds, {'piece', 'gear', 'gold'});
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.vaultFound.length, vaultPieces.length);
  });

  test('somewhere to explore: an open place or dungeon, unguarded first, never the road\'s own', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final s = e.state;
    s.knight.level = 7;
    s.innRepaired = true;
    s.bossesDown.add(0);
    final seen = <String>{};
    for (var i = 0; i < 40; i++) {
      final step = e.exploreStep();
      if (step == null || step.kind == RoadKind.wild) break;
      expect(step.id, isNot(e.roadStep()?.id));
      expect(seen.add(step.id!), isTrue, reason: 'offered ${step.id} twice');
      if (step.kind == RoadKind.place) {
        s.explored.add(step.id!);
      } else {
        s.dungeonsDone.add(step.id!);
      }
    }
    expect(seen, isNotEmpty);
    // Every place and dungeon done: the wilds, once they're open.
    if (List.generate(wildAreas.length, e.wildOpen).any((o) => o)) expect(e.exploreStep()?.kind, RoadKind.wild);
  });

  test('contracts: every guarded place is someone\'s trouble, on the board, and pays a bounty', () {
    for (final p in places.where((p) => p.foe != null && p.relic == null)) {
      expect(contractFor(p.id), isNotNull, reason: p.id);
    }
    for (final c in contracts) {
      expect(placeById(c.place)?.foe, isNotNull, reason: c.place);
    }
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final s = e.state, k = s.knight..level = 8;
    s.innRepaired = true;
    final board = e.board;
    expect(board, isNotEmpty);
    expect(board.length, lessThanOrEqualTo(boardSize));
    final job = board.first;
    expect(e.explorePlace(job.place), isNull);
    final gold = k.coins;
    k.hp = maxHp(k);
    s.foeHp = 1;
    while (s.inBattle) {
      e.takeTurn(BattleAction.attack);
      s.foeHp = math.min(s.foeHp, 1);
    }
    expect(s.explored, contains(job.place));
    expect(k.coins - gold, greaterThanOrEqualTo(contractBounty(k.level)));
    expect(e.board.map((c) => c.place), isNot(contains(job.place)));
  });

  test('the Ember King\'s generals: each one felled leaves him weaker', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state, k = s.knight..level = 40;
    s.innRepaired = true;
    s.unlocked = mainLands - 1;
    for (var c = 0; c < mainLands - 1; c++) {
      s.bossesDown.add(c);
    }
    // (The Ember Throne's seals: half the side lands' lords down.)
    s.bossesDown.addAll([for (var i = 0; i < throneSeals; i++) mainLands + i]);
    e.travel(mainLands - 1);
    s.wins[mainLands - 1] = winsForBoss;
    expect(e.challengeBoss(), isTrue);
    final full = s.foeMax;
    e.takeTurn(BattleAction.flee);
    while (s.inBattle) {
      e.takeTurn(BattleAction.flee);
    }
    // Generals come for you on the Throne's road; fell them all.
    for (var i = 0; i < 400 && s.generalsDown.length < emberGenerals.length; i++) {
      e.explore();
      if (emberGenerals.contains(s.rare?.name)) {
        k.hp = maxHp(k);
        s.foeHp = 1;
        while (s.inBattle) {
          e.takeTurn(BattleAction.attack);
          s.foeHp = math.min(s.foeHp, 1);
        }
      } else {
        while (s.inBattle) {
          e.takeTurn(BattleAction.flee);
        }
      }
      if (s.encounter != null) e.resolveEncounter(0);
      s.pendingLoot.clear();
      s.nemesis = null;
    }
    expect(s.generalsDown, emberGenerals.toSet());
    expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).generalsDown, s.generalsDown);
    k.level = 40;
    expect(e.challengeBoss(), isTrue);
    expect(s.foeMax, lessThan(full * (1 - generalCut * 3) + 2));
  });

  test('a nemesis: the foe that beat you takes a name, grows, hunts you, and pays when it falls', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(11));
    final s = e.state, k = s.knight..level = 12;
    s.innRepaired = true;
    s.unlocked = 2;
    s.bossesDown.addAll([0, 1]);
    e.travel(1);
    void lose() {
      while (s.inBattle) {
        k.hp = 1;
        k.potions = 0;
        s.foeAsleep = 0;
        s.foeFrozen = false;
        s.foeHp = s.foeMax;
        e.takeTurn(BattleAction.attack);
      }
    }
    // Beaten by a common foe: it becomes your nemesis.
    while (s.rare != null || !s.inBattle) {
      if (s.inBattle) e.takeTurn(BattleAction.flee);
      if (!s.inBattle) e.explore();
    }
    final look = foeIn(s).look;
    lose();
    final n = s.nemesis!;
    expect(n.look, look);
    expect(n.rank, 1);
    expect(s.toJson()['nemesis'], isNotNull);
    expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).nemesis!.name, n.name);
    // It waits a few fights, then finds you.
    var met = 0;
    for (var i = 0; i < 200 && !e.nemesisFight; i++) {
      e.explore();
      if (!e.nemesisFight) e.takeTurn(BattleAction.flee);
      met = i;
    }
    expect(e.nemesisFight, isTrue);
    expect(met, greaterThanOrEqualTo(nemesisWait - 1));
    expect(foeIn(s).name, n.name);
    // It wins again: stronger.
    lose();
    expect(s.nemesis!.rank, 2);
    // Beaten at last: gone, with its hoard.
    s.nemesis!.since = nemesisWait;
    while (!e.nemesisFight) {
      if (!s.inBattle) e.explore();
      if (!e.nemesisFight) e.takeTurn(BattleAction.flee);
    }
    final loot = s.pendingLoot.length, gold = k.coins;
    k.hp = maxHp(k);
    s.foeHp = 1;
    while (s.inBattle) {
      e.takeTurn(BattleAction.attack);
      s.foeHp = math.min(s.foeHp, 1);
    }
    expect(s.nemesis, isNull);
    expect(s.nemesesSlain, 1);
    expect(s.pendingLoot.length, greaterThan(loot));
    expect(s.pendingLoot.last.rarity, Rarity.epic);
    expect(k.coins, greaterThan(gold));
  });

  test('the Hall of the Slain: waves in a row, war cries, the War Cry rite and Gungnir', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(6));
    final s = e.state, k = s.knight..level = 34;
    expect(e.whyNotHall(), isNotNull);
    s.unlocked = 5;
    for (var c = 0; c < 4; c++) {
      s.bossesDown.add(c);
    }
    expect(e.whyNotHall(), isNull);
    void win() {
      s.foeHp = 1;
      k.hp = maxHp(k);
      while (s.inBattle) {
        e.takeTurn(BattleAction.attack);
        s.foeHp = math.min(s.foeHp, 1);
      }
    }
    // A wave half-won, then walked out of: it starts over.
    expect(e.startHallFight()!.warcry, isTrue);
    win();
    expect(s.hallStep, 1);
    e.abandonHallWave();
    expect(s.hallStep, 0);
    // A warrior roars on its second turn: its blows harder, yours softer.
    e.startHallFight();
    s.foeHp = s.foeMax = 999999;
    k.hp = maxHp(k);
    var roared = false;
    for (var t = 0; t < 3 && !roared; t++) {
      roared = e.takeTurn(BattleAction.attack).roared;
    }
    expect(roared, isTrue);
    expect(s.foeRoar, greaterThan(0));
    expect(s.heroCowed, greaterThan(0));
    final cowed = nextBlow(s);
    s.foeRoar = 0;
    expect(nextBlow(s), lessThan(cowed));
    // Knocked out mid-wave: back to the start of it.
    k.hp = 1;
    s.foeWindup = false;
    while (s.inBattle) {
      k.hp = 1;
      e.takeTurn(BattleAction.attack);
    }
    expect(s.hallStep, 0);
    // All three waves: the War Cry after the second, Gungnir from the Thane.
    for (var w = 0; w < hallWaves.length; w++) {
      for (var i = 0; i < hallWaves[w].warriors.length; i++) {
        expect(e.startHallFight()!.name, hallWaves[w].warriors[i].name);
        win();
      }
      expect(s.hallWaves, w + 1);
      if (w == 1) expect(k.earnedRites, contains('warcry'));
    }
    expect(e.hallDone, isTrue);
    expect(riteKnown(k, spellById('warcry')!), isTrue);
    expect(s.pendingLoot.where((g) => g.name == 'Gungnir'), hasLength(1));
    expect(isKeepsake(s.pendingLoot.firstWhere((g) => g.name == 'Gungnir')), isTrue);
    // The War Cry drowns out the foe's.
    s.pendingLoot.clear();
    e.startHallFight();
    s.foeHp = s.foeMax = 999999;
    s.foeRoar = 3;
    s.heroCowed = 3;
    s.mana = 9;
    k.preparedSpell = 'warcry';
    k.hp = maxHp(k);
    s.foeAsleep = 2; // (so its blow can't end the fight first)
    e.takeTurn(BattleAction.cast);
    expect(s.heroRoar, greaterThan(0));
    expect(s.heroCowed, 0);
    final back = GameState.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, dynamic>());
    expect(back.hallWaves, hallWaves.length);
    expect(back.knight.earnedRites, contains('warcry'));
  });

  test('the Ash Colosseum: seven bouts in order, the Champion\'s set along the way', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight..level = 30;
    // Shut until the Sunken Sands are open.
    expect(e.whyNotArena(), isNotNull);
    s.unlocked = arenaLand;
    for (var c = 0; c < arenaLand; c++) {
      s.bossesDown.add(c);
    }
    expect(e.whyNotArena(), isNull);
    final won = <GearItem>[];
    for (var i = 0; i < arenaBouts.length; i++) {
      final f = e.startArenaBout()!;
      expect(f.name, arenaBouts[i].name);
      expect(s.arenaFight, isTrue);
      s.foeHp = 1;
      k.hp = maxHp(k);
      while (s.inBattle) {
        e.takeTurn(BattleAction.attack);
        s.foeHp = math.min(s.foeHp, 1);
      }
      expect(s.arenaFight, isFalse);
      expect(s.arenaWins, i + 1);
      won.addAll(s.pendingLoot.where((g) => g.gearSet == arenaSet));
      s.pendingLoot.clear();
    }
    expect(e.arenaDone, isTrue);
    // The whole suit: manica, greaves, signet, galea and lorica, none of them sellable.
    expect({for (final g in won) g.slot}, {GearSlot.gloves, GearSlot.boots, GearSlot.ring, GearSlot.helm, GearSlot.armour});
    expect(won.every(isKeepsake), isTrue);
    // Afterwards the Champion takes you on again, with no second suit.
    expect(e.startArenaBout()!.name, arenaBouts.last.name);
    expect(s.arenaWins, arenaBouts.length);
    // It survives saving.
    final back = GameState.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, dynamic>());
    expect(back.arenaWins, arenaBouts.length);
    expect(back.arenaFight, isTrue);
  });

  test('gold sinks: Mags\' sealed crates and Dunstan\'s honing', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(9));
    final k = e.state.knight
      ..level = 30
      ..coins = 100000;
    // A crate: paid for, rare or finer, the slot you asked for, into your spoils.
    e.state.innRepaired = true;
    for (var i = 0; i < 20; i++) {
      // (Mags has a few a day: sleep through the night for more.)
      if (e.state.cratesToday >= cratesPerDay) {
        expect(e.whyNotCrate(), isNotNull);
        e.state.day = false;
        e.rest();
      }
      final g = e.buyCrate(GearSlot.helm)!;
      expect(g.slot, GearSlot.helm);
      expect(g.rarity.index, greaterThanOrEqualTo(Rarity.rare.index));
    }
    expect(k.coins, 100000 - 20 * crateCost(30));
    expect(e.state.pendingLoot.length, 20);
    // Honing: every stat up, dearer each step, five steps at most, and it survives a save.
    final g = e.loot.roll(HeroClass.knight, 30, odds: const [0, 0, 0, 1, 0], only: GearSlot.weapon);
    k.loadout.weapon = g;
    final before = Map.of(g.stats), first = honeCost(g, 30);
    expect(e.hone(g), isTrue);
    for (final s in before.keys) {
      expect(g.stats[s]!, greaterThan(before[s]!));
    }
    expect(honeCost(g, 30), greaterThan(first));
    while (e.hone(g)) {}
    expect(g.hone, honeMax);
    expect(e.whyNotHone(g), isNotNull);
    final back = GearItem.fromJson((jsonDecode(jsonEncode(g.toJson())) as Map).cast<String, dynamic>());
    expect(back.hone, honeMax);
    expect(back.stats, g.stats);
    expect(tempered(g, 35).hone, honeMax);
  });

  test('a vault piece is strong, but never stronger than a legendary of its level', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    for (final p in vaultPieces) {
      var piece = 0.0, legend = 0.0;
      for (var i = 0; i < 40; i++) {
        piece += e.loot.vaultPiece(p, 40).score;
        legend += e.loot.roll(HeroClass.knight, 40, odds: const [0, 0, 0, 0, 1], only: p.slot).score;
      }
      expect(piece, lessThanOrEqualTo(legend * 1.05), reason: p.name);
    }
  });

  test('the Guardian\'s Oath: all six found, the first heavy blow each fight meets your shield', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(5));
    final s = e.state, k = s.knight;
    for (var i = 0; i < 20 && !s.inBattle; i++) {
      e.explore();
    }
    expect(s.inBattle, isTrue);
    // Not sworn: a heavy blow is just a heavy blow.
    s.foeHp = s.foeMax = 99999;
    s.foeWindup = true;
    expect(e.takeTurn(BattleAction.attack).oath, isFalse);
    // Sworn: the next heavy blow is caught, whole.
    s.vaultFound
      ..clear()
      ..addAll([for (final p in vaultPieces) p.name]);
    // (A dodge or a parry doesn't spend it: it waits for a heavy blow that gets through.)
    SwingResult? caught;
    for (var i = 0; i < 30 && caught == null; i++) {
      k.hp = maxHp(k);
      s.foeWindup = true;
      final r = e.takeTurn(BattleAction.attack);
      if (r.oath) caught = r;
    }
    expect(caught, isNotNull);
    expect(caught!.heavy, isFalse, reason: 'it lands as an ordinary blow');
    expect(caught.counter, greaterThan(0));
    // Once a fight.
    for (var i = 0; i < 10; i++) {
      k.hp = maxHp(k);
      s.foeWindup = true;
      expect(e.takeTurn(BattleAction.attack).oath, isFalse);
    }
    expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).oathUsed, isTrue);
  });

  test('a clean kill: a crossbow bolt that fells the foe pays a bounty, and the special bolt comes back', () {
    // (Seeds where the shot lands: a bolt can miss.)
    var cleanSeen = false;
    for (var seed = 0; seed < 40 && !cleanSeen; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(seed));
      final s = e.state, k = s.knight;
      for (var i = 0; i < 20 && !s.inBattle; i++) {
        e.explore();
      }
      if (!s.inBattle || e.whyNot(BattleAction.shoot) != null) continue;
      k.ammo[AmmoType.fire.name] = 2;
      k.ammoLoaded = AmmoType.fire.name;
      s.foeHp = 1;
      final r = e.takeTurn(BattleAction.shoot);
      if (r.miss) continue;
      final kill = r.kill!;
      expect(kill.clean, isTrue);
      expect(kill.bounty, greaterThan(0));
      expect(kill.boltBack, AmmoType.fire);
      expect(k.ammo[AmmoType.fire.name], 2, reason: 'the bolt it was shot with came back');
      cleanSeen = true;
    }
    expect(cleanSeen, isTrue);
    // A blade's finishing blow is no clean kill.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(9));
    for (var i = 0; i < 20 && !e.state.inBattle; i++) {
      e.explore();
    }
    e.state.foeHp = 1;
    final r = e.takeTurn(BattleAction.skill);
    expect(r.kill?.clean ?? false, isFalse);
  });

  test('a brew already at full strength can\'t be topped up (no reagents wasted)', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    final s = e.state, k = s.knight;
    s.reagents[Brew.might.land] = 10;
    k.coins = 1000;
    expect(e.brew(Brew.might), isTrue);
    expect(k.brews[Brew.might.name], brewFights);
    expect(e.whyNotBrew(Brew.might), isNotNull);
    expect(e.brew(Brew.might), isFalse);
    expect(s.reagents[Brew.might.land], 10 - Brew.might.reagents);
    // One fight later, a top-up is worth it again.
    k.brews[Brew.might.name] = brewFights - 1;
    expect(e.whyNotBrew(Brew.might), isNull);
  });

  test('a region is cleared once its boss is beaten, then beaten again risen (places and dungeons around it count on their own)', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    final s = e.state;
    const land = 1;
    expect(e.landCleared(land), isFalse);
    expect(e.landLeft(land), isNotEmpty);
    s.bossesDown.add(land);
    expect(e.landCleared(land), isFalse);
    expect(e.landLeft(land).single, contains('risen'));
    s.risenDown.add(land);
    expect(e.landCleared(land), isTrue, reason: 'unexplored places and dungeons around it don\'t hold it back');
    expect(e.landLeft(land), isEmpty);
    expect(e.heroicCleared(land), isTrue);
    expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).risenDown, contains(land));
    expect(e.landCleared(0), isFalse);
  });

  test('vault pieces grow with you: a level gained brings every one you own up to it', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight;
    final crown = e.loot.vaultPiece(vaultPieceNamed('Cinder Crown')!, k.level);
    final charm = e.loot.vaultPiece(vaultPieceNamed('Brimstone Charm')!, k.level);
    final plain = e.loot.roll(HeroClass.knight, k.level, odds: const [0, 0, 0, 0, 1], only: GearSlot.boots);
    k.loadout.helm = crown;
    k.loadout.boots = plain;
    k.stash.add(charm);
    final before = crown.stats[Stat.vigour]!;
    while (k.level < 12) {
      e.grantXp(xpToNext(k));
    }
    expect(k.loadout.helm!.level, k.level);
    expect(k.loadout.helm!.stats[Stat.vigour], greaterThan(before));
    expect(k.loadout.helm!.gearSet, 'vault');
    expect(k.stash.single.level, k.level);
    expect(k.loadout.boots!.level, plain.level, reason: 'ordinary gear doesn\'t grow');
  });

  test('dragon lairs: one per kind of dragon, each always leaves its wyrmscale', () {
    final lairs = [for (final p in places) if (p.wyrm != null) p];
    expect([for (final p in lairs) p.wyrm]..sort(), [1, 2, 3, 4, 5]);
    for (final p in lairs) {
      final f = Rare(lookIndex(p.foe!.$1, p.land), p.foe!.$3, name: p.foe!.$4, look: p.foe!.$2).type;
      expect(f.dragon, isTrue, reason: p.name);
      expect(wyrmTierFor(f.look)!.tier, p.wyrm, reason: p.name);
    }
    final rime = Rare(lookIndex('yeti', 18), Aura.frost, name: 'Grandfather Rime', look: rimeWyrmLook).type;
    expect(rime.element, 'frost');
    expect(elementEdgeOn(rime, 'burn'), greaterThan(1));
    // Explored and won: the wyrmscale is in the spoils.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final s = e.state;
    s.knight.level = 40;
    s.bossesDown.addAll({for (var c = 0; c < continents.length; c++) c});
    s.unlocked = continents.length - 1;
    s.day = false;
    expect(e.whyNotExplore('rimehollow'), isNull);
    e.explorePlace('rimehollow');
    s.foeHp = 1;
    var guard = 0;
    while (s.inBattle && guard++ < 50) {
      s.foeHp = 1;
      e.takeTurn(BattleAction.attack);
    }
    expect(s.explored, contains('rimehollow'));
    expect(s.pendingLoot.any((g) => g.name.startsWith('Rimescale')), isTrue);
  });

  test('the Dragon Knight: a Drakesworn knight in the dragons\' lands, sometimes in wyrmscale you can take', () {
    final f = Rare(lookIndex('ashenKnight', 5), Aura.blazing, look: dragonKnightLook).type;
    expect(f.look, dragonKnightLook);
    expect(f.armoured, isTrue);
    expect([for (final c in [5, 6]) continents[c].named.where((n) => n.look == dragonKnightLook).length], [1, 1]);
    // Met over and over in the Cinderreach, he turns up as a rare Ashen Knight now and then.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state;
    s.knight.level = 35;
    s.bossesDown.addAll({0, 1, 2, 3, 4});
    s.unlocked = 5;
    var met = 0;
    for (var i = 0; i < 3000 && met == 0; i++) {
      s.continent = 5;
      e.explore();
      if (s.rare?.look == dragonKnightLook) met++;
      s.inBattle = false;
      s.rare = null;
    }
    expect(met, 1);
  });

  test('the Drakesworn set: dragons and Dragon Knights leave its scale and blueprints; all three turn fire', () {
    expect(trophyLooks[dragonKnightLook], Trophy.dragonscale);
    expect(forgedSetFor(Trophy.dragonscale).id, 'drakesworn');
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(6));
    final s = e.state, k = s.knight;
    k.level = 40;
    s
      ..inBattle = true
      ..foe = lookIndex('pitdemon', 5)
      ..foeLevel = 40;
    final before = counterDamage(s);
    for (final slot in setPieceSlots) {
      final g = e.loot.setPiece('drakesworn', slot, k.heroClass, k.level);
      switch (slot) {
        case GearSlot.armour:
          k.loadout.armour = g.art;
        case GearSlot.ring:
          k.ring = g;
        default:
          k.loadout.put(g);
      }
    }
    // A full suit: helm, plate, gauntlets, sabatons and signet.
    expect(activeSets(k.setGear).any((x) => x.$1.id == 'drakesworn' && x.$2 == 5), isTrue);
    expect(armourTierById(k.loadout.armour).name, 'Drakesworn plate');
    // Guard from the set softens every blow a little; fire is cut by dragonhide on top.
    expect(counterDamage(s), lessThan(before * .75));
    s.foe = lookIndex('ashenKnight', 5);
    expect(counterDamage(s), greaterThan(counterDamage(s..foe = lookIndex('pitdemon', 5))));
  });

  test('a whole suit: the attack and the bash become the order\'s own, with a signature', () {
    GameEngine suited(String set, int seed) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      final k = e.state.knight..level = 40;
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
      k.hp = maxHp(k);
      return e;
    }

    final e = suited('drakesworn', 8);
    final s = e.state, k = s.knight;
    expect(suitWorn(k), 'drakesworn');
    expect(skillName(k), 'Dragon\'s Breath');
    expect(attackName(k), 'Wyrm Cut');
    s
      ..inBattle = true
      ..foe = lookIndex('ashenKnight', 5)
      ..foeLevel = 40
      ..foeHp = 1 << 20
      ..foeMax = 1 << 20;
    final r = e.takeTurn(BattleAction.skill);
    expect(r.art, 'BREATH');
    expect(r.artHit, greaterThan(0));
    // Four pieces: the bonus and its perk, but not the suit's arts.
    k.ring = null;
    expect(suitWorn(k), isNull);
    expect(skillName(k), isNot('Dragon\'s Breath'));
    // The Deepforge suit's Anvil Strike stuns bosses every time; the Bushido's draw always crits.
    final d = suited('deepforge', 9), ds = d.state;
    for (var i = 0; i < 6; i++) {
      ds
        ..inBattle = true
        ..foe = foeIndexes(3).last + 1
        ..foeLevel = 40
        ..foeHp = 1 << 20
        ..foeMax = 1 << 20
        ..skillWait = 0;
      expect(foeIn(ds).boss, isTrue);
      expect(d.takeTurn(BattleAction.skill).stunned, isTrue);
    }
    final b = suited('bushido', 10), bs = b.state;
    bs
      ..inBattle = true
      ..foe = lookIndex('ronin', 16)
      ..foeLevel = 40
      ..foeHp = 1 << 20
      ..foeMax = 1 << 20;
    expect(b.takeTurn(BattleAction.skill).damage.crit, isTrue);
  });

  test('tasks: done straight from the save, claimed once, easiest first, rewards kept small', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final s = e.state, k = s.knight;
    expect(e.nextTask!.id, 'win');
    expect(e.claimTask('win'), isNull, reason: 'not done yet');
    s.foesFelled = 1;
    final coins = k.coins;
    expect(e.claimTask('win'), isNotNull);
    expect(k.coins, coins + 25);
    expect(e.claimTask('win'), isNull, reason: 'once only');
    // A first the save can't show by itself is marked.
    expect(taskById('brew')!.done(s), isFalse);
    e.mark('brew');
    expect(taskById('brew')!.done(s), isTrue);
    // The next one shown is a done one waiting to be claimed, before any still to do.
    expect(e.nextTask!.id, 'brew');
    // Saved and loaded.
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.tasksClaimed, contains('win'));
    expect(back.did, contains('brew'));
    // All of them together: a small share of a game's ~70k gold, and a couple of levels of XP.
    final gold = gameTasks.fold<int>(0, (n, t) => n + t.reward.gold);
    final xp = gameTasks.fold<double>(0, (n, t) => n + t.reward.xp);
    expect(gold, lessThan(7000));
    expect(xp, lessThan(3.5));
    expect(gameTasks.map((t) => t.id).toSet().length, gameTasks.length);
  });

  test('region tasks: claimable once a region is cleared, never shown as next before', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final s = e.state;
    expect(regionTasks.length, continents.length);
    expect(e.nextTask!.land, isNull, reason: 'the main tasks lead');
    s.bossesDown.add(0);
    s.risenDown.add(0);
    for (final p in places.where((p) => p.land == 0)) {
      s.explored.add(p.id);
    }
    for (final d in dungeons.where((d) => d.land == 0)) {
      s.dungeonsDone.add(d.id);
    }
    for (final (r, _) in relicPartsOn(0)) {
      s.forged.add(r);
    }
    expect(e.landCleared(0), isTrue);
    expect(e.taskDone(taskById('clear:0')!), isTrue);
    final keys = s.keys;
    expect(e.claimTask('clear:0'), isNotNull);
    expect(s.keys, keys + 1);
    expect(e.claimTask('clear:0'), isNull);
    expect(e.claimTask('clear:1'), isNull, reason: 'not cleared');
    expect(suitTasks.length, suitArts.length);
    expect(taskById('suit:ashen')!.done(s), isFalse);
    e.mark('suit:ashen');
    expect(taskById('suit:ashen')!.done(s), isTrue, reason: 'worn once is enough');
    final gold = regionTasks.fold<int>(0, (n, t) => n + t.reward.gold);
    expect(gold, lessThan(6000));
  });

  test('combat feats: earned in the fight, told once, then claimable', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state;
    for (var i = 0; i < 20 && !s.inBattle; i++) {
      e.explore();
    }
    expect(s.inBattle, isTrue);
    // One blow finishes it, before it can hit back: untouched and swift.
    s.foeHp = 1;
    e.takeTurn(BattleAction.attack);
    expect(s.inBattle, isFalse);
    expect(s.did, containsAll(['feat:untouched', 'feat:swift']));
    expect(e.taskDone(taskById('feat:untouched')!), isTrue);
    expect(e.taskDone(taskById('feat:flawless')!), isFalse, reason: 'not a boss');
    expect(e.claimTask('feat:untouched'), isNotNull);
    expect(featTasks.map((t) => t.id).toSet().length, featTasks.length);
    final gold = featTasks.fold<int>(0, (n, t) => n + t.reward.gold);
    expect(gold, lessThan(15000));
  });

  test('Wren: errands from the cottage, paid up front, back after a few fights with finds', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final s = e.state, k = s.knight;
    k.coins = 5000;
    expect(e.whyNotErrand('fields'), isNotNull, reason: 'no cottage yet');
    s.home = 1;
    expect(e.whyNotErrand('ruins'), isNotNull, reason: 'the ruins wait for the keep');
    expect(e.sendErrand('fields'), isTrue);
    expect(k.coins, 5000 - errandById('fields')!.feeAt(k.level));
    expect(e.whyNotErrand('wilds'), isNotNull, reason: 'one errand at a time');
    expect(e.errandBack, isFalse);
    expect(e.collectErrand(), isEmpty);
    s.foesFelled += errandById('fields')!.fights;
    expect(e.errandBack, isTrue);
    final timber = s.timber;
    expect(e.collectErrand(), isNotEmpty);
    expect(s.timber, greaterThan(timber));
    expect(s.errand, isNull);
    expect(s.did, contains('errand'));
    // Saved mid-errand and loaded.
    e.sendErrand('wilds');
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.errand, 'wilds');
    expect(back.errandAt, s.errandAt);
  });

  test('the stable: the Hellsteed needs level 28 and two Ember cores as well as gold', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final s = e.state, k = s.knight;
    k.coins = 99999;
    expect(e.purchase('mount:hellsteed'), isFalse);
    k.level = 28;
    expect(e.whyNotBuy('mount:hellsteed'), contains('Ember cores'));
    s.addMat(coreKey(Elemental.ember), 2);
    expect(e.purchase('mount:hellsteed'), isTrue);
    expect(s.mat(coreKey(Elemental.ember)), 0);
    expect(k.mount, 'hellsteed');
  });

  test('the road: the next boss, or while its land waits on a level, something to do meanwhile', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight;
    expect(e.roadStep()!.kind, RoadKind.boss);
    expect(e.roadStep()!.land, 0);
    s.bossesDown.add(0);
    k.level = continents[1].minLevel - 1;
    final step = e.roadStep()!;
    expect(step.kind, isNot(RoadKind.boss), reason: 'the Gloomfen waits on a level');
    expect(step.sub, contains('Level ${continents[1].minLevel}'));
    // With nothing left to explore or delve, at worst: grow stronger.
    s.explored.addAll(places.map((p) => p.id));
    s.dungeonsDone.addAll(dungeons.map((d) => d.id));
    expect(e.roadStep()!.kind, isIn([RoadKind.heroic, RoadKind.train]));
    k.level = continents[1].minLevel;
    expect(e.roadStep()!.kind, RoadKind.boss);
    expect(e.roadStep()!.land, 1);
    // Waiting on the Badlands' level with Ravenmoor open and its boss standing: Ravenmoor first.
    s.bossesDown.addAll({1, 2});
    s.risenDown.add(0);
    s.explored.clear();
    k.level = continents[3].minLevel - 4;
    expect(e.roadStep()!.kind, RoadKind.side);
    expect(continents[e.roadStep()!.land].name, 'Ravenmoor');
    // ...unless a risen boss is up carrying a relic part you're after: that first.
    k.level = continents[2].minLevel + risenAfter;
    if (k.level < continents[3].minLevel) {
      expect(e.roadStep()!.kind, RoadKind.heroic);
      expect(e.roadStep()!.land, 2);
    }
  });

  test('the road learns: the forge after a boss keeps winning, and walls left for later', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight;
    s.innRepaired = true;
    s.bossesDown.addAll({0, 1, 2});
    k.level = continents[3].minLevel;
    expect(e.roadStep()!.kind, RoadKind.boss);
    // Krugg beats you twice, and Dunstan has something for you: the forge first, once.
    s.bossLosses[3] = forgeHintLosses;
    k.coins = 100000;
    s.addMat(oreKey(Metal.iron), 6);
    expect(e.roadStep()!.kind, RoadKind.forge);
    expect(e.roadStep()!.sub, contains('beaten you twice'));
    e.lookedInForge();
    expect(e.roadStep()!.kind, RoadKind.boss, reason: 'been to the forge: back to the boss');
    s.bossLosses[3] = forgeHintLosses + 1;
    expect(e.roadStep()!.kind, RoadKind.forge, reason: 'beaten again: the forge again');
    // Waiting on a level, a side land's boss that keeps winning is left for later.
    s.bossLosses.clear();
    s.bossesDown.add(3);
    s.risenDown.addAll({0, 1, 2, 3});
    k.level = continents[4].minLevel - 1;
    final side = e.roadStep()!;
    expect(side.kind, RoadKind.side);
    s.bossLosses[side.land] = giveUpLosses;
    expect(e.roadStep()!.land, isNot(side.land));
    // A dungeon that keeps ending your runs, likewise.
    s.explored.addAll(places.map((p) => p.id));
    for (var i = mainLands; i < continents.length; i++) {
      s.bossesDown.add(i);
    }
    final delve = e.roadStep()!;
    if (delve.kind == RoadKind.dungeon) {
      s.setbacks['dungeon:${delve.id}'] = giveUpLosses;
      expect(e.roadStep()!.id, isNot(delve.id));
    }
  });

  test('after the Ember King, the road goes on to the lands still standing', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state;
    s.innRepaired = true;
    s.knight.level = 50;
    for (var i = 0; i < continents.length; i++) {
      if (i != 14) s.bossesDown.add(i);
    }
    s.risenDown.addAll(List.generate(continents.length, (i) => i));
    final step = e.roadStep()!;
    expect(step.kind, RoadKind.side);
    expect(step.land, 14);
  });

  test('a risen boss that beats you comes back a little weaker', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state;
    s.bossesDown.add(0);
    s.knight.level = e.risenLevel(0);
    e.travel(0);
    e.exploreHeroic();
    final full = s.foeMax;
    s.inBattle = false;
    s.bossLosses[risenLossKey(0)] = 2;
    e.exploreHeroic();
    expect(s.foeMax, lessThan(full));
    expect(s.foeHp, s.foeMax);
  });

  test('classes: a whole order suit makes you its knight, with ranks, rites and a passive', () {
    GameEngine suited(String set, int seed) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      final k = e.state.knight..level = 30;
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
      k.hp = maxHp(k);
      return e;
    }

    void win(GameEngine e) {
      final s = e.state;
      for (var i = 0; i < 20 && !s.inBattle; i++) {
        e.explore();
      }
      s.foeHp = 1;
      e.takeTurn(BattleAction.attack);
      while (s.inBattle) {
        s.foeHp = 1;
        e.takeTurn(BattleAction.attack);
      }
      s.pendingLoot.clear();
      s.knight.hp = maxHp(s.knight);
    }

    final e = suited('drakesworn', 3);
    final s = e.state, k = s.knight;
    expect(classOf(k)!.name, 'Dragon Knight');
    expect(classRank(k, 'drakesworn'), 1);
    // Rank 1: the first rite is known; the rank 4 one isn't yet.
    expect(riteKnown(k, spellById('wyrmflame')!), isTrue);
    expect(riteKnown(k, spellById('scaleward')!), isFalse);
    expect(spellsKnown(40).any((sp) => sp.order != null), isFalse, reason: 'class rites aren\'t learned by level');
    // Winning in the suit ranks it up, and a new rank's rite goes on the hotbar.
    while (classRank(k, 'drakesworn') < 4) {
      win(e);
    }
    expect(riteKnown(k, spellById('scaleward')!), isTrue);
    expect(k.rites, contains('scaleward'));
    // Out of the suit: a knight again, the class's rites set aside but kept.
    final ring = k.ring;
    k.ring = null;
    expect(classOf(k), isNull);
    expect(riteKnown(k, spellById('scaleward')!), isFalse);
    expect(e.whyNotRite('scaleward'), isNotNull);
    k.ring = ring;
    expect(classRank(k, 'drakesworn'), 4, reason: 'the rank is kept');
    // Saved and loaded with the rank.
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.knight.classWins['drakesworn'], k.classWins['drakesworn']);
    // The Blood Knight at rank 10: a killing blow once a fight leaves you on 1 HP.
    final b = suited('nightblood', 5), bk = b.state.knight;
    bk.classWins['nightblood'] = rankWins.last;
    expect(classPassive(bk, 'nightblood'), isTrue);
    for (var i = 0; i < 20 && !b.state.inBattle; i++) {
      b.explore();
    }
    b.state
      ..foeHp = 1 << 20
      ..foeMax = 1 << 20;
    var saved = false;
    for (var i = 0; i < 40 && b.state.inBattle && !saved; i++) {
      bk.hp = 1;
      final r = b.takeTurn(BattleAction.attack);
      saved = r.cheatedDeath;
    }
    expect(saved, isTrue);
    // Only rites of the class you wear: the Forge Knight can't cast the Dragon Knight's.
    final f = suited('deepforge', 6);
    expect(riteKnown(f.state.knight, spellById('anvilward')!), isTrue);
    expect(riteKnown(f.state.knight, spellById('wyrmflame')!), isFalse);
  });

  test('bolts can be swapped any time, plain ones in between', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final k = e.state.knight;
    expect(e.cycleAmmo(), isNull, reason: 'nothing to swap to');
    k.ammo['fire'] = 3;
    k.ammo['frost'] = 2;
    k.ammoLoaded = 'fire';
    e.state.inBattle = true;
    expect(e.cycleAmmo(), 'frost');
    expect(e.cycleAmmo(), isNull, reason: 'plain bolts');
    expect(e.cycleAmmo(), 'fire');
  });

  test('rare dyes cost their own price, ordinary ones the usual', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final k = e.state.knight;
    expect(e.priceOf('dye:royal'), prices['dye']);
    expect(e.priceOf('dye:obsidian'), 12000);
    k.coins = 11999;
    expect(e.purchase('dye:obsidian'), isFalse);
    k.coins = 12500;
    expect(e.purchase('dye:obsidian'), isTrue);
    expect(k.coins, 500);
    expect(k.dye, 'obsidian');
  });

  test('Hardcore: opens once New Game+ is beaten, and the first knockout ends the road', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state;
    expect(e.hardcoreOpen, isFalse);
    s.bossesDown.addAll({for (var c = 0; c < mainLands; c++) c});
    expect(e.hardcoreOpen, isFalse, reason: 'the first time through opens New Game+, not Hardcore');
    s.ng = 1;
    expect(e.hardcoreOpen, isTrue);
    // Going round New Game+ again keeps it open.
    expect(e.newGamePlus(), isTrue);
    expect(e.state.hcUnlocked, isTrue);
    expect(e.hardcoreOpen, isTrue);
    // A hardcore road: one life.
    final h = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..hardcore = true, random: Random(6));
    expect(h.whyNotNewGamePlus(), isNotNull);
    h.travel(0);
    h.explore();
    h.state.foeLevel = 40;
    for (var i = 0; i < 60 && h.state.inBattle; i++) {
      h.state.knight.hp = 1;
      if (h.takeTurn(BattleAction.attack).knockedOut) break;
    }
    expect(h.state.fallen, isTrue);
    final run = GameEngine.hardcoreSummary(h.state);
    expect(run['fell'], isTrue);
    expect(run['level'], 1);
    // It all survives a save and a load.
    final back = GameState.fromJson(h.state.toJson());
    expect(back.hardcore, isTrue);
    expect(back.fallen, isTrue);
  });

  test('New Game+: start again at level 1 with your keys and vault pieces, foes tougher', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight;
    expect(e.whyNotNewGamePlus(), isNotNull, reason: 'only once the Ember King is down');
    while (k.level < 30) {
      e.grantXp(xpToNext(k));
    }
    k.loadout.helm = e.loot.vaultPiece(vaultPieceNamed('Cinder Crown')!, k.level);
    k.stash.add(e.loot.vaultPiece(vaultPieceNamed('Brimstone Charm')!, k.level));
    k.coins = 5000;
    k.dye = 'midnight';
    s
      ..keys = 3
      ..vaultFound.addAll(['Cinder Crown', 'Brimstone Charm'])
      ..bossesDown.addAll({for (var c = 0; c < mainLands; c++) c})
      ..unlocked = mainLands - 1
      ..foesFelled = 300;
    // A dungeon run left open (its Map button, or home mid-run) doesn't hold it up: it used to,
    // with nothing in town to say a run was open.
    s.dungeon = dungeons.first.id;
    expect(e.whyNotNewGamePlus(), isNull);
    expect(e.newGamePlus(), isTrue);
    expect(e.state.dungeon, isNull);
    final n = e.state, h = n.knight;
    expect(n.ng, 1);
    expect(n.won, isFalse);
    expect(n.bossesDown, isEmpty);
    expect(h.level, 1);
    expect(h.coins, 0);
    expect(h.dye, 'midnight');
    expect(n.keys, 3);
    expect(n.vaultFound, containsAll(['Cinder Crown', 'Brimstone Charm']));
    expect(n.foesFelled, 300);
    expect(h.loadout.helm!.name, 'Cinder Crown');
    expect(h.loadout.helm!.level, 1);
    expect(h.stash.single.name, 'Brimstone Charm');
    expect(e.loot.ng, 1);
    expect(ngFoeHp(1), greaterThan(1));
    // Saved and loaded, still the second time round.
    final back = GameState.fromJson(jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>);
    expect(back.ng, 1);
    expect(GameEngine(back).loot.ng, 1);
  });

  test('the vault has a floor on bad luck: after a dry run of keys, a piece is sure', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    final s = e.state;
    s.keys = 1;
    s.vaultDry = vaultSure;
    expect(e.openVault()!.piece, isTrue);
    expect(s.vaultDry, 0);
    expect(GameState.fromJson(jsonDecode(jsonEncode((s..vaultDry = 3).toJson())) as Map<String, dynamic>).vaultDry, 3);
  });

  test('vault pieces are a set: three worn give the full bonus, and it never drops at random', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final three = [for (final p in vaultPieces.take(3)) e.loot.vaultPiece(p, 20)];
    expect(activeSets(three).single.$1.id, 'vault');
    expect(activeSets(three).single.$2, 3);
    expect(gearSetById('vault')!.forged, isTrue);
    // A piece found before the set existed joins it on loading.
    final old = three.first.toJson()..remove('set');
    expect(GearItem.fromJson(old).gearSet, 'vault');
    // And one saved with an older mix of stats comes back with today's (the same each load).
    final ring = e.loot.vaultPiece(vaultPieceNamed('Ring of the Ember Vault')!, 20).toJson();
    ring['stats'] = {'fortune': 30, 'lifesteal': 5};
    final back = GearItem.fromJson(ring);
    expect(back.stats.keys.toSet(), {Stat.lifesteal, Stat.guard, Stat.damage, Stat.fortune});
    expect(GearItem.fromJson(ring).stats, back.stats);
    expect(GearItem.fromJson(back.toJson()).stats, back.stats);
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

  test('a beaten boss rises again a few levels on: one fight, once, with its relic part', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final s = e.state, k = s.knight;
    s.bossesDown.add(0);
    k.level = continents[0].minLevel + risenAfter - 1;
    expect(e.risenReady(0), isFalse);
    expect(e.whyNotRisen(0), contains('level'));
    k.level++;
    expect(e.risenReady(0), isTrue);
    s.continent = 0;
    e.exploreHeroic();
    expect(foeIn(s).boss, isTrue);
    expect(s.foeMax, greaterThan(spawnHp(bossIndex(0), s.foeLevel)), reason: 'tougher than the first time');
    s.foeHp = 1;
    k.hp = maxHp(k);
    e.takeTurn(BattleAction.skill);
    expect(s.risenDown, contains(0));
    expect(hasRelicPart(s.relicParts, 0, 0), isTrue, reason: 'Gorbo, risen, carries the crown shard');
    expect(e.risenReady(0), isFalse);
  });

  test('a relic part you can go and get is offered on the board, ahead of contracts', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(5));
    final s = e.state;
    s.innRepaired = true;
    s.knight.level = 14;
    expect(e.relicStep(), isNull, reason: 'no blueprint yet');
    s.bossesDown.addAll({0, 1, 2});
    final step = e.relicStep();
    expect(step, isNotNull);
    expect(relicPartsAt(step!.id!), isNotEmpty);
    s.relicParts.clear();
    for (final (r, i) in relicPartsAt(step.id!)) {
      s.relicParts[r] = (s.relicParts[r] ?? 0) | (1 << i);
    }
    expect(e.relicStep()?.id, isNot(step.id));
  });

  test('the road is one line: each land opens behind the one before it', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final s = e.state..knight.level = 40;
    expect(e.whyNotTravel(1), contains('Gorbo'));
    s.bossesDown.add(0);
    expect(e.whyNotTravel(1), isNull);
    expect(e.whyNotTravel(2), isNotNull);
    s.bossesDown.add(1);
    expect(e.whyNotTravel(2), isNull);
    expect(e.whyNotTravel(3), isNotNull);
    expect(e.whyNotTravel(6), contains('Scorchmaw'));
    // A land already set foot in stays open (saves from when the road forked).
    s.wins[4] = 2;
    expect(e.whyNotTravel(4), isNull);
  });

  test('places on the map: explored once, guards fought for, the Lost Isle last', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    final s = e.state, k = s.knight..level = 40;
    // Only Cindervale's places show at first (the Lost Isle hides until the end).
    expect([for (final p in places) if (e.placeShown(p)) p.id], ['millcellar', 'scarecrow', 'orkscouts']);
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
    // One blueprint each time he yields (the suit has more pieces than he has meetings).
    expect(setPieceSlots.where((slot) => s.mat(blueprintKey('ashen', slot)) == 1).length, greaterThanOrEqualTo(4));
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
    expect(ring.rarity, Rarity.legendary);
    expect(ring.level, 20);
    expect(s.mat(trophyKey(Trophy.fang)), 0);
    // The blueprint is kept.
    expect(s.mat(blueprintKey('nightblood', GearSlot.ring)), 1);
    // Each piece is forged once, and can't be sold.
    s..addMat(trophyKey(Trophy.fang), pieceTrophies)..addMat(barKey(Metal.iron), pieceBars);
    expect(e.whyNotForgePiece('nightblood', GearSlot.ring), 'Already forged');
    expect(isKeepsake(ring), isTrue);
    // A few levels on, Dunstan reworks that one up to your level instead of making another.
    s.knight.level = 20 + temperMinGap;
    expect(e.canReforge('nightblood', GearSlot.ring), isTrue);
    final again = e.forgePiece('nightblood', GearSlot.ring)!;
    expect(again.id, ring.id);
    expect(again.level, 20 + temperMinGap);
    expect([...s.knight.stash, ...s.pendingLoot].where((g) => g.gearSet == 'nightblood' && g.slot == GearSlot.ring).single.level, 20 + temperMinGap);
    s.knight.level = 20;
    // Spare copies from before are sold when the game's loaded, the best kept.
    final spare = e.loot.setPiece('nightblood', GearSlot.ring, HeroClass.knight, 5);
    s.knight.stash.add(spare);
    final gold = GameEngine(s).sellSpareSetPieces() + 0;
    expect(gold, 0); // (already sold by the constructor)
    expect(s.knight.stash.contains(spare), isFalse);
    expect([...s.knight.stash, ...s.pendingLoot].where((g) => g.gearSet == 'nightblood' && g.slot == GearSlot.ring).length, 1);
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
    expect(activeSets(k.setGear).any((x) => x.$1.id == 'silverleaf' && x.$2 == 5), isTrue);
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
    // (Over 20 knights, not three: the odd unlucky run is fine, a hard start for everyone isn't.)
    var total = 0;
    for (var seed = 0; seed < 20; seed++) {
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
      expect(wins, greaterThanOrEqualTo(6), reason: 'seed $seed');
      total += wins;
    }
    expect(total / 20, greaterThanOrEqualTo(8));
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
    // Gorbo opens the road on: the Gloomfen.
    expect(r.kill!.opened, [1]);
    expect(s.knight.pets.containsKey(Pet.wolf.name), isTrue);
    expect(s.pendingLoot.any((g) => g.art == 'cyclopseye'), isTrue);
    expect(e.travel(1), isTrue);
    expect(e.travel(2), isFalse);
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
    // Each lump of iron ore makes a bar.
    s.addMat(oreKey(Metal.iron), 3);
    expect(e.smelt(Metal.iron), 3);
    expect(s.mat(barKey(Metal.iron)), 3);
    expect(s.mat(oreKey(Metal.iron)), 0);
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
    s.addMat(oreKey(Metal.iron), 1);
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

  test('Dunstan tempers any epic or legendary piece you wear halfway up to your level, for gold', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(13));
    final k = e.state.knight..level = 20;
    k.loadout.weapon = e.loot.entDrop(HeroClass.knight, 8);
    k.ring = e.loot.roll(HeroClass.knight, 8, odds: const [0, 0, 0, 0, 1], only: GearSlot.ring);
    final before = k.loadout.weapon!, ring = k.ring!;
    expect(e.temperables.map((g) => g.id), containsAll([before.id, ring.id]));
    final gold = e.temperCost(before);
    k.coins = gold - 1;
    expect(e.whyNotTemper(before), isNotNull); // a coin short
    k.coins = gold;
    final after = e.temper(before)!;
    expect(after.level, 14); // halfway from 8 to 20
    expect(after.id, before.id);
    expect(k.loadout.weapon!.level, 14);
    expect(after.stat(Stat.damage), greaterThan(before.stat(Stat.damage)));
    expect(k.coins, 0);
    // The ring too, and a legendary costs more than an epic the same distance behind.
    k.coins = 100000;
    expect(e.temper(ring)!.level, 14);
    expect(k.ring!.level, 14);
    // Still behind: another visit takes it halfway again, and once it's close it can't be.
    expect(e.temper(k.ring!)!.level, 17);
    expect(e.temper(k.ring!)!.level, 19);
    expect(e.temperables.any((g) => g.id == ring.id), isFalse);
    expect(temperFee(20, 12, legendary: true), greaterThan(temperFee(20, 12)));
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

  test('Old Corva\'s cards: paid for, one a fight, every card comes true, and it saves', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(3));
    final s = e.state, k = s.knight;
    k.coins = 50;
    expect(e.whyNotReading, isNull);
    final price = readingPrice(k.level);
    final drawn = e.drawCard();
    expect(drawn, isNotNull);
    expect(s.pint, isTrue);
    expect(e.whyNotReading, isNotNull);
    expect(e.drawCard(), isNull);
    expect(GameState.fromJson(s.toJson()).pint, isTrue);
    e.explore();
    fightOut(e);
    expect(s.pint, isFalse);
    k.coins = 0;
    expect(e.whyNotReading, 'Not enough gold');
    // Every card turns up in time, and none breaks anything.
    final seen = <Tarot>{};
    for (var i = 0; i < 400 && seen.length < Tarot.values.length; i++) {
      s.pint = false;
      s.encounter = null;
      k.brews.clear();
      k.potions = 0;
      k.coins = 1000;
      seen.add(e.drawCard()!.$1);
    }
    expect(seen, Tarot.values.toSet());
    expect(price, greaterThan(0));
  });

  test('the Chariot raises your health for a few fights, then it ebbs', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight)..innRepaired = true, random: Random(1));
    final k = e.state.knight, base = maxHp(k);
    k.chariotFights = tarotFights;
    expect(maxHp(k), base + (base * chariotHp).round());
    expect(Knight.fromJson(k.toJson()).chariotFights, tarotFights);
    for (var i = 0; i < tarotFights; i++) {
      e.explore();
      fightOut(e);
      k.hp = maxHp(k);
    }
    expect(k.chariotFights, 0);
    // (You may have levelled up meanwhile: the Chariot's share is what's gone.)
    final after = maxHp(k);
    k.chariotFights = 1;
    expect(maxHp(k), greaterThan(after));
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
    expect(e.risenReady(0), isTrue);
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
    final kingsfall = e.forgeRelic(0)!;
    // It comes out of the forge already honed: above the legendaries that simply drop.
    expect(kingsfall.hone, relicHone);
  });

  test('class suits are legendary, and old epic pieces become legendary on loading', () {
    final s = GameEngine.newGame(heroClass: HeroClass.knight), loot = LootTable(Random(2));
    expect(loot.setPiece('nightblood', GearSlot.helm, HeroClass.knight, 30).rarity, Rarity.legendary);
    expect(loot.setPiece('arena', GearSlot.helm, HeroClass.knight, 30).rarity, Rarity.epic);
    final old = loot.setPiece('nightblood', GearSlot.gloves, HeroClass.knight, 30);
    final epic = GearItem(id: old.id, name: old.name, slot: old.slot, art: old.art, rarity: Rarity.epic, level: 30, gearSet: 'nightblood', value: 10, stats: {Stat.damage: 100});
    s.knight.stash.add(epic);
    GameEngine(s);
    final now = s.knight.stash.single;
    expect(now.rarity, Rarity.legendary);
    expect(now.stats[Stat.damage], 120);
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

  test('potions past a full belt: drunk if you\'re hurt, the rest sold for gold', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1), clock: () => DateTime(2026, 6, 1));
    final k = e.state.knight;
    k.potions = potionBelt - 1;
    k.hp = maxHp(k);
    final coins = k.coins;
    final said = e.givePotionsForTest(3);
    expect(k.potions, potionBelt);
    expect(k.coins, coins + 2 * e.spareGold);
    expect(said, contains('+${2 * e.spareGold} gold'));
    k.hp = 1;
    final hp = k.hp, coins2 = k.coins;
    e.givePotionsForTest(1);
    expect(k.hp, greaterThan(hp));
    expect(k.coins, coins2);
  });

  test('Fester bursts the foe\'s affliction (turns of it at once), and does nothing more without one', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(3), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    while (k.level < 12) {
      e.grantXp(xpToNext(k));
    }
    s.innRepaired = true;
    e.explore();
    expect(s.inBattle, isTrue);
    k.rites = ['fester'];
    k.preparedSpell = 'fester';
    s
      ..foeMax = 99999
      ..foeHp = 99999
      ..mana = 5
      ..foeBurn = 10
      ..foeBurnTurns = 1;
    expect(e.festerBurst, 10 * festerTurns);
    final r = e.takeTurn(BattleAction.cast);
    expect(r.festered, 10 * festerTurns);
    expect(r.festerKind, 'burn');
    // Nothing on it: no burst.
    s
      ..foeBurnTurns = 0
      ..foeBurn = 0
      ..mana = 5;
    expect(e.festerBurst, 0);
    if (s.inBattle && e.whyNot(BattleAction.cast) == null) expect(e.takeTurn(BattleAction.cast).festered, 0);
  });

  test('Blood Edge: the price now, and the next blade blow can\'t miss and lands harder (then it\'s spent)', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(5), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    s.innRepaired = true;
    e.explore();
    expect(s.inBattle, isTrue);
    // Blood Edge is a Blood Knight's rite: count it known for the test by putting it on and
    // checking the engine's own handling of the cast.
    final sp = spellById('bloodpact')!;
    expect(sp.kind, SpellKind.bloodedge);
    s
      ..foeMax = 999999
      ..foeHp = 999999;
    // Charge it by hand (as the cast does), then a plain attack: it can't miss, and it's big.
    var hits = 0, plain = 0.0, charged = 0.0;
    for (var i = 0; i < 40; i++) {
      k.hp = maxHp(k);
      s.bloodEdge = true;
      final before = s.foeHp;
      final r = e.takeTurn(BattleAction.attack);
      expect(r.miss, isFalse);
      expect(r.edgeSpent, isTrue);
      expect(s.bloodEdge, isFalse);
      charged += before - s.foeHp;
      hits++;
      final b2 = s.foeHp;
      e.takeTurn(BattleAction.attack);
      plain += b2 - s.foeHp;
      s
        ..foeHp = 999999
        ..skillWait = 0;
    }
    expect(hits, 40);
    expect(charged / plain, greaterThan(2.5));
  });

  test('the Ember Throne is sealed till half the side lands\' lords are down, and the road says so', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    while (k.level < 40) {
      e.grantXp(xpToNext(k));
    }
    s.innRepaired = true;
    for (var c = 0; c < throneLand; c++) {
      s.bossesDown.add(c);
    }
    expect(e.whyNotTravel(throneLand), contains('Sealed'));
    expect(e.roadStep()?.title, startsWith('Break a seal'));
    expect(isSideLand(e.roadStep()!.land), isTrue);
    s.bossesDown.addAll([for (var i = 0; i < throneSeals - 1; i++) mainLands + i]);
    expect(e.whyNotTravel(throneLand), contains('1 more side land'));
    s.bossesDown.add(mainLands + throneSeals - 1);
    expect(e.whyNotTravel(throneLand), isNull);
    // Six seals without Deepforge Hold's don't do: its lord holds the one that must break.
    s.bossesDown
      ..remove(throneKeyLand)
      ..add(mainLands + throneSeals);
    expect(e.whyNotTravel(throneLand), contains('holds the last seal'));
    expect(e.roadStep()?.land, throneKeyLand);
    s.bossesDown.add(throneKeyLand);
    expect(e.whyNotTravel(throneLand), isNull);
    expect(e.roadStep()?.land, throneLand);
  });

  test('the Ember King doesn\'t weaken for losing to him: the road sends you after his generals', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    while (k.level < 40) {
      e.grantXp(xpToNext(k));
    }
    s.innRepaired = true;
    for (var c = 0; c < throneLand; c++) {
      s.bossesDown.add(c);
    }
    s.bossesDown.addAll([for (var i = 0; i < throneSeals; i++) mainLands + i]);
    final king = bossIndex(throneLand);
    s.bossLosses[throneLand] = 3;
    expect(e.doggedFor(king), 1);
    s.setbacks['hunt'] = 1;
    expect(e.roadStep()?.title, startsWith('Hunt the Ember King'));
    s.generalsDown.add(emberGenerals.first);
    expect(e.roadStep()?.title, startsWith('Beat Vharrax'));
    // (A last resort, long after: he does give, so the road can't end at his feet for ever.)
    s.bossLosses[throneLand] = kingMercyAfter + 2;
    expect(e.doggedFor(king), lessThan(1));
  });

  test('a suit can be changed for another in one go, and the body armour taken off is kept', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    while (k.level < 35) {
      e.grantXp(xpToNext(k));
    }
    for (final set in ['nightblood', 'deepforge']) {
      for (final slot in setPieceSlots) {
        k.stash.add(e.loot.setPiece(set, slot, k.heroClass, k.level));
      }
    }
    expect(e.wearSuit('nightblood'), setPieceSlots.length);
    expect(suitWorn(k), 'nightblood');
    expect(e.holdsSuit('deepforge'), isTrue);
    expect(e.wearSuit('deepforge'), setPieceSlots.length);
    expect(suitWorn(k), 'deepforge');
    // The Blood Knight's breastplate went in the chest, not into thin air.
    expect(k.stash.any((g) => g.slot == GearSlot.armour && g.art == setArmourId('nightblood')), isTrue);
    expect(e.holdsSuit('nightblood'), isTrue);
    expect(e.wearSuit('nightblood'), setPieceSlots.length);
    expect(suitWorn(k), 'nightblood');
  });

  test('the fortress: after the Ember King; a second runner, a third rack, and outfits keep their body armour', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(3), clock: () => DateTime(2026, 6, 1));
    final s = e.state, k = s.knight;
    s.innRepaired = true;
    s.home = 2;
    k.coins = 100000;
    s.timber = 99;
    s.ironScrap = 99;
    expect(e.whyNotBuild, contains('Vharrax'));
    s.bossesDown.add(mainLands - 1);
    expect(e.buildHome(), isTrue);
    expect(homes[s.home].name, 'Fortress');
    expect(e.stashCap, 120);
    expect(armouryRacks(s.home), 3);
    // Two runners, an errand each.
    expect(e.sendErrand('fields'), isTrue);
    expect(e.sendErrand('ruins'), isTrue);
    expect(s.errand2, 'ruins');
    expect(e.whyNotErrand('wilds'), 'Both runners are out');
    s.foesFelled += errandById('ruins')!.fights;
    expect(e.errandBackOf(0) && e.errandBackOf(1), isTrue);
    expect(e.collectErrand(1), isNotEmpty);
    expect(s.errand2, isNull);
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.errand, 'fields');
    // An outfit in a class suit, another in plain armour: each puts its own body armour back on.
    while (k.level < 35) {
      e.grantXp(xpToNext(k));
    }
    final plain = k.loadout.armour;
    e.saveGearSet(0);
    for (final slot in setPieceSlots) {
      k.stash.add(e.loot.setPiece('deepforge', slot, k.heroClass, k.level));
    }
    e.wearSuit('deepforge');
    expect(suitWorn(k), 'deepforge');
    e.saveGearSet(1);
    e.wearGearSet(0);
    expect(k.loadout.armour, plain);
    e.wearGearSet(1);
    expect(suitWorn(k), 'deepforge');
  });
}
