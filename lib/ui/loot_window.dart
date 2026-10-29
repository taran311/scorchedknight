// "Spoils of victory": every defeated foe drops one piece of gear. Equip it (the old piece goes
// into the gear chest in your tent), keep it in the chest for later, or sell it.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import 'hero_view.dart';
import 'item_icons.dart';
import 'stat_icons.dart';
import '../game/models.dart' show Loadout;
import 'theme.dart';

/// Shows each waiting drop in turn until none are left (or the screen goes away).
bool _resolving = false;

Future<void> resolvePendingLoot(BuildContext context, GameController c, {String? title}) async {
  if (_resolving) return; // one spoils window at a time
  _resolving = true;
  try {
    await _resolve(context, c, title);
  } finally {
    _resolving = false;
  }
}

Future<void> _resolve(BuildContext context, GameController c, String? title) async {
  while (context.mounted && c.nextLoot != null) {
    final item = c.nextLoot!;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LootWindow(controller: c, item: item, title: title),
    );
    switch (choice) {
      case null:
        return;
      case 'equip':
        c.equipLoot(item.id);
      case 'keep':
        c.keepLoot(item.id);
      default:
        c.sellLoot(item.id);
        Audio.play(Sfx.coins);
    }
  }
}

/// A line about how the drop turned up: plainer for plain things, louder the rarer it is.
String _foundLine(GearItem item) {
  final lines = switch (item.rarity) {
    Rarity.legendary => const ['A legendary find!', 'Something ancient wakes in your hands.', 'The air hums. This one is legendary.'],
    Rarity.epic => const ['Now THAT is worth the trip.', 'It glows faintly, as if it\'s pleased to see you.', 'A rare piece of work, this.'],
    Rarity.rare => const ['Something glints among the spoils.', 'Better than most. Much better.', 'It was hidden under the body. Lucky.'],
    _ => const ['The foe dropped something.', 'Not much, but it\'s yours.', 'Something for the pile.'],
  };
  return lines[item.id.hashCode.abs() % lines.length];
}

/// A glow behind a drop's icon in its rarity's colour: none for plain things, a slow pulse for rare
/// and epic, and turning rays of light for a legendary.
class _Halo extends StatefulWidget {
  const _Halo({required this.rarity, required this.child});
  final Rarity rarity;
  final Widget child;

  @override
  State<_Halo> createState() => _HaloState();
}

class _HaloState extends State<_Halo> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.rarity.index >= Rarity.rare.index && !still && !_spin.isAnimating) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rarity.index < Rarity.rare.index) return widget.child;
    final col = Color(widget.rarity.argb);
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) => CustomPaint(painter: _HaloPainter(col, _spin.value, rays: widget.rarity == Rarity.legendary, strength: widget.rarity.index - 2), child: child),
      child: widget.child,
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.col, this.t, {required this.rays, required this.strength});
  final Color col;
  final double t;
  final bool rays;
  final int strength;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide * .62;
    final pulse = .75 + .25 * math.sin(t * math.pi * 6);
    canvas.drawCircle(c, r * (1 + .08 * pulse), Paint()..color = col.withValues(alpha: (.18 + .1 * strength) * pulse)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .35));
    if (!rays) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    final ray = Paint()..color = col.withValues(alpha: .28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 10; i++) {
      canvas.rotate(math.pi / 5);
      canvas.drawPath(Path()..moveTo(-4, 0)..lineTo(0, -r * 1.35)..lineTo(4, 0)..close(), ray);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t || old.col != col;
}

