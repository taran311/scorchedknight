// Small painted icons for crafting stock: a lump of ore, a bar, a cut gem, a fang, a pelt, a
// blueprint. Drawn in code like the
// rest of the art, in the material's own colour.

import 'package:flutter/material.dart';

import '../game/crafting.dart';

enum MatShape { ore, bar, gem, bottle, fang, pelt, scroll, leaf, core, mask, scale, coral, skin, feather }

class MatIcon extends StatelessWidget {
  const MatIcon(this.shape, this.colour, {super.key, this.size = 24});
  final MatShape shape;
  final Color colour;
  final double size;

  factory MatIcon.ore(Metal m, {double size = 24}) => MatIcon(MatShape.ore, Color(m.argb), size: size);
  factory MatIcon.bar(Metal m, {double size = 24}) => MatIcon(MatShape.bar, Color(m.argb), size: size);
  factory MatIcon.gem(Gem g, {double size = 24}) => MatIcon(MatShape.gem, Color(g.argb), size: size);
  factory MatIcon.brew(Color colour, {double size = 24}) => MatIcon(MatShape.bottle, colour, size: size);
  factory MatIcon.trophy(Trophy t, {double size = 24}) => MatIcon(switch (t) {
    Trophy.ashenSteel => MatShape.bar,
    Trophy.fang => MatShape.fang,
    Trophy.pelt => MatShape.pelt,
    Trophy.silk => MatShape.leaf,
    Trophy.runesteel => MatShape.bar,
    Trophy.face => MatShape.mask,
    Trophy.scale => MatShape.scale,
    Trophy.coral => MatShape.coral,
    Trophy.skin => MatShape.skin,
    Trophy.feather => MatShape.feather,
    Trophy.lacquer => MatShape.scale,
    Trophy.dragonscale => MatShape.scale,
  }, Color(t.argb), size: size);
  factory MatIcon.core(Color colour, {double size = 24}) => MatIcon(MatShape.core, colour, size: size);
  factory MatIcon.blueprint({double size = 24}) => MatIcon(MatShape.scroll, const Color(0xFF4A7AB8), size: size);

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _MatPainter(shape, colour)));
}

