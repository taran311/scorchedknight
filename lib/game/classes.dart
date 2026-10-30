// The three paths a hero can follow, their traits and their armour.

enum HeroClass { knight, mage, ranger }

extension HeroClassInfo on HeroClass {
  String get label => switch (this) {
    HeroClass.knight => 'Knight',
    HeroClass.mage => 'Mage',
    HeroClass.ranger => 'Ranger',
  };

  String get blurb => switch (this) {
    HeroClass.knight => 'Sword and shield. Hardest to wound, and the Shield Bash leaves foes seeing stars.',
    HeroClass.mage => 'Staff and spellbook. Gathers mana as you fight, then casts something loud.',
    HeroClass.ranger => 'Bow and quiver. Sharp eyes find weak spots, and an Aimed Shot never misses.',
  };

  /// One line for the class picker and the hero panel.
  String get trait => switch (this) {
    HeroClass.knight => '+15 max HP, 5% less damage taken and the best block',
    HeroClass.mage => 'Fire on every attack, and unspent mana shields you (7% a point)',
    HeroClass.ranger => '+10% critical hits and the quickest feet (25% dodge)',
  };

  String get attackVerb => switch (this) {
    HeroClass.knight => 'strike',
    HeroClass.mage => 'cast',
    HeroClass.ranger => 'shoot',
  };

  static HeroClass parse(String? s) => HeroClass.values.firstWhere((c) => c.name == s, orElse: () => HeroClass.knight);
}

/// How a knight's armour variant is drawn: by its tier, or as mail, scales or plate.
enum ArmourLook { auto, mail, scales, plate, lamellar }

class ArmourTier {
  const ArmourTier(this.id, this.name, this.reduction, this.price, this.heroClass, {this.dropOnly = false, this.metal, this.look = ArmourLook.auto, this.perk, this.perkValue = 0, this.perkText});

  /// A variant's own metal colour, how it's drawn, and its small perk (a stat and amount).
  final int? metal;
  final ArmourLook look;
  final String? perk;
  final int perkValue;
  final String? perkText;
  final String id, name;
  final double reduction;
  final int price;
  final HeroClass heroClass;

  /// Never sold: only dropped by dragons or the undead.
  final bool dropOnly;
}

