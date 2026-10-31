// Static game content: the continents and their foes, rare encounters, chests, dyes and
// companions. Pure Dart (no Flutter imports) so the rules can be tested and simulated anywhere.
//
// The story: the Great Burning. Vharrax the Ember King set the world alight and civilisation
// went up in smoke. You survived it, singed and sooty, and now drink at the Soot & Kettle inn,
// looking for work. Each continent is recovering in its own odd way; cross them all and you
// reach the Ember Throne.

import 'dart:math' as math;

import 'crafting.dart';

/// How a foe hits you: up close, with arrows, with magic, or with fire.
enum Strike { melee, arrow, magic, fire }

/// The combat triangle. Each kind of foe is weak to one of your three ways of fighting and shrugs
/// off the one it uses itself:
/// armoured foes fall to rites and turn your blade; casters fall to the crossbow and ward off
/// rites; archers fall to the blade (you close the gap) and out-shoot your crossbow.
enum FoeKind { none, armoured, caster, ranged }

/// Your three ways of hurting things.
enum AttackStyle { blade, rite, bolt }

/// Damage for the right answer on the triangle, and for the wrong one.
const weakness = 1.25, resistance = .8;

/// How hard [style] lands on a foe of [kind].
double triangle(FoeKind kind, AttackStyle? style) => switch ((kind, style)) {
  (FoeKind.armoured, AttackStyle.rite) || (FoeKind.caster, AttackStyle.bolt) || (FoeKind.ranged, AttackStyle.blade) => weakness,
  (FoeKind.armoured, AttackStyle.blade) || (FoeKind.caster, AttackStyle.rite) || (FoeKind.ranged, AttackStyle.bolt) => resistance,
  _ => 1.0,
};

extension FoeKindInfo on FoeKind {
  String get label => switch (this) {
    FoeKind.armoured => 'Armoured',
    FoeKind.caster => 'Caster',
    FoeKind.ranged => 'Archer',
    FoeKind.none => '',
  };

  /// What beats it, and what it shrugs off.
  AttackStyle? get weakTo => switch (this) {
    FoeKind.armoured => AttackStyle.rite,
    FoeKind.caster => AttackStyle.bolt,
    FoeKind.ranged => AttackStyle.blade,
    FoeKind.none => null,
  };
  AttackStyle? get resists => switch (this) {
    FoeKind.armoured => AttackStyle.blade,
    FoeKind.caster => AttackStyle.rite,
    FoeKind.ranged => AttackStyle.bolt,
    FoeKind.none => null,
  };
}

class FoeType {
  const FoeType(this.name, this.look, {this.boss = false, this.undead = false, this.dragon = false, this.ork = false, this.ent = false, this.hp = 1, this.aura, this.named = false, this.hound = false, this.stone = false, this.demon = false, this.spirit = false, this.venomous = false, this.beast = false, this.pack = false, this.aloft = false, this.strike = Strike.melee, this.armoured = false, this.night = false, this.element, this.mimic = false, this.regrows = false, this.shifts = false, this.evasive = false, this.ironhide = false});
  final String name;

  /// Only out after dark (the vampires of Ravenmoor, the werewolves of the Howling Weald).
  final bool night;

  /// An elemental: the element it's made of ('burn', 'frost' or 'poison'). It shrugs off its own
  /// element and takes double from its opposite (see [elementWeakness]).
  final String? element;

  /// One of the Faceless: it learns how you fight. Whatever way you struck it last turn, it's
  /// braced for this turn ([mimicBrace]).
  final bool mimic;

  /// Lizardfolk: wounds close over between blows ([regrowShare] of its HP each turn), unless fire
  /// touched it that turn.
  final bool regrows;

  /// A shapeshifter: it steps up in its own skin, then takes the shape of some other foe (and its
  /// ways of fighting), and again when it's badly hurt.
  final bool shifts;

  /// Elves: quick as the wind in the leaves. [evasiveMiss] of your attacks and bolts miss them
  /// outright; rites, skills and specials never do.
  final bool evasive;

  /// Dwarves: hides like old leather under forge-hardened mail. Critical hits land as ordinary ones.
  final bool ironhide;

  /// Clad in heavy armour (plate, bone plate, scales, ironbark): your blade does less, rites cut
  /// straight through.
  final bool armoured;

  /// Where it sits on the combat triangle (see [FoeKind]).
  FoeKind get kind => armoured
      ? FoeKind.armoured
      : strike == Strike.magic
      ? FoeKind.caster
      : strike == Strike.arrow
      ? FoeKind.ranged
      : FoeKind.none;

  /// Keeps its distance (archers, casters) or flies (ghosts, gargoyles, wyverns): your blade
  /// reaches it for less, your crossbow for more.
  final bool aloft;

  /// How it attacks you.
  final Strike strike;

  /// Three of them at once (a wolf pack, a war band). Sweeping blows, area spells and special
  /// attacks catch the whole pack: +50%.
  final bool pack;

  /// Set on a rare variant: the aura it fights in (and where its better loot comes from).
  final Aura? aura;

  /// A named rare boss (rarer than an aura variant, and richer).
  final bool named;

  /// Drawn as a great four-legged hound rather than a humanoid or dragon.
  final bool hound;

  /// Living stone: blades and arrows glance off (60%), blunt weapons crush it (150%); spells and
  /// elements hit it normally.
  final bool stone;

  /// Demons: holy damage burns them like the undead, and fire does nothing at all.
  final bool demon;

  /// Ghosts and banshees: steel and arrows pass half through them, holy fire burns them double.
  final bool spirit;

  /// Spiders: poison does nothing.
  final bool venomous;

  /// Drawn by a beast painter (wolves, bears, spiders, unicorns, centaurs) rather than the rig.
  final bool beast;
  bool get rare => aura != null;

  /// Key into art/looks.dart (or foeDragons in art/creatures.dart for dragons).
  final String look;
  final bool boss;

  /// Dragons: they can drop a dragon egg, dragon gear and wyrmscale.
  final bool dragon;

  /// Orks: they can drop ork weapons.
  final bool ork;

  /// Ents: fire burns them twice as hard, poison barely bites, and they can drop heartwood weapons.
  final bool ent;

  /// HP compared with other foes of the same level (ironbark is tough, twiglings are not).
  final double hp;

  /// Holy (smite) damage only hurts the undead (and demons).
  final bool undead;
}

/// What beating a continent's boss the first time brings.
enum Companion { wolf, nightmare, fairy, hellhound, dragon, none }

/// One continent of the burned world: its foes, its boss and what its boss leaves you.
class Continent {
  const Continent({
    required this.name,
    required this.blurb,
    required this.minLevel,
    required this.foes,
    required this.boss,
    required this.companion,
    required this.companionText,
    required this.prize,
    required this.argb,
    this.packs = const [],
    this.named = const [],
    this.hazard,
    this.hazardText = '',
    this.ward,
    required this.reagent,
    this.tier,
    this.opensAfter,
  });
  final String name, blurb;

  /// A side land, off the road to the Ember Throne: the land whose boss opens it (null for the
  /// lands along the road, each opened by the one before).
  final int? opensAfter;

  /// How tough its foes are, as a land along the road would be (null: its place on the road).
  final int? tier;

  /// What this land does to you every turn you fight in it (null: nothing), and how it reads.
  final String? hazard;
  final String hazardText;

  /// The ward Old Wick crafts against it, from reagents gathered in the continent before.
  final String? ward;

  /// What this land's foes drop, for the next continent's ward.
  final String reagent;

  /// Foes here are never weaker than this level (they keep pace with you above it).
  final int minLevel;
  final List<FoeType> foes;
  final FoeType boss;

  /// The companion (or steed) this continent's boss leaves you, and the line that says so.
  final Companion companion;
  final String companionText;

  /// The boss's legendary trinket (an art key in loot.bossTrinket), given the first time.
  final String prize;

  /// The continent's colour on the map.
  final int argb;

  /// Packs that can ambush you here: (look, name).
  final List<(String, String)> packs;

  /// Named rare bosses that roam here.
  final List<NamedRare> named;
}

/// A continent's hazard, without its ward: this share of your max HP every turn (it never knocks
/// you out on its own).
const hazardShare = .05;

/// Reagents a ward takes (from the continent before), and the chance a win there drops one.
const reagentsForWard = 6, reagentChance = .5, reagentsFromBoss = 3;

/// Gold Old Wick asks to craft the ward for [continent].
int wardPrice(int continent) => 60 * continent * continent;

/// Victories in a continent before its boss will face you.
/// Hob's job: what it takes to patch up the Soot & Kettle, and his thanks.
const timberNeeded = 4, ironNeeded = 3, innRepairReward = 40;

/// Potions are earned, not handed out: Hob's starting supplies when you take his job, two more
/// when it's done, a bottle on every boss and now and then on any other foe.
/// How many pieces of gear the chest in your tent holds (a cottage or keep holds more: see [homes]).
const stashSize = 20;

/// Your home in Cindervale, from the tent you start in to a keep of your own. Each is built from
/// gold, timber and iron (which Cindervale's and the Thornwild's foes carry once Hob's job is done,
/// and the orks of the Grimtusk Badlands too), once the land named is behind you.
class HomeTier {
  const HomeTier(this.name, this.chest, this.perk, {this.gold = 0, this.timber = 0, this.iron = 0, this.after = -1});
  final String name;

  /// Gear the chest holds.
  final int chest;

  /// What it does for you, in a line.
  final String perk;
  final int gold, timber, iron;

  /// The continent whose boss must be down first (-1: none).
  final int after;
}

const homes = [
  HomeTier('Tent', stashSize, 'A chest for $stashSize pieces of gear, and a fire to sit by.'),
  HomeTier('Cottage', 40, 'A chest for 40 pieces, and a herb garden: a free health potion every morning you wake here.', gold: 900, timber: 6, iron: 3, after: 0),
  HomeTier('Keep', 80, 'A chest for 80 pieces, and an armoury: save two sets of gear and swap into either in one tap.', gold: 4500, timber: 10, iron: 8, after: 2),
];

/// Heroic trails: once a land's boss falls, its trail can be walked again the hard way. Every foe
/// on it is an elite (a rare, with an aura), and at the end the boss rises again, stronger.
const heroicStops = 5;

/// Heroic foes fight this many levels above you.
const heroicLevels = 3;

/// Where a relic part waits: carried by a land's risen boss (its Heroic trail's end), guarded at
/// a place on the map (it appears once you hold the blueprint), or in a dungeon boss's hoard.
enum PartSource { risen, place, dungeon }

/// One part of a relic: its land, how it's won, and (for a place or a dungeon) which one, by id,
/// with [where] saying it in words. Each is a quest, done once: no farming for it.
class RelicPart {
  const RelicPart(this.name, this.land, this.where, {this.source = PartSource.risen, this.at});
  final String name, where;
  final int land;
  final PartSource source;
  final String? at;
  bool get risen => source == PartSource.risen;
}