class _MatPainter extends CustomPainter {
  _MatPainter(this.shape, this.colour);
  final MatShape shape;
  final Color colour;

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 24);
    final light = Color.lerp(colour, Colors.white, .45)!, dark = Color.lerp(colour, Colors.black, .55)!;
    final outline = Paint()
      ..color = const Color(0xFF14100C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    switch (shape) {
      case MatShape.ore:
        // A grey lump of rock with the metal showing through it.
        final rock = Path()
          ..moveTo(3, 15)
          ..lineTo(6, 7)
          ..lineTo(13, 4)
          ..lineTo(20, 8)
          ..lineTo(21, 16)
          ..lineTo(14, 20)
          ..lineTo(7, 19)
          ..close();
        c.drawPath(rock, Paint()..color = const Color(0xFF6E6862));
        c.drawPath(Path()..moveTo(6, 7)..lineTo(13, 4)..lineTo(20, 8)..lineTo(12, 10)..close(), Paint()..color = const Color(0xFF8E8882));
        for (final (x, y, r) in const [(9.0, 13.0, 2.6), (15.0, 11.0, 2.0), (14.0, 16.0, 1.8)]) {
          c.drawCircle(Offset(x, y), r, Paint()..color = colour);
          c.drawCircle(Offset(x - r * .35, y - r * .35), r * .35, Paint()..color = light);
        }
        c.drawPath(rock, outline);
      case MatShape.bar:
        // An ingot: a trapezoid with a bright top.
        final side = Path()
          ..moveTo(2, 17)
          ..lineTo(6, 10)
          ..lineTo(18, 10)
          ..lineTo(22, 17)
          ..close();
        c.drawPath(side, Paint()..color = colour);
        c.drawPath(Path()..moveTo(2, 17)..lineTo(22, 17)..lineTo(22, 19)..lineTo(2, 19)..close(), Paint()..color = dark);
        c.drawPath(Path()..moveTo(6, 10)..lineTo(18, 10)..lineTo(16.5, 12.5)..lineTo(7.5, 12.5)..close(), Paint()..color = light);
        c.drawPath(Path()..moveTo(2, 17)..lineTo(6, 10)..lineTo(18, 10)..lineTo(22, 17)..lineTo(22, 19)..lineTo(2, 19)..close(), outline);
      case MatShape.gem:
        // A cut stone: table on top, facets below.
        final outer = Path()
          ..moveTo(4, 9)
          ..lineTo(8, 4)
          ..lineTo(16, 4)
          ..lineTo(20, 9)
          ..lineTo(12, 21)
          ..close();
        c.drawPath(outer, Paint()..color = colour);
        c.drawPath(Path()..moveTo(4, 9)..lineTo(20, 9)..lineTo(12, 21)..close(), Paint()..color = dark.withValues(alpha: .45));
        c.drawPath(Path()..moveTo(8, 4)..lineTo(16, 4)..lineTo(14, 9)..lineTo(10, 9)..close(), Paint()..color = light);
        c.drawLine(const Offset(10, 9), const Offset(12, 21), outline..strokeWidth = .8);
        c.drawLine(const Offset(14, 9), const Offset(12, 21), outline);
        c.drawPath(outer, outline..strokeWidth = 1.2);
      case MatShape.bottle:
        // A round-bellied flask with a cork, the brew glowing inside.
        c.drawCircle(const Offset(12, 15), 10, Paint()..color = colour.withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        final flask = Path()
          ..moveTo(9.5, 3)
          ..lineTo(14.5, 3)
          ..lineTo(14.5, 8)
          ..quadraticBezierTo(20.5, 10.5, 20.5, 15.5)
          ..quadraticBezierTo(20.5, 21.5, 12, 21.5)
          ..quadraticBezierTo(3.5, 21.5, 3.5, 15.5)
          ..quadraticBezierTo(3.5, 10.5, 9.5, 8)
          ..close();
        c.drawPath(flask, Paint()..color = const Color(0x55C8D8E0));
        c.save();
        c.clipPath(flask);
        c.drawRect(const Rect.fromLTRB(0, 12, 24, 24), Paint()..color = colour);
        c.drawRect(const Rect.fromLTRB(0, 12, 24, 13.4), Paint()..color = light);
        c.restore();
        c.drawCircle(const Offset(8.5, 15), 1.6, Paint()..color = const Color(0xCCFFFFFF));
        c.drawPath(flask, outline);
        c.drawRect(const Rect.fromLTRB(9, 1, 15, 4), Paint()..color = const Color(0xFF8A5A34));
        c.drawRect(const Rect.fromLTRB(9, 1, 15, 4), outline);
      case MatShape.fang:
        // A long curved fang, a bead of red at the tip.
        final fang = Path()
          ..moveTo(7, 3)
          ..quadraticBezierTo(17, 4, 16, 12)
          ..quadraticBezierTo(15, 18, 10, 22)
          ..quadraticBezierTo(12, 14, 7, 9)
          ..close();
        c.drawPath(fang, Paint()..color = colour);
        c.drawPath(Path()..moveTo(8, 4)..quadraticBezierTo(14, 5, 14, 10), Paint()..color = light..style = PaintingStyle.stroke..strokeWidth = 1.4);
        c.drawPath(fang, outline);
        c.drawCircle(const Offset(10.5, 21), 1.8, Paint()..color = const Color(0xFFC0202A));
      case MatShape.pelt:
        // A stretched hide with a ragged edge.
        final hide = Path()
          ..moveTo(5, 4)
          ..lineTo(9, 6)
          ..lineTo(15, 6)
          ..lineTo(19, 4)
          ..lineTo(18, 10)
          ..lineTo(21, 15)
          ..lineTo(17, 16)
          ..lineTo(16, 21)
          ..lineTo(12, 18)
          ..lineTo(8, 21)
          ..lineTo(7, 16)
          ..lineTo(3, 15)
          ..lineTo(6, 10)
          ..close();
        c.drawPath(hide, Paint()..color = colour);
        c.drawPath(Path()..moveTo(9, 9)..lineTo(15, 9)..lineTo(14, 15)..lineTo(10, 15)..close(), Paint()..color = light.withValues(alpha: .5));
        c.drawPath(hide, outline);
      case MatShape.leaf:
        // A folded length of elven silk, leaf-shaped, with a silver vein.
        final leaf = Path()
          ..moveTo(4, 20)
          ..quadraticBezierTo(3, 6, 20, 4)
          ..quadraticBezierTo(21, 18, 4, 20)
          ..close();
        c.drawPath(leaf, Paint()..color = colour);
        c.drawPath(Path()..moveTo(5, 19)..quadraticBezierTo(11, 11, 19, 5), Paint()..color = light..style = PaintingStyle.stroke..strokeWidth = 1.4);
        c.drawPath(Path()..moveTo(6, 12)..quadraticBezierTo(9, 9, 12, 7), Paint()..color = dark.withValues(alpha: .4)..style = PaintingStyle.stroke..strokeWidth = .9);
        c.drawPath(leaf, outline);
      case MatShape.mask:
        // A porcelain face: two eye-holes and a small, sad mouth.
        final face = Path()
          ..moveTo(12, 3)
          ..quadraticBezierTo(20, 3, 20, 11)
          ..quadraticBezierTo(20, 19, 12, 22)
          ..quadraticBezierTo(4, 19, 4, 11)
          ..quadraticBezierTo(4, 3, 12, 3)
          ..close();
        c.drawPath(face, Paint()..color = colour);
        c.drawPath(Path()..moveTo(7, 6)..quadraticBezierTo(9, 4, 13, 4.5), Paint()..color = light..style = PaintingStyle.stroke..strokeWidth = 1.2);
        final hole = Paint()..color = const Color(0xFF1A1618);
        c.drawOval(const Rect.fromLTWH(7.5, 9, 3.2, 2.2), hole);
        c.drawOval(const Rect.fromLTWH(13.3, 9, 3.2, 2.2), hole);
        c.drawArc(const Rect.fromLTWH(10, 15, 4, 2.4), 3.14, 3.14, false, outline..strokeWidth = .9);
        c.drawPath(face, outline..strokeWidth = 1.2);
      case MatShape.scale:
        // A big shed scale, ridged, with a sun-gold sheen.
        final sc = Path()
          ..moveTo(12, 3)
          ..quadraticBezierTo(21, 8, 19, 15)
          ..quadraticBezierTo(16, 21, 12, 22)
          ..quadraticBezierTo(8, 21, 5, 15)
          ..quadraticBezierTo(3, 8, 12, 3)
          ..close();
        c.drawPath(sc, Paint()..color = colour);
        for (final y in const [9.0, 13.0, 17.0]) {
          c.drawPath(Path()..moveTo(6.5, y)..quadraticBezierTo(12, y - 3, 17.5, y), Paint()..color = dark.withValues(alpha: .5)..style = PaintingStyle.stroke..strokeWidth = 1);
        }
        c.drawPath(Path()..moveTo(10, 5)..quadraticBezierTo(14, 5, 17, 9), Paint()..color = const Color(0xCCFFE07A)..style = PaintingStyle.stroke..strokeWidth = 1.3);
        c.drawPath(sc, outline);
      case MatShape.coral:
        // A branch of deep coral.
        final branch = Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(12, 22), const Offset(12, 8), branch);
        c.drawLine(const Offset(12, 15), const Offset(6, 9), branch);
        c.drawLine(const Offset(6, 9), const Offset(5, 4), branch);
        c.drawLine(const Offset(12, 12), const Offset(18, 6), branch);
        c.drawLine(const Offset(18, 6), const Offset(20, 3), branch);
        c.drawLine(const Offset(12, 8), const Offset(13, 3), branch);
        for (final p in const [Offset(5, 4), Offset(20, 3), Offset(13, 3), Offset(6, 9)]) {
          c.drawCircle(p, 1.6, Paint()..color = light);
        }
      case MatShape.skin:
        // A shed, shimmering skin, still half the shape of something else.
        final skin = Path()
          ..moveTo(5, 6)
          ..quadraticBezierTo(12, 2, 19, 6)
          ..quadraticBezierTo(22, 13, 17, 15)
          ..quadraticBezierTo(18, 21, 12, 22)
          ..quadraticBezierTo(6, 21, 7, 15)
          ..quadraticBezierTo(2, 13, 5, 6)
          ..close();
        c.drawPath(skin, Paint()..color = colour.withValues(alpha: .8));
        c.drawPath(Path()..moveTo(7, 8)..quadraticBezierTo(12, 11, 17, 8), Paint()..color = const Color(0xAAFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        c.drawPath(Path()..moveTo(9, 15)..quadraticBezierTo(12, 18, 15, 15), Paint()..color = const Color(0x88A0F0E0)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        c.drawPath(skin, outline);
      case MatShape.feather:
        // A long flight feather, barred.
        final vane = Path()
          ..moveTo(4, 21)
          ..quadraticBezierTo(6, 8, 20, 3)
          ..quadraticBezierTo(18, 14, 4, 21)
          ..close();
        c.drawPath(vane, Paint()..color = colour);
        for (var i = 0; i < 4; i++) {
          final p = 7.0 + i * 3.2;
          c.drawLine(Offset(p, 22 - p * .95), Offset(p + 3, 18 - p * .95), Paint()..color = dark.withValues(alpha: .6)..strokeWidth = 1.2);
        }
        c.drawLine(const Offset(3, 22), const Offset(19, 4), Paint()..color = dark..strokeWidth = 1.1);
        c.drawPath(vane, outline);
      case MatShape.core:
        // An elemental's core: a glowing orb with a brighter heart.
        c.drawCircle(const Offset(12, 12), 11, Paint()..color = colour.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        c.drawCircle(const Offset(12, 12), 7.5, Paint()..color = colour);
        c.drawCircle(const Offset(12, 12), 4, Paint()..color = light);
        c.drawCircle(const Offset(10, 9.5), 1.6, Paint()..color = const Color(0xDDFFFFFF));
        c.drawCircle(const Offset(12, 12), 7.5, outline);
      case MatShape.scroll:
        // A rolled blueprint: blue paper, white lines.
        c.drawRect(const Rect.fromLTRB(4, 5, 20, 19), Paint()..color = colour);
        final line = Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9;
        c.drawRect(const Rect.fromLTRB(7, 8, 13, 16), line);
        c.drawLine(const Offset(15, 9), const Offset(18, 9), line);
        c.drawLine(const Offset(15, 12), const Offset(18, 12), line);
        c.drawLine(const Offset(15, 15), const Offset(18, 15), line);
        c.drawRect(const Rect.fromLTRB(4, 5, 20, 19), outline);
        for (final x in const [3.0, 21.0]) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 12), width: 3.4, height: 17), const Radius.circular(1.6)), Paint()..color = dark);
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 12), width: 3.4, height: 17), const Radius.circular(1.6)), outline);
        }
    }
  }

  @override
  bool shouldRepaint(_MatPainter old) => old.shape != shape || old.colour != colour;
}
