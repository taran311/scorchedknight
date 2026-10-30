// A battleground for every foe: goblins in the pines, zombies in a graveyard, pillagers in a
// burning village, skeletons in a crypt, orks at their war camp, dragons in their lairs.
// Each is recorded once into a 960 x 540 picture, like the realm backdrops.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';
import 'silhouette_lands.dart';
import 'scenery.dart' show sceneSize;

enum Setting { forest, road, graveyard, plague, village, castle, warcamp, ruins, crypt, elderwood, blightwood, heartgrove, orkcamp, totems, lair, swamp, ice, volcano, boneyard, summit, coast, desert, tomb, moor, moonwood, deepforge, fogshore, jungle, shiftisle, aerie, blossom, roost, frostruin, icecave }

/// How the floating particles behave: drifting dust, rising embers or ash, or falling snow.
enum MoteStyle { drift, embers, snow, spores, leaves }

extension MoteFalls on MoteStyle {
  /// Snow and leaves fall; everything else rises or drifts.
  bool get falls => this == MoteStyle.snow || this == MoteStyle.leaves;
}

class BattlegroundSpec {
  const BattlegroundSpec({
    required this.sky,
    required this.glow,
    required this.far,
    required this.ridge,
    required this.hill,
    required this.ground,
    required this.path,
    required this.grass,
    required this.mote,
    this.moteStyle = MoteStyle.drift,
    this.mist = const Color(0x21FFFFFF),
    this.stars = false,
    this.moon = false,
    this.sun = const Offset(300, 270),
    this.jagged = 1,
  });
  final List<Color> sky, ground, path;
  final Color glow, far, ridge, hill, grass, mote, mist;
  final MoteStyle moteStyle;
  final bool stars, moon;
  final Offset sun;

  /// How sharp the far mountains are (1 = rolling, 2+ = peaks).
  final double jagged;
}

/// Which battleground each foe fights on (by its look key).
const foeSettings = <String, Setting>{
  'goblin': Setting.forest,
  'rogue': Setting.road,
  'zombie': Setting.graveyard,
  'skeleton': Setting.graveyard,
  'pillager': Setting.village,
  'rose': Setting.castle,
  'goblinChief': Setting.warcamp,
  'assassin': Setting.ruins,
  'plague': Setting.plague,
  'skeletonArcher': Setting.crypt,
  'pillagerCap': Setting.village,
  'roseCmd': Setting.castle,
  'twigling': Setting.elderwood,
  'thornEnt': Setting.elderwood,
  'mossEnt': Setting.elderwood,
  'blightEnt': Setting.blightwood,
  'ironEnt': Setting.elderwood,
  'oakheart': Setting.heartgrove,
  'demonhound': Setting.volcano,
  'cyclops': Setting.lair,
  'bonecolossus': Setting.crypt,
  'gargoyle': Setting.castle,
  'pitdemon': Setting.volcano,
  'demonlord': Setting.volcano,
  'gargoylematriarch': Setting.castle,
  'orkbehemoth': Setting.orkcamp,
  'ork': Setting.orkcamp,
  'orkArcher': Setting.orkcamp,
  'orkShaman': Setting.totems,
  'orkBerserker': Setting.orkcamp,
  'skeletonChampion': Setting.crypt,
  'orkWarlord': Setting.orkcamp,
  'wyvern': Setting.lair,
  'mossDragon': Setting.swamp,
  'frostWyrm': Setting.ice,
  'obsidian': Setting.volcano,
  'dragonboneWarden': Setting.boneyard,
  'elderWyrm': Setting.volcano,
  'emberKing': Setting.volcano,
  'kraken': Setting.coast,
  'wolf': Setting.forest,
  'alphawolf': Setting.ice,
  'spider': Setting.ruins,
  'spiderqueen': Setting.crypt,
  'ghost': Setting.graveyard,
  'banshee': Setting.graveyard,
  'wailingqueen': Setting.graveyard,
  'ghoul': Setting.crypt,
  'ghoulking': Setting.crypt,
  'bear': Setting.forest,
  'cavebear': Setting.lair,
  'unicorn': Setting.heartgrove,
  'moonhorn': Setting.heartgrove,
  'centaur': Setting.road,
  'centaurchief': Setting.warcamp,
  'witch': Setting.swamp,
  'covenmother': Setting.swamp,
  'warlock': Setting.ruins,
  'archwarlock': Setting.volcano,
  'minotaur': Setting.ruins,
  'minotaurlord': Setting.castle,
  'mummy': Setting.desert,
  'mummyGuard': Setting.tomb,
  'tombPriest': Setting.tomb,
  'pharaoh': Setting.tomb,
  'duneRaider': Setting.desert,
  'sandArcher': Setting.desert,
  'jackal': Setting.desert,
  // The Ashen Order.
  'ashenKnight': Setting.volcano,
  'ashenChampion': Setting.volcano,
  // Ravenmoor.
  'thrall': Setting.moor,
  'vampireSpawn': Setting.moor,
  'bloodBride': Setting.moor,
  'vampireKnight': Setting.moor,
  'countess': Setting.moor,
  // The Blossom Isles.
  'ronin': Setting.blossom,
  'ashigaru': Setting.blossom,
  'shinobi': Setting.blossom,
  'onmyoji': Setting.blossom,
  'oni': Setting.blossom,
  'shogun': Setting.blossom,
  // The Hollowdeep.
  'cavebat': Setting.roost,
  'batkin': Setting.roost,
  'batkinCaller': Setting.roost,
  'batkinGuard': Setting.roost,
  'roostMother': Setting.roost,
  // The Frostmarch: glaciers, a city frozen solid, and the ice caves under it.
  'frostReaver': Setting.frostruin,
  'frostSkald': Setting.frostruin,
  'frostJarl': Setting.frostruin,
  'frostGiant': Setting.ice,
  'yeti': Setting.ice,
  'snowwolf': Setting.ice,
  'iceWraith': Setting.icecave,
  // The Skyreach Aeries.
  'harpy': Setting.aerie,
  'aerieWarden': Setting.aerie,
  'aerieSkyshot': Setting.aerie,
  'aerieCaller': Setting.aerie,
  'griffin': Setting.aerie,
  'stormRoc': Setting.aerie,
  // The Changeling Isle.
  'shifter': Setting.shiftisle,
  'shifterSly': Setting.shiftisle,
  'shifterHulk': Setting.shiftisle,
  'thousandfold': Setting.shiftisle,
  // The Shattered Sea.
  'merrowRaider': Setting.coast,
  'drownedSailor': Setting.coast,
  'merrowCaller': Setting.coast,
  'merrowGuard': Setting.coast,
  'seaSerpent': Setting.coast,
  'leviathan': Setting.coast,
  // The Sunscale Jungle.
  'lizardGuard': Setting.jungle,
  'lizardSkirmisher': Setting.jungle,
  'lizardShaman': Setting.jungle,
  'lizardChampion': Setting.jungle,
  'lizardKing': Setting.jungle,
  // The Isle of Mists.
  'facelessWanderer': Setting.fogshore,
  'facelessMimic': Setting.fogshore,
  'facelessChoir': Setting.fogshore,
  'facelessWarden': Setting.fogshore,
  'facelessMother': Setting.fogshore,
  // The Silverwood.
  'elfRanger': Setting.heartgrove,
  'elfBlade': Setting.heartgrove,
  'elfWarden': Setting.heartgrove,
  'elfDruid': Setting.heartgrove,
  'elfQueen': Setting.heartgrove,
  // Deepforge Hold (and its forge golems).
  'dwarfAxe': Setting.deepforge,
  'dwarfShield': Setting.deepforge,
  'dwarfXbow': Setting.deepforge,
  'dwarfRune': Setting.deepforge,
  'dwarfThane': Setting.deepforge,
  'golemIron': Setting.deepforge,
  // The Howling Weald.
  'woodsman': Setting.moonwood,
  'werewolf': Setting.moonwood,
  'werewolfStalker': Setting.moonwood,
  'werewolfBrute': Setting.moonwood,
  'werewolfAlpha': Setting.moonwood,
};

Setting settingFor(String look) => foeSettings[look] ?? Setting.road;

