// Painted heroes and gear, reused by the Hero tab, loot window, class picker and friends' sheets.


import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'cadence.dart';

import '../art/body.dart';
import '../art/silhouette.dart';
import '../art/gear_icons.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/rig.dart';
import '../game/catalog.dart' show sweepingWeapons;
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/models.dart' show Loadout;
import '../game/rules.dart' show dualStrikeShare;
import 'item_icons.dart';
import 'stat_icons.dart';
import 'theme.dart';

/// A full-length hero, optionally breathing. Fits the figure to its box.
class HeroFigure extends StatefulWidget {
  const HeroFigure({super.key, required this.look, this.animate = true, this.flip = false});
  final Look look;
  final bool animate, flip;

  @override
  State<HeroFigure> createState() => _HeroFigureState();
}

class _HeroFigureState extends State<HeroFigure> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HeroFigure old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final want = widget.animate && !(WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations);
    if (want && _ticker == null) {
      // Breathing and a cape in the breeze: smooth on a computer, half the work on a phone.
      _ticker = createTicker((e) {
        final ms = e.inMicroseconds / 1000.0;
        if (_cadence.tick(ms, fps: _phone ? 30 : 60)) _time.value = ms;
      })..start();
    } else if (!want && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  final _cadence = Cadence();
  bool _phone = false;

  @override
  Widget build(BuildContext context) {
    _phone = MediaQuery.sizeOf(context).shortestSide < 600;
    return _build();
  }

  Widget _build() => RepaintBoundary(
    child: CustomPaint(
      painter: _FigurePainter(widget.look, _time, still: _ticker == null, flip: widget.flip),
      size: Size.infinite,
    ),
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.look, this.time, {required this.still, required this.flip}) : super(repaint: time);
  final Look look;
  final ValueNotifier<double> time;
  final bool still, flip;

  @override
  void paint(Canvas canvas, Size size) {
    final b = builds[look.build]!;
    // Leave headroom for tall hats and staffs.
    final scale = size.height * .74 / b.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // A warm glow behind, and the figure as a silhouette rimmed in it.
    final centre = Offset(size.width * .5, size.height * .5);
    canvas.drawCircle(centre, size.height * .55, Paint()..shader = ui.Gradient.radial(centre, size.height * .55, [const Color(0x66FF9A50), const Color(0x00FF9A50)]));
    silhouette(
      canvas,
      Offset.zero & size,
      (c) => drawHumanoid(
        c,
        look,
        idlePose(look.stance, time.value, still: still),
        time.value,
        DrawOptions(at: Offset(size.width * (flip ? .56 : .44), size.height * .95), scale: scale, flip: flip),
        still: still,
      ),
      rim: const Color(0xFFFFB070),
      light: const Offset(1.4, -1.6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.look != look || old.still != still;
}

Color rarityColour(Rarity r) => Color(r.argb);

/// A square slot showing a piece of gear, framed in its rarity colour.
class GearIcon extends StatelessWidget {
  const GearIcon({super.key, required this.item, this.size = 52, this.heroClass, this.dye = 'crimson', this.empty});
  final GearItem? item;
  final double size;
  final HeroClass? heroClass;
  final String dye;

  /// Label for an empty slot.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final g = item, col = g == null ? Palette.stone3 : rarityColour(g.rarity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: col, width: g == null ? 1 : 2),
        gradient: RadialGradient(colors: [g == null ? Palette.stone1 : Color.lerp(Palette.stone1, col, .22)!, Palette.stone0]),
        boxShadow: g?.rarity == Rarity.legendary ? [BoxShadow(color: col.withValues(alpha: .5), blurRadius: 8)] : null,
      ),
      child: g == null
          ? Center(
              child: Text(empty ?? '', textAlign: TextAlign.center, style: Txt.label(size: 10, color: Palette.stoneHi)),
            )
          : CustomPaint(painter: _GearPainter(g, heroClass ?? g.heroClass ?? HeroClass.knight, dye)),
    );
  }
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.item, this.heroClass, this.dye);
  final GearItem item;
  final HeroClass heroClass;
  final String dye;

  @override
  void paint(Canvas canvas, Size size) => paintGearIcon(canvas, size, item, heroClass, dye);

  @override
  bool shouldRepaint(_GearPainter old) => old.item.id != item.id || old.dye != dye;
}

