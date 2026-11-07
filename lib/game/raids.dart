// Who hits the town while you're out. Bandits from the start; then, as the lands open up and word
// of Cindervale's hero gets around, whatever's out there comes calling too: goblins up from the
// barns, ghosts drifting in off the fen, the Faceless walking in wearing the neighbours' faces.
// Each comes from a land whose lord you've beaten (the lord kept them in line; now nobody does).

import 'banter.dart';
import 'catalog.dart';

class Raiders {
  const Raiders(
    this.id,
    this.look, {
    required this.gang,
    required this.who,
    required this.innBanner,
    required this.stallBanner,
    required this.inn,
    required this.stall,
    required this.caughtInn,
    required this.caughtStall,
    required this.banter,
    this.from,
    this.gone = 'got clean away',
  });

  /// Saved with the raid; [look] is the foe they're drawn as (from [from]'s own foes, if it has them).
  final String id, look;

  /// The pack's name in the fight ("Bandit Gang"), and who they are in a sentence ("the bandits").
  final String gang, who;

  /// The town card's one line, for a raid on the Soot & Kettle or on Mags' stall.
  final String innBanner, stallBanner;

  /// What Hob (the inn) or Mags (the stall) tells you: two pages. {name} is your name.
  final List<String> inn, stall;

  /// The journal line as you catch up with them.
  final String caughtInn, caughtStall;
  final Banter banter;

  /// The land whose lord has to be down first (by name; null: from the start).
  final String? from;

  /// How it ends if you leave them be.
  final String gone;

  /// Open yet: from the start, or once [from]'s lord is down.
  bool openTo(Set<int> bossesDown) {
    if (from == null) return true;
    final land = continents.indexWhere((l) => l.name == from);
    return land >= 0 && bossesDown.contains(land);
  }

  /// The foe to fight: [look] as it is in [from], if it lives there.
  int get foeIndex {
    final land = from == null ? null : continents.indexWhere((l) => l.name == from);
    return lookIndex(look, land == null || land < 0 ? 0 : land);
  }
}

