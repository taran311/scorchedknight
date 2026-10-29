// What each character wears. A look is just colours and part choices layered onto the shared rig,
// so adding a foe means adding an entry here.

import 'dart:ui';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/engine.dart' show shinesAt, sootFor;
import '../game/models.dart';
import 'paint_kit.dart';

enum Stance { knight, mage, ranger, goblin, rogue, zombie, pillager, rose, ent }

enum HeadKind {
  coif,
  bare,
  nasal,
  greathelm,
  sallet,
  wizardhat,
  cowl,
  circlet,
  scoutcap,
  rangerhood,
  rangermask,
  goblin,
  goblinChief,
  ork,
  orkShaman,
  orkWarlord,
  skull,
  skullHood,
  skullHelm,
  skullHorned,
  hood,
  zombie,
  pillager,
  pillagerCap,
  ent,
  cyclops,
  gargoyle,
  demon,
  bull,
  ghoul,
  banshee,
  witch,
  magemask,
  wyrmhelm,
  wyrmcirclet,
  pumpkin,
  // The tombs of the Sunken Sands.
  mummy,
  pharaoh,
  // The Hidden Ones: a peaked hood over a blank white mask.
  veiled,
  // A golem: a boulder for a head, eyes glowing in its cracks.
  golem,
  // Ravenmoor's vampires: deathly pale, hair slicked back to a widow's peak, red eyes and fangs.
  vampire,
  // A werewolf: a wolf's long head on a man's shoulders, ears back, teeth out.
  wolf,
  // The elves of the Silverwood: long hair, long ears swept back.
  elf,
  // The dwarves of Deepforge Hold: an iron cap with a nose-guard, a nose like a turnip, and a great
  // braided beard.
  dwarf,
  // The Faceless: a head as smooth and blank as an egg, porcelain-pale, with nothing on it at all.
  faceless,
  // The lizardfolk of the Sunscale Jungle: a long scaled snout, a crest of spines, slit eyes.
  lizard,
  // A shapeshifter in its own skin: a lumpy, half-made head with mismatched eyes that won't sit still.
  shifter,
  // The aeriekin, the bird-folk of the Skyreach: a hawk's head with a hooked beak and a crest.
  bird,
  // The Blossom Isles: a samurai's kabuto (crest, flared neck-guard, and a menpo mask if [Look.mask]
  // is set), an ashigaru's conical jingasa, a court magician's tall eboshi, a topknot, and an oni.
  kabuto,
  jingasa,
  eboshi,
  topknot,
  oni,
  // The batkin of the Hollowdeep: great splayed ears, a leaf nose, small fangs and glowing eyes.
  bat,
  // The yetis of the Frostmarch: a shaggy white mane, curled horns, a blue face and tusks.
  yeti,
}

enum TorsoKind { plain, leather, studded, scales, mail, plate, robe, fur, rags, ribs, bark, stone, lamellar, dragonplate }

enum Weapon {
  none,
  longsword,
  greatsword,
  wyrmblade,
  shortsword,
  falchion,
  dagger,
  axe,
  greataxe,
  club,
  mace,
  morningstar,
  hammer,
  staff,
  crystalstaff,
  wand,
  sceptre,
  bow,
  longbow,
  crossbow,
  tome,
  orb,
  dragondagger,
  dragonstaff,
  orkclub,
  orkbow,
  orkstaff,
  halberd,
  spear,
  scimitar,
  chakram,
  throwingknives,
  handcannon,
  cannon,
  handcrossbow,
  heartmaul,
  heartbow,
  livingstaff,
  runeblade,
  runebow,
  runestaff,
  trident,
  hook,
  fishingrod,
  kingsfall,
  // The Hidden Ones' blades, in the Reaper's image.
  sickle,
  scythe,
  // Added with the armoury: a lash, a chained flail, a throwing axe, and the elves' flowering blade.
  whip,
  flail,
  tomahawk,
  thornblade,
  // Elemental blades: a wavy flame-sword, a sword of living ice, a sun-bright blade, a blade of night.
  flamberge,
  frostbrand,
  dawnblade,
  shadowblade,
  // From the old armouries: a duellist's rapier, a glaive, and a great cleaver.
  rapier,
  glaive,
  cleaver,
  // From the Blossom Isles.
  katana,
  wakizashi,
  naginata,
  kanabo,
  yumi,
  shuriken,
  shakujo,
  fan;

  /// The shape a rune-engraved weapon is built on (its runes are drawn over it).
  Weapon get shape => switch (this) {
    runeblade => longsword,
    runebow => longbow,
    runestaff => staff,
    _ => this,
  };

  static Weapon fromArt(String? art) => Weapon.values.firstWhere((w) => w.name == art, orElse: () => Weapon.none);

  bool get isBow => this == yumi || this == bow || this == longbow || this == crossbow || this == orkbow || this == heartbow || this == runebow;
  bool get isStaff => this == shakujo || this == staff || this == crystalstaff || this == dragonstaff || this == orkstaff || this == livingstaff || this == runestaff;
  /// Thrown or fired weapons (not bows): they still use the ranger's aim-and-loose animation.
  bool get isThrown => this == chakram || this == throwingknives || this == shuriken;
  bool get isGun => this == handcannon || this == cannon;

  /// Big two-handed blades held in both hands (drawn behind the body).
  bool get bigBlade => this == greatsword || this == wyrmblade || this == kingsfall || this == cleaver;

  bool get twoHanded => this == cleaver || this == naginata || this == glaive || this == kanabo || this == greatsword || this == wyrmblade || this == greataxe || this == heartmaul || this == trident || isStaff || isBow;
}

enum ShieldKind { kite, round, buckler, tower, dragon }

class ShieldLook {
  const ShieldLook({required this.field, this.trim = const Color(0xFFC9A24E), this.kind = ShieldKind.kite});
  final Color field, trim;
  final ShieldKind kind;
}

class Look {
  const Look({
    required this.build,
    required this.stance,
    required this.skin,
    required this.torso,
    required this.upper,
    required this.fore,
    required this.hand,
    required this.thigh,
    required this.shin,
    required this.boot,
    required this.head,
    this.scale = 1,
    this.torsoKind = TorsoKind.plain,
    this.knee,
    this.elbow,
    this.pauldron,
    this.ruff,
    this.talons = false,
    this.fangCollar = false,
    this.tabard,
    this.trim,
    this.emblem,
    this.belt = const Color(0xFF3A2516),
    this.pouch = false,
    this.cape,
    this.tattered = false,
    this.capeFlow = 0,
    this.helm,
    this.plume,
    this.eyeGlow,
    this.crown = false,
    this.hair = const Color(0xFF3A2A1A),
    this.beard,
    this.hood,
    this.mask,
    this.maskTrim,
    this.weapon = Weapon.none,
    this.offhand = Weapon.none,
    this.poisoned = false,
    this.rusty = false,
    this.shield,
    this.wraps = false,
    this.gore = false,
    this.miasma = false,
    this.skirt,
    this.quiver,
    this.weaponGlow,
    this.offhandGlow,
    this.legendary = false,
    this.hatColour,
    this.weaponTint,
    this.foliage,
    this.canopy = 1,
    this.embers,
    this.bareBranches = false,
    this.berries,
    this.thorns = false,
    this.weaponRarity,
    this.wings,
    this.tail,
    this.ghostly = false,
    this.armourGlow,
    this.wyrmHorns = false,
    this.wyrmGloves = false,
    this.wyrmBoots = false,
    this.female = false,
    this.soot = 0,
    this.shine = false,
    this.engrave = 0,
    this.engraveCol,
    this.blackIron = false,
    this.kitDetail = false,
    this.sprite,
    this.bandaged = false,
    this.usekh = false,
    this.feathered = false,
  });

  final String build;
  final Stance stance;
  final double scale;
  final Ramp skin, torso, upper, fore, hand, thigh, shin, boot;
  final TorsoKind torsoKind;
  final Ramp? knee, elbow, pauldron, helm, hood, mask;
  final Color? tabard, trim, cape, plume, eyeGlow, beard, maskTrim;

  /// A fur mantle over the shoulders.
  final Color? ruff;

  /// Clawed sabatons (dragonslayer armour): the feet end in talons.
  final bool talons;

  /// A collar of dragon's fangs round the throat (any dragon armour).
  final bool fangCollar;
  final String? emblem; // 'flame' (the hero's) or 'rose'
  final Color belt, hair;
  final bool pouch, tattered, crown, poisoned, rusty, wraps, gore, miasma;
  final double capeFlow;
  final HeadKind head;
  final Weapon weapon, offhand;
  final ShieldLook? shield;

  /// Robe skirt for mages; drawn from the waist to the shins.
  final Ramp? skirt;

  /// Leather colour of a quiver worn on the back.
  final Color? quiver;

  /// Element glow on the weapon or off-hand (poison green, fire orange, frost blue, holy gold).
  final Color? weaponGlow, offhandGlow;
  final bool legendary;
  final Color? hatColour;

  /// Material colour of the main weapon (bronze, steel, yew, moonsilver...).
  final Color? weaponTint;

  /// Bat-like wings folded behind the back (gargoyles), in this stone colour.
  final Ramp? wings;

  /// The wings are feathered (harpies, the aeriekin), not bat-like.
  final bool feathered;

  /// A demon's whip-like tail with a barbed tip.
  final Ramp? tail;

  /// The held weapon's rarity colour, for its soft highlight (uncommon and up).
  final Color? weaponRarity;

  /// Leaves sprouting from an ent's head and shoulders.
  final Color? foliage;

  /// An ent's crown: how big the canopy is, whether the branches are dead and bare, and the
  /// colour of berries (or acorns) hanging in it.
  final double canopy;

  /// Glowing cracks of fire through the skin (demons).
  final Color? embers;
  final bool bareBranches;
  final Color? berries;

  /// Thorns along the back and arms.
  final bool thorns;

  /// A spirit (ghosts, banshees): see-through, faintly glowing, and trailing a wisp instead of legs.
  final bool ghostly;

  /// Enchanted or high-tier wyrmscale glows softly in its dragon's colour.
  final Color? armourGlow;

  /// A heroine: longer hair (a braid under a helm), lashes and no beard.
  final bool female;

  /// Soot from the Great Burning, 0 to 1: smudges on the face and kit, scorch marks and a wisp of
  /// smoke. It washes off as the hero levels.
  final double soot;

  /// A hero who has scrubbed off the last of the soot: a polished gleam and the odd twinkle.
  final bool shine;

  /// How finely the armour is worked: 0 plain, 1 etched scrollwork, 2 gilt filigree, 3 gilt
  /// filigree with an ember sigil that glows. [engraveCol] is the engraving's colour.
  final int engrave;
  final Color? engraveCol;

  /// Blackened iron: dark plate with cold edges, a warm glint from below, brass rivets and a
  /// skirt of overlapping lames at the waist.
  final bool blackIron;

  /// Full surface detail on the kit (plates and rivets on the limbs, mail sleeves, quilting,
  /// straps and buckles, folds in the cloth). The hero wears it.
  final bool kitDetail;

  /// A painted image to show instead of the drawn figure (see sprites.dart), if it has loaded.
  final String? sprite;

  /// Wound head to foot in old linen (the mummies): strips spiralling round every limb and the
  /// body, a few loose ends trailing.
  final bool bandaged;

  /// A broad collar of gold and blue beads across the shoulders (tomb royalty and priests).
  final bool usekh;

  /// Wyrmscale's horns: on the shoulders, elbows, forearms and knees (the armour), the knuckles
  /// (gloves), and the heels and toes (boots).
  final bool wyrmHorns, wyrmGloves, wyrmBoots;
}

/// Glow colour for a gear element, or null for plain steel.
Color? elementGlow(Stat? s) => switch (s) {
  Stat.poison => const Color(0xFF8BE05A),
  Stat.burn => const Color(0xFFFF8A2A),
  Stat.frost => const Color(0xFF9ADFFF),
  Stat.smite => const Color(0xFFFFE27A),
  _ => null,
};

const _knightMetals = <String, List<Color>>{
  // Blackened in the Great Burning and never quite scrubbed clean.
  // Steel that walked out of a fire: still grey, with the soot painted on top (body.dart).
  'chainmail': [Color(0xFFC1B7A7), Color(0xFF625B57), Color(0xFF1D1D20)],
  'plate': [Color(0xFFE0DFD7), Color(0xFF83868A), Color(0xFF24272B)],
  'gilded': [Color(0xFFFFE6A0), Color(0xFFC8943A), Color(0xFF553515)],
  'bonemail': [Color(0xFFF2EAD6), Color(0xFFBFB091), Color(0xFF55493A)],
};

const _robes = <String, int>{'apprentice': 0xFF6E6252, 'arcane': 0xFF2F4F86, 'archmage': 0xFF5A2E7A, 'astral': 0xFF1C2448, 'bonerobe': 0xFFCFC3A6, 'verdantrobe': 0xFF3E6A3A, 'oathrobe': 0xFFE8DCC0, 'emberweave': 0xFF4A1A22, 'embroidered': 0xFF6A2E3A, 'thornweave': 0xFF3A4A2A, 'warded': 0xFF2E5A6A, 'sagerobe': 0xFF8A7A5A, 'starweave': 0xFF22305A, 'voidrobe': 0xFF1A1424, 'onmyoji': 0xFFE8E4DA};
const _leathers = <String, int>{'woodsman': 0xFF7A5233, 'studded': 0xFF5E4026, 'brigandine': 0xFF3E5232, 'shadowweave': 0xFF2C2834, 'dragonhide': 0xFF2F6A46, 'bonescale': 0xFFBFB396, 'verdantleather': 0xFF4E7A3A, 'oathleather': 0xFF9A7A4A, 'emberhide': 0xFF3A2228, 'scalejerkin': 0xFF6A6A4A, 'brigandcoat': 0xFF5A2A22, 'huntleathers': 0xFF6A5030, 'wardenmail': 0xFF4A5A4A, 'nightleathers': 0xFF22222E, 'stormhide': 0xFF3A4A5E, 'shinobi': 0xFF1E2230};

