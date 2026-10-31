// Game-style pictures for gear stats: each stat gets its own little icon and a two-word label, shown
// as a chip ("✝ +8 vs undead") instead of a sentence. Also the treasure chest drawn on Keep buttons.

import 'package:flutter/material.dart';

import '../game/loot.dart';
import 'item_icons.dart';
import 'theme.dart';

extension StatLook on Stat {
  /// The stat's colour: what its icon and chip edge are tinted.
  Color get colour => switch (this) {
    Stat.damage => const Color(0xFFFF9A7A),
    Stat.poison => const Color(0xFF8BE05A),
    Stat.burn => const Color(0xFFFF8A3A),
    Stat.frost => const Color(0xFF9ADFFF),
    Stat.bleed => const Color(0xFFE04A4A),
    Stat.smite => const Color(0xFFFFE27A),
    Stat.crit => const Color(0xFFFFC94A),
    Stat.lifesteal => const Color(0xFFFF6A7A),
    Stat.guard => const Color(0xFFB8C8D8),
    Stat.vigour => const Color(0xFFFF7A8A),
    Stat.regen => const Color(0xFFB8A0E8),
    Stat.thorns => const Color(0xFFC9A26A),
    Stat.fortune => const Color(0xFFFFD45A),
    Stat.wisdom => const Color(0xFF8AC8FF),
    Stat.dragonkin => const Color(0xFFFF6A2A),
    Stat.dodge => const Color(0xFFB8E0D0),
    Stat.parry => const Color(0xFFDDD0B1),
    Stat.block => const Color(0xFFC0C8D0),
    Stat.leech => const Color(0xFFC0303A),
    Stat.wyrmbane => const Color(0xFFFFA05A),
  };

  /// A couple of words after the number: "+8 vs undead", "+13% gold".
  String get short => switch (this) {
    Stat.damage => 'damage',
    Stat.poison => 'venom',
    Stat.burn => 'burn',
    Stat.frost => 'frost',
    Stat.bleed => 'bleed',
    Stat.smite => 'vs undead',
    Stat.crit => 'crit',
    Stat.lifesteal => 'HP per hit',
    Stat.guard => 'damage taken',
    Stat.vigour => 'max HP',
    Stat.regen => 'HP per win',
    Stat.thorns => 'thorns',
    Stat.fortune => 'gold',
    Stat.wisdom => 'XP',
    Stat.dragonkin => 'dragon\'s fire',
    Stat.dodge => 'dodge',
    Stat.parry => 'parry',
    Stat.block => 'block',
    Stat.leech => 'lifesteal',
    Stat.wyrmbane => 'vs dragons',
  };

  String amount(int v) => switch (this) {
    Stat.guard => '−$v%',
    _ => '+$v${percent ? '%' : ''}',
  };
}

/// The stat's picture.
class StatGlyph extends StatelessWidget {
  const StatGlyph(this.stat, {super.key, this.size = 18});
  final Stat stat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = stat.colour;
    Widget icon(IconData i) => Icon(i, size: size, color: c);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: switch (stat) {
          Stat.damage => ItemIcon(Item.swords, size: size),
          Stat.block => ItemIcon(Item.shield, size: size),
          Stat.fortune => ItemIcon(Item.coins, size: size),
          Stat.smite => CustomPaint(size: Size.square(size), painter: _HolyCross(c)),
          Stat.poison => icon(Icons.science),
          Stat.burn => icon(Icons.local_fire_department),
          Stat.frost => icon(Icons.ac_unit),
          Stat.bleed => icon(Icons.water_drop),
          Stat.crit => icon(Icons.flare),
          Stat.lifesteal => icon(Icons.favorite),
          Stat.guard => icon(Icons.shield),
          Stat.vigour => icon(Icons.monitor_heart),
          Stat.regen => icon(Icons.bedtime),
          Stat.thorns => icon(Icons.change_history),
          Stat.wisdom => icon(Icons.auto_stories),
          Stat.dragonkin => icon(Icons.whatshot),
          Stat.dodge => icon(Icons.air),
          Stat.parry => icon(Icons.compare_arrows),
          Stat.leech => icon(Icons.bloodtype),
          Stat.wyrmbane => icon(Icons.gps_fixed),
        },
      ),
    );
  }
}

/// A small glowing cross, for holy damage.
class _HolyCross extends CustomPainter {
  _HolyCross(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, bar = w * .22;
    final glow = Paint()..color = c.withValues(alpha: .25);
    canvas.drawCircle(Offset(w / 2, w * .42), w * .42, glow);
    final p = Paint()..color = c;
    final r = Radius.circular(bar * .3);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - bar / 2, w * .06, bar, w * .9), r), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .2, w * .28, w * .6, bar), r), p);
  }

  @override
  bool shouldRepaint(_HolyCross o) => o.c != c;
}

