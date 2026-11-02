// Errands: once you've a cottage, Wren keeps house for you, and for a fee she'll go out while you
// fight: foraging the fields, scavenging the Ashen Wilds, or (from the keep) searching the old
// ruins. She's back after a few of your fights with whatever she found. A little of everything,
// never a fortune. Pure Dart.

/// Your housekeeper.
const retainerName = 'Wren';

class Errand {
  const Errand(this.id, this.name, this.blurb, {required this.fee, required this.perLevel, required this.fights, required this.home});
  final String id, name, blurb;

  /// Gold up front: [fee] and [perLevel] for each of your levels.
  final int fee, perLevel;

  /// Fights you win before she's back.
  final int fights;

  /// The home you need (1: the cottage, 2: the keep).
  final int home;

  int feeAt(int level) => fee + perLevel * level;
}

const errands = <Errand>[
  Errand('fields', 'Forage the fields', 'Timber, iron scrap, and the herbs you\'re shortest of', fee: 40, perLevel: 3, fights: 4, home: 1),
  Errand('wilds', 'Scavenge the Ashen Wilds', 'Gems and ore, and now and then a core', fee: 120, perLevel: 6, fights: 6, home: 1),
  Errand('ruins', 'Search the old ruins', 'A purse, a piece of gear, perhaps a Cinder key', fee: 260, perLevel: 10, fights: 8, home: 2),
];

Errand? errandById(String? id) => errands.where((e) => e.id == id).firstOrNull;
