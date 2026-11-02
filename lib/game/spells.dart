// Mage spells. Mages gather mana with every attack; Cast spends it on the prepared spell. New
// spells unlock as you level; choose which one to prepare in your spellbook.

import 'loot.dart';

enum SpellKind { blast, summon, dragon, nova, ward, chain, drain, slow, weaken, expose, heal, charge, reflect, sleep }

class Spell {
  const Spell(this.id, this.name, this.desc, this.level, this.cost, this.kind, this.argb, {this.mult = 1, this.element, this.summons = 0, this.turns = 0, this.wards = 0, this.drain = .5, this.hex = 0, this.mend = 0, this.order, this.rank = 0, this.selfHurt = 0});
  final String id, name, desc;

  /// Hero level needed to learn it, and mana to cast it.
  final int level, cost;
  final SpellKind kind;
  final int argb;

  /// Multiplies the swing's base damage.
  final double mult;

  /// Extra elemental damage (3 per hero level).
  final Stat? element;

  /// Skeletons raised, and how many of your full turns they fight for.
  final int summons, turns;

  /// Counters absorbed by an arcane ward.
  final int wards;

  /// Share of the hit healed back (drain spells).
  final double drain;

  /// Full turns a hex lasts on the foe.
  final int hex;

  /// Share of your health a healing spell restores.
  final double mend;

  /// A class rite: the class (its suit's id) whose rite it is, and the rank in that class it
  /// unlocks at. Null for the rites every knight can learn by level.
  final String? order;
  final int rank;

  /// Share of your health the rite costs you as you cast it (the Blood Pact).
  final double selfHurt;

  /// Every spell can be prepared now (kept for older callers).
  bool get passive => false;
}

