// Saved game state. Pure Dart; serialised to JSON and kept in the browser.

import 'dart:math' as math;
import 'catalog.dart';
import 'encounters.dart' show chestEvery;
import 'classes.dart';
import 'loot.dart';

class Settings {
  Settings({this.name = 'Sir Smudge', this.guest = false, this.tourSeen = false, this.fastFights = false, this.gore = true, this.music = .5, this.sound = .8, this.muted = false, this.autoSellJunk = true});

  /// Common and uncommon drops that are no upgrade are sold where they fall.
  bool autoSellJunk;

  String name;

  /// Chose to play without signing in (the hero stays on this device); the sign-in screen stays
  /// away until you sign out.
  bool guest;

  /// The first-visit tips at the Inn have been shown.
  bool tourSeen;

  /// Fights play a little quicker.
  bool fastFights;

  /// Blood on hits (off: sparks only).
  bool gore;

  /// Music and sound-effect volumes, 0 to 1, and a switch for all sound.
  double music, sound;
  bool muted;

  Settings copy() => Settings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'name': name,
    if (guest) 'guest': true,
    if (tourSeen) 'tour': true,
    if (fastFights) 'fast': true,
    if (!gore) 'gore': false,
    'music': music,
    'sound': sound,
    if (muted) 'mute': true,
    if (!autoSellJunk) 'junk': false,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    name: j['name'] as String? ?? 'Sir Smudge',
    guest: j['guest'] == true,
    tourSeen: j['tour'] == true,
    fastFights: j['fast'] == true,
    gore: j['gore'] != false,
    music: (j['music'] as num?)?.toDouble() ?? .5,
    sound: (j['sound'] as num?)?.toDouble() ?? .8,
    muted: j['mute'] == true,
    autoSellJunk: j['junk'] != false,
  );
}

/// What one class has equipped. Each class keeps its own, so retraining and coming back
/// restores your old kit.
class Loadout {
  Loadout({required this.armour, this.weapon, this.offhand, this.helm, this.armourEnchant, this.gloves, this.boots, this.cape});
  String armour;
  GearItem? weapon, offhand, helm, gloves, boots, cape;

  /// A rune on this kit's armour (it stays when the armour is upgraded).
  EnchantRoll? armourEnchant;

  factory Loadout.starter(HeroClass c) => Loadout(armour: tiersFor(c).first.id, weapon: starterWeapon(c));

  GearItem? inSlot(GearSlot s) => switch (s) {
    GearSlot.weapon => weapon,
    GearSlot.offhand => offhand,
    GearSlot.helm => helm,
    GearSlot.gloves => gloves,
    GearSlot.boots => boots,
    GearSlot.cape => cape,
    GearSlot.trinket || GearSlot.armour || GearSlot.ring => null,
  };

  /// The off-hand, if it suits the weapon in hand (otherwise it waits, doing nothing).
  GearItem? get activeOffhand => offhandWorksWith(weapon, offhand) ? offhand : null;

  void put(GearItem item) {
    switch (item.slot) {
      case GearSlot.weapon:
        weapon = item;
      case GearSlot.offhand:
        offhand = item;
      case GearSlot.helm:
        helm = item;
      case GearSlot.gloves:
        gloves = item;
      case GearSlot.boots:
        boots = item;
      case GearSlot.cape:
        cape = item;
      case GearSlot.trinket || GearSlot.ring:
        break;
      case GearSlot.armour:
        armour = item.art;
    }
  }

  Map<String, dynamic> toJson() => {
    'armour': armour,
    'weapon': weapon?.toJson(),
    'offhand': offhand?.toJson(),
    'helm': helm?.toJson(),
    if (gloves != null) 'gloves': gloves!.toJson(),
    if (boots != null) 'boots': boots!.toJson(),
    if (cape != null) 'cape': cape!.toJson(),
    if (armourEnchant != null) 'armourEnchant': armourEnchant!.toJson(),
  };

  factory Loadout.fromJson(Map<String, dynamic> j, HeroClass c) => Loadout(
    armour: armourTierById(j['armour'] as String? ?? tiersFor(c).first.id).id,
    weapon: _item(j['weapon']) ?? starterWeapon(c),
    offhand: _item(j['offhand']),
    helm: _item(j['helm']),
    gloves: _item(j['gloves']),
    boots: _item(j['boots']),
    cape: _item(j['cape']),
    armourEnchant: EnchantRoll.fromJson(j['armourEnchant']),
  );
}

GearItem? _item(Object? j) => j is Map ? GearItem.fromJson(j.cast<String, dynamic>()) : null;

