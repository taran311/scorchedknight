// The Soot & Kettle: the inn where every adventure starts and ends. Rest by the fire, shop with
// Mags, sort your gear, read the adventure log, and set out across the map.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/body.dart';
import '../art/looks.dart';
import '../art/paint_kit.dart' show strokePaint;
import '../art/poses.dart';
import '../art/rig.dart';
import '../art/scenery.dart';
import '../art/silhouette.dart';
import '../art/silhouette_inn.dart';
import '../art/town_props.dart';
import '../audio/audio.dart';
import '../build_info.dart';
import '../game/loot.dart';
import '../game/errands.dart' show retainerName;
import '../game/vault.dart';
import '../game/wilds.dart' show wildAreas;
import '../game/catalog.dart';
import '../game/events.dart';
import '../game/controller.dart';
import '../game/engine.dart' show RoadStep, RoadKind;
import '../game/crafting.dart' show smithName, mageName, Gem, Elemental;
import '../game/models.dart';
import '../game/rules.dart';
import 'account_panel.dart';
import 'cadence.dart';
import 'fill_column.dart';
import 'battle_screen.dart';
import 'class_picker.dart' show HeroOrHeroine;
import 'frames.dart';
import 'gear_glance.dart';
import 'hud.dart';
import 'errands_view.dart';
import 'task_routes.dart';
import 'tasks_view.dart';
import 'item_icons.dart';
import 'journal_panel.dart';
import 'loot_window.dart';
import 'arena_page.dart';
import 'dungeon_page.dart';
import 'hall_page.dart';
import 'map_page.dart';
import 'merchant.dart';
import 'quest_dialog.dart';
import '../services/cloud.dart';
import '../services/desktop.dart';
import 'suit_ready.dart';
import 'journey.dart';
import 'throne_seals.dart';
import 'theme.dart';
import 'wilds_page.dart';
import 'trail_data.dart' show trailAt;
import 'trail_page.dart';
import 'full_game_sheet.dart';
import '../game/contracts.dart';

class InnPage extends StatefulWidget {
  const InnPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<InnPage> createState() => _InnPageState();
}

/// Whether Hob has already called you over since the game was opened.
var _hobCalled = false;

/// Tells the town when you come back to it from another screen.
final townRoutes = RouteObserver<ModalRoute<void>>();

