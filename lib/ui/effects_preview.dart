// The afflictions and conditions on show, side by side, for checking them by eye: a little fight
// for each, played over and over (the hero's blow, what it lays on the foe, the foe's answer).
// Open http://localhost:5070/?effects (add &only=burn,venom to pick some). Nothing here touches the
// save: each fight runs on its own game in memory.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/classes.dart' show HeroClass;
import '../game/controller.dart';
import '../game/engine.dart';
import '../game/loot.dart' show Stat, GearItem, GearSlot;
import '../game/models.dart';
import '../game/rules.dart';
import '../services/storage.dart';
import 'battle_stage.dart';
import 'theme.dart';

class _Memory extends GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState s, {int? at}) async {}
  @override
  Future<void> clear() async {}
}

/// One cell: what it shows, the weapon's wound-stats, and a condition laid on between turns.
typedef _Show = ({String id, String title, Map<Stat, int> wound, void Function(GameState s)? lay});

final _shows = <_Show>[
  (id: 'burn', title: 'Burning', wound: {Stat.burn: 30}, lay: null),
  (id: 'venom', title: 'Poisoned (builds up)', wound: {Stat.poison: 30}, lay: null),
  (id: 'bleed', title: 'Bleeding', wound: {Stat.bleed: 30}, lay: null),
  (id: 'frozen', title: 'Frozen', wound: {}, lay: (s) => s.foeFrozen = true),
  (id: 'asleep', title: 'Asleep', wound: {}, lay: (s) => s.foeAsleep = 2),
  (id: 'hexes', title: 'Slowed · Weakened · Exposed', wound: {}, lay: (s) => s
    ..foeSlowed = 3
    ..foeWeakened = 3
    ..foeExposed = 3),
  (id: 'fester', title: 'Fester: the fire erupts (venom: &only=festerv, bleed: festerb)', wound: {Stat.burn: 30}, lay: null),
  (id: 'festerv', title: 'Fester on venom', wound: {Stat.poison: 30}, lay: null),
  (id: 'festerb', title: 'Fester on a bleed', wound: {Stat.bleed: 30}, lay: null),
  (id: 'dual', title: 'Two blades: katana and wakizashi', wound: {}, lay: null),
  (id: 'you', title: 'You: poisoned · war cry', wound: {}, lay: (s) => s
    ..heroPoison = 3
    ..heroRoar = 3),
];

class EffectsPreview extends StatefulWidget {
  const EffectsPreview({super.key});

  @override
  State<EffectsPreview> createState() => _EffectsPreviewState();
}

class _EffectsPreviewState extends State<EffectsPreview> {
  late final List<(_Show, GameController)> _cells;
  Timer? _loop;
  final _rest = <GameController, int>{};

  @override
  void initState() {
    super.initState();
    final only = Uri.base.queryParameters['only']?.split(',');
    _cells = [
      for (final (i, sh) in _shows.indexed)
        if (only == null || only.contains(sh.id)) (sh, _setUp(sh, i)),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (_, c) in _cells) {
        _fight(c);
      }
      _loop = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    });
  }

  GameController _setUp(_Show sh, int i) {
    final c = GameController(storage: _Memory());
    c.engine = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: math.Random(7 + i), clock: () => DateTime(2026, 6, 1));
    final k = c.state.knight;
    while (k.level < 20) {
      c.engine.grantXp(xpToNext(k));
    }
    final w = k.loadout.weapon!;
    w.stats.removeWhere((st, _) => st == Stat.burn || st == Stat.poison || st == Stat.bleed || st == Stat.frost || st == Stat.smite);
    w.stats.addAll(sh.wound);
    w.enchant = null;
    if (sh.id == 'dual') {
      // A katana in the hand and a wakizashi in the other: the off-hand's second stroke.
      final j = w.toJson();
      k.loadout.weapon = GearItem.fromJson({...j, 'art': 'katana', 'name': 'Katana'});
      k.loadout.offhand = GearItem.fromJson({...j, 'id': '${j['id']}-off', 'art': 'wakizashi', 'name': 'Wakizashi', 'slot': GearSlot.offhand.name});
    }
    c.state.innRepaired = true;
    c.loaded = true;
    return c;
  }

  void _fight(GameController c) {
    final s = c.state;
    if (s.inBattle) return;
    c.explore();
    // (It can't fall, and its blows barely scratch: nothing here should end in a knockout.)
    s
      ..foeMax = 999999
      ..foeHp = 999999
      ..foeLevel = 1;
    c
      ..shownFoeHp = 999999
      ..shownFoeMax = 999999;
  }

  void _tick() {
    for (final (sh, c) in _cells) {
      final s = c.state;
      if (c.busy) continue;
      if (!s.inBattle || c.outcome != null) {
        c.leaveBattle();
        _fight(c);
        continue;
      }
      // Between turns: the condition takes hold (as a rite or a frost bolt would lay it), and a
      // pause to see it, then the next blow.
      final wait = _rest[c] ?? 0;
      if (sh.lay != null && wait == 0) {
        sh.lay!(s);
        _rest[c] = 1;
        continue;
      }
      if (wait > 0 && wait < 10) {
        _rest[c] = wait + 1;
        continue;
      }
      _rest[c] = 0;
      s.knight.hp = maxHp(s.knight);
      s.foeLevel = 1;
      // Fester's cells: a blow to lay the affliction, then Fester to burst it, by turns.
      if (sh.id.startsWith('fester') && c.engine.foeAffliction != null && !(_festered[c] ?? false)) {
        _festered[c] = true;
        s.mana = 5;
        s.knight.rites = ['fester'];
        c.castRite('fester');
        continue;
      }
      _festered[c] = false;
      c.act(BattleAction.attack);
    }
  }

  final _festered = <GameController, bool>{};

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: GridView.count(
        crossAxisCount: wide && _cells.length > 1 ? 2 : 1,
        childAspectRatio: 16 / 10,
        padding: const EdgeInsets.all(6),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (final (sh, c) in _cells)
            Stack(
              children: [
                Positioned.fill(child: ListenableBuilder(listenable: c, builder: (_, _x) => BattleStage(controller: c))),
                Positioned(left: 8, top: 6, child: Text(sh.title, style: Txt.label(size: 14, color: Palette.amber, weight: FontWeight.w800))),
              ],
            ),
        ],
      ),
    );
  }
}

