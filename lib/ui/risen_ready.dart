// "A harder foe is waiting": the moment you're strong enough for a boss risen again (a few levels
// past beating it), it says so, once. The toughest one, if several wake at once; the trail and the
// map's list keep pointing at the rest quietly.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import 'hud.dart' show TypePortrait;
import 'theme.dart';

/// Tells you about a risen boss you've just grown strong enough for, if there is one. Returns its
/// land if you chose to go after it now, else null.
Future<int?> announceRisen(BuildContext context, GameController c) async {
  final land = c.risenToAnnounce;
  if (land == null) return null;
  c.risenAnnounced();
  Audio.play(Sfx.quest);
  final l = continents[land], boss = l.boss, colour = Color(l.argb);
  final part = [
    for (final (r, i) in relicPartsOn(land))
      if (relics[r]!.parts[i].risen && c.engine.relicPartWanted(r, i)) relics[r]!.parts[i].name,
  ].firstOrNull;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stone(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('A harder foe is waiting', textAlign: TextAlign.center, style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0x55000000),
                      border: Border.all(color: colour, width: 2),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: colour.withValues(alpha: .45), blurRadius: 14)],
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(3), child: TypePortrait(type: boss)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${boss.name}, risen', style: Txt.label(size: 17, color: Palette.cream, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(l.name, style: Txt.label(size: 13.5, color: colour)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'You\'re level ${c.state.knight.level} now, strong enough to face it again. It has risen, harder than the first time: one fight, no trail before it.',
                style: Txt.onStone(size: 14.5),
              ),
              if (part != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.extension, size: 16, color: Color(0xFFFFD98A)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('It carries the $part', style: Txt.label(size: 13.5, color: const Color(0xFFFFD98A)))),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(flex: 2, child: StoneButton(title: 'Later', onPressed: () => Navigator.of(context).pop(false))),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: StoneButton(title: 'Face it', caption: l.name, tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop(true))),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return go == true ? land : null;
}
