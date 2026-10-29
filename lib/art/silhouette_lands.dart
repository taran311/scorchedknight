// Battlegrounds in the silhouette style: a glowing sky, then layer after layer of dark shapes,
// each nearer one darker and sharper, with fog drifting between. Lit windows, lava and fires are
// the only bright things on the land.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'battlegrounds.dart';
import 'paint_kit.dart';
import 'scenery.dart' show sceneSize;

const _night = Color(0xFF0B0908);
const _ground = 470.0;
const _lamp = Color(0xFFFFB04A);

/// Paints the silhouette battleground for [s] into a 960 x 540 canvas.
void paintSilhouetteLand(Canvas c, Setting s, BattlegroundSpec sp) {
  final r = SeededRandom(s.index * 53 + 11);
  final horizon = sp.sky.last;
  // Each layer from far to near: closer to the sky's colour far off, near-black up close.
  Color layer(double k) => Color.lerp(horizon, _night, k)!;
  final indoor = s == Setting.crypt || s == Setting.lair || s == Setting.tomb || s == Setting.deepforge || s == Setting.roost || s == Setting.icecave;

  // ---- Sky ----
  c.drawRect(Offset.zero & sceneSize, _vertical(sp.sky, 0, _ground));
  final sun = Offset(sp.sun.dx, math.min(sp.sun.dy, 330));
  c.drawCircle(sun, 420, _radial(sun, 420, sp.glow, const [.55, .18, 0], const [0, .45, 1]));
  if (sp.stars) {
    for (var i = 0; i < 70; i++) {
      final p = Offset(r.next() * 960, r.next() * 260);
      c.drawCircle(p, r.next() * 1.2 + .3, Paint()..color = Color.fromRGBO(244, 236, 216, r.next() * .55 + .15));
    }
  }
  if (indoor) {
    // Indoors: a dark back wall, lit from the torches, in place of the sky.
    c.drawRect(Offset.zero & sceneSize, _vertical([_night, layer(.72), layer(.6)], 0, _ground));
  } else {
    if (sp.moon) {
      c.drawCircle(sun, 34, Paint()..color = Color.lerp(sp.glow, const Color(0xFFFFFFFF), .5)!);
      c.drawCircle(sun + const Offset(9, -6), 30, Paint()..color = sp.sky.first.withValues(alpha: .25));
    } else {
      c.drawCircle(sun, 46, Paint()..color = Color.lerp(sp.glow, const Color(0xFFFFFFFF), .35)!.withValues(alpha: .9));
    }
    // Long streaks of cloud, dark against the glow.
    for (var i = 0; i < 4; i++) {
      final y = 70 + r.next() * 150, x = r.next() * 960 - 150, w = 260 + r.next() * 300;
      c.drawOval(
        Rect.fromLTWH(x, y, w, 3 + r.next() * 4),
        Paint()
          ..color = layer(.3 + r.next() * .2).withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  // ---- Far: mountains ----
  final far = layer(.42);
  c.drawPath(_range(r, 330, 90 * sp.jagged.clamp(1.0, 2.2), 5 + (sp.jagged * 3).round(), sp.jagged), Paint()..color = far);
  _fog(c, 360, sp.glow, .22);

  // ---- Middle: the land's character ----
  final mid = layer(.66);
  c.drawPath(_range(r, 394, 34, 6, 1), Paint()..color = mid);
  _features(c, s, sp, r, 405, mid, .7, near: false);
  _fog(c, 420, sp.glow, .16);

  // ---- Near: hills and props ----
  final near = layer(.86);
  c.drawPath(_range(r, 440, 20, 5, 1), Paint()..color = near);
  _features(c, s, sp, r, 452, near, 1, near: true);

  // ---- Ground: dark, with the backlight catching its top edge ----
  c.drawRect(const Rect.fromLTWH(0, _ground - 16, 960, 540 - _ground + 16), _vertical([layer(.9), _night], _ground - 16, 540));
  c.drawLine(const Offset(0, _ground - 16), const Offset(960, _ground - 16), strokePaint(sp.glow.withValues(alpha: .35), 1.4));
  // A faint path where the fight happens.
  c.drawOval(const Rect.fromLTWH(140, _ground - 10, 700, 34), Paint()..color = sp.glow.withValues(alpha: .05));
  // Grass and stones along the very front.
  final blade = Paint()..color = _night;
  for (var x = -10.0; x < 980; x += 6 + r.next() * 8) {
    final h = 8 + r.next() * 22, lean = (r.next() - .5) * 10;
    c.drawPath(
      Path()
        ..moveTo(x - 2.5, 540)
        ..quadraticBezierTo(x + lean * .4, 540 - h * .6, x + lean, 540 - h)
        ..quadraticBezierTo(x + lean * .2, 540 - h * .5, x + 2.5, 540)
        ..close(),
      blade,
    );
  }
  for (var i = 0; i < 5; i++) {
    final x = r.next() * 960, w = 18 + r.next() * 40;
    c.drawOval(Rect.fromLTWH(x, 520 - w * .25, w, w * .5), blade);
  }
  // Vignette: darker at the edges, so the eye sits on the fight.
  c.drawRect(
    Offset.zero & sceneSize,
    Paint()..shader = ui.Gradient.radial(const Offset(480, 300), 620, const [Color(0x00000000), Color(0x00000000), Color(0x8C000000)], const [0, .55, 1]),
  );
}

Paint _vertical(List<Color> cs, double top, double bottom) =>
    Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), cs, List.generate(cs.length, (i) => i / (cs.length - 1)));

Paint _radial(Offset centre, double radius, Color colour, List<double> alphas, List<double> stops) =>
    Paint()..shader = ui.Gradient.radial(centre, radius, [for (final a in alphas) colour.withValues(alpha: a)], stops);

/// A band of fog lying along [y], lit by the sky.
void _fog(Canvas c, double y, Color glow, double a) {
  c.drawRect(
    Rect.fromLTWH(0, y - 40, 960, 80),
    Paint()..shader = ui.Gradient.linear(Offset(0, y - 40), Offset(0, y + 40), [glow.withValues(alpha: 0), glow.withValues(alpha: a), glow.withValues(alpha: 0)], const [0, .5, 1]),
  );
}

/// A ridge line across the scene at [base], [height] tall, with [peaks] bumps (sharper with
/// [jag]), filled down to the bottom.
Path _range(SeededRandom r, double base, double height, int peaks, double jag) {
  // A natural ridge: a few long swells with smaller wrinkles on them (sharper where [jag] is
  // high, as peaks), no two alike.
  final waves = [
    for (var i = 0; i < 4; i++) (r.next() * math.pi * 2, (peaks / 4) * (1 + i * 1.7) * (.8 + r.next() * .4), 1 / (1 + i * 1.6)),
  ];
  final p = Path()..moveTo(-20, 540);
  for (var x = -20.0; x <= 980; x += 6) {
    var y = 0.0, norm = 0.0;
    for (final (phase, freq, amp) in waves) {
      final s = math.sin(x / 960 * math.pi * 2 * freq + phase);
      y += (jag > 1.4 ? 1 - (s).abs() * 2 : s) * amp;
      norm += amp;
    }
    p.lineTo(x, base - height * (.5 + .5 * y / norm));
  }
  p
    ..lineTo(980, 540)
    ..close();
  return p;
}

/// Each land's landmarks, as silhouettes along [base]. [lit] scales how bright windows and
/// fires glow (nearer is brighter).
void _features(Canvas c, Setting s, BattlegroundSpec sp, SeededRandom r, double base, Color col, double lit, {required bool near}) {
  final fill = Paint()..color = col;
  // Spots kept clear in front, where the knight and the foe stand.
  bool clear(double x) => near && ((x > 150 && x < 320) || (x > 620 && x < 830));
  Iterable<double> spots(int n, [double jitter = 60]) sync* {
    for (var i = 0; i < n; i++) {
      final x = (i + .5) * 960 / n + (r.next() - .5) * jitter;
      if (!clear(x)) yield x;
    }
  }

  switch (s) {
    case Setting.forest || Setting.road || Setting.summit || Setting.moonwood || Setting.aerie:
      for (final x in spots(near ? 7 : 16, 40)) {
        _pine(c, x, base + 4, (near ? 150 : 70) * (.7 + r.next() * .5), fill);
      }
      if (s == Setting.road && near) _signpost(c, 560, base + 8, fill);
    case Setting.blossom:
      // Pagodas on the far hills; blossom trees close by.
      if (!near) {
        for (final x in spots(3, 120)) {
          _pagoda(c, x, base + 4, 90 + r.next() * 40, fill);
        }
      }
      for (final x in spots(near ? 4 : 9)) {
        _bigTree(c, x, base + 4, (near ? 150 : 70) * (.7 + r.next() * .4), fill, r);
      }
    case Setting.elderwood || Setting.heartgrove || Setting.jungle:
      for (final x in spots(near ? 5 : 11)) {
        _bigTree(c, x, base + 4, (near ? 200 : 90) * (.7 + r.next() * .5), fill, r);
      }
    case Setting.blightwood || Setting.plague || Setting.swamp:
      for (final x in spots(near ? 6 : 12)) {
        _deadTree(c, x, base + 4, (near ? 170 : 80) * (.7 + r.next() * .5), fill, r);
      }
      if (s == Setting.swamp && near) {
        for (final x in spots(16, 30)) {
          _reeds(c, x, base + 10, fill, r);
        }
      }
    case Setting.graveyard || Setting.boneyard:
      if (s == Setting.boneyard && !near) {
        _ribcage(c, 600, base + 2, 180, fill);
      }
      for (final x in spots(near ? 9 : 14, 40)) {
        if (r.next() < .5) {
          _tomb(c, x, base + 4, near ? 1.3 : .7, fill);
        } else {
          _cross(c, x, base + 4, near ? 1.3 : .7, fill);
        }
      }
      if (!near) _deadTree(c, 140, base, 120, fill, r);
    case Setting.village:
      for (final x in spots(near ? 4 : 7, 40)) {
        _cottage(c, x, base + 4, (near ? 110 : 60) * (.8 + r.next() * .3), fill, lit, r);
      }
    case Setting.castle || Setting.moor:
      if (!near) {
        _castle(c, 520, base + 2, fill, lit, r);
      } else {
        for (final x in spots(5)) {
          _pine(c, x, base + 4, 120 * (.7 + r.next() * .5), fill);
        }
      }
    case Setting.warcamp || Setting.orkcamp:
      for (final x in spots(near ? 4 : 8, 50)) {
        _tent(c, x, base + 4, (near ? 90 : 50) * (.8 + r.next() * .4), fill);
      }
      if (near) {
        _palisade(c, 0, 140, base + 6, fill);
        _palisade(c, 840, 960, base + 6, fill);
      }
      for (final x in spots(near ? 2 : 3, 80)) {
        _brazier(c, x, base + 4, near ? 1.2 : .7, fill, lit);
      }
    case Setting.ruins || Setting.shiftisle:
      for (final x in spots(near ? 5 : 9, 50)) {
        _column(c, x, base + 4, (near ? 150 : 80) * (.5 + r.next() * .6), fill, r);
      }
      if (!near) _arch(c, 470, base + 2, 140, fill);
    case Setting.totems:
      for (final x in spots(near ? 4 : 8, 50)) {
        _totem(c, x, base + 4, (near ? 150 : 80) * (.7 + r.next() * .4), fill, lit);
      }
    case Setting.ice:
      for (final x in spots(near ? 7 : 14, 50)) {
        _spike(c, x, base + 4, (near ? 120 : 70) * (.5 + r.next() * .7), (near ? 30 : 18) * (.7 + r.next() * .5), fill);
      }
    case Setting.volcano:
      if (!near) _volcano(c, 520, base, fill, sp.glow);
      for (final x in spots(near ? 6 : 10, 50)) {
        _spike(c, x, base + 4, (near ? 90 : 50) * (.5 + r.next() * .7), (near ? 36 : 20) * (.7 + r.next() * .5), fill);
      }
      if (near) _lava(c, base + 12);
    case Setting.coast || Setting.fogshore:
      if (!near) {
        // The sea: a flat horizon with the sky's glow laid across it.
        c.drawRect(Rect.fromLTWH(0, base - 30, 960, 60), Paint()..color = col);
        for (var i = 0; i < 9; i++) {
          final y = base - 26 + i * 6.0, w = 160 - i * 12.0;
          c.drawLine(Offset(sp.sun.dx - w / 2, y), Offset(sp.sun.dx + w / 2, y), strokePaint(sp.glow.withValues(alpha: .4 - i * .03), 1.6));
        }
      } else {
        for (final x in spots(5, 60)) {
          _rock(c, x, base + 6, 60 + r.next() * 50, fill, r);
        }
      }
    case Setting.desert:
      // Far off: the pyramids of the old kings, half sunk in the dunes. Near: an obelisk, a
      // toppled statue's head and broken columns poking out of the sand.
      if (!near) {
        _pyramid(c, 600, base + 2, 190, fill);
        _pyramid(c, 790, base + 6, 120, fill);
        _pyramid(c, 330, base + 8, 80, fill);
      } else {
        _obelisk(c, 90, base + 6, 190, fill);
        _sunkHead(c, 520, base + 10, 56, fill);
        for (final x in [880.0, 935.0]) {
          _column(c, x, base + 8, 90 + r.next() * 60, fill, r);
        }
      }
    case Setting.tomb:
      // A tomb hall: square pillars carved with figures, braziers between, a sealed door far back.
      if (!near) {
        _tombDoor(c, 480, base + 4, 230, fill, lit);
        for (final x in [140.0, 820.0]) {
          _tombPillar(c, x, base + 4, 280, fill);
        }
      } else {
        for (final x in [40.0, 920.0]) {
          _tombPillar(c, x, base + 6, 340, fill);
        }
        for (final x in [380.0, 580.0]) {
          _brazier(c, x, base - 110, 1, fill, lit, wall: true);
        }
      }
    case Setting.roost:
      // The Hollowdeep: cave mouths into deeper dark, bats hanging from the roof in rows, and
      // glowcaps lighting the floor.
      if (!near) {
        for (final x in [120.0, 480.0, 840.0]) {
          _caveMouth(c, x, base + 4, 220, fill);
        }
        for (var i = 0; i < 26; i++) {
          _hangingBat(c, 20 + r.next() * 920, 6 + r.next() * 70, .7 + r.next() * .5, fill);
        }
      } else {
        for (final x in [40.0, 920.0]) {
          _stalagmite(c, x, base + 6, 200, fill);
        }
        for (final x in [80.0, 360.0, 520.0, 880.0]) {
          _glowcaps(c, x, base + 8, r);
        }
      }
    case Setting.frostruin:
      // A city frozen solid: towers and domes sheathed in ice on the far side, broken walls and
      // drifts close by.
      if (!near) {
        for (final (x, h) in const [(160.0, 200.0), (420.0, 260.0), (610.0, 170.0), (820.0, 230.0)]) {
          _frozenTower(c, x, base + 4, h, fill, lit, r);
        }
      } else {
        for (final x in spots(4, 80)) {
          _column(c, x, base + 6, 110 + r.next() * 80, fill, r);
        }
        for (final x in spots(6, 60)) {
          _spike(c, x, base + 6, 40 + r.next() * 40, 24, fill);
        }
      }
    case Setting.icecave:
      // Under the glacier: a ceiling hung with great icicles, frozen columns, a blue glow far back.
      if (!near) {
        for (var i = 0; i < 22; i++) {
          final x = r.next() * 960, h = 40 + r.next() * 120;
          c.drawPath(poly([Offset(x - 14, 0), Offset(x, h), Offset(x + 14, 0)]), fill);
        }
        for (final x in [140.0, 500.0, 860.0]) {
          _stalagmite(c, x, base + 4, 160 + r.next() * 80, fill);
        }
      } else {
        for (final x in [40.0, 920.0]) {
          _stalagmite(c, x, base + 6, 260, fill);
        }
      }
    case Setting.crypt || Setting.lair || Setting.deepforge:
      // Indoors: great arches or cave mouths framing the fight, torches between.
      if (!near) {
        for (final x in [120.0, 480.0, 840.0]) {
          s == Setting.crypt ? _arch(c, x, base + 4, 200, fill) : _caveMouth(c, x, base + 4, 220, fill);
        }
      } else {
        for (final x in [40.0, 920.0]) {
          s == Setting.crypt ? _column(c, x, base + 6, 300, fill, r) : _stalagmite(c, x, base + 6, 200, fill);
        }
        for (final x in [380.0, 560.0]) {
          _brazier(c, x, base - 120, 1, fill, lit, wall: true);
        }
      }
  }
}

// ---- Landmarks ----

void _pine(Canvas c, double x, double base, double h, Paint p) {
  final w = h * .32;
  final path = Path()..moveTo(x, base - h);
  for (var i = 1; i <= 4; i++) {
    final y = base - h + h * i * .22, ww = w * (.35 + i * .17);
    path
      ..lineTo(x + ww, y)
      ..lineTo(x + ww * .35, y - h * .04);
  }
  path.lineTo(x + w * .08, base);
  path.lineTo(x - w * .08, base);
  for (var i = 4; i >= 1; i--) {
    final y = base - h + h * i * .22, ww = w * (.35 + i * .17);
    path
      ..lineTo(x - ww * .35, y - h * .04)
      ..lineTo(x - ww, y);
  }
  c.drawPath(path..close(), p);
}

/// A pagoda: tiers of sweeping roofs, each a little narrower, a spire on top.
void _pagoda(Canvas c, double x, double base, double h, Paint p) {
  const tiers = 4;
  for (var i = 0; i < tiers; i++) {
    final y = base - i * h / tiers, w = h * (.42 - i * .07);
    c.drawRect(Rect.fromLTRB(x - w * .6, y - h / tiers * .7, x + w * .6, y), p);
    c.drawPath(
      Path()
        ..moveTo(x - w * 1.1, y - h / tiers * .6)
        ..quadraticBezierTo(x - w * .6, y - h / tiers * .75, x, y - h / tiers * 1.05)
        ..quadraticBezierTo(x + w * .6, y - h / tiers * .75, x + w * 1.1, y - h / tiers * .6)
        ..close(),
      p,
    );
  }
  c.drawLine(Offset(x, base - h), Offset(x, base - h * 1.18), strokePaint(p.color, 2.5));
}

void _bigTree(Canvas c, double x, double base, double h, Paint p, SeededRandom r) {
  c.drawPath(
    Path()
      ..moveTo(x - h * .06, base)
      ..quadraticBezierTo(x - h * .03, base - h * .45, x - h * .1, base - h * .6)
      ..lineTo(x + h * .1, base - h * .6)
      ..quadraticBezierTo(x + h * .03, base - h * .45, x + h * .07, base)
      ..close(),
    p,
  );
  for (var i = 0; i < 7; i++) {
    final a = i / 7 * math.pi * 2, d = h * (.18 + r.next() * .12);
    c.drawCircle(Offset(x + math.cos(a) * d * 1.3, base - h * .72 + math.sin(a) * d * .7), h * (.16 + r.next() * .08), p);
  }
}

void _deadTree(Canvas c, double x, double base, double h, Paint p, SeededRandom r) {
  final trunk = strokePaint(p.color, h * .07)..strokeCap = StrokeCap.round;
  c.drawLine(Offset(x, base), Offset(x + h * .05, base - h * .6), trunk);
  void branch(Offset from, double ang, double len, double w, int depth) {
    final to = from + Offset(math.cos(ang), math.sin(ang)) * len;
    c.drawLine(from, to, strokePaint(p.color, w)..strokeCap = StrokeCap.round);
    if (depth > 0) {
      branch(to, ang - .5 - r.next() * .3, len * .7, w * .65, depth - 1);
      branch(to, ang + .4 + r.next() * .3, len * .65, w * .65, depth - 1);
    }
  }

  final top = Offset(x + h * .05, base - h * .6);
  branch(top, -math.pi / 2 - .5, h * .28, h * .05, 3);
  branch(top, -math.pi / 2 + .45, h * .3, h * .05, 3);
}

void _reeds(Canvas c, double x, double base, Paint p, SeededRandom r) {
  for (var i = 0; i < 5; i++) {
    final dx = (i - 2) * 3.0, h = 20 + r.next() * 26;
    c.drawLine(Offset(x + dx, base), Offset(x + dx + (r.next() - .5) * 8, base - h), strokePaint(p.color, 1.6));
    if (i.isEven) c.drawOval(Rect.fromCenter(center: Offset(x + dx, base - h + 4), width: 4, height: 10), p);
  }
}

void _tomb(Canvas c, double x, double base, double k, Paint p) {
  c.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x - 12 * k, base - 30 * k, 24 * k, 30 * k), topLeft: Radius.circular(12 * k), topRight: Radius.circular(12 * k)), p);
}