/// One stat as a chip: icon, number, a word or two, and (when comparing) how it changes.
/// A [lost] stat is one the current piece has and this one doesn't: struck through, in red.
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.stat, required this.value, this.delta = 0, this.lost = false, this.dense = false});
  final Stat stat;
  final int value, delta;
  final bool lost, dense;

  static const up = Color(0xFF9BE27A), down = Color(0xFFE07A6A);

  @override
  Widget build(BuildContext context) {
    // A stat you'd lose by swapping: no strike-through, just what goes, as a minus in red, on a
    // dim red chip, so it reads like the other changes.
    final edge = lost ? down : stat.colour;
    return Container(
      padding: EdgeInsets.fromLTRB(6, dense ? 2 : 3, 8, dense ? 2 : 3),
      decoration: BoxDecoration(
        color: lost ? const Color(0x33E07A6A) : Colors.black.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: edge.withValues(alpha: lost ? .6 : .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          lost
              ? ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFFE07A6A), BlendMode.srcIn), child: StatGlyph(stat, size: dense ? 15 : 17))
              : StatGlyph(stat, size: dense ? 15 : 17),
          const SizedBox(width: 5),
          Text(
            lost ? '−$value${stat.percent ? '%' : ''}' : stat.amount(value),
            style: Txt.label(size: dense ? 13 : 14.5, color: lost ? const Color(0xFFFF9A8A) : Palette.cream, weight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Text(stat.short, style: Txt.onStone(size: dense ? 12 : 13, color: lost ? const Color(0xFFE8A898) : Palette.parch2)),
          if (delta != 0 && !lost) ...[
            const SizedBox(width: 5),
            DeltaPill(delta, percent: stat.percent, dense: dense),
          ],
        ],
      ),
    );
  }
}

/// A plain chip for other facts about a piece: "Crit 12% · ×2", "Two-handed".
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.text, this.colour = Palette.parch2, this.dense = false, this.trailing});
  final Widget icon;
  final Widget? trailing;
  final String text;
  final Color colour;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(6, dense ? 2 : 3, 8, dense ? 2 : 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colour.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: dense ? 15 : 17, height: dense ? 15 : 17, child: Center(child: icon)),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: Txt.onStone(size: dense ? 12 : 13, color: colour).copyWith(fontWeight: FontWeight.w600))),
        if (trailing != null) ...[const SizedBox(width: 5), trailing!],
      ],
    ),
  );
}

/// A little treasure chest: wooden box, domed lid, iron bands and a gold lock.
class ChestIcon extends StatelessWidget {
  const ChestIcon({super.key, this.size = 26});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _Chest());
}

class _Chest extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .05
      ..color = const Color(0xFF1A0F06);
    final body = Rect.fromLTWH(w * .08, w * .42, w * .84, w * .48);
    final lid = Path()
      ..moveTo(w * .08, w * .44)
      ..lineTo(w * .08, w * .3)
      ..quadraticBezierTo(w * .5, w * .02, w * .92, w * .3)
      ..lineTo(w * .92, w * .44)
      ..close();
    canvas.drawRect(body, Paint()..color = const Color(0xFF8A5A2A));
    canvas.drawPath(lid, Paint()..color = const Color(0xFFA8703A));
    final band = Paint()..color = const Color(0xFF5A4A3A);
    canvas.drawRect(Rect.fromLTWH(w * .2, w * .16, w * .1, w * .74), band);
    canvas.drawRect(Rect.fromLTWH(w * .7, w * .16, w * .1, w * .74), band);
    canvas.drawRect(body, line);
    canvas.drawPath(lid, line);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .41, w * .36, w * .18, w * .2), Radius.circular(w * .03)), Paint()..color = const Color(0xFFFFD45A));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .41, w * .36, w * .18, w * .2), Radius.circular(w * .03)), line..strokeWidth = w * .035);
  }

  @override
  bool shouldRepaint(_Chest o) => false;
}

/// How much a stat goes up or down against what you have on: a little green or red pill with a
/// proper arrow (the font's own ▲ is too small to read).
class DeltaPill extends StatelessWidget {
  const DeltaPill(this.delta, {super.key, this.percent = false, this.dense = false});
  final int delta;
  final bool percent, dense;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0, c = up ? StatChip.up : StatChip.down;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 0, 5, 0),
      decoration: BoxDecoration(color: c.withValues(alpha: .18), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: dense ? 18 : 20, color: c),
          Text('${delta.abs()}${percent ? '%' : ''}', style: Txt.label(size: dense ? 12 : 13, color: c, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}
