// The fight: a big stage, the foe's card, and your choices each turn: Attack with your blade, a
// Shield Bash (or Mighty Blow), Cast an Ember Rite, Shoot your crossbow, drink a Potion, Command
// your companion, or Flee. When it's over: the spoils, then fight on or head back to the map.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/crafting.dart' show smithName;
import '../game/engine.dart';
import '../game/loot.dart' show specialCharge, Stat;
import '../game/models.dart';
import '../game/rules.dart';
import '../game/spells.dart';
import '../game/wilds.dart';
import 'battle_stage.dart';
import 'hud.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'encounter_window.dart';
import 'item_icons.dart';
import 'stat_icons.dart';
import 'theme.dart';
import 'trail_data.dart';

/// What the battle screen should start with, once the stage is listening.
enum BattleStart { explore, boss, resume, raid, heroic, wild }

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
  int _journalFrom = 0;
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
    _journalFrom = c.state.journal.length;
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
      case BattleStart.wild:
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
  /// stay, even short of mana, so you can plan ahead.)
  bool get _hasPotions => c.state.knight.potions > 0;
  bool get _hasCompanion => petStage(c.state.knight) != null || dragonStage(c.state.knight) != null;

  /// Shoot: up comes the timing bar (unless you've asked for auto-aim).
  void _shoot() {
    if (_aiming) return;
    if (c.busy || c.outcome != null || !c.state.inBattle || c.whyNot(BattleAction.shoot) != null) return;
    if (c.state.settings.autoAim) return _act(BattleAction.shoot);
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
    if (widget.start == BattleStart.heroic) return _begin(BattleStart.heroic);
    _begin(trailStep(c.state, c.state.continent) == TrailStep.lair ? BattleStart.boss : BattleStart.explore);
  }

  void _close(BattleExit to) => Navigator.of(context).pop(to);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.state, foe = c.shownFoeType, land = continents[realmAt(c.shownRare?.base ?? c.shownFoe)];
        final lines = s.journal.length > _journalFrom ? s.journal.sublist(_journalFrom) : const <JournalEntry>[];
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
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 5, child: HeroStrip(controller: c)),
                                          const SizedBox(width: 5),
                                          Expanded(flex: 6, child: _FoeCard(controller: c, foe: foe, fill: true)),
                                        ],
                                      ),
                                    ),
                                  _stageIn(
                                    fill,
                                    Stack(
                                    children: [
                                      BattleStage(controller: c, aspectRatio: aspect),
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
                                            HeroCard(controller: c, mana: true),
                                            const SizedBox(height: 6),
                                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: StatusBadges(state: s)),
                                          ],
                                        ),
                                      ),
                                      if (!phone) Positioned(right: 8, top: 8, child: _FoeCard(controller: c, foe: foe)),
                                      Positioned(
                                        left: 10,
                                        bottom: 6,
                                        child: _wild && s.wild != null
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
                            return Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 10), child: frame);
                          }
                          return Center(
                            child: SingleChildScrollView(
                              // A phone gives the fight every pixel of width it can.
                              padding: phone ? const EdgeInsets.fromLTRB(4, 6, 4, 10) : const EdgeInsets.fromLTRB(12, 12, 12, 16),
                              child: ConstrainedBox(constraints: BoxConstraints(maxWidth: w + 6), child: frame),
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
  Widget _deckIn(bool fill, Widget deck) => fill ? Expanded(child: deck) : deck;

  /// The stage keeps its shape on every screen (the log takes a tall phone's spare height).
  Widget _stageIn(bool fill, Widget stage) => stage;

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
    final swing = fullSwing(k);
    final bash = skillName(k) == 'Shield Bash';
    var key = 0;
    Widget slot(BattleAction a, Widget icon, String name, _SlotInfo info, {String? badge, Widget? badgeArt, String? figure, int wait = 0, bool glow = false, Color tint = const Color(0xFF3B3327), String? rite}) {
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
        _ => '×${mult.toStringAsFixed(1)}',
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
            if (special != null) ('⚡', 'Charges your special ${s.specialCharge}/$specialCharge', soft),
          ]),
          badge: bladeEdge != 1 ? pct(bladeEdge) : '$swing',
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
          badge: '×$bashMult',
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
          const Icon(Icons.gps_fixed, size: 38, color: Color(0xFFDDD0B1)),
          'Shoot',
          _SlotInfo('Shoot', const Color(0xFFDDD0B1), [
            ('🏹', '~${(swing * crossbowShare(k) * boltEdge * aimBoost(k)).round()} damage', plain),
            ('🎯', 'Bullseye ×$bullseye', soft),
            if (aloft) ('🦅', 'Easy shot in the air ${pct(aloftShot)}', good),
            if (triangle(kind, AttackStyle.bolt) != 1) edgeLine(triangle(kind, AttackStyle.bolt), 'bolts'),
          ]),
          badge: boltEdge != 1 ? pct(boltEdge) : '${(crossbowShare(k) * 100).round()}%',
          glow: boltEdge > 1,
        ),
        if (_hasPotions)
        slot(
          BattleAction.potion,
          const ItemIcon(Item.potion, size: 38),
          'Potion',
          _SlotInfo('Health potion', const Color(0xFFFF8A8A), [
            ('❤️', 'Heals ${potionHeal(k)} HP', good),
            ('⏱️', 'Uses your turn', soft),
            ('🧪', '${k.potions} left', soft),
          ]),
          badge: '×${k.potions}',
          // Lights up when you're in trouble, so it's the first thing your eye finds.
          glow: k.hp < maxHp(k) * .35,
          tint: const Color(0xFF3A1A1A),
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
        ),
        slot(
          BattleAction.flee,
          const Icon(Icons.directions_run, size: 38, color: Color(0xFFBFB09A)),
          'Flee',
          _SlotInfo('Flee', const Color(0xFFBFB09A), [
            ('🏃', '${(flee * 100).round()}% to escape', plain),
            ('📈', '+${(fleeStep * 100).round()}% each failed try', soft),
            if (s.wild != null) ('🎒', 'Drops ${(fightFleeLoss * 100).round()}% of your pack', bad) else ('🏠', 'Back to the inn', soft),
          ]),
          badge: '${(flee * 100).round()}%',
        ),
      ],
    ];
  }

  List<Widget> _resultButtons() {
    final o = c.outcome!;
    final waiting = c.nextLoot != null;
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
    final onward = widget.start == BattleStart.heroic ? (risen ? 'Face ${continents[land].boss.name}, Risen' : 'Onward · Heroic') : trailAction(c.state, land);
    switch (o) {
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
  Widget build(BuildContext context) {
    final c = controller, colour = foe.aura != null ? Color(foe.aura!.argb) : (foe.boss ? Palette.amber : Palette.cream);
    final realm = realmAt(c.state.rare?.base ?? c.state.foe);
    final aura = foe.aura;
    final weak = weakTo(foe), shrug = shrugsOff(foe);
    final hazard = c.state.inBattle && c.state.hazardIn(realm);
    return FoeCard(
      fill: fill,
      name: foe.name,
      colour: colour,
      hp: c.shownFoeHp,
      maxHp: c.shownFoeMax,
      level: c.state.foeLevel,
      tags: [
        if (aura != null) FoeBadge(label: foe.pack ? 'PACK' : (foe.named ? 'RARE BOSS' : 'RARE'), colour: colour, solid: true, tip: aura.label),
        if (foe.boss && aura == null) const FoeBadge(label: 'BOSS', colour: Palette.amber, solid: true),
        if (foe.kind != FoeKind.none) FoeBadge(icons: [Icon(kindIcon(foe.kind), size: 14, color: kindColour(foe.kind))], text: foe.kind.label, colour: kindColour(foe.kind)),
        if (aura != null && !foe.pack && !foe.named) _perkBadge(aura),
      ],
      badges: [
        if (weak.isNotEmpty) FoeBadge(label: 'Weak', icons: [for (final w in weak) _wayIcon(w)], colour: const Color(0xFF9BE27A), tip: 'Weak to ${weak.join(', ')}'),
        if (shrug.isNotEmpty) FoeBadge(label: 'Resists', icons: [for (final w in shrug) Opacity(opacity: .75, child: _wayIcon(w))], colour: const Color(0xFFE07A6A), tip: 'Shrugs off ${shrug.join(', ')}'),
        if (c.state.inBattle && !c.busy) FoeBadge(icons: const [Icon(Icons.flash_on, size: 15, color: Color(0xFFFF8A70))], text: '~${counterDamage(c.state)}', colour: const Color(0xFFE0A090), tip: 'Hits for about ${counterDamage(c.state)}'),
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
    return FoeBadge(icons: [Icon(icon, size: 14, color: col)], text: text, colour: col, tip: a.perk);
  }
}

/// One slot on the hotbar.
class _SkillSlot extends StatefulWidget {
  const _SkillSlot({required this.hotkey, required this.icon, required this.name, required this.info, this.badge, this.badgeArt, this.figure, this.wait = 0, this.glow = false, this.tint = const Color(0xFF3B3327), this.onTap, this.picked = false, this.onPick});
  final int hotkey;

  /// On a phone: this move is picked (its card shows above the moves; another tap uses it), and
  /// how to pick it.
  final bool picked;
  final VoidCallback? onPick;
  final Widget icon;
  final String name;
  final String? badge;
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
    final slot = AnimatedScale(
      scale: _down && on ? .92 : (_hover && on ? 1.05 : 1),
      duration: const Duration(milliseconds: 90),
      child: AspectRatio(
        // Squatter on a phone, so two rows of moves fit under the fight.
        aspectRatio: isPhone(context) ? 1.12 : .86,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: RadialGradient(center: const Alignment(0, -.3), radius: 1, colors: [Color.lerp(w.tint, Colors.white, _hover && on ? .16 : .08)!, Color.lerp(w.tint, Colors.black, .55)!]),
            border: Border.all(color: w.picked ? const Color(0xFFFFF0C8) : (w.glow ? Palette.amber : (on ? const Color(0xFF8A6A3A) : const Color(0xFF3A3026))), width: w.picked ? 3 : (w.glow ? 2 : 1.5)),
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
                  opacity: on ? 1 : .38,
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
              // The number key.
              Positioned(left: 4, top: 3, child: Text('${w.hotkey}', style: Txt.label(size: 11, color: Palette.parch2))),
              // One key figure.
              if (w.badge != null || w.badgeArt != null)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xCC0E0B08), borderRadius: BorderRadius.circular(3)),
                    child: w.badgeArt ?? Text(w.badge!, style: Txt.label(size: 11, color: Palette.amber)),
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
            child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 104), child: slot),
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
    final keep = fill ? 8 : 2;
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
            if (fill) Expanded(child: SingleChildScrollView(child: _Result(controller: c, onDark: true))) else _Result(controller: c, onDark: true),
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
                    if (recent.isEmpty) Text(phone ? 'Tap a move to use it. Hold one to see what it does.' : 'Pick your move (or press its number key).', style: Txt.onStone(size: 14.5)),
                    // A phone gives each line two rows rather than cut it off mid-word.
                    for (final (i, e) in recent.indexed)
                      Opacity(
                        opacity: fill ? (.45 + .55 * (i + 1) / recent.length) : 1,
                        child: Text(e.text, maxLines: phone ? 2 : 1, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: phone ? 13.5 : 14.5, color: tone(e.kind))),
                      ),
                  ],
                );
                if (fill) {
                  // The log takes the room between the banner and the moves, newest line nearest them.
                  return Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        banner,
                        const SizedBox(height: 5),
                        Expanded(child: ClipRect(child: Align(alignment: Alignment.bottomLeft, child: SingleChildScrollView(reverse: true, child: said)))),
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
            AnimatedOpacity(
              opacity: yourMove ? 1 : .45,
              duration: const Duration(milliseconds: 160),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  // On a phone, the moves wrap into rows of four so each is a good thumb's width.
                  child: isPhone(context) && (moves?.length ?? 0) > 4
                      ? Column(
                          children: [
                            // Even rows (six moves: three and three), so no row ends in a gap.
                            for (final (i, n) in [for (var i = 0, per = (moves!.length / ((moves!.length + 3) ~/ 4)).ceil(); i < moves!.length; i += per) (i, per)]) ...[
                              if (i > 0) const SizedBox(height: 6),
                              Row(children: [...moves!.sublist(i, math.min(i + n, moves!.length)), for (var j = moves!.length; j < i + n; j++) const Expanded(child: SizedBox())]),
                            ],
                          ],
                        )
                      : Row(children: moves ?? const []),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How the fight ended.
class _Result extends StatelessWidget {
  const _Result({required this.controller, this.onDark = false});
  final GameController controller;

  /// Drawn on the dark command deck instead of parchment.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.lastKill, r = c.lastSwing;
    final (title, colour, lines) = switch (c.outcome!) {
      Outcome.won when k != null && k.wild => (
        'Victory!',
        Palette.goldText,
        [
          '+${fmt(k.xp)} XP${k.levelUps > 0 ? ' · level ${c.state.knight.level}!' : ''}',
          'Into your pack: ${fmt(k.packGold)} gold${k.packed.isEmpty ? '' : ', ${k.packed.map((g) => g.name).join(', ')}'}.',
          if (k.potion) 'It was carrying a health potion (${c.state.knight.potions} now).',
          'Pack: ${fmt(c.state.packGold)} gold, ${c.state.pack.length} piece${c.state.pack.length == 1 ? '' : 's'} of gear. Not yours until you get it home.',
        ],
      ),
      Outcome.won => (
        k?.won == true ? 'Vharrax the Ember King is no more!' : (k?.boss == true ? '${k!.name} is defeated!' : 'Victory!'),
        Palette.goldText,
        [
          if (k != null) '+${fmt(k.xp)} XP · +${fmt(k.coins)} gold${k.levelUps > 0 ? ' · level ${c.state.knight.level}!' : ''}',
          if (k?.potion == true) 'It was carrying a health potion (${c.state.knight.potions} now).',
          if (k?.jobFind != null) 'For Hob: ${k!.jobFind} (timber ${c.state.timber}/$timberNeeded, iron ${c.state.ironScrap}/$ironNeeded).',
          if ((k?.reagents ?? 0) > 0) 'Gathered ${k!.reagents} ${continents[c.state.continent].reagent} (${c.state.reagents[c.state.continent]} now), for Old Wick\'s wards.',
          if (k?.chest != null) 'You open ${withArticle(k!.chest!.tier.label.toLowerCase())}: ${k.chest!.summary}.',
          if (k?.companion != null) k!.companion!,
          if (k?.prize != null) 'Its treasure: ${k!.prize!.name}.',
          for (final l in k?.opened ?? const <int>[]) isSideLand(l) ? 'Off the road, a new land: ${continents[l].name}!' : 'The way to ${continents[l].name} is open!',
          if (k?.trophy != null) 'A trophy: ${k!.trophy}, for $smithName\'s forge.',
          if (k?.blueprint != null) 'A blueprint! The ${k!.blueprint}. Take it to $smithName.',
          if (k?.won == true) 'The Great Burning is over. The world can start growing back, and so can your eyebrows. (The adventure carries on: every continent is still there to fight in.)',
        ],
      ),
      Outcome.fled when r?.packLoss != null => (
        'You got away!',
        Palette.inkSoft,
        [r!.packLoss!.none ? 'Your pack was empty, so nothing fell out as you ran.' : 'As you ran, ${r.packLoss!.summary} fell out of your pack.', 'You\'re still out in the wilds.'],
      ),
      Outcome.fled => ('You got away!', Palette.inkSoft, ['You don\'t stop running until you\'re back at the Soot & Kettle. Nothing won, nothing lost but a little dignity.']),
      Outcome.knockedOut when r?.wildExit != null => (
        'Knocked out!',
        const Color(0xFF7A1D14),
        [
          'Scavengers went through your pack while you lay in the ash${r!.packLoss!.none ? ', and found it empty.' : ': ${r.packLoss!.summary} gone.'}',
          if (r.wildExit!.gold > 0 || r.wildExit!.items > 0) 'The innkeeper finds you and what\'s left: ${r.wildExit!.gold} gold${r.wildExit!.items > 0 ? ' and ${r.wildExit!.items} piece${r.wildExit!.items == 1 ? '' : 's'} of gear' : ''}.',
          if ((r.goldLost) > 0) 'Someone helped themselves to ${r.goldLost} of your own gold too.',
        ],
      ),
      Outcome.knockedOut => (
        'Knocked out!',
        const Color(0xFF7A1D14),
        [
          'The innkeeper finds you in a ditch and drags you back to the Soot & Kettle.${(r?.goldLost ?? 0) > 0 ? ' Someone helped themselves to ${r!.goldLost} gold on the way.' : ''} You\'re patched up and ready to go again.',
          if (c.wildHint(c.state.continent) case final a?) 'Struggling here? Better gear waits in ${wildAreas[a].name} (on the map), and the deeper you dare, the better it gets.',
        ],
      ),
    };
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: onDark ? Txt.label(size: 20, color: c.outcome == Outcome.knockedOut ? const Color(0xFFE88A70) : Palette.amber, weight: FontWeight.w800) : Txt.inkLabel(size: 18, color: colour)),
        const SizedBox(height: 4),
        for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(l, style: onDark ? Txt.onStone(size: 14.5, color: Palette.cream) : Txt.body(size: 14.5))),
      ],
    );
    return onDark ? body : Parchment(child: body);
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
  late final _dial = AnimationController(vsync: this, duration: Duration(milliseconds: (950 / widget.speed).round()))..repeat(reverse: true);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _dial.dispose();
    _focus.dispose();
    super.dispose();
  }

  // An eased sweep: quick through the middle, lingering a touch at the ends.
  double get _pos => Curves.easeInOutSine.transform(_dial.value);

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
              Expanded(child: Text('Take aim! Tap (or Space) with the dial in the gold', style: Txt.label(size: 13, color: Palette.cream))),
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
                child: AnimatedBuilder(animation: _dial, builder: (context, _) => CustomPaint(painter: _AimPainter(_pos, widget.zone), size: Size.infinite)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AimPainter extends CustomPainter {
  _AimPainter(this.pos, this.zone);
  final double pos, zone;

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
    // The dial: a bright needle with a glow, overshooting the bar a little.
    final x = bar.left + bar.width * pos;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
      ..color = const Color(0x99FFF0C0)
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(Path()..addPolygon([Offset(x - 6, 0), Offset(x + 6, 0), Offset(x, 7)], true), Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_AimPainter old) => old.pos != pos || old.zone != zone;
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
