// The Ash Colosseum: the seven bouts as a ladder (won, next, still to come), the gladiator you face
// next drawn large with what they're like, the prizes along the way, and the gate out onto the sand.

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../art/rare_looks.dart';
import '../audio/audio.dart';
import '../game/arena.dart';
import '../game/controller.dart';
import '../game/loot.dart' show GearSlot, gearSetById;
import 'battle_screen.dart';
import 'hero_view.dart';
import 'hud.dart';
import 'theme.dart';

class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  GameController get c => widget.controller;

  Future<void> _fight() async {
    if (c.engine.whyNotArena() != null) return;
    if (c.startArenaBout() == null || !mounted) return;
    Audio.play(Sfx.quest);
    final exit = await openBattle(context, c, BattleStart.resume);
    if (!mounted) return;
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  static String _prize(GearSlot s) => switch (s) {
    GearSlot.gloves => 'Manica',
    GearSlot.boots => 'Greaves',
    GearSlot.ring => 'Signet',
    _ => 'Galea and lorica',
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, won = s.arenaWins, done = won >= arenaBouts.length, next = c.engine.arenaBout, b = arenaBouts[next];
      final why = c.engine.whyNotArena();
      const sand = Color(0xFFE8C890), bronze = Color(0xFFE0A050);
      return Scaffold(
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
                        InnBackButton(label: 'Map', icon: Icons.map, onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(arenaName.toUpperCase(), textAlign: TextAlign.center, style: Txt.label(size: 22, color: bronze, weight: FontWeight.w800)),
                    Text(done ? 'You are the Champion of the Ash' : 'Bout ${won + 1} of ${arenaBouts.length}', textAlign: TextAlign.center, style: Txt.label(size: 13, color: Palette.parch2)),
                    const SizedBox(height: 10),
                    // Who's next, drawn large.
                    Stone(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SizedBox(width: 96, height: 120, child: HeroFigure(look: auraLook(foeLooks[b.look]!, arenaAura(next), named: true), flip: true)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(done ? 'A REMATCH, FOR THE CROWD' : 'NEXT ON THE SAND', style: Txt.label(size: 11.5, color: bronze)),
                                Text(b.name, style: Txt.label(size: 18, color: Palette.cream, weight: FontWeight.w800)),
                                Text(b.school, style: Txt.label(size: 13, color: sand)),
                                const SizedBox(height: 4),
                                Text(b.blurb, style: Txt.onStone(size: 13.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // The ladder.
                    for (var i = 0; i < arenaBouts.length; i++) _BoutRow(bout: arenaBouts[i], index: i, won: i < won, next: !done && i == next, prize: arenaBouts[i].prize == null ? null : _prize(arenaBouts[i].prize!)),
                    const SizedBox(height: 8),
                    // The prize for all of it.
                    Stone(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('THE CHAMPION\'S SET · ${done ? 'won' : 'five pieces, won on the sand'}', style: Txt.label(size: 12, color: bronze)),
                          const SizedBox(height: 4),
                          SetChips(set: gearSetById(arenaSet)!, dense: true, named: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    StoneButton(
                      title: why != null ? 'Not now' : (done ? 'Face the Champion again' : 'Fight ${b.name.split(' ').first}'),
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
      );
    },
  );
}

/// One bout on the ladder: its number (ticked once won, glowing if next), the gladiator, and the
/// prize it carries.
class _BoutRow extends StatelessWidget {
  const _BoutRow({required this.bout, required this.index, required this.won, required this.next, this.prize});
  final ArenaBout bout;
  final int index;
  final bool won, next;
  final String? prize;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD98A), green = Color(0xFF9BE27A);
    final col = won ? green : (next ? gold : Palette.parch2);
    return Opacity(
      opacity: won || next ? 1 : .6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: next ? .35 : .22),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: next ? gold : Colors.black.withValues(alpha: .55), width: next ? 1.5 : 1),
          boxShadow: next ? [BoxShadow(color: gold.withValues(alpha: .3), blurRadius: 8)] : null,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: won ? green.withValues(alpha: .2) : Colors.black.withValues(alpha: .3), border: Border.all(color: col, width: 1.4)),
              child: Center(child: won ? const Icon(Icons.check, size: 16, color: green) : Text('${index + 1}', style: Txt.label(size: 13, color: col, weight: FontWeight.w800))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: bout.name, style: Txt.label(size: 14, color: won || next ? Palette.cream : Palette.parch2, weight: FontWeight.w700)),
                  TextSpan(text: '  ${bout.school}', style: Txt.label(size: 12, color: Palette.parch2)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
