// Four-legged companions: the hellhound (charcoal hide, ember cracks, a burning mane) and the
// timber wolf (grey coat, pale belly). Drawn facing right, feet at the origin, about 90 units
// tall at scale 1.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'heads.dart' show leafCluster;
import 'paint_kit.dart';

class HoundLook {
  const HoundLook({required this.coat, required this.belly, required this.eye, this.fire = false, this.mane, this.horns = false});
  final Ramp coat;
  final Color belly, eye;

  /// Ember cracks, burning mane and a flaming tail tip.
  final bool fire;
  final Color? mane;

  /// Curling horns, a spiked collar and bone spines (the Demon Hound).
  final bool horns;
}

const demonHoundLook = HoundLook(
  coat: [Color(0xFF6A2A24), Color(0xFF341210), Color(0xFF120404)],
  belly: Color(0xFF4A1A14),
  eye: Color(0xFFFFE27A),
  fire: true,
  mane: Color(0xFFFF6A1A),
  horns: true,
);

const hellhoundLook = HoundLook(
  coat: [Color(0xFF5A4A48), Color(0xFF2A2020), Color(0xFF0E0A0A)],
  belly: Color(0xFF3A2C2A),
  eye: Color(0xFFFF7A2A),
  fire: true,
  mane: Color(0xFFFF8A2A),
);

const wolfLook = HoundLook(
  coat: [Color(0xFFC8C4BC), Color(0xFF8A8680), Color(0xFF3E3C38)],
  belly: Color(0xFFE8E4DA),
  eye: Color(0xFFF2D27A),
);

