// The opening: the survivor's crest, Vharrax burning a village, and one sooty knight climbing out
// of the ashes. About fifteen seconds, skippable, and shown once before you name your knight.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/body.dart';
import '../art/creatures.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/silhouette.dart';
import '../art/silhouette_inn.dart';
import '../art/sprites.dart';
import '../game/classes.dart';
import '../game/models.dart';
import 'hud.dart' show CrestPainter;
import 'theme.dart';

/// When each part of the intro starts, in milliseconds.
const _burnAt = 3400.0, _ashAt = 9200.0, _endAt = 14200.0;

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone, this.female = false});
  final VoidCallback onDone;
  final bool female;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1000.0))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _fade(double from, double to, {double inMs = 600, double outMs = 600}) {
    if (_t < from || _t > to) return 0;
    return math.min(((_t - from) / inMs).clamp(0.0, 1.0), ((to - _t) / outMs).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final ended = _t >= _endAt;
    final title = _fade(300, _burnAt, outMs: 500);
    final caption = switch (_t) {
      < _burnAt + 900 => null,
      < _ashAt => ('Vharrax the Ember King woke up in a bad mood.', 'Kingdoms, libraries, bakeries: the lot went up in smoke.', _fade(_burnAt + 900, _ashAt - 200)),
      _ => ('One knight crawled out of the ashes.', 'Sooty, singed, and missing half an eyebrow. Time to do something about him.', _fade(_ashAt + 1600, 1e9)),
    };
    return Scaffold(
      backgroundColor: const Color(0xFF0C0907),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ended ? widget.onDone : null,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _IntroPainter(_t, widget.female))),
            // The title card.
            if (title > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: title,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: .9 + .1 * Curves.easeOut.transform(((_t - 300) / 1200).clamp(0.0, 1.0)),
                          child: const SizedBox(width: 84, height: 100, child: CustomPaint(painter: CrestPainter())),
                        ),
                        const SizedBox(height: 18),
                        Text('SCORCHED KNIGHT', style: Txt.logo().copyWith(fontSize: 40, letterSpacing: 3)),
                        const SizedBox(height: 6),
                        Text('Survive the ashfall. Slay the flame.', style: Txt.label(size: 16, color: Palette.parch2)),
                      ],
                    ),
                  ),
                ),
              ),
            if (caption != null && caption.$3 > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: ended ? 120 : 64,
                child: Opacity(
                  opacity: caption.$3,
                  child: Column(
                    children: [
                      Text(caption.$1, textAlign: TextAlign.center, style: Txt.label(size: 22, color: Palette.amber)),
                      const SizedBox(height: 6),
                      Text(caption.$2, textAlign: TextAlign.center, style: Txt.onStone(size: 16, color: Palette.cream)),
                    ],
                  ),
                ),
              ),
            if (ended)
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: Center(
                  child: Opacity(
                    opacity: ((_t - _endAt) / 500).clamp(0.0, 1.0),
                    child: FilledButton(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2A1E),
                        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: const BorderSide(color: Color(0xFFC9A24E))),
                      ),
                      child: Text('Begin', style: Txt.label(size: 18, color: Palette.cream)),
                    ),
                  ),
                ),
              ),
            if (!ended)
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: Text('Skip ›', style: Txt.label(size: 15, color: Palette.parch2)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntroPainter extends CustomPainter {
  _IntroPainter(this.t, this.female);
  final double t;
  final bool female;

  static final _vharrax = foeDragons['emberKing']!;

  // The village: x positions (in a 1000-wide frame), widths and heights.
  static const _houses = [(150.0, 90.0, 70.0), (270.0, 70.0, 56.0), (400.0, 110.0, 84.0), (560.0, 80.0, 62.0), (690.0, 100.0, 74.0), (830.0, 76.0, 58.0)];

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is drawn in a 1000 x 600 frame, scaled to fit and centred; sky and ground run
    // out to the edges.
    final s = math.min(size.width / 1000, size.height / 600);
    final ox = (size.width - 1000 * s) / 2, oy = (size.height - 600 * s) / 2;
    final groundY = oy + 470 * s;
    final full = Offset.zero & size;

    if (t < _burnAt) {
      // The title card: dark, with a slow ember glow behind the crest.
      final k = (t / 1500).clamp(0.0, 1.0);
      canvas.drawRect(full, Paint()..color = const Color(0xFF0C0907));
      canvas.drawCircle(
        size.center(const Offset(0, -40)),
        220,
        Paint()..shader = ui.Gradient.radial(size.center(const Offset(0, -40)), 220, [Color.fromRGBO(200, 80, 30, .35 * k), const Color(0x000C0907)]),
      );
      _embers(canvas, size, t, 1);
      return;
    }

    final ash = t >= _ashAt;
    // The ground shudders while Vharrax breathes fire.
    final dragonAt = _dragonX(t), roaring = !ash && dragonAt < 900 && dragonAt > 80;
    canvas.save();
    if (roaring) canvas.translate(math.sin(t / 23) * 2.2 * s, math.cos(t / 31) * 1.6 * s);
    // How far the burning has gone (0 at the start, 1 once the village is alight).
    final burn = ((t - _burnAt - 2200) / 2600).clamp(0.0, 1.0);
    final fadeIn = ((t - _burnAt) / 700).clamp(0.0, 1.0);
    final ashIn = ash ? ((t - _ashAt) / 900).clamp(0.0, 1.0) : 0.0;

    // Painted backdrops when they've loaded: the burning village, then the ruins of the inn.
    final backdrop = Sprites.get(ash ? 'inn_ruined' : 'village_burning');
    if (backdrop != null) {
      Sprites.cover(canvas, backdrop, full, alignY: ash ? .8 : .7);
      // Before the fire takes hold the village sits in cool dusk; it warms to full blaze.
      if (!ash) canvas.drawRect(full, Paint()..color = Color.fromRGBO(20, 28, 60, .62 * (1 - burn)));
      // Over the ruins it's later, and darker.
      if (ash) canvas.drawRect(full, Paint()..color = const Color(0x66080810));
    } else if (ash) {
      // The ruins of the Soot & Kettle, still burning: the inn you'll come to rebuild.
      canvas.drawRect(full, Paint()..shader = ui.Gradient.linear(Offset(0, oy), Offset(0, groundY), const [Color(0xFF0A0710), Color(0xFF8A3A1E)]));
      canvas.drawRect(Rect.fromLTRB(0, groundY, size.width, size.height), Paint()..color = const Color(0xFF0A0807));
      final k = s * 1000 / 960;
      canvas.save();
      canvas.translate(ox, groundY - 470 * k);
      canvas.scale(k);
      paintSilhouetteInn(canvas, false, t, fence: false);
      canvas.restore();
    } else {
      // Sky: dusk, reddening as the village burns.
      final top = ash ? const Color(0xFF0E1018) : Color.lerp(const Color(0xFF1B2440), const Color(0xFF3A0E0A), burn)!;
      final low = ash ? const Color(0xFF6A2A16) : Color.lerp(const Color(0xFF8A5A4A), const Color(0xFFE0582A), burn)!;
      canvas.drawRect(full, Paint()..shader = ui.Gradient.linear(Offset(0, oy), Offset(0, groundY), [top, low]));
      if (!ash) {
        // A low sun going down behind the hills.
        canvas.drawCircle(Offset(ox + 760 * s, groundY - 90 * s), 46 * s, Paint()..color = Color.lerp(const Color(0xFFF2C890), const Color(0xFFFF8A4A), burn)!.withValues(alpha: .85));
      } else {
        canvas.drawCircle(Offset(ox + 820 * s, oy + 110 * s), 26 * s, Paint()..color = const Color(0x66E8E0D0));
      }
      // Hills and ground.
      final hills = Path()..moveTo(0, groundY - 40 * s);
      for (var x = 0.0; x <= size.width + 40; x += 40) {
        hills.lineTo(x, groundY - 40 * s - math.sin(x / (160 * s)) * 22 * s - math.sin(x / (61 * s)) * 6 * s);
      }
      hills
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      // The king's castle on the far hill, before the hills close in.
      final castle = Paint()..color = Color.lerp(const Color(0xFF3A3A4A), const Color(0xFF4A2018), burn)!;
      final cx = ox + 840 * s, cy = groundY - 64 * s;
      canvas.drawRect(Rect.fromLTWH(cx - 50 * s, cy - 30 * s, 100 * s, 40 * s), castle);
      for (final (dx, w, h) in const [(-50.0, 18.0, 62.0), (34.0, 18.0, 56.0), (-8.0, 22.0, 84.0)]) {
        canvas.drawRect(Rect.fromLTWH(cx + dx * s, cy - h * s, w * s, (h + 10) * s), castle);
        canvas.drawPath(Path()..addPolygon([Offset(cx + (dx - 3) * s, cy - h * s), Offset(cx + (dx + w / 2) * s, cy - (h + 20) * s), Offset(cx + (dx + w + 3) * s, cy - h * s)], true), castle);
      }
      canvas.drawPath(hills, Paint()..color = ash ? const Color(0xFF1C1614) : Color.lerp(const Color(0xFF2A3424), const Color(0xFF2A1A14), burn)!);
      // Pines between the cottages.
      final pine = Paint()..color = Color.lerp(const Color(0xFF1A2418), const Color(0xFF1A100C), burn)!;
      for (final (px, ph) in const [(80.0, 70.0), (205.0, 56.0), (335.0, 80.0), (482.0, 60.0), (625.0, 74.0), (760.0, 64.0), (905.0, 78.0), (960.0, 50.0)]) {
        final bx = ox + px * s;
        for (var j = 0; j < 3; j++) {
          final w = (22 - j * 5) * s, top = groundY - ph * s * (1 - j * .25) - 10 * s;
          canvas.drawPath(Path()..addPolygon([Offset(bx - w, top + ph * s * .45), Offset(bx, top), Offset(bx + w, top + ph * s * .45)], true), pine);
        }
        canvas.drawRect(Rect.fromLTWH(bx - 2 * s, groundY - 14 * s, 4 * s, 14 * s), pine);
      }
      canvas.drawRect(Rect.fromLTRB(0, groundY, size.width, size.height), Paint()..color = ash ? const Color(0xFF15100E) : Color.lerp(const Color(0xFF1E261A), const Color(0xFF1E1410), burn)!);

      // The houses: standing, then alight as Vharrax passes over, then charred stumps.
      for (final (i, (hx, hw, hh)) in _houses.indexed) {
        final x = ox + hx * s, w = hw * s, h = hh * s;
        final lit = ash ? 1.0 : ((t - _litAt(hx)) / 500).clamp(0.0, 1.0);
        _house(canvas, Offset(x, groundY), w, h, s, ash ? 1.0 : lit, ash, i);
        if (!ash && lit > 0) {
          _smoke(canvas, Offset(x, groundY - h * 1.4), s, t, lit, i);
          _fire(canvas, Offset(x, groundY - h * .55), w, h, s, t, lit, i);
          _sparks(canvas, Offset(x, groundY - h), w, s, t, lit, i);
        }
        if (ash) _smoulder(canvas, Offset(x, groundY - h * .25), w, s, t, i);
      }
    }

    // Vharrax sweeps in from the right, breathing fire down on the roofs.
    if (!ash) {
      final dx = _dragonX(t);
      if (dx > -300 && dx < 1300) {
        final at = Offset(ox + dx * s, oy + (190 + math.sin(t / 500) * 14) * s);
        final ds = s * .62;
        final breathing = dx < 900 && dx > 80;
        final painted = Sprites.get('vharrax');
        late Offset mouth;
        if (painted != null) {
          // The painted Vharrax, facing left, rising and dipping as his wings beat.
          final w = 560 * s, h = w * painted.height / painted.width;
          final dst = Rect.fromCenter(center: at + Offset(0, math.sin(t / 220) * 6 * s), width: w, height: h);
          canvas.drawImageRect(painted, Rect.fromLTWH(0, 0, painted.width.toDouble(), painted.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.medium);
          mouth = Offset(dst.left + dst.width * .12, dst.top + dst.height * .4);
        } else {
          // Vharrax as a silhouette against the burning sky, rimmed in fire.
          silhouette(canvas, Offset.zero & size, (c) {
            c.save();
            c.translate(at.dx, at.dy);
            c.scale(-ds * _vharrax.scale, ds * _vharrax.scale); // facing left
            paintDragon(c, _vharrax, flap: math.sin(t / 220), fly: true, breathing: breathing, lineScale: ds * _vharrax.scale);
            c.restore();
          }, rim: const Color(0xFFFF9A50), detail: .3, light: const Offset(0, 3));
          mouth = at + Offset(-146 * ds * _vharrax.scale, -84 * ds * _vharrax.scale);
        }
        if (breathing) {
          // A cone of fire from the jaws down onto the village.
          final ground = Offset(mouth.dx - 110 * s, groundY - 40 * s);
          final flick = math.sin(t / 60) * 6 * s;
          final cone = Path()
            ..moveTo(mouth.dx, mouth.dy)
            ..quadraticBezierTo(mouth.dx - 60 * s, mouth.dy + 60 * s, ground.dx - 50 * s + flick, ground.dy)
            ..lineTo(ground.dx + 60 * s - flick, ground.dy + 10 * s)
            ..quadraticBezierTo(mouth.dx - 10 * s, mouth.dy + 70 * s, mouth.dx + 4 * s, mouth.dy + 6 * s)
            ..close();
          canvas.drawPath(
              cone,
              Paint()
                ..shader = ui.Gradient.linear(mouth, ground, const [Color(0xFFFFF2C0), Color(0xFFFFB04A), Color(0x00E0401A)], const [0, .45, 1])
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s));
        }
      }
      // A red glow over everything as the fire takes hold.
      canvas.drawRect(full, Paint()..color = Color.fromRGBO(255, 90, 30, .1 * burn));
    }

    if (ash) {
      // The survivor: a sooty knight clambers up out of a heap of rubble in the middle, coughs a
      // puff of smoke, and stands.
      final rise = Curves.easeOutBack.transform(((t - _ashAt - 900) / 900).clamp(0.0, 1.0));
      final at = Offset(ox + 500 * s, groundY + (1 - rise) * 120 * s);
      final look = lookFor(HeroClass.knight, Loadout.starter(HeroClass.knight), female: female, soot: 1);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, groundY + 6 * s));
      silhouette(
        canvas,
        Offset.zero & size,
        (c) => drawHumanoid(c, look, idlePose(Stance.knight, t), t, DrawOptions(at: at, scale: 1.25 * s, shadow: rise > .9)),
        rim: const Color(0xFFFF9A50),
      );
      canvas.restore();
      // The rubble heap in front.
      final heap = Path()
        ..moveTo(ox + 400 * s, groundY + 4 * s)
        ..quadraticBezierTo(ox + 430 * s, groundY - 34 * s, ox + 470 * s, groundY - 22 * s)
        ..lineTo(ox + 490 * s, groundY - 34 * s)
        ..quadraticBezierTo(ox + 540 * s, groundY - 40 * s, ox + 560 * s, groundY - 18 * s)
        ..quadraticBezierTo(ox + 590 * s, groundY - 20 * s, ox + 610 * s, groundY + 4 * s)
        ..close();
      canvas.drawPath(heap, Paint()..color = const Color(0xFF241A16));
      canvas.drawPath(
          heap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF0A0605));
      for (final (bx, by) in const [(450.0, -12.0), (520.0, -20.0), (575.0, -8.0)]) {
        canvas.drawCircle(Offset(ox + bx * s, groundY + by * s), 2.2 * s, Paint()..color = Color.fromRGBO(255, 120, 40, .5 + .4 * math.sin(t / 300 + bx)));
      }
      // The cough.
      final cough = ((t - _ashAt - 2300) / 1200).clamp(0.0, 1.0);
      if (cough > 0 && cough < 1) {
        for (var i = 0; i < 4; i++) {
          final p = at + Offset((22 + cough * 40 + i * 8) * s, (-150 - cough * 30 - i * 6) * s);
          canvas.drawCircle(p, (6 + cough * 10 + i * 2) * s, Paint()..color = Color.fromRGBO(140, 130, 124, .45 * (1 - cough)));
        }
      }
      // Fade up from black.
      if (ashIn < 1) canvas.drawRect(full, Paint()..color = Color.fromRGBO(12, 9, 7, 1 - ashIn));
    }

    canvas.restore();
    // Ash drifting down over everything.
    _ash(canvas, size, t, ash ? 1 : burn);
    if (fadeIn < 1) canvas.drawRect(full, Paint()..color = Color.fromRGBO(12, 9, 7, 1 - fadeIn));
    // Into black before the ashes.
    if (!ash && t > _ashAt - 600) canvas.drawRect(full, Paint()..color = Color.fromRGBO(12, 9, 7, ((t - (_ashAt - 600)) / 600).clamp(0.0, 1.0)));
  }

  /// Vharrax's x in the 1000-wide frame: from off the right edge to off the left.
  static double _dragonX(double t) => 1250 - (t - _burnAt - 900) / 4600 * 1600;

  /// When the fire reaches a house at frame x [hx].
  static double _litAt(double hx) => _burnAt + 900 + (1250 - (hx + 40)) / 1600 * 4600;

  void _house(Canvas c, Offset base, double w, double h, double s, double burnt, bool ash, int i) {
    final wall = Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h);
    final roofH = h * .6;
    if (ash) {
      // Charred stumps: a broken wall and a beam or two.
      final stump = Path()
        ..moveTo(wall.left, base.dy)
        ..lineTo(wall.left, base.dy - h * (.5 + (i % 3) * .12))
        ..lineTo(wall.left + w * .25, base.dy - h * .35)
        ..lineTo(wall.left + w * .45, base.dy - h * (.7 - (i % 2) * .2))
        ..lineTo(wall.left + w * .7, base.dy - h * .3)
        ..lineTo(wall.right, base.dy - h * (.45 + (i % 2) * .15))
        ..lineTo(wall.right, base.dy)
        ..close();
      c.drawPath(stump, Paint()..color = const Color(0xFF1E1714));
      c.drawLine(
          Offset(wall.left + w * .2, base.dy - h * .3),
          Offset(wall.left + w * .55, base.dy - h * 1.0),
          Paint()
            ..color = const Color(0xFF120C0A)
            ..strokeWidth = 4 * s);
      return;
    }
    // Cottages in silhouette: timber-framed, thatched, one with a chapel spire; their windows the
    // only warmth.
    const wallCol = Color(0xFF0E0A09), beamCol = Color(0xFF1C1410);
    final wallPaint = Paint()..color = wallCol;
    c.drawRect(wall, wallPaint);
    // Half-timbering: a beam along the top, posts at the corners, a brace each side.
    final beam = Paint()
      ..color = beamCol
      ..strokeWidth = 2.4 * s;
    c.drawLine(Offset(wall.left, wall.top + 2 * s), Offset(wall.right, wall.top + 2 * s), beam);
    c.drawLine(Offset(wall.left + 2 * s, wall.top), Offset(wall.left + 2 * s, base.dy), beam);
    c.drawLine(Offset(wall.right - 2 * s, wall.top), Offset(wall.right - 2 * s, base.dy), beam);
    c.drawLine(Offset(wall.left + 3 * s, base.dy - h * .1), Offset(wall.left + w * .3, wall.top + 3 * s), beam);
    c.drawLine(Offset(wall.right - 3 * s, base.dy - h * .1), Offset(wall.right - w * .3, wall.top + 3 * s), beam);
    // Chimney.
    c.drawRect(Rect.fromLTWH(base.dx + w * .2, wall.top - roofH * .8, w * .1, roofH * .6), wallPaint);
    // A thick thatched roof, its eaves rounded over the walls.
    final roof = Path()
      ..moveTo(wall.left - w * .14, wall.top + 6 * s)
      ..quadraticBezierTo(wall.left - w * .1, wall.top - 4 * s, wall.left + w * .05, wall.top - roofH * .2)
      ..lineTo(base.dx - w * .06, wall.top - roofH)
      ..quadraticBezierTo(base.dx, wall.top - roofH * 1.06, base.dx + w * .06, wall.top - roofH)
      ..lineTo(wall.right - w * .05, wall.top - roofH * .2)
      ..quadraticBezierTo(wall.right + w * .1, wall.top - 4 * s, wall.right + w * .14, wall.top + 6 * s)
      ..close();
    c.drawPath(roof, wallPaint);
    for (var j = 1; j < 4; j++) {
      final y = wall.top - roofH * j / 4.2;
      final half = (w * .64) * (1 - j / 4.2);
      c.drawLine(Offset(base.dx - half, y), Offset(base.dx + half, y), Paint()
        ..color = beamCol
        ..strokeWidth = 1.2 * s);
    }
    if (i == 2) {
      // The chapel's bell tower and spire.
      final tw = w * .22;
      c.drawRect(Rect.fromLTWH(wall.left + w * .08, wall.top - roofH * 1.3, tw, roofH * 1.3), wallPaint);
      c.drawPath(
        Path()..addPolygon([Offset(wall.left + w * .05, wall.top - roofH * 1.3), Offset(wall.left + w * .08 + tw / 2, wall.top - roofH * 2.3), Offset(wall.left + w * .11 + tw, wall.top - roofH * 1.3)], true),
        wallPaint,
      );
      c.drawRect(Rect.fromCenter(center: Offset(wall.left + w * .08 + tw / 2, wall.top - roofH * .95), width: tw * .4, height: roofH * .3), Paint()..color = const Color(0xFF2A1E14));
    }
    final glow = Color.lerp(const Color(0xFFFFB04A), const Color(0xFFFF6A2A), burnt)!;
    c.drawCircle(Offset(base.dx, wall.top + h * .3), w * .6, Paint()..color = glow.withValues(alpha: .2)..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * s));
    final win = Paint()..color = Color.lerp(const Color(0xFFFFD27A), const Color(0xFFFF7A2A), burnt)!;
    for (final fx in [-.22, if (w > 80 * s) .22]) {
      final r = Rect.fromCenter(center: Offset(base.dx + w * fx, wall.top + h * .32), width: w * .16, height: h * .22);
      c.drawRect(r, win);
      c.drawLine(r.topCenter, r.bottomCenter, Paint()
        ..color = wallCol
        ..strokeWidth = 1.4 * s);
      c.drawLine(r.centerLeft, r.centerRight, Paint()
        ..color = wallCol
        ..strokeWidth = 1.4 * s);
    }
    c.drawRect(Rect.fromLTWH(base.dx - w * .08, base.dy - h * .4, w * .16, h * .4), Paint()..color = win.color.withValues(alpha: .55));
  }

  /// A column of black smoke rolling up off a burning roof and leaning away on the wind.
  void _smoke(Canvas c, Offset at, double s, double t, double k, int seed) {
    for (var j = 0; j < 7; j++) {
      final p = (t / 3200 + j / 7 + seed * .13) % 1.0;
      final q = at + Offset((-p * 110 + math.sin(t / 800 + j) * 6) * s, -p * 230 * s);
      c.drawCircle(q, (10 + p * 34) * s, Paint()..color = Color.fromRGBO(28, 18, 16, .55 * (1 - p) * k)..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s));
    }
  }

  /// Sparks spiralling up out of the flames.
  void _sparks(Canvas c, Offset at, double w, double s, double t, double k, int seed) {
    for (var j = 0; j < 8; j++) {
      final p = (t / 1700 + j / 8 + seed * .29) % 1.0;
      final q = at + Offset(((j % 4) - 1.5) * w * .2 + math.sin(t / 240 + j * 2) * 10 * s - p * 30 * s, -p * 150 * s);
      c.drawCircle(q, 1.7 * s, Paint()..color = Color.fromRGBO(255, 190, 90, (1 - p) * k));
    }
  }

  void _fire(Canvas c, Offset at, double w, double h, double s, double t, double k, int seed) {
    for (var j = 0; j < 5; j++) {
      final fx = at.dx + (j - 2) * w * .2, flick = math.sin(t / (90 + j * 13) + seed * 3 + j) * 6 * s;
      final fh = (h * .9 + (j % 2) * h * .3) * k;
      final flame = Path()
        ..moveTo(fx - w * .14, at.dy + h * .3)
        ..quadraticBezierTo(fx - w * .16, at.dy - fh * .4, fx + flick, at.dy - fh)
        ..quadraticBezierTo(fx + w * .16, at.dy - fh * .4, fx + w * .14, at.dy + h * .3)
        ..close();
      c.drawPath(flame, Paint()..shader = ui.Gradient.linear(Offset(fx, at.dy + h * .3), Offset(fx, at.dy - fh), const [Color(0xFFFFE08A), Color(0xFFFF8A3A), Color(0x00D0401A)], const [0, .5, 1]));
    }
    c.drawCircle(
        at,
        w * .9,
        Paint()
          ..color = Color.fromRGBO(255, 120, 40, .18 * k)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * s));
  }

  void _smoulder(Canvas c, Offset at, double w, double s, double t, int seed) {
    for (var j = 0; j < 3; j++) {
      final p = ((t / 2600 + j / 3 + seed * .17) % 1.0);
      final q = at + Offset((j - 1) * w * .25 + math.sin(t / 700 + j) * 6 * s, -p * 90 * s);
      c.drawCircle(q, (5 + p * 12) * s, Paint()..color = Color.fromRGBO(120, 110, 104, .28 * (1 - p)));
    }
  }

  void _ash(Canvas c, Size size, double t, double k) {
    if (k <= 0) return;
    final p = Paint()..color = Color.fromRGBO(200, 190, 180, .5 * k);
    for (var i = 0; i < 46; i++) {
      final sx = (i * 137.5) % 1.0 * size.width + ((i * 7919) % 97);
      final speed = 18 + (i % 5) * 6;
      final y = ((t / 1000 * speed + i * 53) % (size.height + 20)) - 10;
      final x = (sx + math.sin(t / 900 + i) * 14) % size.width;
      c.drawCircle(Offset(x, y), 1.1 + (i % 3) * .5, p);
    }
  }

  void _embers(Canvas c, Size size, double t, double k) {
    for (var i = 0; i < 18; i++) {
      final speed = 22 + (i % 4) * 9;
      final y = size.height - ((t / 1000 * speed + i * 71) % (size.height * .8));
      final x = size.width / 2 + math.sin(i * 2.3) * size.width * .3 + math.sin(t / 800 + i) * 10;
      final a = (.6 * k * (y / size.height)).clamp(0.0, 1.0);
      c.drawCircle(Offset(x, y), 1.6, Paint()..color = Color.fromRGBO(255, 150, 60, a));
    }
  }

  @override
  bool shouldRepaint(_IntroPainter old) => old.t != t || old.female != female;
}
