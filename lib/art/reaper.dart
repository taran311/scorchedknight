// The Grim Reaper, who comes for you when you fall: a tattered, hooded shade that rises out of
// the mist behind you, winds up its scythe and reaps.
//
// [drawReaper] draws the figure itself (into the stage's silhouette pass, like every other figure);
// [drawReaperGlow] lays the parts that give off light (its eyes, the blade's edge, the arc of the
// stroke) over the finished scene, and [drawSoul] the little light that leaves you.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _robeTop = Color(0xFF2A2233), _robeLow = Color(0xFF17121C), _bone = Color(0xFFD9D1B8), _boneDark = Color(0xFF8E8670);
const _wood = Color(0xFF4E3826), _woodLight = Color(0xFF7C5C3C);
const reaperGlow = Color(0xFF9CF6E6);

/// Where everything is for a given moment of the stroke. [at] is the bottom of the robe, centred;
/// [reap] runs 0 (at rest) → .35 (wound up, blade high behind) → 1 (stroke finished, blade low in front).
class ReaperPose {
  ReaperPose(this.at, this.reap, {this.scale = 1});
  final Offset at;
  final double reap, scale;

  static const _rest = -math.pi / 2 + .3, _wound = -math.pi / 2 - 1.0, _through = -math.pi / 2 + 2.5;

  /// The shaft's direction, from the hands to the blade.
  static double angleFor(double reap) =>
      reap <= .35 ? _rest + (_wound - _rest) * (reap / .35) : _wound + (_through - _wound) * ((reap - .35) / .65).clamp(0.0, 1.0);

  double get angle => angleFor(reap);
  Offset p(double x, double y) => at + Offset(x * scale, y * scale);

  /// The leading hand, where the scythe turns.
  Offset get grip => p(40 + 22 * _lean, -205 + 18 * _lean);

  /// How far it leans into the stroke.
  double get _lean => reap <= .35 ? -reap / .35 * .5 : -.5 + 1.5 * ((reap - .35) / .65);

  Offset get dir => Offset(math.cos(angle), math.sin(angle));
  Offset get eye => p(36 + 6 * _lean, -322 + 8 * _lean);
}

