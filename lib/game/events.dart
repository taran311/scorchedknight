// Seasonal events, by the real calendar: for a fortnight or so each year Cindervale celebrates
// something, and the road is a little stranger for it. Pure Dart.

/// The season's event, if one's on.
enum Season { none, hallowash }

extension SeasonInfo on Season {
  String get label => switch (this) {
    Season.hallowash => 'Hallowash',
    Season.none => '',
  };

  /// The word in town when it starts.
  String get greeting => switch (this) {
    Season.hallowash =>
      'Hallowash has come to Cindervale! Pumpkins grin from every doorstep, Hob is making something he calls "soot-toffee", and Mags swears she saw a scarecrow walking on the road. With a pitchfork. And a head that was on fire.',
    Season.none => '',
  };
}

/// What's on, on [day].
Season seasonOn(DateTime day) {
  // Hallowash: the last fortnight of October, and the first days of November.
  if ((day.month == 10 && day.day >= 18) || (day.month == 11 && day.day <= 3)) return Season.hallowash;
  return Season.none;
}

/// Hallowash: the chance the next foe out on the road is Jack o' Cinders instead.
const jackChance = .12;

/// The chance Jack drops his lantern (once you have one, he drops gold and toffee instead).
const lanternChance = .4;
