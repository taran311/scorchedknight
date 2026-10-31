// The shops on the square. Mags' stall: potions and a mystery ring, the crossbow, the first armour
// upgrade, dyes and steeds. Dunstan's forge: golems' ore smelted into bars, the better armour
// forged from them, set pieces from blueprints, and relics. Old Wick's tower: runes, gems ground
// into special bolts, and the wards against each land's hazard. Everything else (weapons, shields, helms, gloves, boots, rings,
// trinkets) comes from the spoils of victory.

import 'package:flutter/material.dart';

import '../art/beasts.dart';
import '../art/looks.dart' show Look, questGiverLooks;
import '../art/griffin.dart';
import '../audio/audio.dart';
import '../art/creatures.dart' show drawFoeDragon, foeDragons;
import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/rules.dart' show crossbowShare, fullSwing, aimBoost;
import '../game/mounts.dart';
import '../game/brews.dart';
import '../game/classes.dart';
import '../game/crafting.dart';
import '../game/loot.dart';
import '../game/controller.dart';
import '../game/rules.dart' show potionHeal;
import 'item_icons.dart';
import 'loot_window.dart' show resolvePendingLoot;
import 'material_icons.dart';
import 'journal_panel.dart' show fmt;
import 'hero_view.dart' show GearIcon, SetChips;
import 'hud.dart' show brewIcon;
import 'stat_icons.dart' show InfoChip, StatChip;
import 'quest_dialog.dart' show NpcPortrait, magsLook;
import 'theme.dart';

const _tierTint = <String, int>{
  'dragonhide': 0xFF2F6A46,
  'bonemail': 0xFFCFC3A6,
  'riveted': 0xFFA8AEB6,
  'scalemail': 0xFFB89A62,
  'blackplate': 0xFF4E525C,
  'fluted': 0xFFE2E8EE,
  'crusader': 0xFFF0F2F4,
  'mithril': 0xFFCFE4F2,
  'obsidian': 0xFF2E2A36,
  'bonerobe': 0xFFCFC3A6,
  'bonescale': 0xFFBFB396,
  'padded': 0xFF7A5233,
  'apprentice': 0xFF6E6252,
  'arcane': 0xFF2F4F86,
  'archmage': 0xFF5A2E7A,
  'astral': 0xFF1C2448,
  'woodsman': 0xFF7A5233,
  'studded': 0xFF5E4026,
  'brigandine': 0xFF3E5232,
  'shadowweave': 0xFF2C2834,
  'emberglass': 0xFF3A2430,
  'emberweave': 0xFF4A1A22,
  'emberhide': 0xFF3A2228,
};

Widget armourIcon(ArmourTier t) => switch (t.id) {
  'chainmail' => const ItemIcon(Item.chainmail),
  'plate' => const ItemIcon(Item.plate),
  'gilded' => const ItemIcon(Item.gilded),
  _ => ItemIcon(Item.armour, tint: Color(_tierTint[t.id] ?? 0xFF7A5233)),
};

/// What the three shops share: a row for a ware, a heading, a "have/need" count and a buy button.
class _Shop {
  _Shop(this.context, this.c);
  final BuildContext context;
  final GameController c;

  static const ok = Color(0xFF9BE27A), short = Color(0xFFE88A70);

