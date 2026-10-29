// Crafting: golems drop ore, Dunstan the smith smelts it into bars, and the bars (with a little gold)
// become armour. Gems, rarer, from any foe, are ground into bundles of special bolts by Old Wick. The merchant sells
// only the basics now; the good armour and bolts are earned. Pure Dart.

import 'ammo.dart';
import 'catalog.dart';
import 'classes.dart';
import 'loot.dart' show GearSlot, gearSetById;

/// The smith and the hedge-mage, Mags' neighbours on the square.
const smithName = 'Dunstan', mageName = 'Old Wick';

/// The three metals, in the order you meet them.
enum Metal { iron, gold, obsidian }

extension MetalInfo on Metal {
  String get ore => switch (this) {
    Metal.iron => 'Iron ore',
    Metal.gold => 'Gold ore',
    Metal.obsidian => 'Obsidian ore',
  };
  String get bar => switch (this) {
    Metal.iron => 'Iron bar',
    Metal.gold => 'Gold bar',
    Metal.obsidian => 'Emberglass ingot',
  };
  int get argb => switch (this) {
    Metal.iron => 0xFFB8673A,
    Metal.gold => 0xFFFFD45A,
    Metal.obsidian => 0xFFFF6A3A,
  };

  /// The golem made of it: its look and name.
  String get golemLook => switch (this) {
    Metal.iron => 'golemIron',
    Metal.gold => 'golemGold',
    Metal.obsidian => 'golemObsidian',
  };
  String get golemName => switch (this) {
    Metal.iron => 'Iron Golem',
    Metal.gold => 'Gold Golem',
    Metal.obsidian => 'Obsidian Golem',
  };

  /// The glow it fights in (it counts as a rare foe).
  Aura get aura => switch (this) {
    Metal.iron => Aura.ancient,
    Metal.gold => Aura.gilded,
    Metal.obsidian => Aura.blazing,
  };
}

/// Keys into the state's materials: 'ore:iron', 'bar:gold', 'gem:ruby'.
String oreKey(Metal m) => 'ore:${m.name}';
String barKey(Metal m) => 'bar:${m.name}';
String gemKey(Gem g) => 'gem:${g.name}';

/// Golems, by land: which metal walks there, and the chance one turns up when you set out. None in
/// Cindervale: a fresh hero's sword would barely scratch one.
const golemLands = <int, List<(Metal, double)>>{
  1: [(Metal.iron, .08)],
  2: [(Metal.iron, .05)],
  3: [(Metal.gold, .06), (Metal.iron, .04)],
  4: [(Metal.gold, .09)],
  5: [(Metal.obsidian, .08)],
  6: [(Metal.obsidian, .06)],
};

/// Golems by look: (name, HP compared with a regular foe). Living stone: blades and arrows glance
/// off and blunt weapons crush them, so they have a little less HP than they look.
final golemTypes = <String, (String, double)>{for (final m in Metal.values) m.golemLook: (m.golemName, .75)};

/// The metal a golem look is made of, or null.
Metal? golemMetal(String? look) => Metal.values.where((m) => m.golemLook == look).firstOrNull;

/// Ore a golem leaves: a few lumps (more from a tougher one).
const golemOreMin = 2, golemOreMax = 4;

/// Ore to a bar, and the smith's fee per bar at [level].
const orePerBar = 2;
int smeltFee(int level) => 4 + level;

/// Tempering a favourite weapon up to your level: worth it once it's this many levels behind, and
/// Dunstan's fee for closing a gap of [gap] levels at [level].
const temperMinGap = 3;
int temperFee(int level, int gap) => 20 + level * 2 + gap * 6;

/// What an armour tier takes at Dunstan's forge: bars of each metal, and gold.
class Recipe {
  const Recipe(this.bars, this.gold);
  final Map<Metal, int> bars;
  final int gold;
}

