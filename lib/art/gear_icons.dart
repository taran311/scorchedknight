// Gear icons: each item drawn with the same art the hero wears, fitted to a square.

import 'dart:math' as math;
import 'dart:ui';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/models.dart';
import 'body.dart';
import 'heads.dart';
import 'looks.dart';
import 'paint_kit.dart';
import 'rig.dart';

/// Where each held item sits along its own axis, so icons can be fitted to a box.
const _extents = <Weapon, (double, double)>{
  Weapon.longsword: (-20, 118),
  Weapon.greatsword: (-20, 150),
  Weapon.kingsfall: (-30, 160),
  Weapon.shortsword: (-20, 62),
  Weapon.falchion: (-18, 98),
  Weapon.dagger: (-10, 40),
  Weapon.axe: (-20, 92),
  Weapon.greataxe: (-20, 126),
  Weapon.mace: (-16, 80),
  Weapon.morningstar: (-16, 86),
  Weapon.hammer: (-20, 104),
  Weapon.staff: (-50, 126),
  Weapon.crystalstaff: (-50, 138),
  Weapon.wand: (-8, 46),
  Weapon.sceptre: (-14, 72),
  Weapon.crossbow: (-26, 54),
  Weapon.handcrossbow: (-16, 44),
  Weapon.dragondagger: (-12, 50),
  Weapon.orkclub: (-16, 104),
  Weapon.halberd: (-40, 140),
  Weapon.spear: (-40, 134),
  Weapon.scimitar: (-16, 96),
  Weapon.handcannon: (-20, 58),
  Weapon.cannon: (-28, 88),
  Weapon.orkstaff: (-50, 140),
  Weapon.dragonstaff: (-50, 140),
  Weapon.heartmaul: (-20, 112),
  Weapon.runeblade: (-20, 118),
  Weapon.runestaff: (-50, 126),
  Weapon.livingstaff: (-50, 132),
  Weapon.trident: (-44, 148),
  Weapon.hook: (-16, 90),
  Weapon.fishingrod: (-12, 122),
  Weapon.sickle: (-12, 92),
  Weapon.scythe: (-18, 136),
  Weapon.whip: (-14, 120),
  Weapon.flail: (-16, 100),
  Weapon.tomahawk: (-14, 74),
  Weapon.thornblade: (-20, 120),
  Weapon.flamberge: (-22, 124),
  Weapon.frostbrand: (-18, 122),
  Weapon.dawnblade: (-22, 122),
  Weapon.shadowblade: (-18, 122),
  Weapon.rapier: (-20, 124),
  Weapon.glaive: (-40, 150),
  Weapon.cleaver: (-34, 140),
  Weapon.katana: (-32, 114),
  Weapon.wakizashi: (-20, 72),
  Weapon.naginata: (-44, 156),
  Weapon.kanabo: (-16, 110),
  Weapon.shakujo: (-50, 134),
};