/// A relic weapon, the finest thing in the game: forged from a blueprint (the land's boss carries
/// it) and three parts, each a quest in a different part of the world (a risen boss, a guardian at
/// a hidden place, a dungeon's hoard), so it comes mid-to-late, after a long road. Dunstan won't
/// hand one to a hero below [minLevel].
class Relic {
  const Relic(this.name, this.parts, this.gold, this.blueprint, {required this.minLevel});
  final String name, blueprint;
  final List<RelicPart> parts;
  final int gold, minLevel;
}

const relics = <int, Relic>{
  0: Relic(
    'Kingsfall',
    [
      RelicPart('Crown Shard', 0, 'Gorbo the One-Eyed, risen, at the end of Cindervale\'s Heroic trail'),
      RelicPart('Ember Core', 3, 'Skarr the Ember-Keeper, in the Ember Pit in the Grimtusk Badlands', source: PartSource.place, at: 'emberpit'),
      RelicPart('Old King\'s Hilt', 4, 'the hoard at the bottom of the Tomb of Kings, under the Sunken Sands', source: PartSource.dungeon, at: 'kingstomb'),
    ],
    2400,
    'Among Gorbo\'s hoard: a scorched blueprint for a greatsword called Kingsfall, forged from the shards of the old king\'s crown. Gorbo kept the crown shard (beat him again, risen, on Cindervale\'s Heroic trail); an ork fire-priest stole its ember core and keeps it in a pit in the Grimtusk Badlands; and the old king\'s hilt was buried with him in the Tomb of Kings.',
    minLevel: 28,
  ),
  2: Relic(
    'Bramblelash',
    [
      RelicPart('Living Briar', 2, 'the Briar Heart, deep in the Thornwild', source: PartSource.place, at: 'briarheart'),
      RelicPart('Heartwood Grip', 9, 'Warden Aelindor, at the Elder Heartwood in the Silverwood', source: PartSource.place, at: 'elderheart'),
      RelicPart('First Bloom', 2, 'Grandmother Bramblecrown, risen, at the end of the Thornwild\'s Heroic trail'),
    ],
    4200,
    'Tucked in Grandmother Bramblecrown\'s roots: a pressed-leaf blueprint for the Bramblelash, a whip of living briar. The briar grows from a heart of thorns somewhere deep in the Thornwild, the grip is heartwood the elves of the Silverwood guard, and the first bloom is Grandmother Bramblecrown\'s own, when she rises again.',
    minLevel: 32,
  ),
};

/// Whether you hold part [i] of relic [relic] (parts are kept as a bit mask).
bool hasRelicPart(Map<int, int> parts, int relic, int i) => ((parts[relic] ?? 0) >> i) & 1 == 1;

/// How many parts of relic [relic] you hold.
int relicPartsFound(Map<int, int> parts, int relic) => [for (var i = 0; i < relics[relic]!.parts.length; i++) if (hasRelicPart(parts, relic, i)) i].length;

/// The relic parts that turn up on land [land]'s Heroic trail: (relic, part index).
List<(int, int)> relicPartsOn(int land) => [
  for (final e in relics.entries)
    for (var i = 0; i < e.value.parts.length; i++)
      if (e.value.parts[i].land == land) (e.key, i),
];


/// The chance a foe carries timber or iron for your building, once Hob's job is done.
const buildFindChance = .3;

/// Lands whose foes carry timber, and iron.
const timberLands = {0, 2}, ironLands = {0, 3};

const jobPotions = 2, innRepairPotions = 2, potionDropChance = .08;

/// Your potion belt holds this many (more found while it's full is left behind), and you can only
/// stop to drink so many in one fight: a potion is a breather, not a way to tank anything.
const potionBelt = 5, potionsPerFight = 2;
const hobsJob = 'Hob the innkeeper looks at the smouldering roof, then at you. "Goblins took the good timber and every nail I had. '
    'Bring me $timberNeeded lengths of timber and $ironNeeded sacks of iron, and you\'ll have a bed by the fire for life."';

const winsForBoss = 8;

/// The share of your HP you get back catching your breath after every win (on top of regeneration).
const breathShare = .06;

/// The lands along the road, Cindervale to the Ember Throne. The side lands come after them.
const mainLands = 7;

/// Off the road: Ravenmoor and the Howling Weald.
bool isSideLand(int continent) => continent >= mainLands;

/// The roads between the lands: a land opens once the boss of ANY land listed for it is down (the
/// side lands, the one that leads to them). Cindervale's boss opens two ways at once, and from
/// there you pick your own route; only the Ember Throne waits behind the Cinderreach alone. Each
/// land's own level still has to be reached.
const _roads = <int, List<int>>{1: [0], 2: [0], 3: [1, 2], 4: [2, 3], 5: [3, 4], 6: [5]};

/// The trophy a land's foes leave (and its places hold), if any.
String? landTrophyName(int land) => switch (land) {
  5 || 6 => 'ashenSteel',
  7 => 'fang',
  8 => 'pelt',
  9 => 'silk',
  10 => 'runesteel',
  11 => 'face',
  12 => 'scale',
  13 => 'coral',
  14 => 'skin',
  15 => 'feather',
  // The Hollowdeep's bats leave fangs, like Ravenmoor's vampires: the same Nightblood set.
  17 => 'fang',
  // The Frostmarch's wolves, yetis and fur-clad reavers leave pelts, like the Weald's werewolves.
  18 => 'pelt',
  _ => null,
};

/// The lands whose bosses open the way to [continent] (none for Cindervale).
List<int> openers(int continent) => continents[continent].opensAfter != null ? [continents[continent].opensAfter!] : (_roads[continent] ?? const []);

/// Every road on the map, as (from, to) pairs.
List<(int, int)> get roads => [for (var c = 0; c < continents.length; c++) for (final f in openers(c)) (f, c)];

/// How tough a land's foes are: its place on the road (a side land, the place it's level with).
int landTier(int continent) => continents[continent].tier ?? continent;

/// The level a continent's boss is a fair fight at: the next continent's level (the last one, and
/// the side lands, six more).
int bossLevel(int continent) => continent + 1 < mainLands ? continents[continent + 1].minLevel : continents[continent].minLevel + 6;

