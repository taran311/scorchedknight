// Griffins: a lion's body, an eagle's head, talons and great feathered wings, rearing on the
// cliffs of the Skyreach Aeries. The Storm Roc is the biggest of them, dark as a thundercloud
// with lightning crawling in its feathers. Faces left (toward the hero); feet at the origin.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

class GriffinLook {
  const GriffinLook({required this.body, required this.wing, required this.head, this.beak = const Color(0xFFE8B040), this.eye = const Color(0xFFFFD84A), this.scale = 1, this.storm = false});
  final Ramp body, wing;
  final Color head, beak, eye;
  final double scale;

  /// Lightning crawls in its feathers (the Storm Roc).
  final bool storm;
}

const griffins = <String, GriffinLook>{
  'griffin': GriffinLook(body: [Color(0xFFE8C88A), Color(0xFFB8864A), Color(0xFF5A3A1A)], wing: [Color(0xFFB08A5A), Color(0xFF6A4A2A), Color(0xFF2A1A0E)], head: Color(0xFFF2EEE4)),
  'stormRoc': GriffinLook(body: [Color(0xFF8A8EA0), Color(0xFF4A4E62), Color(0xFF16182A)], wing: [Color(0xFF6A7088), Color(0xFF30344A), Color(0xFF0E1020)], head: Color(0xFFD8DCE8), beak: Color(0xFFCFD8E8), eye: Color(0xFFBFF0FF), scale: 1.4, storm: true),
};

/// Height of a griffin at scale 1, for health bars and hit marks.
const griffinHeight = 230.0;

/// A griffin rearing at [at], wings up. [hit] rocks it back; [dying] topples it.
void drawGriffin(Canvas c, GriffinLook look, Offset at, double scale, double t, {double hit = 0, double dying = 0, double alpha = 1, ColorFilter? tint, bool still = false}) {
  final flap = still ? 0.0 : math.sin(t / 260);
  c.save();
  c.translate(at.dx + hit * 18, at.dy);
  c.rotate(dying * .9);
  c.scale(scale * look.scale, scale * look.scale);
  final layered = alpha < 1 || tint != null;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha)..colorFilter = tint);
  final body = look.body, dark = [for (final x in body) shade(x, -.3)];
  final wingDark = [for (final x in look.wing) shade(x, -.25)];

  // Shadow.
  c.drawOval(Rect.fromCenter(center: const Offset(30, 2), width: 170, height: 18), Paint()..color = const Color(0x55000000));

  // The far wing, behind everything.
  _wing(c, const Offset(30, -110), wingDark, flap, far: true);
  // The tail: a lion's, with a tuft.
  final tail = Path()
    ..moveTo(100, -80)
    ..quadraticBezierTo(150, -70, 150, -30)
    ..quadraticBezierTo(150, -10, 170, -20);
  c.drawPath(tail, strokePaint(body[1], 7)..strokeCap = StrokeCap.round);
  c.drawOval(Rect.fromCenter(center: const Offset(172, -22), width: 18, height: 12), Paint()..color = dark[1]);
  // Far legs.
  _leg(c, const Offset(85, -55), const Offset(95, 0), dark, paw: true);
  _leg(c, const Offset(-10, -70), const Offset(-30, 0), dark, paw: false);
  // The body: a lion's barrel, deep in the chest.
  final torso = Path()
    ..moveTo(-30, -100)
    ..quadraticBezierTo(30, -120, 100, -95)
    ..quadraticBezierTo(125, -70, 100, -45)
    ..quadraticBezierTo(40, -30, -20, -50)
    ..quadraticBezierTo(-45, -70, -30, -100)
    ..close();
  fillPath(c, torso, body, const Offset(-40, -120), const Offset(120, -40), width: 1.8);
  // Near legs: hind paw, eagle talon in front.
  _leg(c, const Offset(70, -55), const Offset(75, 0), body, paw: true);
  _leg(c, const Offset(-15, -65), const Offset(-45, 0), body, paw: false);
  // Feathered chest and neck up to the head.
  final neck = Path()
    ..moveTo(-35, -60)
    ..quadraticBezierTo(-50, -110, -50, -140)
    ..lineTo(-20, -150)
    ..quadraticBezierTo(0, -110, 10, -95)
    ..close();
  fillPath(c, neck, [look.head, shade(look.head, -.15), shade(look.head, -.4)], const Offset(-50, -150), const Offset(10, -60));
  for (var i = 0; i < 5; i++) {
    final y = -70.0 - i * 15;
    c.drawPath(Path()..moveTo(-42 + i * 2.0, y)..quadraticBezierTo(-30, y + 6, -16 + i * 3.0, y), strokePaint(shade(look.head, -.3), 1.2));
  }
  // The eagle head, looking down at the hero.
  final head = Path()..addOval(Rect.fromCenter(center: const Offset(-48, -152), width: 46, height: 38));
  fillPath(c, head, [look.head, shade(look.head, -.12), shade(look.head, -.4)], const Offset(-70, -170), const Offset(-25, -133));
  // A crest of head feathers swept back.
  for (final (dx, dy) in const [(-30.0, -168.0), (-24.0, -160.0), (-28.0, -150.0)]) {
    c.drawPath(poly([Offset(dx, dy), Offset(dx + 22, dy - 6), Offset(dx + 4, dy + 6)]), Paint()..color = shade(look.head, -.1));
  }
  // The hooked beak.
  final beak = Path()
    ..moveTo(-62, -160)
    ..quadraticBezierTo(-92, -158, -94, -140)
    ..quadraticBezierTo(-86, -146, -78, -142)
    ..lineTo(-64, -144)
    ..close();
  fillPath(c, beak, [shade(look.beak, .3), look.beak, shade(look.beak, -.45)], const Offset(-94, -160), const Offset(-62, -140));
  // The eye: fierce, under a heavy brow.
  c.drawCircle(const Offset(-58, -158), 5, Paint()..color = look.eye);
  c.drawCircle(const Offset(-59, -158), 2.2, Paint()..color = const Color(0xFF14100A));
  c.drawLine(const Offset(-68, -166), const Offset(-48, -164), strokePaint(const Color(0xFF3A2A1A), 2.4));
  // The near wing, raised over its back.
  _wing(c, const Offset(20, -105), look.wing, flap, far: false);
  if (look.storm && !still) {
    // Lightning crawling through its feathers.
    final bolt = strokePaint(const Color(0xFFCFF4FF).withValues(alpha: .5 + .5 * math.sin(t / 90).abs()), 2.2)..strokeCap = StrokeCap.round;
    final p = Path()..moveTo(40, -200);
    for (var i = 1; i < 6; i++) {
      p.lineTo(40 + i * 14.0, -200 + (i.isEven ? -10 : 12) + i * 12.0);
    }
    c.drawPath(p, bolt);
    c.drawCircle(const Offset(40, -150), 60, Paint()..shader = ui.Gradient.radial(const Offset(40, -150), 60, [const Color(0x337AC8FF), const Color(0x007AC8FF)]));
  }
  if (layered) c.restore();
  c.restore();
}

