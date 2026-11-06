// "The road goes on": what the full game holds, and the one-off unlock (Google Play in the app,
// a link to the app on the web). Opened where the free lands end: the map, the Road card.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../services/full_game.dart';
import 'open_link_stub.dart' if (dart.library.js_interop) 'open_link_web.dart';
import 'theme.dart';

Future<void> showFullGame(BuildContext context, GameController c) => showDialog<void>(
      context: context,
      builder: (_) => _FullGameDialog(controller: c),
    );

class _FullGameDialog extends StatelessWidget {
  const _FullGameDialog({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final g = FullGame.instance;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        if (g.owned) {
          return AlertDialog(
            backgroundColor: Palette.stone1,
            title: Text('The whole road is yours', style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
            content: Text('Thank you. Every land is open, all the way to the Ember Throne.', style: Txt.onStone(size: 15)),
            actions: [StoneButton(title: 'Onward', tone: ButtonTone.amber, compact: true, onPressed: () => Navigator.of(context).pop())],
          );
        }
        const lines = [
          (Icons.map, 'Four more lands on the road, and the Ember King'),
          (Icons.explore, 'The rest of the side lands: dwarves, elves, dragons and more'),
          (Icons.shield, 'The Forge Knight and the Dragon Knight'),
          (Icons.auto_awesome, 'Every legendary, every relic, the Colosseum and the Hall'),
          (Icons.local_fire_department, 'New Game+, Hardcore, and the Fortress'),
        ];
        return AlertDialog(
          backgroundColor: Palette.stone1,
          title: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFFFB04A), size: 26),
              const SizedBox(width: 8),
              Expanded(child: Text('The road goes on', style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The free lands end here. Unlock the full game once, keep it for good: no subscription, no adverts.', style: Txt.onStone(size: 14.5)),
                const SizedBox(height: 10),
                for (final (icon, text) in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: Palette.amber),
                        const SizedBox(width: 8),
                        Expanded(child: Text(text, style: Txt.label(size: 13.5, color: Palette.cream))),
                      ],
                    ),
                  ),
                if (g.problem != null) ...[
                  const SizedBox(height: 4),
                  Text(g.problem!, style: Txt.onStone(size: 13, color: const Color(0xFFFF9A7A))),
                ],
                if (!g.canBuy) ...[
                  const SizedBox(height: 4),
                  Text('The full game is in the Android app. Sign in on both to carry your hero across.', style: Txt.onStone(size: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => _askCode(context), child: Text('Code', style: Txt.label(size: 14, color: Palette.parch2))),
            if (g.canBuy)
              TextButton(
                onPressed: g.busy ? null : g.restore,
                child: Text('Restore', style: Txt.label(size: 14, color: Palette.parch2)),
              ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Later', style: Txt.label(size: 14, color: Palette.parch2))),
            if (g.canBuy)
              StoneButton(
                title: g.busy ? 'One moment…' : (g.price == null ? 'Unlock the full game' : 'Unlock · ${g.price}'),
                tone: ButtonTone.amber,
                compact: true,
                onPressed: g.busy
                    ? null
                    : () async {
                        await g.buy();
                        if (g.owned) Audio.play(Sfx.levelUp);
                      },
              )
            else
              StoneButton(title: 'Get it on Google Play', tone: ButtonTone.amber, compact: true, onPressed: () => openLink(playStoreLink)),
          ],
        );
      },
    );
  }
}

/// "Have a code?": a code that unlocks the full game (Google Play's reviewers get one).
Future<void> _askCode(BuildContext context) async {
  final field = TextEditingController();
  String? wrong;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void tryIt() {
          if (FullGame.instance.redeem(field.text)) {
            Navigator.of(context).pop();
          } else {
            setState(() => wrong = 'That code doesn\'t work');
          }
        }

        return AlertDialog(
          backgroundColor: Palette.stone1,
          title: Text('Have a code?', style: Txt.label(size: 18, color: Palette.cream, weight: FontWeight.w800)),
          content: TextField(
            controller: field,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: Txt.label(size: 16, color: Palette.cream),
            decoration: InputDecoration(hintText: 'XXXXX-XXXXXX-XXXX', errorText: wrong),
            onSubmitted: (_) => tryIt(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: Txt.label(size: 14, color: Palette.parch2))),
            StoneButton(title: 'Unlock', tone: ButtonTone.amber, compact: true, onPressed: tryIt),
          ],
        );
      },
    ),
  );
}
