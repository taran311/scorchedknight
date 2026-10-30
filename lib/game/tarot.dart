// Old Corva's cards: the fortune-teller by the hearth at the Soot & Kettle. Pay her, she turns a
// card, and the card comes true. Pure Dart: the rules only (the faces are painted in the UI).

/// The cards in Old Corva's deck.
enum Tarot { sun, wheel, strength, chariot, star, empress, hermit, fool, magician, death, tower }

/// The Chariot: this much more health (a share of your usual most) for [tarotFights] fights.
const chariotHp = .2;

/// Fights the Strength and Chariot cards last.
const tarotFights = 3;

extension TarotInfo on Tarot {
  String get title => switch (this) {
    Tarot.sun => 'The Sun',
    Tarot.wheel => 'Wheel of Fortune',
    Tarot.strength => 'Strength',
    Tarot.chariot => 'The Chariot',
    Tarot.star => 'The Star',
    Tarot.empress => 'The Empress',
    Tarot.hermit => 'The Hermit',
    Tarot.fool => 'The Fool',
    Tarot.magician => 'The Magician',
    Tarot.death => 'Death',
    Tarot.tower => 'The Tower',
  };

  /// Its number in the old deck.
  String get numeral => switch (this) {
    Tarot.sun => 'XIX',
    Tarot.wheel => 'X',
    Tarot.strength => 'VIII',
    Tarot.chariot => 'VII',
    Tarot.star => 'XVII',
    Tarot.empress => 'III',
    Tarot.hermit => 'IX',
    Tarot.fool => '0',
    Tarot.magician => 'I',
    Tarot.death => 'XIII',
    Tarot.tower => 'XVI',
  };

  /// How often it turns up (out of the deck's total).
  double get weight => switch (this) {
    Tarot.sun || Tarot.wheel => 12,
    Tarot.strength || Tarot.chariot => 11,
    Tarot.star => 10,
    Tarot.hermit => 9,
    Tarot.empress => 8,
    Tarot.fool || Tarot.tower => 6,
    Tarot.death => 4,
    Tarot.magician => 3,
  };

  /// The one ill card in the deck.
  bool get ill => this == Tarot.tower;
}

/// What Old Corva charges to turn a card.
int readingPrice(int level) => 2 + level ~/ 2;