/// Item name in rarity colour with its slot and rarity underneath, and stat lines.
class GearDetails extends StatelessWidget {
  const GearDetails({super.key, required this.item, this.compare, this.dense = false, this.kit});
  final GearItem item;

  /// The kit it would join, to say what it pairs with and whether it would be used.
  final Loadout? kit;

  /// What it would replace; stat changes are shown against it.
  final GearItem? compare;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final g = item, col = rarityColour(g.rarity);
    final stats = <Stat>{...g.stats.keys, ...?compare?.stats.keys}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final chips = <Widget>[
      for (final s in stats)
        if (g.stat(s) > 0) StatChip(stat: s, value: g.stat(s), delta: compare == null ? 0 : g.stat(s) - compare!.stat(s), dense: dense),
      // What you'd give up by swapping, after what you'd get.
      if (compare != null)
        for (final s in stats)
          if (g.stat(s) <= 0 && compare!.stat(s) > 0) StatChip(stat: s, value: compare!.stat(s), lost: true, dense: dense),
      ..._pairChips(g),
      if (materialOf(g) case (final name, final tier))
        InfoChip(icon: Icon(Icons.hardware, size: dense ? 14 : 16, color: Palette.parch2), text: '$name ${'●' * tier}${'○' * (6 - tier)}', dense: dense),
    ];
    final note = Txt.onStone(size: dense ? 12.5 : 13.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(g.name, style: Txt.label(size: dense ? 15 : 17, color: col, weight: FontWeight.w800)),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: col.withValues(alpha: .2), borderRadius: BorderRadius.circular(3), border: Border.all(color: col.withValues(alpha: .7))),
              child: Text(g.rarity.label.toUpperCase(), style: Txt.label(size: 10.5, color: col, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${g.slot.label}${g.heroClass == null ? '' : ' · ${g.heroClass!.label}'} · Lv ${g.level}', style: Txt.onStone(size: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(spacing: 5, runSpacing: 5, children: chips),
        ..._pairWarnings(g),
        if (g.enchant != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('✦ ${g.enchant!.title}: ${g.enchant!.describe}', style: note.copyWith(color: const Color(0xFFC8A8F0), fontWeight: FontWeight.w700)),
          ),
        if (g.slot == GearSlot.cape && capeByAbility(g.special) != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('✦ ${capeByAbility(g.special)!.ability}.', style: note.copyWith(color: Palette.amber))),
        // Its set: the name, then what two and three pieces worn add, as chips.
        if (gearSetById(g.gearSet) case final set?) Padding(padding: const EdgeInsets.only(top: 8), child: SetChips(set: set, dense: dense)),
        if (g.specialMove != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('⚡ ${g.specialMove!.name}: ${g.specialMove!.desc}', style: note.copyWith(color: Color(g.specialMove!.argb), fontWeight: FontWeight.w700)),
          ),
        if (g.lore != null && !dense)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('"${g.lore}"', style: Txt.onStone(size: 13, color: Palette.amber).copyWith(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  /// What a weapon or off-hand pairs with, as chips.
  List<Widget> _pairChips(GearItem g) {
    final sz = dense ? 14.0 : 16.0;
    if (g.slot == GearSlot.weapon) {
      final want = offhandKindsFor(g.art);
      return [
        InfoChip(icon: Icon(Icons.flare, size: sz, color: const Color(0xFFFFC94A)), text: 'Crit ${weaponCrit(g)}% · ×${critMultiplier(g) == 2.5 ? '2.5' : '2'}', colour: const Color(0xFFFFDFA0), dense: dense),
        if (want.isEmpty)
          InfoChip(icon: Icon(Icons.back_hand, size: sz, color: Palette.parch2), text: 'Two-handed', dense: dense)
        else
          InfoChip(icon: ItemIcon(Item.shield, size: sz), text: want.map((w) => w.label[0].toUpperCase() + w.label.substring(1)).join(' / '), dense: dense),
        if (sweepingWeapons.contains(g.art)) Tooltip(message: 'A big swing hits the whole pack (wolf packs, war bands): +50% damage against them', child: InfoChip(icon: Icon(Icons.waves, size: sz, color: Palette.amber), text: '+50% vs packs', colour: Palette.amber, dense: dense)),
        if (want.contains(OffhandKind.parrying) && lightBlades.contains(g.art) || want.contains(OffhandKind.wand) || want.contains(OffhandKind.sidearm))
          InfoChip(icon: Icon(Icons.call_split, size: sz, color: Palette.parch2), text: 'Can dual wield', dense: dense),
      ];
    }
    if (g.slot == GearSlot.offhand) {
      final kind = offhandKindOf(g.art);
      if (kind == null) return const [];
      return [
        InfoChip(icon: ItemIcon(Item.swords, size: sz), text: 'With ${kind.weapons}', dense: dense),
        if (kind == OffhandKind.wand || kind == OffhandKind.sidearm || (kind == OffhandKind.parrying && g.heroClass != HeroClass.ranger))
          InfoChip(icon: Icon(Icons.call_split, size: sz, color: Palette.parch2), text: 'Off-hand +${(dualStrikeShare * 100).round()}%', dense: dense),
      ];
    }
    return const [];
  }

  /// A warning if it wouldn't work with the kit you have on.
  List<Widget> _pairWarnings(GearItem g) {
    final style = Txt.onStone(size: dense ? 12.5 : 13.5, color: const Color(0xFFE0A070));
    Widget warn(String t) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 1, right: 5), child: Icon(Icons.warning_amber, size: 16, color: Color(0xFFE0A070))),
          Expanded(child: Text(t, style: style)),
        ],
      ),
    );
    if (g.slot == GearSlot.weapon) {
      final off = kit?.offhand;
      return [if (off != null && !offhandWorksWith(g, off)) warn('Your ${off.name} won\'t be used with this')];
    }
    if (g.slot == GearSlot.offhand && offhandKindOf(g.art) != null) {
      final w = kit?.weapon;
      return [if (kit != null && !offhandWorksWith(w, g)) warn('Not used with your ${w?.name ?? 'bare hands'}')];
    }
    return const [];
  }
}

