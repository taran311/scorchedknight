// The fight: a big stage, the foe's card, and your choices each turn: Attack with your blade, a
// Shield Bash (or Mighty Blow), Cast an Ember Rite, Shoot your crossbow, drink a Potion, Command
// your companion, or Flee. When it's over: the spoils, then fight on or head back to the map.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/ammo.dart';
import '../game/crafting.dart' show smithName, coresPerRune, Gem, GemInfo, Elemental, ElementalInfo, Metal, MetalInfo;
import '../game/engine.dart';
import '../game/loot.dart' show specialChanceAt, Stat, RarityInfo, GearSlotLabel;
import '../game/models.dart';
import '../game/rules.dart';
import '../game/spells.dart';
import '../game/wilds.dart';
import '../game/dungeons.dart' show dungeonRooms;
import 'battle_stage.dart';
import 'frames.dart';
import 'hud.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'material_icons.dart';
import 'encounter_window.dart';
import 'gear_glance.dart';
import 'item_icons.dart';
import 'stat_icons.dart';
import 'theme.dart';
import 'trail_data.dart';

/// What the battle screen should start with, once the stage is listening.
enum BattleStart { explore, boss, resume, raid, heroic, wild, dungeon }

/// What the screen hands back when it closes: back to the map, or (knocked out) to the Inn.
enum BattleExit { map, inn }

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.controller, required this.start});
  final GameController controller;
  final BattleStart start;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  GameController get c => widget.controller;
  bool _spoilsShown = false;

  /// A fight out in the wilds: its winnings go into your pack, and afterwards it's back to the path.
  late final bool _wild = widget.start == BattleStart.wild || c.state.wildFight;

  /// A fight in a dungeon room: afterwards it's back to the doors.
  late final bool _dungeon = widget.start == BattleStart.dungeon || c.state.dungeonFight;

  /// On the land's Heroic trail (picked up again from a saved fight too, or stepped onto from a
  /// patrol once the boss is down).
  late bool _heroic = widget.start == BattleStart.heroic || c.state.heroicFight;

  /// The crossbow's timing bar is up, waiting for you to loose the bolt.
  bool _aiming = false;

  /// On a phone (no hover): a tap uses a move straight away; holding one (or tapping one you can't
  /// use yet) shows its card above the moves until your next move. [_picked] is that move.
  int _picked = 1;
  bool _peek = false;

  /// The picked move's card, for the panel above the moves (set while the hotbar is built).
  _SlotInfo? _pickedInfo;
  bool _pickedReady = false;

  /// Where this fight's journal lines begin, so the panel shows only this fight.
  /// The last log entry from before this fight (the log is capped, so a position in it moves as
  /// old entries drop off the front: this fight's lines are the ones after this entry).
  JournalEntry? _journalFrom;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    c.addListener(_watch);
    // The stage subscribes during the first build; start once it is listening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _begin(widget.start);
      _focus.requestFocus();
    });
  }

  void _begin(BattleStart how) {
    _spoilsShown = false;
    _journalFrom = c.state.journal.lastOrNull;
    switch (how) {
      case BattleStart.explore:
        c.explore();
      case BattleStart.boss:
        if (!c.challengeBoss()) c.explore();
      case BattleStart.resume:
        c.resumeFight();
      case BattleStart.raid:
        if (!c.startRaid()) c.resumeFight();
      case BattleStart.heroic:
        c.exploreHeroic();
      case BattleStart.wild || BattleStart.dungeon:
        c.arriveWild();
    }
  }

  @override
  void dispose() {
    c.removeListener(_watch);
    _focus.dispose();
    // Leaving mid-turn: the fight stays saved and can be picked up from the Inn or the map.
    final game = c;
    Future<void>.microtask(game.leaveBattle);
    super.dispose();
  }

  /// After a win: the spoils (equip or sell), once.
  Future<void> _watch() async {
    if (c.outcome != Outcome.won || _spoilsShown || !mounted) return;
    _spoilsShown = true;
    await resolvePendingLoot(context, c);
    // Something odd on the road, now and then, once the dust settles.
    if (mounted && c.state.encounter != null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) await showEncounter(context, c);
      // Ambushed out of a strongbox: a new fight on this screen.
      if (mounted && c.state.inBattle) {
        _spoilsShown = false;
        _journalFrom = c.state.journal.lastOrNull;
      }
    }
    if (mounted) setState(() {});
  }

  void _act(BattleAction a) {
    if (c.busy || c.outcome != null || !c.state.inBattle) return;
    final why = c.whyNot(a);
    if (why != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(why), duration: const Duration(milliseconds: 1400)));
      return;
    }
    c.act(a);
  }

  /// A number key pressed while the last blow is still playing out: it fires as soon as it can, so
  /// a quick player never has a key press swallowed.
  VoidCallback? _queued;

  void _press(VoidCallback go) {
    if (c.busy && c.state.inBattle && c.outcome == null) {
      _queued = go;
    } else {
      go();
    }
  }

  static const _digits = [
    LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, //
    LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9,
  ];

  /// The rites on your hotbar that you know.
  List<Spell> get _rites => [for (final id in c.state.knight.rites) spellById(id)].whereType<Spell>().where((sp) => sp.level <= c.state.knight.level).toList();

  /// What each hotbar slot does, in order (the number keys follow it).
  List<VoidCallback> _hotbar() => [
    () => _act(BattleAction.attack),
    () => _act(BattleAction.skill),
    for (final sp in _rites) () => _castRite(sp.id),
    _shoot,
    if (_hasPotions) () => _act(BattleAction.potion),
    if (_hasCompanion) () => _act(BattleAction.pet),
    () => _act(BattleAction.flee),
  ];

  /// Potion and companion tiles only show when you have one, to keep the hotbar clean. (Rites
  /// stay, even short of mana, so you can plan ahead.) Once the potion tile is up it stays for the
  /// rest of the fight, greyed out at ×0: the moves sliding along under your thumb mid-fight felt
  /// wrong, and would send a number key to the wrong move. (A new fight starts afresh.)
  bool get _hasPotions => _potionShown = (_potionShown && c.state.turn > 0) || c.state.knight.potions > 0;
  bool _potionShown = false;
  bool get _hasCompanion => petStage(c.state.knight) != null || dragonStage(c.state.knight) != null;

  /// Shoot: up comes the timing bar. Every bolt is aimed by hand (no auto-aim: your timing is the skill).
  void _shoot() {
    if (_aiming) return;
    if (c.busy || c.outcome != null || !c.state.inBattle || c.whyNot(BattleAction.shoot) != null) return;
    setState(() => _aiming = true);
  }

  /// The bolt flies from wherever the dial was.
  void _loose(double pos) {
    if (!_aiming) return;
    setState(() => _aiming = false);
    if (c.busy || c.outcome != null || !c.state.inBattle) return;
    c.act(BattleAction.shoot, aim: aimAt(pos, bullseyeFor(c.state.knight)));
  }

  void _castRite(String id) {
    if (c.busy || c.outcome != null || !c.state.inBattle) return;
    final why = c.whyNotRite(id);
    if (why != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(why), duration: const Duration(milliseconds: 1400)));
      return;
    }
    c.castRite(id);
  }

  /// On to the next stop on the trail (or into the lair, once it's open).
  void _fightOn() {
    c.leaveBattle();
    if (_heroic) return _begin(BattleStart.heroic);
    _begin(trailStep(c.state, c.state.continent) == TrailStep.lair ? BattleStart.boss : BattleStart.explore);
  }

  void _close(BattleExit to) => Navigator.of(context).pop(to);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.state, foe = c.shownFoeType, land = continents[realmAt(c.shownRare?.base ?? c.shownFoe)];
        // Mid-turn, the log waits for the stage: it stops where the turn began.
        final held = c.logHeldAt == null ? -1 : s.journal.indexOf(c.logHeldAt!);
        final upTo = c.busy && c.logHeldAt != null && held >= 0 ? held + 1 : s.journal.length;
        final from = _journalFrom == null ? 0 : s.journal.indexOf(_journalFrom!) + 1;
        final lines = upTo > from ? s.journal.sublist(from, upTo) : const <JournalEntry>[];
        final over = c.outcome != null;
        if (!c.busy && _queued != null) {
          final go = _queued!;
          _queued = null;
          if (!over) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? go() : null);
        }
        return MusicZone(track: foe.boss ? 'boss' : 'battle', child: PopScope(
          canPop: over || !s.inBattle,
          child: CallbackShortcuts(
            bindings: {
              // 1 to 9 along the hotbar, rites and all.
              for (final (i, go) in _hotbar().indexed)
                if (i < _digits.length) SingleActivator(_digits[i]): () => _press(go),
            },
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              child: Scaffold(
                body: Column(
                  children: [
                    SizedBox(height: MediaQuery.paddingOf(context).top),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final wide = box.maxWidth >= 720, phone = isPhone(context);
                          // One game window: a 16:9 stage, and under it the command deck (what just
                          // happened, then your moves). It fits the window but stops growing at a
                          // comfortable size, so a big screen gets breathing room, not a giant fight.
                          const deckH = 190.0, pad = 28.0, maxW = 1040.0;
                          final availH = (box.maxHeight - pad) * .94;
                          var w = math.min(box.maxWidth - 24, maxW);
                          // A phone: a wider, shorter stage (it shows more of the field, not less of the
                          // figures), so the moves fit under it without scrolling.
                          // On a tall phone there's room for the whole 700×540 strip, so it gets it.
                          var aspect = phone ? (box.maxHeight > 760 ? 700 / 540 : 1.55) : 700 / 540;
                          if (wide) {
                            var stageH = w / (16 / 9);
                            if (stageH + deckH > availH) {
                              // A short window: narrow the stage so the deck still fits below it.
                              w = math.max(math.min(box.maxWidth - 24, 640.0), (availH - deckH) * 16 / 9);
                              stageH = w / (16 / 9);
                            }
                            aspect = w / stageH;
                          }
                          // A tall phone: the fight fills the screen, the moves sit at the bottom where your
                          // thumb is, and the space between becomes the battle log.
                          final fill = phone && box.maxHeight >= 640;
                          // On a tall phone: the two cards (with faces) at the top, square moves under
                          // your thumb at the bottom, one tappable log line above them, and the fight
                          // gets everything in between.
                          final frame = Stone(
                            padding: const EdgeInsets.all(3),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Column(
                                mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // On a phone the two cards sit above the fight, side by side, so they
                                  // don't cover it.
                                  if (phone)
                                    Container(
                                      color: const Color(0xFF15110C),
                                      padding: const EdgeInsets.all(5),
                                      // You and the foe side by side, slim, so the fight gets the screen.
                                      // (The two cards stand the same height, side by side.)
                                      child: IntrinsicHeight(child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Tap your card: everything you're wearing, and what it adds up to.
                                          Expanded(flex: 5, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => showGearGlance(context, c), child: HeroStrip(controller: c))),
                                          const SizedBox(width: 5),
                                          // Tap theirs: everything about it, in full.
                                          Expanded(flex: 6, child: _FoeCard(controller: c, foe: foe, fill: true)),
                                        ],
                                      )),
                                    ),
                                  _stageIn(
                                    fill,
                                    Stack(
                                    children: [
                                      BattleStage(controller: c, aspectRatio: aspect, fill: fill),
                                      if (phone)
                                        Positioned(left: 6, top: 6, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: StatusBadges(state: s))),
                                      // You top-left, the foe top-right, like facing cards.
                                      if (!phone)
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: () => showGearGlance(context, c), child: Tooltip(message: 'Your gear', child: HeroCard(controller: c, mana: true)))),
                                            const SizedBox(height: 6),
                                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: StatusBadges(state: s)),
                                          ],
                                        ),
                                      ),
                                      if (!phone) Positioned(right: 8, top: 8, child: _FoeCard(controller: c, foe: foe)),
                                      Positioned(
                                        left: 10,
                                        bottom: 6,
                                        child: _dungeon && c.dungeonNow != null
                                            ? Text('${c.dungeonNow!.name} · room ${math.min(s.dungeonRoom + 1, dungeonRooms + 1)}', style: Txt.label(size: 13, color: Color(c.dungeonNow!.argb)))
                                            : _wild && s.wild != null
                                            ? Text('${wildAreas[s.wild!].name} · step ${s.wildDepth}', style: Txt.label(size: 13, color: Color(wildAreas[s.wild!].argb)))
                                            : Text(land.name, style: Txt.label(size: 13, color: Color(land.argb))),
                                      ),
                                    ],
                                  ),
                                  ),
                                  _deckIn(
                                    fill,
                                    _CommandDeck(
                                    fill: fill,
                                    controller: c,
                                    lines: lines,
                                    moves: over
                                        ? null
                                        : _aiming
                                        ? [Expanded(child: _AimBar(speed: c.state.settings.fastFights ? 1.6 : 1, zone: bullseyeFor(c.state.knight), onLoose: _loose, onCancel: () => setState(() => _aiming = false)))]
                                        : _actionRows().first,
                                    result: over ? _resultButtons() : null,
                                    detail: !over && !_aiming && _peek && _pickedInfo != null ? _PickedCard(info: _pickedInfo!, ready: _pickedReady) : null,
                                  ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (fill) {
                            // (Clear of the phone's own navigation bar at the bottom.)
                            return Padding(padding: EdgeInsets.fromLTRB(4, 6, 4, 10 + MediaQuery.paddingOf(context).bottom), child: frame);
                          }
                          return Center(
                            child: SingleChildScrollView(
                              // A phone gives the fight every pixel of width it can.
                              padding: phone ? const EdgeInsets.fromLTRB(4, 6, 4, 10) : const EdgeInsets.fromLTRB(12, 12, 12, 16),
                              child: RepaintBoundary(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: w + 6), child: frame)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
      },
    );
  }

  /// The command deck stretched to fill what's left of a tall phone screen, or as it is.
  Widget _deckIn(bool fill, Widget deck) => deck;

  /// The stage keeps its shape on every screen (the log takes a tall phone's spare height).
  // (On a tall phone the fight takes whatever the cards above and the square moves below leave.)
  Widget _stageIn(bool fill, Widget stage) => fill ? Expanded(child: stage) : stage;

  /// Your moves as a hotbar of skill slots: a big symbol, a short name, the number key in the
  /// corner and one key figure (damage, mana, potions left). Cooldowns darken the slot and count
  /// down; hovering one opens a card with the detail: what it does, its numbers against this foe,
  /// and why it can't be used right now if it can't.
  List<List<Widget>> _actionRows() {
    _pickedInfo = null;
    final s = c.state, k = s.knight, foe = c.shownFoeType, ready = !c.busy && s.inBattle;
    final pet = petStage(k), ds = dragonStage(k);
    final aloft = foe.aloft, kind = foe.kind;
    // How each way of fighting lands on this foe: aloft, and the combat triangle.
    final bladeEdge = (aloft ? aloftMelee : 1.0) * triangle(kind, AttackStyle.blade);
    final boltEdge = (aloft ? aloftShot : 1.0) * triangle(kind, AttackStyle.bolt);
    final riteEdge = triangle(kind, AttackStyle.rite);
    String pct(double e) => e > 1 ? '+${((e - 1) * 100).round()}%' : '−${((1 - e) * 100).round()}%';
    const good = Color(0xFF9FE07A), bad = Color(0xFFFF8A70), plain = Palette.parch, soft = Palette.parch2;
    // Hover cards are a few one-liners, an emoji each: the numbers that matter, nothing more.
    (String, String, Color) edgeLine(double e, String what) => e > 1 ? ('🎯', 'Weak to $what ${pct(e)}', good) : ('🛡️', 'Resists $what ${pct(e)}', bad);
    String turns(int n) => '$n turn${n == 1 ? '' : 's'}';
    // Every damaging move's corner shows the same thing: about how much it'll hit for, green when
    // the foe's weak to it, red when it shrugs it off.
    Color edgeColour(double e) => e > 1 ? good : (e < 1 ? bad : Palette.amber);
    final swing = fullSwing(k);
    final bash = skillName(k) == 'Shield Bash';
    var key = 0;
    Widget slot(BattleAction a, Widget icon, String name, _SlotInfo info, {String? badge, Color badgeColour = Palette.amber, Widget? badgeArt, String? figure, int wait = 0, bool glow = false, Color tint = const Color(0xFF3B3327), String? rite}) {
      final why = rite != null ? c.whyNotRite(rite) : c.whyNot(a);
      key++;
      final mine = key, phone = isPhone(context);
      final go = rite != null ? () => _castRite(rite) : (a == BattleAction.shoot ? _shoot : () => _act(a));
      // Mid-blow, a tap is remembered and fires the moment the blow is done.
      final use = ready && why == null ? go : (c.busy && s.inBattle && c.outcome == null && why == null ? () => _press(go) : null);
      if (phone && mine == _picked) {
        _pickedInfo = info.blocked(ready ? why : null);
        _pickedReady = use != null;
      }
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _SkillSlot(
            hotkey: key,
            icon: icon,
            name: name,
            badge: badge,
            badgeColour: badgeColour,
            badgeArt: badgeArt,
            figure: figure,
            info: info.blocked(ready ? why : null),
            wait: wait,
            glow: glow && why == null && ready,
            tint: tint,
            onTap: phone && use != null
                ? () {
                    setState(() {
                      _picked = mine;
                      _peek = false;
                    });
                    use();
                  }
                : use,
            picked: phone && _peek && mine == _picked,
            onPick: phone
                ? () => setState(() {
                    _picked = mine;
                    _peek = true;
                  })
                : null,
          ),
        ),
      );
    }

    /// A rite's key figure on its slot, and its lines on the card.
    (String, List<(String, String, Color)>) riteDetail(Spell sp) {
      final arcana = arcanaBoost(k);
      final hits = sp.mult > 1 || sp.kind == SpellKind.heal || sp.element != null;
      final mult = sp.mult * (hits ? riteEdge : 1);
      final figure = switch (sp.kind) {
        SpellKind.slow => 'Slow ${sp.hex}t',
        SpellKind.weaken => '−40% ${sp.hex}t',
        SpellKind.expose => '+25% ${sp.hex}t',
        SpellKind.sleep => 'Sleep ${sp.hex}',
        SpellKind.ward => 'Ward ${sp.wards}',
        SpellKind.reflect => 'Mirror ${sp.wards}',
        SpellKind.summon => '+${sp.summons} ${sp.summons == 1 ? 'ally' : 'allies'}',
        SpellKind.heal => 'Heal ${(sp.mend * 100).round()}%',
        _ => '~${(swing * mult * arcana).round()}',
      };
      final lines = <(String, String, Color)>[
        if (hits) ('⚔️', '~${(swing * mult * arcana).round()} damage', plain),
        ...switch (sp.kind) {
          SpellKind.nova => [('❄️', 'Freezes it: no counter', good)],
          SpellKind.dragon => [('🔥', 'Plus fire damage', plain)],
          SpellKind.chain => [('⚡', 'Leaps three times', plain)],
          SpellKind.drain => [('🩸', 'Heals you ${(sp.drain * 100).round()}% of it', good)],
          SpellKind.heal => [('❤️', 'Heals you ${(sp.mend * 100).round()}% HP', good)],
          SpellKind.slow => [('🐌', 'Half its hits miss · ${turns(sp.hex)}', plain)],
          SpellKind.weaken => [('📉', 'It hits 40% softer · ${turns(sp.hex)}', plain)],
          SpellKind.expose => [('💥', 'You hit 25% harder · ${turns(sp.hex)}', plain)],
          SpellKind.sleep => [('💤', 'Sleeps through ${sp.hex} blows', plain), ('👑', 'Bosses wake after 1', soft)],
          SpellKind.ward => [('✨', 'Blocks the next ${sp.wards} hits', plain)],
          SpellKind.reflect => [('🪞', 'Next ${sp.wards} hits: half to you, all back', plain)],
          SpellKind.summon => [('💀', '${sp.summons} skeleton${sp.summons == 1 ? '' : 's'} · ${turns(sp.turns)}', plain), ('⚔️', '~${summonHit(k.level)} damage each a turn', plain)],
          _ => const <(String, String, Color)>[],
        },
        if (hits && riteEdge != 1) edgeLine(riteEdge, 'rites'),
        ('🔷', '${spellCost(k, sp)} mana · you have ${s.mana}', soft),
      ];
      return (figure, lines);
    }

    final petName = ds != null && pet == null ? 'Firebreath' : (pet?.$2.name ?? 'Companion');
    final flee = fleeChance(k, foe, s.fleeTries);
    final special = k.loadout.weapon?.specialMove;
    // The picked move went away (the last potion drunk): back to Attack.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && isPhone(context) && _pickedInfo == null && _picked != 1 && !c.busy) {
        setState(() {
          _picked = 1;
          _peek = false;
        });
      }
    });
    return [
      [
        slot(
          BattleAction.attack,
          const ItemIcon(Item.swords, size: 40),
          'Attack',
          _SlotInfo('Attack', const Color(0xFFFF9A7A), [
            ('⚔️', '~${(swing * bladeEdge * mightBoost(k)).round()} damage', plain),
            if (aloft) ('🦅', 'Out of reach ${pct(aloftMelee)}', bad),
            if (triangle(kind, AttackStyle.blade) != 1) edgeLine(triangle(kind, AttackStyle.blade), 'blades'),
            if (special != null) ('⚡', '${(specialChanceAt(s.specialCharge) * 100).round()}% chance of ${special.name}', soft),
          ]),
          badge: '~${(swing * bladeEdge * mightBoost(k)).round()}',
          badgeColour: edgeColour(bladeEdge),
          glow: bladeEdge > 1,
          tint: const Color(0xFF5A1A14),
        ),
        slot(
          BattleAction.skill,
          bash ? const ItemIcon(Item.shield, size: 38) : const Icon(Icons.gavel, size: 38, color: Color(0xFFFFD98A)),
          bash ? 'Bash' : 'Mighty Blow',
          _SlotInfo(bash ? 'Shield Bash' : 'Mighty Blow', const Color(0xFFFFD98A), [
            ('⚔️', '~${(swing * bashMult * bladeEdge * mightBoost(k)).round()} damage', plain),
            ('😵', 'Stuns it (bosses 50%)', good),
            if (bladeEdge != 1) edgeLine(bladeEdge, 'blades'),
            ('⏳', s.skillWait > 0 ? 'Ready in ${turns(s.skillWait)}' : 'Cooldown ${turns(skillCooldown)}', soft),
          ]),
          badge: '~${(swing * bashMult * bladeEdge * mightBoost(k)).round()}',
          badgeColour: edgeColour(bladeEdge),
          wait: s.skillWait,
          glow: s.skillWait == 0,
          tint: const Color(0xFF5A4318),
        ),
        for (final sp in _rites)
          (() {
            final (figure, lines) = riteDetail(sp);
            return slot(
              BattleAction.cast,
              Icon(Icons.local_fire_department, size: 40, color: Color(sp.argb)),
              sp.name,
              _SlotInfo(sp.name, Color(sp.argb), lines),
              badgeArt: _ManaCost(spellCost(k, sp)),
              figure: figure,
              glow: riteEdge > 1,
              tint: const Color(0xFF1E2A44),
              rite: sp.id,
            );
          })(),
        slot(
          BattleAction.shoot,
          const Icon(Icons.gps_fixed, size: 38, color: Color(0xFFCDE6B0)),
          'Shoot',
          _SlotInfo('Shoot', const Color(0xFFDDD0B1), [
            ('🏹', '~${(swing * crossbowShare(k) * boltEdge * aimBoost(k)).round()} damage', plain),
            ('🎯', 'Bullseye ×$bullseye', soft),
            if (aloft) ('🦅', 'Easy shot in the air ${pct(aloftShot)}', good),
            if (triangle(kind, AttackStyle.bolt) != 1) edgeLine(triangle(kind, AttackStyle.bolt), 'bolts'),
          ]),
          badge: '~${(swing * crossbowShare(k) * boltEdge * aimBoost(k)).round()}',
          badgeColour: edgeColour(boltEdge),
          glow: boltEdge > 1,
          // The crossbow's own colour: hunter green (blades red, rites blue).
          tint: const Color(0xFF263A20),
        ),
        if (_hasPotions)
        slot(
          BattleAction.potion,
          const ItemIcon(Item.potion, size: 38),
          'Potion',
          _SlotInfo('Health potion', const Color(0xFFFF8A8A), [
            ('❤️', 'Heals ${potionHeal(k)} HP', good),
            ('⏱️', 'Uses your turn', soft),
            ('🧪', '${k.potions} in your belt', soft),
            ('✋', '${math.max(0, potionsPerFight - s.potionsDrunk)} of $potionsPerFight left this fight', s.potionsDrunk >= potionsPerFight ? bad : soft),
          ]),
          badge: '×${k.potions}',
          // Lights up when you're in trouble, so it's the first thing your eye finds.
          glow: (k.hp < maxHp(k) * .35 || s.heroPoison > 1) && s.potionsDrunk < potionsPerFight,
          // A healing teal, so the red flask stands out, and it's never mistaken for Attack's red.
          tint: const Color(0xFF173A38),
        ),
        if (_hasCompanion)
        slot(
          BattleAction.pet,
          Icon(ds != null && pet == null ? Icons.whatshot : Icons.pets, size: 38, color: const Color(0xFFE8B070)),
          petName,
          _SlotInfo(petName, const Color(0xFFE8B070), [
            if (pet == null && ds == null) ('🐾', 'No companion yet', soft) else ('🐾', ds != null && pet == null ? 'Your dragon breathes fire' : 'Your companion strikes', plain),
            if (s.petWait > 0) ('⏳', 'Ready in ${turns(s.petWait)}', soft),
          ]),
          wait: s.petWait,
          // Your companion's earthy amber, like its paw.
          tint: const Color(0xFF4A3218),
        ),
        slot(
          BattleAction.flee,
          const Icon(Icons.directions_run, size: 38, color: Color(0xFFBFB09A)),
          'Flee',
          _SlotInfo('Flee', const Color(0xFFBFB09A), [
            ('🏃', '${(flee * 100).round()}% to escape', plain),
            ('📈', '+${(fleeStep * 100).round()}% each failed try', soft),
            if (s.dungeonFight) ('🚪', 'Back out and bar the door', soft) else if (s.wild != null) ('🎒', 'Drops ${(fightFleeLoss * 100).round()}% of your pack', bad) else ('🏠', 'Back to the inn', soft),
          ]),
          badge: '${(flee * 100).round()}%',
          // A cool, quiet slate: the way out, not something to draw the eye.
          tint: const Color(0xFF2C3238),
        ),
      ],
    ];
  }

  List<Widget> _resultButtons() {
    final o = c.outcome!;
    final waiting = c.nextLoot != null;
    if (_dungeon) {
      // In a dungeon: one room, then back to the doors (or, knocked out, home).
      return [
        if (waiting && o == Outcome.won)
          Expanded(child: StoneButton(title: 'Choose your spoils', tone: ButtonTone.blood, onPressed: () => resolvePendingLoot(context, c).then((_) => mounted ? setState(() {}) : null)))
        else
          Expanded(
            child: o == Outcome.knockedOut
                ? StoneButton(title: 'Wake up at the Soot & Kettle', tone: ButtonTone.blood, onPressed: () => _close(BattleExit.inn))
                : StoneButton(title: c.dungeonCleared ? 'Claim the hoard' : 'Back to the doors', tone: ButtonTone.blood, onPressed: () => _close(BattleExit.map)),
          ),
      ];
    }
    if (_wild) {
      // Out in the wilds: one fight, then back to the path (or, knocked out, home).
      return [
        Expanded(
          child: o == Outcome.knockedOut
              ? StoneButton(title: 'Wake up at the Soot & Kettle', tone: ButtonTone.blood, onPressed: () => _close(BattleExit.inn))
              : StoneButton(title: 'Back to the path', caption: 'Step ${c.state.wildDepth} of ${wildAreas[c.state.wild ?? 0].name}', tone: ButtonTone.blood, onPressed: () => _close(BattleExit.map)),
        ),
      ];
    }
    if (widget.start == BattleStart.raid) {
      // A raid on the town is one fight, then home.
      return [
        if (waiting)
          Expanded(
            child: StoneButton(title: 'Choose your spoils', tone: ButtonTone.blood, onPressed: () => resolvePendingLoot(context, c).then((_) => mounted ? setState(() {}) : null)),
          )
        else
          Expanded(child: StoneButton(title: o == Outcome.knockedOut ? 'Wake up at the Soot & Kettle' : 'Back to town', tone: ButtonTone.blood, onPressed: () => _close(o == Outcome.knockedOut ? BattleExit.inn : BattleExit.map))),
      ];
    }
    // On a Heroic trail, onward means the next elite (or the risen boss).
    final land = c.state.continent, risen = (c.state.heroicWins[land] ?? 0) >= heroicStops;
    final onward = _heroic ? (risen ? 'Face ${continents[land].boss.name}, Risen' : 'Onward · Heroic') : trailAction(c.state, land);
    switch (o) {
      // The lair has fallen (or you're patrolling a land whose lair has): onward is the Heroic
      // trail's elites, or home to rest up first.
      case Outcome.won when !_heroic && !waiting && trailStep(c.state, land) == TrailStep.patrol && c.heroicOpen(land):
        return [
          Expanded(
            flex: 3,
            child: StoneButton(
              title: risen ? 'Face ${continents[land].boss.name}, Risen' : 'Heroic trail',
              caption: risen ? null : 'Elite foes · stop ${(c.state.heroicWins[land] ?? 0) + 1} of $heroicStops',
              tone: ButtonTone.blood,
              onPressed: () {
                _heroic = true;
                _fightOn();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: StoneButton(title: 'Rest in town', onPressed: () => _close(BattleExit.inn))),
        ];
      case Outcome.won:
        return [
          Expanded(
            flex: 3,
            child: StoneButton(
              title: waiting ? 'Choose your spoils' : onward,
              tone: ButtonTone.blood,
              onPressed: waiting ? () => resolvePendingLoot(context, c).then((_) => mounted ? setState(() {}) : null) : _fightOn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: StoneButton(title: 'Back to the trail', onPressed: waiting ? null : () => _close(BattleExit.map))),
        ];
      case Outcome.fled:
        // You ran: all the way home to the village.
        return [Expanded(child: StoneButton(title: 'Back to the Soot & Kettle', caption: 'You ran all the way home', tone: ButtonTone.blood, onPressed: () => _close(BattleExit.inn)))];
      case Outcome.knockedOut:
        return [Expanded(child: StoneButton(title: 'Wake up at the Soot & Kettle', tone: ButtonTone.blood, onPressed: () => _close(BattleExit.inn)))];
    }
  }
}

/// The foe's name, level and HP, in the corner of the stage.
class _FoeCard extends StatelessWidget {
  const _FoeCard({required this.controller, required this.foe, this.fill = false});
  final GameController controller;
  final FoeType foe;
  final bool fill;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: controller.hpShown, builder: (context, _) => _card(context));

  Widget _card(BuildContext context) {
    final c = controller, colour = foe.aura != null ? Color(foe.aura!.argb) : (foe.boss ? Palette.amber : Palette.cream);
    final realm = realmAt(c.state.rare?.base ?? c.state.foe);
    final aura = foe.aura;
    final weak = weakTo(foe), shrug = shrugsOff(foe);
    final hazard = c.state.inBattle && c.state.hazardIn(realm);
    final card = FoeCard(
      fill: fill,
      face: fill ? TypePortrait(type: foe, tier: foeMenace(c.state)) : null,
      // Only a boss gets its land's frame.
      frame: foe.boss || foe.named ? frameForLand(c.state.continent) : null,
      name: foe.name,
      colour: colour,
      hp: c.shownFoeHp,
      maxHp: c.shownFoeMax,
      level: c.state.foeLevel,
      tags: [
        // Winding up a heavy blow: first, where you can't miss it.
        if (c.state.inBattle && c.state.foeWindup && !c.busy)
          const FoeBadge(label: 'HEAVY ×$heavyBlow', colour: Color(0xFFFF5A4A), solid: true, tip: 'Winding up a heavy blow. Bash, freeze or hex it to stop it.'),
        if (aura != null) FoeBadge(label: foe.pack ? 'PACK' : (foe.named ? 'RARE BOSS' : 'RARE'), colour: colour, solid: true, tip: aura.label),
        if (foe.boss && aura == null) const FoeBadge(label: 'BOSS', colour: Palette.amber, solid: true),
        // A foe well above you: say so (the stage shows it too, bigger and darker).
        if (foeMenace(c.state) case final m when m > 0)
          FoeBadge(
            icons: [for (var i = 0; i < m; i++) const Icon(Icons.dangerous, size: 14, color: Color(0xFFFF6A5A))],
            text: m > 1 ? 'Deadly' : 'Tough',
            wordy: true,
            colour: const Color(0xFFFF6A5A),
            tip: '${c.state.foeLevel - c.state.knight.level} levels above you: it hits harder and takes longer to fell',
          ),
        if (foe.kind != FoeKind.none) FoeBadge(
            icons: [Icon(kindIcon(foe.kind), size: 14, color: kindColour(foe.kind))],
            text: foe.kind.label,
            wordy: true,
            colour: kindColour(foe.kind),
            tip: '${foe.kind.label}: weak to ${styleName(foe.kind.weakTo!)}, shrugs off ${styleName(foe.kind.resists!)}',
          ),
        if (aura != null && !foe.pack && !foe.named) _perkBadge(aura),
        if (poisons(foe)) const FoeBadge(icons: [Icon(Icons.science, size: 14, color: Color(0xFF8FD36A))], text: 'Poisons', wordy: true, colour: Color(0xFF8FD36A), tip: 'Its blows can poison you. A health potion cures it.'),
        if (drinksBlood(foe)) const FoeBadge(icons: [Icon(Icons.water_drop, size: 14, color: Color(0xFFE0505A))], text: 'Drinks blood', wordy: true, colour: Color(0xFFE0505A), tip: 'Heals half of every blow that lands on you. Weaken it, slow it, or kill it fast.'),
      ],
      badges: [
        if (weak.isNotEmpty) FoeBadge(label: 'Weak', icons: [for (final w in weak) _wayIcon(w)], colour: const Color(0xFF9BE27A), tip: 'Weak to ${weak.join(', ')}'),
        if (shrug.isNotEmpty) FoeBadge(label: 'Resists', icons: [for (final w in shrug) Opacity(opacity: .75, child: _wayIcon(w))], colour: const Color(0xFFE07A6A), tip: 'Shrugs off ${shrug.join(', ')}'),
        // What you've put on it, with the turns left.
        if (c.state.inBattle && c.state.foeSlowed > 0) FoeBadge(label: 'Slowed ${c.state.foeSlowed}', colour: const Color(0xFF6ABF9A), tip: 'Half its blows miss · ${c.state.foeSlowed} turns left'),
        if (c.state.inBattle && c.state.foeWeakened > 0) FoeBadge(label: 'Weakened ${c.state.foeWeakened}', colour: const Color(0xFFB8A0D8), tip: 'Its blows land 40% softer · ${c.state.foeWeakened} turns left'),
        if (c.state.inBattle && c.state.foeExposed > 0) FoeBadge(label: 'Exposed ${c.state.foeExposed}', colour: const Color(0xFFE0A050), tip: 'Your hits deal 25% more · ${c.state.foeExposed} turns left'),
        if (c.state.inBattle && c.state.foeAsleep > 0) const FoeBadge(label: 'Asleep', colour: Color(0xFFB8A0E8), tip: 'It sleeps through its next blow'),
        if (c.state.inBattle && c.state.foeFrozen) const FoeBadge(label: 'Frozen', colour: Color(0xFF9ADFFF), tip: 'Frozen solid: it misses its next blow'),
        if (c.state.inBattle && c.state.foeBurnTurns > 0) FoeBadge(label: 'Burning ${c.state.foeBurnTurns}', colour: const Color(0xFFFF8A3A), tip: '${c.state.foeBurn} fire a turn · ${c.state.foeBurnTurns} turns left'),
        if (c.state.inBattle && (c.state.foeVenom > 0 || c.state.foeToxin > 0))
          FoeBadge(label: c.state.foeToxin > 0 ? 'Venom ${c.state.foeToxin}' : 'Venom ×${c.state.foeVenom}', colour: const Color(0xFF8FD36A), tip: 'Eats at it every turn for the rest of the fight, and grows with every venomous hit'),
        if (c.state.inBattle && c.state.foeBleedTurns > 0) FoeBadge(label: 'Bleeding ${c.state.foeBleedTurns}', colour: const Color(0xFFE04A4A), tip: '${c.state.foeBleed} a turn · ${c.state.foeBleedTurns} turns left'),
        if (c.state.inBattle && !c.busy) FoeBadge(icons: const [Icon(Icons.flash_on, size: 15, color: Color(0xFFFF8A70))], text: '~${nextBlow(c.state)}', colour: const Color(0xFFE0A090), tip: 'Hits for about ${nextBlow(c.state)}'),
        if (foe.mimic && c.state.lastStyle != null)
          FoeBadge(
            label: 'Braced',
            icons: [Opacity(opacity: .75, child: _wayIcon(styleName(AttackStyle.values.byName(c.state.lastStyle!))))],
            colour: const Color(0xFFC8C4CC),
            tip: 'The Faceless learn: it\'s braced for ${styleName(AttackStyle.values.byName(c.state.lastStyle!))} now (${((1 - mimicBrace) * 100).round()}% less). Switch it up!',
          ),
        if (hazard) FoeBadge(icons: const [Icon(Icons.warning_amber, size: 15, color: Color(0xFFE0A070))], text: '−${(hazardShare * 100).round()}%/turn', colour: const Color(0xFFE0A070), tip: '${continents[realm].hazard}: you lose ${(hazardShare * 100).round()}% HP a turn'),
      ],
    );
    if (!fill) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFoeGlance(context, name: foe.name, colour: colour, level: c.state.foeLevel, badges: [...card.tags, ...card.badges].whereType<FoeBadge>().toList()),
      child: card,
    );
  }

  /// A way of hurting things, as its icon on the card.
  static Widget _wayIcon(String way) => Tooltip(
    message: way,
    child: switch (way) {
      'blades' => const ItemIcon(Item.swords, size: 15),
      'rites' => const Icon(Icons.local_fire_department, size: 15, color: Color(0xFF9ADFFF)),
      'the crossbow' || 'bolts' => const Icon(Icons.gps_fixed, size: 15, color: Color(0xFFDDD0B1)),
      'hammers and maces' => const Icon(Icons.gavel, size: 15, color: Color(0xFFC9B99A)),
      'fire' => const Icon(Icons.whatshot, size: 15, color: Color(0xFFFF8A3A)),
      'holy fire' => const StatGlyph(Stat.smite, size: 15),
      'poison' => const Icon(Icons.science, size: 15, color: Color(0xFF8BE05A)),
      'frost' => const Icon(Icons.ac_unit, size: 15, color: Color(0xFF9ADFFF)),
      'critical hits' => const Icon(Icons.flare, size: 15, color: Color(0xFFFFE07A)),
      _ => const Icon(Icons.circle, size: 10, color: Palette.parch2),
    },
  );

  /// What a rare foe's aura does for its loot, in a word or two.
  static Widget _perkBadge(Aura a) {
    final (IconData icon, String text) = switch (a) {
      Aura.gilded => (Icons.paid, 'More gold'),
      Aura.cursed => (Icons.diamond, 'Legendary odds'),
      Aura.blazing => (Icons.local_fire_department, 'Fire loot'),
      Aura.venom => (Icons.science, 'Poison loot'),
      Aura.frost => (Icons.ac_unit, 'Frost loot'),
      Aura.ancient => (Icons.workspace_premium, 'Best loot'),
    };
    final col = Color(a.argb);
    return FoeBadge(icons: [Icon(icon, size: 14, color: col)], text: text, wordy: true, colour: col, tip: a.perk);
  }
}

