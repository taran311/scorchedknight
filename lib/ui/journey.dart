// What comes after the Ember King, said once, in town: after he falls, New Game+ is open (and how
// to start it), and he rises again for the hardest fight there is, which opens Hardcore; after
// that's won, Hardcore itself. So the next part of the journey is never a label you had to find.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import 'roads_card.dart' show showRoads;
import 'theme.dart';

const _gold = Color(0xFFF2C14E), _blood = Color(0xFFE0503A);

/// Shows the next "what's next" window, if one's due.
Future<void> maybeShowJourney(BuildContext context, GameController c) async {
  final s = c.state, e = c.engine;
  if (s.hardcore || s.inBattle) return;
  if (s.won && !s.did.contains('journey:won')) {
    c.seen('journey:won');
    final risen = s.risenDown.contains(throneLand);
    await _show(context, c, 'The road goes on', Icons.auto_awesome, _gold, [
      (Icons.auto_awesome, _gold, 'New Game+ is open: back to level 1, against tougher foes, with three heirlooms of your choosing from what you carry now.'),
      if (!risen) (Icons.local_fire_department, _blood, 'Vharrax rises again at level ${e.risenLevel(throneLand)}, harder and unbowed. Beat him risen for the Kingslayer gold dye, and Hardcore opens.'),
      (Icons.map, Palette.amber, 'Whatever\'s still standing waits for you here first: side lands, risen bosses, the Colosseum and the Hall.'),
    ]);
    return;
  }
  if (e.hardcoreOpen && !s.did.contains('journey:hc')) {
    c.seen('journey:hc');
    await _show(context, c, 'Hardcore is open', Icons.local_fire_department_rounded, _blood, [
      (Icons.local_fire_department_rounded, _blood, 'A new hero with one life, in a save of their own. Once a fight, Death\'s Door leaves you on 1 HP instead of falling; the next knockout ends the road for good.'),
      (Icons.person, Palette.amber, 'Your hero here stays exactly as they are, and you can go back to them any time between fights.'),
    ]);
  }
}

Future<void> _show(BuildContext context, GameController c, String title, IconData icon, Color col, List<(IconData, Color, String)> lines) async {
  Audio.play(Sfx.quest);
  final see = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Palette.stone1,
      title: Row(
        children: [
          Icon(icon, color: col, size: 26),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, ic, text) in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(i, size: 18, color: ic),
                    const SizedBox(width: 8),
                    Expanded(child: Text(text, style: Txt.onStone(size: 14, color: Palette.cream))),
                  ],
                ),
              ),
            Text('The roads are under your name in your tent, whenever you\'re ready.', style: Txt.onStone(size: 12.5)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Later', style: Txt.label(size: 14, color: Palette.parch2))),
        StoneButton(title: 'See the roads', tone: ButtonTone.amber, compact: true, onPressed: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
  if (see == true && context.mounted) await showRoads(context, c);
}
