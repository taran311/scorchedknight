// The rest of Cindervale's square, in the same night silhouette style as the inn: the signpost
// where the road leaves town, Mags' market stall, and your tent with its campfire. Drawn on the
// inn scene's 960 × 540 canvas, feet on the ground line at y 470.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

const _ink = Color(0xFF0A0807);
const _lamp = Color(0xFFFFB04A);
const _ground = 470.0;

/// The places you can go from the square, and where they sit. The forge and the hedge-mage's tower
/// stand further up the lane, behind the signpost and the stall.
enum TownSpot { gate, stall, inn, tent, forge, enchanter }

const townSpots = <TownSpot, Rect>{
  TownSpot.gate: Rect.fromLTWH(0, 352, 56, 123),
  TownSpot.stall: Rect.fromLTWH(96, 290, 232, 185),
  TownSpot.inn: Rect.fromLTWH(424, 150, 392, 325),
  TownSpot.tent: Rect.fromLTWH(828, 328, 132, 147),
  // The smithy up the lane, clear of the signpost now it stands at the very edge of the square.
  TownSpot.forge: Rect.fromLTWH(46, 214, 92, 216),
  TownSpot.enchanter: Rect.fromLTWH(318, 96, 100, 330),
};

/// A warm glow behind whatever the pointer is over: "you can go here".
void paintSpotGlow(Canvas c, TownSpot spot, double t) {
  final r = townSpots[spot]!, k = .8 + .2 * math.sin(t / 260);
  c.drawOval(r.inflate(10), Paint()..color = _lamp.withValues(alpha: .22 * k)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
}

/// The signpost at the edge of town, its arms pointing out along the road to the wilds.
void paintSignpost(Canvas c, double t) {
  final p = Paint()..color = _ink;
  // A slim post at the very edge of the square, so the forge behind it shows.
  c.drawRect(const Rect.fromLTWH(30, 372, 8, _ground - 372), p);
  // Two arms, both pointing out of town along the road.
  c.drawPath(poly(const [Offset(46, 382), Offset(4, 382), Offset(-6, 392), Offset(4, 402), Offset(46, 402)]), p);
  c.drawPath(poly(const [Offset(42, 410), Offset(8, 410), Offset(0, 418), Offset(8, 426), Offset(42, 426)]), p);
  // A lantern hung on the post, swaying a touch.
  final sway = math.sin(t / 700) * 2;
  final lamp = Offset(14 + sway, 448);
  c.drawLine(const Offset(30, 434), lamp + const Offset(0, -12), strokePaint(_ink, 2));
  paintLantern(c, lamp, t);
  // The road itself, a paler track leaving the square to the left.
  c.drawPath(
    Path()
      ..moveTo(0, 480)
      ..quadraticBezierTo(120, 470, 260, 492)
      ..lineTo(240, 540)
      ..lineTo(0, 540)
      ..close(),
    Paint()..color = const Color(0x22D8C8A8),
  );
}

/// Dunstan's forge, up the lane behind the signpost: a squat stone smithy with a great chimney
/// glowing at the mouth and spitting sparks, the forge's glow pulsing through its open front each
/// time the hammer falls, and an iron anvil hung out as its sign.
void paintForge(Canvas c, double t) {
  const stone = Color(0xFF15100D), roof = Color(0xFF0E0A08), hot = Color(0xFFFF8A2A);
  // The hammer: a beat every 1.3 seconds, the glow jumping with each blow.
  final beat = (t % 1300) / 1300, strike = math.max(0.0, 1 - beat * 5);
  final glow = .7 + .3 * math.sin(t / 130) * math.sin(t / 71) + .5 * strike;
  // Smoke from the chimney.
  for (var i = 0; i < 5; i++) {
    final p = ((t / 3000) + i / 5) % 1.0;
    c.drawCircle(Offset(90 + math.sin(t / 900 + i) * 6 + p * 40, 216 - p * 120), 6 + p * 18, Paint()..color = Color.fromRGBO(70, 60, 56, .35 * (1 - p))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }
  // The heat of the forge, lighting the lane.
  c.drawCircle(const Offset(74, 390), 110, Paint()..color = hot.withValues(alpha: .26 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34));
  // Walls and a low, sagging roof.
  c.drawRect(const Rect.fromLTRB(14, 326, 112, 432), Paint()..color = stone);
  for (var y = 340.0; y < 432; y += 13) {
    c.drawLine(Offset(14, y), Offset(112, y), strokePaint(const Color(0xFF0B0807), 1));
  }
  // The open front, the fire inside it.
  const mouth = Rect.fromLTRB(46, 360, 100, 432);
  c.drawRect(mouth, Paint()..shader = ui.Gradient.radial(const Offset(73, 420), 50, [Color.lerp(hot, const Color(0xFFFFE6A0), .4 * strike)!.withValues(alpha: .95), const Color(0xFF8A2A10), const Color(0xFF1A0A06)], const [0, .5, 1]));
  // The anvil inside, against the fire.
  c.drawPath(poly(const [Offset(58, 404), Offset(90, 404), Offset(84, 410), Offset(78, 410), Offset(80, 424), Offset(68, 424), Offset(70, 410), Offset(62, 410), Offset(52, 406)]), Paint()..color = const Color(0xFF0A0706));
  final roofPath = Path()
    ..moveTo(4, 334)
    ..lineTo(24, 304)
    ..quadraticBezierTo(66, 300, 106, 306)
    ..lineTo(122, 334)
    ..close();
  c.drawPath(roofPath, Paint()..color = roof);
  c.drawPath(roofPath, strokePaint(hot.withValues(alpha: .55 * glow), 1.6));
  // Firelight catching the walls' edges, so the smithy reads against the dark.
  c.drawRect(const Rect.fromLTRB(14, 326, 112, 432), strokePaint(hot.withValues(alpha: .35 * glow), 1.4));
  // The chimney: broad stone, glowing at the mouth.
  c.drawRect(const Rect.fromLTRB(78, 226, 104, 312), Paint()..color = stone);
  c.drawRect(const Rect.fromLTRB(74, 220, 108, 228), Paint()..color = roof);
  for (var y = 240.0; y < 310; y += 12) {
    c.drawLine(Offset(78, y), Offset(104, y), strokePaint(const Color(0xFF0B0807), 1));
  }
  c.drawOval(Rect.fromCenter(center: const Offset(91, 220), width: 30, height: 10), Paint()..color = hot.withValues(alpha: .55 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  // Sparks, thrown up with every blow.
  for (var i = 0; i < 10; i++) {
    final p = ((t / 1600) + i * .137) % 1.0;
    final at = Offset(91 + math.sin(i * 2.3 + t / 400) * 10 + p * 18, 218 - p * 90);
    c.drawCircle(at, 1.6 * (1 - p) + .5, Paint()..color = Color.fromRGBO(255, 190, 90, (1 - p) * .9));
  }
  // The sign: an iron anvil hung from a bracket off the chimney.
  c.drawLine(const Offset(78, 252), const Offset(36, 252), strokePaint(_ink, 2.6));
  c.drawLine(const Offset(42, 252), const Offset(42, 258), strokePaint(_ink, 1.4));
  c.drawLine(const Offset(62, 252), const Offset(62, 258), strokePaint(_ink, 1.4));
  final anvil = poly(const [Offset(32, 258), Offset(70, 258), Offset(64, 266), Offset(58, 266), Offset(60, 276), Offset(42, 276), Offset(44, 266), Offset(38, 266), Offset(28, 261)]);
  c.drawPath(anvil, Paint()..color = _ink);
  c.drawPath(anvil, strokePaint(hot.withValues(alpha: .5 * glow), 1.2));
}

/// Old Wick's tower, up the lane between the stall and the inn: a narrow, leaning stone tower in a
/// crooked pointed hat, a round window glowing violet, and little lights drifting round its tip.
void paintEnchanterTower(Canvas c, double t) {
  const stone = Color(0xFF14111A), hat = Color(0xFF0E0B14), violet = Color(0xFFB88AFF);
  final pulse = .75 + .25 * math.sin(t / 600);
  // A little taller than the stall, so it stands out between the stall and the inn.
  c.save();
  c.translate(366, 432);
  c.scale(1.15);
  c.translate(-366, -432);
  c.drawCircle(const Offset(366, 256), 70, Paint()..color = violet.withValues(alpha: .24 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));
  // The body, leaning a little, wider at the foot.
  final body = Path()
    ..moveTo(338, 432)
    ..quadraticBezierTo(342, 320, 348, 218)
    ..lineTo(386, 214)
    ..quadraticBezierTo(388, 320, 396, 432)
    ..close();
  c.drawPath(body, Paint()..color = stone);
  c.save();
  c.clipPath(body);
  for (var y = 226.0; y < 432; y += 14) {
    c.drawLine(Offset(330, y), Offset(400, y - 2), strokePaint(const Color(0xFF0A080E), 1));
  }
  c.restore();
  c.drawPath(body, strokePaint(violet.withValues(alpha: .4), 1.4));
  // A little balcony and its rail.
  c.drawRect(const Rect.fromLTRB(340, 300, 394, 305), Paint()..color = hat);
  for (var x = 344.0; x < 392; x += 8) {
    c.drawLine(Offset(x, 300), Offset(x, 290), strokePaint(hat, 1.6));
  }
  c.drawLine(const Offset(342, 290), const Offset(392, 290), strokePaint(hat, 1.8));
  // The round window, lit from inside, and a slit lower down.
  const win = Offset(367, 254);
  c.drawCircle(win, 16, Paint()..color = violet.withValues(alpha: .4 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
  c.drawCircle(win, 9, Paint()..color = Color.lerp(violet, const Color(0xFFF0E0FF), .45 * pulse)!);
  c.drawLine(win + const Offset(-9, 0), win + const Offset(9, 0), strokePaint(stone, 1.6));
  c.drawLine(win + const Offset(0, -9), win + const Offset(0, 9), strokePaint(stone, 1.6));
  c.drawCircle(win, 9, strokePaint(stone, 2));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(363, 330, 7, 18), const Radius.circular(3)), Paint()..color = violet.withValues(alpha: .7 * pulse));
  // The hat: a tall crooked cone with a bent tip, and a brim.
  final roof = Path()
    ..moveTo(332, 222)
    ..quadraticBezierTo(360, 206, 400, 218)
    ..lineTo(386, 190)
    ..quadraticBezierTo(380, 160, 382, 140)
    ..quadraticBezierTo(392, 128, 404, 132)
    ..quadraticBezierTo(390, 138, 388, 146)
    ..quadraticBezierTo(366, 170, 352, 196)
    ..close();
  c.drawPath(roof, Paint()..color = hat);
  c.drawPath(roof, strokePaint(violet.withValues(alpha: .25), 1.2));
  // A star on a wire at the tip.
  final tip = const Offset(404, 128) + Offset(0, math.sin(t / 500) * 1.5);
  c.drawCircle(tip, 7, Paint()..color = violet.withValues(alpha: .5 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  c.drawCircle(tip, 2.4, Paint()..color = const Color(0xFFF4ECFF));
  // Little lights drifting round the tower's top.
  for (var i = 0; i < 6; i++) {
    final a = t / 1400 + i * math.pi / 3;
    final at = Offset(368 + math.cos(a) * (30 + (i % 2) * 8), 196 + math.sin(a) * 10 - (i % 3) * 14 + math.sin(t / 300 + i) * 3);
    final front = math.sin(a) > -.3;
    c.drawCircle(at, front ? 2.2 : 1.4, Paint()..color = (i.isEven ? violet : const Color(0xFF9CF6E6)).withValues(alpha: front ? .9 : .4));
  }
  c.restore();
}

/// Mags' stall: a striped awning on carved poles, a lit green backcloth with a shelf of jars,
/// herbs drying along the front beam, a counter draped in her colours and crowded with glowing
/// bottles, and crates and a sack beside it. [drawMags] draws her figure (so it can use the hero
/// rig).
void paintStall(Canvas c, double t, void Function(Canvas) drawMags) {
  const wood = Color(0xFF241810), woodLit = Color(0xFF3E2A1C);
  // The lantern's warmth, filling the stall.
  c.drawCircle(const Offset(206, 372), 120, Paint()..color = _lamp.withValues(alpha: .2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34));

  // Back poles and the backcloth hung between them, lit from the front.
  c.drawRect(const Rect.fromLTWH(124, 316, 7, _ground - 316), Paint()..color = wood);
  c.drawRect(const Rect.fromLTWH(281, 316, 7, _ground - 316), Paint()..color = wood);
  const cloth = Rect.fromLTRB(131, 318, 281, 418);
  c.drawRect(cloth, Paint()..shader = ui.Gradient.radial(const Offset(196, 360), 110, const [Color(0xFF3A5A36), Color(0xFF1A2A1A), Color(0xFF0E160E)], const [0, .55, 1]));
  for (var x = cloth.left + 14; x < cloth.right; x += 19) {
    c.drawLine(Offset(x, cloth.top), Offset(x + 2, cloth.bottom), strokePaint(const Color(0x40000000), 4));
  }
  // A shelf on the backcloth, lined with jars and bundles.
  c.drawRect(const Rect.fromLTWH(136, 352, 140, 5), Paint()..color = woodLit);
  final r = SeededRandom(5);
  for (var x = 140.0; x < 270; x += 13 + r.next() * 4) {
    final h = 10 + r.next() * 9, w = 8 + r.next() * 3;
    final col = [const Color(0xFF8A5A2A), const Color(0xFF4A6A3A), const Color(0xFF6A3A5A), const Color(0xFF7A6A3A)][(x ~/ 13) % 4];
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 352 - h, w, h), const Radius.circular(2)), Paint()..color = col.withValues(alpha: .75));
    c.drawRect(Rect.fromLTWH(x - .5, 352 - h - 2, w + 1, 3), Paint()..color = woodLit);
  }

  // Mags, behind the counter.
  drawMags(c);

  // The counter: planks, a lit top board, and a cloth draped over the front in her colours.
  const front = Rect.fromLTRB(118, 418, 294, _ground);
  c.drawRect(front, Paint()..color = wood);
  for (var y = front.top + 12; y < front.bottom; y += 12) {
    c.drawLine(Offset(front.left, y), Offset(front.right, y), strokePaint(const Color(0xFF140E0A), 1.2));
  }
  c.drawRect(const Rect.fromLTRB(110, 410, 302, 419), Paint()..color = woodLit);
  c.drawLine(const Offset(110, 410), const Offset(302, 410), strokePaint(const Color(0x66FFD8A0), 1.2));
  final drape = Path()..moveTo(146, 419);
  drape.lineTo(266, 419);
  drape.lineTo(266, 446);
  for (var i = 6; i >= 0; i--) {
    final x = 146 + i * 20.0;
    drape.quadraticBezierTo(x + 10, 456, x, 446);
  }
  drape.close();
  c.drawPath(drape, Paint()..shader = ui.Gradient.linear(const Offset(0, 419), const Offset(0, 456), const [Color(0xFF7A2418), Color(0xFF4A140E)]));
  c.drawPath(drape, strokePaint(const Color(0xFFC9A24E), 1.6));
  // Her mark on the drape: a little gold flask.
  const m = Offset(206, 432);
  final gold = Paint()..color = const Color(0xFFE0B860);
  c.drawCircle(m + const Offset(0, 3), 6, gold);
  c.drawRect(Rect.fromCenter(center: m + const Offset(0, -5), width: 4, height: 6), gold);

  // The wares: glowing bottles, jars and pouches along the top board.
  const wares = [
    (126.0, 0, 'flask'), (140.0, 2, 'tall'), (152.0, 1, 'vial'), (166.0, 3, 'jar'), (182.0, 0, 'pouch'), //
    (228.0, 1, 'flask'), (242.0, 2, 'vial'), (254.0, 0, 'tall'), (268.0, 3, 'flask'), (284.0, 1, 'jar'),
  ];
  const colours = [Color(0xFFD8402E), Color(0xFF6ABF4A), Color(0xFF4A82E0), Color(0xFFE8B048)];
  for (final (x, ci, kind) in wares) {
    _bottle(c, Offset(x, 410), kind, colours[ci], t);
  }

  // Poles at the front, carved and capped.
  for (final x in const [110.0, 294.0]) {
    c.drawRect(Rect.fromLTWH(x, 308, 8, _ground - 308), Paint()..color = wood);
    c.drawRect(Rect.fromLTWH(x, 308, 2, _ground - 308), Paint()..color = const Color(0x33FFD8A0));
    c.drawRect(Rect.fromLTWH(x - 2, 404, 12, 6), Paint()..color = woodLit);
  }

  // The awning: red and cream stripes, sagging a little, with a scalloped, tasselled valance.
  const top = 296.0, edge = 322.0;
  final awning = Path()
    ..moveTo(96, edge)
    ..lineTo(122, top)
    ..lineTo(290, top)
    ..lineTo(316, edge)
    ..quadraticBezierTo(206, edge + 6, 96, edge)
    ..close();
  c.save();
  c.clipPath(awning);
  for (var i = 0; i < 10; i++) {
    c.drawRect(Rect.fromLTWH(96 + i * 22.0, top, 22, edge - top + 8), Paint()..color = i.isEven ? const Color(0xFF8A2A1C) : const Color(0xFFC8B088));
  }
  c.drawRect(const Rect.fromLTRB(96, top, 316, edge + 8), Paint()..shader = ui.Gradient.linear(const Offset(0, top), const Offset(0, edge + 6), [const Color(0x99000000), const Color(0x11000000)]));
  c.restore();
  for (var i = 0; i < 10; i++) {
    final x = 96 + i * 22.0, sag = 6 * math.sin((i + .5) / 10 * math.pi);
    c.drawArc(Rect.fromLTWH(x, edge - 9 + sag, 22, 18), 0, math.pi, true, Paint()..color = i.isEven ? const Color(0xFF6A1E14) : const Color(0xFF9A8460));
    // A tassel at each point.
    final tip = Offset(x, edge + sag);
    c.drawLine(tip, tip + const Offset(0, 6), strokePaint(const Color(0xFFC9A24E), 1.4));
    c.drawCircle(tip + const Offset(0, 7), 1.6, Paint()..color = const Color(0xFFC9A24E));
  }
  c.drawPath(awning, strokePaint(_ink, 2.5));
  c.drawLine(const Offset(122, top), const Offset(290, top), strokePaint(const Color(0x55FFD8A0), 1.2));

  // Herbs and garlic drying from the front beam.
  for (final (x, len, col) in const [(172.0, 20.0, Color(0xFF4A5A2A)), (186.0, 14.0, Color(0xFFD8CCA8)), (248.0, 18.0, Color(0xFF5A4A2A)), (262.0, 22.0, Color(0xFF4A5A2A))]) {
    final sway = math.sin(t / 900 + x) * 1.2;
    c.drawLine(Offset(x, edge + 3), Offset(x + sway, edge + 10), strokePaint(_ink, 1));
    c.drawPath(
      Path()
        ..moveTo(x + sway - 4, edge + 10)
        ..quadraticBezierTo(x + sway - 5, edge + 10 + len * .6, x + sway, edge + 10 + len)
        ..quadraticBezierTo(x + sway + 5, edge + 10 + len * .6, x + sway + 4, edge + 10)
        ..close(),
      Paint()..color = col,
    );
  }

  // A hanging lantern at the front.
  final lamp = Offset(146 + math.sin(t / 650) * 1.5, 342);
  c.drawLine(const Offset(146, edge + 4), lamp + const Offset(0, -12), strokePaint(_ink, 2));
  paintLantern(c, lamp, t);

  // Crates, a sack and a barrel beside the stall.
  const crate = Rect.fromLTWH(74, _ground - 30, 32, 30);
  c.drawRect(crate, Paint()..color = wood);
  c.drawLine(crate.topLeft, crate.bottomRight, strokePaint(woodLit, 3));
  c.drawRect(crate, strokePaint(_ink, 1.6));
  c.drawRect(Rect.fromLTWH(crate.left + 4, crate.top - 22, 24, 22), Paint()..color = wood);
  c.drawRect(Rect.fromLTWH(crate.left + 4, crate.top - 22, 24, 22), strokePaint(_ink, 1.6));
  final sack = Path()
    ..moveTo(98, _ground)
    ..quadraticBezierTo(92, _ground - 30, 104, _ground - 36)
    ..lineTo(110, _ground - 40)
    ..lineTo(114, _ground - 34)
    ..quadraticBezierTo(124, _ground - 26, 118, _ground)
    ..close();
  c.drawPath(sack, Paint()..color = const Color(0xFF3A2E20));
  c.drawPath(sack, strokePaint(_ink, 1.4));
  c.drawLine(const Offset(103, _ground - 33), const Offset(115, _ground - 33), strokePaint(const Color(0xFF8A6A3A), 1.6));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(302, _ground - 34, 24, 34), const Radius.circular(6)), Paint()..color = wood);
  for (final y in const [_ground - 27.0, _ground - 8]) {
    c.drawLine(Offset(304, y), Offset(324, y), strokePaint(const Color(0xFF4A3A2A), 2));
  }
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(302, _ground - 34, 24, 34), const Radius.circular(6)), strokePaint(_ink, 1.4));
}