/// Mags still sells the first upgrade for gold; everything above it is forged from bars.
const armourRecipes = <String, Recipe>{
  // Tier II: iron.
  'plate': Recipe({Metal.iron: 6}, 80),
  'archmage': Recipe({Metal.iron: 6}, 80),
  'brigandine': Recipe({Metal.iron: 6}, 80),
  // Tier III: gold, on an iron frame.
  'gilded': Recipe({Metal.gold: 4, Metal.iron: 3}, 160),
  'astral': Recipe({Metal.gold: 4, Metal.iron: 3}, 160),
  'shadowweave': Recipe({Metal.gold: 4, Metal.iron: 3}, 160),
  // Tier IV: emberglass from the Cinderreach, set in gold.
  'emberglass': Recipe({Metal.obsidian: 5, Metal.gold: 3}, 300),
  'emberweave': Recipe({Metal.obsidian: 5, Metal.gold: 3}, 300),
  'emberhide': Recipe({Metal.obsidian: 5, Metal.gold: 3}, 300),
};

bool isCrafted(String armourId) => armourRecipes.containsKey(armourId);

/// Gems: rarer than ore, from any foe. Each one makes a bundle of special bolts.
enum Gem { ruby, pearl, garnet }

extension GemInfo on Gem {
  String get label => switch (this) {
    Gem.ruby => 'Ruby',
    Gem.pearl => 'Pearl',
    Gem.garnet => 'Garnet',
  };
  int get argb => switch (this) {
    Gem.ruby => 0xFFE0302A,
    Gem.pearl => 0xFFF4EEDC,
    Gem.garnet => 0xFF8A1A3A,
  };

  /// The bolts it makes.
  AmmoType get ammo => switch (this) {
    Gem.ruby => AmmoType.fire,
    Gem.pearl => AmmoType.blessed,
    Gem.garnet => AmmoType.leech,
  };
}

Gem gemFor(AmmoType a) => Gem.values.firstWhere((g) => g.ammo == a);

/// The chance a win leaves a gem: a regular foe, a rare one, a boss.
const gemChance = .05, gemChanceRare = .2, gemChanceBoss = 1.0;

/// Old Wick's fee to grind a gem into a bundle of [ammoBundle] bolts.
int fletchFee(int level) => 10 + level;

/// The armour tier a recipe makes, for its class.
ArmourTier craftedTier(String id) => armourTierById(id);

// ------------------------------------------------------------------ blueprints and trophies

/// Trophies: what the Ashen Order, the vampires of Ravenmoor, the werewolves of the Howling Weald,
/// the elves of the Silverwood and the dwarves of Deepforge Hold leave behind. With a blueprint,
/// Dunstan forges them into set pieces.
enum Trophy { ashenSteel, fang, pelt, silk, runesteel, face, scale, coral, skin, feather, lacquer }

extension TrophyInfo on Trophy {
  String get label => switch (this) {
    Trophy.ashenSteel => 'Ashen steel',
    Trophy.fang => 'Vampire fang',
    Trophy.pelt => 'Moon-pelt',
    Trophy.silk => 'Elven silk',
    Trophy.runesteel => 'Runesteel',
    Trophy.face => 'Lost face',
    Trophy.scale => 'Sunscale',
    Trophy.coral => 'Deep coral',
    Trophy.skin => 'Shifting skin',
    Trophy.feather => 'Griffin feather',
    Trophy.lacquer => 'Lacquered scale',
  };
  int get argb => switch (this) {
    Trophy.ashenSteel => 0xFF8A8A92,
    Trophy.fang => 0xFFF2EAD8,
    Trophy.pelt => 0xFF7A7E8A,
    Trophy.silk => 0xFFCFE8D8,
    Trophy.runesteel => 0xFF6A9AD8,
    Trophy.face => 0xFFF2ECE2,
    Trophy.scale => 0xFF8ACA4A,
    Trophy.coral => 0xFFF08A7A,
    Trophy.skin => 0xFFB89AE0,
    Trophy.feather => 0xFFE8D8B0,
    Trophy.lacquer => 0xFFB8322A,
  };
}

String trophyKey(Trophy t) => 'trophy:${t.name}';

