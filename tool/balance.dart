// Balance check: plays the whole game for each class with a simple auto-player (it fights,
// equips upgrades, buys armour and potions, rests at the Inn and takes on each boss when it's
// ready) and prints how long fights last, how much they hurt, when each boss falls and how
// often the hero is knocked out. Run: dart run tool/balance.dart
import 'dart:convert';
import 'dart:math';

import '../lib/game/brews.dart';
import '../lib/game/catalog.dart';
import '../lib/game/classes.dart';
import '../lib/game/crafting.dart';
import '../lib/game/engine.dart';
import '../lib/game/loot.dart';
import '../lib/game/models.dart';
import '../lib/game/wilds.dart';
import '../lib/game/dungeons.dart';
import '../lib/game/rules.dart';
import '../lib/game/spells.dart';

class Stats {
  final turns = List.generate(continents.length, (_) => <int>[]);
  final hurt = List.generate(continents.length, (_) => <double>[]);
  final bossTries = List.generate(continents.length, (_) => <int>[]);
  final bossLevel = List.generate(continents.length, (_) => <int>[]);
  final bossTurns = List.generate(continents.length, (_) => <int>[]);
  final bossPotions = List.generate(continents.length, (_) => <int>[]);
  final fightsTo = List.generate(continents.length, (_) => <int>[]);
  int kos = 0, regularKos = 0, fights = 0, finished = 0, potions = 0, jobKos = 0, jobFights = 0, raids = 0, raidKos = 0, encounters = 0;
  final homeAt = [<int>[], <int>[], <int>[]], homeLevel = [<int>[], <int>[], <int>[]];
  final actions = <BattleAction, int>{};
}

/// The auto-player's choice for this turn.
/// The hardest-hitting rite on the hotbar you can afford right now (made the one to cast).
bool riteReady(GameEngine e) {
  for (final id in e.state.knight.rites) {
    if (e.whyNotRite(id) == null) {
      e.state.knight.preparedSpell = id;
      return true;
    }
  }
  return false;
}

BattleAction choose(GameEngine e, String style) {
  final k = e.state.knight, mh = maxHp(k), f = encounterType(e.state.foe, e.state.rare), aloft = f.aloft, kind = f.kind;
  if ((k.hp < mh * .35 || (e.state.heroPoison > 1 && k.hp < mh * .6)) && e.whyNot(BattleAction.potion) == null) return BattleAction.potion;
  if (style == 'blade') return e.whyNot(BattleAction.skill) == null ? BattleAction.skill : BattleAction.attack;
  // A player who reads the foe's card: lean into its weakness, avoid what it shrugs off.
  final bladeOk = !aloft && (kind.resists != AttackStyle.blade || crossbowShare(k) * triangle(kind, AttackStyle.bolt) < resistance * bashMult);
  if (kind.weakTo == AttackStyle.rite && style != 'nocast' && riteReady(e)) return BattleAction.cast;
  if (e.whyNot(BattleAction.skill) == null && bladeOk) return BattleAction.skill;
  // A heavy blow coming and no Bash ready: a potion now if it would hurt.
  if (e.state.foeWindup && k.hp < mh * .6 && e.whyNot(BattleAction.potion) == null) return BattleAction.potion;
  if (style != 'nocast' && riteReady(e) && kind.resists != AttackStyle.rite) return BattleAction.cast;
  if (e.whyNot(BattleAction.pet) == null) return BattleAction.pet;
  // Blade or bolt, whichever lands harder on this foe.
  final blade = (aloft ? aloftMelee : 1) * triangle(kind, AttackStyle.blade);
  final bolt = crossbowShare(k) * (aloft ? aloftShot : 1) * triangle(kind, AttackStyle.bolt);
  return bolt > blade ? BattleAction.shoot : BattleAction.attack;
}

/// Every drop's rarity across the runs, and legendaries found on each land: to keep the rare ones rare.
final rarityTally = <Rarity, int>{};