class _InnPageState extends State<InnPage> with RouteAware {
  GameController get c => widget.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) townRoutes.subscribe(this, route);
  }

  /// The place pointed at, in the scene or on its button under it: both light up together.
  final _hover = ValueNotifier<TownSpot?>(null);

  @override
  void dispose() {
    townRoutes.unsubscribe(this);
    _hover.dispose();
    super.dispose();
  }

  /// Back in town from somewhere else.
  @override
  void didPopNext() => _checkRaid().then((_) async {
        if (mounted && c.sealNews && !c.state.inBattle && (ModalRoute.of(context)?.isCurrent ?? false)) await showThroneSeals(context, c);
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) await maybeShowJourney(context, c);
        await _checkSuits();
      });

  /// Bandits hit the town while you were out: whoever was robbed runs up to tell you, once.
  Future<void> _checkRaid() async {
    if (c.state.raid == null || c.state.raidSeen || c.state.inBattle || c.jobOffered) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false) || c.state.raidSeen) return;
    c.raidSeen();
    if (await raidAlarm(context, c) && mounted) await _chase();
  }

  /// A class suit Dunstan could finish now: he says so, once per suit (in town, forge open).
  bool _suitAsking = false;
  Future<void> _checkSuits() async {
    if (_suitAsking || _away || c.state.inBattle || c.jobOffered || c.whyShut('forge') != null || c.suitToAnnounce == null) return;
    _suitAsking = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false) || c.suitToAnnounce == null) return;
      final id = c.suitToAnnounce!;
      if (await announceSuitReady(context, c) && mounted) await showForgeWindow(context, c, tab: 'suits', focus: 'suit:$id');
    } finally {
      _suitAsking = false;
    }
  }

  /// After the bandits.
  Future<void> _chase() async {
    if (c.state.raid == null) return;
    final exit = await openBattle(context, c, BattleStart.raid);
    if (!mounted) return;
    if (exit == BattleExit.inn) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // The cutscene has told the story; the rules are in the log's book for anyone who wants them.
      if (!c.state.settings.tourSeen) c.markTourSeen();
      if (mounted && c.nextLoot != null) await resolvePendingLoot(context, c);
      // Walking in, Hob calls you straight over: a beat to take in the place, then his job.
      if (mounted && c.jobOffered && !_hobCalled) {
        _hobCalled = true;
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) await talkToHob(context, c, onHunt: _hunt, first: true);
      }
      if (mounted) await _checkRaid();
      if (mounted && c.sealNews && !c.state.inBattle) await showThroneSeals(context, c);
      if (mounted) await maybeShowJourney(context, c);
      if (mounted) await _checkSuits();
      // A seasonal event: welcomed once a year.
      final season = mounted ? c.greetSeason() : null;
      if (season != null && mounted) showQuestToast(context, season.label, 'A seasonal event is on in Cindervale');
    });
  }

  Future<void> _showStory() async {
    await showDialog<void>(context: context, builder: (_) => const _StoryWindow());
  }

  /// Onto the road's next step: a land's trail (its boss, its boss risen, or patrols to grow
  /// stronger), or the map with the place or dungeon picked; the map too when the way's shut.
  Future<void> _goRoad(RoadStep step) async {
    if (c.state.inBattle) return _resume();
    final nav = Navigator.of(context);
    switch (step.kind) {
      case RoadKind.place:
        await nav.push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c, place: step.id)));
      case RoadKind.dungeon:
        await nav.push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c, dungeon: step.id)));
      case RoadKind.wild:
        await nav.push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c, wild: int.tryParse(step.id ?? ''))));
      case RoadKind.forge:
        // The upgrades first: tempering and honing if there are any, else the forge itself.
        // (After the war it names one piece to strengthen: that one's lit up.)
        await showForgeWindow(context, c, tab: c.engine.upgradesReady > 0 || step.id != null ? 'temper' : 'forge', focus: step.id == null ? null : 'hone:${step.id}');
      case RoadKind.arena:
        await nav.push(MaterialPageRoute<void>(builder: (_) => ArenaPage(controller: c)));
      case RoadKind.hall:
        await nav.push(MaterialPageRoute<void>(builder: (_) => HallPage(controller: c)));
      case RoadKind.boss || RoadKind.heroic || RoadKind.train || RoadKind.side:
        if (c.engine.lockedByFullGame(step.land)) return showFullGame(context, c);
        if (c.whyNotTravel(step.land) != null) return _openMap();
        c.travel(step.land);
        await nav.push(MaterialPageRoute<void>(builder: (_) => TrailPage(controller: c, land: step.land)));
    }
  }

  /// Whether a place in the square is still shut (see GameEngine.whyShut).
  /// Out in the wilds with the run still open: the town waits till you're back (only the way back
  /// to the wilds, and your own tent, the kit on your back, stay open).
  bool get _away => c.state.wild != null;
  static const _awayWhy = 'You\'re out in the Wilds. The town waits till you head home';

  bool _shutSpot(TownSpot spot) => switch (spot) {
    TownSpot.stall || TownSpot.inn when _away => true,
    TownSpot.forge || TownSpot.enchanter when _away => true,
    TownSpot.forge => c.whyShut('forge') != null,
    TownSpot.enchanter => c.whyShut('tower') != null,
    _ => false,
  };

  /// A shut place, tapped: why, and what opens it.
  void _shut(String why) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Palette.stone2, duration: const Duration(seconds: 3), content: Text('🔒 $why', style: Txt.label(size: 13, color: Palette.cream))),
  );

  /// Talk to Hob: take his job, check on it, or hand it in.
  Future<void> _talk() => talkToHob(context, c, onHunt: _hunt);

  /// Straight onto Cindervale's trail, where Hob's goblins are.
  Future<void> _hunt() async {
    if (c.state.inBattle) return _resume();
    c.travel(0);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrailPage(controller: c, land: 0)));
  }

  Future<void> _openMap() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c)));
  }

  Future<void> _openDungeon() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DungeonPage(controller: c)));
  }

  Future<void> _openWilds() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WildsPage(controller: c, fromTown: true)));
  }

  Future<void> _resume() async {
    final exit = await openBattle(context, c, BattleStart.resume);
    // A boss finished off from town: onward goes to the land it opened.
    if (exit == BattleExit.onward && mounted && nextLand != null) {
      final to = nextLand!;
      nextLand = null;
      await showRoadOpens(context, c, from: c.state.continent, to: to);
      if (!mounted || c.whyNotTravel(to) != null) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrailPage(controller: c, land: to)));
    }
  }

  void _openKit() => openTent(context, c);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, k = s.knight, hurt = k.hp < maxHp(k);
      final job = c.onHobsJob, ready = c.innReady, offered = c.jobOffered, phone = isPhone(context);
      final labels = {
                            // (A dungeon run left open, from its Map button or a trip home mid-run: the
                            // way back to it, so it's never forgotten down there.)
                            TownSpot.gate: s.inBattle ? 'Back to the fight' : (s.wild != null ? 'The Wilds' : (s.dungeon != null ? 'Back to the dungeon' : 'Set out')),
                            TownSpot.stall: s.raid == 'stall' ? 'Mags\' Stall · Raided!' : 'Mags\' Stall',
                            TownSpot.inn: (hurt || !s.day) && c.whyNotRest == null && !job && !offered ? (hurt ? 'Soot & Kettle · Rest' : 'Soot & Kettle · Sleep') : 'Soot & Kettle',
                            TownSpot.tent: unspentPoints(k) > 0 ? 'Your ${homes[s.home].name} · +${unspentPoints(k)}' : 'Your ${homes[s.home].name}',
                            TownSpot.forge: '$smithName\'s Forge',
                            TownSpot.enchanter: '$mageName\'s Tower',
                          };
      // A word under a place's name, on a phone: what's waiting there.
      final notes = _away ? <TownSpot, String>{} : <TownSpot, String>{
        if (s.raid == 'stall') TownSpot.stall: 'Raided! Go and help',
        if ((hurt || !s.day) && c.whyNotRest == null && !job && !offered) TownSpot.inn: hurt ? 'Rest and heal' : 'Sleep till morning',
        if (unspentPoints(k) > 0)
          TownSpot.tent: '${unspentPoints(k)} point${unspentPoints(k) == 1 ? '' : 's'} to train'
        // Everything in hand for the next home up: say so (the cottage, then the keep).
        else if (c.engine.whyNotBuild == null && c.engine.nextHome != null)
          TownSpot.tent: '${c.engine.nextHome!.name} ready to build'
        // Wren out on an errand is news, not a job: a word on her home's button, not a card.
        else if (s.home >= 1 && s.errand != null && !c.errandBack)
          TownSpot.tent: '$retainerName back in ${c.errandLeft} ${c.errandLeft == 1 ? 'fight' : 'fights'}',
        // Worn pieces Dunstan could make stronger right now (honed, or brought up to your level),
        // and you've the gold for it.
        // Old Wick: a free scroll to spend first, else bolts or a rune you could have made now.
        if (c.whyShut('tower') == null && k.scrolls > 0)
          TownSpot.enchanter: '${k.scrolls} scroll${k.scrolls == 1 ? '' : 's'} to use'
        else if (c.whyShut('tower') == null && Gem.values.any((g) => c.whyNotFletch(g) == null))
          TownSpot.enchanter: 'Bolts to make'
        else if (c.whyShut('tower') == null && Elemental.values.any((el) => c.whyNotBind(el) == null))
          TownSpot.enchanter: 'A rune to bind',
        if (c.whyShut('forge') == null && c.engine.relicToForge != null)
          TownSpot.forge: '${relics[c.engine.relicToForge]!.name} to forge'
        else if (c.whyShut('forge') == null && c.suitsToFinish.isNotEmpty)
          TownSpot.forge: '${gearSetById(c.suitsToFinish.first)!.name} suit to forge'
        else if (c.whyShut('forge') == null && c.engine.upgradesReady > 0)
          TownSpot.forge: '${c.engine.upgradesReady} upgrade${c.engine.upgradesReady == 1 ? '' : 's'} ready',
      };
      final taps = _away && !s.inBattle
          ? <TownSpot, VoidCallback?>{
              TownSpot.gate: _openWilds,
              TownSpot.stall: () => _shut(_awayWhy),
              TownSpot.inn: () => _shut(_awayWhy),
              TownSpot.tent: _openKit,
              TownSpot.forge: () => _shut(_awayWhy),
              TownSpot.enchanter: () => _shut(_awayWhy),
            }
          : <TownSpot, VoidCallback?>{
                            TownSpot.gate: s.inBattle ? _resume : (offered ? _talk : (s.wild != null ? _openWilds : (s.dungeon != null ? _openDungeon : _openMap))),
                            // (Raided: the stall's button gives chase, as its note says, not Mags' usual chat.)
                            TownSpot.stall: s.inBattle ? () => _shut('Finish your fight first') : (s.raid == 'stall' ? _chase : () => showMerchantWindow(context, c)),
                            TownSpot.inn: () => visitInn(context, c, onHunt: _hunt),
                            TownSpot.tent: _openKit,
                            TownSpot.forge: s.inBattle ? () => _shut('Finish your fight first') : () => c.whyShut('forge') == null
                                // (A relic with every part in: straight to it, lit up.)
                                ? showForgeWindow(context, c, tab: c.engine.relicToForge != null ? 'forge' : (c.engine.upgradesReady > 0 ? 'temper' : null), focus: c.engine.relicToForge == null ? null : 'relic:${c.engine.relicToForge}')
                                : _shut(c.whyShut('forge')!),
                            // (Opened where its note points: bolts to make opens on the bolts.)
                            TownSpot.enchanter: s.inBattle ? () => _shut('Finish your fight first') : () => c.whyShut('tower') == null ? showEnchanterWindow(context, c, tab: notes[TownSpot.enchanter] == 'Bolts to make' ? 'bolts' : null) : _shut(c.whyShut('tower')!),
                          };
      // What's waiting in town, a card each: the fight left open, the road, the board, a task...
      final cards = <Widget>[
                        if (s.inBattle) ...[
                          _ResumeBanner(controller: c, onTap: _resume),
                          const SizedBox(height: 10),
                        ],
                        // Hob's job first: the story's quest outranks the side task below it.
                        // Out in the wilds: one card, the way back to them; the town's own cards wait.
                        if (_away && !s.inBattle) ...[
                          _RoadCard(
                            controller: c,
                            header: 'THE WILDS · THE TOWN WAITS',
                            step: RoadStep(RoadKind.wild, 'Back into ${wildAreas[s.wild!].name.replaceFirst('The ', 'the ')}', 'Step ${math.max(1, s.wildDepth)}', wildAreas[s.wild!].lands.first, id: '${s.wild}'),
                            onGo: _openWilds,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (offered && !_away) ...[
                          _TalkBanner(onTap: _talk),
                          const SizedBox(height: 10),
                        ],
                        if (job && !_away) ...[
                          _QuestCard(
                            compact: phone,
                            timber: s.timber,
                            iron: s.ironScrap,
                            ready: ready,
                            onTap: ready ? _talk : _hunt,
                            onOpen: _talk,
                            nudge: ready || (s.wins[0] == 0 && s.timber == 0),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // The road: the next land's boss, so there's always a way on. (Not until Hob's
                        // job is done: on a new game, the job is the way on, offered or taken.)
                        // (Not mid-fight: the fight is the way on, and the cards' suggestions skip
                        // whatever can't be started mid-fight, so they read oddly.)
                        if (c.engine.roadStep() case final step? when !s.inBattle && !_away && (s.innRepaired || step.land != 0)) ...[
                          _RoadCard(controller: c, step: step, onGo: () => _goRoad(step)),
                          const SizedBox(height: 10),
                        ],
                        // The notice board: the village's troubles, a contract each. (Like the road, not
                        // until Hob's job is done: a new knight has one thing to do first.)
                        if (s.inBattle || _away) ...[]
                        // A relic part you can go and get now comes before the contracts.
                        else if (c.engine.relicStep() case final spot? when s.innRepaired) ...[
                          _RoadCard(controller: c, step: spot, header: 'RELIC PART', icon: Icons.extension, onGo: () => _goRoad(spot)),
                          const SizedBox(height: 10),
                        ]
                        // (Every contract on the board waiting for night: somewhere to explore meanwhile,
                        // and the board again once it's dark.)
                        else if (s.innRepaired && c.engine.board.isNotEmpty && (!s.day || c.engine.board.any((j) => c.engine.whyNotExplore(j.place) == null) || c.engine.exploreStep() == null)) ...[
                          _BoardCard(controller: c),
                          const SizedBox(height: 10),
                        ]
                        // Every contract done: the board points somewhere to explore instead, so a
                        // knight stuck on a boss always has another fight (or find) to go to.
                        else if (c.engine.exploreStep() case final spot? when s.innRepaired) ...[
                          _RoadCard(controller: c, step: spot, header: 'SOMEWHERE TO EXPLORE', onGo: () => _goRoad(spot)),
                          const SizedBox(height: 10),
                        ],
                        // The next task: something to try, and a little for trying it.
                        if (c.nextTask != null && !_away) ...[
                          TaskCard(controller: c, onGo: (t) => goToTask(context, c, t)),
                          const SizedBox(height: 10),
                        ],
                        // Wren, your housekeeper (from the cottage): a card when there's something to do
                        // (she's back, or idle and waiting to be sent); out on an errand, a phone just
                        // notes it on the home button, so the square isn't a stack of cards.
                        if (s.home >= 1 && !_away && (!phone || s.errand == null || c.errandBack)) ...[
                          WrenCard(controller: c, onOpen: () => openTent(context, c, tab: 'home')),
                          const SizedBox(height: 10),
                        ],
                        // Pip (from the fortress): only when he's back with something to collect.
                        if (c.runners > 1 && !_away && c.errandBackOf(1)) ...[
                          WrenCard(controller: c, runner: 1),
                          const SizedBox(height: 10),
                        ],
                        // Hob's cellar: while you've a Cinder key to use in it.
                        if (s.keys > 0 && !_away) ...[
                          _VaultCard(controller: c, compact: phone),
                          const SizedBox(height: 10),
                        ],
                        if (s.raid != null && !s.inBattle && !_away) ...[
                          _Banner(
                            icon: Icons.warning_amber_rounded,
                            text: s.raid == 'inn' ? 'Bandits robbed the Soot & Kettle!' : 'Bandits raided Mags\' stall!',
                            button: 'Chase',
                            onTap: _chase,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (c.nextLoot != null) ...[
                          _Banner(icon: Icons.inventory_2, text: c.nextLoot!.name, button: 'Open', onTap: () => resolvePendingLoot(context, c)),
                          const SizedBox(height: 10),
                        ],
      ];
      final scene = _TownSquare(
        compact: phone,
        hover: _hover,
        hud: Tooltip(message: 'Your gear', child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => showGearGlance(context, c), child: AbsorbPointer(child: HeroCard(controller: c)))),
        onSettings: () => showDialog<void>(context: context, builder: (_) => _SettingsWindow(controller: c)),
        look: heroLook(k),
        repaired: s.innRepaired,
        quest: offered ? 1 : (ready ? 2 : (job ? 3 : 0)),
        raid: s.raid,
        // (Plus 100 with a hardcore road won: its standard by your door, see paintHome.)
        home: s.home + (s.hcBest?['won'] == true ? 100 : 0),
        hallowash: c.season == Season.hallowash,
        time: !s.day ? InnSky.night : (s.won ? InnSky.clearDay : InnSky.ashDay),
        subtitle: c.season == Season.hallowash ? 'Hallowash in the square' : s.won ? 'The Ember King is gone. The ash is settling.' : (s.innRepaired ? 'The square, by the Soot & Kettle' : 'The square, still smoking'),
        labels: labels,
        onTap: taps,
      );
      Widget place(TownSpot spot, {String? note}) => _PlaceButton(
        icon: _TownSquareState._icons[spot]!,
        label: notes[spot] == null && note == null ? labels[spot]! : (spot == TownSpot.gate ? labels[spot]! : _plainLabel(spot, s.home)),
        note: notes[spot] ?? note,
        onTap: taps[spot],
        hot: spot == TownSpot.gate,
        accent: _placeAccent[spot],
        locked: _shutSpot(spot),
        ready: !_shutSpot(spot) && ((spot == TownSpot.forge && c.engine.forgeReady) || (spot == TownSpot.enchanter && c.engine.gemsWaiting)),
        hover: phone ? null : _hover,
        spot: spot,
      );
      // On a big screen: the six places in a row under the scene, in the scene's own order (left to
      // right), the way out first and widest. Point at one and its place in the scene lights up.
      final bar = SizedBox(
        height: 64,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, spot) in const [TownSpot.gate, TownSpot.forge, TownSpot.stall, TownSpot.enchanter, TownSpot.inn, TownSpot.tent].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                flex: spot == TownSpot.gate ? 7 : 5,
                child: place(
                  spot,
                  note: spot != TownSpot.gate
                      ? null
                      : s.inBattle
                      ? 'Your fight is waiting'
                      : offered
                      ? 'Hob has a job for you'
                      : s.wild != null
                      ? 'Step ${math.max(1, s.wildDepth)}'
                      : s.dungeon != null
                      ? 'The run is still open'
                      : 'Out to the map',
                ),
              ),
            ],
          ],
        ),
      );
      final log = _LogPanel(entries: s.journal, onStory: _showStory, fill: phone);
      final size = MediaQuery.sizeOf(context);
      // A wide screen: the square and the log on the left, what's waiting on the right, all of it
      // in view at once rather than down a long page.
      final wide = !phone && size.width >= 1240 && size.height >= 620;
      return Scaffold(
        body: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top),
            Expanded(
              child: LayoutBuilder(builder: (context, viewport) {
                final pad = EdgeInsets.fromLTRB(12, 12, 12, (phone ? 12 : 20) + MediaQuery.paddingOf(context).bottom);
                if (wide) {
                  const side = 420.0, gap = 16.0;
                  final h = viewport.maxHeight - pad.vertical;
                  // The scene as wide as the room allows, leaving the bar and a few lines of log.
                  final left = math.min(math.min(viewport.maxWidth - pad.horizontal - side - gap, (h - 64 - 10 - 150) * 2), 1240.0);
                  return Padding(
                    padding: pad,
                    child: Center(
                      child: SizedBox(
                        width: left + gap + side,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: left,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  RepaintBoundary(child: scene),
                                  const SizedBox(height: 10),
                                  bar,
                                  const SizedBox(height: 10),
                                  Expanded(child: _LogPanel(entries: s.journal, onStory: _showStory, fill: true)),
                                ],
                              ),
                            ),
                            const SizedBox(width: gap),
                            SizedBox(
                              width: side,
                              child: SingleChildScrollView(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  ...cards,
                                  if (cards.isEmpty) Text('Nothing waiting in town. The road is out there.', style: Txt.onStone(size: 13)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                padding: pad,
                child: RepaintBoundary(child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: phone ? double.infinity : fitWidth(context, aspect: 2, below: 310, chrome: 130)),
                    // On a phone the square fills the screen: the place buttons and the log grow
                    // into whatever room the cards leave.
                    child: fillOnPhone(phone, viewport.maxHeight - pad.vertical, [
                        if (phone) ...[
                          Row(
                            children: [
                              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Tooltip(message: 'Your gear', child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => showGearGlance(context, c), child: AbsorbPointer(child: HeroCard(controller: c)))))),
                              IconButton(
                                tooltip: 'Settings',
                                onPressed: () => showDialog<void>(context: context, builder: (_) => _SettingsWindow(controller: c)),
                                icon: const Icon(Icons.settings, color: Palette.parch, size: 26),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        scene,
                        if (phone) ...[
                          const SizedBox(height: 8),
                          // The six places as big buttons under the scene, where thumbs reach.
                          // The six places, two to a row, taller when there's room.
                          Grow(
                            min: 3 * 50 + 16,
                            max: 3 * 82 + 16,
                            weight: 2,
                            child: Column(
                              children: [
                                for (final (i, row) in const [[TownSpot.gate, TownSpot.inn], [TownSpot.stall, TownSpot.forge], [TownSpot.enchanter, TownSpot.tent]].indexed) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        for (final (j, spot) in row.indexed) ...[
                                          if (j > 0) const SizedBox(width: 8),
                                          Expanded(child: place(spot)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          bar,
                        ],
                        const SizedBox(height: 10),
                        ...cards,
                        const SizedBox(height: 12),
                        Grow(min: 56, weight: 3, child: log),
                    ]),
                  ),
                )),
              );
              }),
            ),
          ],
        ),
      );
    },
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.button, required this.onTap});
  final IconData icon;
  final String text, button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stone(
    fill: Palette.stone3,
    child: Row(
      children: [
        Icon(icon, color: Palette.amber),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Txt.onStone(size: 14, color: Palette.cream))),
        const SizedBox(width: 8),
        StoneButton(title: button, compact: true, tone: ButtonTone.amber, onPressed: onTap),
      ],
    ),
  );
}

