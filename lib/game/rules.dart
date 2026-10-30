// The numbers behind every fight. Pure functions over the game state.

import 'dart:math' as math;

import 'ammo.dart';
import 'brews.dart';
import 'catalog.dart';
import 'classes.dart';
import 'loot.dart';
import 'models.dart';
import 'spells.dart';

/// Everything the hero's class, armour and gear add up to.
class HeroStats {
  int damage = 0, poison = 0, burn = 0, frost = 0, smite = 0, lifesteal = 0, vigour = 0, regen = 0, thorns = 0, dragonkin = 0;
  int crit = 0, guard = 0, fortune = 0, wisdom = 0, dodge = 0, parry = 0, block = 0, leech = 0, wyrmbane = 0; // percentages
  double armour = 0;

  int get(Stat s) => switch (s) {
    Stat.damage => damage,
    Stat.poison => poison,
    Stat.burn => burn,
    Stat.frost => frost,
    Stat.smite => smite,
    Stat.crit => crit,
    Stat.lifesteal => lifesteal,
    Stat.guard => guard,
    Stat.vigour => vigour,
    Stat.regen => regen,
    Stat.thorns => thorns,
    Stat.fortune => fortune,
    Stat.wisdom => wisdom,
    Stat.dragonkin => dragonkin,
    Stat.dodge => dodge,
    Stat.parry => parry,
    Stat.block => block,
    Stat.leech => leech,
    Stat.wyrmbane => wyrmbane,
  };

  void add(Stat s, int v) {
    switch (s) {
      case Stat.damage:
        damage += v;
      case Stat.poison:
        poison += v;
      case Stat.burn:
        burn += v;
      case Stat.frost:
        frost += v;
      case Stat.smite:
        smite += v;
      case Stat.crit:
        crit += v;
      case Stat.lifesteal:
        lifesteal += v;
      case Stat.guard:
        guard += v;
      case Stat.vigour:
        vigour += v;
      case Stat.regen:
        regen += v;
      case Stat.thorns:
        thorns += v;
      case Stat.fortune:
        fortune += v;
      case Stat.wisdom:
        wisdom += v;
      case Stat.dragonkin:
        dragonkin += v;
      case Stat.dodge:
        dodge += v;
      case Stat.parry:
        parry += v;
      case Stat.block:
        block += v;
      case Stat.leech:
        leech += v;
      case Stat.wyrmbane:
        wyrmbane += v;
    }
  }
}

HeroStats heroStats(Knight k, {Iterable<GearItem>? gear}) {
  final s = HeroStats()..armour = armourTierById(k.armour).reduction;
  for (final g in gear ?? k.gear) {
    g.stats.forEach(s.add);
    final e = g.enchant;
    if (e != null) s.add(e.info.stat, e.value);
  }
  // Gear sets: two pieces for the first bonus, three for the second as well.
  for (final (set, n) in activeSets(gear ?? k.gear)) {
    set.two.forEach(s.add);
    if (n >= 3) set.three.forEach(s.add);
  }
  final rune = k.loadout.armourEnchant;
  if (rune != null) s.add(rune.info.stat, rune.value);
  // An armour variant's perk (riveted mail parries, blackened plate blocks...).
  final tier = armourTierById(k.armour);
  if (tier.perk != null) s.add(Stat.values.byName(tier.perk!), tier.perkValue);
  // Both hands behind the blow: two-handed weapons (and bows, whose quivers add little) hit
  // harder, to make up for the off-hand they give up.
  if (gear == null) s.damage += twoHandBonus(k.loadout.weapon);
  switch (k.heroClass) {
    case HeroClass.knight:
      s.vigour += 15;
      s.guard += 5;
    case HeroClass.mage:
      s.burn += 3 + k.level ~/ 4;
      s.vigour += 2 * k.level; // robes woven with warding thread
    case HeroClass.ranger:
      s.crit += 10;
  }
  if (k.gloves) s.damage += 3;
  return s;
}