/// Whether the auto-player also takes on the side lands (pass 'side'), by night.
var side = false;

/// A side land worth a visit: open, its boss still up, and you're its level.
int? sideToDo(GameEngine e) {
  final s = e.state, k = s.knight;
  // The lowest-level one first, as a player would.
  int? best;
  for (var i = mainLands; i < continents.length; i++) {
    if (e.whyNotTravel(i) == null && !s.bossesDown.contains(i) && k.level >= continents[i].minLevel + 2 && (best == null || continents[i].minLevel < continents[best].minLevel)) best = i;
  }
  return best;
}

/// Whether the auto-player uses Mags' brews (pass 'nobrews' to compare without), and how often.
var brews = true;
final brewed = <Brew, int>{};

/// The level each crafted armour tier was forged at, across the runs.
final forgedAt = <String, List<int>>{};
final legendsByLand = <int, int>{};
final fineByArt = <String, int>{};
final lootBySource = <String, int>{}, fightsBySource = <String, int>{}, legendBySource = <String, int>{};

void run(String style, int seed, Stats st, {void Function(GameEngine e, int land)? onBoss}) {
  const cls = HeroClass.knight;
  final e = GameEngine(GameEngine.newGame(heroClass: cls), random: Random(seed), clock: () => DateTime(2026, 6, 1));
  final rng = Random(seed + 7);
  e.takeHobsJob();
  final s = e.state, k = s.knight;
  void loot() {
    for (final g in List.of(s.pendingLoot)) {
      rarityTally[g.rarity] = (rarityTally[g.rarity] ?? 0) + 1;
      if (g.rarity == Rarity.legendary) legendsByLand[s.continent] = (legendsByLand[s.continent] ?? 0) + 1;
      if (g.rarity.index >= Rarity.epic.index) fineByArt['${g.rarity.label[0]} ${g.art}'] = (fineByArt['${g.rarity.label[0]} ${g.art}'] ?? 0) + 1;
      final old = e.equippedFor(g);
      final usable = (g.heroClass == null || g.heroClass == k.heroClass) && e.whyNotWear(g) == null;
      final better = g.slot == GearSlot.armour ? armourTierById(g.art).reduction > armourTierById(k.loadout.armour).reduction : old == null || g.score > old.score;
      if (usable && better) {
        e.equipLoot(g.id);
      } else {
        e.sellLoot(g.id);
      }
    }
    // A tidy player: whatever went into the chest gets sold.
    for (final g in List.of(k.stash)) {
      e.sellFromStash(g.id);
    }
  }

  void shop() {
    for (final t in tiersFor(k.heroClass).skip(1).where((t) => !t.dropOnly)) {
      if (!e.owns(t.id) && k.coins >= e.priceOf(t.id) * 1.1) e.purchase(t.id);
    }
    // The forge: smelt every lump of ore, forge the best armour the bars allow, turn gems into bolts.
    for (final m in Metal.values) {
      e.smelt(m);
    }
    for (final t in tiersFor(k.heroClass).reversed) {
      if (isCrafted(t.id) && e.craftArmour(t.id)) {
        forgedAt.putIfAbsent(t.id, () => <int>[]).add(k.level);
        break;
      }
    }
    for (final g in Gem.values) {
      while (e.fletch(g)) {}
    }
    // (Stops when Mags won't sell: mid-fight, say, after a strongbox ambush.)
    while (k.potions < 4 && k.coins > e.priceOf('potion') * 3) {
      if (!e.purchase('potion')) break;
    }
    if (!k.gloves && k.coins > 200) e.purchase('gloves');
    if (k.coins > e.priceOf('crossbow') * 1.5) e.purchase('crossbow');
    if (k.coins > 500 && k.mounts.isEmpty) e.purchase('mount:pony');
    if (k.coins > 1500) e.purchase('mount:warhorse');
    // Dunstan tempers favourite epic and legendary pieces back up to your level.
    for (final g in e.temperables) {
      if (k.coins > e.temperCost(g) * 1.5) e.temper(g);
    }
    if (k.coins > 1200) {
      final r = e.enchantOffer(EnchantSlot.weapon);
      final cur = k.loadout.weapon?.enchant;
      if (r != null && (cur == null || r.tier >= cur.tier)) e.applyEnchant(EnchantSlot.weapon, r);
    }
  }

  var tries = 0, fights = 0, extra = 0;
  while (fights < 3000 && !s.won) {
    {
      // A sensible spellbook: the biggest damage spell known, Healing Light once it's learned.
      final known = spellsKnown(k.level).map((x) => x.id).toSet();
      // Three on the hotbar, the hardest-hitting first.
      const pref = ['chainlightning', 'dragonfire', 'lifedrain', 'frostnova', 'spectralcharge', 'bloodbolt', 'arcanebolt'];
      k.rites = [for (final id in pref) if (known.contains(id)) id].take(riteSlots).toList();
    }
    // Training, by style: a blade player puts it all into Might and Vigour.
    {
      final plan = switch (style) {
        'blade' => const [Trait.might, Trait.might, Trait.vigour],
        'nocast' => const [Trait.might, Trait.aim, Trait.vigour],
        _ => const [Trait.might, Trait.arcana, Trait.aim, Trait.vigour],
      };
      var i = Trait.values.fold<int>(0, (n, t) => n + trained(k, t));
      while (unspentPoints(k) > 0) {
        e.train(plan[i++ % plan.length]);
      }
    }
    e.repairInn(); // Hob's job, as soon as the timber and iron are in
    // Sleep (and wake to morning), unless a side land's night is still to be fought in.
    if (!side || k.hp < maxHp(k) * .7 || sideToDo(e) == null) e.rest();
    shop();
    if (e.buildHome()) {
      st.homeAt[s.home].add(fights);
      st.homeLevel[s.home].add(k.level);
    }
    // Wards as soon as Mags can make them; the furthest land you're allowed into.
    for (var w = 1; w < continents.length; w++) {
      e.craftWard(w);
    }
    // Mags' brews from what's left over: keep Might, Barkskin and Reaper's Bane going, and top up
    // potions with healing draughts.
    if (brews) {
      for (final b in const [Brew.might, Brew.barkskin, Brew.reaperbane]) {
        if (!brewOn(k, b) || (b != Brew.reaperbane && k.brews[b.name]! < 2)) {
          if (e.brew(b)) brewed[b] = (brewed[b] ?? 0) + 1;
        }
      }
      if (!brewOn(k, Brew.healing) && e.brew(Brew.healing)) brewed[Brew.healing] = (brewed[Brew.healing] ?? 0) + 1;
    }
    var c = s.unlocked;
    while (c > 0 && e.whyNotTravel(c) != null) {
      c--;
    }
    if (side && fights.isEven) c = sideToDo(e) ?? c;
    e.travel(c);
    // Like a sensible player: take the boss on at (about) its level, a bit later after a loss.
    // Bandits in town: always give chase.
    final raid = s.raid != null;
    final boss = !raid && e.bossReady && !s.bossesDown.contains(c) && k.level >= bossLevel(c) - 1 + extra;
    if (raid) {
      e.startRaid();
      st.raids++;
    } else if (boss) {
      e.challengeBoss();
      tries++;
    } else {
      e.explore();
    }
    fights++;
    st.fights++;
    final kind = raid ? 'raid' : (boss ? 'boss' : (s.rare != null ? 'rare' : 'regular'));
    final before = s.pendingLoot.length;
    final onJob = !s.innRepaired;
    if (onJob) st.jobFights++;
    final mh = maxHp(k), p0 = k.potions;
    var turns = 0, taken = 0;
    while (s.inBattle && turns < 200) {
      final a = choose(e, style);
      st.actions[a] = (st.actions[a] ?? 0) + 1;
      // A fair hand on the timing bar: a bullseye now and then, a graze now and then.
      final roll = rng.nextDouble();
      final r = e.takeTurn(a, aim: a == BattleAction.shoot ? (roll < .3 ? bullseye : (roll < .85 ? 1 : graze)) : 1);
      turns++;
      taken += r.counter ?? 0;
      if (r.knockedOut) {
        st.kos++;
        if (!boss) st.regularKos++;
        if (onJob) st.jobKos++;
        if (raid) st.raidKos++;
        if (boss) extra++;
      }
    }
    st.potions += p0 - k.potions;
    if (boss) {
      if (s.bossesDown.contains(c)) {
        if (tries > 0 && onBoss != null) onBoss(e, c);
        st.bossTries[c].add(tries);
        st.bossLevel[c].add(k.level);
        st.bossTurns[c].add(turns);
        st.bossPotions[c].add(p0 - k.potions);
        st.fightsTo[c].add(fights);
        tries = 0;
        extra = 0;
      }
    } else if (s.foeHp <= 0 || !s.inBattle) {
      st.turns[c].add(turns);
      st.hurt[c].add(taken / mh);
    }
    lootBySource[kind] = (lootBySource[kind] ?? 0) + s.pendingLoot.length - before;
    for (final g in s.pendingLoot.skip(before)) {
      if (g.rarity == Rarity.legendary) legendBySource[kind] = (legendBySource[kind] ?? 0) + 1;
    }
    fightsBySource[kind] = (fightsBySource[kind] ?? 0) + 1;
    if (s.encounter != null) {
      final b = s.pendingLoot.length;
      e.resolveEncounter(rng.nextInt(2));
      st.encounters++;
      lootBySource['encounter'] = (lootBySource['encounter'] ?? 0) + s.pendingLoot.length - b;
    }
    loot();
  }
  if (s.won) st.finished++;
}