const _specs = <Setting, BattlegroundSpec>{
  // The Hollowdeep: a cavern lit violet from somewhere deeper, glowcaps along the floor, bats
  // hanging from the roof in their thousands.
  Setting.roost: BattlegroundSpec(
    sky: [Color(0xFF0E0A14), Color(0xFF1E1628), Color(0xFF3A2A4A), Color(0xFF5A4A7A)],
    glow: Color(0xFFB8A0FF),
    far: Color(0xFF241C30),
    ridge: Color(0xFF1C1626),
    hill: Color(0xFF181220),
    ground: [Color(0xFF2E2838), Color(0xFF120E16)],
    path: [Color(0xFF4A4058), Color(0xFF241E2C)],
    grass: Color(0xFF0E0A12),
    mote: Color(0x998AF0E0),
    jagged: 2,
  ),
  // The Frostmarch's drowned-in-ice city: a cold blue dusk over towers sheathed in ice.
  Setting.frostruin: BattlegroundSpec(
    sky: [Color(0xFF1A2A4A), Color(0xFF3A5A8A), Color(0xFF8AA8CC), Color(0xFFD8E6F2)],
    glow: Color(0xFFDFF0FF),
    far: Color(0xFF7A90AC),
    ridge: Color(0xFF5A708C),
    hill: Color(0xFF8AA0B8),
    ground: [Color(0xFFD8E4EE), Color(0xFF7A90A4)],
    path: [Color(0xFFB8C8D6), Color(0xFF6A8098)],
    grass: Color(0xFF5A7088),
    mote: Color(0xEEFFFFFF),
    moteStyle: MoteStyle.snow,
    mist: Color(0x40E8F4FF),
    sun: Offset(320, 170),
    jagged: 1.6,
  ),
  // The ice caves: blue light through a glacier roof, icicles, frozen shapes in the walls.
  Setting.icecave: BattlegroundSpec(
    sky: [Color(0xFF0A1424), Color(0xFF16304E), Color(0xFF2E5A82), Color(0xFF6AA0C8)],
    glow: Color(0xFF9ADFFF),
    far: Color(0xFF1E3A58),
    ridge: Color(0xFF16304A),
    hill: Color(0xFF1A3450),
    ground: [Color(0xFF8AB0CC), Color(0xFF2A4A68)],
    path: [Color(0xFFB8D4E8), Color(0xFF5A7A98)],
    grass: Color(0xFF1A2E44),
    mote: Color(0xAADFF4FF),
    jagged: 2.4,
  ),
  // The Blossom Isles: a pink dusk, pagodas on the hills, and petals always falling.
  Setting.blossom: BattlegroundSpec(
    sky: [Color(0xFF3A2A4A), Color(0xFF8A5A7A), Color(0xFFE8A0A8), Color(0xFFFFE0C8)],
    glow: Color(0xFFFFE8D8),
    far: Color(0xFF8A6A8A),
    ridge: Color(0xFF5A4A6A),
    hill: Color(0xFF4A4A5A),
    ground: [Color(0xFF6A7A4A), Color(0xFF2A3420)],
    path: [Color(0xFFC8B898), Color(0xFF7A6A52)],
    grass: Color(0xFF2A3A1E),
    mote: Color(0xEEFFC0D0),
    moteStyle: MoteStyle.leaves,
    mist: Color(0x44FFE0E8),
    sun: Offset(640, 200),
  ),
  // The Skyreach Aeries: above the clouds, in clean blue air the ash never reached.
  Setting.aerie: BattlegroundSpec(
    sky: [Color(0xFF2A5A9A), Color(0xFF5A8AC8), Color(0xFFA8C8E8), Color(0xFFF2F0E8)],
    glow: Color(0xFFFFFAE8),
    far: Color(0xFF8AA0C0),
    ridge: Color(0xFF6A7A98),
    hill: Color(0xFF5A6478),
    ground: [Color(0xFF8A8478), Color(0xFF4A463E)],
    path: [Color(0xFFB8B0A0), Color(0xFF7A7468)],
    grass: Color(0xFF4A5A3A),
    mote: Color(0xCCFFFFFF),
    mist: Color(0x66FFFFFF),
    sun: Offset(720, 120),
    jagged: 3,
  ),
  // The Changeling Isle: ruins under a dusk that can't decide what colour it is.
  Setting.shiftisle: BattlegroundSpec(
    sky: [Color(0xFF140E22), Color(0xFF3A2456), Color(0xFF7A5A8A), Color(0xFFC89AB0)],
    glow: Color(0xFFE8D0FF),
    far: Color(0xFF3A2A4A),
    ridge: Color(0xFF2A1E36),
    hill: Color(0xFF262236),
    ground: [Color(0xFF3A344A), Color(0xFF16121E)],
    path: [Color(0xFF5A5068), Color(0xFF2E2838)],
    grass: Color(0xFF120E18),
    mote: Color(0xAAC8F0E8),
    moteStyle: MoteStyle.spores,
    mist: Color(0x40C8B0E8),
    sun: Offset(620, 170),
  ),
  // The Sunscale Jungle: steaming green under a hot gold sky, vines hanging from giant trunks.
  Setting.jungle: BattlegroundSpec(
    sky: [Color(0xFF1A2A14), Color(0xFF3A5A22), Color(0xFF8AA03A), Color(0xFFE8D27A)],
    glow: Color(0xFFFFE8A0),
    far: Color(0xFF2A4022),
    ridge: Color(0xFF1E3418),
    hill: Color(0xFF223A16),
    ground: [Color(0xFF3E5A22), Color(0xFF16220C)],
    path: [Color(0xFF7A6640), Color(0xFF443822)],
    grass: Color(0xFF0E1A08),
    mote: Color(0xCCFFF0A0),
    moteStyle: MoteStyle.spores,
    mist: Color(0x44D8E8A0),
    sun: Offset(480, 120),
  ),
  // Deepforge Hold: the great hall under the mountain, lit by forges that never went out.
  Setting.deepforge: BattlegroundSpec(
    sky: [Color(0xFF0E0A08), Color(0xFF2A1A10), Color(0xFF5A3418), Color(0xFF9A5A28)],
    glow: Color(0xFFFFB050),
    far: Color(0xFF2A2018),
    ridge: Color(0xFF1E1812),
    hill: Color(0xFF241C16),
    ground: [Color(0xFF3A322C), Color(0xFF161210)],
    path: [Color(0xFF5A5048), Color(0xFF2E2824)],
    grass: Color(0xFF100C0A),
    mote: Color(0x99FFB060),
    moteStyle: MoteStyle.embers,
    jagged: 2,
  ),
  // Ravenmoor by night: a red-tinged moon over the moor and the Countess's black castle.
  Setting.moor: BattlegroundSpec(
    sky: [Color(0xFF08060C), Color(0xFF1C1020), Color(0xFF3A1A2A), Color(0xFF6A3040)],
    glow: Color(0xFFFFD8D0),
    far: Color(0xFF1E141C),
    ridge: Color(0xFF140E14),
    hill: Color(0xFF1C1A1E),
    ground: [Color(0xFF2E2A2A), Color(0xFF121010)],
    path: [Color(0xFF4A4040), Color(0xFF2A2424)],
    grass: Color(0xFF0E0C0C),
    mote: Color(0x66FFB0B8),
    mist: Color(0x38D8B8C8),
    stars: true,
    moon: true,
    sun: Offset(700, 120),
  ),
  // The Howling Weald by night: a full moon over black pines, and mist between the trunks.
  Setting.moonwood: BattlegroundSpec(
    sky: [Color(0xFF060A14), Color(0xFF101C30), Color(0xFF223450), Color(0xFF4A5A78)],
    glow: Color(0xFFF2F4FF),
    far: Color(0xFF1A2434),
    ridge: Color(0xFF121A26),
    hill: Color(0xFF101A18),
    ground: [Color(0xFF1E2A22), Color(0xFF0A100C)],
    path: [Color(0xFF3A3A34), Color(0xFF22221E)],
    grass: Color(0xFF080E0A),
    mote: Color(0x55D8E4FF),
    mist: Color(0x44C8D4F0),
    stars: true,
    moon: true,
    sun: Offset(230, 110),
  ),
  // The Sunken Sands by day: a sun bleached white in an amber haze over dunes of grey-gold sand.
  Setting.desert: BattlegroundSpec(
    sky: [Color(0xFF3A2414), Color(0xFF8A4E22), Color(0xFFD8924A), Color(0xFFF2CE8A)],
    glow: Color(0xFFFFE2A8),
    far: Color(0xFF8A6440),
    ridge: Color(0xFF6E4E30),
    hill: Color(0xFF5A3E24),
    ground: [Color(0xFFB08A58), Color(0xFF5A4028)],
    path: [Color(0xFFC8A270), Color(0xFF8A6A44)],
    grass: Color(0xFF3A2814),
    mote: Color(0x99F2D8A8),
    mist: Color(0x40F2D0A0),
    sun: Offset(640, 230),
  ),
  // Inside the tombs: dusk-gold torchlight on sandstone.
  Setting.tomb: BattlegroundSpec(
    sky: [Color(0xFF140C08), Color(0xFF3A2414), Color(0xFF7A4E26), Color(0xFFB8803E)],
    glow: Color(0xFFFFC870),
    far: Color(0xFF3A2818),
    ridge: Color(0xFF2A1C10),
    hill: Color(0xFF24180E),
    ground: [Color(0xFF7A5E3A), Color(0xFF3A2A18)],
    path: [Color(0xFF9A7A4E), Color(0xFF5A4630)],
    grass: Color(0xFF241608),
    mote: Color(0x88FFD8A0),
    moteStyle: MoteStyle.embers,
    sun: Offset(480, 200),
  ),
  Setting.forest: BattlegroundSpec(
    sky: [Color(0xFF243A3A), Color(0xFF4E6A5E), Color(0xFF9AAA80), Color(0xFFD2C48C)],
    glow: Color(0xFFF2E2A8),
    far: Color(0xFF3E5450),
    ridge: Color(0xFF2E423A),
    hill: Color(0xFF263A28),
    ground: [Color(0xFF3E5230), Color(0xFF1C2816)],
    path: [Color(0xFF6E5E44), Color(0xFF443828)],
    grass: Color(0xFF122012),
    mote: Color(0x99F6F2C8),
  ),
  Setting.road: BattlegroundSpec(
    sky: [Color(0xFF2A3640), Color(0xFF56686F), Color(0xFFA3A48A), Color(0xFFCDBB8C)],
    glow: Color(0xFFF2D9A2),
    far: Color(0xFF46525A),
    ridge: Color(0xFF36413F),
    hill: Color(0xFF34402F),
    ground: [Color(0xFF4A5634), Color(0xFF262E1A)],
    path: [Color(0xFF8A7454), Color(0xFF5A4732)],
    grass: Color(0xFF151D12),
    mote: Color(0x8CFFF6D8),
  ),
  Setting.graveyard: BattlegroundSpec(
    sky: [Color(0xFF0A0E1A), Color(0xFF1A2236), Color(0xFF34405A), Color(0xFF5A6478)],
    glow: Color(0xFFE6ECF4),
    far: Color(0xFF232A38),
    ridge: Color(0xFF1A202C),
    hill: Color(0xFF1C2420),
    ground: [Color(0xFF2A3224), Color(0xFF12160E)],
    path: [Color(0xFF4A4436), Color(0xFF2A261E)],
    grass: Color(0xFF0C120A),
    mote: Color(0x66C8D8F0),
    mist: Color(0x40C8D4E8),
    stars: true,
    moon: true,
    sun: Offset(760, 110),
  ),
  Setting.plague: BattlegroundSpec(
    sky: [Color(0xFF10140C), Color(0xFF2A3418), Color(0xFF5A6A2A), Color(0xFF8A8E4A)],
    glow: Color(0xFFD8E070),
    far: Color(0xFF283018),
    ridge: Color(0xFF1E2412),
    hill: Color(0xFF222A14),
    ground: [Color(0xFF343A1E), Color(0xFF14180A)],
    path: [Color(0xFF4E4A30), Color(0xFF2A281A)],
    grass: Color(0xFF0E1208),
    mote: Color(0x99B6C86A),
    moteStyle: MoteStyle.spores,
    mist: Color(0x55A8C050),
    moon: true,
    sun: Offset(720, 120),
  ),
  Setting.village: BattlegroundSpec(
    sky: [Color(0xFF1A0E0C), Color(0xFF4A1E14), Color(0xFF9A3E1E), Color(0xFFD87A3A)],
    glow: Color(0xFFFFA04A),
    far: Color(0xFF3A2420),
    ridge: Color(0xFF2A1A18),
    hill: Color(0xFF2E2018),
    ground: [Color(0xFF3E3226), Color(0xFF1C1610)],
    path: [Color(0xFF6E5640), Color(0xFF3E3022)],
    grass: Color(0xFF14100A),
    mote: Color(0xCCFF8A3A),
    moteStyle: MoteStyle.embers,
    mist: Color(0x30FF8A4A),
    sun: Offset(700, 330),
  ),
  Setting.castle: BattlegroundSpec(
    sky: [Color(0xFF140A10), Color(0xFF3A1420), Color(0xFF7A2A2A), Color(0xFFB85A40)],
    glow: Color(0xFFFF9A6A),
    far: Color(0xFF2E1E24),
    ridge: Color(0xFF22161A),
    hill: Color(0xFF241A1A),
    ground: [Color(0xFF3A3030), Color(0xFF181414)],
    path: [Color(0xFF6A6060), Color(0xFF3A3434)],
    grass: Color(0xFF120E0E),
    mote: Color(0x99FF6A5A),
    sun: Offset(250, 300),
  ),
  Setting.warcamp: BattlegroundSpec(
    sky: [Color(0xFF1E1810), Color(0xFF4A3A20), Color(0xFF9A7A3A), Color(0xFFD8B060)],
    glow: Color(0xFFFFD27A),
    far: Color(0xFF4A3E2A),
    ridge: Color(0xFF3A3020),
    hill: Color(0xFF3A3220),
    ground: [Color(0xFF4E4228), Color(0xFF241E12)],
    path: [Color(0xFF7A6646), Color(0xFF463A28)],
    grass: Color(0xFF1A160C),
    mote: Color(0x99FFC86A),
    moteStyle: MoteStyle.embers,
  ),
  Setting.ruins: BattlegroundSpec(
    sky: [Color(0xFF0E0C16), Color(0xFF2A2236), Color(0xFF5A3E4A), Color(0xFF9A6A5A)],
    glow: Color(0xFFF0C8A0),
    far: Color(0xFF2A2430),
    ridge: Color(0xFF1E1A24),
    hill: Color(0xFF221E22),
    ground: [Color(0xFF34302E), Color(0xFF161414)],
    path: [Color(0xFF5E5650), Color(0xFF34302C)],
    grass: Color(0xFF100E0E),
    mote: Color(0x66E8D8C8),
    stars: true,
    moon: true,
    sun: Offset(220, 120),
  ),
  Setting.crypt: BattlegroundSpec(
    sky: [Color(0xFF0C0A0A), Color(0xFF1C1816), Color(0xFF2A2420), Color(0xFF3A322A)],
    glow: Color(0xFFFFB050),
    far: Color(0xFF221E1A),
    ridge: Color(0xFF1A1714),
    hill: Color(0xFF1A1714),
    ground: [Color(0xFF3A342C), Color(0xFF16130F)],
    path: [Color(0xFF4A4238), Color(0xFF2A241E)],
    grass: Color(0xFF0E0C0A),
    mote: Color(0x55E8D8B0),
  ),
  Setting.elderwood: BattlegroundSpec(
    sky: [Color(0xFF0E1A14), Color(0xFF1E3426), Color(0xFF3E5E3A), Color(0xFF7A8E5A)],
    glow: Color(0xFFD8F0A0),
    far: Color(0xFF1E2E22),
    ridge: Color(0xFF16241A),
    hill: Color(0xFF1A2A18),
    ground: [Color(0xFF2E3E22), Color(0xFF121A0C)],
    path: [Color(0xFF4A4630), Color(0xFF26241A)],
    grass: Color(0xFF0C140A),
    mote: Color(0xCCE8FF8A),
    moteStyle: MoteStyle.spores,
    mist: Color(0x38A8D890),
    sun: Offset(520, 140),
  ),
  Setting.blightwood: BattlegroundSpec(
    sky: [Color(0xFF0C0810), Color(0xFF1E1426), Color(0xFF3A2A44), Color(0xFF5E4A5E)],
    glow: Color(0xFFC890FF),
    far: Color(0xFF1C1622),
    ridge: Color(0xFF14101A),
    hill: Color(0xFF1A1418),
    ground: [Color(0xFF2A2228), Color(0xFF100C10)],
    path: [Color(0xFF3E3438), Color(0xFF201A1E)],
    grass: Color(0xFF0C080C),
    mote: Color(0xAAC07AFF),
    moteStyle: MoteStyle.spores,
    mist: Color(0x45906AB0),
    moon: true,
    sun: Offset(700, 110),
  ),
  Setting.heartgrove: BattlegroundSpec(
    sky: [Color(0xFF1E1408), Color(0xFF4A3014), Color(0xFF9A6A2A), Color(0xFFE0B060)],
    glow: Color(0xFFFFD27A),
    far: Color(0xFF3A2C18),
    ridge: Color(0xFF2C2010),
    hill: Color(0xFF34280E),
    ground: [Color(0xFF4A3A1E), Color(0xFF1E160A)],
    path: [Color(0xFF6E5A38), Color(0xFF3A2E1C)],
    grass: Color(0xFF181208),
    mote: Color(0xEEE8822A),
    moteStyle: MoteStyle.leaves,
    mist: Color(0x30FFD88A),
    sun: Offset(640, 200),
  ),
  Setting.orkcamp: BattlegroundSpec(
    sky: [Color(0xFF1C2018), Color(0xFF3E4A2C), Color(0xFF8A8A4A), Color(0xFFC8A860)],
    glow: Color(0xFFE8C870),
    far: Color(0xFF3A3A2A),
    ridge: Color(0xFF2C2C20),
    hill: Color(0xFF34301E),
    ground: [Color(0xFF5A4E30), Color(0xFF2A2416)],
    path: [Color(0xFF7A6646), Color(0xFF463A28)],
    grass: Color(0xFF1A1A10),
    mote: Color(0x99FFB060),
    moteStyle: MoteStyle.embers,
  ),
  Setting.totems: BattlegroundSpec(
    sky: [Color(0xFF0A1410), Color(0xFF14302A), Color(0xFF2A5A44), Color(0xFF6A8A5A)],
    glow: Color(0xFFA8F08A),
    far: Color(0xFF1E2E26),
    ridge: Color(0xFF16221C),
    hill: Color(0xFF1A2618),
    ground: [Color(0xFF34402A), Color(0xFF141A10)],
    path: [Color(0xFF4E5238), Color(0xFF2A2C1E)],
    grass: Color(0xFF0E140A),
    mote: Color(0xAA9AFF7A),
    moteStyle: MoteStyle.spores,
    mist: Color(0x406AE080),
    stars: true,
    moon: true,
    sun: Offset(480, 90),
  ),
  Setting.lair: BattlegroundSpec(
    sky: [Color(0xFF120C10), Color(0xFF2E1E22), Color(0xFF5A3A2E), Color(0xFF8A5A3A)],
    glow: Color(0xFFFFB060),
    far: Color(0xFF2E2228),
    ridge: Color(0xFF221A1E),
    hill: Color(0xFF2A2020),
    ground: [Color(0xFF3E3430), Color(0xFF181412)],
    path: [Color(0xFF5A4A40), Color(0xFF2E2620)],
    grass: Color(0xFF120E0C),
    mote: Color(0x99FFC070),
    moteStyle: MoteStyle.embers,
    jagged: 2,
  ),
  Setting.swamp: BattlegroundSpec(
    sky: [Color(0xFF142018), Color(0xFF2A4030), Color(0xFF5A7A50), Color(0xFF9AA870)],
    glow: Color(0xFFE0F0A0),
    far: Color(0xFF2A3A2C),
    ridge: Color(0xFF1E2C20),
    hill: Color(0xFF203020),
    ground: [Color(0xFF2E4026), Color(0xFF121C10)],
    path: [Color(0xFF3A4A34), Color(0xFF1E2A1C)],
    grass: Color(0xFF0E180C),
    mote: Color(0xAAD8F09A),
    moteStyle: MoteStyle.spores,
    mist: Color(0x4090C080),
  ),
  Setting.ice: BattlegroundSpec(
    sky: [Color(0xFF6A8AAE), Color(0xFF9AB8D4), Color(0xFFC8DCEC), Color(0xFFEAF2F8)],
    glow: Color(0xFFFFFFFF),
    far: Color(0xFFA8BED4),
    ridge: Color(0xFF8AA4BE),
    hill: Color(0xFFC0D2E2),
    ground: [Color(0xFFE2ECF4), Color(0xFF9AB0C4)],
    path: [Color(0xFFC8D6E2), Color(0xFF8AA0B4)],
    grass: Color(0xFF7A92A8),
    mote: Color(0xEEFFFFFF),
    moteStyle: MoteStyle.snow,
    mist: Color(0x50FFFFFF),
    sun: Offset(640, 150),
    jagged: 2.4,
  ),
  Setting.volcano: BattlegroundSpec(
    sky: [Color(0xFF0E0608), Color(0xFF2E0E0E), Color(0xFF7A1E14), Color(0xFFD0501E)],
    glow: Color(0xFFFF6A2A),
    far: Color(0xFF241416),
    ridge: Color(0xFF1A0E10),
    hill: Color(0xFF1E1212),
    ground: [Color(0xFF2E2222), Color(0xFF100A0A)],
    path: [Color(0xFF3E2E2A), Color(0xFF1E1614)],
    grass: Color(0xFF0E0808),
    mote: Color(0xEEFF7A2A),
    moteStyle: MoteStyle.embers,
    mist: Color(0x30FF5A2A),
    sun: Offset(720, 220),
    jagged: 2,
  ),
  Setting.boneyard: BattlegroundSpec(
    sky: [Color(0xFF0C0814), Color(0xFF221832), Color(0xFF443058), Color(0xFF7A5A84)],
    glow: Color(0xFFD8B0FF),
    far: Color(0xFF221A2E),
    ridge: Color(0xFF1A1424),
    hill: Color(0xFF201A26),
    ground: [Color(0xFF34303A), Color(0xFF141218)],
    path: [Color(0xFF4E4A54), Color(0xFF2A2830)],
    grass: Color(0xFF0E0C12),
    mote: Color(0xAAC07AFF),
    mist: Color(0x40A080D0),
    stars: true,
    moon: true,
    sun: Offset(640, 100),
    jagged: 1.6,
  ),
  Setting.summit: BattlegroundSpec(
    sky: [Color(0xFF0E0A18), Color(0xFF2A1A3A), Color(0xFF6A2A3A), Color(0xFFC0583A)],
    glow: Color(0xFFFF5A3A),
    far: Color(0xFF2A2234),
    ridge: Color(0xFF1E1826),
    hill: Color(0xFF241C24),
    ground: [Color(0xFF3A2E30), Color(0xFF161012)],
    path: [Color(0xFF5E4A44), Color(0xFF2E2420)],
    grass: Color(0xFF0E0A0A),
    mote: Color(0xCCFF7A3A),
    moteStyle: MoteStyle.embers,
    moon: true,
    stars: true,
    sun: Offset(250, 110),
    jagged: 2.6,
  ),
  Setting.coast: BattlegroundSpec(
    sky: [Color(0xFF1A2A3E), Color(0xFF3A5A72), Color(0xFF8AA6B0), Color(0xFFD8C8A4)],
    glow: Color(0xFFF6E6C0),
    far: Color(0xFF4A5E6E),
    ridge: Color(0xFF2E4A5E),
    hill: Color(0xFF24506A),
    ground: [Color(0xFFC2A878), Color(0xFF6E5A3E)],
    path: [Color(0xFF9A8460), Color(0xFF6A5640)],
    grass: Color(0xFF4A5A3A),
    mote: Color(0x99EAF6FF),
    mist: Color(0x40DDEEFF),
    sun: Offset(700, 250),
  ),
  // The Isle of Mists: a grey shore, a grey sea, and fog so thick the sun is only a pale smudge.
  Setting.fogshore: BattlegroundSpec(
    sky: [Color(0xFF3A3E44), Color(0xFF6A7078), Color(0xFF9AA0A6), Color(0xFFC8CACC)],
    glow: Color(0xFFE8EAEC),
    far: Color(0xFF6A7076),
    ridge: Color(0xFF50565C),
    hill: Color(0xFF464C52),
    ground: [Color(0xFF7A7670), Color(0xFF3A3834)],
    path: [Color(0xFF8A8680), Color(0xFF5A5650)],
    grass: Color(0xFF3A3E38),
    mote: Color(0x88F2F4F6),
    mist: Color(0x88D8DCE0),
    sun: Offset(640, 200),
  ),
};

