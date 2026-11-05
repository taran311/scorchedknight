// Tasks: small things to do, in order from the first fight to the Ember King, each pointing at a
// part of the game you might not find on your own (Mags' find of the day, tempering, the vault…)
// and paying a little for trying it. Each is done once; whether it's done is read straight from
// the save, so nothing can be missed. Pure Dart.

import 'catalog.dart';
import 'knight_classes.dart';
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
  const GameTask(this.id, this.title, this.done, this.reward, {this.land, this.tier});
  final String id, title;
  final bool Function(GameState s) done;
  final TaskReward reward;

  /// A region to clear (its boss beaten, then beaten again risen; see
  /// GameEngine.landCleared), for the region tasks. Those are never offered as "next": you clear
  /// regions in your own order; they turn up to claim once done.
  final int? land;

  /// A combat feat's tier (0 easy … 4 master): a feat is done in a fight, not asked of you, so,
  /// like a region, it only turns up on the square once you've done it.
  final int? tier;
}

/// The tasks, easiest first. Rewards are kept small on purpose: a nudge to try something, not a
/// way round the road (all of them together come to a few thousand gold, a couple of levels'
/// worth of XP, three keys and three scrolls over the whole game).
final gameTasks = <GameTask>[
  GameTask('win', 'Win a fight', (s) => s.foesFelled >= 1, const TaskReward(gold: 25, xp: .2)),
  GameTask('potion', 'Buy a health potion from Mags', (s) => s.did.contains('potion'), const TaskReward(potions: 1)),
  GameTask('equip', 'Wear a find from your chest, at home', (s) => s.did.contains('equip'), const TaskReward(gold: 40)),
  GameTask('train', 'Spend a training point', (s) => Trait.values.any((t) => trained(s.knight, t) > 0), const TaskReward(xp: .2)),
  GameTask('dye', 'Buy a new dye from Mags', (s) => s.knight.ownedDyes.length > 1, const TaskReward(gold: 30)),
  GameTask('mend', 'Mend the Soot & Kettle', (s) => s.innRepaired, const TaskReward(xp: .3)),
  GameTask('explore', 'Explore a place on the map', (s) => s.explored.isNotEmpty, const TaskReward(gold: 60)),
  GameTask('gorbo', 'Defeat Gorbo the One-Eyed', (s) => s.bossesDown.contains(0), const TaskReward(xp: .3, potions: 1)),
  GameTask('rite', 'Swap a new rite onto your hotbar', (s) => s.did.contains('rite'), const TaskReward(gold: 40)),
  GameTask('deal', 'Buy Mags\' find of the day', (s) => s.did.contains('deal'), const TaskReward(gold: 80)),
  GameTask('crossbow', 'Upgrade your crossbow at Mags\'', (s) => s.knight.crossbow > 0, const TaskReward(gold: 80)),
  GameTask('brew', 'Brew a draught at Mags\'', (s) => s.did.contains('brew'), const TaskReward(gold: 60)),
  GameTask('delve', 'Go down into a dungeon', (s) => s.did.contains('delve'), const TaskReward(xp: .3)),
  GameTask('wilds', 'Head out into the Wilds', (s) => s.did.contains('wilds'), const TaskReward(gold: 100)),
  GameTask('bolts', 'Have Old Wick make bolts from a gem', (s) => s.did.contains('fletch'), const TaskReward(gold: 100)),
  GameTask('runeWeapon', 'Enchant your weapon at Old Wick\'s', (s) => s.did.contains('runeWeapon'), const TaskReward(scrolls: 1)),
  GameTask('runeArmour', 'Enchant your armour at Old Wick\'s', (s) => s.did.contains('runeArmour'), const TaskReward(gold: 150)),
  // (Any steed counts: once a boss has given you one, Mags only has better, later ones to sell.)
  GameTask('steed', 'Get a steed: buy one from Mags, or win one', (s) => s.did.contains('steed') || s.knight.mounts.isNotEmpty, const TaskReward(gold: 150)),
  GameTask('cottage', 'Build the cottage', (s) => s.home >= 1, const TaskReward(xp: .4)),
  GameTask('errand', 'Send Wren on an errand', (s) => s.did.contains('errand'), const TaskReward(gold: 100)),
  GameTask('forge', 'Forge armour at Dunstan\'s', (s) => s.did.contains('craft'), const TaskReward(gold: 200)),
  GameTask('vault', 'Open the Ember Vault', (s) => s.did.contains('vault') || s.vaultFound.isNotEmpty, const TaskReward(keys: 1)),
  GameTask('piece', 'Forge a faction suit piece', (s) => s.did.contains('piece'), const TaskReward(gold: 250)),
  GameTask('temper', 'Bring a piece of gear up to your level at Dunstan\'s', (s) => s.did.contains('temper'), const TaskReward(gold: 300)),
  GameTask('heroic', 'Beat a boss again, risen', (s) => s.risenDown.isNotEmpty, const TaskReward(xp: .5, keys: 1)),
  GameTask('keep', 'Build the keep', (s) => s.home >= 2, const TaskReward(gold: 500)),
  GameTask('relic', 'Forge a relic', (s) => s.forged.isNotEmpty, const TaskReward(xp: .5, scrolls: 2)),
  GameTask('suit', 'Wear a whole faction suit', (s) => suitWorn(s.knight) != null || s.did.any((d) => d.startsWith('suit:')), const TaskReward(gold: 600, keys: 1)),
  GameTask('rank5', 'Reach rank 5 as a class knight', (s) => s.knight.classWins.values.any((w) => w >= rankWins[4]), const TaskReward(gold: 400, scrolls: 1)),
  GameTask('master', 'Master a class: rank 10', (s) => s.knight.classWins.values.any((w) => w >= rankWins.last), const TaskReward(gold: 1000, keys: 1)),
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
    GameTask('suit:$id', knightClassById(id) == null ? 'Wear the whole ${gearSets.firstWhere((g) => g.id == id).name}' : 'Become the ${knightClassById(id)!.name}: wear the whole ${gearSets.firstWhere((g) => g.id == id).name}', (s) => s.did.contains('suit:$id') || suitWorn(s.knight) == id, const TaskReward(gold: 250, scrolls: 1)),
];