// ---------------- the wilds ----------------

class WildStats {
  int trips = 0, steps = 0, fights = 0, kos = 0, runs = 0, gold = 0, items = 0, fine = 0, lostGold = 0;
  // The story trail at the same moment, for comparison: gold and fine (epic or better) drops per fight.
  int storyFights = 0, storyGold = 0, storyFine = 0, storyKos = 0;
}

GameEngine _clone(GameEngine e, int seed) {
  final s = GameState.fromJson((jsonDecode(jsonEncode(e.state.toJson())) as Map).cast<String, dynamic>())..pendingLoot.clear();
  return GameEngine(s, random: Random(seed), clock: () => DateTime(2026, 6, 1));
}

int _fine(Iterable<GearItem> gs) => gs.where((g) => g.rarity.index >= Rarity.epic.index).length;

/// Fights until it's over, the way the auto-player does.
bool _fightOut(GameEngine e, Random rng) {
  while (e.state.inBattle) {
    final a = choose(e, 'all');
    final roll = rng.nextDouble();
    final r = e.takeTurn(a, aim: a == BattleAction.shoot ? (roll < .3 ? bullseye : (roll < .85 ? 1 : graze)) : 1);
    if (r.knockedOut) return false;
  }
  return true;
}

/// One trip into wild area [a]: pushes on towards [target] steps, heads home from a waystone
/// once hurt, and runs for it when things go badly.
void wildTrip(GameEngine e, int a, int target, WildStats w, Random rng) {
  final s = e.state, k = s.knight;
  e.rest();
  e.enterWild(a);
  w.trips++;
  final gold0 = k.coins;
  while (true) {
    final mh = maxHp(k);
    if (k.hp < mh * .45) e.drinkPotion();
    final hurt = k.hp < mh * .5 && k.potions == 0;
    if (isWaystone(s.wildDepth) && s.wildDepth > 0 && (s.wildDepth >= target || hurt)) break;
    if (k.hp < mh * .25 && k.potions == 0) {
      w.runs++;
      break;
    }
    final ev = e.stepWild();
    w.steps++;
    if (ev.isFight) {
      w.fights++;
      if (!_fightOut(e, rng)) {
        w.kos++;
        w.gold += k.coins - gold0;
        w.items += s.pendingLoot.length;
        w.fine += _fine(s.pendingLoot);
        s.pendingLoot.clear();
        return;
      }
    } else if (ev != WildEvent.waystone) {
      final choice = switch (ev) {
        WildEvent.thief => k.hp > mh * .5 ? 0 : 1,
        WildEvent.trap => 1,
        WildEvent.pedlar => k.potions < 3 ? 0 : 1,
        WildEvent.hoard => k.hp > mh * .6 ? 0 : 1,
        _ => 0,
      };
      e.resolveWild(choice);
      if (s.inBattle) {
        w.fights++;
        if (!_fightOut(e, rng)) {
          w.kos++;
          w.gold += k.coins - gold0;
          w.items += s.pendingLoot.length;
          w.fine += _fine(s.pendingLoot);
          s.pendingLoot.clear();
          return;
        }
      }
    }
  }
  final exit = e.leaveWild()!;
  w.lostGold += exit.lost.gold;
  w.gold += k.coins - gold0;
  w.items += s.pendingLoot.length;
  w.fine += _fine(s.pendingLoot);
  s.pendingLoot.clear();
}

