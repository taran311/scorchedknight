// What foes say: a taunt as they step up, a wobble when they're nearly beaten, and a last word.
// Pure Dart. Lines are picked by the foe's look; anything without its own lines falls back on its
// kind (beasts growl, the undead moan, bosses get the good stuff).

import 'catalog.dart';

class Banter {
  const Banter({this.enter = const [], this.hurt = const [], this.fall = const []});
  final List<String> enter, hurt, fall;
}

const _byLook = <String, Banter>{
  // ---- Hallowash ----
  'pumpkinhead': Banter(
    enter: ['Trick or treat! I\'ll take the treat. And your head.', 'Hallo-WASH! Get it? No? Nobody ever gets it.', 'I\'m not a scarecrow. I\'m a SCARE-crow.'],
    hurt: ['My pumpkin! You\'re denting my pumpkin!'],
    fall: ['Happy... Hallowash...', 'Save me... a toffee...'],
  ),
  // ---- Golems (anywhere there's ore) ----
  'golemIron': Banter(enter: ['*The rock groans and stands up.*', '*Grinding. Rumbling. It has noticed you.*'], hurt: ['*Chips of stone fly.*'], fall: ['*It crumbles into a heap of rubble and ore.*']),
  'golemGold': Banter(enter: ['*Gold glints in its back as it rises out of the sand.*', '*It turns its glowing eyes on your purse.*'], hurt: ['*Cracks spread across it.*'], fall: ['*It slumps into sand and gold.*']),
  'golemObsidian': Banter(enter: ['*Black glass cracks and shifts. Something inside it is burning.*', '*It rises, hissing, out of the cooled lava.*'], hurt: ['*Shards of black glass ring as they fall.*'], fall: ['*It shatters like a dropped bottle.*']),
  // ---- Elementals (out of the land itself) ----
  'elementalEmber': Banter(enter: ['*a roar like a furnace door opening*', '*the grass around it curls and blackens*'], hurt: ['*sparks spray out of the wound*'], fall: ['*it gutters, and goes out, and leaves its core*']),
  'elementalFrost': Banter(enter: ['*the air cracks with cold*', '*frost races across the ground towards you*'], hurt: ['*ice splinters off it*'], fall: ['*it shatters into a heap of snow and a glowing core*']),
  'elementalMire': Banter(enter: ['*glorp*', '*it smells exactly as bad as it looks*'], hurt: ['*splat*'], fall: ['*it slumps back into the bog, leaving its core*']),
  // ---- The Hidden Ones (anywhere) ----
  'hiddenAcolyte': Banter(
    enter: ['The Reaper sees you. Soon he will do more than look.', 'Hush. Hush now. It only hurts for a moment.', 'You have been marked.'],
    hurt: ['Pain is a prayer...', 'He watches. He is pleased.'],
    fall: ['I go... to Him...', 'Hush...'],
  ),
  'hiddenBlade': Banter(
    enter: ['Two sickles. One for you. One for your shadow.', 'You never saw us. Nobody ever sees us.', 'The harvest begins.'],
    hurt: ['Quick. You are quick.'],
    fall: ['The harvest... goes on...'],
  ),
  'hiddenHexer': Banter(
    enter: ['My lantern burns with His light. Look into it.', 'Every flame goes out. Let me show you.', 'The dead whisper your name. They pronounce it wrong.'],
    hurt: ['The light... flickers...'],
    fall: ['Darkness... at last...'],
  ),
  'hiddenPrior': Banter(
    enter: ['The Reaper sends his regards.', 'You have slipped his scythe once. He does not like to ask twice.', 'Kneel, and I will make it quick. Stand, and I will make it holy.'],
    hurt: ['You fight like one who has already died. Interesting.', 'He will not be denied!'],
    fall: ['I see Him... He is smiling...', 'Hush... at last...'],
  ),
  // ---- Cindervale ----
  'goblin': Banter(
    enter: ['Oi! That timber\'s ours now. Finders keepers!', 'Shiny boots. Give \'em here.', 'Boss says nobody gets past. Boss is very small but very loud.'],
    hurt: ['Ow! Ow! Okay, you can have ONE plank.', 'This wasn\'t in the plan. There was no plan.'],
    fall: ['Tell Hob... the nails were... rubbish anyway...', 'I regret... everything...'],
  ),
  'rogue': Banter(
    enter: ['Your gold or your life. Actually, both.', 'Nice sword. It\'ll look better on me.', 'Nobody saw me. Nobody ever sees me. Except you, apparently.'],
    hurt: ['Right, new plan: run.', 'You were supposed to hand it over politely!'],
    fall: ['Should\'ve... gone into farming...', 'Worth... a try...'],
  ),
  'pillager': Banter(
    enter: ['Everything\'s already on fire. Might as well loot it.', 'I\'ll take that. And that. And YOU.'],
    hurt: ['My bag! Mind the bag!'],
    fall: ['At least... the bag survived...'],
  ),
  'goblinChief': Banter(
    enter: ['I\'m the WARBOSS. That means I\'ve got the big helmet.', 'Who smashed my minions? Was it you? It was you.', 'Iron\'s mine. All of it. Even the bent bits.'],
    hurt: ['My helmet\'s dented! Do you know how much helmets cost?!'],
    fall: ['Not... the helmet...'],
  ),
  'cyclops': Banter(
    enter: ['GORBO SEE YOU. GORBO SEE EVERYTHING. WELL, HALF OF EVERYTHING.', 'You smell like soot. Gorbo likes soot.'],
    hurt: ['Gorbo... not winning?'],
    fall: ['Gorbo... take nap... now...'],
  ),
  // ---- The Gloomfen ----
  'zombie': Banter(enter: ['Braaains... or soup. Gorbo\'s soup was nice.', 'Mmmrrgh.'], fall: ['Mmmrrgh... (fair enough)']),
  'skeleton': Banter(
    enter: ['I\'ve got a bone to pick with you. Several, actually.', 'Rattle rattle. That\'s a threat.'],
    hurt: ['That was my favourite rib!'],
    fall: ['I\'ll... pull myself together... later...'],
  ),
  'ghost': Banter(enter: ['Boooo. Sorry. Force of habit.', 'Leave the fen, living one. It\'s very damp.'], fall: ['At last... I can... rest...']),
  'banshee': Banter(enter: ['AAAAAAAAAAAH!', 'Your doom approaches! Also, your boots are untied.'], fall: ['aaaah... (quietly)']),
  'ghoul': Banter(enter: ['You look delicious. No offence.', 'Fresh meat! Well. Smoked meat.']),
  'skeletonArcher': Banter(enter: ['Hold still. I can\'t see very well. No eyes.', 'I never miss. I\'m mostly holes, but I never miss.'], fall: ['Should have... aimed for... the knee...']),
  'witch': Banter(
    enter: ['A visitor! Do sit down. In the cauldron.', 'Hee hee! What lovely bones you have.'],
    hurt: ['My hat! You\'ve singed my hat!'],
    fall: ['I\'m melting... no wait, that\'s the fen...'],
  ),
  'bonecolossus': Banter(enter: ['I AM MADE OF EVERY FOOL WHO CAME BEFORE YOU.', 'ADD YOUR BONES TO MINE.'], fall: ['I... FALL... TO PIECES...']),
  // ---- The Thornwild ----
  'twigling': Banter(enter: ['Snap snap! I mean... rawr!', 'The forest is ANGRY. I\'m quite small though.']),
  'thornEnt': Banter(enter: ['Hrrrm. You burned my cousins.', 'Prickly? Me? How rude.']),
  'mossEnt': Banter(enter: ['Slowly... very slowly... I will crush you.', 'Hrrrrrrm. (that was hello)']),
  'blightEnt': Banter(enter: ['Rot and ruin, little spark.', 'The blight spreads. So will you, shortly.']),
  'ironEnt': Banter(enter: ['My bark is worse than my bite. My bite is iron.', 'Axes break on me. What have you got?']),
  'bear': Banter(enter: ['*GRRAAWR*', '*sniffs* ...*GRRRR*'], fall: ['*sad bear noises*']),
  'unicorn': Banter(enter: ['*snorts sparkles at you*', 'You are NOT pure of heart. I can tell.'], fall: ['*a final, disappointed neigh*']),
  'centaur': Banter(enter: ['Half horse, half archer, all trouble.', 'The Thornwild is no place for two-legged things.']),
  'oakheart': Banter(enter: ['Little ember. You burned my children.', 'Grandmother is very old. And very cross.'], fall: ['Plant... my acorn... somewhere green...']),
  // ---- The Grimtusk Badlands ----
  'ork': Banter(
    enter: ['WAAAGH! ...sorry, wrong game. RAAARGH!', 'Ork smash! Ork also cook. Ork smash first.', 'You look tough. Ork likes tough. More to smash.'],
    hurt: ['Ow. Ork felt that one.'],
    fall: ['Ork... had... good run...'],
  ),
  'orkArcher': Banter(enter: ['Ork has bow. Ork has pointy sticks. You have problem.']),
  'orkShaman': Banter(enter: ['The spirits say you will lose. The spirits are usually drunk, but still.', 'Ooga-magic!']),
  'orkBerserker': Banter(enter: ['RAAAAAAAAAAAGH!', 'NO THINKING! ONLY AXE!'], hurt: ['MORE! MORE!'], fall: ['...worth... it...']),
  'minotaur': Banter(enter: ['You\'re in my maze now. Well. My valley.', '*stamps hoof meaningfully*']),
  'gargoyle': Banter(enter: ['I\'ve been sitting on that roof for 300 years. I\'m STIFF.', 'Stone cold. Literally.']),
  'warlock': Banter(enter: ['Ash to ash, knight. You\'re halfway there.', 'Vharrax rewards his servants. You, he\'ll just burn.']),
  'orkWarlord': Banter(enter: ['Krugg\'s best smasher! That\'s me!', 'You beat the little orks. Now beat a BIG one.']),
  'orkbehemoth': Banter(enter: ['KRUGG IS THE MOUNTAIN. MOUNTAINS DON\'T MOVE. YOU MOVE.', 'Tiny knight. Tiny sword. Big mistake.'], fall: ['Mountain... falls...']),
  // ---- The Cinderreach ----
  'wyvern': Banter(enter: ['*SCREEEECH*', '*circles overhead, hungrily*']),
  'obsidian': Banter(enter: ['My scales are glass. My temper is fire.', 'Little flame. I am the forge.']),
  'pitdemon': Banter(enter: ['Fire? I BATHE in fire. Try something else.', 'Your soul smells smoky. Delicious.'], fall: ['Back... to the pit... I go...']),
  'dragonboneWarden': Banter(enter: ['None shall pass the bones of the old wyrms.', 'I guarded dragons. You are not a dragon.']),
  'skeletonChampion': Banter(enter: ['I won a hundred tourneys. Then I died. Then I won a hundred more.', 'En garde, sooty one.']),
  // ---- The Ashen Order: knights who knelt to the Ember King ----
  'ashenKnight': Banter(
    enter: ['The Order rides for the Ember King. Stand aside, or burn.', 'You wear a knight\'s steel. We wore it once. Then we chose the winning side.', 'For the Throne, and the fire!'],
    hurt: ['You fight like the old Order did...'],
    fall: ['The fire... take me...', 'Tell them... we had no choice...'],
  ),
  'ashenChampion': Banter(
    enter: ['I held the Ember Gate for ten years. You are not getting through it.', 'Kneel to the fire, and you may keep your head.'],
    hurt: ['Good. GOOD. A real fight, at last.'],
    fall: ['The Order... is ash...'],
  ),
  'malric': Banter(
    enter: ['You again. Every time I burn the road behind me, you walk up it.', 'We were knights once, you and I. One of us still is. Let\'s find out which.', 'Draw, sooty one. Sir Malric does not wait.'],
    hurt: ['Hah! You\'ve been practising.', 'Not bad. Not good enough.'],
    fall: ['Enough. ENOUGH. This isn\'t over.', 'I yield. Today.'],
  ),
  'gargoylematriarch': Banter(enter: ['My children are on every rooftop. They\'ve seen what you did.']),
  'demonhound': Banter(enter: ['*growls in a voice like a furnace*', '*the air shimmers as it pads closer*'], fall: ['*whimpers, and the fire goes out of it*']),
  // ---- The Ember Throne ----
  'archwarlock': Banter(enter: ['I called the fire down on your village. Did you like it?', 'The Ember King\'s flame burns through me.']),
  'minotaurlord': Banter(enter: ['My horns are molten. So is my patience.']),
  'elderWyrm': Banter(enter: ['I remember when the world was green. I preferred it on fire.']),
  'demonlord': Banter(enter: ['I am Azgar, Herald of the Ember King. Kneel, and burn quickly.', 'You\'ve come so far. It\'s almost a shame.'], fall: ['My master... will... avenge...']),
  // ---- Ravenmoor ----
  'thrall': Banter(enter: ['The Countess... needs... more...', 'Don\'t look at the castle. Never look at the castle.'], fall: ['Free... at last...']),
  'vampireSpawn': Banter(enter: ['*hisses, fangs out*', 'So warm. You\'re so WARM.'], hurt: ['*shrieks*'], fall: ['*crumbles to grey dust*']),
  'bloodBride': Banter(enter: ['The Countess sends her love. All of it. Through your neck.', 'Stay for supper, darling. You ARE supper.'], fall: ['My lady... forgive me...']),
  'vampireKnight': Banter(enter: ['I swore to protect the living. Then I stopped being one.', 'The moon is up. You should not be.'], fall: ['Dawn... at last...']),
  'countess': Banter(
    enter: ['A visitor! How lovely. Nobody visits any more. I wonder why.', 'Two hundred years I\'ve kept this moor. Two hundred years, and still so thirsty.'],
    hurt: ['You\'ve spilled my wine. And my blood. I am cross about the wine.'],
    fall: ['Into... the bats... I go...'],
  ),
  // ---- The Silverwood ----
  'elfRanger': Banter(enter: ['You were warned at the first tree. This is the last.', 'Turn back, sooty one. Your boots offend the moss.'], fall: ['The trees... will remember you...']),
  'elfBlade': Banter(enter: ['I have practised this cut for three hundred years. Hold still.', 'Fire-bringer. You smell of it.'], fall: ['Swift... too swift...']),
  'elfWarden': Banter(enter: ['None pass the Silverwood. None have. None will.', 'I sang the fire out of these trees. I can sing you out too.']),
  'elfDruid': Banter(enter: ['The forest has a long memory, and short patience.', 'Root and thorn, hold them!'], fall: ['Grow... back...']),
  'elfQueen': Banter(
    enter: ['The world burned and we hid. Now the world comes knocking, in sooty boots.', 'Show me why I should not close the forest forever.'],
    hurt: ['Hm. You have something the burned world lost.'],
    fall: ['Enough. Enough. You have made your point.'],
  ),
  // ---- Deepforge Hold ----
  'dwarfAxe': Banter(enter: ['OI! Wipe yer boots! This hall\'s older than your whole family!', 'Another surfacer! Get the axe, lads! I am the lads!'], hurt: ['Ha! A real scrapper!'], fall: ['Tell me mum... I went down swinging...']),
  'dwarfShield': Banter(enter: ['Nothing gets past this shield. Nothing. I\'ve checked.', '*thunk* *thunk* That\'s me knocking. Your turn.']),
  'dwarfXbow': Banter(enter: ['Seen a lot of things down a crossbow. You\'re the ugliest.', 'Hold still, I\'ve only the one bolt left. Lie. I\'ve forty.']),
  'dwarfRune': Banter(enter: ['The runes say you\'ll lose. The runes are never wrong. Well. Twice.', 'By stone and steel and grudge!'], fall: ['The runes... lied... third time...']),
  'dwarfThane': Banter(
    enter: ['WHO KNOCKS ON THE DOOR OF DEEPFORGE? Oh. A wee sooty thing. Let\'s have a look at you.', 'Nobody\'s beaten me since the old king. Come on then!'],
    hurt: ['HAH! Now THAT was a hit!'],
    fall: ['Bah! Fine! FINE! Someone fetch the ale!'],
  ),
  // ---- The Skyreach Aeries ----
  'harpy': Banter(enter: ['*a shriek like a kettle full of knives*', 'Fall, little crawler! Fall! We\'ll catch you. Some of you.'], fall: ['*it tumbles down the cliff in a storm of feathers*']),
  'aerieWarden': Banter(enter: ['Crawler. You have climbed very far to die so high up.', 'The sky is ours. The ground was always yours.']),
  'aerieSkyshot': Banter(enter: ['I can see you from three miles off. You walk like a duck.', '*an arrow is already falling towards you*']),
  'aerieCaller': Banter(enter: ['The storm listens to me. Do you hear it?', '*thunder rolls across the peaks*'], fall: ['The sky... falls...']),
  'griffin': Banter(enter: ['*a scream like an eagle and a roar like a lion, at the same time*', '*it rears up and spreads its wings across the whole sky*'], fall: ['*it folds its wings and lies still*']),
  'stormRoc': Banter(
    enter: ['*the sky goes dark, and the dark has wings*', '*lightning cracks down on either side of you*'],
    hurt: ['*thunder, much too close*'],
    fall: ['*the storm breaks, and the sun comes out*'],
  ),
  // ---- The Hollowdeep ----
  'cavebat': Banter(enter: ['*a shriek so high you feel it in your teeth*', '*it drops off the roof and opens its wings*'], fall: ['*it flutters into the dark and doesn\'t come back*']),
  'batkin': Banter(enter: ['I heard you three caves back, surface-walker.', '*click... click... click*'], fall: ['So loud... you were so loud...']),
  'batkinCaller': Banter(enter: ['Listen. Hear that? That\'s your heart, going fast.', '*she hums, and the whole cave hums with her*'], fall: ['The echo... stops...']),
  'batkinGuard': Banter(enter: ['None pass to the Roost.', '*he folds his wings and levels the glaive*'], fall: ['The Mother... will hear of this.']),
  'roostMother': Banter(
    enter: ['*every bat in the cave falls silent at once*', '*she unfolds wings that touch both walls of the cavern*'],
    hurt: ['*a shriek that brings dust down from the roof*'],
    fall: ['*she folds her wings, and lets the dark take her*'],
  ),
  // ---- The Blossom Isles ----
  'ronin': Banter(enter: ['I have no master. Today, I have an opponent.', '*he rests a hand on his sword, and waits*'], fall: ['A good cut. A good end.']),
  'ashigaru': Banter(enter: ['Halt! The ports are closed by order of the Shogun!', 'Spears! Spears up!']),
  'shinobi': Banter(enter: ['*you only see it because it wants you to*', '...'], fall: ['*a puff of smoke, and an empty black coat*']),
  'onmyoji': Banter(enter: ['The stars said you would come. They did not say you would leave.', '*paper charms unfold in the air around her*']),
  'oni': Banter(enter: ['MEAT! Small meat! With a SWORD!', '*it laughs, and the bamboo shakes*'], fall: ['*it sits down heavily, and does not get up*']),
  'shogun': Banter(
    enter: ['You crossed the sea to die by my sword. I respect that.', '*he draws, slowly, and the blossom stops falling*'],
    hurt: ['Good. Again.'],
    fall: ['*he sets down his sword, kneels, and bows*'],
  ),
  // ---- The Changeling Isle ----
  'shifter': Banter(enter: ['Hold still. I want to remember your face.', 'What shall I be for you today?'], fall: ['*it melts into a grey puddle, still trying to be something*']),
  'shifterSly': Banter(enter: ['You\'ve met me before. You just didn\'t know it was me.', '*it smiles with somebody else\'s mouth*']),
  'shifterHulk': Banter(enter: ['BIG. Let\'s be BIG.', '*it swells up like bread rising, then keeps going*']),
  'thousandfold': Banter(
    enter: ['Hello, me.', 'I have been everyone. Now I would like to be you.'],
    hurt: ['That\'s not fair. I was being you.'],
    fall: ['Which... of us... won...?'],
  ),
  // ---- The Shattered Sea ----
  'merrowRaider': Banter(enter: ['Blub-blub! That means "give me your boots".', 'Surface-dweller! Your wreck is OUR wreck!'], fall: ['Back... to the deep...']),
  'merrowCaller': Banter(enter: ['The tide answers me. You do not.', '*the sea rises up behind it like a wall*'], fall: ['The tide... turns...']),
  'merrowGuard': Banter(enter: ['None pass the reef. None. Not even fish.', '*clacks its shell shield*']),
  'seaSerpent': Banter(enter: ['*HSSSSSSS*', '*it rears up out of the surf, and up, and up*'], hurt: ['*thrashes, spraying foam*'], fall: ['*it slides back under the waves, and does not come up*']),
  'leviathan': Banter(
    enter: ['*the whole sea rises, and the Leviathan rises with it*', '*a voice like the tide dragging stones*: WHO WAKES ME?'],
    hurt: ['*the deep groans*'],
    fall: ['*it sinks, and the sea goes calm*'],
  ),
  'kraken': Banter(enter: ['*a hundred wrecks shift as something vast uncoils beneath them*'], fall: ['*the Kraken sinks with a sound like a fleet going down*']),
  // ---- The Sunscale Jungle ----
  'lizardGuard': Banter(enter: ['Sssoft-skin! The sun sssent you to us as a gift!', '*hisses and taps its spear on its shield*'], hurt: ['It will grow back. Everything grows back.'], fall: ['Back... to the egg...']),
  'lizardSkirmisher': Banter(enter: ['*a javelin is already in the air*', 'Run, sssoft-skin. I like it when they run.']),
  'lizardShaman': Banter(enter: ['The sun burned the world clean. Now it will burn you.', 'Sssun-father, see this offering!'], fall: ['The sun... sets...']),
  'lizardChampion': Banter(enter: ['*it lifts a greataxe as big as you, one-handed*', 'I have shed my ssskin eleven times. You will not see a twelfth.']),
  'lizardKing': Banter(
    enter: ['I ATE the sun once, sssooty one. Just a little. It wanted to be eaten.', 'Kneel at the altar. It is warm. You will be warmer.'],
    hurt: ['It grows back. It always grows back!'],
    fall: ['The sun... has a new champion...'],
  ),
  // ---- The Isle of Mists ----
  'facelessWanderer': Banter(enter: ['...', '*it tilts its blank head, and listens to your face*'], hurt: ['*no sound at all*'], fall: ['*for a moment, a face shows through, smiling, and then it\'s gone*']),
  'facelessMimic': Banter(enter: ['"You again? Well, someone like you." It says it in your voice.', '*it raises its sword exactly the way you do*'], hurt: ['"Ow," it says, in your voice.'], fall: ['"Tell my mum... I was brave..." Your words. Your voice.']),
  'facelessChoir': Banter(enter: ['*a hymn with no words, from no mouth*', '*the lantern swings, and the fog sings with it*']),
  'facelessWarden': Banter(enter: ['*it plants its glaive in the shingle, and waits*']),
  'facelessMother': Banter(
    enter: ['Such a lovely face. Sooty, but lovely. May I?', 'Every face here was a gift. Give me yours, and you will never have to see what burned.'],
    hurt: ['You are scratching my children!'],
    fall: ['Take them... take them all back...'],
  ),
  // ---- The Howling Weald ----
  'woodsman': Banter(enter: ['Lovely day for it. Shame about tonight.', 'You\'d best be out of the wood by dark, stranger.'], fall: ['The moon... don\'t let it...']),
  'werewolf': Banter(enter: ['*a howl that shakes the pines*', '*it rises onto its hind legs, much too tall*'], hurt: ['*snarls*'], fall: ['*the wolf goes out of it, and a man lies in the needles*']),
  'werewolfStalker': Banter(enter: ['*eyes in the dark, then teeth*', '*it was behind you all along*'], fall: ['*a last, very human sigh*']),
  'werewolfBrute': Banter(enter: ['*it roars, and the birds leave the whole valley*'], hurt: ['*silver hackles bristle*'], fall: ['*it shrinks back into a very big, very tired man*']),
  'werewolfAlpha': Banter(
    enter: ['*the moon turns red, and the Alpha howls*', 'The Weald is mine. Every throat in it is mine.'],
    hurt: ['*the pack howls with it*'],
    fall: ['The moon... lets me go...'],
  ),
  'emberKing': Banter(
    enter: ['SO. THE SOOTY ONE. I WONDERED WHEN YOU\'D ARRIVE.', 'I BURNED THE WORLD. I WILL NOT MISS ONE KNIGHT.'],
    hurt: ['IMPOSSIBLE. I AM THE FIRE ITSELF.'],
    fall: ['THE FIRE... GOES OUT...'],
  ),
};