void _cross(Canvas c, double x, double base, double k, Paint p) {
  c.drawRect(Rect.fromLTWH(x - 3 * k, base - 40 * k, 6 * k, 40 * k), p);
  c.drawRect(Rect.fromLTWH(x - 12 * k, base - 32 * k, 24 * k, 6 * k), p);
}

void _ribcage(Canvas c, double x, double base, double h, Paint p) {
  for (var i = 0; i < 6; i++) {
    final rx = x - h * .6 + i * h * .24, rh = h * (.55 + math.sin(i / 5 * math.pi) * .45);
    c.drawPath(
      Path()
        ..moveTo(rx, base)
        ..quadraticBezierTo(rx - h * .2, base - rh * .7, rx + h * .05, base - rh),
      strokePaint(p.color, 9)..strokeCap = StrokeCap.round,
    );
  }
  c.drawLine(Offset(x - h * .65, base - h * .05), Offset(x + h * .7, base - h * .25), strokePaint(p.color, 12)..strokeCap = StrokeCap.round);
}

/// A window glowing in the dark, with a soft halo.
void _window(Canvas c, Rect w, double lit) {
  c.drawCircle(w.center, w.width * 1.8, Paint()..color = _lamp.withValues(alpha: .18 * lit)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  c.drawRect(w, Paint()..color = Color.lerp(_lamp, const Color(0xFFFFE6A8), .3)!.withValues(alpha: .85 * lit));
}

void _cottage(Canvas c, double x, double base, double h, Paint p, double lit, SeededRandom r) {
  final w = h * 1.1;
  c.drawRect(Rect.fromLTWH(x - w / 2, base - h * .55, w, h * .55), p);
  c.drawPath(poly([Offset(x - w * .62, base - h * .55), Offset(x, base - h), Offset(x + w * .62, base - h * .55)]), p);
  c.drawRect(Rect.fromLTWH(x + w * .18, base - h * 1.0, w * .12, h * .3), p);
  if (r.next() < .8) _window(c, Rect.fromLTWH(x - w * .3, base - h * .42, w * .14, h * .14), lit);
  if (r.next() < .6) _window(c, Rect.fromLTWH(x + w * .12, base - h * .42, w * .14, h * .14), lit);
}

void _castle(Canvas c, double x, double base, Paint p, double lit, SeededRandom r) {
  c.drawRect(Rect.fromLTWH(x - 160, base - 90, 320, 90), p);
  for (final (dx, h, w) in const [(-170.0, 190.0, 54.0), (-60.0, 150.0, 40.0), (40.0, 230.0, 60.0), (160.0, 170.0, 50.0)]) {
    c.drawRect(Rect.fromLTWH(x + dx - w / 2, base - h, w, h), p);
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(x + dx - w / 2 + i * w / 2.5, base - h - 10, w / 5, 10), p);
    }
    if (dx == 40) c.drawPath(poly([Offset(x + dx - w / 2 - 6, base - h), Offset(x + dx, base - h - 60), Offset(x + dx + w / 2 + 6, base - h)]), p);
    _window(c, Rect.fromLTWH(x + dx - 4, base - h + 30, 8, 14), lit * .9);
  }
  for (var i = 0; i < 9; i++) {
    c.drawRect(Rect.fromLTWH(x - 160 + i * 36, base - 100, 18, 10), p);
  }
}

