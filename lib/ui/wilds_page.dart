// The Wilds: pick an area, then keep stepping into the unknown. Each step is a fight, a chest, a
// thief, a trap, a campfire... Everything you find goes in your pack, and the pack only becomes
// yours when you get it home. Leave from a waystone and you keep it all; run for it anywhere else
// and you lose part of it. The page always says exactly what leaving would cost.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/rules.dart';
import '../game/wilds.dart';
import 'battle_screen.dart';
import 'hud.dart';
import '../game/loot.dart';
import 'hero_view.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'theme.dart';

const _icons = <WildEvent, IconData>{
  WildEvent.chest: Icons.inventory_2,
  WildEvent.thief: Icons.back_hand,
  WildEvent.trap: Icons.warning_amber,
  WildEvent.campfire: Icons.local_fire_department,
  WildEvent.pedlar: Icons.storefront,
  WildEvent.traveller: Icons.explore,
  WildEvent.hoard: Icons.diamond,
  WildEvent.waystone: Icons.signpost,
};

class WildsPage extends StatefulWidget {
  const WildsPage({super.key, required this.controller, this.area});
  final GameController controller;

  /// The area picked on the map (already entered by the map).
  final int? area;

  @override
  State<WildsPage> createState() => _WildsPageState();
}

class _WildsPageState extends State<WildsPage> {
  GameController get c => widget.controller;

  /// What the last step brought, once dealt with (shown until the next step).
  String? _outcome;

  /// Where this trip's journal lines begin.
  int _logFrom = 0;

  @override
  void initState() {
    super.initState();
    _logFrom = math.max(0, c.state.journal.length - 4);
    if (widget.area != null && c.state.wild == widget.area) _logFrom = math.max(0, c.state.journal.length - 1);
  }

  Future<void> _enter(int a) async {
    if (!c.enterWild(a)) return;
    Audio.play(Sfx.quest);
    setState(() {
      _outcome = null;
      _logFrom = c.state.journal.length - 1;
    });
  }

  Future<void> _step() async {
    if (c.state.inBattle) return _fight(BattleStart.resume);
    if (c.state.wildEvent != null) return;
    final e = c.stepWild();
    setState(() => _outcome = e == WildEvent.waystone ? e.text : null);
    if (e.isFight) {
      await _fight(BattleStart.wild);
    } else {
      Audio.play(e == WildEvent.waystone ? Sfx.levelUp : Sfx.quest, power: .7);
    }
  }

  Future<void> _fight(BattleStart how) async {
    final exit = await openBattle(context, c, how);
    if (!mounted) return;
    if (exit == BattleExit.inn) {
      // Knocked out: whatever the scavengers left is in your spoils, back at the inn.
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _outcome = null);
  }

  Future<void> _choose(int choice) async {
    final e = c.wildEvent;
    final out = c.resolveWild(choice);
    setState(() => _outcome = out);
    if (e == WildEvent.thief && choice == 0 && c.state.inBattle) {
      await _fight(BattleStart.wild);
      if (mounted) setState(() => _outcome = 'You caught up with the cutpurse.');
    }
  }