const continents = <Continent>[
  Continent(
    name: 'Cindervale',
    blurb: 'Farmland round the Soot & Kettle, still grey with ash. Goblins have moved into the barns and nobody has the energy to argue.',
    minLevel: 1,
    argb: 0xFFB8A27A,
    foes: [
      FoeType('Soot Goblin', 'goblin', hp: .9),
      FoeType('Ash Bandit', 'rogue', strike: Strike.arrow),
      FoeType('Ember Looter', 'pillager'),
      FoeType('Grey Wolf', 'wolf', hp: .85, beast: true),
      FoeType('Cellar Spider', 'spider', hp: .9, venomous: true, beast: true),
      FoeType('Goblin Warboss', 'goblinChief', hp: 1.15, armoured: true),
    ],
    boss: FoeType('Gorbo the One-Eyed', 'cyclops', boss: true),
    companion: Companion.wolf,
    companionText: 'A wolf pup was guarding Gorbo\'s cave. It decides you\'re its person now.',
    prize: 'cyclopseye',
    reagent: 'Ashbloom',
    packs: [('wolf', 'Wolf Pack'), ('goblin', 'Goblin War Band')],
    named: [
      NamedRare('Grizzletooth the Goblin King', 'goblin', Aura.gilded),
      NamedRare('Redhand the Reaver', 'pillager', Aura.blazing),
      NamedRare('Smudge, Prince of Pickpockets', 'rogue', Aura.cursed),
    ],
  ),
  Continent(
    name: 'The Gloomfen',
    blurb: 'A drowned marsh where the ash fell into the water and the dead got up to complain about it.',
    minLevel: 6,
    argb: 0xFF7A9A8A,
    foes: [
      FoeType('Bog Shambler', 'zombie', undead: true),
      FoeType('Rattlebones', 'skeleton', undead: true, hp: .9),
      FoeType('Fen Ghost', 'ghost', undead: true, spirit: true, hp: .85, aloft: true, strike: Strike.magic),
      FoeType('Wailing Banshee', 'banshee', undead: true, spirit: true, hp: .85, aloft: true, strike: Strike.magic),
      FoeType('Ghoul', 'ghoul', undead: true),
      FoeType('Bone Archer', 'skeletonArcher', undead: true, hp: .9, strike: Strike.arrow),
      FoeType('Plague Shambler', 'plague', undead: true, hp: 1.1, armoured: true),
      FoeType('Bog Witch', 'witch', hp: .9, strike: Strike.magic),
    ],
    boss: FoeType('The Bone Colossus', 'bonecolossus', boss: true, undead: true),
    companion: Companion.nightmare,
    companionText: 'From the Colossus\'s ribcage steps a ghostly black horse. It snorts embers and lets you climb on.',
    prize: 'phylactery',
    reagent: 'Marsh-light',
    hazard: 'Bog rot',
    hazardText: 'The fen\'s rotten air eats at you',
    ward: 'Fenward Charm',
    packs: [('skeleton', 'Skeleton Horde'), ('ghoul', 'Ghoul Pack')],
    named: [
      NamedRare('Old Bones Morrow', 'skeleton', Aura.ancient),
      NamedRare('Mother Blight', 'plague', Aura.venom),
      NamedRare('The Drowned Duke', 'zombie', Aura.cursed),
    ],
  ),
  Continent(
    name: 'The Thornwild',
    blurb: 'An old forest that grew back after the fire, very fast and very cross about it.',
    minLevel: 12,
    argb: 0xFF6E9A4A,
    foes: [
      FoeType('Twigling', 'twigling', ent: true, hp: .8),
      FoeType('Thornback Ent', 'thornEnt', ent: true),
      FoeType('Mossbeard Ent', 'mossEnt', ent: true, hp: 1.1),
      FoeType('Blightroot Ent', 'blightEnt', ent: true),
      FoeType('Brown Bear', 'bear', hp: 1.15, beast: true),
      FoeType('Wild Unicorn', 'unicorn', beast: true, strike: Strike.magic),
      FoeType('Centaur Outrider', 'centaur', beast: true, strike: Strike.arrow),
      FoeType('Ironbark Ent', 'ironEnt', ent: true, hp: 1.25, armoured: true),
    ],
    boss: FoeType('Grandmother Bramblecrown', 'oakheart', boss: true, ent: true),
    companion: Companion.fairy,
    companionText: 'A fairy was trapped in Bramblecrown\'s branches. Freed, she follows you, glowing smugly.',
    prize: 'acorn',
    reagent: 'Heartwood seed',
    hazard: 'Stinging spores',
    hazardText: 'Spores sting your eyes and skin',
    ward: 'Sporeveil',
    packs: [('spider', 'Spider Brood'), ('wolf', 'Wolf Pack')],
    named: [
      NamedRare('Old Rotgut Hollowbark', 'blightEnt', Aura.venom),
      NamedRare('Emberbough the Still-Burning', 'thornEnt', Aura.blazing),
      NamedRare('Silverleaf the Ancient', 'ironEnt', Aura.ancient),
    ],
  ),
  Continent(
    name: 'The Grimtusk Badlands',
    blurb: 'Red rock and war drums. The orks think the Great Burning was a party, and they want another.',
    minLevel: 18,
    argb: 0xFFC0703E,
    foes: [
      FoeType('Ork Raider', 'ork', ork: true),
      FoeType('Ork Archer', 'orkArcher', ork: true, hp: .9, strike: Strike.arrow),
      FoeType('Ork Shaman', 'orkShaman', ork: true, hp: .9, strike: Strike.magic),
      FoeType('Ork Berserker', 'orkBerserker', ork: true, hp: 1.1),
      FoeType('Minotaur', 'minotaur', hp: 1.15),
      FoeType('Gargoyle', 'gargoyle', hp: .9, stone: true, aloft: true),
      FoeType('Ash Warlock', 'warlock', strike: Strike.magic),
      FoeType('Ork Warlord', 'orkWarlord', ork: true, hp: 1.3, armoured: true),
    ],
    boss: FoeType('Krugg the Mountain', 'orkbehemoth', boss: true, ork: true, hp: 1.1, armoured: true),
    companion: Companion.hellhound,
    companionText: 'Krugg kept a hellhound pup in a cage. You open it. It sets your boots on fire, affectionately.',
    prize: 'warhorn',
    reagent: 'War-drum shard',
    hazard: 'Scorching sun',
    hazardText: 'The sun cooks you inside your armour',
    ward: 'Sunshade Talisman',
    packs: [('ork', 'Ork War Band'), ('ashenKnight', 'Ashen Patrol')],
    named: [
      NamedRare('Skarrgash Bloodtusk', 'orkBerserker', Aura.blazing),
      NamedRare('Old Mother Hagra', 'orkShaman', Aura.venom),
      NamedRare('Grimjaw the Gilded', 'ork', Aura.gilded),
    ],
  ),
  Continent(
    name: 'The Sunken Sands',
    blurb: 'The Burning turned a sea of sand to glass and cracked open the old kings\' tombs. Now the dead walk out of them, still wound in their linen, and raiders pick over what they leave.',
    minLevel: 25,
    argb: 0xFFE0B060,
    foes: [
      FoeType('Dune Raider', 'duneRaider'),
      FoeType('Sand Archer', 'sandArcher', hp: .9, strike: Strike.arrow),
      FoeType('Desert Jackal', 'jackal', hp: .85, beast: true),
      FoeType('Tomb Mummy', 'mummy', undead: true, hp: 1.1),
      FoeType('Tomb Priest', 'tombPriest', undead: true, hp: .9, strike: Strike.magic),
      FoeType('Tomb Guardian', 'mummyGuard', undead: true, hp: 1.2, armoured: true),
    ],
    boss: FoeType('Nephrakhet, the Ash Pharaoh', 'pharaoh', boss: true, undead: true, hp: 1.15, strike: Strike.magic),
    companion: Companion.none,
    companionText: 'Nephrakhet crumbles to dust and linen. Behind his throne, the treasury of a dynasty glitters in the torchlight.',
    prize: 'ankh',
    reagent: 'Tomb salt',
    hazard: 'Sandstorm',
    hazardText: 'The wind flays you with hot sand',
    ward: 'Veil of the Dunes',
    packs: [('jackal', 'Jackal Pack'), ('mummy', 'Mummy Procession')],
    named: [
      NamedRare('Queen Sekhara the Gilded', 'mummy', Aura.gilded),
      NamedRare('The Hollow Vizier', 'tombPriest', Aura.cursed),
      NamedRare('Khamsin, Lord of Raiders', 'duneRaider', Aura.blazing),
    ],
  ),
  Continent(
    name: 'The Cinderreach',
    blurb: 'Black glass and smoking craters on the edge of Vharrax\'s realm. Dragons nest here, and not all of them chose his side.',
    minLevel: 31,
    argb: 0xFF8A5A9A,
    foes: [
      FoeType('Ash Wyvern', 'wyvern', dragon: true, aloft: true, strike: Strike.fire),
      FoeType('Obsidian Drake', 'obsidian', dragon: true, hp: 1.1, strike: Strike.fire, armoured: true),
      FoeType('Pit Demon', 'pitdemon', demon: true, strike: Strike.fire),
      FoeType('Dragonbone Warden', 'dragonboneWarden', undead: true, armoured: true),
      FoeType('Ashen Knight', 'ashenKnight', armoured: true),
      FoeType('Gargoyle Sentinel', 'gargoylematriarch', stone: true, hp: 1.1, aloft: true),
    ],
    boss: FoeType('Scorchmaw, Hound of Vharrax', 'demonhound', boss: true, hound: true, strike: Strike.fire),
    companion: Companion.dragon,
    companionText: 'Behind Scorchmaw\'s den, in a nest of cooled glass: a dragon egg, still warm. It isn\'t on his side either.',
    prize: 'collar',
    reagent: 'Black glass',
    hazard: 'Ash storm',
    hazardText: 'Hot ash scours every gap in your kit',
    ward: 'Stormglass Lantern',
    packs: [('ork', 'Ork War Band'), ('ghoul', 'Ghoul Pack')],
    named: [
      NamedRare('Cinderqueen Ashkara', 'obsidian', Aura.blazing),
      NamedRare('The Bone Marshal', 'dragonboneWarden', Aura.ancient),
      NamedRare('Glimmerscale the Hoarder', 'wyvern', Aura.gilded),
    ],
  ),
  Continent(
    name: 'The Ember Throne',
    blurb: 'Vharrax\'s mountain. Everything here is on fire, including the fire.',
    minLevel: 38,
    argb: 0xFFE0502A,
    foes: [
      FoeType('Throne Pit Demon', 'pitdemon', demon: true, hp: 1.1, strike: Strike.fire),
      FoeType('Flamecaller', 'archwarlock', strike: Strike.magic),
      FoeType('Ashen Champion', 'ashenChampion', hp: 1.15, armoured: true),
      FoeType('Elder Ember Wyrm', 'elderWyrm', dragon: true, hp: 1.15, aloft: true, strike: Strike.fire),
      FoeType('Azgar, Herald of Vharrax', 'demonlord', demon: true, hp: 1.3, armoured: true),
    ],
    boss: FoeType('Vharrax the Ember King', 'emberKing', boss: true, dragon: true, hp: 1.35, aloft: true, strike: Strike.fire),
    companion: Companion.none,
    companionText: 'The Ember King falls, and for the first time since the Great Burning, it rains.',
    prize: 'emberheart',
    reagent: 'Ember of the Throne',
    hazard: 'Living flame',
    hazardText: 'The fire here burns on its own',
    ward: 'Frostheart Scroll',
    named: [
      NamedRare('Pyrelord Kazzak', 'pitdemon', Aura.blazing),
      NamedRare('The Smouldering Saint', 'archwarlock', Aura.cursed),
    ],
  ),
  // ---- Side lands, off the road. Their foes keep their worst for the night. ----
  Continent(
    name: 'Ravenmoor',
    blurb: 'A grey moor under a black castle. By day its thralls work the fields with their eyes down. By night the castle wakes, and it is hungry.',
    minLevel: 14,
    tier: 2,
    opensAfter: 1,
    argb: 0xFF9A3A4A,
    foes: [
      FoeType('Moor Thrall', 'thrall', hp: .9),
      FoeType('Grave Ghoul', 'ghoul', undead: true),
      FoeType('Castle Witch', 'witch', hp: .9, strike: Strike.magic),
      FoeType('Vampire Spawn', 'vampireSpawn', undead: true, night: true),
      FoeType('Blood Bride', 'bloodBride', undead: true, hp: .9, strike: Strike.magic, night: true),
      FoeType('Vampire Knight', 'vampireKnight', undead: true, hp: 1.15, armoured: true, night: true),
    ],
    boss: FoeType('Countess Morwenna', 'countess', boss: true, undead: true, hp: 1.1, strike: Strike.magic, night: true),
    companion: Companion.none,
    companionText: 'The Countess comes apart into a hundred bats, and they scatter over the moor. In the castle\'s cellar, the thralls\' chains hang open. They walk home in the dawn light.',
    prize: 'heartsblood',
    reagent: 'Vampire fang',
    packs: [('ghoul', 'Ghoul Pack'), ('vampireSpawn', 'Vampire Brood')],
    named: [
      NamedRare('Lord Vesper the Pale', 'vampireKnight', Aura.cursed),
      NamedRare('The Widow Ilse', 'bloodBride', Aura.frost),
    ],
  ),
  Continent(
    name: 'The Howling Weald',
    blurb: 'Pinewood the fire never reached, and nobody goes into after dark. The woodsmen are friendly enough by day. They do not talk about the moon.',
    minLevel: 20,
    tier: 3,
    opensAfter: 2,
    argb: 0xFF6A7A9A,
    foes: [
      FoeType('Cursed Woodsman', 'woodsman'),
      FoeType('Grey Wolf', 'wolf', hp: .85, beast: true),
      FoeType('Weald Bear', 'bear', hp: 1.15, beast: true),
      FoeType('Werewolf', 'werewolf', hp: 1.1, night: true),
      FoeType('Moonstalker', 'werewolfStalker', hp: .95, night: true),
      FoeType('Silverback', 'werewolfBrute', hp: 1.25, night: true),
    ],
    boss: FoeType('The Alpha of the Weald', 'werewolfAlpha', boss: true, hp: 1.15, night: true),
    companion: Companion.none,
    companionText: 'The Alpha falls, and the moon goes back behind the clouds. In the morning, the woodsmen are just woodsmen again, and very sorry about everything.',
    prize: 'bloodmoonpelt',
    reagent: 'Moon-pelt',
    packs: [('wolf', 'Wolf Pack'), ('werewolf', 'Werewolf Pack')],
    named: [
      NamedRare('Old Greymuzzle', 'werewolf', Aura.ancient),
      NamedRare('Sable the Silver-Eyed', 'werewolfStalker', Aura.frost),
    ],
  ),
  Continent(
    name: 'The Silverwood',
    blurb: 'The elves shut their forest when the world burned, and sang the fire back out of it. Every leaf is still silver. They do not want visitors, and they shoot first.',
    minLevel: 30,
    tier: 5,
    opensAfter: 2,
    argb: 0xFFA8C8B0,
    foes: [
      FoeType('Elven Ranger', 'elfRanger', hp: .9, strike: Strike.arrow, evasive: true),
      FoeType('Elven Spellblade', 'elfBlade', hp: .95, evasive: true),
      FoeType('Silverwood Warden', 'elfWarden', hp: 1.15, armoured: true, evasive: true),
      FoeType('Grove Druid', 'elfDruid', hp: .9, strike: Strike.magic, evasive: true),
      FoeType('Silverbark Ent', 'mossEnt', ent: true, hp: 1.1),
      FoeType('Moonhorn Unicorn', 'unicorn', beast: true, strike: Strike.magic),
    ],
    boss: FoeType('Queen Ithriel', 'elfQueen', boss: true, hp: 1.1, strike: Strike.magic, evasive: true),
    companion: Companion.none,
    companionText: 'Queen Ithriel lowers her staff. "You fight like we used to, before we hid." The gates of the Silverwood open, a little, for you.',
    prize: 'starleaf',
    reagent: 'Elven silk',
    packs: [('elfRanger', 'Elven Patrol')],
    named: [
      NamedRare('Ranger-Captain Faelor', 'elfRanger', Aura.frost),
      NamedRare('The Thornsinger', 'elfDruid', Aura.venom),
    ],
  ),
  Continent(
    name: 'Deepforge Hold',
    blurb: 'A dwarf-hold under the mountains, sealed since the Burning. Its forges never went out, and neither did its grudges. They mine, and smith, and fight anyone who knocks.',
    minLevel: 26,
    tier: 4,
    opensAfter: 3,
    argb: 0xFFB8865A,
    foes: [
      FoeType('Ironbeard Axeman', 'dwarfAxe', hp: 1.05, ironhide: true),
      FoeType('Dwarven Shieldbearer', 'dwarfShield', hp: 1.2, armoured: true, ironhide: true),
      FoeType('Dwarven Arbalist', 'dwarfXbow', hp: .9, strike: Strike.arrow, ironhide: true),
      FoeType('Rune-Priest', 'dwarfRune', hp: .9, strike: Strike.magic, ironhide: true),
      FoeType('Forge Golem', 'golemIron', hp: .75, stone: true),
    ],
    boss: FoeType('Thane Grimnar Deepforge', 'dwarfThane', boss: true, hp: 1.15, armoured: true, ironhide: true),
    companion: Companion.none,
    companionText: 'Thane Grimnar throws down his hammer and laughs till his beard shakes. "Nobody\'s beaten me since the old king. Come and drink, sooty one!" The hold is open to you now.',
    prize: 'runependant',
    reagent: 'Runesteel',
    packs: [('dwarfAxe', 'Dwarven Warband')],
    named: [
      NamedRare('Old Ironbelly', 'dwarfAxe', Aura.gilded),
      NamedRare('Runemaster Ulla', 'dwarfRune', Aura.ancient),
    ],
  ),
  Continent(
    name: 'The Isle of Mists',
    blurb: 'An island out past the Weald\'s coast, where the fog never lifts. The people there gave their faces to it after the Burning, so they would never have to see what was lost. They want yours.',
    minLevel: 33,
    tier: 5,
    opensAfter: 8,
    argb: 0xFFB8B4BC,
    foes: [
      FoeType('Faceless Wanderer', 'facelessWanderer', hp: .95, mimic: true),
      FoeType('Faceless Mimic', 'facelessMimic', mimic: true),
      FoeType('Faceless Choir', 'facelessChoir', hp: .9, strike: Strike.magic, mimic: true),
      FoeType('Faceless Warden', 'facelessWarden', hp: 1.15, armoured: true, mimic: true),
      FoeType('Fog Wraith', 'ghost', hp: .85, spirit: true, aloft: true, strike: Strike.magic),
    ],
    boss: FoeType('The Mother of Masks', 'facelessMother', boss: true, hp: 1.15, strike: Strike.magic, mimic: true),
    companion: Companion.none,
    companionText: 'The Mother of Masks falls, and her ring of faces shatters. All over the island, the Faceless touch their cheeks, and find them there again. The fog begins, very slowly, to lift.',
    prize: 'thousandmask',
    reagent: 'Lost face',
    packs: [('facelessWanderer', 'Faceless Procession')],
    named: [
      NamedRare('The Man Who Was You', 'facelessMimic', Aura.cursed),
      NamedRare('The Silent Cantor', 'facelessChoir', Aura.frost),
    ],
  ),
  Continent(
    name: 'The Sunscale Jungle',
    blurb: 'South of the Sands, where the glass gives way to steaming jungle and stepped stone temples. The lizardfolk worship the sun, and they think the Great Burning was their god paying a visit.',
    minLevel: 28,
    tier: 4,
    opensAfter: 4,
    argb: 0xFF6AAA4A,
    foes: [
      FoeType('Scaleguard', 'lizardGuard', regrows: true),
      FoeType('Lizardfolk Skirmisher', 'lizardSkirmisher', hp: .9, strike: Strike.arrow, regrows: true),
      FoeType('Sun Shaman', 'lizardShaman', hp: .9, strike: Strike.magic, venomous: true, regrows: true),
      FoeType('Saurian Champion', 'lizardChampion', hp: 1.2, armoured: true, regrows: true),
      FoeType('Marsh Drake', 'mossDragon', dragon: true, aloft: true, strike: Strike.fire),
    ],
    boss: FoeType('King Ssarrak the Sun-Eater', 'lizardKing', boss: true, hp: 1.15, armoured: true, regrows: true),
    companion: Companion.none,
    companionText: 'King Ssarrak sinks to his knees and hisses, almost laughing. "The sun has chosen a new champion. Very well." The temple drums go quiet.',
    prize: 'sunfang',
    reagent: 'Shed scale',
    packs: [('lizardGuard', 'Scaleguard Phalanx')],
    named: [
      NamedRare('Ixxa, the Coiled Blade', 'lizardSkirmisher', Aura.venom),
      NamedRare('Old Ironhide', 'lizardChampion', Aura.ancient),
    ],
  ),
  Continent(
    name: 'The Shattered Sea',
    blurb: 'South of the world, the Burning boiled the sea and broke the coast into a thousand reefs. The merrow fight over the wrecks, the serpents hunt the shallows, and something enormous sleeps in the deep.',
    minLevel: 22,
    tier: 3,
    opensAfter: 1,
    argb: 0xFF3A8AB8,
    foes: [
      FoeType('Merrow Raider', 'merrowRaider'),
      FoeType('Merrow Tidecaller', 'merrowCaller', hp: .9, strike: Strike.magic),
      FoeType('Reef Guard', 'merrowGuard', hp: 1.2, armoured: true),
      FoeType('Sea Serpent', 'seaSerpent', hp: 1.1, beast: true),
      FoeType('Drowned Sailor', 'drownedSailor', undead: true, hp: .9),
    ],
    boss: FoeType('The Leviathan', 'leviathan', boss: true, hp: 1.2, beast: true, strike: Strike.magic),
    companion: Companion.none,
    companionText: 'The Leviathan sinks into the deep, and the sea goes calm for the first time since the Burning. On the shore, the merrow watch you, and one by one they lower their tridents.',
    prize: 'leviathaneye',
    reagent: 'Deep coral',
    packs: [('merrowRaider', 'Merrow War-Party')],
    named: [
      NamedRare('Old Brinejaw', 'seaSerpent', Aura.ancient),
      NamedRare('Tidemother Ula', 'merrowCaller', Aura.frost),
    ],
  ),
  Continent(
    name: 'The Changeling Isle',
    blurb: 'Out past the reefs, an island where nothing keeps its shape for long. The changelings who live there wear the faces of everything they\'ve ever met. Whatever steps out to meet you, it won\'t stay that way.',
    minLevel: 36,
    tier: 5,
    opensAfter: 13,
    argb: 0xFFA88AD0,
    foes: [
      FoeType('Changeling', 'shifter', shifts: true),
      FoeType('Skinthief', 'shifterSly', hp: .9, shifts: true),
      FoeType('Mimic Hulk', 'shifterHulk', hp: 1.2, shifts: true),
      FoeType('Echo', 'ghost', hp: .85, spirit: true, aloft: true, strike: Strike.magic),
    ],
    boss: FoeType('The Thousandfold', 'thousandfold', boss: true, hp: 1.2, mimic: true, shifts: true),
    companion: Companion.none,
    companionText: 'The Thousandfold falls, wearing your face, and for a moment you\'re not sure which of you won. Then it melts into a puddle of grey, and the island\'s changelings settle, one by one, into shapes of their own.',
    prize: 'mirrorheart',
    reagent: 'Shifting skin',
    packs: [('shifter', 'Changeling Swarm')],
    named: [
      NamedRare('The Many-Faced', 'shifter', Aura.cursed),
      NamedRare('Grandmother Grey', 'shifterHulk', Aura.ancient),
    ],
  ),
  Continent(
    name: 'The Skyreach Aeries',
    blurb: 'Peaks above the clouds, where the ash never reached. The aeriekin nest here with their griffins, and they look down on the burned world in every sense. Harpies circle below, waiting for anyone who falls.',
    minLevel: 34,
    tier: 5,
    opensAfter: 10,
    argb: 0xFF9AC8E8,
    foes: [
      FoeType('Harpy', 'harpy', hp: .85, aloft: true),
      FoeType('Aeriekin Warden', 'aerieWarden', hp: 1.15, armoured: true),
      FoeType('Aeriekin Skyshot', 'aerieSkyshot', hp: .9, strike: Strike.arrow),
      FoeType('Aeriekin Stormcaller', 'aerieCaller', hp: .9, aloft: true, strike: Strike.magic),
      FoeType('Griffin', 'griffin', hp: 1.1, beast: true, aloft: true),
    ],
    boss: FoeType('Old Thunderwing, the Storm Roc', 'stormRoc', boss: true, hp: 1.2, beast: true, aloft: true, strike: Strike.magic),
    companion: Companion.none,
    companionText: 'Old Thunderwing comes down on the peak like a falling cloud, and does not get up. The aeriekin bow their heads to you, one by one. Down in the valley, a griffin chick watches you with interest.',
    prize: 'stormfeather',
    reagent: 'Griffin feather',
    packs: [('harpy', 'Harpy Flock')],
    named: [
      NamedRare('Shriekmother', 'harpy', Aura.cursed),
      NamedRare('Goldbeak', 'griffin', Aura.gilded),
    ],
  ),
  Continent(
    name: 'The Blossom Isles',
    blurb: 'Far out in the eastern sea, islands where the blossom never stopped falling, even when the sky burned. Masterless ronin walk the roads, shinobi watch from the rooftops, and oni come down from the mountains. The Shogun has closed the ports. He has not closed them to you; he simply expects you to die.',
    minLevel: 37,
    tier: 5,
    opensAfter: 14,
    argb: 0xFFF0A8C0,
    foes: [
      FoeType('Ronin', 'ronin', hp: .95),
      FoeType('Ashigaru Spearman', 'ashigaru', hp: 1.05, armoured: true),
      FoeType('Shinobi', 'shinobi', hp: .85, strike: Strike.arrow, evasive: true),
      FoeType('Onmyoji', 'onmyoji', hp: .9, strike: Strike.magic),
      FoeType('Mountain Oni', 'oni', hp: 1.2, beast: true),
    ],
    boss: FoeType('The Iron Shogun', 'shogun', boss: true, hp: 1.25, armoured: true),
    companion: Companion.none,
    companionText: 'The Iron Shogun kneels, sets down his sword, and bows to you. The ports open the next morning. The blossom keeps falling, and for the first time in a long while, people stop to watch it.',
    prize: 'blossomseal',
    reagent: 'Cherry blossom',
    packs: [('ashigaru', 'Ashigaru Squad')],
    named: [
      NamedRare('The Hundred-Cut', 'ronin', Aura.ancient),
      NamedRare('Kuro the Unseen', 'shinobi', Aura.cursed),
    ],
  ),
  Continent(
    name: 'The Hollowdeep',
    blurb: 'Caves under the fen hills, where the bats fled when the sky burned. There are millions of them down there now, and they have grown large. The batkin who live among them hunt by ear, and they can hear you breathing.',
    minLevel: 19,
    tier: 3,
    opensAfter: 1,
    argb: 0xFF7A6A9A,
    foes: [
      FoeType('Giant Cave Bat', 'cavebat', hp: .75, beast: true, aloft: true),
      FoeType('Batkin Skulker', 'batkin', hp: .85, evasive: true),
      FoeType('Batkin Echo-Caller', 'batkinCaller', hp: .9, strike: Strike.magic),
      FoeType('Batkin Roost-Guard', 'batkinGuard', armoured: true),
      FoeType('Cave Bear', 'cavebear', hp: 1.05, beast: true),
    ],
    boss: FoeType('The Roost Mother', 'roostMother', boss: true, hp: 1.2, beast: true, aloft: true),
    companion: Companion.none,
    companionText: 'The Roost Mother folds her wings and drops into the dark below. Ten thousand bats pour out of the caves at once, past you, up into a sky that isn\'t burning any more. The batkin watch them go, and then they watch you.',
    prize: 'echostone',
    reagent: 'Glowcap',
    packs: [('cavebat', 'Bat Swarm')],
    named: [
      NamedRare('Old Shriek', 'cavebat', Aura.ancient),
      NamedRare('Nightwhisper', 'batkin', Aura.cursed),
    ],
  ),
  Continent(
    name: 'The Frostmarch',
    blurb: 'North of the orklands, the Burning went the other way: the sky froze, and so did everything under it. Glaciers have swallowed a whole city. The reavers who live in its ruins worship the frost giants, and the frost giants let them.',
    minLevel: 27,
    tier: 4,
    opensAfter: 3,
    argb: 0xFF9AC0DC,
    foes: [
      FoeType('Frostbound Reaver', 'frostReaver'),
      FoeType('Rime Skald', 'frostSkald', hp: .9, strike: Strike.magic),
      FoeType('Snow Wolf', 'snowwolf', hp: .85, beast: true),
      FoeType('Yeti', 'yeti', hp: 1.15, beast: true),
      FoeType('Frost Giant', 'frostGiant', hp: 1.2, armoured: true),
      FoeType('Ice Wraith', 'iceWraith', hp: .85, spirit: true, aloft: true, strike: Strike.magic, element: 'frost'),
    ],
    boss: FoeType('Jarl Hrimgar the Ice-Crowned', 'frostJarl', boss: true, hp: 1.25, armoured: true),
    companion: Companion.none,
    companionText: 'Jarl Hrimgar falls to one knee, and the ice crown cracks clean in two. Somewhere under the glacier, the frozen city groans. By morning there is water running in its streets for the first time in a hundred years.',
    prize: 'rimeheart',
    reagent: 'Frost lily',
    packs: [('snowwolf', 'Snow Wolf Pack'), ('frostReaver', 'Reaver Warband')],
    named: [
      NamedRare('Old Whitefang', 'snowwolf', Aura.ancient),
      NamedRare('The Pale Huntress', 'frostReaver', Aura.frost),
    ],
  ),
];