void drawReaper(Canvas c, ReaperPose r, double t, {required bool still}) {
  final s = r.scale;
  Offset p(double x, double y) => r.p(x, y);
  final sway = still ? 0.0 : math.sin(t / 380);
  final lean = r._lean;

  // The mist it rises from.
  final mist = Paint()
    ..color = const Color(0x8C140E1C)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  for (var i = 0; i < 5; i++) {
    final dx = (i - 2) * 44.0 + (still ? 0 : math.sin(t / 700 + i * 1.7) * 14);
    c.drawOval(Rect.fromCenter(center: p(dx, 6 + (i % 2) * 8.0), width: 120 * s, height: 34 * s), mist);
  }

  // The back arm, its bony hand lower on the shaft.
  final grip = r.grip, dir = r.dir;
  final lowHand = grip - dir * (58 * s);
  final sleeve = Paint()
    ..color = _robeLow
    ..strokeWidth = 20 * s
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final backShoulder = p(-30 + 8 * lean, -282);
  c.drawPath(Path()
    ..moveTo(backShoulder.dx, backShoulder.dy)
    ..quadraticBezierTo(p(-30, -210).dx, p(-30, -210).dy, lowHand.dx - 6 * s, lowHand.dy), sleeve);

  // The robe: narrow at the shoulders, flaring to a ragged hem that drifts in the mist.
  final robe = Path()..moveTo(p(36 + 10 * lean, -286).dx, p(36 + 10 * lean, -286).dy);
  robe.cubicTo(p(56, -220).dx, p(56, -220).dy, p(70, -110).dx, p(70, -110).dy, p(84, -10).dx, p(84, -10).dy);
  const n = 10;
  for (var i = 0; i <= n; i++) {
    final x = 84 - 182 * i / n, deep = i.isEven;
    final wave = still ? 0.0 : math.sin(t / 260 + i * 1.3) * 7;
    final q = p(x + wave * .6, deep ? 6 + wave : -24 + wave * .5);
    robe.lineTo(q.dx, q.dy);
  }
  robe.cubicTo(p(-92, -110).dx, p(-92, -110).dy, p(-64, -230).dx, p(-64, -230).dy, p(-42 + 8 * lean, -282).dx, p(-42 + 8 * lean, -282).dy);
  robe.close();
  c.drawPath(
    robe,
    Paint()
      ..shader = ui.Gradient.linear(p(0, -290), p(0, 10), const [_robeTop, _robeLow, Color(0x0017121C)], const [0, .72, 1]),
  );
  // Deep folds falling from the shoulders.
  final fold = Paint()
    ..color = const Color(0x660A070D)
    ..strokeWidth = 5 * s
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  for (final (x0, x1) in const [(-18.0, -40.0), (4.0, 10.0), (24.0, 50.0)]) {
    final a = p(x0, -260), b = p(x0 + 6 + sway * 3, -140), e = p(x1 + sway * 5, -30);
    c.drawPath(Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(b.dx, b.dy, e.dx, e.dy), fold);
  }

  // The scythe: a long, crooked shaft and a great curved blade.
  final butt = grip - dir * (130 * s), head = grip + dir * (200 * s);
  c.drawLine(butt, head, Paint()
    ..color = _wood
    ..strokeWidth = 8 * s
    ..strokeCap = StrokeCap.round);
  c.drawLine(butt + Offset(-dir.dy, dir.dx) * (-1.5 * s), head + Offset(-dir.dy, dir.dx) * (-1.5 * s), Paint()
    ..color = _woodLight
    ..strokeWidth = 2.2 * s
    ..strokeCap = StrokeCap.round);
  c.save();
  c.translate(grip.dx, grip.dy);
  c.rotate(r.angle);
  c.scale(s);
  final blade = _blade();
  c.drawPath(blade, Paint()..shader = ui.Gradient.linear(const Offset(196, 0), const Offset(130, 150), const [Color(0xFF5E666E), Color(0xFFB8C4CC), Color(0xFFE9F0F2)], const [0, .6, 1]));
  c.drawPath(blade, Paint()
    ..color = const Color(0xFF2A2E33)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6);
  // The collar binding blade to shaft.
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(192, 2), width: 18, height: 13), const Radius.circular(3)), Paint()..color = const Color(0xFF3A3530));
  c.restore();

  // The front arm, reaching to the grip.
  final frontShoulder = p(30 + 12 * lean, -280);
  c.drawPath(Path()
    ..moveTo(frontShoulder.dx, frontShoulder.dy)
    ..quadraticBezierTo(p(56 + 10 * lean, -240).dx, p(56, -240).dy, grip.dx - dir.dx * 6 * s, grip.dy - dir.dy * 6 * s), sleeve..color = _robeTop);
  // Bony hands wrapped round the shaft.
  for (final h in [lowHand, grip]) {
    c.drawCircle(h, 7.5 * s, Paint()..color = _bone);
    for (var f = -1; f <= 1; f++) {
      final knuckle = h + Offset(-dir.dy, dir.dx) * (6 * s) + dir * (f * 4.5 * s);
      c.drawCircle(knuckle, 2.6 * s, Paint()..color = _boneDark);
    }
  }

  // The hood, peaked and hanging forward, a skull in its shadow.
  final hood = Path()
    ..moveTo(p(-48 + 8 * lean, -278).dx, p(-48 + 8 * lean, -278).dy)
    ..quadraticBezierTo(p(-54 + 8 * lean, -352).dx, p(-54 + 8 * lean, -352).dy, p(-10 + 6 * lean, -380).dx, p(-10 + 6 * lean, -380).dy)
    ..quadraticBezierTo(p(44 + 8 * lean, -380).dx, p(44 + 8 * lean, -380).dy, p(64 + 8 * lean, -318).dx, p(64 + 8 * lean, -318).dy)
    ..quadraticBezierTo(p(62 + 8 * lean, -290).dx, p(62 + 8 * lean, -290).dy, p(40 + 10 * lean, -282).dx, p(40 + 10 * lean, -282).dy)
    ..close();
  c.drawPath(hood, Paint()..shader = ui.Gradient.linear(p(-40, -380), p(50, -280), const [Color(0xFF332A3D), _robeLow]));
  final face = Rect.fromCenter(center: p(38 + 7 * lean, -318 + 6 * lean), width: 40 * s, height: 56 * s);
  c.drawOval(face, Paint()..color = const Color(0xFF050307));
  // The skull: cranium, cheek and a grinning jaw, lit only from below.
  final skull = p(40 + 7 * lean, -320 + 7 * lean);
  c.drawCircle(skull, 13 * s, Paint()..shader = ui.Gradient.linear(skull - Offset(0, 13 * s), skull + Offset(0, 13 * s), const [Color(0xFF3A362E), _boneDark, _bone]));
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: skull + Offset(2 * s, 14 * s), width: 16 * s, height: 9 * s), Radius.circular(3 * s)),
    Paint()..color = _bone,
  );
  final teeth = Paint()
    ..color = const Color(0xFF3A3328)
    ..strokeWidth = 1 * s;
  for (var i = -2; i <= 2; i++) {
    c.drawLine(skull + Offset((2 + i * 3) * s, 11 * s), skull + Offset((2 + i * 3) * s, 17 * s), teeth);
  }
  final socket = Paint()..color = const Color(0xFF050307);
  c.drawCircle(r.eye + Offset(-6 * s, 0), 4.4 * s, socket);
  c.drawCircle(r.eye + Offset(6 * s, 0), 4.4 * s, socket);
  c.drawPath(
    Path()
      ..moveTo(skull.dx + 1 * s, skull.dy + 5 * s)
      ..lineTo(skull.dx - 2 * s, skull.dy + 9 * s)
      ..lineTo(skull.dx + 4 * s, skull.dy + 9 * s)
      ..close(),
    socket,
  );
}

