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
import '../game/crafting.dart' show smithName;
import '../game/loot.dart' show Rarity, RarityInfo;
import '../game/dungeons.dart' show dungeonById;
import '../game/models.dart' show GameState;
import '../game/rules.dart';
import '../audio/audio.dart';
import 'battle_screen.dart';
import 'encounter_window.dart';
import 'fill_column.dart';
import 'gear_glance.dart';
import 'hud.dart';
import 'hero_view.dart' show GearIcon, rarityColour;
import 'map_page.dart';
import 'item_icons.dart';
import 'stat_icons.dart' show InfoChip;
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

  /// Setting out badly hurt with no potion to drink: a word first, since a knock-out costs you.
  Future<bool> _readyToFight() async {
    // Out in the wilds still: home from there first.
    if (!await headHomeFirst(context, c) || !mounted) return false;
    final k = c.state.knight;
    // (Only when there's something to be done about it: a bed at the inn, or gold for a potion.)
    final canMend = c.whyNotRest == null || k.coins >= c.engine.priceOf('potion');
    if (c.state.inBattle || k.potions > 0 || k.hp >= maxHp(k) * .35 || !canMend) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.stone2,
        title: Text('Badly hurt', style: Txt.label(size: 19, color: const Color(0xFFE88A70))),
        content: Text(
          'You\'re on ${k.hp} of ${maxHp(k)} HP with no potions on your belt. ${c.whyNotRest == null ? 'A rest at the Soot & Kettle puts you back to full${k.coins >= c.engine.priceOf('potion') ? ', and Mags sells potions' : ''}.' : 'Mags sells potions.'}',
          style: Txt.onStone(size: 14.5, color: Palette.cream),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Back to town', style: Txt.label(size: 14, color: Palette.amber))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Fight anyway', style: Txt.label(size: 14, color: Palette.parch2))),
        ],
      ),
    );
    if (go == false && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    return go == true;
  }

  Future<void> _go() async {
    final s = c.state;
    if (!await _readyToFight() || !mounted) return;
    c.travel(land);
    final how = s.inBattle ? BattleStart.resume : (trailStep(s, land) == TrailStep.lair ? BattleStart.boss : BattleStart.explore);
    final exit = await openBattle(context, c, how);
    if (!mounted) return;
    if (exit != BattleExit.inn && c.state.encounter != null) await showEncounter(context, c);
    if (!mounted) return;
    // A strongbox that turned out to be bait: into the ambush.
    if (c.state.inBattle) return _go();
    // Knocked out: you wake up back at the inn.
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
    // The boss is down: on to the land it opened, its own trail in place of this one.
    if (exit == BattleExit.onward) _onward();
  }

  Future<void> _onward() async {
    final to = nextLand;
    nextLand = null;
    if (to == null) return;
    // A moment on the map first: the road from here to there.
    await showRoadOpens(context, c, from: land, to: to);
    if (!mounted) return;
    // Beyond you yet (the road showed it stopping at a gate): stay on this trail.
    if (c.whyNotTravel(to) != null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => TrailPage(controller: c, land: to)));
  }

  /// After one of the Ember King's generals.
  Future<void> _hunt() async {
    if (!c.state.inBattle && !c.engine.canHuntGeneral) {
      c.travel(land);
      if (!c.engine.canHuntGeneral) return;
    }
    if (!await _readyToFight() || !mounted) return;
    c.travel(land);
    final exit = await openBattle(context, c, c.state.inBattle ? BattleStart.resume : BattleStart.general);
    if (!mounted) return;
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Against the land's boss, risen.
  Future<void> _goHeroic() async {
    if (!c.state.inBattle && c.engine.whyNotRisen(land) != null) return;
    if (!await _readyToFight() || !mounted) return;
    c.travel(land);
    final exit = await openBattle(context, c, c.state.inBattle ? BattleStart.resume : BattleStart.heroic);
    if (!mounted) return;
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
    if (exit == BattleExit.onward) _onward();
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
              child: LayoutBuilder(builder: (context, viewport) {
                final pad = EdgeInsets.fromLTRB(12, 12, 12, 16 + MediaQuery.paddingOf(context).bottom);
                return SingleChildScrollView(
                padding: pad,
                child: RepaintBoundary(child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: fitWidth(context, aspect: 1000 / 530, below: 330)),
                    // On a phone the page reaches the bottom of the screen: the last card grows.
                    child: fillOnPhone(phone, viewport.maxHeight - pad.vertical, [
                        // On a phone: you, the land's name and the way back above the scene, not on it.
                        if (phone) ...[
                          Row(
                            children: [
                              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Tooltip(message: 'Your gear', child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => showGearGlance(context, c), child: AbsorbPointer(child: HeroCard(controller: c, compact: true)))))),
                              const SizedBox(width: 8),
                              InnBackButton(label: 'World', icon: Icons.public, onPressed: () => Navigator.of(context).pop()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // The land's name on a line of its own (beside the day and progress pills it
                          // was squeezed till "Ravenmoor" broke mid-word), the pills under it.
                          FitText(l.name, wrap: false, minScale: .7, style: Txt.logo().copyWith(fontSize: 22)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(child: Text('Foes level $level', style: Txt.label(size: 13, color: Palette.parch))),
                              if (_nightPill(s, l) case final p?) ...[p, const SizedBox(width: 6)],
                              _landPill(c, land, step, at),
                            ],
                          ),
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
                                        _landPill(c, land, step, at),
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
                        // No ward for this land's hazard: say so every time, right here, so a fight
                        // never takes the HP by surprise.
                        if (s.hazardIn(land)) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(color: const Color(0x33E0A070), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE0A070))),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Color(0xFFE0A070), size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${l.hazard}: −${(hazardShare * 100).round()}% HP a turn. Old Wick\'s ${l.ward} stops it.', style: Txt.label(size: 13.5, color: const Color(0xFFFFD0A0)))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (c.wildHint(land) case final a?) ...[
                          _GearUp(
                            area: wildAreas[a],
                            onGo: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WildsPage(controller: c))),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Once the lair has fallen: its boss, risen (once you're a few levels on), and
                        // patrolling in a slim row under it.
                        if (c.heroicOpen(land)) ...[
                          if (_risenCard(c, land)) ...[
                            _Heroic(controller: c, land: land, onGo: _goHeroic),
                            if (betterWeaponFor(s.knight, continents[land].boss) != null) ...[
                              const SizedBox(height: 6),
                              _WeaponTip(controller: c, foe: continents[land].boss),
                            ],
                            const SizedBox(height: 10),
                          ],
                          _Patrol(controller: c, land: land, onGo: _go),
                        ] else ...[
                          _NextStop(controller: c, land: land, onGo: _go),
                          // A boss fight is a long one: worth the right weapon for it, if one's in your chest.
                          if (trailStep(s, land) == TrailStep.lair && betterWeaponFor(s.knight, continents[land].boss) != null) ...[
                            const SizedBox(height: 6),
                            _WeaponTip(controller: c, foe: continents[land].boss),
                          ],
                        ],
                        const SizedBox(height: 10),
                        // A relic part kept somewhere in this land (a guardian's place or a dungeon's
                        // hoard), once you have its blueprint: what it is, and the way there.
                        for (final (r, i) in relicPartsOn(land))
                          if (!relics[r]!.parts[i].risen && s.bossesDown.contains(r) && !s.forged.contains(r) && !hasRelicPart(s.relicParts, r, i)) ...[
                            _RelicLead(controller: c, relic: r, part: i, land: land),
                            const SizedBox(height: 10),
                          ],
                        // The Throne: the Ember King's generals, and how much weaker each one leaves him.
                        if (land == mainLands - 1 && !s.bossesDown.contains(land)) ...[
                          _Generals(state: s, onHunt: c.engine.canHuntGeneral || c.whyNotTravel(land) == null ? _hunt : null),
                          const SizedBox(height: 10),
                        ],
                        Grow(child: _Lurking(controller: c, land: land)),
                    ]),
                  ),
                )),
              );
              }),
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
    tip: () {
      // Who only comes out after dark, as a list a person would say: 'the Bats, the Ghouls and Gorbo'.
      final who = [for (final n in night) 'the $n', if (l.boss.night) l.boss.name];
      final list = who.length == 1 ? who.first : '${who.take(who.length - 1).join(', ')} and ${who.last}';
      return s.day
          ? 'Day: $list ${who.length == 1 ? 'is' : 'are'} hiding. Night falls in $left more ${left == 1 ? 'fight' : 'fights'}.'
          : 'Night: $list ${who.length == 1 ? 'is' : 'are'} out. A night at the Soot & Kettle brings the morning.';
    }(),
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