/// Paints [item] into a [size] square.
void paintGearIcon(Canvas canvas, Size size, GearItem item, HeroClass heroClass, String dye) {
  final rarity = Color(item.rarity.argb);

  final s = size.width;
  final glow = elementGlow(item.element);
  final look = lookFor(
    heroClass,
    Loadout(armour: tiersFor(heroClass).first.id, helm: item.slot == GearSlot.helm ? item : null),
    dye: dye,
  );
  final iconLook = look;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  switch (item.slot) {
    case GearSlot.weapon || GearSlot.offhand:
      final shield = switch (item.art) {
        'buckler' => ShieldKind.buckler,
        'kite' => ShieldKind.kite,
        'tower' => ShieldKind.tower,
        'round' => ShieldKind.round,
        'dragonshield' => ShieldKind.dragon,
        _ => null,
      };
      if (shield != null) {
        final h = shield == ShieldKind.tower ? 104.0 : (shield == ShieldKind.buckler ? 36.0 : (shield == ShieldKind.round ? 64.0 : 82.0));
        canvas.translate(s / 2, s / 2);
        canvas.scale(s * .8 / h);
        drawShield(canvas, shield == ShieldKind.kite || shield == ShieldKind.dragon ? const Offset(0, -6) : Offset.zero, 0, ShieldLook(field: shield == ShieldKind.dragon && item.tint != null ? Color(item.tint!) : Color(dyeById(dye).argb), kind: shield));
        break;
      }
      if (item.art == 'quiver') {
        _quiverIcon(canvas, s, glow);
        break;
      }
      final w = Weapon.fromArt(item.art);
      if (w == Weapon.tome || w == Weapon.orb || w == Weapon.chakram || w == Weapon.throwingknives || w == Weapon.shuriken || w == Weapon.fan) {
        // Centre the book, orb, ring or knives on their own middle.
        final (k, centre) = switch (w) {
          Weapon.tome => (s / 34, const Offset(5, -8.5)),
          Weapon.chakram => (s / 44, const Offset(10, -6)),
          Weapon.throwingknives => (s / 36, const Offset(4, -14)),
          Weapon.shuriken => (s / 40, const Offset(10, -14)),
          Weapon.fan => (s / 40, const Offset(8, -14)),
          _ => (s / 30, const Offset(8, -24)),
        };
        canvas.translate(s / 2 - centre.dx * k, s / 2 - centre.dy * k);
        canvas.scale(k);
        drawWeapon(canvas, Offset.zero, 0, w, iconLook, glow: glow, still: true, tint: item.tint == null ? null : Color(item.tint!));
        break;
      }
      if (w.isBow && w != Weapon.crossbow) {
        final half = w == Weapon.yumi ? 80.0 : w == Weapon.longbow || w == Weapon.orkbow || w == Weapon.heartbow || w == Weapon.runebow ? 70.0 : 56.0;
        canvas.translate(s / 2, s / 2);
        canvas.scale(s * 1.2 / (half * 2));
        drawWeapon(canvas, const Offset(-4, 4), 45, w, iconLook, glow: glow, still: true);
        break;
      }
      final (lo, hi) = _extents[w] ?? (-20.0, 100.0);
      final len = hi - lo, scale = s * 1.32 / len;
      // Along the diagonal from bottom-left to top-right.
      final mid = (lo + hi) / 2;
      canvas.translate(s / 2, s / 2);
      canvas.scale(scale);
      final dir = Offset(math.sin(135 * deg), math.cos(135 * deg));
      drawWeapon(canvas, -dir * mid, 135, w, iconLook, glow: glow, still: true, tint: item.tint == null ? null : Color(item.tint!));
    case GearSlot.helm:
      final b = builds[look.build]!;
      final sk = Skeleton.solve(b, Pose.of({}));
      final hasHat = item.art == 'wizardhat' || item.art == 'scoutcap';
      canvas.translate(s / 2, s * (hasHat ? .62 : .55));
      canvas.scale(s / (b.head * (hasHat ? 4.4 : 3.2)));
      canvas.translate(-sk.head.dx, -sk.head.dy);
      drawHead(canvas, sk, look, 0, still: true);
    case GearSlot.armour:
      // A scale tunic.
      canvas.translate(s / 2, s / 2);
      canvas.scale(s / 52);
      final tunic = poly(const [Offset(-12, -20), Offset(-4, -22), Offset(0, -16), Offset(4, -22), Offset(12, -20), Offset(22, -10), Offset(16, -4), Offset(14, 22), Offset(-14, 22), Offset(-16, -4), Offset(-22, -10)]);
      final bone = item.art.startsWith('bone');
      final metal = armourTierById(item.art).metal;
      fillPath(canvas, tunic, ramp(metal ?? (bone ? 0xFFCFC3A6 : 0xFF2F6A46), .3, .5), const Offset(-20, 0), const Offset(20, 0));
      canvas.save();
      canvas.clipPath(tunic);
      final sc = Paint()..color = metal != null ? shade(Color(metal), .2) : (bone ? const Color(0xFFEDE4CE) : const Color(0xFF4E8A62));
      for (var row = 0; row < 6; row++) {
        for (var col = -3; col <= 3; col++) {
          final r = Rect.fromCenter(center: Offset(col * 7.0 + (row.isOdd ? 3.5 : 0), -14.0 + row * 7), width: 7, height: 6);
          canvas.drawArc(r, 0, math.pi, true, sc);
          canvas.drawArc(r, 0, math.pi, false, strokePaint(const Color(0x66000000), .8));
        }
      }
      canvas.restore();
    case GearSlot.trinket || GearSlot.ring:
      canvas.translate(s / 2, s / 2);
      canvas.scale(s / 40);
      _trinket(canvas, item.art, glow ?? (item.tint != null && (item.art == 'dragonbonering' || item.art == 'fangamulet') ? _boneGem(item.tint!) : rarity));
    case GearSlot.gloves:
      canvas.translate(s / 2, s / 2);
      canvas.scale(s / 44);
      _glove(canvas, item.art, gearRamp(item), glow);
    case GearSlot.boots:
      canvas.translate(s / 2, s / 2);
      canvas.scale(s / 44);
      _boot(canvas, item.art, gearRamp(item));
    case GearSlot.cape:
      canvas.translate(s / 2, s / 2);
      canvas.scale(s / 44);
      _cape(canvas, Color(item.tint ?? 0xFF8A1E22), glow ?? rarity);
  }
  canvas.restore();
}