HeadKind _headFor(HeroClass c, GearItem? helm) {
  if (helm == null) return c == HeroClass.knight ? HeadKind.coif : HeadKind.bare;
  return switch (helm.art) {
    'nasal' => HeadKind.nasal,
    'sallet' => HeadKind.sallet,
    'greathelm' => HeadKind.greathelm,
    'wizardhat' => HeadKind.wizardhat,
    'cowl' => HeadKind.cowl,
    'circlet' => HeadKind.circlet,
    'scoutcap' => HeadKind.scoutcap,
    'rangerhood' => HeadKind.rangerhood,
    'mask' => HeadKind.rangermask,
    'moonmask' || 'sunmask' || 'spiritmask' => HeadKind.magemask,
    'wyrmhelm' => HeadKind.wyrmhelm,
    'wyrmcirclet' => HeadKind.wyrmcirclet,
    'kabuto' => HeadKind.kabuto,
    'jingasa' => HeadKind.jingasa,
    'eboshi' => HeadKind.eboshi,
    _ => c == HeroClass.knight ? HeadKind.greathelm : HeadKind.bare,
  };
}

ShieldKind? _shieldFor(GearItem? o) => switch (o?.art) {
  'buckler' => ShieldKind.buckler,
  'kite' => ShieldKind.kite,
  'tower' => ShieldKind.tower,
  'round' => ShieldKind.round,
  'dragonshield' => ShieldKind.dragon,
  _ => null,
};

/// The colour of a pair of gloves or boots: its metal, or leather, cloth or silk by kind.
Ramp gearRamp(GearItem g) {
  if (g.tint != null) return rampOf(Color(g.tint!), .4, .5);
  return switch (g.art) {
    'spellgloves' => ramp(0xFF5A3A7A, .3, .5),
    'slippers' => ramp(0xFF6A4A7A, .3, .5),
    'bracers' => ramp(0xFF7A5233, .28, .5),
    _ => ramp(0xFF6E4A2E, .28, .5),
  };
}

/// A mage's mask colour: moonlit silver, sun gold or porcelain.
Ramp? _maskRamp(String? art) => switch (art) {
  'moonmask' => ramp(0xFFD8E2EE, .3, .5),
  'sunmask' => ramp(0xFFF2CC5A, .3, .5),
  'spiritmask' => ramp(0xFFF4F0E6, .2, .45),
  _ => null,
};

/// The dragon tier of a wyrmscale piece (from its colour), or null for anything else.
WyrmTier? _wyrmOf(GearItem? g) => g == null || g.gearSet != wyrmSet ? null : wyrmTiers.where((w) => w.argb == g.tint).firstOrNull;

/// The glow of enchanted or high-tier wyrmscale: its armour (Obsidian and Elder always glow, any
/// enchanted), or an enchanted or legendary wyrmscale helm, gloves, boots or weapon.
Color? _wyrmGlow(Loadout l) {
  final at = wyrmTierOfArmour(l.armour);
  if (at != null && (at >= 4 || l.armourEnchant != null)) return Color(wyrmTiers[at - 1].trim);
  for (final g in [l.weapon, l.helm, l.gloves, l.boots]) {
    final w = _wyrmOf(g);
    if (w != null && (g!.enchant != null || g.rarity == Rarity.legendary)) return Color(w.trim);
  }
  return null;
}

/// A wyrmscale helm's colour.
Ramp? _wyrmHelm(GearItem? helm) {
  final w = _wyrmOf(helm);
  return w == null ? null : ramp(w.argb, .32, .5);
}

/// The player's hero, built from their class, armour tier, loot and dye. Sooty at first, shining
/// by the end.
/// Everything [heroLook] depends on, as a string: equal strings draw the same hero.
String portraitSignature(Knight k) {
  final l = k.loadout;
  return [k.heroClass.name, l.armour, for (final g in [l.weapon, l.activeOffhand, l.helm, l.gloves, l.boots, l.cape, k.trinket]) g?.id, k.dye, k.gloves, k.poisonFights > 0, k.female, k.level].join('|');
}

/// [glow] lights the weapon up for a moment (a lucky Roll of Fate).
Look heroLook(Knight k, {Color? glow}) => lookFor(k.heroClass, k.loadout, dye: k.dye, gloves: k.gloves, poisoned: k.poisonFights > 0, trinket: k.trinket, female: k.female, soot: sootFor(k.level), shine: shinesAt(k.level), glow: glow);

/// A look for any class and loadout (used for the hero and the class picker).
Look lookFor(HeroClass c, Loadout l, {String dye = 'crimson', bool gloves = false, bool poisoned = false, GearItem? trinket, bool female = false, double soot = 0, bool shine = false, Color? glow}) {
  final dyeCol = Color(dyeById(dye).argb);
  final w = l.weapon, o = l.activeOffhand; // a mismatched off-hand is stowed, not held
  final gl = l.gloves == null ? null : gearRamp(l.gloves!), bt = l.boots == null ? null : gearRamp(l.boots!);
  // A cape won in battle is worn in its own colour.
  final capeCol = l.cape?.tint == null ? null : Color(l.cape!.tint!);
  final weapon = Weapon.fromArt(w?.art);
  final off = _shieldFor(o) != null ? Weapon.none : Weapon.fromArt(o?.art);
  final lit = glow ?? (poisoned ? elementGlow(Stat.poison) : elementGlow(w?.element));
  final legendary = [w, o, l.helm, trinket].any((g) => g?.rarity == Rarity.legendary);
  final skin = ramp(0xFFC99474, .25, .45);
  // Blackened mail and plate come with an iron full helm until a better one drops.
  final blackIron = c == HeroClass.knight && (l.armour == 'chainmail' || l.armour == 'plate');
  final head = blackIron && l.helm == null ? HeadKind.greathelm : _headFor(c, l.helm);
  final helmRarity = l.helm?.rarity;
  final helmSteel = helmRarity == Rarity.legendary ? _knightMetals['gilded']! : const [Color(0xFFD6DBE1), Color(0xFF8B939C), Color(0xFF3A3F46)];
  final shield = _shieldFor(o);
  switch (c) {
    case HeroClass.knight:
      final tier = armourTierById(l.armour);
      final m = tier.metal != null ? ramp(tier.metal!, .35, .5) : _knightMetals[l.armour];
      final wyrmKit = wyrmTierOfArmour(l.armour) != null;
      // Dragonslayer armour is full plate too: armoured legs, knees and elbows, no surcoat over it.
      final plate = wyrmKit || tier.look == ArmourLook.plate || (tier.look == ArmourLook.auto && (l.armour == 'plate' || l.armour == 'gilded' || l.armour == 'bonemail'));
      final cloth = ramp(0xFF5A4A3A, .25, .5), boot = bt ?? (plate && m != null ? m : ramp(0xFF4A3220, .2, .5));
      // Finer armour, finer work: etched at chainmail's protection, gilt from plate's, and the
      // best of all carries a glowing ember sigil.
      final engrave = m == null ? 0 : (tier.reduction >= .4 ? 3 : (tier.reduction >= .28 ? 2 : 1));
      final wyrm = wyrmTierOfArmour(l.armour);
      final engraveCol = wyrm != null ? Color(wyrmTiers[wyrm - 1].trim) : (engrave >= 2 ? const Color(0xFFE8C060) : shade(m?[1] ?? const Color(0xFF888888), -.5));
      const painted = {'padded': 'padded', 'chainmail': 'mail', 'plate': 'plate', 'gilded': 'gilded'};
      return Look(
        sprite: painted[l.armour] == null ? null : '${female ? 'heroine' : 'knight'}_${painted[l.armour]}',
        kitDetail: true,
        blackIron: blackIron,
        engrave: engrave,
        engraveCol: engraveCol,
        female: female,
        soot: soot,
        shine: shine,
        build: 'human',
        stance: Stance.knight,
        skin: skin,
        // Starting kit: a battered mail shirt over the gambeson.
        torso: m ?? ramp(0xFF6E7379, .3, .5),
        torsoKind: wyrmKit ? TorsoKind.dragonplate : (tier.look == ArmourLook.lamellar ? TorsoKind.lamellar : (tier.look == ArmourLook.scales ? TorsoKind.scales : (plate ? TorsoKind.plate : TorsoKind.mail))),
        // A ragged dark tasset hangs from the belt, and the cape is torn to match.
        skirt: wyrmKit ? ramp(0xFF2A2228, .2, .55) : null,
        tattered: wyrmKit,
        talons: wyrmKit,
        fangCollar: wyrmKit,
        ruff: l.armour == 'furmantle' ? const Color(0xFFB8AA96) : null,
        upper: m ?? cloth,
        fore: m ?? ramp(0xFF6E4A2E),
        hand: gl ?? (plate ? m! : (gloves ? helmSteel : ramp(0xFF5A3A22, .25, .5))),
        thigh: m ?? cloth,
        shin: plate ? m! : boot,
        boot: boot,
        knee: plate ? m : null,
        elbow: plate ? m : null,
        pauldron: plate || blackIron || wyrmTierOfArmour(l.armour) != null ? m : ramp(0xFF6E4A2E),
        // Plate is worn bare so the breastplate shows; cloth and mail wear the surcoat.
        tabard: (plate && l.armour != 'surcoat') || tier.look == ArmourLook.lamellar ? null : dyeCol,
        trim: tier.look == ArmourLook.lamellar ? const Color(0xFFE8C060) : (wyrmKit ? null : const Color(0xFFC9A24E)),
        cape: capeCol ?? shade(dyeCol, -.15),
        head: head,
        helm: _wyrmHelm(l.helm) ?? (head == HeadKind.kabuto ? _lacquer : null) ?? ((plate || blackIron) && head != HeadKind.nasal ? (blackIron ? _knightMetals['plate']! : m) : helmSteel),
        plume: head == HeadKind.greathelm || head == HeadKind.sallet ? dyeCol : null,
        armourGlow: _wyrmGlow(l),
        wyrmHorns: wyrmTierOfArmour(l.armour) != null,
        wyrmGloves: _wyrmOf(l.gloves) != null,
        wyrmBoots: _wyrmOf(l.boots) != null,
        weapon: weapon == Weapon.none ? Weapon.longsword : weapon,
        offhand: off,
        poisoned: poisoned,
        weaponGlow: lit,
        weaponTint: w?.tint == null ? null : Color(w!.tint!),
        legendary: legendary,
        weaponRarity: w == null || w.rarity == Rarity.common ? null : Color(w.rarity.argb),
        shield: shield == null ? null : ShieldLook(field: shield == ShieldKind.dragon && o!.tint != null ? Color(o.tint!) : dyeCol, kind: shield, trim: o!.rarity.index >= Rarity.epic.index ? const Color(0xFFF3DC8E) : const Color(0xFFC9A24E)),
      );
    case HeroClass.mage:
      final mw = wyrmTierOfArmour(l.armour), mwt = mw == null ? null : wyrmTiers[mw - 1];
      final robe = ramp(mwt?.argb ?? _robes[l.armour] ?? 0xFF6E6252, .3, .5);
      final trim = mwt != null ? Color(mwt.trim) : l.armour == 'onmyoji' ? const Color(0xFFB8322A) : l.armour == 'emberweave' ? const Color(0xFFFF7A3A) : l.armour == 'archmage' || l.armour == 'astral' || l.armour == 'oathrobe' ? const Color(0xFFE2C46A) : (l.armour == 'bonerobe' ? const Color(0xFF6A5A44) : shade(robe[1], .35));
      return Look(
        female: female,
        soot: soot,
        shine: shine,
        build: 'human',
        stance: Stance.mage,
        skin: skin,
        torso: robe,
        torsoKind: TorsoKind.robe,
        upper: robe,
        fore: robe,
        hand: gl ?? (gloves ? ramp(0xFF4A3A30, .25, .5) : skin),
        thigh: robe,
        shin: ramp(0xFF3A2E24, .2, .5),
        boot: bt ?? ramp(0xFF3A2A1C, .2, .5),
        skirt: robe,
        trim: trim,
        belt: dyeCol,
        pauldron: l.armour == 'astral' ? ramp(0xFF2C3A6E, .35, .5) : null,
        cape: capeCol ?? (l.armour == 'apprentice' ? null : shade(robe[1], -.25)),
        head: head,
        hatColour: dyeCol,
        helm: _wyrmHelm(l.helm) ?? _maskRamp(l.helm?.art) ?? helmSteel,
        armourGlow: _wyrmGlow(l),
        wyrmHorns: wyrmTierOfArmour(l.armour) != null,
        wyrmGloves: _wyrmOf(l.gloves) != null,
        wyrmBoots: _wyrmOf(l.boots) != null,
        // Dragon robes: a fang collar, and a hem and cape torn ragged.
        fangCollar: mw != null,
        tattered: mw != null,
        hair: const Color(0xFF5A4630),
        beard: !female && (l.armour == 'archmage' || l.armour == 'astral') ? const Color(0xFFD8D2C4) : null,
        weapon: weapon == Weapon.none ? Weapon.staff : weapon,
        offhand: off,
        weaponGlow: lit ?? const Color(0xFFFF9A3A),
        weaponTint: w?.tint == null ? null : Color(w!.tint!),
        offhandGlow: elementGlow(o?.element),
        legendary: legendary,
        weaponRarity: w == null || w.rarity == Rarity.common ? null : Color(w.rarity.argb),
      );
    case HeroClass.ranger:
      final rw = wyrmTierOfArmour(l.armour);
      final leather = ramp(rw != null ? wyrmTiers[rw - 1].argb : (_leathers[l.armour] ?? 0xFF7A5233), .28, .5);
      final dark = l.armour == 'shadowweave' || l.armour == 'shinobi' || l.armour == 'nightleathers', dragon = l.armour == 'dragonhide' || rw != null;
      return Look(
        female: female,
        soot: soot,
        shine: shine,
        build: 'lean',
        stance: Stance.ranger,
        skin: skin,
        torso: leather,
        torsoKind: dragon || l.armour == 'bonescale' || l.armour == 'scalejerkin' ? TorsoKind.scales : (l.armour == 'woodsman' || l.armour == 'shinobi' || l.armour == 'nightleathers' ? TorsoKind.leather : (l.armour == 'brigandine' || l.armour == 'wardenmail' ? TorsoKind.mail : TorsoKind.studded)),
        upper: dragon ? leather : ramp(dark ? 0xFF24222A : 0xFF4E5A3A, .25, .5),
        fore: leather,
        hand: gl ?? (gloves ? ramp(0xFF3A2A1A, .25, .5) : skin),
        thigh: dragon ? (rw != null ? rampOf(shade(Color(wyrmTiers[rw - 1].argb), -.25), .25, .5) : ramp(0xFF24523A, .25, .5)) : ramp(dark ? 0xFF1E1C22 : 0xFF4A4232, .2, .5),
        shin: dragon ? leather : ramp(0xFF4A3220, .2, .5),
        pauldron: dragon ? (rw != null ? ramp(wyrmTiers[rw - 1].argb, .35, .5) : ramp(0xFF3E7A52, .3, .5)) : null,
        boot: bt ?? ramp(0xFF3A2616, .2, .5),
        belt: const Color(0xFF2A1A0E),
        pouch: true,
        cape: capeCol ?? shade(dyeCol, -.3),
        capeFlow: 6,
        head: head,
        hood: ramp(dark ? 0xFF24202A : 0xFF3E5232, .25, .55),
        mask: ramp(0xFF2A2A26, .15, .5),
        helm: _wyrmHelm(l.helm),
        armourGlow: _wyrmGlow(l),
        wyrmHorns: wyrmTierOfArmour(l.armour) != null,
        wyrmGloves: _wyrmOf(l.gloves) != null,
        wyrmBoots: _wyrmOf(l.boots) != null,
        // Dragon leathers: a fang collar, a torn cape and clawed boots.
        fangCollar: rw != null,
        tattered: rw != null,
        talons: rw != null,
        hatColour: dyeCol,
        hair: const Color(0xFF6A4424),
        quiver: const Color(0xFF6E4A2A),
        weapon: weapon == Weapon.none ? Weapon.bow : weapon,
        offhand: off,
        weaponGlow: lit,
        weaponTint: w?.tint == null ? null : Color(w!.tint!),
        offhandGlow: elementGlow(o?.element),
        legendary: legendary,
        weaponRarity: w == null || w.rarity == Rarity.common ? null : Color(w.rarity.argb),
      );
  }
}

