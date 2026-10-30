// The road through each land: eight named stops, then the boss's lair. Every win moves you on a
// stop; after the eighth, the lair is open.

import '../game/catalog.dart';
import '../game/models.dart';

/// The stops along each continent's trail, in order.
const trailStops = <List<String>>[
  ['The Barley Fields', 'The Burnt Mill', 'Ash Orchard', 'Toll Bridge', 'Charcoal Barns', 'Smoke Lane', 'The Dry Well', 'Goblin Ditch'],
  ['Drowned Path', 'Reed Maze', 'Lantern Bog', 'Sunken Chapel', 'Mire Steps', 'Witchlight Pool', 'Bone Ferry', 'Fog Hollow'],
  ['Bramble Gate', 'Mossy Hollow', 'The Fallen Giant', 'Thorn Tunnel', 'Owl Hall', 'Root Stair', 'Briar Glade', 'Old Wardstones'],
  ['Red Pass', 'Drum Canyon', 'Tusk Arch', 'Skull Mesa', 'Warband Camp', 'Dust Gulch', 'Totem Field', 'Iron Ford'],
  ['Glassed Shore', 'Dune Sea', 'The Fallen Colossus', 'Jackal Wadi', 'Raider Oasis', 'Avenue of Sphinxes', 'The Sealed Stair', 'Hall of Judgement'],
  ['Glass Flats', 'Crater Rim', 'Steam Vents', 'Obsidian Spires', 'Ash Dunes', 'Wyrm Roost', 'Sulphur Springs', 'The Black Gate'],
  ['Lava Stair', 'Burning Bridge', 'Hall of Cinders', 'Smelter Gate', 'Throne Road', 'Pyre Garden', 'Molten Gallery', 'The Last Door'],
  ['Gallows Cross', 'The Grey Fields', 'Thrall Village', 'Raven Stones', 'Bloodwell Chapel', 'The Drowned Crypt', 'Castle Road', 'The Bat Gate'],
  ['Woodcutters\' Camp', 'Pinefall', 'Claw-Marked Oak', 'The Moon Pool', 'Silver Creek', 'Den of Bones', 'Howling Ridge', 'The Red Clearing'],
  ['The Singing Gate', 'Lantern Boughs', 'The Arrow Bridge', 'Mirror Lake', 'Hall of Leaves', 'The Sleeping Ents', 'Starwatch Steps', 'The Silver Throne'],
  ['The Sealed Door', 'Echo Stair', 'The Long Mine', 'Rune Gallery', 'The Great Bellows', 'Ale Cellars', 'Hall of Ancestors', 'The Anvil Bridge'],
  ['The Ferry Landing', 'Grey Shingle', 'The Drowned Village', 'Mirror Pools', 'The Whispering Steps', 'Hall of Empty Frames', 'The Fog Bell', 'The Masked Chapel'],
  ['The Glass Edge', 'Vine Bridge', 'Basking Rocks', 'The Hatchery', 'Drum Terraces', 'Serpent Steps', 'The Sun Altar', 'The Gilded Stair'],
  ['Shipwreck Cove', 'The Boiled Shallows', 'Merrow Market', 'Coral Arches', 'The Serpent\'s Path', 'Lighthouse Rock', 'The Whirlpool', 'The Edge of the Deep'],
  ['The Wrong Beach', 'Footprints That Change', 'The Village of Strangers', 'Hall of Reflections', 'The Puddle Wood', 'Somebody\'s House', 'Your Own Grave', 'The Unmade Throne'],
  ['The Cloud Stair', 'Harpy Ledges', 'The Rope Bridge', 'Featherfall', 'The Aeriekin Gate', 'Griffin Roosts', 'The Windy Halls', 'The Top of the World'],
  ['Petal Harbour', 'The Red Gate', 'Bamboo Road', 'The Ronin\'s Inn', 'Lantern Bridge', 'The Shinobi Roofs', 'Oni Pass', 'The Thousand Steps'],
  ['The Fallen Hill', 'Glowcap Gallery', 'The Whispering Stair', 'Batkin Market', 'The Drip', 'Ten Thousand Wings', 'The Echo Chamber', 'The Roost Below'],
  ['The White Pass', 'Wolf Run', 'The Frozen Caravan', 'Skald\'s Cairn', 'The Glacier Gate', 'The Drowned-in-Ice City', 'Giants\' Stair', 'The Hall of Hoarfrost'],
];

/// Where each land's boss waits.
const trailLairs = ['Gorbo\'s Barn', 'The Ossuary Mound', 'The Crowned Oak', 'Krugg\'s Hill', 'The Tomb of Nephrakhet', 'The Kennels of Flame', 'The Ember Throne', 'Castle Ravenmoor', 'The Alpha\'s Den', 'The Moonlit Court', 'The Thane\'s Forge', 'The Chapel of Faces', 'The Temple of the Sun', 'The Leviathan\'s Deep', 'The Hall of a Thousand Faces', 'The Thunder Eyrie', 'The Shogun\'s Castle', 'The Mother\'s Roost', 'The Ice Throne'];

/// How far along a land's trail you are: 0 to [winsForBoss] stops cleared.
int trailAt(GameState s, int land) => s.wins[land].clamp(0, winsForBoss);

/// The next step on a land's trail: a stop to fight through, the lair, or (boss beaten) a patrol.
enum TrailStep { stop, lair, patrol }

TrailStep trailStep(GameState s, int land) => s.bossesDown.contains(land)
    ? TrailStep.patrol
    : (trailAt(s, land) >= winsForBoss ? TrailStep.lair : TrailStep.stop);

/// The button's words for the next step.
String trailAction(GameState s, int land) => switch (trailStep(s, land)) {
  TrailStep.stop => 'Onward to ${trailStops[land][trailAt(s, land)]}',
  TrailStep.lair => continents[land].boss.night && s.day ? 'Fight on till nightfall' : 'Storm ${trailLairs[land]}',
  TrailStep.patrol => 'Patrol ${continents[land].name}',
};
