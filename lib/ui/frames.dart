// Ornate frames for the faces on the cards: gold wings and a crown for you, and for a foe a frame
// in the style of the land it's met in (flames in the ember lands, thorns in the wilds, ice in the
// Frostmarch...). All painted, in a 100×100 box: the face sits in the middle, the ring round it,
// and the ornaments in the corners, so nothing spills out of the frame's own square.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../art/looks.dart';
import 'hud.dart' show LookPortrait, TypePortrait;

enum FrameKind { knight, ember, bog, thorn, tusk, sand, raven, forge, tide, sky, blossom, frost, laurel }

/// The frame for a foe met in continent [land] (by its place in the list).
FrameKind frameForLand(int land) => const [
  FrameKind.ember, // Cindervale
  FrameKind.bog, // The Gloomfen
  FrameKind.thorn, // The Thornwild
  FrameKind.tusk, // The Grimtusk Badlands
  FrameKind.sand, // The Sunken Sands
  FrameKind.ember, // The Cinderreach
  FrameKind.ember, // The Ember Throne
  FrameKind.raven, // Ravenmoor
  FrameKind.thorn, // The Howling Weald
  FrameKind.laurel, // The Silverwood
  FrameKind.forge, // Deepforge Hold
  FrameKind.tide, // The Isle of Mists
  FrameKind.thorn, // The Sunscale Jungle
  FrameKind.tide, // The Shattered Sea
  FrameKind.blossom, // The Changeling Isle
  FrameKind.sky, // The Skyreach Aeries
  FrameKind.blossom, // The Blossom Isles
  FrameKind.tusk, // The Hollowdeep
  FrameKind.frost, // The Frostmarch
][land.clamp(0, 18)];

/// Light, mid and dark of each frame's metal (or bone, or ice).
const _metal = {
  FrameKind.knight: [Color(0xFFFFE9A8), Color(0xFFDCA23E), Color(0xFF6E3E0C)],
  FrameKind.ember: [Color(0xFFFFD08A), Color(0xFFD2652A), Color(0xFF5A1606)],
  FrameKind.bog: [Color(0xFFC8DCA8), Color(0xFF6E8E5A), Color(0xFF223018)],
  FrameKind.thorn: [Color(0xFFD8E49A), Color(0xFF6E8A34), Color(0xFF26340E)],
  FrameKind.tusk: [Color(0xFFFBF3E0), Color(0xFFC8B088), Color(0xFF5E4C2C)],
  FrameKind.sand: [Color(0xFFFFEDB0), Color(0xFFE0AE48), Color(0xFF725014)],
  FrameKind.raven: [Color(0xFFC0B8CC), Color(0xFF5E546E), Color(0xFF16121C)],
  FrameKind.forge: [Color(0xFFE2DAD0), Color(0xFF8A8278), Color(0xFF302A26)],
  FrameKind.tide: [Color(0xFFDDF6FA), Color(0xFF5AA8C0), Color(0xFF143E4E)],
  FrameKind.sky: [Color(0xFFFFFFFF), Color(0xFFC4DAEC), Color(0xFF4E6680)],
  FrameKind.blossom: [Color(0xFFFFE6EC), Color(0xFFE09AAC), Color(0xFF702E42)],
  FrameKind.frost: [Color(0xFFF4FCFF), Color(0xFF9ACCEC), Color(0xFF2E5274)],
  FrameKind.laurel: [Color(0xFFF2F6F0), Color(0xFFAAC8B2), Color(0xFF3E5E4C)],
};

/// The jewel set at its foot.
const _gem = {
  FrameKind.knight: Color(0xFFE0302A),
  FrameKind.ember: Color(0xFFFF8A2A),
  FrameKind.bog: Color(0xFF9AE05A),
  FrameKind.thorn: Color(0xFFC03A5A),
  FrameKind.tusk: Color(0xFFB0302A),
  FrameKind.sand: Color(0xFF2ABCB0),
  FrameKind.raven: Color(0xFFB02A4A),
  FrameKind.forge: Color(0xFFFF7A2A),
  FrameKind.tide: Color(0xFF7AE0F0),
  FrameKind.sky: Color(0xFF6AB0FF),
  FrameKind.blossom: Color(0xFFB07AE0),
  FrameKind.frost: Color(0xFFBCEBFF),
  FrameKind.laurel: Color(0xFF7AD09A),
};

/// A face in a frame [size] across; the face itself fills the middle ~70%.
class OrnateFrame extends StatelessWidget {
  const OrnateFrame({super.key, required this.kind, required this.size, required this.child});
  final FrameKind kind;
  final double size;
  final Widget child;