const _black = <Color>[Color(0xFF6E727C), Color(0xFF34373E), Color(0xFF121316)];
const _black2 = <Color>[Color(0xFF8A8E98), Color(0xFF3A3D45), Color(0xFF121316)];
const _gold = <Color>[Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
const _darkBoot = <Color>[Color(0xFF4A4D55), Color(0xFF24262B), Color(0xFF0C0D0F)];
const _bone = <Color>[Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];
const _darkBone = <Color>[Color(0xFFD8CCB0), Color(0xFF9A8C70), Color(0xFF4A402E)];


/// An ent: bark all over, roots for feet, leaves for hair.
Look _ent({required int bark, required Color foliage, required Color eyes, double scale = 1, Color? moss, bool thorns = false, bool miasma = false, double canopy = 1, bool bare = false, Color? berries}) {
  final b = ramp(bark, .22, .55), dark = ramp(bark, .1, .65);
  return Look(
    build: 'ent',
    stance: Stance.ent,
    scale: scale,
    skin: b,
    torso: b,
    torsoKind: TorsoKind.bark,
    upper: b,
    fore: b,
    hand: dark,
    thigh: b,
    shin: b,
    boot: dark,
    head: HeadKind.ent,
    eyeGlow: eyes,
    beard: moss,
    hair: foliage,
    belt: moss ?? shade(Color(bark), -.3),
    foliage: foliage,
    canopy: canopy,
    bareBranches: bare,
    berries: berries,
    thorns: thorns,
    miasma: miasma,
  );
}

final Map<String, Look> entLooks = {
  'twigling': _ent(bark: 0xFF9A7A4E, foliage: const Color(0xFF8BCB52), eyes: const Color(0xFFE8F07A), scale: .62, canopy: .55),
  'thornEnt': _ent(bark: 0xFF5A3E28, foliage: const Color(0xFF4E7A2E), eyes: const Color(0xFFFFB04A), thorns: true, canopy: .9, berries: const Color(0xFFB8283A)),
  'mossEnt': _ent(bark: 0xFF6E5C40, foliage: const Color(0xFF3E6E2E), eyes: const Color(0xFFB8F08A), moss: const Color(0xFF6A9A3E), scale: 1.05, canopy: 1.25),
  'blightEnt': _ent(bark: 0xFF3E3038, foliage: const Color(0xFF6A4A7A), eyes: const Color(0xFFC07AFF), miasma: true, thorns: true, bare: true),
  'ironEnt': _ent(bark: 0xFF70747C, foliage: const Color(0xFF7A9A9A), eyes: const Color(0xFF9ADFFF), scale: 1.15, canopy: .85),
  'oakheart': _ent(bark: 0xFF7A5634, foliage: const Color(0xFFD8782A), eyes: const Color(0xFFFFD45A), moss: const Color(0xFF6A8A3A), scale: 1.5, canopy: 1.7, thorns: true, berries: const Color(0xFF8A5A2A)),
};

Look _gargoyle({double scale = 1.15, int stone = 0xFF8A8C90, Color eyes = const Color(0xFFB07AFF)}) {
  final s = ramp(stone, .25, .55);
  return Look(
    build: 'brute',
    scale: scale,
    stance: Stance.goblin,
    skin: s,
    torso: s,
    torsoKind: TorsoKind.stone,
    upper: s,
    fore: s,
    hand: ramp(stone, .15, .6),
    thigh: s,
    shin: s,
    boot: ramp(stone, .15, .6),
    belt: shade(Color(stone), -.4),
    head: HeadKind.gargoyle,
    eyeGlow: eyes,
    wings: ramp(stone, .2, .6),
  );
}

Look _demon({String build = 'brute', double scale = 1.1, int hide = 0xFFA8302A, Weapon weapon = Weapon.spear, bool wings = false, Color eyes = const Color(0xFFFFD45A)}) {
  final h = ramp(hide, .25, .55), dark = ramp(hide, .1, .65);
  return Look(
    build: build,
    scale: scale,
    stance: Stance.knight,
    skin: h,
    torso: h,
    upper: h,
    fore: h,
    hand: dark,
    thigh: ramp(0xFF2A1A18, .2, .5),
    shin: dark,
    boot: const [Color(0xFF4A3A30), Color(0xFF241A14), Color(0xFF0C0806)],
    belt: const Color(0xFF1A0E0A),
    head: HeadKind.demon,
    eyeGlow: eyes,
    weapon: weapon,
    weaponGlow: const Color(0xFFFF6A1A),
    wings: wings ? ramp(0xFF5A1A18, .2, .6) : null,
    tail: dark,
    pauldron: wings ? const [Color(0xFF8A8E98), Color(0xFF3A3D45), Color(0xFF121316)] : null,
    embers: const Color(0xFFFFA03A),
  );
}

/// A spirit: a hooded shape (or a banshee's wailing face) in a trailing robe, see-through.
Look _spirit({required int robe, HeadKind head = HeadKind.hood, Color eyes = const Color(0xFF9ADFFF), double scale = 1, Color hair = const Color(0xFFE8F0F4), bool crown = false}) {
  final r = ramp(robe, .3, .55);
  return Look(
    build: 'lean',
    scale: scale,
    stance: Stance.mage,
    skin: ramp(0xFFDCE8EE, .2, .5),
    torso: r,
    torsoKind: TorsoKind.robe,
    upper: r,
    fore: r,
    hand: ramp(0xFFDCE8EE, .2, .5),
    thigh: r,
    shin: r,
    boot: r,
    skirt: r,
    head: head,
    hood: r,
    hair: hair,
    eyeGlow: eyes,
    tattered: true,
    cape: shade(Color(robe), -.2),
    capeFlow: 14,
    crown: crown,
    ghostly: true,
  );
}

/// A ghoul: gaunt grey-green flesh in rags, hunched, with long claws.
Look _ghoul({double scale = 1, bool king = false}) {
  final flesh = ramp(king ? 0xFF7A8A6A : 0xFF8A9A7A, .2, .55);
  return Look(
    build: king ? 'brute' : 'lean',
    scale: scale,
    stance: Stance.goblin,
    skin: flesh,
    torso: ramp(0xFF4A4436, .2, .5),
    torsoKind: TorsoKind.rags,
    upper: flesh,
    fore: flesh,
    hand: ramp(0xFF6A7A5A, .2, .55),
    thigh: ramp(0xFF3A362A, .2, .5),
    shin: flesh,
    boot: flesh,
    belt: const Color(0xFF2A241A),
    head: HeadKind.ghoul,
    hair: const Color(0xFF3A3A30),
    eyeGlow: king ? const Color(0xFFFF6A3A) : const Color(0xFFD8F07A),
    wraps: true,
    gore: true,
    crown: king,
    cape: king ? const Color(0xFF3A2A2A) : null,
    tattered: true,
    weapon: king ? Weapon.greataxe : Weapon.none,
  );
}

/// A witch (or the Coven Mother): green skin, a black robe, a crooked hat and a wand.
Look _witch({double scale = 1, bool mother = false}) {
  final robe = ramp(mother ? 0xFF2A1A3A : 0xFF24202A, .3, .5);
  return Look(
    build: 'lean',
    scale: scale,
    stance: Stance.mage,
    skin: ramp(0xFF8AB06A, .25, .5),
    torso: robe,
    torsoKind: TorsoKind.robe,
    upper: robe,
    fore: robe,
    hand: ramp(0xFF8AB06A, .25, .5),
    thigh: robe,
    shin: ramp(0xFF1E1A20, .2, .5),
    boot: ramp(0xFF1A1418, .2, .5),
    skirt: robe,
    trim: mother ? const Color(0xFFB07AFF) : const Color(0xFF6A3A8A),
    belt: const Color(0xFF4A2A5A),
    pouch: true,
    head: HeadKind.witch,
    hatColour: mother ? const Color(0xFF2A1A3A) : const Color(0xFF1E1A24),
    hair: mother ? const Color(0xFFE8E4DA) : const Color(0xFF3A3A3A),
    eyeGlow: mother ? const Color(0xFFE07AFF) : const Color(0xFFB8F05A),
    cape: mother ? const Color(0xFF1A0E24) : null,
    tattered: true,
    weapon: mother ? Weapon.staff : Weapon.wand,
    weaponGlow: mother ? const Color(0xFFE07AFF) : const Color(0xFF8BE05A),
    offhand: mother ? Weapon.orb : Weapon.none,
    offhandGlow: const Color(0xFF8BE05A),
  );
}

/// An unholy wizard: a deep hood with burning eyes, a black-and-crimson robe and a skull staff.
Look _warlock({double scale = 1, bool arch = false}) {
  final robe = ramp(arch ? 0xFF3A0E14 : 0xFF1E1A22, .3, .5);
  return Look(
    build: 'human',
    scale: scale,
    stance: Stance.mage,
    skin: ramp(0xFFB8A8A0, .2, .5),
    torso: robe,
    torsoKind: TorsoKind.robe,
    upper: robe,
    fore: robe,
    hand: ramp(0xFF8A7A78, .2, .5),
    thigh: robe,
    shin: ramp(0xFF1A1418, .2, .5),
    boot: ramp(0xFF14100E, .2, .5),
    skirt: robe,
    trim: const Color(0xFFB8302A),
    belt: const Color(0xFF2A0A0A),
    head: arch ? HeadKind.skullHood : HeadKind.hood,
    hood: ramp(arch ? 0xFF2A0A10 : 0xFF14121A, .3, .5),
    eyeGlow: arch ? const Color(0xFFFF3A2A) : const Color(0xFFC07AFF),
    cape: arch ? const Color(0xFF14060A) : const Color(0xFF0E0C12),
    tattered: true,
    capeFlow: 8,
    pauldron: arch ? _darkBone : null,
    weapon: arch ? Weapon.orkstaff : Weapon.staff,
    weaponGlow: arch ? const Color(0xFFFF3A2A) : const Color(0xFFC07AFF),
    miasma: arch,
  );
}

/// A minotaur: a bull-headed brute in a loincloth with a huge axe.
Look _minotaur({double scale = 1.15, bool lord = false}) {
  final hide = ramp(lord ? 0xFF4A2E22 : 0xFF7A4A30, .25, .55), dark = ramp(lord ? 0xFF2A1A12 : 0xFF4A2A18, .15, .6);
  return Look(
    build: lord ? 'giant' : 'brute',
    scale: scale,
    stance: Stance.knight,
    skin: hide,
    torso: hide,
    torsoKind: TorsoKind.fur,
    upper: hide,
    fore: hide,
    hand: dark,
    thigh: ramp(0xFF5A3A28, .2, .5),
    shin: dark,
    boot: const [Color(0xFF3A3434), Color(0xFF1A1616), Color(0xFF080606)],
    belt: const Color(0xFF3A2414),
    head: HeadKind.bull,
    eyeGlow: lord ? const Color(0xFFFF4A2A) : const Color(0xFFE84A2A),
    weapon: Weapon.greataxe,
    pauldron: lord ? _black : null,
    knee: lord ? _black : null,
    tail: dark,
    rusty: !lord,
  );
}

/// A centaur's upper half (drawn on a horse's body): bare-chested, a bow and a quiver.
Look _centaur({bool chief = false}) {
  final skin = ramp(0xFFC08A62, .25, .5);
  return Look(
    build: 'human',
    scale: chief ? 1.1 : 1,
    stance: Stance.ranger,
    skin: skin,
    torso: chief ? _black : skin,
    torsoKind: chief ? TorsoKind.plate : TorsoKind.plain,
    upper: skin,
    fore: skin,
    hand: skin,
    thigh: skin,
    shin: skin,
    boot: skin,
    belt: const Color(0xFF4A3420),
    head: chief ? HeadKind.sallet : HeadKind.bare,
    helm: chief ? _black2 : null,
    plume: chief ? const Color(0xFFE8E4DA) : null,
    hair: const Color(0xFF3A2A1A),
    beard: chief ? const Color(0xFF6A5A4A) : null,
    quiver: const Color(0xFF6E4A2A),
    weapon: chief ? Weapon.spear : Weapon.longbow,
    pauldron: chief ? _black2 : null,
  );
}

/// A golem: a hulking thing of living rock with veins of ore ([ore]) running through it and eyes
/// that glow in its cracks. Iron, gold or black glass.
Look _golem({required int stone, required Color ore, required Color eyes, double scale = 1.25}) {
  final s = ramp(stone, .22, .6);
  return Look(
    build: 'giant',
    scale: scale,
    stance: Stance.knight,
    skin: s,
    torso: s,
    torsoKind: TorsoKind.stone,
    upper: s,
    fore: s,
    hand: ramp(stone, .12, .62),
    thigh: s,
    shin: s,
    boot: ramp(stone, .12, .62),
    belt: shade(Color(stone), -.45),
    trim: ore,
    head: HeadKind.golem,
    eyeGlow: eyes,
  );
}

/// The Hidden Ones, a clan who worship the Reaper: ash-grey robes with a blood-red sash, deep
/// peaked hoods and blank white masks. Acolytes carry a sickle in his image; Blades carry two;
/// Hexers carry a lantern-staff whose light is the colour of his eyes; the Veiled Prior carries a
/// scythe like his own, and a gilded mask.
Look _hidden({String rank = 'acolyte'}) {
  final prior = rank == 'prior', hexer = rank == 'hexer', blade = rank == 'blade';
  final robe = ramp(prior ? 0xFF2A1C24 : (hexer ? 0xFF2E2A34 : 0xFF4A4448), .28, .5);
  final dark = ramp(prior ? 0xFF180E14 : 0xFF241E22, .2, .5);
  const reaperEyes = Color(0xFF9CF6E6);
  return Look(
    build: blade ? 'lean' : 'human',
    scale: prior ? 1.12 : 1,
    stance: hexer ? Stance.mage : (blade ? Stance.rogue : Stance.knight),
    skin: ramp(0xFFCFC6B8, .2, .5),
    torso: robe,
    torsoKind: TorsoKind.robe,
    upper: robe,
    fore: dark,
    hand: ramp(0xFF2A2226, .2, .5),
    thigh: robe,
    shin: dark,
    boot: ramp(0xFF141012, .2, .5),
    skirt: robe,
    trim: prior ? const Color(0xFFD8B860) : const Color(0xFF8A1E24),
    belt: const Color(0xFF8A1E24),
    head: HeadKind.veiled,
    hood: ramp(prior ? 0xFF1E1218 : (hexer ? 0xFF1C1820 : 0xFF2E282C), .3, .5),
    mask: prior ? const [Color(0xFFFFF0B8), Color(0xFFD8B860), Color(0xFF7A5A20)] : null,
    maskTrim: prior ? const Color(0xFF8A1E24) : null,
    eyeGlow: hexer || prior ? reaperEyes : null,
    cape: prior ? const Color(0xFF120A0E) : const Color(0xFF1E1A1C),
    tattered: true,
    capeFlow: prior ? 10 : 6,
    weapon: prior ? Weapon.scythe : (hexer ? Weapon.staff : Weapon.sickle),
    offhand: blade ? Weapon.sickle : Weapon.none,
    weaponGlow: hexer ? reaperEyes : null,
    miasma: prior,
  );
}


/// The Ashen Order: knights who knelt to Vharrax when the world burned. Ash-grey plate gone dark at
/// the edges, ember-red trim and eyes glowing in the slits of their helms. Knights carry a sword and
/// a kite shield with the Order's colours; champions a burning greatsword; Sir Malric, their
/// best, a burning greatsword and the tattered banner of the Order he betrayed.
Look _ashen({String rank = 'knight'}) {
  final champion = rank == 'champion', malric = rank == 'malric';
  final plate = ramp(malric ? 0xFF5A5A62 : (champion ? 0xFF4E4E56 : 0xFF6A6A72), .32, .55);
  const ember = Color(0xFFFF6A2A);
  return Look(
    build: champion ? 'brute' : 'human',
    scale: champion ? 1.22 : (malric ? 1.12 : 1.05),
    stance: champion || malric ? Stance.rose : Stance.knight,
    skin: ramp(0xFFB89478),
    torso: plate,
    torsoKind: TorsoKind.plate,
    upper: plate,
    fore: plate,
    hand: plate,
    thigh: plate,
    shin: plate,
    boot: _darkBoot,
    knee: plate,
    elbow: plate,
    pauldron: champion || malric ? _black : plate,
    tabard: malric ? const Color(0xFF5A2A1A) : const Color(0xFF34343A),
    trim: ember,
    belt: const Color(0xFF1A120C),
    cape: malric ? const Color(0xFF2A1A16) : (champion ? const Color(0xFF241E1E) : const Color(0xFF3A3A40)),
    tattered: true,
    capeFlow: malric ? 18 : (champion ? 12 : 4),
    head: HeadKind.sallet,
    helm: plate,
    eyeGlow: ember,
    plume: champion || malric ? const Color(0xFFC8401E) : null,
    blackIron: true,
    kitDetail: malric,
    weapon: champion || malric ? Weapon.greatsword : Weapon.longsword,
    weaponGlow: champion || malric ? const Color(0xFFFF8A3A) : null,
    shield: champion || malric ? null : const ShieldLook(field: Color(0xFF2E2E34), trim: ember, kind: ShieldKind.kite),
  );
}

/// Ravenmoor's thralls: grey-faced farmhands in rags, eyes down, a pitchfork in hand.
Look _thrall() {
  final rags = ramp(0xFF6A5E52, .25, .5), skin = ramp(0xFFC8B8B0, .2, .5);
  return Look(
    build: 'lean',
    stance: Stance.zombie,
    skin: skin,
    torso: rags,
    torsoKind: TorsoKind.rags,
    upper: rags,
    fore: skin,
    hand: skin,
    thigh: ramp(0xFF4A4038, .2, .5),
    shin: ramp(0xFF4A4038, .2, .5),
    boot: ramp(0xFF2E2620, .2, .5),
    belt: const Color(0xFF3A2A1E),
    head: HeadKind.bare,
    hair: const Color(0xFF6A645E),
    weapon: Weapon.spear,
  );
}

/// The vampires of Ravenmoor: deathly pale, red-eyed and fanged. Spawn in torn shirts, Blood Brides
/// in white gowns stained red, Vampire Knights in black plate and a red-lined cape, and the
/// Countess herself in a crimson gown with a crown and a sceptre that drinks the light.
Look _vampire({String rank = 'spawn'}) {
  final bride = rank == 'bride', knight = rank == 'knight', countess = rank == 'countess';
  final skin = ramp(0xFFE2D8DC, .15, .45);
  const red = Color(0xFFFF2A3A);
  final gown = ramp(countess ? 0xFF6A0E1E : 0xFFE8E0E0, .25, .5);
  final shirt = ramp(0xFF2A1A22, .3, .5);
  final dress = bride || countess;
  return Look(
    build: knight ? 'human' : 'lean',
    scale: countess ? 1.2 : (knight ? 1.1 : 1),
    stance: dress ? Stance.mage : (knight ? Stance.knight : Stance.rogue),
    skin: skin,
    torso: knight ? _black : (dress ? gown : shirt),
    torsoKind: knight ? TorsoKind.plate : (dress ? TorsoKind.robe : TorsoKind.rags),
    upper: knight ? _black : (dress ? gown : shirt),
    fore: knight ? _black : skin,
    hand: knight ? _black : skin,
    thigh: knight ? _black : ramp(0xFF1E1418, .3, .5),
    shin: knight ? _black : ramp(0xFF1E1418, .3, .5),
    boot: _darkBoot,
    skirt: dress ? gown : null,
    pauldron: knight ? _black : null,
    elbow: knight ? _black : null,
    knee: knight ? _black : null,
    tabard: knight ? const Color(0xFF5A0E18) : null,
    trim: countess ? const Color(0xFFD8B860) : const Color(0xFF8A1424),
    belt: const Color(0xFF2A0E14),
    cape: knight || countess ? const Color(0xFF14080C) : null,
    capeFlow: countess ? 18 : 10,
    head: HeadKind.vampire,
    hair: const Color(0xFF16121A),
    eyeGlow: red,
    female: dress,
    crown: countess,
    weapon: countess ? Weapon.sceptre : (knight ? Weapon.longsword : (bride ? Weapon.dagger : Weapon.none)),
    weaponGlow: countess || bride ? red : null,
    miasma: countess,
  );
}

/// A woodsman of the Howling Weald, friendly by day: leather, a beard and an axe.
Look _woodsman() {
  final leather = ramp(0xFF6A4A2E, .28, .5), skin = ramp(0xFFC08A62);
  return Look(
    build: 'human',
    stance: Stance.knight,
    skin: skin,
    torso: ramp(0xFF7A3A2A, .25, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF7A3A2A, .25, .5),
    fore: skin,
    hand: skin,
    thigh: leather,
    shin: leather,
    boot: ramp(0xFF3A2A1C, .2, .5),
    belt: const Color(0xFF2A1A0E),
    pouch: true,
    head: HeadKind.bare,
    hair: const Color(0xFF5A3A22),
    beard: const Color(0xFF6A4226),
    weapon: Weapon.axe,
  );
}

/// A werewolf: a wolf stood up on a man's legs, hunched, all fur and claws. Stalkers are lean and
/// dark, Silverbacks huge and grey, and the Alpha black with a red moon in its eyes.
Look _werewolf({int fur = 0xFF6A6460, Color eyes = const Color(0xFFFFD84A), String build = 'brute', double scale = 1.12}) {
  final hide = ramp(fur, .25, .55), dark = ramp(fur, .12, .65);
  return Look(
    build: build,
    scale: scale,
    stance: Stance.knight,
    skin: hide,
    torso: hide,
    torsoKind: TorsoKind.fur,
    upper: hide,
    fore: hide,
    hand: dark,
    thigh: hide,
    shin: dark,
    boot: dark,
    belt: shade(Color(fur), -.5),
    head: HeadKind.wolf,
    eyeGlow: eyes,
    tail: dark,
  );
}

/// You, as the wolf: what the Bloodmoon Pelt makes of you for a few turns.
final wolfformLook = _werewolf(fur: 0xFF7A4A3A, eyes: const Color(0xFFFF4A3A), scale: 1.0);

/// The elves of the Silverwood, who shut their forest to the world after the Burning. Silver-green
/// leather and pale gold: rangers with longbows, spellblades with a curved blade, wardens in
/// leaf-shaped plate with a glaive, druids with a living staff, and Queen Ithriel in white and gold.
Look _elf({String rank = 'ranger'}) {
  final warden = rank == 'warden', druid = rank == 'druid', queen = rank == 'queen', blade = rank == 'blade';
  final skin = ramp(0xFFE8CFB4, .18, .45);
  final leaf = ramp(queen ? 0xFFE8E4D4 : (druid ? 0xFF4A6A3A : 0xFF5A7A5A), .3, .5);
  final plate = ramp(0xFFC8D0C4, .3, .5);
  const gold = Color(0xFFE0C068);
  final robe = druid || queen;
  return Look(
    build: 'lean',
    scale: queen ? 1.18 : (warden ? 1.08 : 1.02),
    stance: robe ? Stance.mage : (rank == 'ranger' ? Stance.ranger : (blade ? Stance.rogue : Stance.knight)),
    skin: skin,
    torso: warden ? plate : leaf,
    torsoKind: warden ? TorsoKind.plate : (robe ? TorsoKind.robe : TorsoKind.leather),
    upper: warden ? plate : leaf,
    fore: warden ? plate : skin,
    hand: warden ? plate : ramp(0xFF6A5A3A, .25, .5),
    thigh: warden ? plate : ramp(0xFF4A5A44, .25, .5),
    shin: warden ? plate : ramp(0xFF3A4A34, .25, .5),
    boot: ramp(0xFF5A4630, .25, .5),
    skirt: robe ? leaf : null,
    pauldron: warden ? plate : null,
    trim: gold,
    belt: const Color(0xFF6A5030),
    cape: queen ? const Color(0xFFE8E0C8) : (warden ? const Color(0xFF3E5A3A) : const Color(0xFF2E4A30)),
    capeFlow: queen ? 16 : 6,
    head: HeadKind.elf,
    hair: queen ? const Color(0xFFF2E6B8) : (druid ? const Color(0xFF8A6A3A) : const Color(0xFFD8C890)),
    female: queen || druid,
    crown: queen,
    eyeGlow: queen ? const Color(0xFFBFF0FF) : null,
    quiver: rank == 'ranger' ? const Color(0xFF6E5030) : null,
    weapon: switch (rank) {
      'ranger' => Weapon.longbow,
      'blade' => Weapon.scimitar,
      'warden' => Weapon.halberd,
      'druid' => Weapon.livingstaff,
      _ => Weapon.crystalstaff,
    },
    offhand: blade ? Weapon.dagger : Weapon.none,
    weaponTint: const Color(0xFFDCE4E8),
    weaponGlow: queen ? const Color(0xFFBFF0FF) : (druid ? const Color(0xFF8BE05A) : null),
  );
}

/// The dwarves of Deepforge Hold, gone strange in the dark since the Burning: forge-blackened mail
/// and iron caps, great beards, axes, hammers and heavy crossbows. Shieldbearers hide behind tower
/// shields; rune-priests' hammers glow; the Thane wears gold and a crown on his helm.
Look _dwarf({String rank = 'axe'}) {
  final thane = rank == 'thane', shield = rank == 'shield', rune = rank == 'rune', xbow = rank == 'xbow';
  final mail = ramp(thane ? 0xFF8A7A5A : 0xFF6A6E76, .3, .5);
  final leather = ramp(0xFF5A3E26, .25, .5);
  return Look(
    build: 'dwarf',
    scale: thane ? 1.12 : 1,
    stance: xbow ? Stance.ranger : (rune ? Stance.mage : Stance.knight),
    skin: ramp(0xFFD49A78),
    torso: mail,
    torsoKind: shield || thane ? TorsoKind.plate : TorsoKind.mail,
    upper: mail,
    fore: leather,
    hand: leather,
    thigh: leather,
    shin: mail,
    boot: ramp(0xFF3A2A1C, .2, .5),
    pauldron: shield || thane ? (thane ? _gold : mail) : null,
    knee: shield || thane ? mail : null,
    tabard: rune ? const Color(0xFF2A4A7A) : (thane ? const Color(0xFF7A1E1A) : null),
    trim: const Color(0xFFD8B860),
    belt: const Color(0xFF3A2416),
    head: HeadKind.dwarf,
    helm: thane ? _gold : null,
    beard: switch (rank) {
      'thane' => const Color(0xFFE8E0D0),
      'rune' => const Color(0xFFC8C0B0),
      'shield' => const Color(0xFF3A2A20),
      'xbow' => const Color(0xFFB0602A),
      _ => const Color(0xFF8A4A22),
    },
    crown: thane,
    eyeGlow: rune ? const Color(0xFF7AC8FF) : null,
    weapon: switch (rank) {
      'shield' || 'rune' || 'thane' => Weapon.hammer,
      'xbow' => Weapon.crossbow,
      _ => Weapon.axe,
    },
    weaponGlow: rune ? const Color(0xFF7AC8FF) : (thane ? const Color(0xFFFF9A3A) : null),
    shield: shield ? const ShieldLook(field: Color(0xFF5A4A3A), trim: Color(0xFFD8B860), kind: ShieldKind.tower) : null,
  );
}

/// An elemental: a body of living fire, ice or bog in a man's shape, its legs trailing away into a
/// wisp, its element running through it in glowing veins and glowing in its eyes.
Look _elemental({required int body, required Color vein, required Color eyes, Color? embers}) {
  final b = ramp(body, .3, .55);
  return Look(
    build: 'brute',
    scale: 1.15,
    stance: Stance.mage,
    skin: b,
    torso: b,
    torsoKind: TorsoKind.stone,
    upper: b,
    fore: b,
    hand: ramp(body, .4, .45),
    thigh: b,
    shin: b,
    boot: b,
    belt: shade(Color(body), -.45),
    trim: vein,
    head: HeadKind.golem,
    eyeGlow: eyes,
    embers: embers,
    ghostly: true,
    weaponGlow: vein,
  );
}

/// The Faceless of the Isle of Mists, who gave their faces to the fog after the Burning. Grey,
/// tattered robes and blank porcelain heads. Wanderers carry a hooked blade; Mimics wear a borrowed
/// knight's kit; the Choir carry lanterns; Wardens wear grey plate; the Mother of Masks wears every
/// face she ever took, circling her head.
Look _faceless({String rank = 'wanderer'}) {
  final mimic = rank == 'mimic', choir = rank == 'choir', warden = rank == 'warden', mother = rank == 'mother';
  final robe = ramp(mother ? 0xFF3A3640 : (choir ? 0xFF6A6670 : 0xFF5A5A5E), .3, .5);
  final skin = ramp(0xFFE8E2DA, .15, .4);
  final plate = ramp(0xFF8A8E94, .3, .5);
  return Look(
    build: mother ? 'human' : 'lean',
    scale: mother ? 1.25 : (warden ? 1.08 : 1),
    stance: choir || mother ? Stance.mage : (mimic ? Stance.knight : Stance.rogue),
    skin: skin,
    torso: warden || mimic ? plate : robe,
    torsoKind: warden || mimic ? TorsoKind.plate : TorsoKind.robe,
    upper: warden || mimic ? plate : robe,
    fore: warden || mimic ? plate : robe,
    hand: skin,
    thigh: warden || mimic ? plate : robe,
    shin: warden || mimic ? plate : robe,
    boot: ramp(0xFF2A2A2E, .2, .5),
    skirt: choir || mother ? robe : null,
    pauldron: warden || mimic ? plate : null,
    tabard: mimic ? const Color(0xFF8A1E22) : null,
    trim: mother ? const Color(0xFFD8D0C0) : const Color(0xFF3A3A40),
    belt: const Color(0xFF2A2A2E),
    cape: mother ? const Color(0xFF1E1C22) : const Color(0xFF4A4A50),
    tattered: true,
    capeFlow: mother ? 18 : 8,
    head: HeadKind.faceless,
    hood: choir ? robe : null,
    crown: mother,
    weapon: switch (rank) {
      'mimic' => Weapon.longsword,
      'choir' => Weapon.staff,
      'warden' => Weapon.halberd,
      'mother' => Weapon.sceptre,
      _ => Weapon.hook,
    },
    shield: mimic ? const ShieldLook(field: Color(0xFF8A1E22), kind: ShieldKind.kite) : null,
    weaponGlow: choir || mother ? const Color(0xFFD8E0E8) : null,
    miasma: mother,
  );
}

/// The lizardfolk of the Sunscale Jungle: scaled hide in jungle greens and golds, a crest of
/// spines and a long tail. Scaleguards carry a spear and a round shield; skirmishers throw
/// javelins; shamans carry a bone staff with a sun-disc; champions are huge, in bronze, with a
/// greataxe; King Ssarrak wears a crown of sun-gold.
Look _lizard({String rank = 'guard'}) {
  final king = rank == 'king', champ = rank == 'champion', shaman = rank == 'shaman', skirm = rank == 'skirmisher';
  final hide = ramp(king ? 0xFF8A7A2A : (shaman ? 0xFF4A7A6A : (champ ? 0xFF4A6A2A : 0xFF5A8A3A)), .3, .55);
  final belly = ramp(0xFFD8C88A, .2, .5);
  const bronze = <Color>[Color(0xFFE8B878), Color(0xFFB0783A), Color(0xFF5A3A16)];
  return Look(
    build: champ || king ? 'brute' : 'lean',
    scale: king ? 1.4 : (champ ? 1.25 : 1.02),
    stance: shaman ? Stance.mage : (skirm ? Stance.ranger : Stance.knight),
    skin: hide,
    torso: champ || king ? bronze : belly,
    torsoKind: champ || king ? TorsoKind.scales : (shaman ? TorsoKind.robe : TorsoKind.scales),
    upper: hide,
    fore: hide,
    hand: hide,
    thigh: hide,
    shin: hide,
    boot: ramp(0xFF3A4A22, .2, .5),
    skirt: shaman ? ramp(0xFF8A3A2A, .3, .5) : null,
    pauldron: champ || king ? bronze : null,
    belt: const Color(0xFF5A3A1E),
    trim: const Color(0xFFE8C060),
    head: HeadKind.lizard,
    eyeGlow: king ? const Color(0xFFFFD84A) : const Color(0xFFE8D040),
    crown: king,
    tail: hide,
    weapon: switch (rank) {
      'skirmisher' => Weapon.spear,
      'shaman' => Weapon.staff,
      'champion' => Weapon.greataxe,
      'king' => Weapon.trident,
      _ => Weapon.spear,
    },
    weaponGlow: shaman ? const Color(0xFFFFD27A) : null,
    shield: rank == 'guard' ? const ShieldLook(field: Color(0xFF6A4A26), trim: Color(0xFFE8C060), kind: ShieldKind.round) : null,
  );
}

/// The merrow of the Shattered Sea: fish-folk in sea-green scale, with a fin for a crest, coral
/// and shell for armour, tridents and nets. Tidecallers carry a coral staff that drips; reef
/// guards wear shell plate and carry a big round shield.
Look _merrow({String rank = 'raider'}) {
  final caller = rank == 'caller', guard = rank == 'guard';
  final hide = ramp(caller ? 0xFF4A8AAA : 0xFF4A9A8A, .3, .55);
  final shell = ramp(0xFFE8B8A0, .25, .5);
  return Look(
    build: guard ? 'brute' : 'lean',
    scale: guard ? 1.12 : 1,
    stance: caller ? Stance.mage : Stance.knight,
    skin: hide,
    torso: guard ? shell : ramp(0xFFD8E0C8, .2, .5),
    torsoKind: guard ? TorsoKind.plate : TorsoKind.scales,
    upper: hide,
    fore: hide,
    hand: hide,
    thigh: hide,
    shin: hide,
    boot: ramp(0xFF2A5A5A, .2, .5),
    skirt: caller ? ramp(0xFF2A6A7A, .3, .5) : null,
    pauldron: guard ? shell : null,
    belt: const Color(0xFF3A5A4A),
    trim: const Color(0xFFF2D2C4),
    head: HeadKind.lizard,
    plume: caller ? const Color(0xFF8AE0F0) : const Color(0xFFE06A4A),
    eyeGlow: const Color(0xFFCFFFF0),
    tail: hide,
    weapon: caller ? Weapon.staff : Weapon.trident,
    weaponGlow: caller ? const Color(0xFF8AE0F0) : null,
    weaponTint: const Color(0xFFE8B8A0),
    shield: guard ? const ShieldLook(field: Color(0xFFE8B8A0), trim: Color(0xFF4A9A8A), kind: ShieldKind.round) : null,
  );
}

/// The changelings of the Changeling Isle, in their own skin: grey-violet and half-made, their
/// bodies not quite sure what shape they are, a shimmer coming off them like heat.
Look _shifter({String rank = 'changeling'}) {
  final hulk = rank == 'hulk', sly = rank == 'sly', boss = rank == 'thousandfold';
  final skin = ramp(boss ? 0xFF6A5A8A : 0xFF8A7AA0, .3, .55);
  return Look(
    build: hulk || boss ? 'brute' : 'lean',
    scale: boss ? 1.3 : (hulk ? 1.2 : 1),
    stance: sly ? Stance.rogue : Stance.zombie,
    skin: skin,
    torso: skin,
    torsoKind: TorsoKind.plain,
    upper: skin,
    fore: skin,
    hand: ramp(boss ? 0xFF4A3A6A : 0xFF6A5A80, .3, .5),
    thigh: skin,
    shin: skin,
    boot: skin,
    belt: shade(Color(boss ? 0xFF6A5A8A : 0xFF8A7AA0), -.45),
    head: HeadKind.shifter,
    eyeGlow: const Color(0xFFA0F0E0),
    miasma: true,
    crown: boss,
    offhand: sly ? Weapon.dagger : Weapon.none,
    weapon: sly ? Weapon.dagger : Weapon.none,
  );
}

const _lacquer = <Color>[Color(0xFF5A4A4A), Color(0xFF2A2024), Color(0xFF0E0A0C)];

/// The Blossom Isles: masterless ronin with topknots and katanas, ashigaru in jingasa hats with
/// yari, shinobi in black with throwing stars, onmyoji court magicians in white and tall eboshi,
/// great red oni with iron clubs, and the Shogun himself in black-and-gold lamellar and a menpo.
Look _blossom({String rank = 'ronin'}) {
  final oni = rank == 'oni', shogun = rank == 'shogun', ninja = rank == 'shinobi', mage = rank == 'onmyoji', foot = rank == 'ashigaru';
  final skin = oni ? ramp(rank == 'oni' ? 0xFFB8322A : 0xFF3A5AA8, .25, .5) : ramp(0xFFE0B48C, .25, .45);
  final cloth = ramp(switch (rank) {
    'shinobi' => 0xFF1E2230,
    'onmyoji' => 0xFFE8E4DA,
    'ashigaru' => 0xFF3A3A42,
    'shogun' => 0xFF2A2024,
    'oni' => 0xFF6A5A3A,
    _ => 0xFF2E3A5A,
  }, .3, .5);
  final plates = shogun ? _lacquer : ramp(0xFF6A2A22, .3, .5);
  return Look(
    build: oni ? 'giant' : (ninja ? 'lean' : 'human'),
    scale: oni ? 1.35 : (shogun ? 1.2 : 1),
    stance: mage ? Stance.mage : (ninja ? Stance.rogue : Stance.knight),
    skin: skin,
    torso: oni ? skin : (shogun || foot ? plates : cloth),
    torsoKind: oni ? TorsoKind.plain : (shogun || foot ? TorsoKind.lamellar : (mage ? TorsoKind.robe : TorsoKind.leather)),
    upper: oni ? skin : cloth,
    fore: oni || rank == 'ronin' ? skin : cloth,
    hand: oni ? skin : (ninja ? cloth : ramp(0xFF3A2A20, .25, .5)),
    thigh: oni ? ramp(0xFFE8D8A0, .25, .5) : cloth,
    shin: oni ? skin : (shogun || foot ? plates : cloth),
    boot: oni ? skin : ramp(0xFF2A2420, .2, .5),
    skirt: mage ? cloth : (shogun || foot ? plates : (rank == 'ronin' ? ramp(0xFF2A2A30, .25, .5) : null)),
    pauldron: shogun || foot ? plates : null,
    belt: oni ? const Color(0xFF3A2A1A) : const Color(0xFFB8322A),
    trim: shogun ? const Color(0xFFE8C060) : (mage ? const Color(0xFFB8322A) : const Color(0xFFD8C8A0)),
    head: switch (rank) {
      'shogun' => HeadKind.kabuto,
      'ashigaru' => HeadKind.jingasa,
      'onmyoji' => HeadKind.eboshi,
      'shinobi' => HeadKind.rangermask,
      'oni' => HeadKind.oni,
      _ => HeadKind.topknot,
    },
    helm: shogun ? _lacquer : null,
    hood: ninja ? ramp(0xFF1E2230, .2, .5) : null,
    mask: ninja ? ramp(0xFF1A1C26, .15, .5) : (shogun ? ramp(0xFF2A2024, .3, .5) : null),
    hair: oni ? const Color(0xFF1A1A1A) : const Color(0xFF16120E),
    eyeGlow: oni ? const Color(0xFFFFD84A) : (shogun ? const Color(0xFFFF4A3A) : null),
    weapon: switch (rank) {
      'ashigaru' => Weapon.spear,
      'shinobi' => Weapon.shuriken,
      'onmyoji' => Weapon.fan,
      'oni' => Weapon.kanabo,
      _ => Weapon.katana,
    },
    weaponGlow: shogun ? const Color(0xFFFF4A3A) : (mage ? const Color(0xFFFFB0C8) : null),
  );
}

/// The Hollowdeep's batkin: furred bat-folk with leathery wings folded at their backs. Skulkers
/// are lean and carry hooked sickles; echo-callers wear a ragged robe and carry a staff that hums
/// violet; roost-guards wear scale over their fur and carry a glaive.
Look _batkin({String rank = 'skulker'}) {
  final caller = rank == 'caller', guard = rank == 'guard';
  final fur = ramp(caller ? 0xFF3A3040 : (guard ? 0xFF4A3E38 : 0xFF5A4A52), .25, .55);
  final wing = ramp(caller ? 0xFF4A3A5A : 0xFF5A4450, .2, .6);
  final cloth = ramp(caller ? 0xFF2E2440 : 0xFF2A2226, .3, .5);
  final scale = ramp(0xFF5A5A62, .3, .55);
  return Look(
    build: guard ? 'brute' : 'lean',
    scale: guard ? 1.1 : 1,
    stance: caller ? Stance.mage : (guard ? Stance.knight : Stance.rogue),
    skin: fur,
    torso: guard ? scale : (caller ? cloth : fur),
    torsoKind: guard ? TorsoKind.scales : (caller ? TorsoKind.robe : TorsoKind.fur),
    upper: fur,
    fore: fur,
    hand: darker(fur),
    thigh: caller ? cloth : fur,
    shin: fur,
    boot: darker(fur),
    skirt: caller ? cloth : null,
    pauldron: guard ? scale : null,
    belt: const Color(0xFF1A1216),
    trim: caller ? const Color(0xFFB07AFF) : null,
    head: HeadKind.bat,
    eyeGlow: caller ? const Color(0xFFB07AFF) : const Color(0xFFFFB04A),
    wings: wing,
    talons: true,
    tattered: caller,
    weapon: caller ? Weapon.staff : (guard ? Weapon.glaive : Weapon.sickle),
    weaponGlow: caller ? const Color(0xFFB07AFF) : null,
  );
}

/// The Frostmarch: reavers in furs and mail with nasal helms, round shields and axes; frost giants
/// with skin like glacier ice and beards of hoarfrost; the Jarl in a crown of black iron; and the
/// yetis, all white shag and tusks.
Look _frost({String rank = 'reaver'}) {
  final giant = rank == 'giant', jarl = rank == 'jarl', yeti = rank == 'yeti', skald = rank == 'skald';
  final skin = giant || jarl ? ramp(0xFF9AC0DC, .25, .5) : (yeti ? ramp(0xFFF2F4F8, .15, .45) : ramp(0xFFE8C4A8, .25, .45));
  final fur = ramp(yeti ? 0xFFE8ECF2 : 0xFF8A7A66, .25, .5);
  final mail = ramp(jarl ? 0xFF3A3E46 : 0xFF7A8088, .3, .5);
  final wool = ramp(skald ? 0xFF3A5A8A : 0xFF5A4A3A, .3, .5);
  return Look(
    build: giant || jarl ? 'giant' : (yeti ? 'brute' : 'human'),
    scale: jarl ? 1.5 : (giant ? 1.4 : (yeti ? 1.25 : 1)),
    stance: skald ? Stance.mage : Stance.knight,
    skin: skin,
    torso: yeti ? fur : (giant ? fur : (skald ? wool : mail)),
    torsoKind: yeti || giant ? TorsoKind.fur : (skald ? TorsoKind.robe : (jarl ? TorsoKind.plate : TorsoKind.mail)),
    upper: yeti || giant ? skin : mail,
    fore: skin,
    hand: yeti ? ramp(0xFF6A84A8, .2, .5) : (giant || jarl ? skin : ramp(0xFF5A3E26, .25, .5)),
    thigh: yeti ? fur : wool,
    shin: yeti ? fur : (giant || jarl ? fur : ramp(0xFF8A7A66, .25, .5)),
    boot: yeti ? ramp(0xFF6A84A8, .2, .5) : ramp(0xFF3A2A1C, .2, .5),
    skirt: skald ? wool : null,
    ruff: yeti ? null : (jarl ? const Color(0xFFF2F4F8) : const Color(0xFFB8A890)),
    pauldron: jarl ? mail : null,
    tabard: jarl ? const Color(0xFF2A3A5A) : null,
    belt: const Color(0xFF3A2416),
    trim: jarl ? const Color(0xFFBFE8FF) : const Color(0xFFC8A860),
    head: yeti ? HeadKind.yeti : (jarl || skald ? HeadKind.bare : HeadKind.nasal),
    hair: giant || jarl || skald ? const Color(0xFFE8F0F4) : const Color(0xFFC88A3A),
    beard: yeti ? null : (giant || jarl || skald ? const Color(0xFFE8F0F4) : const Color(0xFFC88A3A)),
    crown: jarl,
    eyeGlow: giant || jarl || yeti ? const Color(0xFF9ADFFF) : (skald ? const Color(0xFFBFF0FF) : null),
    talons: yeti,
    weapon: switch (rank) {
      'giant' => Weapon.club,
      'jarl' => Weapon.greataxe,
      'skald' => Weapon.staff,
      'yeti' => Weapon.none,
      _ => Weapon.axe,
    },
    weaponGlow: jarl || skald ? const Color(0xFFBFF0FF) : null,
    shield: rank == 'reaver' ? const ShieldLook(field: Color(0xFF3A5A8A), trim: Color(0xFFD8D8E0), kind: ShieldKind.round) : null,
  );
}

/// The Skyreach Aeries: harpies (wild-haired, feathered wings, talons) and the aeriekin, proud
/// bird-folk with hawks' heads and great wings, in sky-blue and bronze. Wardens carry a spear and
/// wear bronze; skyshots carry a longbow; stormcallers a staff that crackles.
Look _aerie({String rank = 'warden'}) {
  final harpy = rank == 'harpy', shot = rank == 'skyshot', caller = rank == 'caller';
  final feathers = ramp(harpy ? 0xFF6A5A4A : (caller ? 0xFF4A5A8A : 0xFF8A6A4A), .3, .55);
  final skin = harpy ? ramp(0xFFD8B898, .2, .5) : feathers;
  const bronze = <Color>[Color(0xFFE8B878), Color(0xFFB0783A), Color(0xFF5A3A16)];
  return Look(
    build: 'lean',
    scale: harpy ? .95 : 1.05,
    stance: caller ? Stance.mage : (shot ? Stance.ranger : (harpy ? Stance.rogue : Stance.knight)),
    skin: skin,
    torso: harpy ? feathers : (rank == 'warden' ? bronze : ramp(0xFF5A7AA8, .3, .5)),
    torsoKind: harpy ? TorsoKind.fur : (rank == 'warden' ? TorsoKind.plate : TorsoKind.leather),
    upper: feathers,
    fore: skin,
    hand: ramp(0xFFE8B040, .3, .5),
    thigh: feathers,
    shin: ramp(0xFFE8B040, .3, .5),
    boot: ramp(0xFFC89030, .3, .5),
    skirt: caller ? ramp(0xFF3A4A7A, .3, .5) : null,
    pauldron: rank == 'warden' ? bronze : null,
    belt: const Color(0xFF4A3420),
    trim: const Color(0xFFE8C060),
    head: harpy ? HeadKind.bare : HeadKind.bird,
    hair: const Color(0xFF3A2A1E),
    female: harpy,
    wings: feathers,
    feathered: true,
    eyeGlow: caller ? const Color(0xFFBFF0FF) : null,
    quiver: shot ? const Color(0xFF6E5030) : null,
    weapon: switch (rank) {
      'skyshot' => Weapon.longbow,
      'caller' => Weapon.staff,
      'harpy' => Weapon.none,
      _ => Weapon.spear,
    },
    weaponGlow: caller ? const Color(0xFFBFF0FF) : null,
  );
}

final Map<String, Look> foeLooks = {
  ...entLooks,
  'ghost': _spirit(robe: 0xFF9AB8C8),
  'banshee': _spirit(robe: 0xFFB8C8D8, head: HeadKind.banshee, eyes: const Color(0xFFCFF4FF)),
  'wailingqueen': _spirit(robe: 0xFF8AA0C8, head: HeadKind.banshee, eyes: const Color(0xFFE8D8FF), scale: 1.3, hair: const Color(0xFFCFC8E8), crown: true),
  'ghoul': _ghoul(),
  'ghoulking': _ghoul(scale: 1.3, king: true),
  'witch': _witch(),
  'covenmother': _witch(scale: 1.25, mother: true),
  'warlock': _warlock(),
  'archwarlock': _warlock(scale: 1.25, arch: true),
  // Golems, who walk out of the rock with ore in their backs.
  'golemIron': _golem(stone: 0xFF6A6460, ore: const Color(0xFFC8703A), eyes: const Color(0xFFFF9A4A)),
  'golemGold': _golem(stone: 0xFF8A7656, ore: const Color(0xFFFFD45A), eyes: const Color(0xFFFFF0A0)),
  'golemObsidian': _golem(stone: 0xFF2A2630, ore: const Color(0xFFFF6A3A), eyes: const Color(0xFFFF3A2A), scale: 1.35),
  // The Hidden Ones, who turn up anywhere.
  'hiddenAcolyte': _hidden(),
  'hiddenBlade': _hidden(rank: 'blade'),
  'hiddenHexer': _hidden(rank: 'hexer'),
  'hiddenPrior': _hidden(rank: 'prior'),
  'minotaur': _minotaur(),
  'minotaurlord': _minotaur(scale: 1.4, lord: true),
  // The Ashen Order.
  'ashenKnight': _ashen(),
  'ashenChampion': _ashen(rank: 'champion'),
  'malric': _ashen(rank: 'malric'),
  // Ravenmoor.
  'thrall': _thrall(),
  'vampireSpawn': _vampire(),
  'bloodBride': _vampire(rank: 'bride'),
  'vampireKnight': _vampire(rank: 'knight'),
  'countess': _vampire(rank: 'countess'),
  // The Howling Weald.
  'woodsman': _woodsman(),
  'werewolf': _werewolf(),
  'werewolfStalker': _werewolf(fur: 0xFF3A3A44, eyes: const Color(0xFFCFE8FF), build: 'lean', scale: 1.05),
  'werewolfBrute': _werewolf(fur: 0xFF8A8A92, build: 'giant', scale: 1.3),
  'werewolfAlpha': _werewolf(fur: 0xFF2E2424, eyes: const Color(0xFFFF3A2A), build: 'giant', scale: 1.45),
  // Elementals, rising out of the land.
  'elementalEmber': _elemental(body: 0xFF6A2A16, vein: const Color(0xFFFF8A2A), eyes: const Color(0xFFFFE07A), embers: const Color(0xFFFF6A2A)),
  'elementalFrost': _elemental(body: 0xFF8AB4D4, vein: const Color(0xFFF0FAFF), eyes: const Color(0xFFBFF0FF)),
  'elementalMire': _elemental(body: 0xFF4A5A2A, vein: const Color(0xFF8BE05A), eyes: const Color(0xFFD8F07A)),
  // The Blossom Isles.
  'ronin': _blossom(),
  'ashigaru': _blossom(rank: 'ashigaru'),
  'shinobi': _blossom(rank: 'shinobi'),
  'onmyoji': _blossom(rank: 'onmyoji'),
  'oni': _blossom(rank: 'oni'),
  'shogun': _blossom(rank: 'shogun'),
  'batkin': _batkin(),
  'batkinCaller': _batkin(rank: 'caller'),
  'batkinGuard': _batkin(rank: 'guard'),
  // The Frostmarch.
  'frostReaver': _frost(),
  'frostSkald': _frost(rank: 'skald'),
  'frostGiant': _frost(rank: 'giant'),
  'frostJarl': _frost(rank: 'jarl'),
  'yeti': _frost(rank: 'yeti'),
  'iceWraith': _spirit(robe: 0xFFA8D4EC, head: HeadKind.banshee, eyes: const Color(0xFFBFF0FF), hair: const Color(0xFFDFF4FF)),
  // The Skyreach Aeries.
  'harpy': _aerie(rank: 'harpy'),
  'aerieWarden': _aerie(),
  'aerieSkyshot': _aerie(rank: 'skyshot'),
  'aerieCaller': _aerie(rank: 'caller'),
  // The Changeling Isle.
  'shifter': _shifter(),
  'shifterSly': _shifter(rank: 'sly'),
  'shifterHulk': _shifter(rank: 'hulk'),
  'thousandfold': _shifter(rank: 'thousandfold'),
  // The Shattered Sea.
  'drownedSailor': Look(
    build: 'lean',
    stance: Stance.zombie,
    skin: ramp(0xFF9AB8B0, .2, .5),
    torso: ramp(0xFF3A4A5A, .25, .5),
    torsoKind: TorsoKind.rags,
    upper: ramp(0xFF3A4A5A, .25, .5),
    fore: ramp(0xFF9AB8B0, .2, .5),
    hand: ramp(0xFF9AB8B0, .2, .5),
    thigh: ramp(0xFF5A4A3A, .2, .5),
    shin: ramp(0xFF5A4A3A, .2, .5),
    boot: ramp(0xFF2A2A26, .2, .5),
    belt: const Color(0xFF2A3A2A),
    head: HeadKind.zombie,
    hair: const Color(0xFF3A5A3A),
    weapon: Weapon.hook,
    rusty: true,
  ),
  'merrowRaider': _merrow(),
  'merrowCaller': _merrow(rank: 'caller'),
  'merrowGuard': _merrow(rank: 'guard'),
  // The Sunscale Jungle.
  'lizardGuard': _lizard(),
  'lizardSkirmisher': _lizard(rank: 'skirmisher'),
  'lizardShaman': _lizard(rank: 'shaman'),
  'lizardChampion': _lizard(rank: 'champion'),
  'lizardKing': _lizard(rank: 'king'),
  // The Isle of Mists.
  'facelessWanderer': _faceless(),
  'facelessMimic': _faceless(rank: 'mimic'),
  'facelessChoir': _faceless(rank: 'choir'),
  'facelessWarden': _faceless(rank: 'warden'),
  'facelessMother': _faceless(rank: 'mother'),
  // The Silverwood.
  'elfRanger': _elf(),
  'elfBlade': _elf(rank: 'blade'),
  'elfWarden': _elf(rank: 'warden'),
  'elfDruid': _elf(rank: 'druid'),
  'elfQueen': _elf(rank: 'queen'),
  // Deepforge Hold.
  'dwarfAxe': _dwarf(),
  'dwarfShield': _dwarf(rank: 'shield'),
  'dwarfXbow': _dwarf(rank: 'xbow'),
  'dwarfRune': _dwarf(rank: 'rune'),
  'dwarfThane': _dwarf(rank: 'thane'),
  'centaur': _centaur(),
  'centaurchief': _centaur(chief: true),
  'pitdemon': _demon(),
  'demonlord': _demon(build: 'giant', scale: 1.35, hide: 0xFF8A1E1A, weapon: Weapon.greatsword, wings: true, eyes: const Color(0xFFFFF0A0)),
  'gargoyle': _gargoyle(),
  'gargoylematriarch': _gargoyle(scale: 1.45, stone: 0xFF6A6470, eyes: const Color(0xFFFF6A3A)),
  // The Bone Colossus: a giant skeleton in horned, rusted plate with a greatsword.
  'bonecolossus': Look(
    build: 'skeleton',
    scale: 1.55,
    stance: Stance.knight,
    skin: _darkBone,
    torso: _darkBone,
    torsoKind: TorsoKind.ribs,
    upper: _darkBone,
    fore: _darkBone,
    hand: ramp(0xFF6A5E52, .3, .5),
    thigh: _darkBone,
    shin: ramp(0xFF6A5E52, .3, .5),
    boot: _darkBone,
    knee: ramp(0xFF6A5E52, .3, .5),
    elbow: ramp(0xFF6A5E52, .3, .5),
    pauldron: ramp(0xFF6A5E52, .3, .5),
    belt: const Color(0xFF1A120A),
    cape: const Color(0xFF2A1416),
    tattered: true,
    capeFlow: 10,
    head: HeadKind.skullHorned,
    helm: ramp(0xFF6A5E52, .3, .5),
    eyeGlow: const Color(0xFF7AF0C8),
    weapon: Weapon.greatsword,
    weaponGlow: const Color(0xFF7AF0C8),
    rusty: true,
    embers: const Color(0xFF7AF0B0),
  ),
  // The Ork Behemoth: a giant ork in black plate with a burning greataxe.
  'orkbehemoth': Look(
    build: 'giant',
    scale: 1.42,
    stance: Stance.knight,
    skin: ramp(0xFF4A6A26, .25, .5),
    // Krugg fights bare-chested, a mountain of green muscle and belly under a war-cloak.
    torso: ramp(0xFF4A6A26, .25, .5),
    upper: _black,
    fore: ramp(0xFF4A6A26, .25, .5),
    hand: _black,
    thigh: ramp(0xFF3A2E22, .2, .5),
    shin: _black,
    boot: _darkBoot,
    knee: _black,
    elbow: _black,
    pauldron: _bone,
    belt: const Color(0xFF6E1A12),
    head: HeadKind.orkWarlord,
    helm: _black,
    hair: const Color(0xFF1A140E),
    weapon: Weapon.greataxe,
    weaponGlow: const Color(0xFFFF6A1A),
    gore: true,
    cape: const Color(0xFF6E1A12),
    tattered: true,
  ),
  'cyclops': Look(
    build: 'giant',
    scale: 1.4,
    stance: Stance.knight,
    skin: ramp(0xFFC2946A, .25, .5),
    torso: ramp(0xFFC2946A, .25, .5),
    upper: ramp(0xFFC2946A, .25, .5),
    fore: ramp(0xFFC2946A, .25, .5),
    hand: ramp(0xFFC2946A, .25, .5),
    thigh: ramp(0xFF5A3E22, .2, .5),
    shin: ramp(0xFFC2946A, .25, .5),
    boot: ramp(0xFF8A7458, .2, .55),
    belt: const Color(0xFF3A2414),
    head: HeadKind.cyclops,
    hair: const Color(0xFF3A2A1A),
    weapon: Weapon.club,
    wraps: true,
    pauldron: _bone,
  ),
  'goblin': Look(
    build: 'goblin',
    stance: Stance.goblin,
    skin: ramp(0xFF7F9A4C, .25, .5),
    torso: ramp(0xFF6B4F33, .2, .5),
    torsoKind: TorsoKind.rags,
    upper: ramp(0xFF7F9A4C, .25, .5),
    fore: ramp(0xFF7F9A4C, .25, .5),
    hand: ramp(0xFF7F9A4C, .25, .5),
    thigh: ramp(0xFF5A4632, .2, .5),
    shin: ramp(0xFF7F9A4C, .25, .5),
    boot: ramp(0xFF4F6A2C, .2, .5),
    head: HeadKind.goblin,
    weapon: Weapon.shortsword,
    rusty: true,
    wraps: true,
  ),
  'goblinChief': Look(
    build: 'goblin',
    scale: 1.3,
    stance: Stance.goblin,
    skin: ramp(0xFF6F8A42, .25, .5),
    torso: ramp(0xFF4A3A2A, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF6F8A42, .25, .5),
    fore: ramp(0xFF6F8A42, .25, .5),
    hand: ramp(0xFF6F8A42, .25, .5),
    thigh: ramp(0xFF4A3A2A, .2, .5),
    shin: ramp(0xFF6F8A42, .25, .5),
    boot: ramp(0xFF3A2A1A, .2, .5),
    belt: const Color(0xFF2A1A0E),
    head: HeadKind.goblinChief,
    weapon: Weapon.club,
    pauldron: _bone,
    cape: const Color(0xFF5E1A14),
    tattered: true,
    wraps: true,
  ),
  'rogue': Look(
    build: 'lean',
    stance: Stance.rogue,
    skin: ramp(0xFFC99474, .25, .45),
    torso: ramp(0xFF4A3A2C, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF3E3A32, .2, .5),
    fore: ramp(0xFF5A4030, .2, .5),
    hand: ramp(0xFF2A2018, .2, .5),
    thigh: ramp(0xFF36332C, .2, .5),
    shin: ramp(0xFF3A2A1C, .2, .5),
    boot: ramp(0xFF2A1E14, .2, .5),
    belt: const Color(0xFF2A1A0E),
    pouch: true,
    head: HeadKind.hood,
    hood: ramp(0xFF3B4436, .2, .55),
    mask: ramp(0xFF2A2A26, .15, .5),
    weapon: Weapon.dagger,
    offhand: Weapon.dagger,
    cape: const Color(0xFF2F362B),
  ),
  'assassin': Look(
    build: 'lean',
    stance: Stance.rogue,
    skin: ramp(0xFFB98A6C, .25, .45),
    torso: ramp(0xFF26222A, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF26222A, .2, .5),
    fore: ramp(0xFF3A2A2A, .2, .5),
    hand: ramp(0xFF141014, .2, .5),
    thigh: ramp(0xFF1E1C22, .2, .5),
    shin: ramp(0xFF2A1E1E, .2, .5),
    boot: ramp(0xFF141014, .2, .5),
    belt: const Color(0xFF7A1D14),
    pouch: true,
    head: HeadKind.hood,
    hood: ramp(0xFF24202A, .2, .55),
    mask: ramp(0xFF7A1D14, .15, .5),
    maskTrim: const Color(0xFF7A1D14),
    eyeGlow: const Color(0xFFF0E2C0),
    weapon: Weapon.dagger,
    offhand: Weapon.dagger,
    cape: const Color(0xFF1E1A22),
  ),
  // Hallowash's scarecrow: straw and sackcloth, a pitchfork, and a carved pumpkin for a head.
  'pumpkinhead': Look(
    build: 'lean',
    scale: 1.08,
    stance: Stance.zombie,
    skin: ramp(0xFFD8B860, .25, .45),
    torso: ramp(0xFF6A5A3A, .2, .5),
    torsoKind: TorsoKind.rags,
    upper: ramp(0xFF5A4A6A, .2, .5),
    fore: ramp(0xFFD8B860, .25, .45),
    hand: ramp(0xFFD8B860, .25, .45),
    thigh: ramp(0xFF4A3A2A, .2, .5),
    shin: ramp(0xFFD8B860, .25, .45),
    boot: ramp(0xFF2E2418, .2, .5),
    belt: const Color(0xFF8A6A3A),
    head: HeadKind.pumpkin,
    weapon: Weapon.spear,
  ),
  // ---- The Sunken Sands: the tomb dead and the raiders who rob them ----
  'mummy': _mummy(),
  'mummyGuard': _mummy(guard: true),
  'tombPriest': _mummy(priest: true),
  'pharaoh': _mummy(pharaoh: true),
  'duneRaider': Look(
    build: 'lean',
    stance: Stance.rogue,
    skin: ramp(0xFFB07A54, .25, .45),
    torso: ramp(0xFFC8A878, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFFB89A6A, .2, .5),
    fore: ramp(0xFFB07A54, .25, .45),
    hand: ramp(0xFF5A4030, .2, .5),
    thigh: ramp(0xFF8A6A48, .2, .5),
    shin: ramp(0xFF6A4E34, .2, .5),
    boot: ramp(0xFF4A3424, .2, .5),
    belt: const Color(0xFF7A2A1A),
    pouch: true,
    head: HeadKind.hood,
    hood: ramp(0xFFD8C090, .2, .5),
    mask: ramp(0xFF8A2A1E, .2, .5),
    weapon: Weapon.scimitar,
    cape: const Color(0xFFB89868),
  ),
  'sandArcher': Look(
    build: 'lean',
    stance: Stance.ranger,
    skin: ramp(0xFF9A6A48, .25, .45),
    torso: ramp(0xFFB89868, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFFA88A5A, .2, .5),
    fore: ramp(0xFF9A6A48, .25, .45),
    hand: ramp(0xFF5A4030, .2, .5),
    thigh: ramp(0xFF7A5E40, .2, .5),
    shin: ramp(0xFF5E4430, .2, .5),
    boot: ramp(0xFF4A3424, .2, .5),
    belt: const Color(0xFF2A4E7A),
    head: HeadKind.hood,
    hood: ramp(0xFFE0CCA0, .2, .5),
    mask: ramp(0xFF2A4E7A, .2, .5),
    weapon: Weapon.bow,
    quiver: const Color(0xFF6E4A2A),
  ),
  'zombie': Look(
    build: 'lean',
    stance: Stance.zombie,
    skin: ramp(0xFF8F9A7C, .2, .5),
    torso: ramp(0xFF6B6450, .15, .5),
    torsoKind: TorsoKind.rags,
    gore: true,
    upper: ramp(0xFF6B6450, .15, .5),
    fore: ramp(0xFF8F9A7C, .2, .5),
    hand: ramp(0xFF8F9A7C, .2, .5),
    thigh: ramp(0xFF4A4438, .15, .5),
    shin: ramp(0xFF4A4438, .15, .5),
    boot: ramp(0xFF2E2A22, .15, .5),
    belt: const Color(0xFF2E2418),
    head: HeadKind.zombie,
    hair: const Color(0xFF2A2218),
  ),
  'plague': Look(
    build: 'lean',
    scale: 1.06,
    stance: Stance.zombie,
    skin: ramp(0xFFA3A868, .2, .5),
    torso: ramp(0xFF4E4A3A, .15, .5),
    torsoKind: TorsoKind.rags,
    gore: true,
    upper: ramp(0xFF4E4A3A, .15, .5),
    fore: ramp(0xFFA3A868, .2, .5),
    hand: ramp(0xFFA3A868, .2, .5),
    thigh: ramp(0xFF3A382C, .15, .5),
    shin: ramp(0xFFA3A868, .2, .5),
    boot: ramp(0xFF2A281E, .15, .5),
    belt: const Color(0xFF2A2218),
    head: HeadKind.zombie,
    hair: const Color(0xFF1E1A12),
    miasma: true,
  ),
  'pillager': Look(
    build: 'brute',
    stance: Stance.pillager,
    skin: ramp(0xFFC99474, .25, .45),
    torso: ramp(0xFF6E5A42, .2, .5),
    torsoKind: TorsoKind.fur,
    upper: ramp(0xFFC99474, .25, .45),
    fore: ramp(0xFF5A3E26, .2, .5),
    hand: ramp(0xFFC99474, .25, .45),
    thigh: ramp(0xFF5A4A3A, .2, .5),
    shin: ramp(0xFF6E5A42, .2, .5),
    boot: ramp(0xFF4A3A2A, .2, .5),
    head: HeadKind.pillager,
    beard: const Color(0xFF8A5A2A),
    weapon: Weapon.axe,
    wraps: true,
    shield: const ShieldLook(field: Color(0xFF7A5232), kind: ShieldKind.round),
  ),
  'pillagerCap': Look(
    build: 'brute',
    scale: 1.1,
    stance: Stance.pillager,
    skin: ramp(0xFFC99474, .25, .45),
    torso: ramp(0xFF5A4A3A, .2, .5),
    torsoKind: TorsoKind.fur,
    upper: ramp(0xFF9AA0A8, .3, .5),
    fore: ramp(0xFF5A3E26, .2, .5),
    hand: ramp(0xFF3A2A1A, .2, .5),
    thigh: ramp(0xFF4A3A2A, .2, .5),
    shin: ramp(0xFF9AA0A8, .3, .5),
    boot: ramp(0xFF3A2A1A, .2, .5),
    belt: const Color(0xFF2A1A0E),
    head: HeadKind.pillagerCap,
    beard: const Color(0xFFB06A2A),
    weapon: Weapon.greataxe,
    cape: const Color(0xFF7A1D14),
    pauldron: ramp(0xFF9AA0A8, .3, .5),
  ),
  'rose': Look(
    build: 'human',
    scale: 1.12,
    stance: Stance.rose,
    skin: ramp(0xFFC99474),
    torso: _black,
    torsoKind: TorsoKind.plate,
    upper: _black,
    fore: _black,
    hand: _black,
    thigh: _black,
    shin: _black,
    boot: _darkBoot,
    knee: _black,
    elbow: _black,
    pauldron: _black,
    tabard: const Color(0xFF5A1418),
    trim: const Color(0xFF1A0A0A),
    emblem: 'rose',
    belt: const Color(0xFF1A120C),
    cape: const Color(0xFF2A0A0C),
    head: HeadKind.sallet,
    helm: _black,
    eyeGlow: const Color(0xFFFF4A2E),
    plume: const Color(0xFF7A1418),
    weapon: Weapon.greatsword,
  ),
  'roseCmd': Look(
    build: 'human',
    scale: 1.18,
    stance: Stance.rose,
    skin: ramp(0xFFC99474),
    torso: _black2,
    torsoKind: TorsoKind.plate,
    upper: _black2,
    fore: _black2,
    hand: _black2,
    thigh: _black2,
    shin: _black2,
    boot: _darkBoot,
    knee: _gold,
    elbow: _gold,
    pauldron: _gold,
    tabard: const Color(0xFF3A0C10),
    trim: const Color(0xFFC9A24E),
    emblem: 'rose',
    belt: const Color(0xFF1A120C),
    cape: const Color(0xFF1E0608),
    tattered: true,
    capeFlow: 20,
    head: HeadKind.sallet,
    helm: _black2,
    eyeGlow: const Color(0xFFFF6A3E),
    crown: true,
    weapon: Weapon.greatsword,
  ),
  'ork': Look(
    build: 'brute',
    stance: Stance.knight,
    skin: ramp(0xFF6A8A3E, .25, .5),
    torso: ramp(0xFF5A4630, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF6A8A3E, .25, .5),
    fore: ramp(0xFF6A8A3E, .25, .5),
    hand: ramp(0xFF6A8A3E, .25, .5),
    thigh: ramp(0xFF4A3A28, .2, .5),
    shin: ramp(0xFF4A3A28, .2, .5),
    boot: ramp(0xFF2E2216, .2, .5),
    pauldron: _bone,
    head: HeadKind.ork,
    hair: const Color(0xFF1A140E),
    weapon: Weapon.orkclub,
    wraps: true,
    shield: const ShieldLook(field: Color(0xFF5E4A30), kind: ShieldKind.round),
  ),
  'orkArcher': Look(
    build: 'brute',
    stance: Stance.ranger,
    skin: ramp(0xFF5E7E36, .25, .5),
    torso: ramp(0xFF4A3E2A, .2, .5),
    torsoKind: TorsoKind.studded,
    upper: ramp(0xFF5E7E36, .25, .5),
    fore: ramp(0xFF4A3E2A, .2, .5),
    hand: ramp(0xFF5E7E36, .25, .5),
    thigh: ramp(0xFF3E3424, .2, .5),
    shin: ramp(0xFF3E3424, .2, .5),
    boot: ramp(0xFF2A1E12, .2, .5),
    head: HeadKind.ork,
    hair: const Color(0xFF2A1A0E),
    quiver: const Color(0xFF5A3E22),
    weapon: Weapon.orkbow,
  ),
  'orkShaman': Look(
    build: 'brute',
    stance: Stance.mage,
    skin: ramp(0xFF7A8A44, .25, .5),
    torso: ramp(0xFF4E3A2E, .2, .5),
    torsoKind: TorsoKind.robe,
    skirt: ramp(0xFF4E3A2E, .2, .5),
    trim: const Color(0xFFB8A070),
    upper: ramp(0xFF7A8A44, .25, .5),
    fore: ramp(0xFF7A8A44, .25, .5),
    hand: ramp(0xFF7A8A44, .25, .5),
    thigh: ramp(0xFF3A2C22, .2, .5),
    shin: ramp(0xFF7A8A44, .25, .5),
    boot: ramp(0xFF2A2018, .2, .5),
    belt: const Color(0xFF7A1D14),
    head: HeadKind.orkShaman,
    hair: const Color(0xFF1A140E),
    weapon: Weapon.orkstaff,
    weaponGlow: const Color(0xFF8BE05A),
  ),
  'orkBerserker': Look(
    build: 'brute',
    scale: 1.12,
    stance: Stance.pillager,
    skin: ramp(0xFF5A7A30, .25, .5),
    torso: ramp(0xFF5A7A30, .25, .5),
    torsoKind: TorsoKind.plain,
    gore: true,
    upper: ramp(0xFF5A7A30, .25, .5),
    fore: ramp(0xFF5A7A30, .25, .5),
    hand: ramp(0xFF5A7A30, .25, .5),
    thigh: ramp(0xFF3E3020, .2, .5),
    shin: ramp(0xFF3E3020, .2, .5),
    boot: ramp(0xFF2A1E12, .2, .5),
    belt: const Color(0xFF7A1D14),
    head: HeadKind.ork,
    hair: const Color(0xFF8A2A14),
    weapon: Weapon.greataxe,
    wraps: true,
  ),
  'orkWarlord': Look(
    build: 'brute',
    scale: 1.28,
    stance: Stance.knight,
    skin: ramp(0xFF4E6E2A, .25, .5),
    torso: _black,
    torsoKind: TorsoKind.plate,
    upper: _black,
    fore: ramp(0xFF4E6E2A, .25, .5),
    hand: _black,
    thigh: ramp(0xFF3A2E22, .2, .5),
    shin: _black,
    boot: _darkBoot,
    knee: _black,
    elbow: _black,
    pauldron: _bone,
    belt: const Color(0xFF2A1A0E),
    cape: const Color(0xFF6E1A12),
    tattered: true,
    capeFlow: 14,
    head: HeadKind.orkWarlord,
    helm: _black,
    hair: const Color(0xFF1A140E),
    weapon: Weapon.orkclub,
    weaponGlow: const Color(0xFFFF8A2A),
  ),
  'skeleton': const Look(
    build: 'skeleton',
    stance: Stance.knight,
    skin: _bone,
    torso: _bone,
    torsoKind: TorsoKind.ribs,
    upper: _bone,
    fore: _bone,
    hand: _bone,
    thigh: _bone,
    shin: _bone,
    boot: _bone,
    knee: _bone,
    elbow: _bone,
    belt: Color(0xFF3A2A1C),
    head: HeadKind.skull,
    eyeGlow: Color(0xFF7FE8FF),
    weapon: Weapon.shortsword,
    rusty: true,
  ),
  'skeletonArcher': Look(
    build: 'skeleton',
    stance: Stance.ranger,
    skin: _bone,
    torso: _bone,
    torsoKind: TorsoKind.ribs,
    upper: _bone,
    fore: _bone,
    hand: _bone,
    thigh: _bone,
    shin: _bone,
    boot: _bone,
    knee: _bone,
    elbow: _bone,
    belt: const Color(0xFF2A2018),
    head: HeadKind.skullHood,
    hood: ramp(0xFF3A3630, .2, .55),
    eyeGlow: const Color(0xFF9AFF7A),
    cape: const Color(0xFF34302A),
    tattered: true,
    quiver: const Color(0xFF4A3A28),
    weapon: Weapon.bow,
  ),
  'skeletonChampion': Look(
    build: 'skeleton',
    scale: 1.1,
    stance: Stance.knight,
    skin: _bone,
    torso: _bone,
    torsoKind: TorsoKind.ribs,
    upper: _bone,
    fore: _bone,
    hand: ramp(0xFF8A7A6A, .3, .5),
    thigh: _bone,
    shin: ramp(0xFF8A7A6A, .3, .5),
    boot: _bone,
    knee: ramp(0xFF8A7A6A, .3, .5),
    elbow: _bone,
    pauldron: ramp(0xFF8A7A6A, .3, .5),
    belt: const Color(0xFF2A1A0E),
    cape: const Color(0xFF3A1A18),
    tattered: true,
    head: HeadKind.skullHelm,
    helm: ramp(0xFF8A7A6A, .3, .5),
    eyeGlow: const Color(0xFFFF6A3A),
    weapon: Weapon.axe,
    rusty: true,
    shield: const ShieldLook(field: Color(0xFF4A3A2E), kind: ShieldKind.round),
  ),
  'dragonboneWarden': const Look(
    build: 'skeleton',
    scale: 1.25,
    stance: Stance.knight,
    skin: _darkBone,
    torso: _darkBone,
    torsoKind: TorsoKind.ribs,
    upper: _darkBone,
    fore: _darkBone,
    hand: _darkBone,
    thigh: _darkBone,
    shin: _darkBone,
    boot: _darkBone,
    knee: _darkBone,
    elbow: _darkBone,
    pauldron: _darkBone,
    belt: Color(0xFF1A1218),
    cape: Color(0xFF241830),
    tattered: true,
    capeFlow: 12,
    head: HeadKind.skullHorned,
    eyeGlow: Color(0xFFC07AFF),
    weapon: Weapon.halberd,
    weaponGlow: Color(0xFFC07AFF),
  ),
};

/// The people who stop you on the road with quests.
final Map<String, Look> questGiverLooks = {
  // Hob, who keeps the Soot & Kettle: rolled sleeves, a waistcoat, a sooty apron and a big grey beard.
  'innkeeper': Look(
    build: 'human',
    stance: Stance.mage,
    skin: ramp(0xFFE2A882, .25, .5),
    torso: ramp(0xFF6A4A2E, .25, .5),
    torsoKind: TorsoKind.plain,
    upper: ramp(0xFFA89878, .25, .5),
    fore: ramp(0xFFE2A882, .25, .5),
    hand: ramp(0xFFE2A882, .25, .5),
    thigh: ramp(0xFF4A3A2C, .2, .5),
    shin: ramp(0xFF4A3A2C, .2, .5),
    boot: ramp(0xFF2E2016, .2, .5),
    tabard: const Color(0xFFD8CDB4),
    belt: const Color(0xFF4A3420),
    head: HeadKind.bare,
    hair: const Color(0xFF5E5A54),
    beard: const Color(0xFF8E8A82),
  ),
  // Mags the merchant: a green dress, a leather apron and her hair pinned up.
  'merchant': Look(
    build: 'human',
    stance: Stance.mage,
    female: true,
    skin: ramp(0xFFD9A77E, .25, .5),
    torso: ramp(0xFF3E5A34, .25, .5),
    torsoKind: TorsoKind.robe,
    upper: ramp(0xFF3E5A34, .25, .5),
    fore: ramp(0xFFD9A77E, .25, .5),
    hand: ramp(0xFFD9A77E, .25, .5),
    thigh: ramp(0xFF3E5A34, .25, .5),
    shin: ramp(0xFF3E5A34, .25, .5),
    boot: ramp(0xFF2E2016, .2, .5),
    skirt: ramp(0xFF3E5A34, .25, .5),
    tabard: const Color(0xFF6A4A2E),
    belt: const Color(0xFF4A3420),
    pouch: true,
    head: HeadKind.bare,
    hair: const Color(0xFF8A3A1E),
  ),
  'king': Look(
    build: 'human',
    stance: Stance.mage,
    skin: ramp(0xFFE0B48C, .25, .5),
    torso: ramp(0xFF8A1E22, .3, .5),
    torsoKind: TorsoKind.robe,
    upper: ramp(0xFF8A1E22, .3, .5),
    fore: ramp(0xFF8A1E22, .3, .5),
    hand: ramp(0xFFE0B48C, .25, .5),
    thigh: ramp(0xFF8A1E22, .3, .5),
    shin: ramp(0xFF3A2E24, .2, .5),
    boot: ramp(0xFF3A2A1C, .2, .5),
    skirt: ramp(0xFF8A1E22, .3, .5),
    trim: const Color(0xFFE2C46A),
    belt: const Color(0xFFC9A24E),
    cape: const Color(0xFF3A1A6A),
    head: HeadKind.bare,
    crown: true,
    hair: const Color(0xFFCFC8B8),
    beard: const Color(0xFFD8D2C4),
    weapon: Weapon.sceptre,
    weaponGlow: const Color(0xFFFFE27A),
  ),
  'villager': Look(
    build: 'human',
    stance: Stance.mage,
    skin: ramp(0xFFD9A77E, .25, .5),
    torso: ramp(0xFF7A6A48, .25, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFFB8A888, .25, .5),
    fore: ramp(0xFFB8A888, .25, .5),
    hand: ramp(0xFFD9A77E, .25, .5),
    thigh: ramp(0xFF5A4A34, .2, .5),
    shin: ramp(0xFF5A4A34, .2, .5),
    boot: ramp(0xFF3A2A1C, .2, .5),
    belt: const Color(0xFF4A3420),
    pouch: true,
    head: HeadKind.bare,
    hair: const Color(0xFF8A5A2A),
  ),
  'seer': Look(
    build: 'human',
    stance: Stance.mage,
    skin: ramp(0xFFC89A78, .25, .5),
    torso: ramp(0xFF3A2A4E, .3, .5),
    torsoKind: TorsoKind.robe,
    upper: ramp(0xFF3A2A4E, .3, .5),
    fore: ramp(0xFF3A2A4E, .3, .5),
    hand: ramp(0xFFC89A78, .25, .5),
    thigh: ramp(0xFF3A2A4E, .3, .5),
    shin: ramp(0xFF2A2030, .2, .5),
    boot: ramp(0xFF2A2030, .2, .5),
    skirt: ramp(0xFF3A2A4E, .3, .5),
    trim: const Color(0xFFB89AE0),
    belt: const Color(0xFF6A4A8A),
    head: HeadKind.cowl,
    hatColour: const Color(0xFF6A4A8A),
    hair: const Color(0xFFD8D2C4),
    weapon: Weapon.wand,
    offhand: Weapon.orb,
    offhandGlow: const Color(0xFFC07AFF),
    weaponGlow: const Color(0xFFC07AFF),
  ),
  'mage': Look(
    build: 'human',
    stance: Stance.mage,
    skin: ramp(0xFFE0B48C, .25, .5),
    torso: ramp(0xFF2F4F86, .3, .5),
    torsoKind: TorsoKind.robe,
    upper: ramp(0xFF2F4F86, .3, .5),
    fore: ramp(0xFF2F4F86, .3, .5),
    hand: ramp(0xFFE0B48C, .25, .5),
    thigh: ramp(0xFF2F4F86, .3, .5),
    shin: ramp(0xFF3A2E24, .2, .5),
    boot: ramp(0xFF3A2A1C, .2, .5),
    skirt: ramp(0xFF2F4F86, .3, .5),
    trim: const Color(0xFFE2C46A),
    belt: const Color(0xFF9A2A22),
    cape: const Color(0xFF1C2448),
    head: HeadKind.wizardhat,
    hatColour: const Color(0xFF2F4F86),
    hair: const Color(0xFF8A8A8A),
    beard: const Color(0xFFD8D2C4),
    weapon: Weapon.staff,
    weaponGlow: const Color(0xFF9ADFFF),
  ),
  'fisherman': Look(
    build: 'human',
    stance: Stance.mage,
    skin: ramp(0xFFC08A62, .25, .5),
    torso: ramp(0xFFD8A830, .3, .5), // a yellow oilskin
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFFD8A830, .3, .5),
    fore: ramp(0xFFD8A830, .3, .5),
    hand: ramp(0xFFC08A62, .25, .5),
    thigh: ramp(0xFF3A4A5A, .2, .5),
    shin: ramp(0xFF2A2A2A, .2, .5),
    boot: ramp(0xFF1E1E1E, .2, .5),
    belt: const Color(0xFF4A3420),
    pouch: true,
    head: HeadKind.scoutcap,
    hatColour: const Color(0xFF2E4A6A),
    hair: const Color(0xFFB8B2A6),
    beard: const Color(0xFFD8D2C4),
    weapon: Weapon.fishingrod,
  ),
};

