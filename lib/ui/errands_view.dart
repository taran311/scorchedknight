// Wren, your housekeeper, on screen: her card in the square (out, or back with finds to collect)
// and her errands in your home's tab, to send her off on.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/errands.dart';
import 'item_icons.dart';
import 'loot_window.dart';
import 'theme.dart';

const _wrenColour = Color(0xFF9BC88A);

IconData _icon(String id) => switch (id) {
  'fields' => Icons.grass,
  'wilds' => Icons.landscape,
  _ => Icons.account_balance,
};

Future<void> _collect(BuildContext context, GameController c) async {
  final got = c.collectErrand();
  if (got.isEmpty) return;
  Audio.play(Sfx.coins);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.stone2,
      duration: const Duration(seconds: 3),
      content: Text('$retainerName brought back ${got.join(' · ')}', style: Txt.label(size: 13, color: _wrenColour)),
    ),
  );
  if (c.nextLoot != null && context.mounted) await resolvePendingLoot(context, c, title: 'From $retainerName\'s errand', line: '"Found it under a fallen beam. Thought of you."');
}

/// Wren in the square: out on an errand (and how long), back with finds, or home with nothing to
/// do (tap: off to your home's tab to send her out).
class WrenCard extends StatelessWidget {
  const WrenCard({super.key, required this.controller, this.onOpen});
  final GameController controller;

  /// She's home and idle: open your home's tab.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, e = errandById(s.errand), back = c.errandBack;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: back ? _wrenColour : Palette.stone3, width: back ? 1.6 : 1),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF26301E), Color(0xFF14180F)]),
        boxShadow: [if (back) BoxShadow(color: _wrenColour.withValues(alpha: .3), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(e == null ? Icons.cottage : _icon(e.id), color: _wrenColour, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(retainerName.toUpperCase(), style: Txt.label(size: 11, color: _wrenColour)),
                Text(
                  e == null ? 'Home, and bored' : (back ? 'Back from the errand!' : e.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Txt.label(size: 14.5, color: Palette.cream, weight: FontWeight.w800),
                ),
                if (e != null && !back)
                  Row(
                    children: [
                      for (var i = 0; i < e.fights; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 3, top: 3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: i < e.fights - c.errandLeft ? _wrenColour : Colors.transparent, border: Border.all(color: _wrenColour)),
                        ),
                      const SizedBox(width: 4),
                      Text('back in ${c.errandLeft} ${c.errandLeft == 1 ? 'fight' : 'fights'}', style: Txt.label(size: 11.5, color: Palette.parch2)),
                    ],
                  ),
              ],
            ),
          ),
          if (back) SizedBox(width: 92, child: StoneButton(title: 'Collect', compact: true, tone: ButtonTone.amber, onPressed: () => _collect(context, c))),
          if (e == null && onOpen != null) const Icon(Icons.chevron_right, color: Palette.parch2, size: 26),
        ],
      ),
    );
    return e == null && onOpen != null ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: onOpen, child: card) : card;
  }
}

/// Wren's errands, in your home's tab: what each brings, what she asks, and Send.
class ErrandsPanel extends StatelessWidget {
  const ErrandsPanel({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, k = s.knight;
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$retainerName\'S ERRANDS', style: Txt.label(size: 12, color: _wrenColour)),
          Text('She goes while you fight, and comes back with what she finds.', style: Txt.onStone(size: 12.5)),
          if (s.errand != null) ...[const SizedBox(height: 8), WrenCard(controller: c)],
          const SizedBox(height: 6),
          for (final e in errands)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Opacity(
                opacity: s.home >= e.home ? 1 : .5,
                child: Row(
                  children: [
                    Icon(s.home >= e.home ? _icon(e.id) : Icons.lock, color: _wrenColour, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: Txt.label(size: 14.5, color: Palette.cream, weight: FontWeight.w800)),
                          Text('${e.blurb} · ${e.fights} fights', style: Txt.onStone(size: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 96,
                      child: s.home < e.home
                          ? Text('Keep', textAlign: TextAlign.center, style: Txt.label(size: 12, color: Palette.parch2))
                          : StoneButton(
                              title: 'Send',
                              caption: '${e.feeAt(k.level)} gold',
                              compact: true,
                              tone: ButtonTone.blood,
                              icon: const ItemIcon(Item.coins, size: 14),
                              onPressed: c.whyNotErrand(e.id) == null ? () => c.sendErrand(e.id) : null,
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
