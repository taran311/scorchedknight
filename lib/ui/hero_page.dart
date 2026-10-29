// Kit & spells (opened from your hero at camp): your painted hero, class, equipped gear, totals and satchel. Gear changes only
// through the spoils of victory (equip or sell) and the merchant.

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../audio/audio.dart';
import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/crafting.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart';
import '../game/models.dart' show Knight;
import '../game/mounts.dart';
import '../game/rules.dart';
import '../game/spells.dart';
import 'hero_view.dart';
import 'item_icons.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'material_icons.dart';
import 'merchant.dart';
import 'theme.dart';

/// The tabs inside your tent.
enum _Tab { gear, rites, companions, satchel, home, journey }

class HeroPage extends StatefulWidget {
  const HeroPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> {
  _Tab _tab = _Tab.gear;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, k = c.state.knight;
    final hasFriends = k.hasDragon || k.pets.isNotEmpty || k.mounts.isNotEmpty;
    final tabs = <(_Tab, IconData, String)>[
      (_Tab.gear, Icons.shield, unspentPoints(k) > 0 ? 'Gear · +${unspentPoints(k)}' : 'Gear'),
      (_Tab.rites, Icons.local_fire_department, 'Rites'),
      if (hasFriends) (_Tab.companions, Icons.pets, 'Companions'),
      (_Tab.satchel, Icons.backpack, 'Satchel'),
      (_Tab.home, Icons.cottage, 'Home'),
      (_Tab.journey, Icons.map, 'Journey'),
    ];
    final tab = tabs.any((t) => t.$1 == _tab) ? _tab : _Tab.gear;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.nextLoot != null) ...[
                _LootBanner(controller: c),
                const SizedBox(height: 10),
              ],
              // The tabs, like a character screen's.
              Row(
                children: [
                  for (final (t, icon, label) in tabs)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _TabButton(icon: icon, label: label, on: t == tab, onTap: () => setState(() => _tab = t)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              switch (tab) {
                _Tab.gear => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (unspentPoints(k) > 0) ...[_Training(controller: c), const SizedBox(height: 10)],
                    _PaperDoll(controller: c),
                    if (unspentPoints(k) == 0) ...[const SizedBox(height: 10), _Training(controller: c)],
                  ],
                ),
                _Tab.rites => _Spellbook(controller: c),
                _Tab.companions => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (k.hasDragon || k.pets.isNotEmpty) _Companions(controller: c),
                    if (k.mounts.isNotEmpty) ...[const SizedBox(height: 10), _Stable(controller: c)],
                  ],
                ),
                _Tab.satchel => _Satchel(controller: c),
                _Tab.home => _Home(controller: c),
                _Tab.journey => _Journey(controller: c),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF4A3B26) : Palette.stone1,
          border: Border.all(color: on ? Palette.amber : Palette.stone3, width: on ? 2 : 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: on ? Palette.amber : Palette.parch2),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: Txt.label(size: 13, color: on ? Palette.cream : Palette.parch2))),
          ],
        ),
      ),
    ),
  );
}