/// A fight left open: the foe's face, its health, and the way back in.
class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.controller, required this.onTap});
  final GameController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, foe = encounterType(s.foe, s.rare);
    final colour = foe.aura != null ? Color(foe.aura!.argb) : (foe.boss ? Palette.amber : Palette.cream);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFC04A30), width: 2),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A2418), Color(0xFF1E0E0A)]),
            boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(0, 2)), BoxShadow(color: const Color(0xFFC04A30).withValues(alpha: .35), blurRadius: 12)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                FoeFace(frame: foe.boss || foe.named ? frameForLand(s.continent) : null, size: 76, colour: colour, child: TypePortrait(type: foe, tier: foeMenace(s))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CARRY ON WHERE YOU LEFT OFF', style: Txt.label(size: 11.5, color: const Color(0xFFFF9A7A))),
                      FitText(foe.name, style: Txt.label(size: 16, color: colour, weight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Bar(value: s.foeHp, max: s.foeMax, height: 12, colours: const [Color(0xFF7FCB5A), Color(0xFF2F6A1F)], label: '${fmt(s.foeHp)} / ${fmt(s.foeMax)}'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 84, child: StoneButton(title: 'Fight', compact: true, tone: ButtonTone.blood, onPressed: onTap)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hob has a job going: his portrait, a "!" and a button to go and talk to him.
class _TalkBanner extends StatelessWidget {
  const _TalkBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Palette.amber, width: 2),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A3B26), Palette.stone1]),
          boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(0, 2)), BoxShadow(color: Palette.amber.withValues(alpha: .35), blurRadius: 12)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Stack(
                clipBehavior: Clip.none,
                children: [HobPortrait(size: 56), Positioned(right: -6, top: -6, child: QuestMark(ready: false, size: 24))],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW QUEST', style: Txt.label(size: 11, color: Palette.amber)),
                    Text('Hob wants a word', style: Txt.label(size: 18, color: Palette.cream, weight: FontWeight.w800)),
                  ],
                ),
              ),
              SizedBox(width: 78, child: _ActionTile(icon: Icons.forum, label: 'Talk', tone: ButtonTone.amber, small: true, onTap: onTap)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Hob's quest: a marked card with what to fetch, how far along you are, and the reward.
class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.timber, required this.iron, required this.ready, required this.onTap, required this.onOpen, this.nudge = false, this.compact = false});
  final int timber, iron;
  final bool ready;

  /// On a phone: smaller, the reward as icons and numbers.
  final bool compact;

  /// Glow the button: your first step (go hunting) or the last (hand it in).
  final bool nudge;
  final VoidCallback onTap;

  /// Opens the talk with Hob (tapping the card itself).
  final VoidCallback onOpen;

  Widget _need(Item item, String name, int have, int need) => Tooltip(
    message: '$name: $have of $need',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ItemIcon(item, size: compact ? 22 : 30),
        const SizedBox(width: 6),
        for (var i = 0; i < need; i++)
          Container(
            width: compact ? 11 : 13,
            height: compact ? 11 : 13,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: i < have ? Palette.amber : const Color(0xFF15110C),
              border: Border.all(color: i < have ? const Color(0xFFFFD98A) : Palette.stone3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text('$have/$need', style: Txt.label(size: 14, color: have >= need ? Palette.amber : Palette.cream)),
      ],
    ),
  );

  Widget _reward(Widget icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [icon, const SizedBox(width: 4), Text(text, style: Txt.label(size: 15, color: Palette.cream))],
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onOpen,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _card(),
    ),
  );

  Widget _card() => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: ready ? const Color(0xFFFFD98A) : Palette.amber, width: 2),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A3B26), Palette.stone1]),
      boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(0, 2)), if (ready) BoxShadow(color: Palette.amber.withValues(alpha: .5), blurRadius: 14)],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          QuestMark(ready: ready, size: compact ? 30 : 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ready ? 'READY TO HAND IN' : 'QUEST', style: Txt.label(size: 11, color: Palette.amber)),
                  ],
                ),
                Text('Mend the Soot & Kettle', style: Txt.label(size: compact ? 16 : 18, color: Palette.cream, weight: FontWeight.w800)),
                SizedBox(height: compact ? 4 : 6),
                Wrap(spacing: compact ? 12 : 18, runSpacing: 4, children: [_need(Item.timber, 'Charred timber', timber, timberNeeded), _need(Item.iron, 'Iron scrap', iron, ironNeeded)]),
                SizedBox(height: compact ? 5 : 8),
                if (compact)
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _reward(const ItemIcon(Item.coins, size: 16), '$innRepairReward'),
                      _reward(const ItemIcon(Item.potion, size: 16), '$innRepairPotions'),
                      _reward(const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFFF8A3A)), 'Rests'),
                    ],
                  )
                else
                // What Hob gives you for it, spelled out.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0x66000000), border: Border.all(color: Palette.amberLo), borderRadius: BorderRadius.circular(3)),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    // Each reward keeps its icon and words together, so a narrow phone wraps
                    // whole rewards onto the next line, never an icon on its own.
                    children: [
                      Text('REWARD', style: Txt.label(size: 12, color: Palette.amber)),
                      _reward(const ItemIcon(Item.coins, size: 20), '$innRepairReward gold'),
                      _reward(const ItemIcon(Item.potion, size: 20), '$innRepairPotions potions'),
                      _reward(const Icon(Icons.local_fire_department, size: 20, color: Color(0xFFFF8A3A)), 'Free rests'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Pulse(
            on: nudge,
            child: _IconButtonBlock(icon: Icons.check, art: ready ? null : const ItemIcon(Item.swords, size: 34), label: ready ? 'Hand in' : 'Hunt', tone: ready ? ButtonTone.amber : ButtonTone.blood, onTap: onTap),
          ),
        ],
      ),
    ),
  );
}

