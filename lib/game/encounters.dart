// Odd things on the road: now and then, after a win, something stranger than a goblin turns up.
// Each is a little scene with two choices. Pure Dart; the outcomes are worked out in the engine.

class Encounter {
  const Encounter(this.id, this.title, this.text, this.choices);
  final String id, title, text;

  /// The two things you can do.
  final (String, String) choices;
}

const encounters = <Encounter>[
  Encounter(
    'goat',
    'A goat in a tiny hat',
    'A goat in a very small, very fancy hat is standing in the middle of the road. It stares at you. You stare at it. Neither of you blinks.',
    ('Pet the goat', 'Bow to the goat'),
  ),
  Encounter(
    'bard',
    'A travelling bard',
    'A bard with a dented lute offers to write a song about your deeds. "Very heroic. Lots of rhymes for \'soot\'. Small fee."',
    ('Pay the bard', 'No thanks'),
  ),
  Encounter(
    'chest',
    'A chest in the road',
    'A treasure chest sits alone in the middle of the road. No owner, no tracks, no reason. It is very, very suspiciously alone.',
    ('Open it', 'Walk on by'),
  ),
  Encounter(
    'shrine',
    'A wayside shrine',
    'A cracked little shrine to a forgotten god of nice weather. Someone has left a sad, sooty daisy in the offering bowl.',
    ('Say a prayer', 'Leave it be'),
  ),
  Encounter(
    'migs',
    'Migs\'s cart',
    'A cart rattles up. "Migs! Mags\'s cousin! Genuine relics, very cheap, no refunds, no questions." He offers you a sack with something heavy in it.',
    ('Buy the sack', 'Decline politely'),
  ),
  Encounter(
    'chicken',
    'A chicken and a goblin',
    'A goblin is chasing a chicken down the road. The chicken is winning. The goblin looks at you, desperate. So does the chicken.',
    ('Help the goblin', 'Help the chicken'),
  ),
];

Encounter? encounterById(String? id) => encounters.where((e) => e.id == id).firstOrNull;

/// The chance of a wandering encounter after a win on the trail, and the wins that must pass
/// between two of them.
const encounterChance = .08, encounterCalm = 5;

/// Fights a paid-for bard's song keeps you inspired for, and how much harder you hit meanwhile.
const inspiredFights = 3, inspiredBoost = 1.1;
