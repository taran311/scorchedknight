// "Your suit is ready": the moment Dunstan could finish one of the class suits for you (a
// blueprint for every piece you lack, and the trophies, bars and gold for all of them), he says
// so, once per suit. Shown in the square; the forge's badge keeps reminding you quietly after.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/crafting.dart';
import '../game/knight_classes.dart';
import '../game/loot.dart';
import 'theme.dart';

/// Tells you about the next class suit you could finish, if there is one. True if you chose to go
/// to the forge.
Future<bool> announceSuitReady(BuildContext context, GameController c) async {
  final id = c.suitToAnnounce;
  if (id == null) return false;
  final cls = knightClassById(id)!, set = gearSetById(id)!, missing = c.engine.suitPiecesMissing(id);
  c.suitAnnounced(id);
  Audio.play(Sfx.quest);
  final go = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colour = Color(cls.argb);
      final n = missing.length;
      return AlertDialog(
        backgroundColor: Palette.stone1,
        title: Row(
          children: [
            Icon(Icons.shield, color: colour, size: 26),
            const SizedBox(width: 8),
            Expanded(child: Text('${set.name} suit ready to forge', style: Txt.label(size: 19, color: Palette.cream, weight: FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n == setPieceSlots.length
                  ? '$smithName can forge the whole suit: you have every blueprint, and the trophies, bars and gold for all five pieces.'
                  : '$smithName can forge the ${n == 1 ? 'last piece' : '$n pieces'} you\'re missing: you have the blueprint${n == 1 ? '' : 's'}, and the trophies, bars and gold for ${n == 1 ? 'it' : 'all of them'}.',
              style: Txt.onStone(size: 14.5),
            ),
            const SizedBox(height: 8),
            Text('Still to forge: ${[for (final slot in missing) pieceNoun(slot)].join(', ')}', style: Txt.label(size: 13.5, color: Palette.cream)),
            const SizedBox(height: 10),
            Text('Wear all five and you fight as the ${cls.name}: ${cls.focus.toLowerCase()}.', style: Txt.label(size: 14, color: colour)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Later', style: Txt.label(size: 14, color: Palette.parch2))),
          StoneButton(title: 'To the forge', tone: ButtonTone.amber, compact: true, onPressed: () => Navigator.of(context).pop(true)),
        ],
      );
    },
  );
  return go == true;
}