BattlegroundSpec specFor(Setting s) => _specs[s]!;

/// The light that rims figures in this place: its sky glow, at full strength and a touch brighter.
Color rimFor(BattlegroundSpec g) => Color.lerp(g.glow.withValues(alpha: 1), const Color(0xFFFFF4E0), .25)!;

final Map<Setting, ui.Picture> _cache = {};

/// The battleground picture for a foe (by look key).
ui.Picture battleground(String look) => battlegroundOf(settingFor(look));

ui.Picture battlegroundOf(Setting s) {
  return _cache.putIfAbsent(s, () {
    final rec = ui.PictureRecorder();
    paintSilhouetteLand(Canvas(rec, Offset.zero & sceneSize), s, specFor(s));
    return rec.endRecording();
  });
}

Paint _vertical(List<Color> cs, double top, double bottom) =>
    Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), cs, List.generate(cs.length, (i) => i / (cs.length - 1)));

Paint _radial(Offset centre, double radius, Color colour, List<double> alphas, List<double> stops) =>
    Paint()..shader = ui.Gradient.radial(centre, radius, [for (final a in alphas) colour.withValues(alpha: a)], stops);

/// Paints the battleground for [s] into a 960 x 540 canvas.
void paintBattleground(Canvas c, Setting s) {
  if (s == Setting.crypt) return _crypt(c, specFor(s));
  final sp = specFor(s), r = SeededRandom(s.index * 31 + 7);
  // Sky, stars, sun or moon.
  c.drawRect(Offset.zero & sceneSize, _vertical(sp.sky, 0, 540));
  if (sp.stars) {
    for (var i = 0; i < 60; i++) {
      final p = Offset(r.next() * 960, r.next() * 240);
      c.drawCircle(p, r.next() * 1.3 + .3, Paint()..color = Color.fromRGBO(244, 236, 216, r.next() * .6 + .2));
    }
  }
  c.drawCircle(sp.sun, sp.moon ? 140 : 300, _radial(sp.sun, sp.moon ? 140 : 300, sp.glow, const [.8, .3, 0], const [0, .25, 1]));
  c.drawCircle(sp.sun, sp.moon ? 26 : 30, Paint()..color = sp.glow.withValues(alpha: .9));
  if (sp.moon) c.drawCircle(sp.sun + const Offset(8, -4), 22, Paint()..color = sp.sky[1].withValues(alpha: .35));

  // Mountains, then whatever stands behind the ridge.
  final far = Path()..moveTo(0, 330), ridge = Path()..moveTo(0, 340), hill = Path()..moveTo(0, 368);
  for (var x = 0.0; x <= 960; x += 16) {
    final peak = sp.jagged > 1 ? math.pow(math.sin(x / 110 + 1).abs(), 1 / sp.jagged).toDouble() : math.sin(x / 140 + 1).abs();
    far.lineTo(x, 300 - 70 * sp.jagged * peak * .8 - 30 * math.sin(x / 53) - 12 * r.next());
    ridge.lineTo(x, 326 - 36 * math.sin(x / 90 + 2).abs() - 10 * math.sin(x / 31));
    hill.lineTo(x, 356 - 14 * math.sin(x / 120 + .5) - 6 * math.sin(x / 41));
  }
  for (final p in [far, ridge, hill]) {
    p
      ..lineTo(960, 540)
      ..lineTo(0, 540)
      ..close();
  }
  c.drawPath(far, Paint()..color = sp.far.withValues(alpha: .92));
  if (s == Setting.coast || s == Setting.fogshore) {
    // Open sea to the horizon, with long swells and the sun's glitter on it.
    c.drawRect(const Rect.fromLTWH(0, 300, 960, 80), _vertical(const [Color(0xFF3E7A94), Color(0xFF24506A), Color(0xFF16384E)], 300, 380));
    final glint = Paint()..color = const Color(0x66FFF2D0);
    for (var i = 0; i < 40; i++) {
      final x = 560 + r.next() * 280, y = 304 + r.next() * 60;
      c.drawLine(Offset(x, y), Offset(x + 6 + r.next() * 14, y), glint..strokeWidth = 1.4);
    }
    final swell = strokePaint(const Color(0x40DDF2FF), 1.6);
    for (var row = 0; row < 5; row++) {
      final y = 318.0 + row * 12, p = Path()..moveTo(0, y);
      for (var x = 0.0; x <= 960; x += 40) {
        p.quadraticBezierTo(x + 20, y - 3, x + 40, y);
      }
      c.drawPath(p, swell);
    }
    // Surf breaking on the beach.
    c.drawRect(const Rect.fromLTWH(0, 370, 960, 6), Paint()..color = const Color(0xCCEAF6F8));
  } else {
  _behindRidge(c, s, sp, r);
  c.drawPath(ridge, Paint()..color = sp.ridge);
  c.drawRect(
    const Rect.fromLTWH(-200, 300, 1360, 70),
    Paint()
      ..color = sp.mist
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );
  c.drawPath(hill, Paint()..color = sp.hill);
  _treeLine(c, s, sp, r);
  }

  // Ground and path.
  c.drawRect(const Rect.fromLTWH(0, 372, 960, 168), _vertical(sp.ground, 372, 540));
  final path = svgPath('M0,418 C160,412 300,424 480,416 C660,408 800,420 960,414 L960,488 C800,494 640,482 480,490 C320,498 160,486 0,492 Z');
  c.drawPath(path, _vertical(sp.path, 410, 495));
  c.drawPath(svgPath('M0,418 C160,412 300,424 480,416 C660,408 800,420 960,414'), strokePaint(const Color(0x40000000), 3));
  final stone = Paint()..color = const Color(0x33000000);
  for (var i = 0; i < 14; i++) {
    final x = r.next() * 960, y = 432 + r.next() * 50, w = 4 + r.next() * 8;
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w * 2, height: w * .9), stone);
  }
  _props(c, s, sp, r);

  // Grass, or snow drifts, or cinders.
  final grass = Path();
  for (var x = 0.0; x < 960; x += 6 + r.next() * 10) {
    final y = 508 + r.next() * 30, h = (s == Setting.ice ? 4 : 10) + r.next() * (s == Setting.volcano ? 4 : 16);
    grass
      ..moveTo(x, y)
      ..quadraticBezierTo(x + 2 + r.next() * 4, y - h * .6, x + r.next() * 8 - 2, y - h);
  }
  c.drawPath(grass, strokePaint(sp.grass, 2.4));
  // A low mist over graveyards, swamps and the boneyard.
  if (const {Setting.graveyard, Setting.plague, Setting.swamp, Setting.boneyard, Setting.totems, Setting.elderwood, Setting.blightwood, Setting.jungle}.contains(s)) {
    c.drawRect(
      const Rect.fromLTWH(-100, 470, 1160, 80),
      Paint()
        ..color = sp.mist
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }
}

