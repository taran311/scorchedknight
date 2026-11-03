// Nemeses: the foe that knocked you flat doesn't forget it. It takes a name, tells everyone, and
// comes looking for you on the road, wherever you've got to, a little stronger every time it wins.
// Beat it and you're rid of it, with whatever it took from fallen knights. (After the nemesis of
// Shadow of Mordor: losing should start a story, not just cost gold.) One at a time. Pure Dart.

import 'dart:math' as math;

import 'catalog.dart';

class Nemesis {
  Nemesis({required this.base, required this.look, required this.name, required this.aura, this.rank = 1, this.since = 0, this.wins = 1});

  /// The foe it was (an index into the foe list) and how it's drawn.
  final int base;
  final String look;
  final String name;
  final Aura aura;

  /// How strong it's grown (1 to [nemesisMaxRank]): one more for every time it beats you (and a
  /// level above you for every two).
  int rank;

  /// Fights since you last saw it (it waits a few before it comes for you again).
  int since;

  /// Times it has knocked you out (or seen you run).
  int wins;

  Map<String, dynamic> toJson() => {'b': base, 'l': look, 'n': name, 'a': aura.name, 'r': rank, 's': since, 'w': wins};
  static Nemesis? fromJson(Object? j) {
    if (j is! Map) return null;
    return Nemesis(
      base: (j['b'] as num).toInt(),
      look: j['l'] as String,
      name: j['n'] as String,
      aura: Aura.values.firstWhere((a) => a.name == j['a'], orElse: () => Aura.cursed),
      rank: (j['r'] as num?)?.toInt() ?? 1,
      since: (j['s'] as num?)?.toInt() ?? 0,
      wins: (j['w'] as num?)?.toInt() ?? 1,
    );
  }
}

const nemesisMaxRank = 5;

/// Fights it waits before it can turn up again, and the chance it does on each one after that.
const nemesisWait = 6, nemesisChance = .12;

/// What it pays when it falls: its gold times this (per rank, on top of one), and from this rank
/// up the gear it carries is legendary.
const nemesisGoldPerRank = 1.0, nemesisLegendFrom = 4;

const _given = ['Skarn', 'Vosk', 'Grimmet', 'Hollis', 'Murk', 'Brannoc', 'Yzolde', 'Tharg', 'Edda', 'Corvane', 'Gristle', 'Malk', 'Sorrow', 'Ruk', 'Wenna', 'Ashby'];
const _epithets = ['the Knight-Breaker', 'Who Laughed', 'the Soot-Eater', 'Hero\'s Bane', 'the Unforgotten', 'Twice-Lucky', 'the Gloater', 'Who Took Your Gold', 'the Grudge', 'Ash-Tongue'];
const _fledEpithets = ['Who Watched You Run', 'the Chaser', 'Heel-Biter', 'the Told-You-So'];

/// A name for the foe that beat you (or saw you run).
String nemesisName(math.Random rng, {required bool fled}) {
  final given = _given[rng.nextInt(_given.length)];
  final pool = fled ? _fledEpithets : _epithets;
  final ep = pool[rng.nextInt(pool.length)];
  return ep.startsWith('the ') || ep.startsWith('Who ') ? '$given $ep' : '$given, $ep';
}

/// Its rank's title, for the card and the journal.
String nemesisTitle(int rank) => const ['', 'Grudge-bearer', 'Hunter', 'Tormentor', 'Scourge', 'Nemesis'][rank.clamp(0, nemesisMaxRank)];
