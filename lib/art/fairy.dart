// The fairy companion (Scroll of the Fae).

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A fairy companion: a glowing body, four flickering wings and a trail of motes. [stage] 0 (a
/// wisp) to 3 (a seraph, golden, with a halo).
void drawFairy(Canvas c, Offset at, int stage, double t, {bool still = false}) {
  final gold = stage >= 3;
  final core = gold ? const Color(0xFFFFE9A8) : const Color(0xFFF4D0FF), rim = gold ? const Color(0xFFF2C14E) : const Color(0xFFC88AF0);
  final size = 7.0 + stage * 1.6;
  // Glow.
  c.drawCircle(at, size * 3.2, Paint()..color = rim.withValues(alpha: .22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  // Wings (not on a wisp): two pairs, flapping.
  if (stage >= 1) {
    final flap = still ? .7 : .55 + .45 * math.sin(t / 45).abs();
    final wing = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .32);
    final edge = Paint()
      ..color = rim.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final side in const [-1.0, 1.0]) {
      for (final (dy, len, tilt) in [(-2.0, size * 2.4, -.5), (3.0, size * 1.7, .45)]) {
        c.save();
        c.translate(at.dx, at.dy + dy);
        c.rotate(side * (tilt + (1 - flap) * .6) - (side < 0 ? math.pi : 0));
        final r = Rect.fromLTWH(0, -len * .28 * flap, len, len * .56 * flap);
        c.drawOval(r, wing);
        c.drawOval(r, edge);
        c.restore();
      }
    }
  }
  // Body: a small glowing figure.
  c.drawOval(Rect.fromCenter(center: at + Offset(0, size * .55), width: size * .9, height: size * 1.5), Paint()..color = core.withValues(alpha: .9));
  c.drawCircle(at - Offset(0, size * .45), size * .5, Paint()..color = core);
  c.drawCircle(at, size * .55, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  if (gold) {
    c.drawOval(Rect.fromCenter(center: at - Offset(0, size * 1.15), width: size * 1.2, height: size * .38), Paint()
      ..color = const Color(0xFFFFE08A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
  }
  // A tiny warm heart makes the companion readable even at reduced UI scale.
  c.drawCircle(at + Offset(0, size * .28), size * .18, Paint()..color = gold ? const Color(0xFFFFB94F) : const Color(0xFFE9A8FF));
  // A trail of motes.
  if (!still) {
    for (var i = 1; i <= 4; i++) {
      final o = Offset(math.sin(t / 300 + i) * 6 + i * 4, i * 5.0 + math.cos(t / 250 + i) * 3);
      c.drawCircle(at + o, 1.6 - i * .25, Paint()..color = core.withValues(alpha: .7 - i * .14));
    }
  }
}
