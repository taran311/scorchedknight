// The bats of the Hollowdeep: a giant cave bat hovering on its wings, facing +x (the beast painter
// flips it to face the hero). Feet hang at [at]'s ground line; the bat itself flies above it.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

class BatLook {
  const BatLook({required this.fur, required this.membrane, this.eye = const Color(0xFFFF5A3A), this.ruff, this.torn = false});
  final Color fur, membrane, eye;

  /// A pale ruff of fur at the throat (the Roost Mother).
  final Color? ruff;

  /// Old tears through the wings.
  final bool torn;
}

const caveBat = BatLook(fur: Color(0xFF4A3E46), membrane: Color(0xFF5A4450));
const roostMother = BatLook(fur: Color(0xFFB8AEB4), membrane: Color(0xFF8A6A78), eye: Color(0xFFFF3A4A), ruff: Color(0xFFF2ECEE), torn: true);

Offset _rot(Offset v, double a) => Offset(v.dx * math.cos(a) - v.dy * math.sin(a), v.dx * math.sin(a) + v.dy * math.cos(a));

/// One wing from the shoulder: an arm to the wrist, four long fingers, and the membrane between
/// them in scallops. [side] 1 is the near (right) wing, -1 the far one.
void _wing(Canvas c, double side, double flap, Ramp membrane, Color bone, {bool torn = false}) {
  final shoulder = Offset(16 * side, -108);
  final wrist = shoulder + _rot(Offset(58 * side, -40), flap * side);
  final tips = [for (final v in const [Offset(72, -34), Offset(84, 8), Offset(62, 50), Offset(26, 66)]) wrist + _rot(Offset(v.dx * side, v.dy), flap * side * .6)];
  final hip = Offset(8 * side, -74);
  final p = Path()
    ..moveTo(shoulder.dx, shoulder.dy)
    ..lineTo(wrist.dx, wrist.dy)
    ..lineTo(tips[0].dx, tips[0].dy);
  var prev = tips[0];
  for (final q in [...tips.skip(1), hip]) {
    final mid = (prev + q) / 2, ctrl = mid + (wrist - mid) * .28;
    p.quadraticBezierTo(ctrl.dx, ctrl.dy, q.dx, q.dy);
    prev = q;
  }
  p.close();
  fillPath(c, p, membrane, wrist + const Offset(0, -60), wrist + const Offset(0, 70), width: 1.6);
  if (torn) {
    // Two old rents, showing the dark through them.
    for (final (i, k) in const [(0, .55), (1, .45)]) {
      final at = Offset.lerp(wrist, tips[i + 1], k)! + Offset.lerp(Offset.zero, tips[i] - tips[i + 1], .3)!;
      c.drawPath(poly([at + const Offset(-4, -6), at + const Offset(5, -2), at + const Offset(2, 7), at + const Offset(-5, 3)]), Paint()..color = const Color(0xFF0E0A0C));
    }
  }
  for (final q in tips) {
    c.drawLine(wrist, q, strokePaint(bone, 1.8));
  }
  c.drawLine(shoulder, wrist, strokePaint(bone, 3.2));
  // The thumb's hook at the wrist.
  c.drawPath(poly([wrist, wrist + Offset(6 * side, -9), wrist + Offset(2 * side, 1)]), Paint()..color = const Color(0xFFE8E0D0));
}

/// A giant bat at [at], hovering and beating its wings.
void drawBat(Canvas c, BatLook look, Offset at, double scale, double t, {double hit = 0, bool still = false}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  c.translate(-hit * 10, still ? 0 : math.sin(t / 180) * 6);
  final flap = still ? .1 : math.sin(t / 140) * .55 - .1;
  final fur = rampOf(look.fur, .25, .55), bone = shade(look.fur, -.5);
  final membrane = [shade(look.membrane, .15), look.membrane, shade(look.membrane, -.55)];
  _wing(c, -1, flap, [for (final m in membrane) shade(m, -.25)], shade(bone, -.2), torn: look.torn);
  // Feet hanging, claws curled.
  for (final dx in const [-6.0, 8.0]) {
    c.drawLine(Offset(dx, -72), Offset(dx + 2, -58), strokePaint(shade(look.fur, -.4), 3));
    c.drawPath(poly([Offset(dx - 3, -58), Offset(dx + 6, -58), Offset(dx + 2, -52)]), Paint()..color = const Color(0xFFD8D0C0));
  }
  // A furry body, paler down the chest, and tufts at the shoulders.
  fillPath(c, Path()..addOval(const Rect.fromLTWH(-20, -122, 40, 54)), fur, const Offset(-20, -122), const Offset(20, -68), width: 1.6);
  fillPath(c, Path()..addOval(const Rect.fromLTWH(-9, -112, 20, 34)), [shade(look.fur, .35), shade(look.fur, .2), look.fur], const Offset(0, -112), const Offset(0, -78), line: false);
  for (final dx in const [-14.0, -6.0, 4.0, 12.0]) {
    c.drawPath(poly([Offset(dx - 5, -114), Offset(dx, -124), Offset(dx + 5, -114)]), Paint()..color = fur[1]);
  }
  _wing(c, 1, flap, membrane, bone, torn: look.torn);
  // The head, turned to face its prey: tall ears, a snub snout with a leaf nose, fangs.
  const h = Offset(8, -130);
  for (final (ex, lean, far) in const [(-6.0, -.25, true), (8.0, .15, false)]) {
    final ear = poly([h + Offset(ex - 7, -8), h + Offset(ex - 2 + lean * 30, -40), h + Offset(ex + 8, -6)]);
    fillPath(c, ear, far ? darker(fur) : fur, h + const Offset(0, -40), h, width: 1.3);
    c.drawPath(poly([h + Offset(ex - 3, -10), h + Offset(ex - 1 + lean * 26, -32), h + Offset(ex + 4, -9)]), Paint()..color = far ? const Color(0xFF7A5058) : const Color(0xFFB07A80));
  }
  fillPath(c, Path()..addOval(Rect.fromLTWH(h.dx - 15, h.dy - 14, 30, 26)), fur, h + const Offset(-15, -14), h + const Offset(15, 12), width: 1.5);
  fillPath(c, Path()..addOval(Rect.fromLTWH(h.dx + 6, h.dy - 4, 14, 11)), [shade(look.fur, .3), shade(look.fur, .1), shade(look.fur, -.3)], h + const Offset(6, -4), h + const Offset(20, 7), width: 1.2);
  c.drawPath(poly([h + const Offset(15, -8), h + const Offset(19, -1), h + const Offset(13, -1)]), Paint()..color = shade(look.fur, -.3));
  c.drawCircle(h + const Offset(5, -5), 4.5, Paint()..color = look.eye.withValues(alpha: .6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(h + const Offset(5, -5), 2.4, Paint()..color = look.eye);
  c.drawPath(poly([h + const Offset(8, 5), h + const Offset(19, 6), h + const Offset(10, 10)]), Paint()..color = const Color(0xFF1A0E10));
  for (final fx in const [11.0, 16.0]) {
    c.drawPath(poly([h + Offset(fx - 1.4, 5), h + Offset(fx, 9.5), h + Offset(fx + 1.4, 5)]), Paint()..color = const Color(0xFFF2ECE0));
  }
  if (look.ruff case final ruff?) {
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * .95 + i * math.pi * .15;
      c.drawPath(poly([h + Offset(-12 + math.cos(a) * 4, 10), h + Offset(-6 + math.cos(a) * 16, 22 + math.sin(a) * 4), h + const Offset(2, 12)]), Paint()..color = ruff);
    }
  }
  c.restore();
}