/// Mana [spell] costs you: one less with the full Arcanist set (never below 1).
int spellCost(Knight k, Spell spell) {
  final cheaper = activeSets(k.gear).any((e) => e.$1.cheaperSpells && e.$2 >= 3);
  return math.max(1, spell.cost - (cheaper ? 1 : 0));
}

/// Extra damage a two-handed weapon (or bow) gets from its own damage stat.
int twoHandBonus(GearItem? w) {
  if (w == null) return 0;
  final kind = offhandKindFor(w.art), staff = w.heroClass == HeroClass.mage;
  // Staves get less: a mage's spells already multiply the swing.
  final share = kind == null ? (staff ? .25 : .6) : (kind == OffhandKind.quiver ? .4 : 0.0);
  return ((w.stats[Stat.damage] ?? 0) * share).round();
}

int maxHp(Knight k) => 100 + 5 * (k.level - 1) + heroStats(k).vigour + vigourHp * trained(k, Trait.vigour);

// ---------------- training: your build ----------------

/// The four things a level's training point can go into.
enum Trait { might, arcana, aim, vigour }

extension TraitInfo on Trait {
  String get label => switch (this) {
    Trait.might => 'Might',
    Trait.arcana => 'Arcana',
    Trait.aim => 'Aim',
    Trait.vigour => 'Vigour',
  };

  /// What one point does.
  String get perPoint => switch (this) {
    Trait.might => '+${(mightPer * 100).toStringAsFixed(1)}% blade damage (attacks and bashes)',
    Trait.arcana => '+${(arcanaPer * 100).toStringAsFixed(1)}% rite damage; at $arcanaManaAt, start fights with +1 mana',
    Trait.aim => '+${(aimPer * 100).toStringAsFixed(1)}% crossbow damage, and a wider bullseye',
    Trait.vigour => '+$vigourHp max HP',
  };
}

/// What a point of each trait is worth.
const mightPer = .012, arcanaPer = .016, aimPer = .016, vigourHp = 4, arcanaManaAt = 10;

/// Points put into [t].
int trained(Knight k, Trait t) => k.training[t.name] ?? 0;

/// Points still to spend: one for every level past the first.
int unspentPoints(Knight k) => math.max(0, k.level - 1 - Trait.values.fold<int>(0, (n, t) => n + trained(k, t)));

/// How much harder your blade, rites and crossbow land from training.
double mightBoost(Knight k) => 1 + mightPer * trained(k, Trait.might);
double arcanaBoost(Knight k) => 1 + arcanaPer * trained(k, Trait.arcana);
double aimBoost(Knight k) => 1 + aimPer * trained(k, Trait.aim);

/// Gold to wipe your training and spend it again.
int resetTrainingCost(Knight k) => 25 * k.level;

/// Armour tier plus guard from gear and class, capped at 60%.
double damageReduction(Knight k) {
  final s = heroStats(k);
  return math.min(.6, s.armour + s.guard / 100);
}

/// XP for the next level. The first comes quickly (two fights), so a new hero feels it early.
int xpToNext(Knight k) => k.level == 1 ? 50 : 100 * k.level;

/// A health potion heals more as you level, so it stays worth carrying.
/// What a health potion heals: half your max HP (never less than 40 + 3 a level), so the turn
/// you spend drinking always comes out well ahead of the blow you take for it.
int potionHeal(Knight k) => math.max(40 + 3 * k.level, (maxHp(k) * potionShare).round());

/// Share of your max HP a potion brings back.
const potionShare = .5;

/// Which companion fights: 'dragon', a Pet name, or null if you have none.
String? activeCompanion(Knight k) {
  final a = k.activePet;
  if (a == 'dragon' && k.hasDragon) return a;
  if (a != null && k.pets.containsKey(a)) return a;
  if (k.hasDragon) return 'dragon';
  return k.pets.keys.firstOrNull;
}

