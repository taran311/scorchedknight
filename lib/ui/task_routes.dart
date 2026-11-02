// Where each task is done: tap a task that's still to do and you're taken there (Mags' brews, the
// forge's suits, your tent's rites, the map…), rather than left to hunt for it.

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/tasks.dart';
import 'hero_page.dart';
import 'hud.dart' show InnBackButton;
import 'map_page.dart';
import 'merchant.dart';
import 'theme.dart';
import 'trail_page.dart';
import 'wilds_page.dart';

/// Where a task is done.
enum _Place { mags, forge, wick, tent, map, trail, wilds }

/// Task → (where, which tab or land). Tasks left out (the vault, combat feats) have nowhere to
/// send you: the vault's card is already on the square, and a feat is done in a fight.
(_Place, String?)? _where(GameTask t) {
  if (t.land != null) return (_Place.trail, '${t.land}');
  if (t.id.startsWith('suit:')) return (_Place.forge, 'suits');
  return switch (t.id) {
    'potion' || 'deal' => (_Place.mags, 'supplies'),
    'dye' => (_Place.mags, 'dyes'),
    'brew' => (_Place.mags, 'brews'),
    'crossbow' || 'steed' => (_Place.mags, 'kit'),
    'forge' => (_Place.forge, 'forge'),
    'temper' => (_Place.forge, 'temper'),
    'piece' || 'relic' => (_Place.forge, 'suits'),
    'bolts' => (_Place.wick, 'bolts'),
    'runeWeapon' || 'runeArmour' => (_Place.wick, 'runes'),
    'equip' || 'train' || 'suit' => (_Place.tent, 'gear'),
    'rite' => (_Place.tent, 'rites'),
    'cottage' || 'keep' => (_Place.tent, 'home'),
    'mend' => (_Place.trail, '0'),
    'wilds' => (_Place.wilds, null),
    'win' || 'explore' || 'gorbo' || 'delve' || 'heroic' || 'king' => (_Place.map, null),
    _ => null,
  };
}

/// Whether tapping [t] takes you somewhere.
bool taskGoes(GameTask t) => _where(t) != null;

/// Off to where [t] is done. Already in your tent, [tent] switches its tab instead of opening
/// another tent on top.
Future<void> goToTask(BuildContext context, GameController c, GameTask t, {void Function(String tab)? tent}) async {
  final w = _where(t);
  if (w == null) return;
  final (place, arg) = w;
  final nav = Navigator.of(context);
  switch (place) {
    case _Place.mags:
      if (!c.state.inBattle) await showMerchantWindow(context, c, tab: arg);
    case _Place.forge:
      if (!c.state.inBattle) await showForgeWindow(context, c, tab: arg);
    case _Place.wick:
      if (!c.state.inBattle) await showEnchanterWindow(context, c, tab: arg);
    case _Place.tent:
      if (tent != null) {
        tent(arg!);
      } else {
        await openTent(context, c, tab: arg);
      }
    case _Place.map:
      await nav.push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c)));
    case _Place.wilds:
      await nav.push(MaterialPageRoute<void>(builder: (_) => WildsPage(controller: c, fromTown: true)));
    case _Place.trail:
      final land = int.parse(arg!);
      // Not open yet: the map, which says what opens it.
      if (c.whyNotTravel(land) != null || land >= continents.length) {
        await nav.push(MaterialPageRoute<void>(builder: (_) => MapPage(controller: c)));
      } else {
        c.travel(land);
        await nav.push(MaterialPageRoute<void>(builder: (_) => TrailPage(controller: c, land: land)));
      }
  }
}

/// Your tent (or cottage, or keep): your gear, rites, satchel, home and journey, opened at [tab].
Future<void> openTent(BuildContext context, GameController c, {String? tab}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
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
          Expanded(child: ListenableBuilder(listenable: c, builder: (context, _) => HeroPage(controller: c, tab: tab))),
        ],
      ),
    ),
  ),
);