/// A soft glow that breathes around [child] while [on]: "this is what to press next".
class _Pulse extends StatefulWidget {
  const _Pulse({required this.on, required this.child});
  final bool on;
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.on
      ? widget.child
      : AnimatedBuilder(
          animation: _a,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: Palette.amber.withValues(alpha: .25 + .45 * _a.value), blurRadius: 8 + 14 * _a.value, spreadRadius: 1 + 3 * _a.value)],
            ),
            child: child,
          ),
          child: widget.child,
        );
}

/// A square stone button: a big symbol over a one-word label.
class _IconButtonBlock extends StatelessWidget {
  const _IconButtonBlock({required this.icon, required this.label, required this.onTap, this.tone = ButtonTone.stone, this.art});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ButtonTone tone;
  final Widget? art;
  @override
  Widget build(BuildContext context) => SizedBox(width: 78, child: _ActionTile(icon: icon, label: label, onTap: onTap, tone: tone, small: true, art: art));
}

/// One of the inn's actions: a big symbol and a single word, with the detail in a tooltip.
class _ActionTile extends StatefulWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap, this.tone = ButtonTone.stone, this.small = false, this.art});
  final IconData icon;

  /// A painted symbol to show instead of [icon].
  final Widget? art;
  final String label;
  final VoidCallback? onTap;
  final ButtonTone tone;
  final bool small;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget, enabled = w.onTap != null;
    final fill = switch (w.tone) {
      ButtonTone.blood => Palette.bloodDeep,
      ButtonTone.amber => const Color(0xFFC9963E),
      ButtonTone.stone => Palette.stone2,
    };
    final fg = switch (w.tone) {
      ButtonTone.amber => const Color(0xFF2A1C0C),
      ButtonTone.blood => const Color(0xFFFFF0DC),
      ButtonTone.stone => w.icon == Icons.local_fire_department ? const Color(0xFFFF9A4A) : Palette.amber,
    };
    Widget tile = AnimatedScale(
      scale: _down && enabled ? .95 : 1,
      duration: const Duration(milliseconds: 90),
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? w.onTap : null,
            onHover: (v) => setState(() => _hover = v),
            onHighlightChanged: (v) => setState(() => _down = v),
            borderRadius: BorderRadius.circular(3),
            child: Ink(
              decoration: stoneDecoration(fill: _hover && enabled ? Color.lerp(fill, Colors.white, .08)! : fill),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: w.small ? 6 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      w.art ?? Icon(w.icon, size: w.small ? 30 : 38, color: fg, shadows: const [Shadow(color: Colors.black, offset: Offset(1, 2))]),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    w.label,
                    style: w.tone == ButtonTone.amber ? Txt.inkLabel(size: w.small ? 12 : 15, color: fg) : Txt.label(size: w.small ? 12 : 15, color: Palette.cream, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(button: true, enabled: enabled, label: w.label, child: tile);
  }
}

/// The adventure log, folded to its latest line until opened.
class _LogPanel extends StatefulWidget {
  const _LogPanel({required this.entries, required this.onStory, this.fill = false});
  final List<JournalEntry> entries;
  final VoidCallback onStory;

  /// Given a set height (a phone's square): open, its latest lines filling the room, when there's
  /// room for a line or two; folded to one line when there isn't.
  final bool fill;
  @override
  State<_LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<_LogPanel> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    if (widget.fill) {
      // (Clipped: it never spills past the room it's given, over the navigation bar. Folded, it
      // opens as a sheet instead of growing down the screen.)
      return LayoutBuilder(builder: (context, box) => ClipRect(child: box.maxHeight >= 90 ? _filled() : Align(alignment: Alignment.topCenter, child: _panel(sheet: true))));
    }
    return _panel();
  }

  Widget _filled() {
    final list = widget.entries.reversed.toList();
    return Parchment(
      padding: const EdgeInsets.fromLTRB(10, 2, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu, color: Palette.inkSoft, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Adventure log', style: Txt.inkLabel(size: 15))),
              IconButton(tooltip: 'The story so far', onPressed: widget.onStory, icon: const Icon(Icons.menu_book, color: Palette.blood, size: 20)),
            ],
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(right: 6),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final e = list[i];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x66AE9A72)))),
                  child: Text(
                    e.text,
                    style: switch (e.kind) {
                      EntryKind.damage => Txt.body(size: 14, color: const Color(0xFF7A1D14)),
                      EntryKind.gold => Txt.body(size: 14, color: Palette.goldText),
                      EntryKind.good => Txt.body(size: 14, color: Palette.good),
                      EntryKind.day => Txt.inkLabel(size: 14),
                      EntryKind.plain => Txt.body(size: 14, color: i == 0 ? Palette.ink : Palette.inkSoft),
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The whole log in a sheet from the bottom, for a phone's square with no room to open it.
  void _sheet() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .6),
      child: Parchment(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history_edu, color: Palette.inkSoft, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('Adventure log', style: Txt.inkLabel(size: 15))),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.expand_more, color: Palette.inkSoft)),
              ],
            ),
            Flexible(child: JournalEntryList(entries: widget.entries)),
          ],
        ),
      ),
    ),
  );

  Widget _panel({bool sheet = false}) {
    final last = widget.entries.isEmpty ? null : widget.entries.last, open = _open && !sheet;
    return Parchment(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: sheet ? _sheet : () => setState(() => _open = !_open),
            child: Row(
              children: [
                const Icon(Icons.history_edu, color: Palette.inkSoft, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: open
                      ? Text('Adventure log', style: Txt.inkLabel(size: 15))
                      : Text(last?.text ?? 'Nothing yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.body(size: 14, color: Palette.inkSoft)),
                ),
                IconButton(tooltip: 'The story so far', onPressed: widget.onStory, icon: const Icon(Icons.menu_book, color: Palette.blood, size: 20)),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: Palette.inkSoft),
                const SizedBox(width: 6),
              ],
            ),
          ),
          if (open) Padding(padding: const EdgeInsets.only(right: 6, bottom: 6), child: JournalEntryList(entries: widget.entries)),
        ],
      ),
    );
  }
}

/// Cindervale's square, the hub you come back to: the signpost out to the wilds, Mags' stall,
/// Dunstan's forge and Old Wick's tower up the lane,
/// the Soot & Kettle with Hob out front, and your tent. Point at a place and it lights up with its
/// sign; tap it to go there.
class _TownSquare extends StatefulWidget {
  const _TownSquare({required this.hud, required this.onSettings, required this.look, required this.repaired, required this.quest, required this.subtitle, required this.labels, required this.onTap, required this.hover, this.raid, this.time = InnSky.night, this.home = 0, this.hallowash = false, this.compact = false});

  /// The place pointed at (here or on the buttons under the scene).
  final ValueNotifier<TownSpot?> hover;

  /// On a phone: just the scene (still tappable), with no card, signs or cog laid over it; the
  /// page shows those around it instead.
  final bool compact;

  /// Pumpkins and bats out for Hallowash.
  final bool hallowash;

  /// Your home: tent, cottage or keep.

  /// Day or night (and which kind of day).

  /// Where bandits struck ('stall' or 'inn'), if they have.

  /// Your hero card, in the top corner of the scene.
  final Widget hud;
  final VoidCallback onSettings;
  final Look look;
  final bool repaired;
  final int quest;
  final String? raid;
  final InnSky time;
  final int home;
  final String subtitle;
  final Map<TownSpot, String> labels;
  final Map<TownSpot, VoidCallback?> onTap;

  @override
  State<_TownSquare> createState() => _TownSquareState();
}

class _TownSquareState extends State<_TownSquare> {
  ValueNotifier<TownSpot?> get _hover => widget.hover;

  /// The place under a point in the scene: where places overlap (the forge up the lane behind the
  /// stall and the signpost), the smaller, nearer one wins, so each has a fair patch to point at.
  TownSpot? _at(Offset p, Rect Function(Rect) place) {
    TownSpot? best;
    var area = double.infinity;
    for (final e in townSpots.entries) {
      final r = place(e.value);
      if (r.contains(p) && r.width * r.height < area) (best, area) = (e.key, r.width * r.height);
    }
    return best;
  }

  static const _icons = {TownSpot.gate: Icons.signpost, TownSpot.stall: Icons.storefront, TownSpot.inn: Icons.sports_bar, TownSpot.tent: Icons.shield, TownSpot.forge: Icons.hardware, TownSpot.enchanter: Icons.auto_fix_high};

