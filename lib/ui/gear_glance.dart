// Your gear at a glance, mid-fight: tap your card and a sheet slides up with everything you're
// wearing and what it all adds up to. Tap outside (or drag it down) and you're back in the fight.

import 'package:flutter/material.dart';

import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart';
import '../game/rules.dart';
import 'hero_view.dart';
import 'hud.dart';
import 'stat_icons.dart';
import 'theme.dart';

Future<void> showGearGlance(BuildContext context, GameController c) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * .7),
  builder: (_) => _GearGlance(controller: c),
);

class _GearGlance extends StatelessWidget {
  const _GearGlance({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final k = controller.state.knight, st = heroStats(k), armour = armourTierById(k.loadout.armour);
    final totals = [for (final s in Stat.values) if (st.get(s) != 0) (s, st.get(s))];
    final gear = <(String, GearItem?)>[
      ('Weapon', k.loadout.weapon),
      ('Off-hand', k.loadout.activeOffhand),
      ('Helm', k.loadout.helm),
      ('Gloves', k.loadout.gloves),
      ('Boots', k.loadout.boots),
      ('Cape', k.loadout.cape),
      ('Ring', k.ring),
      ('Trinket', k.trinket),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A3024), Color(0xFF1A1510)]),
        border: Border.all(color: Palette.amberLo, width: 1.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.paddingOf(context).bottom),
      child: SingleChildScrollView(
        child: RepaintBoundary(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Palette.stone3, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 8),
            Text('WHAT YOU\'RE WEARING', style: Txt.label(size: 12, color: Palette.amber)),
            const SizedBox(height: 6),
            // Everything added up.
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                InfoChip(icon: const Icon(Icons.shield, size: 15, color: Palette.cream), text: '${armour.name}: ${(damageReduction(k) * 100).round()}% less damage', colour: Palette.cream, dense: true),
                for (final (s, v) in totals) StatChip(stat: s, value: v, dense: true),
              ],
            ),
            for (final (set, n) in activeSets(k.setGear))
              Padding(padding: const EdgeInsets.only(top: 6), child: SetChips(set: set, dense: true, worn: n)),
            if (armour.perkText case final perk?) Padding(padding: const EdgeInsets.only(top: 5), child: Text('✦ ${armour.name}: $perk', style: Txt.label(size: 12.5, color: Palette.amber))),
            if (k.loadout.armourEnchant case final rune?) Padding(padding: const EdgeInsets.only(top: 5), child: Text('✦ Armour rune, ${rune.title}: ${rune.describe}', style: Txt.label(size: 12.5, color: const Color(0xFFB8A0FF)))),
            const Divider(color: Palette.stone3, height: 16),
            // Piece by piece.
            for (final (label, g) in gear)
              if (g != null) _Piece(label: label, item: g, heroClass: k.heroClass, dye: k.dye),
          ],
        )),
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  const _Piece({required this.label, required this.item, required this.heroClass, required this.dye});
  final String label;
  final GearItem item;
  final HeroClass heroClass;
  final String dye;

  @override
  Widget build(BuildContext context) {
    final g = item, col = Color(g.rarity.argb), sp = g.specialMove;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GearIcon(item: g, size: 38, heroClass: heroClass, dye: dye),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: g.name, style: Txt.label(size: 14, color: col, weight: FontWeight.w800)),
                      TextSpan(text: '  ${label.toUpperCase()}', style: Txt.label(size: 10.5, color: Palette.parch2)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in g.stats.entries) if (e.value != 0) StatChip(stat: e.key, value: e.value, dense: true),
                  ],
                ),
                if (sp != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('★ ${sp.name}: ${sp.desc}', style: Txt.onStone(size: 12.5, color: const Color(0xFFFFD27A)))),
                if (g.enchant case final rune?) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Rune, ${rune.title}: ${rune.describe}', style: Txt.onStone(size: 12.5, color: const Color(0xFFB8A0FF)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The foe in full, from the phone's slim card: every badge with what it means.
Future<void> showFoeGlance(BuildContext context, {required String name, required Color colour, required int level, required List<FoeBadge> badges}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * .6),
  builder: (context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A2420), Color(0xFF1A1010)]),
      border: Border.all(color: const Color(0xFF8E3A2A), width: 1.5),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
    ),
    padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.paddingOf(context).bottom),
    child: SingleChildScrollView(
      child: RepaintBoundary(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Palette.stone3, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 8),
          Text('${name.toUpperCase()} · LV $level', style: Txt.label(size: 13, color: colour, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final b in badges)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  FoeBadge(label: b.label, icons: b.icons, text: b.text, colour: b.colour, solid: b.solid),
                  if (b.tip != null) ...[const SizedBox(width: 8), Expanded(child: Text(b.tip!, style: Txt.onStone(size: 13, color: Palette.parch)))],
                ],
              ),
            ),
        ],
      )),
    ),
  ),
);
