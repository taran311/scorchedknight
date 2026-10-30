// A wandering encounter: a little scene on the road with two choices, then what came of it.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/encounters.dart';
import 'loot_window.dart' show resolvePendingLoot;
import 'theme.dart';

const _icons = <String, IconData>{
  'goat': Icons.pets,
  'bard': Icons.music_note,
  'chest': Icons.inventory_2,
  'shrine': Icons.wb_sunny,
  'migs': Icons.storefront,
  'chicken': Icons.egg_alt,
};

/// Shows the waiting encounter, if there is one.
Future<void> showEncounter(BuildContext context, GameController c) async {
  final e = encounterById(c.state.encounter);
  if (e == null) return;
  Audio.play(Sfx.quest);
  await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _EncounterWindow(controller: c, encounter: e));
  if (context.mounted && c.nextLoot != null) await resolvePendingLoot(context, c);
}

class _EncounterWindow extends StatefulWidget {
  const _EncounterWindow({required this.controller, required this.encounter});
  final GameController controller;
  final Encounter encounter;
  @override
  State<_EncounterWindow> createState() => _EncounterWindowState();
}

class _EncounterWindowState extends State<_EncounterWindow> {
  String? _outcome;

  /// The strongbox's die, tumbling (the outcome waits until it lands).
  int? _roll;
  bool _landed = false;

  void _choose(int i) {
    final c = widget.controller;
    final out = c.resolveEncounter(i);
    final roll = c.state.lastRoll;
    if (widget.encounter.id == 'chest' && i == 0 && roll != null) {
      Audio.play(Sfx.coins);
      setState(() {
        _roll = roll;
        _outcome = out;
      });
      return;
    }
    setState(() => _outcome = out);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, e = widget.encounter;
    String label(int i) {
      final base = i == 0 ? e.choices.$1 : e.choices.$2;
      if (i == 0 && e.id == 'bard') return '$base (${c.bardFee} gold)';
      if (i == 0 && e.id == 'migs') return '$base (${c.migsPrice} gold)';
      return base;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Stone(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFF6A4A2A), Color(0xFF2A1A0E)]),
                      border: Border.all(color: Palette.amber, width: 2),
                    ),
                    child: Icon(_icons[e.id] ?? Icons.help_outline, color: const Color(0xFFFFE6A0), size: 34),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ON THE ROAD', style: Txt.label(size: 12, color: Palette.amber)),
                        Text(e.title, style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: parchmentDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_roll != null) ...[
                      _Die(result: _roll!, onLanded: () => setState(() => _landed = true)),
                      const SizedBox(height: 10),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _roll != null && !_landed
                          ? Text('The die tumbles…', key: const ValueKey('rolling'), style: Txt.body(size: 16.5))
                          : Text(_outcome ?? e.text, key: ValueKey(_outcome), style: Txt.body(size: 16.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_outcome == null)
                Row(
                  children: [
                    Expanded(child: StoneButton(title: label(0), tone: ButtonTone.blood, onPressed: () => _choose(0))),
                    const SizedBox(width: 10),
                    Expanded(child: StoneButton(title: label(1), onPressed: () => _choose(1))),
                  ],
                )
              else if (_roll == null || _landed)
                StoneButton(
                  title: c.state.inBattle ? 'To arms!' : 'Onward',
                  tone: ButtonTone.blood,
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A twenty-sided die tumbling across the table, the numbers flicking past slower and slower, and
/// landing on [result]: red for the low rolls (an ambush), gold for a natural 20.
class _Die extends StatefulWidget {
  const _Die({required this.result, required this.onLanded});
  final int result;
  final VoidCallback onLanded;
  @override
  State<_Die> createState() => _DieState();
}

class _DieState extends State<_Die> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  final _rng = math.Random();
  int _shown = 1;
  Timer? _flick;
  var _gap = 45;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    _flick = Timer(Duration(milliseconds: _gap), () {
      if (!mounted) return;
      if (_gap > 260) {
        setState(() => _shown = widget.result);
        Audio.play(widget.result <= chestAmbush ? Sfx.quest : Sfx.coins);
        widget.onLanded();
        return;
      }
      setState(() => _shown = 1 + _rng.nextInt(20));
      _gap = (_gap * 1.22).round();
      _next();
    });
  }

  @override
  void dispose() {
    _flick?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _shown == widget.result && _gap > 260;
    final colour = !done
        ? const Color(0xFFE8DCC0)
        : widget.result == 20
        ? const Color(0xFFFFD24A)
        : widget.result <= chestAmbush
        ? const Color(0xFFE0503A)
        : widget.result >= chestGear
        ? const Color(0xFF9BE27A)
        : const Color(0xFFE8DCC0);
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_spin.value);
        return Transform.rotate(
          angle: (1 - t) * math.pi * 4,
          child: Transform.scale(
            scale: done ? 1.12 : .9 + .1 * t,
            child: SizedBox(
              width: 78,
              height: 78,
              child: CustomPaint(
                painter: _D20(colour),
                child: Center(child: Text('$_shown', style: Txt.label(size: 26, color: const Color(0xFF2A1A0C), weight: FontWeight.w900))),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _D20 extends CustomPainter {
  _D20(this.colour);
  final Color colour;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    final outer = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        outer.moveTo(p.dx, p.dy);
      } else {
        outer.lineTo(p.dx, p.dy);
      }
    }
    outer.close();
    canvas.drawPath(outer.shift(const Offset(0, 3)), Paint()..color = Colors.black45..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(outer, Paint()..shader = RadialGradient(center: const Alignment(-.3, -.4), colors: [Colors.white, colour, Color.lerp(colour, Colors.black, .35)!]).createShader(Offset.zero & size));
    // The facets: a triangle face in the middle, lines out to the corners.
    final tri = [for (var i = 0; i < 3; i++) c + Offset(math.cos(-math.pi / 2 + i * 2 * math.pi / 3), math.sin(-math.pi / 2 + i * 2 * math.pi / 3)) * r * .62];
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Color.lerp(colour, Colors.black, .5)!;
    canvas.drawPath(Path()..addPolygon(tri, true), edge);
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final corner = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(corner, tri[(i ~/ 2) % 3], edge);
      if (i.isOdd) canvas.drawLine(corner, tri[((i + 1) ~/ 2) % 3], edge);
    }
    canvas.drawPath(outer, edge..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_D20 old) => old.colour != colour;
}