  /// A material and how many: "[bar] 4/6", green when there's enough.
  Widget have(Widget icon, int n, [int? need]) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      // Gold reads as a price ("46"), not as "5000/46"; materials as have/need ("0/2").
      Text(need == null ? ' $n' : (icon is ItemIcon && icon.item == Item.coins ? ' $need' : ' $n/$need'), style: Txt.label(size: 13, color: need == null ? Palette.cream : (n >= need ? ok : short))),
    ],
  );

  Widget buy(String id) {
    final e = c.engine, k = c.state.knight;
    if (e.owns(id) && !id.startsWith('dye:')) return Text(id == 'potion' ? 'Belt full' : 'Owned', style: Txt.label(size: 13, color: ok));
    final price = e.priceOf(id);
    return CostButton(
      label: '$price gold',
      onTap: k.coins >= price
          ? () async {
              c.purchase(id);
              Audio.play(Sfx.coins);
              // A box or pouch opens there and then: see what was inside, and wear it or keep it.
              // (It used to slip into your pending loot, so it looked like you'd paid for nothing.)
              if ((id == 'ringbox' || id == 'bonecarver') && c.nextLoot != null && context.mounted) {
                await resolvePendingLoot(context, c, title: 'The box opens', line: c.nextLoot!.rarity.index >= Rarity.epic.index ? 'Mags whistles. "Well! Lucky you."' : 'Mags peers in. "Not bad, dear."');
              }
            }
          : null,
    );
  }

  Widget ware(Widget icon, String name, String desc, Widget action, {Widget? extra}) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .22),
      border: Border.all(color: Colors.black.withValues(alpha: .55)),
      borderRadius: BorderRadius.circular(2),
    ),
    // On a narrow screen the button drops under the words, so neither gets squeezed; either way it
    // shrinks to fit rather than overflow.
    child: LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 360;
        final words = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Txt.onStone(size: 15, color: Palette.cream).copyWith(fontWeight: FontWeight.w700)),
            if (desc.isNotEmpty) Text(desc, style: Txt.onStone(size: 12.5)),
            if (extra != null) Padding(padding: const EdgeInsets.only(top: 3), child: extra),
          ],
        );
        final button = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: narrow ? box.maxWidth - 38 : box.maxWidth * .42),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: action),
        );
        final top = Row(
          children: [
            SizedBox(width: 30, child: icon),
            const SizedBox(width: 8),
            Expanded(child: words),
            if (!narrow) ...[const SizedBox(width: 8), button],
          ],
        );
        if (!narrow) return top;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [top, const SizedBox(height: 4), Align(alignment: Alignment.centerRight, child: button)],
        );
      },
    ),
  );

  Widget heading(String s) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(s, style: Txt.label(size: 13, color: Palette.parch2)),
  );

  Widget gold() => Text('${fmt(c.state.knight.coins)} gold to spend', style: Txt.label(size: 16, color: Palette.amber));

  /// Your crafting stock as a row of icons and counts (only what you have).
  Widget stock({bool metals = true, bool gems = true, bool trophies = false}) {
    final s = c.state;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (metals)
          for (final m in Metal.values)
            if (s.mat(oreKey(m)) > 0) Tooltip(message: m.ore, child: have(MatIcon.ore(m, size: 20), s.mat(oreKey(m)))),
        if (metals)
          for (final m in Metal.values)
            if (s.mat(barKey(m)) > 0) Tooltip(message: '${m.bar}s', child: have(MatIcon.bar(m, size: 20), s.mat(barKey(m)))),
        if (gems)
          for (final g in Gem.values)
            if (s.mat(gemKey(g)) > 0) Tooltip(message: '${g.label}s', child: have(MatIcon.gem(g, size: 20), s.mat(gemKey(g)))),
        if (trophies)
          for (final t in Trophy.values)
            if (s.mat(trophyKey(t)) > 0) Tooltip(message: t.label, child: have(MatIcon.trophy(t, size: 20), s.mat(trophyKey(t)))),
      ],
    );
  }
}

