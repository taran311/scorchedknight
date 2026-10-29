// The dragon companion at each stage, and its egg.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';
import 'sprites.dart';


/// Where each stage sits in the 960 x 540 battle scene: (x, y, scale).
const dragonPlacement = <String, (double, double, double)>{'Hatchling': (112, 452, .36), 'Drake': (110, 250, .62), 'Elder dragon': (118, 205, .86)};

/// Mouth position in scene coordinates, for aiming fire.
Offset dragonMouth(String stage, double t, {bool still = false}) {
  final (x, y, s) = dragonPlacement[stage]!;
  final bob = stage != 'Hatchling' && !still ? math.sin(t / 360) * 10 : 0.0;
  return Offset(x + 150 * s, y + bob - 90 * s);
}

/// Colours and build of a dragon.
class DragonLook {
  const DragonLook({required this.body, required this.belly, this.horn = const Color(0xFFE8DCB8), this.eye = const Color(0xFFFFD36A), this.scale = 1, this.spikes = false, this.frost = false});
  final List<Color> body;
  final Color belly, horn, eye;
  final double scale;

  /// A row of spines along the back (older, bigger dragons).
  final bool spikes;

  /// Breathes ice rather than fire (the Frost Wyrm).
  final bool frost;
}

const _companionLook = DragonLook(body: [Color(0xFFD0604A), Color(0xFF8E2F22), Color(0xFF3E120C)], belly: Color(0xFFE8A86A));
const _elderCompanionLook = DragonLook(body: [Color(0xFF9A6AC0), Color(0xFF5B3A7A), Color(0xFF24123A)], belly: Color(0xFFE3C27A));

/// The dragons of the Wyrmspine Peaks.
const foeDragons = <String, DragonLook>{
  'wyvern': DragonLook(body: [Color(0xFFA89A86), Color(0xFF5E5448), Color(0xFF221E1A)], belly: Color(0xFFC8B08A), scale: .9),
  'mossDragon': DragonLook(body: [Color(0xFF8ABF6A), Color(0xFF3E6E2E), Color(0xFF14260E)], belly: Color(0xFFD8D27A), scale: 1.0),
  'frostWyrm': DragonLook(body: [Color(0xFFE6F4FF), Color(0xFF7FA8C8), Color(0xFF2A4258)], belly: Color(0xFFBFE8FF), eye: Color(0xFF9AE0FF), scale: 1.05, spikes: true, frost: true),
  'obsidian': DragonLook(body: [Color(0xFF6A6470), Color(0xFF2A2630), Color(0xFF0C0A10)], belly: Color(0xFFB0402A), eye: Color(0xFFFF5A2A), scale: 1.1, spikes: true),
  // Vharrax the Ember King: charcoal scales cracked with fire, a molten belly and white-hot eyes.
  'emberKing': DragonLook(body: [Color(0xFF7A4A3A), Color(0xFF3A1E18), Color(0xFF120806)], belly: Color(0xFFFF8A2A), horn: Color(0xFFFFD27A), eye: Color(0xFFFFFBE0), scale: 1.4, spikes: true),
  'elderWyrm': DragonLook(body: [Color(0xFFE8B05A), Color(0xFFA0401E), Color(0xFF3A0E06)], belly: Color(0xFFF3DC8E), horn: Color(0xFFF6E8C8), eye: Color(0xFFFFF0A0), scale: 1.25, spikes: true),
};

void drawDragon(Canvas c, String stage, double t, {bool breathing = false, bool still = false}) {
  final (x, y, s) = dragonPlacement[stage]!;
  final fly = stage != 'Hatchling';
  final flap = still ? 0.0 : math.sin(t / (fly ? 170 : 420));
  final bob = fly && !still ? math.sin(t / 360) * 10 : 0.0;
  c.save();
  c.translate(x, y + bob);
  c.scale(s, s);
  paintDragon(c, stage == 'Elder dragon' ? _elderCompanionLook : _companionLook, flap: flap, fly: fly, breathing: breathing, lineScale: s);
  c.restore();
}

