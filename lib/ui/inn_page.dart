// The Soot & Kettle: the inn where every adventure starts and ends. Rest by the fire, shop with
// Mags, sort your gear, read the adventure log, and set out across the map.

import 'dart:math' as math;
import 'dart:ui' as ui;

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
import '../game/catalog.dart';
import '../game/events.dart';
import '../game/controller.dart';
import '../game/crafting.dart' show smithName, mageName;
import '../game/models.dart';
import '../game/rules.dart';
import 'account_panel.dart';
import 'cadence.dart';
import 'battle_screen.dart';
import 'hero_page.dart';
import 'class_picker.dart' show HeroOrHeroine;
import 'frames.dart';
import 'hud.dart';
import 'item_icons.dart';
import 'journal_panel.dart';
import 'loot_window.dart';
import 'map_page.dart';
import 'merchant.dart';
import 'quest_dialog.dart';
import '../services/cloud.dart';
import 'theme.dart';
import 'wilds_page.dart';
import 'trail_page.dart';

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

  @override
  void dispose() {
    townRoutes.unsubscribe(this);
    super.dispose();
  }

  /// Back in town from somewhere else.
  @override
  void didPopNext() => _checkRaid();

  /// Bandits hit the town while you were out: whoever was robbed runs up to tell you, once.
  Future<void> _checkRaid() async {
    if (c.state.raid == null || c.state.raidSeen || c.state.inBattle || c.jobOffered) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false) || c.state.raidSeen) return;
    c.raidSeen();
    if (await raidAlarm(context, c) && mounted) await _chase();
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
      // A seasonal event: welcomed once a year.
      final season = mounted ? c.greetSeason() : null;
      if (season != null && mounted) showQuestToast(context, season.label, 'A seasonal event is on in Cindervale');
    });
  }

  Future<void> _showStory() async {
    await showDialog<void>(context: context, builder: (_) => const _StoryWindow());
  }

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

  Future<void> _openWilds() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WildsPage(controller: c)));
  }

  Future<void> _resume() async {
    await openBattle(context, c, BattleStart.resume);
  }

  void _openKit() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Row(
                      children: [
                        InnBackButton(label: 'Town', onPressed: () => Navigator.of(context).pop()),
                        const SizedBox(width: 14),
                        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Your ${homes[c.state.home].name}', style: Txt.logo().copyWith(fontSize: 24)))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: ListenableBuilder(listenable: c, builder: (context, _) => HeroPage(controller: c))),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, k = s.knight, hurt = k.hp < maxHp(k);
      final job = c.onHobsJob, ready = c.innReady, offered = c.jobOffered, phone = isPhone(context);
      final labels = {
                            TownSpot.gate: s.inBattle ? 'Back to the fight' : (s.wild != null ? 'The Wilds' : 'Set out'),
                            TownSpot.stall: s.raid == 'stall' ? 'Mags\' Stall · Raided!' : 'Mags\' Stall',
                            TownSpot.inn: (hurt || !s.day) && c.whyNotRest == null && !job && !offered ? (hurt ? 'Soot & Kettle · Rest' : 'Soot & Kettle · Sleep') : 'Soot & Kettle',
                            TownSpot.tent: unspentPoints(k) > 0 ? 'Your ${homes[s.home].name} · +${unspentPoints(k)}' : 'Your ${homes[s.home].name}',
                            TownSpot.forge: '$smithName\'s Forge',
                            TownSpot.enchanter: '$mageName\'s Tower',
                          };
      final taps = <TownSpot, VoidCallback?>{
                            TownSpot.gate: s.inBattle ? _resume : (offered ? _talk : (s.wild != null ? _openWilds : _openMap)),
                            TownSpot.stall: s.inBattle ? null : () => showMerchantWindow(context, c),
                            TownSpot.inn: () => visitInn(context, c, onHunt: _hunt),
                            TownSpot.tent: _openKit,
                            TownSpot.forge: s.inBattle ? null : () => showForgeWindow(context, c),
                            TownSpot.enchanter: s.inBattle ? null : () => showEnchanterWindow(context, c),
                          };
      return Scaffold(
        body: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                child: RepaintBoundary(child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: fitWidth(context, aspect: 2, below: 230, chrome: 130)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (phone) ...[
                          Row(
                            children: [
                              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: HeroCard(controller: c))),
                              IconButton(
                                tooltip: 'Settings',
                                onPressed: () => showDialog<void>(context: context, builder: (_) => _SettingsWindow(controller: c)),
                                icon: const Icon(Icons.settings, color: Palette.parch, size: 26),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        _TownSquare(
                          compact: phone,
                          hud: HeroCard(controller: c),
                          onSettings: () => showDialog<void>(context: context, builder: (_) => _SettingsWindow(controller: c)),
                          look: heroLook(k),
                          repaired: s.innRepaired,
                          quest: offered ? 1 : (ready ? 2 : (job ? 3 : 0)),
                          raid: s.raid,
                          home: s.home,
                          hallowash: c.season == Season.hallowash,
                          time: !s.day ? InnSky.night : (s.won ? InnSky.clearDay : InnSky.ashDay),
                          subtitle: c.season == Season.hallowash ? 'Hallowash in the square' : s.won ? 'The Ember King is gone. The ash is settling.' : (s.innRepaired ? 'The square, by the Soot & Kettle' : 'The square, still smoking'),
                          labels: labels,
                          onTap: taps,
                        ),
                        if (phone) ...[
                          const SizedBox(height: 8),
                          // The six places as big buttons under the scene, where thumbs reach.
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.6,
                            children: [
                              for (final spot in const [TownSpot.gate, TownSpot.inn, TownSpot.stall, TownSpot.forge, TownSpot.enchanter, TownSpot.tent])
                                _PlaceButton(icon: _TownSquareState._icons[spot]!, label: labels[spot]!, onTap: taps[spot], hot: spot == TownSpot.gate, ready: (spot == TownSpot.forge && c.engine.forgeReady) || (spot == TownSpot.enchanter && c.engine.gemsWaiting)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (s.inBattle) ...[
                          _ResumeBanner(controller: c, onTap: _resume),
                          const SizedBox(height: 10),
                        ],
                        if (s.raid != null && !s.inBattle) ...[
                          _Banner(
                            icon: Icons.warning_amber_rounded,
                            text: s.raid == 'inn' ? 'Bandits robbed the Soot & Kettle!' : 'Bandits raided Mags\' stall!',
                            button: 'Chase',
                            onTap: _chase,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (offered) ...[
                          _TalkBanner(onTap: _talk),
                          const SizedBox(height: 10),
                        ],
                        if (job) ...[
                          _QuestCard(
                            timber: s.timber,
                            iron: s.ironScrap,
                            ready: ready,
                            onTap: ready ? _talk : _hunt,
                            onOpen: _talk,
                            nudge: ready || (s.wins[0] == 0 && s.timber == 0),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (c.nextLoot != null) ...[
                          _Banner(icon: Icons.inventory_2, text: c.nextLoot!.name, button: 'Open', onTap: () => resolvePendingLoot(context, c)),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                        _LogPanel(entries: s.journal, onStory: _showStory),
                      ],
                    ),
                  ),
                )),
              ),
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
                      Text(foe.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 16, color: colour, weight: FontWeight.w800)),
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
  const _QuestCard({required this.timber, required this.iron, required this.ready, required this.onTap, required this.onOpen, this.nudge = false});
  final int timber, iron;
  final bool ready;

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
        ItemIcon(item, size: 30),
        const SizedBox(width: 6),
        for (var i = 0; i < need; i++)
          Container(
            width: 13,
            height: 13,
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
          QuestMark(ready: ready, size: 38),
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
                Text('Mend the Soot & Kettle', style: Txt.label(size: 18, color: Palette.cream, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(spacing: 18, runSpacing: 6, children: [_need(Item.timber, 'Charred timber', timber, timberNeeded), _need(Item.iron, 'Iron scrap', iron, ironNeeded)]),
                const SizedBox(height: 8),
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
  const _LogPanel({required this.entries, required this.onStory});
  final List<JournalEntry> entries;
  final VoidCallback onStory;
  @override
  State<_LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<_LogPanel> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final last = widget.entries.isEmpty ? null : widget.entries.last;
    return Parchment(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                const Icon(Icons.history_edu, color: Palette.inkSoft, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: _open
                      ? Text('Adventure log', style: Txt.inkLabel(size: 15))
                      : Text(last?.text ?? 'Nothing yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.body(size: 14, color: Palette.inkSoft)),
                ),
                IconButton(tooltip: 'The story so far', onPressed: widget.onStory, icon: const Icon(Icons.menu_book, color: Palette.blood, size: 20)),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: Palette.inkSoft),
                const SizedBox(width: 6),
              ],
            ),
          ),
          if (_open) Padding(padding: const EdgeInsets.only(right: 6, bottom: 6), child: JournalEntryList(entries: widget.entries)),
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
  const _TownSquare({required this.hud, required this.onSettings, required this.look, required this.repaired, required this.quest, required this.subtitle, required this.labels, required this.onTap, this.raid, this.time = InnSky.night, this.home = 0, this.hallowash = false, this.compact = false});

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
  TownSpot? _hover;

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
                Positioned.fill(child: _InnScene(look: widget.look, repaired: widget.repaired, quest: widget.quest, hover: _hover, raid: widget.raid, time: widget.time, home: widget.home, hallowash: widget.hallowash)),
                for (final e in townSpots.entries)
                  Positioned.fromRect(
                    rect: place(e.value),
                    child: MouseRegion(
                      cursor: widget.onTap[e.key] != null ? SystemMouseCursors.click : MouseCursor.defer,
                      onEnter: (_) => setState(() => _hover = e.key),
                      onExit: (_) => setState(() => _hover = _hover == e.key ? null : _hover),
                      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap[e.key]),
                    ),
                  ),
                // A sign over each place, always showing, lit when pointed at.
                if (!widget.compact)
                  for (final e in townSpots.entries)
                  Positioned(
                    left: (place(e.value).center.dx - 110).clamp(-50.0, box.maxWidth - 170),
                    width: 220,
                    top: math.max(4, place(e.value).top - 30),
                    // The sign is a way in too: point at it and its place lights up; click it to go.
                    child: Center(
                      child: MouseRegion(
                        cursor: widget.onTap[e.key] != null ? SystemMouseCursors.click : MouseCursor.defer,
                        onEnter: (_) => setState(() => _hover = e.key),
                        onExit: (_) => setState(() => _hover = _hover == e.key ? null : _hover),
                        child: GestureDetector(
                          onTap: widget.onTap[e.key],
                          child: _Sign(icon: _icons[e.key]!, text: widget.labels[e.key] ?? '', lit: _hover == e.key, off: widget.onTap[e.key] == null),
                        ),
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
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 13, color: lit ? Colors.white : Palette.cream))),
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
    paintHome(canvas, t, home);
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
                'Six continents and their bosses stand between you and his Ember Throne.',
                style: Txt.onStone(size: 14.5, color: Palette.cream),
              ),
              const SizedBox(height: 12),
              for (final (icon, colour, text) in const [
                (Icons.explore, Palette.amber, 'Set out, pick a land, fight what turns up'),
                (Icons.sports_kabaddi, Color(0xFFE07A5A), 'Blade, Rites, Crossbow, Potion: keys 1 to 7'),
                (Icons.flight, Color(0xFF8FC3D9), 'Flyers and casters? Crossbow or Rites'),
                (Icons.inventory_2, Palette.amber, 'Every win drops gear'),
                (Icons.workspace_premium, Color(0xFFFFD98A), 'Win $winsForBoss fights to find the boss'),
                (Icons.local_fire_department, Color(0xFFFF8A3A), 'Rest at the inn to heal, free'),
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
    Navigator.of(context).pop();
    await c.newAdventure();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, k = c.state.knight;
    return Dialog(
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
              _toggle('Sell junk where it falls', Icons.sell_rounded, _s.autoSellJunk, (v) => _set((s) => s.autoSellJunk = v)),
              _toggle('Mute all', Icons.volume_off_rounded, _s.muted, (v) => _set((s) => s.muted = v)),
              _slider(Icons.music_note_rounded, _s.music, (v) => _set((s) => s.music = v)),
              _slider(Icons.volume_up_rounded, _s.sound, (v) => _set((s) => s.sound = v), onEnd: () => Audio.play(Sfx.hit)),
              const SizedBox(height: 6),
              StoneButton(
                title: 'Save',
                tone: ButtonTone.blood,
                onPressed: () {
                  c.applySettings(_s);
                  c.setName(_name.text);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 14),
              _CloudSection(controller: c),
              const SizedBox(height: 6),
              TextButton(onPressed: _newHero, child: Text('Start a new hero…', style: Txt.label(size: 13, color: const Color(0xFFE07A5A)))),
            ],
          )),
          ),
        ),
      ),
    );
  }
}

/// One of the town's places as a big button (on a phone, under the scene).
class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.icon, required this.label, this.onTap, this.hot = false, this.ready = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The main way onward (Set out): lit up.
  final bool hot;

  /// Something's waiting there for you (ore to smelt, gems to grind): a little amber light.
  final bool ready;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .5 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: stoneDecoration(fill: hot ? Palette.bloodDeep : Palette.stone2),
          child: Row(
            children: [
              Icon(icon, size: 24, color: hot ? const Color(0xFFFFE0C0) : Palette.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.label(size: 14, color: Palette.cream, weight: FontWeight.w800)),
              ),
              if (ready)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.amber, boxShadow: [BoxShadow(color: Palette.amber.withValues(alpha: .7), blurRadius: 6)]),
                ),
            ],
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