/// The active pet's kind and stage (null when the dragon, or nobody, is fighting).
(Pet, PetStage)? petStage(Knight k) {
  final a = activeCompanion(k);
  final pet = Pet.values.where((p) => p.name == a).firstOrNull;
  if (pet == null) return null;
  final xp = k.pets[pet.name]!;
  var s = petStages[pet]!.first;
  for (final st in petStages[pet]!) {
    if (xp >= st.minXp) s = st;
  }
  return (pet, s);
}

/// The dragon's stage, if the dragon is the companion fighting.
DragonStage? dragonStage(Knight k) {
  final xp = k.dragonXp;
  if (xp == null || activeCompanion(k) != 'dragon') return null;
  var s = dragonStages.first;
  for (final d in dragonStages) {
    if (xp >= d.minXp) s = d;
  }
  return s;
}

/// Damage of one plain attack before effects and crits.
int fullSwing(Knight k) => 8 + 2 * k.level + heroStats(k).damage;

/// The level of the foes you meet in [continent]: never below the continent's own level, and they
/// keep pace with you above it.
int foeLevelFor(int continent, int heroLevel) => math.max(heroLevel, continents[continent].minLevel);

/// Turns a hero of the foe's level, in the gear such a hero usually has, needs to fell a common foe
/// with plain attacks (skills and companions make it fewer), and how many times longer a boss
/// takes.
const turnsPerFoe = 5.8, bossTurns = 3.0;

/// The foe in front of you now: its kind, and any shape a shapeshifter has taken.
FoeType foeIn(GameState s) => formed(encounterType(s.foe, s.rare), s.form);

/// A foe's HP, fixed when the fight starts.
int spawnHp(int foeIndex, int level, [Rare? rare]) {
  // A rare in its own clothes (the Hidden Ones, golems) has its own HP; the base foe sets the land.
  final i = rare?.base ?? foeIndex, f = rare?.type ?? foeAt(i);
  final variant = rare == null ? 1.0 : (rare.name != null && !rare.pack ? namedRareHp : rareHp) * (f.boss ? .7 : 1);
  return ((8 + 2 * level) * turnsPerFoe * (f.boss ? bossTurns : 1) * f.hp * variant * toughness(landTier(realmAt(i)), level)).round();
}

/// Later continents are tougher, and foes keep pace with the gear a hero of [level] usually
/// carries: weapons, crits, elements and companions take a hero from a little over a bare swing at
/// level 1 to about four times it by level 30 (see tool/balance.dart).
double toughness(int realm, int level) => (1 + .06 * realm) * gearPower(level);

/// How many bare swings a typically geared hero of [level] hits for.
double gearPower(int level) => 1.2 + 3.0 * (1 - math.exp(-(level - 1) / 9));

class FoeReward {
  const FoeReward(this.xp, this.coins, this.level);
  final int xp, coins, level;
}

/// What felling the foe at [i] (level [level]) is worth.
FoeReward foeReward(int i, int level, [Knight? k, Rare? rare]) {
  if (rare != null) i = rare.base;
  final f = foeAt(i), b = f.boss, realm = 1 + .1 * landTier(realmAt(i));
  var xp = (18 + 7 * level) * (b ? 3 : 1) * realm, coins = (6 + 3 * level) * (b ? 3 : 1) * realm;
  if (rare != null) {
    xp *= rareRewards;
    coins *= rareRewards * (rare.aura == Aura.gilded ? 2.5 : 1);
  }
  if (k != null) {
    final s = heroStats(k);
    xp *= 1 + s.wisdom / 100;
    coins *= 1 + s.fortune / 100;
  }
  return FoeReward(xp.round(), coins.round(), level);
}

/// One attack's damage, split by type so the stage can show each.
class SwingDamage {
  const SwingDamage({this.base = 0, this.poison = 0, this.burn = 0, this.frost = 0, this.smite = 0, this.chip = 0, this.heal = 0, this.crit = false, this.special, this.ammo, this.spell, this.leech = false, this.devastating = false, this.glancing = false});
  final int base, poison, burn, frost, smite, chip, heal;
  final bool crit;

  /// The special attack this attack unleashed.
  final Special? special;