// ------------------------------------------------------------------- behind the ridge

void _behindRidge(Canvas c, Setting s, BattlegroundSpec sp, SeededRandom r) {
  final dark = Paint()..color = sp.ridge;
  switch (s) {
    case Setting.castle || Setting.moor:
      // The Black Rose keep (and, on Ravenmoor, the Countess's): towers, curtain wall and crimson banners.
      for (final d in const [
        'M560,300 L560,190 L574,190 L574,180 L586,180 L586,190 L600,190 L600,180 L612,180 L612,190 L626,190 L626,300 Z',
        'M626,300 L626,230 L760,230 L760,300 Z',
        'M640,230 L640,216 L652,216 L652,230 Z M668,230 L668,216 L680,216 L680,230 Z M696,230 L696,216 L708,216 L708,230 Z M724,230 L724,216 L736,216 L736,230 Z',
        'M760,300 L760,160 L800,160 L800,300 Z',
        'M752,160 L780,110 L808,160 Z',
        'M520,300 L520,240 L560,240 L560,300 Z',
      ]) {
        c.drawPath(svgPath(d), Paint()..color = const Color(0xFF1A1014));
      }
      for (final x in const [574.0, 772.0]) {
        c.drawPath(poly([Offset(x, 196), Offset(x + 18, 196), Offset(x + 18, 236), Offset(x + 9, 228), Offset(x, 236)]), Paint()..color = const Color(0xFF7A1418));
        c.drawCircle(Offset(x + 9, 210), 3.4, Paint()..color = const Color(0xFF1A0A0A));
      }
      final lit = Paint()..color = const Color(0xCCFFB050);
      for (final p in const [Offset(590, 220), Offset(778, 190), Offset(690, 260)]) {
        c.drawRect(Rect.fromCenter(center: p, width: 4, height: 7), lit);
      }
    case Setting.village:
      // Burning cottages with smoke columns.
      for (final (x, w, h) in const [(520.0, 70.0, 40.0), (610.0, 56.0, 34.0), (690.0, 80.0, 44.0), (800.0, 60.0, 36.0)]) {
        c.drawRect(Rect.fromLTWH(x, 330 - h, w, h + 10), dark);
        c.drawPath(poly([Offset(x - 8, 330 - h), Offset(x + w / 2, 300 - h), Offset(x + w + 8, 330 - h)]), dark);
        c.drawCircle(Offset(x + w / 2, 314 - h), 30, _radial(Offset(x + w / 2, 314 - h), 30, const Color(0xFFFF8A2A), const [.9, .4, 0], const [0, .4, 1]));
        for (var i = 0; i < 5; i++) {
          final p = Offset(x + w / 2 + i * 8 - 10, 290 - h - i * 30);
          c.drawCircle(
            p,
            16 + i * 6,
            Paint()
              ..color = const Color(0x40282020)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }
      }
    case Setting.ruins || Setting.shiftisle:
      // Broken arches of an old town.
      for (final x in const [520.0, 640.0, 760.0]) {
        c.drawRect(Rect.fromLTWH(x, 250, 18, 80), dark);
        c.drawRect(Rect.fromLTWH(x + 70, 270 + (x % 3) * 6, 18, 60), dark);
        c.drawPath(
          Path()
            ..moveTo(x, 252)
            ..quadraticBezierTo(x + 44, 210, x + 88, 268)
            ..lineTo(x + 70, 270)
            ..quadraticBezierTo(x + 44, 236, x + 18, 256)
            ..close(),
          dark,
        );
      }
    case Setting.lair:
    case Setting.summit:
    case Setting.deepforge:
      // A great cave mouth (in Deepforge Hold, the forge-hall's gate) glowing with the hoard's light.
      final mouth = Path()
        ..moveTo(560, 330)
        ..quadraticBezierTo(600, 180, 720, 170)
        ..quadraticBezierTo(840, 180, 880, 330)
        ..close();
      c.drawPath(mouth, Paint()..color = const Color(0xFF0E080A));
      c.drawCircle(const Offset(720, 320), 120, _radial(const Offset(720, 320), 120, const Color(0xFFFFB040), const [.5, .15, 0], const [0, .4, 1]));
    case Setting.volcano:
      // A smoking volcano with a lava run.
      final cone = Path()
        ..moveTo(520, 330)
        ..lineTo(660, 150)
        ..lineTo(720, 150)
        ..lineTo(880, 330)
        ..close();
      c.drawPath(cone, Paint()..color = const Color(0xFF1A0E10));
      c.drawCircle(const Offset(690, 150), 60, _radial(const Offset(690, 150), 60, const Color(0xFFFF6A1A), const [.9, .3, 0], const [0, .4, 1]));
      c.drawPath(
        Path()
          ..moveTo(684, 152)
          ..quadraticBezierTo(670, 220, 700, 260)
          ..quadraticBezierTo(720, 300, 690, 330),
        strokePaint(const Color(0xFFFF7A2A), 5),
      );
      for (var i = 0; i < 5; i++) {
        c.drawCircle(
          Offset(690 + i * 12.0, 120 - i * 26.0),
          20 + i * 8.0,
          Paint()
            ..color = const Color(0x40201414)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
    case Setting.heartgrove:
      // The great heart-oak: a vast trunk, roots and a golden glow in its hollow.
      final trunk = Path()
        ..moveTo(600, 340)
        ..quadraticBezierTo(640, 250, 640, 120)
        ..lineTo(740, 120)
        ..quadraticBezierTo(740, 250, 790, 340)
        ..close();
      c.drawPath(trunk, Paint()..color = const Color(0xFF2A1C0E));
      c.drawCircle(const Offset(690, 260), 60, _radial(const Offset(690, 260), 60, const Color(0xFFFFD45A), const [.85, .3, 0], const [0, .35, 1]));
      c.drawOval(const Rect.fromLTWH(676, 236, 28, 44), Paint()..color = const Color(0xFFFFE8A0));
      final crown = Paint()..color = const Color(0xFF8A4A1A);
      for (final (x, y, rr) in const [(690.0, 90.0, 120.0), (590.0, 120.0, 80.0), (800.0, 120.0, 80.0), (690.0, 30.0, 90.0)]) {
        c.drawCircle(Offset(x, y), rr, crown);
      }
      for (final (x, y, rr) in const [(650.0, 70.0, 60.0), (750.0, 90.0, 50.0), (700.0, 20.0, 50.0)]) {
        c.drawCircle(Offset(x, y), rr, Paint()..color = const Color(0xFFB8642A));
      }
    case Setting.boneyard:
      // The ribs of something enormous, long dead.
      final bone = strokePaint(const Color(0xFF6A6070), 9)..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final x = 540.0 + i * 52;
        c.drawPath(
          Path()
            ..moveTo(x, 330)
            ..quadraticBezierTo(x - 30, 230, x + 30, 180 + (i - 2.5).abs() * 14),
          bone,
        );
      }
      c.drawLine(const Offset(520, 330), const Offset(860, 300), bone);
    case Setting.ice:
      // Ice spires catching the light.
      for (final (x, h) in const [(560.0, 120.0), (610.0, 80.0), (700.0, 150.0), (780.0, 100.0), (840.0, 130.0)]) {
        final spire = poly([Offset(x - 22, 330), Offset(x, 330 - h), Offset(x + 22, 330)]);
        c.drawPath(spire, Paint()..shader = ui.Gradient.linear(Offset(x - 20, 0), Offset(x + 20, 0), const [Color(0xFFEFF8FF), Color(0xFF9AC4E0), Color(0xFF5A84A8)], const [0, .5, 1]));
      }
    default:
      break;
  }
}

// ------------------------------------------------------------------- tree line

void _treeLine(Canvas c, Setting s, BattlegroundSpec sp, SeededRandom r) {
  final dark = sp.ridge, trees = Path();
  if (s == Setting.elderwood || s == Setting.blightwood || s == Setting.jungle) {
    // Huge old trunks rising out of frame, with roots and hanging moss.
    final bark = s == Setting.blightwood ? const Color(0xFF1E1620) : const Color(0xFF1A2414);
    for (final (x, w) in const [(40.0, 70.0), (250.0, 46.0), (450.0, 60.0), (640.0, 40.0), (880.0, 80.0)]) {
      final y = 380 - 10 * math.sin(x / 120 + .5);
      c.drawPath(
        Path()
          ..moveTo(x - w * .8, y)
          ..quadraticBezierTo(x - w * .5, y - 30, x - w * .5, y - 80)
          ..lineTo(x - w * .4, -10)
          ..lineTo(x + w * .4, -10)
          ..lineTo(x + w * .5, y - 80)
          ..quadraticBezierTo(x + w * .5, y - 30, x + w * .8, y)
          ..close(),
        Paint()..color = bark,
      );
      c.drawPath(Path()..moveTo(x - w * .2, 0)..quadraticBezierTo(x - w * .1, y * .5, x - w * .25, y - 40), strokePaint(const Color(0x22000000), 3));
      final moss = s == Setting.blightwood ? const Color(0x664A3A5A) : const Color(0x664E7A3A);
      for (var k = 0; k < 4; k++) {
        c.drawLine(Offset(x - w * .3 + k * w * .2, 60 + k * 14.0), Offset(x - w * .3 + k * w * .2, 120 + k * 30.0), strokePaint(moss, 2));
      }
    }
    return;
  }
  final pines = s == Setting.forest || s == Setting.road || s == Setting.ice || s == Setting.moonwood;
  final dead = const {Setting.heartgrove, Setting.graveyard, Setting.plague, Setting.ruins, Setting.boneyard, Setting.village, Setting.totems}.contains(s);
  final willows = s == Setting.swamp;
  if (s == Setting.warcamp || s == Setting.orkcamp) {
    // A spiked palisade along the hill.
    final stake = ramp(s == Setting.orkcamp ? 0xFF4A3A26 : 0xFF5A4630, .2, .5);
    for (var x = 180.0; x < 800; x += 13) {
      final y = 376 - 10 * math.sin(x / 120 + .5);
      fillPath(c, poly([Offset(x, y), Offset(x, y - 34), Offset(x + 5.5, y - 44 - (x % 26 < 13 ? 4 : 0)), Offset(x + 11, y - 34), Offset(x + 11, y)]), stake, Offset(x, 0), Offset(x + 11, 0), width: 1);
    }
    return;
  }
  if (!pines && !dead && !willows) return;
  for (var x = -10.0; x < 980; x += (s == Setting.forest || s == Setting.moonwood ? 7 : 12) + r.next() * 16) {
    final h = (s == Setting.forest || s == Setting.moonwood ? 50 : 34) + r.next() * 56, w = 9 + r.next() * 7, y = 372 - 10 * math.sin(x / 120 + .5);
    if (pines) {
      trees.addPolygon([
        Offset(x - w, y),
        Offset(x - w * .55, y - h * .45),
        Offset(x - w * .8, y - h * .45),
        Offset(x, y - h),
        Offset(x + w * .8, y - h * .45),
        Offset(x + w * .55, y - h * .45),
        Offset(x + w, y),
      ], true);
    } else if (willows) {
      trees.addOval(Rect.fromCenter(center: Offset(x, y - h * .7), width: w * 3, height: h * .7));
      trees.addRect(Rect.fromLTWH(x - 2, y - h * .5, 4, h * .5));
    } else if (r.next() < .5) {
      trees
        ..moveTo(x, y)
        ..lineTo(x, y - h)
        ..moveTo(x, y - h * .6)
        ..lineTo(x - w, y - h * .8)
        ..moveTo(x, y - h * .45)
        ..lineTo(x + w, y - h * .7);
    }
  }
  if (dead) {
    c.drawPath(trees, strokePaint(dark, 3));
  } else {
    c.drawPath(trees, Paint()..color = s == Setting.ice ? const Color(0xFF6A8AA4) : (willows ? const Color(0xFF1A2A18) : const Color(0xFF16221A)));
    if (s == Setting.ice) {
      // Snow on the boughs.
      final snow = Paint()..color = const Color(0xCCFFFFFF);
      for (var x = 0.0; x < 960; x += 23) {
        c.drawOval(Rect.fromCenter(center: Offset(x, 330 + (x % 3) * 8), width: 12, height: 4), snow);
      }
    }
  }
}

// ------------------------------------------------------------------- props on the ground

/// Background props sit in the gaps behind the fighters (left edge, middle, right edge) and above
/// the road, so they never cover anyone.
void _props(Canvas c, Setting s, BattlegroundSpec sp, SeededRandom r) {
  const spots = [40.0, 120.0, 400.0, 500.0, 600.0, 860.0, 930.0];
  switch (s) {
    case Setting.graveyard || Setting.plague || Setting.moor:
      final stone = s == Setting.plague ? const [Color(0xFF8A8E6A), Color(0xFF5A5E40), Color(0xFF2A2C1C)] : const [Color(0xFF8A90A0), Color(0xFF5A606E), Color(0xFF2A2E36)];
      for (final (i, x) in spots.indexed) {
        final y = 404.0 + (i % 3) * 4, h = 26.0 + (i % 2) * 8;
        if (i % 3 == 1) {
          // A cross.
          fillPath(c, Path()..addRect(Rect.fromLTWH(x - 3, y - h - 6, 6, h + 6)), stone, Offset(x - 3, 0), Offset(x + 3, 0));
          fillPath(c, Path()..addRect(Rect.fromLTWH(x - 11, y - h + 4, 22, 6)), stone, Offset(x - 11, 0), Offset(x + 11, 0));
        } else {
          final tomb = Path()
            ..moveTo(x - 11, y)
            ..lineTo(x - 11, y - h + 10)
            ..quadraticBezierTo(x - 11, y - h, x, y - h)
            ..quadraticBezierTo(x + 11, y - h, x + 11, y - h + 10)
            ..lineTo(x + 11, y)
            ..close();
          fillPath(c, tomb, stone, Offset(x - 11, 0), Offset(x + 11, 0));
          c.drawLine(Offset(x - 5, y - h + 12), Offset(x + 5, y - h + 12), strokePaint(const Color(0x66000000), 1.4));
        }
      }
      // Iron fence along the back.
      final fence = strokePaint(const Color(0xFF14161C), 2);
      c.drawLine(const Offset(0, 382), const Offset(960, 380), fence);
      for (var x = 4.0; x < 960; x += 14) {
        c.drawLine(Offset(x, 392), Offset(x, 370), fence);
        c.drawPath(poly([Offset(x - 2.5, 371), Offset(x, 365), Offset(x + 2.5, 371)]), Paint()..color = const Color(0xFF14161C));
      }
    case Setting.road:
      // A signpost and a lantern post.
      final wood = ramp(0xFF5A4030, .25, .5);
      fillPath(c, Path()..addRect(const Rect.fromLTWH(118, 360, 6, 56)), wood, const Offset(118, 0), const Offset(124, 0));
      fillPath(c, poly(const [Offset(96, 368), Offset(146, 366), Offset(154, 374), Offset(146, 382), Offset(96, 380)]), wood, const Offset(96, 0), const Offset(154, 0));
      fillPath(c, Path()..addRect(const Rect.fromLTWH(880, 344, 5, 72)), wood, const Offset(880, 0), const Offset(885, 0));
      c.drawCircle(const Offset(892, 352), 24, _radial(const Offset(892, 352), 24, const Color(0xFFFFC060), const [.8, .3, 0], const [0, .4, 1]));
      c.drawRect(const Rect.fromLTWH(887, 346, 10, 12), Paint()..color = const Color(0xFFFFD27A));
    case Setting.forest || Setting.moonwood:
      // Ferns and a mossy log.
      final fern = strokePaint(const Color(0xFF2E4A26), 2.4);
      for (final x in spots) {
        for (var k = -2; k <= 2; k++) {
          c.drawPath(
            Path()
              ..moveTo(x, 412)
              ..quadraticBezierTo(x + k * 6, 396, x + k * 12, 400 + k.abs() * 3.0),
            fern,
          );
        }
      }
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(420, 396, 110, 18), const Radius.circular(9))), ramp(0xFF5A4630, .25, .5), const Offset(0, 396), const Offset(0, 414));
      c.drawOval(const Rect.fromLTWH(426, 394, 50, 8), Paint()..color = const Color(0xFF4E6E34));
    case Setting.warcamp || Setting.orkcamp:
      // Hide tents, a skull totem and a fire pit.
      final hide = s == Setting.orkcamp ? ramp(0xFF6A5A3A, .25, .5) : ramp(0xFF7A6040, .25, .5);
      for (final (x, w) in const [(60.0, 80.0), (440.0, 70.0), (880.0, 76.0)]) {
        final tent = poly([Offset(x - w / 2, 410), Offset(x, 352), Offset(x + w / 2, 410)]);
        fillPath(c, tent, hide, Offset(x - w / 2, 0), Offset(x + w / 2, 0));
        c.drawPath(poly([Offset(x - 8, 410), Offset(x, 384), Offset(x + 8, 410)]), Paint()..color = const Color(0xFF1A140C));
        c.drawLine(Offset(x, 352), Offset(x - 6, 340), strokePaint(const Color(0xFF3A2A1A), 2));
        c.drawLine(Offset(x, 352), Offset(x + 6, 340), strokePaint(const Color(0xFF3A2A1A), 2));
      }
      _totem(c, 560, 412);
      c.drawCircle(const Offset(520, 410), 40, _radial(const Offset(520, 410), 40, const Color(0xFFFF8A2A), const [.8, .3, 0], const [0, .4, 1]));
      c.drawPath(poly(const [Offset(508, 412), Offset(516, 390), Offset(522, 402), Offset(528, 386), Offset(534, 412)]), Paint()..color = const Color(0xFFFFB04A));
    case Setting.totems:
      // A ring of standing stones and totems with a green spirit glow.
      for (final x in const [60.0, 150.0, 420.0, 600.0, 880.0]) {
        final h = 50 + (x % 7) * 4;
        fillPath(c, poly([Offset(x - 12, 410), Offset(x - 9, 410 - h), Offset(x + 9, 412 - h - 4), Offset(x + 12, 410)]), const [Color(0xFF6A7066), Color(0xFF444A42), Color(0xFF1E221C)], Offset(x - 12, 0), Offset(x + 12, 0));
        c.drawPath(
          Path()
            ..moveTo(x - 4, 380 - h * .4)
            ..lineTo(x + 4, 370 - h * .4)
            ..lineTo(x, 362 - h * .4),
          strokePaint(const Color(0xFF8BE05A), 2),
        );
      }
      _totem(c, 510, 412);
      c.drawCircle(const Offset(510, 360), 70, _radial(const Offset(510, 360), 70, const Color(0xFF8BE05A), const [.5, .15, 0], const [0, .4, 1]));
    case Setting.roost:
      // Glowcaps at the cavern's edges.
      for (final x in const [70.0, 900.0]) {
        c.drawCircle(Offset(x, 400), 40, _radial(Offset(x, 400), 40, const Color(0xFF8AF0E0), const [.4, .12, 0], const [0, .45, 1]));
        for (var i = 0; i < 3; i++) {
          final dx = (i - 1) * 12.0, h = 10.0 + i * 6;
          c.drawLine(Offset(x + dx, 412), Offset(x + dx, 412 - h), strokePaint(const Color(0xFFB8D8D0), 2.2));
          c.drawOval(Rect.fromCenter(center: Offset(x + dx, 412 - h), width: 14, height: 8), Paint()..color = const Color(0xFFC8FFF4));
        }
      }
    case Setting.deepforge:
      // An anvil, and a brazier of forge-coals glowing beside it.
      final iron = ramp(0xFF5A5E66, .3, .5);
      fillPath(c, poly(const [Offset(110, 412), Offset(120, 392), Offset(98, 386), Offset(98, 378), Offset(170, 378), Offset(186, 386), Offset(150, 392), Offset(160, 412)]), iron, const Offset(98, 378), const Offset(186, 412));
      fillPath(c, poly(const [Offset(840, 412), Offset(848, 380), Offset(904, 380), Offset(912, 412)]), ramp(0xFF4A3A30, .25, .5), const Offset(840, 380), const Offset(912, 412));
      c.drawCircle(const Offset(876, 372), 46, _radial(const Offset(876, 372), 46, const Color(0xFFFF8A3A), const [.75, .25, 0], const [0, .45, 1]));
      for (var i = 0; i < 7; i++) {
        c.drawCircle(Offset(854.0 + i * 7, 378 - (i % 3) * 3.0), 4.5, Paint()..color = Color.lerp(const Color(0xFFFFD27A), const Color(0xFFE0502A), (i % 3) / 2)!);
      }
    case Setting.blossom:
      // A red torii gate behind the duel, a stone lantern, and petals drifted on the path.
      final lacquer = ramp(0xFFC8322A, .25, .5);
      for (final x in const [60.0, 160.0]) {
        fillPath(c, Path()..addRect(Rect.fromLTWH(x - 6, 300, 12, 110)), lacquer, Offset(x - 6, 0), Offset(x + 6, 0));
      }
      fillPath(c, poly(const [Offset(26, 300), Offset(194, 300), Offset(206, 288), Offset(14, 288)]), ramp(0xFF2A2024, .3, .5), const Offset(0, 288), const Offset(0, 300));
      fillPath(c, Path()..addRect(const Rect.fromLTWH(40, 318, 140, 8)), lacquer, const Offset(0, 318), const Offset(0, 326));
      final stone = ramp(0xFF8A8A84, .3, .5);
      fillPath(c, Path()..addRect(const Rect.fromLTWH(886, 380, 10, 30)), stone, const Offset(886, 0), const Offset(896, 0));
      fillPath(c, Path()..addRect(const Rect.fromLTWH(876, 362, 30, 18)), stone, const Offset(876, 0), const Offset(906, 0));
      c.drawRect(const Rect.fromLTWH(884, 366, 14, 10), Paint()..color = const Color(0xFFFFD890));
      fillPath(c, poly(const [Offset(868, 362), Offset(891, 346), Offset(914, 362)]), stone, const Offset(868, 346), const Offset(914, 362));
      for (var i = 0; i < 40; i++) {
        final x = r.next() * 960, y = 400 + r.next() * 14;
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 5, height: 3), Paint()..color = const Color(0xCCFFC0D0));
      }
    case Setting.aerie:
      // Wind-worn boulders, and feathers caught between the rocks.
      final rock = ramp(0xFF8A8A92, .3, .5);
      for (final (x, w) in const [(60.0, 50.0), (900.0, 60.0)]) {
        fillPath(c, Path()..addOval(Rect.fromCenter(center: Offset(x, 404), width: w, height: w * .55)), rock, Offset(x - w / 2, 0), Offset(x + w / 2, 0));
      }
      for (final (x, a) in const [(140.0, -.4), (420.0, .3), (560.0, -.2), (820.0, .5)]) {
        c.save();
        c.translate(x, 410);
        c.rotate(a);
        c.drawOval(const Rect.fromLTWH(-12, -2.5, 24, 5), Paint()..color = const Color(0xFFE8D8B0));
        c.drawLine(const Offset(-14, 0), const Offset(12, 0), strokePaint(const Color(0xFF8A7A5A), 1));
        c.restore();
      }
    case Setting.lair || Setting.summit:
      // The hoard: coins, a goblet, bones.
      final gold = Paint()..color = const Color(0xFFE8C060);
      for (var i = 0; i < 70; i++) {
        final x = 540 + r.next() * 380, y = 408 - r.next() * 18 * (1 - ((x - 730).abs() / 190).clamp(0.0, 1.0));
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 7, height: 3.4), gold);
      }
      fillPath(c, poly(const [Offset(640, 392), Offset(652, 392), Offset(648, 406), Offset(658, 410), Offset(634, 410), Offset(644, 406)]), const [Color(0xFFF6E2A0), Color(0xFFC49A3C), Color(0xFF5E4416)], const Offset(634, 0), const Offset(658, 0));
      _bones(c, const [Offset(80, 406), Offset(440, 410), Offset(900, 404)]);
    case Setting.swamp:
      // Reeds, still water and a ruined pillar wrapped in vines.
      c.drawOval(const Rect.fromLTWH(380, 400, 220, 16), Paint()..color = const Color(0xAA2A4A40));
      final reed = strokePaint(const Color(0xFF3A5A2A), 2);
      for (final x in spots) {
        for (var k = 0; k < 5; k++) {
          c.drawLine(Offset(x + k * 4, 414), Offset(x + k * 4 + (k - 2) * 2, 382 - k * 3.0), reed);
        }
      }
      fillPath(c, Path()..addRect(const Rect.fromLTWH(880, 340, 22, 72)), const [Color(0xFF7A7E6A), Color(0xFF50544A), Color(0xFF26281E)], const Offset(880, 0), const Offset(902, 0));
      c.drawPath(
        Path()
          ..moveTo(880, 350)
          ..quadraticBezierTo(910, 370, 880, 390)
          ..quadraticBezierTo(905, 400, 890, 412),
        strokePaint(const Color(0xFF3E6A2E), 3),
      );
    case Setting.frostruin:
      // A toppled statue's frozen head, a broken pillar furred with rime, a sword stuck in the snow.
      final stone = ramp(0xFF9AA8B8, .3, .5);
      fillPath(c, Path()..addRect(const Rect.fromLTWH(70, 330, 26, 82)), stone, const Offset(70, 0), const Offset(96, 0));
      fillPath(c, poly(const [Offset(64, 330), Offset(102, 330), Offset(96, 318), Offset(80, 326), Offset(70, 316)]), stone, const Offset(64, 0), const Offset(102, 0));
      c.drawRect(const Rect.fromLTWH(64, 326, 38, 6), Paint()..color = const Color(0xFFF2FAFF));
      fillPath(c, Path()..addOval(const Rect.fromLTWH(860, 372, 60, 44)), stone, const Offset(860, 0), const Offset(920, 0));
      c.drawPath(poly(const [Offset(866, 384), Offset(890, 366), Offset(916, 384)]), Paint()..color = const Color(0xFFF2FAFF));
      c.drawLine(const Offset(540, 410), const Offset(548, 368), strokePaint(const Color(0xFF8A9AAA), 3));
      c.drawLine(const Offset(536, 376), const Offset(556, 380), strokePaint(const Color(0xFF6A5A4A), 3));
      for (final x in spots) {
        c.drawOval(Rect.fromCenter(center: Offset(x, 412), width: 40, height: 8), Paint()..color = const Color(0xCCF2FAFF));
      }
    case Setting.icecave:
      // Icicles over the fight, and pale crystals glowing at the cave's edges.
      for (var i = 0; i < 18; i++) {
        final x = 20 + i * 53.0 + r.next() * 20, h = 20 + r.next() * 50;
        c.drawPath(poly([Offset(x - 7, 0), Offset(x, h), Offset(x + 7, 0)]), Paint()..shader = ui.Gradient.linear(Offset(x - 7, 0), Offset(x + 7, 0), const [Color(0xFFDFF4FF), Color(0xFF8AC0E0), Color(0xFF3A6A90)], const [0, .5, 1]));
      }
      for (final x in const [70.0, 900.0]) {
        c.drawCircle(Offset(x, 396), 46, _radial(Offset(x, 396), 46, const Color(0xFF9ADFFF), const [.45, .12, 0], const [0, .45, 1]));
        for (final (dx, h) in const [(-12.0, 30.0), (0.0, 46.0), (12.0, 24.0)]) {
          c.drawPath(poly([Offset(x + dx - 6, 412), Offset(x + dx, 412 - h), Offset(x + dx + 6, 412)]), Paint()..shader = ui.Gradient.linear(Offset(x + dx - 6, 0), Offset(x + dx + 6, 0), const [Color(0xFFF2FAFF), Color(0xFF9AD0F0), Color(0xFF4A80A8)], const [0, .5, 1]));
        }
      }
    case Setting.ice:
      // Ice shards poking through the snow.
      for (final x in spots) {
        c.drawPath(poly([Offset(x - 8, 412), Offset(x - 2, 384), Offset(x + 3, 396), Offset(x + 8, 380), Offset(x + 12, 412)]), Paint()..shader = ui.Gradient.linear(Offset(x - 8, 0), Offset(x + 12, 0), const [Color(0xFFF2FAFF), Color(0xFF9AC4E0), Color(0xFF5A84A8)], const [0, .5, 1]));
      }
    case Setting.volcano:
      // Lava cracks glowing in the black rock.
      final lava = strokePaint(const Color(0xFFFF6A1A), 2.6);
      for (final x in spots) {
        c.drawPath(
          Path()
            ..moveTo(x - 20, 404)
            ..lineTo(x - 6, 410)
            ..lineTo(x + 4, 402)
            ..lineTo(x + 22, 408),
          lava,
        );
        c.drawCircle(Offset(x, 406), 18, _radial(Offset(x, 406), 18, const Color(0xFFFF5A1A), const [.4, .1, 0], const [0, .4, 1]));
      }
    case Setting.boneyard:
      _bones(c, const [Offset(60, 406), Offset(150, 410), Offset(420, 404), Offset(560, 410), Offset(880, 406)]);
    case Setting.village:
      // Overturned cart and scattered barrels.
      final wood = ramp(0xFF5A4030, .25, .5);
      fillPath(c, poly(const [Offset(40, 404), Offset(140, 396), Offset(146, 410), Offset(46, 414)]), wood, const Offset(0, 396), const Offset(0, 414));
      c.drawCircle(const Offset(70, 414), 12, strokePaint(const Color(0xFF2A1A10), 4));
      for (final x in const [440.0, 470.0, 900.0]) {
        fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 388, 22, 24), const Radius.circular(5))), wood, Offset(x, 0), Offset(x + 22, 0));
        c.drawLine(Offset(x, 396), Offset(x + 22, 396), strokePaint(const Color(0xFF2A1A10), 1.6));
      }
    case Setting.castle:
      // Banners on poles by the road.
      for (final x in const [100.0, 900.0]) {
        c.drawLine(Offset(x, 414), Offset(x, 330), strokePaint(const Color(0xFF2A2020), 4));
        c.drawPath(poly([Offset(x + 2, 334), Offset(x + 34, 334), Offset(x + 34, 384), Offset(x + 18, 374), Offset(x + 2, 384)]), Paint()..color = const Color(0xFF7A1418));
        c.drawCircle(Offset(x + 18, 352), 5, Paint()..color = const Color(0xFF1A0A0A));
      }
    case Setting.ruins || Setting.shiftisle:
      // Fallen masonry.
      for (final x in spots) {
        fillPath(c, Path()..addRect(Rect.fromLTWH(x - 10, 398, 20, 14)), const [Color(0xFF6A6260), Color(0xFF443E3C), Color(0xFF1E1A18)], Offset(x - 10, 0), Offset(x + 10, 0));
      }
    case Setting.elderwood || Setting.blightwood || Setting.jungle:
      // Glowing mushrooms and mossy stones.
      final cap = s == Setting.blightwood ? const Color(0xFFB07AFF) : const Color(0xFF9AE07A);
      for (final x in spots) {
        for (var k = 0; k < 3; k++) {
          final mx = x + k * 9 - 9, h = 6.0 + (k * 5) % 9;
          c.drawLine(Offset(mx, 412), Offset(mx, 412 - h), strokePaint(const Color(0xFFD8D0B8), 2));
          c.drawCircle(Offset(mx, 412 - h), 10, _radial(Offset(mx, 412 - h), 10, cap, const [.6, .2, 0], const [0, .4, 1]));
          c.drawOval(Rect.fromCenter(center: Offset(mx, 412 - h), width: 10, height: 6), Paint()..color = cap);
        }
      }
    case Setting.heartgrove:
      // Fallen leaves and roots across the road.
      final root = strokePaint(const Color(0xFF3A2814), 6)..strokeCap = StrokeCap.round;
      for (final x in const [80.0, 420.0, 880.0]) {
        c.drawPath(Path()..moveTo(x - 40, 400)..quadraticBezierTo(x, 386, x + 50, 404), root);
      }
      for (var i = 0; i < 60; i++) {
        final p = Offset(r.next() * 960, 396 + r.next() * 100);
        c.drawOval(Rect.fromCenter(center: p, width: 7, height: 3.5), Paint()..color = Color.lerp(const Color(0xFFD8782A), const Color(0xFF8A3A14), r.next())!.withValues(alpha: .8));
      }
    case Setting.coast || Setting.fogshore:
      // Wet rocks, a wrecked boat's ribs and a fishing net on a post.
      final rock = const [Color(0xFF6A7276), Color(0xFF3E4448), Color(0xFF1E2224)];
      for (final (x, w) in const [(60.0, 46.0), (150.0, 26.0), (880.0, 54.0)]) {
        fillPath(c, Path()..addOval(Rect.fromCenter(center: Offset(x, 410), width: w, height: w * .6)), rock, Offset(x - w / 2, 0), Offset(x + w / 2, 0));
      }
      final rib = strokePaint(const Color(0xFF4A3420), 5)..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final x = 400.0 + i * 22;
        c.drawPath(
          Path()
            ..moveTo(x, 412)
            ..quadraticBezierTo(x - 16, 380, x + 4, 360 + (i - 2).abs() * 6.0),
          rib,
        );
      }
      c.drawLine(const Offset(390, 412), const Offset(500, 404), strokePaint(const Color(0xFF3A2814), 6));
      c.drawLine(const Offset(930, 412), const Offset(930, 350), strokePaint(const Color(0xFF4A3420), 5));
      final net = strokePaint(const Color(0x99D8CCAA), 1);
      for (var k = 0; k < 6; k++) {
        c.drawLine(Offset(930, 354.0 + k * 9), Offset(960, 360.0 + k * 9), net);
        c.drawLine(Offset(932.0 + k * 5, 352), Offset(936.0 + k * 5, 408), net);
      }
    case Setting.crypt || Setting.desert || Setting.tomb:
      break;
  }
}