/// The Frostmarch: its giants and reavers carry the Rimeforged weapons (one per hero).
const frostLand = 18;

/// The Hollowdeep: its bats and batkin carry the Duskwing weapons (one per hero).
const batLand = 17;

/// The Blossom Isles: their weapons, armour and helms only drop there.
const eastLand = 16;

/// How much less a Faceless takes from the way you struck it last turn: it's learned that one.
const mimicBrace = .75;

/// Share of its HP a lizardfolk regrows each turn fire doesn't touch it.
const regrowShare = .04;

/// [me] wearing the shape of foe [form] (a shapeshifter): that foe's look and ways of fighting, with
/// [me]'s strength, rank and aura. Null [form]: just [me].
FoeType formed(FoeType me, int? form) {
  if (form == null) return me;
  final t = foeAt(form);
  return FoeType(
    me.boss ? '${me.name}, as ${t.name}' : '${t.name}?',
    t.look,
    boss: me.boss,
    hp: me.hp,
    aura: me.aura,
    named: me.named,
    pack: me.pack,
    undead: t.undead,
    dragon: t.dragon,
    ork: t.ork,
    ent: t.ent,
    hound: t.hound,
    stone: t.stone,
    demon: t.demon,
    spirit: t.spirit,
    venomous: t.venomous,
    beast: t.beast,
    aloft: t.aloft,
    strike: t.strike,
    armoured: t.armoured,
    element: t.element,
    mimic: t.mimic,
    regrows: t.regrows,
    evasive: t.evasive,
    ironhide: t.ironhide,
    shifts: true,
  );
}

