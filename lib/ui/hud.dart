// Pieces shared by the Inn, map and battle screens: the stats header (HP, XP, level), status
// badges, the crest and still portraits of foes.

import 'package:flutter/material.dart';

import '../art/beast_foes.dart';
import '../art/body.dart';
import '../art/creatures.dart';
import '../art/hounds.dart';
import '../art/kraken.dart';
import '../art/looks.dart';
import '../art/rare_looks.dart';
import '../art/poses.dart';
import '../art/rig.dart';
import '../game/ammo.dart';
import '../game/brews.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/loot.dart' show specialCharge;
import '../game/models.dart';
import '../game/rules.dart';
import '../game/spells.dart';
import 'item_icons.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

/// Your character in the corner of the game window: portrait and level, HP and XP bars, potions
/// and gold, and (in a fight) mana. Sits over the scene, like the hero card in AdventureQuest.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.controller, this.mana = false, this.compact = false});
  final GameController controller;

  /// A slimmer card (smaller face, no XP bar) where the scene needs the room.
  final bool compact;

  /// Show the mana pips (in battle).
  final bool mana;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, mh = maxHp(k), hp = controller.shownHeroHp.clamp(0, mh);
    // Smaller on a phone so it doesn't cover the scene.
    // Smaller in a mid-size window; on a phone the page shrinks it to fit its own spot instead.
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w < 640 && w >= 600 ? .78 : 1.0) * (compact ? .8 : 1);
    final card = Container(
      width: compact ? 250 : 300,
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE63A3024), Color(0xE61A1510)]),
        border: Border.all(color: Palette.amberLo, width: 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The face, with the level on a badge at its foot.
          Stack(
            clipBehavior: Clip.none,
            children: [
              HeroPortrait(look: heroLook(k), size: compact ? 48 : 66, signature: portraitSignature(k)),
              Positioned(right: -6, bottom: -6, child: _LevelBadge(level: k.level, size: 28)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.settings.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 15, color: Palette.cream, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Tooltip(message: 'Health', child: Bar(value: hp, max: mh, height: 14, colours: const [Color(0xFFE0604A), Color(0xFF8E2117)], label: 'HP ${fmt(hp)} / ${fmt(mh)}')),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Tooltip(message: 'Experience to level ${k.level + 1}', child: Bar(value: k.xp, max: xpToNext(k), height: 6, colours: const [Color(0xFFF3C878), Color(0xFF9B6A22)])),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Tooltip(message: 'Health potions', child: Row(children: [const ItemIcon(Item.potion, size: 18), const SizedBox(width: 3), Text('${k.potions}', style: Txt.label(size: 14, color: Palette.cream))])),
                    const SizedBox(width: 12),
                    Tooltip(message: 'Gold', child: Row(children: [const ItemIcon(Item.coins, size: 18), const SizedBox(width: 3), Text(fmt(k.coins), style: Txt.label(size: 14, color: Palette.amber))])),
                    const Spacer(),
                    if (mana)
                      Tooltip(
                        message: 'Mana: each attack, bash or shot gathers 1; rites spend it',
                        child: Row(
                          children: [
                            for (var i = 0; i < maxMana; i++)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(left: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < s.mana ? const Color(0xFF6AC8FF) : const Color(0xFF15202A),
                                  border: Border.all(color: const Color(0xFF9ADFFF), width: 1),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return scale == 1 ? card : Transform.scale(scale: scale, alignment: Alignment.topLeft, child: card);
  }
}

/// A slim bar that slides to its new value, with an optional label written inside it.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, required this.max, required this.colours, this.height = 12, this.label});
  final int value, max;
  final List<Color> colours;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: const Color(0xFF0E0B08), border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(2)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                widthFactor: f,
                heightFactor: 1,
                child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colours))),
              ),
            ),
          ),
          if (label != null)
            Center(
              child: Text(
                label!,
                style: Txt.label(size: height * .78, color: Colors.white).copyWith(height: 1, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
        ],
      ),
    );
  }
}

