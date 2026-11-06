// Tasks on screen: the next one as a card in the square (claim it there when it's done), and the
// whole list, ticked off, in your tent's Journey tab.

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/rules.dart' show xpToNext;
import '../game/tasks.dart';
import 'task_routes.dart' show taskGoes;
import 'item_icons.dart';
import 'theme.dart';

const _taskGold = Color(0xFFF2C14E);

/// The feat tiers' colours, easy to master.
const _tierColours = [Color(0xFFB8A27A), Color(0xFF9BE27A), Color(0xFF6AC0E8), Color(0xFFC8A0F0), Color(0xFFFF8A3A)];

/// What a task pays, as icons and numbers.
class TaskRewardChips extends StatelessWidget {
  const TaskRewardChips({super.key, required this.controller, required this.reward, this.size = 14});
  final GameController controller;
  final TaskReward reward;
  final double size;

  Widget _bit(Widget icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 3),
      Text(
        text,
        style: Txt.label(size: size - 1, color: Palette.cream),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final r = reward, k = controller.state.knight;
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (r.gold > 0) _bit(ItemIcon(Item.coins, size: size), '${r.gold}'),
        if (r.xp > 0) _bit(Icon(Icons.auto_awesome, size: size, color: const Color(0xFF9ADFFF)), '${(xpToNext(k) * r.xp).round()} XP'),
        if (r.potions > 0) _bit(ItemIcon(Item.potion, size: size), '${r.potions}'),
        if (r.scrolls > 0) _bit(Icon(Icons.description, size: size, color: const Color(0xFFB89AE0)), '${r.scrolls}'),
        if (r.keys > 0) _bit(Icon(Icons.vpn_key_rounded, size: size, color: const Color(0xFFFF9A4A)), '${r.keys}'),
      ],
    );
  }
}

Future<void> _claim(BuildContext context, GameController c, GameTask t) async {
  final got = c.claimTask(t.id);
  if (got == null) return;
  Audio.play(Sfx.coins);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.stone2,
      duration: const Duration(seconds: 2),
      content: Text('✓ ${t.title} · ${got.join(' · ')}', style: Txt.label(size: 13, color: _taskGold)),
    ),
  );
}

/// Every finished task claimed at once.
void _claimAll(BuildContext context, GameController c) {
  var n = 0;
  for (final t in allTasks) {
    if (!c.state.tasksClaimed.contains(t.id) && c.taskDone(t) && c.claimTask(t.id) != null) n++;
  }
  if (n == 0) return;
  Audio.play(Sfx.coins);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.stone2,
      duration: const Duration(seconds: 2),
      content: Text('✓ $n tasks claimed', style: Txt.label(size: 13, color: _taskGold)),
    ),
  );
}

/// The next task, as one row in the square: what to do and what it pays, and a Claim button
/// (glowing) once it's done.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.controller, this.onGo});
  final GameController controller;

  /// Tapped while it's still to do: off to wherever it's done (a shop, the map, your tent).
  final ValueChanged<GameTask>? onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller, t = c.nextTask;
    if (t == null) return const SizedBox.shrink();
    final done = c.taskDone(t), more = c.tasksReady - (done ? 1 : 0), go = !done && onGo != null && taskGoes(t);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: done ? _taskGold : Palette.stone3, width: done ? 1.6 : 1),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF332A1C), Color(0xFF18130D)]),
        boxShadow: [if (done) BoxShadow(color: _taskGold.withValues(alpha: .3), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.flag_rounded, color: done ? _taskGold : Palette.parch2, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(done ? 'TASK DONE${more > 0 ? ' · +$more more' : ''}' : 'TASK', style: Txt.label(size: 11, color: done ? _taskGold : Palette.parch2)),
                FitText(
                  t.title,
                  style: Txt.label(size: 14.5, color: Palette.cream, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                TaskRewardChips(controller: c, reward: t.reward, size: 13),
              ],
            ),
          ),
          // (Several done at once: claim them together, not one tap and one card at a time.)
          if (done)
            SizedBox(
              width: more > 0 ? 112 : 88,
              child: StoneButton(
                title: more > 0 ? 'Claim all · ${more + 1}' : 'Claim',
                compact: true,
                tone: ButtonTone.amber,
                onPressed: () => more > 0 ? _claimAll(context, c) : _claim(context, c, t),
              ),
            ),
          if (go) const Icon(Icons.chevron_right, color: Palette.parch2, size: 26),
        ],
      ),
    );
    return go ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onGo!(t), child: card) : card;
  }
}

