// The Ember Vault, in Hob's cellar under the Soot & Kettle: Ashen keys drop now and then from
// the foes you fell (more often from tougher ones), and each opens the vault once. Mostly it's
// gold and good gear, but six pieces are found nowhere else. Pure Dart: the rules only.

import 'loot.dart';

/// The chance a fallen foe leaves an Ashen key: an even match, a tough one and a deadly one (see
/// foeMenace), and a boss.
const keyChance = [.02, .045, .08], keyChanceBoss = .25;

/// From one key: the chance it's one of the vault's own pieces (else good gear and gold, else
/// just gold).
const vaultPieceChance = .2, vaultGearChance = .5;

/// One of the six pieces only the vault holds: each an odd mix no other gear has, about a
/// legendary's worth all told but never more (so the lands stay where the best gear is).
class VaultPiece {
  const VaultPiece(this.name, this.slot, this.art, this.stats, this.lore);
  final String name, art, lore;
  final GearSlot slot;

  /// Each stat's strength against an ordinary roll of it.
  final Map<Stat, double> stats;
}

const vaultPieces = <VaultPiece>[
  VaultPiece('Emberwake Pendant', GearSlot.trinket, 'amulet', {Stat.crit: 1.4, Stat.regen: 1.4, Stat.wisdom: 1.2}, 'Warm as a hearthstone that never quite cooled.'),
  VaultPiece('Ashwalker Boots', GearSlot.boots, 'boots', {Stat.dodge: 1.8, Stat.thorns: 1.6}, 'Salamander-hide soles. They leave no footprints, only scorch marks.'),
  VaultPiece('Keeper\'s Gauntlets', GearSlot.gloves, 'gauntlets', {Stat.crit: 2.0, Stat.parry: 1.3}, 'Whoever kept the vault kept these on. Mostly.'),
  VaultPiece('Ring of the Ember Vault', GearSlot.ring, 'ring', {Stat.fortune: 2.0, Stat.lifesteal: 1.3}, 'A key-ring once. The keys are long gone, the habit isn\'t.'),
  VaultPiece('Cinder Crown', GearSlot.helm, 'greathelm', {Stat.guard: 1.5, Stat.vigour: 1.8}, 'Forged for a king who never came back for it.'),
  VaultPiece('Brimstone Charm', GearSlot.trinket, 'charm', {Stat.block: 1.5, Stat.thorns: 1.6, Stat.regen: .9}, 'Smells of struck matches. Ill-wishers keep their distance.'),
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