void _tent(Canvas c, double x, double base, double h, Paint p) {
  c.drawPath(poly([Offset(x - h * .7, base), Offset(x, base - h), Offset(x + h * .7, base)]), p);
  c.drawLine(Offset(x, base - h), Offset(x, base - h - 30), strokePaint(p.color, 2.5));
  c.drawPath(poly([Offset(x, base - h - 30), Offset(x + 22, base - h - 24), Offset(x, base - h - 18)]), p);
}

void _palisade(Canvas c, double from, double to, double base, Paint p) {
  for (var x = from; x < to; x += 16) {
    c.drawPath(poly([Offset(x, base), Offset(x, base - 70), Offset(x + 7, base - 86), Offset(x + 14, base - 70), Offset(x + 14, base)]), p);
  }
  c.drawRect(Rect.fromLTWH(from, base - 50, to - from, 6), p);
}

void _brazier(Canvas c, double x, double base, double k, Paint p, double lit, {bool wall = false}) {
  if (!wall) c.drawRect(Rect.fromLTWH(x - 3 * k, base - 50 * k, 6 * k, 50 * k), p);
  c.drawPath(poly([Offset(x - 14 * k, base - 56 * k), Offset(x + 14 * k, base - 56 * k), Offset(x + 8 * k, base - 46 * k), Offset(x - 8 * k, base - 46 * k)]), p);
  final f = Offset(x, base - 66 * k);
  c.drawCircle(f, 40 * k, Paint()..color = _lamp.withValues(alpha: .22 * lit)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  c.drawPath(
    Path()
      ..moveTo(x - 9 * k, base - 56 * k)
      ..quadraticBezierTo(x - 10 * k, base - 72 * k, x, base - 84 * k)
      ..quadraticBezierTo(x + 10 * k, base - 72 * k, x + 9 * k, base - 56 * k)
      ..close(),
    Paint()..shader = ui.Gradient.linear(Offset(x, base - 56 * k), Offset(x, base - 84 * k), [const Color(0xFFFFE08A).withValues(alpha: lit), const Color(0xFFFF6A2A).withValues(alpha: .8 * lit)]),
  );
}

void _column(Canvas c, double x, double base, double h, Paint p, SeededRandom r) {
  final w = math.max(14.0, h * .14);
  final broken = r.next() < .6;
  final top = base - h;
  c.drawRect(Rect.fromLTWH(x - w / 2 - 4, base - 10, w + 8, 10), p);
  if (broken) {
    c.drawPath(poly([Offset(x - w / 2, base), Offset(x - w / 2, top + 10), Offset(x - w * .1, top), Offset(x + w * .2, top + 14), Offset(x + w / 2, top + 4), Offset(x + w / 2, base)]), p);
  } else {
    c.drawRect(Rect.fromLTWH(x - w / 2, top, w, h), p);
    c.drawRect(Rect.fromLTWH(x - w / 2 - 6, top - 10, w + 12, 10), p);
  }
}

void _arch(Canvas c, double x, double base, double h, Paint p) {
  final w = h * .8;
  final path = Path()
    ..addRect(Rect.fromLTWH(x - w / 2 - 22, base - h, w + 44, h))
    ..fillType = PathFillType.evenOdd
    ..addPath(
      Path()
        ..moveTo(x - w / 2, base)
        ..lineTo(x - w / 2, base - h * .55)
        ..arcToPoint(Offset(x + w / 2, base - h * .55), radius: Radius.circular(w / 2))
        ..lineTo(x + w / 2, base)
        ..close(),
      Offset.zero,
    );
  c.drawPath(path, p);
}

/// A tower of the frozen city: a tall shaft with a dome or a spire, ice hanging from its ledges, a
/// window or two still lit.
void _frozenTower(Canvas c, double x, double base, double h, Paint p, double lit, SeededRandom r) {
  final w = h * .2;
  c.drawRect(Rect.fromLTWH(x - w / 2, base - h, w, h), p);
  if (r.next() < .5) {
    c.drawCircle(Offset(x, base - h), w * .6, p);
  } else {
    c.drawPath(poly([Offset(x - w * .6, base - h), Offset(x, base - h - w * 1.6), Offset(x + w * .6, base - h)]), p);
  }
  for (var i = 0; i < 4; i++) {
    final ix = x - w / 2 + (i + .5) * w / 4;
    c.drawPath(poly([Offset(ix - 3, base - h * .62), Offset(ix, base - h * .62 + 10 + (i % 2) * 8), Offset(ix + 3, base - h * .62)]), p);
  }
  c.drawRect(Rect.fromLTWH(x - w * .7, base - h * .62 - 6, w * 1.4, 6), p);
  if (r.next() < .7) _window(c, Rect.fromLTWH(x - 4, base - h * .4, 8, 14), lit * .7);
}

void _caveMouth(Canvas c, double x, double base, double h, Paint p) {
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Rect.fromLTWH(x - h, base - h * 1.4, h * 2, h * 1.4))
    ..addPath(
      Path()
        ..moveTo(x - h * .6, base)
        ..quadraticBezierTo(x - h * .7, base - h * .9, x, base - h)
        ..quadraticBezierTo(x + h * .7, base - h * .9, x + h * .6, base)
        ..close(),
      Offset.zero,
    );
  c.drawPath(path, p);
  for (var i = 0; i < 5; i++) {
    final sx = x - h * .5 + i * h * .25;
    c.drawPath(poly([Offset(sx - 8, base - h * .92), Offset(sx, base - h * .7 + (i.isOdd ? 20 : 0)), Offset(sx + 8, base - h * .92)]), p);
  }
}