/// The story trail from the same moment: plain exploring in the newest land, for comparison.
void storyBaseline(GameEngine e, WildStats w, Random rng) {
  final s = e.state, k = s.knight;
  for (var i = 0; i < 20; i++) {
    e.rest();
    final gold0 = k.coins;
    e.explore();
    w.storyFights++;
    if (!_fightOut(e, rng)) w.storyKos++;
    w.storyGold += k.coins - gold0;
    w.storyFine += _fine(s.pendingLoot);
    s.pendingLoot.clear();
  }
}

void wildsReport(int runs) {
  // For each area, the moment it opens (its land's boss falls), try three ways of playing it.
  const targets = {'careful (to step 5)': 5, 'bold (to step 10)': 10, 'greedy (to step 20)': 20};
  for (var a = 0; a < wildAreas.length; a++) {
    final area = wildAreas[a];
    final byPolicy = {for (final t in targets.keys) t: WildStats()};
    final base = WildStats();
    var level = 0, seen = 0;
    for (var i = 0; i < runs; i++) {
      run('all', 2000 + i, Stats(), onBoss: (e, land) {
        if (land != area.opensAfter) return;
        level += e.state.knight.level;
        seen++;
        for (final (j, t) in targets.entries.indexed) {
          for (var trip = 0; trip < 4; trip++) {
            wildTrip(_clone(e, i * 31 + j * 7 + trip), a, t.value, byPolicy[t.key]!, Random(i * 13 + trip));
          }
        }
        final story = _clone(e, i * 97);
        if (land + 1 < mainLands) story.travel(land + 1);
        storyBaseline(story, base, Random(i));
      });
    }
    print('== ${area.name} (opens at level ${(level / max(1, seen)).toStringAsFixed(1)}) ==');
    print('  story trail:            gold/fight ${(base.storyGold / max(1, base.storyFights)).toStringAsFixed(0).padLeft(5)}  epic+/fight ${(base.storyFine / max(1, base.storyFights)).toStringAsFixed(2)}  knockouts ${(base.storyKos / max(1, base.storyFights) * 100).round()}%');
    for (final e in byPolicy.entries) {
      final w = e.value, f = max(1, w.fights);
      print('  ${e.key.padRight(22)}  gold/fight ${(w.gold / f).toStringAsFixed(0).padLeft(5)}  epic+/fight ${(w.fine / f).toStringAsFixed(2)}  steps/trip ${(w.steps / w.trips).toStringAsFixed(1)}  '
          'knocked out ${(w.kos / w.trips * 100).round()}% of trips, ran ${(w.runs / w.trips * 100).round()}%');
    }
  }
}