/// Before a boss: a weapon in your chest that suits it better than the one in your hand (its
/// weakness, or what it shrugs off), and a tap to put it on.
class _WeaponTip extends StatelessWidget {
  const _WeaponTip({required this.controller, required this.foe});
  final GameController controller;
  final FoeType foe;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, tip = betterWeaponFor(k, foe);
    if (tip == null) return const SizedBox.shrink();
    final g = tip.item, col = rarityColour(g.rarity);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(color: const Color(0xFF1E1912), border: Border.all(color: col.withValues(alpha: .7)), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          GearIcon(item: g, size: 38, heroClass: k.heroClass, dye: k.dye),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.why.toUpperCase(), style: Txt.label(size: 11, color: Palette.amber)),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Your '),
                    TextSpan(text: g.name, style: TextStyle(color: col)),
                    TextSpan(text: ' would hit ${foe.name} harder than your ${k.loadout.weapon?.name ?? 'bare hands'}.'),
                  ]),
                  style: Txt.onStone(size: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          StoneButton(
            title: 'Wear it',
            compact: true,
            onPressed: c.state.inBattle
                ? null
                : () {
                    c.equipFromStash(g.id);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text('You take up your ${g.name}.'), duration: const Duration(seconds: 2)));
                  },
          ),
        ],
      ),
    );
  }
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
      TrailStep.lair => l.boss.night && s.day ? '${l.boss.name} comes out at night. Fight on till dark.' : '${l.boss.name} is waiting.',
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

