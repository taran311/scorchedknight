// The map of the burned world, to wander as you like. Roads branch out from the Soot & Kettle: beat
// a land's boss and every road out of it opens, so you choose your own way to the Ember Throne
// (each land's level still has to be reached). Off the roads: two side lands, three wilds, and
// places to explore (caches, shrines, and things guarded by named foes), one red pin each.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/paint_kit.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../audio/audio.dart';
import 'battle_screen.dart' show openBattle, BattleStart, BattleExit;
import 'hud.dart';
import 'loot_window.dart' show resolvePendingLoot;
import 'theme.dart';
import 'trail_data.dart';
import 'trail_page.dart';
import 'wilds_page.dart';
import '../game/wilds.dart';
import '../game/dungeons.dart';
import 'dungeon_page.dart';

/// The map is 1000 wide and this tall: the lands, and the Shattered Sea along the bottom.
const _mapH = 700.0;

/// Where each continent sits on the 1000 × [_mapH] map.
const _spots = <Offset>[Offset(150, 470), Offset(390, 455), Offset(260, 250), Offset(560, 270), Offset(800, 320), Offset(732, 470), Offset(850, 150), Offset(420, 335), Offset(100, 320), Offset(320, 95), Offset(575, 44), Offset(110, 48), Offset(905, 476), Offset(560, 632), Offset(900, 638), Offset(900, 40), Offset(748, 628), Offset(400, 585), Offset(700, 215)];

/// A land's patch on the map (the side lands are smaller).
Size _blobSize(int i) => isSideLand(i) ? const Size(130, 84) : const Size(170, 118);

/// The Soot & Kettle, just off the road at the start.
const _innSpot = Offset(58, 542);

/// Where the three wild areas lie, off the road between the lands.
const _wildSpots = <Offset>[Offset(560, 524), Offset(480, 120), Offset(690, 110)];

/// On a phone the whole map is small, so it can be pinched to zoom and dragged around.
/// On a phone the map gets a tall window of its own, drawn big enough to read, opening on the land
/// you're in: drag to look around, pinch to zoom.
class _PhoneMap extends StatefulWidget {
  const _PhoneMap({required this.focus, required this.builder});
  final Offset focus;
  final Widget Function(double width) builder;

  @override
  State<_PhoneMap> createState() => _PhoneMapState();
}

