// Old Corva's reading: a card face down on the table, turned over to show its picture, and what
// it brings. The faces are painted here, in the style of an old deck: a gilt border, the number
// at the top, the name on a banner below.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/tarot.dart';
import 'theme.dart';

/// Old Corva turns a card (paid for and come true as it's drawn), and the screen shows it.
Future<void> showTarotReading(BuildContext context, GameController c) async {
  final drawn = c.drawCard();
  if (drawn == null) return;
  Audio.play(Sfx.coins);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _Reading(card: drawn.$1, said: drawn.$2),
  );
}

class _Reading extends StatefulWidget {
  const _Reading({required this.card, required this.said});
  final Tarot card;
  final String said;
  @override
  State<_Reading> createState() => _ReadingState();
}

class _ReadingState extends State<_Reading> with SingleTickerProviderStateMixin {
  // Face down a moment, then turned over; the words come up after.
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final h = math.min(340.0, MediaQuery.sizeOf(context).height * .48), w = h * .6;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedBuilder(
            animation: _turn,
            builder: (context, _) {
              final t = _turn.value;
              // 0–.3 face down, .3–.6 turning, then the words.
              final flip = Curves.easeInOut.transform(((t - .3) / .3).clamp(0.0, 1.0));
              final words = ((t - .62) / .3).clamp(0.0, 1.0);
              final showFace = flip >= .5;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OLD CORVA TURNS A CARD', style: Txt.label(size: 13, color: Palette.parch2)),
                  const SizedBox(height: 12),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0015)
                      ..rotateY(math.pi * flip + (showFace ? math.pi : 0)),
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: CustomPaint(painter: showFace ? TarotFace(card) : const _TarotBack()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: words,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(card.title.toUpperCase(), style: Txt.label(size: 22, color: card.ill ? const Color(0xFFFF8A70) : Palette.amber, weight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(widget.said, textAlign: TextAlign.center, style: Txt.onStone(size: 15.5, color: card.ill ? const Color(0xFFFFB0A0) : const Color(0xFFB8E89A))),
                          const SizedBox(height: 14),
                          SizedBox(width: 180, child: StoneButton(title: card.ill ? 'So be it' : 'Thank her', tone: ButtonTone.blood, onPressed: words < 1 ? null : () => Navigator.pop(context))),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The back of every card: deep violet, a gilt border and the reader's eye-and-moon.
class _TarotBack extends CustomPainter {
  const _TarotBack();
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * .06));
    canvas.drawRRect(r, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), const [Color(0xFF3A1E52), Color(0xFF160A22)]));
    _gilt(canvas, size);
    final c = size.center(Offset.zero), u = size.width / 100;
    final gold = Paint()..color = const Color(0xFFE8C070);
    // A crescent, an eye inside a diamond, and stars.
    final moon = Path()
      ..addOval(Rect.fromCircle(center: c - Offset(0, 36 * u), radius: 12 * u))
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c - Offset(-5 * u, 39 * u), radius: 10 * u));
    canvas.drawPath(moon, gold);
    final diamond = Path()
      ..moveTo(c.dx, c.dy - 18 * u)
      ..lineTo(c.dx + 26 * u, c.dy)
      ..lineTo(c.dx, c.dy + 18 * u)
      ..lineTo(c.dx - 26 * u, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * u
      ..color = const Color(0xFFE8C070));
    final eye = Path()
      ..moveTo(c.dx - 16 * u, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - 11 * u, c.dx + 16 * u, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + 11 * u, c.dx - 16 * u, c.dy)
      ..close();
    canvas.drawPath(eye, Paint()..color = const Color(0xFFF4E6C0));
    canvas.drawCircle(c, 5 * u, Paint()..color = const Color(0xFF6A3A8A));
    canvas.drawCircle(c, 2.2 * u, Paint()..color = const Color(0xFF120818));
    for (final (dx, dy, s) in [(-30.0, 40.0, 3.0), (28.0, 46.0, 2.4), (0.0, 58.0, 3.4), (-24.0, -58.0, 2.2), (26.0, -52.0, 2.8)]) {
      _star(canvas, c + Offset(dx * u, dy * u), s * u, 4, gold);
    }
  }

  @override
  bool shouldRepaint(_TarotBack old) => false;
}

/// A card's face: its picture in a gilt frame, its number and its name.
class TarotFace extends CustomPainter {
  const TarotFace(this.card);
  final Tarot card;