/// Who leaves which trophy, by look.
const trophyLooks = <String, Trophy>{
  'ashenKnight': Trophy.ashenSteel,
  'ashenChampion': Trophy.ashenSteel,
  'malric': Trophy.ashenSteel,
  'vampireSpawn': Trophy.fang,
  'bloodBride': Trophy.fang,
  'vampireKnight': Trophy.fang,
  'countess': Trophy.fang,
  // The Hollowdeep's bats lose fangs too.
  'cavebat': Trophy.fang,
  'batkin': Trophy.fang,
  'batkinCaller': Trophy.fang,
  'batkinGuard': Trophy.fang,
  'roostMother': Trophy.fang,
  'werewolf': Trophy.pelt,
  'werewolfStalker': Trophy.pelt,
  'werewolfBrute': Trophy.pelt,
  'werewolfAlpha': Trophy.pelt,
  'elfRanger': Trophy.silk,
  'elfBlade': Trophy.silk,
  'elfWarden': Trophy.silk,
  'elfDruid': Trophy.silk,
  'elfQueen': Trophy.silk,
  'dwarfAxe': Trophy.runesteel,
  'dwarfShield': Trophy.runesteel,
  'dwarfXbow': Trophy.runesteel,
  'dwarfRune': Trophy.runesteel,
  'dwarfThane': Trophy.runesteel,
  'facelessWanderer': Trophy.face,
  'facelessMimic': Trophy.face,
  'facelessChoir': Trophy.face,
  'facelessWarden': Trophy.face,
  'facelessMother': Trophy.face,
  'lizardGuard': Trophy.scale,
  'lizardSkirmisher': Trophy.scale,
  'lizardShaman': Trophy.scale,
  'lizardChampion': Trophy.scale,
  'lizardKing': Trophy.scale,
  'harpy': Trophy.feather,
  'aerieWarden': Trophy.feather,
  'aerieSkyshot': Trophy.feather,
  'aerieCaller': Trophy.feather,
  'griffin': Trophy.feather,
  'stormRoc': Trophy.feather,
  'ronin': Trophy.lacquer,
  'ashigaru': Trophy.lacquer,
  'shinobi': Trophy.lacquer,
  'onmyoji': Trophy.lacquer,
  'oni': Trophy.lacquer,
  'shogun': Trophy.lacquer,
  'merrowRaider': Trophy.coral,
  'merrowCaller': Trophy.coral,
  'merrowGuard': Trophy.coral,
  'seaSerpent': Trophy.coral,
  'leviathan': Trophy.coral,
  'kraken': Trophy.coral,
};

/// The dwarves of Deepforge Hold carry ore: the chance one does, and how much.
const dwarfOreChance = .35, dwarfOre = 2;

/// A set only Dunstan can make: gloves, boots and a ring, each from its own blueprint (dropped by
/// the set's makers), their trophies, bars and gold. Blueprints are kept: forge a piece again as
/// you level and it comes out stronger.
class ForgedSet {
  const ForgedSet(this.id, this.trophy, this.metal, this.from);

  /// Its id in the gear sets (loot.dart).
  final String id;
  final Trophy trophy;
  final Metal metal;

  /// Where its blueprints come from, for the forge.
  final String from;
}

const forgedSets = <ForgedSet>[
  ForgedSet('ashen', Trophy.ashenSteel, Metal.gold, 'the Ashen Order: its knights, and Sir Malric himself'),
  ForgedSet('nightblood', Trophy.fang, Metal.iron, 'the vampires of Ravenmoor and the bats of the Hollowdeep'),
  ForgedSet('moonfang', Trophy.pelt, Metal.iron, 'the werewolves of the Howling Weald, who only come out at night'),
  ForgedSet('silverleaf', Trophy.silk, Metal.gold, 'the elves of the Silverwood'),
  ForgedSet('deepforge', Trophy.runesteel, Metal.iron, 'the dwarves of Deepforge Hold'),
  ForgedSet('faceless', Trophy.face, Metal.gold, 'the Faceless of the Isle of Mists'),
  ForgedSet('sunscale', Trophy.scale, Metal.iron, 'the lizardfolk of the Sunscale Jungle'),
  ForgedSet('tidecaller', Trophy.coral, Metal.gold, 'the merrow and serpents of the Shattered Sea'),
  ForgedSet('changeling', Trophy.skin, Metal.obsidian, 'the shapeshifters of the Changeling Isle'),
  ForgedSet('skyborn', Trophy.feather, Metal.gold, 'the aeriekin, harpies and griffins of the Skyreach Aeries'),
  ForgedSet('bushido', Trophy.lacquer, Metal.iron, 'the ronin, ashigaru, shinobi and oni of the Blossom Isles'),
];