/// A head-and-shoulders portrait of any figure, in a round frame lit like the fire behind them.
class HeroPortrait extends StatelessWidget {
  const HeroPortrait({super.key, required this.look, this.size = 64, this.signature});
  final Look look;
  final double size;

  /// What the portrait shows, as a string (gear, dye, level): when it hasn't changed, the portrait
  /// isn't redrawn, however often the page around it rebuilds.
  final String? signature;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Palette.amber, width: 2),
      gradient: const RadialGradient(center: Alignment(.3, -.2), colors: [Color(0xFF8A4A22), Color(0xFF2A160C)]),
    ),
    child: ClipOval(child: RepaintBoundary(child: CustomPaint(painter: _PortraitPainter(look, signature)))),
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.look, this.signature);
  final Look look;
  final String? signature;
  @override
  void paint(Canvas canvas, Size size) {
    final h = builds[look.build]!.height;
    final scale = size.height / h * 2.7;
    // Arms down and back so nothing crosses the face.
    final pose = Pose.of({J.head: -2, J.nS: -34, J.nE: 20, J.fS: 8, J.fE: 40});
    drawHumanoid(
      canvas,
      look,
      pose,
      0,
      DrawOptions(at: Offset(size.width * .5, size.height + h * scale * .7), scale: scale, shadow: false),
      still: true,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => signature == null ? old.look != look : old.signature != signature;
}

/// The foe's card, opposite yours: name and level, an HP bar, and what to watch for as little
/// game badges (rank, kind, loot perk; what it's weak to and shrugs off; how hard it hits).
class FoeCard extends StatelessWidget {
  const FoeCard({super.key, required this.name, required this.colour, required this.hp, required this.maxHp, required this.level, this.tags = const [], this.badges = const [], this.fill = false});

  /// On a phone: fills the space it's given (beside your own card) instead of its usual width,
  /// with its tags and badges run together to keep it short.
  final bool fill;
  final String name;
  final Color colour;
  final int hp, maxHp, level;

  /// What it is: rank, kind, loot perk.
  final List<Widget> tags;

  /// How to fight it: weak to, shrugs off, how hard it hits, any hazard.
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = w < 640 && w >= 600 ? .78 : 1.0;
    final card = Container(
      width: fill ? double.infinity : 260,
      padding: fill ? const EdgeInsets.fromLTRB(7, 5, 7, 6) : const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE63A2420), Color(0xE61A1010)]),
        border: Border.all(color: const Color(0xFF8E3A2A), width: 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: Txt.label(size: fill ? 13.5 : 15, color: colour, weight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10), border: Border.all(color: Palette.parch.withValues(alpha: .4))),
                child: Text('Lv $level', style: Txt.label(size: 12, color: Palette.parch, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Bar(value: hp, max: maxHp, height: 14, colours: const [Color(0xFF7FCB5A), Color(0xFF2F6A1F)], label: '${fmt(hp)} / ${fmt(maxHp)}'),
          if (fill && tags.length + badges.length > 0)
            Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 3, runSpacing: 3, children: [...tags, ...badges]))
          else ...[
            if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Wrap(spacing: 4, runSpacing: 4, children: tags)),
            if (badges.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 4, runSpacing: 4, children: badges)),
          ],
        ],
      ),
    );
    return scale == 1 || fill ? card : Transform.scale(scale: scale, alignment: Alignment.topRight, child: card);
  }
}