  @override
  Widget build(BuildContext context) => Stone(
    padding: const EdgeInsets.all(3),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: AspectRatio(
        aspectRatio: 16 / 8,
        child: LayoutBuilder(
          builder: (context, box) {
            // The same framing as the painter: the scene's width fills the box, its bottom shows.
            final k = box.maxWidth / sceneSize.width, dy = sceneSize.height - box.maxHeight / k;
            Rect place(Rect r) => Rect.fromLTRB(r.left * k, (r.top - dy) * k, r.right * k, (r.bottom - dy) * k);
            return Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<TownSpot?>(
                    valueListenable: _hover,
                    builder: (context, on, _) => _InnScene(look: widget.look, repaired: widget.repaired, quest: widget.quest, hover: on, raid: widget.raid, time: widget.time, home: widget.home, hallowash: widget.hallowash),
                  ),
                ),
                // One region over the whole scene: what's under the pointer is worked out in one
                // place (see _at), so neighbours never fight over it.
                Positioned.fill(
                  child: ValueListenableBuilder<TownSpot?>(
                    valueListenable: _hover,
                    builder: (context, on, child) => MouseRegion(
                      cursor: on != null && widget.onTap[on] != null ? SystemMouseCursors.click : MouseCursor.defer,
                      onHover: (e) {
                        final at = _at(e.localPosition, place);
                        if (at != _hover.value) _hover.value = at;
                      },
                      onExit: (_) => _hover.value = null,
                      child: child,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (e) {
                        final at = _at(e.localPosition, place);
                        if (at != null) widget.onTap[at]?.call();
                      },
                    ),
                  ),
                ),
                // The sign of the place pointed at, over it (the buttons under the scene name them all).
                if (!widget.compact)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<TownSpot?>(
                        valueListenable: _hover,
                        builder: (context, on, _) {
                          if (on == null) return const SizedBox.shrink();
                          final r = place(townSpots[on]!);
                          // Centred over the place; near an edge, held against it rather than pushed
                          // over its neighbour. Clear of your hero card in the top corner.
                          final edge = r.center.dx < 110 ? -1.0 : (r.center.dx > box.maxWidth - 110 ? 1.0 : 0.0);
                          return Stack(children: [
                            Positioned(
                              left: (r.center.dx - 110).clamp(4.0, math.max(4.0, box.maxWidth - 224)),
                              width: 220,
                              top: (r.top - 30).clamp(r.center.dx < 330 ? 96.0 : 8.0, math.max(96.0, box.maxHeight - 40)),
                              child: Align(alignment: Alignment(edge, 0), child: _Sign(icon: _icons[on]!, text: widget.labels[on] ?? '', lit: true, off: widget.onTap[on] == null)),
                            ),
                          ]);
                        },
                      ),
                    ),
                  ),
                if (!widget.compact) Positioned(left: 8, top: 8, child: widget.hud),
                if (!widget.compact)
                  Positioned(
                  right: 6,
                  top: 6,
                  child: IconButton(
                    tooltip: 'Settings',
                    onPressed: widget.onSettings,
                    icon: const Icon(Icons.settings, color: Palette.parch, size: 24, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 8,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cindervale', style: Txt.logo().copyWith(fontSize: widget.compact ? 18 : 24)),
                        if (!widget.compact) Text(widget.subtitle, style: Txt.label(size: 13, color: Palette.parch)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// A little hanging wooden sign with a symbol and a name.
class _Sign extends StatelessWidget {
  const _Sign({required this.icon, required this.text, required this.lit, this.off = false});
  final IconData icon;
  final String text;
  final bool lit, off;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: lit ? 1.08 : 1,
    duration: const Duration(milliseconds: 120),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 4),
      decoration: BoxDecoration(
        color: lit ? const Color(0xFF6A4A2A) : const Color(0xE63A2818),
        border: Border.all(color: lit ? const Color(0xFFFFD98A) : const Color(0xFF8A6A3A), width: 1.5),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [const BoxShadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 3), if (lit) BoxShadow(color: Palette.amber.withValues(alpha: .6), blurRadius: 12)],
      ),
      child: Opacity(
        opacity: off ? .5 : 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: lit ? const Color(0xFFFFE6A0) : Palette.amber),
            const SizedBox(width: 5),
            Flexible(child: FitText(text, style: Txt.label(size: 13, color: lit ? Colors.white : Palette.cream))),
          ],
        ),
      ),
    ),
  );
}

/// The square at night, the hero out front, ash still drifting down.
class _InnScene extends StatefulWidget {
  const _InnScene({required this.look, this.repaired = true, this.quest = 0, this.hover, this.raid, this.time = InnSky.night, this.home = 0, this.hallowash = false});
  final Look look;
  final int home;
  final bool hallowash;
  final String? raid;
  final InnSky time;
  final bool repaired;

  /// The place being pointed at, to light up.
  final TownSpot? hover;

  /// 0 no quest, 1 a quest to take ("!"), 2 one to hand in (a tick), 3 one under way (a grey "?"):
  /// the marker floats over Hob's head.
  final int quest;

  @override
  State<_InnScene> createState() => _InnSceneState();
}

class _InnSceneState extends State<_InnScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  final _backdrop = _Backdrop();
  final _cadence = Cadence();
  bool _phone = false;

  @override
  void initState() {
    super.initState();
    // Ambient life (breathing, drifting ash): smooth on a computer, half the work on a phone.
    _ticker = createTicker((e) {
      final ms = e.inMicroseconds / 1000.0;
      if (_cadence.tick(ms, fps: _phone ? 30 : 60)) _t.value = ms;
    });
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    _backdrop.picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _phone = MediaQuery.sizeOf(context).shortestSide < 600;
    return _build(context);
  }

  Widget _build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _InnPainter(widget.look, _t, widget.repaired, widget.quest, widget.hover, widget.raid, widget.time, widget.home, widget.hallowash, _backdrop, MediaQuery.devicePixelRatioOf(context), lite: MediaQuery.sizeOf(context).width < 600),
    ),
  );
}

/// The square behind the figures, recorded once and replayed: the inn, the stall with Mags, your
/// home, the signpost. It's re-recorded a dozen or so times a second (smoke, stars and flickering
/// windows move slowly) and whenever what it shows changes, so the hundreds of shapes in it aren't
/// rebuilt every frame.
class _Backdrop {
  ui.Picture? picture;
  String key = '';
  double at = -1e9;
}

/// Where Hob stands in the scene: by the inn's corner, in front of the boarded window.
const _hobX = 548.0;

class _InnPainter extends CustomPainter {
  _InnPainter(this.look, this.time, this.repaired, this.quest, this.hover, this.raid, this.sky, this.home, this.hallowash, this.backdrop, this.dpr, {this.lite = false}) : super(repaint: time);

  /// A phone: the lighter silhouettes (see silhouettePicture).
  final bool lite;
  final int home;
  final bool hallowash;
  final Look look;
  final String? raid;
  final InnSky sky;
  final bool repaired;
  final int quest;
  final TownSpot? hover;
  final ValueNotifier<double> time;
  final _Backdrop backdrop;
  final double dpr;

