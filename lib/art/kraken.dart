// The Kraken: a vast crimson-violet beast heaving out of the shallows, a bulbous mantle with two
// great slit-pupilled eyes, and arms like ship's masts curling over the shore. Faces left (toward
// the hero). Feet (the waterline) at the origin, about 330 units tall at scale 1.
//
// [drawTentacle] also draws the arms that burst from the ground for Call of the Kraken.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'griffin.dart';
import 'paint_kit.dart';

const _hide = [Color(0xFFC4607A), Color(0xFF7A2C4A), Color(0xFF2E0C1E)];
const _underside = Color(0xFFE8B4A8);
const _sucker = Color(0xFFF2D2C4);

/// Height of the Kraken at scale 1, for health bars and hit marks.
const krakenHeight = 330.0;

Offset _cubic(Offset a, Offset b, Offset c, Offset d, double t) {
  final u = 1 - t;
  return a * (u * u * u) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t * t * t);
}

/// One tapering arm along a cubic curve [a]..[d], [width] thick at the root. Suckers run along the
/// side facing [suckerSide] (+1 or -1).
void drawTentacle(Canvas c, Offset a, Offset b, Offset cc, Offset d, double width, {Ramp ramp = _hide, double suckerSide = 1, double alpha = 1, bool suckers = true, double taper = .92, Color belly = _underside}) {
  const n = 22;
  final left = <Offset>[], right = <Offset>[], mid = <Offset>[], norms = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n, p = _cubic(a, b, cc, d, t), q = _cubic(a, b, cc, d, math.min(1, t + .01)), p0 = _cubic(a, b, cc, d, math.max(0, t - .01));
    var dir = q - p0;
    if (dir.distance < .001) dir = const Offset(0, -1);
    final nrm = Offset(-dir.dy, dir.dx) / dir.distance, w = width * (1 - t * taper) / 2;
    left.add(p + nrm * w);
    right.add(p - nrm * w);
    mid.add(p);
    norms.add(nrm);
  }
  final path = Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();
  // Lit from above: lighter at the root, darker towards the tip, across the arm.
  final across = norms[n ~/ 2] * width * .5;
  c.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(mid[n ~/ 2] + across, mid[n ~/ 2] - across, [for (final x in ramp) x.withValues(alpha: alpha)], const [0, .5, 1]),
  );
  c.drawPath(path, strokePaint(outline.withValues(alpha: .8 * alpha), 1.4));
  // The pale underside and its suckers.
  final under = Path()..moveTo(mid.first.dx, mid.first.dy);
  for (var i = 1; i <= n; i++) {
    final p = mid[i] + norms[i] * (width * (1 - i / n * taper) / 2 * .55 * suckerSide);
    under.lineTo(p.dx, p.dy);
  }
  c.drawPath(under, strokePaint(belly.withValues(alpha: .5 * alpha), width * .16));
  if (!suckers) {
    // Scales instead: little arcs along the back.
    for (var i = 1; i < n - 1; i++) {
      final w = width * (1 - i / n * taper) / 2;
      c.drawArc(Rect.fromCircle(center: mid[i] - norms[i] * (w * .4 * suckerSide), radius: math.max(1.5, w * .35)), 0, math.pi, false, strokePaint(ramp[2].withValues(alpha: .35 * alpha), 1.2));
    }
    return;
  }
  for (var i = 2; i < n - 2; i += 2) {
    final w = width * (1 - i / n * .92) / 2;
    c.drawCircle(mid[i] + norms[i] * (w * .62 * suckerSide), math.max(1.2, w * .3), Paint()..color = _sucker.withValues(alpha: .9 * alpha));
    c.drawCircle(mid[i] + norms[i] * (w * .62 * suckerSide), math.max(.6, w * .14), Paint()..color = const Color(0xFF7A2C4A).withValues(alpha: alpha));
  }
}

