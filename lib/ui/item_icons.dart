// Small painted icons for satchel slots and merchant wares (32 x 32 design grid).

import 'package:flutter/material.dart';

import '../art/paint_kit.dart';

enum Item { potion, poison, coins, egg, helm, chainmail, plate, gilded, armour, shield, gauntlets, dye, timber, iron, swords }

class ItemIcon extends StatelessWidget {
  const ItemIcon(this.item, {super.key, this.size = 28, this.tint});
  final Item item;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _IconPainter(item, tint)),
  );
}

final _bottle = svgPath('M12 3 L20 3 L20 6 L19 6 L19 11 C24 13 27 17 27 22 C27 28 22 30 16 30 C10 30 5 28 5 22 C5 17 8 13 13 11 L13 6 L12 6 Z');
final _potionLiquid = svgPath('M7 21 C7 18 9 15 13 13 L19 13 C23 15 25 18 25 21 C25 26 21 27 16 27 C11 27 7 26 7 21 Z');
final _flask = svgPath('M13 3 L19 3 L19 6 L18 6 L18 10 L23 16 L23 27 C23 29 21 30 16 30 C11 30 9 29 9 27 L9 16 L14 10 L14 6 L13 6 Z');
final _flaskLiquid = svgPath('M10 17 L14 12 L18 12 L22 17 L22 26 C22 27 20 28 16 28 C12 28 10 27 10 26 Z');
final _egg = svgPath('M16 3 C22 3 25 12 25 18 C25 24 21 28 16 28 C11 28 7 24 7 18 C7 12 10 3 16 3 Z');
final _helm = svgPath('M7 28 L7 12 C7 6 11 3 16 3 C21 3 25 6 25 12 L25 28 Z');
final _armour = svgPath('M8 5 L12 3 L20 3 L24 5 L28 11 L24 13 L24 29 L8 29 L8 13 L4 11 Z');
final _shield = svgPath('M5 4 L27 4 C28 14 24 22 16 29 C8 22 4 14 5 4 Z');
final _gauntlet = svgPath('M8 28 L8 14 L10 8 L13 7 L15 9 L17 7 L20 8 L22 12 L22 28 Z');