  /// Everything behind Hob and the hero, in scene coordinates.
  void _paintBack(Canvas canvas, double t) {
    paintSilhouetteInn(canvas, repaired, t, fence: false, time: sky);
    if (hover != null) paintSpotGlow(canvas, hover!, t);
    // Up the lane: Dunstan's forge and Old Wick's tower.
    paintForge(canvas, t);
    paintEnchanterTower(canvas, t);
    // The rest of the square: the signpost out of town, Mags at her stall, your tent.
    paintSignpost(canvas, t);
    paintStall(
      canvas,
      t,
      (c) => silhouette(
        c,
        const Rect.fromLTRB(100, 260, 320, 500),
        (cc) => drawHumanoid(cc, magsLook, hobPose, t, const DrawOptions(at: Offset(210, 470), scale: .7, flip: true, shadow: false)),
        rim: const Color(0xFFFFB04A),
        halo: .3,
        detail: .75,
      ),
    );
    paintHome(canvas, t, home % 100, trophy: home >= 100);
    if (hallowash) paintHallowash(canvas, t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // The scene is 960 × 540; show its lower part, where the inn and the road are.
    final k = size.width / sceneSize.width, dy = -(sceneSize.height - size.height / k);
    canvas.scale(k);
    canvas.translate(0, dy);
    final key = '$repaired|$sky|$home|$hallowash|$hover';
    if (backdrop.key != key || t - backdrop.at > 70 || backdrop.picture == null) {
      final rec = ui.PictureRecorder();
      _paintBack(Canvas(rec), t);
      // (The old one isn't disposed here: on the web the last frame may still be drawing it.)
      backdrop
        ..picture = rec.endRecording()
        ..key = key
        ..at = t;
    }
    canvas.drawPicture(backdrop.picture!);
    final day = sky != InnSky.night, detail = day ? .8 : .5;
    // Hob, out front of his inn facing the hero, and the hero: lit together, in one pass.
    silhouette(
      canvas,
      const Rect.fromLTRB(240, 180, 660, 500),
      (c) {
        drawHumanoid(c, hobLook, hobPose, t, const DrawOptions(at: Offset(_hobX, 470), scale: .78, flip: true));
        drawHumanoid(c, look, idlePose(look.stance, t), t, const DrawOptions(at: Offset(446, 470), scale: .78));
      },
      rim: innRim(repaired, sky),
      detail: detail,
      lite: lite,
    );
    // Ash, still falling all these years later (until Vharrax is gone and the sky clears).
    final ash = Paint();
    for (var i = 0; i < (sky == InnSky.clearDay ? 0 : 40); i++) {
      final seed = i * 97.0;
      final x = (seed * 7.3 + t * (.012 + (i % 5) * .004)) % 960;
      final y = (seed * 3.1 + t * (.03 + (i % 3) * .01)) % 540;
      final sway = math.sin(t / 900 + i) * 6;
      canvas.drawCircle(Offset(x + sway, y), 1.4 + (i % 3) * .7, ash..color = const Color(0xFFBFB8AE).withValues(alpha: .35 + (i % 4) * .1));
    }
    // A raid: a red alarm over the place they hit.
    if (raid != null) {
      final at = (raid == 'inn' ? const Offset(620, 300) : const Offset(229, 268)) + Offset(0, math.sin(t / 300) * 4);
      final pulse = .5 + .5 * math.sin(t / 200);
      canvas.drawCircle(at, 22, Paint()..color = const Color(0xFFFF3A2A).withValues(alpha: .25 + .2 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawCircle(at, 15, Paint()..color = const Color(0xFFB0281C));
      canvas.drawCircle(at, 15, strokePaint(const Color(0xFFFFD98A), 2));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at + const Offset(0, -3), width: 5, height: 14), const Radius.circular(2)), Paint()..color = const Color(0xFFFFF0DC));
      canvas.drawCircle(at + const Offset(0, 8), 2.6, Paint()..color = const Color(0xFFFFF0DC));
    }
    // Hob's quest marker, bobbing over the door.
    if (quest > 0) {
      paintQuestMark(canvas, Offset(_hobX + 4, 470 - builds['human']!.height * .78 - 30 + math.sin(t / 380) * 4), quest == 3 ? 13 : 18, quest == 2, pending: quest == 3);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnPainter old) => old.look != look || old.repaired != repaired || old.quest != quest || old.hover != hover || old.raid != raid || old.sky != sky || old.home != home || old.hallowash != hallowash || old.dpr != dpr;
}

/// The story, told once on the first visit (and any time from the log).
class _StoryWindow extends StatelessWidget {
  const _StoryWindow();

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Stone(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: SingleChildScrollView(
          child: RepaintBoundary(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('The Great Burning', style: Txt.label(size: 20, color: Palette.amber, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Vharrax the Ember King burned the world. You survived: singed, sooty, half an eyebrow short. '
                'Six lands and their bosses stand between you and his Ember Throne.',
                style: Txt.onStone(size: 14.5, color: Palette.cream),
              ),
              const SizedBox(height: 12),
              for (final (icon, colour, text) in [
                (Icons.explore, Palette.amber, 'Set out, pick a land, fight what turns up'),
                (Icons.sports_kabaddi, const Color(0xFFE07A5A), isPhone(context) ? 'Tap a move to use it; hold it to see what it does' : 'Blade, Rites, Crossbow, Potion: number keys'),
                (Icons.flight, const Color(0xFF8FC3D9), 'Flyers and casters? Crossbow or Rites'),
                (Icons.inventory_2, Palette.amber, 'Every win drops gear'),
                (Icons.workspace_premium, const Color(0xFFFFD98A), 'Win $winsForBoss fights to find the boss'),
                (Icons.local_fire_department, const Color(0xFFFF8A3A), 'Rest at the inn to heal, free'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(icon, color: colour, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(text, style: Txt.onStone(size: 14.5, color: Palette.cream))),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              StoneButton(title: 'Pull up a stool', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop()),
            ],
          )),
        ),
      ),
    ),
  );
}

/// Your name, faster fights, and starting over.
class _SettingsWindow extends StatefulWidget {
  const _SettingsWindow({required this.controller});
  final GameController controller;

  @override
  State<_SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<_SettingsWindow> {
  late final _name = TextEditingController(text: widget.controller.state.settings.name);
  late Settings _s = widget.controller.state.settings.copy();

  /// Saved (or starting over) already: closing the window needn't save again.
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    // Back to the saved levels if the window closed without saving.
    final s = widget.controller.state.settings;
    Audio.configure(music: s.music, sound: s.sound, muted: s.muted);
    super.dispose();
  }

  /// Hear the change while you make it.
  void _set(void Function(Settings s) change) {
    setState(() => change(_s = _s.copy()));
    Audio.configure(music: _s.music, sound: _s.sound, muted: _s.muted);
  }

  Widget _toggle(String title, IconData icon, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    value: value,
    onChanged: onChanged,
    secondary: Icon(icon, color: Palette.amber, size: 22),
    title: Text(title, style: Txt.onStone(size: 14, color: Palette.cream)),
  );

  Widget _slider(IconData icon, double value, ValueChanged<double> onChanged, {VoidCallback? onEnd}) => Row(
    children: [
      Icon(icon, color: _s.muted ? Palette.cream.withValues(alpha: .35) : Palette.amber, size: 22),
      Expanded(
        child: Slider(value: value, onChanged: _s.muted ? null : onChanged, onChangeEnd: onEnd == null ? null : (_) => onEnd(), activeColor: Palette.amber),
      ),
      SizedBox(width: 38, child: Text('${(value * 100).round()}%', textAlign: TextAlign.right, style: Txt.onStone(size: 12.5))),
    ],
  );

  Future<void> _newHero() async {
    final c = widget.controller;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.stone2,
        title: Text('Start a new hero?', style: Txt.label(size: 18, color: Palette.amber)),
        content: Text('Your level, gold, gear, companions and progress are all wiped. This can\'t be undone.', style: Txt.onStone(size: 14, color: Palette.cream)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Keep my hero', style: Txt.label(size: 14))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Start over', style: Txt.label(size: 14, color: const Color(0xFFE07A5A)))),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    _done = true;
    Navigator.of(context).pop();
    await c.newAdventure();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, k = c.state.knight;
    // Closed by tapping outside or Back (the usual way on a phone): keep what was changed, rather
    // than quietly throwing it away.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || _done) return;
        _done = true;
        c.applySettings(_s);
        c.setName(_name.text);
      },
      child: Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stone(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SingleChildScrollView(
            child: RepaintBoundary(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settings', style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('Your knight\'s name', style: Txt.onStone(size: 14, color: Palette.cream)),
              const SizedBox(height: 6),
              TextField(controller: _name, maxLength: 24, style: Txt.body(size: 15), decoration: const InputDecoration(hintText: 'Sir Smudge', counterText: '')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Look', style: Txt.onStone(size: 14, color: Palette.cream))),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: ListenableBuilder(
                        listenable: c,
                        builder: (context, _) => HeroOrHeroine(female: k.female, onChanged: c.setFemale),
                      ),
                    ),
                  ),
                ],
              ),
              _toggle('Faster fights', Icons.fast_forward_rounded, _s.fastFights, (v) => _set((s) => s.fastFights = v)),
              _toggle('Blood & gore', Icons.water_drop_rounded, _s.gore, (v) => _set((s) => s.gore = v)),
              if (!isDesktopApp) _toggle('Vibration', Icons.vibration_rounded, _s.vibrate, (v) => _set((s) => s.vibrate = v)),
              // On a PC: fullscreen (F11 or Alt+Enter too), straight away rather than on Save.
              if (isDesktopApp)
                ListenableBuilder(
                  listenable: Desktop.instance,
                  builder: (context, _) => _toggle('Fullscreen  (F11)', Icons.fullscreen_rounded, Desktop.instance.fullscreen, Desktop.instance.setFullscreen),
                ),
              _toggle('Sell junk where it falls', Icons.sell_rounded, _s.autoSellJunk, (v) => _set((s) => s.autoSellJunk = v)),
              _toggle('Mute all', Icons.volume_off_rounded, _s.muted, (v) => _set((s) => s.muted = v)),
              // (Two graphs at the top of the screen: the upper one is drawing to the screen, the
              // lower one is the game working out each frame. Red bars are frames that ran late.)
              if (!kIsWeb && (kDebugMode || isDesktopApp)) _toggle('Show frame timings', Icons.speed_rounded, _s.frameTimes, (v) => _set((s) => s.frameTimes = v)),
              _slider(Icons.music_note_rounded, _s.music, (v) => _set((s) => s.music = v)),
              _slider(Icons.volume_up_rounded, _s.sound, (v) => _set((s) => s.sound = v), onEnd: () => Audio.play(Sfx.hit)),
              const SizedBox(height: 6),
              StoneButton(
                title: 'Save',
                tone: ButtonTone.blood,
                onPressed: () {
                  _done = true;
                  c.applySettings(_s);
                  c.setName(_name.text);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 14),
              _CloudSection(controller: c),
              const SizedBox(height: 6),
              if (isDesktopApp) ...[
                StoneButton(
                  title: 'Quit to desktop',
                  compact: true,
                  onPressed: () {
                    _done = true;
                    c.applySettings(_s);
                    c.setName(_name.text);
                    Desktop.instance.quit(c.saveNow);
                  },
                ),
                const SizedBox(height: 4),
              ],
              TextButton(onPressed: _newHero, child: Text('Start a new hero…', style: Txt.label(size: 13, color: const Color(0xFFE07A5A)))),
              // Which build this is: to tell at a glance that a phone has the latest.
              Center(child: Text('Build $buildStamp', style: Txt.onStone(size: 11.5, color: Palette.parch2))),
              if (Audio.report() case final r? when kDebugMode) Padding(padding: const EdgeInsets.only(top: 4), child: Center(child: Text(r, textAlign: TextAlign.center, style: Txt.onStone(size: 10.5, color: Palette.parch2)))),
            ],
          )),
          ),
        ),
      ),
      ),
    );
  }
}

/// Each place's colour on its button: the inn's hearth, Mags' green bottles, the forge's embers,
/// Old Wick's arcane violet, and the cool blue of your tent's canvas at night.
const _placeAccent = <TownSpot, Color>{
  TownSpot.inn: Color(0xFFF2A945),
  TownSpot.stall: Color(0xFF8BD46A),
  TownSpot.forge: Color(0xFFFF7A3A),
  TownSpot.enchanter: Color(0xFFB892FF),
  TownSpot.tent: Color(0xFF7FC0E8),
};