/// On a phone in battle: your side in a slim strip (name and level, HP, mana) to sit beside the
/// foe's card, so the fight itself gets the screen.
class HeroStrip extends StatelessWidget {
  const HeroStrip({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, mh = maxHp(k), hp = controller.shownHeroHp.clamp(0, mh);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE63A3024), Color(0xE61A1510)]),
        border: Border.all(color: Palette.amberLo, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.settings.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 13.5, color: Palette.cream, weight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10), border: Border.all(color: Palette.amberLo)),
                child: Text('Lv ${k.level}', style: Txt.label(size: 12, color: Palette.amber, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Tooltip(message: 'Health', child: Bar(value: hp, max: mh, height: 14, colours: const [Color(0xFFE0604A), Color(0xFF8E2117)], label: '${fmt(hp)} / ${fmt(mh)}')),
          const SizedBox(height: 5),
          Tooltip(
            message: 'Mana: each attack, bash or shot gathers 1; rites spend it',
            child: Row(
              children: [
                for (var i = 0; i < maxMana; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < s.mana ? const Color(0xFF6AC8FF) : const Color(0xFF15202A),
                      border: Border.all(color: const Color(0xFF9ADFFF), width: 1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small badge on the foe card: an optional word, then icons or a figure, edged in [colour].
/// [tip] says it in full on hover.
class FoeBadge extends StatelessWidget {
  const FoeBadge({super.key, this.label, this.icons = const [], this.text, required this.colour, this.tip, this.solid = false});
  final String? label, text, tip;
  final List<Widget> icons;
  final Color colour;

  /// Filled in its colour (rank tags: RARE, BOSS).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: solid ? colour.withValues(alpha: .22) : Colors.black.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(solid ? 4 : 11),
        border: Border.all(color: colour.withValues(alpha: solid ? .8 : .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) Text(label!, style: Txt.label(size: solid ? 11 : 11.5, color: colour, weight: FontWeight.w800)),
          for (final (i, icon) in icons.indexed) Padding(padding: EdgeInsets.only(left: i == 0 && label == null ? 0 : 4), child: SizedBox(width: 15, height: 15, child: Center(child: icon))),
          if (text != null) Padding(padding: EdgeInsets.only(left: icons.isEmpty && label == null ? 0 : 4), child: Text(text!, style: Txt.label(size: 12, color: Palette.cream, weight: FontWeight.w800))),
        ],
      ),
    );
    // On a phone there's no hover: a tap shows the tip.
    return tip == null ? badge : Tooltip(message: tip!, triggerMode: isPhone(context) ? TooltipTriggerMode.tap : null, showDuration: const Duration(seconds: 3), child: badge);
  }
}

/// HP, XP and level, always at the top of the screen.
class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key, required this.controller, this.onSettings, this.leading});
  final GameController controller;
  final VoidCallback? onSettings;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, mh = maxHp(k), hp = controller.shownHeroHp.clamp(0, mh);
    Widget chip(Widget child) => DecoratedBox(
      decoration: stoneDecoration(fill: Palette.stone1, raised: false),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: child),
    );
    return Container(
      decoration: const BoxDecoration(
        color: Palette.stone2,
        border: Border(bottom: BorderSide(color: Palette.stone0, width: 2)),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF443B2E), Palette.stone1]),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 4),
                  ] else ...[
                    const SizedBox(width: 22, height: 27, child: CustomPaint(painter: CrestPainter())),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      s.settings.name,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.label(size: 17, weight: FontWeight.w800),
                    ),
                  ),
                  _LevelBadge(level: k.level),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Health potions',
                    child: chip(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [const ItemIcon(Item.potion, size: 20), const SizedBox(width: 4), Text('${k.potions}', style: Txt.label(size: 15, color: Palette.cream))],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Gold',
                    child: chip(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [const ItemIcon(Item.coins, size: 20), const SizedBox(width: 4), Text(fmt(k.coins), style: Txt.label(size: 15, color: Palette.amber))],
                      ),
                    ),
                  ),
                  if (onSettings != null)
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: onSettings,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.settings, color: Palette.parch, size: 22),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Meter(label: 'HP', value: hp, max: mh, colours: const [Color(0xFFD0503F), Color(0xFF8E2117)]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Meter(label: 'XP', value: k.xp, max: xpToNext(k), colours: const [Color(0xFFE9B960), Color(0xFF9B6A22)]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, this.size = 40});
  final int level;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Level $level',
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF5A4E3E), Palette.stone0]),
        border: Border.all(color: Palette.amber, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (size >= 34) Text('LV', style: Txt.label(size: 9, color: Palette.amber)),
          Text('$level', style: Txt.label(size: size * .42, weight: FontWeight.w800).copyWith(height: 1)),
        ],
      ),
    ),
  );
}

