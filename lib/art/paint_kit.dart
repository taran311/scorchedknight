// Low-level drawing helpers shared by every character: shaded limb capsules, outlined fills,
// colour ramps and a small SVG path parser for the hand-authored shapes.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

const double deg = math.pi / 180;
const Color outline = Color(0xE6100B07);

/// A three-stop colour ramp: highlight, base, shadow.
typedef Ramp = List<Color>;

Color shade(Color c, double f) {
  final t = f < 0 ? 0.0 : 1.0, p = f.abs();
  double mix(double ch) => (t - ch) * p + ch;
  return Color.from(alpha: c.a, red: mix(c.r), green: mix(c.g), blue: mix(c.b));
}

Ramp ramp(int argb, [double light = .32, double dark = .45]) {
  final c = Color(argb);
  return [shade(c, light), c, shade(c, -dark)];
}

Ramp rampOf(Color c, [double light = .32, double dark = .45]) => [shade(c, light), c, shade(c, -dark)];

Ramp darker(Ramp r) => [shade(r[0], -.22), shade(r[1], -.22), shade(r[2], -.15)];

Offset polar(double angleDeg, double len) => Offset(math.sin(angleDeg * deg) * len, math.cos(angleDeg * deg) * len);

final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..color = outline
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

Paint _linearFill(Ramp col, Offset a, Offset b) => Paint()..shader = ui.Gradient.linear(a, b, col, const [0, .5, 1]);

/// Fill [path] with a ramp running from [a] to [b] (or a flat colour) and outline it.
void fillPath(Canvas c, Path path, Object col, Offset a, Offset b, {bool line = true, double width = 1.4}) {
  final paint = col is Ramp ? _linearFill(col, a, b) : (Paint()..color = col as Color);
  c.drawPath(path, paint);
  if (line) c.drawPath(path, _stroke..strokeWidth = width);
}

/// A tapered capsule from [a] (radius [ra]) to [b] (radius [rb]), shaded across its width so it reads
/// as a rounded limb. The rounded ends are the joints.
Path capsulePath(Offset a, double ra, Offset b, double rb) {
  final d = b - a, len = d.distance;
  final path = Path();
  if (len < .5) {
    path.addOval(Rect.fromCircle(center: a, radius: math.max(ra, rb)));
  } else {
    final ang = math.atan2(d.dy, d.dx);
    final al = math.acos(((ra - rb) / len).clamp(-1.0, 1.0));
    path.arcTo(Rect.fromCircle(center: a, radius: ra), ang + al, math.pi * 2 - 2 * al, true);
    path.arcTo(Rect.fromCircle(center: b, radius: rb), ang - al, 2 * al, false);
    path.close();
  }
  return path;
}

Paint _capsuleFill(Offset a, Offset b, double r, Ramp col) {
  final d = b - a, len = d.distance;
  var n = Offset(-d.dy, d.dx) / (len == 0 ? 1 : len);
  if (n.dx * -.55 + n.dy * -.83 < 0) n = -n; // light from the upper left
  final mid = (a + b) / 2;
  return Paint()..shader = ui.Gradient.linear(mid + n * r, mid - n * r, col, const [0, .45, 1]);
}

void capsule(Canvas c, Offset a, double ra, Offset b, double rb, Ramp col, {bool line = true}) {
  final path = capsulePath(a, ra, b, rb);
  c.drawPath(path, _capsuleFill(a, b, math.max(ra, rb), col));
  if (line) c.drawPath(path, _stroke..strokeWidth = 1.4);
}

/// A jointed limb drawn as one piece: every segment's outline first, then every fill on top, so
/// no seam shows where the upper and lower parts meet. [joints] are (point, radius) from the
/// root to the tip; [cols] has one ramp per segment.
///
/// With [bulge], each segment swells with a muscle belly a third of the way down (more on the
/// back of the limb: hamstring, calf, triceps) instead of being a straight tube, and catches a
/// soft sheen along its lit side.
void limb(Canvas c, List<(Offset, double)> joints, List<Ramp> cols, {double bulge = 0}) {
  final paths = [
    for (var i = 0; i + 1 < joints.length; i++)
      bulge > 0 ? musclePath(joints[i].$1, joints[i].$2, joints[i + 1].$1, joints[i + 1].$2, bulge * (i == joints.length - 2 && joints.length > 3 ? .3 : 1)) : capsulePath(joints[i].$1, joints[i].$2, joints[i + 1].$1, joints[i + 1].$2),
  ];
  for (final p in paths) {
    c.drawPath(p, _stroke..strokeWidth = 2.6);
  }
  for (var i = 0; i < paths.length; i++) {
    c.drawPath(paths[i], _capsuleFill(joints[i].$1, joints[i + 1].$1, math.max(joints[i].$2, joints[i + 1].$2) * (1 + bulge), cols[i]));
  }
  if (bulge > 0) {
    // A sheen down the lit side of each part, and a darker core down the shadowed side: plain
    // translucent strokes kept inside the outline (no blur or clipping, which cost every frame).
    for (var i = 0; i < paths.length; i++) {
      final (a, ra) = joints[i];
      final (b, rb) = joints[i + 1];
      final d = b - a, len = d.distance;
      if (len < 2) continue;
      var n = Offset(-d.dy, d.dx) / len;
      if (n.dx * -.55 + n.dy * -.83 < 0) n = -n;
      final u = d / len;
      c.drawLine(a + u * ra * .7 + n * ra * .45, b - u * rb * .7 + n * rb * .45, Paint()
        ..color = shade(cols[i][0], .25).withValues(alpha: .35)
        ..strokeWidth = math.max(1.2, (ra + rb) * .14)
        ..strokeCap = StrokeCap.round);
      c.drawLine(a + u * ra * .5 - n * ra * .7, b - u * rb * .5 - n * rb * .7, Paint()
        ..color = shade(cols[i][2], -.3).withValues(alpha: .3)
        ..strokeWidth = math.max(1.5, (ra + rb) * .2)
        ..strokeCap = StrokeCap.round);
    }
  }
  // A soft crease at each bend, where the parts fold.
  for (var i = 1; i + 1 < joints.length; i++) {
    final (p, r) = joints[i];
    final d = joints[i + 1].$1 - joints[i - 1].$1, len = d.distance;
    if (len < 1) continue;
    final n = Offset(-d.dy, d.dx) / len;
    c.drawLine(p + n * r * .55, p - n * r * .1, Paint()..color = const Color(0x2E000000)..strokeWidth = 1.1..strokeCap = StrokeCap.round);
  }
}

