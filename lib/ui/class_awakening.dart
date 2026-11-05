// The moment you become a class: the last piece of its suit goes on, and the screen dims, your
// knight rises out of a burst of the class's colour, and its name comes up under you, with what it
// is and what it gives you. A few seconds; a tap ends it early. It plays over whatever screen you
// put the piece on in (the app lays it over everything; see main.dart).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/looks.dart';
import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/knight_classes.dart';
import 'hero_view.dart';
import 'theme.dart';

class ClassAwakening extends StatefulWidget {
  const ClassAwakening({super.key, required this.controller});
  final GameController controller;

  @override
  State<ClassAwakening> createState() => _ClassAwakeningState();
}

class _ClassAwakeningState extends State<ClassAwakening> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  String? _id;

  /// How long it plays before it fades by itself.
  static const _length = 7000.0;

  @override
  void initState() {
    super.initState();
    // (&at=3000 with ?awaken: held at that moment, to check it by eye.)
    final hold = double.tryParse(Uri.base.queryParameters['at'] ?? '');
    _ticker = createTicker((d) {
      setState(() => _t = hold ?? d.inMicroseconds / 1000);
      if (_t > _length) _end();
    });
    widget.controller.classAwakened.addListener(_heard);
    // (?awaken=nightblood: plays it on load, to check it by eye.)
    final dev = Uri.base.queryParameters['awaken'];
    if (dev != null) Future.delayed(const Duration(seconds: 3), () => widget.controller.classAwakened.value = dev);
  }

  void _heard() {
    final id = widget.controller.classAwakened.value;
    if (id == null || id == _id) return;
    setState(() {
      _id = id;
      _t = 0;
    });
    Audio.play(Sfx.levelUp);
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void _end() {
    _ticker.stop();
    widget.controller.classAwakened.value = null;
    setState(() => _id = null);
  }

  @override
  void dispose() {
    widget.controller.classAwakened.removeListener(_heard);
    _ticker.dispose();
    super.dispose();
  }

  double _in(double from, double ms) => ((_t - from) / ms).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final cls = knightClassById(_id);
    if (cls == null) return const SizedBox.shrink();
    final k = widget.controller.state.knight, col = Color(cls.argb);
    // In, hold, and out over the last half second.
    final out = 1 - ((_t - (_length - 500)) / 500).clamp(0.0, 1.0);
    final dim = _in(0, 350) * out;
    final rise = Curves.easeOutBack.transform(_in(250, 900));
    final name = Curves.easeOut.transform(_in(900, 600)) * out;
    final lines = Curves.easeOut.transform(_in(1500, 600)) * out;
    final first = cls.rites.firstOrNull;
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _end,
        child: Stack(
          children: [
            // The world goes dark, and the class's colour wells up behind you.
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: .9 * dim))),
            Positioned.fill(child: CustomPaint(painter: _Burst(_t, col, out))),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // You, rising into the light, a little bigger than life.
                    Opacity(
                      opacity: (rise.clamp(0.0, 1.0)) * out,
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - rise)),
                        child: Transform.scale(
                          scale: .85 + .15 * rise,
                          child: SizedBox(
                            width: 220,
                            height: 260,
                            child: DecoratedBox(
                              decoration: BoxDecoration(boxShadow: [BoxShadow(color: col.withValues(alpha: .35 * out), blurRadius: 60, spreadRadius: -20)]),
                              child: HeroFigure(look: heroLook(k)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: name,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - name)),
                        child: Column(
                          children: [
                            Text('YOU ARE NOW', style: Txt.label(size: 13, color: Palette.parch2, weight: FontWeight.w800).copyWith(letterSpacing: 3)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                withArticleOf(cls.name).toUpperCase(),
                                style: Txt.logo().copyWith(fontSize: 34, color: col, letterSpacing: 2, shadows: [Shadow(color: col.withValues(alpha: .8), blurRadius: 18), const Shadow(color: Colors.black, blurRadius: 4)]),
                              ),
                            ),
                            Text(cls.focus, style: Txt.label(size: 15, color: Palette.cream)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: lines,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          children: [
                            Text(cls.blurb, textAlign: TextAlign.center, style: Txt.onStone(size: 14, color: Palette.cream)),
                            const SizedBox(height: 10),
                            if (first != null) _line(Icons.auto_awesome, col, 'Rank 1 rite: ${first.name}'),
                            _line(Icons.military_tech, col, 'At rank $maxRank: ${cls.passive}. ${cls.passiveText}'),
                            _line(Icons.gps_fixed, col, '${cls.bolts}: ${cls.boltsText.toLowerCase()}'),
                            const SizedBox(height: 12),
                            Text('Tap to carry on', style: Txt.label(size: 12, color: Palette.parch2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _line(IconData icon, Color col, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: col),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Txt.onStone(size: 13, color: Palette.cream))),
      ],
    ),
  );
}

/// "Dragon Knight" → "a Dragon Knight".
String withArticleOf(String name) => '${'AEIOU'.contains(name[0]) ? 'an' : 'a'} $name';

/// The light behind you: a ring bursting out, a glow that stays, and motes of the class's colour
/// drifting up.
class _Burst extends CustomPainter {
  _Burst(this.t, this.col, this.out);
  final double t, out;
  final Color col;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 - 90);
    final ring = ((t - 200) / 700).clamp(0.0, 1.0);
    if (ring > 0 && ring < 1) {
      canvas.drawCircle(
        c,
        40 + 340 * Curves.easeOut.transform(ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - ring) + 1
          ..color = col.withValues(alpha: .8 * (1 - ring)),
      );
    }
    final glow = ((t - 150) / 500).clamp(0.0, 1.0) * out;
    canvas.drawCircle(c, 220, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .45 * glow), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 220)));
    // Motes, each on its own slow climb (seeded by its index, so no state is kept).
    for (var i = 0; i < 36; i++) {
      final r = math.Random(i), x = (r.nextDouble() - .5) * 360, speed = .05 + r.nextDouble() * .07, start = r.nextDouble() * 900;
      final age = t - 300 - start;
      if (age < 0) continue;
      final y = 150 - age * speed, a = (1 - (age / 2600)).clamp(0.0, 1.0) * out;
      if (a <= 0) continue;
      canvas.drawCircle(c + Offset(x + math.sin(age / 300 + i) * 10, y), 2 + r.nextDouble() * 2.5, Paint()..color = Color.lerp(col, Colors.white, .35)!.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_Burst old) => true;
}
