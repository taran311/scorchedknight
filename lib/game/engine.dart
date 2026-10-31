// State transitions for every player action. Pure Dart: the Flutter controller calls these, then
// animates the results.
//
// A fight is turn-based: each turn you choose Attack, your class skill, a Potion, your
// companion's command or Flee, and then the foe (if it's still standing) takes its turn.

import 'dart:math' as math;

import 'ammo.dart';
import 'brews.dart';
import 'catalog.dart';
import 'crafting.dart';
import 'classes.dart';
import 'loot.dart';
import 'models.dart';
import 'mounts.dart';
import 'spells.dart';
import 'tarot.dart';
import 'vault.dart';
import 'events.dart';
import 'encounters.dart';
import 'rules.dart';
import 'wilds.dart';
import 'dungeons.dart';

/// What you can do on your turn: swing your blade, your Shield Bash (or Mighty Blow), cast an Ember
/// Rite, shoot your crossbow, drink a potion, command your companion, or run.
enum BattleAction { attack, skill, cast, shoot, potion, pet, flee }

/// A treasure chest and what was inside (the gear also waits in the spoils).
class ChestFind {
  const ChestFind(this.tier, this.coins, this.items, {this.potion = false, this.ammo});

  /// A bundle of special ammunition (rangers), described.
  final String? ammo;
  final ChestTier tier;
  final int coins;
  final List<GearItem> items;
  final bool potion;

  String get summary => [
    '+$coins gold',
    for (final g in items) '${g.name} (${g.rarity.label})',
    if (potion) 'a health potion',
    if (ammo != null) ammo!,
  ].join(', ');
}

class KillResult {
  const KillResult(this.foeIndex, this.name, this.xp, this.coins, this.levelUps, this.loot, {this.egg = false, this.orkGear, this.entGear, this.runeGear, this.prize, this.foe, this.chest, this.companion, this.opened = const [], this.trophy, this.blueprint, this.boss = false, this.won = false, this.reagents = 0, this.jobFind, this.potion = false, this.relicPart, this.packGold = 0, this.packed = const [], this.junkGold = 0, this.jackpot = 0, this.hoard = const [], this.finds = const [], this.breathed = 0, this.key = false, this.clean = false, this.bounty = 0, this.boltBack});

  /// A lucky purse: extra gold on top of the usual (already counted in [coins]).
  final int jackpot;

  /// Gold for junk sold where it fell (see GameEngine.isJunk).
  final int junkGold;
  final int foeIndex;
  final String name;

  /// The foe that fell (a rare variant carries its aura).
  final FoeType? foe;

  /// A treasure chest left behind (now and then; a grand one after a boss).
  final ChestFind? chest;
  final int xp, coins, levelUps;

  /// HP you got back catching your breath after the win.
  final int breathed;

  /// It left a Cinder key, for the Ember Vault.
  final bool key;

  /// A clean kill: your crossbow bolt brought it down. [bounty] is the extra gold (counted in
  /// [coins]); [boltBack] the special bolt you pulled back out of it, if there was one.
  final bool clean;
  final int bounty;
  final AmmoType? boltBack;
  final GearItem? loot;

  /// A dragon egg was found (the Cinderreach's boss).
  final bool egg;

  /// A dragon, ork, ent or the Dragonbone Warden left its class prize (also in the spoils).
  final GearItem? orkGear, entGear, runeGear;

  /// A continent boss's legendary trinket (also in the spoils).
  final GearItem? prize;

  /// A continent boss fell: what joined you, and the continent that opened up.
  final String? companion;
  /// The lands this boss opened the way to.
  final List<int> opened;

  /// A trophy taken ("2× Vampire fang") and a blueprint found, for the victory scroll.
  final String? trophy, blueprint;
  final bool boss;

  /// Vharrax fell for the first time.
  final bool won;

  /// Reagents gathered from this win (for the next continent's ward).
  final int reagents;

  /// For Hob's job: what this foe was carrying ('Charred Timber' or 'Iron Scrap').
  final String? jobFind;

  /// A relic part found on a Heroic trail.
  final String? relicPart;

  /// A dungeon boss's hoard: what was in it (empty for any other foe).
  final List<String> hoard;

  /// Crafting finds, for the victory panel: ('gem', gem name), ('core', element name),
  /// ('ore', metal name), ('scroll', '').
  final List<(String, String)> finds;

  /// It was carrying a health potion.
  final bool potion;

  /// Out in the wilds the gold and gear went into your pack instead: how much gold (depth bonus
  /// included) and which pieces.
  final int packGold;
  final List<GearItem> packed;
  bool get wild => packed.isNotEmpty || packGold > 0;
}

class SwingResult {
  SwingResult(this.action, this.damage, this.miss, this.heroClass, {this.aim = 1, this.edge = 1});

  /// How the blow sat with the foe's weaknesses (above 1: it's weak to it; below: it shrugs it off).
  final double edge;

  /// How well a bolt was aimed on the timing bar (1 a true shot, more a bullseye, less a graze).
  final double aim;

  /// What you did this turn.
  final BattleAction action;
  final SwingDamage damage;
  final bool miss;
  final HeroClass heroClass;
  DragonStage? dragon;

  /// The pet that bit this turn.
  (Pet, PetStage)? pet;
  KillResult? kill;
  int healed = 0;

  /// HP a potion brought back.
  int potion = 0;

  /// You got away (the fight is over, nothing won), or tried and tripped over your own boots.
  bool fled = false, fleeFailed = false;

  /// The foe's blow knocked you out: the fight is lost and you wake at the Inn.
  bool knockedOut = false;
  int goldLost = 0;

  /// Reaper's Bane saved you from this blow: the Reaper came and his scythe went through you.
  bool cheatedDeath = false;

  /// The Bloodmoon Pelt: the wolf came out this turn, or went back in.
  bool wolfed = false, wolfEnded = false;

  /// HP the lizardfolk regrew at the end of the turn, and HP your Sunscale set regrew.
  int regrew = 0, regrown = 0;

  /// Where [regrown] and [mended] came from, in a word for the stage ("Mending", "Horse"...).
  String regrownFrom = '', mendedFrom = '';

  /// Fire and venom (from burning and venom shots) that ate at the foe this turn, and whether a
  /// frost shot froze it out of its next blow.
  int burned = 0, venomed = 0, bled = 0;
  bool froze = false;

  /// A special's stun took (the foe misses its next blow), and the health a special cost you.
  bool specialStun = false;
  int selfHurt = 0;

  /// A lucky moment: an opening for a free extra blow.
  int opening = 0;

  /// A shapeshifter took a new shape this turn (what it became).
  String? shifted;

  /// Out in the wilds: what fell out of your pack as you ran (or as you went down), and, knocked
  /// out, how the trip ended.
  PackLoss? packLoss;
  WildExit? wildExit;

  /// The foe's turn: null if it didn't get one (it fell, or you fled); 0 if it didn't hurt.
  int? counter;

  /// Thorns that struck the foe when it hit you.
  int thorns = 0;

  /// How you met the foe's blow, and your counterattack after a parry.
  Guard? guard;
  int riposte = 0;

  /// Summoned skeletons' blows this turn (and how many fought); HP drained by a drain spell.
  int summonHit = 0, summons = 0, drained = 0;

  /// HP mended by Healing Light (or a unicorn's charge) this turn.
  int mended = 0;

  /// A fairy companion's charm this turn, and what it did (damage to the foe, HP healed).
  FairyCharm? charm;
  int charmHit = 0, charmHeal = 0;

  /// A blow Mirror Ward hurled back at the foe.
  int reflected = 0;

  /// The mounted charge that opens a fight, and the mount.
  int chargeHit = 0;
  Mount? mount;

  /// The off-hand weapon's strike this turn, when dual wielding.
  int offhandHit = 0;

  /// The companion's command this turn (Pounce, Firebreath or a fairy's charm).
  bool command = false;

  /// The knight's Shield Bash left the foe dazed (it skips its blow).
  bool stunned = false;

  /// The foe's blow this turn was a heavy one it wound up; and it's winding up another.
  bool heavy = false, windup = false;

  /// The Guardian's Oath caught the heavy blow.
  bool oath = false;

  /// Its blow poisoned you; poison it did to you this turn; HP it drank from you.
  bool poisoned = false;
  int poisonTick = 0, drank = 0;

  /// A potion cured your poison.
  bool cured = false;

  /// HP the land's hazard took this turn (no ward).
  int hazard = 0;

  /// Damage dealt to the foe this turn, everything included.
  int get dealt =>
      (miss ? 0 : damage.base + damage.effects) + damage.chip + summonHit + offhandHit + riposte + chargeHit + charmHit + reflected + thorns;
}

class GameEngine {
  GameEngine(this.state, {math.Random? random, DateTime Function()? clock}) : _rng = random ?? math.Random(), loot = LootTable(random), clock = clock ?? DateTime.now {
    loot.ng = state.ng;
  }

  /// Today, for seasonal events (swapped out in tests and the simulator).
  final DateTime Function() clock;
  Season get season => seasonOn(clock());

  GameState state;
  final math.Random _rng;

  /// The bolt just loosed brought the foe down (see [cleanKillGold]); and the special bolt it was.
  bool _cleanKill = false;
  AmmoType? _cleanBolt;
  final LootTable loot;

  static GameState newGame({HeroClass? heroClass}) {
    final s = GameState();
    if (heroClass != null) {
      s.knight
        ..heroClass = heroClass
        ..classChosen = true;
    }
    s.knight.hp = maxHp(s.knight);
    s
      ..innRepaired = false
      ..jobTaken = false;
    s.journal.add(JournalEntry('You survived the Great Burning. Soot in your ears, a singed eyebrow, and a seat by the fire at the Soot & Kettle.', EntryKind.good));
    return s;
  }

  /// Adds a line to the journal.
  void note(String text, [EntryKind kind = EntryKind.plain]) => _note(text, kind);

  void _note(String text, [EntryKind kind = EntryKind.plain]) {
    state.journal.add(JournalEntry(text, kind));
    if (state.journal.length > 80) state.journal.removeRange(0, state.journal.length - 80);
  }

  /// [_grantXp] from outside (tests and tools): [n] XP, and any levels it brings.
  int grantXp(int n) => _grantXp(n);

  int _grantXp(int n) {
    final k = state.knight;
    k.xp += n;
    // The companion that fights grows with you (a dragon egg hatches this way too).
    final active = activeCompanion(k);
    if (active == 'dragon') {
      k.dragonXp = k.dragonXp! + n;
    } else if (active != null) {
      k.pets[active] = k.pets[active]! + n;
    }
    var ups = 0;
    while (k.xp >= xpToNext(k)) {
      k.xp -= xpToNext(k);
      k.level++;
      ups++;
      // A rite learned at this level goes straight onto the hotbar, if there's room.
      for (final sp in spells.where((sp) => sp.level == k.level)) {
        if (k.rites.length < riteSlots && !k.rites.contains(sp.id)) {
          k.rites.add(sp.id);
          _note('You learn ${sp.name}. It\'s on your hotbar.', EntryKind.gold);
        } else {
          _note('You learn ${sp.name}. Swap it onto your hotbar in your tent.', EntryKind.gold);
        }
      }
    }
    // A new level patches you up a little, and brings a training point to spend.
    if (ups > 0) {
      _growVault();
      k.hp = math.min(maxHp(k), k.hp + 10 * ups);
      _note('${ups == 1 ? 'A training point' : '$ups training points'} to spend in your tent: Might, Arcana, Aim or Vigour.', EntryKind.gold);
    }
    return ups;
  }

  /// The vault's own pieces grow with their keeper: every one you own, worn or put by, comes up to
  /// your level whenever you gain one (no other gear does; the rest wants replacing or the forge).
  void _growVault() {
    final k = state.knight, lvl = k.level;
    GearItem? grow(GearItem? g) => g != null && g.gearSet == 'vault' && g.level < lvl ? tempered(g, lvl) : g;
    for (final l in k.loadouts.values) {
      l
        ..helm = grow(l.helm)
        ..gloves = grow(l.gloves)
        ..boots = grow(l.boots);
    }
    k
      ..trinket = grow(k.trinket)
      ..ring = grow(k.ring);
    for (final list in [k.stash, state.pack, state.pendingLoot]) {
      for (var i = 0; i < list.length; i++) {
        list[i] = grow(list[i])!;
      }
    }
  }

  // ---------------- the map ----------------

  /// What there is to do in region [c], and how much of it is done: its boss; its places, its
  /// dungeons and the relic parts that turn up there (each done/all).
  ({bool boss, bool risen, int places, int placesAll, int delves, int delvesAll, int parts, int partsAll}) landProgress(int c) {
    final s = state;
    final here = [for (final p in places) if (p.land == c) p], delves = [for (final d in dungeons) if (d.land == c) d], parts = relicPartsOn(c);
    return (
      boss: s.bossesDown.contains(c),
      risen: heroicCleared(c),
      places: here.where((p) => s.explored.contains(p.id)).length,
      placesAll: here.length,
      delves: delves.where((d) => s.dungeonsDone.contains(d.id)).length,
      delvesAll: delves.length,
      parts: parts.where((e) => s.forged.contains(e.$1) || hasRelicPart(s.relicParts, e.$1, e.$2)).length,
      partsAll: parts.length,
    );
  }

  /// Region [c] is cleared: its boss down, every place and dungeon done, every relic part found.
  bool landCleared(int c) {
    final p = landProgress(c);
    return p.boss && p.risen && p.places == p.placesAll && p.delves == p.delvesAll && p.parts == p.partsAll;
  }

  /// Region [c]'s Heroic trail is done: its boss beaten risen (saves from before this was kept
  /// show it by the relic part the risen boss carried), and every part the trail gives found.
  bool heroicCleared(int c) {
    final s = state, risenParts = [for (final (r, i) in relicPartsOn(c)) if (relics[r]!.parts[i].risen) (r, i)];
    bool have((int, int) e) => s.forged.contains(e.$1) || hasRelicPart(s.relicParts, e.$1, e.$2);
    final beaten = s.risenDown.contains(c) || risenParts.any(have);
    return beaten && risenParts.every(have);
  }

  /// Why you can't go to continent [c] yet (null: you can).
  String? whyNotTravel(int c) {
    if (c < 0 || c >= continents.length) return 'No such land';
    final from = openers(c);
    if (from.isNotEmpty && !from.any(state.bossesDown.contains)) {
      return 'Beat ${from.map((f) => '${continents[f].boss.name} (${continents[f].name})').join(' or ')} to find the way';
    }
    final need = continents[c].minLevel;
    if (state.knight.level < need) return 'Reach level $need to enter';
    return null;
  }

  /// Travels to continent [c], if it's open to you and you're its level.
  bool travel(int c) {
    if (state.inBattle || whyNotTravel(c) != null) return false;
    state.continent = c;
    return true;
  }

  /// Why Old Wick can't craft the ward for continent [c] yet (null: she can).
  String? whyNotWard(int c) {
    final land = continents[c];
    if (land.ward == null) return 'Nothing to ward against';
    if (state.warded.contains(c)) return 'You have it';
    final have = state.reagents[c - 1];
    if (have < reagentsForWard) return 'Needs $reagentsForWard ${continents[c - 1].reagent} (you have $have)';
    if (state.knight.coins < wardPrice(c)) return 'Needs ${wardPrice(c)} gold';
    return null;
  }

  /// Old Wick crafts the ward for continent [c] from the last continent's reagents.
  bool craftWard(int c) {
    if (state.inBattle || whyNotWard(c) != null) return false;
    state.reagents[c - 1] -= reagentsForWard;
    state.knight.coins -= wardPrice(c);
    state.warded.add(c);
    _note('Old Wick mutters over the reagents and hands you the ${continents[c].ward}: ${continents[c].hazard!.toLowerCase()} can\'t touch you in ${continents[c].name} now.', EntryKind.gold);
    return true;
  }

  /// Whether the current continent's boss will face you now.
  bool get bossReady => (state.winsToBoss(state.continent) == 0 || state.bossesDown.contains(state.continent)) && !bossAsleep;

  /// The land's boss only comes out at night, and it's day.
  bool get bossAsleep => continents[state.continent].boss.night && state.day;

  /// Sets out into the current continent: a foe from its list steps up, or now and then a rare
  /// foe or a whole pack. Returns the foe you face.
  FoeType explore() {
    final c = state.continent, land = continents[c], all = foeIndexes(c);
    // Some foes only come out at night (and by night, they're most of what's out there).
    final night = !state.day;
    final dayFoes = [for (final i in all) if (!foeAt(i).night) i], nightFoes = [for (final i in all) if (foeAt(i).night) i];
    final idx = nightFoes.isEmpty ? all : (night && _rng.nextDouble() < nightShare ? nightFoes : dayFoes);
    bool awake(String look) => night || !foeAt(lookIndex(look, c)).night;
    final packs = [for (final p in land.packs) if (awake(p.$1)) p], named = [for (final n in land.named) if (awake(n.base)) n];
    final roll = _rng.nextDouble();
    Rare? rare;
    var at = idx[_rng.nextInt(idx.length)];
    if (!state.innRepaired && c == 0) {
      // Hob's job: only goblins for now. Soot Goblins carry off the timber; once that's back,
      // their Warbosses (and the iron) turn up too.
      at = lookIndex(state.timber < timberNeeded || _rng.nextBool() ? 'goblin' : 'goblinChief', 0);
    } else if (season == Season.hallowash && roll < jackChance && idx.any(_canWearJack)) {
      // Hallowash: a scarecrow with a burning pumpkin for a head, lurching along the road.
      final bases = idx.where(_canWearJack).toList();
      at = bases[_rng.nextInt(bases.length)];
      rare = Rare(at, Aura.blazing, name: 'Jack o\' Cinders', look: 'pumpkinhead');
    } else if (_golemFor(c) case final metal?) {
      // A golem pulls itself out of the rock, ore glinting in its back.
      rare = Rare(at, metal.aura, look: metal.golemLook);
      _begin(at, rare);
      final f = encounterType(at, rare);
      _note('The ground shakes. ${_cap(withArticle(f.name))} drags itself up out of the rock, ${metal.ore.toLowerCase()} glinting in its back. Blades glance off it; blunt weapons crush it.', EntryKind.gold);
      return f;
    } else if (_elementalFor(c) case final el?) {
      // An elemental rises out of the land itself.
      rare = Rare(at, el.aura, look: el.look);
      _begin(at, rare);
      final f = encounterType(at, rare);
      _note(
        switch (el) {
          Elemental.ember => 'The ground cracks and glows, and fire pours up out of it into the shape of a man: an Ember Elemental! Fire won\'t hurt it. Frost will, twice over.',
          Elemental.frost => 'The air goes still and bitter, and frost climbs into the shape of a man: a Frost Elemental! Frost won\'t hurt it. Fire will, twice over.',
          Elemental.mire => 'The mud stands up. A Mire Elemental, dripping and stinking! Poison won\'t hurt it. Holy light will, twice over.',
        },
        EntryKind.gold,
      );
      return f;
    } else if (_malricDue(c)) {
      // Sir Malric of the Ashen Order, waiting on the road for you again.
      rare = Rare(at, Aura.blazing, look: malricLook, name: malricName);
      _begin(at, rare);
      _note(_malricMeets[state.malric.clamp(0, _malricMeets.length - 1)], EntryKind.gold);
      return encounterType(at, rare);
    } else if (_rng.nextDouble() < hiddenChance(c, cindervaleClear: state.bossesDown.contains(0))) {
      // The Hidden Ones step out of the ash: one of them, a whole coven, or the Prior himself.
      final r = _rng.nextDouble();
      final look = r < hiddenPriorShare
          ? hiddenPrior
          : r < hiddenPriorShare + hiddenCovenShare
          ? 'hiddenAcolyte'
          : const ['hiddenAcolyte', 'hiddenBlade', 'hiddenHexer'][_rng.nextInt(3)];
      final coven = look != hiddenPrior && r < hiddenPriorShare + hiddenCovenShare;
      rare = Rare(at, Aura.cursed, look: look, name: look == hiddenPrior ? 'The Veiled Prior' : (coven ? 'Hidden Ones Coven' : null), pack: coven);
      _begin(at, rare);
      final f = encounterType(at, rare);
      _note(
        coven
            ? 'Hooded figures step out of the ash all round you, masks white, sickles out. A coven of the Hidden Ones! Sweeping weapons, area spells, special arrows and special attacks hit them all (+50%).'
            : look == hiddenPrior
            ? 'The road goes quiet. A tall figure in a gilded mask waits in your path, scythe in hand: the Veiled Prior of the Hidden Ones. "The Reaper sends his regards."'
            : 'A hooded figure in a white mask steps out of the ash: ${withArticle(f.name)}. The Hidden Ones have found you.',
        EntryKind.gold,
      );
      return f;
    } else if (roll < packChance(c) && packs.isNotEmpty) {
      final (look, name) = packs[_rng.nextInt(packs.length)];
      at = lookIndex(look, c);
      rare = Rare(at, wildAura(foeAt(at)), name: name, pack: true);
    } else if (roll < packChance(c) + rareChance) {
      if (named.isNotEmpty && _rng.nextDouble() < namedRareShare) {
        final n = named[_rng.nextInt(named.length)];
        at = lookIndex(n.base, c);
        rare = Rare(at, n.aura, name: n.name);
      } else {
        rare = Rare(at, Aura.values[_rng.nextInt(Aura.values.length)]);
      }
    }
    _begin(at, rare);
    final f = encounterType(at, rare);
    _note(
      rare == null && f.night
          ? 'Night in ${land.name}. ${_cap(withArticle(f.name))} comes out of the dark!'
          : rare == null
          ? 'You head out into ${land.name}. ${_cap(withArticle(f.name))} blocks the way!'
          : rare.pack
          ? 'You head out into ${land.name}, and ${withArticle(f.name.toLowerCase())} surrounds you! Sweeping weapons, area spells, special arrows and special attacks hit them all (+50%).'
          : 'You head out into ${land.name}. A rare foe: ${f.name}!',
      rare == null ? EntryKind.plain : EntryKind.gold,
    );
    return f;
  }

  /// Whether Sir Malric is waiting on the road into land [c]: only on the road, only once Hob's job
  /// is done, and each meeting no sooner than its land.
  bool _malricDue(int c) {
    final met = state.malric;
    return met < malricLands.length && !isSideLand(c) && c >= malricLands[met] && state.innRepaired && _rng.nextDouble() < malricChance;
  }

  static const _malricMeets = [
    'A rider in blackened plate blocks the road, embers glowing in the slits of his helm. "Sir Malric, of the Ashen Order. The Ember King has heard of a sooty little knight. He sent me to see if you\'re worth burning."',
    '"You again." Sir Malric draws his greatsword, and it catches fire along the edge. "I told the Order you were nobody. Don\'t make a liar of me."',
    '"Third time." Sir Malric doesn\'t bother with a speech. He just salutes you with a burning blade, and charges.',
    'Sir Malric waits at the edge of the Ember King\'s realm, alone, his Order\'s banner burning behind him. "No more yielding. One of us walks on from here."',
  ];

  // ---------------- places on the map ----------------