/// Height of a foe dragon standing on the ground, before scaling.
const dragonHeight = 210.0;

/// A dragon foe standing at [at] (its feet), facing left toward the hero. [hit] (0..1) rocks it
/// back; [dying] rolls it over.
void drawFoeDragon(Canvas c, DragonLook look, Offset at, double scale, double t, {double alpha = 1, double hit = 0, double dying = 0, ColorFilter? tint, bool still = false}) {
  final s = scale * look.scale;
  final painted = identical(look, foeDragons['emberKing']) ? Sprites.get('vharrax') : null;
  if (painted != null) {
    // The painted Vharrax, hovering over the field, facing the hero.
    final h = dragonHeight * s * 1.1, w = h * painted.width / painted.height;
    final bob = still ? 0.0 : math.sin(t / 260) * 8;
    c.save();
    c.translate(at.dx + hit * 18, at.dy);
    c.rotate(-dying * 1.2);
    c.drawOval(Rect.fromCenter(center: const Offset(-20, 2), width: w * .55, height: 22), Paint()..color = Color.fromRGBO(0, 0, 0, .35 * alpha));
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    if (tint != null) paint.colorFilter = tint;
    c.drawImageRect(painted, Rect.fromLTWH(0, 0, painted.width.toDouble(), painted.height.toDouble()), Rect.fromLTWH(-w * .55, -h - 20 + bob, w, h), paint);
    c.restore();
    return;
  }
  final flap = still ? 0.0 : math.sin(t / 260);
  c.save();
  c.translate(at.dx + hit * 18, at.dy);
  c.scale(-s, s); // face the hero
  c.rotate(-dying * 1.2);
  c.translate(0, -44); // feet on the ground
  final layered = alpha < 1 || tint != null;
  if (layered) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
    if (tint != null) p.colorFilter = tint;
    c.saveLayer(null, p);
  }
  c.drawOval(Rect.fromCenter(center: const Offset(-20, 46), width: 220, height: 22), Paint()..color = const Color(0x55000000));
  paintDragon(c, look, flap: flap, fly: true, breathing: false, lineScale: s, flapScale: .55);
  if (layered) c.restore();
  c.restore();
}