class _IconPainter extends CustomPainter {
  _IconPainter(this.item, this.tint);
  final Item item;
  final Color? tint;

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 32);
    final line = strokePaint(Colors.black, 1);
    void fill(Path p, Color col, {bool stroke = true}) {
      c.drawPath(p, Paint()..color = col);
      if (stroke) c.drawPath(p, line);
    }

    final cork = Paint()..color = const Color(0xFF8A6A40);
    switch (item) {
      case Item.potion:
        fill(_bottle, const Color(0xFF2A1F18));
        fill(_potionLiquid, const Color(0xFFC23A30), stroke: false);
        c.drawPath(svgPath('M10 18 C11 16 13 15 15 15'), strokePaint(const Color(0xFFFFB0A0), 1.5));
        c.drawRect(const Rect.fromLTWH(12, 2, 8, 3), cork);
      case Item.poison:
        fill(_flask, const Color(0xFF2A1F18));
        fill(_flaskLiquid, const Color(0xFF5F9F43), stroke: false);
        c.drawCircle(const Offset(14, 21), 1.6, Paint()..color = const Color(0xFFC8F0A8));
        c.drawCircle(const Offset(18, 24), 1.2, Paint()..color = const Color(0xFFC8F0A8));
        c.drawRect(const Rect.fromLTWH(13, 2, 6, 3), cork);
      case Item.coins:
        for (final (cx, cy, col) in const [
          (13.0, 22.0, Color(0xFF9B6A22)),
          (13.0, 19.0, Color(0xFFE3A548)),
          (19.0, 14.0, Color(0xFF9B6A22)),
          (19.0, 11.0, Color(0xFFEFC675)),
        ]) {
          final o = Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: 18, height: 8));
          fill(o, col);
        }
      case Item.egg:
        fill(_egg, const Color(0xFFD9BF8F));
        c.drawOval(Rect.fromCenter(center: const Offset(13, 13), width: 5, height: 4), Paint()..color = const Color(0xFFA8291F));
        c.drawOval(Rect.fromCenter(center: const Offset(19, 20), width: 6, height: 4), Paint()..color = const Color(0xFFA8291F));
      case Item.helm:
        fill(_helm, const Color(0xFF9AA3AE));
        c.drawRect(const Rect.fromLTWH(11, 13, 14, 3), Paint()..color = const Color(0xFF111111));
        c.drawLine(const Offset(19, 4), const Offset(19, 28), strokePaint(const Color(0x4D000000), 2));
      case Item.chainmail:
        fill(_armour, const Color(0xFF7D838B));
        final rings = strokePaint(const Color(0x59000000), 1);
        for (final y in const [13.0, 18.0, 23.0]) {
          c.drawLine(Offset(8, y), Offset(24, y), rings);
        }
      case Item.plate || Item.gilded:
        fill(_armour, item == Item.plate ? const Color(0xFFC3CAD3) : const Color(0xFFD8B04A));
        c.drawPath(svgPath('M12 6 C11 14 12 20 14 27'), strokePaint(const Color(0x99FFFFFF), 2));
      case Item.armour:
        fill(_armour, tint ?? const Color(0xFF7A5233));
        c.drawLine(const Offset(16, 5), const Offset(16, 29), strokePaint(const Color(0x59000000), 1.5));
        c.drawPath(svgPath('M11 6 C10 14 11 20 12 27'), strokePaint(const Color(0x55FFFFFF), 1.6));
      case Item.shield:
        fill(_shield, const Color(0xFF8E2117));
        final band = strokePaint(const Color(0xFFE3A548), 2.5)..strokeCap = StrokeCap.butt;
        c.drawLine(const Offset(16, 4), const Offset(16, 29), band);
        c.drawLine(const Offset(5.5, 12), const Offset(26.5, 12), band);
      case Item.gauntlets:
        fill(_gauntlet, const Color(0xFF9AA3AE));
        c.drawLine(const Offset(8, 20), const Offset(22, 20), strokePaint(const Color(0x66000000), 1));
      case Item.dye:
        fill(svgPath('M12 4 L20 4 L20 8 C24 10 26 13 26 18 C26 24 22 28 16 28 C10 28 6 24 6 18 C6 13 8 10 12 8 Z'), tint ?? const Color(0xFF9A2A22));
        c.drawRect(const Rect.fromLTWH(12, 3, 8, 3), cork);
      case Item.timber:
        // Two charred beams, crossed, their ends glowing.
        for (final (a, b) in const [(Offset(5, 24), Offset(27, 12)), (Offset(5, 14), Offset(27, 26))]) {
          c.drawLine(a, b, strokePaint(Colors.black, 8)..strokeCap = StrokeCap.round);
          c.drawLine(a, b, strokePaint(const Color(0xFF5A3A22), 6)..strokeCap = StrokeCap.round);
          c.drawLine(a + const Offset(0, -1.5), b + const Offset(0, -1.5), strokePaint(const Color(0xFF8A6040), 1.2));
          c.drawCircle(b, 2.2, Paint()..color = const Color(0xFFFF8A3A));
        }
      case Item.iron:
        // A bundle of iron bars.
        for (final (i, y) in const [22.0, 16.0, 10.0].indexed) {
          final bar = Path()..addPolygon([Offset(5 + i * 3, y + 6), Offset(9 + i * 3, y), Offset(27 - i * 3, y), Offset(23 - i * 3, y + 6)], true);
          fill(bar, const [Color(0xFF4E545C), Color(0xFF6E757E), Color(0xFF9AA3AE)][i]);
        }
      case Item.swords:
        // Two swords crossed: blades up, gold guards, dark grips.
        for (final flip in const [1.0, -1.0]) {
          c.save();
          c.translate(16, 16);
          c.scale(flip, 1);
          c.rotate(-.78);
          final blade = Path()..addPolygon(const [Offset(-2.2, 4), Offset(-2.2, -11), Offset(0, -14.5), Offset(2.2, -11), Offset(2.2, 4)], true);
          fill(blade, tint ?? const Color(0xFFDDE3EA));
          c.drawLine(const Offset(0, -12), const Offset(0, 3), strokePaint(const Color(0x55000000), .9));
          fill(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 4, 12, 3), const Radius.circular(1))), const Color(0xFFE3A548));
          fill(Path()..addRect(const Rect.fromLTWH(-1.6, 7, 3.2, 6)), const Color(0xFF4A2E1C));
          fill(Path()..addOval(Rect.fromCircle(center: const Offset(0, 14), radius: 2)), const Color(0xFFE3A548));
          c.restore();
        }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.item != item || old.tint != tint;
}
