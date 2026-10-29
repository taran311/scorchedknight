// One land, up close: its trail of eight stops winding through the land to the boss's lair. You
// walk it a stop at a time; each win clears a stop and moves you on.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/battlegrounds.dart';
import '../art/body.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/scenery.dart' show sceneSize;
import '../art/silhouette.dart';
import '../game/catalog.dart';
import '../game/classes.dart' show HeroClass;
import '../game/controller.dart';
import '../game/models.dart' show GameState;
import '../game/rules.dart';
import '../audio/audio.dart';
import 'battle_screen.dart';
import 'encounter_window.dart';
import 'hud.dart';
import 'item_icons.dart';
import 'theme.dart';
import 'trail_data.dart';
import 'wilds_page.dart';
import '../game/wilds.dart';

/// Where the stops sit on the 1000 × 440 trail picture: along the top, round the bend, back
/// along the bottom to the lair.
// The top band (90 high) is kept clear for your card, the land's name and the way back.
const _nodes = <Offset>[
  Offset(130, 305), Offset(300, 280), Offset(490, 312), Offset(680, 282), Offset(875, 330), //
  Offset(780, 455), Offset(580, 475), Offset(380, 448),
];
const _lair = Offset(165, 452);
const _trailSize = Size(1000, 530);

class TrailPage extends StatefulWidget {
  const TrailPage({super.key, required this.controller, required this.land});
  final GameController controller;
  final int land;

  @override
  State<TrailPage> createState() => _TrailPageState();
}

class _TrailPageState extends State<TrailPage> {
  GameController get c => widget.controller;
  int get land => widget.land;

