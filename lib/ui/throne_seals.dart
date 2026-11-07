// The Ember Throne's seals: six seals of old fire ringed round the throne, one held by each of
// six side-land lords (Thane Grimnar of Deepforge Hold's among them, and it must break). Shown
// when Scorchmaw falls and the way on turns out to be sealed, and again each time a lord's
// fall breaks another: the new seals glow, shake, crack and burst, one after another, and when
// the last goes, the throne flares and the way to Vharrax opens. A tap skips to the end.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import 'theme.dart';

/// Shows the seals as they now stand, breaking the ones that broke since they were last shown.
Future<void> showThroneSeals(BuildContext context, GameController c) {
  final before = c.engine.sealsShown, now = c.engine.sealsNow;
  c.sealsSeen();
  Audio.play(Sfx.quest);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, a1, a2) => ThroneSealsView(steps: c.engine.throneSteps ?? const [], before: before ?? (false, 0), now: now),
      transitionsBuilder: (context, a, a2, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

/// The seal screen: [before] the seals as last shown, [now] as they stand ((Deepforge's broken,
/// how many of the other five)); [steps] what still opens the throne. (Public for the ?seals preview.)
class ThroneSealsView extends StatefulWidget {
  const ThroneSealsView({super.key, required this.steps, required this.before, required this.now});
  final List<(String, bool)> steps;
  final (bool, int) before, now;

  @override
  State<ThroneSealsView> createState() => _ThroneSealsState();
}

/// Seal 0 is Deepforge Hold's; 1 to 5 are the other lords'.
bool _broken((bool, int) s, int i) => i == 0 ? s.$1 : i <= s.$2;

class _ThroneSealsState extends State<ThroneSealsView> with SingleTickerProviderStateMixin {
  static const _lead = 900.0, _each = 1100.0, _flare = 1600.0;

  /// The seals that break on this showing, in turn.
  late final List<int> _breaking = [for (var i = 0; i < throneSeals; i++) if (_broken(widget.now, i) && !_broken(widget.before, i)) i];
  late final bool _opens = List.generate(throneSeals, (i) => _broken(widget.now, i)).every((b) => b);
  late final double _total = _lead + _breaking.length * _each + (_opens ? _flare : 0) + 300;
  late final _t = AnimationController(vsync: this, duration: Duration(milliseconds: _total.round()))..forward();
  final _sounded = <int>{};
  var _flared = false;

  @override
  void initState() {
    super.initState();
    _t.addListener(_sounds);
  }

  double get _ms => _t.value * _total;

  /// How far seal [i] is through its breaking (0 to 1), or null if it isn't breaking this time.
  double? _breakAt(int i) {
    final k = _breaking.indexOf(i);
    if (k < 0) return null;
    return ((_ms - _lead - k * _each) / _each).clamp(0.0, 1.0);
  }

  double get _flareAt => _opens ? ((_ms - _lead - _breaking.length * _each) / _flare).clamp(0.0, 1.0) : 0;

  void _sounds() {
    for (final i in _breaking) {
      if ((_breakAt(i) ?? 0) >= .45 && _sounded.add(i)) Audio.play(Sfx.clang, power: 1.4);
    }
    if (_opens && !_flared && _flareAt > .05) {
      _flared = true;
      Audio.play(Sfx.castFire, power: 1.5);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _skipOrLeave() {
    if (_t.isAnimating) {
      _t.value = 1;
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // The ?seals preview: play it again.
      _sounded.clear();
      _flared = false;
      _t.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyLord = continents[throneKeyLand].boss.name.split(',').first.replaceFirst(' Deepforge', '');
    return Scaffold(
      backgroundColor: const Color(0xFF0E0806),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skipOrLeave,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final done = !_t.isAnimating;
              final broken = [for (var i = 0; i < throneSeals; i++) _broken(widget.now, i) ? 1 : 0].fold(0, (a, b) => a + b);
              final String line;
              if (_opens) {
                line = 'The last seal shatters. The way to Vharrax is open.';
              } else if (_breaking.isNotEmpty) {
                line = _breaking.length == 1 ? 'A seal on the Ember Throne cracks and falls.' : '${_breaking.length} seals on the Ember Throne crack and fall.';
              } else {
                line = 'Sealed in old fire. The lords of the lands off the road each hold a seal.';
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    FittedBox(fit: BoxFit.scaleDown, child: Text('THE EMBER THRONE', style: Txt.logo().copyWith(fontSize: 30, color: const Color(0xFFFFC46A)))),
                    const SizedBox(height: 6),
                    Text(line, textAlign: TextAlign.center, style: Txt.body(size: 17, color: Palette.cream)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(box.maxWidth, box.maxHeight).clamp(200.0, 460.0);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: CustomPaint(
                                painter: _SealsPainter(
                                  now: widget.now,
                                  before: widget.before,
                                  breakAt: [for (var i = 0; i < throneSeals; i++) _breakAt(i)],
                                  flare: _flareAt,
                                  opens: _opens,
                                  t: _ms,
                                ),
                                child: Align(
                                  // Deepforge's seal, at the top: named, as it must break.
                                  alignment: const Alignment(0, -.5),
                                  child: Padding(
                                    padding: EdgeInsets.only(top: side * .02),
                                    child: Text(keyLord, style: Txt.label(size: 12.5, color: _broken(widget.now, 0) ? Palette.parch2 : const Color(0xFFFFC46A))),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: done ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          if (!_opens) ...[
                            Text('$broken of $throneSeals seals broken', style: Txt.label(size: 16, color: const Color(0xFFFFC46A))),
                            const SizedBox(height: 6),
                            for (final (text, ok) in widget.steps)
                              if (!ok)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text('· $text', textAlign: TextAlign.center, style: Txt.onStone(size: 14.5, color: Palette.cream)),
                                ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 260,
                            child: StoneButton(title: _opens ? 'To the throne' : 'Onward', tone: ButtonTone.blood, onPressed: done && Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SealsPainter extends CustomPainter {
  _SealsPainter({required this.now, required this.before, required this.breakAt, required this.flare, required this.opens, required this.t});
  final (bool, int) now, before;
  final List<double?> breakAt;
  final double flare, t;
  final bool opens;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero), r = size.width * .36, seal = size.width * .085;
    // The fire behind the throne: brighter as the seals fall, a blaze when the last goes.
    final lit = [for (var i = 0; i < throneSeals; i++) _litOf(i)].fold(0.0, (a, b) => a + b) / throneSeals;
    final glow = .25 + .35 * lit + .9 * flare;
    canvas.drawCircle(
      centre,
      size.width * (.42 + .25 * flare),
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFF9A3A).withValues(alpha: (glow * .7).clamp(0, 1)),
          const Color(0xFFB8381B).withValues(alpha: (glow * .35).clamp(0, 1)),
          const Color(0x00000000),
        ]).createShader(Rect.fromCircle(center: centre, radius: size.width * (.42 + .25 * flare))),
    );
    // The chains of fire from each standing seal to the throne.
    for (var i = 0; i < throneSeals; i++) {
      final at = _sealAt(centre, r, i), b = breakAt[i];
      final standing = b == null ? !_broken(now, i) : b < .45;
      if (!standing) continue;
      final flicker = .55 + .25 * math.sin(t / 140 + i * 1.7);
      canvas.drawLine(at, Offset.lerp(at, centre, .72)!, Paint()
        ..color = const Color(0xFFFF7A2A).withValues(alpha: flicker * (b == null ? 1 : 1 - b / .45))
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
    }
    _throne(canvas, centre, size.width * .2, flare);
    for (var i = 0; i < throneSeals; i++) {
      _seal(canvas, _sealAt(centre, r, i), seal, i, breakAt[i]);
    }
  }

  /// How lit seal [i] counts towards the throne's glow (a broken seal: 1).
  double _litOf(int i) {
    final b = breakAt[i];
    if (b != null) return b > .5 ? 1 : 0;
    return _broken(now, i) ? 1 : 0;
  }

  Offset _sealAt(Offset centre, double r, int i) {
    final a = -math.pi / 2 + i * 2 * math.pi / throneSeals;
    return centre + Offset(math.cos(a), math.sin(a)) * r;
  }

  void _throne(Canvas canvas, Offset c, double s, double flare) {
    // A throne of black stone, seen from the front: a tall spiked back, arms, a seat.
    final back = Path()
      ..moveTo(c.dx - s * .55, c.dy + s * .7)
      ..lineTo(c.dx - s * .55, c.dy - s * .45)
      ..lineTo(c.dx - s * .4, c.dy - s * .8)
      ..lineTo(c.dx - s * .25, c.dy - s * .5)
      ..lineTo(c.dx, c.dy - s * 1.0)
      ..lineTo(c.dx + s * .25, c.dy - s * .5)
      ..lineTo(c.dx + s * .4, c.dy - s * .8)
      ..lineTo(c.dx + s * .55, c.dy - s * .45)
      ..lineTo(c.dx + s * .55, c.dy + s * .7)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF1A0C08));
    canvas.drawPath(back, Paint()
      ..color = Color.lerp(const Color(0xFF8A3A1A), const Color(0xFFFFD27A), flare)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final seat = Rect.fromLTRB(c.dx - s * .75, c.dy + s * .1, c.dx + s * .75, c.dy + s * .32);
    canvas.drawRRect(RRect.fromRectAndRadius(seat, Radius.circular(s * .06)), Paint()..color = const Color(0xFF2A140C));
    for (final dx in [-.75, .55]) {
      canvas.drawRect(Rect.fromLTWH(c.dx + s * dx, c.dy + s * .32, s * .2, s * .42), Paint()..color = const Color(0xFF2A140C));
    }
    // An ember on the seat back, burning up as the seals fall.
    canvas.drawCircle(c + Offset(0, -s * .35), s * (.12 + .1 * flare), Paint()..color = Color.lerp(const Color(0xFFFF7A2A), const Color(0xFFFFF0C0), flare)!);
    if (flare > 0) {
      // The way opens: a ring of fire bursting outward.
      canvas.drawCircle(c, s * (1 + flare * 3.2), Paint()
        ..color = const Color(0xFFFFC46A).withValues(alpha: (1 - flare) * .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - flare) + 1);
    }
  }

  void _seal(Canvas canvas, Offset at, double r, int i, double? b) {
    final key = i == 0;
    // Broken before this showing, or broken now: dark and cracked.
    final wasBroken = b == null && _broken(now, i);
    if (b == null && !wasBroken) {
      _whole(canvas, at, r, key, 0);
      return;
    }
    if (wasBroken) {
      _cracked(canvas, at, r, key);
      return;
    }
    // Breaking: it glows and shakes (to .45), cracks and bursts (to .7), then lies dark and cracked.
    if (b! < .45) {
      final g = b / .45, shake = math.sin(t / 22 + i) * 3.5 * g;
      _whole(canvas, at + Offset(shake, 0), r * (1 + .12 * g), key, g);
      if (g > .5) _cracks(canvas, at + Offset(shake, 0), r * (1 + .12 * g), (g - .5) * 2, i);
    } else {
      final p = ((b - .45) / .55).clamp(0.0, 1.0);
      _cracked(canvas, at, r, key, alpha: p);
      // Shards flying out, and a flash.
      final rnd = math.Random(i * 31 + 7);
      for (var k = 0; k < 12; k++) {
        final a = rnd.nextDouble() * math.pi * 2, d = r * (1 + 3 * p) * (.6 + rnd.nextDouble() * .6);
        final pos = at + Offset(math.cos(a), math.sin(a)) * d + Offset(0, 40 * p * p);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + p * 6);
        canvas.drawPath(
          Path()
            ..moveTo(-r * .18, 0)
            ..lineTo(0, -r * .12)
            ..lineTo(r * .2, r * .05)
            ..close(),
          Paint()..color = const Color(0xFFFFA24A).withValues(alpha: 1 - p),
        );
        canvas.restore();
      }
      canvas.drawCircle(at, r * (1.2 + 2.2 * p), Paint()..color = const Color(0xFFFFE2A0).withValues(alpha: (1 - p) * .55));
    }
  }

  void _whole(Canvas canvas, Offset at, double r, bool key, double heat) {
    canvas.drawCircle(at, r * 1.25, Paint()..color = const Color(0xFFFF7A2A).withValues(alpha: .18 + .4 * heat + .08 * math.sin(t / 300)));
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.lerp(const Color(0xFFFFC46A), const Color(0xFFFFF6D8), heat)!,
          const Color(0xFFE2562A),
          const Color(0xFF7A1E0E),
        ]).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    canvas.drawCircle(at, r, Paint()
      ..color = key ? const Color(0xFFFFE08A) : const Color(0xFF4A160A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = key ? 3 : 2);
    _rune(canvas, at, r, key, const Color(0xFF3A0E06));
  }

  void _cracked(Canvas canvas, Offset at, double r, bool key, {double alpha = 1}) {
    canvas.drawCircle(at, r, Paint()..color = const Color(0xFF2A1A14).withValues(alpha: alpha));
    canvas.drawCircle(at, r, Paint()
      ..color = const Color(0xFF5A4636).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    _rune(canvas, at, r, key, const Color(0xFF5A4636).withValues(alpha: alpha));
    _cracks(canvas, at, r, 1, key ? 0 : 3, colour: const Color(0xFF0E0806).withValues(alpha: alpha));
  }

  /// A rune on a seal: Deepforge's is a hammer over an anvil, the others a flame.
  void _rune(Canvas canvas, Offset at, double r, bool key, Color colour) {
    final p = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (key) {
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - r * .5, at.dy + r * .1)
          ..lineTo(at.dx + r * .5, at.dy + r * .1)
          ..lineTo(at.dx + r * .3, at.dy + r * .3)
          ..lineTo(at.dx + r * .2, at.dy + r * .5)
          ..lineTo(at.dx - r * .2, at.dy + r * .5)
          ..lineTo(at.dx - r * .3, at.dy + r * .3)
          ..close(),
        p,
      );
      canvas.drawLine(at + Offset(-r * .1, -r * .55), at + Offset(r * .25, -r * .1), p);
      canvas.drawLine(at + Offset(-r * .3, -r * .35), at + Offset(r * .1, -r * .7), p);
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy + r * .5)
          ..quadraticBezierTo(at.dx - r * .45, at.dy + r * .2, at.dx - r * .1, at.dy - r * .2)
          ..quadraticBezierTo(at.dx, at.dy - r * .35, at.dx, at.dy - r * .55)
          ..quadraticBezierTo(at.dx + r * .45, at.dy - r * .1, at.dx + r * .3, at.dy + r * .25)
          ..quadraticBezierTo(at.dx + r * .2, at.dy + r * .5, at.dx, at.dy + r * .5),
        p,
      );
    }
  }

  void _cracks(Canvas canvas, Offset at, double r, double grow, int seed, {Color colour = const Color(0xFF1A0804)}) {
    final rnd = math.Random(seed * 13 + 5), p = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      var pos = at + Offset(rnd.nextDouble() - .5, rnd.nextDouble() - .5) * r * .3;
      final a0 = k * math.pi / 2 + rnd.nextDouble();
      final path = Path()..moveTo(pos.dx, pos.dy);
      for (var j = 0; j < 3; j++) {
        final a = a0 + (rnd.nextDouble() - .5) * .9;
        pos += Offset(math.cos(a), math.sin(a)) * r * .34 * grow;
        path.lineTo(pos.dx, pos.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SealsPainter old) => true;
}
