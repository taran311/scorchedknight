// The Hall of the Slain: its three waves (won, under way, still to come), the warriors of the wave
// you're in with the next one drawn large, your health (it carries from fight to fight: no rest in
// a wave), and the way onto the floor. Walking out mid-wave starts it over.

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../art/rare_looks.dart';
import '../audio/audio.dart';
import '../game/catalog.dart' show Aura;
import '../game/controller.dart';
import '../game/hall.dart';
import 'battle_screen.dart';
import 'hero_view.dart';
import 'hud.dart';
import 'theme.dart';

class HallPage extends StatefulWidget {
  const HallPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<HallPage> createState() => _HallPageState();
}

class _HallPageState extends State<HallPage> {
  GameController get c => widget.controller;

  Future<void> _fight() async {
    if (c.engine.whyNotHall() != null) return;
    if (c.startHallFight() == null || !mounted) return;
    Audio.play(Sfx.quest);
    final exit = await openBattle(context, c, BattleStart.resume);
    if (!mounted) return;
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Out of the hall: mid-wave, ask first (the wave starts over).
  Future<void> _leave() async {
    if (c.state.hallStep > 0 && !c.state.inBattle) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Palette.stone1,
          title: Text('Walk out mid-wave?', style: Txt.label(size: 19, color: Palette.cream)),
          content: Text('The warriors you\'ve beaten will get back up, and the wave starts over next time.', style: Txt.onStone(size: 15)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Stay', style: Txt.label(size: 15, color: Palette.parch2))),
            StoneButton(title: 'Walk out', tone: ButtonTone.blood, compact: true, onPressed: () => Navigator.of(ctx).pop(true)),
          ],
        ),
      );
      if (go != true || !mounted) return;
      c.abandonHallWave();
    }
    if (mounted) Navigator.of(context).pop();
  }

  static String? _prize(int wave) => switch (wave) {
    1 => 'War Cry rite',
    2 => 'Gungnir',
    _ => null,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, done = s.hallWaves >= hallWaves.length, wi = c.engine.hallWave, w = hallWaves[wi], next = c.engine.hallNext;
      final why = c.engine.whyNotHall();
      const gold = Color(0xFFFFD27A), frost = Color(0xFFCFE0F0);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (popped, _) {
          if (!popped) _leave();
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: HeroCard(controller: c))),
                          const SizedBox(width: 8),
                          InnBackButton(label: 'Map', icon: Icons.map, onPressed: _leave),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(hallName.toUpperCase(), textAlign: TextAlign.center, style: Txt.label(size: 22, color: gold, weight: FontWeight.w800)),
                      Text(done ? 'The hall has drunk to you' : 'Wave ${s.hallWaves + 1} of ${hallWaves.length}: ${w.name}', textAlign: TextAlign.center, style: Txt.label(size: 13, color: Palette.parch2)),
                      const SizedBox(height: 10),
                      // The wave under way: its warriors, the next one drawn large.
                      Stone(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                SizedBox(width: 96, height: 120, child: HeroFigure(look: auraLook(foeLooks[next.look]!, Aura.ancient, named: true), flip: true)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(done ? 'FOR THE GLORY OF IT' : 'NEXT FROM THE BENCHES', style: Txt.label(size: 11.5, color: gold)),
                                      Text(next.name, style: Txt.label(size: 18, color: Palette.cream, weight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(w.blurb, style: Txt.onStone(size: 13.5)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.campaign, size: 15, color: Color(0xFFFF8A5A)),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text('Every one of them roars a war cry: harder blows from them, softer from you, for $roarTurns turns.', style: Txt.label(size: 12, color: const Color(0xFFFFB08A)))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // The wave's warriors, beaten ones ticked.
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (var i = 0; i < w.warriors.length; i++)
                                  _Chip(text: w.warriors[i].name, state: i < s.hallStep ? 1 : (i == s.hallStep ? 2 : 0)),
                              ],
                            ),
                            if (s.hallStep > 0) ...[
                              const SizedBox(height: 6),
                              Text('No rest in a wave: your health carries on to the next fight.', style: Txt.label(size: 12, color: frost)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // The three waves, and what each is worth.
                      for (var i = 0; i < hallWaves.length; i++)
                        _WaveRow(index: i, wave: hallWaves[i], won: i < s.hallWaves, now: !done && i == wi, prize: _prize(i)),
                      const SizedBox(height: 10),
                      StoneButton(
                        title: why != null ? 'Not now' : (done ? 'Face the Thane again' : (s.hallStep == 0 ? 'Begin the wave' : 'Next: ${next.name.split(' ').first}')),
                        caption: why,
                        tone: ButtonTone.blood,
                        onPressed: why == null ? _fight : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.state});
  final String text;

  /// 0 still to come, 1 beaten, 2 next.
  final int state;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD98A), green = Color(0xFF9BE27A);
    final col = state == 1 ? green : (state == 2 ? gold : Palette.parch2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .3), borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withValues(alpha: state == 0 ? .35 : .9), width: state == 2 ? 1.6 : 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state == 1 ? Icons.check : (state == 2 ? Icons.arrow_forward : Icons.circle_outlined), size: 13, color: col),
          const SizedBox(width: 4),
          Text(text, style: Txt.label(size: 12, color: col)),
        ],
      ),
    );
  }
}

class _WaveRow extends StatelessWidget {
  const _WaveRow({required this.index, required this.wave, required this.won, required this.now, this.prize});
  final int index;
  final HallWave wave;
  final bool won, now;
  final String? prize;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD98A), green = Color(0xFF9BE27A);
    final col = won ? green : (now ? gold : Palette.parch2);
    return Opacity(
      opacity: won || now ? 1 : .6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: now ? .35 : .22),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: now ? gold : Colors.black.withValues(alpha: .55), width: now ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .3), border: Border.all(color: col, width: 1.4)),
              child: Center(child: won ? const Icon(Icons.check, size: 16, color: green) : Text('${index + 1}', style: Txt.label(size: 13, color: col, weight: FontWeight.w800))),
            ),
            const SizedBox(width: 8),
            Expanded(child: FitText('${wave.name} · ${wave.warriors.length} in a row', style: Txt.label(size: 14, color: won || now ? Palette.cream : Palette.parch2))),
            if (prize != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(won ? Icons.check_circle : Icons.workspace_premium, size: 15, color: won ? green : gold),
                  const SizedBox(width: 3),
                  Text(prize!, style: Txt.label(size: 12, color: won ? green : gold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
