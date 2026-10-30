// The Soot & Kettle in the silhouette style: a big two-storey inn against the night, timber-framed
// over a stone ground floor, its windows the warmest thing for miles. Until Hob's job is done it's
// a smouldering shell, fire still in its bones.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';
import 'scenery.dart' show sceneSize;
import 'town_props.dart' show paintLantern;

const _night = Color(0xFF0A0807);
const _lamp = Color(0xFFFFB04A);
const _ground = 470.0;

// The inn's footprint and storeys.
const _left = 430.0, _right = 810.0, _jetty = 298.0, _eaves = 190.0, _ridge = 96.0;

// Its materials: near-black, but each a touch different so the shapes read.
const _stone = Color(0xFF16110E), _plaster = Color(0xFF130F0D), _timber = Color(0xFF221812), _roof = Color(0xFF100C0A);

/// The sky over the square: night; the brown, ash-choked day the Burning left behind; or (once
/// Vharrax is gone) a clear blue one.
enum InnSky { night, ashDay, clearDay }

/// The light that rims the hero standing outside: firelight, moonlight, or the day.
Color innRim(bool repaired, [InnSky sky = InnSky.night]) => switch (sky) {
  InnSky.ashDay => const Color(0xFFF0C890),
  InnSky.clearDay => const Color(0xFFFFF4DC),
  InnSky.night => repaired ? const Color(0xFFCFE0F2) : const Color(0xFFFF9A50),
};