class _PhoneMapState extends State<_PhoneMap> {
  final _view = TransformationController();
  Size? _placed;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight, w = h * 1000 / _mapH;
      if (_placed != box.biggest) {
        // Centre the land you're in (as near as the edges allow).
        final first = _placed == null;
        _placed = box.biggest;
        final k = w / 1000;
        final dx = (box.maxWidth / 2 - widget.focus.dx * k).clamp(box.maxWidth - w, 0.0);
        final at = Matrix4.translationValues(dx, 0, 0);
        // (The viewer is listening after the first frame, so later moves wait for the frame to end.)
        if (first) {
          _view.value = at;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _view.value = at);
        }
      }
      return ClipRect(
        child: InteractiveViewer(
          transformationController: _view,
          constrained: false,
          minScale: 1,
          maxScale: 3,
          child: SizedBox(width: w, height: h, child: widget.builder(w)),
        ),
      );
    },
  );
}

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GameController get c => widget.controller;
  late int _pick = c.state.continent;

  /// A wild area picked on the map (shown in the panel instead of a land).
  int? _wildPick;

  /// A place picked on the map (shown in the panel instead of a land).
  String? _placePick;

  /// A dungeon picked on the map (shown in the panel instead of a land).
  String? _dungeonPick;

  /// Down into a dungeon (or back to the run under way in it).
  Future<void> _delve(Dungeon d) async {
    if (c.whyNotDungeon(d.id) != null) return;
    if (c.state.dungeon != d.id) {
      if (!await _wardCheck(d.land) || !mounted) return;
      c.enterDungeon(d.id);
      Audio.play(Sfx.quest);
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DungeonPage(controller: c)));
    if (mounted) setState(() {});
  }

  /// Explores a place: its guard's fight, or what's there at once.
  Future<void> _explore(Place p) async {
    if (c.whyNotExplore(p.id) != null) return;
    final out = c.explorePlace(p.id);
    if (c.state.inBattle) {
      final exit = await openBattle(context, c, BattleStart.resume);
      if (!mounted) return;
      if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (out != null) {
      Audio.play(Sfx.quest);
      await showDialog<void>(context: context, builder: (_) => _PlaceFound(place: p, text: out));
      if (mounted && c.nextLoot != null) await resolvePendingLoot(context, c);
    }
    if (mounted) setState(() {});
  }

  /// Into a land: its trail of stops to the boss's lair.
  Future<void> _enter(int land) async {
    setState(() {
      _pick = land;
      _wildPick = null;
      _placePick = null;
      _dungeonPick = null;
    });
    if (c.whyNotTravel(land) != null) return;
    if (!await _wardCheck(land) || !mounted) return;
    c.travel(land);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrailPage(controller: c, land: land)));
    if (mounted) setState(() {});
  }

  /// Lands warned about this session while their ward couldn't be made yet (so it's said once, not
  /// every time you go in).
  static final _warned = <int>{};

  /// Before going into a land with a hazard and no ward: says what it does and how to stop it.
  /// When Old Wick can make the ward right now, it offers to (that one asks every time: it's a
  /// single tap away). Returns whether to go in.
  Future<bool> _wardCheck(int land) async {
    final l = continents[land], s = c.state;
    if (l.ward == null || s.warded.contains(land)) return true;
    final why = c.whyNotWard(land);
    if (why != null && _warned.contains(land)) return true;
    _warned.add(land);
    final reagent = continents[land - 1].reagent, have = s.reagents[land - 1];
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Stone(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFE0A070), size: 26),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${l.hazard} ahead', style: Txt.label(size: 19, color: const Color(0xFFE0A070), weight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: 6),
                Text('In ${l.name} you lose ${(hazardShare * 100).round()}% of your HP every turn you fight. Old Wick\'s ${l.ward} stops it.', style: Txt.onStone(size: 14.5, color: Palette.cream)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.shield_moon, color: Color(0xFF9ADFFF), size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$reagentsForWard $reagent (you have $have) and ${wardPrice(land)} gold${have < reagentsForWard ? '. $reagent drops from foes in ${continents[land - 1].name}.' : ''}',
                        style: Txt.onStone(size: 13.5, color: have >= reagentsForWard ? const Color(0xFF9BE27A) : Palette.parch2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (why == null) ...[
                  StoneButton(title: 'Get the ${l.ward} · ${wardPrice(land)} gold', tone: ButtonTone.amber, compact: true, onPressed: () => Navigator.of(context).pop('craft')),
                  const SizedBox(height: 6),
                ],
                StoneButton(title: 'Go in anyway', compact: true, onPressed: () => Navigator.of(context).pop('go')),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == 'craft') {
      c.craftWard(land);
      Audio.play(Sfx.coins);
    }
    return choice != null;
  }

  /// Off the road: wild area [a] (straight in if it's open; otherwise the panel says how to open it).
  Future<void> _wilds(int a) async {
    setState(() {
      _wildPick = a;
      _placePick = null;
      _dungeonPick = null;
    });
    if (!c.wildOpen(a)) return;
    // Straight in, unless a trip elsewhere is under way (then the page shows that one).
    if (c.state.wild == null) c.enterWild(a);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WildsPage(controller: c, area: a)));
    if (mounted) setState(() {});
  }

  void _home() => Navigator.of(context).pop();

  Widget _hotspot(Offset centre, double w, double h, double k, String label, VoidCallback onTap) => Positioned(
        left: (centre.dx - w / 2) * k,
        top: (centre.dy - h / 2) * k,
        width: w * k,
        height: h * k,
        child: Semantics(
          button: true,
          label: label,
          child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap)),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final s = c.state;
          return MusicZone(
              track: 'travel',
              child: Scaffold(
                body: Column(
                  children: [
                    SizedBox(height: MediaQuery.paddingOf(context).top),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: fitWidth(context, aspect: 1000 / _mapH, below: 200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Your card and the way home sit above the map, not on it (they used to
                                // cover the lands in the corners).
                                ...[
                                  Row(
                                    children: [
                                      Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: HeroCard(controller: c))),
                                      const SizedBox(width: 8),
                                      InnBackButton(label: 'Town', onPressed: _home),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Stone(
                                  padding: const EdgeInsets.all(3),
                                  child: Builder(
                                    builder: (context) {
                                      Widget mapAt(double width) {
                                        final k = width / 1000;
                                        return Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: _MapPainter(
                                                  open: [for (var i = 0; i < continents.length; i++) c.whyNotTravel(i) == null],
                                                  selected: _wildPick == null && _placePick == null && _dungeonPick == null ? _pick : -1,
                                                  delves: [for (final d in dungeons) if (c.whyNotTravel(d.land) == null) (d, c.dungeonOpen(d), s.dungeonsDone.contains(d.id), s.dungeon == d.id)],
                                                  delvePicked: _dungeonPick,
                                                  pins: [for (final p in places) if (c.placeShown(p)) (p, s.explored.contains(p.id), c.whyNotExplore(p.id) == null)],
                                                  pinPicked: _placePick,
                                                  beaten: s.bossesDown,
                                                  wildsOpen: [for (var a = 0; a < wildAreas.length; a++) c.wildOpen(a)],
                                                  wildPicked: _wildPick,
                                                  trip: s.wild,
                                                ),
                                              ),
                                            ),
                                            for (var i = 0; i < continents.length; i++) _hotspot(_spots[i] + const Offset(0, -10), _blobSize(i).width - 20, _blobSize(i).height, k, continents[i].name, () => _enter(i)),
                                            for (final p in places)
                                              if (c.placeShown(p)) _hotspot(Offset(p.x, p.y + 6), math.max(46, 40 / k), math.max(46, 40 / k), k, p.name, () => setState(() {
                                                _placePick = p.id;
                                                _dungeonPick = null;
                                              })),
                                            for (final d in dungeons)
                                              if (c.whyNotTravel(d.land) == null) _hotspot(Offset(d.x, d.y), math.max(46, 40 / k), math.max(46, 40 / k), k, d.name, () => setState(() {
                                                _dungeonPick = d.id;
                                                _placePick = null;
                                                _wildPick = null;
                                              })),
                                            for (var a = 0; a < wildAreas.length; a++) _hotspot(_wildSpots[a] + const Offset(0, 8), 150, 86, k, wildAreas[a].name, () => _wilds(a)),
                                            _hotspot(_innSpot + const Offset(0, 2), 120, 70, k, 'Back to the Soot & Kettle', _home),
                                          ],
                                        );
                                      }

                                      if (isPhone(context)) {
                                        final tall = (MediaQuery.sizeOf(context).height * .48).clamp(260.0, 520.0);
                                        return SizedBox(height: tall, child: _PhoneMap(focus: _spots[_pick], builder: mapAt));
                                      }
                                      return AspectRatio(aspectRatio: 1000 / _mapH, child: LayoutBuilder(builder: (context, box) => mapAt(box.maxWidth)));
                                    },
                                  ),
                                ),
                                if (isPhone(context))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Drag the map to look around; pinch to zoom.', textAlign: TextAlign.center, style: Txt.label(size: 12, color: Palette.parch2)),
                                  ),
                                const SizedBox(height: 10),
                                if (dungeonById(_dungeonPick) case final d?)
                                  _DungeonPanel(controller: c, dungeon: d, onGo: () => _delve(d))
                                else if (placeById(_placePick) case final p?)
                                  _PlacePanel(controller: c, place: p, onGo: () => _explore(p))
                                else if (_wildPick case final a?) _WildPanel(controller: c, area: a, onGo: () => _wilds(a)) else _ContinentPanel(controller: c, index: _pick, onEnter: () => _enter(_pick)),
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

/// The land you've picked: where you are on its trail and who waits at the end. Tap a land on
/// the map to go straight in.
class _ContinentPanel extends StatelessWidget {
  const _ContinentPanel({required this.controller, required this.index, required this.onEnter});
  final GameController controller;
  final int index;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, land = continents[index];
    final blocked = c.whyNotTravel(index), col = Color(land.argb), step = trailStep(s, index), at = trailAt(s, index);
    return Stone(
      child: _panel(
        context,
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A8F96), Color(0xFF4E535A)]),
            border: Border.all(color: Palette.stone0, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: blocked != null ? const Icon(Icons.lock, color: Palette.cream, size: 34) : Padding(padding: const EdgeInsets.all(2), child: TypePortrait(type: land.boss)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(land.name, style: Txt.label(size: 22, color: col, weight: FontWeight.w800)),
            if (blocked != null)
              Text(blocked, style: Txt.onStone(size: 16, color: Palette.cream))
            else ...[
              Text(land.blurb, maxLines: 4, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 15)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < winsForBoss; i++)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step == TrailStep.patrol || i < at ? Palette.amber : const Color(0xFF15110C),
                        border: Border.all(color: Palette.stone3),
                      ),
                    ),
                  Icon(step == TrailStep.patrol ? Icons.flag : Icons.workspace_premium, size: 20, color: step == TrailStep.stop ? Palette.stone3 : Palette.amber),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      step == TrailStep.patrol ? '${land.boss.name} beaten' : (step == TrailStep.lair ? 'The lair is open!' : '${trailLairs[index]} ahead'),
                      overflow: TextOverflow.ellipsis,
                      style: Txt.label(size: 14, color: Palette.parch),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        StoneButton(
          title: blocked == null ? 'Enter' : 'Locked',
          caption: blocked == null ? land.name : null,
          tone: ButtonTone.blood,
          onPressed: blocked == null ? onEnter : null,
        ),
      ),
    );
  }
}