  Future<void> _go() async {
    final s = c.state;
    c.travel(land);
    final how = s.inBattle ? BattleStart.resume : (trailStep(s, land) == TrailStep.lair ? BattleStart.boss : BattleStart.explore);
    final exit = await openBattle(context, c, how);
    if (!mounted) return;
    if (exit != BattleExit.inn && c.state.encounter != null) await showEncounter(context, c);
    if (!mounted) return;
    // Knocked out: you wake up back at the inn.
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Onto the land's Heroic trail.
  Future<void> _goHeroic() async {
    c.travel(land);
    final exit = await openBattle(context, c, c.state.inBattle ? BattleStart.resume : BattleStart.heroic);
    if (!mounted) return;
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, l = continents[land], step = trailStep(s, land), at = trailAt(s, land);
      final level = foeLevelFor(land, s.knight.level), phone = isPhone(context);
      return MusicZone(track: 'travel', child: Scaffold(
        body: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: fitWidth(context, aspect: 1000 / 530, below: 330)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // On a phone: you, the land's name and the way back above the scene, not on it.
                        if (phone) ...[
                          Row(
                            children: [
                              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: HeroCard(controller: c, compact: true))),
                              const SizedBox(width: 8),
                              InnBackButton(label: 'World', icon: Icons.public, onPressed: () => Navigator.of(context).pop()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: Text(l.name, style: Txt.logo().copyWith(fontSize: 22))),
                              if (_nightPill(s, l) case final p?) ...[p, const SizedBox(width: 6)],
                              _Pill(
                                icon: Icons.flag,
                                text: step == TrailStep.patrol ? 'Cleared' : '$at / $winsForBoss',
                                tip: step == TrailStep.patrol ? 'The lair has fallen. The roads still need watching.' : 'Stops cleared on the way to ${trailLairs[land]}',
                              ),
                            ],
                          ),
                          Text('Foes level $level', style: Txt.label(size: 13, color: Palette.parch)),
                          const SizedBox(height: 6),
                        ],
                        // The land, with its trail drawn over it.
                        Stone(
                          padding: const EdgeInsets.all(3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: AspectRatio(
                              aspectRatio: _trailSize.width / _trailSize.height,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: LayoutBuilder(
                                      builder: (context, box) {
                                        final k = box.maxWidth / _trailSize.width, target = _target(step, at);
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned.fill(
                                              child: GestureDetector(
                                                onTapUp: (d) {
                                                  // Tapping where you're headed sets off too.
                                                  if ((d.localPosition / k - target).distance < 60) _go();
                                                },
                                                child: CustomPaint(painter: _TrailPainter(land: land, at: at, step: step, hero: heroLook(s.knight))),
                                              ),
                                            ),
                                            // The way on: a bobbing marker over where you're headed. Tap it to go.
                                            Positioned(
                                              left: target.dx * k - 34,
                                              top: target.dy * k - (step == TrailStep.stop ? 30 : 46) * k - 84,
                                              child: _GoMarker(
                                                lair: step == TrailStep.lair && !s.inBattle,
                                                tip: s.inBattle ? 'Back to your fight' : trailAction(s, land),
                                                onTap: _go,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  if (!phone)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 8,
                                    child: IgnorePointer(
                                      child: Column(
                                        children: [
                                          Text(l.name, style: Txt.logo().copyWith(fontSize: 26)),
                                          Text('Foes level $level', style: Txt.label(size: 14, color: Palette.parch)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!phone) Positioned(left: 8, top: 8, child: HeroCard(controller: c, compact: true)),
                                  if (!phone)
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        InnBackButton(label: 'World', icon: Icons.public, onPressed: () => Navigator.of(context).pop()),
                                        const SizedBox(height: 8),
                                        _Pill(
                                          icon: Icons.flag,
                                          text: step == TrailStep.patrol ? 'Cleared' : '$at / $winsForBoss',
                                          tip: step == TrailStep.patrol ? 'The lair has fallen. The roads still need watching.' : 'Stops cleared on the way to ${trailLairs[land]}',
                                        ),
                                        if (_nightPill(s, l) case final p?) ...[const SizedBox(height: 6), p],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (c.wildHint(land) case final a?) ...[
                          _GearUp(
                            area: wildAreas[a],
                            onGo: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WildsPage(controller: c))),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _NextStop(controller: c, land: land, onGo: _go),
                        if (c.heroicOpen(land)) ...[
                          const SizedBox(height: 10),
                          _Heroic(controller: c, land: land, onGo: _goHeroic),
                        ],
                        const SizedBox(height: 10),
                        _Lurking(controller: c, land: land),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    },
  );
}

/// In a land whose worst only come out after dark: whether it's day or night, and what that means.
Widget? _nightPill(GameState s, Continent l) {
  final night = [for (final f in l.foes) if (f.night) f.name];
  if (night.isEmpty && !l.boss.night) return null;
  final left = dayLength - s.dayWins;
  return _Pill(
    icon: s.day ? Icons.wb_sunny : Icons.nightlight_round,
    text: s.day ? 'Day' : 'Night',
    colour: s.day ? Palette.amber : const Color(0xFFCFD8FF),
    tip: s.day
        ? 'Day: the ${night.join(', ')} and ${l.boss.name} are hiding. Night falls in $left more ${left == 1 ? 'fight' : 'fights'}.'
        : 'Night: the ${night.join(', ')} are out, and ${l.boss.name} with them. A night at the Soot & Kettle brings the morning.',
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.tip, this.colour = Palette.amber});
  final IconData icon;
  final String text, tip;
  final Color colour;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xCC15110C), border: Border.all(color: Palette.stone3), borderRadius: BorderRadius.circular(3)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: colour, size: 18), const SizedBox(width: 6), Text(text, style: Txt.label(size: 15, color: Palette.cream))]),
    ),
  );
}

/// Where you're headed next, and what's known about it.
class _NextStop extends StatelessWidget {
  const _NextStop({required this.controller, required this.land, required this.onGo});
  final GameController controller;
  final int land;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, l = continents[land], step = trailStep(s, land), at = trailAt(s, land);
    final job = land == 0 && !s.innRepaired;
    final (kicker, title) = switch (step) {
      TrailStep.stop => ('STOP ${at + 1} OF $winsForBoss', trailStops[land][at]),
      TrailStep.lair => ('THE LAIR', trailLairs[land]),
      TrailStep.patrol => ('ON PATROL', 'The roads of ${l.name}'),
    };
    final note = switch (step) {
      TrailStep.stop when job => s.timber < timberNeeded ? 'Soot Goblins, dragging Hob\'s timber' : 'Goblin Warbosses, sitting on Hob\'s iron',
      TrailStep.stop => 'Something waits here. Win to press on.',
      TrailStep.lair => l.boss.night && s.day ? '${l.boss.name} only comes out at night. Fight on here till dark (or come back after).' : '${l.boss.name} is waiting.',
      TrailStep.patrol => 'Foes still prowl. Good for gold, gear and ${isSideLand(land) ? '${l.reagent.toLowerCase()}s' : l.reagent}.',
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onGo,
        child: Stone(
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A8F96), Color(0xFF4E535A)]),
                border: Border.all(color: step == TrailStep.lair ? Palette.amber : Palette.stone0, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: step == TrailStep.lair
                  ? Padding(padding: const EdgeInsets.all(2), child: TypePortrait(type: l.boss))
                  : job
                  ? Padding(padding: const EdgeInsets.all(2), child: TypePortrait(type: l.foes.firstWhere((f) => f.look == (s.timber < timberNeeded ? 'goblin' : 'goblinChief'), orElse: () => l.foes.first)))
                  : const Center(child: Text('?', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Color(0xFFEFE4C8), shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))]))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker, style: Txt.label(size: 12, color: Palette.amber)),
                Text(title, style: Txt.label(size: 22, color: Palette.cream, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(note, style: Txt.onStone(size: 15)),
                if (job) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const ItemIcon(Item.timber, size: 22),
                      Text(' ${s.timber}/$timberNeeded   ', style: Txt.label(size: 15, color: Palette.cream)),
                      const ItemIcon(Item.iron, size: 22),
                      Text(' ${s.ironScrap}/$ironNeeded', style: Txt.label(size: 15, color: Palette.cream)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _GoBadge(),
        ],
      ),
        ),
      ),
    );
  }
}