ForgedSet? forgedSetById(String id) => forgedSets.where((f) => f.id == id).firstOrNull;
ForgedSet forgedSetFor(Trophy t) => forgedSets.firstWhere((f) => f.trophy == t);

/// The three pieces of a forged set.
const setPieceSlots = [GearSlot.gloves, GearSlot.boots, GearSlot.ring];

/// Key into the state's materials for a blueprint you hold: 'bp:ashen:gloves'.
String blueprintKey(String set, GearSlot slot) => 'bp:$set:${slot.name}';

/// What a piece is called: "gloves", "boots", "ring".
String pieceNoun(GearSlot slot) => switch (slot) {
  GearSlot.gloves => 'gloves',
  GearSlot.boots => 'boots',
  _ => 'ring',
};

/// The blueprint's name: "Ashen gloves blueprint".
String blueprintName(ForgedSet f, GearSlot slot) => '${gearSetById(f.id)!.name} ${pieceNoun(slot)} blueprint';

/// What a piece takes: trophies, bars of the set's metal, and Dunstan's fee at [level].
const pieceTrophies = 4, pieceBars = 2;
int pieceFee(int level) => 60 + 6 * level;

/// The chance a win leaves its trophy, and a blueprint (more from a named or rare foe; bosses and
/// Sir Malric always leave one you haven't got).
const trophyChance = .4, trophiesFromBoss = 3, blueprintChance = .05, blueprintChanceRare = .25;

// ------------------------------------------------------------------ elementals and their cores

/// Elementals rise out of the land itself: living fire, ice and bog. Each leaves a core of its
/// element, and Old Wick binds three cores into a weapon rune of that element.
enum Elemental { ember, frost, mire }

extension ElementalInfo on Elemental {
  String get look => switch (this) {
    Elemental.ember => 'elementalEmber',
    Elemental.frost => 'elementalFrost',
    Elemental.mire => 'elementalMire',
  };
  String get label => elementalLooks[look]!.$1;
  String get core => switch (this) {
    Elemental.ember => 'Ember core',
    Elemental.frost => 'Frost core',
    Elemental.mire => 'Mire core',
  };
  Aura get aura => switch (this) {
    Elemental.ember => Aura.blazing,
    Elemental.frost => Aura.frost,
    Elemental.mire => Aura.venom,
  };

  /// The weapon rune its cores make.
  String get rune => switch (this) {
    Elemental.ember => 'flametongue',
    Elemental.frost => 'frostbite',
    Elemental.mire => 'venomfang',
  };
  int get argb => switch (this) {
    Elemental.ember => 0xFFFF7A2A,
    Elemental.frost => 0xFF9ADFFF,
    Elemental.mire => 0xFF8BE05A,
  };
}

String coreKey(Elemental e) => 'core:${e.name}';

/// The elemental a look is, or null.
Elemental? elementalOf(String? look) => Elemental.values.where((e) => e.look == look).firstOrNull;

/// Where elementals rise, by land, and the chance one does when you set out: fire in the hot
/// lands and the forge-hold, frost where the nights are cold, the mire in the wet and the green.
const elementalLands = <int, List<(Elemental, double)>>{
  1: [(Elemental.mire, .05)],
  2: [(Elemental.mire, .03), (Elemental.frost, .02)],
  3: [(Elemental.ember, .04)],
  4: [(Elemental.ember, .03), (Elemental.frost, .02)],
  5: [(Elemental.ember, .05)],
  6: [(Elemental.ember, .04)],
  7: [(Elemental.frost, .04)],
  8: [(Elemental.frost, .05)],
  9: [(Elemental.mire, .03), (Elemental.frost, .03)],
  10: [(Elemental.ember, .05)],
};

/// Cores an elemental leaves (one or two), and how many Old Wick binds into a rune.
const coresMin = 1, coresMax = 2, coresPerRune = 3;
