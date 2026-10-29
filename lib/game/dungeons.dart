// Dungeons: a land's deep places, open once its boss is down. You go in through one door and
// choose your way room by room: every room has two or three doors, and all you get is a clue from
// behind each one. A growl is a fight (sometimes an elite). A glitter is treasure, or a trap set
// to look like it. Silence is a shrine, a key, or a trap. A locked door is a vault, and you need
// a key for it. After the sixth room, one door is left: the boss's, and the hoard behind it.
// Being knocked out ends the run. Pure Dart.

import 'catalog.dart';

class Dungeon {
  const Dungeon({
    required this.id,
    required this.name,
    required this.land,
    required this.x,
    required this.y,
    required this.blurb,
    required this.foes,
    required this.boss,
    required this.setting,
    required this.argb,
    required this.minLevel,
  });

  final String id, name, blurb;

  /// The level you need to go down (its land's boss has to be down too).
  final int minLevel;

  /// The land it's in (open once that land's boss is down), and where its pin sits on the map.
  final int land;
  final double x, y;

  /// Looks of the land's foes that live down here.
  final List<String> foes;

  /// Its boss: (name, base look from the land, drawn as this look instead (or null), aura).
  final (String, String, String?, Aura) boss;

  /// The battleground its fights happen on (a Setting name).
  final String setting;
  final int argb;
}

const dungeons = <Dungeon>[
  Dungeon(
    id: 'warrens',
    name: 'The Goblin Warrens',
    land: 0,
    x: 262,
    y: 398,
    blurb: 'Under the barns, the goblins have been digging. Nobody knew how far. It goes a lot further than the barns.',
    foes: ['goblin', 'goblinChief', 'spider', 'wolf'],
    boss: ('Grubnak the Tunnel-King', 'goblinChief', null, Aura.gilded),
    setting: 'lair',
    argb: 0xFFB8A27A,
    minLevel: 8,
  ),
  Dungeon(
    id: 'ossuary',
    name: 'The Sunken Ossuary',
    land: 1,
    x: 300,
    y: 540,
    blurb: 'A monks\' bone-house that sank into the fen, every shelf still stacked. The bones have started stacking themselves.',
    foes: ['zombie', 'skeleton', 'ghoul', 'skeletonArcher', 'ghost'],
    boss: ('The Drowned Abbot', 'plague', 'ghoulking', Aura.cursed),
    setting: 'crypt',
    argb: 0xFF7A8A6A,
    minLevel: 14,
  ),
  Dungeon(
    id: 'blackmine',
    name: 'The Black Mine',
    land: 3,
    x: 505,
    y: 345,
    blurb: 'The orks dug for iron and found something older. They kept digging anyway. That\'s orks.',
    foes: ['ork', 'orkBerserker', 'minotaur', 'gargoyle'],
    boss: ('Old Gutspike, the Mine Boss', 'orkWarlord', null, Aura.blazing),
    setting: 'deepforge',
    argb: 0xFFB86A3A,
    minLevel: 24,
  ),
  Dungeon(
    id: 'kingstomb',
    name: 'The Tomb of Kings',
    land: 4,
    x: 880,
    y: 395,
    blurb: 'Under the sand, a stair down into the old kings\' tomb. The robbers who found it are still in there, wrapped up neatly.',
    foes: ['mummy', 'tombPriest', 'mummyGuard', 'jackal'],
    boss: ('High Priest Senmut', 'tombPriest', null, Aura.ancient),
    setting: 'tomb',
    argb: 0xFFE0C080,
    minLevel: 28,
  ),
  Dungeon(
    id: 'echopits',
    name: 'The Echo Pits',
    land: 17,
    x: 480,
    y: 610,
    blurb: 'Below the Hollowdeep, shafts so deep a dropped stone never lands. The batkin say their old king still lives at the bottom. He can\'t hear any more. He doesn\'t need to.',
    foes: ['cavebat', 'batkin', 'batkinCaller', 'batkinGuard'],
    boss: ('The Deaf King', 'batkinGuard', null, Aura.cursed),
    setting: 'roost',
    argb: 0xFF7A6A9A,
    minLevel: 24,
  ),
  Dungeon(
    id: 'frozenhalls',
    name: 'The Frozen Halls',
    land: 18,
    x: 690,
    y: 290,
    blurb: 'The frozen city\'s palace, deep under the glacier. Its halls are still lit, blue, from somewhere inside the ice. The Frost-Witch keeps them that way.',
    foes: ['frostReaver', 'yeti', 'iceWraith', 'frostGiant'],
    boss: ('Skadi the Frost-Witch', 'frostSkald', null, Aura.frost),
    setting: 'icecave',
    argb: 0xFF9AC0DC,
    minLevel: 32,
  ),
];