/// A leg from [hip] to [foot]: a lion's paw behind, an eagle's talons in front.
void _leg(Canvas c, Offset hip, Offset foot, Ramp col, {required bool paw}) {
  final knee = Offset.lerp(hip, foot, .5)! + Offset(paw ? 14 : -8, 0);
  c.drawPath(Path()..moveTo(hip.dx, hip.dy)..quadraticBezierTo(knee.dx, knee.dy, foot.dx, foot.dy), strokePaint(col[1], paw ? 16 : 11)..strokeCap = StrokeCap.round);
  if (paw) {
    c.drawOval(Rect.fromCenter(center: foot + const Offset(-4, -3), width: 22, height: 10), Paint()..color = col[2]);
  } else {
    final claw = strokePaint(const Color(0xFF2A2018), 2.6)..strokeCap = StrokeCap.round;
    for (final dx in const [-12.0, -5.0, 2.0]) {
      c.drawLine(foot + const Offset(0, -4), foot + Offset(dx, 1), claw);
    }
    c.drawCircle(foot + const Offset(0, -5), 5, Paint()..color = const Color(0xFFE8B040));
  }
}

/// A great feathered wing rising from [root], its feathers fanned (flapping with [flap]).
void _wing(Canvas c, Offset root, Ramp col, double flap, {required bool far}) {
  final lift = flap * 14;
  for (var i = 0; i < 9; i++) {
    final a = -1.15 + i * .16 + (far ? .1 : 0);
    final len = 110.0 + (i < 5 ? i * 12 : (8 - i) * 10) + (far ? -10 : 0);
    final tip = root + Offset(math.cos(a) * len, math.sin(a) * len - lift * (i / 9));
    final dir = tip - root, n = Offset(-dir.dy, dir.dx) / dir.distance;
    final feather = Path()
      ..moveTo(root.dx, root.dy)
      ..quadraticBezierTo(root.dx + dir.dx * .55 + n.dx * 9, root.dy + dir.dy * .55 + n.dy * 9, tip.dx, tip.dy)
      ..quadraticBezierTo(root.dx + dir.dx * .55 - n.dx * 9, root.dy + dir.dy * .55 - n.dy * 9, root.dx, root.dy)
      ..close();
    fillPath(c, feather, [shade(col[0], -i * .02), col[1], col[2]], tip, root, width: 1.1);
  }
  // The coverts: shorter feathers over the base.
  final covert = Path()
    ..moveTo(root.dx - 12, root.dy + 10)
    ..quadraticBezierTo(root.dx + 30, root.dy - 70 - lift * .4, root.dx + 70, root.dy - 50 - lift * .5)
    ..quadraticBezierTo(root.dx + 40, root.dy - 10, root.dx - 12, root.dy + 10)
    ..close();
  fillPath(c, covert, [shade(col[0], .1), col[0], col[1]], root, root + const Offset(60, -60));
}