/// A place picked on the map: what's there, and the way in (or why not yet).
class _PlacePanel extends StatelessWidget {
  const _PlacePanel({required this.controller, required this.place, required this.onGo});
  final GameController controller;
  final Place place;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller, p = place, done = c.state.explored.contains(p.id), why = c.whyNotExplore(p.id);
    final land = continents[p.land];
    return Stone(
      child: _panel(
        context,
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: done ? const [Color(0xFF7A6A54), Color(0xFF2A2018)] : const [Color(0xFFB0141A), Color(0xFF3A0608)]),
            border: Border.all(color: Palette.amber, width: 2),
          ),
          child: Icon(
            done
                ? Icons.check
                : switch (p.kind) {
                    PlaceKind.guarded => Icons.shield,
                    PlaceKind.cache => Icons.inventory_2,
                    PlaceKind.shrine => Icons.wb_sunny,
                  },
            color: const Color(0xFFFFE6A0),
            size: 34,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: Txt.label(size: 22, color: Palette.cream, weight: FontWeight.w800)),
            Text('${land.name} · ${done ? 'explored' : switch (p.kind) {
              PlaceKind.guarded => 'guarded by ${p.foe!.$4}',
              PlaceKind.cache => 'something hidden here',
              PlaceKind.shrine => 'a shrine',
            }}', style: Txt.label(size: 13, color: Palette.amber)),
            const SizedBox(height: 2),
            Text(done ? p.after : p.blurb, maxLines: 3, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 15)),
          ],
        ),
        StoneButton(
          title: done ? 'Explored' : (why == null ? (p.kind == PlaceKind.guarded ? 'Fight' : 'Explore') : 'Not yet'),
          caption: done || why == null ? null : why,
          tone: ButtonTone.blood,
          onPressed: why == null ? onGo : null,
        ),
      ),
    );
  }
}

/// A dungeon picked on the map: what's down there, and the way in (or what opens it).
class _DungeonPanel extends StatelessWidget {
  const _DungeonPanel({required this.controller, required this.dungeon, required this.onGo});
  final GameController controller;
  final Dungeon dungeon;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, d = dungeon, why = c.whyNotDungeon(d.id), here = s.dungeon == d.id, done = s.dungeonsDone.contains(d.id);
    final col = Color(d.argb);
    return Stone(
      child: _panel(
        context,
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: done ? Palette.amber : Palette.stone0, width: 2),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(col, Colors.black, .4)!, const Color(0xFF0E0A08)]),
          ),
          child: Icon(why != null && !here ? Icons.lock : (done ? Icons.star : Icons.stairs), color: done ? Palette.amber : Palette.cream, size: 34),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.name, style: Txt.label(size: 22, color: col, weight: FontWeight.w800)),
            Text(
              '${continents[d.land].name} · ${here ? 'room ${math.min(s.dungeonRoom + 1, dungeonRooms + 1)} of ${dungeonRooms + 1}' : (done ? '${d.boss.$1} beaten' : 'ruled by ${d.boss.$1}')}',
              style: Txt.label(size: 13, color: Palette.amber),
            ),
            const SizedBox(height: 2),
            Text(why ?? d.blurb, maxLines: 3, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 15, color: why == null ? Palette.parch2 : Palette.cream)),
          ],
        ),
        StoneButton(
          title: here ? 'Back down' : (why == null ? (done ? 'Delve again' : 'Delve') : 'Locked'),
          tone: ButtonTone.blood,
          onPressed: why == null ? onGo : null,
        ),
      ),
    );
  }
}

/// What you found at a place.
class _PlaceFound extends StatelessWidget {
  const _PlaceFound({required this.place, required this.text});
  final Place place;
  final String text;

  @override
  Widget build(BuildContext context) => Dialog(
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
            Text('EXPLORED', style: Txt.label(size: 12, color: Palette.amber)),
            Text(place.name, style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: parchmentDecoration(),
                  child: Text(text, style: Txt.body(size: 16.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            StoneButton(title: 'Onward', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    ),
  );
}

/// A wild area picked on the map: what it is, and the way in (or what opens it).
class _WildPanel extends StatelessWidget {
  const _WildPanel({required this.controller, required this.area, required this.onGo});
  final GameController controller;
  final int area;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller, w = wildAreas[area], col = Color(w.argb), open = c.wildOpen(area), here = c.state.wild == area;
    return Stone(
      fill: const Color(0xFF2E3A22),
      child: _panel(
        context,
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Palette.stone0, width: 2),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(col, Colors.black, .35)!, Color.lerp(col, Colors.black, .75)!]),
          ),
          child: Icon(open ? Icons.forest : Icons.lock, color: Palette.cream, size: 34),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(w.name, style: Txt.label(size: 22, color: col, weight: FontWeight.w800)),
            Text(open ? w.blurb : 'Opens when ${continents[w.opensAfter].boss.name} falls.',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 15, color: open ? Palette.parch2 : Palette.cream)),
            const SizedBox(height: 4),
            Text('Off the road: encounter after encounter, better gear the deeper you dare.', style: Txt.label(size: 13, color: Palette.parch)),
          ],
        ),
        StoneButton(title: open ? (here ? 'Back in' : 'Head in') : 'Locked', caption: here ? 'Step ${c.state.wildDepth}' : null, tone: ButtonTone.blood, onPressed: open ? onGo : null),
      ),
    );
  }
}