/// Each class has five armour tiers (same protection, different look): its starting kit, the first
/// upgrade from the merchant, and three forged at Dunstan's from bars (see crafting.dart). Plus any
/// armour won in battle.
const armourTiers = <ArmourTier>[
  ArmourTier('padded', 'Mail shirt and gambeson', 0, 0, HeroClass.knight),
  ArmourTier('chainmail', 'Blackened mail', .15, 120, HeroClass.knight),
  ArmourTier('plate', 'Blackened iron plate', .30, 300, HeroClass.knight),
  ArmourTier('gilded', 'Gilded plate', .40, 600, HeroClass.knight),
  ArmourTier('apprentice', 'Apprentice robe', 0, 0, HeroClass.mage),
  ArmourTier('arcane', 'Arcane robe', .15, 120, HeroClass.mage),
  ArmourTier('archmage', 'Archmage vestments', .30, 300, HeroClass.mage),
  ArmourTier('astral', 'Astral raiment', .40, 600, HeroClass.mage),
  ArmourTier('woodsman', "Woodsman's tunic", 0, 0, HeroClass.ranger),
  ArmourTier('studded', 'Studded jerkin', .15, 120, HeroClass.ranger),
  ArmourTier('brigandine', "Ranger's brigandine", .30, 300, HeroClass.ranger),
  ArmourTier('shadowweave', 'Shadowweave', .40, 600, HeroClass.ranger),
  // Tier IV: forged at Dunstan's from emberglass, the Obsidian Golems' ore, set in gold.
  ArmourTier('emberglass', 'Emberglass plate', .45, 0, HeroClass.knight, metal: 0xFF3A2430, look: ArmourLook.plate),
  ArmourTier('emberweave', 'Emberweave mantle', .45, 0, HeroClass.mage),
  ArmourTier('emberhide', 'Emberhide jerkin', .45, 0, HeroClass.ranger),
  ArmourTier('dragonhide', 'Dragonhide armour', .45, 0, HeroClass.ranger, dropOnly: true),
  // Bone armour: only the undead drop it. As good as plate (so it can turn up early without
  // making the forge pointless), and the dead hit you softer while you wear their bones.
  ArmourTier('bonemail', 'Bone-plate armour', .30, 0, HeroClass.knight, dropOnly: true),
  ArmourTier('bonerobe', 'Bonewoven robe', .30, 0, HeroClass.mage, dropOnly: true),
  ArmourTier('bonescale', 'Bone-scale jerkin', .30, 0, HeroClass.ranger, dropOnly: true),
  // Knight armour variants, won in battle: chainmail and platebodies with their own look and perk.
  ArmourTier('riveted', 'Riveted mail', .16, 0, HeroClass.knight, dropOnly: true, metal: 0xFFA8AEB6, look: ArmourLook.mail, perk: 'parry', perkValue: 3, perkText: '+3% parry'),
  ArmourTier('scalemail', 'Scale mail', .18, 0, HeroClass.knight, dropOnly: true, metal: 0xFFB89A62, look: ArmourLook.scales, perk: 'thorns', perkValue: 8, perkText: 'thorns 8'),
  ArmourTier('blackplate', 'Blackened plate', .28, 0, HeroClass.knight, dropOnly: true, metal: 0xFF4E525C, look: ArmourLook.plate, perk: 'block', perkValue: 4, perkText: '+4% block'),
  ArmourTier('fluted', 'Fluted plate', .30, 0, HeroClass.knight, dropOnly: true, metal: 0xFFE2E8EE, look: ArmourLook.plate, perk: 'crit', perkValue: 3, perkText: '+3% crit'),
  ArmourTier('crusader', 'Crusader plate', .30, 0, HeroClass.knight, dropOnly: true, metal: 0xFFF0F2F4, look: ArmourLook.plate, perk: 'guard', perkValue: 4, perkText: '+4% guard'),
  ArmourTier('mithril', 'Mithril mail', .36, 0, HeroClass.knight, dropOnly: true, metal: 0xFFCFE4F2, look: ArmourLook.mail, perk: 'dodge', perkValue: 6, perkText: '+6% dodge'),
  ArmourTier('obsidian', 'Obsidian plate', .40, 0, HeroClass.knight, dropOnly: true, metal: 0xFF2E2A36, look: ArmourLook.plate, perk: 'block', perkValue: 5, perkText: '+5% block'),
  // From the old armouries: plate worn under a heraldic surcoat, and plate under a fur mantle.
  ArmourTier('surcoat', 'Surcoat plate', .30, 0, HeroClass.knight, dropOnly: true, metal: 0xFFB8BEC6, look: ArmourLook.plate, perk: 'regen', perkValue: 10, perkText: 'heal 10 after every win'),
  ArmourTier('furmantle', 'Fur-mantled plate', .38, 0, HeroClass.knight, dropOnly: true, metal: 0xFF8E9AA0, look: ArmourLook.plate, perk: 'vigour', perkValue: 25, perkText: '+25 max HP'),
  // Mage and ranger variants: the same protection as the knight's at each band, their own perks.
  ArmourTier('embroidered', 'Embroidered robe', .16, 0, HeroClass.mage, dropOnly: true, perk: 'crit', perkValue: 3, perkText: '+3% crit'),
  ArmourTier('thornweave', 'Thornweave robe', .18, 0, HeroClass.mage, dropOnly: true, perk: 'thorns', perkValue: 8, perkText: 'thorns 8'),
  ArmourTier('warded', 'Warded robe', .28, 0, HeroClass.mage, dropOnly: true, perk: 'guard', perkValue: 4, perkText: '+4% guard'),
  ArmourTier('sagerobe', 'Sage\'s robe', .30, 0, HeroClass.mage, dropOnly: true, perk: 'wisdom', perkValue: 10, perkText: '+10% XP'),
  ArmourTier('starweave', 'Starweave robe', .36, 0, HeroClass.mage, dropOnly: true, perk: 'dodge', perkValue: 6, perkText: '+6% dodge'),
  ArmourTier('voidrobe', 'Void-silk robe', .40, 0, HeroClass.mage, dropOnly: true, perk: 'block', perkValue: 5, perkText: '+5% block'),
  ArmourTier('scalejerkin', 'Scale jerkin', .16, 0, HeroClass.ranger, dropOnly: true, perk: 'thorns', perkValue: 8, perkText: 'thorns 8'),
  ArmourTier('brigandcoat', 'Brigand\'s coat', .18, 0, HeroClass.ranger, dropOnly: true, perk: 'parry', perkValue: 3, perkText: '+3% parry'),
  ArmourTier('huntleathers', 'Hunter\'s leathers', .28, 0, HeroClass.ranger, dropOnly: true, perk: 'crit', perkValue: 3, perkText: '+3% crit'),
  ArmourTier('wardenmail', 'Warden\'s mail', .30, 0, HeroClass.ranger, dropOnly: true, perk: 'guard', perkValue: 4, perkText: '+4% guard'),
  ArmourTier('nightleathers', 'Night leathers', .36, 0, HeroClass.ranger, dropOnly: true, perk: 'dodge', perkValue: 6, perkText: '+6% dodge'),
  ArmourTier('stormhide', 'Stormhide coat', .40, 0, HeroClass.ranger, dropOnly: true, perk: 'block', perkValue: 5, perkText: '+5% block'),
  // The Blossom Isles: lacquered lamellar, an onmyoji's robes, and a shinobi's dark garb.
  ArmourTier('oyoroi', 'O-yoroi', .42, 0, HeroClass.knight, dropOnly: true, metal: 0xFF8A2A22, look: ArmourLook.lamellar, perk: 'parry', perkValue: 6, perkText: '+6% parry'),
  ArmourTier('onmyoji', 'Onmyoji robes', .42, 0, HeroClass.mage, dropOnly: true, perk: 'wisdom', perkValue: 15, perkText: '+15% XP'),
  ArmourTier('shinobi', 'Shinobi garb', .42, 0, HeroClass.ranger, dropOnly: true, perk: 'dodge', perkValue: 7, perkText: '+7% dodge'),
];