void _trinket(Canvas c, String art, Color gem) {
  const gold = [Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
  void jewel(Offset at, double r) {
    c.drawCircle(at, r, Paint()..color = gem);
    c.drawCircle(at - Offset(r * .3, r * .3), r * .35, Paint()..color = const Color(0xAAFFFFFF));
    c.drawCircle(at, r, strokePaint(outline, 1));
  }

  switch (art) {
    case 'infernalsigil':
      // A black iron seal with a burning horned rune.
      c.drawCircle(Offset.zero, 13, Paint()..color = const Color(0x66FF5A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      fillPath(c, Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 12)), const [Color(0xFF6A6470), Color(0xFF2A2630), Color(0xFF0C0A10)], const Offset(-12, -12), const Offset(12, 12));
      final rune = strokePaint(const Color(0xFFFF7A2A), 2)..strokeCap = StrokeCap.round;
      c.drawPath(Path()..moveTo(-6, -6)..quadraticBezierTo(-3, 2, 0, 6)..quadraticBezierTo(3, 2, 6, -6), rune);
      c.drawLine(const Offset(0, -7), const Offset(0, 6), rune);
      c.drawLine(const Offset(-4, 1), const Offset(4, 1), rune);
    case 'gargoyleheart':
      // A carved stone heart with a violet glow in its cracks.
      final heart = Path()
        ..moveTo(0, 14)
        ..quadraticBezierTo(-16, 2, -12, -8)
        ..quadraticBezierTo(-6, -15, 0, -7)
        ..quadraticBezierTo(6, -15, 12, -8)
        ..quadraticBezierTo(16, 2, 0, 14)
        ..close();
      fillPath(c, heart, const [Color(0xFFB8BAC0), Color(0xFF7A7C82), Color(0xFF3A3C42)], const Offset(-14, -12), const Offset(14, 14));
      c.drawPath(Path()..moveTo(-4, -6)..lineTo(1, 0)..lineTo(-2, 5)..lineTo(3, 10), strokePaint(const Color(0xFFB07AFF), 1.6));
    case 'ankh':
      // A gold ankh with a lapis inlay, faintly glowing green.
      c.drawCircle(const Offset(0, 0), 15, Paint()..color = const Color(0x407AF0A8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      c.drawOval(Rect.fromCenter(center: const Offset(0, -9), width: 13, height: 15), strokePaint(outline, 6));
      c.drawOval(Rect.fromCenter(center: const Offset(0, -9), width: 13, height: 15), strokePaint(gold[1], 4));
      final bar = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 1), width: 26, height: 6), const Radius.circular(2)));
      final stem = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 9), width: 6, height: 20), const Radius.circular(2)));
      fillPath(c, bar, gold, const Offset(0, -2), const Offset(0, 4));
      fillPath(c, stem, gold, const Offset(-3, 0), const Offset(3, 0));
      c.drawRect(Rect.fromCenter(center: const Offset(0, 9), width: 2.4, height: 14), Paint()..color = const Color(0xFF2E5AA8));
    case 'ashenseal':
      // The Ashen Order's grey iron seal, broken in two, embers in the crack.
      c.drawCircle(Offset.zero, 13, Paint()..color = const Color(0x55FF6A2A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      for (final (dx, half) in const [(-1.5, true), (1.5, false)]) {
        c.save();
        c.translate(dx, half ? -.5 : .5);
        final p = Path()
          ..moveTo(0, -12)
          ..lineTo(2, -5)
          ..lineTo(-1, 1)
          ..lineTo(2, 7)
          ..lineTo(0, 12);
        if (half) {
          p.arcToPoint(const Offset(0, -12), radius: const Radius.circular(12));
        } else {
          p.arcToPoint(const Offset(0, -12), radius: const Radius.circular(12), clockwise: false);
        }
        fillPath(c, p..close(), const [Color(0xFF9A9AA2), Color(0xFF5A5A62), Color(0xFF222226)], const Offset(-12, -12), const Offset(12, 12));
        c.restore();
      }
      c.drawPath(Path()..moveTo(0, -12)..lineTo(2, -5)..lineTo(-1, 1)..lineTo(2, 7)..lineTo(0, 12), strokePaint(const Color(0xFFFF7A2A), 1.6));
      // A sword on the seal.
      c.drawLine(const Offset(-6, -6), const Offset(6, 6), strokePaint(const Color(0xFFD8D8DE), 2));
      c.drawLine(const Offset(-6, 2), const Offset(-2, 6), strokePaint(const Color(0xFFD8D8DE), 2));
    case 'heartsblood':
      // A crystal vial of something dark red, still warm.
      c.drawCircle(const Offset(0, 4), 13, Paint()..color = const Color(0x55E0203A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final vial = Path()
        ..moveTo(-3, -12)
        ..lineTo(3, -12)
        ..lineTo(3, -5)
        ..quadraticBezierTo(10, -1, 10, 6)
        ..quadraticBezierTo(10, 15, 0, 15)
        ..quadraticBezierTo(-10, 15, -10, 6)
        ..quadraticBezierTo(-10, -1, -3, -5)
        ..close();
      c.drawPath(vial, Paint()..color = const Color(0x66E8E0F0));
      c.save();
      c.clipPath(vial);
      c.drawRect(const Rect.fromLTRB(-12, 0, 12, 16), Paint()..color = const Color(0xFF8A0E1E));
      c.drawRect(const Rect.fromLTRB(-12, 0, 12, 2), Paint()..color = const Color(0xFFE0303A));
      c.restore();
      c.drawCircle(const Offset(-4, 6), 1.8, Paint()..color = const Color(0xBBFFFFFF));
      c.drawPath(vial, strokePaint(outline, 1.2));
      c.drawRect(const Rect.fromLTWH(-4, -15, 8, 4), Paint()..color = gold[1]);
      c.drawRect(const Rect.fromLTWH(-4, -15, 8, 4), strokePaint(outline, 1));
    case 'starleaf':
      // A silver leaf brooch with a star caught in it.
      c.drawCircle(Offset.zero, 14, Paint()..color = const Color(0x44BFF0FF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final leaf = Path()
        ..moveTo(-12, 12)
        ..quadraticBezierTo(-14, -8, 12, -12)
        ..quadraticBezierTo(14, 10, -12, 12)
        ..close();
      fillPath(c, leaf, const [Color(0xFFF4F8FA), Color(0xFFB8C4CC), Color(0xFF5A6670)], const Offset(-12, -12), const Offset(12, 12));
      c.drawPath(Path()..moveTo(-11, 11)..quadraticBezierTo(-1, 1, 11, -11), strokePaint(const Color(0xFF7A8690), 1.2));
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5, rad = i.isEven ? 5.5 : 2.2;
        final p = Offset(math.cos(a) * rad, math.sin(a) * rad);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      c.drawPath(star..close(), Paint()..color = const Color(0xFFBFF0FF));
    case 'runependant':
      // A runestone on a heavy chain, its rune glowing blue.
      c.drawLine(const Offset(-9, -15), const Offset(0, -9), strokePaint(const Color(0xFF8A8E96), 2.6));
      c.drawLine(const Offset(9, -15), const Offset(0, -9), strokePaint(const Color(0xFF8A8E96), 2.6));
      final stone = poly(const [Offset(0, -10), Offset(10, -3), Offset(8, 12), Offset(-8, 12), Offset(-10, -3)]);
      fillPath(c, stone, const [Color(0xFF9A9AA0), Color(0xFF5A5A62), Color(0xFF26262C)], const Offset(-10, -10), const Offset(10, 12));
      c.drawCircle(const Offset(0, 2), 9, Paint()..color = const Color(0x557AC8FF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final rune = strokePaint(const Color(0xFF9ADCFF), 1.8)..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(0, -4), const Offset(0, 8), rune);
      c.drawLine(const Offset(0, -2), const Offset(4, 2), rune);
      c.drawLine(const Offset(0, 3), const Offset(-4, 7), rune);
    case 'blossomseal':
      // A cherry blossom carved in red jade, on a silk cord.
      c.drawLine(const Offset(-8, -16), const Offset(0, -8), strokePaint(const Color(0xFFE8C060), 1.6));
      c.drawLine(const Offset(8, -16), const Offset(0, -8), strokePaint(const Color(0xFFE8C060), 1.6));
      c.drawCircle(const Offset(0, 3), 15, Paint()..color = const Color(0x44FF8AA8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5 - math.pi / 2, d = Offset(math.cos(a), math.sin(a));
        fillPath(c, Path()..addOval(Rect.fromCircle(center: const Offset(0, 3) + d * 6.5, radius: 5.5)), const [Color(0xFFFF9AB0), Color(0xFFC83A4A), Color(0xFF5A0E18)], const Offset(-12, -8), const Offset(12, 14));
      }
      c.drawCircle(const Offset(0, 3), 3.4, Paint()..color = const Color(0xFFF2D27A));
    case 'stormfeather':
      // A great storm-grey plume, lightning running down its spine.
      c.drawCircle(Offset.zero, 14, Paint()..color = const Color(0x447AC8FF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final plume = Path()
        ..moveTo(-8, 16)
        ..quadraticBezierTo(-12, -4, 10, -16)
        ..quadraticBezierTo(10, 6, -8, 16)
        ..close();
      fillPath(c, plume, const [Color(0xFFC8D0E0), Color(0xFF6A7088), Color(0xFF1E2234)], const Offset(-12, -16), const Offset(10, 16));
      c.drawPath(poly(const [Offset(6, -12), Offset(0, -2), Offset(4, -1), Offset(-4, 10), Offset(0, 0), Offset(-3, 0)]), Paint()..color = const Color(0xFFCFF4FF));
    case 'mirrorheart':
      // A grey heart caught halfway through changing shape, a shimmer coming off it.
      c.drawCircle(Offset.zero, 14, Paint()..color = const Color(0x44C8A8F0)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final heart = Path()
        ..moveTo(0, 13)
        ..quadraticBezierTo(-15, 2, -11, -7)
        ..quadraticBezierTo(-5, -14, 0, -6)
        ..quadraticBezierTo(6, -15, 12, -6)
        ..quadraticBezierTo(15, 4, 0, 13)
        ..close();
      fillPath(c, heart, const [Color(0xFFC8B8E0), Color(0xFF8A7AA0), Color(0xFF3A2E4A)], const Offset(-13, -12), const Offset(13, 13));
      c.drawCircle(const Offset(-4, -2), 2.4, Paint()..color = const Color(0xFFF2F6F0));
      c.drawCircle(const Offset(-4, -2), 1.1, Paint()..color = const Color(0xFF14101A));
      c.drawCircle(const Offset(5, 3), 1.8, Paint()..color = const Color(0xFFFF6A5A));
    case 'leviathaneye':
      // A great pale eye set in a ring of coral.
      c.drawCircle(Offset.zero, 15, Paint()..color = const Color(0x448AE0F0)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        c.drawCircle(Offset(math.cos(a) * 11, math.sin(a) * 11), 3.4, Paint()..color = const Color(0xFFF08A7A));
      }
      c.drawCircle(Offset.zero, 9, Paint()..color = const Color(0xFFCFFFFF));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 3, height: 13), Paint()..color = const Color(0xFF0A1028));
      c.drawCircle(const Offset(-3, -3), 1.8, Paint()..color = const Color(0xDDFFFFFF));
      c.drawCircle(Offset.zero, 9, strokePaint(outline, 1));
    case 'sunfang':
      // A curved fang set in a sun-gold cap, warm and glowing.
      c.drawCircle(const Offset(0, 2), 13, Paint()..color = const Color(0x55FFD27A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final fang = Path()
        ..moveTo(-6, -8)
        ..quadraticBezierTo(8, -6, 6, 6)
        ..quadraticBezierTo(4, 13, -2, 16)
        ..quadraticBezierTo(2, 6, -6, 0)
        ..close();
      fillPath(c, fang, const [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)], const Offset(-6, -8), const Offset(8, 16));
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -10), width: 16, height: 7), const Radius.circular(2))), gold, const Offset(0, -13), const Offset(0, -7));
      for (var i = 0; i < 6; i++) {
        final a = -math.pi + i * math.pi / 5;
        c.drawLine(Offset(math.cos(a) * 9, -10 + math.sin(a) * 6), Offset(math.cos(a) * 13, -10 + math.sin(a) * 9), strokePaint(gold[1], 1.6));
      }
    case 'thousandmask':
      // A porcelain mask, and faint other faces moving under it.
      c.drawCircle(Offset.zero, 14, Paint()..color = const Color(0x33D8E0E8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final face = Path()
        ..moveTo(0, -15)
        ..quadraticBezierTo(13, -15, 13, -2)
        ..quadraticBezierTo(13, 12, 0, 17)
        ..quadraticBezierTo(-13, 12, -13, -2)
        ..quadraticBezierTo(-13, -15, 0, -15)
        ..close();
      fillPath(c, face, const [Color(0xFFFFFCF6), Color(0xFFE2DAD0), Color(0xFF8A847C)], const Offset(-13, -15), const Offset(13, 17));
      for (final (dx, dy) in const [(-6.0, -6.0), (5.0, 3.0)]) {
        c.drawOval(Rect.fromCenter(center: Offset(dx, dy), width: 7, height: 9), strokePaint(const Color(0x338A847C), 1));
      }
      final hole = Paint()..color = const Color(0xFF1A1618);
      c.drawOval(Rect.fromCenter(center: const Offset(-4.5, -2), width: 5, height: 3), hole);
      c.drawOval(Rect.fromCenter(center: const Offset(4.5, -2), width: 5, height: 3), hole);
      c.drawArc(Rect.fromCenter(center: const Offset(0, 8), width: 8, height: 4), 0, math.pi, false, strokePaint(const Color(0xFF1A1618), 1.2));
    case 'bloodmoonpelt':
      // A wolf's pelt, its head at the top, a red moon behind.
      c.drawCircle(const Offset(5, -7), 9, Paint()..color = const Color(0xFFC8302A));
      c.drawCircle(const Offset(5, -7), 12, Paint()..color = const Color(0x55FF4A3A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      final pelt = Path()
        ..moveTo(-6, -12)
        ..lineTo(-3, -16)
        ..lineTo(-1, -11)
        ..lineTo(2, -11)
        ..lineTo(4, -16)
        ..lineTo(6, -11)
        ..lineTo(8, -6)
        ..lineTo(13, -3)
        ..lineTo(9, 1)
        ..lineTo(11, 8)
        ..lineTo(6, 7)
        ..lineTo(3, 16)
        ..lineTo(-1, 9)
        ..lineTo(-5, 16)
        ..lineTo(-6, 7)
        ..lineTo(-11, 8)
        ..lineTo(-8, 1)
        ..lineTo(-12, -3)
        ..lineTo(-7, -6)
        ..close();
      fillPath(c, pelt, const [Color(0xFF9A6A5A), Color(0xFF6A3E32), Color(0xFF2A1612)], const Offset(-12, -16), const Offset(12, 16));
      c.drawCircle(const Offset(-3, -9), 1.2, Paint()..color = const Color(0xFFFF4A3A));
      c.drawCircle(const Offset(3, -9), 1.2, Paint()..color = const Color(0xFFFF4A3A));
    case 'phylactery':
      // A bone vial with a slow green glow.
      c.drawCircle(const Offset(0, 4), 12, Paint()..color = const Color(0x557AF0C8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 4), width: 14, height: 20), const Radius.circular(6))), const [Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)], const Offset(-7, 0), const Offset(7, 0));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 6), width: 8, height: 12), const Radius.circular(4)), Paint()..color = const Color(0xFF7AF0C8));
      c.drawRect(const Rect.fromLTWH(-4, -10, 8, 5), Paint()..color = const Color(0xFF5A4A3A));
      c.drawLine(const Offset(0, -10), const Offset(0, -16), strokePaint(gold[2], 2));
    case 'warhorn':
      // A curved horn banded in iron.
      final horn = Path()
        ..moveTo(-14, 10)
        ..quadraticBezierTo(-12, -12, 12, -12)
        ..lineTo(14, -4)
        ..quadraticBezierTo(-4, -4, -8, 12)
        ..close();
      fillPath(c, horn, const [Color(0xFFF2EAD2), Color(0xFFB8AC8A), Color(0xFF4E4636)], const Offset(-14, 0), const Offset(14, 0));
      for (final x in const [-6.0, 4.0]) {
        c.drawLine(Offset(x, -9), Offset(x - 3, -2), strokePaint(const Color(0xFF3A3A40), 3));
      }
      c.drawOval(const Rect.fromLTWH(10, -14, 6, 12), Paint()..color = const Color(0xFF2A2420));
    case 'cinderjack':
      // A little jack-o'-lantern on a chain, grinning and lit.
      c.drawLine(const Offset(0, -16), const Offset(0, -10), strokePaint(const Color(0xFF6A6A6A), 1.6));
      c.drawCircle(const Offset(0, 2), 16, Paint()..color = const Color(0x55FF8A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      for (final (dx, col) in const [(-5.0, Color(0xFFC8641A)), (5.0, Color(0xFFC8641A)), (0.0, Color(0xFFE07A22))]) {
        c.drawOval(Rect.fromCenter(center: Offset(dx, 2), width: 15, height: 22), Paint()..color = col);
      }
      c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 25, height: 22), strokePaint(outline, 1.2));
      c.drawRect(const Rect.fromLTWH(-1.5, -12, 3, 4), Paint()..color = const Color(0xFF4A5A2A));
      final lit = Paint()..color = const Color(0xFFFFE07A);
      c.drawPath(poly(const [Offset(-7, -1), Offset(-2, -1), Offset(-4.5, -5)]), lit);
      c.drawPath(poly(const [Offset(2, -1), Offset(7, -1), Offset(4.5, -5)]), lit);
      c.drawPath(poly(const [Offset(-8, 4), Offset(-5, 6), Offset(-2, 4), Offset(1, 7), Offset(4, 4), Offset(8, 4), Offset(4, 10), Offset(-4, 10)]), lit);
    case 'cyclopseye':
      // A great eye set in a bronze amulet.
      c.drawLine(const Offset(-10, -14), const Offset(0, -10), strokePaint(gold[2], 2));
      c.drawLine(const Offset(10, -14), const Offset(0, -10), strokePaint(gold[2], 2));
      fillPath(c, Path()..addOval(Rect.fromCircle(center: const Offset(0, 3), radius: 12)), gold, const Offset(-12, -9), const Offset(12, 15));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 3), width: 17, height: 13), Paint()..color = const Color(0xFFF4EEDC));
      c.drawCircle(const Offset(1, 3), 4.6, Paint()..color = const Color(0xFF8A3A1A));
      c.drawCircle(const Offset(1.5, 3), 2, Paint()..color = const Color(0xFF120A06));
      c.drawCircle(const Offset(-.5, 1.5), 1.2, Paint()..color = const Color(0xCCFFFFFF));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 3), width: 17, height: 13), strokePaint(outline, 1));
    case 'hiddenmask':
      // A gilded mask with one eye-slit and a red tear run down through it.
      final face = Path()
        ..moveTo(0, -15)
        ..quadraticBezierTo(13, -15, 13, -2)
        ..quadraticBezierTo(13, 12, 0, 17)
        ..quadraticBezierTo(-13, 12, -13, -2)
        ..quadraticBezierTo(-13, -15, 0, -15)
        ..close();
      fillPath(c, face, gold, const Offset(-13, -15), const Offset(13, 17));
      c.drawOval(Rect.fromCenter(center: const Offset(4, -2), width: 11, height: 6), Paint()
        ..color = const Color(0x889CF6E6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      c.drawPath(
        Path()
          ..moveTo(-1, -1)
          ..quadraticBezierTo(4, -4, 9, -2)
          ..quadraticBezierTo(4, 0, -1, -1)
          ..close(),
        Paint()..color = const Color(0xFF120A0C),
      );
      c.drawLine(const Offset(4.5, -9), const Offset(4, 8), strokePaint(const Color(0xFFA0222A), 2)..strokeCap = StrokeCap.round);
      c.drawCircle(const Offset(4, 10.5), 1.6, Paint()..color = const Color(0xFFA0222A));
    case 'collar':
      // A spiked iron collar, still glowing.
      c.drawCircle(const Offset(0, 2), 11, strokePaint(outline, 7));
      c.drawCircle(const Offset(0, 2), 11, strokePaint(const Color(0xFF4A4A50), 5));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4, d = Offset(math.cos(a), math.sin(a));
        c.drawPath(poly([const Offset(0, 2) + d * 13 + Offset(-d.dy, d.dx) * 2.4, const Offset(0, 2) + d * 19, const Offset(0, 2) + d * 13 - Offset(-d.dy, d.dx) * 2.4]), Paint()..color = const Color(0xFFD6DBE1));
      }
      c.drawCircle(const Offset(0, 2), 8, strokePaint(const Color(0xFFFF7A2A), 1.6));
      jewel(const Offset(0, 13), 3);
    case 'acorn':
      // A golden acorn with a leaf.
      final nut = Path()
        ..moveTo(-9, -2)
        ..quadraticBezierTo(-10, 12, 0, 16)
        ..quadraticBezierTo(10, 12, 9, -2)
        ..close();
      fillPath(c, nut, gold, const Offset(-9, 0), const Offset(9, 0));
      final cap = Path()
        ..moveTo(-11, -1)
        ..quadraticBezierTo(-10, -11, 0, -11)
        ..quadraticBezierTo(10, -11, 11, -1)
        ..close();
      fillPath(c, cap, const [Color(0xFFA8784A), Color(0xFF6E4A28), Color(0xFF2E1C0C)], const Offset(0, -11), const Offset(0, -1));
      for (var x = -8.0; x <= 8; x += 4) {
        c.drawLine(Offset(x, -9), Offset(x + 2, -2), strokePaint(const Color(0x55000000), 1));
      }
      c.drawLine(const Offset(0, -11), const Offset(2, -16), strokePaint(const Color(0xFF4A3018), 2.2));
      c.drawPath(Path()..moveTo(2, -15)..quadraticBezierTo(12, -20, 15, -12)..quadraticBezierTo(8, -10, 2, -15), Paint()..color = const Color(0xFF6AAA3E));
      jewel(const Offset(0, 6), 3.2);
    case 'dragonbonering':
      // An ivory band, ridged like knucklebone, set with a gem in the dragon's colour between two
      // little horns.
      const ivory = [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)];
      c.drawCircle(const Offset(0, 4), 9, strokePaint(outline, 6));
      c.drawCircle(const Offset(0, 4), 9, strokePaint(ivory[1], 4));
      for (var a = 0.6; a < 5.8; a += .7) {
        final p = const Offset(0, 4) + Offset(math.cos(a) * 9, math.sin(a) * 9);
        c.drawLine(p - Offset(math.cos(a) * 1.6, math.sin(a) * 1.6), p + Offset(math.cos(a) * 1.6, math.sin(a) * 1.6), strokePaint(ivory[2], .9));
      }
      for (final s in const [-1.0, 1.0]) {
        c.drawPath(Path()..moveTo(s * 3, -6)..quadraticBezierTo(s * 9, -9, s * 10, -15)..quadraticBezierTo(s * 6, -10, s * 1.5, -9)..close(), Paint()..color = ivory[0]);
        c.drawPath(Path()..moveTo(s * 3, -6)..quadraticBezierTo(s * 9, -9, s * 10, -15)..quadraticBezierTo(s * 6, -10, s * 1.5, -9)..close(), strokePaint(outline, 1));
      }
      jewel(const Offset(0, -6), 4.6);
    case 'fangamulet':
      // A curved dragon's fang on a cord, with a small gem at its root.
      const ivory = [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)];
      c.drawPath(Path()..moveTo(-12, -14)..quadraticBezierTo(0, 0, 12, -14), strokePaint(const Color(0xFF5A3A22), 1.8));
      final fang = Path()
        ..moveTo(-4, -6)
        ..quadraticBezierTo(-6, 6, 2, 15)
        ..quadraticBezierTo(0, 6, 4, -6)
        ..close();
      fillPath(c, fang, ivory, const Offset(-5, -6), const Offset(5, 15), width: 1.2);
      c.drawLine(const Offset(-1, 0), const Offset(1, 8), strokePaint(const Color(0x667A6A48), 1));
      jewel(const Offset(0, -7), 3);
    case 'ring':
      c.drawCircle(const Offset(0, 4), 9, strokePaint(outline, 5.5));
      c.drawCircle(const Offset(0, 4), 9, strokePaint(gold[1], 3.5));
      jewel(const Offset(0, -6), 5);
    case 'charm':
      fillPath(c, Path()..addOval(Rect.fromCircle(center: const Offset(0, 2), radius: 12)), gold, const Offset(-12, -10), const Offset(12, 14));
      c.drawCircle(const Offset(0, 2), 8, strokePaint(const Color(0x66000000), 1.2));
      c.drawLine(const Offset(0, -10), const Offset(0, -16), strokePaint(gold[2], 2));
      jewel(const Offset(0, 2), 3);
    case 'brooch':
      fillPath(c, poly(const [Offset(0, -13), Offset(12, 0), Offset(0, 13), Offset(-12, 0)]), gold, const Offset(-12, -12), const Offset(12, 12));
      jewel(Offset.zero, 6);
    case 'talisman':
      final p = Path()
        ..moveTo(0, -14)
        ..lineTo(10, -4)
        ..lineTo(6, 14)
        ..lineTo(-6, 14)
        ..lineTo(-10, -4)
        ..close();
      fillPath(c, p, const [Color(0xFFE6DCC4), Color(0xFFB8A888), Color(0xFF6A5E48)], const Offset(-10, -14), const Offset(10, 14));
      c.drawLine(const Offset(-4, 0), const Offset(4, 6), strokePaint(gem, 2));
      c.drawLine(const Offset(4, 0), const Offset(-4, 6), strokePaint(gem, 2));
    default: // amulet / pendant
      final chain = Path()
        ..moveTo(-12, -14)
        ..quadraticBezierTo(0, 4, 12, -14);
      c.drawPath(chain, strokePaint(gold[1], 1.8));
      fillPath(c, poly(const [Offset(0, -6), Offset(8, 4), Offset(0, 16), Offset(-8, 4)]), gold, const Offset(-8, -6), const Offset(8, 16));
      jewel(const Offset(0, 5), 4.5);
  }
}

