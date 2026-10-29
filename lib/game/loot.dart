// Random loot. Every defeated foe drops one piece of gear for your class (bosses drop better).
// There is no inventory: you either equip it (your old piece is sold) or sell it on the spot.

import 'dart:math' as math;

import 'classes.dart';
import 'enchants.dart';

export 'enchants.dart';

enum GearSlot { weapon, offhand, helm, trinket, armour, gloves, boots, ring, cape }

extension GearSlotLabel on GearSlot {
  String get label => switch (this) {
    GearSlot.weapon => 'Weapon',
    GearSlot.offhand => 'Off-hand',
    GearSlot.helm => 'Head',
    GearSlot.trinket => 'Trinket',
    GearSlot.armour => 'Armour',
    GearSlot.gloves => 'Hands',
    GearSlot.boots => 'Feet',
    GearSlot.ring => 'Ring',
    GearSlot.cape => 'Cape',
  };
}

// ------------------------------------------------------------------ capes

/// A cape: worn over the armour in its own colour, with one class ability (stored as the item's
/// [GearItem.special]).
class Cape {
  const Cape(this.id, this.name, this.heroClass, this.argb, this.stat, this.ability, this.lore);
  final String id, name, ability, lore;

  /// Null for a cape any class can wear (earned, never dropped).
  final HeroClass? heroClass;
  final int argb;
  final Stat stat;
}

const capes = <Cape>[
  Cape('rally', 'Bannerlord\'s cloak', HeroClass.knight, 0xFF8A1E22, Stat.vigour, 'Rally: once a fight, when a blow leaves you under 30% health, you rally and recover 25% of it', 'A torn banner, stitched into a cloak after the battle it won.'),
  Cape('vanguard', 'Crusader\'s mantle', HeroClass.knight, 0xFFE8E4DA, Stat.guard, 'Vanguard: the first blow struck at you each fight glances off completely', 'White as the first light. It has never been touched by a first strike.'),
  Cape('manawell', 'Cloak of the Wellspring', HeroClass.mage, 0xFF2F6AA8, Stat.wisdom, 'Wellspring: every fight starts with 1 extra mana', 'The hem is always damp, as if it has just come out of a holy pool.'),
  Cape('starweave', 'Starweave cloak', HeroClass.mage, 0xFF2A1A4A, Stat.crit, 'Starweave: every spell you cast hits 30% harder', 'Look closely and the stars on it move.'),
  Cape('firstshot', 'Hunter\'s cloak', HeroClass.ranger, 0xFF3E5A2E, Stat.crit, 'First Shot: your first attack each fight is always a critical hit', 'Leaves stick to it, and it never rustles.'),
  Cape('shadow', 'Shadow cloak', HeroClass.ranger, 0xFF1E1A22, Stat.dodge, 'Shadowstep: when you dodge a blow, you strike back from the shadows', 'You put it on, and for a moment nobody remembers you were there.'),
];

Cape? capeByAbility(String? id) => capes.where((c) => c.id == id).firstOrNull;

/// Chance a boss or rare foe leaves a cape for your class.
const capeChance = .06;

// ------------------------------------------------------------------ gear sets

/// A set of gloves, boots and a ring that steers a build. Wear two pieces for the first bonus,
/// all three for the second as well.
class GearSet {
  const GearSet(this.id, this.name, this.two, this.three, this.twoText, this.threeText, {this.heroClass, this.cheaperSpells = false, this.forged = false, this.bloodthirst = false, this.longWolf = false, this.firstMiss = false, this.forgeheart = false, this.firstCrit = false, this.regrowth = false, this.undertow = false, this.adapt = false, this.updraft = false, this.bushido = false});
  final String id, name, twoText, threeText;
  final Map<Stat, int> two, three;
  final HeroClass? heroClass;

  /// The three-piece bonus also makes every spell cost 1 less mana (the Arcanist's).
  final bool cheaperSpells;

  /// Only forged at Dunstan's, from blueprints (never a random drop).
  final bool forged;

  /// The full Nightblood set: under half health, every heal from your blows is doubled.
  final bool bloodthirst;

  /// The full Moonfang set: the Bloodmoon Pelt's wolf stays [longWolfTurns] turns longer.
  final bool longWolf;

  /// The full Silverleaf set: the first blow struck at you each fight misses.
  final bool firstMiss;

  /// The full Deepforge set: every blow you block mends you ([forgeheartHeal] of your HP).
  final bool forgeheart;

  /// The full Faceless set: nobody sees your first blow coming. It's always a critical hit.
  final bool firstCrit;

  /// The full Sunscale set: like the lizardfolk, your wounds close over. Under half health, you
  /// mend [regrowthHeal] of your HP every turn.
  final bool regrowth;

  /// The full Tidecaller set: your frost drags at the foe like the undertow. A frost hit now and
  /// then ([undertowChance]) slows it: half its blows miss for two turns.
  final bool undertow;

  /// The full Changeling set: change how you strike (blade, rite or bolt) from one turn to the next
  /// and the blow lands [adaptBoost] times as hard.
  final bool adapt;

  /// The full Skyborn set: you fight like you were born in the air. Against foes aloft, everything
  /// you do lands [updraftBoost] times as hard (it more than makes up for a blade's lost reach).
  final bool updraft;

  /// The full Bushido set: each turn a fight lasts, your blows land [bushidoStep] harder, up to
  /// [bushidoCap].
  final bool bushido;
}

/// How hard each forged set's pieces roll, so every set's pieces come out about as strong as one
/// another (and a little stronger than a random epic piece): their stats are worth different amounts.
const _setPower = <String, double>{
  'ashen': 1.26,
  'nightblood': 1.4,
  'moonfang': 1.16,
  'silverleaf': 1.4,
  'deepforge': 1.75,
  'faceless': 1.32,
  'sunscale': 1.2,
  'tidecaller': 1.03,
  'changeling': 1.1,
  'skyborn': 1.6,
  'bushido': 1.25,
};

/// Turns the full Moonfang set adds to the wolf; what the full Deepforge set mends on a block.
const longWolfTurns = 2, forgeheartHeal = .06, regrowthHeal = .04, undertowChance = .25, adaptBoost = 1.2, updraftBoost = 1.25, bushidoStep = .05, bushidoCap = .25;

const gearSets = <GearSet>[
  GearSet('embersworn', 'Embersworn', {Stat.burn: 6}, {Stat.burn: 10, Stat.crit: 5}, '+6 fire on every full swing', '+10 more fire and +5% crit: a fire build'),
  GearSet('bloodbound', 'Bloodbound', {Stat.leech: 4}, {Stat.leech: 6, Stat.lifesteal: 6}, 'Heal 4% of your damage', 'Heal 6% more, plus 6 per swing: a lifesteal build'),
  GearSet('windrunner', 'Windrunner', {Stat.dodge: 5}, {Stat.dodge: 5, Stat.crit: 8}, '+5% dodge', '+5% more dodge and +8% crit: a quick, deadly build'),
  GearSet('bulwark', 'Bulwark', {Stat.block: 5}, {Stat.block: 5, Stat.thorns: 25, Stat.guard: 5}, '+5% block', '+5% more block, +5% guard and thorns: a wall'),
  GearSet('arcanist', 'Arcanist', {Stat.wisdom: 20, Stat.crit: 3}, {}, '+20% XP and +3% crit', 'Every spell costs 1 less mana', heroClass: HeroClass.mage, cheaperSpells: true),
  // Forged from blueprints: the Ashen Order's, Ravenmoor's vampires' and the Weald's werewolves'.
  GearSet('ashen', 'Ashen', {Stat.guard: 4, Stat.burn: 3}, {Stat.thorns: 20, Stat.burn: 4}, '+4% guard and +3 fire', '+20 thorns and +4 more fire: whoever strikes you burns', forged: true),
  GearSet('nightblood', 'Nightblood', {Stat.leech: 4, Stat.lifesteal: 4}, {Stat.leech: 3}, 'Heal 4% of your damage, plus 4 a swing', 'Bloodthirst: under half health, everything your blows heal you is doubled', forged: true, bloodthirst: true),
  GearSet('moonfang', 'Moonfang', {Stat.crit: 5, Stat.dodge: 3}, {Stat.crit: 4, Stat.dodge: 3, Stat.damage: 3}, '+5% crit and +3% dodge', '+4% crit, +3% dodge, +3 damage, and the Bloodmoon Pelt\'s wolf stays $longWolfTurns turns longer', forged: true, longWolf: true),
  GearSet('silverleaf', 'Silverleaf', {Stat.dodge: 4, Stat.crit: 4}, {Stat.dodge: 4, Stat.regen: 8}, '+4% dodge and +4% crit', '+4% more dodge, regeneration, and the first blow at you each fight always misses', forged: true, firstMiss: true),
  GearSet('deepforge', 'Deepforge', {Stat.guard: 5, Stat.block: 4}, {Stat.block: 5, Stat.vigour: 20}, '+5% guard and +4% block', '+5% more block, +20 vigour, and every blow you block mends you 6% of your HP', forged: true, forgeheart: true),
  GearSet('faceless', 'Faceless', {Stat.crit: 5, Stat.parry: 4}, {Stat.crit: 5, Stat.damage: 4}, '+5% crit and +4% parry', '+5% more crit, +4 damage, and your first blow each fight is always a critical hit', forged: true, firstCrit: true),
  GearSet('sunscale', 'Sunscale', {Stat.vigour: 20, Stat.regen: 6}, {Stat.thorns: 15, Stat.guard: 4}, '+20 vigour and regeneration', '+15 thorns and +4% guard, and under half health you regrow 4% of your HP every turn, like a lizard', forged: true, regrowth: true),
  GearSet('tidecaller', 'Tidecaller', {Stat.frost: 5, Stat.dodge: 3}, {Stat.frost: 4, Stat.regen: 6}, '+5 frost on every full swing and +3% dodge', '+4 more frost, regeneration, and now and then your frost drags the foe down like the undertow: half its blows miss for two turns', forged: true, undertow: true),
  GearSet('changeling', 'Changeling', {Stat.dodge: 4, Stat.crit: 4}, {Stat.damage: 2, Stat.crit: 4}, '+4% dodge and +4% crit', '+2 damage, +4% more crit, and whenever you change how you strike from the turn before (blade, rite or bolt), the blow lands 20% harder', forged: true, adapt: true),
  GearSet('bushido', 'Bushido', {Stat.parry: 4, Stat.crit: 4}, {Stat.damage: 3, Stat.parry: 3}, '+4% parry and +4% crit', '+3 damage, +3% more parry, and every turn a fight goes on, your blows land 5% harder (up to 25%): the longer the duel, the surer the cut', forged: true, bushido: true),
  GearSet('skyborn', 'Skyborn', {Stat.dodge: 5, Stat.crit: 3}, {Stat.crit: 4, Stat.dodge: 3}, '+5% dodge and +3% crit', '+4% more crit, +3% dodge, and against anything in the air (fliers, ghosts, archers on the cliffs) all your blows land 25% harder', forged: true, updraft: true),
];

GearSet? gearSetById(String? id) => gearSets.where((s) => s.id == id).firstOrNull;

/// Chance a rare-or-better pair of gloves, boots or ring belongs to a set.
const gearSetChance = .25;

/// Gear sets active from [gear]: each with how many pieces are worn (2 or 3).
List<(GearSet, int)> activeSets(Iterable<GearItem> gear) {
  final counts = <String, int>{};
  for (final g in gear) {
    if (g.gearSet != null) counts[g.gearSet!] = (counts[g.gearSet!] ?? 0) + 1;
  }
  return [
    for (final e in counts.entries)
      if (e.value >= 2 && gearSetById(e.key) != null) (gearSetById(e.key)!, e.value),
  ];
}

enum Rarity { common, uncommon, rare, epic, legendary }

extension RarityInfo on Rarity {
  String get label => switch (this) {
    Rarity.common => 'Common',
    Rarity.uncommon => 'Uncommon',
    Rarity.rare => 'Rare',
    Rarity.epic => 'Epic',
    Rarity.legendary => 'Legendary',
  };
  int get argb => switch (this) {
    Rarity.common => 0xFFB8B2A4,
    Rarity.uncommon => 0xFF6FBF4A,
    Rarity.rare => 0xFF4F8FE0,
    Rarity.epic => 0xFFA867D8,
    Rarity.legendary => 0xFFF09A2E,
  };
  double get power => const [1.0, 1.2, 1.45, 1.75, 2.1][index];
  double get valueMult => const [1.0, 1.4, 2.0, 3.0, 4.5][index];
}

// ------------------------------------------------------------------ off-hands

/// What a weapon leaves the other hand free for.
enum OffhandKind { shield, focus, quiver, sidearm, parrying, wand }

extension OffhandKindInfo on OffhandKind {
  String get label => switch (this) {
    OffhandKind.shield => 'shields',
    OffhandKind.focus => 'spellbooks and orbs',
    OffhandKind.quiver => 'quivers',
    OffhandKind.sidearm => 'hand crossbows',
    OffhandKind.parrying => 'off-hand daggers',
    OffhandKind.wand => 'off-hand wands',
  };

  /// The weapons that take this kind of off-hand.
  String get weapons => switch (this) {
    OffhandKind.shield => 'one-handed swords, daggers, axes and maces',
    OffhandKind.focus => 'wands and sceptres',
    OffhandKind.quiver => 'bows',
    OffhandKind.sidearm => 'crossbows and hand crossbows (dual wield)',
    OffhandKind.parrying => 'daggers, short swords and scimitars (dual wield), and chakrams, throwing knives and hand cannons',
    OffhandKind.wand => 'wands and sceptres (dual wield)',
  };
}

/// Light one-handed blades: they can take a second blade in the off hand instead of a shield.
const lightBlades = {'dagger', 'shortsword', 'scimitar', 'dragondagger', 'rapier', 'katana', 'wakizashi'};

/// The off-hand a weapon usually pairs with, or null for two-handed weapons (greatswords,
/// polearms, staves, cannons): both hands on the haft.
OffhandKind? offhandKindFor(String? weaponArt) => switch (weaponArt) {
  'dagger' || 'shortsword' || 'longsword' || 'scimitar' || 'falchion' || 'axe' || 'mace' || 'morningstar' || 'club' || 'orkclub' || 'dragondagger' || 'hook' || 'flail' || 'thornblade' || 'rapier' || 'katana' || 'wakizashi' || 'flamberge' || 'frostbrand' || 'dawnblade' || 'shadowblade' => OffhandKind.shield,
  // The Bramblelash is a lash in one hand: a shield, a tome or a parrying blade in the other, by class.
  'whip' => OffhandKind.shield,
  'wand' || 'sceptre' => OffhandKind.focus,
  'shakujo' => OffhandKind.focus, // a monk's staff in one hand, a war fan in the other
  'runeblade' => OffhandKind.shield,
  'bow' || 'longbow' || 'orkbow' || 'heartbow' || 'runebow' || 'yumi' => OffhandKind.quiver,
  'crossbow' || 'handcrossbow' => OffhandKind.sidearm,
  'chakram' || 'throwingknives' || 'handcannon' || 'tomahawk' || 'shuriken' => OffhandKind.parrying,
  null => OffhandKind.shield,
  _ => null,
};