/// A hound standing (or mid-pounce, [pounce] 0..1) at [at], at [scale]. [t] animates breathing,
/// tail and flames.
void drawHound(Canvas c, HoundLook look, Offset at, double scale, double t, {double pounce = 0, bool still = false}) {
  final breathe = still ? 0.0 : math.sin(t / 380);
  final run = pounce > 0 ? math.sin(pounce * math.pi * 6) : 0.0;
  c.save();
  c.translate(at.dx, at.dy - (pounce > 0 ? math.sin(pounce * math.pi) * 40 : 0));
  c.scale(scale, scale);
  c.drawOval(Rect.fromCenter(center: const Offset(4, 2), width: 96, height: 12), Paint()..color = const Color(0x55000000));
  final coat = look.coat, dark = [for (final x in coat) shade(x, -.25)];

  // Tail (behind), swishing: a bushy brush, thick in the middle and tapering to a point, held low.
  final swish = still ? 0.0 : math.sin(t / 260) * 6;
  final tail = Path()
    ..moveTo(-40, -74)
    ..quadraticBezierTo(-58, -76 + swish * .4, -66, -60 + swish)
    ..quadraticBezierTo(-72, -44 + swish, -66, -30 + swish * 1.2)
    ..quadraticBezierTo(-60, -42 + swish, -56, -54 + swish * .6)
    ..quadraticBezierTo(-50, -64, -40, -64)
    ..close();
  fillPath(c, tail, coat, const Offset(-60, -76), const Offset(-60, -30), width: 1.6);
  if (!look.fire) {
    for (var i = 0; i < 4; i++) {
      final y = -68.0 + i * 8 + swish * (.4 + i * .2);
      c.drawLine(Offset(-62 - i * 1.0, y), Offset(-57 - i * .5, y + 4), strokePaint(coat[2].withValues(alpha: .45), 1.1));
    }
  }
  if (look.fire) _flame(c, Offset(-66, -30 + swish * 1.2), 9, t, still);

  // Legs: long and lean. Hind legs bend forward at the knee and back at the hock; forelegs stand
  // straight under the shoulder.
  void paw(Offset p, Ramp col) {
    final pad = Path()
      ..moveTo(p.dx - 5, p.dy + 2)
      ..quadraticBezierTo(p.dx - 6, p.dy - 4, p.dx, p.dy - 4)
      ..quadraticBezierTo(p.dx + 9, p.dy - 4, p.dx + 11, p.dy + 1)
      ..quadraticBezierTo(p.dx + 11, p.dy + 4, p.dx + 6, p.dy + 4)
      ..lineTo(p.dx - 3, p.dy + 4)
      ..close();
    fillPath(c, pad, col, p + const Offset(0, -4), p + const Offset(0, 4));
    for (final dx in const [3.5, 6.5]) {
      c.drawLine(p + Offset(dx, -1), p + Offset(dx + .5, 3.5), strokePaint(const Color(0x66000000), .9));
    }
    c.drawLine(p + const Offset(10, 2), p + const Offset(12.5, 3.5), strokePaint(const Color(0xFF2A2420), 1.2));
  }

  void hind(Offset hip, double swing, Ramp col) {
    final stifle = hip + Offset(10 + math.sin(swing) * 8, 20);
    final hock = stifle + Offset(-12 + math.sin(swing) * 4, 18);
    final foot = hock + const Offset(5, 17);
    limb(c, [(hip, 12), (stifle, 7), (hock, 4.2), (foot, 3.6)], [col, col, col], bulge: .25);
    paw(foot, col);
  }

  void fore(Offset shoulder, double swing, Ramp col) {
    final elbow = shoulder + Offset(-2 + math.sin(swing) * 6, 18);
    final wrist = elbow + Offset(1 + math.sin(swing) * 6, 28);
    final foot = wrist + const Offset(2, 7);
    limb(c, [(shoulder, 9.5), (elbow, 6), (wrist, 3.8), (foot, 3.6)], [col, col, col], bulge: .2);
    paw(foot, col);
  }

  hind(const Offset(-28, -58), run * .8 + .2, dark);
  fore(const Offset(20, -56), -run * .8 - .1, dark);

  // Body and neck as one shape: a deep chest, a tucked waist, a round haunch and a strong neck
  // rising to the head.
  final b = breathe;
  final body = Path()
    ..moveTo(-40, -74 - b)
    ..quadraticBezierTo(-50, -66, -46, -56)
    ..quadraticBezierTo(-40, -46, -28, -48)
    ..quadraticBezierTo(-14, -52, 0, -50)
    ..quadraticBezierTo(10, -42, 22, -40)
    ..quadraticBezierTo(34, -40, 38, -52)
    ..quadraticBezierTo(42, -62, 46, -74)
    ..lineTo(50, -84 - b)
    ..quadraticBezierTo(40, -96 - b, 30, -88 - b)
    ..quadraticBezierTo(22, -80 - b, 8, -79 - b)
    ..quadraticBezierTo(-20, -77 - b, -40, -74 - b)
    ..close();
  fillPath(c, body, coat, const Offset(0, -92), const Offset(0, -40), width: 1.6);
  // Near legs go under the body: draw them, then lay the body's fill back over their tops so they
  // grow out of it with no joint showing.
  hind(const Offset(-33, -58), -run * .8 - .2, coat);
  fore(const Offset(25, -56), run * .8 + .1, coat);
  c.save();
  c.clipPath(body);
  fillPath(c, body, coat, const Offset(0, -92), const Offset(0, -40), line: false);
  // The pale chest and belly, the shadow behind the ribcage and the curve of the haunch.
  c.drawPath(
    Path()
      ..moveTo(-6, -48)
      ..quadraticBezierTo(14, -58, 30, -54)
      ..quadraticBezierTo(42, -60, 46, -80)
      ..lineTo(60, -80)
      ..lineTo(60, -30)
      ..lineTo(-6, -30)
      ..close(),
    Paint()..color = look.belly.withValues(alpha: look.fire ? .45 : .8),
  );
  c.drawPath(
    Path()
      ..moveTo(-4, -70)
      ..quadraticBezierTo(4, -58, 0, -50),
    strokePaint(coat[2].withValues(alpha: .35), 2.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  c.drawArc(Rect.fromCenter(center: const Offset(-32, -62), width: 26, height: 24), math.pi * .85, math.pi * .9, false, strokePaint(coat[2].withValues(alpha: .4), 1.6));
  c.drawArc(Rect.fromCenter(center: const Offset(20, -60), width: 20, height: 22), -math.pi * .1, math.pi * .7, false, strokePaint(coat[2].withValues(alpha: .3), 1.4));
  // Light along the back.
  c.drawPath(
    Path()
      ..moveTo(-38, -72 - b)
      ..quadraticBezierTo(-10, -77 - b, 22, -82 - b),
    strokePaint(coat[0].withValues(alpha: .55), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
  );
  c.restore();
  c.drawPath(body, strokePaint(outline, 1.6));
  if (look.fire) {
    // Glowing cracks in the hide.
    final crack = strokePaint(const Color(0xFFFF7A2A).withValues(alpha: still ? .9 : .7 + .3 * math.sin(t / 200).abs()), 1.6);
    for (final (a, b, d) in const [(Offset(-24, -68), Offset(-16, -60), Offset(-10, -64)), (Offset(2, -72), Offset(8, -64), Offset(16, -68))]) {
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(d.dx, d.dy),
        crack,
      );
    }
  } else {
    // Shaggy fur: a pale ruff spilling softly down the throat and chest, and a darker saddle of
    // guard hairs over the shoulders.
    final ruff = Path()..moveTo(44, -86 - b);
    for (var i = 0; i <= 6; i++) {
      final f = i / 6;
      final x = 50 - f * 12, y = -82 + f * 36;
      ruff
        ..lineTo(x + 3.5, y + 2)
        ..lineTo(x + .5, y + 5);
    }
    ruff
      ..lineTo(30, -44)
      ..quadraticBezierTo(40, -64, 38, -86 - b)
      ..close();
    c.drawPath(ruff, Paint()..color = look.belly.withValues(alpha: .9));
    final saddle = Path()..moveTo(34, -90 - b);
    for (var i = 0; i <= 5; i++) {
      final f = i / 5;
      saddle
        ..lineTo(32 - f * 26, -84 + f * 6 - b)
        ..lineTo(29 - f * 26, -79 + f * 6 - b);
    }
    saddle
      ..quadraticBezierTo(14, -82 - b, 34, -90 - b)
      ..close();
    c.drawPath(saddle, Paint()..color = shade(coat[1], -.2).withValues(alpha: .7));
  }

  // Head: a broad skull, a clear brow, a long muzzle and big pricked ears.
  c.save();
  c.translate(48, -92);
  c.scale(.86, .86);
  c.rotate(-.12 + (pounce > 0 ? -.25 : 0) + breathe * .02);
  final head = Path()
    ..moveTo(-10, 10)
    ..quadraticBezierTo(-13, -10, 2, -15)
    ..quadraticBezierTo(14, -19, 22, -11)
    ..quadraticBezierTo(28, -8, 34, -6)
    ..quadraticBezierTo(44, -4, 47, -1)
    ..quadraticBezierTo(48, 3, 44, 5)
    ..quadraticBezierTo(34, 7, 28, 8)
    ..quadraticBezierTo(22, 13, 12, 13)
    ..quadraticBezierTo(0, 14, -10, 10)
    ..close();
  fillPath(c, head, coat, const Offset(0, -18), const Offset(0, 14));
  // Pale muzzle and cheek.
  c.save();
  c.clipPath(head);
  c.drawPath(
    Path()
      ..moveTo(14, 13)
      ..quadraticBezierTo(18, 2, 30, 1)
      ..lineTo(50, 0)
      ..lineTo(50, 14)
      ..close(),
    Paint()..color = look.belly.withValues(alpha: look.fire ? .35 : .75),
  );
  c.drawLine(const Offset(2, -14), const Offset(26, -9), strokePaint(coat[0].withValues(alpha: .6), 2.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
  c.restore();
  c.drawPath(head, strokePaint(outline, 1.4));
  // Ears.
  for (final dx in const [2.0, 11.0]) {
    final ear = poly([Offset(dx - 5, -13), Offset(dx + 1, -32), Offset(dx + 7, -14)]);
    fillPath(c, ear, dx == 2 ? dark : coat, Offset(dx, -32), Offset(dx, -13));
    c.drawPath(poly([Offset(dx - 1.5, -15), Offset(dx + 1, -26), Offset(dx + 3.5, -15)]), Paint()..color = const Color(0x55301A14));
  }
  // Eye, nose, jaw.
  if (look.horns) {
    // Curling horns and a spiked collar.
    for (final dx in const [0.0, 9.0]) {
      final horn = Path()
        ..moveTo(dx + 2, -13)
        ..quadraticBezierTo(dx - 6, -34, dx + 12, -46)
        ..quadraticBezierTo(dx + 2, -32, dx + 10, -14)
        ..close();
      fillPath(c, horn, const [Color(0xFFF2EAD2), Color(0xFFB8AC8A), Color(0xFF4E4636)], Offset(dx - 6, -46), Offset(dx + 10, -13));
    }
    c.drawLine(const Offset(-10, 4), const Offset(-4, -12), strokePaint(const Color(0xFF2A2A2E), 6));
    for (final y in const [-8.0, -2.0, 4.0]) {
      c.drawPath(poly([Offset(-9, y - 2), Offset(-16, y), Offset(-9, y + 2)]), Paint()..color = const Color(0xFFC8CCD2));
    }
  }
  // A heavy brow over a narrow, glinting eye.
  c.drawLine(const Offset(14, -11), const Offset(26, -8), strokePaint(coat[2], 2));
  c.drawCircle(const Offset(21, -6), 4.5, Paint()..color = look.eye.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawOval(Rect.fromCenter(center: const Offset(21, -6), width: 6, height: 3.6), Paint()..color = look.eye);
  c.drawCircle(const Offset(22, -6), 1.1, Paint()..color = const Color(0xFF140C0A));
  c.drawOval(Rect.fromCenter(center: const Offset(46, -1), width: 6, height: 5), Paint()..color = const Color(0xFF140C0A));
  c.drawCircle(const Offset(45, -2.2), .9, Paint()..color = const Color(0x99FFFFFF));
  c.drawLine(const Offset(28, 6), const Offset(42, 4), strokePaint(const Color(0xFF140C0A), 1.6));
  if (pounce > .2 && pounce < .8) {
    // Jaws open for the bite.
    c.drawPath(poly(const [Offset(26, 5), Offset(44, 4), Offset(36, 15)]), Paint()..color = const Color(0xFF3A0A0A));
    for (final x in const [31.0, 38.0]) {
      c.drawPath(poly([Offset(x, 5), Offset(x + 1.5, 10), Offset(x + 3, 5)]), Paint()..color = const Color(0xFFF2EAD2));
    }
  }
  c.restore();

  if (look.horns) {
    // Bone spines down the back.
    for (var i = 0; i < 5; i++) {
      final x = -30.0 + i * 10;
      final y = -75.0 - i * 1.2 - breathe;
      final spine = poly([Offset(x - 4, y + 2), Offset(x + 1, y - 14 - (i % 2) * 4), Offset(x + 5, y + 1)]);
      c.drawPath(spine, Paint()..color = const Color(0xFFE8DCC0));
      c.drawPath(spine, strokePaint(outline, .8));
    }
  }
  // A burning mane along the neck and shoulders.
  if (look.fire) {
    for (var i = 0; i < 5; i++) {
      _flame(c, Offset(14.0 + i * 4, -80.0 - i * 2 - breathe), 7 + (i % 2) * 3.0, t + i * 90, still);
    }
  } else if (look.mane != null) {
    leafCluster(c, const Offset(28, -80), 10, look.mane!);
  }
  c.restore();
}

void _flame(Canvas c, Offset at, double size, double t, bool still) {
  final flick = still ? 0.0 : math.sin(t / 90 + at.dx) * .25;
  final p = Path()
    ..moveTo(at.dx - size * .5, at.dy)
    ..quadraticBezierTo(at.dx - size * .4, at.dy - size * (1.2 + flick), at.dx + size * flick, at.dy - size * (1.8 + flick))
    ..quadraticBezierTo(at.dx + size * .5, at.dy - size * .9, at.dx + size * .5, at.dy)
    ..close();
  c.drawPath(p, Paint()..color = const Color(0xCCFF6A1A));
  c.drawPath(Path()..addOval(Rect.fromCenter(center: at + Offset(0, -size * .5), width: size * .6, height: size)), Paint()..color = const Color(0xDDFFD27A));
}