/// The land's Heroic trail: elites all the way, the boss risen at the end, and the relic's parts.
/// After a few knock-outs on this trail: a nudge towards the wilds, where the gear is better.
class _GearUp extends StatelessWidget {
  const _GearUp({required this.area, required this.onGo});
  final WildArea area;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) => Stone(
    fill: const Color(0xFF2E3A22),
    child: Row(
      children: [
        const Icon(Icons.forest, color: Color(0xFF9FD07A), size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Too tough for now?', style: Txt.label(size: 17, color: Palette.amber)),
              Text('This trail keeps knocking you flat. Better gear waits in ${area.name}, and the deeper you dare, the better it gets. Come back stronger.', style: Txt.onStone(size: 14.5, color: Palette.cream)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 120, child: StoneButton(title: 'To the wilds', compact: true, onPressed: onGo)),
      ],
    ),
  );
}

class _Heroic extends StatelessWidget {
  const _Heroic({required this.controller, required this.land, required this.onGo});
  final GameController controller;
  final int land;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, at = s.heroicWins[land] ?? 0, risen = at >= heroicStops, relic = relics[land];
    final parts = s.relicParts[land] ?? 0, forged = s.forged.contains(land);
    const gold = Color(0xFFFFD98A);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onGo,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1A12), Color(0xFF1A0C08)]),
            border: Border.all(color: gold, width: 1.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: const Color(0xFFFF8A3A).withValues(alpha: .25), blurRadius: 14)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HEROIC TRAIL', style: Txt.label(size: 12, color: gold)),
                    Text(risen ? '${continents[land].boss.name}, Risen' : 'Elite foes · stop ${at + 1} of $heroicStops', style: Txt.label(size: 19, color: Palette.cream, weight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    // The stops, then the crown of the risen boss.
                    Row(
                      children: [
                        for (var i = 0; i < heroicStops; i++)
                          Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: i < at ? gold : const Color(0xFF2A1A12), border: Border.all(color: gold.withValues(alpha: .7))),
                          ),
                        Icon(Icons.workspace_premium, size: 20, color: risen ? const Color(0xFFFF8A3A) : gold.withValues(alpha: .5)),
                      ],
                    ),
                    if (relic != null) ...[
                      const SizedBox(height: 10),
                      _RelicReward(
                        name: land == 2 && s.knight.heroClass == HeroClass.ranger ? 'Briarsong' : relic.name,
                        parts: relic.parts,
                        found: parts,
                        forged: forged,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF7A2418), border: Border.all(color: gold, width: 2)),
                child: Center(child: risen ? const Icon(Icons.workspace_premium, color: gold, size: 28) : const ItemIcon(Item.swords, size: 30)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Heroic trail's prize: a chest, the relic it builds, and its parts as chips (found ones
/// ticked). Elites on the trail drop the parts; Dunstan forges the relic once you have them all.
class _RelicReward extends StatelessWidget {
  const _RelicReward({required this.name, required this.parts, required this.found, required this.forged});
  final String name;
  final List<String> parts;
  final int found;
  final bool forged;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD98A), green = Color(0xFF9BE27A);
    final all = found >= parts.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .3), borderRadius: BorderRadius.circular(4), border: Border.all(color: gold.withValues(alpha: .35))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(forged ? Icons.check_circle : Icons.inventory_2, size: 30, color: forged ? green : gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'REWARD  ', style: Txt.label(size: 11.5, color: gold)),
                      TextSpan(text: name, style: Txt.label(size: 15, color: Palette.cream, weight: FontWeight.w800)),
                      TextSpan(text: forged ? '  · forged' : '  · a relic weapon', style: Txt.label(size: 12, color: forged ? green : Palette.parch2)),
                    ],
                  ),
                ),
                if (!forged) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      for (var i = 0; i < parts.length; i++)
                        Tooltip(
                          message: i < found ? 'Found' : 'Elites on this trail carry it',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: i < found ? green.withValues(alpha: .15) : Colors.black.withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: i < found ? green.withValues(alpha: .7) : Palette.parch2.withValues(alpha: .3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(i < found ? Icons.check : Icons.lock_outline, size: 14, color: i < found ? green : Palette.parch2.withValues(alpha: .7)),
                                const SizedBox(width: 4),
                                Text(parts[i], style: Txt.label(size: 12.5, color: i < found ? green : Palette.parch2)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(all ? 'All parts found: take them to Dunstan\'s forge.' : 'Elites drop the parts. Bring all ${parts.length} to Dunstan.', style: Txt.onStone(size: 12.5, color: all ? green : Palette.parch2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Who lives in this land, the boss, its reward, and the land's hazard.
class _Lurking extends StatelessWidget {
  const _Lurking({required this.controller, required this.land});
  final GameController controller;
  final int land;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, l = continents[land], beaten = s.bossesDown.contains(land);
    final (rewardIcon, reward) = switch (l.companion) {
      Companion.wolf => (Icons.pets, 'a wolf pup companion'),
      Companion.nightmare => (Icons.nights_stay, 'the Nightmare, a ghostly steed'),
      Companion.fairy => (Icons.auto_awesome, 'a fairy companion'),
      Companion.hellhound => (Icons.pets, 'a hellhound pup companion'),
      Companion.dragon => (Icons.egg, 'a dragon egg'),
      Companion.none => (Icons.emoji_events, 'the end of the Great Burning'),
    };
    Widget portrait(FoeType f, double size) => Tooltip(
      message: [
        f.name,
        if (f.aloft) 'aloft: crossbow or rites',
        if (f.kind != FoeKind.none) '${f.kind.label.toLowerCase()}: weak to ${styleName(f.kind.weakTo!)}',
      ].join(' · '),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A8F96), Color(0xFF4E535A)]),
          border: Border.all(color: Palette.stone0, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(2), child: TypePortrait(type: f))),
            if (f.aloft) const Positioned(right: 2, top: 2, child: Icon(Icons.flight, size: 15, color: Palette.cream, shadows: [Shadow(color: Colors.black, blurRadius: 3)])),
            if (f.kind != FoeKind.none) Positioned(left: 2, top: 2, child: Icon(kindIcon(f.kind), size: 15, color: kindColour(f.kind), shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
          ],
        ),
      ),
    );
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lurking here', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 6),
          Wrap(children: [for (final f in l.foes) portrait(f, 58)]),
          const Divider(color: Palette.stone3, height: 14),
          Row(
            children: [
              portrait(l.boss, 64),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(beaten ? 'BOSS · BEATEN' : 'BOSS', style: Txt.label(size: 12, color: beaten ? const Color(0xFF9BE27A) : Palette.amber)),
                    Text(l.boss.name, style: Txt.label(size: 18, color: Palette.cream, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pill(icon: Icons.shield_moon, text: 'Lv ${bossLevel(land)}', tip: 'Best faced at level ${bossLevel(land)}'),
                        _Pill(icon: rewardIcon, text: 'Reward', tip: 'It guards $reward'),
                        if (l.hazard != null)
                          s.warded.contains(land)
                              ? _Pill(icon: Icons.verified_user, colour: const Color(0xFF9BE27A), text: 'Warded', tip: '${l.hazard}: your ${l.ward} keeps it off you')
                              : _Pill(
                                  icon: Icons.warning_amber,
                                  colour: const Color(0xFFE0A070),
                                  text: '−${(hazardShare * 100).round()}% HP / turn',
                                  tip: '${l.hazard}: ${l.hazardText}. Old Wick crafts a ${l.ward} from $reagentsForWard ${continents[land - 1].reagent} (you have ${s.reagents[land - 1]}).',
                                ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Always on screen: back to the world, and the big button onward.
/// Where the trail sends you next: the next stop, the lair, or (once it's beaten) the lair again.
Offset _target(TrailStep step, int at) => switch (step) {
  TrailStep.stop => _nodes[at],
  _ => _lair,
};

/// The little crossed-swords seal on the next-stop card, saying the card itself sets off.
class _GoBadge extends StatelessWidget {
  const _GoBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Palette.bloodDeep,
      border: Border.all(color: const Color(0xFFFFD98A), width: 2),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: const Center(child: ItemIcon(Item.swords, size: 26)),
  );
}

/// A bobbing, glowing seal with a point at the bottom, hovering over the place you go next.
class _GoMarker extends StatefulWidget {
  const _GoMarker({required this.lair, required this.tip, required this.onTap});
  final bool lair;
  final String tip;
  final VoidCallback onTap;
  @override
  State<_GoMarker> createState() => _GoMarkerState();
}

class _GoMarkerState extends State<_GoMarker> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  bool _hover = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.lair ? const Color(0xFFC9963E) : Palette.bloodDeep;
    return Tooltip(
      message: widget.tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final t = _anim.value, bob = math.sin(t * math.pi * 2) * 5, ring = t;
              return SizedBox(
                width: 68,
                height: 84,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // A ring spreading out from the seal, again and again.
                    Positioned(
                      top: 2 + bob - 10 * ring,
                      child: Opacity(
                        opacity: (1 - ring) * .7,
                        child: Container(
                          width: 64 + 20 * ring,
                          height: 64 + 20 * ring,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFD98A), width: 2.5)),
                        ),
                      ),
                    ),
                    Positioned(top: 2 + bob, child: Transform.scale(scale: _hover ? 1.12 : 1, child: child)),
                  ],
                ),
              );
            },
            child: CustomPaint(
              painter: _PinPainter(fill),
              child: SizedBox(
                width: 64,
                height: 78,
                child: Align(
                  alignment: const Alignment(0, -.42),
                  child: widget.lair ? const Icon(Icons.workspace_premium, color: Color(0xFF2A1C0C), size: 34) : const ItemIcon(Item.swords, size: 36),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A map pin: a round seal with a point beneath it.
class _PinPainter extends CustomPainter {
  _PinPainter(this.fill);
  final Color fill;
  @override
  void paint(Canvas c, Size size) {
    final r = size.width / 2, centre = Offset(r, r);
    final pin = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: r - 2))
      ..moveTo(r - 12, r + r * .72)
      ..lineTo(r, size.height - 1)
      ..lineTo(r + 12, r + r * .72)
      ..close();
    c.drawPath(pin.shift(const Offset(0, 3)), Paint()..color = const Color(0x99000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawPath(pin, Paint()..color = fill);
    c.drawPath(pin, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFD98A));
    c.drawCircle(centre, r - 7, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x66FFE6A0));
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.fill != fill;
}

/// The land itself (its battleground, darkened), the trail winding through it, the stops, the
/// lair, and you standing at the next stop.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.land, required this.at, required this.step, required this.hero});
  final int land, at;
  final TrailStep step;
  final Look hero;

  static final _pictures = <int, ui.Picture>{};

  @override
  void paint(Canvas canvas, Size size) {
    final l = continents[land], col = Color(l.argb);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / _trailSize.width);
    // The land: its battleground, scaled to cover, darkened so the trail stands out.
    final bg = _pictures[land] ??= battleground(l.foes.first.look);
    canvas.save();
    final k = _trailSize.width / sceneSize.width;
    canvas.scale(k);
    canvas.translate(0, -(sceneSize.height - _trailSize.height / k) * .6);
    canvas.drawPicture(bg);
    canvas.restore();
    canvas.drawRect(Offset.zero & _trailSize, Paint()..color = const Color(0x8C0A0806));

    // The trail: a worn road from stop to stop, lit where you've walked.
    final pts = [..._nodes, _lair];
    final road = Path()..moveTo(pts.first.dx - 90, pts.first.dy + 10);
    road.quadraticBezierTo(pts.first.dx - 40, pts.first.dy + 20, pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final bend = i == 5 ? const Offset(120, -10) : Offset(0, (i.isEven ? 1 : -1) * 28.0);
      final mid = Offset.lerp(a, b, .5)! + bend;
      road.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(road, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x66000000));
    canvas.drawPath(road, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6A5640));
    // Footsteps so far, in the land's colour.
    final walked = (step == TrailStep.patrol ? pts.length : at + 1).clamp(1, pts.length);
    for (final m in road.computeMetrics()) {
      // The share of the road up to the stop you're at.
      final stopsLen = _lengthTo(road, walked);
      for (double d = 0; d < math.min(stopsLen, m.length); d += 18) {
        canvas.drawPath(m.extractPath(d, d + 9), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(col, Colors.white, .35)!);
      }
    }

    // The stops.
    for (var i = 0; i < _nodes.length; i++) {
      final p = _nodes[i], cleared = step == TrailStep.patrol || i < at, here = step == TrailStep.stop && i == at;
      if (here) {
        canvas.drawCircle(p, 38, Paint()..color = col.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      }
      canvas.drawCircle(p, here ? 24 : 20, Paint()..color = const Color(0xFF15110C));
      canvas.drawCircle(
        p,
        here ? 21 : 17,
        Paint()..color = cleared ? const Color(0xFFC9963E) : (here ? Color.lerp(col, Colors.white, .2)! : const Color(0xFF3A3128)),
      );
      canvas.drawCircle(p, here ? 24 : 20, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = here ? const Color(0xFFFFE6A0) : const Color(0xFF8A7458));
      if (cleared) {
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - 8, p.dy)
            ..lineTo(p.dx - 2, p.dy + 6)
            ..lineTo(p.dx + 9, p.dy - 6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF2A1C0C),
        );
      } else {
        _text(canvas, '${i + 1}', p, here ? 20 : 16, here ? const Color(0xFF15110C) : const Color(0xFFBFB09A));
      }
      // The stop's name under it.
      _text(canvas, trailStops[land][i], p + const Offset(0, 40), 15, here ? const Color(0xFFFFE6A0) : const Color(0xCCDDD0B1));
    }

    // The lair: a dark ring with a crown, glowing once it's open.
    final open = step != TrailStep.stop;
    if (open) canvas.drawCircle(_lair, 56, Paint()..color = const Color(0xFFFF9A3A).withValues(alpha: step == TrailStep.lair ? .55 : .25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawCircle(_lair, 38, Paint()..color = const Color(0xFF15110C));
    canvas.drawCircle(_lair, 34, Paint()..color = step == TrailStep.patrol ? const Color(0xFFC9963E) : (open ? const Color(0xFF7A2A18) : const Color(0xFF2A221C)));
    canvas.drawCircle(_lair, 38, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = open ? const Color(0xFFFFD98A) : const Color(0xFF8A7458));
    if (step == TrailStep.patrol) {
      // A planted flag: beaten.
      canvas.drawLine(_lair + const Offset(-6, 18), _lair + const Offset(-6, -20), Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF2A1C0C));
      canvas.drawPath(Path()..addPolygon([_lair + const Offset(-6, -20), _lair + const Offset(16, -12), _lair + const Offset(-6, -4)], true), Paint()..color = const Color(0xFF8E2117));
    } else {
      final crown = Path()
        ..addPolygon([
          _lair + const Offset(-16, 10), _lair + const Offset(-18, -10), _lair + const Offset(-8, -2), _lair + const Offset(0, -16), //
          _lair + const Offset(8, -2), _lair + const Offset(18, -10), _lair + const Offset(16, 10),
        ], true);
      canvas.drawPath(crown, Paint()..color = open ? const Color(0xFFFFD98A) : const Color(0xFF6A5A44));
      if (!open) {
        // Padlocked until the trail is walked.
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: _lair + const Offset(14, 16), width: 16, height: 13), const Radius.circular(2)), Paint()..color = const Color(0xFFBFB09A));
        canvas.drawArc(Rect.fromCenter(center: _lair + const Offset(14, 9), width: 10, height: 10), math.pi, math.pi, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFBFB09A));
      }
    }
    _text(canvas, trailLairs[land], _lair + const Offset(0, 54), 17, open ? const Color(0xFFFFD98A) : const Color(0xCCDDD0B1));

    // You, a step behind where you're headed: the marker shows the way on.
    final you = switch (step) {
      TrailStep.stop => at == 0 ? const Offset(48, 316) : _nodes[at - 1],
      TrailStep.lair => _nodes.last,
      TrailStep.patrol => _lair + const Offset(70, 0),
    };
    silhouette(
      canvas,
      Offset.zero & _trailSize,
      (c) => drawHumanoid(c, hero, idlePose(hero.stance, 0, still: true), 0, DrawOptions(at: you + const Offset(0, -26), scale: .34, shadow: false), still: true),
      rim: Color.lerp(col, Colors.white, .4)!,
      halo: .7,
    );
    canvas.restore();
  }

  /// How far along [road] the stop numbered [n] (1-based, the lair last) sits.
  double _lengthTo(Path road, int n) {
    final m = road.computeMetrics().first;
    final pts = [..._nodes, _lair];
    final target = pts[n - 1];
    var best = 0.0, bestD = double.infinity;
    for (double d = 0; d <= m.length; d += 4) {
      final t = m.getTangentForOffset(d)!.position;
      final dist = (t - target).distance;
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    return best;
  }

  void _text(Canvas c, String s, Offset centre, double size, Color colour) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: Txt.label(size: size, color: colour, weight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.land != land || old.at != at || old.step != step || old.hero != hero;
}

