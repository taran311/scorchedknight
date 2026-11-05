// Mage spells. Mages gather mana with every attack; Cast spends it on the prepared spell. New
// spells unlock as you level; choose which one to prepare in your spellbook.

import 'loot.dart';

enum SpellKind { blast, summon, dragon, nova, ward, chain, drain, slow, weaken, expose, heal, charge, reflect, sleep, warcry, fester, bloodedge }

class Spell {
  const Spell(this.id, this.name, this.desc, this.level, this.cost, this.kind, this.argb, {this.mult = 1, this.element, this.summons = 0, this.turns = 0, this.wards = 0, this.drain = .5, this.hex = 0, this.mend = 0, this.order, this.rank = 0, this.selfHurt = 0, this.earned});
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

  /// A rite won rather than learned by level: where it's won (it's known once it's in
  /// [Knight.earnedRites]).
  final String? earned;

  /// Every spell can be prepared now (kept for older callers).
  bool get passive => false;
}

/// Blood Edge: how much your next blade blow adds, in whole swings (the old Blood Pact's 2.6x, saved
/// for the blow you choose).
const bloodEdgeBonus = 2.6;

/// Fester: how many turns of the foe's affliction it brings on at once.
const festerTurns = 4;

const spells = <Spell>[
  Spell('arcanebolt', 'Arcane Bolt', 'A crackling bolt: 2x damage', 1, 2, SpellKind.blast, 0xFF9ADFFF, mult: 2),
  Spell('sloth', 'Hex of Sloth', 'The foe moves as if through tar: half its counters miss for 3 turns', 2, 3, SpellKind.slow, 0xFF6ABF9A, hex: 3),
  Spell('raisedead', 'Summon Undead', 'Raise a skeleton warrior that fights beside you for 4 turns', 3, 3, SpellKind.summon, 0xFFB07AFF, summons: 1, turns: 4),
  Spell('enfeeble', 'Enfeeble', 'Sap the foe\'s strength: its counters hit 40% softer for 3 turns', 4, 3, SpellKind.weaken, 0xFFB8A0D8, hex: 3),
  Spell('frostnova', 'Frost Nova', 'A burst of ice: 1.5x damage plus frost, and the foe is frozen and can\'t hit back', 5, 3, SpellKind.nova, 0xFF9ADFFF, mult: 1.5, element: Stat.frost),
  Spell('bloodbolt', 'Blood Siphon', 'A crimson bolt that drinks: 1.5x damage, and you heal a fifth of it', 6, 3, SpellKind.drain, 0xFFB0302A, mult: 1.5, drain: .2),
  Spell('arcaneward', 'Arcane Ward', 'A shimmering ward that absorbs the next 2 counters', 7, 4, SpellKind.ward, 0xFF7FB8E8, wards: 2),
  Spell('sunder', 'Sunder Armour', 'A cracking blow (1.4x), and the foe\'s defences give: your hits deal 25% more for 4 turns', 8, 3, SpellKind.expose, 0xFFE0A050, mult: 1.4, hex: 4),
  Spell('dragonfire', 'Summon Dragonfire', 'Call a dragon from the sky to breathe a fireball: 2.5x damage plus fire', 9, 4, SpellKind.dragon, 0xFFFF7A2A, mult: 2.5, element: Stat.burn),
  Spell('slumber', 'Slumber', 'Lull the foe to sleep: it sleeps through its next 2 blows (bosses shake it off after 1, and a foe lulled again in the same fight sleeps through just 1)', 10, 3, SpellKind.sleep, 0xFFB8A0E8, hex: 2),
  Spell('fester', 'Fester', 'A heavy blow (2x), and whatever is eating at the foe erupts: $festerTurns turns of its fire, venom or bleeding at once (fire and bleeding are kept going)', 12, 3, SpellKind.fester, 0xFFB4D25A, mult: 2),
  Spell('spectralcharge', 'Spectral Charge', 'A ghostly warhorse thunders out of the mist and tramples the foe: 2.3x damage', 11, 3, SpellKind.charge, 0xFF9ADFFF, mult: 2.3),
  Spell('chainlightning', 'Chain Lightning', 'Lightning leaps three times: 2.5x damage', 12, 4, SpellKind.chain, 0xFFE8F4FF, mult: 2.5),
  Spell('mirrorward', 'Mirror Ward', 'A shimmering mirror for the next 2 blows: you take half, and the foe takes the other half back', 13, 4, SpellKind.reflect, 0xFFCFE8F8, wards: 2),
  Spell('undeadhorde', 'Raise the Horde', 'Three skeletons claw out of the earth and fight for 3 turns', 15, 4, SpellKind.summon, 0xFF8A5AC0, summons: 3, turns: 3),
  Spell('lifedrain', 'Life Drain', 'Drain the foe\'s life: 1.6x damage, and you heal a quarter of it', 18, 4, SpellKind.drain, 0xFF8BE05A, mult: 1.6, drain: .25),
  Spell('healinglight', 'Healing Light', 'A column of golden light: an attack that also mends 30% of your health', 9, 4, SpellKind.heal, 0xFFFFE27A, mend: .3, mult: 1.3),
  // The late rites, for the long road to the Ember King: each a stronger turn on one you know,
  // at full mana, so none of them makes an earlier one pointless before it's earned its place.
  Spell('emberstorm', 'Ember Storm', 'A storm of cinders leaps from foe to ground to foe: 3x damage', 22, 4, SpellKind.chain, 0xFFFF9A4A, mult: 3),
  Spell('ashenhex', 'Ashen Hex', 'Choking ash in its lungs: its counters hit 40% softer for 4 turns', 26, 2, SpellKind.weaken, 0xFFA89C8C, hex: 4),
  Spell('phoenix', 'Phoenix Flame', 'Wings of fire fold round you: an attack that also mends 35% of your health', 30, 5, SpellKind.heal, 0xFFFFB04A, mend: .35, mult: 1.5),
  Spell('bonelegion', 'Bone Legion', 'Four skeletons in rusted mail rise and fight for 3 turns', 35, 5, SpellKind.summon, 0xFF9A7AD0, summons: 4, turns: 3),
  Spell('cataclysm', 'Cataclysm', 'An elder wyrm darkens the sky and pours its fire over the foe: 3.5x damage plus fire', 40, 5, SpellKind.dragon, 0xFFFF5A2A, mult: 3.5, element: Stat.burn),
  // Won, not learned: the Hall of the Slain teaches its War Cry to the living who survive its second wave.
  Spell('warcry', 'War Cry', 'A roar from the old hall: your blows land 25% harder for 3 turns, and any war cry the foe has raised is drowned out', 1, 3, SpellKind.warcry, 0xFFCFE0F0, hex: 3, earned: 'the Hall of the Slain'),

  // Class rites: each class's own, unlocked by rank while you wear its suit (see knight_classes).
  // Built from the same effects as the rites above, so they're new ways to fight, not new rules.
  // The Dragon Knight (Drakesworn): fire and burst.
  Spell('wyrmflame', 'Wyrmflame', 'A gout of wyrmfire from your gauntlet: 2x damage plus fire', 1, 3, SpellKind.blast, 0xFFFF7A2A, mult: 2, element: Stat.burn, order: 'drakesworn', rank: 1),
  Spell('scaleward', 'Scale Ward', 'Your scales harden: the next 2 blows glance off you', 1, 3, SpellKind.ward, 0xFFE8A050, wards: 2, order: 'drakesworn', rank: 4),
  Spell('dragonroar', 'Dragon\'s Roar', 'A roar that shakes its nerve: 1.3x, and your hits deal 25% more for 4 turns', 1, 3, SpellKind.expose, 0xFFFF5A2A, mult: 1.3, hex: 4, order: 'drakesworn', rank: 7),
  // The Blood Knight (Nightblood): drain and sustain.
  Spell('crimsonthirst', 'Crimson Thirst', 'Your blade drinks: 1.6x damage, and you heal a third of it', 1, 3, SpellKind.drain, 0xFFC8303A, mult: 1.6, drain: .35, order: 'nightblood', rank: 1),
  // (Its id is still the old Blood Pact's, so hotbars saved with it keep it.)
  Spell('bloodpact', 'Blood Edge', 'Bleed 15% of your health onto your blade: your next attack or Mighty Blow can\'t miss and lands +${bloodEdgeBonus}x harder', 1, 3, SpellKind.bloodedge, 0xFFC8303A, selfHurt: .15, order: 'nightblood', rank: 4),
  Spell('nightveil', 'Night Veil', 'Shadows wrap you: half its blows miss for 3 turns', 1, 3, SpellKind.slow, 0xFF6A4A8A, hex: 3, order: 'nightblood', rank: 7),
  // The Forge Knight (Deepforge): guard and stun.
  Spell('anvilward', 'Anvil Ward', 'Runes of iron ring round you: the next 2 blows are stopped dead', 1, 3, SpellKind.ward, 0xFFE8C060, wards: 2, order: 'deepforge', rank: 1),
  Spell('moltenhammer', 'Molten Hammer', 'A white-hot blow: 2x damage, and it hits 40% softer for 3 turns', 1, 4, SpellKind.weaken, 0xFFFF8A3A, mult: 2, hex: 3, order: 'deepforge', rank: 4),
  Spell('earthshaker', 'Earthshaker', 'You split the ground under it: 1.4x, and it can\'t hit back this turn', 1, 5, SpellKind.nova, 0xFFB08A5A, mult: 1.4, order: 'deepforge', rank: 7),
];

Spell? spellById(String? id) => spells.where((s) => s.id == id).firstOrNull;

/// The most mana a mage can hold.
const maxMana = 5;

/// How many rites fit on the hotbar.
const riteSlots = 3;

/// A summoned skeleton's blow each swing at [level].
// (A skeleton's blow: see summonHit in rules.dart, half of one of yours.)


/// Spells known at [level].
List<Spell> spellsKnown(int level) => [for (final s in spells) if (s.order == null && s.earned == null && s.level <= level) s];
