// Enchantments: a rune on your weapon and one on your armour. The merchant's enchanter rolls one
// at random for gold (tier I, II or rare III), and you keep it or keep what you had. Some drops
// come already enchanted.

import 'dart:math' as math;

import 'loot.dart';

enum EnchantSlot { weapon, armour }

class Enchantment {
  const Enchantment(this.id, this.name, this.slot, this.stat, this.scale);
  final String id, name;
  final EnchantSlot slot;
  final Stat stat;

  /// Relative strength, against the usual roll for that stat.
  final double scale;
}

const enchantments = <Enchantment>[
  // Weapon runes.
  Enchantment('flametongue', 'Flametongue', EnchantSlot.weapon, Stat.burn, 1.0),
  Enchantment('venomfang', 'Venomfang', EnchantSlot.weapon, Stat.poison, 1.0),
  Enchantment('frostbite', 'Frostbite', EnchantSlot.weapon, Stat.frost, 1.0),
  Enchantment('holylight', 'Holy Light', EnchantSlot.weapon, Stat.smite, 1.0),
  Enchantment('keenedge', 'Keen Edge', EnchantSlot.weapon, Stat.crit, .8),
  Enchantment('vampiric', 'Vampiric', EnchantSlot.weapon, Stat.lifesteal, .9),
  Enchantment('might', 'Might', EnchantSlot.weapon, Stat.damage, .8),
  Enchantment('wyrmslayer', 'Wyrmslayer', EnchantSlot.weapon, Stat.dragonkin, 1.2),
  Enchantment('riposte', 'Riposte', EnchantSlot.weapon, Stat.parry, .8),
  Enchantment('bloodleech', 'Bloodleech', EnchantSlot.weapon, Stat.leech, .6),
  // Armour runes.
  Enchantment('warding', 'Warding', EnchantSlot.armour, Stat.guard, .9),
  Enchantment('vitality', 'Vitality', EnchantSlot.armour, Stat.vigour, 1.0),
  Enchantment('renewal', 'Renewal', EnchantSlot.armour, Stat.regen, 1.0),
  Enchantment('thornmail', 'Thornmail', EnchantSlot.armour, Stat.thorns, 1.0),
  Enchantment('fleetfoot', 'Fleetfoot', EnchantSlot.armour, Stat.dodge, .7),
  Enchantment('steadfast', 'Steadfast', EnchantSlot.armour, Stat.block, .8),
  Enchantment('prosperity', 'Prosperity', EnchantSlot.armour, Stat.fortune, 1.0),
  Enchantment('sage', 'the Sage', EnchantSlot.armour, Stat.wisdom, 1.0),
];

Enchantment? enchantmentById(String id) => enchantments.where((e) => e.id == id).firstOrNull;

/// One enchantment as applied: which rune, its tier (1–3) and its value.
class EnchantRoll {
  const EnchantRoll(this.id, this.tier, this.value);
  final String id;
  final int tier, value;

  Enchantment get info => enchantmentById(id)!;
  String get title => '${info.name} ${const ['I', 'II', 'III'][(tier - 1).clamp(0, 2)]}';
  String get describe => info.stat.describe(value);

  Map<String, dynamic> toJson() => {'e': id, 't': tier, 'v': value};
  static EnchantRoll? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['e'] as String?;
    if (id == null || enchantmentById(id) == null) return null;
    return EnchantRoll(id, (j['t'] as num?)?.toInt() ?? 1, (j['v'] as num?)?.toInt() ?? 1);
  }
}

/// The enchanter's fee at [level].
int enchantCost(int level) => 40 + 8 * level;

/// Rolls a random rune for [slot]: tier I 60%, II 30%, III 10%. [tierFloor] raises the minimum.
EnchantRoll rollEnchant(EnchantSlot slot, int level, math.Random rng, {int tierFloor = 1}) {
  final pool = enchantments.where((e) => e.slot == slot).toList();
  final e = pool[rng.nextInt(pool.length)];
  final r = rng.nextDouble();
  final tier = math.max(tierFloor, r < .6 ? 1 : (r < .9 ? 2 : 3));
  final value = math.max(1, (statRoll(e.stat, level) * e.scale * const [.6, 1.0, 1.5][tier - 1]).round());
  return EnchantRoll(e.id, tier, value);
}

/// Three different runes for [slot] to choose from (a scroll, or the enchanter's fee), each its
/// own tier. Runes in [skip] aren't offered (Wyrmslayer to someone with no dragon). Each card's
/// tier is a little less generous than a single roll's, so the chance that a III is among the
/// three stays about what one roll's was (one in ten).
List<EnchantRoll> rollChoices(EnchantSlot slot, int level, math.Random rng, {int count = 3, Set<String> skip = const {}}) {
  final pool = enchantments.where((e) => e.slot == slot && !skip.contains(e.id)).toList()..shuffle(rng);
  return [
    for (final e in pool.take(count))
      () {
        final r = rng.nextDouble(), tier = r < .71 ? 1 : (r < .965 ? 2 : 3);
        return EnchantRoll(e.id, tier, math.max(1, (statRoll(e.stat, level) * e.scale * const [.6, 1.0, 1.5][tier - 1]).round()));
      }(),
  ];
}

/// A chosen rune (by id), worked well: tier II, or III a quarter of the time (an elemental's cores
/// bound by Old Wick).
EnchantRoll boundRune(String id, int level, math.Random rng) {
  final e = enchantmentById(id)!, tier = rng.nextDouble() < .25 ? 3 : 2;
  return EnchantRoll(id, tier, math.max(1, (statRoll(e.stat, level) * e.scale * const [.6, 1.0, 1.5][tier - 1]).round()));
}