/// One slot on the hotbar.
class _SkillSlot extends StatefulWidget {
  const _SkillSlot({required this.hotkey, required this.icon, required this.name, required this.info, this.badge, this.badgeColour = Palette.amber, this.badgeArt, this.figure, this.wait = 0, this.glow = false, this.tint = const Color(0xFF3B3327), this.onTap, this.picked = false, this.onPick});
  final int hotkey;

  /// On a phone: this move is picked (its card shows above the moves; another tap uses it), and
  /// how to pick it.
  final bool picked;
  final VoidCallback? onPick;
  final Widget icon;
  final String name;
  final String? badge;
  final Color badgeColour;
  final Widget? badgeArt;

  /// The move's key effect, under its symbol (a rite's "×2.3" or "Slow 4t").
  final String? figure;

  /// The card that opens on hover.
  final _SlotInfo info;
  final int wait;
  final bool glow;
  final Color tint;
  final VoidCallback? onTap;

  @override
  State<_SkillSlot> createState() => _SkillSlotState();
}

class _SkillSlotState extends State<_SkillSlot> {
  bool _hover = false, _down = false;
  final _card = OverlayPortalController();
  final _link = LayerLink();

  /// Which edge of the tile the card lines up with, so it never runs off the screen.
  Alignment _side = Alignment.center;