/// Every off-hand a weapon can take: its usual one, plus a second weapon for dual wielding
/// (a dagger beside a light blade, a second wand beside a wand).
Set<OffhandKind> offhandKindsFor(String? weaponArt) {
  final main = offhandKindFor(weaponArt);
  return {
    if (main != null) main,
    if (lightBlades.contains(weaponArt)) OffhandKind.parrying,
    if (weaponArt == 'wand' || weaponArt == 'sceptre') OffhandKind.wand,
    if (weaponArt == 'whip') ...[OffhandKind.focus, OffhandKind.parrying],
  };
}

/// What kind of off-hand an item is.
OffhandKind? offhandKindOf(String art) => switch (art) {
  'buckler' || 'kite' || 'tower' || 'round' || 'dragonshield' => OffhandKind.shield,
  'tome' || 'orb' || 'fan' => OffhandKind.focus,
  'quiver' => OffhandKind.quiver,
  'handcrossbow' => OffhandKind.sidearm,
  'dagger' || 'wakizashi' => OffhandKind.parrying,
  'wand' => OffhandKind.wand,
  _ => null,
};

/// Whether [offhand] can be used alongside [weapon]. A mismatched off-hand stays in your kit
/// but does nothing until you wield a weapon it suits.
bool offhandWorksWith(GearItem? weapon, GearItem? offhand) {
  if (offhand == null) return false;
  final kind = offhandKindOf(offhand.art);
  return kind != null && offhandKindsFor(weapon?.art).contains(kind);
}

/// Dual wielding: a second weapon in the off hand (a dagger beside a light blade, a second wand,
/// a hand crossbow beside a crossbow) that strikes after every full swing. You give up a shield
/// or tome for it.
bool isDualWield(GearItem? weapon, GearItem? offhand) {
  if (!offhandWorksWith(weapon, offhand)) return false;
  return switch (offhandKindOf(offhand!.art)) {
    OffhandKind.wand || OffhandKind.sidearm => true,
    OffhandKind.parrying => lightBlades.contains(weapon?.art),
    _ => false,
  };
}

// ------------------------------------------------------------------ special attacks

// ------------------------------------------------------------------ crits by weapon

/// Built-in critical-hit chance (percent) from a weapon's kind: quick, precise weapons crit more.
int weaponKindCrit(String? art) => switch (art) {
  'dagger' || 'dragondagger' || 'throwingknives' => 8,
  'handcrossbow' => 8, // quick to aim
  'crossbow' || 'handcannon' => 6,
  'scimitar' || 'falchion' || 'shortsword' || 'chakram' => 5,
  'runeblade' || 'runebow' => 6, // runes guide the strike
  'runestaff' => 4,
  'bow' || 'longbow' || 'orkbow' || 'heartbow' || 'longsword' || 'spear' || 'trident' || 'wand' => 3,
  'hook' => 6,
  'whip' || 'tomahawk' => 5,
  'rapier' || 'shuriken' => 7, // the point finds the gaps
  'katana' || 'wakizashi' => 6,
  'yumi' => 4,
  'flamberge' || 'frostbrand' || 'dawnblade' || 'shadowblade' => 4,
  'glaive' || 'naginata' => 3,
  'cleaver' || 'kanabo' || 'shakujo' => 1, // the lash cracks where it's aimed; the axe flies true
  'thornblade' => 4,
  'flail' => 3, // it comes round the shield
  'scythe' => 2,
  'sceptre' || 'axe' || 'halberd' || 'crystalstaff' => 2,
  _ => 1, // greatswords, hammers, maces, staves, cannons: heavy, steady hitters
};

/// Extra crit chance (percent) by rarity: rarer weapons find the gaps more often.
int rarityCrit(Rarity r) => const [0, 2, 4, 7, 10][r.index];

/// A weapon's total built-in crit chance (percent).
int weaponCrit(GearItem? w) => w == null ? 1 : weaponKindCrit(w.art) + rarityCrit(w.rarity);

/// How hard a critical hit lands with this weapon: legendaries hit 2.5x.
double critMultiplier(GearItem? w) => w?.rarity == Rarity.legendary ? 2.5 : 2.0;

/// The share of epic and legendary weapon drops that are bloodleech weapons.
const bloodleechChance = .12;

/// The most of your damage you can heal from bloodleech, however it's stacked (ammunition can
/// push it a little further for that one shot).
const leechCap = 25;

/// Full swings it takes to charge a special attack; it fires on the last of them.
const specialCharge = 4;

/// Specials fire at random: this chance on any attack, a little more for each attack since the
/// last (so a dry spell never runs long). About one attack in four, on average.
const specialBase = .15, specialStep = .045;
double specialChanceAt(int since) => math.min(1, specialBase + specialStep * since);

/// A quest weapon's special attack. It charges with each full swing and fires on its own.
class Special {
  const Special(this.name, this.desc, this.mult, this.argb, {this.heal = 0, this.coins = 0, this.crit = false, this.sure = false, this.volley = 0, this.element, this.meteor = false, this.wave = false, this.kraken = false, this.rain = false, this.cleave = false, this.dragon = false, this.dice = false, this.deadrun = false, this.storm = false, this.bats = false, this.demon = false, this.legion = false, this.wolves = false, this.avalanche = false, this.stun = 0, this.selfHurt = 0, this.summon = 0, this.expose = 0});
  final String name, desc;

  /// Multiplies the swing's base damage.
  final double mult;
  final int argb;

  /// HP restored and gold found when it fires.
  final int heal, coins;

  /// Always a critical hit; never misses (even ale-addled).
  final bool crit, sure;

  /// Extra arrows loosed (for the animation).
  final int volley;

  /// Extra elemental damage, 3 per hero level.
  final Stat? element;

  /// Falls from the sky (for the animation).
  final bool meteor;

  /// A wall of seawater crashes across the field; tentacles burst up under the foe.
  final bool wave, kraken;

  /// Arrows or bolts rain down from the sky; a great sweeping blow.
  final bool rain, cleave;

  /// What comes for the foe (for the animation): a dragon breathing fire, the dice of fate, the
  /// dead riding out, lightning from the sky, a swarm of bats, a demon from a burning rift, the
  /// dead clawing up out of the ground, ghost wolves.
  final bool dragon, dice, deadrun, storm, bats, demon, legion, wolves;

  /// The mountain comes down: great shards of ice fall on the foe.
  final bool avalanche;

  /// What it leaves behind: the chance the foe is stunned out of its next blow, a share of your
  /// own health it costs you, skeletons that stay to fight (for 2 turns), and turns the foe's
  /// guard is torn open (your hits deal 25% more).
  final double stun, selfHurt;
  final int summon, expose;
}

const specials = <String, Special>{
  'verdict': Special('Royal Verdict', 'A crushing blow for triple damage, and holy fire', 3, 0xFFFFD45A, element: Stat.smite, sure: true),
  'crownvolley': Special('Volley of the Crown', 'Five golden arrows at once: triple damage', 3, 0xFFFFD45A, volley: 4, sure: true),
  'edict': Special('Edict of Light', 'A beam of holy light: 2.5x damage plus holy fire', 2.5, 0xFFFFF0A0, element: Stat.smite, sure: true),
  'harvest': Special('Harvest Home', 'A mighty heave: double damage, and you recover 20 HP', 2, 0xFF9BE27A, heal: 20),
  'luckyshot': Special('Lucky Shot', 'Always a critical hit, and 25 gold found on the foe', 1, 0xFFF2C14E, crit: true, coins: 25, sure: true),
  'hearth': Special('Hearth Charm', 'A warm spell: 1.8x damage, and you recover 25 HP', 1.8, 0xFFFFB060, heal: 25),
  'fate': Special('Twist of Fate', 'Fate guides the blade: 1.5x damage, always critical', 1.5, 0xFFC07AFF, crit: true, sure: true),
  'omen': Special('Foretold Shot', 'An arrow that was always going to land: quadruple damage', 4, 0xFFC07AFF, sure: true),
  'glimpse': Special('Glimpse Beyond', 'Strike where the foe will be: double damage, always critical', 2, 0xFFC07AFF, crit: true, sure: true),
  'thunder': Special('Thunderclap', 'Lightning and ice: 2.5x damage plus frost', 2.5, 0xFF9ADFFF, element: Stat.frost, sure: true),
  'firerain': Special('Rain of Fire', 'A sky full of burning arrows: 2.5x damage plus fire', 2.5, 0xFFFF7A2A, volley: 4, element: Stat.burn, sure: true),
  'runesurge': Special('Runic Surge', 'The runes blaze white: 2.5x damage plus holy fire', 2.5, 0xFF7FE0FF, element: Stat.smite, sure: true),
  'poseidon': Special('Wrath of the Deep', 'The trident calls either a Tidal Wave (2.8x damage plus frost) or the Kraken itself (3x damage)', 3, 0xFF3AA8D8, sure: true),
  'tidalwave': Special('Tidal Wave', 'A wall of seawater crashes over the foe: 2.8x damage plus frost', 2.8, 0xFF3AA8D8, element: Stat.frost, wave: true, sure: true),
  'krakencall': Special('Call of the Kraken', 'Tentacles burst from the earth and crush the foe: triple damage', 3, 0xFF4E8A8A, kraken: true, sure: true),
  'tidevolley': Special('Tidecaller Volley', 'Arrows of living seawater ride a breaking wave: 2.5x damage plus frost', 2.5, 0xFF3AA8D8, volley: 4, element: Stat.frost, wave: true, sure: true),
  'reelin': Special('Reel \'Em In', 'Hook the foe and haul it close: double damage, always critical, and 30 gold shaken loose', 2, 0xFFC8B070, crit: true, coins: 30, sure: true),
  // Every legendary weapon carries its class's special.
  'arrowrain': Special('Arrow Rain', 'A storm of arrows falls from the sky: 2.2x damage', 2.2, 0xFFF2C14E, rain: true, sure: true),
  'arcanestorm': Special('Arcane Storm', 'Bolts of raw magic rain down on the foe: 2.2x damage', 2.2, 0xFFB07AFF, rain: true, sure: true),
  'cleave': Special('Mighty Cleave', 'A great sweeping blow: 2.2x damage', 2.2, 0xFFE8E2D0, cleave: true, sure: true),
  'oath': Special('Unbroken Oath', 'Every promise you kept strikes at once: triple damage plus holy fire', 3, 0xFFF0E2B8, element: Stat.smite, sure: true),
  'kingsfall': Special('Fall of Kings', 'The crack in the blade splits open: a sweeping blow of crown-fire for 3.2x damage plus fire', 3.2, 0xFFFF8A3A, element: Stat.burn, cleave: true, sure: true),
  'bramblelash': Special('Bramblelash', 'The briar lashes out and roots the foe: 3x damage plus poison, and you recover 15 HP', 3, 0xFF6FBF4A, element: Stat.poison, heal: 15, sure: true),
  'briarvolley': Special('Briarsong', 'Arrows that burst into thorns where they land: 3x damage plus poison, and you recover 15 HP', 3, 0xFF6FBF4A, volley: 4, element: Stat.poison, heal: 15, sure: true),
  'meteor': Special('Meteor', 'Calls down a falling star: triple damage plus fire', 3, 0xFFFF7A2A, element: Stat.burn, meteor: true, sure: true),
  // The legendary specials: each named legendary weapon carries one of its class's (see
  // [legendSpecial]). All are worth about the same; they just do it differently.
  'wyrmcall': Special('Wyrmcall', 'A dragon answers: it sweeps down and bathes the foe in fire, 1.6x damage plus fire', 1.6, 0xFFFF7A2A, element: Stat.burn, dragon: true, sure: true),
  'fatesroll': Special('Roll of Fate', 'Roll the bones: lucky, the blade blazes for 3x damage; unlucky, a plain hit and the dice bite back', 1, 0xFFF2C14E, dice: true, sure: true),
  'luckyroll': Special('Lucky!', 'Sixes! The blade blazes: 3x damage', 3, 0xFFF2C14E, dice: true, sure: true),
  'unluckyroll': Special('Unlucky!', 'Snake eyes: a plain hit, and the dice bite back (8% of your health and a point of mana)', 1, 0xFFB06AE0, dice: true, selfHurt: .08, sure: true),
  'deadcharge': Special('Charge of the Dead', 'A host of the dead rides out of the ground and straight through the foe: 2.3x damage', 2.3, 0xFFB07AFF, deadrun: true, sure: true),
  'stormcall': Special('Stormcall', 'Lightning splits the sky and strikes the foe: 2x damage, and half the time it\'s stunned out of its next blow', 2, 0xFFCFE8FF, storm: true, stun: .5, sure: true),
  'nightswarm': Special('Night Swarm', 'A storm of bats pours over the foe: 2x damage, and you drink 15 HP from it', 2, 0xFF9A8ABA, bats: true, heal: 15, sure: true),
  'hellgate': Special('Hellgate', 'A demon claws out of a burning rift and strikes: double damage plus fire, but it takes its price (5% of your health)', 2, 0xFFE0402A, element: Stat.burn, demon: true, selfHurt: .05, sure: true),
  'legion': Special('Rise, Legion', 'The dead claw up out of the ground and tear at the foe: 2x damage, and one stays to fight for 2 turns', 2, 0xFF8A5AC0, legion: true, summon: 1, sure: true),
  'avalanche': Special('Avalanche', 'The mountain answers: a fall of ice crashes down on the foe, 2x damage plus frost, and half the time it\'s frozen out of its next blow', 2, 0xFFBFE8FF, element: Stat.frost, avalanche: true, stun: .5, sure: true),
  'moonpack': Special('Moon Pack', 'Ghost wolves race out of the dark and tear its guard open: 2x damage, and your hits deal 25% more for 2 turns', 2, 0xFF9ADFFF, wolves: true, expose: 2, sure: true),
};

/// The specials a class's named legendary weapons carry: each weapon always the same one (picked
/// by its name), so a legendary is known by its special.
const legendSpecials = <HeroClass, List<String>>{
  HeroClass.knight: ['cleave', 'fatesroll', 'deadcharge', 'hellgate', 'stormcall'],
  HeroClass.mage: ['arcanestorm', 'wyrmcall', 'legion', 'stormcall', 'hellgate'],
  HeroClass.ranger: ['arrowrain', 'moonpack', 'stormcall', 'fatesroll', 'nightswarm'],
};

String legendSpecial(String name, HeroClass c) {
  final pool = legendSpecials[c]!;
  return pool[name.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) % pool.length];
}