/// Mags' stall: supplies, the crossbow, the first armour upgrade, dyes and the stable.
class MerchantWares extends StatelessWidget {
  const MerchantWares({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, e = c.engine, x = _Shop(context, c);
    final upgrades = [for (final t in tiersFor(k.heroClass).skip(1)) if (!t.dropOnly && t.reduction > armourTierById(k.armour).reduction) t];
    final bought = upgrades.where((t) => !isCrafted(t.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        x.heading('Supplies'),
        x.ware(
          const ItemIcon(Item.potion),
          'Health potion',
          '',
          x.buy('potion'),
          extra: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              InfoChip(icon: const Icon(Icons.favorite, size: 14, color: Color(0xFFE0604A)), text: '+${potionHeal(k)}', dense: true),
              InfoChip(icon: const ItemIcon(Item.potion, size: 14), text: '${k.potions}/$potionBelt', dense: true),
              const InfoChip(icon: Icon(Icons.repeat, size: 14, color: Palette.parch2), text: '$potionsPerFight a fight', dense: true),
            ],
          ),
        ),
        // Mags' find of the day: one piece, seen before you buy, new every day.
        Builder(
          builder: (context) {
            final g = c.dailyDeal, sold = c.whyNotDeal == 'Sold out: back tomorrow';
            final left = c.untilNextDeal, hours = left.inHours, mins = left.inMinutes % 60;
            final when = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
            return x.ware(
              Opacity(opacity: sold ? .4 : 1, child: GearIcon(item: g, size: 30, heroClass: k.heroClass, dye: k.dye)),
              sold ? 'Today\'s find · sold' : 'Today\'s find: ${g.name}',
              sold ? 'Something new in $when' : '${g.rarity.label} ${g.slot.label.toLowerCase()} · new in $when',
              sold
                  ? Text('Sold', style: Txt.label(size: 13, color: _Shop.ok))
                  : CostButton(
                      label: '${c.dealPrice} gold',
                      onTap: c.whyNotDeal == null
                          ? () async {
                              c.buyDeal();
                              Audio.play(g.rarity.index >= Rarity.epic.index ? Sfx.epicDrop : Sfx.coins);
                              if (c.nextLoot != null && context.mounted) await resolvePendingLoot(context, c, title: 'Mags\' find of the day', line: 'She wraps it in a bit of sacking. "Mind how you go."');
                            }
                          : null,
                    ),
              extra: sold ? null : Wrap(spacing: 5, runSpacing: 4, children: [for (final e in g.stats.entries) StatChip(stat: e.key, value: e.value, dense: true)]),
            );
          },
        ),
        x.heading('Brews · each lasts $brewFights fights'),
        for (final b in Brew.values)
          if (b.land <= c.state.unlocked || c.state.reagents[b.land] > 0)
            x.ware(
              MatIcon.brew(Color(b.argb), size: 28),
              b.label,
              '',
              CostButton(
                label: b == Brew.healing ? 'Brew' : (brewOn(k, b) ? (b == Brew.reaperbane ? 'In you' : 'Top up') : 'Brew & drink'),
                onTap: c.whyNotBrew(b) == null
                    ? () {
                        c.brew(b);
                        Audio.play(Sfx.potion);
                      }
                    : null,
              ),
              extra: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InfoChip(icon: Icon(brewIcon(b), size: 14, color: Color(b.argb)), text: b.short, colour: Color(b.argb), dense: true),
                  Tooltip(message: b.ingredient, child: x.have(const Icon(Icons.eco, size: 15, color: Color(0xFF9BE27A)), c.state.reagents[b.land], b.reagents)),
                  x.have(const ItemIcon(Item.coins, size: 14), k.coins, b.fee(k.level)),
                  if (brewOn(k, b) && b != Brew.reaperbane) InfoChip(icon: const Icon(Icons.hourglass_bottom, size: 14, color: _Shop.ok), text: '${k.brews[b.name]} left', colour: _Shop.ok, dense: true),
                ],
              ),
            ),
        x.heading('Crossbow'),
        x.ware(
          const Icon(Icons.gps_fixed, color: Color(0xFFC8A070), size: 26),
          k.crossbow + 1 < crossbows.length ? crossbows[k.crossbow + 1].$1 : crossbows.last.$1,
          k.crossbow + 1 < crossbows.length
              ? 'Shots ~${(fullSwing(k) * crossbows[k.crossbow + 1].$2 * aimBoost(k)).round()} (now ~${(fullSwing(k) * crossbowShare(k) * aimBoost(k)).round()}) · ×$aloftShot vs flyers'
              : 'The best there is',
          x.buy('crossbow'),
        ),
        if (upgrades.isNotEmpty) ...[
          x.heading('${k.heroClass.label} armour'),
          for (final t in bought) x.ware(armourIcon(t), t.name, '−${(t.reduction * 100).round()}% damage taken · now −${(armourTierById(k.armour).reduction * 100).round()}%', x.buy(t.id)),
          if (bought.length < upgrades.length) Text('Better armour: forged at $smithName\'s', style: Txt.onStone(size: 12.5)),
        ],
        x.heading('Dyes · ${switch (k.heroClass) {
          HeroClass.knight => 'cape, tabard, plume and shield',
          HeroClass.mage => 'sash and hat',
          HeroClass.ranger => 'cloak and feather',
        }} · ${prices['dye']} gold'),
        // One row of swatches: tap one you own to wear it, or buy it.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in dyes.where((d) => !seasonalDyes.containsKey(d.id) || k.ownedDyes.contains(d.id) || c.season.name == seasonalDyes[d.id]))
              _DyeSwatch(
                colour: Color(d.argb),
                name: seasonalDyes.containsKey(d.id) ? '${d.name} (this season only)' : d.name,
                owned: k.ownedDyes.contains(d.id),
                wearing: k.dye == d.id,
                price: e.priceOf('dye:${d.id}'),
                onTap: k.ownedDyes.contains(d.id)
                    ? () => c.wearDye(d.id)
                    : (k.coins >= e.priceOf('dye:${d.id}')
                          ? () {
                              c.purchase('dye:${d.id}');
                              Audio.play(Sfx.coins);
                            }
                          : null),
              ),
          ],
        ),
        x.heading('Stable'),
        for (final m in mounts.where((m) => !m.dropOnly)) x.ware(MountIcon(m.id), m.name, m.desc, x.buy('mount:${m.id}')),
      ],
    );
  }
}