/// Shapes a shapeshifter can take: any regular foe of another land (a boss takes the shape of
/// other bosses).
List<int> shiftForms(int land, {required bool boss}) => [
  for (var c = 0; c < continents.length; c++)
    if (c != land) ...(boss ? [bossIndex(c)] : foeIndexes(c)),
];

/// The share of attacks and bolts that miss an elf outright.
const evasiveMiss = .2;

/// When a shapeshifter shifts again: under this share of its HP (bosses: at each third).
const reshiftAt = .5;

/// The beasts of the deep, drawn rising out of the water: the Kraken and the serpents.
const seaBeasts = {'kraken', 'seaSerpent', 'leviathan', 'griffin', 'stormRoc'};

/// The sea's people carry pearls: the chance one of the Shattered Sea's foes leaves one (on top of
/// the usual gem chance), and the chance a merrow carries one of its sea-forged weapons.
const pearlChance = .15, seaGearChance = .06;

/// Every foe in one list: each continent's foes then its boss. A foe's index is its id in saves.
final List<FoeType> foes = [
  for (final c in continents) ...[...c.foes, c.boss],
];

/// Index of the first foe of each continent in [foes].
final List<int> _starts = () {
  final out = <int>[];
  var i = 0;
  for (final c in continents) {
    out.add(i);
    i += c.foes.length + 1;
  }
  return out;
}();

/// A foe by index (clamped, so an old save can't point past the end).
FoeType foeAt(int i) => foes[i.clamp(0, foes.length - 1)];

/// Indexes of a continent's regular foes.
List<int> foeIndexes(int continent) => [for (var i = 0; i < continents[continent].foes.length; i++) _starts[continent] + i];

/// Index of a continent's boss.
int bossIndex(int continent) => _starts[continent] + continents[continent].foes.length;

/// The continent a foe belongs to.
int realmAt(int i) {
  for (var c = continents.length - 1; c >= 0; c--) {
    if (i >= _starts[c]) return c;
  }
  return 0;
}

/// Index of a foe by its look within [continent] (any continent if it isn't there).
int lookIndex(String look, [int? continent]) {
  if (continent != null) {
    final local = foeIndexes(continent).where((i) => foes[i].look == look).firstOrNull;
    if (local != null) return local;
  }
  final i = foes.indexWhere((f) => f.look == look);
  return i < 0 ? 0 : i;
}

/// Against a foe that's aloft: your blade deals this much, your crossbow this much.
const aloftMelee = .7, aloftShot = 1.25;

/// The knight's crossbow, upgraded at Mags's stall: (name, share of an attack a bolt deals, price).
const crossbows = <(String, double, int)>[
  ('Rusty crossbow', .7, 0),
  ('Light crossbow', .8, 150),
  ('Heavy crossbow', .9, 450),
  ('Ember arbalest', 1.0, 1100),
];

/// Weapons whose blows sweep through a whole pack.
const sweepingWeapons = {'halberd', 'greataxe', 'greatsword', 'morningstar'};

/// Weapons that crush stone.
const bluntWeapons = {'mace', 'morningstar', 'hammer', 'club', 'orkclub', 'heartmaul'};

/// One eye, no depth: the Cyclops swings hard but misses more (extra dodge against it).
const cyclopsDodge = .15, cyclopsHits = 1.2;

// ------------------------------------------------------------------ rare encounters

/// The aura a rare foe fights in. Each one changes how it looks and what it drops.
enum Aura { gilded, cursed, blazing, venom, frost, ancient }

extension AuraInfo on Aura {
  String get label => switch (this) {
    Aura.gilded => 'Gilded',
    Aura.cursed => 'Cursed',
    Aura.blazing => 'Blazing',
    Aura.venom => 'Venomous',
    Aura.frost => 'Frostbound',
    Aura.ancient => 'Ancient',
  };
  int get argb => switch (this) {
    Aura.gilded => 0xFFFFD45A,
    Aura.cursed => 0xFFB07AFF,
    Aura.blazing => 0xFFFF7A2A,
    Aura.venom => 0xFF8BE05A,
    Aura.frost => 0xFF9ADFFF,
    Aura.ancient => 0xFFF2EAD0,
  };

  /// What makes this aura's spoils special, for the foe card.
  String get perk => switch (this) {
    Aura.gilded => 'Drops a heap of gold',
    Aura.cursed => 'Better odds of legendary loot',
    Aura.blazing => 'Its loot burns',
    Aura.venom => 'Its loot is poisoned',
    Aura.frost => 'Its loot freezes',
    Aura.ancient => 'Tough, with the best loot of all',
  };
}

/// A named rare boss: a variant of a regular foe ([base] is its look key).
class NamedRare {
  const NamedRare(this.name, this.base, this.aura);
  final String name, base;
  final Aura aura;
}