/// Small badges for status effects, poison, the dragon and Peaceful mode.
class StatusBadges extends StatelessWidget {
  const StatusBadges({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final k = state.knight, ds = dragonStage(k), move = k.loadouts[k.heroClass]!.weapon?.specialMove, pet = petStage(k);
    final items = <(String, Color, String)>[
      if (move != null)
        (
          '${move.name} ${'●' * state.specialCharge}${'○' * (specialCharge - state.specialCharge)}',
          Color(move.argb),
          'Special attack: ${move.desc}. Charges with each attack and fires on the ${specialCharge}th.',
        ),
      if (k.poisonFights > 0) ('Poisoned blade · ${k.poisonFights}', const Color(0xFF9BE27A), 'Poison on every attack for ${k.poisonFights} more ${k.poisonFights == 1 ? 'fight' : 'fights'}'),
      for (final (b, left) in activeBrews(k))
        (
          b == Brew.reaperbane ? b.badge : '${b.badge} · $left',
          Color(b.argb),
          b == Brew.reaperbane ? b.desc : '${b.label}: ${b.desc.replaceAll(' for $brewFights fights', '')} ($left more ${left == 1 ? 'fight' : 'fights'})',
        ),
      if (ds != null) ('${ds.name}${ds.chip > 0 ? ' +${ds.chip}' : ''}', const Color(0xFFF4955F), 'Your dragon companion'),
      if (pet != null)
        (
          '${pet.$2.name} +${pet.$2.bite}',
          switch (pet.$1) {
            Pet.hellhound => const Color(0xFFFF7A2A),
            Pet.wolf => const Color(0xFFC8C4BC),
            Pet.fairy => const Color(0xFFE6B8FF),
          },
          pet.$1 == Pet.fairy ? 'Your fairy strikes with every attack and casts a charm every ${pet.$2.charm} attacks' : 'Your companion bites with every attack',
        ),
      if (ammoById(k.ammoLoaded) != null)
        (
          '${ammoById(k.ammoLoaded)!.label(Missile.bolt)} ×${k.ammo[k.ammoLoaded] ?? 0}',
          Color(ammoById(k.ammoLoaded)!.argb),
          '${ammoById(k.ammoLoaded)!.desc}: one per crossbow shot',
        ),
      if (state.inBattle && state.wolfTurns > 0) ('Wolfform · ${state.wolfTurns}', const Color(0xFFFF6A5A), 'The Bloodmoon Pelt: you hit ${((wolfDamage - 1) * 100).round()}% harder, heal ${(wolfHeal * 100).round()}% of what you deal, and take ${((1 - wolfHide) * 100).round()}% less'),
      if (wearsPelt(k) && !state.wolfUsed && (!state.inBattle || state.wolfTurns == 0)) ('Bloodmoon Pelt', const Color(0xFFC8302A), 'Under ${(wolfAt * 100).round()}% health, the wolf comes out for ${wolfTurnsFor(k)} turns (once a fight)'),
      if (state.summons > 0) ('Skeletons ×${state.summons} · ${state.summonTurns} turns', const Color(0xFFC89AFF), 'Your summoned dead strike with you'),
      if (state.wards > 0) ('Ward ×${state.wards}', const Color(0xFF7FB8E8), 'Absorbs the foe\'s next blow'),
      if (state.mirror > 0) ('Mirror ×${state.mirror}', const Color(0xFFCFE8F8), 'You take half; the foe takes the whole blow back'),
      if (state.inBattle && state.foeAsleep > 0) ('Foe asleep', const Color(0xFFB8A0E8), 'It sleeps through its next blow'),
      if (state.inBattle && state.foeSlowed > 0) ('Foe slowed · ${state.foeSlowed}', const Color(0xFF6ABF9A), 'Half its blows miss'),
      if (state.inBattle && state.foeWeakened > 0) ('Foe weakened · ${state.foeWeakened}', const Color(0xFFB8A0D8), 'Its blows land 40% softer'),
      if (state.inBattle && state.foeExposed > 0) ('Foe exposed · ${state.foeExposed}', const Color(0xFFE0A050), 'Your hits deal 25% more'),
    ];
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final (label, colour, tip) in items)
          Tooltip(
            message: tip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xC70F0C09),
                border: Border.all(color: Palette.stone3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(label, style: Txt.label(size: 12, color: colour)),
            ),
          ),
      ],
    );
  }
}