  Future<void> _leave() async {
    final s = c.state, share = c.leaveShare;
    if (share > 0 && (s.packGold > 0 || s.pack.isNotEmpty)) {
      final (gold, items) = lossOf(share, s.packGold, s.pack.length);
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => _Confirm(
          title: 'Run for it?',
          text:
              'You\'re between waystones. Bandits follow anyone who runs from the wilds, and you\'ll drop about ${(share * 100).round()}% of your pack on the way: $gold gold${items > 0 ? ' and $items piece${items == 1 ? '' : 's'} of gear' : ''}.\n\nThe next waystone is ${nextWaystone(s.wildDepth) - s.wildDepth} step${nextWaystone(s.wildDepth) - s.wildDepth == 1 ? '' : 's'} on. Leave from there and you keep everything.',
          yes: 'Run for it',
          no: 'Stay',
        ),
      );
      if (go != true || !mounted) return;
    }
    final exit = c.leaveWild();
    if (exit == null || !mounted) return;
    final something = exit.gold > 0 || exit.items > 0 || !exit.lost.none;
    if (something) {
      Audio.play(exit.safe ? Sfx.coins : Sfx.flee);
      await showDialog<void>(context: context, builder: (_) => _Haul(exit: exit));
    }
    if (mounted && c.nextLoot != null) await resolvePendingLoot(context, c, title: 'From the wilds');
    // Back out to the map you came from.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, a = s.wild;
      return MusicZone(
        track: 'travel',
        child: Scaffold(
          body: Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 20 + MediaQuery.paddingOf(context).bottom),
                  child: RepaintBoundary(child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: InnBackButton(label: 'Map', icon: Icons.public, onPressed: () => Navigator.of(context).pop())),
                          const SizedBox(height: 10),
                          a == null ? _picker() : _trip(a),
                        ],
                      ),
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  // ---------------- choosing where to go ----------------

  Widget _picker() {
    final s = c.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('THE WILDS', style: Txt.logo()),
        const SizedBox(height: 2),
        Text('Off the road, no story, no rules. Just you and whatever\'s out there.', style: Txt.onStone(size: 15)),
        const SizedBox(height: 10),
        const _Rules(),
        const SizedBox(height: 10),
        for (var i = 0; i < wildAreas.length; i++) ...[
          _AreaCard(
            area: wildAreas[i],
            locked: c.wildOpen(i) ? null : c.whyNotWild(i),
            best: s.wildBest[i] ?? 0,
            suggested: c.wildHint(s.continent) == i,
            onEnter: c.whyNotWild(i) == null ? () => _enter(i) : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ---------------- out in the wilds ----------------

  Widget _trip(int a) {
    final s = c.state, area = wildAreas[a], k = s.knight, col = Color(area.argb), d = s.wildDepth, e = c.wildEvent;
    final next = nextWaystone(d), at = isWaystone(d);
    final log = s.journal.length > _logFrom ? s.journal.sublist(_logFrom) : const <JournalEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where you are: the path behind you, the waystones ahead, fog over the rest.
        Stone(
          padding: const EdgeInsets.all(3),
          child: SizedBox(
            height: 170,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PathPainter(depth: d, colour: col, best: s.wildBest[a] ?? 0, alert: s.wildAlert))),
                Positioned(
                  left: 10,
                  top: 8,
                  right: 10,
                  child: Row(
                    children: [
                      Expanded(child: Text(area.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 20, color: col, weight: FontWeight.w800))),
                      Text(d == 0 ? 'At the edge' : 'Step $d', style: Txt.label(size: 18, color: Palette.cream)),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  right: 10,
                  child: Row(
                    children: [
                      Icon(at && e == null ? Icons.shield : Icons.signpost, size: 18, color: at && e == null ? const Color(0xFF9FE07A) : Palette.parch2),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          at && e == null ? 'Safe to head home: you\'ll keep everything.' : 'Next waystone: step $next (${next - d} to go)',
                          overflow: TextOverflow.ellipsis,
                          style: Txt.label(size: 14, color: at && e == null ? const Color(0xFFBFF0A0) : Palette.parch),
                        ),
                      ),
                      Text('Foes +${wildLevels(d, a)} lv · gold ×${wildGold(d).toStringAsFixed(2)}', style: Txt.label(size: 13, color: Palette.amber)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // What to do next, right under the trail: press on, or head for home.
        _actions(),
        const SizedBox(height: 10),
        // You and your pack.
        Stone(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Color(0xFFE05A4A), size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: Bar(value: k.hp, max: maxHp(k), height: 18, label: '${k.hp} / ${maxHp(k)}', colours: const [Color(0xFFE0604A), Color(0xFF8A1E14)])),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Drink a potion: +${potionHeal(k)} HP',
                    child: SizedBox(
                      width: 128,
                      child: StoneButton(
                        title: 'Potion · ${k.potions}',
                        compact: true,
                        onPressed: k.potions > 0 && k.hp < maxHp(k) && !s.inBattle
                            ? () {
                                if (c.drinkPotion() > 0) Audio.play(Sfx.potion);
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.backpack, color: Palette.amber, size: 22),
                  const SizedBox(width: 6),
                  Text('Your pack', style: Txt.label(size: 16)),
                  const SizedBox(width: 10),
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD45A), size: 18),
                  const SizedBox(width: 3),
                  Text(fmt(s.packGold), style: Txt.label(size: 18, color: const Color(0xFFFFD45A))),
                  const Spacer(),
                  Flexible(child: Text('Not yours until you get it home', overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 13))),
                ],
              ),
              const SizedBox(height: 6),
              if (s.pack.isEmpty)
                Text('Nothing but crumbs and a bit of string, so far.', style: Txt.onStone(size: 14))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in s.pack)
                      Tooltip(
                        message: '${g.name} · ${g.rarity.label} · level ${g.level}',
                        child: GearIcon(item: g, size: 46, heroClass: k.heroClass, dye: k.dye),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // What's in front of you.
        if (e != null && e != WildEvent.waystone)
          _EventCard(event: e, controller: c, onChoose: _choose)
        else if (_outcome != null)
          _Note(icon: at ? Icons.signpost : Icons.check_circle_outline, text: _outcome!)
        else if (s.inBattle)
          const _Note(icon: Icons.sports_martial_arts, text: 'A fight is waiting for you. Step back in to finish it.')
        else if (d == 0) ...[
          _Note(icon: Icons.forest, text: area.blurb),
          const SizedBox(height: 10),
          const _Rules(),
        ]
        else
          const _Note(icon: Icons.help_outline, text: 'The path winds on into the ash. You can\'t see what\'s next.'),
        if (log.isNotEmpty) ...[
          const SizedBox(height: 10),
          Stone(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('On this trip', style: Txt.label(size: 14, color: Palette.amber)),
                const SizedBox(height: 4),
                for (final l in log.reversed.take(6)) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(l.text, style: Txt.onStone(size: 13.5))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _actions() {
    final s = c.state;
    final List<Widget> row;
    {
      final share = c.leaveShare, empty = s.packGold == 0 && s.pack.isEmpty;
      final (gold, items) = lossOf(share, s.packGold, s.pack.length);
      final pending = s.wildEvent != null;
      row = [
        Expanded(
          flex: 2,
          child: StoneButton(
            title: share == 0 || empty ? 'Head home' : 'Run for it',
            caption: share == 0 ? 'Keep everything' : (empty ? 'Nothing to lose yet' : 'Lose $gold gold${items > 0 ? ', $items gear' : ''}'),
            onPressed: s.inBattle ? null : _leave,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: StoneButton(
            title: s.inBattle ? 'Back into the fight' : 'Venture deeper',
            caption: s.inBattle ? null : (pending ? 'Deal with this first' : 'Step ${s.wildDepth + 1}${isWaystone(s.wildDepth + 1) ? ' · a waystone' : ' · unknown'}'),
            tone: ButtonTone.blood,
            onPressed: pending ? null : _step,
          ),
        ),
      ];
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: row);
  }
}

/// How the wilds work, in four lines.
class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Palette.inkSoft),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Txt.body(size: 15))),
        ],
      ),
    );
    return Parchment(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How the wilds work', style: Txt.inkLabel(size: 16)),
          const SizedBox(height: 6),
          line(Icons.help_outline, 'Every step is a surprise. No healing on the way.'),
          line(Icons.backpack, 'Loot goes in your pack. Deeper: tougher, richer.'),
          line(Icons.signpost, 'Waystone every $waystoneEvery steps: leave there, keep it all.'),
          line(Icons.directions_run, 'Leave early −${(fleeLoss * 100).round()}% · flee a fight −${(fightFleeLoss * 100).round()}% · knocked out −${(koLoss * 100).round()}%'),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.locked, required this.best, required this.suggested, required this.onEnter});
  final WildArea area;
  final String? locked;
  final int best;
  final bool suggested;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    final col = Color(area.argb);
    return Opacity(
      opacity: locked == null ? 1 : .6,
      child: Stone(
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Palette.stone0, width: 2),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(col, Colors.black, .35)!, Color.lerp(col, Colors.black, .75)!]),
              ),
              child: Icon(locked == null ? Icons.forest : Icons.lock, color: Palette.cream, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(area.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 20, color: col, weight: FontWeight.w800))),
                      if (suggested) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Palette.bloodDeep, borderRadius: BorderRadius.circular(3), border: Border.all(color: Palette.amber)),
                          child: Text('Gear up here', style: Txt.label(size: 12, color: Palette.amber)),
                        ),
                      ],
                    ],
                  ),
                  Text(locked ?? area.blurb, style: Txt.onStone(size: 14.5, color: locked == null ? Palette.parch2 : Palette.cream)),
                  if (locked == null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${[for (final l in area.lands) continents[l].name].join(' & ')} foes · ruled by ${area.warlord.$1}${best > 0 ? ' · deepest: step $best' : ''}',
                      style: Txt.label(size: 13, color: Palette.parch),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 110, child: StoneButton(title: 'Head in', tone: ButtonTone.blood, compact: true, onPressed: onEnter)),
          ],
        ),
      ),
    );
  }
}