  /// The special ammunition this attack spent.
  final AmmoType? ammo;

  /// The spell this attack cast.
  final Spell? spell;

  /// Some of the heal came from bloodleech (for the animation).
  final bool leech;

  /// A crit that hit half again as hard; a blow that only grazed (half damage).
  final bool devastating, glancing;

  int get effects => poison + burn + frost + smite;
  int get total => base + effects + chip;
}

/// Your chance to land a critical hit: crit from gear and class, plus your weapon's own (quick and
/// rare weapons crit more), and a wolf hunting with you. Up to 45%.
double critChance(Knight k) => math.min(.45, (heroStats(k).crit + weaponCrit(k.loadouts[k.heroClass]!.weapon) + (petStage(k)?.$2.crit ?? 0)) / 100);

/// Whether an attack catches a whole pack: a sweeping weapon, an area spell, a special arrow or a
/// special attack.
bool sweepsPack(GearItem? weapon, Special? sp, Spell? cast, AmmoType? shot) =>
    sp != null || shot != null || sweepingWeapons.contains(weapon?.art) || const {SpellKind.nova, SpellKind.chain, SpellKind.dragon, SpellKind.charge}.contains(cast?.kind);

/// The chance an attack only grazes (half damage), and the chance it misses outright.
const glanceChance = .1, missChance = .05;