const spells = <Spell>[
  Spell('arcanebolt', 'Arcane Bolt', 'A crackling bolt: 1.8x damage', 1, 2, SpellKind.blast, 0xFF9ADFFF, mult: 1.8),
  Spell('sloth', 'Hex of Sloth', 'The foe moves as if through tar: half its counters miss for 4 turns', 2, 2, SpellKind.slow, 0xFF6ABF9A, hex: 4),
  Spell('raisedead', 'Summon Undead', 'Raise a skeleton warrior that fights beside you for 4 turns', 3, 3, SpellKind.summon, 0xFFB07AFF, summons: 1, turns: 4),
  Spell('enfeeble', 'Enfeeble', 'Sap the foe\'s strength: its counters hit 40% softer for 4 turns', 4, 2, SpellKind.weaken, 0xFFB8A0D8, hex: 4),
  Spell('frostnova', 'Frost Nova', 'A burst of ice: 1.5x damage plus frost, and the foe is frozen and can\'t hit back', 5, 3, SpellKind.nova, 0xFF9ADFFF, mult: 1.5, element: Stat.frost),
  Spell('bloodbolt', 'Blood Siphon', 'A crimson bolt that drinks: 1.5x damage, and you heal a third of it', 6, 3, SpellKind.drain, 0xFFB0302A, mult: 1.5, drain: .33),
  Spell('arcaneward', 'Arcane Ward', 'A shimmering ward that absorbs the next 3 counters', 7, 3, SpellKind.ward, 0xFF7FB8E8, wards: 3),
  Spell('sunder', 'Sunder Armour', 'Crack the foe\'s defences: your hits deal 25% more for 4 turns', 8, 3, SpellKind.expose, 0xFFE0A050, hex: 4),
  Spell('dragonfire', 'Summon Dragonfire', 'Call a dragon from the sky to breathe a fireball: 2.2x damage plus fire', 9, 5, SpellKind.dragon, 0xFFFF7A2A, mult: 2.2, element: Stat.burn),
  Spell('slumber', 'Slumber', 'Lull the foe to sleep: it sleeps through its next 3 blows (bosses and giants shake it off after 1)', 10, 3, SpellKind.sleep, 0xFFB8A0E8, hex: 3),
  Spell('spectralcharge', 'Spectral Charge', 'A ghostly warhorse thunders out of the mist and tramples the foe: double damage', 11, 3, SpellKind.charge, 0xFF9ADFFF, mult: 2),
  Spell('chainlightning', 'Chain Lightning', 'Lightning leaps three times: 2.2x damage', 12, 4, SpellKind.chain, 0xFFE8F4FF, mult: 2.2),
  Spell('mirrorward', 'Mirror Ward', 'A shimmering mirror for the next 3 blows: you take half, and the foe takes the whole blow back', 13, 3, SpellKind.reflect, 0xFFCFE8F8, wards: 3),
  Spell('undeadhorde', 'Raise the Horde', 'Three skeletons claw out of the earth and fight for 3 turns', 15, 5, SpellKind.summon, 0xFF8A5AC0, summons: 3, turns: 3),
  Spell('lifedrain', 'Life Drain', 'Drain the foe\'s life: 1.8x damage, and you heal half of it', 18, 4, SpellKind.drain, 0xFF8BE05A, mult: 1.8),
  Spell('healinglight', 'Healing Light', 'A column of golden light: an attack that also mends 30% of your health', 9, 4, SpellKind.heal, 0xFFFFE27A, mend: .3),
  // The late rites, for the long road to the Ember King: each a stronger turn on one you know,
  // at full mana, so none of them makes an earlier one pointless before it's earned its place.
  Spell('emberstorm', 'Ember Storm', 'A storm of cinders leaps from foe to ground to foe: 2.6x damage', 22, 5, SpellKind.chain, 0xFFFF9A4A, mult: 2.6),
  Spell('ashenhex', 'Ashen Hex', 'Choking ash in its lungs: its counters hit 40% softer for 6 turns', 26, 3, SpellKind.weaken, 0xFFA89C8C, hex: 6),
  Spell('phoenix', 'Phoenix Flame', 'Wings of fire fold round you: an attack that also mends 45% of your health', 30, 5, SpellKind.heal, 0xFFFFB04A, mend: .45),
  Spell('bonelegion', 'Bone Legion', 'Four skeletons in rusted mail rise and fight for 3 turns', 35, 5, SpellKind.summon, 0xFF9A7AD0, summons: 4, turns: 3),
  Spell('cataclysm', 'Cataclysm', 'The sky splits and the ash comes down burning: 3x damage plus fire', 40, 5, SpellKind.dragon, 0xFFFF5A2A, mult: 3, element: Stat.burn),

  // Class rites: each class's own, unlocked by rank while you wear its suit (see knight_classes).
  // Built from the same effects as the rites above, so they're new ways to fight, not new rules.
  // The Dragon Knight (Drakesworn): fire and burst.
  Spell('wyrmflame', 'Wyrmflame', 'A gout of wyrmfire from your gauntlet: 2x damage plus fire', 1, 3, SpellKind.blast, 0xFFFF7A2A, mult: 2, element: Stat.burn, order: 'drakesworn', rank: 1),
  Spell('scaleward', 'Scale Ward', 'Your scales harden: the next 2 blows glance off you', 1, 3, SpellKind.ward, 0xFFE8A050, wards: 2, order: 'drakesworn', rank: 4),
  Spell('dragonroar', 'Dragon\'s Roar', 'A roar that shakes its nerve: 1.3x, and your hits deal 25% more for 4 turns', 1, 3, SpellKind.expose, 0xFFFF5A2A, mult: 1.3, hex: 4, order: 'drakesworn', rank: 7),
  // The Blood Knight (Nightblood): drain and sustain.
  Spell('crimsonthirst', 'Crimson Thirst', 'Your blade drinks: 1.6x damage, and you heal half of it', 1, 3, SpellKind.drain, 0xFFC8303A, mult: 1.6, drain: .5, order: 'nightblood', rank: 1),
  Spell('bloodpact', 'Blood Pact', 'Pay 15% of your health for a terrible blow: 2.6x damage', 1, 3, SpellKind.blast, 0xFF8A1020, mult: 2.6, selfHurt: .15, order: 'nightblood', rank: 4),
  Spell('nightveil', 'Night Veil', 'Shadows wrap you: half its blows miss for 3 turns', 1, 2, SpellKind.slow, 0xFF6A4A8A, hex: 3, order: 'nightblood', rank: 7),
  // The Forge Knight (Deepforge): guard and stun.
  Spell('anvilward', 'Anvil Ward', 'Runes of iron ring round you: the next 3 blows are stopped dead', 1, 3, SpellKind.ward, 0xFFE8C060, wards: 3, order: 'deepforge', rank: 1),
  Spell('moltenhammer', 'Molten Hammer', 'A white-hot blow: 2x damage, and it hits 40% softer for 3 turns', 1, 4, SpellKind.weaken, 0xFFFF8A3A, mult: 2, hex: 3, order: 'deepforge', rank: 4),
  Spell('earthshaker', 'Earthshaker', 'You split the ground under it: 1.4x, and it can\'t hit back this turn', 1, 4, SpellKind.nova, 0xFFB08A5A, mult: 1.4, order: 'deepforge', rank: 7),
];

Spell? spellById(String? id) => spells.where((s) => s.id == id).firstOrNull;

/// The most mana a mage can hold.
const maxMana = 5;

/// How many rites fit on the hotbar.
const riteSlots = 3;

/// A summoned skeleton's blow each swing at [level].
int summonHit(int level) => 4 + (level * 1.5).round();


/// Spells known at [level].
List<Spell> spellsKnown(int level) => [for (final s in spells) if (s.order == null && s.level <= level) s];