/// Every task, in order: claimed ones ticked and dimmed, done ones with a Claim button, the rest
/// with their reward.
class TaskList extends StatelessWidget {
  const TaskList({super.key, required this.controller, this.onGo});
  final GameController controller;

  /// A row still to do, tapped: off to wherever it's done.
  final ValueChanged<GameTask>? onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, claimed = gameTasks.where((t) => s.tasksClaimed.contains(t.id)).length;
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Tasks · $claimed / ${gameTasks.length}', style: Txt.label(size: 15, color: Palette.amber))),
              if (c.tasksReady >= 2)
                Builder(builder: (context) => SizedBox(width: 128, child: StoneButton(title: 'Claim all · ${c.tasksReady}', compact: true, tone: ButtonTone.amber, onPressed: () => _claimAll(context, c)))),
            ],
          ),
          const SizedBox(height: 6),
          for (final t in gameTasks) _row(c, t),
          const SizedBox(height: 12),
          Text('Lands cleared · ${regionTasks.where((t) => s.tasksClaimed.contains(t.id)).length} / ${regionTasks.length}', style: Txt.label(size: 15, color: Palette.amber)),
          Text('A land\'s boss beaten, then beaten again risen', style: Txt.onStone(size: 12)),
          const SizedBox(height: 6),
          for (final t in regionTasks) _row(c, t),
          const SizedBox(height: 12),
          Text('Faction suits · ${suitTasks.where((t) => s.tasksClaimed.contains(t.id)).length} / ${suitTasks.length}', style: Txt.label(size: 15, color: Palette.amber)),
          Text('Wear all five pieces of a suit once', style: Txt.onStone(size: 12)),
          const SizedBox(height: 6),
          for (final t in suitTasks) _row(c, t),
          const SizedBox(height: 12),
          Text('Combat feats · ${featTasks.where((t) => s.tasksClaimed.contains(t.id)).length} / ${featTasks.length}', style: Txt.label(size: 15, color: Palette.amber)),
          Text('Ways of winning, not just winning: done in the fight itself', style: Txt.onStone(size: 12)),
          for (var tier = 0; tier < featTiers.length; tier++) ...[
            const SizedBox(height: 8),
            Text(featTiers[tier].toUpperCase(), style: Txt.label(size: 12, color: _tierColours[tier])),
            for (final t in featTasks.where((t) => t.tier == tier)) _row(c, t),
          ],
        ],
      ),
    );
  }

  Widget _row(GameController c, GameTask t) {
    final s = c.state;
    return Builder(
      builder: (context) {
        final got = s.tasksClaimed.contains(t.id), done = c.taskDone(t);
        final row = Opacity(
          opacity: got ? .45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .35))),
            ),
            child: Row(
              children: [
                Icon(got ? Icons.check_circle : (done ? Icons.check_circle_outline : Icons.radio_button_unchecked), size: 18, color: got || done ? _taskGold : Palette.stone3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.title, style: Txt.onStone(size: 14, color: Palette.cream)),
                ),
                if (done && !got)
                  SizedBox(
                    width: 80,
                    child: StoneButton(title: 'Claim', compact: true, tone: ButtonTone.amber, onPressed: () => _claim(context, c, t)),
                  )
                else
                  TaskRewardChips(controller: c, reward: t.reward, size: 12),
                if (!done && !got && onGo != null && taskGoes(t)) const Icon(Icons.chevron_right, color: Palette.parch2, size: 20),
              ],
            ),
          ),
        );
        return !done && !got && onGo != null && taskGoes(t) ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onGo!(t), child: row) : row;
      },
    );
  }
}