/// Damage for one attack. [roll] is a 0..1 random number for crits. [mult] scales the blow (a
/// skill), [sureCrit] makes it a critical hit.
SwingDamage swingDamage(GameState state, double roll, {Special? special, AmmoType? ammo, Spell? spell, double? hitRoll, double mult = 1, bool sureCrit = false}) {
  final k = state.knight, s = heroStats(k);
  final sp = special, shot = ammo, bonus = shot == null ? 0 : ammoBonus(k.level), cast = spell;
  var base = fullSwing(k);
  final exposed = state.foeExposed > 0 ? 1.25 : 1.0; // Sunder Armour
  base = (base * mult * (sp?.mult ?? 1) * (cast?.mult ?? 1) * exposed * outmatchedHits(state.foeLevel, k.level)).round();
  // Hit variety: crits (more likely with quick and rare weapons, and now and then devastating),
  // and glancing blows that only graze.
  final weapon = k.loadouts[k.heroClass]!.weapon, chance = critChance(k);
  // Dwarves' ironhide turns critical hits into ordinary ones.
  final crit = !foeIn(state).ironhide && (sp?.crit == true || sureCrit || roll < chance);
  final devastating = crit && roll < chance * .2;
  final glancing = !crit && sp == null && cast == null && mult <= 1 && (hitRoll ?? 1) < glanceChance;
  // Stone skin: blades and arrows glance off, blunt weapons crush; a mage's magic doesn't care.
  final foe = foeIn(state);
  if (foe.stone && cast == null) base = (base * (bluntWeapons.contains(weapon?.art) ? 1.5 : .6)).round();
  // Spirits: steel and arrows pass half through; magic doesn't care.
  if (foe.spirit && cast == null) base = (base * .6).round();
  // Packs: sweeping blows, area spells, special arrows and special attacks catch them all.
  if (foe.pack && sweepsPack(weapon, sp, cast, shot)) base = (base * 1.5).round();
  // Wyrmscale gear: dragons take more (up to +35% from a full set).
  if (foe.dragon && s.wyrmbane > 0) base = (base * (1 + math.min(wyrmbaneCap, s.wyrmbane) / 100)).round();
  if (crit) base = (base * critMultiplier(weapon) * (devastating ? 1.5 : 1)).round();
  if (glancing) base = (base * .5).round();
  final ds = dragonStage(k), pet = petStage(k)?.$2;
  // The companion's blow: dragon fire (boosted by dragonkin gear) or a pet's bite.
  final chip = pet != null ? pet.bite + k.level ~/ 6 : (ds == null || ds.chip == 0 ? 0 : ds.chip + k.level ~/ 5 + s.dragonkin);
  final poison = s.poison + (k.poisonFights > 0 ? 4 + k.level ~/ 3 : 0), extra = sp?.element == null ? 0 : 3 * k.level;
  // Blessed shots: light against the living, heavy against the unholy; frost shots a smaller chill.
  final unholy = foe.undead || foe.demon || foe.element == 'poison';
  int shotAdds(Stat st) => shot?.stat != st ? 0 : switch (shot!) {
    AmmoType.blessed => holyShot(k.level, unholy),
    AmmoType.frost => (bonus * frostShare).round(),
    _ => bonus,
  };
  int ammoAdds(Stat st) => shotAdds(st) + (cast?.element == st ? 3 * k.level : 0);
  final burn = s.burn + (sp?.element == Stat.burn ? extra : 0) + ammoAdds(Stat.burn) + (pet?.burn ?? 0);
  // An elemental shrugs off its own element and takes double from its opposite.
  int el(Stat st, int v) => foe.element == null ? v : (foe.element == st.name ? 0 : (elementWeakness(foe.element!) == st.name ? v * 2 : v));
  return SwingDamage(
    base: base,
    // Ents shrug off half the poison; spiders all of it.
    poison: el(Stat.poison, foe.venomous ? 0 : (foe.ent ? (poison + ammoAdds(Stat.poison)) ~/ 2 : poison + ammoAdds(Stat.poison))),
    // Ents burn twice as hard; demons (and the Ember King himself) only half as hard.
    burn: el(Stat.burn, foe.demon || foe.look == 'emberKing' ? burn ~/ 2 : (foe.ent ? burn * 2 : burn)),
    frost: el(Stat.frost, s.frost + (sp?.element == Stat.frost ? extra : 0) + ammoAdds(Stat.frost)),
    // A special's holy fire hurts anything; ordinary smite only the undead and demons. Holy fire
    // burns spirits twice over.
    // Holy light also burns away a mire elemental, twice over.
    smite: el(Stat.smite, ((foe.undead || foe.demon || foe.element == 'poison' ? s.smite : 0) + (sp?.element == Stat.smite ? extra : 0) + ammoAdds(Stat.smite)) * (foe.spirit ? 2 : 1)),
    chip: chip,
    // Bloodleech heals a share of the hit (capped), on top of flat lifesteal.
    heal: s.lifesteal + (sp?.heal ?? 0) + (base * math.min(leechCap + (shot == AmmoType.leech ? 15 : 0), s.leech + (shot == AmmoType.leech ? 15 : 0)) / 100).round(),
    leech: s.leech > 0 || shot == AmmoType.leech,
    devastating: devastating,
    glancing: glancing,
    crit: crit,
    special: sp,
    ammo: shot,
    spell: cast,
  );
}

// ------------------------------------------------------------------ the foe's turn

/// How hard the foe at [foeIndex] (or a rare variant) hits back each turn, before armour. Grows
/// with its level and continent; bosses and rare foes hit harder.
int foeAttack(int foeIndex, Rare? rare, int level) {
  final f = encounterType(foeIndex, rare), realm = landTier(realmAt(rare?.base ?? foeIndex));
  var a = (13 + 5.6 * level) * (1 + .05 * realm);
  // The first few levels go easier on a new hero, while they learn the ropes (and the flat part of
  // the formula would otherwise make Cindervale the hardest land in the game, per foe).
  if (level < 5) a *= .7 + .075 * (level - 1);
  // Bosses hit hard (Gorbo, the very first, a little less: he's where a new hero learns bosses).
  if (f.boss) a *= realm == 0 ? 1.4 : 1.6;
  if (f.dragon) a += 1;
  if (f.rare) a *= f.named ? 1.35 : 1.2;
  if (f.pack) a *= 1.1;
  if (f.look == 'cyclops') a *= cyclopsHits;
  return a.round();
}

