// Contracts: the village's troubles, pinned to the notice board at the Soot & Kettle. Every guarded
// place on the map is somebody's problem: a farmer's flock, the chapel's bell, Mags' supply carts.
// Take the job and the place's guardian is the mark; put it down and whoever posted it pays a
// bounty on top of what you find. (After the Witcher's contracts: a reason, a client and a price,
// not just a red dot.) Pure Dart.

import 'catalog.dart';

class Contract {
  const Contract(this.place, this.client, this.ask);

  /// The guarded place (by id) whose guardian is the mark.
  final String place;

  /// Who posted it, and what they wrote.
  final String client, ask;
}

/// The village's notice board, one contract a guarded place.
const contracts = <Contract>[
  Contract('scarecrow', 'Farmer Tolly', 'Something in my top field\'s got up off its pole and it\'s walking about. It took a goose. It took the dog. Please.'),
  Contract('orkscouts', 'Mags', 'Orks keep jumping my supply carts on the south road. Find their camp. I\'ll make it worth your while.'),
  Contract('drownedbell', 'Sister Agna', 'The old bell in the fen rings every night at midnight, and the bell-ringer drowned forty years ago. Make it stop.'),
  Contract('barrow', 'The Reeve', 'Sir Rattlesby\'s barrow has opened, and he\'s challenging passers-by to duels. He\'s winning. Kindly lose him.'),
  Contract('skulltotem', 'Hob', 'An ork shaman\'s raised a totem up in the Badlands and the drovers won\'t go past it. Knock it down, and him with it.'),
  Contract('warcamp', 'Dunstan', 'Gorehowl\'s lot have been taking every scrap of iron off the road to make axes. I want it back. And him gone.'),
  Contract('queensleep', 'Old Wick', 'A queen in the Sands has stopped sleeping. I\'d rather she started again. Permanently, if you can.'),
  Contract('glasswyrm', 'Dunstan', 'There\'s a wyrm out in the glass with a hide like a gilded window. I want a scale off it. You can keep the rest.'),
  Contract('glassfurnace', 'Old Wick', 'Something\'s living in the old furnace and burning the Cinderreach hotter every day. Put it out.'),
  Contract('caldera', 'The Reeve', 'Cinderjaw\'s been dropping out of the sky on the caravans. The Reeve will pay for every caravan that gets through after.'),
  Contract('ashengate', 'Hob', 'The Ashen Order\'s last gatekeeper still holds the road to the Throne. Nobody gets past him. Be the first.'),
  Contract('eyrie', 'Old Wick', 'Aurumvex the Elder is older than the Burning. I\'d like to know what it knows. Failing that, I\'d like it dead.'),
  Contract('gallows', 'Sister Agna', 'The ghouls at the crossroads are digging up the hanged and crowning one of them king. This cannot continue.'),
  Contract('battower', 'Farmer Tolly', 'Every sheep I own has two little holes in its neck. The Bat King lives in the tower on the hill. Please.'),
  Contract('woodcutter', 'Wren', 'The woodcutter in the Weald still goes out every night. He\'s been dead a year. Wren\'s cousin saw him.'),
  Contract('lostmine', 'Dunstan', 'Rustbeard went mad down the old mine and won\'t let anyone near the gold seam. He was my teacher. Be quick about it.'),
  Contract('foundry', 'Dunstan', 'The dwarves built a golem out of gold and forgot to switch it off. It\'s guarding the foundry from everyone, dwarves included.'),
  Contract('choirstones', 'Sister Agna', 'The stones on the Isle are singing, and anyone who listens too long walks into the sea. Silence the cantor.'),
  Contract('wallow', 'Mags', 'Old Mudjaw\'s eaten two of my spice carts and a donkey. I want my spices back. The donkey\'s a lost cause.'),
  Contract('krakenreef', 'The Reeve', 'No ship gets past the reef. The Reeve would like a ship to get past the reef. There\'s something big in the way.'),
  Contract('ziggurat', 'Old Wick', 'The lizardfolk are hatching something in the ziggurat. Literally. Go and see what, and stop it.'),
  Contract('skinthief', 'Hob', 'Somebody came into the inn last week wearing my face. Then they left with my takings. I want my face back.'),
  Contract('rocnest', 'Farmer Tolly', 'A griffin took my best cow. Flew off with it. Into the clouds. I\'d like to see it try that again with you there.'),
  Contract('onigate', 'The Reeve', 'A red oni sits on the gate to the Blossom Isles and eats anyone who knocks. Knock.'),
  Contract('rimehollow', 'Dunstan', 'There\'s a frost wyrm in a hollow up north, sleeping on the best ice-iron I ever saw. Wake it. Then put it back to sleep.'),
  Contract('orchardroost', 'Wren', 'The fig orchard in the Hollowdeep has a king now. A bat king. He\'s eating all the figs, and the people who come for them.'),
];

Contract? contractFor(String place) => contracts.where((c) => c.place == place).firstOrNull;

/// The bounty a contract pays on top of the place itself: gold, by your level.
int contractBounty(int level) => 5 * (6 + 3 * level);

/// How many contracts the board shows at once (the nearest to your level first).
const boardSize = 3;

/// Whether [p] is a guarded place with a contract on the board.
bool hasContract(Place p) => p.foe != null && contractFor(p.id) != null;
