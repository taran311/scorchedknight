// Special ammunition: burning, blessed and bloodleech shots, three clear jobs (burst, holy fire
// against anything, healing). One is
// spent on each full swing and adds its effect to the hit. Arrows for bows, bolts for crossbows,
// edges for chakrams and coatings for throwing knives: the same five kinds, named for the weapon.

import 'loot.dart';

enum AmmoType { fire, blessed, leech }

/// What a ranger's weapon fires, for naming the ammunition.
enum Missile { arrow, bolt, chakram, knife }

/// The missile a weapon uses, or null if it takes no special ammunition (hand cannons, melee).
Missile? missileFor(String? weaponArt) => switch (weaponArt) {
  'bow' || 'longbow' || 'orkbow' || 'heartbow' || 'runebow' || 'yumi' => Missile.arrow,
  'crossbow' || 'handcrossbow' => Missile.bolt,
  'chakram' => Missile.chakram,
  'throwingknives' || 'shuriken' || 'tomahawk' => Missile.knife,
  _ => null,
};

extension AmmoInfo on AmmoType {
  /// "Poisoned arrows", "Burning bolts", "Frost-edged chakrams", "Serrated knives"...
  String label(Missile? m) {
    final noun = switch (m) {
      Missile.bolt => 'bolts',
      Missile.chakram => 'chakrams',
      Missile.knife => 'knives',
      Missile.arrow || null => 'arrows',
    };
    final edged = m == Missile.chakram;
    final word = switch (this) {
      AmmoType.fire => edged ? 'Flame-edged' : 'Burning',
      AmmoType.blessed => 'Blessed',
      AmmoType.leech => 'Bloodleech',
    };
    return '$word $noun';
  }

  String get desc => switch (this) {
    AmmoType.fire => 'Adds fire to each crossbow shot (ents burn twice as hard)',
    AmmoType.blessed => 'Holy fire on each crossbow shot, against any foe',
    AmmoType.leech => 'Each crossbow shot heals you 15% of its damage',
  };

  int get argb => switch (this) {
    AmmoType.fire => 0xFFFF8A2A,
    AmmoType.blessed => 0xFFFFE27A,
    AmmoType.leech => 0xFFB0302A,
  };

  /// The element it adds (bloodleech heals instead).
  Stat? get stat => switch (this) {
    AmmoType.fire => Stat.burn,
    AmmoType.blessed => Stat.smite,
    AmmoType.leech => null,
  };

  /// Price of a bundle of [ammoBundle] at the merchant.
  int get price => switch (this) {
    AmmoType.blessed || AmmoType.leech => 45,
    AmmoType.fire => 35,
  };
}

/// Shots in a bundle.
const ammoBundle = 10;

/// Extra damage per shot at [level].
int ammoBonus(int level) => 3 + (level * 1.2).round();

AmmoType? ammoById(String? id) => AmmoType.values.where((a) => a.name == id).firstOrNull;
