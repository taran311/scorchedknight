// Rare foes: the same foe, dressed in its aura. Gilded foes wear gold, cursed ones purple, blazing
// ones ember, venomous ones green, frostbound ones ice and ancient ones bleached bone. Everyone's
// eyes and weapons glow with the aura; named bosses also get a crown and a legendary shimmer.

import 'dart:ui';

import '../game/catalog.dart';
import 'creatures.dart';
import 'looks.dart';
import 'paint_kit.dart';

Color auraColour(Aura a) => Color(a.argb);

/// The metal a rare foe's armour turns to.
Ramp _metal(Aura a) => switch (a) {
  Aura.gilded => const [Color(0xFFF6E2A0), Color(0xFFC49A3C), Color(0xFF5E4416)],
  Aura.cursed => const [Color(0xFFB89AD8), Color(0xFF5E3A8A), Color(0xFF22123A)],
  Aura.blazing => const [Color(0xFFF2A070), Color(0xFF9A3A1A), Color(0xFF3A1008)],
  Aura.venom => const [Color(0xFFB0D88A), Color(0xFF4E7A2E), Color(0xFF1A2A0E)],
  Aura.frost => const [Color(0xFFEFF8FF), Color(0xFF8AB8D8), Color(0xFF2E4A64)],
  Aura.ancient => const [Color(0xFFF2EAD0), Color(0xFFB8AC8A), Color(0xFF4E4636)],
};

Ramp _tintRamp(Ramp r, Color to, double f) => [for (final c in r) Color.lerp(c, to, f)!];
Ramp? _tintMaybe(Ramp? r, Color to, double f) => r == null ? null : _tintRamp(r, to, f);

/// How strongly the aura tints cloth and skin.
double _wash(Aura a) => switch (a) {
  Aura.gilded => .12,
  Aura.ancient => .35,
  Aura.frost => .3,
  _ => .22,
};

final Map<String, Look> _lookCache = {};

/// [base] dressed in [aura]'s colours (a bit bigger, glowing eyes and weapons).
Look auraLook(Look base, Aura aura, {bool named = false}) => _lookCache.putIfAbsent('${base.hashCode}:${aura.name}:$named', () {
  final glow = auraColour(aura), metal = _metal(aura), wash = _wash(aura);
  final armoured = base.helm != null || base.pauldron != null;
  final ent = base.torsoKind == TorsoKind.bark || base.build == 'giant' || base.scale > 1.5 || base.ghostly || base.head == HeadKind.bull; // ents, giants, spirits and beasts get no armour, capes or crowns
  return Look(
    build: base.build,
    stance: base.stance,
    scale: base.scale * (named ? 1.14 : 1.07),
    skin: _tintRamp(base.skin, glow, wash * .7),
    torso: armoured ? metal : _tintRamp(base.torso, glow, wash),
    upper: _tintRamp(base.upper, glow, wash),
    fore: _tintRamp(base.fore, glow, wash),
    hand: _tintRamp(base.hand, glow, wash * .7),
    thigh: _tintRamp(base.thigh, glow, wash),
    shin: _tintRamp(base.shin, glow, wash),
    boot: _tintRamp(base.boot, glow, wash * .6),
    head: base.head,
    torsoKind: base.torsoKind,
    knee: base.knee == null ? null : metal,
    elbow: base.elbow == null ? null : metal,
    pauldron: named && !ent ? metal : (base.pauldron == null ? null : metal),
    tabard: base.tabard == null ? null : Color.lerp(base.tabard, glow, .45),
    trim: aura == Aura.gilded ? const Color(0xFFFFE08A) : (base.trim == null ? null : Color.lerp(base.trim, glow, .5)),
    emblem: base.emblem,
    belt: Color.lerp(base.belt, glow, .2)!,
    pouch: base.pouch,
    cape: named && !ent ? shade(glow, -.45) : (base.cape == null ? null : Color.lerp(base.cape, glow, .35)),
    tattered: base.tattered,
    capeFlow: base.capeFlow,
    helm: base.helm == null ? null : metal,
    plume: base.plume == null ? null : glow,
    eyeGlow: glow,
    crown: base.crown || (named && !ent),
    hair: Color.lerp(base.hair, glow, wash)!,
    beard: base.beard == null ? null : Color.lerp(base.beard, glow, wash),
    hood: _tintMaybe(base.hood, glow, wash),
    mask: _tintMaybe(base.mask, glow, wash),
    maskTrim: base.maskTrim == null ? null : glow,
    weapon: base.weapon,
    offhand: base.offhand,
    poisoned: base.poisoned || aura == Aura.venom,
    rusty: false,
    shield: base.shield,
    wraps: base.wraps,
    gore: base.gore,
    miasma: base.miasma || aura == Aura.venom || aura == Aura.cursed,
    skirt: _tintMaybe(base.skirt, glow, wash),
    quiver: base.quiver,
    weaponGlow: glow,
    offhandGlow: base.offhand == Weapon.none ? null : glow,
    legendary: named,
    hatColour: base.hatColour == null ? null : Color.lerp(base.hatColour, glow, .35),
    foliage: base.foliage == null ? null : Color.lerp(base.foliage, glow, .45),
    canopy: base.canopy,
    embers: base.embers,
    bareBranches: base.bareBranches,
    berries: base.berries,
    thorns: base.thorns,
    weaponTint: aura == Aura.gilded ? const Color(0xFFE8C060) : (aura == Aura.frost ? const Color(0xFFCFE8F8) : base.weaponTint),
    wings: base.wings == null ? null : _tintRamp(base.wings!, glow, wash),
    tail: base.tail == null ? null : _tintRamp(base.tail!, glow, wash),
    ghostly: base.ghostly,
    bandaged: base.bandaged,
    usekh: base.usekh,
  );
});

/// A dragon in [aura]'s colours.
DragonLook auraDragon(DragonLook base, Aura aura, {bool named = false}) {
  final glow = auraColour(aura);
  // A frost wyrm in a frost aura goes deep blue so it still stands apart from the regular one.
  final to = aura == Aura.frost && base.frost ? const Color(0xFF2E5C9A) : glow;
  final body = aura == Aura.gilded ? _metal(aura) : _tintRamp(base.body, to, .4);
  return DragonLook(
    body: body,
    belly: Color.lerp(base.belly, glow, .45)!,
    horn: aura == Aura.ancient ? const Color(0xFFFFF6E0) : base.horn,
    eye: glow,
    scale: base.scale * (named ? 1.12 : 1.06),
    spikes: true,
    frost: base.frost || aura == Aura.frost,
  );
}

/// The look for any foe on the road, rare variants included.
Look foeLookOf(FoeType f) {
  final base = foeLooks[f.look] ?? foeLooks['goblin']!;
  return f.aura == null ? base : auraLook(base, f.aura!, named: f.named);
}

DragonLook dragonLookOf(FoeType f) {
  final base = foeDragons[f.look] ?? foeDragons.values.first;
  return f.aura == null ? base : auraDragon(base, f.aura!, named: f.named);
}