  void _show(bool on) {
    // On a phone the picked move's card is in the deck already; no floating card.
    if (on && widget.onPick != null) return;
    if (on) {
      final box = context.findRenderObject() as RenderBox?, w = MediaQuery.sizeOf(context).width;
      if (box != null && box.hasSize) {
        final x = box.localToGlobal(box.size.center(Offset.zero)).dx;
        _side = x < 140 ? Alignment.centerLeft : (x > w - 140 ? Alignment.centerRight : Alignment.center);
      }
    }
    setState(() => _hover = on);
    on ? _card.show() : _card.hide();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget, on = w.onTap != null;
    // Can't be used right now (no mana, not ready): the tile drains to a dark grey and its symbol
    // to greyscale, so a live move's colour is what the eye finds. (Only fading the symbol left
    // the tile's own colour lit, and a dead rite looked nearly as ready as Attack.)
    final tint = on ? w.tint : Color.lerp(w.tint, const Color(0xFF16130F), .82)!;
    final slot = AnimatedScale(
      scale: _down && on ? .92 : (_hover && on ? 1.05 : 1),
      duration: const Duration(milliseconds: 90),
      child: AspectRatio(
        // Squatter on a phone, so two rows of moves fit under the fight.
        aspectRatio: isPhone(context) ? 1.12 : .86,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: RadialGradient(center: const Alignment(0, -.3), radius: 1, colors: [Color.lerp(tint, Colors.white, _hover && on ? .16 : (on ? .08 : .03))!, Color.lerp(tint, Colors.black, .55)!]),
            border: Border.all(color: w.picked ? const Color(0xFFFFF0C8) : (w.glow ? Palette.amber : (on ? const Color(0xFF8A6A3A) : const Color(0xFF2A241C))), width: w.picked ? 3 : (w.glow ? 2 : 1.5)),
            boxShadow: [
              const BoxShadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 3),
              if (w.glow) BoxShadow(color: Palette.amber.withValues(alpha: .45), blurRadius: 10),
            ],
          ),
          child: Stack(
            children: [
              // The symbol and the name under it.
              Positioned.fill(
                child: Opacity(
                  opacity: on ? 1 : .42,
                  child: ColorFiltered(
                  colorFilter: on
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                      : const ColorFilter.matrix([.33, .59, .11, 0, 0, .33, .59, .11, 0, 0, .33, .59, .11, 0, 0, 0, 0, 0, 1, 0]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(flex: 3, child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.only(top: 10), child: w.icon))),
                      if (w.figure != null)
                        FittedBox(fit: BoxFit.scaleDown, child: Text(w.figure!, maxLines: 1, style: Txt.label(size: 12, color: Palette.amber, weight: FontWeight.w800))),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(w.name, maxLines: 1, style: Txt.label(size: 13, color: Palette.cream))),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                  ),
                ),
              ),
              // The number key (not on a phone: no keys there).
              if (!isPhone(context)) Positioned(left: 4, top: 3, child: Text('${w.hotkey}', style: Txt.label(size: 11, color: Palette.parch2))),
              // One key figure.
              if (w.badge != null || w.badgeArt != null)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xCC0E0B08), borderRadius: BorderRadius.circular(3)),
                    child: w.badgeArt ?? Text(w.badge!, style: Txt.label(size: 11.5, color: w.badgeColour, weight: FontWeight.w800)),
                  ),
                ),
              // Cooling down: a dark veil and the turns left.
              if (w.wait > 0)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${w.wait}', style: Txt.logo().copyWith(fontSize: 30, color: Palette.cream))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    // The card floats above the slot, centred on it, while the pointer is over it (or while it's
    // held down on a touch screen).
    return OverlayPortal(
      controller: _card,
      overlayChildBuilder: (context) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment(_side.x, -1),
          followerAnchor: Alignment(_side.x, 1),
          offset: const Offset(0, -10),
          child: IgnorePointer(child: _InfoCard(info: w.info)),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          cursor: on ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => _show(true),
          onExit: (_) => _show(false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            onLongPressStart: (_) => w.onPick == null ? _card.show() : w.onPick!(),
            onLongPressEnd: (_) => _card.hide(),
            // On a phone a tap uses the move at once; a move that can't be used shows why instead.
            onTap: w.onTap ?? w.onPick,
            // On a phone the moves are square tiles (no taller than 120); elsewhere a row of slots.
            child: isPhone(context)
                ? LayoutBuilder(builder: (context, box) => SizedBox(height: math.min(box.maxWidth * (MediaQuery.sizeOf(context).height >= 820 ? 1.12 : 1), 120), child: slot))
                : ConstrainedBox(constraints: const BoxConstraints(maxHeight: 104), child: slot),
          ),
        ),
      ),
    );
  }
}