void _totem(Canvas c, double x, double y) {
  fillPath(c, Path()..addRect(Rect.fromLTWH(x - 4, y - 60, 8, 60)), ramp(0xFF5A4030, .25, .5), Offset(x - 4, 0), Offset(x + 4, 0));
  const bone = [Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];
  fillPath(c, Path()..addOval(Rect.fromCenter(center: Offset(x, y - 64), width: 18, height: 16)), bone, Offset(x - 9, 0), Offset(x + 9, 0));
  c.drawCircle(Offset(x - 3, y - 64), 2.2, Paint()..color = const Color(0xFF1A120C));
  c.drawCircle(Offset(x + 4, y - 64), 2.2, Paint()..color = const Color(0xFF1A120C));
  for (final dx in const [-1.0, 1.0]) {
    c.drawPath(poly([Offset(x + dx * 7, y - 70), Offset(x + dx * 16, y - 84), Offset(x + dx * 10, y - 68)]), Paint()..color = const Color(0xFFD8CCAA));
  }
}

void _bones(Canvas c, List<Offset> at) {
  final bone = strokePaint(const Color(0xFFD8CCAA), 4)..strokeCap = StrokeCap.round;
  for (final p in at) {
    c.drawLine(p + const Offset(-12, 2), p + const Offset(12, -2), bone);
    c.drawCircle(p + const Offset(-13, 2), 3.4, Paint()..color = const Color(0xFFD8CCAA));
    c.drawCircle(p + const Offset(13, -2), 3.4, Paint()..color = const Color(0xFFD8CCAA));
    c.drawOval(Rect.fromCenter(center: p + const Offset(20, -4), width: 12, height: 10), Paint()..color = const Color(0xFFE6DCC0));
    c.drawCircle(p + const Offset(22, -5), 1.8, Paint()..color = const Color(0xFF1A120C));
  }
}