// ---------------- dungeons ----------------

class DungeonStats {
  int runs = 0, cleared = 0, kos = 0, left = 0, rooms = 0, fights = 0, gold = 0, fine = 0, potions = 0;
}

/// One run into dungeon [d]: picks doors by how hurt it is (quiet ones when low), drinks potions
/// below 45%, and climbs out if it's nearly dead and out of potions.
void dungeonRun(GameEngine e, Dungeon d, DungeonStats w, Random rng) {
  final s = e.state, k = s.knight;
  e.rest();
  final gold0 = k.coins, pots0 = k.potions;
  e.enterDungeon(d.id);
  w.runs++;
  while (!e.dungeonCleared) {
    final mh = maxHp(k);
    while (k.hp < mh * .45 && k.potions > 0) {
      e.drinkPotion();
    }
    if (k.hp < mh * .3 && k.potions == 0) {
      w.left++;
      break;
    }
    final doors = s.dungeonDoors;
    var pick = doors.indexOf(DoorClue.locked.name);
    if (pick < 0 || !s.dungeonKey) {
      final low = k.hp < mh * .55;
      final order = low ? [DoorClue.quiet, DoorClue.glitter, DoorClue.growl, DoorClue.boss] : [DoorClue.glitter, DoorClue.growl, DoorClue.quiet, DoorClue.boss];
      final open = [for (var i = 0; i < doors.length; i++) if (doors[i] != DoorClue.locked.name) i];
      pick = rng.nextDouble() < .5 ? open[rng.nextInt(open.length)] : open.reduce((a, b) => order.indexOf(DoorClue.values.byName(doors[a])) <= order.indexOf(DoorClue.values.byName(doors[b])) ? a : b);
    }
    final out = e.openDoor(pick);
    if (out == null) break;
    w.rooms++;
    if (out.$1.isFight) {
      w.fights++;
      if (!_fightOut(e, rng)) {
        w.kos++;
        break;
      }
    }
  }
  if (e.dungeonCleared) w.cleared++;
  w.gold += k.coins - gold0;
  w.potions += pots0 - k.potions;
  w.fine += _fine(s.pendingLoot);
  s.pendingLoot.clear();
  e.leaveDungeon();
}