  static const face = .6;

  @override
  Widget build(BuildContext context) {
    final f = size * face;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _FramePainter(kind, front: false)))),
          ClipOval(child: SizedBox(width: f, height: f, child: child)),
          Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _FramePainter(kind, front: true))))),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.kind, {required this.front});
  final FrameKind kind;

  /// The ring and whatever crosses over it; or (false) everything behind the face.
  final bool front;

  static const _ring = 34.0, _width = 5.5;

  List<Color> get m => _metal[kind]!;

  Paint _fill(Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [m[0], m[1], m[2], m[1]],
      stops: const [0, .35, .75, 1],
    ).createShader(r);

  Paint get _edge => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeJoin = StrokeJoin.round
    ..color = Color.lerp(m[2], Colors.black, .45)!;

  void _solid(Canvas canvas, Path p) {
    canvas.drawPath(p, _fill(p.getBounds()));
    canvas.drawPath(p, _edge);
  }

  static Offset _polar(double a, double r) => Offset(math.cos(a), math.sin(a)) * r;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.translate(50, 50);
    final s = _style;
    if (front) {
      _ringOf(canvas);
      s.front?.call(canvas);
    } else {
      s.back(canvas);
    }
    canvas.restore();
  }

  // ---- each frame: what goes behind the face and ring, and what crosses over the ring --------------

  ({void Function(Canvas) back, void Function(Canvas)? front}) get _style => switch (kind) {
    // A golden dragon coiled the whole way round, its head at the top, its tail tufted in flame.
    FrameKind.knight => (
      back: (c) => _serpent(c, _knightCoil, over: false),
      front: (c) {
        _serpent(c, _knightCoil, over: true);
        _dragonHead(c, _knightCoil, eye: const Color(0xFFFF3A2A));
      },
    ),
    // Flames licking up all the way round, tallest at the top.
    FrameKind.ember => (back: _flames, front: (c) => _jewel(c, const Offset(0, _ring + 1))),
    // A fen eel wound round, dripping.
    FrameKind.bog => (
      back: (c) {
        _drips(c);
        _serpent(c, _eelCoil, over: false);
      },
      front: (c) {
        _serpent(c, _eelCoil, over: true);
        _snakeHead(c, _eelCoil, eye: const Color(0xFFE8E05A), tongue: true);
      },
    ),
    // A thorned vine wound round, in leaf.
    FrameKind.thorn => (
      back: (c) {
        _vine(c, thorns: true);
        _serpent(c, _vineCoil, over: false);
      },
      front: (c) {
        _serpent(c, _vineCoil, over: true);
        _jewel(c, const Offset(0, _ring + 1));
      },
    ),
    // A ring of bone: ribs all round and great tusks below.
    FrameKind.tusk => (back: _bones, front: (c) => _jewel(c, const Offset(0, _ring + 1))),
    // A cobra coiled round a sun-disc.
    FrameKind.sand => (
      back: (c) {
        _rays(c);
        _serpent(c, _cobraCoil, over: false);
      },
      front: (c) {
        _serpent(c, _cobraCoil, over: true);
        _snakeHead(c, _cobraCoil, eye: const Color(0xFFFF4A3A), hood: true);
      },
    ),
    // Black feathers the whole way round, a beak at the top.
    FrameKind.raven => (back: (c) => _feathers(c, wings: false), front: (c) => _jewel(c, const Offset(0, _ring + 1))),
    // An iron chain round a riveted ring.
    FrameKind.forge => (back: (c) => _chain(c, over: false), front: (c) => _chain(c, over: true)),
    // A sea serpent rising through the waves.
    FrameKind.tide => (
      back: (c) {
        _waves(c);
        _serpent(c, _seaCoil, over: false);
      },
      front: (c) {
        _serpent(c, _seaCoil, over: true);
        _snakeHead(c, _seaCoil, eye: const Color(0xFFFFE07A), crest: true);
      },
    ),
    // White feathers round, and wings spread.
    FrameKind.sky => (back: (c) => _feathers(c, wings: true), front: (c) => _jewel(c, const Offset(0, _ring + 1))),
    // A flowering vine wound round.
    FrameKind.blossom => (
      back: (c) {
        _vine(c, thorns: false);
        _serpent(c, _vineCoil, over: false);
      },
      front: (c) {
        _serpent(c, _vineCoil, over: true);
        for (final a in [-90.0, -30.0, 30.0, 150.0, 210.0]) {
          _flower(c, _polar(a * math.pi / 180, _ring + 4), a == -90 ? 6.5 : 5);
        }
      },
    ),
    // An ice wyrm coiled round, shards of rime behind.
    FrameKind.frost => (
      back: (c) {
        _shards(c);
        _serpent(c, _wyrmCoil, over: false);
      },
      front: (c) {
        _serpent(c, _wyrmCoil, over: true);
        _dragonHead(c, _wyrmCoil, eye: const Color(0xFF7AF0FF));
      },
    ),
    // A laurel wreath, all the way round.
    FrameKind.laurel => (back: _laurel, front: (c) => _jewel(c, const Offset(0, _ring + 1))),
  };

  // ---- the ring --------------------------------------------------------------------------------------

  void _ringOf(Canvas canvas) {
    final ring = Rect.fromCircle(center: Offset.zero, radius: _ring);
    canvas.drawCircle(
      Offset.zero,
      _ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [m[0], m[1], m[2], m[1], m[0]], stops: const [0, .3, .6, .85, 1]).createShader(ring.inflate(4)),
    );
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Color.lerp(m[2], Colors.black, .45)!;
    canvas.drawCircle(Offset.zero, _ring + _width / 2, dark);
    canvas.drawCircle(Offset.zero, _ring - _width / 2, dark);
    // A fine inner bead line, and a glint top left.
    canvas.drawCircle(Offset.zero, _ring, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = m[0].withValues(alpha: .7));
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: _ring + 1.2), math.pi * 1.05, math.pi * .45, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .65));
    if (kind == FrameKind.forge) {
      for (var i = 0; i < 12; i++) {
        final at = _polar(i * math.pi / 6 + math.pi / 12, _ring);
        canvas.drawCircle(at, 1.7, Paint()..color = m[2]);
        canvas.drawCircle(at - const Offset(.4, .4), 1, Paint()..color = const Color(0xFFE8A060));
      }
    }
  }

  void _jewel(Canvas canvas, Offset at) {
    final setting = Path()
      ..moveTo(at.dx, at.dy - 6.5)
      ..lineTo(at.dx + 6, at.dy)
      ..lineTo(at.dx, at.dy + 6.5)
      ..lineTo(at.dx - 6, at.dy)
      ..close();
    _solid(canvas, setting);
    final g = _gem[kind]!;
    final stone = Rect.fromCenter(center: at, width: 6.4, height: 7.4);
    canvas.drawOval(stone, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.5), colors: [Color.lerp(g, Colors.white, .7)!, g, Color.lerp(g, Colors.black, .55)!], stops: const [0, .45, 1]).createShader(stone));
  }

  // ---- coils: a body wound round the ring, crossing over and under it --------------------------------

  /// Where a coil starts (its head), how far round it runs, how many times it crosses the ring,
  /// how thick it is at the neck, and whether it has a crest of fins along its back.
  static const _knightCoil = (start: -1.15, sweep: 5.3, waves: 4, thick: 10.5, fins: true, tail: true);
  static const _wyrmCoil = (start: -1.99, sweep: -5.3, waves: 4, thick: 10.0, fins: true, tail: true);
  static const _eelCoil = (start: -1.9, sweep: 5.6, waves: 5, thick: 6.5, fins: false, tail: false);
  static const _cobraCoil = (start: -1.57, sweep: 5.9, waves: 4, thick: 6.5, fins: false, tail: false);
  static const _seaCoil = (start: -1.25, sweep: 5.3, waves: 4, thick: 7.5, fins: true, tail: true);
  static const _vineCoil = (start: -1.57, sweep: 6.28, waves: 7, thick: 2.6, fins: false, tail: false);

  /// The coil's centre line at [s] (0 the head, 1 the tail tip): it weaves out from the ring and
  /// back across it.
  static Offset _coilAt(({double start, double sweep, int waves, double thick, bool fins, bool tail}) c, double s) {
    final a = c.start + c.sweep * s;
    return _polar(a, _ring + 5.5 + 5.5 * math.sin(c.waves * 2 * math.pi * s));
  }

  /// Whether the coil is crossing over the ring at [s] (the inward half of each weave).
  static bool _isOver(({double start, double sweep, int waves, double thick, bool fins, bool tail}) c, double s) => math.sin(c.waves * 2 * math.pi * s) < -.15;

  void _serpent(Canvas canvas, ({double start, double sweep, int waves, double thick, bool fins, bool tail}) c, {required bool over}) {
    const n = 160;
    double half(double s) => c.thick / 2 * (1 - .62 * s);
    final pts = [for (var i = 0; i <= n; i++) _coilAt(c, i / n)];
    Offset normal(int i) {
      final d = pts[math.min(n, i + 1)] - pts[math.max(0, i - 1)];
      final l = d.distance == 0 ? 1.0 : d.distance;
      return Offset(-d.dy / l, d.dx / l);
    }

    // Draw it in runs: all of it behind the ring, or (over) just the runs crossing over the ring.
    var i = 0;
    while (i < n) {
      if (over && !_isOver(c, i / n)) {
        i++;
        continue;
      }
      var j = i;
      while (j < n && (!over || _isOver(c, j / n))) {
        j++;
      }
      final a = math.max(0, i - 1), b = math.min(n, j + 1);
      final left = <Offset>[], right = <Offset>[];
      for (var k = a; k <= b; k++) {
        final w = half(k / n), nn = normal(k);
        left.add(pts[k] + nn * w);
        right.add(pts[k] - nn * w);
      }
      final body = Path()..addPolygon([...left, ...right.reversed], true);
      _solid(canvas, body);
      // A paler belly along the inner side.
      final inward = c.sweep > 0 ? 1.0 : -1.0;
      final belly = <Offset>[for (var k = a; k <= b; k++) pts[k] - normal(k) * half(k / n) * inward * .1];
      final bellyEdge = <Offset>[for (var k = a; k <= b; k++) pts[k] + normal(k) * half(k / n) * inward * .85];
      if (c.thick > 5) canvas.drawPath(Path()..addPolygon([...belly, ...bellyEdge.reversed], true), Paint()..color = m[0].withValues(alpha: .45));
      // Scales: little arcs across the body, and a light line down its back.
      final scale = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = Color.lerp(m[2], Colors.black, .25)!.withValues(alpha: .85);
      // Scales: overlapping chevrons pointing down the body, in two staggered rows.
      for (var k = a + 2; k < b - 2; k += 3) {
        final w = half(k / n), nn = normal(k), along = pts[k + 1] - pts[k];
        final dir = along / (along.distance == 0 ? 1 : along.distance);
        for (final row in [-.45, .45]) {
          final o = pts[k] + nn * w * row + dir * (row > 0 ? 1.0 : 0);
          final sw = w * .42;
          canvas.drawPath(
            Path()
              ..moveTo((o + nn * sw).dx, (o + nn * sw).dy)
              ..quadraticBezierTo((o + dir * 2.4).dx, (o + dir * 2.4).dy, (o - nn * sw).dx, (o - nn * sw).dy),
            scale,
          );
        }
      }
      canvas.drawPoints(
        ui.PointMode.polygon,
        [for (var k = a; k <= b; k++) pts[k] + normal(k) * half(k / n) * .45],
        Paint()
          ..strokeWidth = .7
          ..color = m[0].withValues(alpha: .8),
      );
      // A crest of fins along the outside of its back.
      if (c.fins && !over) {
        for (var k = a + 3; k < b - 3 && k < n * .9; k += 5) {
          final p = pts[k], out = p / p.distance, w = half(k / n);
          final along = pts[k + 3] - pts[k];
          final spike = 3 + 5 * (1 - k / n);
          final fin = Path()
            ..moveTo((p + out * w * .5 - along * .3).dx, (p + out * w * .5 - along * .3).dy)
            ..quadraticBezierTo((p + out * (w + spike * .6)).dx, (p + out * (w + spike * .6)).dy, (p + out * (w + spike) + along * 1.1).dx, (p + out * (w + spike) + along * 1.1).dy)
            ..lineTo((p + out * w * .5 + along * .7).dx, (p + out * w * .5 + along * .7).dy)
            ..close();
          _solid(canvas, fin);
        }
      }
      i = j + 1;
    }
    // The tail: a tuft of flame (or a finned fluke) at its tip.
    if (c.tail && (over == _isOver(c, 1))) {
      final tip = pts[n], d = pts[n] - pts[n - 4], ang = math.atan2(d.dy, d.dx);
      for (final (da, len) in [(-.7, 10.0), (-.25, 14.0), (.25, 14.0), (.7, 10.0)]) {
        _solid(canvas, _leaf(tip, ang + da, len, 3.2));
      }
    }
  }

  /// Which way a coil's head faces: back along its body, turned out from the ring.
  ({Offset at, double angle}) _headPose(({double start, double sweep, int waves, double thick, bool fins, bool tail}) c) {
    final at = _coilAt(c, 0), next = _coilAt(c, .01);
    final back = (at - next) / (at - next).distance, out = at / at.distance;
    final d = back + out * .35;
    return (at: at, angle: math.atan2(d.dy, d.dx));
  }

  /// Turns the canvas to draw a head facing +x at the coil's start, kept upright.
  void _atHead(Canvas canvas, ({double start, double sweep, int waves, double thick, bool fins, bool tail}) c, double size, void Function() draw) {
    final pose = _headPose(c);
    canvas.save();
    canvas.translate(pose.at.dx, pose.at.dy);
    canvas.rotate(pose.angle);
    if (math.cos(pose.angle) < 0) canvas.scale(1, -1);
    canvas.scale(size / 16);
    draw();
    canvas.restore();
  }

  void _dragonHead(Canvas canvas, ({double start, double sweep, int waves, double thick, bool fins, bool tail}) c, {required Color eye}) {
    _atHead(canvas, c, 25, () {
      // Horns swept back, then the skull, the open jaw and its teeth.
      for (final (bx, tx, ty) in [(1.0, -12.0, -12.0), (3.5, -7.0, -15.0)]) {
        final horn = Path()
          ..moveTo(bx - 1.5, -4)
          ..quadraticBezierTo((bx + tx) / 2, -8.5, tx, ty)
          ..quadraticBezierTo((bx + tx) / 2 + 2, -6.5, bx + 2, -4.2)
          ..close();
        _solid(canvas, horn);
      }
      final jaw = Path()
        ..moveTo(-3, 2.5)
        ..lineTo(6, 2.2)
        ..lineTo(13.5, 4.8)
        ..lineTo(12.5, 6.4)
        ..lineTo(4, 6.2)
        ..quadraticBezierTo(-1, 6.2, -4, 4.5)
        ..close();
      _solid(canvas, jaw);
      final skull = Path()
        ..moveTo(-5, -3.5)
        ..quadraticBezierTo(0, -6.5, 5, -5)
        ..lineTo(9, -3.6)
        ..quadraticBezierTo(14, -2.6, 16, -.6)
        ..lineTo(15.6, 1.4)
        ..lineTo(7, 2.4)
        ..lineTo(-4, 3)
        ..close();
      _solid(canvas, skull);
      final white = Paint()..color = const Color(0xFFF6F0E0);
      for (final x in [8.0, 10.5, 13.0]) {
        canvas.drawPath(Path()
          ..moveTo(x, 2.2)
          ..lineTo(x + .7, 3.9)
          ..lineTo(x + 1.4, 2.1)
          ..close(), white);
      }
      // The brow ridge over a glowing eye, and a nostril.
      canvas.drawCircle(const Offset(5.6, -1.6), 2.6, Paint()..color = eye.withValues(alpha: .35));
      canvas.drawOval(Rect.fromCenter(center: const Offset(5.6, -1.6), width: 3.2, height: 2), Paint()..color = eye);
      canvas.drawLine(const Offset(5.6, -2.5), const Offset(5.6, -.7), Paint()
        ..strokeWidth = .6
        ..color = Colors.black);
      canvas.drawLine(const Offset(2.5, -3.6), const Offset(8.5, -2.8), _edge..strokeWidth = .9);
      canvas.drawCircle(const Offset(14.4, -1), .6, Paint()..color = Colors.black54);
      // A frill of spikes down the back of the head.
      for (final (x, y) in [(-4.0, -3.0), (-5.5, -.5), (-5.5, 2.0)]) {
        _solid(canvas, Path()
          ..moveTo(x + 1.5, y - 1)
          ..lineTo(x - 3.2, y - .2)
          ..lineTo(x + 1.5, y + 1.2)
          ..close());
      }
    });
  }

  void _snakeHead(Canvas canvas, ({double start, double sweep, int waves, double thick, bool fins, bool tail}) c, {required Color eye, bool hood = false, bool tongue = false, bool crest = false}) {
    _atHead(canvas, c, 16, () {
      if (hood) {
        // A cobra's hood, spread behind the head.
        final h = Path()
          ..moveTo(-6, 0)
          ..quadraticBezierTo(-5, -11, 4, -7)
          ..lineTo(4, 7)
          ..quadraticBezierTo(-5, 11, -6, 0)
          ..close();
        _solid(canvas, h);
        canvas.drawPath(Path()
          ..moveTo(-2, -4)
          ..quadraticBezierTo(0, 0, -2, 4), _edge..strokeWidth = .7);
      }
      if (crest) {
        for (final x in [-3.0, 0.0, 3.0]) {
          _solid(canvas, Path()
            ..moveTo(x - 1.5, -3)
            ..lineTo(x - 3.5, -9)
            ..lineTo(x + 2, -3.4)
            ..close());
        }
      }
      if (tongue) {
        canvas.drawPath(Path()
          ..moveTo(12, .5)
          ..lineTo(17, .5)
          ..lineTo(19, -1)
          ..moveTo(17, .5)
          ..lineTo(19, 2), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0xFFD02A3A));
      }
      final head = Path()
        ..moveTo(-3, -3.5)
        ..quadraticBezierTo(4, -6, 10, -3.2)
        ..quadraticBezierTo(14, -1.5, 13.5, .8)
        ..quadraticBezierTo(12, 3.6, 6, 4)
        ..quadraticBezierTo(0, 4.4, -3, 3.5)
        ..close();
      _solid(canvas, head);
      canvas.drawCircle(const Offset(6.5, -1.5), 2.2, Paint()..color = eye.withValues(alpha: .35));
      canvas.drawOval(Rect.fromCenter(center: const Offset(6.5, -1.5), width: 2.8, height: 1.8), Paint()..color = eye);
      canvas.drawLine(const Offset(6.5, -2.3), const Offset(6.5, -.7), Paint()
        ..strokeWidth = .5
        ..color = Colors.black);
      canvas.drawLine(const Offset(9, 1.6), const Offset(13, .8), _edge..strokeWidth = .6);
    });
  }

  // ---- wreaths and the rest -------------------------------------------------------------------------

  /// A feather (or leaf) from [base], pointing along [angle], [len] long and [w] wide.
  Path _leaf(Offset base, double angle, double len, double w) {
    final d = Offset(math.cos(angle), math.sin(angle)), n = Offset(-d.dy, d.dx);
    final tip = base + d * len;
    final a = base + d * len * .45 + n * w, b = base + d * len * .55 - n * w * .8;
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(a.dx, a.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(b.dx, b.dy, base.dx, base.dy)
      ..close();
  }

  /// Leaves (or feathers) all the way round: up each side from the foot to the crown, each one
  /// pointing on round the ring, alternately out and in.
  void _wreath(Canvas canvas, {required int perSide, required double len, required double w, double r = _ring + 4, double splay = .55}) {
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < perSide; i++) {
        final a = math.pi / 2 - side * (.18 + i * (math.pi - .3) / perSide);
        final at = _polar(a, r);
        final along = a - side * math.pi / 2;
        final outward = i.isEven ? 1.0 : -.4;
        _solid(canvas, _leaf(at, along - side * splay * outward, len, w));
      }
    }
  }

  void _laurel(Canvas canvas) {
    _wreath(canvas, perSide: 10, len: 13, w: 3.8, splay: .7);
    _wreath(canvas, perSide: 9, len: 10, w: 3, r: _ring + 9, splay: .3);
  }

  void _feathers(Canvas canvas, {required bool wings}) {
    if (wings) {
      // Wings spread from the shoulders.
      for (final side in [-1.0, 1.0]) {
        for (var i = 5; i >= 0; i--) {
          final a = (-62 + i * 15) * math.pi / 180;
          _solid(canvas, _leaf(Offset(side * 24, -16 + i * 4.0), side > 0 ? a : math.pi - a, 30 - i * 3.0, 4.6));
        }
      }
    }
    _wreath(canvas, perSide: 11, len: 15, w: 3.4, splay: 1);
    if (!wings) {
      final beak = Path()
        ..moveTo(-6, -_ring + 1)
        ..quadraticBezierTo(0, -_ring - 8, 0, -_ring - 15)
        ..quadraticBezierTo(2, -_ring - 7, 6, -_ring + 1)
        ..close();
      _solid(canvas, beak);
    }
  }

  void _flames(Canvas canvas) {
    // Flames all the way round, tallest over the crown.
    for (var i = 0; i < 20; i++) {
      final a = i * math.pi * 2 / 20 - math.pi / 2;
      final up = (1 - math.sin(a)) / 2;
      _flame(canvas, _polar(a, _ring + 1), a + math.pi / 2, 8 + 9 * up + (i.isEven ? 2 : 0), 4 + 1.5 * up);
    }
  }

  void _flame(Canvas canvas, Offset at, double angle, double len, double w) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final outer = Path()
      ..moveTo(-w, 2)
      ..cubicTo(-w * 1.1, -len * .45, -w * .1, -len * .55, w * .25, -len)
      ..cubicTo(w * .2, -len * .65, w * 1.2, -len * .45, w, 2)
      ..close();
    _solid(canvas, outer);
    final inner = Path()
      ..moveTo(-w * .45, 1)
      ..cubicTo(-w * .5, -len * .3, 0, -len * .4, w * .1, -len * .62)
      ..cubicTo(w * .25, -len * .4, w * .55, -len * .3, w * .45, 1)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFE08A).withValues(alpha: .85));
    canvas.restore();
  }

  void _drips(Canvas canvas) {
    for (final (a, l) in [(70.0, 9.0), (100.0, 12.0), (130.0, 7.0), (40.0, 6.0)]) {
      final at = _polar(a * math.pi / 180, _ring + 2);
      final p = Path()
        ..moveTo(at.dx - 2.2, at.dy)
        ..quadraticBezierTo(at.dx - 3, at.dy + l, at.dx, at.dy + l + 2.5)
        ..quadraticBezierTo(at.dx + 3, at.dy + l, at.dx + 2.2, at.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFF8AC05A));
      canvas.drawPath(p, _edge);
    }
  }

  void _vine(Canvas canvas, {required bool thorns}) {
    // Leaves (and thorns) along the vine, all the way round.
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 + .2;
      final at = _polar(a, _ring + 6);
      final along = a + math.pi / 2;
      if (thorns) {
        final out = at / at.distance, nn = Offset(-out.dy, out.dx);
        final t = Path()
          ..moveTo((at + nn * 2).dx, (at + nn * 2).dy)
          ..lineTo((at + out * 8 - nn * 1.5).dx, (at + out * 8 - nn * 1.5).dy)
          ..lineTo((at - nn * 2).dx, (at - nn * 2).dy)
          ..close();
        _solid(canvas, t);
      }
      if (i.isEven) {
        canvas.drawPath(_leaf(at, along + .9, 10, 3.6), Paint()..color = thorns ? const Color(0xFF6A9A3A) : const Color(0xFF7AB05A));
        canvas.drawPath(_leaf(at, along + .9, 10, 3.6), _edge);
      }
    }
  }

  void _bones(Canvas canvas) {
    // Ribs all the way round, curving the same way, and two great tusks below.
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi * 2 / 18;
      final base = _polar(a, _ring + 1), tip = _polar(a + .22, _ring + 11), mid = _polar(a + .05, _ring + 7);
      final nn = Offset(-math.sin(a), math.cos(a));
      final rib = Path()
        ..moveTo((base + nn * 2).dx, (base + nn * 2).dy)
        ..quadraticBezierTo((mid + nn * 1.2).dx, (mid + nn * 1.2).dy, tip.dx, tip.dy)
        ..quadraticBezierTo((mid - nn * 1.6).dx, (mid - nn * 1.6).dy, (base - nn * 2).dx, (base - nn * 2).dy)
        ..close();
      _solid(canvas, rib);
    }
    for (final side in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(side * 16, 33)
        ..cubicTo(side * 44, 42, side * 52, 10, side * 44, -18)
        ..cubicTo(side * 43, 2, side * 36, 24, side * 12, 27)
        ..close();
      _solid(canvas, p);
      final horn = Path()
        ..moveTo(side * 10, -_ring + 1)
        ..quadraticBezierTo(side * 20, -_ring - 9, side * 26, -_ring - 13)
        ..quadraticBezierTo(side * 23, -_ring - 2, side * 21, -_ring + 6)
        ..close();
      _solid(canvas, horn);
    }
  }

  void _rays(Canvas canvas) {
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
      final len = i.isEven ? 15.0 : 10.0, w = i.isEven ? 2.6 : 2.0;
      final base = d * (_ring + 1);
      _solid(canvas, Path()
        ..moveTo((base + n * w).dx, (base + n * w).dy)
        ..lineTo((d * (_ring + len)).dx, (d * (_ring + len)).dy)
        ..lineTo((base - n * w).dx, (base - n * w).dy)
        ..close());
    }
  }

  void _chain(Canvas canvas, {required bool over}) {
    // Iron links all round: flat ones lie under the ring, the upright ones cross over it.
    if (!over) {
      final plate = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 90, height: 90), const Radius.circular(8));
      _solid(canvas, Path()..addRRect(plate));
      for (final cn in [const Offset(-39, -39), const Offset(39, -39), const Offset(-39, 39), const Offset(39, 39)]) {
        canvas.drawCircle(cn, 2.6, Paint()..color = m[2]);
        canvas.drawCircle(cn - const Offset(.6, .6), 1.5, Paint()..color = const Color(0xFFE8A060));
      }
    }
    for (var i = 0; i < 16; i++) {
      if (i.isEven == over) continue;
      final a = i * math.pi / 8;
      canvas.save();
      final at = _polar(a, _ring + (over ? 0 : 1));
      canvas.translate(at.dx, at.dy);
      canvas.rotate(a + math.pi / 2);
      final link = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 12, height: over ? 5 : 7.5), const Radius.circular(3.5));
      canvas.drawRRect(link, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = Color.lerp(m[2], Colors.black, .3)!);
      canvas.drawRRect(link, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(colors: [m[0], m[1], m[2]]).createShader(link.outerRect));
      canvas.restore();
    }
  }

  void _waves(Canvas canvas) {
    for (final side in [-1.0, 1.0]) {
      for (final (y, sc) in [(30.0, 1.0), (14.0, .8)]) {
        canvas.save();
        canvas.translate(side * 34, y);
        canvas.scale(side * sc, sc);
        final p = Path()
          ..moveTo(-14, 8)
          ..cubicTo(4, 14, 16, 0, 8, -8)
          ..cubicTo(4, -12, -2, -8, 2, -4)
          ..cubicTo(5, 0, 2, 4, -8, 4)
          ..close();
        _solid(canvas, p);
        canvas.restore();
      }
    }
  }

  void _flower(Canvas canvas, Offset at, double r) {
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final p = _leaf(at, a, r * 1.4, r * .6);
      canvas.drawPath(p, Paint()..shader = RadialGradient(colors: [Colors.white, m[1]]).createShader(Rect.fromCircle(center: at, radius: r * 1.4)));
      canvas.drawPath(p, _edge..strokeWidth = .6);
    }
    canvas.drawCircle(at, r * .32, Paint()..color = const Color(0xFFFFE08A));
  }

  void _shards(Canvas canvas) {
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 + .1;
      final len = i.isEven ? 15.0 : 10.0, w = i.isEven ? 3.6 : 2.8;
      final d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
      final base = d * (_ring + 1);
      final p = Path()
        ..moveTo((base + n * w).dx, (base + n * w).dy)
        ..lineTo((base + d * len * .7 + n * w * .5).dx, (base + d * len * .7 + n * w * .5).dy)
        ..lineTo((base + d * len).dx, (base + d * len).dy)
        ..lineTo((base + d * len * .7 - n * w * .5).dx, (base + d * len * .7 - n * w * .5).dy)
        ..lineTo((base - n * w).dx, (base - n * w).dy)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFCFEFFF).withValues(alpha: .85));
      canvas.drawPath(p, _edge..strokeWidth = .7);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.kind != kind || old.front != front;
}