/// What a move's hover card says: its name (in the move's colour), lines of detail (each in its own
/// colour: green for an edge, red for a drawback), and, if it can't be used now, why.
class _SlotInfo {
  const _SlotInfo(this.title, this.colour, this.lines, [this.why]);
  final String title;
  final Color colour;
  final List<(String, String, Color)> lines;
  final String? why;
  _SlotInfo blocked(String? why) => _SlotInfo(title, colour, lines, why);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.info});
  final _SlotInfo info;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Container(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 250),
      padding: const EdgeInsets.fromLTRB(12, 9, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xF2171310),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.colour.withValues(alpha: .7), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.title, style: Txt.label(size: 17, color: info.colour, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final (emoji, text, colour) in info.lines) _line(emoji, text, colour),
          if (info.why != null) _line('🚫', info.why!, const Color(0xFFFF8A70)),
        ],
      ),
    ),
  );

  /// Each line's little picture, drawn as a coloured icon (emoji fonts don't reliably load on
  /// the web, and these match the game's own art).
  static Widget _glyph(String key) => switch (key) {
    '⚔️' => const ItemIcon(Item.swords, size: 18),
    '🧪' => const ItemIcon(Item.potion, size: 18),
    _ => () {
      final (IconData icon, Color col) = switch (key) {
        '🏹' => (Icons.gps_fixed, const Color(0xFFDDD0B1)),
        '🎯' => (Icons.trending_up, const Color(0xFF9FE07A)),
        '🛡️' => (Icons.shield, const Color(0xFFFF8A70)),
        '🦅' => (Icons.air, const Color(0xFFB8D8F0)),
        '⚡' => (Icons.bolt, const Color(0xFFFFD45A)),
        '😵' => (Icons.auto_awesome, const Color(0xFFFFE27A)),
        '⏳' => (Icons.hourglass_bottom, const Color(0xFFC9B99A)),
        '❄️' => (Icons.ac_unit, const Color(0xFF9ADFFF)),
        '🔥' => (Icons.local_fire_department, const Color(0xFFFF8A3A)),
        '🩸' => (Icons.water_drop, const Color(0xFFE0453A)),
        '❤️' => (Icons.favorite, const Color(0xFFFF6A6A)),
        '🐌' => (Icons.speed, const Color(0xFF6ABF9A)),
        '📉' => (Icons.trending_down, const Color(0xFFB8A0D8)),
        '💥' => (Icons.flare, const Color(0xFFE0A050)),
        '💤' => (Icons.bedtime, const Color(0xFFB8A0E8)),
        '👑' => (Icons.workspace_premium, const Color(0xFFFFC94A)),
        '✨' => (Icons.security, const Color(0xFF7FB8E8)),
        '🪞' => (Icons.flip, const Color(0xFFCFE8F8)),
        '💀' => (Icons.groups, const Color(0xFFB07AFF)),
        '🔷' => (Icons.water_drop, const Color(0xFF6AC8FF)),
        '⏱️' => (Icons.timer, const Color(0xFFC9B99A)),
        '🐾' => (Icons.pets, const Color(0xFFE8B070)),
        '🏃' => (Icons.directions_run, const Color(0xFFBFB09A)),
        '📈' => (Icons.trending_up, const Color(0xFF9FE07A)),
        '🏠' => (Icons.home, const Color(0xFFE8B070)),
        '🎒' => (Icons.backpack, const Color(0xFFFF8A70)),
        '🚫' => (Icons.block, const Color(0xFFFF8A70)),
        _ => (Icons.circle, const Color(0xFFC9B99A)),
      };
      return Icon(icon, size: 17, color: col);
    }(),
  };

  static Widget _line(String emoji, String text, Color colour) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1, right: 7), child: SizedBox(width: 18, height: 18, child: Center(child: _glyph(emoji)))),
        Flexible(child: Text(text, style: Txt.onStone(size: 15, color: colour).copyWith(fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

/// A rite's mana cost as little blue drops.
class _ManaCost extends StatelessWidget {
  const _ManaCost(this.cost);
  final int cost;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < cost; i++)
        Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6AC8FF))),
    ],
  );
}

