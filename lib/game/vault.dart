// The Ember Vault, in Hob's cellar under the Soot & Kettle: Cinder keys drop now and then from
// the foes you fell (more often from tougher ones), and each opens the vault once. Mostly it's
// gold and good gear, but six pieces are found nowhere else. Pure Dart: the rules only.

import 'loot.dart';

/// The chance a fallen foe leaves a Cinder key: an even match, a tough one and a deadly one (see
/// foeMenace), and a boss.
const keyChance = [.02, .045, .08], keyChanceBoss = .25;

/// From one key: the chance it's one of the vault's own pieces (else good gear and gold, else
/// just gold).
const vaultPieceChance = .2, vaultGearChance = .5;

/// Bad luck has a floor: after this many keys in a row without one of the vault's own pieces,
/// the next one is sure to be one (while any are left to find).
const vaultSure = 7;

/// One of the six pieces only the vault holds: each carries a stat no ordinary piece of its kind
/// ever rolls (dodge on a pendant, crit on boots, block on gauntlets, guard on a ring, lifesteal
/// on a helm, block and thorns on a charm), about a
/// legendary's worth all told but never more (so the lands stay where the best gear is). They're
/// a set too ('vault' in loot.dart): any two, then any three worn, add the vault's fire. And they
/// grow with you: each level you gain, every vault piece you own comes up to it (engine's
/// _growVault), so one found early is never outgrown.
class VaultPiece {
  const VaultPiece(this.name, this.slot, this.art, this.stats, this.lore);
  final String name, art, lore;
  final GearSlot slot;

  /// Each stat's strength against an ordinary roll of it.
  final Map<Stat, double> stats;
}

const vaultPieces = <VaultPiece>[
  VaultPiece('Emberwake Pendant', GearSlot.trinket, 'amulet', {Stat.crit: 1.2, Stat.vigour: 1.0, Stat.dodge: 1.1, Stat.damage: .45}, 'Warm as a hearthstone that never quite cooled.'),
  VaultPiece('Ashwalker Boots', GearSlot.boots, 'boots', {Stat.dodge: 1.7, Stat.crit: 1.2, Stat.vigour: 1.0, Stat.guard: .9}, 'Salamander-hide soles. They leave no footprints, only scorch marks.'),
  VaultPiece('Keeper\'s Gauntlets', GearSlot.gloves, 'gauntlets', {Stat.damage: 1.4, Stat.crit: 1.6, Stat.block: 1.4}, 'Whoever kept the vault kept these on. Mostly.'),
  VaultPiece('Ring of the Ember Vault', GearSlot.ring, 'ring', {Stat.lifesteal: 1.5, Stat.guard: 1.1, Stat.damage: .8, Stat.fortune: .8}, 'A key-ring once. The keys are long gone, the habit isn\'t.'),
  VaultPiece('Cinder Crown', GearSlot.helm, 'greathelm', {Stat.guard: 1.5, Stat.vigour: 1.5, Stat.lifesteal: 1.5}, 'Forged for a king who never came back for it.'),
  VaultPiece('Brimstone Charm', GearSlot.trinket, 'charm', {Stat.block: 1.4, Stat.thorns: 1.4, Stat.regen: .8, Stat.damage: .35}, 'Smells of struck matches. Ill-wishers keep their distance.'),
];

VaultPiece? vaultPieceNamed(String name) => vaultPieces.where((p) => p.name == name).firstOrNull;

/// What one key brought out of the vault.
class VaultFind {
  const VaultFind(this.gold, this.item, {this.piece = false});
  final int gold;
  final GearItem? item;

  /// [item] is one of the vault's own six.
  final bool piece;
}

/// The Guardian's Oath: everything the vault keeps, found. From then on, the first heavy blow
/// a foe brings down on you each fight (the one it rears back for) meets your shield and lands no
/// harder than an ordinary blow.
bool guardianSworn(List<String> found) => vaultPieces.every((p) => found.contains(p.name));