/// A rare encounter: a variant of a regular foe ([base] is its index in [foes]).
class Rare {
  const Rare(this.base, this.aura, {this.name, this.pack = false, this.look});

  /// Drawn as something else entirely (Jack o' Cinders wears a scarecrow over his base foe's stats).
  final String? look;

  /// Three of the base foe at once.
  final bool pack;
  final int base;
  final Aura aura;

  /// Set for named rare bosses and packs.
  final String? name;

  FoeType get type {
    final rank = hiddenRanks[look];
    if (rank != null) {
      // One of the Hidden Ones: their own kind of foe, wherever they turn up (the base foe only sets
      // how strong the land makes them).
      final prior = look == hiddenPrior;
      return FoeType(name ?? rank.$1, look!, hp: rank.$3, aura: aura, named: prior, pack: pack, strike: rank.$2);
    }
    final elemental = elementalLooks[look];
    if (elemental != null) {
      // An elemental: living fire, ice or bog, wherever it rises.
      return FoeType(name ?? elemental.$1, look!, hp: .9, aura: aura, element: elemental.$2, strike: elemental.$3, aloft: elemental.$2 == 'poison');
    }
    if (look == malricLook) {
      // Sir Malric the Ashen: a knight like you, gone over to the Ember King.
      return FoeType(name ?? malricName, look!, hp: 1.05, aura: aura, named: true, armoured: true);
    }
    final golem = golemTypes[look];
    if (golem != null) {
      // A golem: living stone, wherever it walks.
      return FoeType(name ?? golem.$1, look!, hp: golem.$2, aura: aura, stone: true);
    }
    final b = foeAt(base);
    return FoeType(name ?? '${aura.label} ${b.name}', look ?? b.look, boss: b.boss, undead: b.undead, dragon: b.dragon, ork: b.ork, ent: b.ent, hp: b.hp, aura: aura, named: name != null && !pack, hound: b.hound, stone: b.stone, demon: b.demon, spirit: b.spirit, venomous: b.venomous, beast: b.beast, pack: pack, aloft: b.aloft, strike: b.strike, armoured: b.armoured, night: b.night, element: b.element, mimic: b.mimic, regrows: b.regrows, shifts: b.shifts, evasive: b.evasive, ironhide: b.ironhide);
  }

  Map<String, dynamic> toJson() => {'b': base, 'a': aura.name, if (name != null) 'n': name, if (pack) 'p': true, if (look != null) 'l': look};
  factory Rare.fromJson(Map<String, dynamic> j) => Rare(
    (j['b'] as num).toInt(),
    Aura.values.firstWhere((a) => a.name == j['a'], orElse: () => Aura.cursed),
    name: j['n'] as String?,
    pack: j['p'] == true,
    look: j['l'] as String?,
  );
}

/// The Hidden Ones: a clan of masked, hooded cultists who worship the Reaper and turn up anywhere
/// past Cindervale, thickest in the Gloomfen where the dead walk. By look: (name, how it fights, HP).
const hiddenRanks = <String, (String, Strike, double)>{
  'hiddenAcolyte': ('Hidden Acolyte', Strike.melee, 1.0),
  'hiddenBlade': ('Hidden Blade', Strike.melee, .9),
  'hiddenHexer': ('Hidden Hexer', Strike.magic, .9),
  'hiddenPrior': ('The Veiled Prior', Strike.magic, 1.2),
};
const hiddenPrior = 'hiddenPrior';

/// Elementals by look: (name, element, how it strikes). Ember elementals burn, frost elementals
/// cast, mire elementals drift (aloft).
const elementalLooks = <String, (String, String, Strike)>{
  'elementalEmber': ('Ember Elemental', 'burn', Strike.fire),
  'elementalFrost': ('Frost Elemental', 'frost', Strike.magic),
  'elementalMire': ('Mire Elemental', 'poison', Strike.melee),
};

/// What an element's elemental takes double damage from: fire and frost from each other, the
/// mire from holy light.
String elementWeakness(String element) => switch (element) {
  'burn' => 'frost',
  'frost' => 'burn',
  _ => 'smite',
};

/// Sir Malric the Ashen, the Ashen Order's champion: a knight who went over to Vharrax when the
/// world burned, and your rival on the road. He finds you again and again, each time further
/// along, and each time you beat him he yields and rides off; the last time, in the Cinderreach or
/// beyond, it's a duel to the end.
const malricLook = 'malric', malricName = 'Sir Malric the Ashen';

/// The land he first turns up in for each meeting (the last is the duel).
const malricLands = [2, 3, 4, 5];

/// The chance he's waiting when you set out (once the land is far enough along the road).
const malricChance = .05;

/// The chance the Hidden Ones step out of the ash when you set out into [continent]: never in
/// Cindervale until Gorbo is down, often in the Gloomfen, now and then everywhere else.
double hiddenChance(int continent, {required bool cindervaleClear}) => continent == 0 ? (cindervaleClear ? .03 : 0) : (continent == 1 ? .08 : .045);

/// Of those meetings: the share that are a whole coven, and the share that are the Prior himself.
const hiddenCovenShare = .25, hiddenPriorShare = .12;

/// The chance the Prior leaves his mask behind (once you have it, he leaves gold).
const hiddenMaskChance = .4;

/// The foe in front of you: the regular one, or a rare variant.
FoeType encounterType(int foe, Rare? rare) => rare?.type ?? foeAt(foe);

/// When you set out, the chance a rare foe turns up instead (and the share of those that are
/// named bosses), and the chance a pack ambushes you.
const rareChance = .08, namedRareShare = .35;

/// Packs turn up more often the further you go.
double packChance(int continent) => .05 + .025 * continent;

/// The aura a pack (or a beast turned rare) wears.
Aura wildAura(FoeType f) => f.undead ? Aura.cursed : (f.venomous ? Aura.venom : (f.ork ? Aura.blazing : Aura.ancient));

/// The chance a treasure chest turns up after a regular victory, and after a rare foe (bosses
/// always leave a grand one).
const chestChance = .05, rareChestChance = .2;

/// The chance a regular foe drops a piece of gear at all (gold and XP always come). Rare foes,
/// bosses and warlords always drop one; out in the wilds, where loot is the point, half do.
/// Fewer drops make each one matter, and keep the spoils window from opening after every fight.
const gearDropChance = .2, wildGearDropChance = .5, packGearDropChance = .4;

/// One of the Hidden Ones (not the Prior, who always carries something): the chance it does.
const hiddenGearChance = .5;

/// How rare foes compare with the regular foe: HP and rewards.
const rareHp = 1.5, namedRareHp = 1.8, rareRewards = 1.8;

/// Town raids: the chance one happens after a win out in the wilds, and how many wins must pass
/// after one before another can (so they stay a treat, not a chore).
const raidChance = .12, raidCalm = 8;

/// Fights out in the wilds before the day you woke to turns back to night.
const dayLength = 6;

/// In a land with night foes, the share of foes after dark who are night foes.
const nightShare = .7;

enum ChestTier { wooden, iron, gilded, ancient }

extension ChestInfo on ChestTier {
  String get label => switch (this) {
    ChestTier.wooden => 'Wooden chest',
    ChestTier.iron => 'Iron-bound chest',
    ChestTier.gilded => 'Gilded chest',
    ChestTier.ancient => 'Ancient chest',
  };
  int get argb => switch (this) {
    ChestTier.wooden => 0xFF8A5E34,
    ChestTier.iron => 0xFF8A949E,
    ChestTier.gilded => 0xFFE8C060,
    ChestTier.ancient => 0xFFB07AFF,
  };
}

/// Chances an ork drops its class weapon.
const orkGearChance = .12, orkGearChanceBoss = .35;

/// Chance an undead foe leaves bone gear (weapon or armour), and from an undead boss.
const boneGearChance = .08, boneGearChanceBoss = .3;

/// Chance a foe carries a scroll of enchanting (a free rune at the enchanter).
const scrollChance = .03, scrollChanceBoss = .15;

/// Bone weapons by name.
const boneWeapons = {'Bone cleaver', 'Bone bow', 'Ossuary staff'};

/// The Dragonbone Warden guards the rune-forges: a small chance it drops a rune-engraved weapon
/// for your class (better from its rare and named variants).
const runeLook = 'dragonboneWarden', runeChance = .06, runeChanceRare = .18;

/// Chances an ent drops its heartwood weapon.
const entGearChance = .12, entGearChanceBoss = .4;

/// The elves of the Silverwood carry a Thornbloom weapon: the chance one leaves it (once per hero).
const elfGearChance = .05, elfGearChanceBoss = .3;

/// The chance a foe of the Hollowdeep carries a Duskwing weapon (a boss far more often). One per
/// hero, like the elves' Thornbloom.
const batGearChance = .05, batGearChanceBoss = .3;

/// The chance a foe of the Frostmarch carries a Rimeforged weapon. One per hero.
const frostGearChance = .05, frostGearChanceBoss = .3;

/// Lucky moments, rolled every time they could happen. An opening: a free second blow (this share
/// of the first) on an attack. A jackpot: a foe's purse is three times as fat. (Your health only
/// ever comes back from things you chose: potions, brews, rest, lifesteal, your gear.)
const openingChance = .06, openingShare = .5;

/// Foes whose blows can poison you: [heroPoisonTurns] turns of [heroPoisonShare] of your HP
/// each, at [heroPoisonChance] a landed blow. A health potion cures it.
bool poisons(FoeType f) => f.look == 'spider' || f.look == 'plague' || f.look == 'blightEnt' || f.look == 'lizardSkirmisher' || f.look == 'mossDragon';
const heroPoisonChance = .35, heroPoisonTurns = 3, heroPoisonShare = .04;

/// Foes that drink your blood: they heal [bloodDrink] of every blow that lands on you.
bool drinksBlood(FoeType f) => const {'vampireSpawn', 'bloodBride', 'vampireKnight', 'countess', 'cavebat'}.contains(f.look);
const bloodDrink = .5;

/// A venomous weapon's poison grows by this share of its venom with every hit; a serrated
/// weapon's wound bleeds for [bleedTurns] turns; frost freezes the foe at [frostFreeze] a hit.
const toxinGrowth = .35, bleedTurns = 2, frostFreeze = .08;

/// The chance a foe (a boss) winds up a heavy blow for its next turn, and how hard it lands.
const windupChance = .15, windupBoss = .15, heavyBlow = 1.5;
const jackpotChance = .04;

/// A clean kill (a crossbow bolt lands the finishing blow): this much more gold from the foe, and
/// a special bolt comes back out of it.
const cleanKillGold = .3;

/// Elemental arms (see LootTable.elementArms): the chance a fire or frost elemental leaves its
/// weapon, and the chance one of the Aeries' foes (dawn) or Ravenmoor's night-walkers (shadow) does.
const elementArmsChance = .25, landArmsChance = .04;

