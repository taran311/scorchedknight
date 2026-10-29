// The Wilds: lawless country off the story's road. You walk in and keep walking, one encounter
// after another (fights, chests, thieves, traps, a campfire if you're lucky), carrying everything
// you find in your pack. Nothing in the pack is yours until you get it home.
//
// Leave from a waystone (every few steps, and the edge you came in by) and you keep it all. Run
// for it anywhere else and you drop part of the pack as you go; bandits follow the wilds' runners
// for exactly this reason. Get knocked flat and most of it is gone. The deeper you go, the
// tougher the foes and the better the finds. Pure Dart.

import 'catalog.dart';

class WildArea {
  const WildArea({
    required this.name,
    required this.blurb,
    required this.lands,
    required this.opensAfter,
    required this.warlord,
    required this.argb,
    required this.ramp,
    this.bandits = const ['rogue', 'pillager'],
  });

  /// Levels foes gain over yours per step in (a fresh hero in the first wilds has less to fall
  /// back on than a veteran in the last).
  final double ramp;
  final String name, blurb;

  /// The lands whose foes roam here, and the land whose boss has to fall before it opens.
  final List<int> lands;
  final int opensAfter;

  /// The named brute who rules the deep wilds: (name, base look, aura).
  final (String, String, Aura) warlord;

  /// Looks of the bandits who prowl here (they turn up more than anyone else).
  final List<String> bandits;
  final int argb;
}

const wildAreas = <WildArea>[
  WildArea(
    name: 'The Ashen Wilds',
    blurb: 'Grey scrub and burned-out farms beyond Cindervale\'s last fence. Bandits, wolves and whatever crawled out of the fen.',
    lands: [0, 1],
    opensAfter: 0,
    warlord: ('The Ash Baron', 'pillager', Aura.gilded),
    argb: 0xFFB8A27A,
    ramp: .3,
  ),
  WildArea(
    name: 'The Briarwaste',
    blurb: 'Thorn thickets taller than houses, ork hunting camps and bears that have stopped being polite.',
    lands: [2, 3],
    opensAfter: 2,
    warlord: ('Old Gnasher, the Bear-King', 'bear', Aura.ancient),
    argb: 0xFF7FA05A,
    ramp: .55,
  ),
  WildArea(
    name: 'The Smoking Marches',
    blurb: 'Cracked plains that still burn underfoot. Drakes, demons and the bravest, stupidest bandits alive.',
    lands: [5, 6],
    opensAfter: 4,
    warlord: ('The Cinder Tyrant', 'ashenChampion', Aura.blazing),
    argb: 0xFFE07A3A,
    ramp: .65,
  ),
];

/// A waystone every this many steps: leave from one (or from the edge, at step 0) and you keep
/// your whole pack.
const waystoneEvery = 5;

/// Share of the pack you lose: running home between waystones, running from a single fight (you
/// stay in the wilds), and being knocked out.
const fleeLoss = .4, fightFleeLoss = .15, koLoss = .75;

/// Share of the pack's gold a thief gets away with if you let him go.
const thiefTake = .2;

/// Whether [depth] is a waystone (or the edge of the wilds).
bool isWaystone(int depth) => depth % waystoneEvery == 0;

/// The next waystone ahead of [depth].
int nextWaystone(int depth) => (depth ~/ waystoneEvery + 1) * waystoneEvery;

/// Levels foes in [area] gain over yours this deep.
int wildLevels(int depth, [int area = 0]) => (depth * wildAreas[area].ramp).floor().clamp(0, 14);

/// Gold from fights this deep is worth this many times the usual (a little under at the edge,
/// since chests and hoards make up the difference).
double wildGold(int depth) => .75 + .04 * depth;

/// Gear found this deep is this many levels above you.
int wildGearLift(int depth) => (depth ~/ 5).clamp(0, 4);

/// Rarity odds (common to legendary) for gear found this deep: better the further you go.
/// Rarity weights for a drop at [depth]: the deeper, the finer, but a legendary only starts to
/// show past the second waystone and stays a prize even deep down (about 1 in 30 at step 30).
List<int> wildOdds(int depth) => [(55 - 3 * depth).clamp(0, 55), 30, 12 + depth, 3 + depth ~/ 2, depth < 10 ? 0 : (depth - 6) ~/ 8];

/// What can turn up on a step into the unknown.
enum WildEvent { fight, rare, pack, warlord, chest, thief, trap, campfire, pedlar, traveller, hoard, waystone }

extension WildEventInfo on WildEvent {
  bool get isFight => this == WildEvent.fight || this == WildEvent.rare || this == WildEvent.pack || this == WildEvent.warlord;