/// The player's hero. (Named Knight for history; it holds any class.)
class Knight {
  Knight({
    this.level = 1,
    this.xp = 0,
    this.hp = 100,
    this.coins = 0,
    this.heroClass = HeroClass.knight,
    this.classChosen = false,
    Map<HeroClass, Loadout>? loadouts,
    this.trinket,
    this.ring,
    this.gloves = false,
    this.dye = 'crimson',
    List<String>? ownedDyes,
    this.potions = 0,
    this.poisonFights = 0,
    this.chariotFights = 0,
    Map<String, int>? brews,
    this.dragonXp,
    Map<String, int>? ammo,
    this.ammoLoaded,
    this.preparedSpell = 'arcanebolt',
    List<String>? rites,
    Map<String, int>? training,
    Map<String, int>? pets,
    this.activePet,
    List<String>? mounts,
    this.mount,
    this.scrolls = 0,
    this.female = false,
    this.crossbow = 0,
    List<GearItem>? stash,
  }) : stash = stash ?? [],
       rites = rites ?? [preparedSpell],
       training = training ?? {},
       ammo = ammo ?? {},
       brews = brews ?? {},
       mounts = mounts ?? [],
       pets = pets ?? {},
       loadouts = loadouts ?? {for (final c in HeroClass.values) c: Loadout.starter(c)},
       ownedDyes = ownedDyes ?? ['crimson'];

  int level, xp, hp, coins;
  HeroClass heroClass;

  /// The gear chest in your tent: pieces you've taken off or kept, to wear again later.
  List<GearItem> stash;

  /// False until the player has named their knight and set out.
  bool classChosen;
  Map<HeroClass, Loadout> loadouts;
  GearItem? trinket;

  /// A ring, worn whatever your class (like the trinket).
  GearItem? ring;

  /// Gauntlets, spellgloves or bracers, depending on class: +3 per attack.
  bool gloves;
  String dye;
  List<String> ownedDyes;
  int potions;

  /// Fights left with weapon poison on the blade.
  int poisonFights;

  /// Fights left with the Chariot card's extra health (see [chariotHp]).
  int chariotFights;

  /// Mags' brews you've drunk, by id, and the fights each has left (Reaper's Bane: 1 until spent).
  final Map<String, int> brews;

  /// Special ammunition owned (by [AmmoType] name), and which kind is loaded.
  final Map<String, int> ammo;
  String? ammoLoaded;

  /// The rite last cast (an id in spells); a Cast with no rite named uses it.
  String preparedSpell;

  /// The rites on your hotbar, up to [riteSlots] of them.
  List<String> rites;

  /// Points spent on each trait (might, arcana, aim, vigour): one more to spend every level.
  Map<String, int> training;

  /// Companions besides the dragon, with their XP, and which companion fights ('dragon' or a Pet
  /// name). Null means the dragon if you have one, otherwise your first companion.
  final Map<String, int> pets;
  String? activePet;

  /// Mounts owned (ids in mounts.dart) and the one you ride (null: on foot).
  final List<String> mounts;
  String? mount;

  /// Scrolls of enchanting: each pays for one rune at the enchanter instead of gold.
  int scrolls;

  /// The hero's look: a heroine when true. Purely cosmetic.
  bool female;

  /// The crossbow on your back: an index into [crossbows] (upgraded at Mags's stall).
  int crossbow;

  /// XP earned since the dragon egg was found; null when no egg.
  int? dragonXp;

  bool get hasDragon => dragonXp != null;
  Loadout get loadout => loadouts[heroClass]!;
  String get armour => loadout.armour;

  GearItem? equipped(GearSlot s) => s == GearSlot.trinket ? trinket : (s == GearSlot.ring ? ring : loadout.inSlot(s));