/// Patrolling a land whose lair has fallen: one slim row (the risen boss, when it's back, above).
class _Patrol extends StatelessWidget {
  const _Patrol({required this.controller, required this.land, required this.onGo});
  final GameController controller;
  final int land;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final l = continents[land];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onGo,
        child: Stone(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Row(
            children: [
              const Icon(Icons.flag, color: Palette.amber, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patrol ${l.name}', style: Txt.label(size: 17, color: Palette.cream, weight: FontWeight.w800)),
                    Text('Gold, gear and ${isSideLand(land) ? '${l.reagent.toLowerCase()}s' : l.reagent}', style: Txt.onStone(size: 13.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _GoBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

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
              Text('Better gear waits in ${area.name}.', style: Txt.onStone(size: 14.5, color: Palette.cream)),
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
    final s = controller.state, why = controller.engine.whyNotRisen(land), ready = why == null, boss = continents[land].boss;
    // Every relic with a part this boss carries (whose blueprint you've found), and this land's own.
    final shown = {for (final (r, i) in relicPartsOn(land)) if (s.bossesDown.contains(r) && relics[r]!.parts[i].risen) r, if (relics.containsKey(land)) land}.toList()..sort();
    const gold = Color(0xFFFFD98A);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // (Not ready yet: a tap says why, rather than doing nothing.)
        onTap: ready
            ? onGo
            : () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('${boss.name} $why.'.replaceFirst('Rises again', 'rises again')), duration: const Duration(seconds: 3))),
        child: Opacity(
          opacity: ready ? 1 : .8,
          child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1A12), Color(0xFF1A0C08)]),
            border: Border.all(color: ready ? gold : gold.withValues(alpha: .4), width: 1.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: ready ? [BoxShadow(color: const Color(0xFFFF8A3A).withValues(alpha: .25), blurRadius: 14)] : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THE BOSS, RISEN', style: Txt.label(size: 12, color: gold)),
                    Text('${boss.name}, Risen', style: Txt.label(size: 19, color: Palette.cream, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(ready ? 'One fight, tougher than before' : why, style: Txt.label(size: 13, color: ready ? Palette.parch2 : gold)),
                    // The Ember King, risen: what's different, and his prize (it goes on into New Game+).
                    if (land == throneLand) ...[
                      const SizedBox(height: 4),
                      Text('Unbowed: stun, freeze or lull him and he loses that turn, but never two running', style: Txt.onStone(size: 12.5, color: Palette.cream)),
                      Text(s.knight.ownedDyes.contains(kingslayerDye) ? '✓ Kingslayer gold dye, yours' : 'Prize: the Kingslayer gold dye, which comes with you into New Game+', style: Txt.onStone(size: 12.5, color: gold)),
                    ],
                    for (final r in shown) ...[
                      const SizedBox(height: 10),
                      _RelicReward(
                        name: r == 2 && s.knight.heroClass == HeroClass.ranger ? 'Briarsong' : relics[r]!.name,
                        relic: relics[r]!,
                        has: [for (var i = 0; i < relics[r]!.parts.length; i++) hasRelicPart(s.relicParts, r, i)],
                        here: land,
                        forged: s.forged.contains(r),
                        // (Only what this trail's risen boss carries is spelled out here: a part at a
                        // place has its own card below.)
                        spell: [for (var i = 0; i < relics[r]!.parts.length; i++) if (relics[r]!.parts[i].risen) i],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: ready ? const Color(0xFF7A2418) : const Color(0xFF2A1C14), border: Border.all(color: ready ? gold : gold.withValues(alpha: .4), width: 2)),
                // Ready: its flame. Not yet: a lock and the level it rises at.
                child: Center(
                  child: ready
                      ? const Icon(Icons.local_fire_department, color: gold, size: 28)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: gold.withValues(alpha: .8), size: 18),
                            Text('Lv ${controller.engine.risenLevel(land)}', style: Txt.label(size: 11.5, color: gold)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// A relic part waiting at a place or in a dungeon in this land: the relic and its parts (the one
/// here glowing, as on the risen boss's card), and a tap to go straight there on the map.
class _RelicLead extends StatelessWidget {
  const _RelicLead({required this.controller, required this.relic, required this.part, required this.land});
  final GameController controller;
  final int relic, part, land;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, r = relics[relic]!, p = r.parts[part];
    final dungeon = p.source == PartSource.dungeon;
    final spot = dungeon ? dungeonById(p.at)?.name : placeById(p.at)?.name;
    const gold = Color(0xFFFFD98A);
    // The risen boss's card above already shows this relic and its parts: here, just the one.
    final onHeroic = _risenCard(controller, land) &&
        (relic == land || relicPartsOn(land).any((e) => e.$1 == relic && relics[relic]!.parts[e.$2].risen && s.bossesDown.contains(relic)));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: controller, place: dungeon ? null : p.at, dungeon: dungeon ? p.at : null))),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1A12), Color(0xFF1A0C08)]),
            border: Border.all(color: gold, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('RELIC PART · ${(spot ?? 'somewhere here').toUpperCase()}', style: Txt.label(size: 12, color: gold))),
                  Text(dungeon ? 'Delve ›' : 'Go there ›', style: Txt.label(size: 13, color: gold, weight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              if (onHeroic)
                Row(
                  children: [
                    const Icon(Icons.place, size: 15, color: gold),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${p.name}, for ${relic == 2 && s.knight.heroClass == HeroClass.ranger ? 'Briarsong' : r.name} · held by ${p.where}', style: Txt.label(size: 12.5, color: gold))),
                  ],
                )
              else
                _RelicReward(
                  name: relic == 2 && s.knight.heroClass == HeroClass.ranger ? 'Briarsong' : r.name,
                  relic: r,
                  has: [for (var i = 0; i < r.parts.length; i++) hasRelicPart(s.relicParts, relic, i)],
                  here: land,
                  forged: false,
                  spell: [part],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The risen boss's prize: a chest, the relic it builds, and its parts as chips (found ones
/// ticked). Risen bosses, guardians and dungeons hold the parts; Dunstan forges the relic once you have them all.
class _RelicReward extends StatelessWidget {
  const _RelicReward({required this.name, required this.relic, required this.has, required this.here, required this.forged, this.spell});
  final String name;

  /// The parts whose keeper is spelled out under the chips (by default every one waiting here).
  final List<int>? spell;
  final Relic relic;

  /// Which parts you hold, and the land whose trail this is.
  final List<bool> has;
  final int here;
  final bool forged;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD98A), green = Color(0xFF9BE27A);
    final parts = relic.parts, all = has.every((h) => h);
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
                      TextSpan(text: forged ? '  · forged' : '  · relic · Lv ${relic.minLevel}+', style: Txt.label(size: 12, color: forged ? green : Palette.parch2)),
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
                        Builder(
                          builder: (context) {
                            // Three looks: found (green, ticked), waiting in this land (gold and
                            // glowing: this is the one to go after here), and elsewhere (greyed out).
                            // (On a card about one way in, a part in this land kept somewhere else is
                            // named by where, not lit as "here": the risen boss's card's gold chips are
                            // only what its own trail gives.)
                            final local = !has[i] && parts[i].land == here && (spell == null || spell!.contains(i));
                            final keeper = parts[i].source == PartSource.dungeon ? dungeonById(parts[i].at)?.name : placeById(parts[i].at)?.name;
                            final elsewhere = !has[i] && !local && parts[i].land == here && keeper != null;
                            final col = has[i] ? green : (local ? gold : Palette.parch2);
                            return Opacity(
                              opacity: has[i] || local ? 1 : (elsewhere ? .75 : .45),
                              child: Tooltip(
                                message: has[i] ? 'Found' : 'Held by ${parts[i].where}',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: has[i] ? green.withValues(alpha: .15) : (local ? gold.withValues(alpha: .18) : Colors.black.withValues(alpha: .3)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: has[i] ? green.withValues(alpha: .7) : (local ? gold : Palette.parch2.withValues(alpha: .3)), width: local ? 1.6 : 1),
                                    boxShadow: local ? [BoxShadow(color: gold.withValues(alpha: .45), blurRadius: 8)] : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(has[i] ? Icons.check : (local || elsewhere ? Icons.place : Icons.lock_outline), size: 14, color: col),
                                      const SizedBox(width: 4),
                                      // (Free to wrap: a long part and place ran out past the box on a phone.)
                                      Flexible(
                                        child: Text(
                                          has[i] ? parts[i].name : (local ? '${parts[i].name} · HERE' : '${parts[i].name} · ${elsewhere ? keeper : continents[parts[i].land].name}'),
                                          style: Txt.label(size: 12.5, color: col, weight: local ? FontWeight.w800 : FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  // The one waiting in this land, spelled out.
                  for (var i = 0; i < parts.length; i++)
                    if (!has[i] && parts[i].land == here && (spell == null || spell!.contains(i))) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 15, color: gold),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Held by ${parts[i].where}', style: Txt.label(size: 12.5, color: gold))),
                        ],
                      ),
                    ],
                  if (all) ...[
                    const SizedBox(height: 4),
                    Text('All found: to Dunstan\'s forge!', style: Txt.label(size: 12.5, color: green)),
                  ],
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
    // What the boss gives the first time, by name on its pill (it used to read only "Reward",
    // with the prize in a tooltip). What it carries when it rises again stays a surprise until
    // then: the risen boss's card names it once the boss is down.
    final (rewardIcon, rewardName, reward) = switch (l.companion) {
      Companion.wolf => (Icons.pets, 'Wolf pup', 'a wolf pup companion'),
      Companion.nightmare => (Icons.nights_stay, 'Nightmare steed', 'the Nightmare, a ghostly steed'),
      Companion.fairy => (Icons.auto_awesome, 'Fairy', 'a fairy companion'),
      Companion.hellhound => (Icons.pets, 'Hellhound pup', 'a hellhound pup companion'),
      Companion.dragon => (Icons.egg, 'Dragon egg', 'a dragon egg'),
      Companion.none => (Icons.emoji_events, 'The end of it all', 'the end of the Great Burning'),
    };
    final relic = relics[land];
    Widget portrait(FoeType f, double size, {(Rarity, double)? seen}) => Tooltip(
      message: [
        f.name,
        if (seen != null) '${seen.$1.label.toLowerCase()} sighting: about 1 fight in ${_oneIn(seen.$2)}',
        if (f.aloft) 'aloft: crossbow or rites',
        if (f.kind != FoeKind.none) '${f.kind.label.toLowerCase()}: weak to ${styleName(f.kind.weakTo!)}',
      ].join(' · '),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A8F96), Color(0xFF4E535A)]),
          border: Border.all(color: seen == null ? Palette.stone0 : Color(seen.$1.argb), width: seen == null ? 2 : 2.5),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [if (seen != null) BoxShadow(color: Color(seen.$1.argb).withValues(alpha: .45), blurRadius: 6)],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(2), child: TypePortrait(type: f))),
            // (No corner symbols: flying, its kind, a pack. They cluttered the faces; the tooltip says
            // it, and the fight's foe card shows what it's weak to.)
            // How often it turns up, on its face: one fight in so many.
            if (seen != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  color: const Color(0xCC120E0A),
                  child: Text('1/${_oneIn(seen.$2)}', textAlign: TextAlign.center, style: Txt.label(size: 11, color: Color(seen.$1.argb), weight: FontWeight.w800)),
                ),
              ),
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
          // The rarer things that turn up here, bordered by how rare: packs, golems, elementals,
          // the Hidden Ones and the land's named foes.
          if (sightingsIn(land, cindervaleClear: s.bossesDown.contains(0), gloomfenClear: s.bossesDown.contains(1)) case final rare when rare.isNotEmpty) ...[
            Text('Rarer sightings', style: Txt.label(size: 12, color: Palette.parch2)),
            const SizedBox(height: 4),
            Wrap(children: [for (final (r, odds) in rare) portrait(r.type, 50, seen: (sightingRarity(odds), odds))]),
          ],
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
                        // (The level it fights at: yours, never below the land's. It used to say "best faced
                        // at" the next land's level, which the road never waited for.)
                        _Pill(icon: Icons.shield_moon, text: 'Lv ${bossLevelFor(land, s.knight.level)}', tip: 'It fights at your level, from ${l.minLevel} up to ${l.minLevel + bossSpanFor(land)}: past that, every level you gain is on your side'),
                        _Pill(icon: rewardIcon, text: rewardName, tip: 'It guards $reward'),
                        if (relic != null && !beaten) _Pill(icon: Icons.description, text: 'Relic blueprint', tip: 'A blueprint for ${relic.name}: its parts are found around the world, and $smithName forges it'),
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

/// One fight in how many, from a chance a fight, in round numbers past twenty (1/25, not 1/27).
int _oneIn(double odds) {
  final n = math.max(2, (1 / odds).round());
  return n <= 20 ? n : (n <= 60 ? (n / 5).round() * 5 : (n / 10).round() * 10);
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
  // (Labelled, so it's plain that this is the button: the whole card fights, too.)
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.bloodDeep,
          border: Border.all(color: const Color(0xFFFFD98A), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: const Center(child: ItemIcon(Item.swords, size: 26)),
      ),
      const SizedBox(height: 3),
      Text('FIGHT', style: Txt.label(size: 11.5, color: const Color(0xFFFFD98A))),
    ],
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
    // One outline, seal and point together: the point's sides meet the seal's rim, and the rim runs
    // round the long way between them. (Drawn as a circle and a triangle, the triangle's top edge
    // was stroked right across the bottom of the seal.)
    final rr = r - 2, half = math.asin(12 / rr), base = Rect.fromCircle(center: centre, radius: rr);
    final pin = Path()
      ..moveTo(r, size.height - 1)
      ..lineTo(centre.dx + rr * math.sin(half), centre.dy + rr * math.cos(half))
      ..arcTo(base, math.pi / 2 - half, -(2 * math.pi - 2 * half), false)
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
      // (Not the first stop's name while the way-on marker stands over the lair: it sits right on
      // top of it, and the name showed half-hidden, like one cut short.)
      if (!(i == 0 && step != TrailStep.stop)) _text(canvas, trailStops[land][i], p + const Offset(0, 40), 15, here ? const Color(0xFFFFE6A0) : const Color(0xCCDDD0B1));
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
      // (Clear of the marker's point over the lair: closer in, his weapon crossed it.)
      TrailStep.patrol => _lair + const Offset(108, 0),
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


/// The Ember King's generals, on the Throne's trail: who's down, who still stands, and what it's
/// worth against him.
class _Generals extends StatelessWidget {
  const _Generals({required this.state, this.onHunt});
  final GameState state;

  /// Go after one still standing (null: all down).
  final VoidCallback? onHunt;

  @override
  Widget build(BuildContext context) {
    final down = state.generalsDown.where(emberGenerals.contains).length;
    const ember = Color(0xFFFF8A4A);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A160C), Color(0xFF1A0A06)]),
        border: Border.all(color: ember, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(down == 0 ? 'THE EMBER KING\'S GENERALS' : 'GENERALS DOWN: $down OF ${emberGenerals.length} · VHARRAX ${(generalCut * down * 100).round()}% WEAKER', style: Txt.label(size: 12, color: ember)),
          const SizedBox(height: 4),
          Text(
            down >= emberGenerals.length
                ? 'All three are down. He\'s as weak as he\'ll ever be.'
                : 'Not needed to face him, but each one you fell first leaves him ${(generalCut * 100).round()}% weaker. They turn up now and then on the road here, or go after them.',
            style: Txt.onStone(size: 13.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final g in emberGenerals)
                InfoChip(
                  icon: Icon(state.generalsDown.contains(g) ? Icons.check_circle : Icons.local_fire_department, size: 14, color: state.generalsDown.contains(g) ? const Color(0xFF9BE27A) : ember),
                  text: g,
                  colour: state.generalsDown.contains(g) ? const Color(0xFF9BE27A) : ember,
                ),
            ],
          ),
          if (down < emberGenerals.length && onHunt != null) ...[
            const SizedBox(height: 8),
            StoneButton(title: 'Hunt a general', caption: '${emberGenerals.length - down} still standing', compact: true, onPressed: onHunt),
          ],
        ],
      ),
    );
  }
}

/// Whether the land's risen boss gets its card: its boss beaten, and not yet beaten risen.
bool _risenCard(GameController c, int land) => c.heroicOpen(land) && !c.heroicCleared(land) && !c.state.risenDown.contains(land);

/// The land's state, by its flag as on the map: stops so far, its boss down (gold), or everything
/// in it done (green, "Cleared"). It used to say "Cleared" as soon as the boss fell, while the
/// map's flag stayed gold with more still to do.
Widget _landPill(GameController c, int land, TrailStep step, int at) {
  if (step != TrailStep.patrol) return _Pill(icon: Icons.flag, text: '$at / $winsForBoss', tip: 'Stops cleared on the way to ${trailLairs[land]}');
  if (c.engine.landCleared(land)) {
    return const _Pill(icon: Icons.flag, text: 'Cleared', colour: Color(0xFF9BE27A), tip: 'Everything here done. Still good for gear, gold and XP.');
  }
  final left = c.engine.landLeft(land);
  return _Pill(icon: Icons.flag, text: 'Boss down', tip: left.isEmpty ? 'The lair has fallen.' : 'Still to do: ${left.join(' · ')}');
}