/// Your knight in the middle, gear slots down each side, and the totals as icon chips below.
class _PaperDoll extends StatelessWidget {
  const _PaperDoll({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, k = s.knight, tier = armourTierById(k.armour), h = heroStats(k), ds = dragonStage(k);
    Widget slot(GearSlot gs, String empty) {
      final g = k.equipped(gs);
      final idle = gs == GearSlot.offhand && g != null && k.loadout.activeOffhand == null;
      final twoHanded = gs == GearSlot.offhand && offhandKindFor(k.loadout.weapon?.art) == null;
      final colour = g == null ? Palette.stone3 : rarityColour(g.rarity);
      final spare = stashFor(k, gs).length;
      return Tooltip(
        message: g == null ? (twoHanded ? 'Both hands on your weapon' : '$empty: empty${spare > 0 ? ' · $spare in your chest' : ''}') : '${g.name} · ${g.rarity.label}${idle ? ' (not used with this weapon)' : ''}${spare > 0 ? ' · $spare more in your chest' : ''}',
        child: GestureDetector(
          onTap: g == null && spare == 0 ? null : () => showSlotSheet(context, c, gs, empty),
          child: MouseRegion(
            cursor: g == null && spare == 0 ? MouseCursor.defer : SystemMouseCursors.click,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(colors: [Color(0xFF3A3128), Color(0xFF15110C)]),
                    border: Border.all(color: colour, width: g == null ? 1 : 2),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [if (g != null) BoxShadow(color: colour.withValues(alpha: .35), blurRadius: 8)],
                  ),
                  child: Opacity(opacity: idle ? .4 : 1, child: Center(child: GearIcon(item: g, size: 52, heroClass: k.heroClass, dye: k.dye, empty: ''))),
                ),
                    // Spares for this slot in your chest.
                    if (spare > 0)
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFF6A4A1A), border: Border.all(color: Palette.amber), borderRadius: BorderRadius.circular(8)),
                          child: Text('+$spare', style: Txt.label(size: 11, color: const Color(0xFFFFE6A0))),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(empty, style: Txt.label(size: 12, color: g == null ? Palette.stoneHi : Palette.parch2)),
              ],
            ),
          ),
        ),
      );
    }

    final offName = switch (offhandKindFor(k.loadout.weapon?.art)) {
      OffhandKind.shield => 'Shield',
      OffhandKind.focus => 'Tome',
      OffhandKind.quiver => 'Quiver',
      OffhandKind.sidearm => 'Sidearm',
      OffhandKind.parrying => 'Dagger',
      OffhandKind.wand => 'Wand',
      null => 'Off-hand',
    };
    Widget column(List<Widget> slots) => Column(children: [for (final (i, w) in slots.indexed) ...[if (i > 0) const SizedBox(height: 10), w]]);

    // The totals as chips: a symbol and a number, the name in the tooltip.
    final chip = ds == null || ds.chip == 0 ? 0 : ds.chip + k.level ~/ 5 + h.dragonkin;
    final stats = <(Widget, String, String)>[
      (const ItemIcon(Item.swords, size: 22), '${fullSwing(k)}', 'Attack: about ${fullSwing(k)} damage a swing'),
      (const Icon(Icons.favorite, size: 20, color: Color(0xFFE0604A)), '${maxHp(k)}', 'Max HP'),
      (const Icon(Icons.shield, size: 20, color: Color(0xFFB8C0C8)), '−${(damageReduction(k) * 100).round()}%', 'Damage taken'),
      (const Icon(Icons.auto_awesome, size: 20, color: Palette.amber), '${(critChance(k) * 100).round()}%', 'Critical hit chance'),
      (const Icon(Icons.air, size: 20, color: Color(0xFF9ADFFF)), '${(dodgeChance(k) * 100).round()}%', 'Dodge chance'),
      (const Icon(Icons.swap_horiz, size: 20, color: Palette.parch), '${(parryChance(k) * 100).round()}%', 'Parry chance'),
      (const Icon(Icons.security, size: 20, color: Palette.parch), '${(blockChance(k) * 100).round()}%', 'Block chance'),
      (const Icon(Icons.gavel, size: 20, color: Color(0xFFFFD98A)), '×$bashMult', '${skillName(k)}: ×$bashMult and dazes the foe, every 4 turns'),
      (const Icon(Icons.gps_fixed, size: 20, color: Palette.parch), '~${(fullSwing(k) * crossbowShare(k) * aimBoost(k)).round()}', 'Crossbow shot: about ${(fullSwing(k) * crossbowShare(k) * aimBoost(k)).round()} damage, ×$aloftShot against foes in the air, and it fires special bolts'),
      if (h.poison > 0 || k.poisonFights > 0) (const Icon(Icons.science, size: 20, color: Color(0xFF9BE27A)), '+${h.poison + (k.poisonFights > 0 ? 4 + k.level ~/ 3 : 0)}', 'Poison per attack'),
      if (h.burn > 0) (const Icon(Icons.whatshot, size: 20, color: Color(0xFFFF7A2A)), '+${h.burn}', 'Fire per attack'),
      if (h.frost > 0) (const Icon(Icons.ac_unit, size: 20, color: Color(0xFF9ADFFF)), '+${h.frost}', 'Frost per attack'),
      if (h.smite > 0) (const Icon(Icons.wb_sunny, size: 20, color: Color(0xFFFFE6A0)), '+${h.smite}', 'Holy damage against the undead and demons'),
      if (chip > 0) (const Icon(Icons.local_fire_department, size: 20, color: Color(0xFFF4955F)), '+$chip', 'Dragon fire per attack'),
      if (h.lifesteal > 0) (const Icon(Icons.bloodtype, size: 20, color: Color(0xFFC23A30)), '+${h.lifesteal}', 'Life steal: heal per attack'),
      (const Icon(Icons.healing, size: 20, color: Color(0xFF9BE27A)), '+${h.regen + (maxHp(k) * breathShare).round()}', 'Second wind: HP back after each win'),
      if (h.thorns > 0) (const Icon(Icons.grass, size: 20, color: Color(0xFF9BE27A)), '${h.thorns}', 'Thorns: damage back when hurt'),
      if (h.fortune > 0) (const ItemIcon(Item.coins, size: 20), '+${h.fortune}%', 'Fortune: more gold'),
      if (h.wisdom > 0) (const Icon(Icons.menu_book, size: 20, color: Palette.parch), '+${h.wisdom}%', 'Wisdom: more XP'),
    ];

    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column([slot(GearSlot.helm, 'Head'), slot(GearSlot.cape, 'Cape'), slot(GearSlot.gloves, 'Hands'), slot(GearSlot.boots, 'Feet')]),
              Expanded(
                child: Column(
                  children: [
                    Text(s.settings.name, style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
                    Text('Level ${k.level} knight', style: Txt.label(size: 13, color: Palette.amber)),
                    SizedBox(height: 300, child: HeroFigure(look: heroLook(k))),
                    // The armour you wear, under your feet.
                    Tooltip(
                      message: '${tier.name}: −${(tier.reduction * 100).round()}% damage taken${k.loadout.armourEnchant == null ? '' : ' · ${k.loadout.armourEnchant!.title}: ${k.loadout.armourEnchant!.describe}'}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0x66000000), border: Border.all(color: Palette.stone3), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 24, height: 24, child: FittedBox(child: armourIcon(tier))),
                            const SizedBox(width: 6),
                            Flexible(child: Text(tier.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 13, color: Palette.cream))),
                            if (k.gloves) ...[const SizedBox(width: 8), const Tooltip(message: 'Gripped gauntlets: +3 damage a swing', child: ItemIcon(Item.gauntlets, size: 20))],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              column([slot(GearSlot.weapon, 'Weapon'), slot(GearSlot.offhand, offName), slot(GearSlot.ring, 'Ring'), slot(GearSlot.trinket, 'Trinket')]),
            ],
          ),
          // Sets and cape abilities, when they apply.
          for (final (set, n) in activeSets(k.gear))
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('✦ ${set.name} set $n/3: ${set.twoText}${n >= 3 ? '; ${set.threeText}' : ''}', textAlign: TextAlign.center, style: Txt.label(size: 13, color: Palette.amber))),
          if (capeByAbility(k.loadout.cape?.special) case final cape?)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('✦ ${cape.ability}', textAlign: TextAlign.center, style: Txt.label(size: 13, color: Palette.amber))),
          const Divider(color: Palette.stone3, height: 22),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final (icon, value, tip) in stats)
                Tooltip(
                  message: tip,
                  child: Container(
                    width: 78,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x55000000), border: Border.all(color: Palette.stone3), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        SizedBox(height: 22, child: Center(child: icon)),
                        const SizedBox(height: 2),
                        Text(value, style: Txt.label(size: 15, color: Palette.cream)),
                        // A word under each number, so nobody has to hover to know what it is.
                        Text(_statWord(tip), maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 10.5, color: Palette.parch2)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A one-word caption for a stat tile, from its tooltip.
String _statWord(String tip) {
  final first = tip.split(RegExp(r'[: ]')).first;
  return switch (first) {
    'Max' => 'HP',
    'Damage' => 'Armour',
    'Critical' => 'Crit',
    'Shield' || 'Mighty' => 'Bash',
    'Crossbow' => 'Bolt',
    'Second' => 'Rest',
    'Life' => 'Leech',
    'Holy' => 'Holy',
    _ => first,
  };
}

class _LootBanner extends StatelessWidget {
  const _LootBanner({required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final g = controller.nextLoot!;
    return Stone(
      fill: const Color(0xFF4A3A22),
      child: Row(
        children: [
          GearIcon(item: g, size: 44, heroClass: controller.state.knight.heroClass, dye: controller.state.knight.dye),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unclaimed spoils', style: Txt.label(size: 12, color: Palette.parch2)),
                Text(g.name, style: Txt.label(size: 15, color: rarityColour(g.rarity))),
              ],
            ),
          ),
          StoneButton(title: 'Choose', compact: true, tone: ButtonTone.amber, onPressed: () => resolvePendingLoot(context, controller)),
        ],
      ),
    );
  }
}