class _LootWindow extends StatelessWidget {
  const _LootWindow({required this.controller, required this.item, this.title});
  final GameController controller;
  final GearItem item;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final k = controller.state.knight, old = controller.engine.equippedFor(item), col = rarityColour(item.rarity);
    final cant = controller.engine.whyNotWear(item);
    final better = cant == null && (item.slot == GearSlot.armour ? armourTierById(item.art).reduction > armourTierById(k.loadouts[item.heroClass ?? k.heroClass]!.armour).reduction : old == null || item.score > old.score);
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stone(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title ?? 'Spoils of victory', textAlign: TextAlign.center, style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    _foundLine(item),
                    textAlign: TextAlign.center,
                    style: Txt.onStone(size: 13.5, color: item.rarity == Rarity.legendary ? col : Palette.parch2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Halo(rarity: item.rarity, child: GearIcon(item: item, size: 72, heroClass: k.heroClass, dye: k.dye)),
                      const SizedBox(width: 12),
                      Expanded(child: GearDetails(item: item, compare: old, kit: k.loadouts[item.heroClass ?? k.heroClass])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .25),
                      border: Border.all(color: Colors.black.withValues(alpha: .55)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: item.slot == GearSlot.armour
                        ? Builder(builder: (_) {
                            final tier = armourTierById(item.art), now = armourTierById(k.loadouts[item.heroClass ?? k.heroClass]!.armour);
                            final perk = boneArmour.contains(item.art) ? 'Undead hit 25% softer' : tier.perkText;
                            final d = ((tier.reduction - now.reduction) * 100).round();
                            return Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                InfoChip(icon: const Icon(Icons.shield, size: 16, color: Color(0xFFB8C8D8)), text: '−${(tier.reduction * 100).round()}% damage taken', colour: Palette.cream, trailing: d == 0 ? null : DeltaPill(d, percent: true)),
                                if (perk != null) InfoChip(icon: const Icon(Icons.auto_awesome, size: 16, color: Palette.amber), text: perk, colour: Palette.amber),
                                InfoChip(icon: const Icon(Icons.swap_horiz, size: 16, color: Palette.parch2), text: 'Now: ${now.name} −${(now.reduction * 100).round()}%'),
                              ],
                            );
                          })
                        : old == null
                        ? Text('Your ${item.slot.label.toLowerCase()} slot is empty.', style: Txt.onStone(size: 13.5))
                        : _PeekGear(
                            item: old,
                            heroClass: k.heroClass,
                            dye: k.dye,
                            kit: k.loadouts[item.heroClass ?? k.heroClass],
                            child: Row(
                              children: [
                                GearIcon(item: old, size: 40, heroClass: k.heroClass, dye: k.dye),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Equipped now', style: Txt.label(size: 11, color: Palette.parch2)),
                                      Text(old.name, style: Txt.label(size: 14, color: rarityColour(old.rarity))),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.info_outline, size: 18, color: Palette.parch2),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StoneButton(
                          title: cant == null ? 'Equip' : 'Can\'t',
                          icon: cant == null ? _equipIcon(item.slot) : const Icon(Icons.block, size: 22, color: Color(0xFFFF8A70)),
                          caption: cant ?? (better ? 'Upgrade!' : (old == null ? 'Fill the slot' : (controller.stashFull ? 'Old one sells' : 'Old to chest'))),
                          tone: better ? ButtonTone.blood : ButtonTone.stone,
                          onPressed: cant != null ? null : () => Navigator.of(context).pop('equip'),
                        ),
                      ),
                      if (item.slot != GearSlot.armour) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: StoneButton(
                            title: 'Keep',
                            icon: const ChestIcon(size: 24),
                            caption: controller.stashFull ? 'Chest full' : '${controller.state.knight.stash.length}/${controller.stashCap}',
                            onPressed: controller.stashFull ? null : () => Navigator.of(context).pop('keep'),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: StoneButton(
                          title: 'Sell',
                          icon: const ItemIcon(Item.coins, size: 24),
                          caption: '+${item.value} gold',
                          tone: better ? ButtonTone.stone : ButtonTone.amber,
                          onPressed: () => Navigator.of(context).pop('sell'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What Equip shows: the kind of piece going on.
Widget _equipIcon(GearSlot slot) => switch (slot) {
  GearSlot.weapon => const ItemIcon(Item.swords, size: 24),
  GearSlot.offhand => const ItemIcon(Item.shield, size: 24),
  GearSlot.helm => const ItemIcon(Item.helm, size: 24),
  GearSlot.armour => const ItemIcon(Item.armour, size: 24),
  GearSlot.gloves => const ItemIcon(Item.gauntlets, size: 24),
  _ => const Icon(Icons.back_hand, size: 22, color: Color(0xFFFFE0C0)),
};

/// The piece you have on now: hover it (or tap, on a touch screen) to see its full stats in a card
/// above, to weigh against the drop.
class _PeekGear extends StatefulWidget {
  const _PeekGear({required this.item, required this.heroClass, required this.dye, required this.kit, required this.child});
  final GearItem item;
  final HeroClass heroClass;
  final String dye;
  final Loadout? kit;
  final Widget child;
  @override
  State<_PeekGear> createState() => _PeekGearState();
}

class _PeekGearState extends State<_PeekGear> {
  final _card = OverlayPortalController();
  final _link = LayerLink();

  void _show(bool on) => on ? _card.show() : _card.hide();

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _card,
    overlayChildBuilder: (context) => Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -8),
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xF71A1510),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: rarityColour(widget.item.rarity).withValues(alpha: .7), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EQUIPPED NOW', style: Txt.label(size: 11, color: Palette.parch2, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GearIcon(item: widget.item, size: 56, heroClass: widget.heroClass, dye: widget.dye),
                      const SizedBox(width: 10),
                      Expanded(child: GearDetails(item: widget.item, kit: widget.kit, dense: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    child: CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        onEnter: (_) => _show(true),
        onExit: (_) => _show(false),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _show(!_card.isShowing), child: widget.child),
      ),
    ),
  );
}