/// The chance the foe's blow misses you outright (more for nimble rangers).
double dodgeChance(Knight k, [FoeType? foe]) => math.min(.6, (k.heroClass == HeroClass.ranger ? .25 : .15) + heroStats(k).dodge / 100 + (foe?.look == 'cyclops' ? cyclopsDodge : 0));

/// How the foe's blow went.
enum Guard { dodge, parry, block, hit, frozen, warded, slowed, guarded, asleep, stunned }

/// Share of an attack the off-hand weapon adds when dual wielding.
const dualStrikeShare = .08;

/// Whether the hero is dual wielding (a second weapon in the off hand, not a shield or tome).
bool dualWielding(Knight k) {
  final l = k.loadouts[k.heroClass]!;
  return isDualWield(l.weapon, l.offhand);
}

/// The off-hand weapon's strike after an attack: a share of it, lifted or dulled by the same
/// things (Sunder Armour, stone skin). 0 if not dual wielding.
int offhandStrike(GameState state) {
  final k = state.knight;
  if (!dualWielding(k)) return 0;
  var hit = fullSwing(k) * dualStrikeShare;
  if (state.foeExposed > 0) hit *= 1.25;
  final f = foeIn(state);
  if ((f.stone || f.spirit) && k.heroClass != HeroClass.mage) hit *= .6;
  return math.max(1, hit.round());
}

bool _hasShield(Knight k) => const {'buckler', 'kite', 'tower', 'round', 'dragonshield'}.contains(k.loadouts[k.heroClass]!.activeOffhand?.art);

/// The chance to parry the foe's blow (deflect it and riposte), from class and crit. Up to 40%.
double parryChance(Knight k) {
  final base = switch (k.heroClass) {
    HeroClass.knight => 10,
    HeroClass.ranger => 7,
    HeroClass.mage => 5,
  };
  final s = heroStats(k);
  // Two blades catch a blow better than one.
  final twin = dualWielding(k) && k.heroClass == HeroClass.knight ? 3 : 0;
  return ((base + s.crit ~/ 2 + s.parry + twin) / 100).clamp(0.0, .4);
}

/// The chance to block (or, for mages, ward off) most of the blow, from class, shield and guard.
/// Up to 50%.
double blockChance(Knight k) {
  final base = switch (k.heroClass) {
    HeroClass.knight => 10,
    HeroClass.mage => 12,
    HeroClass.ranger => 5,
  };
  final shield = _hasShield(k) ? 8 : 0;
  final s = heroStats(k);
  return ((base + shield + s.guard ~/ 2 + s.block) / 100).clamp(0.0, .5);
}

/// A block lets this share of the blow through (a shield stops more of it).
double blockLeak(Knight k) => _hasShield(k) ? .3 : .45;

/// The riposte after a parry: half an attack.
int riposte(Knight k) => (fullSwing(k) * .5).round();

/// What its next blow will do: [counterDamage], heavier if it's winding up.
int nextBlow(GameState s) => (counterDamage(s) * (s.foeWindup ? heavyBlow : 1)).round();

/// The foe's blow after armour and guard (at least 1).
int counterDamage(GameState s) {
  final k = s.knight;
  final weakened = s.foeWeakened > 0 ? .6 : 1.0; // Enfeeble
  // The dead hit softer against armour made of their own bones.
  final bones = foeIn(s).undead && boneArmour.contains(k.loadout.armour) ? boneWard : 1.0;
  final bark = brewOn(k, Brew.barkskin) ? barkskinBrew : 1.0;
  final hide = s.wolfTurns > 0 ? wolfHide : 1.0;
  return math.max(1, (foeAttack(s.foe, s.rare, s.foeLevel) * (1 - damageReduction(k)) * weakened * bones * bark * hide * manaShield(s) * outmatched(s.foeLevel, k.level)).round());
}

/// The Bloodmoon Pelt: when a blow leaves you under [wolfAt] of your HP, the wolf comes out (once a
/// fight) for [wolfTurns] turns. It hits [wolfDamage] times as hard, heals [wolfHeal] of what it
/// deals, and its hide takes the edge off blows ([wolfHide]).
const wolfAt = .5, wolfTurns = 3, wolfDamage = 1.35, wolfHeal = .12, wolfHide = .8;
const peltArt = 'bloodmoonpelt';