/// A small class emblem: crossed sword, star, or arrow.
class ClassEmblem extends StatelessWidget {
  const ClassEmblem(this.heroClass, {super.key, this.size = 22, this.colour = Palette.amber});
  final HeroClass heroClass;
  final double size;
  final Color colour;
  @override
  Widget build(BuildContext context) => Icon(
    switch (heroClass) {
      HeroClass.knight => Icons.shield_outlined,
      HeroClass.mage => Icons.auto_awesome,
      HeroClass.ranger => Icons.north_east,
    },
    size: size,
    color: colour,
  );
}

/// A gear set at a glance: its name, then a "2" row and a "3" row of what those pieces worn add
/// (stat chips, and the full set's special power in a few words).
class SetChips extends StatelessWidget {
  const SetChips({super.key, required this.set, this.dense = false, this.named = true, this.worn});
  final GearSet set;
  final bool dense;

  /// Pieces of it you're wearing: shown by its name, and the tiers not reached yet are dimmed.
  final int? worn;

  /// With its name on top (off where a heading already names it).
  final bool named;

  Widget _tier(String n, Map<Stat, int> stats, String? perk) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Opacity(opacity: worn == null || worn! >= int.parse(n) ? 1 : .4, child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 6, top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Palette.amber.withValues(alpha: .18), shape: BoxShape.circle, border: Border.all(color: Palette.amber.withValues(alpha: .7))),
          child: Text(n, style: Txt.label(size: 12, color: Palette.amber, weight: FontWeight.w900)),
        ),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final e in stats.entries) StatChip(stat: e.key, value: e.value, dense: true),
              if (perk != null) InfoChip(icon: const Icon(Icons.auto_awesome, size: 14, color: Palette.amber), text: perk, colour: Palette.amber, dense: true),
            ],
          ),
        ),
      ],
    )),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (named) Row(
        children: [
          const Icon(Icons.auto_awesome, size: 15, color: Palette.amber),
          const SizedBox(width: 5),
          Text('${set.name} set${worn == null ? '' : ' $worn/3'}', style: Txt.label(size: dense ? 13 : 14, color: Palette.amber, weight: FontWeight.w800)),
        ],
      ),
      _tier('2', set.two, null),
      _tier('3', set.three, set.perk),
    ],
  );
}