  /// Places that show on the map: their land is open, and the hidden one once all the rest are
  /// explored.
  bool placeShown(Place p) {
    final from = openers(p.land);
    final open = from.isEmpty || from.any(state.bossesDown.contains);
    // A relic guardian only shows while you hold the blueprint and still need what it guards.
    if (p.relic case (final r, final i) when !relicPartWanted(r, i) && !state.explored.contains(p.id)) return false;
    return open && (!p.hidden || places.every((o) => o.hidden || o.relic != null || state.explored.contains(o.id)));
  }

  /// Why you can't explore place [id] now (null: you can).
  String? whyNotExplore(String id) {
    final p = placeById(id);
    if (p == null) return 'No such place';
    if (state.explored.contains(id)) return 'Explored';
    if (state.inBattle) return 'Not mid-fight';
    if (!placeShown(p)) return 'Not found yet';
    final travel = whyNotTravel(p.land);
    if (travel != null) return travel;
    final foe = p.foe;
    if (foe != null && state.day && foeAt(lookIndex(foe.$1, p.land)).night) return 'Its guard only comes out at night';
    return null;
  }

  /// Explores place [id]. A guarded place starts the fight with its guard (null comes back: win it
  /// to claim the place); anything else is claimed at once, and what happened comes back.
  String? explorePlace(String id) {
    if (whyNotExplore(id) != null) return null;
    final p = placeById(id)!;
    state.continent = p.land;
    final foe = p.foe;
    if (foe != null) {
      final at = lookIndex(foe.$1, p.land);
      final rare = Rare(at, foe.$3, name: foe.$4, look: foe.$2);
      _begin(at, rare, above: p.above);
      state.place = p.id;
      _note('${p.name}. ${p.blurb} ${foe.$4} stands in your way!', EntryKind.gold);
      return null;
    }
    state.explored.add(p.id);
    _note('${p.name}. ${p.blurb}', EntryKind.gold);
    _note(p.after, EntryKind.gold);
    final got = _placeReward(p);
    return '${p.blurb}\n\n${p.after}${got.isEmpty ? '' : '\n\n${got.join(' · ')}'}';
  }

