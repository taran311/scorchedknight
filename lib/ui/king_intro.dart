// Before the last fight, the first time: the Ember Throne. Dark, then embers rising, the throne
// room catching light, and Vharrax lifting his head out of the fire, bigger than the screen can
// hold. He speaks (he knows what you've done to get here: his hounds, his seals, his generals),
// then roars, and his name burns across the screen. Tap moves the words on; a skip in the corner
// goes straight to the fight.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/creatures.dart';
import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import 'theme.dart';

/// Plays the intro if it's the first time at his door; then the fight goes ahead.
Future<void> maybeShowKingIntro(BuildContext context, GameController c) async {
  if (c.state.did.contains('kingintro') || c.state.continent != throneLand || c.state.bossesDown.contains(throneLand)) return;
  c.engine.mark('kingintro');
  final s = c.state, name = s.settings.name.isEmpty ? 'knight' : s.settings.name;
  final felled = [for (final g in emberGenerals) if (s.generalsDown.contains(g)) g.split(' ').first];
  final lines = <(String?, String)>[
    (null, 'The Ember Throne. The stone underfoot is warm, and the air shimmers like a forge mouth.'),
    (null, 'Something vast shifts in the dark beyond the pillars. Two eyes open, each the size of a shield.'),
    ('Vharrax', 'So. The sooty one. I burned your village, $name. I did not think to look in the ashes.'),
    ('Vharrax', felled.isEmpty
        ? 'You slew my hound and broke my seals. My generals did not even slow you. No matter.'
        : 'You slew my hound, broke my seals, and cut down ${felled.length == 1 ? felled.first : '${felled.sublist(0, felled.length - 1).join(', ')} and ${felled.last}'}. They were loyal. I will remember them, briefly.'),
    ('Vharrax', 'Come, then. Let us see what ash is made of.'),
  ];
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => _KingIntro(lines: lines),
      transitionsBuilder: (context, a, a2, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _KingIntro extends StatefulWidget {
  const _KingIntro({required this.lines});
  final List<(String?, String)> lines;

  @override
  State<_KingIntro> createState() => _KingIntroState();
}

class _KingIntroState extends State<_KingIntro> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  /// When he lifts his head, and when the words begin.
  static const _riseAt = 900.0, _wordsAt = 2600.0;

  /// The line showing, when it started, and the roar's moment (after the last line).
  int _line = 0;
  double _lineAt = _wordsAt;
  double? _roarAt;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      setState(() => _t = d.inMicroseconds / 1000);
      // A line holds for a while, then the next comes in by itself.
      if (_roarAt == null && _t > _lineAt + _hold(_line)) _next();
    })..start();
    Audio.play(Sfx.castFire, power: .6);
  }

  double _hold(int i) => 1400 + widget.lines[i].$2.length * 38;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _next() {
    if (_t < _wordsAt) return;
    if (_roarAt != null) {
      if (_t > _roarAt! + 900) Navigator.of(context).pop();
      return;
    }
    final shown = ((_t - _lineAt) / 28).floor();
    // Mid-line: the whole line at once.
    if (shown < widget.lines[_line].$2.length) {
      _lineAt = _t - widget.lines[_line].$2.length * 28;
      return;
    }
    if (_line < widget.lines.length - 1) {
      _line++;
      _lineAt = _t;
    } else {
      _roarAt = _t;
      Audio.play(Sfx.castFire, power: 1.6);
      Audio.play(Sfx.bash, power: 1.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roar = _roarAt == null ? 0.0 : ((_t - _roarAt!) / 1400).clamp(0.0, 1.0);
    // The roar shakes the room.
    final shake = _roarAt == null || roar >= 1 ? Offset.zero : Offset(math.sin(_t / 18) * 9 * (1 - roar), math.cos(_t / 23) * 6 * (1 - roar));
    final (who, text) = widget.lines[_line];
    final typed = ((_t - _lineAt) / 28).floor().clamp(0, text.length);
    final words = _t < _wordsAt || _roarAt != null ? 0.0 : ((_t - _lineAt) / 300).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xFF080403),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: shake,
                child: CustomPaint(painter: _ThronePainter(_t, _riseAt, roar)),
              ),
            ),
            // His name, burning in after the roar.
            if (_roarAt != null)
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -.62),
                  child: Opacity(
                    opacity: Curves.easeOut.transform(((_t - _roarAt! - 300) / 700).clamp(0.0, 1.0)),
                    child: Transform.scale(
                      scale: 1.25 - .25 * Curves.easeOutBack.transform(((_t - _roarAt! - 300) / 700).clamp(0.0, 1.0)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'VHARRAX',
                                style: Txt.logo().copyWith(fontSize: 58, color: const Color(0xFFFFC46A), letterSpacing: 4, shadows: const [Shadow(color: Color(0xFFFF6A1A), blurRadius: 24), Shadow(color: Colors.black, blurRadius: 6)]),
                              ),
                            ),
                            Text('THE EMBER KING', style: Txt.label(size: 18, color: const Color(0xFFFFE2B0), weight: FontWeight.w800).copyWith(letterSpacing: 6)),
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: ((_t - _roarAt! - 900) / 400).clamp(0.0, 1.0),
                              child: Text('Tap to fight', style: Txt.label(size: 14, color: Palette.parch2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // The words, at the foot of the screen.
            if (words > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 28,
                child: SafeArea(
                  top: false,
                  child: Opacity(
                    opacity: words,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          decoration: BoxDecoration(
                            color: const Color(0xD9120806),
                            border: Border.all(color: who == null ? const Color(0xFF5A3A28) : const Color(0xFFFF7A2A), width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (who != null) Text(who.toUpperCase(), style: Txt.label(size: 13, color: const Color(0xFFFF9A4A), weight: FontWeight.w800).copyWith(letterSpacing: 2)),
                              Text(
                                text.substring(0, typed),
                                style: who == null
                                    ? Txt.body(size: 17, color: Palette.cream).copyWith(fontStyle: FontStyle.italic)
                                    : Txt.body(size: 18, color: const Color(0xFFFFE2B0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Straight to the fight.
            Positioned(
              right: 8,
              top: 8,
              child: SafeArea(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Skip', style: Txt.label(size: 14, color: Palette.parch2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The throne room: a fire glow welling up from below, pillars in silhouette, embers rising, and
/// Vharrax lifting out of the dark; at the roar, a flash and the glow flaring.
class _ThronePainter extends CustomPainter {
  _ThronePainter(this.t, this.riseAt, this.roar);
  final double t, riseAt, roar;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final light = ((t - 200) / 1800).clamp(0.0, 1.0);
    final flare = roar > 0 ? math.sin(roar * math.pi) : 0.0;
    // The glow from the fire pit below the throne.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, .55),
          radius: 1.1,
          colors: [
            Color.lerp(const Color(0xFF000000), const Color(0xFFB8401A), light * (.75 + .25 * math.sin(t / 400)) + flare * .4)!,
            Color.lerp(const Color(0xFF000000), const Color(0xFF4A1408), light)!,
            const Color(0xFF080403),
          ],
          stops: const [0, .45, 1],
        ).createShader(Offset.zero & size),
    );
    // Pillars, left and right, in silhouette.
    final pillar = Paint()..color = const Color(0xFF0E0605);
    for (final x in [w * .06, w * .2, w * .8, w * .94]) {
      final pw = w * .07;
      canvas.drawRect(Rect.fromLTWH(x - pw / 2, h * .08, pw, h), pillar);
      canvas.drawRect(Rect.fromLTWH(x - pw * .7, h * .08, pw * 1.4, h * .03), pillar);
    }
    // Vharrax: rising from below the frame, filling it.
    final rise = Curves.easeOutCubic.transform(((t - riseAt) / 2400).clamp(0.0, 1.0));
    if (rise > 0) {
      final look = foeDragons['emberKing']!;
      final target = math.min(h * .62, w * 1.05 * .8);
      final scale = target / (dragonHeight * 1.1 * look.scale);
      final at = Offset(w * .6, h * .8 + (1 - rise) * h * .45);
      drawFoeDragon(canvas, look, at, scale, t, alpha: rise, breathing: roar > 0 && roar < .8);
    }
    // Embers drifting up, more as the room lights.
    final rnd = math.Random(4);
    for (var i = 0; i < 70; i++) {
      final x0 = rnd.nextDouble() * w, speed = 30 + rnd.nextDouble() * 60, phase = rnd.nextDouble() * 10000, r = 1 + rnd.nextDouble() * 2.2;
      final y = h - ((t + phase) / 1000 * speed) % (h + 40);
      final x = x0 + math.sin((t + phase) / 700) * 12;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFB15A).withValues(alpha: (.25 + .6 * rnd.nextDouble()) * light));
    }
    // The roar: a flash.
    if (flare > 0) canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFD7A0).withValues(alpha: flare * .35));
  }

  @override
  bool shouldRepaint(_ThronePainter old) => true;
}