/// The Blossom Isles' armour for each class (it only drops there).
const eastArmour = {HeroClass.knight: 'oyoroi', HeroClass.mage: 'onmyoji', HeroClass.ranger: 'shinobi'};

/// Armour variants by class and level band: (from level, ids). Every class has the same
/// protection on offer at each band; only the perks and looks differ. They never beat what
/// Dunstan can forge at the same point (plate .30, gilded .40): a variant is a side-grade with a
/// perk, and the forge stays the sure way up.
const armourVariants = <HeroClass, List<(int, List<String>)>>{
  HeroClass.knight: [
    (1, ['riveted', 'scalemail']),
    (10, ['riveted', 'scalemail', 'blackplate', 'fluted', 'crusader', 'surcoat']),
    (22, ['blackplate', 'fluted', 'crusader', 'surcoat', 'mithril', 'furmantle', 'obsidian']),
  ],
  HeroClass.mage: [
    (1, ['embroidered', 'thornweave']),
    (10, ['embroidered', 'thornweave', 'warded', 'sagerobe']),
    (22, ['warded', 'sagerobe', 'starweave', 'voidrobe']),
  ],
  HeroClass.ranger: [
    (1, ['scalejerkin', 'brigandcoat']),
    (10, ['scalejerkin', 'brigandcoat', 'huntleathers', 'wardenmail']),
    (22, ['huntleathers', 'wardenmail', 'nightleathers', 'stormhide']),
  ],
};

/// Chance a knight finds an armour variant after a victory (more from bosses and rare foes).
const armourVariantChance = .025, armourVariantChanceBoss = .08;

/// The bone armour tiers.
const boneArmour = {'bonemail', 'bonerobe', 'bonescale'};

