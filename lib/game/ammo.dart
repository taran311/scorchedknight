// Special ammunition: five kinds, each with its own job. Burning shots set the foe ablaze (fire
// every turn for a few turns); blessed shots are holy fire, a little against anything and a lot
// against the undead; bloodleech shots heal you; frost shots may freeze the foe out of its next
// blow; venom shots build up poison that eats at it every turn for the rest of the fight. One is
// spent on each shot. Arrows for bows, bolts for crossbows,
// edges for chakrams and coatings for throwing knives: the same five kinds, named for the weapon.

import 'dart:math' as math;

import 'loot.dart';

enum AmmoType { fire, blessed, leech, frost, venom }

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
      AmmoType.frost => edged ? 'Frost-edged' : 'Frost-tipped',
      AmmoType.venom => m == Missile.knife ? 'Envenomed' : 'Venom-tipped',
    };
    return '$word $noun';
  }

  /// What it does, in a line (no numbers).
  String get desc => switch (this) {
    AmmoType.fire => 'Sets the foe ablaze: fire every turn for $burnTurns turns',
    AmmoType.blessed => 'Holy fire: a little against anything, a lot against the undead',
    AmmoType.leech => 'Each shot heals you 15% of its damage',
    AmmoType.frost => 'A chill on each shot, and a chance to freeze the foe out of its next blow',
    AmmoType.venom => 'Each shot adds venom that eats at the foe every turn, building up',
  };

  /// What it does at [level], with the numbers.
  String describe(int level) => switch (this) {
    AmmoType.fire => 'Sets the foe ablaze: ${burnTick(level)} fire a turn for $burnTurns turns (ents burn twice as hard)',
    AmmoType.blessed => '+${holyShot(level, false)} holy fire, +${holyShot(level, true)} against the undead and demons',
    AmmoType.leech => 'Each shot heals you 15% of its damage',
    AmmoType.frost => '+${(ammoBonus(level) * frostShare).round()} frost, and a ${(freezeChance * 100).round()}% chance to freeze the foe out of its next blow',
    AmmoType.venom => 'Each shot adds ${venomTick(level)} venom a turn, for the rest of the fight (it stacks)',
  };

  /// What it does, in a few words (for a chip).
  String short(int level) => switch (this) {
    AmmoType.fire => '${burnTick(level)} burn ×$burnTurns turns',
    AmmoType.blessed => '+${holyShot(level, false)} holy · +${holyShot(level, true)} vs undead',
    AmmoType.leech => 'Heals 15% of the hit',
    AmmoType.frost => '+${(ammoBonus(level) * frostShare).round()} frost · ${(freezeChance * 100).round()}% freeze',
    AmmoType.venom => '+${venomTick(level)} venom a turn, stacks',
  };

  int get argb => switch (this) {
    AmmoType.fire => 0xFFFF8A2A,
    AmmoType.blessed => 0xFFFFE27A,
    AmmoType.leech => 0xFFB0302A,
    AmmoType.frost => 0xFF9ADFFF,
    AmmoType.venom => 0xFF8FD36A,
  };

  /// The element it adds to the shot itself (burning and venom work over the turns after;
  /// bloodleech heals instead).
  Stat? get stat => switch (this) {
    AmmoType.blessed => Stat.smite,
    AmmoType.frost => Stat.frost,
    AmmoType.fire || AmmoType.leech || AmmoType.venom => null,
  };

  /// Price of a bundle of [ammoBundle] at the merchant.
  int get price => switch (this) {
    AmmoType.blessed || AmmoType.leech || AmmoType.frost => 45,
    AmmoType.fire || AmmoType.venom => 40,
  };
}

/// Shots in a bundle.
const ammoBundle = 10;

/// Extra damage per shot at [level].
int ammoBonus(int level) => 3 + (level * 1.2).round();

/// Burning shots: fire each turn (a share of a shot's bonus) and for how many turns. A fresh shot
/// rekindles it; it doesn't stack.
const burnTurns = 3, burnShare = .9;
int burnTick(int level) => (ammoBonus(level) * burnShare).round();

/// Blessed shots: holy fire, light against the living and heavy against the undead and demons.
int holyShot(int level, bool unholy) => (ammoBonus(level) * (unholy ? 1.6 : .6)).round();

/// Frost shots: a smaller chill than the others' bonus, and the chance to freeze the foe out of
/// its next blow (half that against a boss).
const frostShare = .5, freezeChance = .25;

/// Venom shots: each adds a stack doing this much every turn for the rest of the fight.
const venomShare = .3;
int venomTick(int level) => math.max(1, (ammoBonus(level) * venomShare).round());

AmmoType? ammoById(String? id) => AmmoType.values.where((a) => a.name == id).firstOrNull;