/// The special every legendary weapon of a class carries.
String classSpecial(HeroClass c) => switch (c) {
  HeroClass.knight => 'cleave',
  HeroClass.mage => 'arcanestorm',
  HeroClass.ranger => 'arrowrain',
};

/// Everything gear can do. Per-swing effects only apply to full-strength swings.
enum Stat { damage, poison, burn, frost, smite, crit, lifesteal, guard, vigour, regen, thorns, fortune, wisdom, dragonkin, dodge, parry, block, leech, wyrmbane }

extension StatInfo on Stat {
  bool get percent => const {Stat.crit, Stat.guard, Stat.fortune, Stat.wisdom, Stat.dodge, Stat.parry, Stat.block, Stat.leech, Stat.wyrmbane}.contains(this);

  String describe(int v) => switch (this) {
    Stat.damage => '+$v damage per swing',
    Stat.poison => '+$v poison per swing',
    Stat.burn => '+$v fire per swing',
    Stat.frost => '+$v frost per swing',
    Stat.smite => '+$v holy damage to the undead',
    Stat.crit => '+$v% critical hit chance',
    Stat.lifesteal => 'Heal $v HP per swing',
    Stat.guard => '$v% less damage taken',
    Stat.vigour => '+$v max HP',
    Stat.regen => 'Heal $v HP after every win',
    Stat.thorns => 'Deal $v back when you are hurt',
    Stat.fortune => '+$v% gold from victories',
    Stat.wisdom => '+$v% XP from victories',
    Stat.dragonkin => '+$v to your dragon\'s fire',
    Stat.dodge => '+$v% chance to dodge the foe\'s counter',
    Stat.parry => '+$v% chance to parry the foe\'s counter',
    Stat.block => '+$v% chance to block the foe\'s counter',
    Stat.leech => 'Heal $v% of your damage (bloodleech)',
    Stat.wyrmbane => '+$v% damage to dragons',
  };
}