/// The blade, in the shaft's own frame: the shaft runs along +x from the hands, and the blade
/// hooks out sideways from its head, curving back toward the reaper.
Path _blade() => Path()
  ..moveTo(186, -8)
  ..quadraticBezierTo(232, 70, 128, 168)
  ..quadraticBezierTo(150, 120, 168, 82)
  ..quadraticBezierTo(184, 40, 176, 6)
  ..close();

/// What shines: the eyes, the cutting edge, and the bright arc the stroke leaves behind ([trail]).
void drawReaperGlow(Canvas c, ReaperPose r, double appear, double trail, double t, {required bool still}) {
  final s = r.scale;
  final flicker = still ? 1.0 : .8 + .2 * math.sin(t / 90) * math.sin(t / 143);
  final fierce = (r.reap > .35 ? 1.0 : r.reap / .35) * .6 + .4;
  final glow = Paint()
    ..color = reaperGlow.withValues(alpha: appear * flicker * fierce)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s);
  for (final dx in [-6.0, 6.0]) {
    final e = r.eye + Offset(dx * s, 0);
    c.drawCircle(e, 7 * s, glow);
    c.drawCircle(e, 2.2 * s, Paint()..color = Colors.white.withValues(alpha: appear * flicker));
  }

  // A glint running along the edge.
  c.save();
  c.translate(r.grip.dx, r.grip.dy);
  c.rotate(r.angle);
  c.scale(s);
  final edge = Path()
    ..moveTo(176, 6)
    ..quadraticBezierTo(184, 40, 168, 82)
    ..quadraticBezierTo(150, 120, 128, 168);
  c.drawPath(edge, Paint()
    ..color = reaperGlow.withValues(alpha: appear * (.25 + .5 * fierce))
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  c.drawPath(edge, Paint()
    ..color = Colors.white.withValues(alpha: appear * .9)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4);
  c.restore();

  if (trail > .01) {
    // The stroke: a pale crescent swept through the air where the blade passed.
    const from = .4;
    final a0 = ReaperPose.angleFor(from) + .62, a1 = ReaperPose.angleFor(math.min(r.reap, 1)) + .62;
    if (a1 > a0) {
      final rect = Rect.fromCircle(center: r.grip, radius: 192 * s);
      final sweep = ui.Gradient.sweep(r.grip, [reaperGlow.withValues(alpha: 0), reaperGlow.withValues(alpha: .55 * trail), Colors.white.withValues(alpha: .95 * trail)], const [0, .7, 1], TileMode.clamp, a0, a1);
      c.drawArc(rect, a0, a1 - a0, false, Paint()
        ..shader = sweep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46 * s
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      c.drawArc(rect.inflate(10 * s), a0, a1 - a0, false, Paint()
        ..shader = sweep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * s
        ..strokeCap = StrokeCap.round);
    }
  }
}

/// The soul: a small pale flame drawn up out of you, [p] from 0 (leaving) to 1 (gone).
void drawSoul(Canvas c, Offset from, Offset to, double p, double t, {required bool still}) {
  if (p <= 0 || p >= 1) return;
  final e = Curves.easeInOut.transform(p);
  final drift = still ? 0.0 : math.sin(t / 160) * 10 * (1 - e);
  final at = Offset.lerp(from, to, e)! + Offset(drift, 0);
  final a = math.sin(p * math.pi).clamp(0.0, 1.0);
  // A wispy tail trailing back toward the body.
  for (var i = 1; i <= 5; i++) {
    final q = math.max(0.0, e - i * .045);
    final tail = Offset.lerp(from, to, q)! + Offset(still ? 0 : math.sin(t / 160 + i) * 8, 0);
    c.drawCircle(tail, 13 - i * 1.8, Paint()..color = reaperGlow.withValues(alpha: a * (.6 - i * .09)));
  }
  c.drawCircle(at, 40, Paint()
    ..color = reaperGlow.withValues(alpha: a * .55)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
  c.drawCircle(at, 13, Paint()
    ..color = reaperGlow.withValues(alpha: a)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(at, 8, Paint()..color = Colors.white.withValues(alpha: a));
}