/// A still picture of a foe, scaled to fit its box.
class FoePortrait extends StatelessWidget {
  const FoePortrait({super.key, required this.foeIndex, this.rare});
  final int foeIndex;

  /// A rare variant standing in for the regular foe.
  final Rare? rare;
  @override
  Widget build(BuildContext context) => TypePortrait(type: encounterType(foeIndex, rare));
}

/// A still picture of any foe type (rare variants and World Bosses included).
class TypePortrait extends StatelessWidget {
  const TypePortrait({super.key, required this.type});
  final FoeType type;
  @override
  Widget build(BuildContext context) {
    if (type.hound) return CustomPaint(painter: _HoundPortrait());
    if (type.dragon) return CustomPaint(painter: _DragonPortrait(dragonLookOf(type)));
    if (isSeaLook(type.look) || isBeastLook(type.look)) return CustomPaint(painter: _BeastPortrait(type));
    return CustomPaint(painter: _FoePainter(foeLookOf(type)));
  }
}

class _HoundPortrait extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = size.height / 92 * 1.1;
    canvas.translate(size.width * .7, size.height * .98);
    canvas.scale(-1, 1);
    drawHound(canvas, demonHoundLook, Offset.zero, scale, 0, still: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HoundPortrait old) => false;
}

/// Wolves, bears, spiders, unicorns, centaurs (rider and all) and the kraken, fitted to the box.
class _BeastPortrait extends CustomPainter {
  _BeastPortrait(this.type);
  final FoeType type;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (isSeaLook(type.look)) {
      final k = size.height / seaHeight(type.look);
      canvas.translate(size.width / 2, size.height * .98);
      canvas.scale(k);
      drawSeaBeast(canvas, type.look, Offset.zero, 1, 0, still: true);
    } else {
      final h = beastHeight(type.look), w = h * (type.look.startsWith('spider') ? 2.6 : 1.7);
      final k = size.height * .92 / h < size.width * .95 / w ? size.height * .92 / h : size.width * .95 / w;
      canvas.translate(size.width / 2, size.height * .97);
      canvas.scale(k);
      drawBeastFoe(canvas, type.look, Offset.zero, 0, still: true, rider: type.look.startsWith('centaur') ? foeLookOf(type) : null);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeastPortrait old) => old.type != type;
}