class GearItem {
  GearItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.art,
    required this.rarity,
    required this.level,
    required this.stats,
    required this.value,
    this.heroClass,
    this.lore,
    this.tint,
    this.special,
    this.enchant,
    this.gearSet,
  });

  /// The gear set this piece belongs to (an id in [gearSets]), if any.
  final String? gearSet;

  /// A rune from the enchanter (or found on the drop).
  EnchantRoll? enchant;

  /// A quest weapon's special attack (an id in [specials]).
  final String? special;
  Special? get specialMove => special == null ? null : specials[special];

  final String id, name, art;

  /// Material colour (bronze, steel, yew...) for the weapon's blade or wood.
  final int? tint;
  final GearSlot slot;
  final HeroClass? heroClass; // null = any class (trinkets)
  final Rarity rarity;
  final int level, value;
  final Map<Stat, int> stats;
  final String? lore;

  int stat(Stat s) => stats[s] ?? 0;

  /// The dominant effect colour shown on the weapon (poison green, fire orange, frost blue...).
  Stat? get element {
    // An elemental rune shows first: it's what the enchanter made glow.
    final rune = enchant?.info.stat;
    if (rune == Stat.poison || rune == Stat.burn || rune == Stat.frost || rune == Stat.smite) return rune;
    for (final s in const [Stat.poison, Stat.burn, Stat.frost, Stat.smite]) {
      if (stat(s) > 0) return s;
    }
    return null;
  }

  /// A rough single number to compare items in the same slot.
  int get score {
    var t = 0.0;
    stats.forEach((s, v) => t += v * statWeight(s));
    // A special attack (quest and rune weapons) fires every few swings: worth a lot.
    if (special != null) t *= 1.35;
    return t.round();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slot': slot.name,
    'art': art,
    'rarity': rarity.name,
    'level': level,
    'value': value,
    'cls': heroClass?.name,
    'lore': lore,
    if (tint != null) 'tn': tint,
    if (special != null) 'sp': special,
    if (gearSet != null) 'set': gearSet,
    if (enchant != null) 'en': enchant!.toJson(),
    'stats': {for (final e in stats.entries) e.key.name: e.value},
  };

  factory GearItem.fromJson(Map<String, dynamic> j) => GearItem(
    id: j['id'] as String,
    name: j['name'] as String,
    slot: GearSlot.values.byName(j['slot'] as String),
    art: j['art'] as String,
    rarity: Rarity.values.byName(j['rarity'] as String),
    level: (j['level'] as num).toInt(),
    value: (j['value'] as num).toInt(),
    heroClass: j['cls'] == null ? null : HeroClass.values.byName(j['cls'] as String),
    lore: j['lore'] as String?,
    tint: (j['tn'] as num?)?.toInt(),
    special: j['sp'] as String?,
    gearSet: j['set'] as String?,
    enchant: EnchantRoll.fromJson(j['en']),
    stats: {
      for (final e in ((j['stats'] as Map?) ?? {}).entries)
        if (Stat.values.any((s) => s.name == e.key)) Stat.values.byName(e.key as String): (e.value as num).toInt(),
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Bases: what an item is before any enchantment. (name, art, primary stat, primary scale)

/// What a weapon is made of, which sets its material word and colour as levels rise.
enum _Make { none, metal, wood }

class _Base {
  const _Base(this.name, this.art, this.primary, this.scale, [this.make = _Make.none]);
  final String name, art;
  final Stat primary;
  final double scale;
  final _Make make;
}

/// Materials by level band: (name, colour). Each band up adds 7% to the base stat.
/// The six material tiers, one per level band (1–3, 4–6, 7–10, 11–15, 16–22, 23+): metal for
/// blades, maces, crossbows and armour pieces; wood for bows, staves and wands. A better material
/// means more of the item's main stat (+7% a tier).
const _metals = <(String, int)>[
  ('Bronze', 0xFFC8925A),
  ('Iron', 0xFF9EA4AA),
  ('Steel', 0xFFD8DEE4),
  ('Silver', 0xFFF2F5F8),
  ('Gold', 0xFFF2D27A),
  ('Platinum', 0xFFCFDCEC),
];
const _woods = <(String, int)>[
  ('Ash', 0xFFB08A5A),
  ('Oak', 0xFF8A6440),
  ('Yew', 0xFF9A5A3A),
  ('Elder', 0xFF6A4E3A),
  ('Silverbark', 0xFFC8CCD4),
  ('Goldenwood', 0xFFE0C47A),
];

/// The material an item is made of and its tier (1–6), or null for cloth, leather and jewels.
(String, int)? materialOf(GearItem g) {
  final first = g.name.split(' ').first;
  for (final ladder in [_metals, _woods]) {
    final i = ladder.indexWhere((m) => m.$1 == first);
    if (i >= 0) return (ladder[i].$1, i + 1);
  }
  return null;
}

/// The material band for a level: 1–3, 4–6, 7–10, 11–15, 16–22, 23+.
int _band(int level) => level <= 3 ? 0 : level <= 6 ? 1 : level <= 10 ? 2 : level <= 15 ? 3 : level <= 22 ? 4 : 5;

const _m = _Make.metal, _wd = _Make.wood;

/// The Blossom Isles' armouries: weapons and off-hands that only drop there.
const Map<HeroClass, Map<GearSlot, List<_Base>>> _eastBases = {
  HeroClass.knight: {
    GearSlot.weapon: [
      _Base('Katana', 'katana', Stat.damage, 1.2, _m),
      _Base('Wakizashi', 'wakizashi', Stat.damage, 1.0, _m),
      _Base('Naginata', 'naginata', Stat.damage, 1.25, _m),
      _Base('Yari', 'spear', Stat.damage, 1.15, _m),
      _Base('Kanabo', 'kanabo', Stat.damage, 1.3, _m),
    ],
    GearSlot.offhand: [
      _Base('Off-hand wakizashi', 'wakizashi', Stat.parry, .9, _m),
      _Base('Round shield', 'round', Stat.guard, .95),
    ],
    GearSlot.helm: [
      _Base('Kabuto', 'kabuto', Stat.vigour, 1.1),
      _Base('Horned kabuto', 'kabuto', Stat.vigour, 1.2),
    ],
  },
  HeroClass.mage: {
    GearSlot.weapon: [
      _Base('Shakujo', 'shakujo', Stat.damage, 1.2, _wd),
      _Base('Temple shakujo', 'shakujo', Stat.damage, 1.3),
    ],
    GearSlot.offhand: [
      _Base('War fan', 'fan', Stat.wisdom, 1.1),
      _Base('Storm fan', 'fan', Stat.frost, 1.05),
    ],
    GearSlot.helm: [
      _Base('Eboshi', 'eboshi', Stat.wisdom, 1.1),
      _Base('Kitsune mask', 'spiritmask', Stat.regen, 1.05),
    ],
  },
  HeroClass.ranger: {
    GearSlot.weapon: [
      _Base('Yumi', 'yumi', Stat.damage, 1.25, _wd),
      _Base('Shuriken', 'shuriken', Stat.damage, 1.1, _m),
    ],
    GearSlot.offhand: [
      _Base('Tanto', 'dagger', Stat.crit, .9, _m),
    ],
    GearSlot.helm: [
      _Base('Shinobi hood', 'mask', Stat.vigour, 1.1),
      _Base('Jingasa', 'jingasa', Stat.vigour, 1.05),
    ],
  },
};

const Map<HeroClass, Map<GearSlot, List<_Base>>> _bases = {
  HeroClass.knight: {
    GearSlot.weapon: [
      // Daggers
      _Base('Dirk', 'dagger', Stat.damage, .85, _m),
      _Base('Rondel dagger', 'dagger', Stat.damage, .95, _m),
      // Short swords
      _Base('Gladius', 'shortsword', Stat.damage, .95, _m),
      _Base('Cutlass', 'scimitar', Stat.damage, .95, _m),
      // Longswords
      _Base('Arming sword', 'longsword', Stat.damage, 1.0, _m),
      _Base('Longsword', 'longsword', Stat.damage, 1.1, _m),
      _Base('Bastard sword', 'longsword', Stat.damage, 1.15, _m),
      // Halberds
      _Base('Halberd', 'halberd', Stat.damage, 1.2, _m),
      _Base('Poleaxe', 'halberd', Stat.damage, 1.25, _m),
      _Base('Glaive', 'glaive', Stat.damage, 1.15, _m),
      // Spears
      _Base('Spear', 'spear', Stat.damage, 1.05, _m),
      _Base('Boar spear', 'spear', Stat.damage, 1.1, _m),
      _Base('Pike', 'spear', Stat.damage, 1.15, _m),
      // Battleaxes
      _Base('War axe', 'axe', Stat.damage, 1.1, _m),
      _Base('Bearded axe', 'axe', Stat.damage, 1.15, _m),
      _Base('Battleaxe', 'greataxe', Stat.damage, 1.25, _m),
      // Scimitars
      _Base('Scimitar', 'scimitar', Stat.damage, 1.05, _m),
      _Base('Falchion', 'falchion', Stat.damage, 1.0, _m),
      _Base('Shamshir', 'scimitar', Stat.damage, 1.1, _m),
      // Two-handed
      _Base('Greatsword', 'greatsword', Stat.damage, 1.3, _m),
      _Base('Claymore', 'greatsword', Stat.damage, 1.3, _m),
      _Base('Zweihänder', 'greatsword', Stat.damage, 1.35, _m),
      _Base('Great cleaver', 'cleaver', Stat.damage, 1.35, _m),
      // A duellist's blade: light, quick, and it finds the gaps.
      _Base('Rapier', 'rapier', Stat.damage, .95, _m),
      // Blunt
      _Base('Flanged mace', 'mace', Stat.damage, 1.1, _m),
      _Base('Morning star', 'morningstar', Stat.damage, 1.2, _m),
      _Base('Warhammer', 'hammer', Stat.damage, 1.25, _m),
      // Flails: a spiked ball on a chain, swung over a shield.
      _Base('Flail', 'flail', Stat.damage, 1.15, _m),
      _Base('Heavy flail', 'flail', Stat.damage, 1.2, _m),
    ],
    GearSlot.offhand: [
      _Base('Buckler', 'buckler', Stat.guard, .5),
      _Base('Heater shield', 'kite', Stat.guard, .75),
      _Base('Kite shield', 'kite', Stat.guard, 1.0),
      _Base('Tower shield', 'tower', Stat.guard, 1.3),
      _Base('Round shield', 'round', Stat.guard, .9),
      _Base('Spiked buckler', 'buckler', Stat.thorns, 1.0),
      // A second blade, for dual wielding daggers, short swords and scimitars.
      _Base('Off-hand dirk', 'dagger', Stat.damage, .3, _m),
      _Base('Parrying dagger', 'dagger', Stat.crit, .6, _m),
      _Base('Main-gauche', 'dagger', Stat.parry, .8, _m),
    ],
    GearSlot.helm: [
      _Base('Nasal helm', 'nasal', Stat.vigour, .8),
      _Base('Bascinet', 'greathelm', Stat.vigour, .9),
      _Base('Great helm', 'greathelm', Stat.vigour, 1.0),
      _Base('Sallet', 'sallet', Stat.vigour, 1.05),
      _Base('Armet', 'greathelm', Stat.vigour, 1.15),
    ],
    GearSlot.gloves: [
      _Base('Gauntlets', 'gauntlets', Stat.damage, .45, _m),
      _Base('Mailed gloves', 'gauntlets', Stat.guard, .7, _m),
      _Base('Brawler\'s gauntlets', 'gauntlets', Stat.crit, .6, _m),
    ],
    GearSlot.boots: [
      _Base('Sabatons', 'sabatons', Stat.guard, .7, _m),
      _Base('Greaves', 'sabatons', Stat.vigour, .7, _m),
      _Base('Riding boots', 'boots', Stat.vigour, .6),
    ],
  },
  HeroClass.mage: {
    GearSlot.weapon: [
      // Staves
      _Base('Staff', 'staff', Stat.damage, 1.0, _wd),
      _Base('Gnarled staff', 'staff', Stat.damage, 1.1, _wd),
      _Base('Battle staff', 'staff', Stat.damage, 1.15, _wd),
      _Base('Crystal staff', 'crystalstaff', Stat.damage, 1.3),
      // Wands
      _Base('Wand', 'wand', Stat.damage, .95, _wd),
      _Base('Bone wand', 'wand', Stat.damage, 1.05),
      _Base('Obsidian wand', 'wand', Stat.damage, 1.1),
      _Base('Runed sceptre', 'sceptre', Stat.damage, 1.2),
      // Scythes: a reaper's tool, for mages who deal in endings.
      _Base('Scythe', 'scythe', Stat.damage, 1.2, _wd),
      _Base('Grim scythe', 'scythe', Stat.damage, 1.3),
    ],
    GearSlot.offhand: [
      // Spellbooks
      _Base('Spell tome', 'tome', Stat.burn, .8),
      _Base('Grimoire', 'tome', Stat.burn, 1.0),
      _Base('Codex of storms', 'tome', Stat.frost, 1.0),
      _Base('Book of shadows', 'tome', Stat.poison, 1.05),
      // Orbs
      _Base('Arcane orb', 'orb', Stat.frost, .9),
      _Base("Seer's orb", 'orb', Stat.wisdom, 1.2),
      _Base('Storm orb', 'orb', Stat.frost, 1.1),
      _Base('Focus crystal', 'orb', Stat.burn, 1.1),
      // A second wand, for dual wielding with a wand or sceptre.
      _Base('Off-hand wand', 'wand', Stat.damage, .3, _wd),
      _Base('Ember wand', 'wand', Stat.burn, .8),
      _Base('Rime wand', 'wand', Stat.frost, .8),
    ],
    GearSlot.helm: [
      _Base('Pointed hat', 'wizardhat', Stat.vigour, .8),
      _Base("Wizard's cowl", 'cowl', Stat.vigour, .9),
      _Base('Silver circlet', 'circlet', Stat.vigour, 1.0),
      _Base('Starlit hat', 'wizardhat', Stat.vigour, 1.15),
      // Masks: an ornate face-shell instead of a hat.
      _Base('Moon mask', 'moonmask', Stat.wisdom, 1.0),
      _Base('Sun mask', 'sunmask', Stat.crit, .9),
      _Base('Porcelain mask', 'spiritmask', Stat.regen, 1.0),
    ],
    GearSlot.gloves: [
      _Base('Spellgloves', 'spellgloves', Stat.burn, .55),
      _Base('Silk gloves', 'spellgloves', Stat.wisdom, .7),
      _Base('Runed gloves', 'spellgloves', Stat.frost, .55),
    ],
    GearSlot.boots: [
      _Base('Slippers', 'slippers', Stat.regen, .7),
      _Base('Pilgrim\'s sandals', 'slippers', Stat.vigour, .6),
      _Base('Soft boots', 'boots', Stat.wisdom, .6),
    ],
  },
  HeroClass.ranger: {
    GearSlot.weapon: [
      // Shortbows
      _Base('Shortbow', 'bow', Stat.damage, .95, _wd),
      _Base('Hunting bow', 'bow', Stat.damage, 1.0, _wd),
      _Base('Recurve bow', 'bow', Stat.damage, 1.1, _wd),
      // Longbows
      _Base('Longbow', 'longbow', Stat.damage, 1.2, _wd),
      _Base('Warbow', 'longbow', Stat.damage, 1.25, _wd),
      // Chakrams
      _Base('Chakram', 'chakram', Stat.damage, 1.05, _m),
      _Base('Bladed ring', 'chakram', Stat.damage, 1.1, _m),
      // Throwing knives
      _Base('Throwing knives', 'throwingknives', Stat.damage, 1.0, _m),
      _Base('Throwing daggers', 'throwingknives', Stat.damage, 1.05, _m),
      // Tomahawks
      _Base('Tomahawk', 'tomahawk', Stat.damage, 1.1, _m),
      _Base('Throwing axe', 'tomahawk', Stat.damage, 1.15, _m),
      // Crossbows
      _Base('Light crossbow', 'crossbow', Stat.damage, 1.1, _m),
      _Base('Heavy crossbow', 'crossbow', Stat.damage, 1.3, _m),
      _Base('Arbalest', 'crossbow', Stat.damage, 1.35, _m),
      // Hand crossbows: one-handed, so another can go in the off hand.
      _Base('Hand crossbow', 'handcrossbow', Stat.damage, .95, _m),
      _Base('Repeating hand crossbow', 'handcrossbow', Stat.damage, 1.05, _m),
      // Cannons
      _Base('Hand cannon', 'handcannon', Stat.damage, 1.3, _m),
      _Base('Blunderbuss', 'handcannon', Stat.damage, 1.35, _m),
      _Base('Bombard', 'cannon', Stat.damage, 1.45, _m),
    ],
    GearSlot.offhand: [
      _Base('Quiver', 'quiver', Stat.damage, .5),
      _Base('Long quiver', 'quiver', Stat.damage, .6),
      _Base('Hunter\'s quiver', 'quiver', Stat.crit, .8),
      _Base('Barbed-arrow quiver', 'quiver', Stat.crit, 1.0),
      // For crossbows: a second, smaller crossbow in the other hand.
      _Base('Hand crossbow', 'handcrossbow', Stat.damage, .5, _m),
      _Base('Pistol crossbow', 'handcrossbow', Stat.damage, .6, _m),
      _Base('Repeating hand crossbow', 'handcrossbow', Stat.crit, .9, _m),
      // For chakrams, knives and hand cannons.
      _Base('Parrying dagger', 'dagger', Stat.crit, .8),
      _Base('Main-gauche', 'dagger', Stat.guard, .8),
    ],
    GearSlot.helm: [
      _Base("Scout's cap", 'scoutcap', Stat.vigour, .8),
      _Base("Ranger's hood", 'rangerhood', Stat.vigour, .9),
      _Base('Leaf-crowned hood', 'rangerhood', Stat.vigour, 1.0),
      _Base('Woodland mask', 'mask', Stat.vigour, 1.1),
    ],
    GearSlot.gloves: [
      _Base('Bracers', 'bracers', Stat.crit, .6),
      _Base('Archer\'s gloves', 'bracers', Stat.damage, .45),
      _Base('Hide gloves', 'bracers', Stat.dodge, .6),
    ],
    GearSlot.boots: [
      _Base('Soft boots', 'boots', Stat.dodge, .6),
      _Base('Tracker\'s boots', 'boots', Stat.fortune, .7),
      _Base('Woodland boots', 'boots', Stat.vigour, .6),
    ],
  },
};

const _rings = <_Base>[
  _Base('Band', 'ring', Stat.damage, .5),
  _Base('Signet', 'ring', Stat.crit, .7),
  _Base('Ember ring', 'ring', Stat.burn, .6),
  _Base('Frost ring', 'ring', Stat.frost, .6),
  _Base('Venom ring', 'ring', Stat.poison, .6),
  _Base('Bloodstone ring', 'ring', Stat.lifesteal, .7),
  _Base('Lucky ring', 'ring', Stat.fortune, .8),
  _Base('Sage\'s ring', 'ring', Stat.wisdom, .8),
];

const _trinkets = <_Base>[
  _Base('Amulet', 'amulet', Stat.vigour, .8),
  _Base('Charm', 'charm', Stat.fortune, 1.0),
  _Base('Brooch', 'brooch', Stat.regen, 1.0),
  _Base('Talisman', 'talisman', Stat.wisdom, 1.0),
  _Base('Pendant', 'amulet', Stat.lifesteal, .8),
];

// ---------------------------------------------------------------------------------------------
// Enchantments: each adds a stat and, for the first two, a word to the name.

class _Affix {
  const _Affix(this.stat, this.prefix, this.suffix, this.slots);
  final Stat stat;
  final String prefix, suffix;
  final Set<GearSlot> slots;
}

const _w = GearSlot.weapon, _o = GearSlot.offhand, _h = GearSlot.helm, _t = GearSlot.trinket, _gl = GearSlot.gloves, _bt = GearSlot.boots, _rg = GearSlot.ring;

const _affixes = <_Affix>[
  _Affix(Stat.damage, 'Keen', 'of Might', {_w, _t, _o, _gl, _rg}),
  _Affix(Stat.poison, 'Venomous', 'of Venom', {_w, _o, _t, _rg, _gl}),
  _Affix(Stat.burn, 'Searing', 'of Embers', {_w, _o, _t, _rg, _gl}),
  _Affix(Stat.frost, 'Frostbitten', 'of Winter', {_w, _o, _t, _rg, _gl}),
  _Affix(Stat.smite, 'Hallowed', 'of Dawn', {_w, _o, _rg}),
  _Affix(Stat.crit, 'Deadly', 'of Precision', {_w, _h, _t, _gl, _rg}),
  _Affix(Stat.lifesteal, 'Thirsting', 'of Renewal', {_w, _t, _gl, _rg}),
  _Affix(Stat.guard, 'Stalwart', 'of Warding', {_o, _h, _t, _bt}),
  _Affix(Stat.vigour, 'Hale', 'of Vigour', {_h, _o, _t, _bt}),
  _Affix(Stat.regen, 'Soothing', 'of the Hearth', {_h, _t, _bt, _rg}),
  _Affix(Stat.thorns, 'Thorned', 'of Brambles', {_o, _h, _bt}),
  _Affix(Stat.fortune, 'Gilded', 'of Fortune', {_h, _t, _w, _rg, _bt}),
  _Affix(Stat.wisdom, 'Sage', 'of Insight', {_h, _t, _rg}),
  _Affix(Stat.dragonkin, 'Wyrmbound', 'of the Wyrm', {_w, _t, _rg}),
  _Affix(Stat.dodge, 'Nimble', 'of the Fox', {_bt, _gl}),
  _Affix(Stat.parry, 'Duelling', 'of the Duel', {_gl, _rg}),
  _Affix(Stat.block, 'Steadfast', 'of the Wall', {_bt}),
];

/// What one point of each stat is worth, for comparing items (see GearItem.score).
double statWeight(Stat s) => switch (s) {
  Stat.damage || Stat.poison || Stat.burn || Stat.frost => 3.0,
  Stat.smite => 1.2,
  Stat.thorns || Stat.regen => .5,
  Stat.crit || Stat.guard => 1.5,
  Stat.lifesteal => 2.0,
  Stat.vigour => .4,
  Stat.fortune || Stat.wisdom => .3,
  Stat.dragonkin => 2.0,
  Stat.dodge || Stat.parry || Stat.block => 1.2,
  Stat.leech => 2.5,
  Stat.wyrmbane => .6,
};

/// The score a random epic weapon of [c]'s comes out at, on average, at [level] (its base stat
/// with material and rarity, and three enchantments). Signature weapons are tuned against it.
double randomEpicWeapon(HeroClass c, int level) {
  const power = 1.75; // Rarity.epic.power
  final bases = _bases[c]![GearSlot.weapon]!;
  final made = 1 + _band(level) * .07;
  var primary = 0.0;
  for (final b in bases) {
    primary += statWeight(b.primary) * _base(b.primary, level) * b.scale * power * (b.make == _Make.none ? 1 : made);
  }
  primary /= bases.length;
  final pool = _affixes.where((a) => a.slots.contains(GearSlot.weapon)).toList();
  var affix = 0.0;
  for (final a in pool) {
    affix += statWeight(a.stat) * _base(a.stat, level) * .8 * power;
  }
  return primary + 3 * affix / pool.length;
}

/// How far above a random epic weapon each kind of signature weapon sits: farmed epics a little
/// above (they're farmed for), legendaries well above (and they carry a special), relics above that.
const farmedEdge = 1.05, legendEdge = 1.2, relicEdge = 1.35;

/// The typical amount of a stat at a level (before rarity and luck).
double statRoll(Stat s, int level) => _base(s, level);

/// [g] reworked at the forge up to [level]: every stat grows as if it had dropped there (runes and
/// specials stay as they are).
GearItem tempered(GearItem g, int level) => GearItem(
  id: g.id,
  name: g.name,
  slot: g.slot,
  art: g.art,
  rarity: g.rarity,
  level: level,
  heroClass: g.heroClass,
  lore: g.lore,
  tint: g.tint,
  special: g.special,
  enchant: g.enchant,
  gearSet: g.gearSet,
  value: (g.value * (3 + level * 1.2) / (3 + g.level * 1.2)).round(),
  stats: {for (final e in g.stats.entries) e.key: math.max(e.value, (e.value * _base(e.key, level) / _base(e.key, g.level)).round())},
);

/// How much of a stat an enchantment or base grants at a level.
int _roll(Stat s, int level, double mult, math.Random r) {
  final jitter = .85 + r.nextDouble() * .3;
  return math.max(1, (_base(s, level) * mult * jitter).round());
}

double _base(Stat s, int level) {
  final v = switch (s) {
    Stat.damage => 1.5 + level * .7,
    Stat.poison || Stat.burn || Stat.frost => 1.5 + level * .45,
    Stat.smite => 3 + level * .8,
    Stat.crit => 4 + level * .3,
    Stat.lifesteal => 1 + level * .25,
    Stat.guard => 2.5 + level * .15,
    Stat.vigour => 6 + level * 2.0,
    Stat.regen => 6 + level * 2.0,
    Stat.thorns => 3 + level * 1.0,
    Stat.fortune || Stat.wisdom => 8 + level * 1.0,
    Stat.dragonkin => 1 + level * .15,
    Stat.dodge || Stat.parry || Stat.block => 4 + level * .2,
    Stat.leech => 6 + level * .15,
    Stat.wyrmbane => 5.0,
  };
  return v.toDouble();
}

// ---------------------------------------------------------------------------------------------
// Legendaries: named, fixed effects, scaled by level.

class _Legend {
  const _Legend(this.name, this.slot, this.art, this.heroClass, this.stats, this.lore, {this.special});
  final String name, art, lore;

  /// A weapon's own special attack (otherwise one is picked for it by name).
  final String? special;
  final GearSlot slot;
  final HeroClass? heroClass;
  final Map<Stat, double> stats; // multipliers on the normal roll
}

const _legends = <_Legend>[
  _Legend('Gauntlets of the Berserker', _gl, 'gauntlets', HeroClass.knight, {Stat.damage: 1.8, Stat.crit: 1.6}, 'The knuckles are worn smooth, and not from praying.'),
  _Legend('Spellweaver\'s Gloves', _gl, 'spellgloves', HeroClass.mage, {Stat.burn: 1.6, Stat.frost: 1.4, Stat.wisdom: 1.6}, 'Every finger is stitched with a different word.'),
  _Legend('Fletcher\'s Grips', _gl, 'bracers', HeroClass.ranger, {Stat.crit: 2.0, Stat.damage: 1.2, Stat.dodge: 1.0}, 'They have never let an arrow fly crooked.'),
  _Legend('Windwalker Boots', _bt, 'boots', null, {Stat.dodge: 2.4, Stat.vigour: 1.2, Stat.fortune: 1.0}, 'Footprints in the snow, then none at all.'),
  _Legend('Ironshod Sabatons', _bt, 'sabatons', HeroClass.knight, {Stat.guard: 2.0, Stat.block: 1.6, Stat.thorns: 1.5}, 'Each step rings like a bell in a quiet chapel.'),
  _Legend('Treads of the Hearth', _bt, 'slippers', null, {Stat.regen: 2.2, Stat.vigour: 1.5}, 'Warm feet, warm heart, as Gran always said.'),
  _Legend('Ring of the Phoenix', _rg, 'ring', null, {Stat.burn: 2.0, Stat.regen: 1.6}, 'It was ash once. It will be again, and then gold.'),
  _Legend('Band of the Duellist', _rg, 'ring', null, {Stat.parry: 2.0, Stat.crit: 1.5}, 'Worn on the sword hand, where it catches the light.'),
  _Legend('Bloodstone Signet', _rg, 'ring', null, {Stat.lifesteal: 2.2, Stat.damage: 1.0}, 'Its stone darkens a little after every fight.'),
  // The knight's legendary weapons: each has its own special attack.
  _Legend('Oathkeeper', _w, 'longsword', HeroClass.knight, {Stat.damage: 1.6, Stat.lifesteal: 1.5, Stat.guard: 1.0}, 'It has never broken a promise, nor a shield.', special: 'cleave'),
  _Legend('Dawnbreaker', _w, 'mace', HeroClass.knight, {Stat.damage: 1.3, Stat.smite: 2.5, Stat.burn: 1.0}, 'The dead flinch at its shadow. Raise it high, and the sky answers.', special: 'stormcall'),
  _Legend('Grimtooth', _w, 'axe', HeroClass.knight, {Stat.damage: 1.9, Stat.crit: 1.4}, 'Notched from a hundred quarrels. Something below the earth likes the sound it makes.', special: 'hellgate'),
  _Legend('Gambler\'s Edge', _w, 'rapier', HeroClass.knight, {Stat.damage: 1.5, Stat.crit: 1.8}, 'Won in a game of bones from a man who swore he never lost. The dice came with it.', special: 'fatesroll'),
  _Legend('Gravewarden', _w, 'halberd', HeroClass.knight, {Stat.damage: 1.7, Stat.smite: 1.6}, 'Carried by the last captain of the barrow guard. His men still answer when it calls.', special: 'deadcharge'),
  _Legend('Legion\'s Due', _w, 'greatsword', HeroClass.knight, {Stat.damage: 1.8, Stat.guard: 1.0}, 'Forged on a battlefield from the swords of the fallen, who never quite left it.', special: 'legion'),
  _Legend('Wyrmcaller', _w, 'spear', HeroClass.knight, {Stat.damage: 1.5, Stat.burn: 1.6}, 'Its head is a dragon\'s tooth. Hold it up, and somewhere in the ash, something big turns its head.', special: 'wyrmcall'),
  _Legend('Moonfang', _w, 'scimitar', HeroClass.knight, {Stat.damage: 1.6, Stat.dodge: 1.2, Stat.crit: 1.0}, 'Silver, curved like a new moon. Wolves no one can see run beside whoever holds it.', special: 'moonpack'),
  _Legend('The Bat-King\'s Flail', _w, 'flail', HeroClass.knight, {Stat.damage: 1.6, Stat.leech: 1.0}, 'Taken from the Bat Tower. Swing it, and the dark itself takes wing.', special: 'nightswarm'),
  _Legend("The Warden's Bulwark", _o, 'tower', HeroClass.knight, {Stat.guard: 2.2, Stat.thorns: 2.0, Stat.vigour: 1.0}, 'Carried by the last keeper of the Cindervale gate.'),
  _Legend('Crown of the Last King', _h, 'sallet', HeroClass.knight, {Stat.vigour: 1.8, Stat.crit: 1.5, Stat.fortune: 1.0}, 'The last king before the Great Burning wore it. He would want it worn.'),
  _Legend('Hearthfire Staff', _w, 'crystalstaff', HeroClass.mage, {Stat.damage: 1.3, Stat.burn: 2.4, Stat.dragonkin: 1.5}, 'Warm to the touch, even in winter.'),
  _Legend('Rimefrost Sceptre', _w, 'sceptre', HeroClass.mage, {Stat.damage: 1.3, Stat.frost: 2.4, Stat.guard: 1.0}, 'Frost creeps along the floor wherever it rests.'),
  _Legend('The Verdant Wand', _w, 'wand', HeroClass.mage, {Stat.damage: 1.2, Stat.poison: 2.2, Stat.lifesteal: 1.5}, 'A living branch that refuses to wither.'),
  _Legend('Tome of Endless Pages', _o, 'tome', HeroClass.mage, {Stat.burn: 1.5, Stat.wisdom: 3.0}, 'No one has ever reached the last page.'),
  _Legend('Circlet of Quiet Stars', _h, 'circlet', HeroClass.mage, {Stat.vigour: 1.5, Stat.regen: 2.5, Stat.guard: 1.0}, 'Sleep beneath it and wake renewed.'),
  _Legend('Thornwhisper', _w, 'longbow', HeroClass.ranger, {Stat.damage: 1.4, Stat.poison: 2.0, Stat.crit: 1.5}, 'Its arrows sing a single, venomous note.'),
  _Legend('Galeforce', _w, 'bow', HeroClass.ranger, {Stat.damage: 1.7, Stat.crit: 2.5}, 'Strung with a thread of the north wind.'),
  _Legend('Stinger', _w, 'crossbow', HeroClass.ranger, {Stat.damage: 1.3, Stat.poison: 2.8}, 'Small bolts. Very bad news.'),
  _Legend('Stormfeather Quiver', _o, 'quiver', HeroClass.ranger, {Stat.damage: 1.6, Stat.crit: 1.5}, 'Its fletchings crackle. One arrow in three flies home again.'),
  _Legend('Quiver of the Endless Hunt', _o, 'quiver', HeroClass.ranger, {Stat.damage: 1.4, Stat.poison: 1.4, Stat.fortune: 1.0}, 'However many you draw, it is never quite empty.'),
  _Legend('Quiver of the Hollow Moon', _o, 'quiver', HeroClass.ranger, {Stat.smite: 2.5, Stat.frost: 1.6}, 'Its arrows glow pale against the dark.'),
  _Legend('Mask of the Silent Wood', _h, 'mask', HeroClass.ranger, {Stat.vigour: 1.2, Stat.crit: 2.0, Stat.fortune: 1.5}, 'The forest falls quiet when it is worn.'),
  _Legend('Amulet of the Hearth', _t, 'amulet', null, {Stat.regen: 2.5, Stat.vigour: 1.5}, 'Smells faintly of woodsmoke and bread.'),
  _Legend("Gambler's Coin", _t, 'charm', null, {Stat.fortune: 3.5, Stat.crit: 1.5}, 'Heads, you win. Tails, you also win.'),
  _Legend("Wyrm's Eye Pendant", _t, 'amulet', null, {Stat.dragonkin: 3.0, Stat.burn: 1.2}, 'Your dragon purrs when you wear it.'),
  _Legend('Locket of Second Wind', _t, 'brooch', null, {Stat.lifesteal: 2.0, Stat.regen: 1.8}, 'Inside, a tiny portrait of someone who believed in you.'),
  _Legend('Ring of the Three Embers', _rg, 'ring', null, {Stat.poison: 1.0, Stat.burn: 1.0, Stat.frost: 1.0}, 'Three stones: moss, ember and rime.'),
];

/// All named legendaries, for the design doc and the in-game codex.
List<String> get legendaryNames => [for (final l in _legends) l.name];

// ---------------------------------------------------------------------------------------------

class LootTable {
  LootTable([math.Random? random]) : _r = random ?? math.Random();
  final math.Random _r;

  Rarity _rarity(bool boss, [List<int>? odds]) {
    // Per 1000 drops from a regular foe: 550 common, 300 uncommon, 120 rare, 27 epic, 3 legendary.
    // Legendaries should be a moment, not a Tuesday.
    final weights = odds ?? (boss ? const [0, 100, 650, 230, 20] : const [550, 300, 120, 27, 3]);
    var pick = _r.nextInt(weights.reduce((a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      if (pick < weights[i]) return Rarity.values[i];
      pick -= weights[i];
    }
    return Rarity.common;
  }

  GearSlot _slot() {
    final p = _r.nextInt(100);
    return p < 28 ? _w : p < 46 ? _o : p < 60 ? _h : p < 71 ? _gl : p < 82 ? _bt : p < 91 ? _rg : _t;
  }

  T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  String _id() => 'g${DateTime.now().microsecondsSinceEpoch}${_r.nextInt(1 << 20)}';

  int _value(int level, Rarity rarity, GearSlot slot) => ((3 + level * 1.2) * rarity.valueMult * (slot == _w ? 1.2 : 1.0)).round();

  /// A wyrmscale piece from a slain dragon of [tier]: a weapon, helm, armour, gloves or boots in
  /// the dragon's colour, each striking dragons harder. Higher tiers are rarer; now and then a
  /// piece comes enchanted, and enchanted or legendary pieces glow.
  GearItem wyrmDrop(HeroClass heroClass, int level, WyrmTier tier, {GearSlot? only}) {
    const slots = [GearSlot.weapon, GearSlot.offhand, GearSlot.helm, GearSlot.armour, GearSlot.gloves, GearSlot.boots];
    final slot = only ?? slots[_r.nextInt(slots.length)];
    final t = tier.tier;
    final rarity = switch (t) {
      1 => Rarity.rare,
      2 => _r.nextDouble() < .6 ? Rarity.rare : Rarity.epic,
      3 => Rarity.epic,
      4 => _r.nextDouble() < .7 ? Rarity.epic : Rarity.legendary,
      _ => Rarity.legendary,
    };
    final bane = switch (slot) {
      GearSlot.weapon => 4 + 2 * t,
      _ => 2 + t,
    };
    final (name, art, stats, lore) = switch (slot) {
      GearSlot.weapon => switch (heroClass) {
        HeroClass.knight => ('${tier.name} Wyrmbane greatsword', 'wyrmblade', <Stat, double>{Stat.damage: 1.3 + .08 * t, Stat.crit: .8}, 'Its edge is a row of dragon\'s teeth, set in steel.'),
        HeroClass.mage => ('${tier.name} wyrmspine staff', 'dragonstaff', <Stat, double>{Stat.damage: 1.2 + .08 * t, Stat.burn: 1.2}, 'A dragon\'s spine, still warm along its length.'),
        HeroClass.ranger => ('${tier.name} wyrmhorn bow', 'longbow', <Stat, double>{Stat.damage: 1.25 + .08 * t, Stat.crit: 1.0}, 'Bent from a dragon\'s horn; it never loses its pull.'),
      },
      GearSlot.offhand => switch (heroClass) {
        HeroClass.knight => ('${tier.name} dragonslayer shield', 'dragonshield', <Stat, double>{Stat.guard: 1.0, Stat.block: .8}, 'A dragon\'s head run through, on a field of its own scales. Fire slides off it.'),
        HeroClass.mage => ('${tier.name} wyrm\'s eye', 'orb', <Stat, double>{Stat.burn: 1.0, Stat.wisdom: .8}, 'A dragon\'s eye, set in glass. It still blinks now and then.'),
        HeroClass.ranger => ('${tier.name} wyrmtooth quiver', 'quiver', <Stat, double>{Stat.crit: .9, Stat.damage: .4}, 'Every arrowhead is a dragon\'s tooth.'),
      },
      GearSlot.helm => (
        heroClass == HeroClass.knight ? '${tier.name} wyrmhelm' : '${tier.name} wyrmhorn circlet',
        heroClass == HeroClass.knight ? 'wyrmhelm' : 'wyrmcirclet',
        <Stat, double>{Stat.guard: .9, Stat.vigour: .8},
        'Two horns swept back, like the dragon it was taken from.',
      ),
      GearSlot.gloves => (
        '${tier.name} wyrmscale ${heroClass == HeroClass.knight ? 'gauntlets' : (heroClass == HeroClass.ranger ? 'bracers' : 'gloves')}',
        switch (heroClass) {
          HeroClass.knight => 'gauntlets',
          HeroClass.mage => 'spellgloves',
          HeroClass.ranger => 'bracers',
        },
        <Stat, double>{Stat.damage: .6, Stat.crit: .6},
        'Scale over scale, each one a shield the size of a coin.',
      ),
      GearSlot.boots => (
        '${tier.name} wyrmscale ${heroClass == HeroClass.knight ? 'sabatons' : 'boots'}',
        heroClass == HeroClass.knight ? 'sabatons' : 'boots',
        <Stat, double>{Stat.vigour: .8, Stat.dodge: .7},
        'They leave no prints, only scorch marks.',
      ),
      _ => (wyrmArmourName(heroClass, tier), wyrmArmourId(heroClass, t), <Stat, double>{}, 'Damage taken −${((.30 + .04 * (t - 1)) * 100).round()}%, +${3 + 2 * t}% damage to dragons.'),
    };
    final enchant = slot != GearSlot.armour && _r.nextDouble() < .25 ? rollEnchant(slot == GearSlot.weapon ? EnchantSlot.weapon : EnchantSlot.armour, level, _r) : null;
    return GearItem(
      id: _id(),
      name: name,
      slot: slot,
      art: art,
      rarity: rarity,
      level: level,
      heroClass: heroClass,
      lore: lore,
      tint: tier.argb,
      enchant: enchant,
      gearSet: wyrmSet,
      value: _value(level, rarity, slot) * 2,
      stats: {
        for (final e in stats.entries) e.key: _roll(e.key, level, e.value * (rarity == Rarity.legendary ? 1.25 : (rarity == Rarity.epic ? 1.1 : 1)), _r),
        if (slot != GearSlot.armour) Stat.wyrmbane: bane,
      },
    );
  }

  /// Dragonbone jewellery of [tier]: a ring (crit and damage) or a fang amulet (vigour and guard),
  /// carved from a dragon's bones with a gem of its colour, and striking dragons harder.
  GearItem dragonboneJewel(int level, WyrmTier tier, {required bool ring, Rarity? rarity}) {
    final t = tier.tier;
    final r = rarity ??
        switch (t) {
          1 => Rarity.rare,
          2 => _r.nextDouble() < .6 ? Rarity.rare : Rarity.epic,
          3 => Rarity.epic,
          4 => _r.nextDouble() < .7 ? Rarity.epic : Rarity.legendary,
          _ => Rarity.legendary,
        };
    final boost = r == Rarity.legendary ? 1.25 : (r == Rarity.epic ? 1.1 : 1.0);
    final stats = ring ? <Stat, double>{Stat.crit: .8, Stat.damage: .5} : <Stat, double>{Stat.vigour: 1.0, Stat.guard: .6};
    return GearItem(
      id: _id(),
      name: ring ? '${tier.name} dragonbone ring' : '${tier.name} fang amulet',
      slot: ring ? GearSlot.ring : GearSlot.trinket,
      art: ring ? 'dragonbonering' : 'fangamulet',
      rarity: r,
      level: level,
      lore: ring ? 'Carved from a dragon\'s knucklebone; the gem is the colour of its scales.' : 'A dragon\'s fang on a cord of its own sinew.',
      tint: tier.argb,
      gearSet: wyrmSet,
      value: _value(level, r, ring ? GearSlot.ring : GearSlot.trinket) * 2,
      stats: {
        for (final e in stats.entries) e.key: _roll(e.key, level, e.value * boost, _r),
        Stat.wyrmbane: 2 + t,
      },
    );
  }

  /// Orks' prize for each class: an Ork club (knight), Ork bow (ranger) or Ork staff (mage). Epic.
  GearItem orkDrop(HeroClass heroClass, int level) {
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Ork club', 'orkclub', <Stat, double>{Stat.damage: 1.8, Stat.crit: 1.2}, 'Iron-banded, nail-studded, and never once washed.'),
      HeroClass.ranger => ('Ork bow', 'orkbow', <Stat, double>{Stat.damage: 1.5, Stat.crit: 1.4}, 'Pulling it takes the arms of an ork. Or yours, now.'),
      HeroClass.mage => ('Ork staff', 'orkstaff', <Stat, double>{Stat.damage: 1.4, Stat.poison: 1.8}, 'A shaman\'s totem. The skull still mutters.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge),
    );
  }

  /// The Kraken's hoard. [poseidon]: Poseidon's own weapon for your class (legendary): a trident
  /// for knights and mages (it calls a Tidal Wave or the Kraken), a bow for rangers. Otherwise a
  /// sea-forged prize: the Fisherman's Hook (knight), the Pearl of the Deep (mage off-hand) or a
  /// Harpoon crossbow (ranger).
  GearItem seaDrop(HeroClass heroClass, int level, {required bool poseidon}) {
    const sea = 0xFF4FB8C8, brass = 0xFFC8B070;
    if (poseidon) {
      final (name, art, tint, special, stats, lore) = switch (heroClass) {
        HeroClass.knight => ('Poseidon\'s Trident', 'trident', sea, 'poseidon', <Stat, double>{Stat.damage: 1.6, Stat.frost: 1.6, Stat.crit: 1.0}, 'Three prongs of sea-gold. The tide turns when you lift it.'),
        HeroClass.mage => ('Poseidon\'s Trident', 'trident', sea, 'poseidon', <Stat, double>{Stat.damage: 1.5, Stat.frost: 1.8, Stat.wisdom: 1.0}, 'Three prongs of sea-gold. The tide turns when you lift it.'),
        HeroClass.ranger => ('Poseidon\'s Bow', 'longbow', sea, 'tidevolley', <Stat, double>{Stat.damage: 1.5, Stat.frost: 1.6, Stat.crit: 1.2}, 'Strung with a sea-serpent\'s whisker. Its arrows come back wet.'),
      };
      return GearItem(
        id: _id(),
        name: name,
        slot: GearSlot.weapon,
        art: art,
        tint: tint,
        rarity: Rarity.legendary,
        level: level,
        heroClass: heroClass,
        lore: lore,
        special: special,
        value: _value(level, Rarity.legendary, GearSlot.weapon) * 2,
        stats: _signature(stats, level, heroClass),
      );
    }
    return switch (heroClass) {
      HeroClass.knight => GearItem(
        id: _id(),
        name: 'Fisherman\'s Hook',
        slot: GearSlot.weapon,
        art: 'hook',
        tint: brass,
        rarity: Rarity.epic,
        level: level,
        heroClass: heroClass,
        lore: 'It has landed bigger things than you. Recently.',
        special: 'reelin',
        value: _value(level, Rarity.epic, GearSlot.weapon),
        stats: _tuned({Stat.damage: 1.4, Stat.crit: 1.2, Stat.fortune: 1.2}, level, heroClass, farmedEdge),
      ),
      HeroClass.mage => GearItem(
        id: _id(),
        name: 'Pearl of the Deep',
        slot: GearSlot.offhand,
        art: 'orb',
        tint: sea,
        rarity: Rarity.legendary,
        level: level,
        heroClass: heroClass,
        lore: 'Hold it to your ear and you hear the Kraken breathing.',
        value: _value(level, Rarity.legendary, GearSlot.offhand),
        stats: {Stat.frost: _roll(Stat.frost, level, 2.2, _r), Stat.wisdom: _roll(Stat.wisdom, level, 2.0, _r), Stat.regen: _roll(Stat.regen, level, 1.2, _r)},
      ),
      HeroClass.ranger => GearItem(
        id: _id(),
        name: 'Harpoon crossbow',
        slot: GearSlot.weapon,
        art: 'crossbow',
        tint: sea,
        rarity: Rarity.epic,
        level: level,
        heroClass: heroClass,
        lore: 'Made for whales. Works on anything.',
        special: 'reelin',
        value: _value(level, Rarity.epic, GearSlot.weapon),
        stats: _tuned({Stat.damage: 1.7, Stat.crit: 1.3}, level, heroClass, farmedEdge),
      ),
    };
  }

  /// A cape for [heroClass]: epic (now and then legendary, with a stronger stat).
  GearItem capeDrop(HeroClass heroClass, int level) {
    final pool = capes.where((c) => c.heroClass == heroClass).toList(), cape = _pick(pool);
    final legendary = _r.nextDouble() < .1, rarity = legendary ? Rarity.legendary : Rarity.epic;
    return GearItem(
      id: _id(),
      name: legendary ? 'Exalted ${cape.name[0].toLowerCase()}${cape.name.substring(1)}' : cape.name,
      slot: GearSlot.cape,
      art: 'cape',
      tint: cape.argb,
      rarity: rarity,
      level: level,
      heroClass: heroClass,
      lore: cape.lore,
      special: cape.id,
      value: _value(level, rarity, GearSlot.cape),
      stats: {cape.stat: _roll(cape.stat, level, legendary ? 1.2 : .8, _r)},
    );
  }

  /// Gear earned by a deed (see challenges.dart): never dropped, never sold by the merchant.
  /// The undead's prize: a bone weapon or bone armour for your class. Epic. Bone weapons carry
  /// holy fire (it burns the dead) and an Ossuary staff makes your raised dead fight longer.
  GearItem boneDrop(HeroClass heroClass, int level, {required bool armour}) {
    const bone = 0xFFE8DCC0;
    if (armour) {
      final (id, name) = switch (heroClass) {
        HeroClass.knight => ('bonemail', 'Bone-plate armour'),
        HeroClass.mage => ('bonerobe', 'Bonewoven robe'),
        HeroClass.ranger => ('bonescale', 'Bone-scale jerkin'),
      };
      return GearItem(
        id: _id(),
        name: name,
        slot: GearSlot.armour,
        art: id,
        rarity: Rarity.epic,
        level: level,
        heroClass: heroClass,
        lore: 'Ribs for plates, knucklebones for rivets. The dead hesitate to strike their own.',
        value: _value(level, Rarity.epic, GearSlot.armour),
        stats: const {},
      );
    }
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Bone cleaver', 'axe', <Stat, double>{Stat.damage: 1.6, Stat.smite: 1.5, Stat.crit: 1.0}, 'A giant\'s jawbone, sharpened. It hums near graves.'),
      HeroClass.ranger => ('Bone bow', 'longbow', <Stat, double>{Stat.damage: 1.5, Stat.smite: 1.4, Stat.crit: 1.0}, 'Strung with sinew, nocked with ribs. It never misses the dead.'),
      HeroClass.mage => ('Ossuary staff', 'staff', <Stat, double>{Stat.damage: 1.4, Stat.smite: 1.5, Stat.wisdom: 1.0}, 'A spine of many spines. The dead you raise answer it gladly.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      tint: bone,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge),
    );
  }

  /// Ents' prize for each class: a Heartwood maul (knight), Heartwood bow (ranger) or Living staff
  /// (mage). Epic, and they mend you a little after every fight.
  GearItem entDrop(HeroClass heroClass, int level) {
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Heartwood maul', 'heartmaul', <Stat, double>{Stat.damage: 1.6, Stat.regen: 1.4, Stat.thorns: 1.2}, 'Cut from a living ent, with its blessing. Mostly.'),
      HeroClass.ranger => ('Heartwood bow', 'heartbow', <Stat, double>{Stat.damage: 1.5, Stat.regen: 1.3, Stat.poison: 1.0}, 'It still puts out leaves every spring.'),
      HeroClass.mage => ('Living staff', 'livingstaff', <Stat, double>{Stat.damage: 1.4, Stat.regen: 1.6, Stat.poison: 1.2}, 'Roots twitch toward water when you hold it.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge),
    );
  }

  /// Grandmother Bramblecrown's acorn: a legendary trinket for any class.
  GearItem acornDrop(int level) => GearItem(
    id: _id(),
    name: 'Bramblecrown\'s Acorn',
    slot: GearSlot.trinket,
    art: 'acorn',
    rarity: Rarity.legendary,
    level: level,
    lore: 'Plant it and a forest will remember your name.',
    value: _value(level, Rarity.legendary, GearSlot.trinket),
    stats: {Stat.regen: _roll(Stat.regen, level, 2.4, _r), Stat.vigour: _roll(Stat.vigour, level, 2.0, _r), Stat.thorns: _roll(Stat.thorns, level, 1.6, _r)},
  );

  /// A quest giver's exclusive weapon for [heroClass]: legendary, with a special attack. Only
  /// quest givers hand these out.
  GearItem questWeapon(String giver, HeroClass heroClass, int level) {
    const gold = 0xFFE8C060, iron = 0xFF8A8E94, fate = 0xFF8A5AC0;
    final (name, art, tint, special, stats, lore) = switch ((giver, heroClass)) {
      ('king', HeroClass.knight) => ('Crownsplitter', 'greatsword', gold, 'verdict', {Stat.damage: 1.5, Stat.smite: 1.5}, 'Forged for the King\'s champion. Now that\'s you.'),
      ('king', HeroClass.ranger) => ('Sovereign\'s Longbow', 'longbow', gold, 'crownvolley', {Stat.damage: 1.4, Stat.crit: 1.4}, 'Its string was spun from the royal standard.'),
      ('king', _) => ('Sceptre of the Realm', 'sceptre', gold, 'edict', {Stat.damage: 1.4, Stat.smite: 1.6}, 'Whoever holds it speaks with the King\'s voice.'),
      ('villager', HeroClass.knight) => ('Millbrook Pitchfork', 'spear', iron, 'harvest', {Stat.damage: 1.3, Stat.regen: 1.4}, 'Three prongs, one purpose. The village is grateful.'),
      ('villager', HeroClass.ranger) => ('Poacher\'s Shortbow', 'bow', null, 'luckyshot', {Stat.damage: 1.3, Stat.fortune: 1.5}, 'Nobody asks where it came from. Nobody tells.'),
      ('villager', _) => ('Hedge-Witch\'s Wand', 'wand', null, 'hearth', {Stat.damage: 1.3, Stat.regen: 1.6}, 'Smells faintly of thyme and woodsmoke.'),
      ('seer', HeroClass.knight) => ('Fateblade', 'longsword', fate, 'fate', {Stat.damage: 1.5, Stat.crit: 1.6}, 'The Seer saw you holding it, so here it is.'),
      ('seer', HeroClass.ranger) => ('Omen Bow', 'longbow', fate, 'omen', {Stat.damage: 1.4, Stat.crit: 1.6}, 'Every arrow already knows where it will land.'),
      ('seer', _) => ('Eye of Ages', 'crystalstaff', fate, 'glimpse', {Stat.damage: 1.4, Stat.wisdom: 1.8}, 'Look into the crystal. Something looks back.'),
      ('mage', HeroClass.knight) => ('Stormbrand', 'longsword', 0xFFB8D8F0, 'thunder', {Stat.damage: 1.4, Stat.frost: 1.6}, 'It hums before a storm, and during one, and after.'),
      ('mage', HeroClass.ranger) => ('Emberstring', 'longbow', null, 'firerain', {Stat.damage: 1.4, Stat.burn: 1.6}, 'Mind your fingers.'),
      _ => ('Staff of the Archmagus', 'staff', null, 'meteor', {Stat.damage: 1.4, Stat.burn: 1.8}, 'The mage swore it was a loan. You\'re not so sure.'),
    };
    final slot = GearSlot.weapon;
    return GearItem(
      id: _id(),
      name: name,
      slot: slot,
      art: art,
      tint: tint,
      rarity: Rarity.legendary,
      level: level,
      heroClass: heroClass,
      lore: lore,
      special: special,
      value: _value(level, Rarity.legendary, slot),
      stats: _signature(stats, level, heroClass),
    );
  }

  /// The relic forged from land [continent]'s blueprint and parts: a legendary weapon a cut above
  /// anything that drops, with its own special attack.
  GearItem relicWeapon(int continent, int level, HeroClass heroClass) {
    final (name, art, special, stats, lore) = switch ((continent, heroClass)) {
      (2, HeroClass.ranger) => (
        'Briarsong',
        'heartbow',
        'briarvolley',
        {Stat.damage: 1.7, Stat.poison: 1.3, Stat.regen: 1.0},
        'Its string is a single bramble, grown taut between two horns of heartwood. It hums like bees.',
      ),
      (2, _) => (
        'Bramblelash',
        'whip',
        'bramblelash',
        {Stat.damage: 1.7, Stat.poison: 1.3, Stat.thorns: 1.0},
        'A living briar from the oldest ent in the Thornwild, given willingly (it says). It flowers when it tastes blood. Or sap. Or soup.',
      ),
      _ => (
        'Kingsfall',
        'kingsfall',
        'kingsfall',
        {Stat.damage: 1.8, Stat.burn: 1.4},
        'Forged from the shards of the old king\'s crown. The crack down the blade has been glowing since the Burning, and it has not cooled once.',
      ),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.legendary,
      level: level,
      heroClass: continent == 0 ? HeroClass.knight : heroClass,
      lore: lore,
      special: special,
      value: _value(level, Rarity.legendary, GearSlot.weapon) * 3,
      stats: _signature(stats, level, heroClass, edge: relicEdge),
    );
  }

  /// Elemental arms, one of each kind per hero: flame (from fire elementals), frost (from frost
  /// elementals), dawn (from the Skyreach Aeries) and shadow (from Ravenmoor's night). Knights get
  /// a blade of that element, rangers a bow, mages a staff or wand. Epic.
  GearItem elementArms(String kind, HeroClass heroClass, int level) {
    final (name, art, tint, stats, lore) = switch ((kind, heroClass)) {
      ('flame', HeroClass.knight) => ('Flamberge', 'flamberge', null, <Stat, double>{Stat.damage: 1.5, Stat.burn: 1.4, Stat.crit: .8}, 'Its wavy edge tears as it cuts, and the fire gets in after.'),
      ('flame', HeroClass.ranger) => ('Cinderbow', 'longbow', 0xFFD86A2A, <Stat, double>{Stat.damage: 1.45, Stat.burn: 1.4, Stat.crit: .8}, 'The string glows like a fuse. Don\'t touch it.'),
      ('flame', _) => ('Flamecaller staff', 'crystalstaff', 0xFFE8743A, <Stat, double>{Stat.damage: 1.35, Stat.burn: 1.6, Stat.wisdom: .8}, 'A fire elemental\'s heart, caged in glass and very cross about it.'),
      ('frost', HeroClass.knight) => ('Frostbrand', 'frostbrand', null, <Stat, double>{Stat.damage: 1.5, Stat.frost: 1.4, Stat.guard: .8}, 'Ice that will not melt, grown into a sword. Your breath steams around it.'),
      ('frost', HeroClass.ranger) => ('Rimebow', 'longbow', 0xFF9CCDE8, <Stat, double>{Stat.damage: 1.45, Stat.frost: 1.4, Stat.crit: .8}, 'Arrows leave it already frosted.'),
      ('frost', _) => ('Rimestaff', 'crystalstaff', 0xFFB8E4F8, <Stat, double>{Stat.damage: 1.35, Stat.frost: 1.6, Stat.wisdom: .8}, 'Snow falls upward around it, very slowly.'),
      ('dawn', HeroClass.knight) => ('Dawnblade', 'dawnblade', null, <Stat, double>{Stat.damage: 1.5, Stat.smite: 1.6, Stat.vigour: .8}, 'Forged on the highest aerie, where the sun comes up first. It never quite stops glowing.'),
      ('dawn', HeroClass.ranger) => ('Dawnbow', 'longbow', 0xFFE8C060, <Stat, double>{Stat.damage: 1.45, Stat.smite: 1.6, Stat.crit: .8}, 'Each arrow leaves a thread of morning behind it.'),
      ('dawn', _) => ('Sun sceptre', 'sceptre', 0xFFE8C060, <Stat, double>{Stat.damage: 1.35, Stat.smite: 1.8, Stat.wisdom: .8}, 'Hold it up and the shadows step back a pace.'),
      ('shadow', HeroClass.knight) => ('Shadowfang', 'shadowblade', null, <Stat, double>{Stat.damage: 1.5, Stat.lifesteal: 1.2, Stat.crit: 1.0}, 'A blade of night from Ravenmoor. It drinks a little of every wound.'),
      ('shadow', HeroClass.ranger) => ('Nightbow', 'bow', 0xFF3A3242, <Stat, double>{Stat.damage: 1.45, Stat.lifesteal: 1.2, Stat.crit: 1.0}, 'You never hear it loose. Neither do they.'),
      _ => ('Umbral wand', 'wand', 0xFF3A3242, <Stat, double>{Stat.damage: 1.35, Stat.lifesteal: 1.2, Stat.wisdom: 1.0}, 'It casts no shadow. It is one.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      tint: tint,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge),
    );
  }

  /// The elves' prize for each class: a Thornbloom blade (knight), Thornbloom bow (ranger) or
  /// Thornbloom wand (mage). Epic, and quick: the elves never stand still to fight.
  GearItem elfDrop(HeroClass heroClass, int level) {
    const silver = 0xFFD8E8D0;
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Thornbloom blade', 'thornblade', <Stat, double>{Stat.damage: 1.5, Stat.dodge: 1.4, Stat.poison: 1.0}, 'Silver steel, and a briar that the elves swear grew there on its own.'),
      HeroClass.ranger => ('Thornbloom bow', 'longbow', <Stat, double>{Stat.damage: 1.45, Stat.dodge: 1.4, Stat.crit: 1.0}, 'Strung with spider-silk. It flowers a little after every shot.'),
      HeroClass.mage => ('Thornbloom wand', 'wand', <Stat, double>{Stat.damage: 1.35, Stat.dodge: 1.4, Stat.poison: 1.2}, 'A cutting from the elves\' oldest rosebush. It still has opinions.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      tint: art == 'thornblade' ? null : silver,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge),
    );
  }

  /// The Duskwing weapons the Hollowdeep's bats and batkin carry: epic, one per hero, and each
  /// drinks a little from every blow (leech) on top of its own strength.
  GearItem batDrop(HeroClass heroClass, int level) {
    const dusk = 0xFF7A6A9A;
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Duskwing scimitar', 'scimitar', <Stat, double>{Stat.damage: 1.45, Stat.leech: 1.2, Stat.dodge: 1.0}, 'Black steel, curved like a wing. It drinks a little from every cut, and passes some of it on to you.'),
      HeroClass.ranger => ('Duskwing bow', 'longbow', <Stat, double>{Stat.damage: 1.4, Stat.leech: 1.0, Stat.crit: 1.0}, 'Strung with bat-wing sinew. You hear where the arrow will land before you loose it.'),
      HeroClass.mage => ('Echo-caller\'s staff', 'crystalstaff', <Stat, double>{Stat.damage: 1.3, Stat.leech: 1.1, Stat.wisdom: .9}, 'Black wood and a violet crystal that hums. Every spell you cast comes back to you, a little.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      tint: dusk,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      // The bats come when it's called: Night Swarm, with its stats a little lower to pay for it.
      special: 'nightswarm',
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge / 1.35),
    );
  }

  /// The Rimeforged weapons the Frostmarch's giants and reavers carry: epic, one per hero, cold
  /// enough to burn (frost) and heavy enough to turn a blow (guard). The mountain comes when it's
  /// called: Avalanche, with its stats a little lower to pay for it.
  GearItem frostDrop(HeroClass heroClass, int level) {
    const rime = 0xFF9AC0DC;
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Rimeforged greataxe', 'greataxe', <Stat, double>{Stat.damage: 1.45, Stat.frost: 1.3, Stat.guard: .9}, 'Forged in a giant\'s hearth from ice that never melts. Frost creeps up your gauntlets when you swing it, and it doesn\'t hurt at all.'),
      HeroClass.ranger => ('Rimeforged bow', 'longbow', <Stat, double>{Stat.damage: 1.4, Stat.frost: 1.3, Stat.crit: .9}, 'A giant\'s rib, strung with frozen gut. The arrows come off it white with rime.'),
      HeroClass.mage => ('Rimeforged staff', 'crystalstaff', <Stat, double>{Stat.damage: 1.3, Stat.frost: 1.3, Stat.wisdom: .9}, 'A shard of glacier on a black iron rod. Snow falls wherever you point it.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      tint: rime,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      special: 'avalanche',
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: _tuned(stats, level, heroClass, farmedEdge / 1.35),
    );
  }

  /// A rune-engraved weapon for [heroClass]: legendary, with a perfect rune already bound and the
  /// Runic Surge special. Only the Dragonbone Warden guards these.
  GearItem runeWeapon(HeroClass heroClass, int level) {
    final (name, art, rune, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Rune-engraved sword', 'runeblade', 'might', {Stat.damage: 1.7, Stat.crit: 1.2}, 'The runes along the fuller spell a name no one living can read.'),
      HeroClass.ranger => ('Rune-engraved bow', 'runebow', 'keenedge', {Stat.damage: 1.6, Stat.crit: 1.4}, 'Its runes glow brighter the further the arrow has to fly.'),
      HeroClass.mage => ('Rune-engraved staff', 'runestaff', 'holylight', {Stat.damage: 1.6, Stat.wisdom: 1.5}, 'Every rune is a word of an old spell. Together, they never stop casting.'),
    };
    final e = enchantmentById(rune)!;
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.legendary,
      level: level,
      heroClass: heroClass,
      lore: lore,
      special: 'runesurge',
      enchant: EnchantRoll(rune, 3, math.max(1, (statRoll(e.stat, level) * e.scale * 1.5).round())),
      value: _value(level, Rarity.legendary, GearSlot.weapon) * 2,
      stats: _signature(stats, level, heroClass),
    );
  }

  /// Stats for a signature weapon (quest or rune): a quarter stronger than its recipe, plus a
  /// third stat, so it beats a typical rolled legendary even before its special attack.
  Map<Stat, int> _signature(Map<Stat, double> recipe, int level, HeroClass heroClass, {double edge = legendEdge}) {
    final extra = recipe.containsKey(Stat.crit) ? Stat.vigour : Stat.crit;
    return _tuned({...recipe, extra: (recipe[extra] ?? 0) + .8}, level, heroClass, edge);
  }

  /// A signature weapon's stats: [recipe]'s mix, scaled so that on average it scores [edge] times a
  /// random epic weapon of [heroClass]'s at [level]. (Recipes say what a weapon is; this says how
  /// strong, the same way for all of them, so none falls behind the random drops.)
  Map<Stat, int> _tuned(Map<Stat, double> recipe, int level, HeroClass heroClass, double edge) {
    var raw = 0.0;
    recipe.forEach((s, m) => raw += statWeight(s) * _base(s, level) * m);
    final k = edge * randomEpicWeapon(heroClass, level) / raw;
    return {for (final e in recipe.entries) e.key: _roll(e.key, level, e.value * k, _r)};
  }

  /// Hallowash: Jack o' Cinders' head, hollowed out and hung on a chain. Burns, finds gold and
  /// teaches you things (mostly about pumpkins).
  GearItem cinderJack(int level) => GearItem(
    id: _id(),
    name: 'Cinder-Jack Lantern',
    slot: GearSlot.trinket,
    art: 'cinderjack',
    rarity: Rarity.epic,
    level: level,
    lore: 'A Hallowash prize. It grins at you from your belt. The candle inside never goes out, and nobody has ever lit it.',
    value: _value(level, Rarity.epic, GearSlot.trinket),
    stats: {Stat.burn: _roll(Stat.burn, level, 1.3, _r), Stat.fortune: _roll(Stat.fortune, level, 1.5, _r), Stat.wisdom: _roll(Stat.wisdom, level, 1.2, _r)},
  );

  /// The Veiled Prior's gilded mask. Wear it, and the Reaper looks right past you.
  GearItem hiddenMask(int level) => GearItem(
    id: _id(),
    name: 'Mask of the Hidden',
    slot: GearSlot.trinket,
    art: 'hiddenmask',
    rarity: Rarity.epic,
    level: level,
    lore: 'A gilded mask with no mouth and one eye, and a red tear painted down through it. Wear it, and the Reaper looks right past you.',
    value: _value(level, Rarity.epic, GearSlot.trinket),
    stats: {Stat.dodge: _roll(Stat.dodge, level, 1.4, _r), Stat.crit: _roll(Stat.crit, level, 1.2, _r), Stat.leech: _roll(Stat.leech, level, 1.0, _r)},
  );

  /// A special boss's legendary trinket, by art.
  GearItem bossTrinket(String art, int level) {
    switch (art) {
      case 'cyclopseye':
        return cyclopsEyeDrop(level);
      case 'collar':
        return collarDrop(level);
    }
    final (name, lore, stats) = switch (art) {
      'infernalsigil' => ('Infernal Sigil', 'Azgar\'s seal. It burns the hand of anyone unworthy. You seem fine.', {Stat.damage: 1.6, Stat.leech: 1.2, Stat.crit: 1.2}),
      'emberheart' => ('Emberheart', 'The last coal of the Ember King. It keeps you warm, and it is very sorry.', {Stat.damage: 2.0, Stat.burn: 2.0, Stat.vigour: 1.8, Stat.crit: 1.4}),
      'acorn' => ('Bramblecrown\'s Acorn', 'Grandmother Bramblecrown\'s last seed. Plant it somewhere that never burned.', {Stat.regen: 1.8, Stat.vigour: 1.6, Stat.thorns: 1.4}),
      'gargoyleheart' => ('Gargoyle Heart', 'A heart of carved stone. It beats once an hour, very hard.', {Stat.guard: 1.6, Stat.thorns: 1.6, Stat.block: 1.2}),
      'ankh' => ('Ankh of Nephrakhet', 'The Ash Pharaoh\'s key of life. It is cold, and it ticks like a heart.', {Stat.vigour: 2.0, Stat.smite: 1.6, Stat.leech: 1.0}),
      'phylactery' => ('Bone Phylactery', 'The Colossus kept its heart in here. It still beats, slowly.', {Stat.vigour: 2.2, Stat.regen: 1.8, Stat.block: 1.0}),
      'ashenseal' => ('Malric\'s Ashen Seal', 'The seal of the Ashen Order, broken in two. He gave it to you himself, at the end. "Do better with it than I did."', {Stat.damage: 1.3, Stat.burn: 1.2, Stat.guard: 1.3}),
      'heartsblood' => ('Heart\'s Blood', 'A drop of the Countess, set in a crystal vial. It is still warm, and it still wants.', {Stat.leech: 2.0, Stat.lifesteal: 2.0, Stat.crit: 1.5}),
      'starleaf' => ('Starleaf Brooch', 'Queen Ithriel\'s own brooch: a silver leaf with a star caught in it. The elves say it never lets an arrow fly crooked.', {Stat.crit: 2.4, Stat.dodge: 2.2, Stat.regen: 1.8}),
      'runependant' => ('Thane\'s Rune-Pendant', 'A runestone on a chain as thick as your thumb. Grimnar says it was his grandmother\'s. It hums when you\'re hit.', {Stat.guard: 2.9, Stat.block: 2.6, Stat.vigour: 2.5}),
      'echostone' => ('The Echo Stone', 'A violet stone from the Roost Mother\'s nest, set in silver wings. Hold it to your ear and you hear the cave, and every blow coming before it lands.', {Stat.damage: .7, Stat.dodge: 1.5, Stat.leech: 1.4, Stat.crit: 1.1}),
      'rimeheart' => ('The Rimeheart', 'The Jarl\'s heart-stone: a lump of blue glacier ice in a cage of black iron. It never melts, and the cold in it keeps you standing.', {Stat.frost: 1.25, Stat.guard: 1.2, Stat.vigour: 1.05, Stat.damage: .55}),
      'blossomseal' => ('Shogun\'s Blossom Seal', 'The Iron Shogun\'s seal: a cherry blossom carved in red jade. Duels fought under it are always fair, and always short.', {Stat.crit: 1.6, Stat.parry: 1.5, Stat.damage: 1.3}),
      'stormfeather' => ('Thunderwing\'s Plume', 'One feather from the Storm Roc, as long as your arm. It hums before a storm, and your blows come down like lightning.', {Stat.crit: 1.7, Stat.dodge: 1.5, Stat.damage: 1.3}),
      'mirrorheart' => ('Heart of the Thousandfold', 'A grey, slippery heart that changes shape in your hand: a bird, a fist, your own face. It wants to be useful.', {Stat.damage: 1.5, Stat.crit: 1.5, Stat.dodge: 1.5}),
      'leviathaneye' => ('Leviathan\'s Eye', 'A pale, glowing eye the size of your fist, set in coral. It never closes, and the sea is calm wherever it looks.', {Stat.frost: 1.8, Stat.vigour: 1.6, Stat.dodge: 1.3}),
      'sunfang' => ('Sun-Eater\'s Fang', 'King Ssarrak\'s tooth, set in sun-gold. It is always warm, and it makes your wounds itch as they close.', {Stat.damage: 1.1, Stat.regen: 1.5, Stat.thorns: 1.1}),
      'thousandmask' => ('Mask of a Thousand Faces', 'The Mother\'s own mask, with every face she ever took moving under the porcelain. Wear it, and foes can never quite tell where you\'ll strike.', {Stat.crit: 1.7, Stat.parry: 1.5, Stat.damage: 1.3}),
      'bloodmoonpelt' => ('Bloodmoon Pelt', 'The Alpha\'s hide, red under the moon. Wear it, and when you\'re hurt badly enough, the wolf comes out.', {Stat.damage: 1.1, Stat.crit: 1.2, Stat.vigour: 1.0}),
      _ => ('Krugg\'s War Horn', 'One blast and every ork in the valley picks up an axe.', {Stat.damage: 1.5, Stat.crit: 1.2, Stat.fortune: 1.2}),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.trinket,
      art: art,
      rarity: Rarity.legendary,
      level: level,
      lore: lore,
      value: _value(level, Rarity.legendary, GearSlot.trinket),
      stats: {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
  }

  /// A piece of a forged set (gloves, boots or a ring), made at Dunstan's from its blueprint: epic,
  /// at your level, with the set's own stats.
  GearItem setPiece(String setId, GearSlot slot, HeroClass heroClass, int level) {
    final set = gearSetById(setId)!;
    final (main, second, third) = switch ((setId, slot)) {
      ('ashen', GearSlot.gloves) => (Stat.damage, Stat.burn, Stat.guard),
      ('ashen', GearSlot.boots) => (Stat.guard, Stat.block, Stat.vigour),
      ('ashen', _) => (Stat.burn, Stat.thorns, Stat.guard),
      ('nightblood', GearSlot.gloves) => (Stat.damage, Stat.lifesteal, Stat.crit),
      ('nightblood', GearSlot.boots) => (Stat.dodge, Stat.vigour, Stat.lifesteal),
      ('nightblood', _) => (Stat.leech, Stat.lifesteal, Stat.vigour),
      ('silverleaf', GearSlot.gloves) => (Stat.crit, Stat.damage, Stat.dodge),
      ('silverleaf', GearSlot.boots) => (Stat.dodge, Stat.regen, Stat.crit),
      ('silverleaf', _) => (Stat.crit, Stat.regen, Stat.dodge),
      ('deepforge', GearSlot.gloves) => (Stat.damage, Stat.guard, Stat.block),
      ('deepforge', GearSlot.boots) => (Stat.guard, Stat.block, Stat.vigour),
      ('deepforge', _) => (Stat.block, Stat.guard, Stat.thorns),
      ('faceless', GearSlot.gloves) => (Stat.damage, Stat.crit, Stat.parry),
      ('faceless', GearSlot.boots) => (Stat.parry, Stat.dodge, Stat.crit),
      ('faceless', _) => (Stat.crit, Stat.parry, Stat.damage),
      ('sunscale', GearSlot.gloves) => (Stat.damage, Stat.thorns, Stat.vigour),
      ('sunscale', GearSlot.boots) => (Stat.vigour, Stat.regen, Stat.dodge),
      ('sunscale', _) => (Stat.regen, Stat.vigour, Stat.thorns),
      ('tidecaller', GearSlot.gloves) => (Stat.frost, Stat.damage, Stat.crit),
      ('tidecaller', GearSlot.boots) => (Stat.dodge, Stat.frost, Stat.vigour),
      ('tidecaller', _) => (Stat.frost, Stat.regen, Stat.dodge),
      ('changeling', GearSlot.gloves) => (Stat.damage, Stat.crit, Stat.dodge),
      ('changeling', GearSlot.boots) => (Stat.dodge, Stat.crit, Stat.damage),
      ('changeling', _) => (Stat.crit, Stat.damage, Stat.dodge),
      ('skyborn', GearSlot.gloves) => (Stat.crit, Stat.damage, Stat.dodge),
      ('skyborn', GearSlot.boots) => (Stat.dodge, Stat.vigour, Stat.crit),
      ('skyborn', _) => (Stat.dodge, Stat.crit, Stat.fortune),
      ('bushido', GearSlot.gloves) => (Stat.damage, Stat.parry, Stat.crit),
      ('bushido', GearSlot.boots) => (Stat.parry, Stat.vigour, Stat.crit),
      ('bushido', _) => (Stat.crit, Stat.parry, Stat.damage),
      (_, GearSlot.gloves) => (Stat.damage, Stat.crit, Stat.dodge),
      (_, GearSlot.boots) => (Stat.dodge, Stat.crit, Stat.vigour),
      _ => (Stat.crit, Stat.damage, Stat.regen),
    };
    const rarity = Rarity.epic;
    // A little better than a random epic piece (it's farmed for), with the set's bonus on top.
    final scale = switch (main) {
      Stat.damage || Stat.leech => .5,
      Stat.guard => .7,
      Stat.crit => .65,
      _ => .6,
    };
    // Each set's stats weigh differently, so each is tuned to land a little above an average
    // random epic piece of the same slot (see tool/items.dart).
    final power = _setPower[setId] ?? 1.0;
    final stats = <Stat, int>{main: _roll(main, level, scale * rarity.power * 1.15 * power, _r)};
    for (final st in [second, third]) {
      stats[st] = (stats[st] ?? 0) + _roll(st, level, .8 * rarity.power * .6 * power, _r);
    }
    final art = switch (slot) {
      GearSlot.gloves => switch (heroClass) {
        HeroClass.knight => 'gauntlets',
        HeroClass.mage => 'spellgloves',
        HeroClass.ranger => 'bracers',
      },
      GearSlot.boots => heroClass == HeroClass.knight ? 'sabatons' : 'boots',
      _ => 'ring',
    };
    final noun = switch (slot) {
      GearSlot.gloves => heroClass == HeroClass.knight ? 'gauntlets' : (heroClass == HeroClass.mage ? 'gloves' : 'bracers'),
      GearSlot.boots => heroClass == HeroClass.knight ? 'sabatons' : 'boots',
      _ => 'signet',
    };
    return GearItem(
      id: _id(),
      name: '${set.name} $noun',
      slot: slot,
      art: art,
      rarity: rarity,
      level: level,
      gearSet: set.id,
      tint: switch (setId) {
        'ashen' => 0xFF5A5A62,
        'nightblood' => 0xFF7A1424,
        'silverleaf' => 0xFFCFE0D4,
        'deepforge' => 0xFF6A7A9A,
        'faceless' => 0xFFD8D2CA,
        'sunscale' => 0xFF5A8A3A,
        'tidecaller' => 0xFF3A8AB8,
        'changeling' => 0xFF8A6AB0,
        'skyborn' => 0xFF9AC8E8,
        'bushido' => 0xFFB8322A,
        _ => 0xFF8A94A8,
      },
      heroClass: slot == GearSlot.ring ? null : heroClass,
      lore: 'Forged by Dunstan from a blueprint. ${set.twoText} with two pieces; ${set.threeText[0].toLowerCase()}${set.threeText.substring(1)} with all three.',
      value: _value(level, rarity, slot),
      stats: stats,
    );
  }

  /// The Cyclops's eye, set in an amulet: a legendary trinket that finds weak spots.
  GearItem cyclopsEyeDrop(int level) => GearItem(
    id: _id(),
    name: 'Gorbo\'s Eye',
    slot: GearSlot.trinket,
    art: 'cyclopseye',
    rarity: Rarity.legendary,
    level: level,
    lore: 'It still looks around when you\'re not watching it.',
    value: _value(level, Rarity.legendary, GearSlot.trinket),
    stats: {Stat.crit: _roll(Stat.crit, level, 1.8, _r), Stat.parry: _roll(Stat.parry, level, 1.2, _r), Stat.wisdom: _roll(Stat.wisdom, level, 1.5, _r)},
  );

  /// The Demon Hound's collar: a legendary trinket for any class.
  GearItem collarDrop(int level) => GearItem(
    id: _id(),
    name: 'Scorchmaw\'s Collar',
    slot: GearSlot.trinket,
    art: 'collar',
    rarity: Rarity.legendary,
    level: level,
    lore: 'Still warm. Something on the other side of it still pulls.',
    value: _value(level, Rarity.legendary, GearSlot.trinket),
    stats: {Stat.burn: _roll(Stat.burn, level, 2.0, _r), Stat.thorns: _roll(Stat.thorns, level, 1.8, _r), Stat.dodge: _roll(Stat.dodge, level, 1.0, _r)},
  );

  /// Rolls one drop. [odds] overrides the rarity weights (common to legendary); [element] makes
  /// a rare foe's aura show up as the drop's first affix.
  GearItem roll(HeroClass heroClass, int level, {bool boss = false, List<int>? odds, Stat? element, GearItem? wielding, GearSlot? only, bool east = false}) {
    final rarity = _rarity(boss, odds);
    final legends = _legends.where((l) => (l.heroClass == null || l.heroClass == heroClass) && (only == null || l.slot == only)).toList();
    if (rarity == Rarity.legendary && legends.isNotEmpty) {
      final pool = legends;
      final l = _pick(pool);
      return GearItem(
        id: _id(),
        name: l.name,
        slot: l.slot,
        art: l.art,
        rarity: rarity,
        level: level,
        heroClass: l.heroClass,
        lore: l.lore,
        // Legendary weapons carry a special attack: each its own, from its class's (by its name).
        special: l.slot == _w ? (l.special ?? legendSpecial(l.name, l.heroClass ?? heroClass)) : null,
        value: _value(level, rarity, l.slot),
        // Named legendary weapons are tuned like every other signature weapon; the rest roll as written.
        stats: l.slot == _w ? _tuned(l.stats, level, l.heroClass ?? heroClass, legendEdge) : {for (final e in l.stats.entries) e.key: _roll(e.key, level, e.value, _r)},
      );
    }
    final slot = only ?? _slot();
    // Off-hands usually suit the weapon you're holding.
    var bases = slot == _t ? _trinkets : (slot == _rg ? _rings : _bases[heroClass]![slot]!);
    // In the Blossom Isles, most weapons and off-hands are the islands' own.
    final eastern = _eastBases[heroClass]![slot];
    if (east && eastern != null && _r.nextInt(3) > 0) bases = eastern;
    final want = offhandKindsFor(wielding?.art);
    if (slot == _o && want.isNotEmpty && _r.nextInt(4) > 0) {
      final suited = bases.where((b) => want.contains(offhandKindOf(b.art))).toList();
      if (suited.isNotEmpty) bases = suited;
    }
    final base = _pick(bases);
    // Material by level, sometimes a band better or worse.
    final band = (_band(level) + (_r.nextInt(5) == 0 ? (_r.nextBool() ? 1 : -1) : 0)).clamp(0, 5);
    final material = switch (base.make) {
      _Make.metal => _metals[band],
      _Make.wood => _woods[band],
      _Make.none => null,
    };
    final made = material == null ? 1.0 : 1 + band * .07;
    final stats = <Stat, int>{base.primary: _roll(base.primary, level, base.scale * rarity.power * made, _r)};
    final pool = _affixes.where((a) => a.slots.contains(slot)).toList()..shuffle(_r);
    if (element != null && rarity.index > 0) {
      final i = pool.indexWhere((a) => a.stat == element);
      if (i > 0) pool.insert(0, pool.removeAt(i));
    }
    final chosen = <_Affix>[];
    for (final a in pool) {
      if (chosen.length >= rarity.index) break;
      if (a.stat == base.primary && chosen.isEmpty && rarity.index < 2 && a.stat != element) continue; // keep names varied
      chosen.add(a);
    }
    // Gloves, boots and rings are accessories: their enchantments roll smaller.
    final accessory = slot == _gl || slot == _bt || slot == _rg ? .55 : 1.0;
    for (final a in chosen) {
      stats[a.stat] = (stats[a.stat] ?? 0) + _roll(a.stat, level, .8 * rarity.power * accessory, _r);
    }
    final prefix = chosen.isNotEmpty ? '${chosen[0].prefix} ' : '';
    final suffix = chosen.length > 1 ? ' ${chosen[1].suffix}' : '';
    final epic = rarity == Rarity.epic ? _pick(const ['Ancient ', 'Runed ', 'Masterwork ', 'Storied ']) : '';
    final baseName = material == null ? base.name : '${material.$1} ${base.name[0].toLowerCase()}${base.name.substring(1)}';
    // Rarely, an epic or legendary weapon is a bloodleech: it drinks from every wound it makes.
    var bloodleech = false;
    if (slot == _w && rarity.index >= Rarity.epic.index && _r.nextDouble() < bloodleechChance) {
      bloodleech = true;
      stats[Stat.leech] = (rarity == Rarity.legendary ? 14 : 10) + _r.nextInt(4);
    }
    // Now and then a rare-or-better weapon comes already enchanted.
    final enchant = slot == _w && rarity.index >= Rarity.rare.index && _r.nextDouble() < .15 ? rollEnchant(EnchantSlot.weapon, level, _r) : null;
    // Rare-or-better gloves, boots and rings sometimes belong to a set.
    GearSet? set;
    if ((slot == _gl || slot == _bt || slot == _rg) && rarity.index >= Rarity.rare.index && _r.nextDouble() < gearSetChance) {
      final sets = gearSets.where((g) => !g.forged && (g.heroClass == null || g.heroClass == heroClass)).toList();
      set = _pick(sets);
    }
    final low = '${baseName[0].toLowerCase()}${baseName.substring(1)}';
    return GearItem(
      enchant: enchant,
      gearSet: set?.id,
      id: _id(),
      name: set != null ? '${set.name} $low$suffix' : (bloodleech ? 'Bloodleech $low$suffix' : '$prefix$epic$baseName$suffix'.trim()),
      tint: bloodleech ? 0xFFB0302A : material?.$2,
      slot: slot,
      art: base.art,
      rarity: rarity,
      level: level,
      heroClass: slot == _t || slot == _rg ? null : heroClass,
      value: _value(level, rarity, slot),
      stats: stats,
    );
  }
}

/// The plain starting kit, so every class begins with a weapon in hand.
GearItem starterWeapon(HeroClass c) {
  final (name, art) = switch (c) {
    HeroClass.knight => ('Arming sword', 'longsword'),
    HeroClass.mage => ('Ash staff', 'staff'),
    HeroClass.ranger => ('Hunting bow', 'bow'),
  };
  return GearItem(
    id: 'starter-${c.name}',
    name: name,
    slot: GearSlot.weapon,
    art: art,
    rarity: Rarity.common,
    level: 1,
    heroClass: c,
    value: 4,
    stats: const {Stat.damage: 1},
  );
}

/// Marks wyrmscale pieces (not a set with a bonus: each piece strikes dragons harder on its own).
const wyrmSet = 'wyrmscale';

String wyrmArmourName(HeroClass c, WyrmTier w) => armourTierById(wyrmArmourId(c, w.tier)).name;