/// The bottom of the battle window: a dark strip of earth under the fight, an iron rail along its
/// top, the latest thing that happened, and your moves (or, once it's over, how it went and what
/// next). It dims while blows are trading, and lights up when it's your move.
class _CommandDeck extends StatelessWidget {
  const _CommandDeck({required this.controller, required this.lines, this.moves, this.result, this.detail, this.fill = false});

  /// Filling a tall phone screen: more of the log shows, and the moves sit at the very bottom.
  final bool fill;

  /// On a phone: the picked move's card, shown above the moves.
  final Widget? detail;
  final GameController controller;
  final List<JournalEntry> lines;
  final List<Widget>? moves, result;

  @override
  Widget build(BuildContext context) {
    final c = controller, yourMove = !c.busy && c.state.inBattle && c.outcome == null;
    final header = c.outcome != null
        ? null
        : c.busy
        ? switch (c.lastSwing?.action) {
            BattleAction.cast => 'Embers gather…',
            BattleAction.shoot => 'Bolts fly…',
            _ => 'Steel meets steel…',
          }
        : 'Turn ${c.state.turn + 1} · your move';
    // The log is a line or two at most; tap it for the whole fight.
    // (A tall phone shows two, a shorter one just the newest.)
    final roomy = fill && MediaQuery.sizeOf(context).height >= 820;
    final keep = fill && !roomy ? 1 : 2;
    final recent = lines.length <= keep ? lines : lines.sublist(lines.length - keep);
    Color tone(EntryKind k) => switch (k) {
      EntryKind.damage => const Color(0xFFE88A70),
      EntryKind.gold => Palette.amber,
      EntryKind.good => const Color(0xFF9BE27A),
      _ => Palette.parch,
    };
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1E1812), Color(0xFF0E0B08)]),
        border: Border(top: BorderSide(color: Color(0xFF8A6A3A), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result != null) ...[
            if (fill)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .45),
                child: SingleChildScrollView(child: RepaintBoundary(child: _Result(controller: c, onDark: true))),
              )
            else
              _Result(controller: c, onDark: true),
            const SizedBox(height: 8),
            Row(children: result!),
          ] else ...[
            // What just happened, two lines at most, beside a little banner (on a phone, under it, so
            // the lines get the whole width and aren't cut short).
            Builder(
              builder: (context) {
                final phone = isPhone(context);
                final banner = AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: yourMove ? const Color(0xFF6A4A1A) : const Color(0xFF2A221A),
                    border: Border.all(color: yourMove ? Palette.amber : Palette.stone3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(header ?? '', style: Txt.label(size: 13, color: yourMove ? const Color(0xFFFFE6A0) : Palette.parch2)),
                );
                final said = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Newest at the bottom, older lines fading up the log.
                  children: [
                    if (recent.isEmpty && c.state.knight.level < 3) Text(phone ? 'Tap a move to use it. Hold one to see what it does.' : 'Pick your move (or press its number key).', style: Txt.onStone(size: 14.5)),
                    // A phone gives each line two rows rather than cut it off mid-word.
                    for (final (i, e) in recent.indexed)
                      Opacity(
                        opacity: fill ? (.45 + .55 * (i + 1) / recent.length) : 1,
                        child: Text(e.text, maxLines: phone && !roomy ? 2 : 1, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: phone ? 13.5 : 14.5, color: tone(e.kind))),
                      ),
                  ],
                );
                if (fill) {
                  // A slim strip: the turn banner and the newest line beside it. Tap it for the
                  // whole fight so far. (The screen goes to the fight and the moves.)
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showLog(context, lines, tone),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        banner,
                        const SizedBox(width: 8),
                        Expanded(child: SizedBox(height: roomy ? 40 : 36, child: Align(alignment: Alignment.centerLeft, child: said))),
                        const Icon(Icons.expand_less, size: 20, color: Palette.parch2),
                      ],
                    ),
                  );
                }
                return phone
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [banner, const SizedBox(height: 5), said])
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [banner, const SizedBox(width: 10), Expanded(child: said)]);
              },
            ),
            const SizedBox(height: 8),
            if (detail != null) ...[detail!, const SizedBox(height: 8)],
            _moves(context, yourMove, grow: fill),
          ],
        ],
      ),
    );
  }

  Widget _moves(BuildContext context, bool yourMove, {bool grow = false}) {
    final m = moves ?? const <Widget>[];
    Widget row(List<Widget> cells) => Row(children: cells);
    return AnimatedOpacity(
      opacity: yourMove ? 1 : .45,
      duration: const Duration(milliseconds: 160),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          // On a phone, the moves wrap into rows of four so each is a good thumb's width.
          child: isPhone(context) && m.length > 4
              ? Column(
                  children: [
                    // Even rows (six moves: three and three), so no row ends in a gap.
                    for (final (i, n) in [for (var i = 0, per = (m.length / ((m.length + 3) ~/ 4)).ceil(); i < m.length; i += per) (i, per)]) ...[
                      if (i > 0) SizedBox(height: grow ? 10 : 6),
                      row([...m.sublist(i, math.min(i + n, m.length)), for (var j = m.length; j < i + n; j++) const Expanded(child: SizedBox())]),
                    ],
                  ],
                )
              : row(m),
        ),
      ),
    );
  }
}