class Dye {
  const Dye(this.id, this.name, this.argb);
  final String id, name;
  final int argb;
}

const dyes = <Dye>[
  Dye('crimson', 'Crimson', 0xFF9A2A22),
  Dye('royal', 'Royal blue', 0xFF2B4A8A),
  Dye('forest', 'Forest green', 0xFF2E5F35),
  Dye('ochre', 'Ochre', 0xFFB98A2E),
  Dye('ember', 'Ember', 0xFFC2501E),
  Dye('midnight', 'Midnight', 0xFF1E2238),
  Dye('amethyst', 'Amethyst', 0xFF6A3A9A),
  Dye('pumpkin', 'Hallowash pumpkin', 0xFFD8661A),
];

/// Dyes Mags only stocks during their seasonal event (yours to keep once bought).
const seasonalDyes = {'pumpkin': 'hallowash'};

Dye dyeById(String id) => dyes.firstWhere((d) => d.id == id, orElse: () => dyes.first);

class DragonStage {
  const DragonStage(this.name, this.minXp, this.chip);
  final String name;
  final int minXp, chip;
}

/// Companions besides the dragon. Only one companion fights at a time (choose under Kit);
/// the active one grows with the XP you earn.
enum Pet { hellhound, wolf, fairy }

class PetStage {
  const PetStage(this.name, this.minXp, this.bite, {this.burn = 0, this.crit = 0, this.guard = false, this.charm = 0});
  final String name;
  final int minXp;

  /// Damage of its bite on every attack (like the dragon's fire).
  final int bite;

  /// Hellhounds: fire on attacks. Wolves: crit chance (percent) from hunting together.
  final int burn, crit;

  /// Leaps in front of the foe's blow now and then (hellhounds and up).
  final bool guard;

  /// Fairies: every this many attacks, a charm (see [FairyCharm]). 0 for hounds.
  final int charm;
}

/// A fairy's charms, cast in turn: sleep, sap its strength, slow it, poison it, drink its life.
enum FairyCharm {
  slumber('Slumber dust', 'the foe sleeps through its next blow', 0xFFB8A0E8),
  enfeeble('Wilting charm', 'its blows land 40% softer for 2 turns', 0xFFB8A0D8),
  slow('Tangleroot', 'half its blows miss for 2 turns', 0xFF6ABF9A),
  venom('Thornsting', 'poison damage', 0xFF8BE05A),
  leech('Lifebloom', 'drains the foe and heals you', 0xFFE07AA0);

  const FairyCharm(this.label, this.effect, this.argb);
  final String label, effect;
  final int argb;
}

const petStages = <Pet, List<PetStage>>{
  Pet.hellhound: [
    PetStage('Hellhound pup', 0, 3, burn: 2),
    PetStage('Hellhound', 400, 5, burn: 4, guard: true),
    PetStage('Hellhound alpha', 1500, 7, burn: 6, guard: true),
    PetStage('Hound of Cinders', 4000, 10, burn: 8, guard: true),
  ],
  Pet.wolf: [
    PetStage('Wolf pup', 0, 2),
    PetStage('Timber wolf', 400, 4, crit: 3),
    PetStage('Dire wolf', 1500, 6, crit: 5),
    PetStage('Moonfang', 4000, 8, crit: 8),
  ],
  // A lighter bite than the hounds, but a charm every few attacks.
  Pet.fairy: [
    PetStage('Wisp', 0, 2, charm: 4),
    PetStage('Pixie', 400, 3, charm: 3),
    PetStage('Faerie', 1500, 4, charm: 3),
    PetStage('Seraph', 4000, 5, charm: 2),
  ],
};

/// Wyrmscale pieces from dragons: the chance one drops (more from bosses and rare dragons), and the
/// most extra damage to dragons a full set can give (percent).
const wyrmChance = .10, wyrmChanceBoss = .35, wyrmChanceRare = .2, wyrmbaneCap = 35;

const dragonStages = <DragonStage>[
  DragonStage('Egg', 0, 0),
  DragonStage('Hatchling', 300, 4),
  DragonStage('Drake', 1200, 7),
  DragonStage('Elder dragon', 3500, 11),
];

/// "a" or "an" before [word], by its first letter ("an ancient", "a cursed").
String aOrAn(String word) => RegExp(r'^[aeiouAEIOU]').hasMatch(word) ? 'an' : 'a';

/// [word] with "a" or "an" in front: "an epic chest".
String withArticle(String word) => '${aOrAn(word)} $word';

/// Shop prices for non-armour items.
const prices = <String, int>{'potion': 25, 'poison': 40, 'gloves': 80, 'dye': 30};


// ------------------------------------------------------------------ places to explore

/// What a place on the map holds the first time you explore it.
enum PlaceKind { guarded, cache, shrine }

/// A place on the map off the trails: a treasure cache, a shrine, or something guarded by a named
/// foe. Each is explored once. They show on the map once their land is open, so there's always
/// something to go and look at.
class Place {
  const Place(
    this.id,
    this.name,
    this.land,
    this.x,
    this.y,
    this.kind,
    this.blurb,
    this.after, {
    this.foe,
    this.purses = 0,
    this.potions = 0,
    this.ore = const {},
    this.gems = 0,
    this.brew,
    this.trophies = 0,
    this.legendary = false,
    this.hidden = false,
    this.relic,
    this.above = 0,
  });

  /// A relic part's guardian: this place only shows once you hold that relic's blueprint (and still
  /// need the part), and winning it gives the part: (relic, part index).
  final (int, int)? relic;

  /// Levels its guardian fights above you.
  final int above;
  final String id, name, blurb;

  /// What you find (or what happens) once it's explored.
  final String after;

  /// Its land (it shows, and can be explored, once you can travel there), and where it sits on
  /// the 1000 × 600 map.
  final int land;
  final double x, y;
  final PlaceKind kind;

  /// Who guards it: (base foe's look in its land, look to draw, aura, name).
  final (String, String?, Aura, String)? foe;

  /// Rewards: purses of gold (each worth a regular foe's gold at your level, times five), health
  /// potions, ore by metal name, gems, a brew (by name) for a few fights, trophies of the land, and a
  /// legendary piece of gear.
  final int purses, potions, gems, trophies;
  final Map<String, int> ore;
  final String? brew;
  final bool legendary;

  /// Only shows once every other place has been explored.
  final bool hidden;
}