void _quiverIcon(Canvas c, double s, Color? glow) {
  c.save();
  c.translate(s / 2, s / 2);
  c.scale(s / 52);
  c.rotate(35 * deg);
  for (var i = 0; i < 3; i++) {
    final x = -5.0 + i * 5;
    c.drawLine(Offset(x, -12), Offset(x, -24), strokePaint(const Color(0xFF6E4C31), 1.6));
    c.drawPath(poly([Offset(x, -26), Offset(x - 3, -19), Offset(x + 3, -19)]), Paint()..color = i == 1 ? const Color(0xFF9A2A22) : const Color(0xFFE8DCC4));
  }
  if (glow != null) {
    c.drawCircle(
      const Offset(0, -20),
      10,
      Paint()
        ..color = glow.withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }
  capsule(c, const Offset(0, -12), 9, const Offset(0, 20), 7.5, ramp(0xFF6E4A2A));
  c.drawLine(const Offset(-9, -6), const Offset(9, -6), strokePaint(const Color(0xFF3A2516), 2));
  c.drawLine(const Offset(-8, 12), const Offset(8, 12), strokePaint(const Color(0xFF3A2516), 2));
  c.restore();
}


/// A cape hanging from a clasp, its folds catching the light.
void _cape(Canvas c, Color col, Color gem) {
  final cloth = Path()
    ..moveTo(-8, -16)
    ..lineTo(8, -16)
    ..quadraticBezierTo(16, 2, 18, 18)
    ..quadraticBezierTo(8, 14, 4, 19)
    ..quadraticBezierTo(-2, 14, -6, 19)
    ..quadraticBezierTo(-12, 14, -18, 18)
    ..quadraticBezierTo(-16, 2, -8, -16)
    ..close();
  fillPath(c, cloth, [shade(col, .25), col, shade(col, -.5)], const Offset(-18, 0), const Offset(18, 0));
  for (final x in const [-6.0, 2.0, 9.0]) {
    c.drawLine(Offset(x * .6, -12), Offset(x, 16), strokePaint(shade(col, -.35), 1));
  }
  c.drawCircle(const Offset(0, -15), 4, Paint()..color = const Color(0xFFC9A24E));
  c.drawCircle(const Offset(0, -15), 2.2, Paint()..color = gem);
}

/// A glove: a cuff, a palm and four fingers (plated for gauntlets).
void _glove(Canvas c, String art, Ramp col, Color? glow) {
  if (glow != null) c.drawCircle(const Offset(0, -2), 16, Paint()..color = glow.withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  final cuff = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, 6, 22, 12), const Radius.circular(3)));
  fillPath(c, cuff, [shade(col[0], -.05), shade(col[1], -.1), col[2]], const Offset(-11, 0), const Offset(11, 0));
  final palm = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -8, 20, 16), const Radius.circular(5)));
  fillPath(c, palm, col, const Offset(-10, 0), const Offset(10, 0));
  for (var i = 0; i < 4; i++) {
    final x = -8.0 + i * 5.3, top = -18.0 + (i == 0 || i == 3 ? 3 : 0);
    fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, top, 4.6, 12), const Radius.circular(2.3))), col, Offset(x, 0), Offset(x + 4.6, 0));
    if (art == 'gauntlets') c.drawLine(Offset(x + .5, top + 5), Offset(x + 4, top + 5), strokePaint(col[2], .8));
  }
  final thumb = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, -4, 10, 5), const Radius.circular(2.5)));
  fillPath(c, thumb, col, const Offset(9, 0), const Offset(19, 0));
  if (art == 'gauntlets') {
    c.drawLine(const Offset(-10, 0), const Offset(10, 0), strokePaint(col[0], 1.2));
  } else if (art == 'spellgloves') {
    c.drawCircle(const Offset(0, 0), 3, Paint()..color = glow ?? const Color(0xFF9ADFFF));
  } else if (art == 'bracers') {
    for (final y in const [9.0, 13.0]) {
      c.drawLine(Offset(-10, y), Offset(10, y), strokePaint(const Color(0xFF2A1A0E), 1.2));
    }
  }
}