/// The smith's forge: smelting golems' ore into bars, forging armour from them, and relics.
class ForgeWares extends StatelessWidget {
  const ForgeWares({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, k = s.knight, x = _Shop(context, c);
    final forged = [for (final t in tiersFor(k.heroClass)) if (isCrafted(t.id) && t.reduction > armourTierById(k.armour).reduction) t];
    final anyOre = Metal.values.any((m) => s.mat(oreKey(m)) > 0 || s.mat(barKey(m)) > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        x.heading('Your ore and bars'),
        if (anyOre || Trophy.values.any((t) => s.mat(trophyKey(t)) > 0)) x.stock(gems: false, trophies: true) else Text('None yet: golems carry ore', style: Txt.onStone(size: 12.5)),
        const SizedBox(height: 4),
        for (final m in Metal.values)
          if (s.mat(oreKey(m)) > 0)
            x.ware(
              MatIcon.ore(m, size: 28),
              'Smelt ${m.ore.toLowerCase()}',
              '$orePerBar lumps make ${withArticle(m.bar.toLowerCase())} · ${smeltFee(k.level)} gold a bar',
              CostButton(
                label: c.engine.barsFrom(m) > 0 ? 'Smelt ${c.engine.barsFrom(m)} · ${c.engine.smeltCost(m)} gold' : 'Need $orePerBar',
                onTap: c.whyNotSmelt(m) == null
                    ? () {
                        c.smelt(m);
                        Audio.play(Sfx.clang);
                      }
                    : null,
              ),
            ),
        x.heading('${k.heroClass.label} armour'),
        if (forged.isEmpty) Text('You wear the best $smithName makes', style: Txt.onStone(size: 12.5)),
        for (final t in forged)
          x.ware(
            armourIcon(t),
            t.name,
            '−${(t.reduction * 100).round()}% damage taken · now −${(armourTierById(k.armour).reduction * 100).round()}%',
            CostButton(
              label: 'Forge',
              onTap: c.whyNotCraft(t.id) == null
                  ? () {
                      c.craftArmour(t.id);
                      Audio.play(Sfx.levelUp);
                    }
                  : null,
            ),
            extra: Wrap(
              spacing: 10,
              children: [
                for (final e in armourRecipes[t.id]!.bars.entries) x.have(MatIcon.bar(e.key, size: 16), s.mat(barKey(e.key)), e.value),
                x.have(const ItemIcon(Item.coins, size: 14), k.coins, armourRecipes[t.id]!.gold),
              ],
            ),
          ),
        // Tempering: a favourite weapon reworked up to your level, so a farmed prize stays useful.
        x.heading('Tempering'),
        if (c.temperable case final w?)
          x.ware(
            GearIcon(item: w, size: 30, heroClass: k.heroClass, dye: k.dye),
            'Temper ${w.name}',
            'Lv ${w.level} → ${k.level}, runes and specials kept',
            CostButton(
              label: 'Temper',
              onTap: c.whyNotTemper() == null
                  ? () {
                      if (c.temper() != null) Audio.play(Sfx.clang);
                    }
                  : null,
            ),
            extra: Wrap(
              spacing: 10,
              children: [
                x.have(MatIcon.bar(c.temperCost(w).$1, size: 16), s.mat(barKey(c.temperCost(w).$1)), c.temperCost(w).$2),
                x.have(const ItemIcon(Item.coins, size: 14), k.coins, c.temperCost(w).$3),
              ],
            ),
          )
        else
          Text('Epic and legendary weapons, back up to your level', style: Txt.onStone(size: 12.5)),
        // Set pieces, from the blueprints the Ashen Order, the vampires and the werewolves carry.
        for (final f in forgedSets)
          if (s.mat(trophyKey(f.trophy)) > 0 || setPieceSlots.any((slot) => s.mat(blueprintKey(f.id, slot)) > 0)) ...[
            x.heading('${gearSetById(f.id)!.name} set · blueprints from ${f.from}'),
            SetChips(set: gearSetById(f.id)!, dense: true, named: false),
            const SizedBox(height: 4),
            for (final slot in setPieceSlots)
              if (s.mat(blueprintKey(f.id, slot)) > 0)
                x.ware(
                  MatIcon.blueprint(size: 28),
                  '${gearSetById(f.id)!.name} ${pieceNoun(slot)}',
                  'Epic, at your level',
                  CostButton(
                    label: 'Forge',
                    onTap: c.whyNotForgePiece(f.id, slot) == null
                        ? () {
                            if (c.forgePiece(f.id, slot) != null) {
                              Audio.play(Sfx.clang);
                              resolvePendingLoot(context, c);
                            }
                          }
                        : null,
                  ),
                  extra: Wrap(
                    spacing: 10,
                    children: [
                      x.have(MatIcon.trophy(f.trophy, size: 16), s.mat(trophyKey(f.trophy)), pieceTrophies),
                      x.have(MatIcon.bar(f.metal, size: 16), s.mat(barKey(f.metal)), pieceBars),
                      x.have(const ItemIcon(Item.coins, size: 14), k.coins, pieceFee(k.level)),
                    ],
                  ),
                )
              else
                x.ware(
                  Opacity(opacity: .35, child: MatIcon.blueprint(size: 28)),
                  '${gearSetById(f.id)!.name} ${pieceNoun(slot)}',
                  'No blueprint yet',
                  const SizedBox(),
                ),
          ],
        // Relics: a blueprint and its parts, forged into a legend.
        if (relics.keys.any((l) => c.heroicOpen(l) && !s.forged.contains(l))) x.heading('Relics'),
        for (final e in relics.entries)
          if (c.heroicOpen(e.key) && !s.forged.contains(e.key)) ...[
            x.ware(
              const Icon(Icons.hardware, color: Color(0xFFFFB04A), size: 26),
              'Forge ${e.key == 2 && k.heroClass == HeroClass.ranger ? 'Briarsong' : e.value.name}',
              '${[for (var i = 0; i < e.value.parts.length; i++) '${hasRelicPart(s.relicParts, e.key, i) ? '✓' : '·'} ${e.value.parts[i].name}'].join('  ')} · Lv ${e.value.minLevel}+',
              CostButton(
                label: '${e.value.gold} gold',
                onTap: c.whyNotForge(e.key) == null
                    ? () {
                        if (c.forgeRelic(e.key) != null) {
                          Audio.play(Sfx.levelUp);
                          resolvePendingLoot(context, c);
                        }
                      }
                    : null,
              ),
            ),
          ],
      ],
    );
  }
}