  List<Color> get _sky => switch (card) {
    Tarot.sun => const [Color(0xFFFFE9A8), Color(0xFFF0B04A)],
    Tarot.wheel => const [Color(0xFFBCD6EE), Color(0xFF5A86B8)],
    Tarot.strength => const [Color(0xFFF4C29A), Color(0xFFB0402A)],
    Tarot.chariot => const [Color(0xFFCCD8E4), Color(0xFF5A6E88)],
    Tarot.star => const [Color(0xFF3A4E8A), Color(0xFF10163A)],
    Tarot.empress => const [Color(0xFFD8EAB0), Color(0xFF5A8A3A)],
    Tarot.hermit => const [Color(0xFF4A5268), Color(0xFF14161E)],
    Tarot.fool => const [Color(0xFFCDEBFF), Color(0xFF7AB0D8)],
    Tarot.magician => const [Color(0xFFD8B8F0), Color(0xFF5A2E8A)],
    Tarot.death => const [Color(0xFFE88A5A), Color(0xFF2A1022)],
    Tarot.tower => const [Color(0xFF6A6478), Color(0xFF1E1822)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * .06));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFF2E2B8));
    final u = size.width / 100;
    // The picture's window.
    final art = Rect.fromLTWH(9 * u, 22 * u, 82 * u, size.height - 48 * u);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(art, Radius.circular(3 * u)));
    canvas.drawRect(art, Paint()..shader = ui.Gradient.linear(art.topCenter, art.bottomCenter, _sky));
    canvas.translate(art.left, art.top);
    _picture(canvas, art.size, art.width / 100);
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(art, Radius.circular(3 * u)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * u
      ..color = const Color(0xFF7A5420));
    _gilt(canvas, size);
    // The number, in a roundel at the top.
    final top = Offset(size.width / 2, 12 * u);
    canvas.drawCircle(top, 8 * u, Paint()..color = const Color(0xFF2A1A0C));
    canvas.drawCircle(top, 8 * u, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * u
      ..color = const Color(0xFFE8C070));
    _label(canvas, card.numeral, top, (card.numeral.length > 3 ? 5.2 : card.numeral.length > 2 ? 6 : 7.5) * u, const Color(0xFFF4DCA0), maxWidth: 14 * u);
    // The name, on a banner along the foot.
    final banner = Rect.fromCenter(center: Offset(size.width / 2, size.height - 13 * u), width: 78 * u, height: 12 * u);
    final ribbon = Path()
      ..moveTo(banner.left - 6 * u, banner.top + 2 * u)
      ..lineTo(banner.left, banner.top)
      ..lineTo(banner.right, banner.top)
      ..lineTo(banner.right + 6 * u, banner.top + 2 * u)
      ..lineTo(banner.right + 2 * u, banner.center.dy + 1 * u)
      ..lineTo(banner.right + 6 * u, banner.bottom)
      ..lineTo(banner.left - 6 * u, banner.bottom)
      ..lineTo(banner.left - 2 * u, banner.center.dy + 1 * u)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = card.ill ? const Color(0xFF6A1A12) : const Color(0xFF3A2410));
    canvas.drawPath(ribbon, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * u
      ..color = const Color(0xFFE8C070));
    _label(canvas, card.title.toUpperCase(), banner.center, 6.2 * u, const Color(0xFFF4DCA0), maxWidth: banner.width - 4 * u);
  }

  void _picture(Canvas canvas, Size s, double u) {
    final w = s.width, h = s.height, c = Offset(w / 2, h * .45);
    final gold = Paint()..color = const Color(0xFFF6D27A);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * u
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A1A0C);
    void hills(Color col, double y) {
      final p = Path()
        ..moveTo(0, h)
        ..lineTo(0, y)
        ..quadraticBezierTo(w * .3, y - 14 * u, w * .55, y - 2 * u)
        ..quadraticBezierTo(w * .8, y + 8 * u, w, y - 6 * u)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = col);
    }

    switch (card) {
      case Tarot.sun:
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8, d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
          final len = (i.isEven ? 40 : 30) * u;
          final p = Path()
            ..moveTo((c + d * 18 * u + n * 5 * u).dx, (c + d * 18 * u + n * 5 * u).dy)
            ..lineTo((c + d * len).dx, (c + d * len).dy)
            ..lineTo((c + d * 18 * u - n * 5 * u).dx, (c + d * 18 * u - n * 5 * u).dy)
            ..close();
          canvas.drawPath(p, Paint()..color = const Color(0xFFFFF2B8));
        }
        canvas.drawCircle(c, 20 * u, Paint()..shader = ui.Gradient.radial(c - Offset(5 * u, 6 * u), 24 * u, const [Color(0xFFFFFBE0), Color(0xFFFFC23A), Color(0xFFE0801A)], const [0, .55, 1]));
        hills(const Color(0xFF8AA04A), h * .86);
      case Tarot.wheel:
        for (final (dx, dy) in [(-34.0, -40.0), (34.0, -42.0), (-36.0, 50.0), (34.0, 52.0)]) {
          for (final o in [const Offset(-5, 0), const Offset(4, -3), const Offset(9, 1)]) {
            canvas.drawCircle(c + Offset(dx * u, dy * u) + o * u, 6 * u, Paint()..color = Colors.white.withValues(alpha: .85));
          }
        }
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * u
          ..color = const Color(0xFFE8B04A);
        canvas.drawCircle(c, 28 * u, ring);
        canvas.drawCircle(c, 28 * u, ink..strokeWidth = 1 * u);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 26 * u, Paint()
            ..strokeWidth = 2.6 * u
            ..color = const Color(0xFFC8902E));
        }
        canvas.drawCircle(c, 7 * u, gold);
        canvas.drawCircle(c, 7 * u, ink);
      case Tarot.strength:
        hills(const Color(0xFF7A2A1A), h * .84);
        // A raised sword, glowing.
        canvas.drawCircle(c, 30 * u, Paint()..shader = ui.Gradient.radial(c, 30 * u, [const Color(0xFFFFF0C0).withValues(alpha: .8), const Color(0x00FFF0C0)]));
        final blade = Path()
          ..moveTo(c.dx, c.dy - 40 * u)
          ..lineTo(c.dx + 5 * u, c.dy - 32 * u)
          ..lineTo(c.dx + 5 * u, c.dy + 14 * u)
          ..lineTo(c.dx - 5 * u, c.dy + 14 * u)
          ..lineTo(c.dx - 5 * u, c.dy - 32 * u)
          ..close();
        canvas.drawPath(blade, Paint()..shader = ui.Gradient.linear(Offset(c.dx - 5 * u, 0), Offset(c.dx + 5 * u, 0), const [Color(0xFFFFFFFF), Color(0xFF9AA4B0)]));
        canvas.drawPath(blade, ink);
        final guard = RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, 16 * u), width: 30 * u, height: 5 * u), Radius.circular(2 * u));
        canvas.drawRRect(guard, gold);
        canvas.drawRRect(guard, ink);
        canvas.drawRect(Rect.fromCenter(center: c + Offset(0, 26 * u), width: 5 * u, height: 16 * u), Paint()..color = const Color(0xFF5A2E14));
        canvas.drawCircle(c + Offset(0, 35 * u), 4 * u, gold);
      case Tarot.chariot:
        hills(const Color(0xFF6A7A5A), h * .8);
        final box = Path()
          ..moveTo(c.dx - 26 * u, c.dy - 6 * u)
          ..lineTo(c.dx + 26 * u, c.dy - 6 * u)
          ..lineTo(c.dx + 20 * u, c.dy + 18 * u)
          ..lineTo(c.dx - 20 * u, c.dy + 18 * u)
          ..close();
        canvas.drawPath(box, Paint()..color = const Color(0xFF3A5A8A));
        canvas.drawPath(box, ink);
        canvas.drawCircle(c + Offset(0, 6 * u), 6 * u, gold);
        for (final dx in [-22.0, 22.0]) {
          final at = c + Offset(dx * u, 22 * u);
          canvas.drawCircle(at, 11 * u, Paint()..color = const Color(0xFF8A5A2A));
          canvas.drawCircle(at, 11 * u, ink);
          for (var i = 0; i < 4; i++) {
            final a = i * math.pi / 4;
            canvas.drawLine(at - Offset(math.cos(a), math.sin(a)) * 10 * u, at + Offset(math.cos(a), math.sin(a)) * 10 * u, ink);
          }
        }
        // A pennant on a pole.
        canvas.drawLine(c + Offset(18 * u, -6 * u), c + Offset(18 * u, -40 * u), ink..strokeWidth = 1.8 * u);
        final flag = Path()
          ..moveTo(c.dx + 18 * u, c.dy - 40 * u)
          ..lineTo(c.dx + 40 * u, c.dy - 34 * u)
          ..lineTo(c.dx + 18 * u, c.dy - 28 * u)
          ..close();
        canvas.drawPath(flag, Paint()..color = const Color(0xFFC0302A));
      case Tarot.star:
        final water = Rect.fromLTWH(0, h * .78, w, h * .22);
        canvas.drawRect(water, Paint()..shader = ui.Gradient.linear(water.topCenter, water.bottomCenter, const [Color(0xFF3A6AA8), Color(0xFF14284A)]));
        canvas.drawCircle(c, 26 * u, Paint()..shader = ui.Gradient.radial(c, 26 * u, [const Color(0xFFFFF6D0).withValues(alpha: .6), const Color(0x00FFF6D0)]));
        _star(canvas, c, 22 * u, 8, Paint()..color = const Color(0xFFFFE9A0));
        _star(canvas, c, 10 * u, 8, Paint()..color = Colors.white);
        for (final (dx, dy, r) in [(-32.0, -34.0, 5.0), (30.0, -30.0, 6.0), (-34.0, 18.0, 4.0), (34.0, 16.0, 5.0), (0.0, -46.0, 4.0), (-16.0, 34.0, 3.0), (18.0, 32.0, 3.5)]) {
          _star(canvas, c + Offset(dx * u, dy * u), r * u, 8, Paint()..color = const Color(0xFFFFF2C0));
        }
      case Tarot.empress:
        hills(const Color(0xFF4A7A2A), h * .82);
        // A crown over a healing flask.
        final crown = Path()
          ..moveTo(c.dx - 16 * u, c.dy - 26 * u)
          ..lineTo(c.dx - 18 * u, c.dy - 40 * u)
          ..lineTo(c.dx - 8 * u, c.dy - 32 * u)
          ..lineTo(c.dx, c.dy - 44 * u)
          ..lineTo(c.dx + 8 * u, c.dy - 32 * u)
          ..lineTo(c.dx + 18 * u, c.dy - 40 * u)
          ..lineTo(c.dx + 16 * u, c.dy - 26 * u)
          ..close();
        canvas.drawPath(crown, gold);
        canvas.drawPath(crown, ink);
        final flask = Path()
          ..moveTo(c.dx - 5 * u, c.dy - 18 * u)
          ..lineTo(c.dx + 5 * u, c.dy - 18 * u)
          ..lineTo(c.dx + 5 * u, c.dy - 6 * u)
          ..quadraticBezierTo(c.dx + 22 * u, c.dy, c.dx + 20 * u, c.dy + 16 * u)
          ..quadraticBezierTo(c.dx + 16 * u, c.dy + 30 * u, c.dx, c.dy + 30 * u)
          ..quadraticBezierTo(c.dx - 16 * u, c.dy + 30 * u, c.dx - 20 * u, c.dy + 16 * u)
          ..quadraticBezierTo(c.dx - 22 * u, c.dy, c.dx - 5 * u, c.dy - 6 * u)
          ..close();
        canvas.drawPath(flask, Paint()..shader = ui.Gradient.radial(c + Offset(-5 * u, 8 * u), 24 * u, const [Color(0xFFFF8A8A), Color(0xFFC0202A), Color(0xFF6A0A10)], const [0, .5, 1]));
        canvas.drawPath(flask, ink);
        canvas.drawRect(Rect.fromCenter(center: c + Offset(0, -21 * u), width: 9 * u, height: 5 * u), Paint()..color = const Color(0xFF8A5A2A));
      case Tarot.hermit:
        hills(const Color(0xFF2A2E3A), h * .86);
        // A lantern held out on a staff, its glow on the dark.
        final lamp = c + Offset(6 * u, -4 * u);
        canvas.drawCircle(lamp, 34 * u, Paint()..shader = ui.Gradient.radial(lamp, 34 * u, [const Color(0xFFFFD27A).withValues(alpha: .65), const Color(0x00FFD27A)]));
        canvas.drawLine(c + Offset(-20 * u, 46 * u), c + Offset(-6 * u, -30 * u), Paint()
          ..strokeWidth = 3 * u
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF6A4220));
        canvas.drawLine(c + Offset(-6 * u, -30 * u), lamp - Offset(0, 14 * u), ink..strokeWidth = 1.2 * u);
        final body = RRect.fromRectAndRadius(Rect.fromCenter(center: lamp, width: 14 * u, height: 20 * u), Radius.circular(3 * u));
        canvas.drawRRect(body, Paint()..color = const Color(0xFFFFE6A0));
        canvas.drawRRect(body, ink);
        canvas.drawLine(lamp - Offset(0, 10 * u), lamp + Offset(0, 10 * u), ink);
        canvas.drawPath(
          Path()
            ..moveTo(lamp.dx - 9 * u, lamp.dy - 10 * u)
            ..lineTo(lamp.dx, lamp.dy - 17 * u)
            ..lineTo(lamp.dx + 9 * u, lamp.dy - 10 * u)
            ..close(),
          Paint()..color = const Color(0xFF3A2A1A),
        );
      case Tarot.fool:
        // A winding road over the hills to a far sun.
        canvas.drawCircle(Offset(w * .72, h * .22), 10 * u, Paint()..color = const Color(0xFFFFF2B0));
        final mount = Path()
          ..moveTo(0, h * .6)
          ..lineTo(w * .25, h * .38)
          ..lineTo(w * .45, h * .55)
          ..lineTo(w * .7, h * .32)
          ..lineTo(w, h * .58)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(mount, Paint()..color = const Color(0xFF8A9AB8));
        hills(const Color(0xFF7AA04A), h * .7);
        final road = Path()
          ..moveTo(w * .3, h)
          ..quadraticBezierTo(w * .75, h * .88, w * .45, h * .78)
          ..quadraticBezierTo(w * .25, h * .72, w * .5, h * .66)
          ..lineTo(w * .53, h * .66)
          ..quadraticBezierTo(w * .32, h * .73, w * .52, h * .78)
          ..quadraticBezierTo(w * .9, h * .9, w * .55, h)
          ..close();
        canvas.drawPath(road, Paint()..color = const Color(0xFFE8D4A0));
        // A bundle on a stick, set down by the road.
        canvas.drawLine(Offset(w * .2, h * .92), Offset(w * .34, h * .68), Paint()
          ..strokeWidth = 2 * u
          ..color = const Color(0xFF6A4220));
        canvas.drawCircle(Offset(w * .35, h * .66), 6 * u, Paint()..color = const Color(0xFFC0302A));
      case Tarot.magician:
        // A wand and the sign of the endless.
        final inf = Path();
        for (var i = 0; i <= 40; i++) {
          final a = i / 40 * math.pi * 2;
          final p = c + Offset(math.sin(a) * 18 * u, math.sin(a) * math.cos(a) * 12 * u) - Offset(0, 30 * u);
          if (i == 0) {
            inf.moveTo(p.dx, p.dy);
          } else {
            inf.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(inf, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * u
          ..color = const Color(0xFFF6D27A));
        canvas.drawLine(c + Offset(-18 * u, 36 * u), c + Offset(14 * u, -8 * u), Paint()
          ..strokeWidth = 4 * u
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF2A1A0C));
        canvas.drawCircle(c + Offset(16 * u, -10 * u), 10 * u, Paint()..shader = ui.Gradient.radial(c + Offset(16 * u, -10 * u), 10 * u, [Colors.white, const Color(0x00E8C8FF)]));
        for (final (dx, dy, r) in [(28.0, -22.0, 4.0), (30.0, 4.0, 3.0), (4.0, -20.0, 3.0), (-26.0, 10.0, 3.5), (24.0, 30.0, 3.0)]) {
          _star(canvas, c + Offset(dx * u, dy * u), r * u, 4, Paint()..color = Colors.white);
        }
      case Tarot.death:
        // A scythe against a rising sun: an ending, and a dawn.
        final sun = Offset(w / 2, h * .82);
        canvas.drawCircle(sun, 26 * u, Paint()..color = const Color(0xFFFFC27A));
        hills(const Color(0xFF1A0E16), h * .84);
        canvas.drawLine(c + Offset(-10 * u, 44 * u), c + Offset(8 * u, -36 * u), Paint()
          ..strokeWidth = 3.2 * u
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF4A3020));
        final blade = Path()
          ..moveTo(c.dx + 8 * u, c.dy - 36 * u)
          ..quadraticBezierTo(c.dx - 16 * u, c.dy - 44 * u, c.dx - 34 * u, c.dy - 22 * u)
          ..quadraticBezierTo(c.dx - 14 * u, c.dy - 34 * u, c.dx + 6 * u, c.dy - 28 * u)
          ..close();
        canvas.drawPath(blade, Paint()..shader = ui.Gradient.linear(blade.getBounds().topCenter, blade.getBounds().bottomCenter, const [Color(0xFFE8ECF0), Color(0xFF7A8490)]));
        canvas.drawPath(blade, ink);
        // A white rose at its foot.
        final rose = c + Offset(-14 * u, 30 * u);
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          canvas.drawCircle(rose + Offset(math.cos(a), math.sin(a)) * 3.4 * u, 3.4 * u, Paint()..color = const Color(0xFFF4EEE8));
        }
        canvas.drawCircle(rose, 2 * u, Paint()..color = const Color(0xFFE8C070));
      case Tarot.tower:
        hills(const Color(0xFF2A2026), h * .88);
        final tower = Rect.fromCenter(center: c + Offset(0, 14 * u), width: 24 * u, height: 60 * u);
        canvas.drawRect(tower, Paint()..color = const Color(0xFF8A7A6A));
        canvas.drawRect(tower, ink);
        for (final dy in [-10.0, 6.0, 22.0]) {
          canvas.drawRect(Rect.fromCenter(center: c + Offset(0, dy * u), width: 5 * u, height: 8 * u), Paint()..color = const Color(0xFFFFB04A));
        }
        // Its crown knocked askew, flames out of the top, and the bolt that did it.
        canvas.save();
        canvas.translate(c.dx + 8 * u, c.dy - 20 * u);
        canvas.rotate(.5);
        final crown = Path()
          ..moveTo(-10 * u, 0)
          ..lineTo(-11 * u, -9 * u)
          ..lineTo(-4 * u, -4 * u)
          ..lineTo(0, -11 * u)
          ..lineTo(4 * u, -4 * u)
          ..lineTo(11 * u, -9 * u)
          ..lineTo(10 * u, 0)
          ..close();
        canvas.drawPath(crown, gold);
        canvas.drawPath(crown, ink);
        canvas.restore();
        for (final dx in [-8.0, 0.0, 8.0]) {
          final f = c + Offset(dx * u, -16 * u);
          canvas.drawPath(
            Path()
              ..moveTo(f.dx - 4 * u, f.dy)
              ..quadraticBezierTo(f.dx - 3 * u, f.dy - 10 * u, f.dx + 1 * u, f.dy - 14 * u)
              ..quadraticBezierTo(f.dx + 4 * u, f.dy - 6 * u, f.dx + 4 * u, f.dy)
              ..close(),
            Paint()..color = const Color(0xFFFF7A2A),
          );
        }
        final bolt = Path()
          ..moveTo(w * .9, 0)
          ..lineTo(w * .68, h * .2)
          ..lineTo(w * .76, h * .21)
          ..lineTo(w * .56, h * .36)
          ..lineTo(w * .7, h * .24)
          ..lineTo(w * .62, h * .23)
          ..lineTo(w * .82, 0)
          ..close();
        canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFF6B0));
    }
  }

  @override
  bool shouldRepaint(TarotFace old) => old.card != card;
}