  /// Gear that counts: a mismatched off-hand doesn't.
  Iterable<GearItem> get gear => [loadout.weapon, loadout.activeOffhand, loadout.helm, loadout.gloves, loadout.boots, loadout.cape, trinket, ring].whereType<GearItem>();

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'hp': hp,
    'coins': coins,
    'class': heroClass.name,
    'classChosen': classChosen,
    'loadouts': {for (final e in loadouts.entries) e.key.name: e.value.toJson()},
    'trinket': trinket?.toJson(),
    if (ring != null) 'ring': ring!.toJson(),
    'gloves': gloves,
    'dye': dye,
    'ownedDyes': ownedDyes,
    'potions': potions,
    if (poisonFights > 0) 'poison': poisonFights,
    if (chariotFights > 0) 'chariot': chariotFights,
    if (brews.isNotEmpty) 'brews': brews,
    'dragonXp': dragonXp,
    'ammo': ammo,
    'ammoLoaded': ammoLoaded,
    'spell': preparedSpell,
    'rites': rites,
    'training': training,
    'pets': pets,
    'activePet': activePet,
    if (mounts.isNotEmpty) 'mounts': mounts,
    if (mount != null) 'mount': mount,
    if (scrolls > 0) 'scrolls': scrolls,
    if (female) 'female': true,
    if (crossbow > 0) 'crossbow': crossbow,
    if (stash.isNotEmpty) 'stash': [for (final g in stash) g.toJson()],
  };

  factory Knight.fromJson(Map<String, dynamic> j) {
    final cls = HeroClassInfo.parse(j['class'] as String?);
    final raw = (j['loadouts'] as Map?)?.cast<String, dynamic>() ?? {};
    // Potions past the belt (saves from before it existed) are sold back at 20 gold each.
    final pots = (j['potions'] as num?)?.toInt() ?? 3, extra = math.max(0, pots - potionBelt);
    return Knight(
      level: (j['level'] as num?)?.toInt() ?? 1,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      hp: (j['hp'] as num?)?.toInt() ?? 100,
      coins: ((j['coins'] as num?)?.toInt() ?? 0) + extra * 20,
      heroClass: cls,
      classChosen: j['classChosen'] as bool? ?? false,
      loadouts: {
        for (final c in HeroClass.values)
          c: raw[c.name] is Map ? Loadout.fromJson((raw[c.name] as Map).cast<String, dynamic>(), c) : Loadout.starter(c),
      },
      trinket: _item(j['trinket']),
      ring: _item(j['ring']),
      gloves: j['gloves'] as bool? ?? false,
      dye: j['dye'] as String? ?? 'crimson',
      ownedDyes: (j['ownedDyes'] as List?)?.cast<String>(),
      potions: pots - extra,
      poisonFights: (j['poison'] as num?)?.toInt() ?? 0,
      chariotFights: (j['chariot'] as num?)?.toInt() ?? 0,
      brews: {for (final e in ((j['brews'] as Map?) ?? const {}).entries) if (e.value is num) e.key as String: (e.value as num).toInt()},
      dragonXp: (j['dragonXp'] as num?)?.toInt(),
      ammo: _ammo(j['ammo']),
      ammoLoaded: _ammoLoaded(j['ammoLoaded'], j['ammo']),
      stash: [for (final g in (j['stash'] as List?) ?? const []) _item(g)].whereType<GearItem>().toList(),
      preparedSpell: j['spell'] as String? ?? 'arcanebolt',
      rites: (j['rites'] as List?)?.whereType<String>().toList() ?? [j['spell'] as String? ?? 'arcanebolt'],
      training: {for (final e in ((j['training'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
      pets: {for (final e in ((j['pets'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()},
      activePet: j['activePet'] as String?,
      mounts: (j['mounts'] as List?)?.cast<String>().toList(),
      mount: j['mount'] as String?,
      scrolls: (j['scrolls'] as num?)?.toInt() ?? 0,
      female: j['female'] == true,
      crossbow: ((j['crossbow'] as num?)?.toInt() ?? 0).clamp(0, crossbows.length - 1),
    );
  }
}

enum EntryKind { plain, damage, gold, good, day }

class JournalEntry {
  JournalEntry(this.text, [this.kind = EntryKind.plain]);
  final String text;
  final EntryKind kind;
  Map<String, dynamic> toJson() => {'t': text, 'k': kind.name};
  factory JournalEntry.fromJson(Map<String, dynamic> j) =>
      JournalEntry(j['t'] as String, EntryKind.values.firstWhere((k) => k.name == j['k'], orElse: () => EntryKind.plain));
}

class GameState {
  GameState({
    Settings? settings,
    Knight? knight,
    this.continent = 0,
    this.unlocked = 0,
    List<int>? wins,
    Set<int>? bossesDown,
    List<int>? reagents,
    Set<int>? warded,
    this.innRepaired = true,
    this.jobTaken = true,
    this.raid,
    this.raidSeen = false,
    Set<String>? trophies,
    this.raidCalm = 0,
    this.raidFight = false,
    this.day = false,
    this.dayWins = 0,
    this.home = 0,
    Map<int, int>? heroicWins,
    Map<int, int>? relicParts,
    Set<int>? forged,
    this.heroicFight = false,
    this.seasonSeen = '',
    this.encounter,
    this.encounterCalm = 0,
    this.chestIn = chestEvery,
    this.keys = 0,
    List<String>? vaultFound,
    this.lastRoll,
    this.inspired = 0,
    this.wild,
    this.wildDepth = 0,
    this.packGold = 0,
    List<GearItem>? pack,
    this.wildEvent,
    this.wildFight = false,
    this.wildAlert = false,
    this.warlordMet = false,
    this.dungeon,
    this.dungeonRoom = 0,
    List<String>? dungeonDoors,
    List<String>? dungeonPath,
    this.dungeonKey = false,
    this.dungeonFight = false,
    Set<String>? dungeonsDone,
    this.pint = false,
    this.malric = 0,
    this.form,
    this.shifts = 0,
    this.lastStyle,
    Set<String>? explored,
    this.place,
    this.wolfTurns = 0,
    this.wolfUsed = false,
    Map<int, int>? wildBest,
    Map<int, int>? struggle,
    List<List<String>>? gearSets,
    this.timber = 0,
    this.ironScrap = 0,
    Map<String, int>? mats,
    this.inBattle = false,
    this.foe = 0,
    this.rare,
    this.foeHp = 0,
    this.foeMax = 1,
    this.foeLevel = 1,
    this.turn = 0,
    this.fleeTries = 0,
    this.skillWait = 0,
    this.petWait = 0,
    this.mana = 0,
    this.summons = 0,
    this.summonTurns = 0,
    this.wards = 0,
    this.mirror = 0,
    this.foeFrozen = false,
    this.foeWindup = false,
    this.heroPoison = 0,
    this.foeAsleep = 0,
    this.foeSlowed = 0,
    this.foeWeakened = 0,
    this.foeExposed = 0,
    this.foeBurn = 0,
    this.foeBurnTurns = 0,
    this.foeVenom = 0,
    this.foeToxin = 0,
    this.foeBleed = 0,
    this.foeBleedTurns = 0,
    this.potionsDrunk = 0,
    this.fairyCharge = 0,
    this.fairyNext = 0,
    this.specialCharge = 0,
    this.mended = false,
    this.rallied = false,
    this.vanguardUsed = false,
    this.charged = false,
    List<JournalEntry>? journal,
    List<GearItem>? pendingLoot,
    this.dealDay,
    this.deal,
    this.dealBought = false,
    this.foesFelled = 0,
    this.raresFelled = 0,
    this.chestsOpened = 0,
    this.knockouts = 0,
    this.flees = 0,
  }) : settings = settings ?? Settings(),
       gearSets = gearSets ?? [],
       explored = explored ?? {},
       pack = pack ?? [],
       mats = mats ?? {},
       wildBest = wildBest ?? {},
       dungeonDoors = dungeonDoors ?? [],
       dungeonPath = dungeonPath ?? [],
       dungeonsDone = dungeonsDone ?? {},
       struggle = struggle ?? {},
       heroicWins = heroicWins ?? {},
       relicParts = relicParts ?? {},
       forged = forged ?? {},
       knight = knight ?? Knight(),
       wins = wins ?? List.filled(continents.length, 0),
       bossesDown = bossesDown ?? {},
       reagents = reagents ?? List.filled(continents.length, 0),
       warded = warded ?? {},
       journal = journal ?? [],
       pendingLoot = pendingLoot ?? [],
       vaultFound = vaultFound ?? [],
       trophies = trophies ?? {};

  Settings settings;
  Knight knight;

  /// The continent you're adventuring in, and the furthest one open to you.
  int continent, unlocked;

  /// Victories in each continent (its boss faces you after [winsForBoss]), and continents whose
  /// boss you've beaten at least once.
  final List<int> wins;
  final Set<int> bossesDown;

  /// Reagents gathered in each continent (for the next one's ward), and continents warded.
  final List<int> reagents;
  final Set<int> warded;

  /// Hob's job: the Soot & Kettle is still smouldering when a new hero arrives. Goblins in
  /// Cindervale drop the charred timber and iron scrap to patch it up; until then, no resting.
  bool innRepaired;

  /// Whether you've accepted Hob's job (talked to him and said yes).
  bool jobTaken;

  /// Bandits have hit the town while you were out: 'stall' (Mags) or 'inn' (Hob), or null.
  /// [raidSeen] once you've been told; [raidCalm] wins to go before another can happen;
  /// [raidFight] while you're chasing them down.
  String? raid;
  bool raidSeen, raidFight;

  /// One-of-a-kind prizes already found (the ork club, heartwood gear, rune weapon, dragon gear):
  /// each turns up once a game, so finding one is an event.
  final Set<String> trophies;
  int raidCalm;

  /// Day or night over Cindervale: a night at the inn brings the morning (such as it is under the
  /// ash); [dayWins] fights out in the wilds later, night falls again.
  bool day;
  int dayWins;
  /// Your home: 0 the tent, 1 a cottage, 2 a keep (an index into homes), and the gear sets saved in
  /// its armoury (ids of the pieces).
  int home;
  List<List<String>> gearSets;

  /// Heroic trails: stops cleared on each land's (reset when its risen boss falls), relic parts
  /// found for each land, the lands whose relic Mags has forged, and whether the fight under way
  /// is a heroic one.
  Map<int, int> heroicWins, relicParts;
  Set<int> forged;
  bool heroicFight;

  /// The last seasonal event you were welcomed to ('hallowash-2026'), so it's announced once.
  String seasonSeen;

  /// A wandering encounter waiting for you (an id in encounters), wins to go before another can
  /// turn up, and fights left of a bard's inspiring song.
  String? encounter;
  int encounterCalm, inspired;

  /// Wins until the next strongbox by the road ([chestEvery]).
  int chestIn;

  /// Ashen keys in hand, for the Ember Vault, and which of its own pieces you've found (by name).
  int keys;
  final List<String> vaultFound;

  /// What the strongbox's die last came up (for the window to show it landing).
  int? lastRoll;

  /// A trip into the wilds: the area (an index into wildAreas, null when you're not out there),
  /// how many steps in, the gold and gear in your pack (not yours until you get it home), a step
  /// waiting on your choice (a WildEvent name), whether the fight under way is a wild one, whether
  /// the last step stirred something up (the next is a fight), and whether you've met the area's
  /// warlord this trip.
  int? wild;
  int wildDepth, packGold;
  List<GearItem> pack;
  String? wildEvent;
  bool wildFight, wildAlert, warlordMet;

  /// A dungeon run under way: which dungeon, the room you're in (rooms cleared so far), the doors
  /// in front of you (DoorClue names), what each room behind you turned out to be (RoomKind
  /// names), whether you carry a key, and whether the fight under way is in it. [dungeonsDone]:
  /// dungeons whose boss you've beaten.
  String? dungeon;
  int dungeonRoom;
  List<String> dungeonDoors, dungeonPath;
  bool dungeonKey, dungeonFight;
  final Set<String> dungeonsDone;

  /// Had Old Corva read a card at the Soot & Kettle since the last fight (one a fight). (Saved
  /// as 'pint', from when it was a pint of stout.)
  bool pint;

  /// Times you've beaten Sir Malric the Ashen (at [malricLands].length he's gone for good).
  int malric;

  /// A shapeshifter's current form: the foe (by index) whose shape and ways it has taken, and how
  /// many times it has shifted this fight.
  int? form;
  int shifts;

  /// The way you struck last turn (blade, rite or bolt), which the Faceless brace for.
  String? lastStyle;

  /// Places on the map you've explored (by id), and the one whose guard you're fighting now.
  final Set<String> explored;
  String? place;

  /// The Bloodmoon Pelt: turns left as the wolf this fight, and whether it's come out already.
  int wolfTurns;
  bool wolfUsed;

  /// The deepest step reached in each wild area.
  Map<int, int> wildBest;

  /// Times knocked out on each land's trail since its boss last fell (to suggest the wilds).
  Map<int, int> struggle;

  /// Charred timber and iron scrap: Hob's job, and after that, building stock.
  int timber, ironScrap;

  /// Crafting stock, by key (see crafting.dart): golems' ore, smelted bars, and gems.
  final Map<String, int> mats;
  int mat(String key) => mats[key] ?? 0;
  void addMat(String key, int n) {
    final v = mat(key) + n;
    if (v <= 0) {
      mats.remove(key);
    } else {
      mats[key] = v;
    }
  }

  /// Whether fighting in [c] hurts you every turn.
  bool hazardIn(int c) => continents[c].hazard != null && !warded.contains(c);

  /// A fight is going on: the foe (its index in [foes], or the rare variant), its HP and level.
  bool inBattle;
  int foe;
  Rare? rare;
  int foeHp, foeMax, foeLevel;

  /// Turns taken this fight, and turns until the class skill and the companion's command are
  /// ready again (0 = ready).
  int turn, skillWait, petWait;

  /// Times you've tried to flee this fight and been cut off (each one makes the next likelier).
  int fleeTries;

  /// The mage's mana, skeletons fighting alongside (and turns they have left), arcane wards up,
  /// mirror blows left, and whether the foe is frozen out of its next blow.
  int mana, summons, summonTurns, wards, mirror;
  bool foeFrozen;

  /// The foe is winding up a heavy blow for its next turn (a Bash, a freeze or a hex stops it).
  bool foeWindup;

  /// Turns of poison left in you (a spider's bite, a plague cloud); a health potion cures it.
  int heroPoison;

  /// Blows the foe will sleep through, and hexes on it in turns left: slowed (half its blows
  /// miss), weakened (hits 40% softer) and exposed (your hits deal 25% more).
  int foeAsleep, foeSlowed, foeWeakened, foeExposed;

  /// Burning bolts: fire the foe takes each turn, and turns of it left. Venom bolts: stacks of
  /// venom in it (each does its share every turn, for the rest of the fight).
  int foeBurn, foeBurnTurns, foeVenom;

  /// A venomous weapon's poison in the foe (it eats this much a turn, and grows with every hit),
  /// and a serrated weapon's wound (this much a turn, for so many turns).
  int foeToxin, foeBleed, foeBleedTurns;

  /// Potions drunk this fight (only [potionsPerFight] allowed).
  int potionsDrunk;

  /// A fairy companion: attacks towards its next charm, and which charm is next.
  int fairyCharge, fairyNext;

  /// Attacks charged toward the weapon's special attack.
  int specialCharge;

  /// Once-a-fight things already used: Healing Light, the Bannerlord's rally, the Crusader's
  /// first block, and the mount's opening charge.
  bool mended, rallied, vanguardUsed, charged;

  List<JournalEntry> journal;

  /// Drops waiting for "equip or sell". Usually empty; survives closing the app mid-choice.
  List<GearItem> pendingLoot;

  /// Mags' find of the day: the day it's for (days since 1970, local time), the piece, and whether
  /// you've bought it.
  int? dealDay;
  GearItem? deal;
  bool dealBought;
  int foesFelled, raresFelled, chestsOpened, knockouts, flees;

  /// Whether Vharrax has fallen (the story is done; the world keeps going).
  bool get won => bossesDown.contains(mainLands - 1);

  /// Wins in [c] still needed before its boss will fight you (0: ready).
  int winsToBoss(int c) => (winsForBoss - wins[c]).clamp(0, winsForBoss);

  Map<String, dynamic> toJson() => {
    'v': 2,
    'settings': settings.toJson(),
    'knight': knight.toJson(),
    'continent': continent,
    'unlocked': unlocked,
    'wins': wins,
    'bosses': bossesDown.toList(),
    'reagents': reagents,
    'warded': warded.toList(),
    'inn': innRepaired,
    'job': jobTaken,
    if (raid != null) 'raid': raid,
    'raidSeen': raidSeen,
    if (trophies.isNotEmpty) 'trophies': trophies.toList(),
    'raidCalm': raidCalm,
    'raidFight': raidFight,
    'day': day,
    'dayWins': dayWins,
    'home': home,
    'heroic': {for (final e in heroicWins.entries) '${e.key}': e.value},
    'partMask': {for (final e in relicParts.entries) '${e.key}': e.value},
    'forged': forged.toList(),
    'heroicFight': heroicFight,
    'seasonSeen': seasonSeen,
    if (encounter != null) 'encounter': encounter,
    'encounterCalm': encounterCalm,
    'chestIn': chestIn,
    if (keys > 0) 'keys': keys,
    if (vaultFound.isNotEmpty) 'vaultFound': vaultFound,
    'inspired': inspired,
    if (wild != null) ...{
      'wild': wild,
      'wildDepth': wildDepth,
      'packGold': packGold,
      'pack': pack.map((e) => e.toJson()).toList(),
      if (wildEvent != null) 'wildEvent': wildEvent,
      'wildFight': wildFight,
      'wildAlert': wildAlert,
      'warlordMet': warlordMet,
    },
    if (dungeon != null) ...{
      'dungeon': dungeon,
      'dungeonRoom': dungeonRoom,
      'dungeonDoors': dungeonDoors,
      'dungeonPath': dungeonPath,
      if (dungeonKey) 'dungeonKey': true,
      if (dungeonFight) 'dungeonFight': true,
    },
    if (dungeonsDone.isNotEmpty) 'dungeonsDone': dungeonsDone.toList(),
    if (pint) 'pint': true,
    if (malric > 0) 'malric': malric,
    if (form != null) 'form': form,
    if (shifts > 0) 'shifts': shifts,
    if (lastStyle != null) 'lastStyle': lastStyle,
    if (explored.isNotEmpty) 'explored': explored.toList(),
    if (place != null) 'place': place,
    if (wolfTurns > 0) 'wolf': wolfTurns,
    if (wolfUsed) 'wolfUsed': true,
    'wildBest': {for (final e in wildBest.entries) '${e.key}': e.value},
    'struggle': {for (final e in struggle.entries) '${e.key}': e.value},
    'sets': gearSets,
    'timber': timber,
    'iron': ironScrap,
    'mats': mats,
    if (inBattle) ...{
      'battle': true,
      'foe': foe,
      if (rare != null) 'rare': rare!.toJson(),
      'foeHp': foeHp,
      'foeMax': foeMax,
      'foeLevel': foeLevel,
      'turn': turn,
      'fleeTries': fleeTries,
      'skillWait': skillWait,
      'petWait': petWait,
      'mana': mana,
      'summons': summons,
      'summonTurns': summonTurns,
      'wards': wards,
      'mirror': mirror,
      'frozen': foeFrozen,
      'windup': foeWindup,
      if (heroPoison > 0) 'hpoison': heroPoison,
      'asleep': foeAsleep,
      'slowed': foeSlowed,
      'weakened': foeWeakened,
      'exposed': foeExposed,
      if (foeBurnTurns > 0) 'burn': [foeBurn, foeBurnTurns],
      if (foeVenom > 0) 'venom': foeVenom,
      if (foeToxin > 0) 'toxin': foeToxin,
      if (foeBleedTurns > 0) 'bleed': [foeBleed, foeBleedTurns],
      if (potionsDrunk > 0) 'drunk': potionsDrunk,
      'fairyCharge': fairyCharge,
      'fairyNext': fairyNext,
      'mended': mended,
      'rallied': rallied,
      'vanguard': vanguardUsed,
      'charged': charged,
    },
    'special': specialCharge,
    'journal': journal.map((e) => e.toJson()).toList(),
    'pendingLoot': pendingLoot.map((e) => e.toJson()).toList(),
    if (dealDay != null) 'dealDay': dealDay,
    if (deal != null) 'deal': deal!.toJson(),
    if (dealBought) 'dealBought': true,
    'felled': foesFelled,
    'raresFelled': raresFelled,
    'chests': chestsOpened,
    'kos': knockouts,
    'flees': flees,
  };

  factory GameState.fromJson(Map<String, dynamic> raw) {
    final j = (raw['v'] as num? ?? 1) < 2 ? _sandsMigration(raw) : raw;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f((e as Map).cast<String, dynamic>())).toList();
    int n(String key, [int fallback = 0]) => (j[key] as num?)?.toInt() ?? fallback;
    final wins = List.filled(continents.length, 0);
    final saved = (j['wins'] as List?) ?? const [];
    for (var i = 0; i < wins.length && i < saved.length; i++) {
      wins[i] = (saved[i] as num).toInt();
    }
    final reagents = List.filled(continents.length, 0);
    final rs = (j['reagents'] as List?) ?? const [];
    for (var i = 0; i < reagents.length && i < rs.length; i++) {
      reagents[i] = (rs[i] as num).toInt();
    }
    return GameState(
      reagents: reagents,
      warded: ((j['warded'] as List?) ?? []).map((e) => (e as num).toInt()).toSet(),
      // Heroes from before Hob's job find the inn already patched up.
      innRepaired: j['inn'] as bool? ?? true,
      jobTaken: j['job'] as bool? ?? ((j['inn'] as bool? ?? true) || n('timber') > 0 || n('iron') > 0),
      raid: j['raid'] as String?,
      raidSeen: j['raidSeen'] as bool? ?? false,
      trophies: {...((j['trophies'] as List?) ?? const []).whereType<String>()},
      raidCalm: n('raidCalm'),
      raidFight: j['raidFight'] as bool? ?? false,
      day: j['day'] as bool? ?? false,
      dayWins: n('dayWins'),
      home: n('home'),
      heroicWins: {for (final e in ((j['heroic'] as Map?) ?? const {}).entries) int.parse(e.key as String): (e.value as num).toInt()},
      // (Older saves counted parts found in order; now each part is a bit, found in any order.)
      relicParts: j['partMask'] is Map
          ? {for (final e in (j['partMask'] as Map).entries) int.parse(e.key as String): (e.value as num).toInt()}
          : {for (final e in ((j['parts'] as Map?) ?? const {}).entries) int.parse(e.key as String): (1 << (e.value as num).toInt()) - 1},
      forged: {for (final x in (j['forged'] as List? ?? const [])) (x as num).toInt()},
      heroicFight: j['heroicFight'] as bool? ?? false,
      seasonSeen: j['seasonSeen'] as String? ?? '',
      encounter: j['encounter'] as String?,
      encounterCalm: n('encounterCalm'),
      chestIn: n('chestIn', chestEvery),
      keys: n('keys'),
      vaultFound: (j['vaultFound'] as List?)?.cast<String>().toList(),
      inspired: n('inspired'),
      wild: (j['wild'] as num?)?.toInt(),
      wildDepth: n('wildDepth'),
      packGold: n('packGold'),
      pack: list('pack', GearItem.fromJson),
      wildEvent: j['wildEvent'] as String?,
      wildFight: j['wildFight'] == true,
      wildAlert: j['wildAlert'] == true,
      warlordMet: j['warlordMet'] == true,
      dungeon: j['dungeon'] as String?,
      dungeonRoom: n('dungeonRoom'),
      dungeonDoors: [...((j['dungeonDoors'] as List?) ?? const []).whereType<String>()],
      dungeonPath: [...((j['dungeonPath'] as List?) ?? const []).whereType<String>()],
      dungeonKey: j['dungeonKey'] == true,
      dungeonFight: j['dungeonFight'] == true,
      dungeonsDone: {...((j['dungeonsDone'] as List?) ?? const []).whereType<String>()},
      pint: j['pint'] == true,
      malric: n('malric'),
      form: (j['form'] as num?)?.toInt(),
      shifts: n('shifts'),
      lastStyle: j['lastStyle'] as String?,
      explored: {...((j['explored'] as List?) ?? const []).whereType<String>()},
      place: j['place'] as String?,
      wolfTurns: n('wolf'),
      wolfUsed: j['wolfUsed'] == true,
      wildBest: {for (final e in ((j['wildBest'] as Map?) ?? const {}).entries) int.parse(e.key as String): (e.value as num).toInt()},
      struggle: {for (final e in ((j['struggle'] as Map?) ?? const {}).entries) int.parse(e.key as String): (e.value as num).toInt()},
      gearSets: [for (final g in (j['sets'] as List? ?? const [])) (g as List).whereType<String>().toList()],
      timber: n('timber'),
      ironScrap: n('iron'),
      mats: {for (final e in ((j['mats'] as Map?) ?? const {}).entries) if (e.value is num) e.key as String: (e.value as num).toInt()},
      settings: Settings.fromJson(((j['settings'] as Map?) ?? {}).cast<String, dynamic>()),
      knight: Knight.fromJson(((j['knight'] as Map?) ?? {}).cast<String, dynamic>()),
      continent: n('continent').clamp(0, continents.length - 1),
      unlocked: n('unlocked').clamp(0, continents.length - 1),
      wins: wins,
      bossesDown: ((j['bosses'] as List?) ?? []).map((e) => (e as num).toInt()).toSet(),
      inBattle: j['battle'] == true,
      foe: n('foe'),
      rare: j['rare'] is Map ? Rare.fromJson((j['rare'] as Map).cast<String, dynamic>()) : null,
      foeHp: n('foeHp'),
      foeMax: n('foeMax', 1),
      foeLevel: n('foeLevel', 1),
      turn: n('turn'),
      fleeTries: n('fleeTries'),
      skillWait: n('skillWait'),
      petWait: n('petWait'),
      mana: n('mana'),
      summons: n('summons'),
      summonTurns: n('summonTurns'),
      wards: n('wards'),
      mirror: n('mirror'),
      foeFrozen: j['frozen'] == true,
      foeWindup: j['windup'] == true,
      heroPoison: n('hpoison'),
      foeAsleep: n('asleep'),
      foeSlowed: n('slowed'),
      foeWeakened: n('weakened'),
      foeExposed: n('exposed'),
      foeBurn: (j['burn'] is List && (j['burn'] as List).length == 2) ? ((j['burn'] as List)[0] as num).toInt() : 0,
      foeBurnTurns: (j['burn'] is List && (j['burn'] as List).length == 2) ? ((j['burn'] as List)[1] as num).toInt() : 0,
      foeVenom: n('venom'),
      foeToxin: n('toxin'),
      foeBleed: (j['bleed'] is List && (j['bleed'] as List).length == 2) ? ((j['bleed'] as List)[0] as num).toInt() : 0,
      foeBleedTurns: (j['bleed'] is List && (j['bleed'] as List).length == 2) ? ((j['bleed'] as List)[1] as num).toInt() : 0,
      potionsDrunk: n('drunk'),
      fairyCharge: n('fairyCharge'),
      fairyNext: n('fairyNext'),
      specialCharge: n('special'),
      mended: j['mended'] == true,
      rallied: j['rallied'] == true,
      vanguardUsed: j['vanguard'] == true,
      charged: j['charged'] == true,
      journal: list('journal', JournalEntry.fromJson),
      pendingLoot: list('pendingLoot', GearItem.fromJson),
      dealDay: (j['dealDay'] as num?)?.toInt(),
      deal: j['deal'] is Map ? GearItem.fromJson((j['deal'] as Map).cast<String, dynamic>()) : null,
      dealBought: j['dealBought'] == true,
      foesFelled: n('felled'),
      raresFelled: n('raresFelled'),
      chestsOpened: n('chests'),
      knockouts: n('kos'),
      flees: n('flees'),
    );
  }
}

/// Special bolts kept by kind (the five of them); retired kinds (poisoned and barbed) come back
/// as burning bolts, one for one.
const _boltKinds = {'fire', 'blessed', 'leech', 'frost', 'venom'};
Map<String, int> _ammo(Object? raw) {
  final out = <String, int>{};
  for (final e in ((raw as Map?) ?? const {}).entries) {
    final n = (e.value as num).toInt(), key = _boltKinds.contains(e.key) ? e.key as String : 'fire';
    if (n > 0) out[key] = (out[key] ?? 0) + n;
  }
  return out;
}

String? _ammoLoaded(Object? loaded, Object? raw) {
  if (loaded is! String) return null;
  if (_boltKinds.contains(loaded)) return loaded;
  return _ammo(raw).containsKey('fire') ? 'fire' : null;
}

/// The land the Sunken Sands went in at (version 2 of the save): every land from here on moved up
/// one, and every foe from its first one moved along by the Sands' foes and boss.
const _sandsAt = 4;

/// Brings a save from before the Sunken Sands up to date: land numbers at or past the Sands move
/// up one (wins, reagents, beaten bosses, wards, heroic trails, where you are), and foe numbers
/// past it move along. The Sands start untouched, open to anyone who'd got that far.
Map<String, dynamic> _sandsMigration(Map<String, dynamic> j) {
  final out = Map<String, dynamic>.of(j);
  int land(Object? c) {
    final n = (c as num?)?.toInt() ?? 0;
    return n >= _sandsAt ? n + 1 : n;
  }

  var firstShifted = 0;
  for (var c = 0; c < _sandsAt; c++) {
    firstShifted += continents[c].foes.length + 1;
  }
  final added = continents[_sandsAt].foes.length + 1;
  int foe(Object? i) {
    final n = (i as num?)?.toInt() ?? 0;
    return n >= firstShifted ? n + added : n;
  }

  List<Object?> insertZero(Object? xs) {
    final l = List<Object?>.of((xs as List?) ?? const []);
    if (l.length > _sandsAt) l.insert(_sandsAt, 0);
    return l;
  }

  Map<String, Object?> keys(Object? m) => {for (final e in ((m as Map?) ?? const {}).entries) '${land(int.parse(e.key as String))}': e.value};

  out['wins'] = insertZero(j['wins']);
  out['reagents'] = insertZero(j['reagents']);
  for (final k in const ['bosses', 'warded', 'forged']) {
    out[k] = [for (final x in (j[k] as List?) ?? const []) land(x)];
  }
  for (final k in const ['heroic', 'parts', 'struggle']) {
    if (j[k] != null) out[k] = keys(j[k]);
  }
  out['continent'] = land(j['continent']);
  out['unlocked'] = land(j['unlocked']);
  if (j['foe'] != null) out['foe'] = foe(j['foe']);
  if (j['rare'] is Map) {
    final r = Map<String, dynamic>.of((j['rare'] as Map).cast<String, dynamic>());
    r['b'] = foe(r['b']);
    out['rare'] = r;
  }
  out['v'] = 2;
  return out;
}