const raiders = <Raiders>[
  Raiders(
    'bandits',
    'rogue',
    gang: 'Bandit Gang',
    who: 'the bandits',
    innBanner: 'Bandits robbed the Soot & Kettle!',
    stallBanner: 'Bandits raided Mags\' stall!',
    inn: ['{name}! Bandits! They came through the back while I was changing a barrel.', 'Took the strongbox, the candlesticks, and my good kettle. They can\'t have got far with all that.'],
    stall: ['{name}, thank the stars. Bandits turned my stall over not ten minutes ago!', 'Half my potions and every pouch of coin. They went off down the road, laughing. Bring it back and I\'ll make it worth your while.'],
    caughtInn: 'You catch the bandits in the lane behind the Soot & Kettle, arms full of Hob\'s silver!',
    caughtStall: 'You catch the bandits at the edge of the square, Mags\' stock bulging in their sacks!',
    banter: Banter(enter: ['Uh oh. It\'s the hero.', 'Run! No wait, fight! No, run!', 'We were just... borrowing it.'], fall: ['Fine! Keep your stupid potions!']),
  ),
  Raiders(
    'goblins',
    'goblin',
    from: 'Cindervale',
    gang: 'Goblin Mob',
    who: 'the goblins',
    innBanner: 'Goblins ransacked the Soot & Kettle!',
    stallBanner: 'Goblins swarmed Mags\' stall!',
    inn: ['{name}! Goblins, up out of the barns! A dozen of them, maybe more. Hard to count, they never stand still.', 'They drank the cellar dry, ate the candles and ran off with the till. Singing. Badly.'],
    stall: ['{name}! Goblins! Little soot-faced ones, all elbows and teeth!', 'They went straight for the sweets, then the potions, then the coin. Off towards the old barns, giggling. Go and get it back!'],
    caughtInn: 'You catch the goblins in the barn behind the square, sitting on Hob\'s barrels and arguing about the till!',
    caughtStall: 'You catch the goblins in the old barns, faces sticky, Mags\' potions clinking in their pockets!',
    banter: Banter(enter: ['MINE! All mine! Mostly mine!', 'Shiny man! Shiny man is here!', 'We share! You get nothing!'], fall: ['Waaah! Take it! Take it back!']),
    gone: 'scurried back into the barns with all of it',
  ),
  Raiders(
    'ghosts',
    'ghost',
    from: 'The Gloomfen',
    gang: 'Fen Haunting',
    who: 'the ghosts',
    innBanner: 'Ghosts are terrorising the Soot & Kettle!',
    stallBanner: 'Ghosts are haunting Mags\' stall!',
    inn: ['{name}... the fog came in off the fen tonight, and something came in with it.', 'The candles go out on their own, the tankards fly about, and every drop of ale\'s gone sour. Nobody\'ll stay past dark. Send them back where they came from.'],
    stall: ['{name}, I\'m not a nervous woman. But my stall\'s haunted.', 'Cold hands in the coin box, faces in the potion bottles. Half my stock walked off into the fog by itself. Please. Before they come back.'],
    caughtInn: 'You follow the cold out past the Soot & Kettle to the fen\'s edge, where the dead have gathered round Hob\'s silver!',
    caughtStall: 'You find them at the edge of the fog, pale shapes passing Mags\' bottles from hand to hand!',
    banter: Banter(enter: ['Warm... you\'re so warm...', 'This was our town too. Before the fire.', 'Stay. Stay with us. Forever.'], fall: ['Back... to the water...']),
    gone: 'sank back into the fen, and took it all with them',
  ),
  Raiders(
    'orks',
    'ork',
    from: 'The Grimtusk Badlands',
    gang: 'Ork Raiding Party',
    who: 'the orks',
    innBanner: 'Orks smashed up the Soot & Kettle!',
    stallBanner: 'Orks flattened Mags\' stall!',
    inn: ['{name}! Orks! Came down the road beating drums, kicked the door in and asked for a party!', 'When I said we were shut, they took the kegs, the till and half the tables. Said it was a toll. For the road. Which they don\'t own.'],
    stall: ['{name}! Orks, a whole raiding party! Painted red, all of them!', 'They flattened my stall to get at the potions and called it tribute. I\'ll give them tribute. Go on, give them some from me!'],
    caughtInn: 'You catch the orks on the road out of town, rolling Hob\'s kegs and chanting!',
    caughtStall: 'You catch the orks round a fire past the fields, swigging Mags\' potions like ale!',
    banter: Banter(enter: ['Oi! Dis is OUR party!', 'More fighting! Good!', 'You want the barrels back? Come and get \'em!'], fall: ['Bah! Rubbish party anyway!']),
  ),
  Raiders(
    'spawn',
    'vampireSpawn',
    from: 'Ravenmoor',
    gang: 'Vampire Brood',
    who: 'the vampire spawn',
    innBanner: 'Vampire spawn are preying on the Soot & Kettle!',
    stallBanner: 'Vampire spawn ransacked Mags\' stall!',
    inn: ['{name}. Last night something knocked, and somebody let it in. You\'re meant to ask first, aren\'t you? I didn\'t know.', 'Pale things, quick as cats. The regulars are all right, just faint. But they\'ve taken the silver, and the red wine, all of it. They\'ll be back tonight.'],
    stall: ['{name}, they came after dark. Pale, with eyes like the castle on the moor.', 'They smashed every bottle of healing draught first, so nobody could mend. Then they took the coin. Find them before they come back hungry.'],
    caughtInn: 'You track the brood to a barn roof past the square, Hob\'s silver hung round their necks!',
    caughtStall: 'You catch the brood in the churchyard, picking through Mags\' coin by moonlight!',
    banter: Banter(enter: ['Mmm. Fresh.', 'The Countess sends her regards.', 'You smell like iron. And courage.'], fall: ['The moor... will remember...']),
    gone: 'flew off towards the moor, and they won\'t be back with it',
  ),
  Raiders(
    'batkin',
    'batkin',
    from: 'The Hollowdeep',
    gang: 'Batkin Swarm',
    who: 'the batkin',
    innBanner: 'Batkin swarmed the Soot & Kettle!',
    stallBanner: 'Batkin stripped Mags\' stall!',
    inn: ['{name}! The sky went black with them. Bats, big as dogs, and the batkin riding the swarm!', 'In through the chimney, out through the windows, and everything shiny went with them. They hear a coin drop from a mile off.'],
    stall: ['{name}! Bats! Thousands of bats, and those things that hunt with them!', 'Every coin, every glass bottle, anything that glints. They went back towards the hills. Mind your ears.'],
    caughtInn: 'You catch the swarm settling in the bell tower, Hob\'s candlesticks hanging among them!',
    caughtStall: 'You catch the batkin roosting under the old bridge, Mags\' coins chiming in their claws!',
    banter: Banter(enter: ['We heard you coming. We always hear.', 'Shhh... listen... your heart is so loud.', 'Shiny things. Our shiny things.'], fall: ['Back... to the dark...']),
    gone: 'flew back to the Hollowdeep, and the shiny things went with them',
  ),
  Raiders(
    'faceless',
    'facelessWanderer',
    from: 'The Isle of Mists',
    gang: 'Faceless Procession',
    who: 'the Faceless',
    innBanner: 'The Faceless are terrorising the Soot & Kettle!',
    stallBanner: 'The Faceless emptied Mags\' stall!',
    inn: ['{name}... I served a man ale all evening. Old Tam, I thought. Then his face slid off.', 'There were six of them by closing, wearing my regulars\' faces. They emptied the till and walked out smiling. Nobody\'s sure who\'s really who any more.'],
    stall: ['{name}, it was me. I mean, it looked like me, behind my own stall, selling my own stock. To itself.', 'By the time I got back they\'d sold everything to each other and walked off with the coin. Find them. And check their faces.'],
    caughtInn: 'You find a procession of the Faceless on the road west, still wearing the regulars\' faces, Hob\'s silver in their hands!',
    caughtStall: 'You catch the Faceless at the crossroads, one of them still wearing Mags\' face, her coin box under its arm!',
    banter: Banter(enter: ['We liked your town. We liked the faces.', 'Yours would fit us. Yours would fit us well.', 'Who are you, really? We could find out.'], fall: ['Give... it... back... our face...']),
    gone: 'walked off into the fog wearing your neighbours\' faces',
  ),
  Raiders(
    'merrow',
    'merrowRaider',
    from: 'The Shattered Sea',
    gang: 'Merrow War-Party',
    who: 'the merrow',
    innBanner: 'Merrow raiders looted the Soot & Kettle!',
    stallBanner: 'Merrow raiders looted Mags\' stall!',
    inn: ['{name}! Fish-folk! Up the river in the night, all spears and seaweed!', 'They took every barrel of salt and every coin, and they left the floor wet. They\'ll make for the river mouth. Hurry.'],
    stall: ['{name}! Merrow, up the river! I didn\'t know they could walk that far!', 'Every potion and every pouch of coin, gone in a wave of them. They\'ll be heading back to the water.'],
    caughtInn: 'You catch the merrow at the riverbank, loading Hob\'s silver into a wreck of a boat!',
    caughtStall: 'You catch the merrow wading back down the river, Mags\' sacks dragging behind them!',
    banter: Banter(enter: ['Dry-walker! Give us the shiny!', 'The tide takes what it likes.', 'For the reef! For the wrecks!'], fall: ['The sea... keeps... what it...']),
    gone: 'went back down the river to the sea, and the sea keeps what it takes',
  ),
];

Raiders raidersById(String? id) => raiders.firstWhere((r) => r.id == id, orElse: () => raiders.first);
