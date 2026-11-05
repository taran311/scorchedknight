// The three roads, kept in your tent: the first time through, New Game+ (open once the Ember King
// falls) and Hardcore (open once New Game+ is beaten): one life, in a save of its own. Locked ones say
// what opens them, so there's always a next road in sight. Under your name in the tent, a label says
// which road you're on; tap it for the card.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/models.dart';
import 'theme.dart';

const _gold = Color(0xFFF2C14E), _blood = Color(0xFFE0503A), _ash = Color(0xFFE8B070), _dim = Color(0xFF8A8070);

/// Which road this save is on: (name, colour, icon).
(String, Color, IconData) roadOf(GameState s) => s.hardcore
    ? ('Hardcore · one life', _blood, Icons.local_fire_department_rounded)
    : s.ng > 0
    ? ('New Game+', _gold, Icons.auto_awesome)
    : ('The road', _ash, Icons.flag_rounded);

/// The road you're on, as a small label (under your name in the tent): tap it for all three.
class RoadLabel extends StatelessWidget {
  const RoadLabel({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final (name, col, icon) = roadOf(s);
    final next = !s.hardcore && s.won && controller.whyNotNewGamePlus == null;
    return Tooltip(
      message: 'The roads: tap to see all three',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showRoads(context, controller),
        child: Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.fromLTRB(7, 2, 6, 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col.withValues(alpha: .75)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: col),
              const SizedBox(width: 4),
              Text(name.toUpperCase(), style: Txt.label(size: 11, color: col, weight: FontWeight.w800).copyWith(letterSpacing: .6)),
              const SizedBox(width: 3),
              // A new road to start: a dot, like a waiting task's.
              if (next) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 2), decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
              Icon(Icons.chevron_right_rounded, size: 14, color: col.withValues(alpha: .8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three roads, in a sheet over the tent.
Future<void> showRoads(BuildContext context, GameController controller) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListenableBuilder(listenable: controller, builder: (context, _) => RoadsCard(controller: controller, onDone: () => Navigator.of(context).pop())),
    ),
  ),
);

class RoadsCard extends StatelessWidget {
  const RoadsCard({super.key, required this.controller, this.onDone});
  final GameController controller;

  /// After switching roads (to close the sheet it's in).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, hc = s.hardcore;
    final ngOpen = !hc && s.won && c.whyNotNewGamePlus == null, onNg = !hc && s.ng > 0;
    final run = s.hcRun, best = s.hcBest;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (hc ? _blood : _gold).withValues(alpha: .8), width: 1.6),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: hc ? const [Color(0xFF3A1610), Color(0xFF1A0B08)] : const [Color(0xFF2E2614), Color(0xFF17120A)]),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('THE ROADS', style: Txt.label(size: 14, color: hc ? _blood : _gold, weight: FontWeight.w800))),
              if (onDone != null) InkWell(onTap: onDone, child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close_rounded, size: 20, color: Palette.parch2))),
            ],
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(Icons.flag_rounded, 'The road', hc || s.won || onNg ? 'Done' : 'You\'re here', _ash, done: hc || s.won || onNg, here: !hc && !onNg && !s.won)),
                const SizedBox(width: 6),
                Expanded(
                  child: _tile(
                    Icons.auto_awesome,
                    'New Game+',
                    hc ? 'Done' : (ngOpen ? 'Tougher foes, legendaries ×2' : (onNg ? (s.won ? 'Done' : 'You\'re here') : 'Beat the Ember King')),
                    _gold,
                    locked: !hc && !ngOpen && !onNg,
                    here: onNg && !s.won,
                    done: hc || (onNg && s.won),
                    action: ngOpen ? ('Begin', () => _beginNg(context)) : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _tile(
                    Icons.local_fire_department_rounded,
                    'Hardcore',
                    hc
                        ? (s.won ? 'The King is dead' : 'You\'re here')
                        : c.hardcoreOpen
                        ? (run != null ? '${run['name']} · Lv ${run['level']}' : (best != null ? 'Best: ${best['won'] == true ? 'beat the King' : 'Lv ${best['level']}'}' : 'One life. Own save'))
                        : 'Beat New Game+',
                    _blood,
                    locked: !hc && !c.hardcoreOpen,
                    here: hc,
                    action: hc
                        ? ('Main hero', s.inBattle ? null : () => _leaveHc())
                        : c.hardcoreOpen
                        ? (run != null ? 'Continue' : 'Begin', s.inBattle ? null : () => _beginHc(context, run != null))
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hc
                ? 'One life, and Death\'s Door: once a fight, the blow that would end you leaves you on 1 HP instead, with a turn to drink or run (and better odds of getting away). The next one ends the road.'
                : 'Hardcore: a new hero with one life, in a save of its own. Death\'s Door gives one reprieve a fight; the next knockout ends the road for good.',
            style: Txt.onStone(size: 12, color: Palette.parch2),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String line, Color colour, {bool locked = false, bool here = false, bool done = false, (String, VoidCallback?)? action}) {
    final col = locked ? _dim : colour;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: locked ? .35 : .22),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: col.withValues(alpha: here ? .95 : (locked ? .3 : .55)), width: here ? 1.8 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(locked ? Icons.lock_rounded : (done ? Icons.check_circle_rounded : icon), size: 20, color: col),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: Txt.label(size: 13, color: col, weight: FontWeight.w800))),
          const SizedBox(height: 3),
          Text(line, textAlign: TextAlign.center, maxLines: 2, style: Txt.onStone(size: 11.5, color: locked ? _dim : Palette.parch2)),
          if (action != null) ...[
            const Spacer(),
            const SizedBox(height: 5),
            SizedBox(height: 30, child: StoneButton(title: action.$1, compact: true, tone: colour == _blood ? ButtonTone.blood : ButtonTone.amber, onPressed: action.$2)),
          ],
        ],
      ),
    );
  }

  Future<void> _leaveHc() async {
    onDone?.call();
    await controller.leaveHardcore();
  }

  Future<void> _beginHc(BuildContext context, bool resume) async {
    final c = controller;
    if (!resume) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Palette.stone2,
          title: Text('A hardcore road?', style: Txt.label(size: 18, color: _blood)),
          content: Text(
            'A new hero, from level 1, with one life. Once a fight, Death\'s Door leaves you on 1 HP instead of falling, with a turn to drink or run. '
            'The knockout after that ends the road for good, and that hero is gone. '
            'It\'s a save of its own: your main hero stays exactly as they are, and you can go back to them any time between fights.',
            style: Txt.onStone(size: 14, color: Palette.cream),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Not yet', style: Txt.label(size: 14))),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Begin', style: Txt.label(size: 14, color: _blood))),
          ],
        ),
      );
      if (sure != true) return;
    }
    Audio.play(Sfx.quest);
    onDone?.call();
    await c.enterHardcore();
  }

  Future<void> _beginNg(BuildContext context) async {
    final c = controller;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.stone2,
        title: Text('Start the road again?', style: Txt.label(size: 18, color: _gold)),
        content: Text(
          'You start again at level 1 in Cindervale, against tougher foes, with legendaries twice as likely. Your Cinder keys and the vault\'s pieces come with you (back to level 1, growing as you do). Gold, other gear, companions and the map start over.',
          style: Txt.onStone(size: 14, color: Palette.cream),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Not yet', style: Txt.label(size: 14))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Begin', style: Txt.label(size: 14, color: _gold))),
        ],
      ),
    );
    if (sure != true) return;
    Audio.play(Sfx.levelUp);
    onDone?.call();
    await c.newGamePlus();
  }
}
