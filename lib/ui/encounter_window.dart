// A wandering encounter: a little scene on the road with two choices, then what came of it.

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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(_outcome ?? e.text, key: ValueKey(_outcome), style: Txt.body(size: 16.5)),
                ),
              ),
              const SizedBox(height: 12),
              if (_outcome == null)
                Row(
                  children: [
                    Expanded(child: StoneButton(title: label(0), tone: ButtonTone.blood, onPressed: () => setState(() => _outcome = c.resolveEncounter(0)))),
                    const SizedBox(width: 10),
                    Expanded(child: StoneButton(title: label(1), onPressed: () => setState(() => _outcome = c.resolveEncounter(1)))),
                  ],
                )
              else
                StoneButton(title: 'Onward', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}