/// The hedge-mage's tower: runes on your weapon and armour, gems ground into special bolts, and the
/// wards against each land's hazard.
class EnchanterWares extends StatelessWidget {
  const EnchanterWares({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, k = s.knight, x = _Shop(context, c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        x.heading('Runes · ${enchantCost(k.level)} gold a rune'),
        for (final slot in EnchantSlot.values)
          Builder(
            builder: (context) {
              final kit = k.loadout;
              final current = slot == EnchantSlot.weapon ? kit.weapon?.enchant : kit.armourEnchant;
              final what = slot == EnchantSlot.weapon ? (kit.weapon?.name ?? 'No weapon') : armourTierById(kit.armour).name;
              return x.ware(
                Icon(slot == EnchantSlot.weapon ? Icons.auto_fix_high : Icons.shield_moon, color: const Color(0xFFB89AE0), size: 26),
                slot == EnchantSlot.weapon ? 'Your weapon' : 'Your armour',
                '$what · ${current == null ? 'no rune yet' : '${current.title}: ${current.describe}'}',
                k.scrolls > 0
                    ? CostButton(label: 'Read a scroll (${k.scrolls})', onTap: () => enchantFlow(context, c, slot, scroll: true))
                    : CostButton(
                        label: current == null ? 'Enchant' : 'New runes',
                        onTap: k.coins >= enchantCost(k.level) ? () => enchantFlow(context, c, slot) : null,
                      ),
              );
            },
          ),
        // A rune on an old weapon isn't lost when you trade up: Old Wick moves it across.
        if (k.loadout.weapon != null && c.runedSpares.isNotEmpty) ...[
          x.heading('Move a rune · ${c.runeMoveCost} gold'),
          for (final g in c.runedSpares)
            x.ware(
              const Icon(Icons.swap_horiz, color: Color(0xFFB89AE0), size: 26),
              '${g.enchant!.title} from your ${g.name}',
              '→ ${k.loadout.weapon!.name}${k.loadout.weapon!.enchant == null ? '' : ' (replaces ${k.loadout.weapon!.enchant!.title})'}',
              CostButton(
                label: 'Move',
                onTap: c.whyNotMoveRune(g) == null
                    ? () {
                        c.moveRune(g);
                        Audio.play(Sfx.castHoly);
                      }
                    : null,
              ),
            ),
        ],
        if (Elemental.values.any((el) => s.mat(coreKey(el)) > 0)) ...[
          x.heading('Elemental cores · $coresPerRune make a weapon rune'),
          for (final el in Elemental.values)
            if (s.mat(coreKey(el)) > 0)
              x.ware(
                MatIcon.core(Color(el.argb), size: 28),
                'Bind ${el.core.toLowerCase()}s',
                '${enchantmentById(el.rune)!.name} rune, tier II+ · ${enchantCost(k.level)} gold',
                CostButton(
                  label: 'Bind',
                  onTap: c.whyNotBind(el) == null ? () => enchantFlow(context, c, EnchantSlot.weapon, core: el) : null,
                ),
                extra: x.have(MatIcon.core(Color(el.argb), size: 16), s.mat(coreKey(el)), coresPerRune),
              ),
        ],
        x.heading('Special bolts · 1 gem = $ammoBundle'),
        for (final a in AmmoType.values)
          x.ware(
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Color(a.argb).withValues(alpha: .25), border: Border.all(color: Color(a.argb), width: 2)),
              child: Icon(Icons.north_east, size: 16, color: Color(a.argb)),
            ),
            a.label(Missile.bolt),
            '${a.short(k.level)}${(k.ammo[a.name] ?? 0) > 0 ? ' · ×${k.ammo[a.name]}' : ''}',
            extra: x.have(MatIcon.gem(gemFor(a), size: 16), s.mat(gemKey(gemFor(a))), 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((k.ammo[a.name] ?? 0) > 0) ...[
                  k.ammoLoaded == a.name ? Text('Loaded', style: Txt.label(size: 13, color: _Shop.ok)) : CostButton(label: 'Load', onTap: () => c.loadAmmo(a.name)),
                  const SizedBox(width: 6),
                ],
                CostButton(
                  label: 'Fit ${gemFor(a).label.toLowerCase()} · ${fletchFee(k.level)} gold',
                  onTap: c.whyNotFletch(gemFor(a)) == null
                      ? () {
                          c.fletch(gemFor(a));
                          Audio.play(Sfx.coins);
                        }
                      : null,
                ),
              ],
            ),
          ),
        if (s.unlocked > 0 || s.reagents.any((n) => n > 0)) ...[
          x.heading('Wards'),
          for (var i = 1; i < continents.length; i++)
            if (continents[i].ward != null && i <= s.unlocked + 1)
              x.ware(
                Icon(Icons.shield_moon, color: s.warded.contains(i) ? _Shop.ok : const Color(0xFF9ADFFF), size: 26),
                continents[i].ward!,
                'Stops ${continents[i].hazard!.toLowerCase()} · ${continents[i].name}',
                s.warded.contains(i) ? Text('Warded', style: Txt.label(size: 13, color: _Shop.ok)) : CostButton(label: 'Craft', onTap: c.whyNotWard(i) == null ? () => c.craftWard(i) : null),
                extra: s.warded.contains(i)
                    ? null
                    : Wrap(
                        spacing: 10,
                        children: [
                          Tooltip(message: continents[i - 1].reagent, child: x.have(const Icon(Icons.eco, size: 15, color: Color(0xFF9BE27A)), s.reagents[i - 1], reagentsForWard)),
                          x.have(const ItemIcon(Item.coins, size: 14), k.coins, wardPrice(i)),
                        ],
                      ),
              ),
        ],
      ],
    );
  }
}