/// A closer look at a piece of gear you're wearing.
void showGearItem(BuildContext context, GameController controller, GearItem g) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Stone(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GearIcon(item: g, size: 72, heroClass: controller.state.knight.heroClass, dye: controller.state.knight.dye),
                const SizedBox(width: 12),
                Expanded(child: GearDetails(item: g, kit: controller.state.knight.loadouts[g.heroClass ?? controller.state.knight.heroClass])),
              ],
            ),
            const SizedBox(height: 10),
            Text('Sells for ${g.value} gold when replaced.', style: Txt.onStone(size: 13)),
            const SizedBox(height: 10),
            StoneButton(title: 'Close', compact: true, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    ),
  ),
);

/// The pieces in your chest that fit [slot] (and your class).
List<GearItem> stashFor(Knight k, GearSlot slot) => [for (final g in k.stash) if (g.slot == slot && (g.heroClass == null || g.heroClass == k.heroClass)) g];

/// One gear slot up close: what you're wearing, and the spares in your chest for it, each with
/// its stats against what you wear. Wear a spare (the old one goes back in the chest) or sell it.
Future<void> showSlotSheet(BuildContext context, GameController c, GearSlot slot, String label, {GearItem? pick}) =>
    showDialog<void>(context: context, builder: (_) => _SlotSheet(controller: c, slot: slot, label: label, pick: pick));

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.controller, required this.slot, required this.label, this.pick});
  final GameController controller;
  final GearSlot slot;
  final String label;
  final GearItem? pick;
  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late String? _picked = widget.pick?.id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller, k = c.state.knight, worn = k.equipped(widget.slot), spares = stashFor(k, widget.slot);
      final picked = spares.where((g) => g.id == _picked).firstOrNull ?? (spares.isNotEmpty ? spares.first : null);
      final kit = k.loadouts[k.heroClass];
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stone(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(widget.label, style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800))),
                      IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Palette.parch)),
                    ],
                  ),
                  // What you wear now.
                  Text('WEARING', style: Txt.label(size: 11, color: Palette.parch2)),
                  const SizedBox(height: 4),
                  worn == null
                      ? Text('Nothing', style: Txt.onStone(size: 14))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GearIcon(item: worn, size: 56, heroClass: k.heroClass, dye: k.dye),
                            const SizedBox(width: 10),
                            Expanded(child: GearDetails(item: worn, kit: kit, dense: true)),
                          ],
                        ),
                  if (spares.isNotEmpty) ...[
                    const Divider(color: Palette.stone3, height: 22),
                    Text('IN YOUR CHEST', style: Txt.label(size: 11, color: Palette.parch2)),
                    const SizedBox(height: 6),
                    // The spares as a row of tiles; the one picked is shown below against what you wear.
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final g in spares)
                          GestureDetector(
                            onTap: () => setState(() => _picked = g.id),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const RadialGradient(colors: [Color(0xFF3A3128), Color(0xFF15110C)]),
                                  border: Border.all(color: picked?.id == g.id ? Palette.amber : rarityColour(g.rarity), width: picked?.id == g.id ? 2.5 : 1.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(child: GearIcon(item: g, size: 42, heroClass: k.heroClass, dye: k.dye)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (picked != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0x55000000), border: Border.all(color: rarityColour(picked.rarity)), borderRadius: BorderRadius.circular(4)),
                        child: GearDetails(item: picked, compare: worn, kit: kit),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Builder(
                              builder: (context) {
                                final cant = c.engine.whyNotWear(picked);
                                return StoneButton(
                                  title: cant == null ? 'Wear it' : 'Can\'t wear',
                                  caption: cant ?? (c.state.inBattle ? 'Not mid-fight' : (worn == null ? null : '${worn.name} to the chest')),
                                  tone: ButtonTone.blood,
                                  onPressed: c.state.inBattle || cant != null ? null : () => c.equipFromStash(picked.id),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: StoneButton(title: 'Sell', caption: '+${picked.value} gold', onPressed: () {
                            c.sellFromStash(picked.id);
                            Audio.play(Sfx.coins);
                          })),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Satchel extends StatelessWidget {
  const _Satchel({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, k = s.knight, ds = dragonStage(k);
    // Everything you carry, in three groups: what's on your belt, what the forge and the tower
    // turn into things, and what you've gathered for someone.
    final belt = <Widget>[
      if (k.potions > 0) _Slot(tooltip: '${k.potions} health potion${k.potions == 1 ? '' : 's'}: each heals ${potionHeal(k)} HP. Drink in a fight.', badge: '${k.potions}', child: const ItemIcon(Item.potion)),
      if (k.scrolls > 0) _Slot(tooltip: '${k.scrolls} scroll${k.scrolls == 1 ? '' : 's'} of enchanting: a free rune at the enchanter', badge: '${k.scrolls}', child: const Icon(Icons.description, color: Color(0xFFE8DCC0))),
      _Slot(tooltip: '${fmt(k.coins)} gold', badge: fmt(k.coins), child: const ItemIcon(Item.coins)),
      for (final e in k.ammo.entries)
        if (ammoById(e.key) case final a? when e.value > 0) _Slot(tooltip: '${a.label(missileFor(k.loadout.weapon?.art) ?? Missile.bolt)} ×${e.value}: ${a.desc}', badge: '${e.value}', child: Icon(Icons.north_east, color: Color(a.argb))),
      if (ds?.name == 'Egg') _Slot(tooltip: 'Dragon egg: ${k.dragonXp} / 300 XP to hatch', child: const ItemIcon(Item.egg)),
      for (final d in k.ownedDyes.where((d) => d != k.dye))
        _Slot(tooltip: 'Wear ${dyeById(d).name}', onTap: () => c.wearDye(d), child: ItemIcon(Item.dye, tint: Color(dyeById(d).argb))),
    ];
    Widget? mat(String key, String name, Widget icon, String use) {
      final n = s.mat(key);
      return n > 0 ? _Slot(tooltip: '$n× $name: $use', badge: '$n', child: icon) : null;
    }
    final craft = <Widget?>[
      for (final g in Gem.values) mat(gemKey(g), g.label, MatIcon.gem(g), 'Old Wick sets it, or it makes ${g.ammo.label(Missile.bolt).toLowerCase()}'),
      for (final m in Metal.values) mat(oreKey(m), m.ore, MatIcon.ore(m), '$smithName smelts it into bars'),
      for (final m in Metal.values) mat(barKey(m), m.bar, MatIcon.bar(m), '$smithName forges and tempers with it'),
      for (final e in Elemental.values) mat(coreKey(e), e.core, MatIcon.core(switch (e) { Elemental.ember => const Color(0xFFFF7A2A), Elemental.frost => const Color(0xFF9ADFFF), Elemental.mire => const Color(0xFF8FD36A) }), 'Old Wick makes a rune from it'),
      for (final t in Trophy.values) mat(trophyKey(t), t.label, MatIcon.trophy(t), '$smithName forges set pieces from it'),
      for (final key in s.mats.keys.where((k) => k.startsWith('bp:')))
        _Slot(tooltip: '${_blueprintTitle(key)}: take it to $smithName', child: MatIcon.blueprint()),
    ].whereType<Widget>().toList();
    final gathered = <Widget>[
      if (!s.innRepaired && s.timber > 0) _Slot(tooltip: 'Charred timber for Hob: ${s.timber}/$timberNeeded', badge: '${s.timber}', child: const ItemIcon(Item.timber)),
      if (!s.innRepaired && s.ironScrap > 0) _Slot(tooltip: 'Iron scrap for Hob: ${s.ironScrap}/$ironNeeded', badge: '${s.ironScrap}', child: const ItemIcon(Item.iron)),
      for (var l = 0; l < continents.length; l++)
        if (s.reagents[l] > 0) _Slot(tooltip: '${s.reagents[l]}× ${continents[l].reagent}: Old Wick makes wards from them', badge: '${s.reagents[l]}', child: MatIcon(MatShape.leaf, Color(continents[l].argb))),
      for (final e in s.relicParts.entries)
        if (relics[e.key] case final r? when e.value > 0 && !s.forged.contains(e.key))
          for (var i = 0; i < r.parts.length; i++)
            if (hasRelicPart(s.relicParts, e.key, i)) _Slot(tooltip: '${r.parts[i].name}: a part of ${r.name}', child: const Icon(Icons.extension, color: Color(0xFFFFD98A))),
    ];
    Widget group(String title, List<Widget> items, String empty) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Txt.label(size: 15, color: Palette.amber)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(empty, style: Txt.onStone(size: 12.5))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [for (final w in items) SizedBox(width: 64, height: 64, child: w)]),
        const SizedBox(height: 12),
      ],
    );
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, color: Palette.amber, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text('Gear chest', style: Txt.label(size: 15, color: Palette.amber))),
              Text('${k.stash.length} / ${c.stashCap}', style: Txt.label(size: 14, color: k.stash.length >= c.stashCap ? const Color(0xFFE88A70) : Palette.parch2)),
            ],
          ),
          const SizedBox(height: 6),
          if (k.stash.isEmpty)
            Text('Empty. Gear you take off, or keep from your spoils, waits here.', style: Txt.onStone(size: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in k.stash)
                  Tooltip(
                    message: '${g.name} · ${g.rarity.label} ${g.slot.label.toLowerCase()}',
                    child: GestureDetector(
                      onTap: () => showSlotSheet(context, c, g.slot, g.slot.label, pick: g),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const RadialGradient(colors: [Color(0xFF3A3128), Color(0xFF15110C)]),
                            border: Border.all(color: rarityColour(g.rarity), width: 1.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Center(child: GearIcon(item: g, size: 46, heroClass: k.heroClass, dye: k.dye)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const Divider(color: Palette.stone3, height: 22),
          group('Belt', belt, ''),
          group('For the forge and the tower', craft, 'Nothing yet. Golems carry ore and gems, and some foes leave trophies.'),
          if (gathered.isNotEmpty) group('Gathered', gathered, ''),
          Text('Hover (or tap and hold) anything to see what it\'s for. Tap a spare dye to wear it.', style: Txt.onStone(size: 12.5)),
        ],
      ),
    );
  }
}

/// "Nightblood gloves blueprint", from its key ('bp:nightblood:gloves').
String _blueprintTitle(String key) {
  final parts = key.split(':');
  final set = parts.length > 1 ? gearSetById(parts[1])?.name : null;
  final slot = parts.length > 2 ? GearSlot.values.where((g) => g.name == parts[2]).firstOrNull : null;
  return set == null || slot == null ? 'A blueprint' : '$set ${pieceNoun(slot)} blueprint';
}

class _Slot extends StatelessWidget {
  const _Slot({this.child, this.tooltip, this.onTap, this.badge});
  final Widget? child;
  final String? tooltip, badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        border: Border.all(color: Colors.black.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          if (child != null) Center(child: FractionallySizedBox(widthFactor: .7, heightFactor: .7, child: FittedBox(child: child))),
          if (badge != null) Positioned(left: 3, top: 1, child: Text(badge!, style: Txt.label(size: 12, color: Palette.amber))),
        ],
      ),
    );
    if (onTap != null) box = InkWell(onTap: onTap, child: box);
    if (tooltip != null) box = Tooltip(message: tooltip!, child: box);
    return Semantics(button: onTap != null, label: tooltip, child: box);
  }
}