/// One of the town's places as a big button (on a phone, under the scene).
/// A place's plain name, for a button that says what's waiting on a line of its own.
String _plainLabel(TownSpot spot, int home) => switch (spot) {
  TownSpot.forge => '$smithName\'s Forge',
  TownSpot.stall => 'Mags\' Stall',
  TownSpot.inn => 'Soot & Kettle',
  TownSpot.tent => 'Your ${homes[home].name}',
  TownSpot.enchanter => '$mageName\'s Tower',
  TownSpot.gate => 'Set out',
};

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.icon, required this.label, this.note, this.onTap, this.hot = false, this.ready = false, this.accent, this.locked = false, this.hover, this.spot});

  /// With a pointer (a big screen): the place pointed at, shared with the scene so the two light
  /// up together; [spot] is this button's.
  final ValueNotifier<TownSpot?>? hover;
  final TownSpot? spot;

  /// A line under the name: what's waiting there (points to train, a rest).
  final String? note;

  /// Not open yet: dimmed, with a padlock (tapping says what opens it).
  final bool locked;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The place's own colour (its icon, an edge of light and a tinted rim on the stone), so each
  /// is known at a glance; the stone stays the same grey, so the square still looks of a piece.
  final Color? accent;

  /// The main way onward (Set out): lit up.
  final bool hot;

  /// Something's waiting there for you (ore to smelt, gems to grind): a little amber light.
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final h = hover;
    if (h == null) return _button(false);
    return MouseRegion(
      onEnter: (_) => h.value = spot,
      onExit: (_) {
        if (h.value == spot) h.value = null;
      },
      child: ValueListenableBuilder<TownSpot?>(valueListenable: h, builder: (context, on, _) => _button(on == spot)),
    );
  }

  Widget _button(bool lit) => AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      boxShadow: lit ? [BoxShadow(color: (hot ? Palette.amber : (accent ?? Palette.amber)).withValues(alpha: .55), blurRadius: 14, spreadRadius: 1)] : const [],
    ),
    transform: lit ? (Matrix4.identity()..translateByDouble(0, -2, 0, 1)) : Matrix4.identity(),
    child: Opacity(
    opacity: onTap == null || locked ? .5 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: hot || accent == null
              ? stoneDecoration(fill: hot ? Palette.bloodDeep : Palette.stone2)
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Color.lerp(Palette.stone0, accent, .45)!, width: 2),
                  // The stone, with the place's light falling across it from the icon's side.
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color.lerp(Palette.stone2, accent, .22)!, Color.lerp(Palette.stone2, Colors.black, .06)!],
                    stops: const [0, .55],
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(0, 2))],
                ),
          child: LayoutBuilder(builder: (context, box) {
            final big = box.maxHeight >= 64;
            return Row(
            children: [
              Icon(icon, size: big ? 30 : 24, color: hot ? const Color(0xFFFFE0C0) : (accent ?? Palette.amber), shadows: accent == null || hot ? null : [Shadow(color: accent!.withValues(alpha: .6), blurRadius: 8)]),
              const SizedBox(width: 8),
              Expanded(
                child: note == null
                    ? Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.label(size: big ? 15.5 : 14, color: Palette.cream, weight: FontWeight.w800))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FitText(label, style: Txt.label(size: big ? 15.5 : 14, color: Palette.cream, weight: FontWeight.w800)),
                          FitText(note!, style: Txt.label(size: big ? 12.5 : 11.5, color: Palette.amber)),
                        ],
                      ),
              ),
              if (ready)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.amber, boxShadow: [BoxShadow(color: Palette.amber.withValues(alpha: .7), blurRadius: 6)]),
                ),
              if (locked) const Icon(Icons.lock, size: 18, color: Palette.parch2),
            ],
          );
          }),
        ),
      ),
    ),
    ),
  );
}

/// Settings: where your hero is kept, and signing in with Google so it follows you between the
/// browser and the Android app.
class _CloudSection extends StatelessWidget {
  const _CloudSection({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSave.instance;
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        final note = Txt.onStone(size: 12.5);
        if (!cloud.available) {
          if (steamBuild) return Text('Your hero is saved on this computer, and Steam Cloud keeps a copy for any other PC you play on.', textAlign: TextAlign.center, style: note);
          if (isDesktopApp) return Text('Your hero is saved on this computer.', textAlign: TextAlign.center, style: note);
          return Text('Your hero is kept on this device. Clearing the browser\'s site data (or uninstalling the app) wipes it.', textAlign: TextAlign.center, style: note);
        }
        final synced = cloud.lastSync;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(4), border: Border.all(color: Palette.stone3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(cloud.signedIn ? Icons.cloud_done : Icons.cloud_outlined, color: Palette.amber, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Cloud save', style: Txt.label(size: 15, color: Palette.cream, weight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                cloud.signedIn
                    ? 'Signed in as ${cloud.who}. Your hero follows you to any browser or phone you sign in on.${synced == null ? '' : ' Last saved up at ${synced.hour.toString().padLeft(2, '0')}:${synced.minute.toString().padLeft(2, '0')}.'}'
                    : cloud.needsVerify
                    ? 'Nearly there: check your email to finish signing in.'
                    : 'Sign in to keep your hero safe and play it on your phone and in the browser.',
                style: note,
              ),
              if (cloud.signedIn && cloud.problem != null) ...[
                const SizedBox(height: 4),
                Text(cloud.problem!, style: Txt.onStone(size: 12.5, color: const Color(0xFFE0A070))),
              ],
              const SizedBox(height: 8),
              if (cloud.signedIn)
                Row(
                  children: [
                    Expanded(child: StoneButton(title: 'Sync now', compact: true, onPressed: controller.syncWithCloud)),
                    const SizedBox(width: 8),
                    Expanded(child: StoneButton(title: 'Sign out', compact: true, onPressed: cloud.signOut)),
                  ],
                ),
              // Deleting the account (Play requires it be possible from inside the app).
              if (cloud.signedIn)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Palette.stone2,
                          title: Text('Delete your account?', style: Txt.label(size: 17, color: Palette.cream)),
                          content: Text('Your account and your cloud save are deleted for good. Your hero stays on this device.', style: Txt.onStone(size: 14)),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Keep it', style: Txt.label(size: 14, color: Palette.parch))),
                            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete', style: Txt.label(size: 14, color: const Color(0xFFE0604A)))),
                          ],
                        ),
                      );
                      if (yes == true) await cloud.deleteAccount();
                    },
                    child: Text('Delete account', style: Txt.label(size: 12.5, color: Palette.parch2)),
                  ),
                )
              else
                const AccountPanel(compact: true),
            ],
          ),
        );
      },
    );
  }
}


/// The Ember Vault in Hob's cellar: your Cinder keys, the six pieces only it holds (the ones you've
/// found shown, the rest still locked), and the door.
class _VaultCard extends StatelessWidget {
  const _VaultCard({required this.controller, this.compact = false});
  final GameController controller;

  /// On a phone: one row (the pieces as a count, the Oath as a shield) so the square fits the screen.
  final bool compact;