/// A big, plain way home: a stone button with a little house and "Inn".
class InnBackButton extends StatelessWidget {
  const InnBackButton({super.key, required this.onPressed, this.label = 'Inn', this.icon = Icons.cottage});
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .45 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(3),
        child: Ink(
          decoration: stoneDecoration(fill: Palette.stone3),
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chevron_left, color: Palette.parch, size: 22),
              Icon(icon, color: Palette.amber, size: 22),
              const SizedBox(width: 6),
              Text(label, style: Txt.label(size: 15, color: Palette.cream, weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DragonPortrait extends CustomPainter {
  _DragonPortrait(this.look);
  final DragonLook look;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Head and shoulders fill the frame.
    final scale = size.height / (dragonHeight * look.scale) * 1.05;
    drawFoeDragon(canvas, look, Offset(size.width * .78, size.height * .98), scale, 0, still: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DragonPortrait old) => old.look != look;
}

/// A still picture of any foe look (used for raid bosses).
class LookPortrait extends StatelessWidget {
  const LookPortrait({super.key, required this.look});
  final Look look;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FoePainter(look));
}

class _FoePainter extends CustomPainter {
  _FoePainter(this.look);
  final Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final h = builds[look.build]!.height * look.scale * 1.15;
    final scale = (size.height * .92) / h;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawHumanoid(
      canvas,
      look,
      stances[look.stance]!,
      0,
      DrawOptions(at: Offset(size.width * .5, size.height * .97), scale: scale * look.scale, flip: true, shadow: false),
      still: true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoePainter old) => old.look != look;
}

/// Scorched Knight's crest: a shield with a flame on it.
class CrestPainter extends CustomPainter {
  const CrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shield = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * .45)
      ..quadraticBezierTo(w, h * .85, w / 2, h)
      ..quadraticBezierTo(0, h * .85, 0, h * .45)
      ..close();
    canvas.drawPath(shield, Paint()..color = const Color(0xFF3A2A20));
    canvas.drawPath(shield, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Palette.amber);
    final cx = w / 2;
    final flame = Path()
      ..moveTo(cx, h * .82)
      ..quadraticBezierTo(cx - w * .32, h * .7, cx - w * .22, h * .42)
      ..quadraticBezierTo(cx - w * .12, h * .3, cx - w * .06, h * .14)
      ..quadraticBezierTo(cx, h * .3, cx + w * .06, h * .34)
      ..quadraticBezierTo(cx + w * .12, h * .22, cx + w * .2, h * .12)
      ..quadraticBezierTo(cx + w * .34, h * .45, cx + w * .24, h * .64)
      ..quadraticBezierTo(cx + w * .16, h * .8, cx, h * .82)
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFE0582A));
    final inner = Path()
      ..moveTo(cx, h * .76)
      ..quadraticBezierTo(cx - w * .14, h * .68, cx - w * .08, h * .5)
      ..quadraticBezierTo(cx + w * .02, h * .54, cx + w * .06, h * .44)
      ..quadraticBezierTo(cx + w * .16, h * .64, cx, h * .76)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFF6C34A));
  }

  @override
  bool shouldRepaint(CrestPainter old) => false;
}

/// Your ways of fighting, as the triangle names them.
String styleName(AttackStyle s) => switch (s) {
  AttackStyle.blade => 'blades',
  AttackStyle.rite => 'rites',
  AttackStyle.bolt => 'the crossbow',
};

/// Each kind of foe's colour and symbol on its card and portrait.
Color kindColour(FoeKind k) => switch (k) {
  FoeKind.armoured => const Color(0xFFB8C4D0),
  FoeKind.caster => const Color(0xFFC89AFF),
  FoeKind.ranged => const Color(0xFF9BE27A),
  FoeKind.none => const Color(0xFFDDD0B1),
};

IconData kindIcon(FoeKind k) => switch (k) {
  FoeKind.armoured => Icons.shield,
  FoeKind.caster => Icons.auto_awesome,
  FoeKind.ranged => Icons.my_location,
  FoeKind.none => Icons.circle,
};

/// What a foe is weak to, in a few words for its card: the combat triangle and its own nature.
List<String> weakTo(FoeType f) => [
  if (f.kind != FoeKind.none) styleName(f.kind.weakTo!),
  if (f.aloft && f.kind.weakTo != AttackStyle.bolt) 'the crossbow',
  if ((f.stone || f.spirit) && f.kind.weakTo != AttackStyle.rite) 'rites',
  if (f.stone) 'hammers and maces',
  if (f.ent || f.regrows) 'fire',
  if (f.undead || f.demon || f.element == 'poison') 'holy fire',
  if (f.evasive && f.kind.weakTo != AttackStyle.rite) 'rites',
  if (f.element == 'burn') 'frost',
  if (f.element == 'frost') 'fire',
];

/// What it shrugs off.
List<String> shrugsOff(FoeType f) => [
  if (f.kind != FoeKind.none) styleName(f.kind.resists!),
  if ((f.aloft || f.stone || f.spirit) && f.kind.resists != AttackStyle.blade) 'blades',
  if (f.spirit && f.kind.resists != AttackStyle.bolt) 'bolts',
  if (f.venomous || f.ent) 'poison',
  if (f.demon || f.element == 'burn') 'fire',
  if (f.element == 'frost') 'frost',
  if (f.element == 'poison') 'poison',
  if (f.ironhide) 'critical hits',
  if (f.evasive && f.kind.resists != AttackStyle.blade) 'blades',
];