const _beast = Banter(enter: ['*growls*', '*snarls and circles*', '*bares its teeth*'], hurt: ['*whimpers*'], fall: ['*a last, sorry whine*']);
const _undead = Banter(enter: ['*a long, dry rattle*', 'Join usss...'], hurt: ['*clatter*'], fall: ['*collapses into dust*']);
const _anyone = Banter(
  enter: ['You again? Well, someone like you.', 'Turn back, knight. Or don\'t. I\'m not your mum.', 'This road\'s mine.'],
  hurt: ['Wait wait wait. Can we talk about this?', 'I\'ve made a terrible mistake.'],
  fall: ['Ugh...', 'Tell my mum... I was brave...', 'Not... fair...'],
);
const _boss = Banter(hurt: ['You\'re... stronger than you look.', 'This isn\'t over!'], fall: ['How... could I lose... to someone so sooty...']);

/// Banter for [f]: its own lines where it has them, then its kind's.
Banter banterFor(FoeType f) {
  final own = _byLook[f.look];
  final kind = f.beast || f.hound ? _beast : (f.undead ? _undead : (f.boss ? _boss : _anyone));
  return Banter(
    enter: own?.enter.isNotEmpty == true ? own!.enter : kind.enter.isNotEmpty ? kind.enter : _anyone.enter,
    hurt: own?.hurt.isNotEmpty == true ? own!.hurt : kind.hurt,
    fall: own?.fall.isNotEmpty == true ? own!.fall : kind.fall,
  );
}

/// The raiders who hit the town get their own lines.
const raidBanter = Banter(
  enter: ['Uh oh. It\'s the hero.', 'Run! No wait, fight! No, run!', 'We were just... borrowing it.'],
  fall: ['Fine! Keep your stupid potions!'],
);