/// A boot: a shaft and a foot (plated sabatons, soft slippers, tall leather boots).
void _boot(Canvas c, String art, Ramp col) {
  final tall = art != 'slippers';
  final shaft = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9, tall ? -18 : -2, 14, tall ? 26 : 10), const Radius.circular(3)));
  fillPath(c, shaft, col, const Offset(-9, 0), const Offset(5, 0));
  final foot = Path()
    ..moveTo(-10, 6)
    ..lineTo(6, 6)
    ..quadraticBezierTo(18, 8, 18, 14)
    ..lineTo(-10, 14)
    ..close();
  fillPath(c, foot, col, const Offset(-10, 6), const Offset(18, 14));
  c.drawRect(const Rect.fromLTWH(-10, 14, 28, 3), Paint()..color = shade(col[2], -.2));
  if (art == 'sabatons') {
    for (final y in const [-12.0, -4.0, 4.0]) {
      c.drawLine(Offset(-9, y), Offset(5, y), strokePaint(col[2], 1));
    }
    for (final x in const [2.0, 8.0, 13.0]) {
      c.drawLine(Offset(x, 7), Offset(x, 14), strokePaint(col[2], .8));
    }
  } else if (tall) {
    c.drawLine(const Offset(-9, -14), const Offset(5, -14), strokePaint(shade(col[0], .1), 2));
  }
}

/// A dragonbone gem in its dragon's colour (Obsidian's black scales get an ember gem).
Color _boneGem(int tint) {
  final w = wyrmTiers.where((t) => t.argb == tint).firstOrNull;
  return Color(w == null ? tint : (w.tier == 4 ? w.trim : w.argb));
}
