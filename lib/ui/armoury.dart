// A dev page for judging the art: the knight drawn large in every armour tier, side by side.
// Open http://localhost:5070/?armoury (add &slow=4 to watch the idle in slow motion).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/body.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/rig.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/models.dart';
import 'hero_view.dart';
import 'theme.dart';

class ArmouryPreview extends StatelessWidget {
  const ArmouryPreview({super.key});

  /// ?armoury&new: the newest weapons and armour, worn, and as icons.
  Widget _newKit() {
    GearItem g(String art, GearSlot slot, HeroClass c, {Rarity r = Rarity.epic, int? tint}) => GearItem(id: art, name: art, slot: slot, art: art, rarity: r, level: 20, heroClass: c, value: 0, tint: tint, stats: const {});
    final kits = <(String, HeroClass, Loadout)>[
      ('Bramblelash', HeroClass.knight, Loadout(armour: 'surcoat', weapon: g('whip', GearSlot.weapon, HeroClass.knight, r: Rarity.legendary), offhand: g('round', GearSlot.offhand, HeroClass.knight))),
      ('Flail · fur mantle', HeroClass.knight, Loadout(armour: 'furmantle', weapon: g('flail', GearSlot.weapon, HeroClass.knight), offhand: g('buckler', GearSlot.offhand, HeroClass.knight))),
      ('Katana · O-yoroi', HeroClass.knight, Loadout(armour: 'oyoroi', weapon: g('katana', GearSlot.weapon, HeroClass.knight), offhand: g('wakizashi', GearSlot.offhand, HeroClass.knight), helm: g('kabuto', GearSlot.helm, HeroClass.knight))),
      ('Naginata', HeroClass.knight, Loadout(armour: 'oyoroi', weapon: g('naginata', GearSlot.weapon, HeroClass.knight), helm: g('kabuto', GearSlot.helm, HeroClass.knight))),
      ('Cleaver', HeroClass.knight, Loadout(armour: 'plate', weapon: g('cleaver', GearSlot.weapon, HeroClass.knight))),
      ('Onmyoji', HeroClass.mage, Loadout(armour: 'onmyoji', weapon: g('shakujo', GearSlot.weapon, HeroClass.mage), offhand: g('fan', GearSlot.offhand, HeroClass.mage), helm: g('eboshi', GearSlot.helm, HeroClass.mage))),
      ('Scythe', HeroClass.mage, Loadout(armour: 'starweave', weapon: g('scythe', GearSlot.weapon, HeroClass.mage))),
      ('Shinobi · yumi', HeroClass.ranger, Loadout(armour: 'shinobi', weapon: g('yumi', GearSlot.weapon, HeroClass.ranger), helm: g('mask', GearSlot.helm, HeroClass.ranger))),
      ('Tomahawk', HeroClass.ranger, Loadout(armour: 'huntleathers', weapon: g('tomahawk', GearSlot.weapon, HeroClass.ranger))),
    ];
    const arts = ['whip', 'flail', 'tomahawk', 'thornblade', 'flamberge', 'frostbrand', 'dawnblade', 'shadowblade', 'rapier', 'glaive', 'cleaver', 'katana', 'wakizashi', 'naginata', 'kanabo', 'yumi', 'shuriken', 'shakujo', 'fan', 'scythe', 'round'];
    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                for (final (name, cls, kit) in kits)
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: HeroFigure(look: lookFor(cls, kit))),
                        Text(name, style: Txt.label(size: 12, color: Palette.cream)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              children: [
                for (final a in arts)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(children: [GearIcon(item: g(a, a == 'round' || a == 'fan' ? GearSlot.offhand : GearSlot.weapon, HeroClass.knight), size: 64, heroClass: HeroClass.knight, dye: 'crimson'), Text(a, style: Txt.label(size: 10, color: Palette.cream))]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ?armoury&weapons: every weapon in the knight's hand, plainly lit (not a silhouette), at
  /// rest and (with &ms=320) at the moment the swing lands, to check which way each one faces.
  Widget _allWeapons() {
    final ms = double.tryParse(Uri.base.queryParameters['ms'] ?? '');
    final arts = [for (final w in Weapon.values) if (w != Weapon.none) w.name];
    return Scaffold(
      backgroundColor: const Color(0xFF6A5E52),
      body: GridView.count(
        crossAxisCount: int.tryParse(Uri.base.queryParameters['cols'] ?? '') ?? 8,
        childAspectRatio: .8,
        children: [
          for (final a in arts)
            Column(
              children: [
                Expanded(child: CustomPaint(size: Size.infinite, painter: _Holding(a, ms))),
                Text(a, style: Txt.label(size: 11, color: Palette.cream)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Uri.base.queryParameters.containsKey('weapons')) return _allWeapons();
    if (Uri.base.queryParameters.containsKey('new')) return _newKit();
    final tiers = [for (final t in tiersFor(HeroClass.knight)) if (!t.dropOnly) t];
    final relic = LootTable(math.Random(1)).relicWeapon(0, 10, HeroClass.knight);
    Widget knight(ArmourTier t, {double soot = 0, bool female = false, bool kingsfall = false}) {
      final l = Loadout.starter(HeroClass.knight)..armour = t.id;
      if (kingsfall) l.weapon = relic;
      return Expanded(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  gradient: const RadialGradient(center: Alignment(0, .2), colors: [Color(0xFF6A5E52), Color(0xFF2A2420)]),
                ),
                child: HeroFigure(look: lookFor(HeroClass.knight, l, soot: soot, female: female)),
              ),
            ),
            Text(t.name, style: Txt.label(size: 14, color: Palette.cream)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: Column(
        children: [
          Expanded(child: Row(children: [for (final t in tiers) knight(t)])),
          Expanded(child: Row(children: [for (final t in tiers) knight(t, soot: 1, female: true)])),
          // The relics, in hand.
          Expanded(child: Row(children: [for (final t in tiers) knight(t, kingsfall: true)])),
        ],
      ),
    );
  }
}

class _Holding extends CustomPainter {
  _Holding(this.art, this.ms);
  final String art;
  final double? ms;

  @override
  void paint(Canvas canvas, Size size) {
    final item = GearItem(id: art, name: art, slot: GearSlot.weapon, art: art, rarity: Rarity.epic, level: 20, heroClass: HeroClass.knight, value: 0, stats: const {});
    final l = Loadout.starter(HeroClass.knight)
      ..armour = 'plate'
      ..weapon = item;
    final look = lookFor(HeroClass.knight, l);
    final b = builds[look.build]!;
    final idle = idlePose(look.stance, 0, still: true);
    final pose = ms == null ? idle : (sampleClip(idle, swingClip, ms!) ?? idle);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawHumanoid(canvas, look, pose, 0, DrawOptions(at: Offset(size.width * .42, size.height * .92), scale: size.height * .62 / b.height), still: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Holding old) => false;
}