Dungeon? dungeonById(String? id) => dungeons.where((d) => d.id == id).firstOrNull;

/// Rooms before the boss's door.
const dungeonRooms = 6;

/// What you hear (or see) behind a door, and the boss's door at the end.
enum DoorClue { growl, glitter, quiet, locked, boss }

extension DoorClueInfo on DoorClue {
  String get label => switch (this) {
    DoorClue.growl => 'Growling',
    DoorClue.glitter => 'Glittering',
    DoorClue.quiet => 'Silent',
    DoorClue.locked => 'Locked',
    DoorClue.boss => 'The last door',
  };

  /// What it might be, for the door's tooltip.
  String get hint => switch (this) {
    DoorClue.growl => 'Something\'s in there. A fight, maybe a nasty one.',
    DoorClue.glitter => 'Treasure, or something made to look like it.',
    DoorClue.quiet => 'A shrine, a key, or a trap nobody\'s sprung.',
    DoorClue.locked => 'A vault. You need a key.',
    DoorClue.boss => 'Whoever rules down here.',
  };
}

/// What was behind a door.
enum RoomKind { fight, elite, ambush, treasure, trap, shrine, key, vault, boss }

extension RoomKindInfo on RoomKind {
  bool get isFight => this == RoomKind.fight || this == RoomKind.elite || this == RoomKind.ambush || this == RoomKind.boss;

  String get title => switch (this) {
    RoomKind.fight => 'A fight',
    RoomKind.elite => 'An elite!',
    RoomKind.ambush => 'Ambush!',
    RoomKind.treasure => 'Treasure',
    RoomKind.trap => 'A trap!',
    RoomKind.shrine => 'A shrine',
    RoomKind.key => 'A key',
    RoomKind.vault => 'The vault',
    RoomKind.boss => 'The boss',
  };
}

/// What a door turns out to be, rolled from [r] (0 to 1): the clue is a hint, not a promise.
RoomKind roomBehind(DoorClue clue, double r, {required bool hasKey}) => switch (clue) {
  DoorClue.growl => r < .25 ? RoomKind.elite : RoomKind.fight,
  DoorClue.glitter => r < .6 ? RoomKind.treasure : RoomKind.trap,
  DoorClue.quiet => r < .3 ? (hasKey ? RoomKind.shrine : RoomKind.key) : (r < .65 ? RoomKind.shrine : (r < .85 ? RoomKind.trap : RoomKind.ambush)),
  DoorClue.locked => RoomKind.vault,
  DoorClue.boss => RoomKind.boss,
};

/// How likely each clue is on an ordinary door.
const doorWeights = <DoorClue, double>{DoorClue.growl: 45, DoorClue.glitter: 25, DoorClue.quiet: 30};

/// The chance a room has a locked door among its others.
const lockedChance = .3;

/// Levels foes gain over a hero of [level] in room [room]: a third of your level more by the
/// last room, an elite one more, and the boss more again.
int dungeonLevels(int room, RoomKind kind, int level) =>
    (level * .3 * room / dungeonRooms).round() + (kind == RoomKind.elite ? 1 : 0) + (kind == RoomKind.boss ? 2 + level ~/ 10 : 0);

/// The chance you spot a trap in time, and the share of your health one takes if you don't.
const trapSpot = .35, trapHurtMin = .12, trapHurtMax = .22;

/// Health a shrine gives back, and the chance it leaves a potion too.
const shrineHeal = .4, shrinePotion = .3;

/// Gold in a treasure room, a vault and the boss's hoard for a hero of [level], deeper is richer.
int treasureGold(int level, int room) => ((8 + 4 * level) * (1 + room * .1)).round();
int vaultGold(int level) => 30 + 10 * level;
int bossHoardGold(int level) => 50 + 15 * level;

/// Rarity odds (common to legendary) for gear in a treasure room, a vault and the boss's hoard
/// (the first time, and after).
const treasureOdds = [10, 45, 35, 9, 1], vaultOdds = [0, 10, 45, 40, 5], hoardOdds = [0, 0, 20, 65, 15], hoardOddsAgain = [0, 10, 50, 35, 5];

/// The chance a treasure room has a piece of gear in it.
const treasureGearChance = .25;

/// Things that go wrong in a trap room: (what happened, what you saw in time).
const trapTales = [
  ('Darts hiss out of the walls.', 'You spot the holes in the wall and duck the darts.'),
  ('The floor drops away under one foot.', 'You test the floor, and a whole slab drops into the dark.'),
  ('Stones come down from the ceiling.', 'Dust trickles from the ceiling. You wait. The stones come down where you would have been.'),
  ('A blade swings out of the wall at chest height.', 'You spot the slot in the wall and step round the blade when it swings.'),
  ('Green gas puffs up out of the floor.', 'It smells wrong in here. You hold your breath and run through.'),
];