/// The whole fight's log, in a sheet from the bottom (from the slim log strip on a phone).
void _showLog(BuildContext context, List<JournalEntry> lines, Color Function(EntryKind) tone) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * .6),
  builder: (context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1A1510),
      border: Border.all(color: Palette.amberLo, width: 1.5),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
    ),
    padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + MediaQuery.paddingOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Palette.stone3, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 8),
        Text('THIS FIGHT', style: Txt.label(size: 12, color: Palette.amber)),
        const SizedBox(height: 6),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            reverse: true,
            children: [for (final e in lines.reversed) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(e.text, style: Txt.onStone(size: 14, color: tone(e.kind))))],
          ),
        ),
      ],
    ),
  ),
);

/// How the fight ended.
class _Result extends StatelessWidget {
  const _Result({required this.controller, this.onDark = false});
  final GameController controller;

  /// Drawn on the dark command deck instead of parchment.
  final bool onDark;

  static const _green = Color(0xFF9BE27A), _gold = Color(0xFFF2C14E);

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.lastKill, r = c.lastSwing, s = c.state;
    // A win is a row of spoils, each an icon and a few words; everything else is a line or two.
    final spoils = <_Spoil>[];
    var lines = <String>[];
    final String title;
    switch (c.outcome!) {
      case Outcome.won:
        title = k?.won == true ? 'The Ember King is no more!' : (k?.boss == true ? 'Boss defeated!' : 'Victory!');
        if (k != null) {
          final chest = k.chest;
          spoils.addAll([
            if (k.levelUps > 0) _Spoil(const Icon(Icons.arrow_upward, size: 18, color: _green), 'Level ${s.knight.level}!', _green, big: true),
            _Spoil(const Icon(Icons.auto_awesome, size: 17, color: Color(0xFFB8D8FF)), '+${fmt(k.xp)} XP', const Color(0xFFB8D8FF)),
            if (k.wild)
              _Spoil(const ItemIcon(Item.coins, size: 18), '+${fmt(k.packGold)} to your pack', _gold, tip: 'Gold and gear in your pack are only yours once you get them home')
            else
              _Spoil(const ItemIcon(Item.coins, size: 18), '+${fmt(k.coins + (chest?.coins ?? 0))}', _gold),
            if (k.potion || chest?.potion == true) const _Spoil(ItemIcon(Item.potion, size: 18), 'Potion', Color(0xFFE88A70)),
            if (k.jobFind != null)
              _Spoil(ItemIcon(k.jobFind!.contains('Timber') ? Item.timber : Item.iron, size: 18), k.jobFind!.contains('Timber') ? 'Timber ${s.timber}/$timberNeeded' : 'Iron ${s.ironScrap}/$ironNeeded', Palette.cream, tip: 'For Hob\'s repairs'),
            if (k.reagents > 0) _Spoil(const Icon(Icons.local_florist, size: 17, color: Color(0xFFE0A0D0)), '+${k.reagents} ${continents[s.continent].reagent}', const Color(0xFFE0A0D0), tip: 'For Old Wick\'s wards (${s.reagents[s.continent]} now)'),
            if (chest != null) _Spoil(const Icon(Icons.inventory_2, size: 17, color: _gold), chest.tier.label, _gold),
            for (final g in [...?chest?.items, if (k.wild) ...k.packed]) _Spoil(const Icon(Icons.shield_outlined, size: 17), g.name, Color(g.rarity.argb), tip: '${g.rarity.label} ${g.slot.label.toLowerCase()}'),
            // Bolts: a find worth noticing (they load themselves onto your crossbow).
            if (chest?.ammo != null) _Spoil(const Icon(Icons.north_east, size: 17, color: Color(0xFFFFB86A)), '+${chest!.ammo!}', const Color(0xFFFFB86A), big: true, tip: 'Special bolts for your crossbow: one per Shoot'),
            // What it was carrying for the crafters.
            for (final (kind, name) in k.finds)
              switch (kind) {
                'gem' => _Spoil(MatIcon.gem(Gem.values.byName(name), size: 18), Gem.values.byName(name).label, Color(Gem.values.byName(name).argb), big: true, tip: 'Old Wick grinds it into ${Gem.values.byName(name).ammo.label(Missile.bolt).toLowerCase()}'),
                'core' => _Spoil(MatIcon(MatShape.gem, Color(Elemental.values.byName(name).argb), size: 18), Elemental.values.byName(name).core, Color(Elemental.values.byName(name).argb), tip: 'Old Wick binds $coresPerRune into a rune'),
                'ore' => _Spoil(MatIcon.ore(Metal.values.byName(name), size: 18), Metal.values.byName(name).ore, Color(Metal.values.byName(name).argb), tip: '$smithName smelts it into bars'),
                _ => const _Spoil(Icon(Icons.description, size: 17, color: Color(0xFFB8A0FF)), 'Enchanting scroll', Color(0xFFB8A0FF), tip: 'A free rune at the enchanter'),
              },
            if (k.companion != null) _Spoil(const Icon(Icons.pets, size: 17, color: _green), 'New companion!', _green, big: true, tip: k.companion),
            if (k.prize != null) _Spoil(const Icon(Icons.diamond, size: 17, color: Color(0xFFFFB04A)), k.prize!.name, Color(k.prize!.rarity.argb), big: true),
            for (final l in k.opened) _Spoil(const Icon(Icons.map, size: 17, color: _gold), isSideLand(l) ? 'Found: ${continents[l].name}' : 'Open: ${continents[l].name}', _gold, big: true),
            for (final h in k.hoard) _Spoil(const Icon(Icons.diamond, size: 17, color: _gold), h, _gold, big: true),
            if (k.trophy != null) _Spoil(const Icon(Icons.emoji_events, size: 17, color: Palette.cream), k.trophy!, Palette.cream, tip: 'For $smithName\'s forge'),
            if (k.blueprint != null) _Spoil(const Icon(Icons.description, size: 17, color: Color(0xFF8AB8F0)), k.blueprint!, const Color(0xFF8AB8F0), big: true, tip: 'A blueprint. Take it to $smithName'),
          ]);
          if (k.won) lines = ['The Great Burning is over. Your eyebrows can start growing back.'];
        }
      case Outcome.fled when r?.packLoss != null:
        title = 'You got away!';
        lines = [r!.packLoss!.none ? 'Nothing fell out of your pack.' : 'Dropped as you ran: ${r.packLoss!.summary}.'];
      case Outcome.fled:
        title = 'You got away!';
        lines = ['Back to the Soot & Kettle, a little less dignified.'];
      case Outcome.knockedOut when r?.wildExit != null:
        title = 'Knocked out!';
        lines = [
          r!.packLoss!.none ? 'Scavengers found your pack empty.' : 'Scavengers took ${r.packLoss!.summary}.',
          if (r.wildExit!.gold > 0 || r.wildExit!.items > 0) 'Hob saved ${r.wildExit!.gold} gold${r.wildExit!.items > 0 ? ' and ${r.wildExit!.items} piece${r.wildExit!.items == 1 ? '' : 's'} of gear' : ''}.',
          if (r.goldLost > 0) '−${r.goldLost} of your own gold.',
        ];
      case Outcome.knockedOut:
        title = 'Knocked out!';
        lines = [
          'Hob dragged you back to the inn.${(r?.goldLost ?? 0) > 0 ? ' −${r!.goldLost} gold.' : ''}',
          if (c.wildHint(s.continent) case final a?) 'Tip: better gear waits in ${wildAreas[a].name}.',
        ];
    }
    final colour = c.outcome == Outcome.knockedOut ? (onDark ? const Color(0xFFE88A70) : const Color(0xFF7A1D14)) : (onDark ? Palette.amber : Palette.goldText);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: onDark ? Txt.label(size: 20, color: colour, weight: FontWeight.w800) : Txt.inkLabel(size: 18, color: colour)),
        const SizedBox(height: 6),
        if (spoils.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: spoils),
        for (final l in lines) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l, style: onDark ? Txt.onStone(size: 14.5, color: Palette.cream) : Txt.body(size: 14.5))),
      ],
    );
    return onDark ? body : Parchment(child: body);
  }
}