bool wearsPelt(Knight k) => k.trinket?.art == peltArt;

/// Turns the wolf lasts for [k] (longer in the full Moonfang set).
int wolfTurnsFor(Knight k) => wolfTurns + (activeSets(k.gear).any((e) => e.$1.longWolf && e.$2 >= 3) ? longWolfTurns : 0);

/// Whether the full Nightblood set's Bloodthirst is on: under half health, heals from your blows
/// are doubled.
bool bloodthirsty(Knight k) => k.hp < maxHp(k) / 2 && activeSets(k.gear).any((e) => e.$1.bloodthirst && e.$2 >= 3);

/// A mage's unspent mana hums around them like a shield: 7% softer blows for each point held.
/// Casting spends the protection too.
double manaShield(GameState s) => s.knight.heroClass == HeroClass.mage ? 1 - .07 * s.mana : 1;

/// A foe above your level hits harder (5% a level) and shrugs off more of your blows (3% a level,
/// down to half), so a continent's own level is worth reaching before you push on.
double outmatched(int foeLevel, int heroLevel) => 1 + .05 * math.max(0, foeLevel - heroLevel);
double outmatchedHits(int foeLevel, int heroLevel) => math.max(.5, 1 - .03 * math.max(0, foeLevel - heroLevel));

/// Turns the class skill rests after use, and the companion's command.
const skillCooldown = 3, petCooldown = 3;

/// The knight's Shield Bash and the ranger's Aimed Shot hit this much harder than an attack.
const bashMult = 1.5, aimedMult = 1.15;

/// The crossbow's timing bar: a bolt loosed in the bullseye hits this much harder, one loosed at
/// the very edge only grazes. [bullseyeZone] and [trueZone] are how far from the centre (as a share
/// of half the bar) each band reaches.
const bullseye = 1.5, graze = .6, bullseyeZone = .16, trueZone = .7;

/// What a bolt loosed at [pos] (0 to 1 along the bar) is worth.
double aimAt(double pos, [double zone = bullseyeZone]) {
  final d = (pos - .5).abs() * 2;
  return d < zone ? bullseye : (d < trueZone ? 1 : graze);
}

/// The bullseye's half-width for [k]: Aim widens it a little (up to half again).
double bullseyeFor(Knight k) => math.min(bullseyeZone * 1.5, bullseyeZone + .004 * trained(k, Trait.aim));

/// The chance to get away when you flee: better for nimble heroes, worse against bosses.
/// Your chance to get away: 60% (bosses 30%) plus half your dodge, and [fleeStep] more for every
/// time you've already tried and failed this fight (the foe tires, you spot the gap). Up to 95%
/// (bosses 80%).
double fleeChance(Knight k, FoeType foe, [int tries = 0]) =>
    math.min(foe.boss ? .8 : .95, math.min(.9, (foe.boss ? .3 : .6) + dodgeChance(k, foe) * .5) + fleeStep * tries);

/// How much better your odds of fleeing get after each failed try in a fight.
const fleeStep = .15;

/// Mana you start each fight with.
int startingMana(Knight k) => 1 + (k.loadout.cape?.special == 'manawell' ? 1 : 0) + (trained(k, Trait.arcana) >= arcanaManaAt ? 1 : 0) + (brewOn(k, Brew.wisp) ? wispMana : 0);

/// Whether a shield is on your arm (the skill is a Shield Bash then; otherwise a Mighty Blow).
bool hasShield(Knight k) => _hasShield(k);

/// The knight's skill: a Shield Bash with a shield, a Mighty Blow with anything else.
String skillName(Knight k) => _hasShield(k) ? 'Shield Bash' : 'Mighty Blow';

/// What a crossbow bolt deals, as a share of an attack.
double crossbowShare(Knight k) => crossbows[k.crossbow.clamp(0, crossbows.length - 1)].$2;
