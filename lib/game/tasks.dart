// Tasks: small things to do, in order from the first fight to the Ember King, each pointing at a
// part of the game you might not find on your own (Mags' find of the day, tempering, the vault…)
// and paying a little for trying it. Each is done once; whether it's done is read straight from
// the save, so nothing can be missed. Pure Dart.

import 'catalog.dart';
import 'loot.dart' show gearSets;
import 'models.dart';
import 'rules.dart';

/// What a task pays: gold, a share of a level's XP, health potions, scrolls of enchanting (a
/// free rune each) and Cinder keys.
class TaskReward {
  const TaskReward({this.gold = 0, this.xp = 0, this.potions = 0, this.scrolls = 0, this.keys = 0});
  final int gold, potions, scrolls, keys;

  /// A share of what your next level takes.
  final double xp;
}

class GameTask {
  const GameTask(this.id, this.title, this.done, this.reward, {this.land});
  final String id, title;
  final bool Function(GameState s) done;
  final TaskReward reward;

  /// A region to clear (its boss, risen boss, places, dungeons and relic parts all done; see
  /// GameEngine.landCleared), for the region tasks. Those are never offered as "next": you clear
  /// regions in your own order; they turn up to claim once done.
  final int? land;
}

/// The tasks, easiest first. Rewards are kept small on purpose: a nudge to try something, not a
/// way round the road (all of them together come to a few thousand gold, a couple of levels'
/// worth of XP, three keys and three scrolls over the whole game).
final gameTasks = <GameTask>[
  GameTask('win', 'Win a fight', (s) => s.foesFelled >= 1, const TaskReward(gold: 25, xp: .2)),
  GameTask('potion', 'Buy a health potion from Mags', (s) => s.did.contains('potion'), const TaskReward(potions: 1)),
  GameTask('equip', 'Wear something you found', (s) => s.did.contains('equip'), const TaskReward(gold: 40)),
  GameTask('train', 'Spend a training point', (s) => Trait.values.any((t) => trained(s.knight, t) > 0), const TaskReward(xp: .2)),
  GameTask('rite', 'Put a new rite on your hotbar', (s) => s.did.contains('rite'), const TaskReward(gold: 40)),
  GameTask('dye', 'Buy a new dye', (s) => s.knight.ownedDyes.length > 1, const TaskReward(gold: 30)),
  GameTask('mend', 'Mend the Soot & Kettle', (s) => s.innRepaired, const TaskReward(xp: .3)),
  GameTask('explore', 'Explore a place on the map', (s) => s.explored.isNotEmpty, const TaskReward(gold: 60)),
  GameTask('gorbo', 'Defeat Gorbo the One-Eyed', (s) => s.bossesDown.contains(0), const TaskReward(xp: .3, potions: 1)),
  GameTask('deal', 'Buy Mags\' find of the day', (s) => s.did.contains('deal'), const TaskReward(gold: 80)),
  GameTask('crossbow', 'Upgrade your crossbow', (s) => s.knight.crossbow > 0, const TaskReward(gold: 80)),
  GameTask('brew', 'Brew a draught at Mags\'', (s) => s.did.contains('brew'), const TaskReward(gold: 60)),
  GameTask('delve', 'Go down into a dungeon', (s) => s.did.contains('delve'), const TaskReward(xp: .3)),
  GameTask('wilds', 'Head out into the Wilds', (s) => s.did.contains('wilds'), const TaskReward(gold: 100)),
  GameTask('bolts', 'Fit special bolts at Old Wick\'s', (s) => s.did.contains('fletch'), const TaskReward(gold: 100)),
  GameTask('runeWeapon', 'Enchant your weapon', (s) => s.knight.loadout.weapon?.enchant != null, const TaskReward(scrolls: 1)),
  GameTask('runeArmour', 'Enchant your armour', (s) => s.knight.loadout.armourEnchant != null, const TaskReward(gold: 150)),
  GameTask('steed', 'Buy a steed', (s) => s.knight.mounts.isNotEmpty, const TaskReward(gold: 150)),
  GameTask('cottage', 'Build the cottage', (s) => s.home >= 1, const TaskReward(xp: .4)),
  GameTask('forge', 'Forge armour at Dunstan\'s', (s) => s.did.contains('craft'), const TaskReward(gold: 200)),
  GameTask('vault', 'Open the Ember Vault', (s) => s.did.contains('vault') || s.vaultFound.isNotEmpty, const TaskReward(keys: 1)),
  GameTask('piece', 'Forge a faction suit piece', (s) => s.did.contains('piece'), const TaskReward(gold: 250)),
  GameTask('temper', 'Temper a piece of gear', (s) => s.did.contains('temper'), const TaskReward(gold: 300)),
  GameTask('heroic', 'Beat a risen boss on a Heroic trail', (s) => s.risenDown.isNotEmpty, const TaskReward(xp: .5, keys: 1)),
  GameTask('keep', 'Build the keep', (s) => s.home >= 2, const TaskReward(gold: 500)),
  GameTask('relic', 'Forge a relic', (s) => s.forged.isNotEmpty, const TaskReward(xp: .5, scrolls: 2)),
  GameTask('suit', 'Wear a whole faction suit', (s) => suitWorn(s.knight) != null, const TaskReward(gold: 600, keys: 1)),
  GameTask('king', 'Slay the Ember King', (s) => s.won, const TaskReward(gold: 1000)),
];

/// One task per region: clear it of everything new (the map's gold tick) for a reward. The road's
/// lands give a Cinder key and more gold the further along they are; the side lands some gold.
final regionTasks = <GameTask>[
  for (var c = 0; c < continents.length; c++)
    GameTask('clear:$c', 'Clear ${continents[c].name}', (s) => false, c < mainLands ? TaskReward(gold: 100 * (c + 1), keys: 1) : const TaskReward(gold: 200), land: c),
];

/// One task per faction suit: wear all of it once. Each pays a little gold and a scroll (a free
/// rune for the new kit); the suit itself is the real prize.
final suitTasks = <GameTask>[
  for (final id in suitArts.keys)
    GameTask('suit:$id', 'Wear the whole ${gearSets.firstWhere((g) => g.id == id).name}', (s) => s.did.contains('suit:$id') || suitWorn(s.knight) == id, const TaskReward(gold: 250, scrolls: 1)),
];

final allTasks = [...gameTasks, ...regionTasks, ...suitTasks];

GameTask? taskById(String id) => allTasks.where((t) => t.id == id).firstOrNull;