/// The Kraken at [at] (the waterline below its centre), at [scale]. [hit] 0..1 rocks it back,
/// [dying] 0..1 sinks it beneath the waves.
void drawKraken(Canvas c, Offset at, double scale, double t, {double hit = 0, double dying = 0, double alpha = 1, ColorFilter? tint, bool still = false}) {
  final sway = still ? 0.0 : t / 700;
  c.save();
  c.translate(at.dx + hit * 18, at.dy + dying * 260);
  c.scale(scale, scale);
  final layered = alpha < 1 || tint != null;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha)..colorFilter = tint);
  if (dying > 0) c.clipRect(const Rect.fromLTRB(-400, -600, 400, 8)); // sinking below the shore

  // A dark pool of churned seawater around it.
  c.drawOval(Rect.fromCenter(center: const Offset(10, 2), width: 340, height: 34), Paint()..color = const Color(0xCC0E2A36));
  c.drawOval(Rect.fromCenter(center: const Offset(10, 0), width: 300, height: 22), strokePaint(const Color(0x88CFEFF2), 2));

  double s(double k, [double a = 1]) => math.sin(sway * a + k);

  // Back arms, darker, rising behind the mantle.
  final dark = [for (final x in _hide) shade(x, -.3)];
  drawTentacle(c, const Offset(60, -30), Offset(150, -120 + 20 * s(0)), Offset(170 + 16 * s(1), -260), Offset(110 + 24 * s(2), -300 + 10 * s(.5)), 46, ramp: dark, suckerSide: -1);
  drawTentacle(c, const Offset(-30, -30), const Offset(-60, -160), Offset(20 + 18 * s(3), -280 + 10 * s(1)), Offset(70 + 20 * s(1.4), -250), 40, ramp: dark);

  // The mantle: a great bulbous head leaning back.
  final mantle = Path()
    ..moveTo(-74, -60)
    ..cubicTo(-110, -150, -80, -300, 30, -326)
    ..cubicTo(120, -330, 140, -230, 96, -150)
    ..cubicTo(80, -110, 70, -80, 68, -60)
    ..close();
  fillPath(c, mantle, _hide, const Offset(-80, -300), const Offset(110, -60), width: 2);
  // Ridges and pale spots.
  for (final (p, r) in const [(Offset(10, -270), 9.0), (Offset(50, -230), 12.0), (Offset(-30, -220), 7.0), (Offset(70, -280), 6.0), (Offset(20, -190), 8.0), (Offset(-50, -170), 6.0)]) {
    c.drawOval(Rect.fromCenter(center: p, width: r * 2, height: r * 1.4), Paint()..color = const Color(0x55F2C4C8));
  }
  c.drawPath(
    Path()
      ..moveTo(-40, -290)
      ..quadraticBezierTo(0, -240, 60, -300),
    strokePaint(const Color(0x442E0C1E), 4),
  );

  // Eyes, facing the hero: huge, gold, with goat-slit pupils.
  for (final (p, r) in const [(Offset(-58, -132), 19.0), (Offset(-8, -122), 16.0)]) {
    c.drawCircle(p, r + 4, Paint()..color = const Color(0xFF3A0E22));
    c.drawCircle(p, r + 10, Paint()..color = const Color(0x66FFD24A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawCircle(p, r, Paint()..shader = ui.Gradient.radial(p, r, const [Color(0xFFFFF0A0), Color(0xFFF2B830), Color(0xFF9A5A10)], const [0, .6, 1]));
    final blink = still ? 1.0 : (math.sin(t / 2300 + p.dx) > .985 ? .15 : 1.0);
    c.drawOval(Rect.fromCenter(center: p, width: r * 1.5, height: r * .34 * blink + 1), Paint()..color = const Color(0xFF140408));
    c.drawCircle(p + Offset(-r * .35, -r * .4), r * .18, Paint()..color = const Color(0xCCFFFFFF));
  }
  // A heavy brow over the eyes.
  c.drawPath(
    Path()
      ..moveTo(-84, -150)
      ..quadraticBezierTo(-40, -168, 10, -146),
    strokePaint(const Color(0xFF4A1430), 7)..strokeCap = StrokeCap.round,
  );

  // Front arms: two coiled on the shore, one reaching for the hero, one raised to strike.
  drawTentacle(c, const Offset(-60, -50), const Offset(-120, -10), Offset(-180 + 8 * s(2), -6), Offset(-220 + 10 * s(2.4), -40 + 6 * s(1)), 44, suckerSide: -1);
  drawTentacle(c, const Offset(50, -50), const Offset(110, -4), Offset(170, -10 + 4 * s(1)), Offset(200 + 8 * s(1.8), -50 + 8 * s(.3)), 42);
  drawTentacle(c, const Offset(-56, -56), Offset(-130, -80 + 10 * s(.7)), Offset(-210 + 14 * s(1.1), -90 + 12 * s(2)), Offset(-250 + 18 * s(1.3), -160 + 16 * s(.9)), 40, suckerSide: -1);
  drawTentacle(c, const Offset(-70, -70), const Offset(-150, -120), Offset(-200 + 12 * s(2.2), -250 + 10 * s(.4)), Offset(-150 + 20 * s(1.6), -300 + 16 * s(1.2)), 36, suckerSide: -1);

  // Foam where the arms meet the water.
  final foam = Paint()..color = const Color(0xCCEAF6F8);
  for (final x in const [-150.0, -70.0, 20.0, 120.0]) {
    c.drawOval(Rect.fromCenter(center: Offset(x + (still ? 0 : 6 * math.sin(t / 300 + x)), -2), width: 40, height: 8), foam);
  }
  if (layered) c.restore();
  c.restore();
}

/// A breaking wave crossing the field for Tidal Wave: [p] 0..1 sweeps it from [from] to [to].
void drawWave(Canvas c, Offset from, Offset to, double p, double t) {
  if (p <= 0 || p >= 1) return;
  final x = from.dx + (to.dx - from.dx) * p, ground = from.dy;
  final h = 210 * math.sin(math.min(1, p * 1.3) * math.pi * .9).abs() + 40;
  final fade = p > .85 ? (1 - p) / .15 : 1.0;
  final body = Path()
    ..moveTo(x - 360, ground + 6)
    ..lineTo(x - 300, ground - h * .35)
    ..quadraticBezierTo(x - 120, ground - h * .7, x - 10, ground - h)
    ..quadraticBezierTo(x + 60, ground - h * 1.05, x + 70, ground - h * .78)
    ..quadraticBezierTo(x + 30, ground - h * .8, x + 30, ground - h * .55)
    ..quadraticBezierTo(x + 50, ground - h * .2, x + 90, ground + 6)
    ..close();
  c.drawPath(
    body,
    Paint()
      ..shader = ui.Gradient.linear(Offset(x, ground - h), Offset(x, ground), [const Color(0xFF8EE0F0).withValues(alpha: .92 * fade), const Color(0xFF2A88B8).withValues(alpha: .9 * fade), const Color(0xFF0E3A5A).withValues(alpha: .85 * fade)], const [0, .5, 1]),
  );
  // White foam on the crest and spray.
  c.drawPath(
    Path()
      ..moveTo(x - 140, ground - h * .66)
      ..quadraticBezierTo(x - 20, ground - h * 1.04, x + 64, ground - h * .8),
    strokePaint(const Color(0xFFF2FCFF).withValues(alpha: fade), 9)..strokeCap = StrokeCap.round,
  );
  final spray = Paint()..color = const Color(0xFFEAF8FF).withValues(alpha: .8 * fade);
  for (var i = 0; i < 9; i++) {
    final a = t / 120 + i * 1.7;
    c.drawCircle(Offset(x + 40 + 30 * math.cos(a), ground - h * .9 - 22 * math.sin(a).abs() - i * 3), 3 + (i % 3) * 2.0, spray);
  }
  // Streaks of water through the body.
  for (var i = 0; i < 4; i++) {
    c.drawPath(
      Path()
        ..moveTo(x - 260 + i * 60, ground - 8 - i * 4)
        ..quadraticBezierTo(x - 160 + i * 50, ground - h * (.3 + i * .1), x - 40 + i * 20, ground - h * (.55 + i * .08)),
      strokePaint(const Color(0x55E8FAFF).withValues(alpha: .35 * fade), 3),
    );
  }
}

/// Call of the Kraken: [p] 0..1, three great arms burst from the ground around [at], wrap the foe,
/// then sink away.
void drawKrakenGrasp(Canvas c, Offset at, double p, double t) {
  if (p <= 0 || p >= 1) return;
  final rise = p < .35 ? p / .35 : (p > .75 ? (1 - p) / .25 : 1.0);
  final squeeze = p > .35 && p < .75 ? math.sin((p - .35) / .4 * math.pi) : 0.0;
  // Cracked earth and splashing water where they break through.
  c.drawOval(Rect.fromCenter(center: at + const Offset(0, 4), width: 300 * rise + 20, height: 26), Paint()..color = const Color(0xCC0E2A36));
  for (final (dx, lean, h) in const [(-110.0, 1.0, 300.0), (100.0, -1.0, 280.0), (-20.0, .4, 340.0)]) {
    final base = at + Offset(dx, 0), top = h * rise;
    drawTentacle(
      c,
      base,
      base + Offset(-lean * 20, -top * .4),
      base + Offset(lean * (60 + 40 * squeeze), -top * .8),
      base + Offset(lean * (90 + 30 * squeeze) + 8 * math.sin(t / 200 + dx), -top),
      40 * (.6 + .4 * rise),
      suckerSide: lean,
      alpha: rise.clamp(0.0, 1.0),
    );
  }
  final spray = Paint()..color = const Color(0xCCEAF8FF);
  for (var i = 0; i < 8; i++) {
    final a = i / 8 * math.pi, r = 150 * rise;
    c.drawCircle(at + Offset(math.cos(a) * r - 10, -math.sin(a) * 24 * rise), 4, spray);
  }
}


// ------------------------------------------------------------------ serpents of the deep

/// Colours and size of a sea serpent (and the Leviathan, the biggest of them).
class SerpentLook {
  const SerpentLook({required this.body, required this.belly, required this.fin, required this.eye, this.scale = 1, this.humps = 2, this.barbels = false});
  final Ramp body;
  final Color belly, fin, eye;
  final double scale;
  final int humps;

  /// Long whiskers trailing from the jaw (the Leviathan).
  final bool barbels;
}

const seaSerpents = <String, SerpentLook>{
  'seaSerpent': SerpentLook(body: [Color(0xFF6AC8B8), Color(0xFF2A7A80), Color(0xFF0E2E36)], belly: Color(0xFFE8E0B0), fin: Color(0xFFE06A4A), eye: Color(0xFFFFE07A)),
  'leviathan': SerpentLook(body: [Color(0xFF5A7AB0), Color(0xFF243A6A), Color(0xFF0A1028)], belly: Color(0xFFB8D8E8), fin: Color(0xFF8AE0F0), eye: Color(0xFFCFFFFF), scale: 1.45, humps: 3, barbels: true),
};

/// Great beasts drawn by their own painters rather than on the rig: the Kraken, the serpents and
/// the griffins.
bool isSeaLook(String look) => look == 'kraken' || seaSerpents.containsKey(look) || griffins.containsKey(look);

/// Height of such a beast at scale 1, for health bars and hit marks.
double seaHeight(String look) => look == 'kraken' ? krakenHeight : (griffins[look] != null ? griffinHeight * griffins[look]!.scale : 250 * (seaSerpents[look]?.scale ?? 1));

/// The Kraken or a serpent at [at] (the waterline), facing left.
void drawSeaBeast(Canvas c, String look, Offset at, double scale, double t, {double hit = 0, double dying = 0, double alpha = 1, ColorFilter? tint, bool still = false}) {
  final serpent = seaSerpents[look], griffin = griffins[look];
  if (griffin != null) {
    drawGriffin(c, griffin, at, scale, t, hit: hit, dying: dying, alpha: alpha, tint: tint, still: still);
  } else if (serpent == null) {
    drawKraken(c, at, scale, t, hit: hit, dying: dying, alpha: alpha, tint: tint, still: still);
  } else {
    drawSerpent(c, serpent, at, scale, t, hit: hit, dying: dying, alpha: alpha, tint: tint, still: still);
  }
}

/// A sea serpent rearing out of the water: humps of its coils behind, a long neck curving up and
/// over, and a finned, fanged head looking down at the hero. [dying] sinks it below the waves.
void drawSerpent(Canvas c, SerpentLook look, Offset at, double scale, double t, {double hit = 0, double dying = 0, double alpha = 1, ColorFilter? tint, bool still = false}) {
  final sway = still ? 0.0 : t / 650;
  double s(double k, [double a = 1]) => math.sin(sway * a + k);
  c.save();
  c.translate(at.dx + hit * 18, at.dy + dying * 280);
  c.scale(scale * look.scale, scale * look.scale);
  final layered = alpha < 1 || tint != null;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha)..colorFilter = tint);
  if (dying > 0) c.clipRect(const Rect.fromLTRB(-400, -600, 400, 8));
  final body = look.body, dark = [for (final x in body) shade(x, -.25)];

  // Churned water around it.
  c.drawOval(Rect.fromCenter(center: const Offset(40, 2), width: 300, height: 28), Paint()..color = const Color(0xCC0E2A36));
  c.drawOval(Rect.fromCenter(center: const Offset(40, 0), width: 260, height: 18), strokePaint(const Color(0x88CFEFF2), 2));

  // The coils, arching out of the water behind.
  for (var i = 0; i < look.humps; i++) {
    final x = 70.0 + i * 52, h = 54.0 - i * 10 + 6 * s(i * 1.3);
    drawTentacle(c, Offset(x, 4), Offset(x + 4, -h), Offset(x + 30, -h), Offset(x + 38, 4), 30 - i * 4, ramp: dark, suckers: false, taper: .15, belly: look.belly);
    // A fin on each hump.
    final top = Offset(x + 19, -h * .78);
    c.drawPath(poly([top + const Offset(-10, 0), top + const Offset(-2, -18), top + const Offset(8, -2)]), Paint()..color = look.fin.withValues(alpha: .85));
  }
  // The neck: up out of the water and curving over towards the hero.
  final neckTop = Offset(-44 + 10 * s(.5), -214 + 8 * s(1.2));
  drawTentacle(c, const Offset(30, 6), const Offset(60, -110), Offset(-70 + 8 * s(.8), -150), neckTop, 56, ramp: body, suckers: false, taper: .45, suckerSide: -1, belly: look.belly);
  // A crest of fins down the back of the neck.
  for (var i = 0; i < 6; i++) {
    final k = i / 6.0, p = Offset(30 + (neckTop.dx - 30) * k + 22 * math.sin(k * math.pi), 6 + (neckTop.dy - 6) * k);
    c.drawPath(poly([p + const Offset(4, 6), p + Offset(16 - k * 6, -10), p + const Offset(12, 14)]), Paint()..color = look.fin.withValues(alpha: .9));
  }

  // The head, looking down and left at the hero.
  c.save();
  c.translate(neckTop.dx, neckTop.dy);
  c.rotate(.35 + .05 * s(2));
  // Frill fins fanned behind the jaw.
  for (final (a, l) in const [(-.9, 34.0), (-.4, 40.0), (.1, 34.0)]) {
    final tip = Offset(math.cos(a) * l + 20, math.sin(a) * l - 6);
    c.drawPath(poly([const Offset(10, -8), tip, const Offset(18, 6)]), Paint()..color = look.fin);
    c.drawLine(const Offset(14, -2), tip, strokePaint(shade(look.fin, -.4), 1.2));
  }
  // Upper jaw and skull.
  final skull = Path()
    ..moveTo(26, -18)
    ..quadraticBezierTo(0, -30, -30, -18)
    ..quadraticBezierTo(-62, -8, -70, 2)
    ..lineTo(-26, 4)
    ..quadraticBezierTo(4, 10, 26, 10)
    ..close();
  fillPath(c, skull, body, const Offset(-70, -30), const Offset(26, 10), width: 1.6);
  // The open lower jaw.
  final jaw = Path()
    ..moveTo(18, 12)
    ..quadraticBezierTo(-10, 16, -56, 22)
    ..lineTo(-24, 8)
    ..close();
  fillPath(c, jaw, dark, const Offset(-56, 8), const Offset(18, 22), width: 1.4);
  c.drawPath(poly(const [Offset(-26, 5), Offset(-60, 6), Offset(-52, 18), Offset(-20, 10)]), Paint()..color = const Color(0xFF3A0A12));
  final tooth = Paint()..color = const Color(0xFFF6F0E0);
  for (var i = 0; i < 5; i++) {
    final x = -58.0 + i * 8;
    c.drawPath(poly([Offset(x, 4), Offset(x + 2, 11), Offset(x + 4, 4)]), tooth);
    c.drawPath(poly([Offset(x + 3, 19 - i * 1.5), Offset(x + 5, 12 - i * 1.5), Offset(x + 7, 18 - i * 1.5)]), tooth);
  }
  if (look.barbels) {
    for (final (dy, len) in const [(6.0, 60.0), (12.0, 46.0)]) {
      c.drawPath(Path()..moveTo(-60, dy)..quadraticBezierTo(-70, dy + 30, -60 + 10 * s(dy), dy + len), strokePaint(look.fin.withValues(alpha: .8), 2.4)..strokeCap = StrokeCap.round);
    }
  }
  // The eye: glowing, slit.
  final eye = const Offset(-18, -14);
  c.drawCircle(eye, 11, Paint()..color = look.eye.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  c.drawOval(Rect.fromCenter(center: eye, width: 14, height: 9), Paint()..color = look.eye);
  c.drawOval(Rect.fromCenter(center: eye, width: 3, height: 8), Paint()..color = const Color(0xFF0A0A10));
  c.drawPath(Path()..moveTo(-34, -22)..quadraticBezierTo(-18, -28, -4, -22), strokePaint(dark[2], 3));
  c.restore();

  // Foam where it breaks the surface.
  final foam = Paint()..color = const Color(0xCCEAF6F8);
  for (final x in const [10.0, 60.0, 110.0, 170.0]) {
    c.drawOval(Rect.fromCenter(center: Offset(x + (still ? 0 : 5 * math.sin(t / 300 + x)), -2), width: 34, height: 7), foam);
  }
  if (layered) c.restore();
  c.restore();
}
