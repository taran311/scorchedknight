// The square's suggestions, put to the test: whole games played by players who do what the town's
// cards tell them, checking every suggestion as it's made. Each card must name something you can
// actually go and do there and then (the land open, the place unexplored and its guard awake, the
// dungeon open, the risen boss risen), its words must be true (the level it says a land opens at),
// and following it must lead somewhere: no step that hangs on for ever, none that sends you to be
// knocked out again and again.
//
// Players:
//   road      does only what the Road card says (and the town chores: potions, gear, the forge)
//   cards     taps whichever card is showing: the road mostly, the relic part, the board's
//             contract or "somewhere to explore" the rest of the time
//   careless  follows the road but never shops beyond potions and armour (no brews, wards, runes,
//             bolts or forging)
//   wander    goes where it likes half the time (any open land, a random place), the road the rest
//   noforge   never goes to Dunstan's forge
//   hinted    never goes to the forge unless the Road card sends it there
//
// Run: dart --packages=.dart_tool/package_config.json run tool/road_audit.dart [runs] [player]

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:scorchedknight/game/brews.dart';
import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/classes.dart';
import 'package:scorchedknight/game/crafting.dart';
import 'package:scorchedknight/game/dungeons.dart';
import 'package:scorchedknight/game/engine.dart';
import 'package:scorchedknight/game/knight_classes.dart';
import 'package:scorchedknight/game/loot.dart';
import 'package:scorchedknight/game/models.dart';
import 'package:scorchedknight/game/rules.dart';
import 'package:scorchedknight/game/spells.dart';
import 'package:scorchedknight/game/vault.dart' show isKeepsake;

/// Everything wrong one game turned up, and how its steps went.
class Audit {
  Audit(this.player, this.seed);
  final String player;
  final int seed;
  final problems = <String>[];
  int fights = 0, knockouts = 0, coins = 0, level = 0;
  bool won = false;
  /// Gold held when each main boss fell: land → coins.
  final goldAt = <int, int>{};

  /// Each step the Road card showed, in order: its words, the level and fight it first showed at,
  /// how many fights it stayed up, and the knockouts along the way.
  final steps = <({String title, String sub, int level, int from, int fights, int kos, int streak})>[];

  void flag(String what) {
    if (problems.length < 60 && !problems.contains(what)) problems.add(what);
  }
}

/// A turn's move: a potion at a third of HP, the foe's weakness, rites, the skill and companion.
/// 'smart' reads the foe's card and picks the hardest-landing move; 'full' the old fixed order
/// (weakness, bash, any rite, companion, bolt); 'melee' only the two attacks (and potions).
var policy = 'smart';

/// Whether the audit's knight takes Fester onto the hotbar (and what it was worth when it could).
var useFester = Platform.environment['FESTER'] == '1';
final festerSeen = <double>[];

/// The odds a hardcore player wants before taking a boss on.
var hcOdds = .9;