/// Ember Rites as a grid of tiles: tap one you've learned to prepare it for Cast.
class _Spellbook extends StatelessWidget {
  const _Spellbook({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight;
    final list = [...spells]..sort((a, b) => a.level.compareTo(b.level));
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Pick up to $riteSlots rites for your hotbar (${k.rites.length}/$riteSlots)', style: Txt.label(size: 15, color: Palette.amber))),
              Tooltip(
                message: 'Every attack, bash or shot gathers 1 mana; you start a fight with ${startingMana(k)}',
                child: Row(
                  children: [
                    for (var i = 0; i < maxMana; i++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i < startingMana(k) ? const Color(0xFF6AC8FF) : const Color(0xFF15202A), border: Border.all(color: const Color(0xFF9ADFFF))),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 640 ? 6 : (box.maxWidth > 420 ? 5 : 4);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  for (final sp in list)
                    Builder(
                      builder: (context) {
                        final known = sp.level <= k.level, slotAt = k.rites.indexOf(sp.id), prepared = slotAt >= 0, col = Color(sp.argb);
                        return Tooltip(
                          message: known ? '${sp.name}: ${sp.desc}${prepared ? ' (tap to take it off your hotbar)' : ' (tap to put it on your hotbar)'}' : '${sp.name}: learned at level ${sp.level}',
                          child: GestureDetector(
                            onTap: known ? () => c.prepareSpell(sp.id) : null,
                            child: MouseRegion(
                              cursor: known ? SystemMouseCursors.click : MouseCursor.defer,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(center: const Alignment(0, -.3), colors: [known ? col.withValues(alpha: .28) : const Color(0xFF2A241E), const Color(0xFF15110C)]),
                                  border: Border.all(color: prepared ? col : (known ? const Color(0xFF6A5640) : Palette.stone2), width: prepared ? 2.5 : 1),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [if (prepared) BoxShadow(color: col.withValues(alpha: .5), blurRadius: 12)],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: known ? 1 : .4,
                                        // Shrinks to the tile on a narrow phone rather than spill out of it.
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(known ? Icons.local_fire_department : Icons.lock, size: 34, color: col),
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              child: FittedBox(fit: BoxFit.scaleDown, child: Text(sp.name, style: Txt.label(size: 13, color: Palette.cream))),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (var i = 0; i < sp.cost; i++)
                                                  Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6AC8FF))),
                                              ],
                                            ),
                                          ],
                                        ),
                                        ),
                                      ),
                                    ),
                                    if (!known) Positioned(right: 5, top: 4, child: Text('Lv ${sp.level}', style: Txt.label(size: 11, color: Palette.parch2))),
                                    if (prepared)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 1),
                                          decoration: BoxDecoration(color: col, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                          child: Text('SLOT ${slotAt + 1}', textAlign: TextAlign.center, style: Txt.label(size: 10, color: const Color(0xFF15110C))),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The journey so far: continents crossed, bosses felled and a few tallies.
class _Journey extends StatelessWidget {
  const _Journey({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final rows = <(String, String)>[
      ('Continents reached', '${[for (var i = 0; i < mainLands; i++) if (openers(i).isEmpty || openers(i).any(s.bossesDown.contains)) i].length} of $mainLands${[for (var i = mainLands; i < continents.length; i++) if (openers(i).any(s.bossesDown.contains)) i].isEmpty ? '' : ' (and off the road)'}'),
      ('Places explored', '${s.explored.length} of ${places.length}'),
      ('Bosses felled', s.bossesDown.isEmpty ? 'none yet' : [for (final i in s.bossesDown.toList()..sort()) continents[i].boss.name].join(', ')),
      ('Foes felled', fmt(s.foesFelled)),
      ('Rare foes', fmt(s.raresFelled)),
      ('Chests opened', fmt(s.chestsOpened)),
      ('Knocked out', s.knockouts == 0 ? 'never' : '${s.knockouts} ${s.knockouts == 1 ? 'time' : 'times'}'),
      ('Ran away', s.flees == 0 ? 'never' : '${s.flees} ${s.flees == 1 ? 'time' : 'times'}'),
    ];
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.won ? 'The journey (Vharrax is no more!)' : 'The journey', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 6),
          for (final (a, b) in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .35)))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a, style: Txt.onStone(size: 14, color: Palette.cream)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(b, textAlign: TextAlign.right, style: Txt.onStone(size: 14, color: Palette.amber))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Your mounts: pick the one you ride. Every fight opens with its charge.
class _Stable extends StatelessWidget {
  const _Stable({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight;
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stable', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 4),
          Text('Ride a mount and every fight opens with a charge.', style: Txt.onStone(size: 12.5)),
          const SizedBox(height: 8),
          for (final m in mounts.where((m) => k.mounts.contains(m.id)))
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: k.mount == m.id ? Palette.amber.withValues(alpha: .12) : Colors.black.withValues(alpha: .22),
                border: Border.all(color: k.mount == m.id ? Palette.amber : Colors.black.withValues(alpha: .55)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  MountIcon(m.id, size: 34),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: Txt.onStone(size: 14.5, color: Palette.cream).copyWith(fontWeight: FontWeight.w700)),
                        Text(m.desc, style: Txt.onStone(size: 12.5)),
                      ],
                    ),
                  ),
                  k.mount == m.id
                      ? TextButton(onPressed: () => c.setMount(null), child: Text('Riding · walk', style: Txt.label(size: 13, color: Palette.amber)))
                      : TextButton(onPressed: () => c.setMount(m.id), child: Text('Ride', style: Txt.label(size: 13, color: Palette.amber))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Companions extends StatelessWidget {
  const _Companions({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, active = activeCompanion(k);
    Widget row(String id, String name, String perk, int xp, int? next, Color colour) {
      final fighting = active == id;
      return Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: fighting ? colour.withValues(alpha: .14) : Colors.black.withValues(alpha: .22),
          border: Border.all(color: fighting ? colour : Colors.black.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(id == Pet.fairy.name ? Icons.auto_awesome : Icons.pets, color: colour, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Txt.onStone(size: 14.5, color: Palette.cream).copyWith(fontWeight: FontWeight.w700)),
                  Text('$perk · ${next == null ? 'fully grown' : '${fmt(xp)} / ${fmt(next)} XP to grow'}', style: Txt.onStone(size: 12.5)),
                ],
              ),
            ),
            fighting
                ? Text('Fighting', style: Txt.label(size: 13, color: colour))
                : TextButton(onPressed: () => c.setCompanion(id), child: Text('Bring along', style: Txt.label(size: 13, color: Palette.amber))),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    if (k.hasDragon) {
      final xp = k.dragonXp!;
      final stage = dragonStages.lastWhere((d) => xp >= d.minXp);
      final next = dragonStages.where((d) => d.minXp > xp).firstOrNull;
      rows.add(row('dragon', stage.name == 'Egg' ? 'Dragon egg' : 'Dragon: ${stage.name}', stage.chip == 0 ? 'Hatches as you earn XP (300 XP)' : 'Breathes fire on every attack; Command: a great gout of fire', xp, next?.minXp, const Color(0xFFF4955F)));
    }
    for (final pet in Pet.values) {
      final xp = k.pets[pet.name];
      if (xp == null) continue;
      final stages = petStages[pet]!, stage = stages.lastWhere((st) => xp >= st.minXp), next = stages.where((st) => st.minXp > xp).firstOrNull;
      final perk = [
        'bites for ${stage.bite}',
        if (stage.burn > 0) '+${stage.burn} fire',
        if (stage.crit > 0) '+${stage.crit}% crit',
        if (stage.guard) 'sometimes takes a blow for you',
        if (stage.charm > 0) 'a charm every ${stage.charm} attacks (sleep, weaken, slow, poison, life drain, in turn)',
      ].join(', ');
      rows.add(row(pet.name, stage.name, perk[0].toUpperCase() + perk.substring(1), xp, next?.minXp, petColour(pet)));
    }
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Companions', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 4),
          Text('One companion fights beside you at a time, and it grows with the XP you earn. In a fight, Command sends it in: hounds pounce, a fairy casts a charm, a dragon breathes fire.', style: Txt.onStone(size: 12.5)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

Color petColour(Pet p) => switch (p) {
  Pet.hellhound => const Color(0xFFFF7A2A),
  Pet.wolf => const Color(0xFFC8C4BC),
  Pet.fairy => const Color(0xFFE6B8FF),
};

/// Your home: what it gives you, what you've got to build with, the next one up, and (in a keep)
/// the armoury's gear sets.
class _Home extends StatelessWidget {
  const _Home({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, home = homes[s.home], next = c.nextHome, why = c.whyNotBuild;
    Widget cost(Widget icon, int have, int need) => Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text('$have / $need', style: Txt.label(size: 15, color: have >= need ? const Color(0xFF9BE27A) : const Color(0xFFE88A70))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stone(
          child: Row(
            children: [
              Icon(s.home == 0 ? Icons.holiday_village : (s.home == 1 ? Icons.cottage : Icons.castle), size: 44, color: Palette.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your ${home.name}', style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
                    Text(home.perk, style: Txt.onStone(size: 14)),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const ItemIcon(Item.timber, size: 22),
                        Text(' ${s.timber}   ', style: Txt.label(size: 15, color: Palette.cream)),
                        const ItemIcon(Item.iron, size: 22),
                        Text(' ${s.ironScrap}', style: Txt.label(size: 15, color: Palette.cream)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 10),
          Stone(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('BUILD NEXT', style: Txt.label(size: 12, color: Palette.amber)),
                Text('A ${next.name}', style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
                Text(next.perk, style: Txt.onStone(size: 14)),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    cost(const ItemIcon(Item.coins, size: 22), s.knight.coins, next.gold),
                    cost(const ItemIcon(Item.timber, size: 22), s.timber, next.timber),
                    cost(const ItemIcon(Item.iron, size: 22), s.ironScrap, next.iron),
                  ],
                ),
                if (next.after >= 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.bossesDown.contains(next.after) ? '✓ ${continents[next.after].boss.name} is beaten' : 'First, beat ${continents[next.after].boss.name}',
                    style: Txt.onStone(size: 13, color: s.bossesDown.contains(next.after) ? const Color(0xFF9BE27A) : const Color(0xFFE88A70)),
                  ),
                ],
                const SizedBox(height: 4),
                Text('Timber comes from foes in Cindervale and the Thornwild; iron from Cindervale and the Grimtusk Badlands.', style: Txt.onStone(size: 12.5)),
                const SizedBox(height: 10),
                StoneButton(
                  title: 'Build the ${next.name.toLowerCase()}',
                  caption: why,
                  tone: ButtonTone.blood,
                  onPressed: why == null ? c.buildHome : null,
                ),
              ],
            ),
          ),
        ],
        if (s.home >= 2) ...[
          const SizedBox(height: 10),
          Stone(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('THE ARMOURY', style: Txt.label(size: 12, color: Palette.amber)),
                const SizedBox(height: 6),
                for (var i = 0; i < 2; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            i < s.gearSets.length && s.gearSets[i].isNotEmpty ? 'Set ${i + 1}: ${s.gearSets[i].length} pieces' : 'Set ${i + 1}: empty',
                            style: Txt.label(size: 15, color: Palette.cream),
                          ),
                        ),
                        SizedBox(width: 130, child: StoneButton(title: 'Save what I wear', compact: true, onPressed: () => c.saveGearSet(i))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: StoneButton(title: 'Wear it', compact: true, tone: ButtonTone.blood, onPressed: i < s.gearSets.length && s.gearSets[i].isNotEmpty && !s.inBattle ? () => c.wearGearSet(i) : null),
                        ),
                      ],
                    ),
                  ),
                Text('Pieces you\'re not wearing wait in your chest; Wear it swaps the set\'s pieces on and puts what they replace in the chest.', style: Txt.onStone(size: 12.5)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Training: a point to spend every level, on Might, Arcana, Aim or Vigour. Your build.
class _Training extends StatelessWidget {
  const _Training({required this.controller});
  final GameController controller;

  static const _icons = {Trait.might: Icons.sports_martial_arts, Trait.arcana: Icons.local_fire_department, Trait.aim: Icons.gps_fixed, Trait.vigour: Icons.favorite};
  static const _colours = {Trait.might: Color(0xFFE8A070), Trait.arcana: Color(0xFF9ADFFF), Trait.aim: Color(0xFF9BE27A), Trait.vigour: Color(0xFFE0604A)};

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, free = unspentPoints(k), any = Trait.values.any((t) => trained(k, t) > 0);
    final style = _style(k);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A3024), Color(0xFF1A1510)]),
        border: Border.all(color: free > 0 ? Palette.amber : Palette.stone3, width: free > 0 ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [if (free > 0) BoxShadow(color: Palette.amber.withValues(alpha: .3), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  free > 0 ? 'Training · $free point${free == 1 ? '' : 's'} to spend' : 'Training${style == null ? '' : ' · $style'}',
                  style: Txt.label(size: 15, color: Palette.amber),
                ),
              ),
              if (any)
                TextButton(
                  onPressed: k.coins >= resetTrainingCost(k) && !c.state.inBattle ? c.resetTraining : null,
                  child: Text('Reset (${resetTrainingCost(k)} gold)', style: Txt.label(size: 12, color: Palette.parch2)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final t in Trait.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(_icons[t], color: _colours[t], size: 22),
                  const SizedBox(width: 8),
                  SizedBox(width: 74, child: Text(t.label, style: Txt.label(size: 15, color: Palette.cream))),
                  SizedBox(width: 30, child: Text('${trained(k, t)}', textAlign: TextAlign.right, style: Txt.label(size: 16, color: _colours[t]!, weight: FontWeight.w800))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.perPoint, style: Txt.onStone(size: 12.5))),
                  SizedBox(
                    width: 40,
                    height: 34,
                    child: StoneButton(title: '+', compact: true, tone: ButtonTone.blood, onPressed: free > 0 ? () => c.train(t) : null),
                  ),
                ],
              ),
            ),
          Text('A point every level. Lean into one way of fighting, or keep all three sharp.', style: Txt.onStone(size: 12)),
        ],
      ),
    );
  }

  /// A name for the build, once it leans one way.
  static String? _style(Knight k) {
    final pts = {for (final t in Trait.values) t: trained(k, t)};
    final total = pts.values.fold<int>(0, (a, b) => a + b);
    if (total < 4) return null;
    final top = pts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value < total * .45) return 'Battle-mage of all trades';
    return switch (top.key) {
      Trait.might => 'Blademaster',
      Trait.arcana => 'Ember-sage',
      Trait.aim => 'Deadeye',
      Trait.vigour => 'Ironhide',
    };
  }
}
