// Mags' apothecary: brews made from the reagents your foes drop (the same herbs, salts and glowing
// things the wards are made from), for a little gold. Most are drunk there and then and last your
// next few fights; the healing draught fills your potion belt instead, for drinking mid-fight.
// Pure Dart.

import 'catalog.dart';
import 'models.dart';

enum Brew { healing, might, arcane, hawkeye, barkskin, wisp, reaperbane }

/// Fights a drunk brew lasts.
const brewFights = 3;

/// How strong each one is.
const mightBrew = 1.15, arcaneBrew = 1.2, hawkeyeBrew = 1.2, barkskinBrew = .85, wispMana = 2;

/// Reaper's Bane: when a blow would knock you out, you stay up with this share of your HP instead
/// (once, then it's spent).
const reaperbaneHp = .3;

/// Healing draughts a brew makes.
const healingDraughts = 2;

extension BrewInfo on Brew {
  String get label => switch (this) {
    Brew.healing => 'Healing draughts',
    Brew.might => 'Draught of Might',
    Brew.arcane => 'Arcane draught',
    Brew.hawkeye => 'Hawkeye draught',
    Brew.barkskin => 'Barkskin brew',
    Brew.wisp => 'Wisp-light tonic',
    Brew.reaperbane => 'Reaper\'s Bane',
  };

  /// What it does, in a line.
  String get desc => switch (this) {
    Brew.healing => '$healingDraughts health potions for your belt, to drink mid-fight',
    Brew.might => 'Weapon blows hit +${((mightBrew - 1) * 100).round()}% for $brewFights fights',
    Brew.arcane => 'Rites hit +${((arcaneBrew - 1) * 100).round()}% for $brewFights fights',
    Brew.hawkeye => 'Crossbow shots hit +${((hawkeyeBrew - 1) * 100).round()}% for $brewFights fights',
    Brew.barkskin => 'Take ${((1 - barkskinBrew) * 100).round()}% less damage for $brewFights fights',
    Brew.wisp => 'Start each of your next $brewFights fights with +$wispMana mana',
    Brew.reaperbane => 'The next blow that would knock you out leaves you standing on ${(reaperbaneHp * 100).round()}% HP',
  };

  /// Short, for a status badge.
  String get badge => switch (this) {
    Brew.healing => 'Healing',
    Brew.might => 'Might',
    Brew.arcane => 'Arcane',
    Brew.hawkeye => 'Hawkeye',
    Brew.barkskin => 'Barkskin',
    Brew.wisp => 'Wisp-light',
    Brew.reaperbane => 'Reaper\'s Bane',
  };

  int get argb => switch (this) {
    Brew.healing => 0xFFD8402E,
    Brew.might => 0xFFE87A2A,
    Brew.arcane => 0xFFB07AFF,
    Brew.hawkeye => 0xFF6AC8E8,
    Brew.barkskin => 0xFF7AA84A,
    Brew.wisp => 0xFF4A82E0,
    Brew.reaperbane => 0xFF9CF6E6,
  };

  /// The land whose reagent it's brewed from (an index into [continents]).
  int get land => switch (this) {
    Brew.healing || Brew.might => 0,
    Brew.arcane || Brew.wisp => 1,
    Brew.barkskin || Brew.hawkeye => 2,
    Brew.reaperbane => 4,
  };

  String get ingredient => continents[land].reagent;

  /// Reagents it takes.
  int get reagents => this == Brew.reaperbane ? 3 : 2;

  /// Mags' fee at [level].
  int fee(int level) => (this == Brew.reaperbane ? 30 : 6) + 2 * level;

  /// Drunk on the spot and lasting [brewFights] fights (everything but the healing draughts).
  bool get lasting => this != Brew.healing;
}

Brew? brewById(String id) => Brew.values.where((b) => b.name == id).firstOrNull;

/// Whether [b] is working on [k] right now.
bool brewOn(Knight k, Brew b) => (k.brews[b.name] ?? 0) > 0;

/// The brews working on [k], with the fights each has left.
List<(Brew, int)> activeBrews(Knight k) => [for (final b in Brew.values) if (brewOn(k, b)) (b, k.brews[b.name]!)];