/// A small picture of a mount, from the same art as the battle.
class MountIcon extends StatelessWidget {
  const MountIcon(this.id, {super.key, this.size = 30});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _MountPainter(id)));
}

class _MountPainter extends CustomPainter {
  _MountPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 190;
    if (id == 'griffin') {
      canvas.save();
      canvas.translate(size.width * .5, size.height * .95);
      canvas.scale(-1, 1);
      drawGriffin(canvas, griffins['griffin']!, Offset.zero, s * .75, 0, still: true);
      canvas.restore();
    } else if (id == 'wyvern') {
      drawFoeDragon(canvas, foeDragons['wyvern']!, Offset(size.width * .35, size.height * .95), s * .9, 0, still: true);
    } else {
      drawHorse(canvas, horseFor(id), Offset(size.width * .42, size.height * .98), s * 1.6, 0, still: true);
    }
  }

  @override
  bool shouldRepaint(_MountPainter old) => old.id != id;
}

/// Pays for runes (or reads a scroll) and offers three to choose from, or keep what you had. With
/// [core], binds three of an elemental's cores into its own rune instead (one offer).
Future<void> enchantFlow(BuildContext context, GameController c, EnchantSlot slot, {bool scroll = false, Elemental? core}) async {
  final kit = c.state.knight.loadout;
  final current = slot == EnchantSlot.weapon ? kit.weapon?.enchant : kit.armourEnchant;
  final bound = core != null ? c.bindCores(core) : null;
  final choices = core != null ? [if (bound != null) bound] : c.enchantChoices(slot, scroll: scroll);
  if (choices.isEmpty || !context.mounted) return;
  if (choices.any((r) => r.tier == 3)) Audio.play(Sfx.epicDrop);
  final pick = await showDialog<EnchantRoll>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stone(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(choices.length == 1 ? 'The rune takes shape…' : 'Three runes take shape. Choose one.', style: Txt.label(size: 15, color: Palette.amber)),
              const SizedBox(height: 10),
              for (final r in choices) ...[
                _RuneCard(roll: r, onTap: () => Navigator.of(context).pop(r)),
                const SizedBox(height: 8),
              ],
              Text(current == null ? 'Nothing to replace yet.' : 'Now: ${current.title}: ${current.describe}', style: Txt.onStone(size: 13)),
              if (current != null) ...[
                const SizedBox(height: 8),
                StoneButton(title: 'Keep ${current.title}', compact: true, onPressed: () => Navigator.of(context).pop()),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  if (pick != null) {
    c.applyEnchant(slot, pick);
    Audio.play(Sfx.coins);
  }
}

/// One rune on offer: its name in its tier's colour (I blue, II violet, III orange), the tier as
/// pips, and what it does. Tap to bind it.
class _RuneCard extends StatefulWidget {
  const _RuneCard({required this.roll, required this.onTap});
  final EnchantRoll roll;
  final VoidCallback onTap;

  @override
  State<_RuneCard> createState() => _RuneCardState();
}

class _RuneCardState extends State<_RuneCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.roll, col = [const Color(0xFF9BC2E8), const Color(0xFFB07AFF), const Color(0xFFF09A2E)][r.tier - 1];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFF1A1512), col, _hover ? .22 : .1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: col.withValues(alpha: _hover ? 1 : .6), width: r.tier == 3 ? 2 : 1.4),
            boxShadow: [if (r.tier == 3 || _hover) BoxShadow(color: col.withValues(alpha: .35), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Icon(Icons.auto_fix_high, color: col, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: Txt.label(size: 17, color: col, weight: FontWeight.w800)),
                    Text(r.describe, style: Txt.onStone(size: 14, color: Palette.cream)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i < r.tier ? col : Colors.transparent, border: Border.all(color: col.withValues(alpha: .7))),
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

class CostButton extends StatelessWidget {
  const CostButton({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .45 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEFC675), Color(0xFFB98634)]),
          ),
          child: Text(label, style: Txt.inkLabel(size: 13, color: const Color(0xFF2A1C0C))),
        ),
      ),
    ),
  );
}