/// A limb segment with a muscle belly: wider a third of the way down, mostly on the back side, with
/// rounded joints at both ends.
Path musclePath(Offset a, double ra, Offset b, double rb, double bulge) {
  final d = b - a, len = d.distance;
  if (len < 1) return capsulePath(a, ra, b, rb);
  final u = d / len, n = Offset(-u.dy, u.dx);
  const steps = 14;
  final back = <Offset>[], front = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps, w = ra + (rb - ra) * t;
    final belly = math.exp(-math.pow((t - .36) / .26, 2).toDouble());
    final p = a + d * t;
    back.add(p + n * w * (1 + bulge * belly));
    front.add(p - n * w * (1 + bulge * .35 * belly));
  }
  // One outline: down the back, round the far joint, up the front and round the near joint.
  // (Built as a single contour rather than a union of shapes, which is slow to do every frame.)
  final path = Path()..moveTo(back.first.dx, back.first.dy);
  for (final q in back.skip(1)) {
    path.lineTo(q.dx, q.dy);
  }
  path.arcToPoint(front.last, radius: Radius.circular(rb), clockwise: false);
  for (final q in front.reversed.skip(1)) {
    path.lineTo(q.dx, q.dy);
  }
  path.arcToPoint(back.first, radius: Radius.circular(ra), clockwise: false);
  return path..close();
}

void blob(Canvas c, Offset p, double r, Ramp col, {bool line = true}) => capsule(c, p, r, p + const Offset(.01, 0), r, col, line: line);

void strokeLine(Canvas c, Offset a, Offset b, Color color, double width) {
  c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

Paint strokePaint(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..color = color
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Chainmail texture: rows of small rings clipped to [path].
/// With [glint], each ring also catches a little light on its top edge (for dark mail).
void mailTexture(Canvas c, Path path, {Color? glint}) {
  // Interlocking rings in offset rows, each a dark loop with a glint of light on its upper edge,
  // packed so every ring overlaps its neighbours, as real mail does.
  final b = path.getBounds();
  final ring = strokePaint(const Color(0xB30A0A0C), 1.05);
  final shine = strokePaint(glint ?? const Color(0x80FFFFFF), .75);
  const dx = 4.2, dy = 2.9, w = 4.6, h = 3.4;
  c.save();
  c.clipPath(path);
  var row = 0;
  for (var y = b.top - dy; y < b.bottom + dy; y += dy, row++) {
    final off = row.isOdd ? dx / 2 : 0.0;
    for (var x = b.left - dx + off; x < b.right + dx; x += dx) {
      final r = Rect.fromCenter(center: Offset(x, y), width: w, height: h);
      c.drawOval(r, ring);
      c.drawArc(r.deflate(.6), math.pi * 1.1, math.pi * .55, false, shine);
    }
  }
  c.restore();
}

Path poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final q in pts.skip(1)) {
    p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

/// Parses the absolute SVG path commands used in this project (M, L, H, V, C, Q, Z).
Path svgPath(String d) {
  final tokens = RegExp(r'[MLHVCQZmlhvcqz]|-?\d*\.?\d+(?:e-?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  final p = Path();
  var i = 0;
  var cmd = 'M';
  var cx = 0.0, cy = 0.0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(t)) {
      cmd = t.toUpperCase();
      i++;
      if (cmd == 'Z') {
        p.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        cx = n();
        cy = n();
        p.moveTo(cx, cy);
        cmd = 'L';
      case 'L':
        cx = n();
        cy = n();
        p.lineTo(cx, cy);
      case 'H':
        cx = n();
        p.lineTo(cx, cy);
      case 'V':
        cy = n();
        p.lineTo(cx, cy);
      case 'C':
        final x1 = n(), y1 = n(), x2 = n(), y2 = n();
        cx = n();
        cy = n();
        p.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'Q':
        final x1 = n(), y1 = n();
        cx = n();
        cy = n();
        p.quadraticBezierTo(x1, y1, cx, cy);
      default:
        i++;
    }
  }
  return p;
}

/// Deterministic pseudo-random numbers so scenery looks the same every launch.
class SeededRandom {
  SeededRandom(this._s);
  int _s;
  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = _imul(t ^ (t >>> 15), 1 | t);
    t = (t + _imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
}