/// One thing won: an icon and a few words, in a chip. The big ones (a level, a new land, a
/// companion) glow in their colour.
class _Spoil extends StatelessWidget {
  const _Spoil(this.icon, this.text, this.colour, {this.big = false, this.tip});
  final Widget icon;
  final String text;
  final Color colour;
  final bool big;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: big ? Color.lerp(const Color(0xE0120E0A), colour, .22) : const Color(0xD0120E0A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colour.withValues(alpha: big ? .9 : .45), width: big ? 1.5 : 1),
        boxShadow: big ? [BoxShadow(color: colour.withValues(alpha: .35), blurRadius: 8)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(data: IconThemeData(color: colour), child: SizedBox(width: 18, height: 18, child: Center(child: icon))),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: Txt.label(size: 14, color: big ? colour : Palette.cream, weight: FontWeight.w800))),
        ],
      ),
    );
    return tip == null ? chip : Tooltip(message: tip!, triggerMode: isPhone(context) ? TooltipTriggerMode.tap : null, child: chip);
  }
}

/// Opens a fight and returns how it ended.
Future<BattleExit?> openBattle(BuildContext context, GameController c, BattleStart start) =>
    Navigator.of(context).push<BattleExit>(MaterialPageRoute(builder: (_) => BattleScreen(controller: c, start: start)));