/// A bat asleep upside down, hung by its feet from the roof at [top]: wings wrapped round it.
void _hangingBat(Canvas c, double x, double top, double k, Paint p) {
  c.drawLine(Offset(x - 2 * k, top), Offset(x - 2 * k, top + 5 * k), strokePaint(p.color, 1.2));
  c.drawLine(Offset(x + 2 * k, top), Offset(x + 2 * k, top + 5 * k), strokePaint(p.color, 1.2));
  c.drawOval(Rect.fromCenter(center: Offset(x, top + 13 * k), width: 11 * k, height: 18 * k), p);
  // Ears pointing down at the bottom.
  c.drawPath(poly([Offset(x - 4 * k, top + 19 * k), Offset(x - 3 * k, top + 26 * k), Offset(x - 1 * k, top + 20 * k)]), p);
  c.drawPath(poly([Offset(x + 1 * k, top + 20 * k), Offset(x + 3 * k, top + 26 * k), Offset(x + 4 * k, top + 19 * k)]), p);
}

/// A cluster of glowcaps: pale stems and caps lit from inside, a teal glow round them.
void _glowcaps(Canvas c, double x, double base, SeededRandom r) {
  const glow = Color(0xFF8AF0E0);
  c.drawCircle(Offset(x, base - 10), 44, _radial(Offset(x, base - 10), 44, glow, const [.35, .1, 0], const [0, .45, 1]));
  for (var i = 0; i < 4; i++) {
    final dx = (r.next() - .5) * 40, h = 8 + r.next() * 18, w = 8 + r.next() * 10;
    c.drawLine(Offset(x + dx, base), Offset(x + dx, base - h), strokePaint(const Color(0xFFB8D8D0), 2.2));
    c.drawPath(
      Path()
        ..moveTo(x + dx - w / 2, base - h)
        ..quadraticBezierTo(x + dx, base - h - w * .9, x + dx + w / 2, base - h)
        ..close(),
      Paint()..color = Color.lerp(glow, const Color(0xFFFFFFFF), .3)!,
    );
  }
}