/// Paints a dragon facing +x around the origin (body centre), in its own units: a deep-chested
/// body, a thick S-curved neck, a horned head with a hinged jaw, bat wings stretched over long
/// finger bones, a heavy tapering tail with a spade tip, and clawed legs.
void paintDragon(Canvas c, DragonLook look, {required double flap, required bool fly, required bool breathing, required double lineScale, double flapScale = 1}) {
  final col = look.body;
  final line = strokePaint(outline, 1.8 / lineScale);
  void fp(Path p, List<Color> cs, {Offset from = const Offset(0, -110), Offset to = const Offset(0, 40)}) {
    c.drawPath(p, Paint()..shader = ui.Gradient.linear(from, to, cs, const [0, .5, 1]));
    c.drawPath(p, line);
  }

  final dark = [shade(col[0], -.22), shade(col[1], -.22), col[2]];
  final membrane = [shade(col[0], .05), shade(col[1], .08), shade(col[2], .1)];

  // A wing: an arm out to the wrist, four long fingers fanning back, and the membrane between
  // them, scalloped where it sags. [angle] flaps it about the shoulder.
  void wing(Offset shoulder, double angle, double size, List<Color> skin, List<Color> bone) {
    c.save();
    c.translate(shoulder.dx, shoulder.dy);
    c.rotate(angle * deg);
    c.scale(size, size);
    // The arm reaches up and a little forward to the wrist; the fingers fan out behind it.
    const elbow = Offset(14, -62), wrist = Offset(30, -122);
    const tips = [Offset(-72, -150), Offset(-108, -96), Offset(-96, -48), Offset(-56, -14)];
    final m = Path()
      ..moveTo(0, 0)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(wrist.dx, wrist.dy)
      ..lineTo(tips[0].dx, tips[0].dy);
    for (var i = 1; i < tips.length; i++) {
      final a = tips[i - 1], b = tips[i];
      // Each panel of skin sags inward between two finger tips.
      final mid = Offset.lerp(a, b, .5)!, inward = Offset.lerp(mid, wrist, .28)!;
      m.quadraticBezierTo(inward.dx, inward.dy, b.dx, b.dy);
    }
    m
      ..quadraticBezierTo(-24, -2, 0, 0)
      ..close();
    c.drawPath(m, Paint()..shader = ui.Gradient.linear(wrist, const Offset(-60, 0), skin, const [0, .55, 1]));
    // Veins in the skin.
    for (final t in tips.skip(1)) {
      c.drawLine(Offset.lerp(wrist, t, .25)!, Offset.lerp(wrist, t, .75)! + const Offset(-6, 4), strokePaint(skin[2].withValues(alpha: .25), 1.2));
    }
    c.drawPath(m, line);
    // The bones: arm, forearm and fingers, thick at the wrist.
    final bonePaint = Ramp.from(bone);
    capsule(c, Offset.zero, 5, elbow, 3.6, bonePaint);
    capsule(c, elbow, 3.6, wrist, 3, bonePaint);
    for (final (i, t) in tips.indexed) {
      capsule(c, wrist, 2.4 - i * .2, t, 1.1, bonePaint);
    }
    // A hooked thumb claw at the wrist.
    c.drawPath(
      Path()
        ..moveTo(wrist.dx - 3, wrist.dy - 2)
        ..quadraticBezierTo(wrist.dx + 2, wrist.dy - 14, wrist.dx + 12, wrist.dy - 14)
        ..quadraticBezierTo(wrist.dx + 4, wrist.dy - 8, wrist.dx + 4, wrist.dy - 2)
        ..close(),
      Paint()..color = look.horn,
    );
    c.restore();
  }

  final beat = flap * (fly ? 24 : 6) * flapScale;
  wing(const Offset(-10, -42), beat + 16, 1.0, [shade(membrane[0], -.25), shade(membrane[1], -.25), shade(membrane[2], -.2)], dark);

  // Tail: thick at the root, curling down and back to a spade.
  final tail = Path()
    ..moveTo(-60, -22)
    ..cubicTo(-110, -18, -130, 30, -176, 30)
    ..quadraticBezierTo(-192, 30, -200, 24)
    ..quadraticBezierTo(-188, 38, -170, 40)
    ..cubicTo(-120, 44, -100, 14, -62, 14)
    ..close();
  fp(tail, col);
  final spade = Path()
    ..moveTo(-196, 26)
    ..lineTo(-222, 14)
    ..lineTo(-214, 30)
    ..lineTo(-224, 46)
    ..lineTo(-192, 36)
    ..close();
  fp(spade, dark);

  // Legs: a heavy hind leg bending back at the hock, a foreleg under the chest, clawed feet.
  void legs(Ramp cs, Offset off) {
    Offset p(double x, double y) => Offset(x, y) + off;
    limb(c, [(p(-38, 0), 19), (p(-22, 22), 10), (p(-40, 34), 6.5), (p(-32, 44), 5.5)], [cs, cs, cs], bulge: .25);
    limb(c, [(p(30, 2), 13), (p(36, 24), 8), (p(32, 37), 5.5), (p(40, 44), 5)], [cs, cs, cs], bulge: .2);
    final claw = Paint()..color = shade(look.horn, -.15);
    for (final foot in [p(-32, 44), p(40, 44)]) {
      for (final dy in const [-3.0, .5, 3.5]) {
        final a = foot + Offset(4, dy);
        c.drawPath(poly([a + const Offset(0, -1.8), a + const Offset(7, 1.4), a + const Offset(0, 1.8)]), claw);
      }
    }
  }

  legs(dark, const Offset(12, -3));

  // Body: a deep chest under the shoulders, a rounded belly and a strong haunch.
  final body = Path()
    ..moveTo(-66, -22)
    ..cubicTo(-46, -48, 6, -52, 38, -40)
    ..cubicTo(58, -32, 70, -12, 62, 8)
    ..cubicTo(56, 24, 34, 30, 8, 28)
    ..cubicTo(-24, 28, -54, 26, -70, 12)
    ..cubicTo(-80, 2, -76, -12, -66, -22)
    ..close();
  fp(body, col);
  legs(col, Offset.zero);

  // Neck: a thick S-curve rising from the shoulders.
  final neck = Path()
    ..moveTo(30, -42)
    ..cubicTo(52, -58, 58, -84, 80, -100)
    ..lineTo(100, -88)
    ..cubicTo(86, -74, 78, -48, 62, -10)
    ..close();
  fp(neck, col);

  // Belly plates down the throat, chest and belly, and scales over the back.
  c.save();
  c.clipPath(Path()..addPath(body, Offset.zero)..addPath(neck, Offset.zero));
  final plates = Path()
    ..moveTo(92, -90)
    ..cubicTo(74, -60, 70, -30, 62, 0)
    ..cubicTo(50, 26, -10, 34, -60, 22)
    ..lineTo(-60, 40)
    ..lineTo(90, 40)
    ..close();
  c.drawPath(plates, Paint()..color = look.belly.withValues(alpha: .85));
  for (var i = 0; i < 12; i++) {
    final t = i / 11;
    final q = Offset.lerp(const Offset(88, -84), const Offset(64, -4), math.min(1, t * 1.6))!;
    final r = t < .62 ? q : Offset.lerp(const Offset(62, 2), const Offset(-50, 26), (t - .62) / .38)!;
    c.drawArc(Rect.fromCenter(center: r, width: 20, height: 12), .2, 2.6, false, strokePaint(shade(look.belly, -.35).withValues(alpha: .7), 1.2));
  }
  final scale = strokePaint(col[2].withValues(alpha: .3), 1.1);
  for (var row = 0; row < 3; row++) {
    for (var x = -60.0 + row * 6; x < 44; x += 12) {
      final y = -40.0 + row * 10 + (x > 20 ? (x - 20) * .3 : 0);
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 12, height: 9), .3, 2.5, false, scale);
    }
  }
  // Light along the back.
  c.drawPath(
    Path()
      ..moveTo(-60, -26)
      ..cubicTo(-30, -46, 10, -50, 40, -40)
      ..cubicTo(56, -56, 64, -78, 82, -96),
    strokePaint(col[0].withValues(alpha: .5), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  c.restore();

  if (look.spikes) {
    final spike = Paint()..color = shade(look.horn, -.15);
    for (var i = 0; i < 8; i++) {
      final t = i / 7;
      final base = t < .6 ? Offset.lerp(const Offset(-56, -32), const Offset(30, -46), t / .6)! : Offset.lerp(const Offset(36, -46), const Offset(78, -98), (t - .6) / .4)!;
      final h = 12.0 - (t - .5).abs() * 6;
      final p = poly([base + const Offset(-5, 3), base + Offset(-1, -h), base + const Offset(6, 2)]);
      c.drawPath(p, spike);
      c.drawPath(p, line);
    }
  }

  // Head: a long skull with a heavy brow, and a lower jaw that drops when it breathes.
  c.save();
  c.translate(92, -92);
  final jawDrop = breathing ? .32 : 0.0;
  final jaw = Path()
    ..moveTo(-6, 4)
    ..quadraticBezierTo(20, 10, 52, 8)
    ..lineTo(54, 12)
    ..quadraticBezierTo(24, 20, -2, 14)
    ..close();
  c.save();
  c.rotate(jawDrop);
  fp(jaw, dark, from: const Offset(0, 0), to: const Offset(0, 20));
  c.restore();
  if (breathing) {
    c.drawPath(
      Path()
        ..moveTo(4, 6)
        ..lineTo(56, 2)
        ..lineTo(50, 22)
        ..close(),
      Paint()..color = look.frost ? const Color(0xFF2A4A6A) : const Color(0xFF5A1406),
    );
  }
  final skull = Path()
    ..moveTo(-14, -2)
    ..quadraticBezierTo(-14, -18, 2, -20)
    ..quadraticBezierTo(18, -24, 30, -14)
    ..quadraticBezierTo(46, -12, 58, -6)
    ..quadraticBezierTo(62, -2, 58, 4)
    ..quadraticBezierTo(30, 8, 4, 8)
    ..quadraticBezierTo(-10, 8, -14, -2)
    ..close();
  fp(skull, col, from: const Offset(0, -22), to: const Offset(0, 10));
  // Teeth along the upper jaw.
  final tooth = Paint()..color = const Color(0xFFF2EAD2);
  for (var x = 14.0; x < 54; x += 7) {
    c.drawPath(poly([Offset(x, 6), Offset(x + 2, 11), Offset(x + 4, 5.5)]), tooth);
  }
  // Brow ridge, nostril and the eye under the brow.
  c.drawPath(
    Path()
      ..moveTo(6, -18)
      ..quadraticBezierTo(18, -24, 30, -16),
    strokePaint(col[2], 3),
  );
  c.drawOval(Rect.fromCenter(center: const Offset(55, -4), width: 5, height: 3), Paint()..color = col[2]);
  c.drawOval(Rect.fromCenter(center: const Offset(20, -11), width: 13, height: 9), Paint()
    ..color = look.eye.withValues(alpha: .6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  c.drawOval(Rect.fromCenter(center: const Offset(20, -11), width: 9, height: 5.5), Paint()..color = look.eye);
  c.drawOval(Rect.fromCenter(center: const Offset(21, -11), width: 2, height: 5), Paint()..color = const Color(0xFF140806));
  // Swept-back horns and a frill of small spines behind the jaw.
  for (final (base, tip, w) in const [(Offset(4, -18), Offset(-40, -40), 6.0), (Offset(-6, -12), Offset(-44, -22), 5.0)]) {
    final horn = Path()
      ..moveTo(base.dx - w, base.dy)
      ..quadraticBezierTo((base.dx + tip.dx) / 2, base.dy - 18, tip.dx, tip.dy)
      ..quadraticBezierTo((base.dx + tip.dx) / 2 + 6, base.dy - 6, base.dx + w, base.dy + 2)
      ..close();
    fp(horn, [look.horn, shade(look.horn, -.2), shade(look.horn, -.5)], from: tip, to: base);
  }
  for (var i = 0; i < 3; i++) {
    final b = Offset(-10.0 + i * 2, 2.0 + i * 4);
    c.drawPath(poly([b, b + Offset(-12, 2 + i * 2.0), b + const Offset(0, 4)]), Paint()..color = shade(look.horn, -.3));
  }
  c.restore();

  wing(const Offset(4, -40), beat, 1.18, [shade(membrane[0], .1), membrane[1], membrane[2]], col);
}

final _nest = svgPath('M-26,0 Q-30,-14 -10,-10 Q0,-16 12,-10 Q30,-14 26,0 Z');
final _egg = svgPath('M0,-60 C17,-60 25,-32 23,-19 C21,-4 -21,-4 -23,-19 C-25,-32 -17,-60 0,-60 Z');

void drawEgg(Canvas c, Offset at) {
  c.save();
  c.translate(at.dx, at.dy);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 56, height: 12), Paint()..color = const Color(0x66000000));
  fillPath(c, _nest, const [Color(0xFFC4A46A), Color(0xFF8A6A3A), Color(0xFF4A3418)], const Offset(0, -14), Offset.zero);
  c.drawPath(
    _egg,
    Paint()..shader = ui.Gradient.radial(const Offset(-7, -40), 38, const [Color(0xFFF6E8C8), Color(0xFFC9A77A), Color(0xFF6E4E2E)], const [0, .6, 1]),
  );
  c.drawPath(_egg, strokePaint(outline, 1.5));
  final spot = Paint()..color = const Color(0xA6962819);
  for (final (a, b, rx, ry) in const [(-8.0, -38.0, 4.0, 3.0), (9.0, -26.0, 5.0, 3.5), (4.0, -50.0, 3.0, 2.0), (-12.0, -20.0, 3.0, 2.0)]) {
    c.drawOval(Rect.fromCenter(center: Offset(a, b), width: rx * 2, height: ry * 2), spot);
  }
  c.restore();
}