void dungeonsReport(int runs) {
  side = true;
  for (final d in dungeons) {
    final w = DungeonStats();
    var level = 0, seen = 0;
    for (var i = 0; i < runs; i++) {
      var done = false;
      run('all', 3000 + i, Stats(), onBoss: (e, land) {
        if (done || !e.state.bossesDown.contains(d.land) || e.state.knight.level < d.minLevel) return;
        done = true;
        level += e.state.knight.level;
        seen++;
        for (var trip = 0; trip < 6; trip++) {
          dungeonRun(_clone(e, i * 31 + trip), d, w, Random(i * 17 + trip));
        }
      });
    }
    final r = max(1, w.runs);
    print('${d.name.padRight(20)} at level ${(level / max(1, seen)).toStringAsFixed(1).padLeft(4)} · runs ${w.runs} · cleared ${(w.cleared / r * 100).round()}% · knocked out ${(w.kos / r * 100).round()}% · climbed out ${(w.left / r * 100).round()}% · '
        'rooms/run ${(w.rooms / r).toStringAsFixed(1)} · gold/run ${(w.gold / r).round()} · epic+/run ${(w.fine / r).toStringAsFixed(2)} · potions/run ${(w.potions / r).toStringAsFixed(1)}');
  }
}

String avg(List<num> xs) => xs.isEmpty ? '-' : (xs.fold<num>(0, (a, b) => a + b) / xs.length).toStringAsFixed(1);
String pct(List<double> xs) => xs.isEmpty ? '-' : '${(xs.reduce((a, b) => a + b) / xs.length * 100).round()}%';