/// The gilt edge round a card, inside its rim.
void _gilt(Canvas canvas, Size size) {
  final u = size.width / 100;
  canvas.drawRRect(
    RRect.fromRectAndRadius((Offset.zero & size).deflate(2.5 * u), Radius.circular(5 * u)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * u
      ..color = const Color(0xFFC8962E),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius((Offset.zero & size).deflate(5.2 * u), Radius.circular(4 * u)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8 * u
      ..color = const Color(0xFFE8C070),
  );
}

void _star(Canvas canvas, Offset at, double r, int points, Paint paint) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / points;
    final rr = i.isEven ? r : r * .4;
    final pt = at + Offset(math.cos(a), math.sin(a)) * rr;
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  canvas.drawPath(p, paint);
}

void _label(Canvas canvas, String text, Offset centre, double size, Color colour, {double? maxWidth}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: Txt.label(size: size, color: colour, weight: FontWeight.w800)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
}

/// `?tarot`: every card face, and the back (a dev check).
class TarotPreview extends StatelessWidget {
  const TarotPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF1A1510),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final t in Tarot.values) SizedBox(width: 120, height: 200, child: CustomPaint(painter: TarotFace(t))),
          const SizedBox(width: 120, height: 200, child: CustomPaint(painter: _TarotBack())),
        ],
      ),
    ),
  );
}