/// A shop window: whoever keeps it (their face, name and one line in a speech bubble), your gold,
/// and their wares.
Future<void> _showShop(BuildContext context, GameController c, {required String name, required String role, required String line, required Look look, required List<Color> glow, required Color colour, required Widget Function() wares, double zoom = 2.8}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Stone(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NpcPortrait(look: look, size: 68, glow: glow, border: colour, zoom: zoom),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: Txt.label(size: 18, color: colour, weight: FontWeight.w800))),
                          // Your gold, as a coin and a number.
                          ListenableBuilder(
                            listenable: c,
                            builder: (context, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [const ItemIcon(Item.coins, size: 16), Text(' ${fmt(c.state.knight.coins)}', style: Txt.label(size: 15, color: Palette.amber, weight: FontWeight.w800))],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20, color: Palette.parch),
                          ),
                        ],
                      ),
                      Text(role, style: Txt.onStone(size: 12, color: Palette.parch2)),
                      const SizedBox(height: 5),
                      // What they say, in a speech bubble like Hob's.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFEDE3CC), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFF2A2016), width: 1.5)),
                        child: Text(line, style: Txt.body(size: 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: RepaintBoundary(child: ListenableBuilder(listenable: c, builder: (context, _) => wares())),
              ),
            ),
            const SizedBox(height: 10),
            StoneButton(title: 'Done', tone: ButtonTone.blood, compact: true, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    ),
  ),
);