/// A step waiting on your choice.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.controller, required this.onChoose});
  final WildEvent event;
  final GameController controller;
  final void Function(int) onChoose;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state;
    final (yes, no) = event.choices;
    final first = switch (event) {
      WildEvent.pedlar => '$yes (${pedlarPrice(s.knight.level)} gold)',
      _ => yes,
    };
    final warn = switch (event) {
      WildEvent.thief => 'Let him go and he takes ${(s.packGold * thiefTake).floor()} gold from your pack. Chase him and it\'s a fight.',
      WildEvent.hoard => 'Grab it all and they\'ll come after you: the next step will be a fight.',
      WildEvent.campfire => 'Heals ${(campfireHeal * 100).round()}% of your HP.',
      _ => null,
    };
    return Stone(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFF6A4A2A), Color(0xFF2A1A0E)]),
                  border: Border.all(color: Palette.amber, width: 2),
                ),
                child: Icon(_icons[event] ?? Icons.help_outline, color: const Color(0xFFFFE6A0), size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP ${s.wildDepth}', style: Txt.label(size: 12, color: Palette.amber)),
                    Text(event.title, style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: parchmentDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.text, style: Txt.body(size: 16)),
                if (warn != null) ...[const SizedBox(height: 6), Text(warn, style: Txt.body(size: 14, color: Palette.inkSoft, italic: true))],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StoneButton(title: first, tone: ButtonTone.blood, onPressed: () => onChoose(0))),
              const SizedBox(width: 10),
              Expanded(child: StoneButton(title: no, onPressed: () => onChoose(1))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Parchment(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Palette.inkSoft, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Txt.body(size: 16))),
      ],
    ),
  );
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.title, required this.text, required this.yes, required this.no});
  final String title, text, yes, no;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Stone(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Txt.label(size: 20, color: Palette.amber, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), decoration: parchmentDecoration(), child: Text(text, style: Txt.body(size: 16))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StoneButton(title: yes, tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop(true))),
                const SizedBox(width: 10),
                Expanded(child: StoneButton(title: no, onPressed: () => Navigator.of(context).pop(false))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// What you brought home.
class _Haul extends StatelessWidget {
  const _Haul({required this.exit});
  final WildExit exit;

  @override
  Widget build(BuildContext context) {
    final x = exit;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Stone(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(x.safe ? 'Home safe' : 'You got out', style: Txt.label(size: 22, color: Palette.amber, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: parchmentDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${x.depth} step${x.depth == 1 ? '' : 's'} into the wilds.', style: Txt.body(size: 16)),
                    const SizedBox(height: 4),
                    Text(
                      x.gold == 0 && x.items == 0 ? 'You came back empty-handed.' : 'You brought home ${fmt(x.gold)} gold${x.items > 0 ? ' and ${x.items} piece${x.items == 1 ? '' : 's'} of gear' : ''}.',
                      style: Txt.body(size: 16, weight: FontWeight.w700),
                    ),
                    if (!x.lost.none) ...[
                      const SizedBox(height: 4),
                      Text('Lost on the way out: ${x.lost.summary}.', style: Txt.body(size: 15, color: const Color(0xFF7A1D14))),
                    ],
                    if (x.safe && (x.gold > 0 || x.items > 0)) ...[
                      const SizedBox(height: 4),
                      Text('You left from a waystone, so nobody followed you.', style: Txt.body(size: 14, color: Palette.inkSoft, italic: true)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StoneButton(title: x.items > 0 ? 'Sort the gear' : 'Onward', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trail through the wilds: steps behind you, where you stand, and waystones ahead in the fog.
class _PathPainter extends CustomPainter {
  _PathPainter({required this.depth, required this.colour, required this.best, required this.alert});
  final int depth, best;
  final Color colour;
  final bool alert;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    // Sky and ground.
    c.drawRect(
      Offset.zero & size,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(colour, Colors.black, .78)!, const Color(0xFF15110C)]).createShader(Offset.zero & size),
    );
    final hills = Path()..moveTo(0, h * .62);
    for (var x = 0.0; x <= w; x += 24) {
      hills.lineTo(x, h * .58 + math.sin(x / 70 + depth) * 9 + math.sin(x / 23) * 4);
    }
    hills
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    c.drawPath(hills, Paint()..color = Color.lerp(colour, Colors.black, .82)!);
    // Dead trees on the skyline.
    final tree = Paint()
      ..color = const Color(0xFF0E0B08)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final x = (i * 137.0 + depth * 41) % w, y = h * .58 + math.sin(x / 70 + depth) * 9;
      c.drawLine(Offset(x, y), Offset(x, y - 18 - (i % 3) * 6), tree);
      c.drawLine(Offset(x, y - 12), Offset(x + 6, y - 18), tree);
      c.drawLine(Offset(x, y - 8), Offset(x - 5, y - 13), tree);
    }

    // The steps: a few behind you, then up to the waystone after next.
    final from = math.max(0, depth - 3), to = math.max(from + 8, nextWaystone(depth));
    final n = to - from;
    Offset at(int i) {
      final t = (i - from) / n;
      return Offset(30 + t * (w - 60), h * .66 + math.sin(i * 1.3) * 10);
    }

    final path = Path()..moveTo(at(from).dx, at(from).dy);
    for (var i = from + 1; i <= to; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    c.drawPath(path, Paint()
      ..color = const Color(0xFF5A4A36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    // Fog over what's ahead.
    final fogFrom = at(depth).dx + 14;
    c.drawRect(
      Rect.fromLTRB(fogFrom, 0, w, h),
      Paint()..shader = const LinearGradient(colors: [Color(0x00151110), Color(0xCC151110)], stops: [0, .35]).createShader(Rect.fromLTRB(fogFrom, 0, w, h)),
    );

    for (var i = from; i <= to; i++) {
      final p = at(i), stone = isWaystone(i);
      if (stone) {
        // A carved standing stone, glowing faintly.
        final lit = i == depth;
        c.drawCircle(p + const Offset(0, -14), lit ? 22 : 14, Paint()
          ..color = (lit ? const Color(0xFF9FE07A) : const Color(0xFF6FA0C0)).withValues(alpha: lit ? .35 : .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        final s = Path()
          ..moveTo(p.dx - 7, p.dy + 4)
          ..lineTo(p.dx - 6, p.dy - 22)
          ..quadraticBezierTo(p.dx, p.dy - 30, p.dx + 6, p.dy - 22)
          ..lineTo(p.dx + 7, p.dy + 4)
          ..close();
        c.drawPath(s, Paint()..color = const Color(0xFF8A8A84));
        c.drawPath(s, Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
        c.drawLine(p + const Offset(-2, -18), p + const Offset(2, -10), Paint()
          ..color = lit ? const Color(0xFFBFF0A0) : const Color(0xFF9AC8E0)
          ..strokeWidth = 1.6);
      } else if (i < depth) {
        c.drawCircle(p, 5, Paint()..color = Palette.parch2);
        c.drawCircle(p, 5, Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      } else if (i > depth) {
        c.drawCircle(p, 8, Paint()..color = const Color(0xFF231C14));
        c.drawCircle(p, 8, Paint()
          ..color = const Color(0xFF6E604C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
        _text(c, '?', p, 11, const Color(0xFFBFB09A));
      }
      if (i == best && i > depth) _text(c, 'deepest', p + const Offset(0, 20), 9.5, Palette.amber);
      if (stone && i > 0) _text(c, '$i', p + const Offset(0, 16), 10, const Color(0xFFBFD8E8));
    }
    // You.
    final me = at(depth);
    c.drawCircle(me, 16, Paint()
      ..color = (alert ? const Color(0xFFFF5A3A) : Palette.amber).withValues(alpha: .45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    c.drawCircle(me, 9, Paint()..color = alert ? const Color(0xFFFF7A5A) : Palette.amber);
    c.drawCircle(me, 9, Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // A little banner on a pole.
    c.drawLine(me + const Offset(0, -8), me + const Offset(0, -34), Paint()
      ..color = const Color(0xFF2A2018)
      ..strokeWidth = 2.4);
    c.drawPath(
      Path()
        ..moveTo(me.dx, me.dy - 34)
        ..lineTo(me.dx + 16, me.dy - 29)
        ..lineTo(me.dx, me.dy - 24)
        ..close(),
      Paint()..color = Palette.blood,
    );
    if (alert) _text(c, 'They\'re coming!', me + const Offset(0, 24), 11, const Color(0xFFFF9A7A));
  }

  void _text(Canvas c, String s, Offset centre, double size, Color colour) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: colour, fontWeight: FontWeight.w800, shadows: const [Shadow(offset: Offset(1, 1), color: Colors.black)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.depth != depth || old.best != best || old.alert != alert || old.colour != colour;
}