  /// What a place gives the first time: returns it as short lines ("+240 gold", "2 health potions").
  List<String> _placeReward(Place p) {
    final k = state.knight, got = <String>[];
    if (p.purses > 0) {
      final gold = p.purses * 5 * (6 + 3 * k.level);
      k.coins += gold;
      got.add('+$gold gold');
    }
    if (p.potions > 0) {
      _givePotions(p.potions);
      got.add('${p.potions} health potion${p.potions == 1 ? '' : 's'}');
    }
    for (final e in p.ore.entries) {
      final m = Metal.values.byName(e.key);
      state.addMat(oreKey(m), e.value);
      got.add('${e.value} ${m.ore.toLowerCase()}');
    }
    for (var i = 0; i < p.gems; i++) {
      final g = Gem.values[_rng.nextInt(Gem.values.length)];
      state.addMat(gemKey(g), 1);
      got.add(withArticle(g.label.toLowerCase()));
    }
    if (p.brew case final name?) {
      final b = Brew.values.byName(name);
      k.brews[b.name] = b == Brew.reaperbane ? 1 : brewFights;
      got.add(b.label);
    }
    final trophy = Trophy.values.byName(landTrophyName(p.land) ?? 'ashenSteel');
    if (p.trophies > 0) {
      state.addMat(trophyKey(trophy), p.trophies);
      got.add('${p.trophies} ${trophy.label.toLowerCase()}');
    }
    if (p.legendary) {
      final g = loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: const [0, 0, 0, 0, 1]);
      state.pendingLoot.add(g);
      got.add(g.name);
    }
    if (got.isNotEmpty) _note('You find: ${got.join(', ')}.', EntryKind.gold);
    return got;
  }

  // ---------------- town raids ----------------

  /// After a win out in the wilds, now and then bandits hit the town while you're away. Never
  /// twice in a row: [raidCalm] wins have to pass first.
  void _maybeRaid() {
    final s = state;
    if (s.raid != null) {
      // Left too long, the bandits get clean away.
      if (s.raidSeen && --s.raidCalm <= raidCalm - 3) {
        s.raid = null;
        _note('Word from town: the bandits got clean away. Maybe next time.');
      }
      return;
    }
    // Not while Hob's first job is under way: one thing at a time.
    if (!s.jobTaken || !s.innRepaired) return;
    if (s.raidCalm > 0) {
      s.raidCalm--;
      return;
    }
    if (_rng.nextDouble() < raidChance) {
      s.raid = s.innRepaired && _rng.nextBool() ? 'inn' : 'stall';
      s.raidSeen = false;
      s.raidCalm = raidCalm;
    }
  }

  /// Chases down the bandits who raided the town: a band of them, carrying a gilded haul.
  bool startRaid() {
    if (state.inBattle || state.raid == null) return false;
    final at = lookIndex('rogue', 0);
    _begin(at, Rare(at, Aura.gilded, name: 'Bandit Gang', pack: true));
    state.raidFight = true;
    _note(
      state.raid == 'inn'
          ? 'You catch the bandits in the lane behind the Soot & Kettle, arms full of Hob\'s silver!'
          : 'You catch the bandits at the edge of the square, Mags\' stock bulging in their sacks!',
      EntryKind.gold,
    );
    return true;
  }

  /// Lets the bandits go (they get away with it).
  void letRaidGo() {
    if (state.raid == null) return;
    state.raid = null;
    _note('You let the bandits go. Somebody else\'s problem.');
  }

  // ---------------- heroic trails and relics ----------------

  /// A land's Heroic trail opens once its boss is down.
  bool heroicOpen(int c) => state.bossesDown.contains(c);

  /// The next fight on the current land's Heroic trail: an elite, or at the end the boss, risen.
  FoeType exploreHeroic() {
    final c = state.continent, idx = foeIndexes(c);
    final Rare rare;
    final int at;
    if ((state.heroicWins[c] ?? 0) >= heroicStops) {
      at = bossIndex(c);
      rare = Rare(at, Aura.ancient, name: '${continents[c].boss.name}, Risen');
    } else {
      at = idx[_rng.nextInt(idx.length)];
      rare = Rare(at, Aura.values[_rng.nextInt(Aura.values.length)]);
    }
    _begin(at, rare, above: heroicLevels);
    state.heroicFight = true;
    final f = encounterType(at, rare);
    _note(f.boss ? '${f.name} claws its way back out of the ash!' : 'Heroic trail: ${withArticle(f.name)} bars the way!', EntryKind.gold);
    return f;
  }

  /// A win on a Heroic trail: a step along it (or, for the risen boss, back to the start), and
  /// perhaps the next part of the land's relic.
  String? _heroicWin(int c, bool risen) {
    state.heroicWins[c] = risen ? 0 : (state.heroicWins[c] ?? 0) + 1;
    if (risen) state.risenDown.add(c);
    // A risen boss always carries the relic part it's keeping (if you hold that relic's blueprint).
    if (!risen) return null;
    for (final (r, i) in relicPartsOn(c)) {
      if (relics[r]!.parts[i].risen && _grantPart(r, i)) return relics[r]!.parts[i].name;
    }
    return null;
  }

  /// Whether part [i] of relic [r] is still wanted: its blueprint found, the part not yet in hand,
  /// the relic not yet forged.
  bool relicPartWanted(int r, int i) => !state.forged.contains(r) && state.bossesDown.contains(r) && !hasRelicPart(state.relicParts, r, i);

  /// Hands over part [i] of relic [r], if it's still wanted.
  bool _grantPart(int r, int i) {
    if (!relicPartWanted(r, i)) return false;
    final relic = relics[r]!, part = relic.parts[i];
    state.relicParts[r] = (state.relicParts[r] ?? 0) | (1 << i);
    final found = relicPartsFound(state.relicParts, r);
    _note('You have the ${part.name}! ($found of ${relic.parts.length} parts of ${relic.name})', EntryKind.gold);
    if (found == relic.parts.length) _note('That\'s every part of ${relic.name}. Take them to Dunstan\'s forge.', EntryKind.gold);
    return true;
  }

  /// Why Dunstan can't forge land [c]'s relic yet (null if she can).
  String? whyNotForge(int c) {
    final relic = relics[c];
    if (relic == null) return 'No relic here';
    if (state.forged.contains(c)) return 'Already forged';
    if (!heroicOpen(c)) return 'Find the blueprint first';
    final have = relicPartsFound(state.relicParts, c);
    if (have < relic.parts.length) return 'Parts $have/${relic.parts.length}';
    if (state.knight.level < relic.minLevel) return 'Reach level ${relic.minLevel} to wield it';
    if (state.knight.coins < relic.gold) return 'Needs ${relic.gold} gold';
    return null;
  }

  /// Dunstan forges the relic: it goes into your spoils, to wear or keep.
  GearItem? forgeRelic(int c) {
    if (whyNotForge(c) != null) return null;
    final relic = relics[c]!, k = state.knight;
    k.coins -= relic.gold;
    state.forged.add(c);
    final item = loot.relicWeapon(c, k.level, k.heroClass);
    state.pendingLoot.add(item);
    _note('Dunstan works the forge all night. At dawn he hands you ${item.name}, still smoking. "Don\'t say I never make you anything."', EntryKind.gold);
    return item;
  }

  // ---------------- the wilds ----------------

  /// Wild area [a] opens once the boss of its land falls.
  /// Open once its land's boss has fallen (or any boss further along the road).
  bool wildOpen(int a) => state.bossesDown.any((b) => b >= wildAreas[a].opensAfter);

  /// Why you can't head into wild area [a] (null if you can).
  String? whyNotWild(int a) {
    if (!wildOpen(a)) return 'Opens when ${continents[wildAreas[a].opensAfter].boss.name} falls';
    if (state.inBattle) return 'You\'re in a fight';
    if (state.wild != null && state.wild != a) return 'You\'re already out in ${wildAreas[state.wild!].name}';
    return null;
  }

  /// Sets off into wild area [a] with an empty pack (or carries on a trip already under way).
  bool enterWild(int a) {
    if (whyNotWild(a) != null) return false;
    if (state.wild == a) return true;
    state
      ..wild = a
      ..wildDepth = 0
      ..packGold = 0
      ..pack = []
      ..wildEvent = null
      ..wildFight = false
      ..wildAlert = false
      ..warlordMet = false;
    _note('You step off the road into ${wildAreas[a].name}. Whatever you find out here, you\'ll have to carry home.', EntryKind.gold);
    return true;
  }

  /// The area you're out in, if any.
  WildArea? get wildArea => state.wild == null ? null : wildAreas[state.wild!];

  /// The step waiting on your choice, if any.
  WildEvent? get wildEvent => WildEvent.values.where((e) => e.name == state.wildEvent).firstOrNull;

  /// What leaving right now would cost: nothing at a waystone, [fleeLoss] of the pack elsewhere.
  double get leaveShare => isWaystone(state.wildDepth) && state.wildEvent == null ? 0 : fleeLoss;

  /// One step deeper into the unknown. Returns what you came across: a fight (already begun; open
  /// the battle screen), a waystone, or something waiting on your choice (see [resolveWild]).
  WildEvent stepWild() {
    assert(state.wild != null && !state.inBattle && state.wildEvent == null);
    final s = state, a = wildArea!;
    s.wildDepth++;
    if (s.wildDepth > (s.wildBest[s.wild!] ?? 0)) s.wildBest[s.wild!] = s.wildDepth;
    if (isWaystone(s.wildDepth)) {
      _note('Step ${s.wildDepth}: a waystone. From here you can head home with everything in your pack.', EntryKind.good);
      return WildEvent.waystone;
    }
    late WildEvent e;
    if (s.wildAlert) {
      s.wildAlert = false;
      e = WildEvent.pack;
    } else {
      final w = wildWeights(s.wildDepth, pack: s.packGold > 0 || s.pack.isNotEmpty, warlordMet: s.warlordMet);
      var roll = _rng.nextDouble() * w.values.reduce((x, y) => x + y);
      e = w.keys.last;
      for (final entry in w.entries) {
        if (roll < entry.value) {
          e = entry.key;
          break;
        }
        roll -= entry.value;
      }
    }
    if (e.isFight) {
      _wildFight(e, a, bandits: e == WildEvent.pack && _rng.nextBool());
    } else {
      s.wildEvent = e.name;
      _note('Step ${s.wildDepth}: ${e.title.toLowerCase()}.');
    }
    return e;
  }

  /// Starts a fight out in the wilds: a foe from the area's lands (bandits most of all), a rare
  /// one, a pack, or the warlord, tougher the deeper you are.
  void _wildFight(WildEvent e, WildArea a, {bool bandits = false}) {
    final s = state;
    final pool = [
      for (final l in a.lands) ...foeIndexes(l),
      for (final b in a.bandits) ...[lookIndex(b, 0), lookIndex(b, 0)],
    ];
    var at = pool[_rng.nextInt(pool.length)];
    Rare? rare;
    String line;
    switch (e) {
      case WildEvent.warlord:
        final (name, base, aura) = a.warlord;
        at = lookIndex(base);
        rare = Rare(at, aura, name: name);
        s.warlordMet = true;
        line = '$name, who rules these wilds, steps out to see who\'s been killing his people!';
      case WildEvent.pack:
        if (bandits) {
          at = lookIndex('rogue', 0);
          rare = Rare(at, Aura.gilded, name: 'Bandit Gang', pack: true);
        } else {
          final packs = [for (final l in a.lands) ...continents[l].packs];
          final (look, name) = packs[_rng.nextInt(packs.length)];
          at = lookIndex(look);
          rare = Rare(at, wildAura(foeAt(at)), name: name, pack: true);
        }
        line = 'A ${rare.name!.toLowerCase()} surrounds you!';
      case WildEvent.rare:
        rare = Rare(at, Aura.values[_rng.nextInt(Aura.values.length)]);
        line = 'Something rare prowls here: ${rare.type.name}!';
      default:
        line = '${_cap(withArticle(foeAt(at).name))} comes out of the ash!';
    }
    _begin(at, rare, above: wildLevels(s.wildDepth, s.wild!));
    s.wildFight = true;
    _note('Step ${s.wildDepth}: $line', rare == null ? EntryKind.plain : EntryKind.gold);
  }

  /// Answers the step waiting on you with choice 0 or 1. Returns what happened, in a line. (A
  /// cutpurse you chase leaves a fight under way: open the battle screen.)
  String resolveWild(int choice) {
    final e = wildEvent;
    if (e == null || state.inBattle) return '';
    state.wildEvent = null;
    final s = state, k = s.knight, mh = maxHp(k), d = s.wildDepth;
    String out;
    switch ((e, choice)) {
      case (WildEvent.chest, 0):
        final gold = chestGold(k.level, d);
        if (_rng.nextDouble() < .8) {
          s.packGold += gold;
          var line = 'Gold, and plenty of it. (+$gold gold to your pack)';
          if (_rng.nextDouble() < .3) {
            final g = loot.roll(k.heroClass, k.level + wildGearLift(d), wielding: k.loadout.weapon, odds: wildOdds(d));
            s.pack.add(g);
            line = 'Gold, and under it ${g.name} (${g.rarity.label}). (+$gold gold to your pack)';
          }
          out = line;
        } else {
          final hurt = math.min(k.hp - 1, (mh * .15).round());
          k.hp -= hurt;
          s.packGold += gold ~/ 2;
          out = 'A needle springs out of the lock. Your hand goes numb, but you shake out some coins. (−$hurt HP, +${gold ~/ 2} gold to your pack)';
        }
        s.chestsOpened++;
      case (WildEvent.thief, 0):
        final at = lookIndex('rogue', 0);
        _begin(at, Rare(at, Aura.gilded, name: 'Cutpurse'), above: wildLevels(d, s.wild!));
        s.wildFight = true;
        out = '"Oi!" He bolts, then thinks better of it and draws a knife. He\'s carrying a fat purse of someone else\'s gold.';
      case (WildEvent.thief, _):
        final took = (s.packGold * thiefTake).floor();
        s.packGold -= took;
        out = took > 0 ? 'He tips his hat and strolls off with a handful of your gold. (−$took gold from your pack)' : 'He rummages, finds nothing, looks at you with deep pity, and leaves.';
      case (WildEvent.trap, 0):
        if (_rng.nextDouble() < .55) {
          final gold = (chestGold(k.level, d) * .6).round();
          s.packGold += gold;
          final flask = _rng.nextDouble() < .25;
          if (flask) _givePotions();
          out = 'Behind a stump: the trapper\'s stash. (+$gold gold to your pack${flask ? ', and a health potion' : ''})';
        } else {
          final hurt = math.min(k.hp - 1, (mh * .12).round());
          k.hp -= hurt;
          out = 'The wire was only the first snare. The second one finds your ankle. (−$hurt HP)';
        }
      case (WildEvent.campfire, 0):
        final before = k.hp;
        k.hp = math.min(mh, k.hp + (mh * campfireHeal).round());
        final back = _rng.nextDouble() < .2;
        if (back) s.wildAlert = true;
        out = 'The stew is lentils and wild garlic, and it\'s perfect. (+${k.hp - before} HP)${back ? ' Then you hear voices coming back up the path. Whoever owns this fire wants it back.' : ''}';
      case (WildEvent.pedlar, 0):
        final price = pedlarPrice(k.level);
        if (k.potions >= potionBelt) {
          out = '"Your belt\'s already full, friend!" Pip looks almost offended. (Your belt holds $potionBelt.)';
        } else if (s.packGold >= price) {
          s.packGold -= price;
          _givePotions();
          out = 'Pip counts the coins out of your pack and hands over a potion. (−$price gold from your pack, +1 potion)';
        } else if (k.coins >= price) {
          k.coins -= price;
          _givePotions();
          out = 'Pip takes your own coin, the pack being a bit light. (−$price gold, +1 potion)';
        } else {
          out = '"No coin, no potion." Pip shrugs his enormous pack and trudges off.';
        }
      case (WildEvent.traveller, 0):
        final xp = 12 * k.level, gold = (5 * k.level * wildGold(d)).round();
        final ups = _grantXp(xp);
        s.packGold += gold;
        out = 'You walk them all the way to the road. They insist on paying you, and tell you three stories on the way. (+$xp XP${ups > 0 ? ', level up!' : ''}, +$gold gold to your pack)';
      case (WildEvent.traveller, _):
        final xp = 4 * k.level;
        _grantXp(xp);
        out = 'You turn their map the right way up and point. They look at it, then at you, with total wonder. (+$xp XP)';
      case (WildEvent.hoard, 0):
        final gold = hoardGold(k.level, d);
        final g = loot.roll(k.heroClass, k.level + wildGearLift(d), wielding: k.loadout.weapon, odds: wildOdds(d + 4));
        s.packGold += gold;
        s.pack.add(g);
        s.wildAlert = true;
        out = 'You stuff your pack until the seams creak: $gold gold and ${g.name} (${g.rarity.label}). Somewhere close, someone shouts. They know. (The next step will be a fight.)';
      case (WildEvent.hoard, _):
        final gold = (hoardGold(k.level, d) * .35).round();
        s.packGold += gold;
        out = 'You take a quiet handful and slip away before anyone comes back. (+$gold gold to your pack)';
      default:
        out = switch (e) {
          WildEvent.chest => 'You leave the chest be. It looks almost disappointed.',
          WildEvent.trap => 'You step carefully over the wire and carry on.',
          WildEvent.campfire => 'You leave the stew. It\'s hard, but you do it.',
          WildEvent.pedlar => '"Your loss!" Pip calls after you. "Potions are going UP next week!"',
          _ => 'You move on.',
        };
    }
    _note(out, EntryKind.gold);
    return out;
  }

  /// Heads home from the wilds: everything from a waystone, the rest of the pack otherwise (see
  /// [leaveShare]). The haul waits in your spoils, to wear or sell.
  WildExit? leaveWild() {
    if (state.wild == null || state.inBattle) return null;
    final share = leaveShare;
    final lost = _dropFromPack(share);
    if (!lost.none) _note('You run for it. Bandits shadow you all the way to the road, snatching at your pack: ${lost.summary} gone.', EntryKind.damage);
    return _bankPack(lost, safe: share == 0);
  }

  /// Drinks a potion between fights.
  /// Potions into your belt, up to [potionBelt]; the rest are left where they lie.
  void _givePotions([int n = 1]) {
    final k = state.knight, room = math.max(0, potionBelt - k.potions), got = math.min(n, room);
    k.potions += got;
    if (got < n) _note('Your potion belt is full ($potionBelt): you leave ${n - got == 1 ? 'one' : '${n - got}'} behind.');
  }

  int drinkPotion() {
    final k = state.knight;
    if (state.inBattle || k.potions <= 0 || k.hp >= maxHp(k)) return 0;
    k.potions--;
    final before = k.hp;
    k.hp = math.min(maxHp(k), k.hp + potionHeal(k));
    _note('You drink a health potion: +${k.hp - before} HP.', EntryKind.good);
    return k.hp - before;
  }

  /// Drops [share] of the pack: that much of the gold, and that many pieces of gear, at random.
  PackLoss _dropFromPack(double share) {
    final s = state;
    final (gold, n) = lossOf(share, s.packGold, s.pack.length);
    s.packGold -= gold;
    final names = <String>[];
    for (var i = 0; i < n && s.pack.isNotEmpty; i++) {
      names.add(s.pack.removeAt(_rng.nextInt(s.pack.length)).name);
    }
    return PackLoss(gold, names);
  }

  /// Brings what's left in the pack home: the gold into your purse, the gear into your spoils.
  WildExit _bankPack(PackLoss lost, {required bool safe}) {
    final s = state, k = s.knight;
    final exit = WildExit(gold: s.packGold, items: s.pack.length, lost: lost, depth: s.wildDepth, safe: safe);
    k.coins += s.packGold;
    s.pendingLoot.addAll(s.pack);
    _note(
      exit.gold == 0 && exit.items == 0
          ? 'You come out of ${wildAreas[s.wild!].name} with nothing to show for it but scratches.'
          : 'You come out of ${wildAreas[s.wild!].name} after ${s.wildDepth} steps with ${exit.gold} gold${exit.items > 0 ? ' and ${exit.items == 1 ? 'a piece' : '${exit.items} pieces'} of gear' : ''}.',
      EntryKind.gold,
    );
    s
      ..wild = null
      ..wildDepth = 0
      ..packGold = 0
      ..pack = []
      ..wildEvent = null
      ..wildFight = false
      ..wildAlert = false
      ..warlordMet = false;
    return exit;
  }

  /// The wilds this hero should try when a land's trail has knocked them flat a few times: the
  /// toughest one open (null if none, or they're not struggling on land [c]).
  int? wildHint(int c) {
    if ((state.struggle[c] ?? 0) < struggleHint) return null;
    for (var a = wildAreas.length - 1; a >= 0; a--) {
      if (wildOpen(a)) return a;
    }
    return null;
  }

  // ---------------- dungeons ----------------

  /// A dungeon opens once its land's boss is down.
  bool dungeonOpen(Dungeon d) => state.bossesDown.contains(d.land);

  /// Why you can't go into dungeon [id] now (null: you can, or you're already in it).
  String? whyNotDungeon(String id) {
    final d = dungeonById(id);
    if (d == null) return 'No such place';
    if (!dungeonOpen(d)) return 'Opens when ${continents[d.land].boss.name} falls';
    if (state.dungeon == id) return null;
    if (state.knight.level < d.minLevel) return 'Reach level ${d.minLevel} to go down';
    if (state.inBattle) return 'Not mid-fight';
    if (state.wild != null) return 'You\'re out in ${wildAreas[state.wild!].name}';
    if (state.dungeon != null) return 'You\'re already down in ${dungeonById(state.dungeon)!.name}';
    return null;
  }

  /// Goes down into dungeon [id] (or carries on a run already under way there).
  bool enterDungeon(String id) {
    if (whyNotDungeon(id) != null) return false;
    if (state.dungeon == id) return true;
    final d = dungeonById(id)!;
    state
      ..dungeon = id
      ..dungeonRoom = 0
      ..dungeonKey = false
      ..dungeonFight = false
      ..continent = d.land;
    state.dungeonPath.clear();
    _rollDoors();
    _note('You go down into ${d.name}. ${d.blurb}', EntryKind.gold);
    return true;
  }

  Dungeon? get dungeonNow => dungeonById(state.dungeon);

  /// The boss is down and the hoard is yours: all that's left is the way out.
  bool get dungeonCleared => state.dungeon != null && state.dungeonRoom > dungeonRooms;

  /// The doors in front of you now.
  List<DoorClue> get dungeonDoors => [for (final d in state.dungeonDoors) DoorClue.values.byName(d)];

  void _rollDoors() {
    final s = state;
    s.dungeonDoors.clear();
    if (s.dungeonRoom > dungeonRooms) return;
    if (s.dungeonRoom == dungeonRooms) {
      s.dungeonDoors.add(DoorClue.boss.name);
      return;
    }
    final n = _rng.nextBool() ? 3 : 2;
    final total = doorWeights.values.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < n; i++) {
      var r = _rng.nextDouble() * total;
      for (final e in doorWeights.entries) {
        r -= e.value;
        if (r <= 0) {
          s.dungeonDoors.add(e.key.name);
          break;
        }
      }
      if (s.dungeonDoors.length <= i) s.dungeonDoors.add(DoorClue.growl.name);
    }
    if (_rng.nextDouble() < lockedChance) s.dungeonDoors[_rng.nextInt(n)] = DoorClue.locked.name;
  }

  /// Why door [i] won't open (null: it will).
  String? whyNotDoor(int i) {
    final s = state;
    if (s.dungeon == null || i < 0 || i >= s.dungeonDoors.length) return 'No such door';
    if (s.inBattle) return 'Not mid-fight';
    if (s.dungeonDoors[i] == DoorClue.locked.name && !s.dungeonKey) return 'Locked. Find a key.';
    return null;
  }

  /// Opens door [i] and steps through. A fight room begins its fight (open the battle screen);
  /// anything else is dealt with at once. What it was, and what happened, come back.
  (RoomKind, String)? openDoor(int i) {
    if (whyNotDoor(i) != null) return null;
    final s = state, d = dungeonNow!;
    final clue = DoorClue.values.byName(s.dungeonDoors[i]);
    final kind = roomBehind(clue, _rng.nextDouble(), hasKey: s.dungeonKey);
    s.dungeonPath.add(kind.name);
    if (kind.isFight) {
      s.dungeonDoors.removeAt(i);
      return (kind, _dungeonFight(d, kind));
    }
    final text = _dungeonRoom(kind);
    s.dungeonRoom++;
    _rollDoors();
    return (kind, text);
  }

  /// Starts the fight behind a door: one of the dungeon's foes (an elite one with an aura), or its
  /// boss.
  String _dungeonFight(Dungeon d, RoomKind kind) {
    final s = state;
    final int at;
    Rare? rare;
    if (kind == RoomKind.boss) {
      final (name, base, look, aura) = d.boss;
      at = lookIndex(base, d.land);
      rare = Rare(at, aura, name: name, look: look);
    } else {
      at = lookIndex(d.foes[_rng.nextInt(d.foes.length)], d.land);
      if (kind == RoomKind.elite) rare = Rare(at, Aura.values[_rng.nextInt(Aura.values.length)]);
    }
    _begin(at, rare, above: dungeonLevels(s.dungeonRoom, kind, s.knight.level));
    s.dungeonFight = true;
    final f = encounterType(at, rare);
    final line = switch (kind) {
      RoomKind.boss => '${f.name} rises to meet you. This is their hall, and you are in it.',
      RoomKind.elite => 'Something big waits in the dark: ${withArticle(f.name)}!',
      RoomKind.ambush => 'It was too quiet. ${_cap(withArticle(f.name))} drops on you from the dark!',
      _ => '${_cap(withArticle(f.name))} is waiting behind the door.',
    };
    _note(line, kind == RoomKind.fight ? EntryKind.plain : EntryKind.gold);
    return line;
  }

  /// A room with no fight in it: what's there, and what it did.
  String _dungeonRoom(RoomKind kind) {
    final s = state, k = s.knight, mh = maxHp(k), room = s.dungeonRoom;
    final String text;
    switch (kind) {
      case RoomKind.treasure:
        final gold = treasureGold(k.level, room);
        k.coins += gold;
        final finds = ['+$gold gold'];
        if (_rng.nextDouble() < treasureGearChance) {
          final g = loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: treasureOdds);
          s.pendingLoot.add(g);
          finds.add(g.name);
        }
        if (_rng.nextDouble() < .3) {
          final gem = Gem.values[_rng.nextInt(Gem.values.length)];
          s.addMat(gemKey(gem), 1);
          finds.add(withArticle(gem.label.toLowerCase()));
        }
        text = 'A chest in the corner, and nobody watching it. ${finds.join(' · ')}';
      case RoomKind.trap:
        final tale = trapTales[_rng.nextInt(trapTales.length)];
        if (_rng.nextDouble() < trapSpot) {
          text = tale.$2;
        } else {
          final before = k.hp;
          k.hp = math.max(1, k.hp - (mh * (trapHurtMin + _rng.nextDouble() * (trapHurtMax - trapHurtMin))).round());
          text = '${tale.$1} −${before - k.hp} HP';
        }
      case RoomKind.shrine:
        final before = k.hp;
        k.hp = math.min(mh, k.hp + (mh * shrineHeal).round());
        final potion = _rng.nextDouble() < shrinePotion;
        if (potion) _givePotions();
        text = 'A little shrine, candles still lit. You kneel a moment. +${k.hp - before} HP${potion ? ' · a health potion on the altar' : ''}';
      case RoomKind.key:
        s.dungeonKey = true;
        text = 'An empty room, and on a hook by the door, an iron key. Somewhere down here is a lock it fits.';
      case RoomKind.vault:
        s.dungeonKey = false;
        final gold = vaultGold(k.level);
        k.coins += gold;
        final g = loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: vaultOdds);
        s.pendingLoot.add(g);
        final gems = 1 + _rng.nextInt(2);
        for (var i = 0; i < gems; i++) {
          s.addMat(gemKey(Gem.values[_rng.nextInt(Gem.values.length)]), 1);
        }
        text = 'The key turns. Behind the door: the vault, untouched. +$gold gold · ${g.name} · $gems gem${gems == 1 ? '' : 's'}';
      default:
        text = '';
    }
    _note(text, kind == RoomKind.trap ? EntryKind.damage : EntryKind.gold);
    return text;
  }

  /// A fight in a dungeon won: on to the next room, or (the boss) the hoard.
  List<String> _dungeonWin() {
    final s = state, d = dungeonNow!, k = s.knight;
    final boss = s.dungeonPath.isNotEmpty && s.dungeonPath.last == RoomKind.boss.name;
    s.dungeonRoom = boss ? dungeonRooms + 1 : s.dungeonRoom + 1;
    if (!boss) {
      _rollDoors();
      return const [];
    }
    s.dungeonDoors.clear();
    // A relic part waiting in this hoard (if you hold the blueprint that needs it).
    for (final e in relics.entries) {
      for (var i = 0; i < e.value.parts.length; i++) {
        final p = e.value.parts[i];
        if (p.source == PartSource.dungeon && p.at == d.id) _grantPart(e.key, i);
      }
    }
    final first = s.dungeonsDone.add(d.id);
    final gold = bossHoardGold(k.level);
    k.coins += gold;
    final g = loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: first ? hoardOdds : hoardOddsAgain);
    s.pendingLoot.add(g);
    for (var i = 0; i < 2; i++) {
      s.addMat(gemKey(Gem.values[_rng.nextInt(Gem.values.length)]), 1);
    }
    _note('Behind ${d.boss.$1}\'s throne: the hoard. +$gold gold, ${g.name} and two gems.', EntryKind.gold);
    return ['+$gold gold', g.name, '2 gems'];
  }

  /// Climbs back out of the dungeon (the run ends; a cleared one can be run again).
  bool leaveDungeon() {
    if (state.dungeon == null || state.inBattle) return false;
    final d = dungeonNow!;
    _note(dungeonCleared ? 'You climb out of ${d.name} with the hoard on your back.' : 'You climb back out of ${d.name}.');
    _closeDungeon();
    return true;
  }

  void _closeDungeon() {
    state
      ..dungeon = null
      ..dungeonRoom = 0
      ..dungeonKey = false
      ..dungeonFight = false;
    state.dungeonDoors.clear();
    state.dungeonPath.clear();
  }

  // ---------------- wandering encounters ----------------

  /// After a win on the road, now and then something odd turns up.
  void _maybeEncounter() {
    final s = state;
    if (s.encounter != null || !s.innRepaired) return;
    // Every so many wins, a strongbox: something to look forward to.
    if (--s.chestIn <= 0) {
      s.chestIn = chestEvery;
      s.encounter = 'chest';
      return;
    }
    if (s.encounterCalm > 0) {
      s.encounterCalm--;
      return;
    }
    if (_rng.nextDouble() < encounterChance) {
      final pool = [for (final e in encounters) if (e.id != 'chest') e];
      s.encounter = pool[_rng.nextInt(pool.length)].id;
      s.encounterCalm = encounterCalm;
    }
  }

  /// What the bard charges.
  int get bardFee => 30 + 5 * state.knight.level;

  /// What Migs wants for his sack.
  int get migsPrice => 60 + 12 * state.knight.level;

  /// Plays out the waiting encounter with choice 0 or 1. Returns what happened, in a line.
  String resolveEncounter(int choice) {
    final e = encounterById(state.encounter);
    state.encounter = null;
    if (e == null) return '';
    final k = state.knight, mh = maxHp(k);
    String out;
    switch ((e.id, choice)) {
      case ('goat', 0):
        final before = k.hp;
        k.hp = math.min(mh, k.hp + (mh * .3).round());
        out = 'The goat leans into your hand and sighs. You feel oddly at peace. (+${k.hp - before} HP)';
      case ('goat', _):
        final xp = 10 * k.level;
        final ups = _grantXp(xp);
        out = 'The goat dips its hat to you, gravely, and wanders off. You feel you\'ve learned something. (+$xp XP${ups > 0 ? ', level up!' : ''})';
      case ('bard', 0):
        if (k.coins < bardFee) {
          out = 'You pat your pockets. The bard sighs and writes a song about that instead.';
        } else {
          k.coins -= bardFee;
          state.inspired = inspiredFights;
          out = '"The Ballad of the Sooty Knight" is... surprisingly stirring. Your next $inspiredFights fights, you hit ${((inspiredBoost - 1) * 100).round()}% harder. (−$bardFee gold)';
        }
      case ('bard', _):
        out = 'The bard writes a song about you anyway. It rhymes "knight" with "fright" and "sooty" with "not a beauty". Rude.';
      case ('chest', 0):
        final roll = 1 + _rng.nextInt(20);
        state.lastRoll = roll;
        if (roll <= chestAmbush) {
          // Bait: the box is empty, and whoever left it steps out of the trees.
          final here = foeIndexes(state.continent);
          final f = here[_rng.nextInt(here.length)];
          out = 'You roll a $roll. The lid swings up on nothing but straw, and ${withArticle(foeAt(f).name).toLowerCase()} steps out of the trees. It was bait. Ambush!';
          _note(out, EntryKind.damage);
          _begin(f, null, above: chestAmbushLevels);
          return out;
        } else if (roll < chestGear) {
          final gold = 15 * k.level + 20;
          k.coins += gold;
          final flask = _rng.nextBool();
          if (flask) _givePotions();
          out = 'You roll a $roll. The lock clicks open: a fat purse${flask ? ' and a healing potion' : ''}. (+$gold gold${flask ? ', +1 potion' : ''})';
        } else {
          final jackpot = roll == 20;
          final g = loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: jackpot ? const [0, 0, 0, 65, 35] : const [0, 0, 60, 34, 6]);
          state.pendingLoot.add(g);
          final gold = jackpot ? 40 * k.level + 60 : 8 * k.level;
          k.coins += gold;
          out = jackpot
              ? 'A natural 20! The box all but bursts open: ${g.name} (${g.rarity.label}), on a bed of gold. (+$gold gold)'
              : 'You roll a $roll. Under the straw, wrapped in oilcloth: ${g.name} (${g.rarity.label}). (+$gold gold)';
        }
      case ('chest', _):
        out = 'As you walk past, the chest sighs and grows a little pair of legs and toddles off into the trees. Wise.';
      case ('shrine', 0):
        k.hp = mh;
        out = 'For a moment the ash parts and a single warm sunbeam lands on you. You feel wonderful. (Full health)';
      case ('shrine', _):
        out = 'You leave the shrine be. Somewhere, a forgotten god of nice weather shrugs.';
      case ('migs', 0):
        if (k.coins < migsPrice) {
          out = '"No gold, no sack." Migs rattles off. You hear him laughing for a long time.';
        } else {
          k.coins -= migsPrice;
          final g = loot.roll(k.heroClass, k.level, odds: const [0, 25, 57, 16, 2]);
          state.pendingLoot.add(g);
          out = 'Inside the sack: ${g.name} (${g.rarity.label}). Genuine, apparently. (−$migsPrice gold)';
        }
      case ('migs', _):
        out = '"Your loss!" Migs rattles off. A wheel falls off his cart a little way down the road.';
      case ('chicken', 0):
        final gold = 10 * k.level + 15, xp = 6 * k.level;
        k.coins += gold;
        _grantXp(xp);
        out = 'Together you corner the chicken. The goblin is so grateful he gives you his shiniest button. It\'s worth a surprising amount. (+$gold gold, +$xp XP)';
      default:
        _givePotions();
        out = 'You scoop up the chicken. Its farmer comes running, overjoyed, and presses a health potion on you. The goblin sulks. (+1 potion)';
    }
    _note(out, EntryKind.gold);
    return out;
  }

  /// Foes Jack o' Cinders can borrow the stats of: ones that walk on two legs.
  bool _canWearJack(int i) {
    final f = foeAt(i);
    return !f.beast && !f.hound && !f.dragon && !seaBeasts.contains(f.look);
  }

  /// Welcomes you to a seasonal event, once a year. Returns the season, the first time.
  Season? greetSeason() {
    final s = season, key = '${s.name}-${clock().year}';
    if (s == Season.none || state.seasonSeen == key) return null;
    state.seasonSeen = key;
    _note(s.greeting, EntryKind.gold);
    return s;
  }

  /// Faces the current continent's boss. False if it isn't ready for you yet.
  bool challengeBoss() {
    if (state.inBattle || !bossReady) return false;
    final c = state.continent;
    _begin(bossIndex(c), null);
    _note('${foeAt(bossIndex(c)).name} rises to meet you!', EntryKind.gold);
    return true;
  }

  void _begin(int foe, Rare? rare, {int above = 0}) {
    final k = state.knight, level = foeLevelFor(realmAt(rare?.base ?? foe), k.level) + above;
    state
      ..inBattle = true
      ..foe = foe
      ..rare = rare
      ..foeLevel = level
      ..foeMax = (spawnHp(foe, level, rare) * ngFoeHp(state.ng)).round()
      ..turn = 0
      ..fleeTries = 0
      ..skillWait = 0
      ..petWait = 0
      ..mana = startingMana(k)
      ..summons = 0
      ..summonTurns = 0
      ..wards = 0
      ..mirror = 0
      ..foeFrozen = false
      ..foeWindup = false
      ..heroPoison = 0
      ..foeAsleep = 0
      ..foeSlowed = 0
      ..foeWeakened = 0
      ..foeExposed = 0
      ..foeBurn = 0
      ..foeBurnTurns = 0
      ..foeToxin = 0
      ..foeBleed = 0
      ..foeBleedTurns = 0
      ..foeVenom = 0
      ..potionsDrunk = 0
      ..fairyCharge = 0
      ..mended = false
      ..rallied = false
      ..vanguardUsed = false
      ..oathUsed = false
      ..charged = false
      ..wolfTurns = 0
      ..wolfUsed = false
      ..lastStyle = null
      ..form = null
      ..shifts = 0;
    state.foeHp = state.foeMax;
  }

  void _endBattle() {
    state
      ..heroicFight = false
      ..wildFight = false
      ..dungeonFight = false
      ..foeBurn = 0
      ..foeBurnTurns = 0
      ..foeToxin = 0
      ..foeBleed = 0
      ..foeBleedTurns = 0
      ..foeVenom = 0
      ..heroPoison = 0;
    if (state.inspired > 0) state.inspired--;
    state.pint = false;
    if (state.raidFight) {
      state.raidFight = false;
      if (state.raid != null) {
        state.raid = null;
        _note('The bandits slip away down the road with their haul.');
      }
    }
    state
      ..inBattle = false
      ..rare = null
      ..summons = 0
      ..summonTurns = 0
      ..wards = 0
      ..mirror = 0
      ..wolfTurns = 0
      ..place = null
      ..form = null
      ..shifts = 0;
    final k = state.knight;
    if (k.poisonFights > 0) k.poisonFights--;
    if (k.chariotFights > 0 && --k.chariotFights == 0) {
      k.hp = math.min(k.hp, maxHp(k));
      _note('The Chariot\'s strength leaves you.');
    }
    // Brews wear off a fight at a time (Reaper's Bane waits until it's needed).
    for (final b in Brew.values) {
      if (b == Brew.reaperbane || !brewOn(k, b)) continue;
      final left = k.brews[b.name]! - 1;
      k.brews[b.name] = left;
      if (left <= 0) {
        k.brews.remove(b.name);
        _note('Your ${b.label.toLowerCase()} wears off.');
      }
    }
  }

  // ---------------- what you can do this turn ----------------

  /// Whether [a] can be chosen right now (and if not, why not).
  String? whyNot(BattleAction a) {
    if (!state.inBattle) return 'No fight on';
    final k = state.knight;
    switch (a) {
      case BattleAction.attack || BattleAction.flee || BattleAction.shoot:
        return null;
      case BattleAction.potion:
        if (k.potions < 1) return 'No potions left';
        if (state.potionsDrunk >= potionsPerFight) return 'No time for another this fight ($potionsPerFight a fight)';
        if (k.hp >= maxHp(k)) return 'Already at full health';
        return null;
      case BattleAction.cast:
        return whyNotRite(k.preparedSpell);
      case BattleAction.skill:
        return state.skillWait > 0 ? 'Ready in ${state.skillWait} ${state.skillWait == 1 ? 'turn' : 'turns'}' : null;
      case BattleAction.pet:
        final who = activeCompanion(k);
        if (who == null) return 'No companion yet';
        if (who == 'dragon' && (dragonStage(k)?.chip ?? 0) == 0) return 'Your egg hasn\'t hatched';
        return state.petWait > 0 ? 'Ready in ${state.petWait} ${state.petWait == 1 ? 'turn' : 'turns'}' : null;
    }
  }

  /// The foe's own quirks against this blow (for the WEAK! / Resisted pop-ups; the damage itself
  /// is worked out in swingDamage).
  double _quirk(FoeType f, bool melee, bool shooting, bool casting, Spell? cast) {
    if (f.stone && cast == null) return bluntWeapons.contains(state.knight.loadout.weapon?.art) && melee ? 1.5 : .6;
    if (f.spirit && cast == null) return .6;
    return 1;
  }

  /// Puts a training point into [t].
  bool train(Trait t) {
    final k = state.knight;
    if (unspentPoints(k) < 1) return false;
    final hpFrac = k.hp / maxHp(k);
    k.training[t.name] = trained(k, t) + 1;
    if (t == Trait.vigour) k.hp = (hpFrac * maxHp(k)).round();
    return true;
  }

  /// Wipes your training (for gold) so you can spend it again.
  bool resetTraining() {
    final k = state.knight, cost = resetTrainingCost(k);
    if (k.training.values.every((v) => v == 0) || k.coins < cost || state.inBattle) return false;
    k.coins -= cost;
    k.training.clear();
    k.hp = math.min(k.hp, maxHp(k));
    _note('You spend a long evening forgetting old habits. Your training is yours to spend again.');
    return true;
  }

  /// Why the rite [id] can't be cast right now (null if it can).
  String? whyNotRite(String id) {
    final k = state.knight, sp = spellById(id);
    if (sp == null || sp.level > k.level) return 'Prepare a rite first';
    final cost = spellCost(k, sp);
    return state.mana >= cost ? null : 'Needs $cost mana';
  }

  /// Puts a rite on the hotbar, or takes it off (the hotbar always keeps at least one). With the
  /// hotbar full, the newest rite takes the last slot.
  void toggleRite(String id) {
    final k = state.knight, sp = spellById(id);
    if (sp == null || sp.level > k.level) return;
    k.rites.removeWhere((r) => spellById(r) == null);
    if (k.rites.contains(id)) {
      if (k.rites.length > 1) k.rites.remove(id);
    } else if (k.rites.length < riteSlots) {
      k.rites.add(id);
    } else {
      k.rites[riteSlots - 1] = id;
    }
    if (!k.rites.contains(k.preparedSpell)) k.preparedSpell = k.rites.first;
  }

  /// Takes your turn, then (if it's still standing and you're still here) the foe's.
  /// Mounted, a fight opens with a free charge as the foe arrives: you ride it down, then get
  /// off and fight on foot. Null with no mount (or once it's been made this fight).
  SwingResult? openingCharge() {
    if (!state.inBattle || state.charged || mountById(state.knight.mount) == null) return null;
    final r = SwingResult(BattleAction.attack, const SwingDamage(), true, state.knight.heroClass);
    _charge(r);
    r.kill = _checkKill();
    return r;
  }

  void _charge(SwingResult r) {
    final k = state.knight, mount = mountById(k.mount), foe = foeIn(state), foeName = foe.name;
    if (state.charged || mount == null) return;
    state.charged = true;
    var hit = (fullSwing(k) * mount.charge).round();
    if (mount.burn) hit += (foe.demon ? 1 : 2) * k.level;
    state.foeHp -= hit;
    r
      ..chargeHit = hit
      ..mount = mount;
    _note(mount.flying ? 'Your ${mount.name.toLowerCase()} swoops down on $foeName for $hit!' : 'You charge on your ${mount.name.toLowerCase()} and run $foeName down for $hit!', EntryKind.damage);
    if (mount.mend > 0) {
      final before = k.hp;
      k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * mount.mend).round());
      r.mended += k.hp - before;
      r.mendedFrom = mount.name;
    }
  }

  SwingResult takeTurn(BattleAction action, {double aim = 1}) {
    assert(state.inBattle);
    final k = state.knight, foe = foeIn(state), foeName = foe.name;
    if (whyNot(action) != null) action = BattleAction.attack;
    state.turn++;
    final melee = action == BattleAction.attack || action == BattleAction.skill;
    final shooting = action == BattleAction.shoot, casting = action == BattleAction.cast;
    final striking = melee || shooting || casting;
    // The weapon's special attack charges on attacks and fires on the last charge.
    final move = k.loadout.weapon?.specialMove;
    Special? fire;
    if (move != null && action == BattleAction.attack) {
      // A roll on every attack (the longer it waits, the likelier), like the old adventures.
      if (_rng.nextDouble() < specialChanceAt(state.specialCharge)) {
        state.specialCharge = 0;
        fire = move;
        // Poseidon's Trident calls the sea or the Kraken, as the tide decides.
        if (identical(move, specials['poseidon'])) fire = specials[_rng.nextBool() ? 'tidalwave' : 'krakencall'];
        // The Roll of Fate: sixes more often than snake eyes.
        if (identical(move, specials['fatesroll'])) fire = specials[_rng.nextDouble() < .6 ? 'luckyroll' : 'unluckyroll'];
      } else {
        state.specialCharge++;
      }
    }
    // Special bolts: one per crossbow shot, while they last.
    final loaded = ammoById(k.ammoLoaded);
    AmmoType? shot;
    if (shooting && loaded != null && (k.ammo[loaded.name] ?? 0) > 0) {
      shot = loaded;
      final left = k.ammo[loaded.name] = k.ammo[loaded.name]! - 1;
      if (left == 0) {
        k.ammo.remove(loaded.name);
        k.ammoLoaded = null;
        _note('That was your last of the ${loaded.label(Missile.bolt).toLowerCase()}.');
      }
    }
    // Fighting gathers mana; an Ember Rite spends it.
    Spell? cast;
    if (casting) {
      cast = spellById(k.preparedSpell)!;
      state.mana -= spellCost(k, cast);
    } else if (striking) {
      state.mana = math.min(maxMana, state.mana + 1);
    }
    if (cast?.kind == SpellKind.expose) state.foeExposed = cast!.hex + 1; // takes hold at once
    // A foe that's aloft is hard to reach with a blade and easy pickings for a crossbow.
    final reach = foe.aloft ? (melee ? aloftMelee : (shooting ? aloftShot : 1.0)) : 1.0;
    // The combat triangle: the right way of fighting this kind of foe hits harder.
    final style = melee ? AttackStyle.blade : (shooting ? AttackStyle.bolt : (casting ? AttackStyle.rite : null));
    // The Faceless learn: whatever way you struck last turn, they're braced for now.
    final braced = foe.mimic && style != null && style.name == state.lastStyle;
    // The full Changeling set: a change of style lands harder.
    final adapted = style != null && state.lastStyle != null && style.name != state.lastStyle && activeSets(k.gear).any((e) => e.$1.adapt && e.$2 >= 3);
    if (style != null) state.lastStyle = style.name;
    final edge = triangle(foe.kind, style) * (braced ? mimicBrace : 1);
    final cape = k.loadout.cape?.special;
    final bash = action == BattleAction.skill;
    // Training, and any of Mags' brews you've drunk.
    final train = melee
        ? mightBoost(k) * (brewOn(k, Brew.might) ? mightBrew : 1)
        : (shooting ? aimBoost(k) * (brewOn(k, Brew.hawkeye) ? hawkeyeBrew : 1) : (casting ? arcanaBoost(k) * (brewOn(k, Brew.arcane) ? arcaneBrew : 1) : 1.0));
    final song = state.inspired > 0 ? inspiredBoost : 1.0;
    final wolf = state.wolfTurns > 0 ? wolfDamage : 1.0;
    final updraft = foe.aloft && activeSets(k.gear).any((e) => e.$1.updraft && e.$2 >= 3) ? updraftBoost : 1.0;
    final bushido = activeSets(k.gear).any((e) => e.$1.bushido && e.$2 >= 3) ? 1 + math.min(bushidoCap, (state.turn - 1) * bushidoStep) : 1.0;
    final mult = reach * edge * train * song * wolf * updraft * bushido * (adapted ? adaptBoost : 1) * (bash ? bashMult : (shooting ? crossbowShare(k) * aim : (casting && cape == 'starweave' ? 1.3 : 1.0)));
    final d = striking
        ? swingDamage(state, _rng.nextDouble(), special: fire, ammo: shot, spell: cast, hitRoll: _rng.nextDouble(), mult: mult, sureCrit: state.turn == 1 && activeSets(k.gear).any((e) => e.$1.firstCrit && e.$2 >= 3))
        : const SwingDamage();
    // Attacks and shots can miss now and then. Specials, rites and the bash always land.
    final miss = (action == BattleAction.attack || (shooting && aim <= 1)) && fire?.sure != true && _rng.nextDouble() < missChance;
    // Elves are quick: some attacks and bolts just miss (rites, skills and specials never do).
    final dodged = !miss && foe.evasive && (action == BattleAction.attack || shooting) && fire?.sure != true && _rng.nextDouble() < evasiveMiss;
    final r = SwingResult(action, d, miss || dodged || !striking, k.heroClass, aim: shooting ? aim : 1, edge: reach * edge * _quirk(foe, melee, shooting, casting, cast));
    if (bash) state.skillWait = skillCooldown + 1;

    // The mount's opening charge, if it didn't already come as the foe arrived.
    if (striking) _charge(r);

    switch (action) {
      case BattleAction.potion:
        k.potions--;
        state.potionsDrunk++;
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + potionHeal(k));
        r.potion = k.hp - before;
        if (state.heroPoison > 0) {
          state.heroPoison = 0;
          r.cured = true;
        }
        _note('You drink a health potion and recover ${r.potion} HP. It tastes of smoke, like everything.', EntryKind.good);
      case BattleAction.flee:
        if (_rng.nextDouble() < fleeChance(k, foe, state.fleeTries)) {
          r.fled = true;
          state.flees++;
          if (state.wildFight) {
            // In the wilds you run from the fight, not from the wilds, and shed weight as you go.
            final lost = _dropFromPack(fightFleeLoss);
            r.packLoss = lost;
            _endBattle();
            _note(lost.none ? 'You flee from $foeName and lose it in the scrub.' : 'You flee from $foeName, and ${lost.summary} spills out of your pack as you run.', lost.none ? EntryKind.plain : EntryKind.damage);
            return r;
          }
          if (state.dungeonFight) {
            // In a dungeon you back out of the room and bar the door: the run goes on.
            if (state.dungeonPath.isNotEmpty) state.dungeonPath.removeLast();
            if (state.dungeonDoors.isEmpty) _rollDoors();
            _endBattle();
            _note('You back out of the room and bar the door on $foeName.');
            return r;
          }
          _endBattle();
          _note('You flee from $foeName, coat-tails smoking. Back to the Soot & Kettle!');
          return r;
        }
        r.fleeFailed = true;
        state.fleeTries++;
        _note('You try to flee, but $foeName cuts you off! (Next try: ${(fleeChance(k, foe, state.fleeTries) * 100).round()}%)');
      case BattleAction.pet:
        _command(r);
      case BattleAction.attack || BattleAction.skill || BattleAction.cast || BattleAction.shoot:
        _strike(r, fire, cast, foeName);
    }
    if (shot != null && !r.miss && state.foeHp > 0) _shotTakes(shot, r, foe, foeName);
    // A clean kill: the bolt itself brought it down (not your companion, the dead or a burn after).
    _cleanKill = shooting && !r.miss && state.inBattle && state.foeHp <= 0;
    _cleanBolt = _cleanKill ? shot : null;
    if (fire != null) _specialTakes(fire, r, foe, foeName);
    // A lucky moment: the foe leaves an opening, and you get a free second blow in.
    if (action == BattleAction.attack && fire == null && !r.miss && state.foeHp > 0 && _rng.nextDouble() < openingChance) {
      r.opening = math.max(1, (d.base * openingShare).round());
      state.foeHp -= r.opening;
      _note('An opening! You get a second blow in for ${r.opening}.', EntryKind.damage);
    }

    if (striking) {
      // Dual wielding: the off-hand weapon strikes after every blade attack, even if the main blow
      // missed.
      final o = melee ? (offhandStrike(state) * reach).round() : 0;
      if (o > 0) {
        state.foeHp -= o;
        r.offhandHit = o;
        _note('Your off-hand ${k.loadout.activeOffhand!.name.toLowerCase()} strikes for $o.', EntryKind.damage);
      }
      // Your companion goes in next, then the summoned dead (the order the fight plays them).
      _bite(r);
      // Summoned skeletons strike with you until their time is up.
      if (state.summons > 0) {
        final hit = state.summons * summonHit(k.level);
        state.foeHp -= hit;
        r
          ..summonHit = hit
          ..summons = state.summons;
        _note('Your ${state.summons == 1 ? 'skeleton strikes' : '${state.summons} skeletons strike'} for $hit.', EntryKind.damage);
        state.summonTurns--;
        if (state.summonTurns <= 0) {
          state.summons = 0;
          _note('Your summoned dead crumble back into the earth.');
        }
      }
    }
    _burnAndVenom(r, foe, foeName);
    r.kill = _checkKill();
    if (r.kill == null) {
      _maybeShift(r);
      _foeTurn(r, bash);
      // Now and then it rears back for a heavy blow next turn: you see it coming, so Bash it,
      // freeze it, hex it, or brace with a potion.
      if (r.kill == null && state.inBattle && state.foeHp > 0 && _rng.nextDouble() < (foe.boss ? windupBoss : windupChance)) {
        state.foeWindup = true;
        r.windup = true;
        _note('$foeName rears back for a heavy blow!', EntryKind.damage);
      }
    }
    // The land itself: unwarded, its hazard hurts you every turn (but never knocks you out).
    final land = realmAt(state.rare?.base ?? state.foe);
    if (state.inBattle && !state.wildFight && state.hazardIn(land)) {
      final hurt = math.max(1, (maxHp(k) * hazardShare).round());
      final before = k.hp;
      k.hp = math.max(1, k.hp - hurt);
      r.hazard = before - k.hp;
      // The why (and the cure) once a fight; after that, just the bite.
      if (r.hazard > 0) {
        _note(state.turn <= 1 ? '${continents[land].hazard}: −${r.hazard} HP. ${continents[land].hazardText}; Old Wick could craft a ${continents[land].ward}.' : '${continents[land].hazard}: −${r.hazard} HP.', EntryKind.damage);
      }
    }
    // Poison in you: it eats at you every turn till it runs out or a potion cures it (it never
    // knocks you out on its own).
    if (state.inBattle && k.hp > 0 && state.heroPoison > 0 && !r.poisoned) {
      final before = k.hp;
      k.hp = math.max(1, k.hp - math.max(1, (maxHp(k) * heroPoisonShare).round()));
      r.poisonTick = before - k.hp;
      state.heroPoison--;
      if (r.poisonTick > 0) _note('Poison: −${r.poisonTick} HP.', EntryKind.damage);
    }
    // Lizardfolk: wounds close between blows, unless fire touched them this turn.
    if (state.inBattle && foe.regrows && r.damage.burn == 0 && r.burned == 0 && state.foeHp < state.foeMax) {
      final before = state.foeHp;
      state.foeHp = math.min(state.foeMax, state.foeHp + (state.foeMax * regrowShare).round());
      r.regrew = state.foeHp - before;
      _note('$foeName\'s wounds close over (+${r.regrew}). Fire would stop that.');
    }
    // A mending draught: a little HP back every turn, while it lasts.
    if (state.inBattle && k.hp > 0 && k.hp < maxHp(k) && brewOn(k, Brew.healing)) {
      final before = k.hp;
      k.hp = math.min(maxHp(k), k.hp + math.max(1, (maxHp(k) * mendingBrew).round()));
      r.regrown += k.hp - before;
      r.regrownFrom = 'Mending';
    }
    // The full Sunscale set: under half health, you regrow too.
    if (state.inBattle && k.hp > 0 && k.hp < maxHp(k) / 2 && activeSets(k.gear).any((e) => e.$1.regrowth && e.$2 >= 3)) {
      final before = k.hp;
      k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * regrowthHeal).round());
      r.regrown += k.hp - before;
      r.regrownFrom = r.regrownFrom.isEmpty ? 'Sunscale' : '${r.regrownFrom} + Sunscale';
    }
    // The wolf goes back in when its time is up.
    if (state.wolfTurns > 0 && !r.wolfed && striking) {
      state.wolfTurns--;
      if (state.wolfTurns == 0) {
        r.wolfEnded = true;
        _note('The red goes out of your eyes. You\'re you again, out of breath and very hairy.');
      }
    }
    // Hexes and cooldowns wear off one turn at a time.
    state
      ..foeSlowed = math.max(0, state.foeSlowed - 1)
      ..foeWeakened = math.max(0, state.foeWeakened - 1)
      ..foeExposed = math.max(0, state.foeExposed - 1)
      ..skillWait = math.max(0, state.skillWait - 1)
      ..petWait = math.max(0, state.petWait - 1);
    return r;
  }

  /// What a special shot leaves behind: a burning shot sets the foe ablaze, a venom shot adds a
  /// stack of venom, a frost shot may freeze it out of its next blow.
  void _shotTakes(AmmoType shot, SwingResult r, FoeType foe, String foeName) {
    final k = state.knight;
    switch (shot) {
      case AmmoType.fire:
        // Ents burn twice as hard; demons, the Ember King and fire elementals hardly at all.
        final tick = foe.element == 'burn' ? 0 : (burnTick(k.level) * (foe.ent ? 2 : (foe.demon || foe.look == 'emberKing' ? .5 : (foe.element == 'frost' ? 2 : 1)))).round();
        if (tick > 0) {
          state
            ..foeBurn = tick
            ..foeBurnTurns = burnTurns;
          _note('$foeName catches fire.', EntryKind.damage);
        }
      case AmmoType.venom:
        if (!foe.venomous && foe.element != 'poison') {
          state.foeVenom++;
          _note(state.foeVenom == 1 ? 'Venom gets into $foeName.' : 'More venom: $foeName has ${state.foeVenom} doses in it now.', EntryKind.damage);
        }
      case AmmoType.frost:
        if (!state.foeFrozen && foe.element != 'frost' && _rng.nextDouble() < freezeChance * (foe.boss ? .5 : 1)) {
          state.foeFrozen = true;
          r.froze = true;
          _note('The frost bites deep: $foeName is frozen solid!', EntryKind.good);
        }
      case AmmoType.blessed || AmmoType.leech:
        break;
    }
  }

  /// What a special attack leaves behind: a stun, its price in your own health (and, for the
  /// dice, a point of mana), the dead who stay to fight, a foe's guard torn open.
  void _specialTakes(Special sp, SwingResult r, FoeType foe, String foeName) {
    final k = state.knight;
    if (sp.stun > 0 && state.foeHp > 0 && !state.foeFrozen && _rng.nextDouble() < sp.stun) {
      state.foeFrozen = true;
      r.specialStun = true;
      _note('$foeName reels, stunned.', EntryKind.good);
    }
    if (sp.selfHurt > 0) {
      final before = k.hp;
      k.hp = math.max(1, k.hp - (maxHp(k) * sp.selfHurt).round());
      r.selfHurt = before - k.hp;
      if (sp.dice) state.mana = math.max(0, state.mana - 1);
      _note(sp.dice ? 'The dice bite back: −${r.selfHurt} HP.' : 'The demon takes its price: −${r.selfHurt} HP.', EntryKind.damage);
    }
    if (sp.summon > 0 && state.foeHp > 0) {
      state
        ..summons = math.min(3, state.summons + sp.summon)
        ..summonTurns = math.max(state.summonTurns, 2);
      r.summons = state.summons;
      _note('One of the dead stays to fight beside you.', EntryKind.good);
    }
    if (sp.expose > 0) state.foeExposed = math.max(state.foeExposed, sp.expose + 1);
  }

  /// Fire and venom eat at the foe every turn while they last (ents shrug off half the venom).
  void _burnAndVenom(SwingResult r, FoeType foe, String foeName) {
    if (!state.inBattle || state.foeHp <= 0) return;
    final k = state.knight;
    if (state.foeBurnTurns > 0) {
      r.burned = math.min(state.foeHp, state.foeBurn);
      state
        ..foeHp -= r.burned
        ..foeBurnTurns -= 1;
      _note('$foeName burns for ${r.burned}.', EntryKind.damage);
    }
    if ((state.foeVenom > 0 || state.foeToxin > 0) && state.foeHp > 0) {
      final v = (state.foeVenom * venomTick(k.level) * (foe.ent ? .5 : 1)).round() + state.foeToxin;
      r.venomed = math.min(state.foeHp, v);
      state.foeHp -= r.venomed;
      _note('The venom eats at $foeName for ${r.venomed}.', EntryKind.damage);
    }
    if (state.foeBleedTurns > 0 && state.foeHp > 0) {
      r.bled = math.min(state.foeHp, state.foeBleed);
      state
        ..foeHp -= r.bled
        ..foeBleedTurns -= 1;
      _note('$foeName bleeds for ${r.bled}.', EntryKind.damage);
    }
  }

  /// A shapeshifter takes a new shape: on its first turn, and again when it's badly hurt (a boss at
  /// each third of its HP).
  void _maybeShift(SwingResult r) {
    final me = encounterType(state.foe, state.rare);
    if (!me.shifts) return;
    final hurt = state.foeHp / state.foeMax;
    final due = me.boss ? state.shifts < 1 + (hurt < 2 / 3 ? 1 : 0) + (hurt < 1 / 3 ? 1 : 0) : state.shifts < 1 + (hurt < reshiftAt ? 1 : 0);
    // The Thousandfold first wears your own face, for a turn or two.
    if (!due || (me.boss && state.shifts == 0 && hurt > .9)) return;
    final forms = shiftForms(realmAt(state.rare?.base ?? state.foe), boss: me.boss)..remove(state.form);
    state
      ..form = forms[_rng.nextInt(forms.length)]
      ..shifts += 1;
    final now = foeIn(state);
    r.shifted = foeAt(state.form!).name;
    _note('${me.name} ripples like hot air, folds in on itself, and stands up as ${withArticle(foeAt(state.form!).name)}! It fights like one now.', EntryKind.gold);
    final (weak, shrug) = foeEdges(now);
    if (weak.isNotEmpty || shrug.isNotEmpty) _note('(${[if (weak.isNotEmpty) 'Weak to ${weak.join(', ')}', if (shrug.isNotEmpty) 'shrugs off ${shrug.join(', ')}'].join('; ')}.)');
  }

  /// Your attack (or skill): the blow, its effects and any spell.
  void _strike(SwingResult r, Special? fire, Spell? cast, String foeName) {
    final k = state.knight, d = r.damage;
    if (cast != null) {
      _note('You cast ${cast.name}!', EntryKind.gold);
      switch (cast.kind) {
        case SpellKind.summon:
          state.summons = math.max(state.summons, cast.summons);
          state.summonTurns = cast.turns + (k.loadout.weapon?.name == 'Ossuary staff' ? 1 : 0);
          _note(cast.summons == 1 ? 'A skeleton warrior claws its way out of the earth to fight for you.' : '${cast.summons} skeletons rise to fight for you.');
        case SpellKind.nova:
          state.foeFrozen = true;
        case SpellKind.ward:
          state.wards = math.min(3, state.wards + cast.wards);
        case SpellKind.drain:
          final before = k.hp;
          k.hp = math.min(maxHp(k), k.hp + (d.base * cast.drain).round());
          r.drained = k.hp - before;
        case SpellKind.slow:
          state.foeSlowed = cast.hex + 1;
          _note('$foeName slows to a crawl.');
        case SpellKind.weaken:
          state.foeWeakened = cast.hex + 1;
          _note('$foeName\'s strength drains away.');
        case SpellKind.expose:
          _note('$foeName\'s defences crack open.');
        case SpellKind.heal:
          final before = k.hp;
          k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * cast.mend).round());
          r.mended += k.hp - before;
          r.mendedFrom = 'Mend';
          _note('Golden light mends ${k.hp - before} HP.', EntryKind.good);
        case SpellKind.sleep:
          final big = foeIn(state).boss;
          state.foeAsleep = big ? 1 : cast.hex;
          _note(big ? '$foeName nods off, but it won\'t sleep long.' : '$foeName falls into a deep sleep.');
        case SpellKind.reflect:
          state.mirror = cast.wards;
          _note('A shimmering mirror rises before you.');
        case SpellKind.blast || SpellKind.dragon || SpellKind.chain || SpellKind.charge:
          break;
      }
    }
    final shooting = r.action == BattleAction.shoot;
    if (r.miss) {
      final elf = encounterType(state.foe, state.rare).evasive || foeIn(state).evasive;
      _note(elf ? '$foeName sways aside like a leaf in the wind. You miss.' : (shooting ? 'You loose a bolt at $foeName, but miss.' : 'You swing at $foeName, but miss.'));
      return;
    }
    final hit = d.base + d.effects;
    state.foeHp -= hit;
    final extras = [
      if (d.poison > 0) '${d.poison} poison',
      if (d.burn > 0) '${d.burn} fire',
      if (d.frost > 0) '${d.frost} frost',
      if (d.smite > 0) '${d.smite} holy',
    ];
    if (fire != null) {
      _note('${fire.name}! Your special attack unleashes.', EntryKind.gold);
      if (fire.coins > 0) k.coins += fire.coins;
    }
    final how = switch (r.action) {
      BattleAction.skill => '${skillName(k)}! You hit',
      BattleAction.shoot => 'Your ${crossbows[k.crossbow].$1.toLowerCase()} hits',
      BattleAction.cast => 'The rite hits',
      _ => 'You strike and hit',
    };
    _note('$how $foeName for $hit${d.crit ? ' (critical!)' : ''}${extras.isEmpty ? '' : ', including ${extras.join(', ')}'}.', EntryKind.damage);
    // What the weapon leaves in the wound: fire that keeps burning, venom that builds, a bleed.
    if (d.ignite > 0) {
      if (state.foeBurnTurns == 0) _note('$foeName catches fire.', EntryKind.damage);
      state
        ..foeBurn = math.max(state.foeBurnTurns > 0 ? state.foeBurn : 0, d.ignite)
        ..foeBurnTurns = burnTurns;
    }
    if (d.envenom > 0) {
      state.foeToxin += math.max(1, (d.envenom * toxinGrowth).round());
      if (state.foeToxin == math.max(1, (d.envenom * toxinGrowth).round())) _note('Venom gets into $foeName.', EntryKind.damage);
    }
    if (d.bleed > 0) {
      if (state.foeBleedTurns == 0) _note('$foeName starts to bleed.', EntryKind.damage);
      state
        ..foeBleed = math.max(state.foeBleedTurns > 0 ? state.foeBleed : 0, d.bleed)
        ..foeBleedTurns = bleedTurns;
    }
    // Frost now and then freezes it out of its next blow.
    if (d.frost > 0 && !state.foeFrozen && state.foeHp > 0 && _rng.nextDouble() < frostFreeze * (foeIn(state).boss ? .5 : 1)) {
      state.foeFrozen = true;
      r.froze = true;
      _note('The cold bites deep: $foeName freezes solid!', EntryKind.good);
    }
    // The full Tidecaller set: frost drags the foe down like the undertow.
    if (d.frost > 0 && state.foeSlowed == 0 && activeSets(k.gear).any((e) => e.$1.undertow && e.$2 >= 3) && _rng.nextDouble() < undertowChance) {
      state.foeSlowed = 2;
      _note('The undertow drags at $foeName: half its blows will miss for two turns.', EntryKind.good);
    }
    // The wolf heals as it tears; Bloodthirst (the full Nightblood set) doubles it all when you're low.
    var heal = d.heal + (state.wolfTurns > 0 ? (hit * wolfHeal).round() : 0);
    if (heal > 0 && bloodthirsty(k)) heal *= 2;
    if (heal > 0) {
      final before = k.hp;
      k.hp = math.min(maxHp(k), k.hp + heal);
      r.healed = k.hp - before;
    }
  }

  /// The companion's bite (or dragon fire) that follows every attack, and a fairy's charms.
  void _bite(SwingResult r) {
    final k = state.knight, d = r.damage, ds = dragonStage(k), pet = petStage(k);
    if (d.chip <= 0) return;
    if (pet != null) {
      r.pet = pet;
      state.foeHp -= d.chip;
      _note('Your ${pet.$2.name.toLowerCase()} bites for ${d.chip}.', EntryKind.damage);
      // A fairy's charm comes when it comes: about one bite in [charm], likelier the longer since.
      final every = pet.$2.charm;
      if (every > 0) {
        if (_rng.nextDouble() < math.min(1.0, (1 + state.fairyCharge * .5) / every)) {
          _charm(r);
        } else {
          state.fairyCharge++;
        }
      }
    } else if (ds != null) {
      r.dragon = ds;
      state.foeHp -= d.chip;
      _note('Your ${ds.name.toLowerCase()} breathes fire for ${d.chip}.', EntryKind.damage);
    }
  }

  /// A fairy weaves its next charm.
  void _charm(SwingResult r) {
    final k = state.knight, pet = petStage(k)!;
    state.fairyCharge = 0;
    final charm = FairyCharm.values[_rng.nextInt(FairyCharm.values.length)];
    state.fairyNext++;
    r.charm = charm;
    switch (charm) {
      case FairyCharm.slumber:
        state.foeAsleep = math.max(state.foeAsleep, 1);
      case FairyCharm.enfeeble:
        state.foeWeakened = math.max(state.foeWeakened, 3);
      case FairyCharm.slow:
        state.foeSlowed = math.max(state.foeSlowed, 3);
      case FairyCharm.venom:
        r.charmHit = 4 + k.level;
      case FairyCharm.leech:
        r.charmHit = 3 + k.level ~/ 2;
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + 6 + k.level);
        r.charmHeal = k.hp - before;
    }
    state.foeHp -= r.charmHit;
    _note('Your ${pet.$2.name.toLowerCase()} casts ${charm.label}: ${charm.effect}${r.charmHit > 0 ? ' (${r.charmHit})' : ''}${r.charmHeal > 0 ? ', +${r.charmHeal} HP' : ''}.', EntryKind.good);
  }

  /// The companion's command: hounds pounce (and may stagger the foe), a fairy casts a charm at
  /// once, a dragon breathes a great gout of fire.
  void _command(SwingResult r) {
    final k = state.knight, pet = petStage(k), ds = dragonStage(k), foe = foeIn(state);
    // A command is worth a turn: it scales with your own blow, and companions fly, so it reaches
    // foes that are aloft too.
    final bite = swingDamage(state, 1).chip, blow = fullSwing(k) * outmatchedHits(state.foeLevel, k.level);
    state.petWait = petCooldown + 1;
    r.command = true;
    if (pet != null && pet.$1 == Pet.fairy) {
      r.pet = pet;
      final hit = (blow * .6).round() + bite;
      state.foeHp -= hit;
      _note('Your ${pet.$2.name.toLowerCase()} darts in for $hit.', EntryKind.damage);
      _charm(r);
      r.charmHit += hit;
    } else if (pet != null) {
      r.pet = pet;
      final hit = (blow * .9).round() + bite + (pet.$1 == Pet.hellhound && !foe.demon ? 2 * k.level : 0);
      state.foeHp -= hit;
      r.charmHit = hit;
      final stagger = _rng.nextDouble() < .35;
      if (stagger) state.foeFrozen = true;
      _note('Your ${pet.$2.name.toLowerCase()} pounces for $hit!${stagger ? ' The foe staggers.' : ''}', EntryKind.damage);
    } else if (ds != null) {
      r.dragon = ds;
      final hit = (blow * 1.1).round() + bite + (foe.demon || foe.look == 'emberKing' ? k.level : 3 * k.level);
      state.foeHp -= hit;
      r.charmHit = hit;
      _note('Your ${ds.name.toLowerCase()} rears up and breathes a torrent of fire for $hit!', EntryKind.damage);
    }
  }

  /// The foe's turn: if it's still standing, it hits back.
  void _foeTurn(SwingResult r, bool bashed) {
    final k = state.knight, foe = foeIn(state), foeName = foe.name;
    final pet = petStage(k);
    // A heavy blow it wound up last turn: spent now, landed or not.
    final heavy = state.foeWindup;
    state.foeWindup = false;
    void spared(Guard g, String text) {
      r
        ..counter = 0
        ..guard = g;
      _note(text);
    }

    if (bashed && (!foe.boss || _rng.nextBool())) {
      r.stunned = true;
      spared(Guard.stunned, '$foeName is seeing stars and can\'t hit back.');
      return;
    }
    if (bashed) _note('$foeName shakes off your ${skillName(k)}!');
    final roll = _rng.nextDouble(), dodge = dodgeChance(k, foe), parry = parryChance(k), block = blockChance(k);
    if (pet != null && pet.$2.guard && _rng.nextDouble() < .12) {
      spared(Guard.guarded, '$foeName swings, but your ${pet.$2.name.toLowerCase()} leaps in the way.');
    } else if (state.foeSlowed > 0 && _rng.nextDouble() < .5) {
      spared(Guard.slowed, '$foeName swings far too slowly. It misses.');
    } else if (state.foeAsleep > 0) {
      state.foeAsleep--;
      spared(Guard.asleep, state.foeAsleep > 0 ? '$foeName snores through its turn.' : '$foeName stirs and wakes.');
    } else if (state.foeFrozen) {
      state.foeFrozen = false;
      spared(Guard.frozen, '$foeName can\'t move and can\'t hit back.');
    } else if (state.wards > 0) {
      state.wards--;
      spared(Guard.warded, '$foeName strikes. Your arcane ward absorbs it.');
    } else if (roll < dodge) {
      r
        ..counter = 0
        ..guard = Guard.dodge;
      if (k.loadout.cape?.special == 'shadow') {
        // Shadowstep: a dodge becomes a strike from the shadows.
        final hit = riposte(k);
        state.foeHp -= hit;
        r.riposte = hit;
        _note('$foeName strikes. You melt into the shadows and hit back for $hit!', EntryKind.damage);
        r.kill = _checkKill();
      } else {
        _note('$foeName strikes. You dodge!');
      }
    } else if (k.loadout.cape?.special == 'vanguard' && !state.vanguardUsed) {
      // Vanguard: the fight's first blow glances off the Crusader's mantle.
      state.vanguardUsed = true;
      spared(Guard.block, '$foeName strikes. The blow glances off your Crusader\'s mantle.');
    } else if (!state.vanguardUsed && activeSets(k.gear).any((e) => e.$1.firstMiss && e.$2 >= 3)) {
      // Silverleaf: the fight's first blow finds only a drift of silver leaves where you were.
      state.vanguardUsed = true;
      r
        ..counter = 0
        ..guard = Guard.dodge;
      _note('$foeName strikes, and finds only a drift of silver leaves where you were.');
    } else if (roll < dodge + (1 - dodge) * parry) {
      // Parry: deflect the blow and strike back.
      final hit = riposte(k);
      state.foeHp -= hit;
      r
        ..counter = 0
        ..guard = Guard.parry
        ..riposte = hit;
      _note('$foeName strikes. You parry and riposte for $hit!', EntryKind.damage);
      r.kill = _checkKill();
    } else {
      final blocked = _rng.nextDouble() < block;
      // The Guardian's Oath: the first heavy blow each fight that gets through to you meets the
      // vault-keeper's shield, and lands no harder than an ordinary one.
      final oath = heavy && !state.oathUsed && guardianSworn(state.vaultFound);
      if (oath) {
        state.oathUsed = true;
        r.oath = true;
        _note('$foeName brings its heavy blow down. Your Guardian\'s Oath holds: the shield takes the worst of it.');
      }
      final full = (counterDamage(state) * (heavy && !oath ? heavyBlow : 1)).round();
      r.heavy = heavy && !oath;
      var hurt = blocked ? (full * blockLeak(k)).round() : full;
      if (state.mirror > 0) {
        // Mirror Ward: you take half; the foe takes the whole blow back.
        state.mirror--;
        hurt = (hurt / 2).round();
        state.foeHp -= full;
        r.reflected = full;
      }
      k.hp = math.max(0, k.hp - hurt);
      if (blocked && k.hp > 0 && activeSets(k.gear).any((e) => e.$1.forgeheart && e.$2 >= 3)) {
        // Deepforge: the block rings like an anvil, and you feel it in your bones.
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * forgeheartHeal).round());
        r.mended += k.hp - before;
        r.mendedFrom = 'Forgeheart';
      }
      if (k.loadout.cape?.special == 'rally' && !state.rallied && k.hp < maxHp(k) * .3) {
        // Rally: the Bannerlord's cloak won't let you fall back.
        state.rallied = true;
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * .25).round());
        r.mended += k.hp - before;
        r.mendedFrom = 'Rally';
        _note('You rally beneath your banner and recover ${k.hp - before} HP!', EntryKind.good);
      }
      r
        ..counter = hurt
        ..guard = blocked ? Guard.block : Guard.hit;
      // Vampires drink from the wound; spiders and plague leave poison in it.
      if (hurt > 0 && drinksBlood(foe) && state.foeHp < state.foeMax) {
        final before = state.foeHp;
        state.foeHp = math.min(state.foeMax, state.foeHp + (hurt * bloodDrink).round());
        r.drank = state.foeHp - before;
        if (r.drank > 0) _note('$foeName drinks from the wound (+${r.drank}).', EntryKind.damage);
      }
      if (hurt > 0 && k.hp > 0 && poisons(foe) && _rng.nextDouble() < heroPoisonChance) {
        state.heroPoison = heroPoisonTurns;
        r.poisoned = true;
        _note('You\'re poisoned! A potion would cure it.', EntryKind.damage);
      }
      final thorns = hurt > 0 ? heroStats(k).thorns : 0;
      if (thorns > 0) {
        state.foeHp -= thorns;
        r.thorns = thorns;
      }
      final how = blocked ? (hurt == 0 ? 'You block it completely.' : 'You block most of it: $hurt gets through.') : (r.heavy ? 'A heavy blow: $hurt!' : 'It hits you for $hurt.');
      _note('$foeName strikes. $how${thorns > 0 ? ' Your thorns bite for $thorns.' : ''}${r.reflected > 0 ? ' Your mirror hurls ${r.reflected} back!' : ''}', hurt > 0 ? EntryKind.damage : EntryKind.plain);
      if (thorns > 0 || r.reflected > 0) r.kill = _checkKill();
      if (r.kill == null && k.hp <= 0) {
        if (brewOn(k, Brew.reaperbane)) {
          // Reaper's Bane: he comes for you, and his scythe goes right through you.
          k.brews.remove(Brew.reaperbane.name);
          k.hp = math.max(1, (maxHp(k) * reaperbaneHp).round());
          r.cheatedDeath = true;
          _note('The Reaper comes for you, and his scythe passes straight through. Reaper\'s Bane burns in your chest: you stand back up on ${k.hp} HP.', EntryKind.good);
        } else {
          _knockOut(r, foeName);
        }
      }
      // The Bloodmoon Pelt: hurt badly enough, the wolf comes out.
      if (state.inBattle && k.hp > 0 && !state.wolfUsed && wearsPelt(k) && k.hp < maxHp(k) * wolfAt) {
        state
          ..wolfUsed = true
          ..wolfTurns = wolfTurnsFor(k);
        r.wolfed = true;
        _note('The Bloodmoon Pelt burns red. Your bones crack, your jaw lengthens, and you HOWL. For ${state.wolfTurns} turns you fight as the wolf: harder blows that heal you, and a hide that turns them.', EntryKind.gold);
      }
    }
  }

  /// Your HP ran out: the fight is lost. The innkeeper drags you home and patches you up; someone
  /// helped themselves to a little of your gold on the way.
  void _knockOut(SwingResult r, String foeName) {
    final k = state.knight;
    r.knockedOut = true;
    state.knockouts++;
    final lost = math.min(k.coins ~/ 10, 20 + 10 * k.level);
    k.coins -= lost;
    r.goldLost = lost;
    k.hp = maxHp(k);
    final wild = state.wildFight;
    // Struggling on a land's trail: the town starts suggesting the wilds for better gear.
    final dungeon = state.dungeonFight;
    if (!wild && !dungeon && !state.raidFight && !state.heroicFight) {
      final c = realmAt(state.rare?.base ?? state.foe);
      state.struggle[c] = (state.struggle[c] ?? 0) + 1;
    }
    _endBattle();
    if (dungeon) {
      final d = dungeonNow;
      _closeDungeon();
      if (d != null) _note('Somebody drags you up out of ${d.name}. The run is over.', EntryKind.damage);
    }
    _note('$foeName knocks you flat. You wake up by the fire at the Soot & Kettle, sootier than ever${lost > 0 ? ', and $lost gold lighter' : ''}.', EntryKind.damage);
    if (wild) {
      // The scavengers of the wilds go through your pack before anyone finds you.
      r.packLoss = _dropFromPack(koLoss);
      r.wildExit = _bankPack(r.packLoss!, safe: false);
      if (!r.packLoss!.none) _note('Scavengers went through your pack while you lay there: ${r.packLoss!.summary} gone.', EntryKind.damage);
    }
  }

  // ---------------- victory ----------------

  KillResult? _checkKill() {
    if (state.foeHp > 0 || !state.inBattle) return null;
    state.foeHp = 0;
    final k = state.knight, i = state.foe, rare = state.rare, f = foeIn(state), r = foeReward(i, state.foeLevel, k, rare);
    final c = realmAt(rare?.base ?? i), firstBoss = f.boss && rare == null && !state.bossesDown.contains(c) && !state.wildFight;
    // Out in the wilds, whatever this foe leaves goes into your pack (see the end of this).
    final wild = state.wildFight, coins0 = k.coins, loot0 = state.pendingLoot.length;
    // A lucky moment: now and then a foe was carrying far more than it should.
    final jackpot = _rng.nextDouble() < jackpotChance ? r.coins * 2 : 0;
    k.coins += r.coins + jackpot;
    if (jackpot > 0) _note('Jackpot! It was carrying a fat purse: +$jackpot gold.', EntryKind.gold);
    // A clean kill with the crossbow: a hunter's bounty, and the bolt pulled back out.
    final clean = _cleanKill, boltBack = _cleanBolt;
    _cleanKill = false;
    _cleanBolt = null;
    final bounty = clean ? math.max(1, (r.coins * cleanKillGold).round()) : 0;
    k.coins += bounty;
    if (boltBack != null) {
      k.ammo[boltBack.name] = (k.ammo[boltBack.name] ?? 0) + 1;
      k.ammoLoaded ??= boltBack.name;
    }
    if (clean) _note('A clean kill! One bolt, and it\'s down. +$bounty gold${boltBack != null ? ', and you pull your bolt back out' : ''}.', EntryKind.gold);
    final ups = _grantXp(r.xp);
    final gearLevel = wild ? k.level + wildGearLift(state.wildDepth) : k.level;
    // Not every foe carries something worth taking; rare foes and bosses always do.
    // A pack is just three ordinary foes: a better chance of something, but no promise. A golem
    // leaves ore, not gear; one of the Hidden Ones, now and then something (the Prior always).
    // Golems and elementals leave ore and cores, not gear.
    final golemFight = golemMetal(rare?.look) != null || elementalOf(rare?.look) != null;
    final hiddenOne = hiddenRanks.containsKey(rare?.look) && rare?.look != hiddenPrior && rare?.pack != true;
    final single = rare != null && !rare.pack && !golemFight && !hiddenOne;
    final carries = !golemFight &&
        (single || f.boss || _rng.nextDouble() < (hiddenOne ? hiddenGearChance : (rare != null ? packGearDropChance : (wild ? wildGearDropChance : gearDropChance))));
    final GearItem? drop = !carries
        ? null
        : rare == null
        ? loot.roll(k.heroClass, gearLevel, wielding: k.loadout.weapon, boss: f.boss, odds: wild ? wildOdds(state.wildDepth) : null, east: c == eastLand)
        : loot.roll(k.heroClass, gearLevel, wielding: k.loadout.weapon, odds: rareOdds(rare), element: auraStat(rare.aura), east: c == eastLand);
    // A warlord of the wilds always leaves something fine.
    if (wild && rare != null && rare.name == wildAreas[state.wild!].warlord.$1) {
      state.pendingLoot.add(loot.roll(k.heroClass, gearLevel, wielding: k.loadout.weapon, odds: const [0, 0, 0, 85, 15]));
    }
    if (drop != null) state.pendingLoot.add(drop);
    GearItem? orkPrize, wyrm, bonePrize, entPrize, rune, prize;
    String? raidWon, relicPart;
    var hoard = const <String>[];
    final boost = rare == null ? 1.0 : 1.5;
    if (f.ork && !_hasPrize(k, _orkArt(k.heroClass)) && _rng.nextDouble() < (f.boss ? orkGearChanceBoss : orkGearChance) * boost) {
      orkPrize = loot.orkDrop(k.heroClass, k.level);
      state.trophies.add(orkPrize.art);
      state.pendingLoot.add(orkPrize);
    }
    if (f.undead && _rng.nextDouble() < (f.boss ? boneGearChanceBoss : boneGearChance) * boost) {
      // The dead leave their bones: armour if you haven't got it, otherwise often a weapon.
      final kit = k.loadout;
      final hasArmour = state.trophies.contains('bone:armour') || boneArmour.contains(kit.armour) || state.pendingLoot.any((g) => boneArmour.contains(g.art));
      final hasWeapon = state.trophies.contains('bone:weapon') || boneWeapons.contains(kit.weapon?.name) || state.pendingLoot.any((g) => boneWeapons.contains(g.name));
      final armour = !hasArmour && (hasWeapon || _rng.nextDouble() < .45);
      if (armour || !hasWeapon) {
        bonePrize = loot.boneDrop(k.heroClass, k.level, armour: armour);
        state.trophies.add(armour ? 'bone:armour' : 'bone:weapon');
        state.pendingLoot.add(bonePrize);
      }
    }
    if (f.ent && !_hasPrize(k, _entArt(k.heroClass)) && _rng.nextDouble() < (f.boss ? entGearChanceBoss : entGearChance) * boost) {
      entPrize = loot.entDrop(k.heroClass, k.level);
      state.trophies.add(entPrize.art);
      state.pendingLoot.add(entPrize);
    }
    // Elemental arms: one of each kind per hero.
    final armsKind = f.element == 'burn' ? 'flame' : f.element == 'frost' ? 'frost' : (c == 15 ? 'dawn' : (c == 7 && f.night ? 'shadow' : null));
    if (armsKind != null && !state.trophies.contains('arms:$armsKind') && _rng.nextDouble() < (f.element != null ? elementArmsChance : (f.boss ? landArmsChance * 6 : landArmsChance)) * boost) {
      final arms = loot.elementArms(armsKind, k.heroClass, k.level);
      prize ??= arms;
      state.trophies.add('arms:$armsKind');
      state.pendingLoot.add(arms);
    }
    if (c == 9 && !state.trophies.contains('thornbloom') && !_hasPrize(k, 'thornblade') && _rng.nextDouble() < (f.boss ? elfGearChanceBoss : elfGearChance) * boost) {
      // The elves' flowering weapons: one per hero, like the orks' and the ents'.
      entPrize = loot.elfDrop(k.heroClass, k.level);
      state.trophies.add('thornbloom');
      state.pendingLoot.add(entPrize);
    }
    if (c == batLand && !state.trophies.contains('duskwing') && _rng.nextDouble() < (f.boss ? batGearChanceBoss : batGearChance) * boost) {
      // The Hollowdeep's Duskwing weapons: one per hero, like the elves' Thornbloom.
      entPrize = loot.batDrop(k.heroClass, k.level);
      state.trophies.add('duskwing');
      state.pendingLoot.add(entPrize);
    }
    if (c == frostLand && !state.trophies.contains('rimeforged') && _rng.nextDouble() < (f.boss ? frostGearChanceBoss : frostGearChance) * boost) {
      // The Frostmarch's Rimeforged weapons: one per hero.
      entPrize = loot.frostDrop(k.heroClass, k.level);
      state.trophies.add('rimeforged');
      state.pendingLoot.add(entPrize);
    }
    if (f.look == runeLook && !_hasRuneWeapon(k) && _rng.nextDouble() < (f.rare ? runeChanceRare : runeChance)) {
      rune = loot.runeWeapon(k.heroClass, k.level);
      state.trophies.add(rune.art);
      state.pendingLoot.add(rune);
    }
    if (f.dragon) {
      // Dragons leave one kind of prize: wyrmscale, a piece in this dragon's colour (its tier).
      final tier = wyrmTierFor(f.look);
      if (tier != null && _rng.nextDouble() < (f.boss ? wyrmChanceBoss : (rare != null ? wyrmChanceRare : wyrmChance))) {
        // Now and then it's jewellery carved from its bones instead.
        final jewel = _rng.nextInt(7);
        wyrm = jewel >= 5 ? loot.dragonboneJewel(k.level, tier, ring: jewel == 5) : loot.wyrmDrop(k.heroClass, k.level, tier);
        state.pendingLoot.add(wyrm);
      }
    }
    // Now and then an armour variant for your class (in the Blossom Isles, sometimes its own).
    GearItem? suit;
    if (_rng.nextDouble() < (f.boss || rare != null ? armourVariantChanceBoss : armourVariantChance)) {
      final band = armourVariants[k.heroClass]!.lastWhere((b) => k.level >= b.$1).$2;
      final east = c == eastLand && k.level >= 22 && _rng.nextDouble() < .5;
      final t = armourTierById(east ? eastArmour[k.heroClass]! : band[_rng.nextInt(band.length)]);
      suit = GearItem(id: 'suit${_rng.nextInt(1 << 30)}', name: t.name, slot: GearSlot.armour, art: t.id, rarity: t.reduction >= .3 ? Rarity.epic : Rarity.rare, level: k.level, heroClass: k.heroClass, lore: 'Damage taken −${(t.reduction * 100).round()}%, ${t.perkText}.', value: 20 + 4 * k.level, stats: const {});
      state.pendingLoot.add(suit);
    }
    // A scroll of enchanting now and then (a free rune at the enchanter).
    final scroll = _rng.nextDouble() < (f.boss || rare != null ? scrollChanceBoss : scrollChance);
    if (scroll) k.scrolls++;
    // Bosses and rare foes sometimes leave a cape with a class ability.
    GearItem? cape;
    if ((f.boss || rare != null) && _rng.nextDouble() < capeChance) {
      cape = loot.capeDrop(k.heroClass, k.level);
      state.pendingLoot.add(cape);
    }
    // A steed won in battle: a tamed wyvern, a wild unicorn.
    final steed = mountDrops[f.look];
    Mount? wonMount;
    if (steed != null && !k.mounts.contains(steed.$1) && _rng.nextDouble() < steed.$2 * boost) {
      wonMount = mountById(steed.$1);
      _gainMount(steed.$1);
    }
    // A continent's boss: its legendary trinket (always the first time), its companion, and the
    // way on to the next continent.
    final land = continents[c];
    String? companion;
    final opened = <int>[];
    final placeWon = placeById(state.place);
    var egg = false;
    if (f.boss && rare == null) {
      if (firstBoss || (!_hasTrinket(k, land.prize) && _rng.nextDouble() < .15)) {
        prize = loot.bossTrinket(land.prize, k.level);
        state.pendingLoot.add(prize);
      }
      state.struggle.remove(c);
      if (firstBoss) {
        state.bossesDown.add(c);
        companion = land.companionText;
        switch (land.companion) {
          case Companion.wolf:
            _gainPet(Pet.wolf);
          case Companion.fairy:
            _gainPet(Pet.fairy);
          case Companion.hellhound:
            _gainPet(Pet.hellhound);
          case Companion.nightmare:
            _gainMount('nightmare');
          case Companion.dragon:
            if (!k.hasDragon) {
              k.dragonXp = 0;
              k.activePet = 'dragon';
            }
            egg = true;
          case Companion.none:
            break;
        }
        // Every land this boss opens a road to (that no other beaten boss had opened already).
        for (var l = 0; l < continents.length; l++) {
          final from = openers(l);
          if (from.contains(c) && !from.any((f) => f != c && state.bossesDown.contains(f))) {
            opened.add(l);
            if (!isSideLand(l)) state.unlocked = math.max(state.unlocked, l);
          }
        }
      }
    } else if (wild) {
      _passTime();
    } else if (state.heroicFight) {
      relicPart = _heroicWin(c, f.boss);
      _maybeRaid();
      _passTime();
    } else if (state.dungeonFight) {
      hoard = _dungeonWin();
      _passTime();
    } else if (placeWon != null) {
      state.explored.add(placeWon.id);
      if (placeWon.relic case (final r, final i)) _grantPart(r, i);
      _passTime();
    } else if (state.raidFight) {
      raidWon = state.raid;
      state.raid = null;
    } else {
      state.wins[c]++;
      _maybeRaid();
      _passTime();
      _maybeEncounter();
    }
    // Reagents for the next continent's ward.
    var reagents = 0;
    if (c + 1 < mainLands) {
      reagents = f.boss && rare == null ? reagentsFromBoss : (_rng.nextDouble() < reagentChance * boost ? 1 : 0);
      state.reagents[c] += reagents;
    }
    // A golem leaves its ore; any foe now and then a gem.
    final golem = golemMetal(rare?.look);
    var ore = 0;
    if (golem != null) {
      ore = golemOreMin + _rng.nextInt(golemOreMax - golemOreMin + 1);
      state.addMat(oreKey(golem), ore);
    }
    // The Shattered Sea: its people carry pearls, the merrow now and then a sea-forged weapon, and
    // the Kraken guards a sea-god's own.
    final sea = trophyLooks[f.look] == Trophy.coral || rare?.look == 'kraken';
    var pearl = false;
    if (sea && !wild && _rng.nextDouble() < pearlChance) {
      pearl = true;
      state.addMat(gemKey(Gem.pearl), 1);
    }
    GearItem? seaPrize;
    if (rare?.look == 'kraken') {
      seaPrize = loot.seaDrop(k.heroClass, k.level, poseidon: true);
    } else if (f.look.startsWith('merrow') && !state.trophies.contains('sea') && _rng.nextDouble() < seaGearChance * boost) {
      seaPrize = loot.seaDrop(k.heroClass, k.level, poseidon: false);
      state.trophies.add('sea');
    }
    if (seaPrize != null) state.pendingLoot.add(seaPrize);
    // An elemental leaves its core.
    final elemental = elementalOf(rare?.look);
    var cores = 0;
    if (elemental != null) {
      cores = coresMin + _rng.nextInt(coresMax - coresMin + 1);
      state.addMat(coreKey(elemental), cores);
    }
    // The dwarves of Deepforge Hold carry ore from their mines.
    Metal? dwarfMetal;
    if (trophyLooks[f.look] == Trophy.runesteel && (f.boss || _rng.nextDouble() < dwarfOreChance)) {
      dwarfMetal = _rng.nextBool() ? Metal.iron : Metal.gold;
      state.addMat(oreKey(dwarfMetal), f.boss ? dwarfOre * 3 : dwarfOre);
    }
    Gem? gem;
    if (!wild && _rng.nextDouble() < (f.boss ? gemChanceBoss : (rare != null ? gemChanceRare : gemChance))) {
      gem = Gem.values[_rng.nextInt(Gem.values.length)];
      state.addMat(gemKey(gem), 1);
    }
    // Now and then a foe carries a health potion (bosses always do).
    final flask = f.boss || _rng.nextDouble() < potionDropChance;
    if (flask) _givePotions();
    // Hob's job: goblins carry off what the inn needs.
    String? jobFind;
    if (onHobsJob && c == 0 && rare == null && !f.boss) {
      if (state.timber < timberNeeded) {
        state.timber++;
        jobFind = 'Charred Timber';
      } else if (state.ironScrap < ironNeeded) {
        state.ironScrap++;
        jobFind = 'Iron Scrap';
      }
    } else if (state.innRepaired && !state.raidFight && state.home < homes.length - 1) {
      // Building stock for your home, from the lands that have it.
      if (timberLands.contains(c) && _rng.nextDouble() < buildFindChance) {
        state.timber++;
        jobFind = 'Charred Timber';
      } else if (ironLands.contains(c) && _rng.nextDouble() < buildFindChance) {
        state.ironScrap++;
        jobFind = 'Iron Scrap';
      }
    }
    final chest = f.boss || _rng.nextDouble() < (single ? rareChestChance : chestChance) ? openChest(rare: single ? rare : null, grand: f.boss) : null;
    // Now and then a Cinder key for the Ember Vault: likelier the tougher the foe was.
    final over = state.foeLevel - k.level;
    final key = _rng.nextDouble() < (f.boss ? keyChanceBoss : keyChance[over >= 6 ? 2 : (over >= 3 ? 1 : 0)]);
    if (key) {
      state.keys++;
      _note('Among the spoils: a Cinder key, still warm. Hob\'s cellar has a door it would fit.', EntryKind.gold);
    }
    // In the wilds: everything this fight was worth goes into the pack, gold with the depth bonus.
    var packGold = 0, packed = <GearItem>[];
    if (wild) {
      packGold = ((k.coins - coins0) * wildGold(state.wildDepth)).round();
      k.coins = coins0;
      state.packGold += packGold;
      packed = state.pendingLoot.sublist(loot0);
      state.pendingLoot.removeRange(loot0, state.pendingLoot.length);
      state.pack.addAll(packed);
    }
    state.foesFelled++;
    if (rare != null) state.raresFelled++;
    final won = firstBoss && c == mainLands - 1;
    // The Ashen Order, Ravenmoor's vampires and the Weald's werewolves leave trophies, and now and
    // then a blueprint for their set (their bosses and Sir Malric always leave one you lack).
    // Shapeshifters leave their shifting skin, whatever shape they died in (and see below).
    final shifter = encounterType(i, rare).shifts;
    final trophy = shifter ? Trophy.skin : trophyLooks[f.look];
    var trophies = 0;
    String? blueprint;
    if (trophy != null) {
      final malric = rare?.look == malricLook;
      trophies = f.boss || malric ? trophiesFromBoss : (_rng.nextDouble() < trophyChance ? (f.pack ? 2 : 1) : 0);
      if (trophies > 0) state.addMat(trophyKey(trophy), trophies);
      final set = forgedSetFor(trophy);
      final missing = [for (final slot in setPieceSlots) if (state.mat(blueprintKey(set.id, slot)) == 0) slot];
      if (missing.isNotEmpty && (f.boss || malric || _rng.nextDouble() < (rare != null ? blueprintChanceRare : blueprintChance))) {
        final slot = missing[_rng.nextInt(missing.length)];
        state.addMat(blueprintKey(set.id, slot), 1);
        blueprint = blueprintName(set, slot);
      }
    }
    // A shapeshifter that died wearing a trophy-bearer's shape now and then leaves that too.
    Trophy? formTrophy;
    final worn = shifter && state.form != null ? trophyLooks[f.look] : null;
    if (worn != null && _rng.nextDouble() < trophyChance) {
      formTrophy = worn;
      state.addMat(trophyKey(worn), 1);
    }
    // Sir Malric yields and rides off (until the last time).
    var malricGone = false;
    if (rare?.look == malricLook) {
      state.malric++;
      if (state.malric >= malricLands.length) {
        malricGone = true;
        state.pendingLoot.add(loot.bossTrinket('ashenseal', k.level));
      }
    }
    // Catching your breath after a win: a little back for everyone, and regeneration gear mends
    // you on the spot.
    final regen = heroStats(k).regen + (maxHp(k) * breathShare).round();
    var breathed = 0;
    if (regen > 0 && k.hp < maxHp(k)) {
      final before = k.hp;
      k.hp = math.min(maxHp(k), k.hp + regen);
      breathed = k.hp - before;
      _note('You catch your breath and mend ${k.hp - before} HP.', EntryKind.good);
    }
    _endBattle();
    final the = (f.boss || f.named) && !f.pack ? '' : 'the ';
    _note(
      wild ? 'You defeated $the${f.name}. +${r.xp} XP. Into your pack: $packGold gold${packed.isEmpty ? '' : ' and ${packed.length == 1 ? packed.first.name : '${packed.length} pieces of gear'}'}.' : 'You defeated $the${f.name}. +${r.xp} XP, +${r.coins} gold.',
      EntryKind.gold,
    );
    if (drop != null) _note('It dropped ${drop.rarity == Rarity.epic || drop.rarity == Rarity.legendary ? 'something special: ' : ''}${drop.name} (${drop.rarity.label}).', EntryKind.gold);
    if (companion != null) _note(companion, EntryKind.gold);
    if (prize != null) _note('${f.name} leaves its treasure behind: ${prize.name}!', EntryKind.gold);
    for (final l in opened) {
      _note(isSideLand(l) ? 'Off the road, a new land: ${continents[l].name}. ${continents[l].blurb}' : 'The way to ${continents[l].name} is open.', EntryKind.gold);
    }
    if (rare?.look == malricLook) {
      _note(
        malricGone
            ? 'Sir Malric falls to one knee, and doesn\'t get up. He presses something into your hand: the Ashen Order\'s seal, broken in two. "Do better with it than I did." Then the ash takes him. (Malric\'s Ashen Seal!)'
            : 'Sir Malric staggers back and lowers his blade. "Enough. You\'ve improved." He whistles for his horse and rides off into the ash. He\'ll be back.',
        EntryKind.gold,
      );
    }
    if (trophies > 0) _note('You take ${trophies == 1 ? withArticle(trophy!.label.toLowerCase()) : '$trophies ${trophy!.label.toLowerCase()}'} (${state.mat(trophyKey(trophy))}). $smithName can forge with it, given the blueprint.', EntryKind.gold);
    if (formTrophy != null) _note('It died wearing that shape so well it left ${withArticle(formTrophy.label.toLowerCase())} behind!', EntryKind.gold);
    if (blueprint != null) _note('Folded inside its armour: a blueprint! The $blueprint. Take it to $smithName.', EntryKind.gold);
    if (won) _note('Vharrax the Ember King is no more. The Great Burning is over. The world can start growing back.', EntryKind.gold);
    if (won) _note('New Game+ waits in town, whenever you want the road again, harder.', EntryKind.gold);
    if (wonMount != null) _note('The ${wonMount.name.toLowerCase()} bows its head to you. It\'s yours to ride.', EntryKind.gold);
    if (wyrm != null) _note('From its scales and bones: ${wyrm.name}!', EntryKind.gold);
    if (orkPrize != null) _note('The ork drops its ${orkPrize.name.toLowerCase()}!', EntryKind.gold);
    if (jobFind != null && state.innRepaired) {
      _note('You salvage ${jobFind == 'Charred Timber' ? 'a length of timber' : 'a sack of iron'} for building (${state.timber} timber, ${state.ironScrap} iron).', EntryKind.gold);
    } else if (jobFind != null) {
      _note(
        jobFind == 'Charred Timber'
            ? 'It was carrying off a length of Charred Timber. That\'s Hob\'s (${state.timber} of $timberNeeded).'
            : 'It had a sack of Iron Scrap: nails, hinges, a kettle lid (${state.ironScrap} of $ironNeeded).',
        EntryKind.gold,
      );
      if (innReady) _note('That\'s everything Hob asked for. Take it back to the Soot & Kettle.', EntryKind.gold);
    }
    if (reagents > 0) _note('You gather ${reagents == 1 ? withArticle(land.reagent) : '$reagents ${land.reagent}'}${reagents == 1 ? '' : 's'} (${state.reagents[c]}). Old Wick can make a ward from $reagentsForWard.', EntryKind.gold);
    if (scroll) _note('Tucked in its belt: a scroll of enchanting. Read it at the enchanter for a free rune.', EntryKind.gold);
    if (pearl) _note('Tangled in its kit: a pearl, still wet from the sea (${state.mat(gemKey(Gem.pearl))}). Old Wick grinds pearls into blessed bolts.', EntryKind.gold);
    if (seaPrize != null) _note(rare?.look == 'kraken' ? 'Among the wrecks where the Kraken slept: ${seaPrize.name}! A sea-god\'s own weapon.' : 'The merrow drops a sea-forged weapon: ${seaPrize.name}!', EntryKind.gold);
    if (elemental != null) _note('Where it stood, ${cores == 1 ? withArticle(elemental.core.toLowerCase()) : '$cores ${elemental.core.toLowerCase()}s'} still glows (${state.mat(coreKey(elemental))}). Old Wick binds $coresPerRune into a rune.', EntryKind.gold);
    if (dwarfMetal != null) _note('In its pack: ${dwarfMetal.ore.toLowerCase()}, fresh from the mine (${state.mat(oreKey(dwarfMetal))}).', EntryKind.gold);
    if (golem != null) _note('The golem crumbles. Among the rubble: $ore lumps of ${golem.ore.toLowerCase()} (${state.mat(oreKey(golem))}). Dunstan can smelt it into bars.', EntryKind.gold);
    if (gem != null) _note('Something glints in the ash: ${withArticle(gem.label.toLowerCase())}! Old Wick can grind it into a bundle of ${gem.ammo.label(Missile.bolt).toLowerCase()}.', EntryKind.gold);
    if (suit != null) _note('Among the spoils: a suit of ${suit.name.toLowerCase()}.', EntryKind.gold);
    if (cape != null) _note('A cape flutters down: ${cape.name}. ${capeByAbility(cape.special)!.ability}.', EntryKind.gold);
    if (bonePrize != null) _note('Among the bones: ${bonePrize.name.toLowerCase()}!', EntryKind.gold);
    if (rune != null) _note('Among the Warden\'s bones, runes glow: ${withArticle(rune.name)}!', EntryKind.gold);
    if (entPrize != null) _note('The ent leaves you a gift: ${entPrize.name}!', EntryKind.gold);
    if (rare?.look == hiddenPrior) {
      if (!_hasPrize(k, 'hiddenmask') && !k.stash.any((g) => g.art == 'hiddenmask') && k.trinket?.art != 'hiddenmask' && _rng.nextDouble() < hiddenMaskChance) {
        state.pendingLoot.add(loot.hiddenMask(k.level));
        _note('The Prior\'s gilded mask falls face-up in the ash, its red tear still wet. (The Mask of the Hidden!)', EntryKind.gold);
      } else {
        final tithe = 20 + 5 * k.level;
        k.coins += tithe;
        _note('Under the Prior\'s robes, a purse of the coven\'s tithes: +$tithe gold.', EntryKind.gold);
      }
    }
    if (rare?.look == 'pumpkinhead') {
      if (!_hasPrize(k, 'cinderjack') && !k.stash.any((g) => g.art == 'cinderjack') && k.trinket?.art != 'cinderjack' && _rng.nextDouble() < lanternChance) {
        state.pendingLoot.add(loot.cinderJack(k.level));
        _note('Jack\'s pumpkin rolls to a stop at your feet, still lit. You could hang that on your belt. (The Cinder-Jack Lantern!)', EntryKind.gold);
      } else {
        final toffee = 15 + 4 * k.level;
        k.coins += toffee;
        _note('Jack leaves a sack of soot-toffee behind. Mags will buy anything: +$toffee gold.', EntryKind.gold);
      }
    }
    if (firstBoss && relics[c] != null) _note(relics[c]!.blueprint, EntryKind.gold);
    if (firstBoss) _note('${land.name}\'s Heroic trail is open: elite foes, and ${f.name} waiting at the end, risen.', EntryKind.gold);
    if (placeWon != null) {
      _note(placeWon.after, EntryKind.gold);
      _placeReward(placeWon);
    }
    if (raidWon == 'stall') {
      _givePotions();
      _note('You haul Mags\' stock back to her stall. She presses a health potion into your hand: "On the house. Don\'t tell anyone."', EntryKind.gold);
    } else if (raidWon == 'inn') {
      k.coins += r.coins;
      _note('You bring Hob back his silver. He counts it twice and slides you ${r.coins} gold for your trouble.', EntryKind.gold);
    }
    if (ups > 0) _note('You reached level ${k.level}. ${shineLine(k.level)}', EntryKind.gold);
    final junkGold = _sellJunk(loot0);
    return KillResult(i, f.name, r.xp, r.coins + jackpot + bounty, ups, breathed: breathed, key: key, clean: clean, bounty: bounty, boltBack: boltBack, jackpot: jackpot, drop, junkGold: junkGold, egg: egg, orkGear: orkPrize, entGear: entPrize, runeGear: rune, prize: prize, foe: f, chest: chest, companion: companion, opened: opened, trophy: trophies > 0 ? '${trophies > 1 ? '$trophies× ' : ''}${trophy!.label}' : null, blueprint: blueprint, boss: f.boss && rare == null, won: won, reagents: reagents, jobFind: jobFind, potion: flask, relicPart: relicPart, packGold: packGold, packed: packed, hoard: hoard, finds: [
      if (gem != null) ('gem', gem.name),
      if (pearl) ('gem', Gem.pearl.name),
      if (elemental != null) ('core', elemental.name),
      if (golem != null) ('ore', golem.name),
      if (dwarfMetal != null) ('ore', dwarfMetal.name),
      if (scroll) ('scroll', ''),
    ]);
  }

  void _gainPet(Pet p) {
    final k = state.knight;
    if (k.pets.containsKey(p.name)) return;
    k.pets[p.name] = 0;
    k.activePet ??= p.name;
  }

  /// Rarity odds (common to legendary) for a rare foe's drop: mostly rare and epic, now and then legendary.
  /// (Legendaries were turning up about once a land; they're meant to be the find of a lifetime.)
  static List<int> rareOdds(Rare rare) => rare.pack
      ? const [600, 800, 500, 99, 1]
      : rare.name != null || rare.aura == Aura.ancient
      ? const [0, 0, 115, 82, 3]
      : rare.aura == Aura.cursed
      ? const [0, 0, 112, 84, 4]
      : const [0, 40, 117, 42, 1];

  /// The affix a rare foe's aura puts on its drop.
  static Stat? auraStat(Aura a) => switch (a) {
    Aura.gilded => Stat.fortune,
    Aura.cursed => Stat.lifesteal,
    Aura.blazing => Stat.burn,
    Aura.venom => Stat.poison,
    Aura.frost => Stat.frost,
    Aura.ancient => null,
  };

  /// Opens a treasure chest: gold, gear (into the spoils) and sometimes a potion. Rare foes leave
  /// gilded or ancient chests, and bosses grand ones.
  ChestFind openChest({Rare? rare, bool grand = false}) {
    final k = state.knight;
    final weights = grand ? const [0, 0, 40, 60] : rare == null ? const [50, 30, 15, 5] : (rare.name != null || rare.aura == Aura.ancient ? const [0, 0, 40, 60] : const [0, 0, 70, 30]);
    var pick = _rng.nextInt(weights.reduce((a, b) => a + b)), t = 0;
    while (pick >= weights[t]) {
      pick -= weights[t];
      t++;
    }
    final tier = ChestTier.values[t];
    final coins = ((6 + 2 * k.level) * const [1, 2, 3, 5][t] * (1 + heroStats(k).fortune / 100) * (0.8 + _rng.nextDouble() * .4)).round();
    const odds = [
      [55, 35, 9, 1, 0],
      [0, 65, 30, 5, 0],
      [0, 50, 120, 29, 1],
      [0, 0, 110, 87, 3],
    ];
    // One piece per chest; a boss's grand chest holds two.
    final items = [for (var n = 0; n < (t == 3 ? 2 : 1); n++) loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: odds[t])];
    final potion = t < 2 && _rng.nextDouble() < .45;
    // Sometimes a bundle of special crossbow bolts.
    AmmoType? ammo;
    if (_rng.nextDouble() < .3) {
      ammo = AmmoType.values[_rng.nextInt(AmmoType.values.length)];
      k.ammo[ammo.name] = (k.ammo[ammo.name] ?? 0) + ammoBundle;
      k.ammoLoaded ??= ammo.name;
    }
    k.coins += coins;
    if (potion) _givePotions();
    state.pendingLoot.addAll(items);
    state.chestsOpened++;
    final find = ChestFind(tier, coins, items, potion: potion, ammo: ammo == null ? null : '$ammoBundle ${ammo.label(Missile.bolt).toLowerCase()}');
    _note('You open ${withArticle(tier.label.toLowerCase())}: ${find.summary}.', EntryKind.gold);
    return find;
  }

  static String _orkArt(HeroClass c) => switch (c) {
    HeroClass.knight => 'orkclub',
    HeroClass.ranger => 'orkbow',
    HeroClass.mage => 'orkstaff',
  };

  /// Already holding this class's rune weapon (or one is waiting in the spoils).
  bool _hasRuneWeapon(Knight k) {
    const runes = {'runeblade', 'runebow', 'runestaff'};
    return state.trophies.any(runes.contains) || runes.contains(k.loadout.weapon?.art) || state.pendingLoot.any((g) => runes.contains(g.art));
  }

  static String _entArt(HeroClass c) => switch (c) {
    HeroClass.knight => 'heartmaul',
    HeroClass.ranger => 'heartbow',
    HeroClass.mage => 'livingstaff',
  };

  /// Wearing a trinket with this [art] (or one is waiting in the spoils).
  bool _hasTrinket(Knight k, String art) => k.trinket?.art == art || state.pendingLoot.any((g) => g.art == art);

  bool _hasPrize(Knight k, String art) => state.trophies.contains(art) || k.loadout.weapon?.art == art || state.pendingLoot.any((g) => g.art == art);


  // ---------------- the Inn ----------------

  /// A night by the fire at the Soot & Kettle: full health. Free (the innkeeper owes you one).
  /// Why you can't rest yet (null if you can).
  String? get whyNotRest => state.innRepaired ? null : 'The roof is still smouldering. Hob needs timber and iron before anyone sleeps here.';

  /// On Hob's job: the inn needs patching up, and Cindervale has only goblins in it until it is.
  bool get onHobsJob => !state.innRepaired && state.jobTaken;

  /// Hob has a job for you and you haven't said yes yet.
  bool get jobOffered => !state.innRepaired && !state.jobTaken;

  /// You agree to fetch Hob's timber and iron.
  bool takeHobsJob() {
    if (!jobOffered) return false;
    state.jobTaken = true;
    _givePotions(jobPotions);
    _note(hobsJob, EntryKind.gold);
    _note('Hob presses $jobPotions flasks of red into your hands. "On the house. Don\'t drink them all at once."', EntryKind.good);
    return true;
  }

  /// Everything Hob asked for is in hand.
  bool get innReady => !state.innRepaired && state.timber >= timberNeeded && state.ironScrap >= ironNeeded;

  /// Hands Hob the timber and iron: the Soot & Kettle is patched up, the fire is lit, and the
  /// rest of Cindervale is open for business.
  bool repairInn() {
    if (!innReady) return false;
    state
      ..innRepaired = true
      ..timber = 0
      ..ironScrap = 0;
    state.knight.coins += innRepairReward;
    _givePotions(innRepairPotions);
    state.knight.hp = maxHp(state.knight);
    _note('Hob hammers the last plank into place and lights the fire. "Rooms are free for you, forever. And here, for your trouble." +$innRepairReward gold and $innRepairPotions potions.', EntryKind.gold);
    _note('With the goblins scattered, the rest of Cindervale\'s troubles come out of the ash: bandits, looters, wolves and worse.', EntryKind.plain);
    return true;
  }

  /// What Old Corva charges to turn a card, at your level.
  int get readingCost => readingPrice(state.knight.level);

  /// Why Old Corva won't read for you right now (null if she will).
  String? get whyNotReading {
    if (!state.innRepaired) return 'Her stool is buried under the rubble';
    if (state.inBattle || state.wild != null) return 'You\'re a long way from the hearth';
    if (state.pint) return 'One card till your next fight';
    if (state.knight.coins < readingCost) return 'Not enough gold';
    return null;
  }

  /// Old Corva turns a card by the hearth at the Soot & Kettle, and it comes true. Returns the
  /// card and what it did (null if she won't read for you).
  (Tarot, String)? drawCard() {
    if (whyNotReading != null) return null;
    final s = state, k = s.knight;
    k.coins -= readingCost;
    // (Saved as 'pint': one reading a fight, as there used to be one pint.)
    s.pint = true;
    // Cards that can't come true right now are out of the deck.
    final deck = {
      for (final t in Tarot.values)
        if (!(t == Tarot.fool && s.encounter != null) && !(t == Tarot.death && brewOn(k, Brew.reaperbane)) && !(t == Tarot.empress && k.potions >= potionBelt)) t: t.weight,
    };
    var r = _rng.nextDouble() * deck.values.fold(0.0, (a, b) => a + b);
    var card = deck.keys.first;
    for (final e in deck.entries) {
      r -= e.value;
      if (r < 0) {
        card = e.key;
        break;
      }
    }
    String out;
    switch (card) {
      case Tarot.sun:
        final xp = 6 * k.level + 6, ups = _grantXp(xp);
        out = 'Light on the road ahead. +$xp XP${ups > 0 ? ', level up!' : ''}';
      case Tarot.wheel:
        final gold = 6 + 3 * k.level;
        k.coins += gold;
        out = 'Fortune turns your way. +$gold gold';
      case Tarot.strength:
        s.inspired = math.max(s.inspired, tarotFights);
        out = 'Your arm will not tire. You hit ${((inspiredBoost - 1) * 100).round()}% harder for your next $tarotFights fights';
      case Tarot.chariot:
        final before = maxHp(k);
        k.chariotFights = tarotFights;
        k.hp += maxHp(k) - before;
        out = 'Onward, unbroken. +${maxHp(k) - before} most health for your next $tarotFights fights';
      case Tarot.star:
        final before = k.hp;
        k.hp = maxHp(k);
        s.heroPoison = 0;
        out = k.hp > before ? 'Hope, and healing. Back to full health (+${k.hp - before} HP)' : 'Hope, and healing. You already feel whole';
      case Tarot.empress:
        _givePotions();
        out = 'Plenty. A healing potion, pressed into your hand';
      case Tarot.hermit:
        final boss = foeAt(bossIndex(s.continent)), weak = boss.kind.weakTo;
        out = weak != null && !s.bossesDown.contains(s.continent)
            ? 'The lantern shows the way. ${boss.name} fears ${_styleWord(weak)}'
            : 'The lantern shows the way. Strike where a foe is weak: +${((weakness - 1) * 100).round()}%';
      case Tarot.fool:
        s.encounter = encounters[_rng.nextInt(encounters.length)].id;
        out = 'A new road opens. Something odd waits after your next win';
      case Tarot.magician:
        k.scrolls++;
        out = 'Power in your hands. +1 scroll of enchanting (a free rune at Old Wick\'s tower)';
      case Tarot.death:
        k.brews[Brew.reaperbane.name] = 1;
        out = 'Not your ending. The next blow that would fell you leaves you standing';
      case Tarot.tower:
        final gold = math.min(k.coins, 3 + k.level);
        k.coins -= gold;
        out = gold > 0 ? 'Ruin. A purse-string snaps on the way home. −$gold gold' : 'Ruin, but you\'ve nothing left to lose';
    }
    _note('Old Corva turns ${card.title}. $out.', card.ill ? EntryKind.damage : EntryKind.good);
    return (card, '$out.');
  }

  static String _styleWord(AttackStyle st) => switch (st) {
    AttackStyle.blade => 'cold steel',
    AttackStyle.rite => 'rites',
    AttackStyle.bolt => 'bolts',
  };

  /// A night at the inn: full health, and you wake to the morning.
  int rest() {
    if (!state.innRepaired) return 0;
    final k = state.knight, before = k.hp;
    k.hp = maxHp(k);
    final healed = k.hp - before;
    _note(healed > 0 ? 'You sleep by the fire at the Soot & Kettle and recover $healed HP.' : 'You sleep by the fire. You were already fine, but the soup is good.', EntryKind.good);
    if (!state.day && state.home >= 1) {
      _givePotions();
      _note('From your herb garden: a fresh health potion.', EntryKind.good);
    }
    if (!state.day) {
      _note(
        state.won
            ? 'Morning. Real morning: blue sky over Cindervale, the first since the Burning.'
            : 'Morning, such as it is. Since the Burning, Vharrax\'s ash hangs over everything; the sun is a dull coin behind it, and noon is a brown dusk.',
      );
    }
    state
      ..day = true
      ..dayWins = 0;
    return healed;
  }

  /// A fight's worth of the day goes by; enough of them and night falls.
  void _passTime() {
    if (!state.day || ++state.dayWins < dayLength) return;
    state
      ..day = false
      ..dayWins = 0;
    _note('Dusk settles over the ash. Night again.');
  }

  // ---------------- loot ----------------

  /// Equips a pending drop. Whatever was in that slot is sold.
  /// Puts on spoils from a fight. Whatever it replaces goes into your gear chest (or, if the
  /// chest is full, is sold). Returns the gold from a sale (0 if it went in the chest).
  int equipLoot(String itemId) {
    final i = state.pendingLoot.indexWhere((g) => g.id == itemId);
    if (i < 0 || whyNotWear(state.pendingLoot[i]) != null) return 0;
    return _wear(state.pendingLoot.removeAt(i));
  }

  /// Your gear chest is full.
  /// How much gear your home's chest holds.
  int get stashCap => homes[state.home].chest;
  bool get stashFull => state.knight.stash.length >= stashCap;

  // ---------------- your home ----------------

  /// The next home up, or null at the top.
  HomeTier? get nextHome => state.home + 1 < homes.length ? homes[state.home + 1] : null;

  /// Why the next home can't be built yet (null if it can).
  String? get whyNotBuild {
    final h = nextHome, k = state.knight;
    if (h == null) return 'You have the finest home in Cindervale';
    if (!state.innRepaired) return 'Help Hob with the Soot & Kettle first';
    if (h.after >= 0 && !state.bossesDown.contains(h.after)) return 'Beat ${continents[h.after].boss.name} first';
    if (k.coins < h.gold) return 'Needs ${h.gold} gold';
    if (state.timber < h.timber) return 'Needs ${h.timber} timber';
    if (state.ironScrap < h.iron) return 'Needs ${h.iron} iron';
    return null;
  }

  bool buildHome() {
    if (whyNotBuild != null) return false;
    final h = nextHome!;
    state.knight.coins -= h.gold;
    state.timber -= h.timber;
    state.ironScrap -= h.iron;
    state.home++;
    _note(
      h.name == 'Cottage'
          ? 'Hob lends a hand and a ladder. By sundown your tent is a snug little cottage, with a herb garden out front and a chest big enough to sit on.'
          : 'Stone by stone, your cottage becomes a keep: walls, a tower, a banner with your flame on it, and an armoury racked with your gear.',
      EntryKind.gold,
    );
    return true;
  }

  /// Saves what you're wearing as gear set [i] in the keep's armoury.
  void saveGearSet(int i) {
    final k = state.knight, l = k.loadout;
    final ids = [for (final g in [l.weapon, l.offhand, l.helm, l.gloves, l.boots, l.cape, k.trinket, k.ring]) if (g != null) g.id];
    while (state.gearSets.length <= i) {
      state.gearSets.add([]);
    }
    state.gearSets[i] = ids;
    _note('You hang your gear on the armoury rack as set ${i + 1}.');
  }

  /// Puts on gear set [i]: every piece of it that's in your chest.
  int wearGearSet(int i) {
    if (i >= state.gearSets.length || state.inBattle) return 0;
    var n = 0;
    for (final id in state.gearSets[i]) {
      if (equipFromStash(id)) n++;
    }
    if (n > 0) _note('You change into gear set ${i + 1}.');
    return n;
  }

  /// Puts spoils straight into your gear chest without wearing them. False if the chest is full.
  bool keepLoot(String itemId) {
    final i = state.pendingLoot.indexWhere((g) => g.id == itemId);
    if (i < 0 || stashFull) return false;
    final item = state.pendingLoot.removeAt(i);
    state.knight.stash.add(item);
    _note('You put ${item.name} in your gear chest.', EntryKind.gold);
    return true;
  }

  /// Takes a piece out of your gear chest and wears it; what it replaces goes back in the chest.
  /// Why [item] can't be worn with what you're wielding (null if it can): a shield or tome is no
  /// use with a weapon that takes both hands, and an off-hand has to suit the weapon it's beside.
  String? whyNotWear(GearItem item) {
    if (item.slot != GearSlot.offhand) return null;
    final weapon = state.knight.loadouts[item.heroClass ?? state.knight.heroClass]?.weapon;
    if (offhandWorksWith(weapon, item)) return null;
    final name = weapon?.name ?? 'weapon';
    return offhandKindFor(weapon?.art) == null ? 'Your $name needs both hands' : 'Doesn\'t go with your $name';
  }

  bool equipFromStash(String itemId) {
    final k = state.knight, i = k.stash.indexWhere((g) => g.id == itemId);
    if (i < 0 || state.inBattle || whyNotWear(k.stash[i]) != null) return false;
    _wear(k.stash.removeAt(i));
    return true;
  }

  /// Sells a piece from your gear chest.
  int sellFromStash(String itemId) {
    final k = state.knight, i = k.stash.indexWhere((g) => g.id == itemId);
    if (i < 0) return 0;
    final item = k.stash.removeAt(i);
    k.coins += item.value;
    _note('You sell ${item.name} for ${item.value} gold.', EntryKind.gold);
    return item.value;
  }

  int _wear(GearItem item) {
    final k = state.knight;
    final old = equippedFor(item);
    final hpFrac = k.hp / maxHp(k);
    if (item.slot == GearSlot.trinket) {
      k.trinket = item;
    } else if (item.slot == GearSlot.ring) {
      k.ring = item;
    } else if (item.slot == GearSlot.armour) {
      k.loadouts[item.heroClass ?? k.heroClass]!.armour = item.art;
    } else {
      k.loadouts[item.heroClass ?? k.heroClass]!.put(item);
    }
    // The old piece goes into the chest, unless it's full.
    var sold = 0;
    if (old != null && k.stash.length < stashCap) {
      k.stash.add(old);
    } else if (old != null) {
      sold = old.value;
      k.coins += sold;
    }
    k.hp = math.max(1, (maxHp(k) * hpFrac).round()); // keep the same share of health
    _note(
      'You equip ${item.name}${old == null ? '' : (sold > 0 ? ' and sell your ${old.name} for $sold gold (your chest is full)' : '; your ${old.name} goes in your gear chest')}.',
      EntryKind.gold,
    );
    final kit = k.loadouts[item.heroClass ?? k.heroClass]!;
    if (kit.offhand != null && kit.activeOffhand == null && (item.slot == GearSlot.weapon || item.slot == GearSlot.offhand)) {
      _note('Your ${kit.offhand!.name} won\'t be used with ${kit.weapon?.name ?? 'bare hands'}: it waits in your kit.');
    }
    return sold;
  }

  /// What [item] would replace: the trinket, the ring, or that slot in its own class's kit.
  GearItem? equippedFor(GearItem item) =>
      item.slot == GearSlot.trinket ? state.knight.trinket : (item.slot == GearSlot.ring ? state.knight.ring : state.knight.loadouts[item.heroClass ?? state.knight.heroClass]!.inSlot(item.slot));

  /// Whether [item] is junk: common or uncommon, nothing special, and no better than what you
  /// wear (or can't be worn with your weapon). With the setting on, junk is sold where it falls.
  bool isJunk(GearItem item) {
    if (item.rarity.index > Rarity.uncommon.index || item.special != null || item.gearSet != null || item.enchant != null) return false;
    if (item.slot == GearSlot.armour) return armourTierById(item.art).reduction <= armourTierById(state.knight.loadouts[item.heroClass ?? state.knight.heroClass]!.armour).reduction;
    final old = equippedFor(item);
    return old != null && (item.score <= old.score || whyNotWear(item) != null);
  }

  /// Sells the junk that's just dropped (from [from] on in the spoils), if the setting's on.
  int _sellJunk(int from) {
    if (!state.settings.autoSellJunk || state.wildFight) return 0;
    var gold = 0;
    for (var i = state.pendingLoot.length - 1; i >= from; i--) {
      final g = state.pendingLoot[i];
      if (!isJunk(g)) continue;
      state.pendingLoot.removeAt(i);
      state.knight.coins += g.value;
      gold += g.value;
    }
    if (gold > 0) _note('Junk sold where it fell: +$gold gold.', EntryKind.gold);
    return gold;
  }

  int sellLoot(String itemId) {
    final i = state.pendingLoot.indexWhere((g) => g.id == itemId);
    if (i < 0) return 0;
    final item = state.pendingLoot.removeAt(i);
    state.knight.coins += item.value;
    _note('You sell ${item.name} for ${item.value} gold.', EntryKind.gold);
    return item.value;
  }

  // ---------------- the merchant ----------------

  int priceOf(String id) {
    final ammo = id.startsWith('ammo:') ? ammoById(id.substring(5)) : null;
    final lvl = state.knight.level;
    if (ammo != null) return ammo.price + 2 * lvl;
    final mount = id.startsWith('mount:') ? mountById(id.substring(6)) : null;
    if (mount != null) return mount.dropOnly ? 1 << 30 : mount.price;
    final tier = armourTiers.where((a) => a.id == id).firstOrNull;
    // Potions get stronger and dearer as you level.
    return switch (id) {
      'crossbow' => state.knight.crossbow + 1 < crossbows.length ? crossbows[state.knight.crossbow + 1].$3 : 1 << 30,
      'potion' => 20 + 2 * lvl,
      'boots' => 40 + 6 * lvl,
      'ringbox' => 60 + 10 * lvl,
      'bonecarver' => 90 + 12 * lvl,
      _ => id.startsWith('dye:') ? (dyeById(id.substring(4)).price ?? prices['dye']!) : (tier?.price ?? prices[id] ?? 1 << 30),
    };
  }

  bool owns(String id) {
    final k = state.knight;
    if (id.startsWith('dye:')) return k.ownedDyes.contains(id.substring(4));
    if (id.startsWith('mount:')) return k.mounts.contains(id.substring(6));
    final tier = armourTiers.where((a) => a.id == id).firstOrNull;
    // Already wearing something at least as protective (a shop tier, or a variant won in battle).
    if (tier != null) return armourTierById(k.loadouts[tier.heroClass]!.armour).reduction >= tier.reduction;
    return switch (id) {
      'crossbow' => k.crossbow + 1 >= crossbows.length,
      'gloves' => k.gloves,
      'potion' => k.potions >= potionBelt,
      'boots' => k.loadout.boots != null,
      _ => false,
    };
  }

  /// Whether the merchant sells [id] at all (some armour and steeds are only ever won; the better
  /// armour and the special bolts are forged from what you bring her).
  bool engineSells(String id) => !armourTiers.any((t) => t.id == id && (t.dropOnly || isCrafted(t.id))) && !id.startsWith('ammo:') && !(id.startsWith('mount:') && (mountById(id.substring(6))?.dropOnly ?? true));

  /// Rides [id] (or goes on foot with null). Only mounts you own.
  void setMount(String? id) {
    final k = state.knight;
    if (id != null && !k.mounts.contains(id)) return;
    k.mount = id;
  }

  /// A new mount joins your stable, and you ride it if it charges harder than the one you're on.
  void _gainMount(String id) {
    final k = state.knight, m = mountById(id);
    if (m == null || k.mounts.contains(id)) return;
    k.mounts.add(id);
    if ((mountById(k.mount)?.charge ?? 0) < m.charge) k.mount = id;
  }

  bool purchase(String id) {
    final k = state.knight, price = priceOf(id);
    if (state.inBattle || k.coins < price || owns(id) || !engineSells(id)) return false;
    k.coins -= price;
    String what;
    final ammo = id.startsWith('ammo:') ? ammoById(id.substring(5)) : null;
    if (ammo != null) {
      k.ammo[ammo.name] = (k.ammo[ammo.name] ?? 0) + ammoBundle;
      k.ammoLoaded ??= ammo.name;
      _note('You buy $ammoBundle ${ammo.label(Missile.bolt).toLowerCase()} for $price gold.', EntryKind.gold);
      return true;
    }
    final mount = id.startsWith('mount:') ? mountById(id.substring(6)) : null;
    if (mount != null) {
      _gainMount(mount.id);
      _note('You buy ${withArticle(mount.name.toLowerCase())} for $price gold. Every fight now opens with a charge.', EntryKind.gold);
      return true;
    }
    switch (id) {
      case 'crossbow':
        k.crossbow++;
        what = withArticle(crossbows[k.crossbow].$1.toLowerCase());
      case 'potion':
        _givePotions();
        what = 'a health potion';
      case 'poison':
        k.poisonFights = 3;
        what = 'weapon poison (3 fights)';
      case 'gloves':
        k.gloves = true;
        what = glovesName(k.heroClass).toLowerCase();
      case 'boots':
        // A plain, sturdy pair from the cobbler (better ones come from battle).
        k.loadout.boots = loot.roll(k.heroClass, k.level, odds: const [100, 0, 0, 0, 0], only: GearSlot.boots);
        what = k.loadout.boots!.name.toLowerCase();
      case 'bonecarver':
        // The bone carver's pouch: a dragonbone ring or fang amulet, from the dragons of the lands
        // you've reached (the Obsidian and Elder pieces only ever come from the dragons themselves).
        final tier = wyrmTiers[(state.unlocked - 1).clamp(0, 2)];
        final jewel = loot.dragonboneJewel(k.level, tier, ring: _rng.nextBool(), rarity: _rng.nextDouble() < .8 ? Rarity.rare : Rarity.epic);
        state.pendingLoot.add(jewel);
        what = 'a bone carver\'s pouch. Inside: ${jewel.name} (${jewel.rarity.label})';
      case 'ringbox':
        // A jeweller's box: you don't know which ring until it's open.
        final ring = loot.roll(k.heroClass, k.level, odds: const [0, 55, 35, 9, 1], only: GearSlot.ring);
        state.pendingLoot.add(ring);
        what = 'a jeweller\'s box. Inside: ${ring.name} (${ring.rarity.label})';
      default:
        if (id.startsWith('dye:')) {
          final d = id.substring(4);
          k.ownedDyes.add(d);
          k.dye = d;
          what = '${dyeById(d).name.toLowerCase()} dye';
        } else {
          final tier = armourTierById(id);
          k.loadouts[tier.heroClass]!.armour = tier.id;
          what = tier.name.toLowerCase();
        }
    }
    _note('You buy $what for $price gold.', EntryKind.gold);
    return true;
  }

  // ---------------- the Ember Vault ----------------

  String? get whyNotVault {
    // (A trip into the wilds is no bar: you're back in town, and the shops serve you too.)
    if (state.inBattle) return 'Not mid-fight';
    if (state.keys <= 0) return 'You need a Cinder key';
    return null;
  }

  /// Turns a Cinder key in the Ember Vault's door: one of its own pieces (one you haven't found,
  /// while there are any), or good gear and gold, or gold alone. Gear goes to your spoils.
  VaultFind? openVault() {
    if (whyNotVault != null) return null;
    final s = state, k = s.knight;
    s.keys--;
    final gold = (25 * k.level + 40) * (1 + heroStats(k).fortune / 100) * (.8 + _rng.nextDouble() * .4);
    final roll = _rng.nextDouble();
    VaultFind find;
    final unfound = [for (final p in vaultPieces) if (!s.vaultFound.contains(p.name)) p];
    final sure = unfound.isNotEmpty && s.vaultDry >= vaultSure;
    if (sure || roll < vaultPieceChance) {
      s.vaultDry = 0;
      final pool = unfound.isEmpty ? vaultPieces : unfound;
      final piece = pool[_rng.nextInt(pool.length)];
      final g = loot.vaultPiece(piece, k.level);
      if (!s.vaultFound.contains(piece.name)) {
        s.vaultFound.add(piece.name);
        if (guardianSworn(s.vaultFound)) _note('The last of the vault\'s treasures is yours. You swear the Guardian\'s Oath: from now on, the first heavy blow in every fight lands no harder than a normal one.', EntryKind.good);
      }
      find = VaultFind((gold * .5).round(), g, piece: true);
    } else if (roll < vaultPieceChance + vaultGearChance) {
      s.vaultDry++;
      find = VaultFind((gold * .6).round(), loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: const [0, 0, 60, 35, 5]));
    } else {
      s.vaultDry++;
      find = VaultFind((gold * 1.6).round(), null);
    }
    k.coins += find.gold;
    if (find.item != null) s.pendingLoot.add(find.item!);
    _note(
      find.piece
          ? 'The vault door groans open. On a velvet cushion, untouched for a hundred years: ${find.item!.name}! (+${find.gold} gold)'
          : find.item != null
          ? 'The vault door groans open: ${find.item!.name} (${find.item!.rarity.label}) and a purse. (+${find.gold} gold)'
          : 'The vault door groans open on a heap of old coin. (+${find.gold} gold)',
      EntryKind.gold,
    );
    return find;
  }

  // ---------------- Mags' find of the day ----------------

  /// Today, as days since 1970 (by the player's own clock: a new find every midnight).
  int get _today {
    final n = clock();
    return DateTime.utc(n.year, n.month, n.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  /// Mags' find of the day: one piece of gear, seen before you buy it, new every day. Anything
  /// from a dud to (rarely) a legendary, but never a relic or a quest weapon.
  GearItem get dailyDeal {
    final s = state, k = s.knight;
    if (s.dealDay != _today || s.deal == null) {
      GearItem g;
      var tries = 0;
      do {
        g = loot.roll(k.heroClass, k.level, wielding: k.loadout.weapon, odds: const [12, 44, 30, 12, 2]);
      } while (g.special != null && ++tries < 20);
      s
        ..dealDay = _today
        ..deal = g
        ..dealBought = false;
    }
    return s.deal!;
  }

  /// What Mags wants for today's find: by its rarity, at the level it was found.
  int get dealPrice {
    final g = dailyDeal;
    final base = 50 + 10 * g.level;
    return switch (g.rarity) {
      Rarity.common => base ~/ 2,
      Rarity.uncommon => base,
      Rarity.rare => base * 2,
      Rarity.epic => base * 4,
      Rarity.legendary => base * 9,
    };
  }

  /// Time until a new find.
  Duration get untilNextDeal {
    final n = clock();
    return DateTime(n.year, n.month, n.day + 1).difference(n);
  }

  String? get whyNotDeal {
    if (state.dealBought && state.dealDay == _today) return 'Sold out: back tomorrow';
    if (state.knight.coins < dealPrice) return 'Not enough gold';
    return null;
  }

  bool buyDeal() {
    if (whyNotDeal != null) return false;
    final g = dailyDeal, price = dealPrice;
    state.knight.coins -= price;
    state.dealBought = true;
    state.pendingLoot.add(g);
    _note('You buy Mags\' find of the day: ${g.name} (${g.rarity.label}) for $price gold.', EntryKind.gold);
    return true;
  }

  // ---------------- the forge: ore, bars, armour and bolts ----------------

  /// The golem (its metal) that turns up as you set out into [c], if one does.
  /// The elemental that rises as you set out into [c], if one does.
  Elemental? _elementalFor(int c) {
    var roll = _rng.nextDouble();
    for (final (el, chance) in elementalLands[c] ?? const <(Elemental, double)>[]) {
      if (roll < chance) return el;
      roll -= chance;
    }
    return null;
  }

  /// Why Old Wick can't bind [el]'s cores into a rune on your weapon (null: she can).
  String? whyNotBind(Elemental el) {
    final k = state.knight;
    if (state.inBattle) return 'Not mid-fight';
    if (k.loadout.weapon == null) return 'No weapon';
    final have = state.mat(coreKey(el));
    if (have < coresPerRune) return 'Needs $coresPerRune ${el.core.toLowerCase()}s (you have $have)';
    if (k.coins < enchantCost(k.level)) return 'Needs ${enchantCost(k.level)} gold';
    return null;
  }

  /// Old Wick binds three of [el]'s cores into its rune (tier II, sometimes III), offered for your
  /// weapon: keep it or keep what you have, as with any rune.
  EnchantRoll? bindCores(Elemental el) {
    if (whyNotBind(el) != null) return null;
    final k = state.knight;
    state.addMat(coreKey(el), -coresPerRune);
    k.coins -= enchantCost(k.level);
    final roll = boundRune(el.rune, k.level, _rng);
    _note('Old Wick cracks the ${el.core.toLowerCase()}s into her crucible and draws a rune out of the light: ${roll.title} (${roll.describe}).', EntryKind.gold);
    return roll;
  }

  Metal? _golemFor(int c) {
    var roll = _rng.nextDouble();
    for (final (metal, chance) in golemLands[c] ?? const <(Metal, double)>[]) {
      if (roll < chance) return metal;
      roll -= chance;
    }
    return null;
  }

  /// Something waiting at the forge: ore to smelt, or armour you could forge right now.
  bool get forgeReady =>
      Metal.values.any((m) => whyNotSmelt(m) == null) ||
      armourRecipes.keys.any((id) => armourTierById(id).heroClass == state.knight.heroClass && whyNotCraft(id) == null) ||
      // A set piece you could forge and aren't wearing yet.
      forgedSets.any((f) => setPieceSlots.any((slot) => whyNotForgePiece(f.id, slot) == null && !state.knight.gear.any((g) => g.gearSet == f.id && g.slot == slot)));

  /// Gems you could have ground into bolts.
  bool get gemsWaiting => Gem.values.any((g) => whyNotFletch(g) == null) || Elemental.values.any((el) => whyNotBind(el) == null);

  /// Bars [metal]'s ore would make now, and what the smith asks for them.
  int barsFrom(Metal metal) => state.mat(oreKey(metal)) ~/ orePerBar;
  int smeltCost(Metal metal) => barsFrom(metal) * smeltFee(state.knight.level);

  String? whyNotSmelt(Metal metal) {
    if (state.inBattle) return 'Not mid-fight';
    if (barsFrom(metal) == 0) return 'Needs $orePerBar ${metal.ore.toLowerCase()}';
    if (state.knight.coins < smeltCost(metal)) return 'Needs ${smeltCost(metal)} gold';
    return null;
  }

  /// Smelts all of [metal]'s ore into bars (two lumps a bar). Returns the bars made.
  int smelt(Metal metal) {
    if (whyNotSmelt(metal) != null) return 0;
    final bars = barsFrom(metal), cost = smeltCost(metal);
    state.knight.coins -= cost;
    state.addMat(oreKey(metal), -bars * orePerBar);
    state.addMat(barKey(metal), bars);
    _note('Dunstan\'s furnace roars. ${bars * orePerBar} ${metal.ore.toLowerCase()} becomes $bars ${metal.bar.toLowerCase()}${bars == 1 ? '' : 's'} ($cost gold).', EntryKind.gold);
    return bars;
  }

  /// Why Dunstan can't forge armour tier [id] for you now (null if she can).
  String? whyNotCraft(String id) {
    final recipe = armourRecipes[id];
    if (recipe == null) return 'Not forged';
    if (state.inBattle) return 'Not mid-fight';
    if (owns(id)) return 'You have as good';
    for (final e in recipe.bars.entries) {
      if (state.mat(barKey(e.key)) < e.value) return 'Needs ${e.value} ${e.key.bar.toLowerCase()}s';
    }
    if (state.knight.coins < recipe.gold) return 'Needs ${recipe.gold} gold';
    return null;
  }

  /// Dunstan forges armour tier [id] from bars and gold, and you put it on.
  bool craftArmour(String id) {
    if (whyNotCraft(id) != null) return false;
    final recipe = armourRecipes[id]!, tier = armourTierById(id);
    for (final e in recipe.bars.entries) {
      state.addMat(barKey(e.key), -e.value);
    }
    state.knight.coins -= recipe.gold;
    state.knight.loadouts[tier.heroClass]!.armour = tier.id;
    _note('Dunstan hammers the bars into shape: ${tier.name}! Damage taken −${(tier.reduction * 100).round()}%.', EntryKind.gold);
    return true;
  }

  /// Why Dunstan can't forge the [slot] piece of forged set [setId] yet (null: he can).
  String? whyNotForgePiece(String setId, GearSlot slot) {
    final f = forgedSetById(setId);
    if (f == null) return 'No such set';
    if (state.inBattle) return 'Not mid-fight';
    if (state.mat(blueprintKey(setId, slot)) == 0) return 'Find the blueprint first';
    final have = state.mat(trophyKey(f.trophy));
    if (have < pieceTrophies) return 'Needs $pieceTrophies ${f.trophy.label.toLowerCase()} (you have $have)';
    if (state.mat(barKey(f.metal)) < pieceBars) return 'Needs $pieceBars ${f.metal.bar.toLowerCase()}s';
    if (state.knight.coins < pieceFee(state.knight.level)) return 'Needs ${pieceFee(state.knight.level)} gold';
    return null;
  }

  /// Dunstan forges a set piece from its blueprint (kept for next time), trophies, bars and gold.
  /// It goes into your spoils, at your level.
  GearItem? forgePiece(String setId, GearSlot slot) {
    if (whyNotForgePiece(setId, slot) != null) return null;
    final f = forgedSetById(setId)!, k = state.knight;
    state
      ..addMat(trophyKey(f.trophy), -pieceTrophies)
      ..addMat(barKey(f.metal), -pieceBars);
    k.coins -= pieceFee(k.level);
    final item = loot.setPiece(setId, slot, k.heroClass, k.level);
    state.pendingLoot.add(item);
    _note('$smithName spreads out the blueprint, weighs the ${f.trophy.label.toLowerCase()} in his hand, and gets to work. By evening: ${item.name}.', EntryKind.gold);
    return item;
  }

  // ---------------- tempering ----------------

  /// The weapon in your hand, if it's worth tempering: epic or legendary (a farmed prize, a relic,
  /// a set piece), and at least [temperMinGap] levels behind you.
  /// What you wear that Dunstan can temper: epic and legendary pieces a few levels behind you
  /// (vault pieces keep up on their own).
  List<GearItem> get temperables {
    final k = state.knight;
    return [
      for (final g in k.gear)
        if (g.rarity.index >= Rarity.epic.index && g.gearSet != 'vault' && k.level - g.level >= temperMinGap) g,
    ];
  }

  /// What tempering [g] costs, in gold.
  int temperCost(GearItem g) => temperFee(state.knight.level, state.knight.level - g.level, legendary: g.rarity == Rarity.legendary);

  String? whyNotTemper(GearItem g) {
    if (state.inBattle) return 'Not mid-fight';
    if (!temperables.any((t) => t.id == g.id)) return 'Already close to your level';
    if (state.knight.coins < temperCost(g)) return 'Needs ${temperCost(g)} gold';
    return null;
  }

  /// Dunstan reworks [g] (something you wear) up to your level.
  // ---------------- New Game+ ----------------

  /// Why you can't start the road again yet (null: you can).
  String? whyNotNewGamePlus() {
    final s = state;
    if (!s.won) return 'Defeat the Ember King first';
    if (s.inBattle) return 'Not mid-fight';
    if (s.wild != null || s.dungeon != null) return 'Come back to town first';
    return null;
  }

  /// New Game+: the Ember King fell, and the ash comes back thicker. You start again at level 1 in
  /// Cindervale with nothing but your name, your looks, your Cinder keys and the vault's own pieces
  /// (back to level 1, growing with you as ever: worn where they were worn). Everything else
  /// starts over, and every foe is tougher for it ([ngFoeHp], [ngFoeHit]) while legendaries
  /// drop more often.
  bool newGamePlus() {
    if (whyNotNewGamePlus() != null) return false;
    final old = state, k = old.knight;
    final fresh = newGame(heroClass: k.heroClass);
    final n = fresh.knight;
    n
      ..female = k.female
      ..dye = k.dye
      ..ownedDyes = [...k.ownedDyes];
    // The vault's pieces: each one you own comes along once, worn if it was worn.
    final seen = <String>{};
    GearItem? carry(GearItem? g) {
      if (g == null || g.gearSet != 'vault' || !seen.add(g.name)) return null;
      final p = vaultPieceNamed(g.name);
      return p == null ? null : loot.vaultPiece(p, 1);
    }
    final l = k.loadout, nl = n.loadout;
    nl
      ..helm = carry(l.helm) ?? nl.helm
      ..gloves = carry(l.gloves) ?? nl.gloves
      ..boots = carry(l.boots) ?? nl.boots;
    n
      ..trinket = carry(k.trinket)
      ..ring = carry(k.ring);
    for (final g in [
      for (final lo in k.loadouts.values) ...[lo.helm, lo.gloves, lo.boots],
      ...k.stash,
      ...old.pack,
      ...old.pendingLoot,
    ]) {
      final c = carry(g);
      if (c != null) n.stash.add(c);
    }
    n.hp = maxHp(n);
    fresh
      ..settings = old.settings
      ..ng = old.ng + 1
      ..keys = old.keys
      ..vaultDry = old.vaultDry
      ..seasonSeen = old.seasonSeen
      ..foesFelled = old.foesFelled
      ..raresFelled = old.raresFelled
      ..chestsOpened = old.chestsOpened
      ..knockouts = old.knockouts
      ..flees = old.flees;
    fresh.vaultFound.addAll(old.vaultFound);
    fresh.journal
      ..clear()
      ..add(JournalEntry('New Game+ ${'★' * math.min(fresh.ng, 5)}: the ash comes back thicker, and so do the things in it. You start again in Cindervale, the vault\'s pieces still on you.', EntryKind.gold));
    state = fresh;
    loot.ng = fresh.ng;
    return true;
  }

  GearItem? temper(GearItem g) {
    if (whyNotTemper(g) != null) return null;
    final k = state.knight, gold = temperCost(g), better = tempered(g, temperTo(g.level, k.level));
    k.coins -= gold;
    if (identical(k.trinket, g) || k.trinket?.id == g.id) {
      k.trinket = better;
    } else if (k.ring?.id == g.id) {
      k.ring = better;
    } else {
      final l = k.loadout;
      if (l.weapon?.id == g.id) l.weapon = better;
      if (l.offhand?.id == g.id) l.offhand = better;
      if (l.helm?.id == g.id) l.helm = better;
      if (l.gloves?.id == g.id) l.gloves = better;
      if (l.boots?.id == g.id) l.boots = better;
      if (l.cape?.id == g.id) l.cape = better;
    }
    _note('$smithName heats ${g.name} white and hammers until dark. It comes out level ${better.level}, and hungry. (−$gold gold)', EntryKind.gold);
    return better;
  }

  String? whyNotFletch(Gem gem) {
    if (state.inBattle) return 'Not mid-fight';
    if (state.mat(gemKey(gem)) <= 0) return 'Needs ${withArticle(gem.label.toLowerCase())}';
    if (state.knight.coins < fletchFee(state.knight.level)) return 'Needs ${fletchFee(state.knight.level)} gold';
    return null;
  }

  /// Old Wick grinds [gem] into a bundle of special bolts.
  bool fletch(Gem gem) {
    if (whyNotFletch(gem) != null) return false;
    final k = state.knight, fee = fletchFee(k.level), ammo = gem.ammo;
    state.addMat(gemKey(gem), -1);
    k.coins -= fee;
    k.ammo[ammo.name] = (k.ammo[ammo.name] ?? 0) + ammoBundle;
    k.ammoLoaded ??= ammo.name;
    _note('Old Wick grinds the ${gem.label.toLowerCase()} to glittering dust and works it into $ammoBundle ${ammo.label(Missile.bolt).toLowerCase()} ($fee gold).', EntryKind.gold);
    return true;
  }

  // ---------------- Mags' apothecary ----------------

  /// Why Mags can't brew [b] for you now (null if she can).
  String? whyNotBrew(Brew b) {
    if (state.inBattle) return 'Not mid-fight';
    if (b == Brew.reaperbane && brewOn(state.knight, b)) return 'It\'s still in you';
    // A top-up only brings it back to full: nothing to gain (and reagents to lose) while it is.
    if ((state.knight.brews[b.name] ?? 0) >= brewFights) return 'Already full: $brewFights fights left';
    if (state.reagents[b.land] < b.reagents) return 'Needs ${b.reagents} ${b.ingredient}';
    if (state.knight.coins < b.fee(state.knight.level)) return 'Needs ${b.fee(state.knight.level)} gold';
    return null;
  }

  /// Mags brews [b] from your reagents. Healing draughts go on your belt; anything else you drink
  /// there and then, and it works for your next few fights (a fresh one tops up the same kind).
  bool brew(Brew b) {
    if (whyNotBrew(b) != null) return false;
    final k = state.knight, fee = b.fee(k.level);
    state.reagents[b.land] -= b.reagents;
    k.coins -= fee;
    {
      k.brews[b.name] = b == Brew.reaperbane ? 1 : brewFights;
      _note(b == Brew.reaperbane
          ? 'Mags grinds the tomb salt, mutters something over it and makes you drink it all. It tastes of dust and coins. Reaper\'s Bane: the next blow that would fell you won\'t ($fee gold).'
          : 'Mags pours you ${withArticle(b.label.toLowerCase())} and watches you drink it. ${b.desc} ($fee gold).', EntryKind.gold);
    }
    return true;
  }

  // ---------------- the enchanter ----------------

  /// Pays the enchanter for a random rune on your weapon or armour. Returns the rune on offer
  /// (keep it with [applyEnchant], or keep what you had), or null if you can't pay.
  EnchantRoll? enchantOffer(EnchantSlot slot, {bool scroll = false}) {
    final k = state.knight, cost = scroll ? 0 : enchantCost(k.level);
    if (k.coins < cost || (scroll && k.scrolls <= 0) || (slot == EnchantSlot.weapon && k.loadout.weapon == null)) return null;
    k.coins -= cost;
    if (scroll) k.scrolls--;
    final roll = rollEnchant(slot, k.level, _rng);
    _note('The enchanter works a rune for $cost gold: ${roll.title} (${roll.describe}).', EntryKind.gold);
    return roll;
  }

  /// Pays (or reads a scroll) for three runes to choose from; keep one with [applyEnchant], or
  /// keep what you had. Empty if you can't pay.
  List<EnchantRoll> enchantChoices(EnchantSlot slot, {bool scroll = false}) {
    final k = state.knight, cost = scroll ? 0 : enchantCost(k.level);
    if (k.coins < cost || (scroll && k.scrolls <= 0) || (slot == EnchantSlot.weapon && k.loadout.weapon == null)) return const [];
    k.coins -= cost;
    if (scroll) k.scrolls--;
    final choices = rollChoices(slot, k.level, _rng, skip: {if (dragonStage(k) == null) 'wyrmslayer'});
    _note('${scroll ? 'You read a scroll of enchanting' : 'The enchanter works for $cost gold'}: ${choices.map((r) => r.title).join(', ')} take shape.', EntryKind.gold);
    return choices;
  }

  /// Weapons in your chest with a rune worth moving onto the one in your hand.
  List<GearItem> get runedSpares {
    final k = state.knight, held = k.loadout.weapon;
    return [for (final g in k.stash) if (g.slot == GearSlot.weapon && g.enchant != null && !identical(g, held)) g];
  }

  /// What Old Wick charges to lift a rune off one weapon and set it in another (half a new one).
  int get runeMoveCost => enchantCost(state.knight.level) ~/ 2;

  /// Why a rune can't be moved off [from] right now (null if it can).
  String? whyNotMoveRune(GearItem from) {
    final k = state.knight;
    if (k.loadout.weapon == null) return 'Hold a weapon first';
    if (from.enchant == null) return 'No rune on it';
    if (k.coins < runeMoveCost) return 'Not enough gold';
    return null;
  }

  /// Old Wick lifts the rune off [from] (left plain, in your chest) and sets it in the weapon in
  /// your hand, replacing any rune it had. A rune keeps its tier and strength.
  bool moveRune(GearItem from) {
    if (whyNotMoveRune(from) != null) return false;
    final k = state.knight, to = k.loadout.weapon!, rune = from.enchant!;
    k.coins -= runeMoveCost;
    from.enchant = null;
    to.enchant = rune;
    _note('Old Wick lifts ${rune.title} off your ${from.name} and sets it in your ${to.name} ($runeMoveCost gold).', EntryKind.gold);
    return true;
  }

  void applyEnchant(EnchantSlot slot, EnchantRoll roll) {
    final kit = state.knight.loadout;
    if (slot == EnchantSlot.weapon) {
      kit.weapon?.enchant = roll;
    } else {
      kit.armourEnchant = roll;
    }
    _note('Your ${slot == EnchantSlot.weapon ? kit.weapon?.name ?? 'weapon' : armourTierById(kit.armour).name.toLowerCase()} now bears ${roll.title}.', EntryKind.gold);
  }

  /// Chooses which companion fights ('dragon' or a Pet name).
  void setCompanion(String id) {
    final k = state.knight;
    if ((id == 'dragon' && k.hasDragon) || k.pets.containsKey(id)) k.activePet = id;
  }

  /// Loads a kind of ammunition you own.
  void loadAmmo(String type) {
    if ((state.knight.ammo[type] ?? 0) > 0) state.knight.ammoLoaded = type;
  }

  /// Swaps to the next kind of bolt you carry, plain ones in between. Any time, even mid-fight
  /// (a frost elemental just turned up and you've fire loaded): it costs no turn.
  String? cycleAmmo() {
    final k = state.knight;
    final order = [null, for (final a in AmmoType.values) if ((k.ammo[a.name] ?? 0) > 0) a.name];
    if (order.length == 1) return null;
    k.ammoLoaded = order[(order.indexOf(k.ammoLoaded) + 1) % order.length];
    return k.ammoLoaded;
  }

  void wearDye(String id) {
    final k = state.knight;
    if (k.ownedDyes.contains(id)) k.dye = id;
  }

  // ---------------- classes ----------------

  void chooseClass(HeroClass c) {
    final k = state.knight;
    k
      ..heroClass = c
      ..classChosen = true;
    k.hp = maxHp(k);
    _note('You set out as a ${c.label.toLowerCase()}.', EntryKind.good);
  }

  /// Retrain as another class at the Inn. Level and gold stay; each class keeps its own kit.
  bool retrain(HeroClass c) {
    final k = state.knight, cost = retrainCost(k.level);
    if (state.inBattle || c == k.heroClass || k.coins < cost) return false;
    final frac = k.hp / maxHp(k);
    k.coins -= cost;
    k.heroClass = c;
    k.hp = math.max(1, (maxHp(k) * frac).round());
    _note('You retrain at the Inn and take up the path of the ${c.label.toLowerCase()} ($cost gold).', EntryKind.gold);
    return true;
  }

  void applySettings(Settings next) => state.settings = next;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String glovesName(HeroClass c) => switch (c) {
  HeroClass.knight => 'Gauntlets',
  HeroClass.mage => 'Spellweaver gloves',
  HeroClass.ranger => "Archer's bracers",
};

/// How scorched the hero still looks: 1 at level 1 (soot everywhere), fading to 0 by level 30.
double sootFor(int level) => (1 - (level - 1) / 29).clamp(0.0, 1.0);

/// From level 30 the hero doesn't just look clean: they shine.
bool shinesAt(int level) => level >= 30;

/// How the hero looks, in a few words.
String sootLabel(int level) => switch (sootFor(level)) {
  _ when shinesAt(level) => 'shining',
  > .7 => 'covered in soot',
  > .4 => 'still quite sooty',
  > .1 => 'a little sooty',
  _ => 'nearly spotless',
};

/// A word on the hero's look as they level, for the level-up line.
String shineLine(int level) => switch (level) {
  >= 30 => 'Not a speck of soot left. You positively shine.',
  >= 20 => 'You catch your reflection in your armour. Barely sooty at all.',
  >= 10 => 'Some of the soot has finally washed off.',
  _ => 'You brush a little soot off your shoulders.',
};