/// One of Mags' wares, standing on [base]: a round flask, a tall bottle, a little vial, a jar or a
/// pouch, glass ones glowing faintly with what's inside.
void _bottle(Canvas c, Offset base, String kind, Color col, double t) {
  final glow = .7 + .3 * math.sin(t / 600 + base.dx);
  final outline = strokePaint(_ink, 1.3);
  switch (kind) {
    case 'pouch':
      final p = Path()
        ..moveTo(base.dx - 7, base.dy)
        ..quadraticBezierTo(base.dx - 9, base.dy - 10, base.dx - 3, base.dy - 12)
        ..lineTo(base.dx + 3, base.dy - 12)
        ..quadraticBezierTo(base.dx + 9, base.dy - 10, base.dx + 7, base.dy)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0xFF6A4A2A));
      c.drawPath(p, outline);
      c.drawLine(base + const Offset(-3, -10), base + const Offset(3, -10), strokePaint(const Color(0xFFC9A24E), 1.2));
      return;
    case 'jar':
      final j = RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - 6, base.dy - 12, 12, 12), const Radius.circular(3));
      c.drawRRect(j, Paint()..color = Color.lerp(col, const Color(0xFF2A1C14), .4)!);
      c.drawRect(Rect.fromLTWH(base.dx - 7, base.dy - 15, 14, 4), Paint()..color = const Color(0xFF8A6A4A));
      c.drawRRect(j, outline);
      return;
  }
  final (body, neck) = switch (kind) {
    'tall' => (Rect.fromLTWH(base.dx - 4.5, base.dy - 16, 9, 16), 7.0),
    'vial' => (Rect.fromLTWH(base.dx - 3, base.dy - 9, 6, 9), 4.0),
    _ => (Rect.fromCircle(center: base + const Offset(0, -7.5), radius: 7.5), 5.0),
  };
  c.drawCircle(body.center, body.width * .9, Paint()..color = col.withValues(alpha: .28 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  // Neck and cork.
  c.drawRect(Rect.fromLTWH(base.dx - 2, body.top - neck, 4, neck + 1), Paint()..color = const Color(0xFF9AB0B8).withValues(alpha: .6));
  c.drawRect(Rect.fromLTWH(base.dx - 2.5, body.top - neck - 3, 5, 3.5), Paint()..color = const Color(0xFF8A6040));
  final shape = kind == 'flask' ? (Path()..addOval(body)) : (Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(2.5))));
  c.drawPath(shape, Paint()..shader = ui.Gradient.linear(body.topCenter, body.bottomCenter, [Color.lerp(col, const Color(0xFFFFFFFF), .35)!, col, Color.lerp(col, const Color(0xFF000000), .35)!], const [0, .45, 1]));
  // A glint on the glass.
  c.drawLine(body.topLeft + Offset(body.width * .28, body.height * .25), body.topLeft + Offset(body.width * .28, body.height * .55), strokePaint(const Color(0xCCFFFFFF), 1.2)..strokeCap = StrokeCap.round);
  c.drawPath(shape, outline);
}