  static const _ember = Color(0xFFFF9A4A);

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, found = s.vaultFound;
    if (compact) {
      final sworn = guardianSworn(found);
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _ember.withValues(alpha: .7), width: 1.5),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A2216), Color(0xFF1A0E08)]),
        ),
        child: Row(
          children: [
            const Icon(Icons.vpn_key_rounded, color: _ember, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EMBER VAULT', style: Txt.label(size: 14, color: _ember, weight: FontWeight.w800)),
                  Row(
                    children: [
                      Text('${s.keys} ${s.keys == 1 ? 'key' : 'keys'}', style: Txt.onStone(size: 12.5)),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: sworn ? 'Guardian\'s Oath: each fight\'s first heavy blow hits no harder than a normal one, and the vault keeps its best gear for you' : 'Vault pieces found · all six: the Guardian\'s Oath',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(sworn ? Icons.verified_user_rounded : Icons.inventory_2_outlined, size: 14, color: _ember),
                            const SizedBox(width: 3),
                            Text('${found.length}/${vaultPieces.length}', style: Txt.label(size: 12.5, color: _ember)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (s.keys > 0 && c.whyNotVault != null) Text(c.whyNotVault!, style: Txt.onStone(size: 11.5, color: const Color(0xFFE8B070))),
                  if (nextVaultPieceLevel(found.length, s.knight.level) case final at?) Text('Its next piece stirs at level $at', style: Txt.onStone(size: 11.5)),
                ],
              ),
            ),
            SizedBox(width: 88, child: StoneButton(title: 'Open', compact: true, tone: ButtonTone.blood, onPressed: c.whyNotVault == null ? () => _open(context) : null)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _ember.withValues(alpha: .7), width: 1.5),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A2216), Color(0xFF1A0E08)]),
        boxShadow: [BoxShadow(color: _ember.withValues(alpha: .18), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: _ember, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('THE EMBER VAULT', style: Txt.label(size: 15, color: _ember, weight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        // Where keys come from: a tap away.
                        const Tooltip(
                          message: 'Foes drop Cinder keys now and then. Tough foes drop them twice as often, Deadly ones four times, and bosses two times in five.',
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: Duration(seconds: 5),
                          child: Icon(Icons.info_outline, size: 16, color: _ember),
                        ),
                      ],
                    ),
                    Text('Hob\'s cellar · ${s.keys} Cinder ${s.keys == 1 ? 'key' : 'keys'}', style: Txt.onStone(size: 12.5)),
                    // Why the door won't open, when you've a key but it still won't.
                    if (s.keys > 0 && c.whyNotVault != null) Text(c.whyNotVault!, style: Txt.onStone(size: 12, color: const Color(0xFFE8B070))),
                    // No key yet: where to get one, in a few words.
                    if (s.keys == 0) Text('Foes drop keys · tougher ones more often', style: Txt.onStone(size: 12, color: const Color(0xFFE8B070))),
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                child: StoneButton(title: 'Open', compact: true, tone: ButtonTone.blood, onPressed: c.whyNotVault == null ? () => _open(context) : null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The collection: six pieces, the found ones lit.
          Row(
            children: [
              for (final p in vaultPieces)
                Expanded(
                  child: Tooltip(
                    message: found.contains(p.name) ? p.name : 'Still in the vault',
                    child: Container(
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: found.contains(p.name) ? const Color(0xFF4A2A14) : Colors.black38,
                        border: Border.all(color: found.contains(p.name) ? _ember : const Color(0xFF3A2A1E)),
                      ),
                      child: Icon(found.contains(p.name) ? _icon(p.slot) : Icons.lock_outline, size: 16, color: found.contains(p.name) ? _ember : const Color(0xFF5A4636)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Find all six: the Guardian's Oath.
          if (guardianSworn(found))
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_rounded, size: 15, color: _ember),
                const SizedBox(width: 4),
                Flexible(child: Text('Guardian\'s Oath: each fight\'s first heavy blow hits no harder than a normal one, and the vault keeps its best gear for you', textAlign: TextAlign.center, style: Txt.onStone(size: 11.5, color: _ember))),
              ],
            )
          else
            Text('${found.length} of ${vaultPieces.length} found · all six: the Guardian\'s Oath', textAlign: TextAlign.center, style: Txt.onStone(size: 11.5, color: Palette.parch2)),
        ],
      ),
    );
  }

  static IconData _icon(GearSlot slot) => switch (slot) {
    GearSlot.trinket => Icons.brightness_7,
    GearSlot.boots => Icons.directions_walk,
    GearSlot.gloves => Icons.back_hand,
    GearSlot.ring => Icons.radio_button_checked,
    GearSlot.helm => Icons.military_tech,
    _ => Icons.auto_awesome,
  };

  Future<void> _open(BuildContext context) async {
    final c = controller;
    // (This card is gone the moment the key turns, when the last key's used: carry on from the
    // navigator's context, so "Look closer" still opens the find.)
    final nav = Navigator.of(context).context;
    final wasSworn = guardianSworn(c.state.vaultFound);
    final find = c.openVault();
    if (find == null || !context.mounted) return;
    final oath = !wasSworn && guardianSworn(c.state.vaultFound);
    Audio.play(find.piece ? Sfx.legendaryDrop : (find.item != null ? Sfx.rareDrop : Sfx.coins));
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Stone(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key_rounded, color: _ember, size: 40),
                const SizedBox(height: 6),
                Text(find.piece ? 'A VAULT PIECE!' : 'THE VAULT OPENS', style: Txt.label(size: 20, color: find.piece ? const Color(0xFFFFB04A) : _ember, weight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  find.piece
                      ? 'On a velvet cushion, untouched for a hundred years: ${find.item!.name}.'
                      : find.item != null
                      ? 'Behind the door: ${find.item!.name} (${find.item!.rarity.label}), and a purse.'
                      : 'Behind the door: a heap of old coin.',
                  textAlign: TextAlign.center,
                  style: Txt.onStone(size: 15),
                ),
                const SizedBox(height: 6),
                Text('+${find.gold} gold', style: Txt.label(size: 15, color: Palette.amber, weight: FontWeight.w800)),
                if (oath) ...[
                  const SizedBox(height: 12),
                  const Icon(Icons.verified_user_rounded, color: _ember, size: 34),
                  Text('THE GUARDIAN\'S OATH', style: Txt.label(size: 18, color: const Color(0xFFFFB04A), weight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Every treasure the vault kept is yours, and its keeper\'s oath with them. From now on, the first heavy blow in every fight meets your shield and lands no harder than a normal one.', textAlign: TextAlign.center, style: Txt.onStone(size: 13.5)),
                ],
                const SizedBox(height: 12),
                StoneButton(title: find.item != null ? 'Look closer' : 'Lovely', tone: ButtonTone.blood, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
    if (nav.mounted && c.nextLoot != null) await resolvePendingLoot(nav, c, title: find.piece ? 'From the Ember Vault' : 'The vault\'s spoils', line: find.item?.lore ?? 'Dusty, but none the worse for it.');
  }
}

/// The road on: the next land's boss, how far along its trail you are, and a button straight there
/// (or, while the way's still shut, what opens it).
class _RoadCard extends StatelessWidget {
  const _RoadCard({required this.controller, required this.step, required this.onGo, this.header, this.icon});

  /// An icon in place of the step's own (a relic part's).
  final IconData? icon;
  final GameController controller;
  final RoadStep step;
  final VoidCallback onGo;

  /// Words over the title in place of the road's own (the board's "somewhere to explore").
  final String? header;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, l = continents[step.land], at = trailAt(s, step.land), col = Color(l.argb), boss = step.kind == RoadKind.boss;
    final road = [for (var i = 0; i < mainLands; i++) i].where((i) => !s.bossesDown.contains(i)).firstOrNull ?? mainLands - 1;
    final art = icon != null ? Icon(icon, color: Palette.amber, size: 30) : switch (step.kind) {
      RoadKind.boss || RoadKind.heroic || RoadKind.side => SizedBox.expand(child: TypePortrait(type: l.boss)),
      RoadKind.place => const Icon(Icons.place, color: Palette.amber, size: 30),
      RoadKind.dungeon => const Icon(Icons.stairs, color: Palette.amber, size: 30),
      RoadKind.train => const Icon(Icons.trending_up, color: Palette.amber, size: 30),
      RoadKind.wild => const Icon(Icons.forest, color: Palette.amber, size: 30),
      RoadKind.forge => const Icon(Icons.hardware, color: Palette.amber, size: 30),
      RoadKind.arena => const Icon(Icons.stadium, color: Palette.amber, size: 30),
      RoadKind.hall => const Icon(Icons.groups, color: Palette.amber, size: 30),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Color.lerp(Palette.stone3, col, .5)!, width: 1.4),
        gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color.lerp(const Color(0xFF2A1A12), col, .18)!, const Color(0xFF18120D)], stops: const [0, .6]),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: Palette.stone0, border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(3)),
            child: Padding(padding: const EdgeInsets.all(2), child: Center(child: art)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header ?? (boss ? 'THE ROAD · ${road + 1} / $mainLands' : 'ON THE WAY · ${road + 1} / $mainLands'), style: Txt.label(size: 11, color: Palette.parch2)),
                FitText(step.title, style: Txt.label(size: 14.5, color: Palette.cream, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                if (step.why != null)
                  FitText(step.why!, style: Txt.label(size: 12, color: const Color(0xFFE0A070)))
                else if (!boss)
                  FitText(step.sub, style: Txt.label(size: 12, color: Palette.amber))
                else
                  Row(
                    children: [
                      Flexible(child: FitText(l.name, style: Txt.label(size: 12, color: Palette.amber))),
                      const SizedBox(width: 8),
                      // The trail's stops, one pip each, then the lair.
                      for (var i = 0; i < winsForBoss; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: i < at ? col : Colors.transparent, border: Border.all(color: i < at ? col : Palette.stone3)),
                        ),
                      Icon(Icons.castle, size: 13, color: at >= winsForBoss ? col : Palette.stone3),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 76, child: StoneButton(title: step.why == null ? 'Go' : 'Map', compact: true, tone: step.why == null ? ButtonTone.blood : ButtonTone.stone, onPressed: onGo)),
        ],
      ),
    );
  }
}

/// The notice board by the inn door: the top contract, and the rest a tap away.
class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final board = controller.engine.board, top = board.first, p = placeById(top.place)!;
    const pin = Color(0xFFE0B070);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showBoard(context, controller),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Color.lerp(Palette.stone3, pin, .5)!, width: 1.4),
            gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF33261A), Color(0xFF18120D)], stops: [0, .6]),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: const Color(0xFFCDB98C), border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(3)),
                child: const Icon(Icons.push_pin, color: Color(0xFF8A2A1A), size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NOTICE BOARD · ${board.length} ${board.length == 1 ? 'CONTRACT' : 'CONTRACTS'}', style: Txt.label(size: 11, color: Palette.parch2)),
                    FitText(p.foe!.$4, style: Txt.label(size: 14.5, color: Palette.cream, weight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    FitText('${top.client} · ${continents[p.land].name}', style: Txt.label(size: 12, color: pin)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 76, child: StoneButton(title: 'Read', compact: true, onPressed: () => showBoard(context, controller))),
            ],
          ),
        ),
      ),
    );
  }
}

/// The notice board up close: each contract, who posted it and what they'll pay, and the way there.
Future<void> showBoard(BuildContext context, GameController c) => showDialog<void>(
  context: context,
  builder: (ctx) {
    final board = c.engine.board, bounty = contractBounty(c.state.knight.level);
    return Dialog(
      backgroundColor: Palette.stone1,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('The Notice Board', style: Txt.label(size: 20, color: Palette.cream)),
              const SizedBox(height: 2),
              Text('Pinned by the inn door. Put the trouble down, and whoever posted it pays a bounty on top of what you find.', style: Txt.onStone(size: 13.5)),
              for (final job in board) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final p = placeById(job.place)!, l = continents[p.land];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6D8B4),
                      border: Border.all(color: const Color(0xFF8A6A3A), width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WANTED: ${p.foe!.$4.toUpperCase()}', style: Txt.inkLabel(size: 14, color: const Color(0xFF8A2A1A))),
                        Text('${p.name} · ${l.name}', style: Txt.inkLabel(size: 12, color: const Color(0xFF5A4A32), weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('"${job.ask}"', style: Txt.body(size: 14.5, italic: true)),
                        Text('— ${job.client}', style: Txt.body(size: 13, color: const Color(0xFF5A4A32))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text('Bounty: $bounty gold', style: Txt.inkLabel(size: 14))),
                            StoneButton(
                              title: 'Take it',
                              compact: true,
                              tone: ButtonTone.blood,
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c, place: job.place)));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Close', style: Txt.label(size: 15, color: Palette.parch2)))),
            ],
          ),
        ),
      ),
    );
  },
);