/// Inside a crypt: vaulted arches, pillars, wall torches and flagstones.
void _crypt(Canvas c, BattlegroundSpec sp) {
  c.drawRect(Offset.zero & sceneSize, _vertical(const [Color(0xFF0C0A08), Color(0xFF1E1A16), Color(0xFF2A241E)], 0, 400));
  // Back wall blocks.
  final mortar = strokePaint(const Color(0x55000000), 1.4);
  for (var y = 40.0; y < 380; y += 26) {
    final off = ((y / 26).round().isOdd) ? 30.0 : 0.0;
    c.drawLine(Offset(0, y), Offset(960, y), mortar);
    for (var x = off; x < 960; x += 60) {
      c.drawLine(Offset(x, y), Offset(x, y + 26), mortar);
    }
  }
  // Arches with dark alcoves.
  for (final x in const [60.0, 300.0, 540.0, 780.0]) {
    final alcove = Path()
      ..moveTo(x, 380)
      ..lineTo(x, 200)
      ..quadraticBezierTo(x + 60, 120, x + 120, 200)
      ..lineTo(x + 120, 380)
      ..close();
    c.drawPath(alcove, Paint()..color = const Color(0xFF080606));
    c.drawPath(alcove, strokePaint(const Color(0xFF3A322A), 8));
    // A coffin or a skull shelf in each.
    c.drawOval(Rect.fromCenter(center: Offset(x + 60, 300), width: 16, height: 14), Paint()..color = const Color(0xFF8A806A));
    c.drawRect(Rect.fromLTWH(x + 20, 340, 80, 6), Paint()..color = const Color(0xFF3A322A));
  }
  // Pillars and torches between arches.
  for (final x in const [200.0, 440.0, 680.0, 920.0]) {
    fillPath(c, Path()..addRect(Rect.fromLTWH(x - 14, 60, 28, 330)), const [Color(0xFF4A4238), Color(0xFF2E2822), Color(0xFF14110E)], Offset(x - 14, 0), Offset(x + 14, 0));
    c.drawCircle(Offset(x, 190), 90, _radial(Offset(x, 190), 90, sp.glow, const [.55, .18, 0], const [0, .35, 1]));
    c.drawRect(Rect.fromLTWH(x - 3, 196, 6, 18), Paint()..color = const Color(0xFF3A2A1A));
    c.drawPath(poly([Offset(x - 6, 198), Offset(x, 176), Offset(x + 6, 198)]), Paint()..color = const Color(0xFFFFC060));
  }
  // Floor flagstones.
  c.drawRect(const Rect.fromLTWH(0, 380, 960, 160), _vertical(sp.ground, 380, 540));
  for (var y = 400.0; y < 540; y += 30) {
    c.drawLine(Offset(0, y), Offset(960, y), mortar);
    for (var x = (y / 30).round().isOdd ? 40.0 : 0.0; x < 960; x += 80) {
      c.drawLine(Offset(x, y), Offset(x - 10, y + 30), mortar);
    }
  }
  _bones(c, const [Offset(100, 470), Offset(470, 500), Offset(880, 480)]);
  c.drawRect(
    const Rect.fromLTWH(-100, 470, 1160, 80),
    Paint()
      ..color = const Color(0x30000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
}