/// Your home on the right of the square: the tent, then a cottage, then a keep.
void paintHome(Canvas c, double t, int home) => switch (home) {
  0 => paintTent(c, t),
  1 => _cottage(c, t),
  _ => _keep(c, t),
};

/// A cottage: stone below, a thick thatch above, a lit window with a flower box, a chimney with
/// smoke, and the herb garden out front.
void _cottage(Canvas c, double t) {
  const stone = Color(0xFF16110E), thatch = Color(0xFF1E1610);
  // Chimney smoke.
  for (var i = 0; i < 5; i++) {
    final p = ((t / 3600) + i / 5) % 1.0;
    c.drawCircle(Offset(930 + math.sin(t / 900 + i) * 5 + p * 30, 300 - p * 110), 5 + p * 14, Paint()..color = Color.fromRGBO(120, 112, 104, .3 * (1 - p))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
  c.drawRect(const Rect.fromLTWH(920, 302, 18, 50), Paint()..color = stone);
  // Walls.
  const wall = Rect.fromLTRB(846, 384, 958, _ground);
  c.drawRect(wall, Paint()..color = stone);
  for (var y = wall.top + 14; y < wall.bottom; y += 14) {
    c.drawLine(Offset(wall.left, y), Offset(wall.right, y), strokePaint(const Color(0xFF0C0908), 1));
  }
  // The thatch, thick and rounded.
  final roof = Path()
    ..moveTo(834, 392)
    ..quadraticBezierTo(836, 380, 852, 372)
    ..lineTo(898, 326)
    ..quadraticBezierTo(904, 320, 910, 326)
    ..lineTo(956, 372)
    ..quadraticBezierTo(972, 380, 970, 392)
    ..close();
  c.drawPath(roof, Paint()..color = thatch);
  for (var i = 1; i < 5; i++) {
    final y = 392 - i * 13.0, half = 66 - i * 12.0;
    c.drawLine(Offset(904 - half, y), Offset(904 + half, y), strokePaint(const Color(0xFF2A2016), 1.2));
  }
  c.drawPath(roof, strokePaint(const Color(0x33FFB04A), 1.2));
  // Door and a lit window with a flower box.
  c.drawRRect(RRect.fromRectAndCorners(const Rect.fromLTWH(860, 418, 24, 52), topLeft: const Radius.circular(12), topRight: const Radius.circular(12)), Paint()..color = const Color(0xFF2A1C12));
  const win = Rect.fromLTWH(906, 404, 32, 28);
  c.drawCircle(win.center, 40, Paint()..color = _lamp.withValues(alpha: .2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  c.drawRect(win, Paint()..color = const Color(0xFFFFC870));
  c.drawLine(win.topCenter, win.bottomCenter, strokePaint(stone, 2.5));
  c.drawLine(win.centerLeft, win.centerRight, strokePaint(stone, 2.5));
  c.drawRect(win, strokePaint(stone, 3));
  c.drawRect(Rect.fromLTWH(win.left - 3, win.bottom, win.width + 6, 7), Paint()..color = const Color(0xFF3A2416));
  for (var i = 0; i < 5; i++) {
    c.drawCircle(Offset(win.left + 2 + i * 7.0, win.bottom - 1), 2.6, Paint()..color = i.isEven ? const Color(0xFFD8503A) : const Color(0xFFE8C04A));
  }
  // The herb garden: a row of green under the window.
  for (var i = 0; i < 6; i++) {
    final x = 900.0 + i * 9;
    c.drawPath(
      Path()
        ..moveTo(x - 4, _ground)
        ..quadraticBezierTo(x - 3, _ground - 12, x, _ground - 14 - (i % 2) * 4)
        ..quadraticBezierTo(x + 3, _ground - 12, x + 4, _ground)
        ..close(),
      Paint()..color = const Color(0xFF3A5A2A),
    );
  }
}

/// A small keep: a square tower with battlements and your banner, a curtain wall and a gate.
void _keep(Canvas c, double t) {
  const stone = Color(0xFF17120F), lip = Color(0x30FFB04A);
  // Curtain wall with crenels.
  c.drawRect(const Rect.fromLTRB(818, 410, 960, _ground), Paint()..color = stone);
  for (var x = 818.0; x < 960; x += 14) {
    c.drawRect(Rect.fromLTWH(x, 400, 8, 12), Paint()..color = stone);
  }
  // The tower.
  const tower = Rect.fromLTRB(866, 260, 940, _ground);
  c.drawRect(tower, Paint()..color = stone);
  for (var y = tower.top + 16; y < tower.bottom; y += 16) {
    c.drawLine(Offset(tower.left, y), Offset(tower.right, y), strokePaint(const Color(0xFF0C0908), 1));
  }
  for (var x = tower.left - 4; x < tower.right + 4; x += 15) {
    c.drawRect(Rect.fromLTWH(x, tower.top - 14, 10, 15), Paint()..color = stone);
  }
  c.drawLine(tower.topLeft, tower.bottomLeft, strokePaint(lip, 1.4));
  // Arrow slits and a lit window high up.
  for (final y in const [300.0, 360.0]) {
    c.drawRect(Rect.fromLTWH(900, y, 5, 18), Paint()..color = const Color(0xFF050404));
  }
  const win = Rect.fromLTWH(892, 278, 20, 16);
  c.drawCircle(win.center, 26, Paint()..color = _lamp.withValues(alpha: .22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  c.drawRRect(RRect.fromRectAndCorners(win, topLeft: const Radius.circular(8), topRight: const Radius.circular(8)), Paint()..color = const Color(0xFFFFC870));
  // The banner: your flame on red, rippling.
  c.drawRect(const Rect.fromLTWH(901, 200, 3, 46), Paint()..color = stone);
  final wave = math.sin(t / 280) * 3;
  c.drawPath(
    Path()
      ..moveTo(904, 204)
      ..quadraticBezierTo(920, 200 + wave, 940, 206)
      ..lineTo(936, 216)
      ..lineTo(940, 226)
      ..quadraticBezierTo(920, 222 - wave, 904, 226)
      ..close(),
    Paint()..color = const Color(0xFF8E2117),
  );
  c.drawCircle(Offset(918, 215 + wave * .3), 3, Paint()..color = const Color(0xFFFFB04A));
  // The gate, with torches either side.
  final gate = Path()
    ..moveTo(830, _ground)
    ..lineTo(830, 438)
    ..arcToPoint(const Offset(858, 438), radius: const Radius.circular(14))
    ..lineTo(858, _ground)
    ..close();
  c.drawPath(gate, Paint()..color = const Color(0xFF241810));
  for (var x = 834.0; x < 858; x += 6) {
    c.drawLine(Offset(x, 432), Offset(x, _ground), strokePaint(const Color(0xFF120C08), 1.5));
  }
  for (final x in const [824.0, 864.0]) {
    final f = .8 + .2 * math.sin(t / 90 + x);
    c.drawCircle(Offset(x, 428), 12 * f, Paint()..color = const Color(0xFFFF8A3A).withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawPath(
      Path()
        ..moveTo(x - 3, 432)
        ..quadraticBezierTo(x - 3, 426, x + math.sin(t / 70 + x), 420 - 3 * f)
        ..quadraticBezierTo(x + 3, 426, x + 3, 432)
        ..close(),
      Paint()..color = const Color(0xFFFFC060),
    );
  }
}

void _campfire(Canvas c, double t, Offset at) {
  final f = .85 + .15 * math.sin(t / 120);
  c.drawCircle(at + const Offset(0, -10), 30 * f, Paint()..color = const Color(0xFFFF8A3A).withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  for (var i = 0; i < 3; i++) {
    final dx = (i - 1) * 6.0, h = (16 + i % 2 * 6) * f;
    c.drawPath(
      Path()
        ..moveTo(at.dx + dx - 5, at.dy)
        ..quadraticBezierTo(at.dx + dx - 4, at.dy - h * .6, at.dx + dx + math.sin(t / 90 + i) * 2, at.dy - h)
        ..quadraticBezierTo(at.dx + dx + 4, at.dy - h * .6, at.dx + dx + 5, at.dy)
        ..close(),
      Paint()..shader = ui.Gradient.linear(at, at + Offset(0, -h), [const Color(0xFFFFE08A), const Color(0xFFFF6A1A)]),
    );
  }
  c.drawLine(at + const Offset(-12, 2), at + const Offset(12, -2), strokePaint(_ink, 4));
  c.drawLine(at + const Offset(-12, -2), at + const Offset(12, 2), strokePaint(_ink, 4));
}

/// Your tent: a canvas A-frame with your crest on a pennant, and a little campfire in front.
void paintTent(Canvas c, double t, {bool fire = true}) {
  final p = Paint()..color = _ink;
  // Pennant pole and flag (the hero's flame on red).
  c.drawRect(const Rect.fromLTWH(896, 322, 4, 50), p);
  final wave = math.sin(t / 300) * 3;
  c.drawPath(poly([const Offset(900, 324), Offset(930, 330 + wave), const Offset(900, 342)]), Paint()..color = const Color(0xFF8E2117));
  // The tent: dark canvas with a lit seam where the flap is open.
  final tent = Path()
    ..moveTo(836, _ground)
    ..lineTo(898, 368)
    ..lineTo(958, _ground)
    ..close();
  c.drawPath(tent, Paint()..shader = ui.Gradient.linear(const Offset(836, 0), const Offset(958, 0), const [Color(0xFF1E1610), Color(0xFF120D0A)]));
  // Seams down the canvas, catching the firelight.
  for (final f in const [.3, .7]) {
    c.drawLine(const Offset(898, 368), Offset(836 + 122 * f, _ground), strokePaint(const Color(0x22FFB04A), 1.2));
  }
  c.drawPath(tent, strokePaint(_ink, 2));
  c.drawPath(
    Path()
      ..moveTo(898, 378)
      ..lineTo(880, _ground)
      ..lineTo(912, _ground)
      ..close(),
    Paint()..shader = ui.Gradient.linear(const Offset(898, 378), const Offset(898, _ground), [const Color(0x00FFB04A), const Color(0xAAFFB04A)]),
  );
  c.drawLine(const Offset(898, 368), const Offset(880, _ground), strokePaint(const Color(0xFF2A1C14), 2));
  // Your spare shield, leaning by the flap.
  c.drawOval(const Rect.fromLTWH(918, 436, 26, 32), Paint()..color = const Color(0xFF5A1A14));
  c.drawOval(const Rect.fromLTWH(918, 436, 26, 32), strokePaint(const Color(0xFF8A7A5A), 2));
  c.drawLine(const Offset(931, 440), const Offset(931, 464), strokePaint(const Color(0xFF8A7A5A), 1.6));
  // Guy ropes.
  c.drawLine(const Offset(850, 446), const Offset(828, _ground), strokePaint(_ink, 1.6));
  // The campfire.
  if (fire) _campfire(c, t, const Offset(866, _ground + 14));
}

/// A hanging iron lantern centred on [at]: a ring and a little peaked roof, a dark cage, warm
/// glass with a flickering flame inside, and the glow it throws.
void paintLantern(Canvas c, Offset at, double t, {double size = 1}) {
  final f = .88 + .12 * math.sin(t / 110 + at.dx);
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(size);
  // The glow.
  c.drawCircle(Offset.zero, 26, Paint()..color = _lamp.withValues(alpha: .26 * f)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  // The glass, lit from the flame.
  const glass = Rect.fromLTRB(-5.5, -7, 5.5, 7);
  c.drawRRect(RRect.fromRectAndRadius(glass, const Radius.circular(2)), Paint()..shader = ui.Gradient.radial(const Offset(0, 1), 9, [const Color(0xFFFFF0B0), const Color(0xFFFFB04A), const Color(0xFFB0581A)], const [0, .5, 1]));
  // The flame.
  c.drawPath(
    Path()
      ..moveTo(0, 4)
      ..quadraticBezierTo(-3, 1, 0, -4 * f)
      ..quadraticBezierTo(3, 1, 0, 4)
      ..close(),
    Paint()..color = const Color(0xFFFFFFE0),
  );
  // The cage: a frame round the glass with a bar down the middle, a roof and a base.
  final iron = strokePaint(_ink, 1.6);
  c.drawRRect(RRect.fromRectAndRadius(glass, const Radius.circular(2)), iron);
  c.drawLine(const Offset(0, -7), const Offset(0, 7), strokePaint(_ink, 1));
  c.drawPath(poly(const [Offset(-8, -7), Offset(0, -13), Offset(8, -7)]), Paint()..color = _ink);
  c.drawRect(const Rect.fromLTRB(-7, 7, 7, 10), Paint()..color = _ink);
  c.drawCircle(const Offset(0, -15), 2.4, strokePaint(_ink, 1.6));
  c.restore();
}

/// Hallowash in the square: grinning pumpkins on doorsteps and counters, and bats over the roofs.
void paintHallowash(Canvas c, double t) {
  for (final (at, size) in const [(Offset(586, 466), 1.0), (Offset(656, 466), .85), (Offset(290, 408), .7), (Offset(72, 468), .9), (Offset(828, 468), .8), (Offset(742, 404), .6)]) {
    _jack(c, at, size, t);
  }
  // Bats, flitting about the chimney and the moon.
  for (var i = 0; i < 5; i++) {
    final a = t / (1400 + i * 230) + i * 1.3;
    final at = Offset(760 + math.cos(a) * (80 + i * 18), 120 + math.sin(a * 1.7) * (30 + i * 6));
    final flap = math.sin(t / 70 + i * 2) * 5;
    final p = Path()
      ..moveTo(at.dx - 9, at.dy - flap)
      ..quadraticBezierTo(at.dx - 5, at.dy - 2, at.dx - 2, at.dy + 1)
      ..lineTo(at.dx, at.dy - 2)
      ..lineTo(at.dx + 2, at.dy + 1)
      ..quadraticBezierTo(at.dx + 5, at.dy - 2, at.dx + 9, at.dy - flap)
      ..quadraticBezierTo(at.dx + 4, at.dy + 3, at.dx, at.dy + 3)
      ..quadraticBezierTo(at.dx - 4, at.dy + 3, at.dx - 9, at.dy - flap)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFF0A0607));
  }
}

/// A carved pumpkin sitting on the ground at [at] (its base), lit from inside.
void _jack(Canvas c, Offset at, double size, double t) {
  final f = .75 + .25 * math.sin(t / 80 + at.dx) * math.sin(t / 47);
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(size);
  c.drawCircle(const Offset(0, -9), 22, Paint()..color = const Color(0xFFFF8A1A).withValues(alpha: .28 * f)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  for (final (dx, col) in const [(-6.0, Color(0xFFB0581A)), (6.0, Color(0xFFB0581A)), (0.0, Color(0xFFD06A1E))]) {
    c.drawOval(Rect.fromCenter(center: Offset(dx, -9), width: 16, height: 18), Paint()..color = col);
  }
  c.drawOval(Rect.fromCenter(center: const Offset(0, -9), width: 28, height: 18), strokePaint(_ink, 1.2));
  c.drawRect(const Rect.fromLTWH(-1.5, -21, 3, 4), Paint()..color = const Color(0xFF3A4A20));
  final lit = Paint()..color = Color.lerp(const Color(0xFFFF9A2A), const Color(0xFFFFE07A), f)!;
  c.drawPath(poly(const [Offset(-8, -11), Offset(-3, -11), Offset(-5.5, -15)]), lit);
  c.drawPath(poly(const [Offset(3, -11), Offset(8, -11), Offset(5.5, -15)]), lit);
  c.drawPath(poly(const [Offset(-8, -7), Offset(-5, -5), Offset(-2, -7), Offset(1, -4), Offset(4, -7), Offset(8, -7), Offset(4, -2), Offset(-4, -2)]), lit);
  c.restore();
}