/// Combat feats, like a combat achievement list: a way of winning a fight, not just winning it.
/// Done in the fight itself (the engine marks 'feat:id' as it happens) or read from the save.
const featTiers = ['Easy', 'Medium', 'Hard', 'Elite', 'Master'];
const _featGold = [50, 150, 400, 800, 1500];

GameTask _feat(int tier, String id, String title, {bool Function(GameState s)? by, int keys = 0}) =>
    GameTask('feat:$id', title, by ?? (s) => s.did.contains('feat:$id'), TaskReward(gold: _featGold[tier], keys: keys), tier: tier);

final featTasks = <GameTask>[
  _feat(0, 'untouched', 'Win a fight without taking a hit'),
  _feat(0, 'swift', 'Win a fight in 2 turns or fewer'),
  _feat(0, 'clean', 'Make a clean kill with the crossbow'),
  _feat(0, 'rare', 'Defeat a rare foe', by: (s) => s.raresFelled >= 1),
  _feat(0, 'pack', 'Defeat a pack'),
  _feat(0, 'dry', 'Beat a boss without drinking a potion'),
  _feat(1, 'bossSwift', 'Beat a boss in 6 turns or fewer'),
  _feat(1, 'riteBoss', 'Finish a boss with a rite'),
  _feat(1, 'boltBoss', 'Finish a boss with a crossbow bolt'),
  _feat(1, 'over3', 'Defeat a foe 3 levels above you'),
  _feat(1, 'rares10', 'Defeat 10 rare foes', by: (s) => s.raresFelled >= 10),
  _feat(1, 'wilds10', 'Reach step 10 in the Wilds', by: (s) => s.wildBest.values.any((d) => d >= 10)),
  _feat(2, 'bladeBoss', 'Beat a boss with your blade alone (no rites, bolts or potions)', keys: 1),
  _feat(2, 'flawless', 'Beat a boss without taking a hit', keys: 1),
  _feat(2, 'over6', 'Defeat a foe 6 levels above you', keys: 1),
  _feat(2, 'brink', 'Win a fight with less than a tenth of your HP left', keys: 1),
  _feat(2, 'risenDry', 'Beat a risen boss without drinking a potion', keys: 1),
  _feat(2, 'wilds25', 'Reach step 25 in the Wilds', by: (s) => s.wildBest.values.any((d) => d >= 25), keys: 1),
  _feat(3, 'risenFlawless', 'Beat a risen boss without taking a hit', keys: 1),
  _feat(3, 'kingDry', 'Slay the Ember King without drinking a potion', keys: 1),
  _feat(3, 'kingSwift', 'Slay the Ember King in 10 turns or fewer', keys: 1),
  _feat(3, 'rares100', 'Defeat 100 rare foes', by: (s) => s.raresFelled >= 100, keys: 1),
  _feat(4, 'kingFlawless', 'Slay the Ember King without taking a hit', keys: 2),
  _feat(4, 'allRisen', 'Beat every risen boss on the road', by: (s) => s.risenDown.where((c) => c < mainLands).length >= mainLands, keys: 2),
  _feat(4, 'ngKing', 'Slay the Ember King on New Game+', keys: 2),
];

final allTasks = [...gameTasks, ...regionTasks, ...suitTasks, ...featTasks];

GameTask? taskById(String id) => allTasks.where((t) => t.id == id).firstOrNull;