void _stalagmite(Canvas c, double x, double base, double h, Paint p) {
  c.drawPath(poly([Offset(x - 40, base), Offset(x - 8, base - h), Offset(x + 6, base - h * .9), Offset(x + 40, base)]), p);
}

void _totem(Canvas c, double x, double base, double h, Paint p, double lit) {
  final w = h * .18;
  c.drawRect(Rect.fromLTWH(x - w / 2, base - h, w, h), p);
  c.drawPath(poly([Offset(x - w * 1.8, base - h * .78), Offset(x - w / 2, base - h * .7), Offset(x - w / 2, base - h * .82)]), p);
  c.drawPath(poly([Offset(x + w * 1.8, base - h * .78), Offset(x + w / 2, base - h * .7), Offset(x + w / 2, base - h * .82)]), p);
  for (final y in [.9, .55]) {
    for (final s in [-1, 1]) {
      c.drawCircle(Offset(x + s * w * .2, base - h * y), 2, Paint()..color = _lamp.withValues(alpha: .7 * lit));
    }
  }
}

void _spike(Canvas c, double x, double base, double h, double w, Paint p) {
  c.drawPath(poly([Offset(x - w / 2, base), Offset(x - w * .1, base - h), Offset(x + w * .08, base - h * .85), Offset(x + w / 2, base)]), p);
}

