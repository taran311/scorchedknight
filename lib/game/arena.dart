// The Ash Colosseum: an old imperial arena half-buried at the edge of the Sunken Sands, where the
// Ember King's games-master still sends gladiators out onto the ash for anyone who will fight them.
// Seven bouts, one after another, each a gladiator of a different school; the last is the Champion
// of the Ash. Beat them all and the Champion's own helm and lorica are yours, and on the way the
// rest of the Champion's set (manica, greaves and signet). Pure Dart.

import 'catalog.dart';
import 'loot.dart' show GearSlot;

/// One bout: the gladiator (look, name, how they fight), how far above you they fight, and the
/// piece of the Champion's set it wins (if any).
class ArenaBout {
  const ArenaBout(this.look, this.name, this.school, this.blurb, {this.above = 0, this.prize, this.armoured = false, this.evasive = false, this.strike = Strike.melee, this.hp = 1.0, this.boss = false});
  final String look, name, school, blurb;
  final int above;
  final GearSlot? prize;
  final bool armoured, evasive, boss;
  final Strike strike;
  final double hp;
}

/// The Colosseum's land, and where it sits on the map (it took the Riddling Sphinx's spot).
const arenaLand = 4;
const arenaX = 905.0, arenaY = 245.0;
const arenaName = 'The Ash Colosseum';
const arenaBlurb = 'Half the arena is buried in the dunes, but the sand inside is raked every morning, and the games-master still sits in his box. "Fight," he says, "and the crowd will remember you." There is no crowd. You hear it anyway.';

/// The set the Colosseum gives, and its armour (the Champion's lorica).
const arenaSet = 'arena';

const arenaBouts = <ArenaBout>[
  ArenaBout('murmillo', 'Brutus the Murmillo', 'Murmillo', 'Fish-crested helm, a great scutum and a gladius. He fights behind the shield and waits for you to tire.', armoured: true, hp: 1.15, above: 2),
  ArenaBout('retiarius', 'Nerio the Net-Caster', 'Retiarius', 'No helm, no shield: a net, a trident and quick feet. Half your swings will catch nothing but sand.', evasive: true, hp: 1.0, above: 2, prize: GearSlot.gloves),
  ArenaBout('thraex', 'Sica of Thrace', 'Thraex', 'A griffin on her crest and a curved sica that comes round the edge of any shield.', hp: 1.15, above: 3),
  ArenaBout('hoplomachus', 'Doros the Hoplomachus', 'Hoplomachus', 'Spear and round shield, like the old hoplites. He keeps you at the end of his reach.', armoured: true, hp: 1.2, above: 3, prize: GearSlot.boots),
  ArenaBout('sagittarius', 'Lucia the Sagittaria', 'Sagittaria', 'An archer of the arena: she shoots from across the sand and makes you run the whole of it.', strike: Strike.arrow, hp: 1.1, above: 4, prize: GearSlot.ring),
  ArenaBout('secutor', 'Ferox the Secutor', 'Secutor', 'A smooth, egg-round helm with two small eyeholes, built to chase down net-men. He does not stop coming.', armoured: true, hp: 1.35, above: 5),
  ArenaBout('arenaChampion', 'Ignis, Champion of the Ash', 'Champion', 'Undefeated in a hundred bouts. His crest burns, his spatha is longer than your arm, and the crowd that isn\'t there roars his name.', armoured: true, hp: 2.25, above: 4, boss: true, prize: GearSlot.helm),
];

/// The bout a gladiator look belongs to.
ArenaBout? arenaBoutOf(String? look) => arenaBouts.where((b) => b.look == look).firstOrNull;

/// The foe a gladiator is: their school's way of fighting, at the strength of the Sunken Sands. (The
/// Champion isn't a land's boss: he has a boss's staying power in his HP, not a boss's blows.)
FoeType arenaFoeType(ArenaBout b, Aura aura) => FoeType(b.name, b.look, hp: b.hp, aura: aura, named: true, armoured: b.armoured, evasive: b.evasive, strike: b.strike);

/// The base foe a gladiator stands in for (it sets the land's strength): a Dune Raider of the Sands.
int arenaBase() => lookIndex('duneRaider', arenaLand);

/// The aura each bout fights in.
Aura arenaAura(int bout) => bout == arenaBouts.length - 1 ? Aura.blazing : const [Aura.ancient, Aura.frost, Aura.cursed, Aura.ancient, Aura.gilded, Aura.cursed][bout % 6];