/// The crossbow's timing bar: a dial sweeps back and forth; loose the bolt (tap, Space or Enter)
/// with it in the gold centre for a bullseye, anywhere in the amber for a true shot, out at the
/// red edges for a graze.
class _AimBar extends StatefulWidget {
  const _AimBar({required this.onLoose, required this.onCancel, this.speed = 1, this.zone = bullseyeZone});
  final ValueChanged<double> onLoose;

  /// The bullseye's half-width (Aim training widens it).
  final double zone;
  final VoidCallback onCancel;
  final double speed;
  @override
  State<_AimBar> createState() => _AimBarState();
}

class _AimBarState extends State<_AimBar> with SingleTickerProviderStateMixin {
  late final _dial = AnimationController(vsync: this, duration: Duration(milliseconds: (950 / widget.speed).round()));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Start sweeping once the bar is on screen, so the frame that lays it out doesn't swallow the
    // first stretch of the sweep (that was the stutter as it set off from the left).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _dial.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _dial.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Mostly an even sweep, easing just a little at the ends: a full stop there read as a hitch.
  double get _pos => .75 * _dial.value + .25 * Curves.easeInOutSine.transform(_dial.value);

  void _loose() {
    _dial.stop();
    widget.onLoose(_pos);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.space): _loose,
      const SingleActivator(LogicalKeyboardKey.enter): _loose,
      const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
    },
    child: Focus(
      focusNode: _focus,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 18, color: Color(0xFFFFD98A)),
              const SizedBox(width: 6),
              Expanded(child: Text('Tap when the dial is in the gold', style: Txt.label(size: 13, color: Palette.cream))),
              TextButton(onPressed: widget.onCancel, child: Text('Cancel', style: Txt.label(size: 12, color: Palette.parch2))),
            ],
          ),
          const SizedBox(height: 4),
          MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _loose(),
              child: SizedBox(
                height: 46,
                // Only the needle repaints each frame; the bar under it is drawn once.
                child: RepaintBoundary(
                  child: CustomPaint(painter: _AimPainter(widget.zone), foregroundPainter: _NeedlePainter(_dial, () => _pos), size: Size.infinite),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AimPainter extends CustomPainter {
  _AimPainter(this.zone);
  final double zone;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Rect.fromLTWH(6, 8, size.width - 12, size.height - 16), mid = bar.center.dx, half = bar.width / 2;
    final r = RRect.fromRectAndRadius(bar, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(r);
    // Red at the edges, amber across most of it, gold in the middle.
    canvas.drawRect(bar, Paint()..color = const Color(0xFF6A1A12));
    canvas.drawRect(Rect.fromLTRB(mid - half * trueZone, bar.top, mid + half * trueZone, bar.bottom), Paint()..shader = const LinearGradient(colors: [Color(0xFF8A5A1A), Color(0xFFB8862A), Color(0xFF8A5A1A)]).createShader(bar));
    canvas.drawRect(Rect.fromLTRB(mid - half * zone, bar.top, mid + half * zone, bar.bottom), Paint()..color = const Color(0xFFFFD45A));
    // Tick marks along the bar.
    for (var i = 1; i < 20; i++) {
      final x = bar.left + bar.width * i / 20;
      canvas.drawLine(Offset(x, bar.bottom - (i % 5 == 0 ? 10 : 5)), Offset(x, bar.bottom), Paint()
        ..color = const Color(0x55000000)
        ..strokeWidth = 1.5);
    }
    canvas.restore();
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF2A1C0C));
    // A little crosshair over the gold.
    canvas.drawCircle(Offset(mid, bar.center.dy), 7, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF6A3A0A));
  }

  @override
  bool shouldRepaint(_AimPainter old) => old.zone != zone;
}

/// The dial's needle, repainted every frame straight from the animation (no rebuilds), with a
/// soft halo instead of a blur, which is cheaper to draw.
class _NeedlePainter extends CustomPainter {
  _NeedlePainter(Listenable dial, this.pos) : super(repaint: dial);
  final double Function() pos;

  @override
  void paint(Canvas canvas, Size size) {
    // A bright needle with a halo, overshooting the bar a little.
    final bar = Rect.fromLTWH(6, 8, size.width - 12, size.height - 16), x = bar.left + bar.width * pos();
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
      ..color = const Color(0x55FFF0C0)
      ..strokeWidth = 9);
    canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(Path()..addPolygon([Offset(x - 6, 0), Offset(x + 6, 0), Offset(x, 7)], true), Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => false;
}

/// On a phone (no hover): the picked move's card, laid out in the deck above the moves: what it
/// does in a few lines, and "tap to use", or why it can't be used. Shown once you hold a move.
class _PickedCard extends StatelessWidget {
  const _PickedCard({required this.info, required this.ready});
  final _SlotInfo info;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
    decoration: BoxDecoration(
      color: const Color(0xFF171310),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: info.colour.withValues(alpha: .6), width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(info.title, style: Txt.label(size: 16, color: info.colour, weight: FontWeight.w800))),
            if (ready && info.why == null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app, size: 16, color: Palette.amber),
                  const SizedBox(width: 4),
                  Text('Tap to use', style: Txt.label(size: 12, color: Palette.amber)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            for (final (emoji, text, colour) in info.lines) _InfoCard._line(emoji, text, colour),
            if (info.why != null) _InfoCard._line('🚫', info.why!, const Color(0xFFFF8A70)),
          ],
        ),
      ],
    ),
  );
}