/// The parchment map: the road, the six lands, fog over the ones not reached yet, and the wilds
/// off the road between them.
class _MapPainter extends CustomPainter {
  _MapPainter({required this.open, required this.selected, required this.beaten, required this.wildsOpen, this.wildPicked, this.trip, this.pins = const [], this.pinPicked, this.delves = const [], this.delvePicked});

  /// Dungeons shown: each with whether it's open, whether its boss is beaten, and whether you're
  /// down in it now.
  final List<(Dungeon, bool, bool, bool)> delves;
  final String? delvePicked;

  /// Places shown: each with whether it's explored, and whether it can be explored now.
  final List<(Place, bool, bool)> pins;
  final String? pinPicked;
  final List<bool> open;
  final int selected;
  final Set<int> beaten;
  final List<bool> wildsOpen;
  final int? wildPicked, trip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000);
    const rect = Rect.fromLTWH(0, 0, 1000, _mapH);
    canvas.drawRect(
        rect, Paint()..shader = const RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xFFE6D8B4), Color(0xFFCDB98C), Color(0xFF9C8558)], stops: [0, .7, 1]).createShader(rect));
    // A few stains and the sea in the corner.
    final r = SeededRandom(4);
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(Offset(r.next() * 1000, r.next() * _mapH), 8 + r.next() * 30, Paint()..color = const Color(0xFF8A6A3A).withValues(alpha: .05 + r.next() * .05));
    }
    final sea = Path()
      ..moveTo(0, 0)
      ..lineTo(260, 0)
      ..quadraticBezierTo(200, 60, 120, 70)
      ..quadraticBezierTo(40, 90, 0, 150)
      ..close();
    canvas.drawPath(sea, Paint()..color = const Color(0xFF7FA0A8).withValues(alpha: .55));
    // The Shattered Sea along the southern edge, broken up by reefs.
    final south = Path()..moveTo(0, 612);
    for (var x = 0.0; x <= 1000; x += 50) {
      south.quadraticBezierTo(x + 25, 600 + 10 * math.sin(x / 90), x + 50, 604 + 14 * math.sin(x / 130 + 1));
    }
    south
      ..lineTo(1000, _mapH)
      ..lineTo(0, _mapH)
      ..close();
    canvas.drawPath(south, Paint()..color = const Color(0xFF7FA0A8).withValues(alpha: .55));
    for (var i = 0; i < 9; i++) {
      canvas.drawArc(Rect.fromCenter(center: Offset(60.0 + i * 108, 652.0 + (i % 3) * 8), width: 22, height: 8), math.pi, math.pi, false, strokePaint(const Color(0xFF4A6A72), 1.4));
    }
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(Rect.fromCenter(center: Offset(60.0 + i * 40, 30.0 + i * 8), width: 22, height: 8), math.pi, math.pi, false, strokePaint(const Color(0xFF4A6A72), 1.4));
    }

    // The roads, dashed: from the Inn to Cindervale, and on between the lands, branching (the
    // tracks to the side lands narrower). Roads not open yet are faint.
    void dashed(Path path, double width, double gap, double alpha) {
      for (final metric in path.computeMetrics()) {
        for (double d = 0; d < metric.length; d += gap) {
          canvas.drawPath(metric.extractPath(d, d + gap * .55), strokePaint(const Color(0xFF6A4A2A).withValues(alpha: alpha), width)..strokeCap = StrokeCap.round);
        }
      }
    }

    Path bend(Offset a, Offset b) {
      final mid = Offset.lerp(a, b, .5)! + Offset((b.dy - a.dy) * .18, (a.dx - b.dx) * .18);
      return Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }

    dashed(bend(_innSpot, _spots[0]), 3.2, 22, 1);
    for (final (from, to) in roads) {
      final side = isSideLand(to), lit = beaten.contains(from);
      dashed(bend(_spots[from], _spots[to]), side ? 2 : 3.2, side ? 14 : 22, lit ? (side ? .8 : 1) : .3);
    }
    for (var i = 0; i < continents.length; i++) {
      final at = _spots[i], land = continents[i], open = this.open[i], size = _blobSize(i);
      final col = Color(land.argb);
      final blob = Path()..addOval(Rect.fromCenter(center: at, width: size.width, height: size.height));
      canvas.drawPath(blob, Paint()..color = col.withValues(alpha: open ? .38 : .14));
      canvas.drawPath(blob, strokePaint(shade(col, -.45).withValues(alpha: open ? .8 : .3), i == selected ? 3.5 : 1.6));
      _landmark(canvas, i, at, open);
      if (!open) {
        // Fog of war and a padlock.
        canvas.drawPath(
            blob,
            Paint()
              ..color = const Color(0xFFCBBB96).withValues(alpha: .55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        _padlock(canvas, at + const Offset(0, -6));
      }
      if (beaten.contains(i)) _flag(canvas, at + const Offset(52, -44));
      final tp = TextPainter(
        text: TextSpan(text: land.name, style: Txt.inkLabel(size: isSideLand(i) ? 17 : 21, color: open ? const Color(0xFF2A1A0E) : const Color(0xFF6A5A44))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy + (isSideLand(i) ? 30 : 40)));
    }
    for (var a = 0; a < wildAreas.length; a++) {
      _wild(canvas, a, _wildSpots[a]);
    }
    // Places to explore: a red orb on a pin (dim once explored, with a tick).
    for (final (p, done, ready) in pins) {
      _pin(canvas, Offset(p.x, p.y), p.name, done, ready, p.id == pinPicked);
    }
    // Dungeons: a stair down into the dark, under a stone arch.
    for (final (d, open, done, here) in delves) {
      _delve(canvas, Offset(d.x, d.y), d.name, open, done, here, d.id == delvePicked);
    }
    // The Inn: a little house with a tankard sign, where it all starts.
    _inn(canvas, _innSpot);
    // A compass rose and the border.
    _compass(canvas, const Offset(945, 545));
    canvas.drawRect(rect.deflate(6), strokePaint(const Color(0xFF6A4A2A), 3));
    canvas.restore();
  }

  void _landmark(Canvas c, int i, Offset at, bool open) {
    final ink = strokePaint(const Color(0xFF3A2614).withValues(alpha: open ? .9 : .4), 2.2);
    final fill = Paint()..color = const Color(0xFF3A2614).withValues(alpha: open ? .75 : .3);
    switch (i) {
      case 0: // farmhouses and a field
        for (final dx in const [-36.0, 0.0, 34.0]) {
          final h = at + Offset(dx, -8 + (dx == 0 ? -6 : 0));
          c.drawRect(Rect.fromCenter(center: h, width: 18, height: 14), ink);
          c.drawPath(poly([h + const Offset(-12, -7), h + const Offset(0, -17), h + const Offset(12, -7)]), fill);
        }
        for (var j = 0; j < 4; j++) {
          c.drawLine(at + Offset(-40.0 + j * 6, 18), at + Offset(-16.0 + j * 6, 18), ink);
        }
      case 1: // reeds and a gravestone in the water
        for (var j = 0; j < 5; j++) {
          final x = at.dx - 40 + j * 18;
          c.drawLine(Offset(x, at.dy + 14), Offset(x + 3, at.dy - 10), ink);
          c.drawOval(Rect.fromCenter(center: Offset(x + 3, at.dy - 12), width: 4, height: 9), fill);
        }
        c.drawRRect(RRect.fromRectAndCorners(Rect.fromCenter(center: at + const Offset(0, -16), width: 16, height: 22), topLeft: const Radius.circular(8), topRight: const Radius.circular(8)), fill);
        c.drawLine(at + const Offset(-30, 20), at + const Offset(30, 20), ink);
      case 2: // trees
        for (final (dx, dy, s) in const [(-34.0, 4.0, 1.0), (0.0, -10.0, 1.3), (32.0, 2.0, 1.1)]) {
          final t = at + Offset(dx, dy);
          c.drawPath(poly([t + Offset(-12 * s, 10), t + Offset(0, -22 * s), t + Offset(12 * s, 10)]), fill);
          c.drawLine(t + const Offset(0, 10), t + const Offset(0, 18), ink);
        }
      case 4: // pyramids in the dunes
        for (final (dx, h) in const [(-22.0, 30.0), (16.0, 40.0)]) {
          final b = at + Offset(dx, 14);
          c.drawPath(poly([b + Offset(-h * .9, 0), b + Offset(0, -h), b + Offset(h * .9, 0)]), fill);
        }
        c.drawPath(Path()..moveTo(at.dx - 46, at.dy + 20)..quadraticBezierTo(at.dx - 20, at.dy + 12, at.dx + 6, at.dy + 20)..quadraticBezierTo(at.dx + 30, at.dy + 26, at.dx + 50, at.dy + 18), ink);
      case 3: // mesas and a banner
        for (final (dx, w, h) in const [(-30.0, 34.0, 18.0), (18.0, 46.0, 26.0)]) {
          final b = at + Offset(dx, 14);
          c.drawPath(poly([b + Offset(-w / 2, 0), b + Offset(-w / 2 + 6, -h), b + Offset(w / 2 - 6, -h), b + Offset(w / 2, 0)]), fill);
        }
        c.drawLine(at + const Offset(18, -12), at + const Offset(18, -34), ink);
        c.drawPath(poly([at + const Offset(18, -34), at + const Offset(32, -29), at + const Offset(18, -24)]), Paint()..color = const Color(0xFF9A2A22).withValues(alpha: open ? .8 : .3));
      case 5: // craters and black glass spikes
        c.drawOval(Rect.fromCenter(center: at + const Offset(-22, 10), width: 34, height: 12), ink);
        c.drawOval(Rect.fromCenter(center: at + const Offset(24, 16), width: 26, height: 9), ink);
        for (final dx in const [-6.0, 6.0, 16.0]) {
          c.drawPath(poly([at + Offset(dx - 5, 4), at + Offset(dx, -24 - dx.abs()), at + Offset(dx + 5, 4)]), fill);
        }
      case 6: // the volcano, glowing
        final v = at + const Offset(0, 14);
        c.drawPath(poly([v + const Offset(-50, 0), v + const Offset(-12, -50), v + const Offset(12, -50), v + const Offset(50, 0)]), fill);
        if (open) {
          c.drawCircle(
              v + const Offset(0, -54),
              18,
              Paint()
                ..color = const Color(0xFFFF7A2A).withValues(alpha: .6)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        }
        c.drawPath(poly([v + const Offset(-12, -50), v + const Offset(-4, -36), v + const Offset(4, -44), v + const Offset(12, -50)]),
            Paint()..color = const Color(0xFFE0502A).withValues(alpha: open ? .9 : .3));
      case 7: // a black castle on a crag, and bats
        final base = at + const Offset(0, 12);
        c.drawPath(poly([base + const Offset(-40, 0), base + const Offset(-20, -16), base + const Offset(18, -20), base + const Offset(40, 0)]), fill);
        for (final (dx, h) in const [(-14.0, 26.0), (0.0, 36.0), (14.0, 24.0)]) {
          final b = base + Offset(dx, -16);
          c.drawRect(Rect.fromLTWH(b.dx - 4, b.dy - h, 8, h), fill);
          c.drawPath(poly([b + Offset(-6, -h), b + Offset(0, -h - 10), b + Offset(6, -h)]), fill);
        }
        for (final b in [at + const Offset(26, -34), at + const Offset(36, -26), at + const Offset(-30, -30)]) {
          c.drawPath(Path()..moveTo(b.dx - 6, b.dy)..quadraticBezierTo(b.dx - 3, b.dy - 4, b.dx, b.dy)..quadraticBezierTo(b.dx + 3, b.dy - 4, b.dx + 6, b.dy), ink..strokeWidth = 1.6);
        }
      case 9: // silver trees, tall and slender
        for (final (dx, h) in const [(-30.0, 26.0), (-8.0, 36.0), (16.0, 30.0)]) {
          final t = at + Offset(dx, 10);
          c.drawLine(t, t + Offset(0, -h), ink);
          c.drawOval(Rect.fromCenter(center: t + Offset(0, -h), width: 16, height: 22), Paint()..color = const Color(0xFF8AA898).withValues(alpha: open ? .9 : .35));
          c.drawOval(Rect.fromCenter(center: t + Offset(0, -h), width: 16, height: 22), ink..strokeWidth = 1.4);
        }
      case 10: // a mountain with a great door in it
        final m = at + const Offset(0, 14);
        c.drawPath(poly([m + const Offset(-44, 0), m + const Offset(-6, -42), m + const Offset(8, -34), m + const Offset(44, 0)]), fill);
        c.drawRect(Rect.fromCenter(center: m + const Offset(0, -8), width: 16, height: 16), Paint()..color = const Color(0xFFFF9A3A).withValues(alpha: open ? .85 : .3));
        c.drawRect(Rect.fromCenter(center: m + const Offset(0, -8), width: 16, height: 16), ink..strokeWidth = 1.6);
      case 11: // a lone chapel spire in the fog, and fog curls
        final b = at + const Offset(0, 12);
        c.drawRect(Rect.fromLTWH(b.dx - 9, b.dy - 18, 18, 18), fill);
        c.drawPath(poly([b + const Offset(-11, -18), b + const Offset(0, -40), b + const Offset(11, -18)]), fill);
        for (final dy in const [-6.0, 4.0]) {
          c.drawPath(Path()..moveTo(at.dx - 44, at.dy + dy)..quadraticBezierTo(at.dx - 22, at.dy + dy - 8, at.dx, at.dy + dy)..quadraticBezierTo(at.dx + 22, at.dy + dy + 8, at.dx + 44, at.dy + dy), ink..strokeWidth = 1.4);
        }
      case 12: // a stepped temple among palms
        final b = at + const Offset(-6, 12);
        for (var i = 0; i < 3; i++) {
          c.drawRect(Rect.fromLTWH(b.dx - 20 + i * 6, b.dy - 9 - i * 9, 40 - i * 12, 9), fill);
        }
        for (final dx in const [26.0, -32.0]) {
          final p = at + Offset(dx, 12);
          c.drawLine(p, p + const Offset(2, -26), ink..strokeWidth = 2);
          for (final a in const [-2.4, -1.6, -.9, -.2]) {
            c.drawLine(p + const Offset(2, -26), p + Offset(2 + math.cos(a) * 11, -26 + math.sin(a) * 7 + 4), ink..strokeWidth = 1.8);
          }
        }
      case 15: // a bird on a crag above the clouds
        c.drawPath(poly([at + const Offset(-30, 14), at + const Offset(-6, -26), at + const Offset(8, -14), at + const Offset(26, 14)]), fill);
        for (final dx in const [-38.0, 30.0]) {
          c.drawOval(Rect.fromCenter(center: at + Offset(dx, 10), width: 34, height: 12), Paint()..color = const Color(0xFFF2F0E8).withValues(alpha: open ? .9 : .4));
        }
        final b = at + const Offset(16, -34);
        c.drawPath(Path()..moveTo(b.dx - 12, b.dy)..quadraticBezierTo(b.dx - 6, b.dy - 7, b.dx, b.dy)..quadraticBezierTo(b.dx + 6, b.dy - 7, b.dx + 12, b.dy), ink..strokeWidth = 2);
      case 16: // a torii gate on an island, under a blossom tree
        c.drawOval(Rect.fromCenter(center: at + const Offset(0, 12), width: 84, height: 18), fill);
        final red = Paint()..color = const Color(0xFFB8322A).withValues(alpha: open ? .9 : .35);
        for (final dx in const [-14.0, 6.0]) {
          c.drawRect(Rect.fromLTWH(at.dx + dx, at.dy - 22, 4, 32), red);
        }
        c.drawRect(Rect.fromLTWH(at.dx - 20, at.dy - 26, 34, 4), red);
        c.drawRect(Rect.fromLTWH(at.dx - 16, at.dy - 18, 26, 3), red);
        c.drawLine(at + const Offset(26, 10), at + const Offset(28, -14), ink);
        for (final (dx, dy) in const [(20.0, -20.0), (30.0, -24.0), (36.0, -14.0), (24.0, -12.0)]) {
          c.drawCircle(at + Offset(dx, dy), 6, Paint()..color = const Color(0xFFF0A8C0).withValues(alpha: open ? .9 : .35));
        }
      case 18: // snowy peaks with a frozen tower between them
        for (final (dx, h, w) in const [(-28.0, 40.0, 30.0), (24.0, 48.0, 34.0)]) {
          final b = at + Offset(dx, 14);
          c.drawPath(poly([b + Offset(-w, 0), b + Offset(0, -h), b + Offset(w, 0)]), fill);
          c.drawPath(poly([b + Offset(-w * .35, -h * .65), b + Offset(0, -h), b + Offset(w * .35, -h * .65), b + Offset(w * .1, -h * .55), b + Offset(-w * .1, -h * .6)]), Paint()..color = const Color(0xFFF2F6FA).withValues(alpha: open ? .95 : .4));
        }
        final tw = at + const Offset(-2, 14);
        c.drawRect(Rect.fromLTWH(tw.dx - 5, tw.dy - 34, 10, 34), Paint()..color = const Color(0xFF9AC0DC).withValues(alpha: open ? .95 : .4));
        c.drawRect(Rect.fromLTWH(tw.dx - 5, tw.dy - 34, 10, 34), ink..strokeWidth = 1.4);
        c.drawPath(poly([tw + const Offset(-8, -34), tw + const Offset(0, -46), tw + const Offset(8, -34)]), fill);
      case 17: // a cave mouth in a hill, and bats pouring out of it
        final h = at + const Offset(0, 14);
        c.drawPath(Path()..moveTo(h.dx - 48, h.dy)..quadraticBezierTo(h.dx - 30, h.dy - 40, h.dx, h.dy - 38)..quadraticBezierTo(h.dx + 32, h.dy - 36, h.dx + 48, h.dy)..close(), fill);
        c.drawPath(Path()..moveTo(h.dx - 14, h.dy)..quadraticBezierTo(h.dx - 12, h.dy - 22, h.dx, h.dy - 22)..quadraticBezierTo(h.dx + 12, h.dy - 22, h.dx + 14, h.dy)..close(), Paint()..color = const Color(0xFF1A1420).withValues(alpha: open ? .85 : .35));
        for (final b in [at + const Offset(8, -34), at + const Offset(22, -42), at + const Offset(-6, -46), at + const Offset(34, -30)]) {
          c.drawPath(Path()..moveTo(b.dx - 6, b.dy)..quadraticBezierTo(b.dx - 3, b.dy - 4, b.dx, b.dy)..quadraticBezierTo(b.dx + 3, b.dy - 4, b.dx + 6, b.dy), ink..strokeWidth = 1.6);
        }
      case 14: // a little island of standing stones, each a different shape
        c.drawOval(Rect.fromCenter(center: at + const Offset(0, 12), width: 80, height: 18), fill);
        for (final (dx, h, w) in const [(-24.0, 22.0, 8.0), (-6.0, 30.0, 10.0), (12.0, 18.0, 12.0), (28.0, 26.0, 7.0)]) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(at.dx + dx - w / 2, at.dy + 6 - h, w, h), Radius.circular(w / 2)), fill);
        }
      case 13: // a serpent's coils breaking the waves
        for (var i = 0; i < 3; i++) {
          final h = at + Offset(-30.0 + i * 22, 8);
          c.drawArc(Rect.fromCenter(center: h, width: 20, height: 22), math.pi, math.pi, false, ink..strokeWidth = 4);
        }
        c.drawPath(Path()..moveTo(at.dx + 32, at.dy + 8)..quadraticBezierTo(at.dx + 40, at.dy - 24, at.dx + 26, at.dy - 30), ink..strokeWidth = 4);
        c.drawCircle(at + const Offset(24, -30), 5, fill);
      case 8: // pines under a full moon
        c.drawCircle(at + const Offset(30, -30), 9, Paint()..color = const Color(0xFFF2E8C0).withValues(alpha: open ? .95 : .4));
        c.drawCircle(at + const Offset(30, -30), 9, strokePaint(const Color(0xFF3A2614).withValues(alpha: open ? .6 : .3), 1.2));
        for (final (dx, dy, sc) in const [(-30.0, 6.0, .9), (-10.0, -2.0, 1.15), (12.0, 6.0, 1.0)]) {
          final t = at + Offset(dx, dy);
          c.drawPath(poly([t + Offset(-10 * sc, 10), t + Offset(0, -24 * sc), t + Offset(10 * sc, 10)]), fill);
          c.drawLine(t + const Offset(0, 10), t + const Offset(0, 16), ink);
        }
    }
  }

  void _pin(Canvas c, Offset at, String name, bool done, bool ready, bool picked) {
    if (picked) c.drawCircle(at, 15, strokePaint(const Color(0xFFFFE6A0), 3));
    c.drawCircle(at + const Offset(1.5, 2), 10, Paint()..color = const Color(0x55000000));
    final orb = Rect.fromCircle(center: at, radius: 10);
    c.drawCircle(
      at,
      10,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: done ? const [Color(0xFFB8A890), Color(0xFF7A6A54), Color(0xFF3A3024)] : const [Color(0xFFFF8A7A), Color(0xFFB0141A), Color(0xFF4A0608)],
          stops: const [0, .55, 1],
        ).createShader(orb),
    );
    c.drawCircle(at, 10, strokePaint(const Color(0xFF2A1A0E), 1.6));
    if (done) {
      c.drawPath(Path()..moveTo(at.dx - 4.5, at.dy)..lineTo(at.dx - 1, at.dy + 4)..lineTo(at.dx + 5, at.dy - 4), strokePaint(const Color(0xFFF2EAD2), 2.2)..strokeCap = StrokeCap.round);
    } else {
      c.drawCircle(at + const Offset(-3, -3.5), 2.6, Paint()..color = const Color(0xCCFFFFFF));
      if (!ready) _padlock(c, at + const Offset(10, 4), .45);
    }
    final tp = TextPainter(
      text: TextSpan(text: name, style: Txt.inkLabel(size: 13, color: done ? const Color(0xFF6A5A44) : const Color(0xFF2A1A0E))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((at.dx - tp.width / 2).clamp(8, 992 - tp.width), at.dy + 11));
  }

  /// A dungeon's mouth: a stone arch over steps going down into the dark, a glow if you're down
  /// there now, a star once its boss is beaten.
  void _delve(Canvas c, Offset at, String name, bool open, bool done, bool here, bool picked) {
    final a = open ? 1.0 : .45;
    if (picked) c.drawCircle(at, 19, strokePaint(const Color(0xFFFFE6A0), 3));
    if (here) c.drawCircle(at, 20, Paint()..color = const Color(0xFFFFB04A).withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    final arch = Path()
      ..moveTo(at.dx - 15, at.dy + 10)
      ..lineTo(at.dx - 15, at.dy - 4)
      ..arcToPoint(Offset(at.dx + 15, at.dy - 4), radius: const Radius.circular(15))
      ..lineTo(at.dx + 15, at.dy + 10)
      ..close();
    c.drawPath(arch, Paint()..color = const Color(0xFF8A7A62).withValues(alpha: a));
    final mouth = Path()
      ..moveTo(at.dx - 9, at.dy + 10)
      ..lineTo(at.dx - 9, at.dy - 2)
      ..arcToPoint(Offset(at.dx + 9, at.dy - 2), radius: const Radius.circular(9))
      ..lineTo(at.dx + 9, at.dy + 10)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFF140E0A).withValues(alpha: a));
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(at.dx - 7 + i * 1.5, at.dy + 8 - i * 3.5), Offset(at.dx + 7 - i * 1.5, at.dy + 8 - i * 3.5), strokePaint(const Color(0xFF6A5A46).withValues(alpha: a), 1.6));
    }
    c.drawPath(arch, strokePaint(const Color(0xFF2A1A0E).withValues(alpha: a), 1.8));
    if (done) {
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? 7.0 : 3.0, ang = -math.pi / 2 + i * math.pi / 5;
        final p = at + const Offset(15, -16) + Offset(math.cos(ang) * r, math.sin(ang) * r);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      c.drawPath(star..close(), Paint()..color = const Color(0xFFE3A548));
      c.drawPath(star, strokePaint(const Color(0xFF3A2614), 1));
    } else if (!open) {
      _padlock(c, at + const Offset(15, 6), .45);
    }
    final tp = TextPainter(
      text: TextSpan(text: name, style: Txt.inkLabel(size: 13, color: open ? const Color(0xFF2A1A0E) : const Color(0xFF6A5A44))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((at.dx - tp.width / 2).clamp(8, 992 - tp.width), at.dy + 12));
  }

  void _padlock(Canvas c, Offset at, [double scale = 1]) {
    if (scale != 1) {
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(scale);
      _padlock(c, Offset.zero);
      c.restore();
      return;
    }
    c.drawArc(Rect.fromCenter(center: at + const Offset(0, -8), width: 18, height: 20), math.pi, math.pi, false, strokePaint(const Color(0xFF4A3A2A), 3.5));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at + const Offset(0, 4), width: 26, height: 20), const Radius.circular(3)), Paint()..color = const Color(0xFF6A5236));
    c.drawCircle(at + const Offset(0, 3), 3, Paint()..color = const Color(0xFF2A1C10));
  }

  void _flag(Canvas c, Offset at) {
    c.drawLine(at, at + const Offset(0, 26), strokePaint(const Color(0xFF3A2614), 2));
    c.drawPath(poly([at, at + const Offset(16, 5), at + const Offset(0, 10)]), Paint()..color = const Color(0xFFE3A548));
  }

  void _inn(Canvas c, Offset at) {
    final ink = strokePaint(const Color(0xFF3A2614), 2.2);
    c.drawRect(Rect.fromCenter(center: at, width: 34, height: 22), Paint()..color = const Color(0xFFB0905E));
    c.drawRect(Rect.fromCenter(center: at, width: 34, height: 22), ink);
    c.drawPath(poly([at + const Offset(-22, -11), at + const Offset(0, -30), at + const Offset(22, -11)]), Paint()..color = const Color(0xFF6A3A26));
    c.drawRect(Rect.fromCenter(center: at + const Offset(-6, 4), width: 8, height: 13), Paint()..color = const Color(0xFFFFCF7A));
    c.drawLine(at + const Offset(12, -24), at + const Offset(12, -38), strokePaint(const Color(0xFF8A8A8A).withValues(alpha: .6), 4));
    // The label sits under the house, clear of Cindervale's name.
    final tp = TextPainter(text: TextSpan(text: 'The Soot & Kettle', style: Txt.inkLabel(size: 15, color: const Color(0xFF3A2614))), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, at + Offset(math.max(-at.dx + 14, -tp.width / 2), 14));
  }

  /// A patch of wild country: scrub and dead trees, tinted the area's colour, its name in italics.
  void _wild(Canvas c, int a, Offset at) {
    final open = wildsOpen[a], w = wildAreas[a], col = Color(w.argb), picked = wildPicked == a;
    final r = SeededRandom(a * 7 + 3);
    final patch = Path();
    for (var i = 0; i <= 14; i++) {
      final ang = i / 14 * math.pi * 2, rad = 1 + (r.next() - .5) * .3;
      final p = at + Offset(math.cos(ang) * 64 * rad, math.sin(ang) * 34 * rad);
      i == 0 ? patch.moveTo(p.dx, p.dy) : patch.lineTo(p.dx, p.dy);
    }
    patch.close();
    _fillPatch(c, patch, col, open, picked);
    // Scrub: little tufts and dead trees.
    final ink = strokePaint(const Color(0xFF2A2014).withValues(alpha: open ? .85 : .35), 1.8)..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final t = at + Offset(-44.0 + i * 22 + (r.next() - .5) * 8, -6 + (r.next() - .5) * 16);
      c.drawLine(t, t + const Offset(0, -16), ink);
      c.drawLine(t + const Offset(0, -10), t + const Offset(6, -16), ink);
      c.drawLine(t + const Offset(0, -6), t + const Offset(-5, -11), ink);
    }
    for (var i = 0; i < 8; i++) {
      final t = at + Offset((r.next() - .5) * 100, 6 + (r.next() - .5) * 20);
      c.drawLine(t, t + const Offset(-3, -5), ink);
      c.drawLine(t, t + const Offset(3, -5), ink);
    }
    if (!open) _padlock(c, at + const Offset(0, -2));
    if (trip == a) {
      // You're out there now: a little banner.
      final p = at + const Offset(30, -26);
      c.drawLine(p, p + const Offset(0, 24), strokePaint(const Color(0xFF3A2614), 2));
      c.drawPath(poly([p, p + const Offset(14, 4), p + const Offset(0, 9)]), Paint()..color = const Color(0xFFA8291F));
    }
    final tp = TextPainter(
      text: TextSpan(text: w.name, style: Txt.inkLabel(size: 16, color: open ? const Color(0xFF2E3A1E) : const Color(0xFF6A5A44)).copyWith(fontStyle: FontStyle.italic)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy + 30));
  }

  void _fillPatch(Canvas c, Path patch, Color col, bool open, bool picked) {
    c.drawPath(patch, Paint()..color = Color.lerp(col, const Color(0xFF3A4A2A), .55)!.withValues(alpha: open ? .42 : .14));
    c.drawPath(
      patch,
      strokePaint(const Color(0xFF3A2614).withValues(alpha: open ? .7 : .3), picked ? 3.5 : 1.4)..strokeJoin = StrokeJoin.round,
    );
  }

  void _compass(Canvas c, Offset at) {
    final p = Paint()..color = const Color(0xFF6A4A2A);
    c.drawPath(poly([at + const Offset(0, -26), at + const Offset(6, 0), at + const Offset(0, 26), at + const Offset(-6, 0)]), p);
    c.drawPath(poly([at + const Offset(-26, 0), at + const Offset(0, -6), at + const Offset(26, 0), at + const Offset(0, 6)]), p..color = const Color(0xFF8A6A3A));
    final tp = TextPainter(text: TextSpan(text: 'N', style: Txt.inkLabel(size: 13, color: const Color(0xFF3A2614))), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, at + Offset(-tp.width / 2, -44));
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.open.toString() != open.toString() ||
      old.selected != selected ||
      old.beaten.length != beaten.length ||
      old.wildPicked != wildPicked ||
      old.pinPicked != pinPicked ||
      old.delvePicked != delvePicked ||
      old.delves.toString() != delves.toString() ||
      old.pins.length != pins.length ||
      old.pins.where((p) => p.$2).length != pins.where((p) => p.$2).length ||
      old.trip != trip ||
      old.wildsOpen.toString() != wildsOpen.toString();
}

/// A map panel: a picture, what it is, and the way in. Side by side on a big screen; on a phone
/// the button drops underneath at full width, where a thumb finds it.
Widget _panel(BuildContext context, Widget art, Widget info, Widget button) => isPhone(context)
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [art, const SizedBox(width: 12), Expanded(child: info)]),
          const SizedBox(height: 10),
          button,
        ],
      )
    : Row(children: [art, const SizedBox(width: 12), Expanded(child: info), const SizedBox(width: 12), SizedBox(width: 170, child: button)]);