/// Undead counters hit this much as hard against bone armour.
const boneWard = .75;

/// Wyrmscale: armour, weapons, helms, gloves and boots made from slain dragons. Each kind of dragon
/// gives its own tier and colour, and every piece strikes dragons harder (Stat.wyrmbane).
class WyrmTier {
  const WyrmTier(this.tier, this.dragon, this.name, this.argb, this.trim);

  /// 1 (Ash Wyvern) to 5 (the Elder Wyrm).
  final int tier;

  /// The dragon's look (its rare and named variants count too).
  final String dragon;
  final String name;
  final int argb, trim;
}

const wyrmTiers = <WyrmTier>[
  WyrmTier(1, 'wyvern', 'Ashen', 0xFF9A8C7C, 0xFFD8CBB8),
  WyrmTier(2, 'mossDragon', 'Mossback', 0xFF5E8E48, 0xFFC8E08A),
  WyrmTier(3, 'frostWyrm', 'Rimescale', 0xFF9CCDE8, 0xFFF0FAFF),
  WyrmTier(4, 'obsidian', 'Obsidian', 0xFF3E3442, 0xFFE0502A),
  WyrmTier(5, 'elderWyrm', 'Elder', 0xFFE2B048, 0xFFFFF0B8),
];

WyrmTier? wyrmTierFor(String dragonLook) => wyrmTiers.where((w) => w.dragon == dragonLook).firstOrNull;

/// A wyrmscale armour tier's id for a class: 'wyrm-knight-3'.
String wyrmArmourId(HeroClass c, int tier) => 'wyrm-${c.name}-$tier';

/// The wyrmscale tier (1 to 5) of an armour id, or null.
int? wyrmTierOfArmour(String id) => id.startsWith('wyrm-') ? int.tryParse(id.split('-').last) : null;

/// Wyrmscale armour: a little better than the merchant's best at every tier, and it strikes
/// dragons harder.
final wyrmArmour = <ArmourTier>[
  for (final w in wyrmTiers)
    for (final c in HeroClass.values)
      ArmourTier(
        wyrmArmourId(c, w.tier),
        switch (c) {
          HeroClass.knight => '${w.name} wyrmplate',
          HeroClass.mage => '${w.name} wyrmscale robe',
          HeroClass.ranger => '${w.name} wyrmhide',
        },
        .30 + .04 * (w.tier - 1),
        0,
        c,
        dropOnly: true,
        metal: w.argb,
        look: c == HeroClass.knight ? ArmourLook.scales : ArmourLook.auto,
        perk: 'wyrmbane',
        perkValue: 3 + 2 * w.tier,
        perkText: '+${3 + 2 * w.tier}% damage to dragons',
      ),
];

List<ArmourTier> tiersFor(HeroClass c) => [...armourTiers, ...wyrmArmour].where((t) => t.heroClass == c).toList();

ArmourTier armourTierById(String id) {
  if (id == 'leather') id = 'padded'; // saves from the first prototype
  return [...armourTiers, ...wyrmArmour].firstWhere((t) => t.id == id, orElse: () => armourTiers.first);
}

/// Index within its class (0 is the starting armour).
int tierIndex(String id) => tiersFor(armourTierById(id).heroClass).indexWhere((t) => t.id == armourTierById(id).id);

/// The class skill: its name and what it does (the fourth button in a fight).
extension HeroClassSkill on HeroClass {
  String get skillName => switch (this) {
    HeroClass.knight => 'Shield Bash',
    HeroClass.mage => 'Cast',
    HeroClass.ranger => 'Aimed Shot',
  };

  String get skillText => switch (this) {
    HeroClass.knight => '1.5x damage, and the foe is too dazed to hit back. Ready every 4 turns.',
    HeroClass.mage => 'Casts your prepared spell. Each attack gathers 1 mana.',
    HeroClass.ranger => 'A sure critical hit that never misses. Ready every 4 turns.',
  };
}

/// Gold to retrain at the Inn as another class.
int retrainCost(int level) => 100 + 20 * level;