/// `?frames`: every land's frame round its boss, and yours, side by side (a dev check).
class FramesPreview extends StatelessWidget {
  const FramesPreview({super.key});
  @override
  Widget build(BuildContext context) => Uri.base.queryParameters.containsKey('vets')
      // ?frames&vets: foes as they are, tough and deadly, side by side.
      ? Scaffold(
          backgroundColor: const Color(0xFF1A1510),
          body: SingleChildScrollView(
            child: Column(children: [
              for (final look in ['pillager', 'goblin', 'ork', 'zombie', 'duneRaider', 'skeletonArcher'])
                if (foeLooks[look] != null)
                  Row(children: [
                    for (var t = 0; t < 3; t++) SizedBox(width: 130, height: 160, child: LookPortrait(look: foeLooks[look]!.veteran(t))),
                  ]),
            ]),
          ),
        )
      : Uri.base.queryParameters.containsKey('big')
      // ?frames&big: a few up close.
      ? Scaffold(
          backgroundColor: const Color(0xFF1A1510),
          body: Wrap(children: [
            for (final k in [FrameKind.knight, FrameKind.frost, FrameKind.sand, FrameKind.tide])
              Padding(padding: const EdgeInsets.all(8), child: OrnateFrame(kind: k, size: 380, child: Container(color: const Color(0xFF5A5E66)))),
          ]),
        )
      : Scaffold(
    backgroundColor: const Color(0xFF1A1510),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (i, l) in continents.indexed)
            Column(mainAxisSize: MainAxisSize.min, children: [
              OrnateFrame(kind: frameForLand(i), size: 110, child: Container(color: const Color(0xFF5A5E66), child: TypePortrait(type: l.boss))),
              SizedBox(width: 110, child: Text(l.name.replaceFirst('The ', ''), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10))),
            ]),
          for (final k in FrameKind.values)
            Column(mainAxisSize: MainAxisSize.min, children: [
              OrnateFrame(kind: k, size: 110, child: Container(color: const Color(0xFF5A5E66))),
              Text(k.name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
        ],
      ),
    ),
  );
}