// ---- Mummies ----

/// Old linen: one ramp for shins and feet alike, so the feet are bare and wrapped, not booted.
final Ramp _linen = ramp(0xFFCDBF9A, .2, .5);
final Ramp _linenDark = ramp(0xFFA89874, .2, .5);

/// The tomb dead of the Sunken Sands, wound in linen with coals for eyes. A [guard] stands taller
/// with a khopesh-like blade, a gilded collar and a round shield; a [priest] carries a staff and
/// glows green; the [pharaoh] wears the striped headcloth, a royal cape and a kilt of gold.
Look _mummy({bool guard = false, bool priest = false, bool pharaoh = false}) => Look(
  build: pharaoh ? 'giant' : (guard ? 'human' : 'lean'),
  scale: pharaoh ? 1.3 : (guard ? 1.08 : 1),
  stance: priest || pharaoh ? Stance.mage : (guard ? Stance.knight : Stance.zombie),
  skin: _linen,
  torso: guard || pharaoh ? _linen : _linenDark,
  upper: _linen,
  fore: _linen,
  hand: _linenDark,
  thigh: _linenDark,
  shin: _linen,
  boot: _linen,
  belt: pharaoh || guard ? const Color(0xFFE0B040) : const Color(0xFF5A4630),
  head: pharaoh ? HeadKind.pharaoh : HeadKind.mummy,
  eyeGlow: priest || pharaoh ? const Color(0xFF7AF0A8) : const Color(0xFFFFB84A),
  bandaged: true,
  usekh: guard || priest || pharaoh,
  weapon: pharaoh ? Weapon.sceptre : (priest ? Weapon.staff : (guard ? Weapon.scimitar : Weapon.none)),
  weaponGlow: priest || pharaoh ? const Color(0xFF7AF0A8) : null,
  shield: guard ? const ShieldLook(field: Color(0xFF2E5AA8), trim: Color(0xFFE0B040), kind: ShieldKind.round) : null,
  skirt: pharaoh ? ramp(0xFFE8D8A8, .2, .45) : (priest ? ramp(0xFFB8A880, .2, .5) : null),
  cape: pharaoh ? const Color(0xFF233E7A) : null,
  tattered: true,
);