void _volcano(Canvas c, double x, double base, Paint p, Color glow) {
  final cone = poly([Offset(x - 330, base), Offset(x - 70, base - 200), Offset(x + 60, base - 200), Offset(x + 330, base)]);
  c.drawCircle(Offset(x, base - 210), 120, Paint()..color = const Color(0xFFFF6A2A).withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
  c.drawPath(cone, p);
  // Lava running down its face.
  for (final (dx, len) in const [(-20.0, 150.0), (30.0, 120.0), (-60.0, 90.0)]) {
    c.drawPath(
      Path()
        ..moveTo(x + dx * .3, base - 198)
        ..quadraticBezierTo(x + dx, base - 198 + len * .5, x + dx * 1.6, base - 198 + len),
      strokePaint(const Color(0xFFFF7A2A), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }
}

void _lava(Canvas c, double y) {
  final crack = Path()..moveTo(0, y + 20);
  for (var x = 0.0; x <= 960; x += 60) {
    crack.lineTo(x + 30, y + 14 + (x % 120 == 0 ? 8 : -2));
  }
  c.drawPath(crack, strokePaint(const Color(0xFFFF7A2A), 2.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
}

void _rock(Canvas c, double x, double base, double h, Paint p, SeededRandom r) {
  c.drawPath(poly([Offset(x - h * .7, base), Offset(x - h * .4, base - h * .7), Offset(x + h * .1, base - h), Offset(x + h * .6, base - h * .5), Offset(x + h * .8, base)]), p);
}

void _signpost(Canvas c, double x, double base, Paint p) {
  c.drawRect(Rect.fromLTWH(x - 3, base - 90, 6, 90), p);
  c.drawPath(poly([Offset(x - 2, base - 84), Offset(x + 48, base - 84), Offset(x + 60, base - 76), Offset(x + 48, base - 68), Offset(x - 2, base - 68)]), p);
  c.drawPath(poly([Offset(x + 2, base - 60), Offset(x - 44, base - 60), Offset(x - 54, base - 53), Offset(x - 44, base - 46), Offset(x + 2, base - 46)]), p);
}

// ---- The Sunken Sands ----

/// A pyramid, its point a little worn, the light catching its edge.
void _pyramid(Canvas c, double x, double base, double h, Paint p) {
  c.drawPath(poly([Offset(x - h * 1.3, base), Offset(x - h * .06, base - h), Offset(x + h * .06, base - h), Offset(x + h * 1.3, base)]), p);
  // Its courses: faint steps down the lit face.
  final step = Paint()..color = const Color(0x14FFE0A0);
  for (var i = 1; i < 6; i++) {
    final y = base - h + i * h / 6, w = h * 1.3 * i / 6;
    c.drawLine(Offset(x - w * .1, y), Offset(x + w, y), strokePaint(step.color, 1.2));
  }
}

void _obelisk(Canvas c, double x, double base, double h, Paint p) {
  final w = h * .13;
  c.drawPath(poly([Offset(x - w, base), Offset(x - w * .7, base - h * .9), Offset(x, base - h), Offset(x + w * .7, base - h * .9), Offset(x + w, base)]), p);
}

/// A colossal stone head half-buried in the sand, the headcloth still on it.
void _sunkHead(Canvas c, double x, double base, double h, Paint p) {
  c.drawPath(
    Path()
      ..moveTo(x - h * 1.1, base)
      ..lineTo(x - h * 1.0, base - h * .7)
      ..quadraticBezierTo(x - h * .4, base - h * 1.3, x + h * .5, base - h * 1.05)
      ..lineTo(x + h * .7, base - h * .6)
      ..lineTo(x + h * .9, base - h * .55)
      ..lineTo(x + h * .75, base - h * .3)
      ..lineTo(x + h * 1.1, base)
      ..close(),
    p,
  );
}

/// A square tomb pillar with its capital.
void _tombPillar(Canvas c, double x, double base, double h, Paint p) {
  final w = h * .12;
  c.drawRect(Rect.fromLTWH(x - w / 2, base - h, w, h), p);
  c.drawRect(Rect.fromLTWH(x - w * .8, base - h - 14, w * 1.6, 14), p);
  c.drawRect(Rect.fromLTWH(x - w * .7, base - 12, w * 1.4, 12), p);
}

/// The sealed door of a tomb: a trapezoid frame, the seal glowing faintly.
void _tombDoor(Canvas c, double x, double base, double h, Paint p, double lit) {
  final w = h * .55;
  final frame = Path()
    ..fillType = PathFillType.evenOdd
    ..addPolygon([Offset(x - w * .7, base), Offset(x - w * .55, base - h), Offset(x + w * .55, base - h), Offset(x + w * .7, base)], true)
    ..addPolygon([Offset(x - w * .4, base), Offset(x - w * .32, base - h * .75), Offset(x + w * .32, base - h * .75), Offset(x + w * .4, base)], true);
  c.drawPath(frame, p);
  c.drawRect(Rect.fromLTWH(x - w * .9, base - h - 16, w * 1.8, 16), p);
  c.drawCircle(Offset(x, base - h * .45), 26, Paint()..color = const Color(0xFF7AF0A8).withValues(alpha: .18 * lit)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  c.drawCircle(Offset(x, base - h * .45), 7, Paint()..color = const Color(0xFF7AF0A8).withValues(alpha: .55 * lit));
}
