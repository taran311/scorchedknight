// Classes, the AdventureQuest way: the armour IS the class. Wear a whole faction suit and you
// fight as that order's knight: its own attack and bash (the suit arts), its own rites, its own
// crossbow bolts, and a rank in it that grows with every fight you win wearing it. Take the suit
// off and you're a knight again, every rank kept. Pure Dart.

import 'models.dart';
import 'rules.dart' show suitWorn;
import 'spells.dart';

class KnightClass {
  const KnightClass({required this.id, required this.name, required this.focus, required this.blurb, required this.argb, required this.passive, required this.passiveText, required this.bolts, required this.boltsText});

  /// The suit's id (a GearSet id): wear all of it and you're this class.
  final String id;

  /// 'Dragon Knight'; and its focus in a few words ('Fire and burst').
  final String name, focus, blurb;
  final int argb;

  /// The rank 10 passive.
  final String passive, passiveText;

  /// What its crossbow bolts do.
  final String bolts, boltsText;

  /// Its rites, in the order they unlock.
  List<Spell> get rites => [for (final s in spells) if (s.order == id) s]..sort((a, b) => a.rank.compareTo(b.rank));
}

const knightClasses = <KnightClass>[
  KnightClass(
    id: 'drakesworn',
    name: 'Dragon Knight',
    focus: 'Fire and burst',
    blurb: 'Sworn to the wyrms of the Caldera. Hits hard and sets everything burning.',
    argb: 0xFFFF7A2A,
    passive: 'Draconic Blood',
    passiveText: 'Every third attack breathes fire: +50% damage',
    bolts: 'Ember bolts',
    boltsText: 'Your bolts set it burning',
  ),
  KnightClass(
    id: 'nightblood',
    name: 'Blood Knight',
    focus: 'Drain and sustain',
    blurb: 'Ravenmoor\'s night order. Heals on the blood it spills, and is hard to put down.',
    argb: 0xFFC8303A,
    passive: 'Undying',
    passiveText: 'Once a fight, a killing blow leaves you on 1 HP',
    bolts: 'Blood bolts',
    boltsText: 'Your bolts heal you a fifth of what they deal',
  ),
  KnightClass(
    id: 'deepforge',
    name: 'Forge Knight',
    focus: 'Guard and stun',
    blurb: 'The dwarves\' iron order. Blocks, wards and stops foes in their tracks.',
    argb: 0xFFE8C060,
    passive: 'Living Steel',
    passiveText: 'A fifth of every blow you block hits back',
    bolts: 'Iron bolts',
    boltsText: 'Your bolts punch through: +25% damage',
  ),
];

KnightClass? knightClassById(String? id) => knightClasses.where((c) => c.id == id).firstOrNull;

/// The class you're fighting as: the suit you wear whole, if it's a class suit.
KnightClass? classOf(Knight k) => knightClassById(suitWorn(k));

/// Renown a win earns: more in the harder lands, so an order you only join late (the dragons are
/// far off) can still be mastered before the Ember King.
int renownFor(int landLevel) => landLevel >= 30 ? 3 : (landLevel >= 18 ? 2 : 1);

/// Renown needed for each rank, 1 to 10: quick at first, slower towards the top. (Kept in
/// [Knight.classWins].)
const rankWins = [0, 8, 18, 30, 44, 60, 78, 98, 120, 150];
const maxRank = 10;

/// Rank in class [id] from the renown you've won in it.
int classRank(Knight k, String id) {
  final w = k.classWins[id] ?? 0;
  return rankWins.where((n) => w >= n).length;
}

/// Renown to the next rank in class [id] (0 at the top).
int winsToNextRank(Knight k, String id) {
  final r = classRank(k, id);
  return r >= maxRank ? 0 : rankWins[r] - (k.classWins[id] ?? 0);
}

/// Whether [k] can use rite [sp] now: a level rite once learned; a class rite while wearing that
/// class's suit, at the rank it unlocks.
bool riteKnown(Knight k, Spell sp) {
  if (sp.order == null) return sp.level <= k.level;
  return classOf(k)?.id == sp.order && classRank(k, sp.order!) >= sp.rank;
}

/// The class passive is on: wearing [id]'s suit at full rank.
bool classPassive(Knight k, String id) => classOf(k)?.id == id && classRank(k, id) >= maxRank;