BattleAction choose(GameEngine e) {
  final k = e.state.knight, f = encounterType(e.state.foe, e.state.rare);
  if (k.hp < maxHp(k) * .35 && e.whyNot(BattleAction.potion) == null) return BattleAction.potion;
  // Hardcore: Death's Door has held once this fight and there's nothing to drink: run.
  if (e.state.hardcore && e.state.doorUsed && k.hp < maxHp(k) * .35 && e.whyNot(BattleAction.flee) == null) return BattleAction.flee;
  if (policy == 'melee') return e.whyNot(BattleAction.skill) == null ? BattleAction.skill : BattleAction.attack;
  if (policy == 'smart') return smart(e);
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

/// A player who reads the foe's card: the move that lands hardest on this foe, from how each way of
/// fighting lands on it (the triangle, flying, stone and spirits), the bash when it's ready, a
/// bolt when it's the better shot, a damage rite when there's mana for it.
BattleAction smart(GameEngine e) {
  final k = e.state.knight, f = foeIn(e.state);
  final might = mightBoost(k);
  final blade = styleEdgeOn(f, AttackStyle.blade);
  var best = BattleAction.attack;
  var score = blade;
  if (e.whyNot(BattleAction.skill) == null && blade * bashMult > score) {
    best = BattleAction.skill;
    score = blade * bashMult;
  }
  final bolt = styleEdgeOn(f, AttackStyle.bolt) * crossbowShare(k) * aimBoost(k) / might;
  if (bolt > score) {
    best = BattleAction.shoot;
    score = bolt;
  }
  for (final id in k.rites) {
    final sp = spellById(id);
    if (sp == null || e.whyNotRite(id) != null) continue;
    // (Blood Edge is worth the blow it charges, as Blood Pact's own blow was.)
    final dmg = sp.kind == SpellKind.bloodedge
        ? blade * bloodEdgeBonus
        : styleEdgeOn(f, AttackStyle.rite) * sp.mult * arcanaBoost(k) / might + (sp.element == null ? 0 : .3) + (sp.kind == SpellKind.fester ? e.festerBurst / max(1, fullSwing(k)) : 0);
    if (sp.kind == SpellKind.fester) festerSeen.add(e.festerBurst / max(1, fullSwing(k)));
    if (sp.mult > 0 && dmg > score) {
      best = BattleAction.cast;
      score = dmg;
      k.preparedSpell = id;
    }
  }
  return best;
}

/// Between fights: rest, rites, training, and (unless careless) the shops and the forge. (Places
/// are left for the cards to send you to.)
// ---- forced builds, for the balance sweep: BUILD=nightblood|deepforge|drakesworn (the class's
// whole suit from a few levels after its land opens, kept at level) and WEAPON=<a legendary's
// name> (from level 15, when legendaries start to drop, kept at level).
var buildSuit = Platform.environment['BUILD'];
var buildWeapon = Platform.environment['WEAPON'];
const suitFrom = {'nightblood': 18, 'deepforge': 30, 'drakesworn': 35, 'ashen': 12, 'moonfang': 24, 'silverleaf': 34, 'faceless': 37, 'sunscale': 32, 'tidecaller': 26, 'changeling': 40};
const classRitesOf = {'drakesworn': ['wyrmflame', 'dragonroar', 'scaleward'], 'nightblood': ['crimsonthirst', 'bloodpact', 'nightveil'], 'deepforge': ['moltenhammer', 'earthshaker', 'anvilward']};
var _suitAt = -99, _weaponAt = -99;
bool suitOn(Knight k) => buildSuit != null && k.level >= suitFrom[buildSuit]!;
bool weaponOn(Knight k) => buildWeapon != null && k.level >= 15;

void applyBuild(GameEngine e) {
  final k = e.state.knight;
  if (suitOn(k) && (k.level - _suitAt >= 3 || suitWorn(k) != buildSuit)) {
    _suitAt = k.level;
    for (final slot in setPieceSlots) {
      final g = e.loot.setPiece(buildSuit!, slot, k.heroClass, k.level);
      switch (slot) {
        case GearSlot.armour:
          k.loadout.armour = g.art;
        case GearSlot.ring:
          k.ring = g;
        default:
          k.loadout.put(g);
      }
    }
  }
  if (weaponOn(k) && (k.level - _weaponAt >= 3 || k.loadout.weapon?.name != buildWeapon)) {
    _weaponAt = k.level;
    k.loadout.weapon = e.loot.legendNamed(buildWeapon!, k.heroClass, k.level) ?? (throw 'No legendary named $buildWeapon');
  }
}

/// Slots the forced build holds: the loot never replaces them.
bool buildHolds(Knight k, GearSlot slot) => (slot == GearSlot.weapon && weaponOn(k)) || (suitOn(k) && setPieceSlots.contains(slot));

void inTown(GameEngine e, {required bool careless, bool wards = true, bool forge = true, bool armour = true}) {
  applyBuild(e);
  _inTown(e, careless: careless, wards: wards, forge: forge, armour: armour);
  // (The shops and the forge may have put other armour on: the build's suit goes back on.)
  applyBuild(e);
}

void _inTown(GameEngine e, {required bool careless, bool wards = true, bool forge = true, bool armour = true}) {
  final s = e.state, k = s.knight;
  final known = spellsKnown(k.level).map((x) => x.id).toSet();
  // (A test build: FESTERBUILD=poison|burn|bleed puts that on the blade, a third of a swing.)
  final fb = Platform.environment['FESTERBUILD'];
  if (fb != null && k.loadout.weapon != null) {
    final w = k.loadout.weapon!, st = Stat.values.byName(fb);
    w.stats.removeWhere((x, _) => x == Stat.poison || x == Stat.burn || x == Stat.bleed);
    w.stats[st] = 0;
    w.stats[st] = (fullSwing(k) * .33).round();
  }
  // (Fester only for a knight whose blade lays a real affliction: a quarter of a swing a turn.)
  final h = heroStats(k), festers = useFester && (h.burn + h.poison + h.bleed) >= fullSwing(k) * .25;
  final pref = ['chainlightning', if (festers) 'fester' else 'dragonfire', 'lifedrain', 'frostnova', 'spectralcharge', 'bloodbolt', 'arcanebolt'];
  final cls = classRitesOf[classOf(k)?.id] ?? const <String>[];
  k.rites = [
    for (final id in cls) if (spellById(id) case final sp? when riteKnown(k, sp)) id,
    for (final id in pref) if (known.contains(id)) id,
  ].take(riteSlots).toList();
  const plan = [Trait.might, Trait.arcana, Trait.aim, Trait.vigour];
  var i = 0;
  while (unspentPoints(k) > 0) {
    e.train(plan[i++ % plan.length]);
  }
  e.repairInn();
  if (k.hp < maxHp(k) * .7) e.rest();
  e.buildHome();
  while (k.potions < 4 && k.coins > e.priceOf('potion') * 3) {
    if (!e.purchase('potion')) break;
  }
  for (final t in tiersFor(k.heroClass).skip(1).where((t) => !t.dropOnly && !isCrafted(t.id))) {
    if (!e.owns(t.id) && k.coins >= e.priceOf(t.id) * 1.2) e.purchase(t.id);
  }
  // (Wards even for the careless: the map offers one at the door of an unwarded land.)
  for (var w = 1; w < continents.length && wards; w++) {
    e.craftWard(w);
  }
  if (careless) return;
  if (k.coins > e.priceOf('crossbow') * 1.5) e.purchase('crossbow');
  for (final g in Gem.values) {
    while (e.fletch(g)) {}
  }
  if (k.coins > 1500) {
    final r = e.enchantOffer(EnchantSlot.weapon);
    if (r != null) {
      final cur = k.loadout.weapon?.enchant;
      if (cur == null || r.tier >= cur.tier) e.applyEnchant(EnchantSlot.weapon, r);
    }
  }
  for (final b in Brew.values) {
    if (!brewOn(k, b)) e.brew(b);
  }
  if (!forge) return;
  forgeChores(e, armour: armour);
}

/// Everything at Dunstan's: smelting, armour, set pieces, tempering, relics.
void forgeChores(GameEngine e, {bool armour = true}) {
  final k = e.state.knight;
  for (final m in Metal.values) {
    e.smelt(m);
  }
  for (final t in tiersFor(k.heroClass).reversed) {
    if (armour && isCrafted(t.id) && e.craftArmour(t.id)) break;
  }
  for (final f in forgedSets) {
    for (final slot in setPieceSlots) {
      if (!e.hasSetPiece(f.id, slot) || e.canReforge(f.id, slot)) e.forgePiece(f.id, slot);
    }
  }
  for (final g in e.temperables) {
    if (e.whyNotTemper(g) == null) e.temper(g);
  }
  for (final c in relics.keys) {
    if (e.whyNotForge(c) == null) e.forgeRelic(c);
  }
}

/// Spoils: wear what's better, keep keepsakes, sell the rest.
void takeLoot(GameEngine e) {
  final s = e.state, k = s.knight;
  for (final g in List.of(s.pendingLoot)) {
    final old = e.equippedFor(g);
    final usable = (g.heroClass == null || g.heroClass == k.heroClass) && e.whyNotWear(g) == null && !buildHolds(k, g.slot);
    final better = g.slot == GearSlot.armour ? armourTierById(g.art).reduction > armourTierById(k.loadout.armour).reduction : old == null || gearWorth(k, g, old) > gearWorth(k, old, old);
    if (usable && better) {
      e.equipLoot(g.id);
    } else if (isKeepsake(g)) {
      e.keepLoot(g.id);
    } else {
      e.sellLoot(g.id);
    }
  }
  for (final g in List.of(k.stash)) {
    if (!isKeepsake(g)) e.sellFromStash(g.id);
  }
}

/// Fights the fight in front of you out. True if you were knocked out.
/// Called after every fight: (engine, foe type, turns, share of max HP lost, knocked out).
void Function(GameEngine e, FoeType f, int turns, double lost, bool ko)? onFight;

var _dumped = 0;

bool fight(GameEngine e, Random rng, Audit a) {
  final s = e.state;
  final f0 = s.inBattle ? encounterType(s.foe, s.rare) : null, hp0 = s.knight.hp / maxHp(s.knight);
  var turns = 0, ko = false;
  while (s.inBattle && turns < 400) {
    final m = choose(e);
    final r = e.takeTurn(m, aim: m == BattleAction.shoot ? [bullseye, 1.0, graze][rng.nextInt(3)] : 1);
    turns++;
    if (r.knockedOut) ko = true;
  }
  if (turns >= 400) a.flag('a fight never ended (${encounterType(s.foe, s.rare).name})');
  if (f0 != null) onFight?.call(e, f0, turns, hp0 - s.knight.hp / maxHp(s.knight), ko);
  a.fights++;
  if (ko) a.knockouts++;
  if (ko && Platform.environment['DEBUGKO'] == '1' && (f0?.name.startsWith('Vharrax') ?? false) && _dumped++ < 1) {
    for (final j in s.journal.reversed.take(40).toList().reversed) {
      print('    | ${j.text}');
    }
  }
  if (s.encounter != null) e.resolveEncounter(rng.nextInt(2));
  takeLoot(e);
  return ko;
}

/// Checks a card's step can be taken now, and that what it says is true. Null if it's fine.
String? checkStep(GameEngine e, RoadStep st, {required bool road}) {
  final s = e.state, k = s.knight;
  if (st.why != null) return null; // A blocked boss: the card says why, and offers the map.
  switch (st.kind) {
    case RoadKind.boss || RoadKind.side:
      if (e.whyNotTravel(st.land) != null) return '"${st.title}": ${continents[st.land].name} is shut (${e.whyNotTravel(st.land)})';
      if (s.bossesDown.contains(st.land)) return '"${st.title}": that boss is already down';
      if (st.kind == RoadKind.side && !isSideLand(st.land)) return '"${st.title}": not a side land';
    case RoadKind.heroic:
      if (e.whyNotRisen(st.land) != null) return '"${st.title}": ${e.whyNotRisen(st.land)}';
      if (e.whyNotTravel(st.land) != null) return '"${st.title}": ${continents[st.land].name} is shut';
    case RoadKind.place:
      if (e.whyNotExplore(st.id!) != null) return '"${st.title}": ${e.whyNotExplore(st.id!)}';
      if (placeById(st.id!)!.land != st.land) return '"${st.title}": the card names the wrong land';
    case RoadKind.dungeon:
      if (e.whyNotDungeon(st.id!) != null) return '"${st.title}": ${e.whyNotDungeon(st.id!)}';
    case RoadKind.train:
      if (e.whyNotTravel(st.land) != null) return '"${st.title}": ${continents[st.land].name} is shut';
    case RoadKind.forge:
      if (!e.forgeReady && e.upgradesReady == 0) return '"${st.title}": nothing at the forge to do';
    case RoadKind.arena:
      if (e.whyNotArena() != null) return '"${st.title}": ${e.whyNotArena()}';
    case RoadKind.hall:
      if (e.whyNotHall() != null) return '"${st.title}": ${e.whyNotHall()}';
    case RoadKind.wild:
      break;
  }
  // "Level N opens the X": the next land on the road, and you're below N.
  final m = RegExp(r'Level (\d+) opens (.+)').firstMatch(st.sub);
  if (m != null) {
    final next = [for (var i = 0; i < mainLands; i++) i].firstWhere((i) => !s.bossesDown.contains(i));
    final need = int.parse(m.group(1)!);
    if (need != continents[next].minLevel) return '"${st.sub}": the next land opens at ${continents[next].minLevel}';
    if (k.level >= need) return '"${st.sub}": you\'re already level ${k.level}';
    if (!continents[next].name.toLowerCase().endsWith(m.group(2)!.toLowerCase().replaceFirst('the ', ''))) return '"${st.sub}": the next land is ${continents[next].name}';
  }
  final g = RegExp(r'reach level (\d+)').firstMatch(st.title);
  if (g != null && k.level >= int.parse(g.group(1)!)) return '"${st.title}": you\'re already level ${k.level}';
  return null;
}

/// Does what a card says: one fight's worth of it (or a whole dungeon run). True if you fought.
void take(GameEngine e, RoadStep st, Random rng, Audit a) {
  final s = e.state;
  switch (st.kind) {
    case RoadKind.boss || RoadKind.side || RoadKind.train:
      if (st.why != null) {
        // The way's shut for something other than your level: fight on where you are.
        e.travel(s.unlocked.clamp(0, mainLands - 1));
        e.explore();
      } else {
        e.travel(st.land);
        if (st.kind != RoadKind.train && e.bossReady && !s.bossesDown.contains(st.land)) {
          // A player sleeps it off before a boss (the inn's free), unless it only comes out at night.
          if (!continents[st.land].boss.night) e.rest();
          e.challengeBoss();
        } else {
          e.explore();
        }
      }
      fight(e, rng, a);
    case RoadKind.heroic:
      e.rest();
      e.travel(st.land);
      e.exploreHeroic();
      fight(e, rng, a);
    case RoadKind.place:
      e.explorePlace(st.id!);
      if (s.inBattle) fight(e, rng, a);
    case RoadKind.dungeon:
      if (!e.enterDungeon(st.id!)) return;
      var rooms = 0;
      while (s.dungeon != null && rooms++ < 40) {
        if (e.dungeonCleared) {
          e.leaveDungeon();
          break;
        }
        final doors = [for (var i = 0; i < s.dungeonDoors.length; i++) if (e.whyNotDoor(i) == null) i];
        if (doors.isEmpty) {
          e.leaveDungeon();
          break;
        }
        e.openDoor(doors[rng.nextInt(doors.length)]);
        if (s.inBattle && fight(e, rng, a)) break;
        if (s.knight.hp < maxHp(s.knight) * .25 && !s.inBattle) {
          // Too hurt to go on: out, like a player would.
          e.leaveDungeon();
        }
      }
      if (rooms >= 40) a.flag('a dungeon run never ended (${dungeonById(st.id!)!.name})');
    case RoadKind.forge:
      // The road says the forge: everything Dunstan can do, then back to the road.
      forgeChores(e);
      e.lookedInForge();
    case RoadKind.arena:
      e.rest();
      if (e.startArenaBout() != null) fight(e, rng, a);
    case RoadKind.hall:
      e.rest();
      if (e.startHallFight() != null) fight(e, rng, a);
    case RoadKind.wild:
      break;
  }
}

/// How often you'd beat the boss a card names, fresh from the inn, as you are right now: [n]
/// tries from a copy of the save. Null if it isn't a boss you can face yet.
double? winOdds(GameEngine e, RoadStep st, int n) {
  if (!const {RoadKind.boss, RoadKind.side, RoadKind.heroic}.contains(st.kind) || st.why != null) return null;
  final json = jsonEncode(e.state.toJson());
  var won = 0;
  final hook = onFight;
  onFight = null;
  for (var i = 0; i < n; i++) {
    final s = GameState.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
    final t = GameEngine(s, random: Random(1000 + i), clock: () => DateTime(2026, 6, 1));
    s.knight.hp = maxHp(s.knight);
    s.day = !continents[st.land].boss.night;
    t.travel(st.land);
    if (st.kind == RoadKind.heroic) {
      t.exploreHeroic();
    } else {
      s.wins[st.land] = winsForBoss;
      if (!t.challengeBoss()) return null;
    }
    final a = Audit('trial', 0), fled = s.flees;
    if (!fight(t, Random(i), a) && s.flees == fled) won++;
  }
  onFight = hook;
  return won / n;
}

/// The odds each boss step was shown at, across every game: step → (times, summed odds).
final odds = <String, (int, double, int)>{};

/// Where each game stood when the Ember King's card first came up: (player, level, side lords
/// beaten, side lands set foot in, fights so far).
final atKing = <(String, int, int, int, int)>[];

Audit play(int seed, String player, {int maxFights = 2500}) {
  final a = Audit(player, seed);
  _suitAt = _weaponAt = -99;
  final was = policy;
  if (player == 'careless') policy = 'full';
  final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed), clock: () => DateTime(2026, 6, 1));
  final rng = Random(seed * 7 + 1), s = e.state, k = s.knight;
  e.takeHobsJob();
  if (player.startsWith('hc')) s.hardcore = true;
  String? showing;
  var shownFrom = 0, shownKos = 0, shownLevel = 0, shownSub = '', loops = 0, streak = 0, worst = 0;
  final tried = <String>{};
  void close() {
    final title = showing;
    if (title != null) a.steps.add((title: title, sub: shownSub, level: shownLevel, from: shownFrom, fights: a.fights - shownFrom, kos: a.knockouts - shownKos, streak: worst));
  }

  while (!s.won && !s.fallen && a.fights < maxFights && loops++ < maxFights * 3) {
    inTown(e, careless: player == 'careless', wards: player != 'noward', forge: player != 'noforge' && player != 'hinted', armour: player != 'noarmour');
    if (s.inBattle) {
      fight(e, rng, a);
      continue;
    }
    // Hob's job first: the cards wait for the inn.
    if (!s.innRepaired) {
      e.travel(0);
      e.explore();
      fight(e, rng, a);
      continue;
    }
    final road = e.roadStep();
    if (road == null) break;
    // Track the Road card's step as it changes.
    if (road.title != showing) {
      close();
      showing = road.title;
      shownSub = road.sub;
      shownFrom = a.fights;
      shownKos = a.knockouts;
      shownLevel = k.level;
      streak = worst = 0;
    }
    if (road.land == throneLand && road.kind == RoadKind.boss && !tried.contains('king@')) {
      tried.add('king@');
      final side = [for (var c = mainLands; c < continents.length; c++) c];
      atKing.add((player, k.level, side.where(s.bossesDown.contains).length, side.where((c) => s.bossesDown.contains(c) || (c < s.wins.length && s.wins[c] > 0)).length, a.fights));
    }
    // The first time a boss card can actually be taken on (its trail walked): how good are the odds?
    if (player == 'road' && (road.kind == RoadKind.heroic || ((road.kind == RoadKind.boss || road.kind == RoadKind.side) && s.winsToBoss(road.land) == 0)) && !tried.contains(road.title)) {
      tried.add(road.title);
      // KINGONLY=1: only the Ember King's odds (much faster), with KINGTRIES tries.
      final kingOnly = Platform.environment['KINGONLY'] == '1';
      if ((!kingOnly || road.land == throneLand ? winOdds(e, road, kingOnly ? int.parse(Platform.environment['KINGTRIES'] ?? '24') : 12) : null) case final w?) {
        final key = road.title.replaceAll(RegExp(r' · .*'), '');
        final (n, sum, lv) = odds[key] ?? (0, 0.0, 0);
        odds[key] = (n + 1, sum + w, lv + k.level);
      }
    }
    if (checkStep(e, road, road: true) case final bad?) a.flag('road at level ${k.level}: $bad');
    // The other cards on the square, checked as they show.
    final relic = e.relicStep(), explore = e.exploreStep();
    if (relic != null) {
      if (checkStep(e, relic, road: false) case final bad?) a.flag('relic card at level ${k.level}: $bad');
    }
    if (explore != null) {
      if (checkStep(e, explore, road: false) case final bad?) a.flag('explore card at level ${k.level}: $bad');
    }
    for (final j in e.board.take(1)) {
      final why = e.whyNotExplore(j.place);
      if (why != null && why != 'Its guard only comes out at night') a.flag('board at level ${k.level}: ${placeById(j.place)!.name}: $why');
    }
    // What this player does now.
    RoadStep pick = road;
    if (player == 'cards' && rng.nextDouble() < .35) {
      final board = e.board.where((j) => e.whyNotExplore(j.place) == null).firstOrNull;
      pick = relic ?? (board != null ? RoadStep(RoadKind.place, 'contract', '', placeById(board.place)!.land, id: board.place) : explore) ?? road;
    } else if (player == 'wander' && rng.nextDouble() < .5) {
      final open = [for (var i = 0; i < continents.length; i++) if (e.whyNotTravel(i) == null) i];
      final c = open[rng.nextInt(open.length)];
      e.travel(c);
      if (e.bossReady && !s.bossesDown.contains(c) && rng.nextBool()) {
        e.challengeBoss();
      } else {
        e.explore();
      }
      fight(e, rng, a);
      continue;
    }
    // A hardcore player doesn't take a boss on till the odds are good: grow on its land's foes first.
    if (player == 'hc' && (winOdds(e, pick, 12) ?? 1) < hcOdds && k.level < 60) {
      e.travel(e.whyNotTravel(pick.land) == null ? pick.land : s.continent);
      if (!s.day && continents[s.continent].boss.night == false) e.rest();
      e.explore();
      if (s.inBattle) fight(e, rng, a);
      continue;
    }
    final kos = a.knockouts, fought = a.fights;
    take(e, pick, rng, a);
    // Knockouts one after another while the card stays the same: a wall the card keeps sending you at.
    if (a.knockouts > kos) {
      streak++;
      if (streak > worst) worst = streak;
    } else if (a.fights > fought) {
      streak = 0;
    }
    // Night falls and day comes as a player would see it: sleep when it's dark and a boss isn't
    // waiting for the night.
    if (!s.day && !(e.whyNotTravel(pick.land) == null && continents[pick.land].boss.night)) e.rest();
  }
  close();
  policy = was;
  a.won = s.won;
  a.coins = k.coins;
  a.level = k.level;
  if (s.fallen) a.flag('fell at level ${k.level} on "$showing"');
  if (!s.won && !s.fallen) a.flag('never beat Vharrax: stuck on "$showing" ($shownSub) at level ${k.level} after ${a.fights} fights');
  // Steps that hung on, or kept knocking you out.
  for (final st in a.steps) {
    if (st.fights > 120) a.flag('"${st.title}" stayed up ${st.fights} fights (from level ${st.level})');
    if (st.streak >= 4) a.flag('"${st.title}" knocked you out ${st.streak} times running (from level ${st.level})');
  }
  return a;
}

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 6;
  final players = args.length > 1 ? [args[1]] : const ['road', 'cards', 'careless', 'wander'];
  final tally = <String, int>{};
  for (final p in players) {
    var won = 0, fights = 0, kos = 0;
    final byStep = <String, (int, int, int, int)>{};
    for (var seed = 1; seed <= runs; seed++) {
      final a = play(seed, p);
      if (a.won) won++;
      fights += a.fights;
      kos += a.knockouts;
      for (final st in a.steps) {
        final key = st.title.replaceAll(RegExp(r'\d+'), 'N');
        final (n, f, k, l) = byStep[key] ?? (0, 0, 0, 0);
        byStep[key] = (n + 1, f + st.fights, k + st.kos, l + st.level);
      }
      for (final x in a.problems) {
        final key = '[$p] ${x.replaceAll(RegExp(r'level \d+'), 'level N').replaceAll(RegExp(r'\d+ fights'), 'N fights').replaceAll(RegExp(r'\d+ times'), 'N times')}';
        tally[key] = (tally[key] ?? 0) + 1;
      }
      if (seed == 1) {
        print('== $p, seed 1: the Road card, step by step ==');
        for (final st in a.steps) {
          print('  L${st.level.toString().padLeft(2)} f${st.from.toString().padLeft(4)}  ${st.fights.toString().padLeft(3)} fights ${st.kos > 0 ? '${st.kos} KO' : '    '}  ${st.title}${st.sub.isEmpty ? '' : '  · ${st.sub}'}');
        }
        for (final x in a.problems) {
          print('  ! $x');
        }
      }
    }
    print('== $p: where the knockouts were (per game: times shown, fights, knockouts; level when shown) ==');
    for (final e in (byStep.entries.toList()..sort((a, b) => b.value.$3 - a.value.$3)).take(14)) {
      final (n, f, k, l) = e.value;
      print('  ${(k / runs).toStringAsFixed(1).padLeft(5)} KO  ${(f / runs).toStringAsFixed(1).padLeft(5)} fights  L${(l / n).toStringAsFixed(0).padLeft(2)}  ${e.key}');
    }
    print('== $p: $won/$runs beat Vharrax · ${(fights / runs).round()} fights · ${(kos / runs).toStringAsFixed(1)} knockouts a game ==\n');
  }
  if (odds.isNotEmpty) {
    print('== The road player\'s odds against each boss the moment it can first take it on (12 tries from a copy) ==');
    for (final e in (odds.entries.toList()..sort((a, b) => a.value.$2 / a.value.$1 < b.value.$2 / b.value.$1 ? -1 : 1))) {
      final (n, sum, lv) = e.value;
      print('  ${(sum / n * 100).round().toString().padLeft(3)}%  L${(lv / n).toStringAsFixed(0).padLeft(2)}  ${e.key}');
    }
  }
  if (festerSeen.isNotEmpty) {
    final worth = festerSeen.where((x) => x > 0).toList()..sort();
    print('== Fester: ready ${festerSeen.length}× · something to burst ${worth.length}× · burst in swings: median ${worth.isEmpty ? 0 : worth[worth.length ~/ 2].toStringAsFixed(2)}, top 10% ${worth.isEmpty ? 0 : worth[worth.length * 9 ~/ 10].toStringAsFixed(2)} ==');
  }
  print('== Problems, all games (how many games each turned up in) ==');
  final keys = tally.keys.toList()..sort((a, b) => tally[b]! - tally[a]!);
  for (final x in keys) {
    print('  ${tally[x]}×  $x');
  }
}
