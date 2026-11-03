// The Hall of the Slain: up on the Frostmarch's highest glacier, a longhall of black timber where
// the warriors who died well still feast, and fight, and rise again the next morning to fight
// again. They'll let the living in, if the living can prove themselves: three waves of them, one
// warrior after another with no rest between, and the last wave led by their Thane. Win a wave's
// worth of fights in a row and it's done; fall (or walk out) mid-wave and the wave starts over.
// The second wave teaches you their War Cry; the Thane carries the Allfather's spear. Pure Dart.

import 'catalog.dart';

/// One warrior of the hall: their look, name and way of fighting. Every one of them roars a war
/// cry now and then (see [FoeType.warcry]).
class Einherjar {
  const Einherjar(this.look, this.name, {this.hp = 1.0, this.armoured = false, this.strike = Strike.melee, this.above = 0});
  final String look, name;
  final double hp;
  final bool armoured;
  final Strike strike;
  final int above;
}

/// A wave: its name, what you're told before it, and its warriors in the order they come.
class HallWave {
  const HallWave(this.name, this.blurb, this.warriors);
  final String name, blurb;
  final List<Einherjar> warriors;
}

/// The hall's land (the Frostmarch) and where it sits on the map (it took the Frozen Caravan's spot).
const hallLand = 18;
const hallX = 785.0, hallY = 238.0;
const hallName = 'The Hall of the Slain';
const hallBlurb = 'A longhall of black timber on the highest glacier, its doors carved with wolves and its roof thatched with shields. Inside, the dead who died well are feasting. They put down their cups when you come in. "One of the living," says the Thane. "Let\'s see you die well."';

const hallWaves = <HallWave>[
  HallWave('The Shieldwall', 'Three of the hall\'s warriors, one after another. No rest between: the hall doesn\'t give any.', [
    Einherjar('einherjarReaver', 'Bjarki Shield-Breaker', hp: 1.05, armoured: true, above: 1),
    Einherjar('einherjarSkald', 'Sigrun of the Long Song', hp: .95, strike: Strike.magic, above: 1),
    Einherjar('einherjarReaver', 'Hallvard Red-Axe', hp: 1.05, armoured: true, above: 1),
  ]),
  HallWave('The Berserkers\' Bench', 'They tear off their shirts and bite their shields. Survive them and the hall will teach you its War Cry.', [
    Einherjar('einherjarBerserker', 'Ulf the Bear-Shirt', hp: 1.1, above: 2),
    Einherjar('einherjarSkald', 'Gunnhild Raven-Voice', hp: 1.05, strike: Strike.magic, above: 2),
    Einherjar('einherjarBerserker', 'Grimkell Wolf-Coat', hp: 1.1, above: 3),
  ]),
  HallWave('The Thane\'s Own', 'His oath-sworn, the frost-giant he wrestled to death and back, and then the Thane himself, with the Allfather\'s spear.', [
    Einherjar('einherjarReaver', 'Thorvald Oathsworn', hp: 1.1, armoured: true, above: 3),
    Einherjar('einherjarGiant', 'Hrungnir the Twice-Slain', hp: 1.2, armoured: true, above: 3),
    Einherjar('einherjarThane', 'Ragnvald, Thane of the Slain', hp: 1.75, armoured: true, above: 3),
  ]),
];

/// The warriors' looks, for the foe they are.
Einherjar? einherjarOf(String? look, String? name) => [for (final w in hallWaves) ...w.warriors].where((e) => e.look == look && (name == null || e.name == name)).firstOrNull;

/// The foe a warrior of the hall is: tough as the Frostmarch, and every one of them roars.
FoeType hallFoeType(Einherjar e, Aura aura) => FoeType(e.name, e.look, hp: e.hp, aura: aura, named: true, armoured: e.armoured, strike: e.strike, warcry: true);

/// The base foe they stand in for (it sets the land's strength): a Frostbound Reaver.
int hallBase() => lookIndex('frostReaver', hallLand);

/// The war cry: how much harder its blows land while it rages, how much softer yours while you're
/// cowed, and for how many of your turns. It roars on its second turn and every fourth after.
const roarHit = 1.3, cowedHit = .8, roarTurns = 3;
bool roarsOn(int turn) => turn >= 2 && (turn - 2) % 4 == 0;

/// Your War Cry (the rite the hall teaches): how much harder your blows land while it lasts.
const warcryBoost = 1.25;