/// Mags' stall, from the square.
Future<void> showMerchantWindow(BuildContext context, GameController c) => _showShop(
  context,
  c,
  name: 'Mags',
  role: 'Merchant',
  line: 'Potions, brews, and whatever turned up in my cart today, dear.',
  look: magsLook,
  glow: const [Color(0xFF3A6A3A), Color(0xFF12200F)],
  colour: const Color(0xFF8BD46A),
  wares: () => MerchantWares(controller: c),
);

/// The forge, from the square.
Future<void> showForgeWindow(BuildContext context, GameController c) => _showShop(
  context,
  c,
  name: smithName,
  role: 'Blacksmith',
  line: 'Ore in, armour out. Gold makes it quicker.',
  look: questGiverLooks['smith']!,
  glow: const [Color(0xFFB0501E), Color(0xFF2A0E06)],
  colour: const Color(0xFFFFB04A),
  wares: () => ForgeWares(controller: c),
);

/// The hedge-mage's tower, from the square.
Future<void> showEnchanterWindow(BuildContext context, GameController c) => _showShop(
  context,
  c,
  name: mageName,
  role: 'Hedge-mage',
  line: 'Runes, wards, little stones that burn. Mind the cat.',
  look: questGiverLooks['mage']!,
  zoom: 2.1,
  glow: const [Color(0xFF4A3A8A), Color(0xFF120C24)],
  colour: const Color(0xFFC8A8FF),
  wares: () => EnchanterWares(controller: c),
);

/// A dye as a round swatch: a tick on the one you're wearing, a coin price on ones you don't own.
class _DyeSwatch extends StatelessWidget {
  const _DyeSwatch({required this.colour, required this.name, required this.owned, required this.wearing, required this.price, this.onTap});
  final Color colour;
  final String name;
  final bool owned, wearing;
  final int price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: owned ? (wearing ? '$name · wearing' : '$name · tap to wear') : '$name · $price gold',
    child: GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: Opacity(
          opacity: owned || onTap != null ? 1 : .45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour,
                  border: Border.all(color: wearing ? Palette.amber : Colors.black, width: wearing ? 3 : 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
                ),
                child: wearing ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
              ),
              const SizedBox(height: 2),
              owned
                  ? Text(wearing ? 'On' : 'Owned', style: Txt.label(size: 10.5, color: wearing ? Palette.amber : Palette.parch2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [const ItemIcon(Item.coins, size: 11), Text(' $price', style: Txt.label(size: 10.5, color: Palette.amber))]),
            ],
          ),
        ),
      ),
    ),
  );
}