void main(List<String> args) {
  final runs = args.isEmpty ? 20 : int.parse(args.first);
  brews = !args.contains('nobrews');
  side = args.contains('side');
  if (args.contains('wilds')) return wildsReport(runs);
  if (args.contains('dungeons')) return dungeonsReport(runs);
  // 'all' uses every tool; 'nocast' never casts; 'blade' only swings (and bashes): a pure melee
  // knight should still get there, just harder.
  for (final style in const ['all', 'nocast', 'blade']) {
    final st = Stats();
    rarityTally.clear();
    legendsByLand.clear();
    for (var i = 0; i < runs; i++) {
      run(style, 1000 + i, st);
    }
    final drops = rarityTally.values.fold<int>(0, (a, b) => a + b);
    print('  loot per run: ${(drops / runs).toStringAsFixed(0)} items · ${[for (final r in Rarity.values) '${r.label} ${(100 * (rarityTally[r] ?? 0) / drops).toStringAsFixed(1)}%'].join(', ')}');
    if (args.contains('why')) print('  fine by art: ${(fineByArt.entries.toList()..sort((a, b) => b.value - a.value)).take(30).map((e) => '${e.key} ${(e.value / runs).toStringAsFixed(1)}').join(', ')}');
    fineByArt.clear();
    if (args.contains('why')) print('  drops by source (items / fights): ${lootBySource.entries.map((e) => '${e.key} ${(e.value / runs).toStringAsFixed(0)}/${((fightsBySource[e.key] ?? 0) / runs).toStringAsFixed(0)}').join(', ')}');
    if (args.contains('why')) print('  legendaries by source, per run: ${legendBySource.entries.map((e) => '${e.key} ${(e.value / runs).toStringAsFixed(2)}').join(', ')}');
    lootBySource.clear();
    fightsBySource.clear();
    legendBySource.clear();
    print('  legendaries per run, by land: ${[for (var c = 0; c < continents.length; c++) ((legendsByLand[c] ?? 0) / runs).toStringAsFixed(1)].join(' · ')}');
    print('== Knight, $style ($runs runs, ${st.finished} beat Vharrax) ==');
    for (var c = 0; c < continents.length; c++) {
      print('  ${continents[c].name.padRight(22)} turns/foe ${avg(st.turns[c]).padLeft(4)}  hp lost/foe ${pct(st.hurt[c]).padLeft(4)}  '
          'boss: level ${avg(st.bossLevel[c]).padLeft(4)}, tries ${avg(st.bossTries[c])}, turns ${avg(st.bossTurns[c])}, potions ${avg(st.bossPotions[c])}, after ${avg(st.fightsTo[c])} fights');
    }
    final all = st.actions.values.fold<int>(0, (a, b) => a + b);
    print('  cottage built in ${st.homeAt[1].length} runs, at fight ${avg(st.homeAt[1])} (level ${avg(st.homeLevel[1])}) · keep in ${st.homeAt[2].length}, at fight ${avg(st.homeAt[2])} (level ${avg(st.homeLevel[2])})');
    print('  Hob\'s job: ${st.jobKos} knockouts in ${st.jobFights} fights · raids ${st.raids} (${st.raidKos} knockouts) · encounters ${st.encounters}');
    print('  knockouts ${st.kos} (${st.regularKos} by regular foes) in ${st.fights} fights · potions ${st.potions} · actions ${[for (final e in st.actions.entries) '${e.key.name} ${(e.value / all * 100).round()}%'].join(', ')}');
    print('  forged: ${[for (final e in forgedAt.entries) '${e.key} ${e.value.length}× at level ${avg(e.value)}'].join(', ')}');
    print('  brewed per run: ${[for (final e in brewed.entries) '${e.key.name} ${(e.value / runs).toStringAsFixed(1)}'].join(', ')}');
    brewed.clear();
    forgedAt.clear();
  }
}