const places = <Place>[
  Place('millcellar', 'The Old Mill Cellar', 0, 68, 395, PlaceKind.cache, 'The mill burned, but its cellar door is still padlocked, and something rattles when you kick it.', 'Under the floury sacks: the miller\'s savings, and two bottles of something medicinal.', purses: 1, potions: 2),
  Place('scarecrow', 'The Scarecrow Field', 0, 250, 545, PlaceKind.guarded, 'One scarecrow in the field turns its head to watch you go by. The others don\'t.', 'Old Stitchface comes apart in a heap of straw. Stuffed in his chest: a farmer\'s stolen purse.', foe: ('pillager', 'pumpkinhead', Aura.cursed, 'Old Stitchface'), purses: 2),
  Place('lanternchapel', 'Lantern Chapel', 1, 300, 395, PlaceKind.shrine, 'A drowned chapel with one candle still burning on the altar. Nobody has lit it in years.', 'You kneel. The candle flares pale and cold, and for a moment you see the Reaper\'s shadow turn away. (Reaper\'s Bane is in you.)', brew: 'reaperbane'),
  Place('drownedbell', 'The Drowned Bell', 1, 510, 410, PlaceKind.guarded, 'Out in the fen, a bell rings under the water. Something is ringing it.', 'The Bellringer wails, and sinks for good. In the silt where she stood: a sack of old offerings and a gem.', foe: ('banshee', null, Aura.frost, 'The Bellringer'), purses: 2, gems: 1),
  Place('fairyring', 'The Fairy Ring', 2, 175, 175, PlaceKind.shrine, 'A perfect ring of white mushrooms, humming faintly. Stepping inside seems rude. You do it anyway.', 'Tiny lights spin round you, giggling. You come out of the ring a day later, feeling marvellous, mana tingling in your fingers. (Wisp brew for three fights.)', brew: 'wisp', potions: 1),
  Place('hollowstump', 'The Hollow Stump', 2, 360, 205, PlaceKind.cache, 'A great stump, hollow inside, with a squirrel-sized door. Somebody lives here. Somebody rich.', 'A squirrel\'s hoard: nuts, mostly, and a surprising number of gems.', gems: 2, purses: 1),
  Place('skulltotem', 'The Skull Totem', 3, 455, 225, PlaceKind.guarded, 'A pile of skulls taller than a house, and an ork shaman asleep at the top of it.', 'Gutrot the Unburied tumbles down his own totem. His hut is full of loot from a dozen raids.', foe: ('orkShaman', null, Aura.venom, 'Gutrot the Unburied'), purses: 3),
  Place('ironseam', 'The Iron Seam', 3, 640, 200, PlaceKind.cache, 'A crack in the red rock, and in it, a gleam. The orks never noticed: they were busy shouting.', 'You prise out lumps of good ore. Dunstan will be pleased.', ore: {'iron': 6, 'gold': 3}),
  Place('sphinx', 'The Riddling Sphinx', 4, 905, 245, PlaceKind.shrine, 'A stone sphinx half-buried in the sand. "What walks on four legs, then two, then fights a dragon?" You say "me". It seems to accept that.', 'The sphinx\'s eyes glow, and you feel wiser, and sturdier. (Barkskin for three fights, and a purse it was sitting on.)', brew: 'barkskin', purses: 2),
  Place('treasury', 'The Sunken Treasury', 4, 928, 360, PlaceKind.cache, 'Steps going down into the glass sand, and at the bottom, a door with a pharaoh\'s seal. It\'s been opened before. Not all the way.', 'Gold, dusty and heavy, and a jewel the tomb-robbers missed.', purses: 4, gems: 1),
  Place('malriccamp', 'An Abandoned Camp', 5, 610, 430, PlaceKind.cache, 'A cold campfire on the black glass, a bedroll, and a knight\'s things left neatly folded. Someone left in a hurry, or doesn\'t mean to come back.', 'Under the bedroll: Ashen steel, and a letter in a careful hand. "If I don\'t come back, I was wrong about all of it. — M."', trophies: 3, purses: 2),
  Place('glasswyrm', 'Glassjaw\'s Roost', 5, 790, 560, PlaceKind.guarded, 'A wyvern\'s nest of melted glass and stolen silver, and the wyvern, wide awake.', 'Glassjaw crashes down into her own hoard. You fill your pockets.', foe: ('wyvern', null, Aura.gilded, 'Glassjaw'), purses: 4, ore: {'obsidian': 4}),
  Place('battower', 'The Bat Tower', 7, 318, 350, PlaceKind.guarded, 'A ruined tower on the moor, black with roosting bats. They all wake at dusk, and so does their master.', 'The Bat King bursts into a cloud of shrieking wings. In his roost: fangs, and the Countess\'s tithe.', foe: ('vampireSpawn', null, Aura.cursed, 'The Bat King'), purses: 2, trophies: 3),
  Place('moonpool', 'The Moon Pool', 8, 48, 255, PlaceKind.shrine, 'A still pool in the pines that holds the moon even by day. The werewolves drink here. So, carefully, do you.', 'The water is ice-cold and tastes of silver. You feel wolfish. At the edge, shed pelts, silver in the moonlight.', trophies: 3, potions: 1),
  Place('starlitglade', 'The Starlit Glade', 9, 440, 38, PlaceKind.shrine, 'A glade where the elves leave offerings to the stars: bowls of water, and folded silk. Taking some seems rude. Kneeling seems right.', 'Starlight pools in your hands and runs up your arms. (Arcane brew for three fights.) Somebody left elven silk on the stone; you take it, gratefully.', brew: 'arcane', trophies: 3),
  Place('lostmine', 'The Lost Mine', 10, 700, 32, PlaceKind.guarded, 'A mine the dwarves sealed and forgot. Somebody unsealed it, and is down there with a pick, laughing.', 'Rustbeard the Mad goes down at last. His cart is full: ore, and ingots of runesteel.', foe: ('dwarfAxe', null, Aura.blazing, 'Rustbeard the Mad'), ore: {'gold': 4, 'obsidian': 3}, trophies: 3),
  Place('maskmaker', 'The Mask-Maker\'s Hut', 11, 190, 106, PlaceKind.cache, 'A hut on the shore, walls hung with porcelain faces, every one of them smiling. The mask-maker is gone. The faces are watching the door.', 'Behind the workbench: her savings, and a basket of faces she never got to give back.', purses: 3, trophies: 4),
  Place('ziggurat', 'The Sunken Ziggurat', 12, 962, 418, PlaceKind.guarded, 'A stepped temple half-swallowed by the jungle, with something old sleeping on the altar at the top. It is very warm, and very big, and it is waking up.', 'The Egg-Keeper slumps across her altar. Around it: offerings of gold, gems, and her own shed scales.', foe: ('lizardShaman', 'lizardChampion', Aura.gilded, 'Sss\'thyx the Egg-Keeper'), purses: 3, gems: 1, trophies: 4),
  Place('krakenreef', 'The Kraken\'s Reef', 13, 715, 652, PlaceKind.guarded, 'A ring of black rock where the water boils, and wrecks piled on wrecks. Every sailor knows not to sail here. Every sailor knows why.', 'The Kraken sinks back into the deep with a sound like a ship breaking. Among the wrecks, where it slept: a weapon that belonged to a sea-god.', foe: ('seaSerpent', 'kraken', Aura.ancient, 'The Kraken'), purses: 4),
  Place('wreck', 'The Sunken Galleon', 13, 330, 640, PlaceKind.cache, 'A treasure galleon, broken on the reef at low tide. The merrow have been at it, but not all of it.', 'In the captain\'s cabin, under a foot of water: his strongbox, and a handful of pearls.', purses: 4, gems: 2, trophies: 2),
  Place('mirrorhall', 'The Hall of Mirrors', 14, 868, 600, PlaceKind.shrine, 'A ruined hall full of mirrors, and in every one, a different you: older, younger, a goblin, a dragon. One of them winks.', 'You stare until your reflection settles back into your own shape, and feel stronger for it. (Might for three fights.) The mirrors shed their silver skins at your feet.', brew: 'might', trophies: 3),
  Place('castleoflanterns', 'The Lantern Shrine', 16, 700, 640, PlaceKind.shrine, 'A shrine on a rock in the sea, hung with a thousand paper lanterns. An old priest sweeps the steps and doesn\'t look up.', 'You ring the bell and bow. The priest nods, once, and hands you a cup of tea and a folded scrap of lacquer. (Might for three fights.)', brew: 'might', trophies: 3),
  Place('rocnest', 'The Great Nest', 15, 798, 26, PlaceKind.guarded, 'A nest the size of a cottage on the highest peak, woven from whole trees, and something huge and feathered sitting on it.', 'The mother griffin takes wing and is gone. In the nest: feathers by the armful, gold the aeriekin left as offerings, and eggshell like porcelain.', foe: ('griffin', null, Aura.ancient, 'The Mother Griffin'), purses: 3, trophies: 4, gems: 1),
  // Relic guardians: they show once you hold the blueprint that needs what they guard.
  Place('emberpit', 'The Ember Pit', 3, 600, 140, PlaceKind.guarded, 'A pit in the red rock, glowing from the bottom. An ork fire-priest sits in it, cross-legged, a coal the size of your head cupped in his hands. It is the old king\'s ember core, and he has been praying to it.', 'Skarr the Ember-Keeper falls into his own fire and doesn\'t come out. The ember core is still warm. It will be warm for a thousand years.', foe: ('orkShaman', null, Aura.blazing, 'Skarr the Ember-Keeper'), purses: 3, relic: (0, 1), above: 3),
  Place('briarheart', 'The Briar Heart', 2, 140, 215, PlaceKind.guarded, 'Deep in the Thornwild, the brambles twist into a knot the size of a house, and the knot is breathing. Something at its heart keeps the whole wood growing.', 'The Briar Heart shudders, and lets go of the one living strand it was holding. It coils round your wrist, gently, like it\'s decided you\'ll do.', foe: ('thornEnt', null, Aura.venom, 'The Briar Heart'), purses: 2, relic: (2, 0), above: 3),
  Place('elderheart', 'The Elder Heartwood', 9, 285, 160, PlaceKind.guarded, 'The oldest tree in the Silverwood, hollowed out by the elves into a hall. An elf in silver-leaf armour stands at its door, and has done for three hundred years.', 'Warden Aelindor kneels, and offers you a grip of heartwood with both hands. "The Grandmother asked for it back, once. I told her no. I find I can\'t tell you no."', foe: ('elfWarden', null, Aura.ancient, 'Warden Aelindor'), purses: 3, relic: (2, 1), above: 3),
  Place('frozencaravan', 'The Frozen Caravan', 18, 785, 238, PlaceKind.cache, 'A merchant caravan, frozen solid in the middle of the pass: wagons, oxen, drivers, all of it, still mid-stride under the ice. The strongbox is on the last wagon.', 'You chip it free. Inside: a hundred-year-old fortune, a bottle of something warming, and furs the reavers never found.', purses: 4, potions: 1, trophies: 3),
  Place('yeticave', 'The Yeti\'s Larder', 18, 612, 180, PlaceKind.guarded, 'A cave full of bones, and a yeti the size of a cottage asleep across the mouth of it. Something in there glitters.', 'Old Avalanche goes down like his name. Past the bones: everything he ever took off a traveller.', foe: ('yeti', null, Aura.ancient, 'Old Avalanche'), purses: 3, gems: 2, trophies: 2),
  Place('orchardroost', 'The Orchard Roost', 17, 300, 612, PlaceKind.guarded, 'An old orchard sank into the caves when the hill fell in. The fruit bats found it. Their king has eaten every fig in it, and is still hungry.', 'The Fig King flaps off into the dark, much too full to fight. Under the trees: a pile of seeds, a pile of coins, and fangs he lost in the figs.', foe: ('cavebat', null, Aura.gilded, 'The Fig King'), purses: 2, trophies: 3),
  Place('lostisle', 'The Lost Isle', 0, 228, 20, PlaceKind.cache, 'Out past the coast, an island that isn\'t on any map but yours, now you\'ve been everywhere else. A rowing boat waits on the shore.', 'On the island, under a crooked tree: the old king\'s last treasure, buried before the Burning.', purses: 6, legendary: true, hidden: true),
];

Place? placeById(String? id) => places.where((p) => p.id == id).firstOrNull;

/// How hard each of your ways of fighting really lands on [f], all its traits together: the
/// triangle, flying (blades can't reach it well, bolts pluck it down), stone and spirit (only rites
/// bite cleanly) and the elves' dodging. Above 1 it's weak to it; below, it shrugs it off.
double styleEdgeOn(FoeType f, AttackStyle s) {
  var e = triangle(f.kind, s);
  if (f.aloft) e *= s == AttackStyle.blade ? aloftMelee : (s == AttackStyle.bolt ? aloftShot : 1);
  if (s != AttackStyle.rite && (f.stone || f.spirit)) e *= .6;
  if (s != AttackStyle.rite && f.evasive) e *= 1 - evasiveMiss;
  return e;
}

/// How [f] takes each kind of elemental harm ('burn', 'frost', 'poison', 'smite'), as the damage
/// rules work it out: above 1 weak, below 1 resistant (0: immune).
double elementEdgeOn(FoeType f, String st) {
  var e = switch (st) {
    'burn' => f.demon || f.look == 'emberKing' ? .5 : (f.ent ? 2.0 : 1.0),
    'poison' => f.venomous ? 0.0 : (f.ent ? .5 : 1.0),
    // Ordinary holy fire only burns the unholy (so they're weak to it), and spirits twice over.
    'smite' => (f.undead || f.demon || f.element == 'poison' ? 1.5 : 1.0) * (f.spirit ? 2 : 1),
    _ => 1.0,
  };
  if (f.element != null) e = f.element == st ? 0 : (elementWeakness(f.element!) == st ? e * 2 : e);
  return e;
}

/// The words for [AttackStyle]s on a foe's card.
const styleWords = {AttackStyle.blade: 'blades', AttackStyle.rite: 'rites', AttackStyle.bolt: 'the crossbow'};

/// What [f] is weak to and what it shrugs off, in a few words each for its card. Never the same
/// thing in both: each is worked out once, from how the blows really land.
(List<String>, List<String>) foeEdges(FoeType f) {
  final weak = <String>[], shrug = <String>[];
  void sort(String what, double e) {
    if (e > 1.01) weak.add(what);
    if (e < .99) shrug.add(what);
  }

  for (final s in AttackStyle.values) {
    sort(styleWords[s]!, styleEdgeOn(f, s));
  }
  // Stone cracks under a hammer, whatever blades do.
  if (f.stone) weak.add('hammers and maces');
  final burn = elementEdgeOn(f, 'burn');
  // What regrows is stopped by fire, unless fire can't touch it.
  sort('fire', f.regrows && burn >= 1 ? math.max(burn, 1.5) : burn);
  sort('holy fire', elementEdgeOn(f, 'smite'));
  sort('poison', elementEdgeOn(f, 'poison'));
  sort('frost', elementEdgeOn(f, 'frost'));
  if (f.ironhide) shrug.add('critical hits');
  return (weak, shrug);
}