  String get title => switch (this) {
    WildEvent.chest => 'A chest in the ash',
    WildEvent.thief => 'A hand in your pack!',
    WildEvent.trap => 'A snare across the path',
    WildEvent.campfire => 'An abandoned campfire',
    WildEvent.pedlar => 'Pip the pedlar',
    WildEvent.traveller => 'A lost traveller',
    WildEvent.hoard => 'A bandit hoard',
    WildEvent.waystone => 'A waystone',
    _ => '',
  };

  String get text => switch (this) {
    WildEvent.chest => 'Half buried, iron-bound, and very much not yours. It might be treasure. It might be a trap. It is definitely a chest.',
    WildEvent.thief => 'A cutpurse has crept up behind you and has one hand deep in your pack. He freezes. You freeze. He grins.',
    WildEvent.trap => 'A wire glints at ankle height, strung between two burnt stumps. Whoever set it might have left something worth taking nearby.',
    WildEvent.campfire => 'The embers are still warm. Someone left in a hurry, and left a pot of lentil stew bubbling. It smells wonderful.',
    WildEvent.pedlar => 'A tiny pedlar with an enormous backpack. "Pip\'s the name! Potions, fresh-ish! Don\'t ask what\'s in them, I don\'t."',
    WildEvent.traveller => 'A traveller sits on a rock, completely lost, holding a map upside down. "Is this the way to Cindervale? It\'s been three days."',
    WildEvent.hoard => 'Under a tarp behind a rock: a bandit gang\'s stash, sacks of it, and nobody guarding it. Yet.',
    WildEvent.waystone => 'An old carved stone, warm to the touch. Travellers say nothing that steps out of the wilds from here can be followed. Your pack is safe to carry home.',
    _ => '',
  };

  /// The two choices (the second is always the careful one).
  (String, String) get choices => switch (this) {
    WildEvent.chest => ('Open it', 'Leave it'),
    WildEvent.thief => ('Chase him down', 'Let him go'),
    WildEvent.trap => ('Search around it', 'Step over it'),
    WildEvent.campfire => ('Rest and eat', 'Keep moving'),
    WildEvent.pedlar => ('Buy a potion', 'Move on'),
    WildEvent.traveller => ('Walk them to the road', 'Point the way'),
    WildEvent.hoard => ('Grab it all', 'Take a handful'),
    _ => ('', ''),
  };
}

/// How likely each kind of step is this deep ([pack]: anything to steal; [warlordMet]: already
/// faced the warlord this trip).
Map<WildEvent, double> wildWeights(int depth, {required bool pack, required bool warlordMet}) => {
  WildEvent.fight: 50,
  WildEvent.rare: 5 + depth * .4,
  WildEvent.pack: 3 + depth * .3,
  WildEvent.chest: 9,
  if (pack) WildEvent.thief: 7,
  WildEvent.trap: 6,
  WildEvent.campfire: 7,
  WildEvent.pedlar: 3,
  WildEvent.traveller: 3,
  if (depth >= 6) WildEvent.hoard: 3,
  if (depth >= 12 && !warlordMet) WildEvent.warlord: 6,
};

/// Health a rest at a campfire brings back (share of max HP), and what Pip charges for a potion.
const campfireHeal = .35;
int pedlarPrice(int level) => 30 + 5 * level;

/// Gold in a chest, a hoard and a trap-setter's stash this deep, for a hero of [level].
int chestGold(int level, int depth) => ((10 + 5 * level) * wildGold(depth)).round();
int hoardGold(int level, int depth) => ((30 + 12 * level) * wildGold(depth)).round();

/// Everything dropped or taken from the pack: the gold and how many pieces of gear.
class PackLoss {
  const PackLoss(this.gold, this.items);
  final int gold;
  final List<String> items;
  bool get none => gold == 0 && items.isEmpty;
  String get summary => [if (gold > 0) '$gold gold', if (items.isNotEmpty) items.length == 1 ? items.first : '${items.length} pieces of gear'].join(' and ');
}

/// How a trip into the wilds ended.
class WildExit {
  const WildExit({required this.gold, required this.items, required this.lost, required this.depth, required this.safe});
  final int gold, items, depth;
  final PackLoss lost;

  /// Left from a waystone (or the edge): nothing dropped.
  final bool safe;
}

/// Gold and pieces of gear [share] of a pack holding [gold] and [items] pieces comes to (gear
/// rounds to the nearest piece).
(int, int) lossOf(double share, int gold, int items) => ((gold * share).floor(), (items * share).round());

/// Knock-outs on one land's trail before the town starts suggesting the wilds.
const struggleHint = 2;