/// Paints the inn scene (960 x 540) at time [t] (ms).
/// [fence] draws the paddock fence on the left (the town square puts Mags' stall there instead).
void paintSilhouetteInn(Canvas c, bool repaired, double t, {bool fence = true, InnSky time = InnSky.night}) {
  final r = SeededRandom(7);
  final night = time == InnSky.night;
  // ---- Sky ----
  final sky = switch (time) {
    InnSky.ashDay => const [Color(0xFF3E3630), Color(0xFF7A6450), Color(0xFFC09868)],
    InnSky.clearDay => const [Color(0xFF3A74BC), Color(0xFF78ACD8), Color(0xFFD8E6EC)],
    InnSky.night => repaired ? const [Color(0xFF070A18), Color(0xFF16203C), Color(0xFF3A4462)] : const [Color(0xFF0A0710), Color(0xFF2A1218), Color(0xFF8A3A1E)],
  };
  c.drawRect(Offset.zero & sceneSize, Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, _ground), sky, const [0, .55, 1]));
  if (!night) {
    _daySky(c, time, t);
  } else {
    _nightSky(c, r, repaired, t);
  }
  if (!repaired) {
    // The glow of fires still burning beyond the hills.
    c.drawRect(const Rect.fromLTWH(0, 300, 960, 170), Paint()..shader = ui.Gradient.linear(const Offset(0, 300), const Offset(0, 470), [const Color(0x00FF6A2A), const Color(0x59FF6A2A)]));
  }

  // ---- Far: hills, the broken towers of a burnt town, and a ruined keep ----
  Color layer(double k) => Color.lerp(sky.last, _night, k)!;
  final far = Paint()..color = layer(.5);
  final hills = Path()..moveTo(0, 540);
  for (var x = 0.0; x <= 960; x += 8) {
    hills.lineTo(x, 360 - math.sin(x / 140) * 18 - math.sin(x / 53 + 1) * 7 - math.max(0, (x - 820) * .25));
  }
  c.drawPath(
    hills
      ..lineTo(960, 540)
      ..close(),
    far,
  );
  for (final (x, h, w) in const [(90.0, 70.0, 22.0), (130.0, 46.0, 16.0), (200.0, 58.0, 18.0), (250.0, 30.0, 26.0)]) {
    c.drawRect(Rect.fromLTWH(x, 352 - h, w, h + 10), far);
    c.drawPath(poly([Offset(x - 2, 352 - h), Offset(x + w * .3, 352 - h - 10), Offset(x + w * .6, 352 - h + 4), Offset(x + w + 2, 352 - h - 6), Offset(x + w + 2, 352 - h + 6)]), far);
  }
  // The keep on the far hill: a curtain wall and two towers, one snapped off.
  c.drawRect(const Rect.fromLTWH(856, 300, 80, 34), far);
  for (var x = 856.0; x < 936; x += 10) {
    c.drawRect(Rect.fromLTWH(x, 294, 6, 8), far);
  }
  c.drawRect(const Rect.fromLTWH(846, 262, 22, 72), far);
  c.drawPath(poly(const [Offset(842, 262), Offset(857, 238), Offset(872, 262)]), far);
  c.drawPath(poly(const [Offset(924, 334), Offset(924, 276), Offset(932, 268), Offset(938, 284), Offset(946, 272), Offset(946, 334)]), far);
  if (!repaired) {
    // A thread of smoke from the keep.
    for (var i = 0; i < 4; i++) {
      final p = ((t / 5200) + i / 4) % 1.0;
      c.drawCircle(Offset(935 - p * 30, 262 - p * 120), 5 + p * 16, Paint()..color = Color.fromRGBO(40, 28, 26, .35 * (1 - p))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }
  c.drawRect(const Rect.fromLTWH(0, 330, 960, 80), Paint()..shader = ui.Gradient.linear(const Offset(0, 330), const Offset(0, 410), [sky.last.withValues(alpha: 0), sky.last.withValues(alpha: .25), sky.last.withValues(alpha: 0)], const [0, .5, 1]));

  // ---- Middle: trees around the square ----
  final mid = Paint()..color = layer(.75);
  for (final (x, h) in const [(40.0, 120.0), (110.0, 90.0), (318.0, 110.0), (862.0, 130.0), (930.0, 100.0)]) {
    _tree(c, x, 430, h, mid, repaired);
  }
  c.drawRect(const Rect.fromLTWH(0, 410, 960, 40), Paint()..color = layer(.78));

  // ---- The inn ----
  _inn(c, repaired, t, night ? 1 : .5);

  // ---- Ground: a cobbled square, warmed by the inn's light ----
  c.drawRect(const Rect.fromLTWH(0, _ground, 960, 70), Paint()..shader = ui.Gradient.linear(const Offset(0, _ground), const Offset(0, 540), [layer(.86), _night]));
  _cobbles(c, repaired);
  c.drawLine(const Offset(0, _ground), const Offset(960, _ground), strokePaint((repaired ? const Color(0xFF8FA4C4) : const Color(0xFFFF8A4A)).withValues(alpha: .3), 1.2));
  // Light spilling onto the cobbles from the door and the lit windows.
  final spill = repaired ? _lamp : const Color(0xFFFF7A30);
  for (final (x, w, a) in [(620.0, 170.0, repaired ? .3 : .12), (509.0, 110.0, repaired ? .16 : .04), (731.0, 110.0, .16)]) {
    c.drawOval(Rect.fromCenter(center: Offset(x, _ground + 14), width: w, height: 30), Paint()..color = spill.withValues(alpha: a * (night ? 1 : .4))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }

  // ---- Smoke and sparks ----
  final smokeAt = repaired ? const Offset(752, 66) : const Offset(600, 140);
  for (var i = 0; i < (repaired ? 6 : 9); i++) {
    final p = ((t / (repaired ? 4200 : 2800)) + i / (repaired ? 6 : 9)) % 1.0;
    final at = smokeAt + Offset(math.sin(t / 1100 + i) * 10 + p * (repaired ? 60 : 90), -p * (repaired ? 120 : 200));
    final col = repaired ? Color.fromRGBO(150, 160, 180, .2 * (1 - p)) : Color.fromRGBO(60, 44, 40, .6 * (1 - p));
    c.drawCircle(at, (repaired ? 8 : 16) + p * (repaired ? 22 : 44), Paint()..color = col..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  if (!repaired) {
    for (var i = 0; i < 16; i++) {
      final p = ((t / 2400) + i * .113) % 1.0;
      final at = Offset(560 + (i * 37) % 90 + math.sin(t / 300 + i) * 8 + p * 40, 160 - p * 160);
      c.drawCircle(at, 1.8, Paint()..color = Color.fromRGBO(255, 180, 80, 1 - p));
    }
  }

  // ---- The front ----
  final front = Paint()..color = _night;
  if (fence) {
    for (var x = 20.0; x < 300; x += 34) {
      c.drawRect(Rect.fromLTWH(x, _ground - 44, 6, 50), front);
    }
    c.drawRect(const Rect.fromLTWH(10, _ground - 36, 290, 5), front);
    c.drawRect(const Rect.fromLTWH(10, _ground - 18, 290, 5), front);
  }
  for (var x = -10.0; x < 980; x += 7 + (x * 13 % 9)) {
    final h = 10 + (x * 7 % 18);
    c.drawPath(poly([Offset(x - 2.5, 540), Offset(x + (x % 5) - 2, 540 - h), Offset(x + 2.5, 540)]), front);
  }
}

void _nightSky(Canvas c, SeededRandom r, bool repaired, double t) {
  for (var i = 0; i < 90; i++) {
    final p = Offset(r.next() * 960, r.next() * 300);
    final tw = .75 + .25 * math.sin(t / (400 + i * 13) + i);
    c.drawCircle(p, r.next() * 1.2 + .3, Paint()..color = Color.fromRGBO(244, 236, 216, (r.next() * .6 + .15) * (repaired ? 1 : .5) * tw));
  }
  const moon = Offset(818, 116);
  c.drawCircle(moon, 150, Paint()..shader = ui.Gradient.radial(moon, 150, [const Color(0x38DCE6F2), const Color(0x00DCE6F2)]));
  c.drawCircle(moon, 30, Paint()..shader = ui.Gradient.radial(moon - const Offset(8, 8), 34, const [Color(0xFFFAF8EC), Color(0xFFDCD8C4)]));
  for (final (o, rr) in const [(Offset(-9, 5), 6.0), (Offset(8, -8), 4.0), (Offset(6, 10), 3.0)]) {
    c.drawCircle(moon + o, rr, Paint()..color = const Color(0x16000000));
  }
}

/// Daytime: under the ash, a dull sun behind drifting brown haze; once it's gone, a bright sun,
/// clouds, and birds.
void _daySky(Canvas c, InnSky time, double t) {
  const sun = Offset(818, 112);
  if (time == InnSky.ashDay) {
    c.drawCircle(sun, 170, Paint()..shader = ui.Gradient.radial(sun, 170, [const Color(0x55F0D0A0), const Color(0x00F0D0A0)]));
    c.drawCircle(sun, 26, Paint()..color = const Color(0xB3F4E0B8));
    // Bands of ash haze drifting across it.
    for (var i = 0; i < 5; i++) {
      final x = (t * (.006 + i * .002) + i * 260) % 1400 - 220, y = 70.0 + i * 46;
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 420, height: 34), Paint()..color = const Color(0x40463A30)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
  } else {
    c.drawCircle(sun, 160, Paint()..shader = ui.Gradient.radial(sun, 160, [const Color(0x66FFF6D8), const Color(0x00FFF6D8)]));
    c.drawCircle(sun, 26, Paint()..color = const Color(0xFFFFFBEA));
    for (var i = 0; i < 4; i++) {
      final x = (t * (.004 + i * .0015) + i * 330) % 1400 - 220, y = 60.0 + i * 38;
      for (final (dx, dy, w) in const [(0.0, 0.0, 110.0), (40.0, -14.0, 80.0), (-46.0, 6.0, 70.0)]) {
        c.drawOval(Rect.fromCenter(center: Offset(x + dx, y + dy), width: w, height: w * .42), Paint()..color = const Color(0xCCFFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }
    // A few birds wheeling over the square.
    for (var i = 0; i < 4; i++) {
      final x = (t * .03 + i * 90) % 1100 - 70, y = 150.0 + i * 14 + math.sin(t / 900 + i) * 10, flap = math.sin(t / 120 + i * 2) * 4;
      c.drawPath(
        Path()
          ..moveTo(x - 8, y - flap)
          ..quadraticBezierTo(x - 4, y - 3, x, y)
          ..quadraticBezierTo(x + 4, y - 3, x + 8, y - flap),
        strokePaint(const Color(0xFF2A2A32), 1.6)..strokeCap = StrokeCap.round,
      );
    }
  }
}

void _inn(Canvas c, bool repaired, double t, double lit) {
  final rim = lit < 1 ? const Color(0xFFE8D0A8) : (repaired ? const Color(0xFF8FA4C4) : const Color(0xFFFF8A4A));
  final fire = .7 + .3 * math.sin(t / 140) * math.sin(t / 77);

  // Chimney, behind the roof.
  c.drawRect(const Rect.fromLTWH(735, 74, 34, 80), Paint()..color = _stone);
  c.drawRect(const Rect.fromLTWH(730, 68, 44, 9), Paint()..color = _timber);
  for (var y = 84.0; y < 150; y += 11) {
    c.drawLine(Offset(735, y), Offset(769, y), strokePaint(const Color(0xFF0C0908), 1));
  }

  // ---- The roof: a long hipped roof of shingles, or a burnt-open shell ----
  final roof = repaired
      ? poly(const [Offset(_left - 24, _eaves + 6), Offset(_left + 74, _ridge), Offset(_right - 74, _ridge), Offset(_right + 24, _eaves + 6)])
      : poly(const [
          Offset(_left - 24, _eaves + 6), Offset(_left + 74, _ridge), Offset(522, _ridge), Offset(534, 128), Offset(548, 112), //
          Offset(566, 146), Offset(588, 122), Offset(604, 152), Offset(626, 116), Offset(648, 140), Offset(664, 104), //
          Offset(676, _ridge), Offset(_right - 74, _ridge), Offset(_right + 24, _eaves + 6),
        ]);
  if (!repaired) {
    // Fire glowing inside the hole, behind the shingles.
    c.drawCircle(const Offset(595, 160), 90, Paint()..color = Color.fromRGBO(255, 110, 40, .34 * fire)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
  }
  c.drawPath(roof, Paint()..color = _roof);
  c.save();
  c.clipPath(roof);
  // Rows of shingles, each row a touch lighter at its lower lip.
  for (var y = _ridge + 12; y < _eaves + 6; y += 13) {
    c.drawLine(Offset(_left - 30, y), Offset(_right + 30, y), strokePaint(const Color(0xFF1A1310), 1.4));
    final r = SeededRandom(y.toInt());
    for (var x = _left - 20 + (y % 26 == 0 ? 0 : 9); x < _right + 20; x += 18 + r.next() * 4) {
      c.drawLine(Offset(x, y - 12), Offset(x, y), strokePaint(const Color(0xFF0B0807), 1));
    }
  }
  // Light from below catches the eaves.
  c.drawRect(const Rect.fromLTRB(_left - 30, _eaves - 30, _right + 30, _eaves + 8), Paint()..shader = ui.Gradient.linear(const Offset(0, _eaves - 30), const Offset(0, _eaves + 8), [const Color(0x00000000), rim.withValues(alpha: .08)]));
  c.restore();
  c.drawPath(roof, strokePaint(rim.withValues(alpha: .35), 1.4));
  if (repaired) {
    // Two dormers, their windows lit.
    for (final x in const [530.0, 670.0]) {
      final d = poly([Offset(x - 26, 176), Offset(x - 26, 140), Offset(x, 118), Offset(x + 26, 140), Offset(x + 26, 176)]);
      c.drawPath(d, Paint()..color = _plaster);
      c.drawPath(poly([Offset(x - 32, 142), Offset(x, 114), Offset(x + 32, 142)]), strokePaint(_roof, 6));
      _window(c, Rect.fromLTWH(x - 11, 144, 22, 26), lit, panes: 2, shutters: false);
    }
  } else {
    // Charred rafters poking up through the gap, and flames licking out.
    for (final (x0, y0, x1, y1) in const [(544.0, 186.0, 534.0, 104.0), (580.0, 186.0, 592.0, 96.0), (620.0, 186.0, 612.0, 110.0), (652.0, 186.0, 664.0, 100.0)]) {
      c.drawLine(Offset(x0, y0), Offset(x1, y1), strokePaint(_roof, 6)..strokeCap = StrokeCap.round);
      c.drawLine(Offset(x0 + 2, y0), Offset(x1 + 2, y1), strokePaint(const Color(0xFFFF7A2A).withValues(alpha: .35 * fire), 1.2));
    }
    for (var i = 0; i < 9; i++) {
      final x = 540 + i * 15.0, base = 150.0 + (i % 3) * 6, h = 26 + 20 * math.sin(t / (90 + i * 17) + i * 1.7).abs();
      final flame = Path()
        ..moveTo(x - 9, base)
        ..quadraticBezierTo(x - 10, base - h * .5, x + math.sin(t / 70 + i) * 4, base - h)
        ..quadraticBezierTo(x + 10, base - h * .5, x + 9, base)
        ..close();
      c.drawPath(flame, Paint()..shader = ui.Gradient.linear(Offset(x, base), Offset(x, base - h), [const Color(0xFFFFE08A), const Color(0xFFFF7A2A), const Color(0x00E0401A)], const [0, .45, 1]));
    }
  }

  // ---- Upper storey: timber-framed plaster, jutting out over the ground floor ----
  const upper = Rect.fromLTRB(_left, _eaves, _right, _jetty);
  c.drawRect(upper, Paint()..color = _plaster);
  final beam = Paint()..color = _timber;
  c.drawRect(const Rect.fromLTRB(_left, _eaves, _right, _eaves + 7), beam);
  const posts = [_left, 510.0, 580.0, 660.0, 730.0, _right - 7];
  for (final x in posts) {
    c.drawRect(Rect.fromLTWH(x, _eaves, 7, _jetty - _eaves), beam);
  }
  // Cross braces in the panels between the windows.
  for (final (a, b) in const [(517.0, 580.0), (667.0, 730.0)]) {
    c.drawLine(Offset(a, _jetty - 4), Offset(b, _eaves + 8), strokePaint(_timber, 5));
    c.drawLine(Offset(b, _jetty - 4), Offset(a, _eaves + 8), strokePaint(_timber, 5));
    c.drawLine(Offset(a, (_eaves + _jetty) / 2), Offset(b, (_eaves + _jetty) / 2), strokePaint(_timber, 4));
  }
  // The jetty beam, with joist ends showing under it.
  c.drawRect(const Rect.fromLTRB(_left - 6, _jetty - 6, _right + 6, _jetty + 6), beam);
  c.drawLine(const Offset(_left - 6, _jetty - 6), const Offset(_right + 6, _jetty - 6), strokePaint(rim.withValues(alpha: .25), 1));
  for (var x = _left + 4; x < _right; x += 26) {
    c.drawRect(Rect.fromLTWH(x, _jetty + 6, 8, 6), beam);
  }

  // ---- Ground storey: stone ----
  const lower = Rect.fromLTRB(_left + 8, _jetty + 6, _right - 8, _ground);
  c.drawRect(lower, Paint()..color = _stone);
  final r = SeededRandom(3);
  for (var y = _jetty + 6 + 20; y < _ground; y += 20) {
    c.drawLine(Offset(lower.left, y), Offset(lower.right, y), strokePaint(const Color(0xFF0D0A08), 1.2));
    for (var x = lower.left + ((y ~/ 20).isEven ? 0 : 18) + r.next() * 8; x < lower.right; x += 30 + r.next() * 14) {
      c.drawLine(Offset(x, y - 20), Offset(x, y), strokePaint(const Color(0xFF0D0A08), 1.2));
    }
  }
  // Corner quoins: bigger, paler blocks up each corner.
  for (final x in const [_left + 8, _right - 26]) {
    for (var y = _jetty + 8; y < _ground - 4; y += 20) {
      c.drawRect(Rect.fromLTWH(x + ((y ~/ 20).isEven ? 0 : 4), y, 18, 18), Paint()..color = const Color(0xFF1C1612));
    }
  }

  // ---- Windows ----
  final flicker = .55 + .45 * math.sin(t / 110 + 1) * math.sin(t / 63);
  const uppers = [Rect.fromLTWH(454, 218, 40, 50), Rect.fromLTWH(600, 218, 40, 50), Rect.fromLTWH(746, 218, 40, 50)];
  for (final (i, w) in uppers.indexed) {
    if (repaired) {
      _window(c, w, (i == 1 ? .85 : 1) * lit);
    } else if (i == 1) {
      _window(c, w, flicker * .8, fire: true);
    } else {
      _darkWindow(c, w, boarded: i == 0);
    }
  }
  const lowers = [Rect.fromLTWH(476, 336, 66, 72), Rect.fromLTWH(698, 336, 66, 72)];
  for (final (i, w) in lowers.indexed) {
    if (repaired) {
      _window(c, w, lit, panes: 3, shutters: false);
    } else if (i == 1) {
      _window(c, w, flicker, fire: true, panes: 3, shutters: false);
    } else {
      _darkWindow(c, w, boarded: true);
    }
  }

  // ---- The door, under a little porch roof ----
  const door = Rect.fromLTWH(594, 352, 52, 118);
  final arch = Path()
    ..moveTo(door.left, door.bottom)
    ..lineTo(door.left, door.top + 26)
    ..arcToPoint(Offset(door.right, door.top + 26), radius: const Radius.circular(26))
    ..lineTo(door.right, door.bottom)
    ..close();
  // Stone surround.
  c.drawPath(arch, strokePaint(const Color(0xFF221A15), 10));
  if (repaired) {
    // Open, spilling light.
    c.drawCircle(door.center, 100, Paint()..color = _lamp.withValues(alpha: .2 * lit)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    c.drawPath(arch, Paint()..shader = ui.Gradient.linear(door.topCenter, door.bottomCenter, const [Color(0xFFFFD890), Color(0xFFFFB04A)]));
    // The door itself, swung open against the frame.
    c.drawPath(poly(const [Offset(594, 470), Offset(594, 378), Offset(608, 382), Offset(608, 466)]), Paint()..color = _timber);
  } else {
    c.drawPath(arch, Paint()..color = const Color(0xFF070505));
    // Shut, with planks nailed across it.
    for (final (y0, y1) in const [(392.0, 404.0), (430.0, 420.0)]) {
      c.drawLine(Offset(door.left - 6, y0), Offset(door.right + 6, y1), strokePaint(const Color(0xFF241A14), 7));
    }
  }
  // Steps.
  c.drawRect(Rect.fromLTWH(door.left - 10, _ground - 6, door.width + 20, 6), Paint()..color = const Color(0xFF1C1612));
  // Porch roof on two brackets.
  c.drawPath(poly(const [Offset(578, 342), Offset(620, 322), Offset(662, 342), Offset(662, 348), Offset(620, 330), Offset(578, 348)]), Paint()..color = _timber);
  c.drawLine(const Offset(582, 346), const Offset(594, 362), strokePaint(_timber, 4));
  c.drawLine(const Offset(658, 346), const Offset(646, 362), strokePaint(_timber, 4));
  // A lantern on an iron arm beside the door.
  c.drawLine(const Offset(672, 344), const Offset(688, 344), strokePaint(_night, 3));
  paintLantern(c, Offset(688 + math.sin(t / 800) * 1.2, 362), t);

  // ---- The sign: a painted board with a kettle, hung from a wrought bracket ----
  c.drawLine(const Offset(_left, 232), const Offset(352, 232), strokePaint(_night, 5));
  c.drawLine(const Offset(_left, 252), const Offset(400, 232), strokePaint(_night, 3));
  c.drawArc(Rect.fromCenter(center: const Offset(357, 226), width: 12, height: 12), 0, math.pi * 1.5, false, strokePaint(_night, 3));
  final sway = math.sin(t / 900) * (repaired ? .04 : .07) + (repaired ? 0 : .18);
  c.save();
  c.translate(380, 234);
  c.rotate(sway);
  c.drawLine(const Offset(-20, 0), const Offset(-20, 10), strokePaint(_night, 2));
  if (repaired) c.drawLine(const Offset(20, 0), const Offset(20, 10), strokePaint(_night, 2));
  const board = Rect.fromLTWH(-28, 10, 56, 42);
  c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(3)), Paint()..shader = ui.Gradient.linear(board.topCenter, board.bottomCenter, repaired ? const [Color(0xFF5A3C26), Color(0xFF2E1E14)] : const [Color(0xFF2E2018), Color(0xFF16100C)]));
  final gilt = repaired ? const Color(0xFFD8B060) : const Color(0xFF6A5030);
  c.drawRRect(RRect.fromRectAndRadius(board.deflate(3), const Radius.circular(2)), strokePaint(gilt, 1.6));
  // The kettle.
  final kettle = Paint()..color = repaired ? const Color(0xFFEAD49A) : const Color(0xFF5A4630);
  c.drawOval(const Rect.fromLTWH(-12, 24, 24, 20), kettle);
  c.drawRect(const Rect.fromLTWH(-9, 22, 18, 4), kettle);
  c.drawCircle(const Offset(0, 20), 2.4, kettle);
  c.drawPath(poly(const [Offset(10, 34), Offset(19, 26), Offset(21, 28), Offset(12, 39)]), kettle);
  c.drawArc(const Rect.fromLTWH(-10, 14, 20, 18), math.pi * 1.05, math.pi * .9, false, strokePaint(kettle.color, 2));
  if (repaired) {
    // A curl of steam.
    final s = math.sin(t / 500) * 2;
    c.drawPath(
      Path()
        ..moveTo(-16, 24)
        ..quadraticBezierTo(-22 + s, 18, -17, 13)
        ..quadraticBezierTo(-12 + s, 8, -18, 2),
      strokePaint(const Color(0x99F2E6C8), 1.2)..strokeCap = StrokeCap.round,
    );
  } else {
    // Scorched across one corner.
    c.drawCircle(const Offset(18, 44), 12, Paint()..color = const Color(0xCC050302)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
  c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(3)), strokePaint(_night, 1.6));
  c.restore();

  // ---- Barrels and a crate by the wall ----
  for (final (x, w, h) in const [(762.0, 26.0, 38.0), (790.0, 26.0, 38.0)]) {
    final b = RRect.fromRectAndRadius(Rect.fromLTWH(x, _ground - h, w, h), const Radius.circular(7));
    c.drawRRect(b, Paint()..color = const Color(0xFF15100D));
    for (final f in const [.22, .78]) {
      c.drawLine(Offset(x + 2, _ground - h * f), Offset(x + w - 2, _ground - h * f), strokePaint(const Color(0xFF2A211B), 2));
    }
    c.drawRRect(b, strokePaint(rim.withValues(alpha: .25), 1));
  }
  const crate = Rect.fromLTWH(774, _ground - 64, 30, 26);
  c.drawRect(crate, Paint()..color = const Color(0xFF1A130F));
  c.drawLine(crate.topLeft, crate.bottomRight, strokePaint(const Color(0xFF2A1F17), 2.5));
  c.drawLine(crate.bottomLeft, crate.topRight, strokePaint(const Color(0xFF2A1F17), 2.5));
  c.drawRect(crate, strokePaint(const Color(0xFF2A1F17), 2));
  if (!repaired) {
    // A beam fallen against the wall.
    c.drawPath(poly(const [Offset(812, 300), Offset(830, 294), Offset(864, _ground), Offset(844, _ground)]), Paint()..color = _roof);
  }
}

/// A warm window: deep reveal, leaded panes, wooden shutters folded back and a sill.
void _window(Canvas c, Rect w, double k, {bool fire = false, int panes = 2, bool shutters = true}) {
  final col = fire ? const Color(0xFFFF8A3A) : _lamp;
  c.drawCircle(w.center, w.width * 1.5, Paint()..color = col.withValues(alpha: .2 * k)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  if (shutters) {
    for (final s in [Rect.fromLTWH(w.left - w.width * .42, w.top, w.width * .4, w.height), Rect.fromLTWH(w.right + w.width * .02, w.top, w.width * .4, w.height)]) {
      c.drawRect(s, Paint()..color = _timber);
      c.drawLine(s.centerLeft, s.centerRight, strokePaint(const Color(0xFF120D0A), 1.5));
      c.drawRect(s, strokePaint(const Color(0xFF120D0A), 1.2));
    }
  }
  c.drawRect(w, Paint()..shader = ui.Gradient.linear(w.topCenter, w.bottomCenter, [Color.lerp(col, const Color(0xFFFFE6A8), .45)!.withValues(alpha: k), col.withValues(alpha: .85 * k)]));
  final bar = strokePaint(const Color(0xFF0E0A09), 2.2);
  for (var i = 1; i < panes; i++) {
    final x = w.left + w.width * i / panes;
    c.drawLine(Offset(x, w.top), Offset(x, w.bottom), bar);
  }
  for (var i = 1; i < 3; i++) {
    final y = w.top + w.height * i / 3;
    c.drawLine(Offset(w.left, y), Offset(w.right, y), bar);
  }
  c.drawRect(w, strokePaint(const Color(0xFF0E0A09), 4));
  // The sill.
  c.drawRect(Rect.fromLTWH(w.left - 5, w.bottom, w.width + 10, 5), Paint()..color = _timber);
  c.drawLine(Offset(w.left - 5, w.bottom), Offset(w.right + 5, w.bottom), strokePaint(col.withValues(alpha: .5 * k), 1));
}

/// A dark, empty window (boarded up across, if [boarded]).
void _darkWindow(Canvas c, Rect w, {bool boarded = false}) {
  c.drawRect(w, Paint()..color = const Color(0xFF050404));
  if (boarded) {
    for (var k = 0; k < 3; k++) {
      c.drawLine(Offset(w.left - 5, w.top + 10 + k * w.height * .3), Offset(w.right + 5, w.top + 16 + k * w.height * .26), strokePaint(const Color(0xFF221812), 6));
    }
  } else {
    // Broken glass: a jagged shard left in one corner.
    c.drawPath(poly([w.topLeft, w.topLeft + Offset(w.width * .5, 0), w.topLeft + Offset(w.width * .2, w.height * .4)]), Paint()..color = const Color(0x332A3A4A));
  }
  c.drawRect(w, strokePaint(const Color(0xFF1A1310), 4));
  c.drawRect(Rect.fromLTWH(w.left - 5, w.bottom, w.width + 10, 5), Paint()..color = _timber);
}

/// Cobbles across the square: rows of rounded stones, smaller towards the back.
void _cobbles(Canvas c, bool repaired) {
  final r = SeededRandom(19);
  final stone = Paint()..color = const Color(0xFF1B1512);
  final lip = strokePaint((repaired ? const Color(0xFF8FA4C4) : const Color(0xFFFF8A4A)).withValues(alpha: .08), 1);
  var y = _ground + 5.0, h = 5.0;
  while (y < 540) {
    final w = h * 2.2;
    for (var x = -r.next() * w; x < 960; x += w + 2 + r.next() * 3) {
      final s = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w * (.8 + r.next() * .3), h), Radius.circular(h * .45));
      c.drawRRect(s, stone);
      c.drawLine(s.outerRect.topLeft + Offset(h * .4, 0), s.outerRect.topRight - Offset(h * .4, 0), lip);
    }
    y += h + 2.5;
    h *= 1.28;
  }
}

void _tree(Canvas c, double x, double base, double h, Paint p, bool leafy) {
  c.drawRect(Rect.fromLTWH(x - h * .04, base - h * .5, h * .08, h * .5), p);
  if (leafy) {
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * math.pi * 2;
      c.drawCircle(Offset(x + math.cos(a) * h * .2, base - h * .7 + math.sin(a) * h * .14), h * .2, p);
    }
  } else {
    // Burnt bare.
    for (final (dx, dy) in const [(-.3, -.95), (.25, -1.0), (-.1, -1.1), (.35, -.75), (-.35, -.7)]) {
      c.drawLine(Offset(x, base - h * .5), Offset(x + dx * h * .6, base + dy * h * .9), strokePaint(p.color, h * .03)..strokeCap = StrokeCap.round);
    }
  }
}
