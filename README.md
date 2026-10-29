# Scorched Knight

*Survive the ashfall. Slay the flame.*

A cartoony 2D turn-based fantasy RPG for the web (Flutter). Vharrax the Ember King burned the world in the **Great Burning**. You survived it, singed and sooty, and now drink at the **Soot & Kettle**, the one inn still standing. Seven lands lie between you and the end of the Ember Throne. Cross them all and put the fire out for good.

Its own game, with its own brand: no sign-in, no calories, nothing shared with CalorieKnight or The Calorie Card. It was started from a copy of CalorieKnight's game layer and art.

## Run it

```
cd C:\scorchedknight
run_web.bat
```

That serves the game at **http://localhost:5070** and opens it in your normal Chrome (CalorieKnight keeps 5050, so both can run side by side). The hero is saved in the browser; `flutter run -d chrome` would open a throwaway Chrome profile and forget them each time. It's a **release build**, so it plays smoothly; whenever a file in `lib` changes it rebuilds by itself (`tool/dev.dart` watches for you; about a minute, then refresh the page). `run_web.bat debug` runs the debug build instead: changes land in seconds, but the game runs noticeably slower. `r`, `R` and `q` still work in the terminal. Add `?slow=6` to the address to watch the fight animations in slow motion.

Checks:

```
flutter test                     # rules and screens
dart run tool/balance.dart 16    # plays the whole game 16 times per class and prints the balance
```

Packages: `shared_preferences` (the save on the device), `google_fonts`, and Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`) for cloud saves. Cloud saves stay off until Firebase is set up; the game plays the same without them.

## Phones, Android and cloud saves

- **Phones:** every screen has a phone layout (under 600px wide). The town's four places become big buttons under the scene, the fight stacks your card and the foe's above the stage with the moves in rows of four, and long-press shows a move's card. The web version installs to the home screen (`web/manifest.json`).
- **Android:** `tool\setup_android.bat` creates the Android project and applies the game's name, icon, dark launch screen, internet access and release signing (`tool/android_patch.dart`).
- **Cloud saves:** sign in with Google in Settings and the hero follows you between browser and phone (`lib/services/cloud.dart`, Firestore at `players/{uid}`, rules in `firestore.rules`).
- **Setup steps** for Firebase, Android Studio and the Play Store: **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)**.

## How it plays

1. **Name your knight**, hero or heroine. Everyone starts covered in soot.
2. **The Soot & Kettle** is home: rest by the fire (free, full health), **have a pint** (2 gold, once between fights: a tip about the boss, liquid courage for your next fight, a bowl of lentil stew, an arm-wrestle, a toast to your deeds, a stranger's tale, or just the hiccups), shop with **Mags the merchant**, sort your **Kit & rites**, read the adventure log, and **Set out**.
3. **The map**: pick an open continent and **Explore** to fight whatever turns up (now and then a rare foe, a named rare boss or a whole pack). Win 8 fights in a continent to find its boss; beat the boss to open the next continent and win its companion and legendary trinket. Bosses can be fought again any time after.
4. **Fights are turn-based.** One hero, the knight, with three tools. Each turn pick one (keys 1 to 7 work on a keyboard):

| | |
|---|---|
| **Attack** | Your blade. Charges a weapon's special attack, and your companion bites along. |
| **Shield Bash** | (A **Mighty Blow** without a shield.) 1.5× and the foe is too dazed to hit back; bosses shake it off half the time. Rests 3 turns. |
| **Cast** | An **Ember Rite**: the spell you've prepared (16 of them, learned as you level, Arcane Bolt to Healing Light). Every attack, bash or shot gathers 1 mana; rites spend it. |
| **Shoot** | Your **crossbow**: 70% of an attack (upgrade it at Mags's stall to 80 / 90 / 100%), with special bolts if you've loaded some: **burning** (fire), **blessed** (holy fire against anything) or **bloodleech** (heals you). |
| **Potion** | Heals half your max HP (at least 40 + 3 × level). It takes your turn, so the foe still swings, but it always comes out well ahead. Mags sells more. |
| **Command** | Your companion acts: hounds pounce (and may stagger the foe), a fairy casts a charm at once, a dragon breathes a torrent of fire. Rests 3 turns. |
| **Flee** | 60% (bosses 30%), plus half your dodge, and 15% better after every failed try in the same fight (up to 95%, bosses 80%). You run all the way back to the Soot & Kettle and lose nothing but the fight. |

   **Foes aloft or out of reach** (archers, witches, warlocks, ghosts and banshees, gargoyles, wyverns, Vharrax himself) take 70% from your blade and 125% from your crossbow; rites reach anything. Foes fight back their own way too: archers shoot, casters hurl magic, dragons and demons breathe fire.

   Then the foe swings: you might dodge, parry and riposte, block, or take it. Run out of HP and you're **knocked out**: the innkeeper drags you back to the Soot & Kettle, patched up but a little poorer (10% of your gold, capped).
5. **Spoils**: about a third of ordinary foes drop gear (rare foes and bosses always do); equip it (the old piece goes to your chest), keep it or sell it. Rarities per 1000 ordinary drops: 550 common, 300 uncommon, 120 rare, 27 epic, 3 legendary. Each land has its signature loot, once a game each: bone gear from the Gloomfen's dead, heartwood from the Thornwild's ents, the ork weapon from the Grimtusk Badlands, a rune weapon from the dragonbone wardens. Dragons leave one kind of prize, the **wyrmscale** set (gear and dragonbone jewellery in the dragon's colour).
6. **Scorched to shining**: the hero starts with soot on their face and kit, scorch marks and a wisp of smoke. It washes off as you level (gone by level 30), and from level 30 you shine.

## One knight, not three classes

Scorched Knight has one hero, the knight. Variety comes from how you fight (blade, rites, crossbow, companion) and from gear, the way AdventureQuest gives one character weapons, spells and pets. A shield adds block chance and makes the skill a Shield Bash. Armour from Mags: 0 / 15 / 30 / 40% damage taken off for 0 / 120 / 300 / 600 gold.

The mage and ranger kit from CalorieKnight (robes, staves, bows, their looks and loot tables) is still in the code, unused, in case we ever want other heroes or builds; the game only makes knights.

## The continents

| # | Continent | Level | Hazard (ward) | Drops (for the next ward) | Boss | First-win reward |
|---|---|---|---|---|---|---|
| 1 | **Cindervale** (ashy farmland round the inn) | 1 | none | Ashbloom | Gorbo the One-Eyed (cyclops) | Wolf pup · Gorbo's Eye |
| 2 | **The Gloomfen** (drowned, haunted marsh) | 6 | Bog rot (Fenward Charm) | Marsh-light | The Bone Colossus | The Nightmare (ghostly steed) · Bone Phylactery |
| 3 | **The Thornwild** (a forest that grew back angry) | 12 | Stinging spores (Sporeveil) | Heartwood seed | Grandmother Bramblecrown (great ent) | Fairy · Bramblecrown's Acorn |
| 4 | **The Grimtusk Badlands** (orks, minotaurs, gargoyles) | 18 | Scorching sun (Sunshade Talisman) | War-drum shard | Krugg the Mountain (ork behemoth) | Hellhound pup · Krugg's War Horn |
| 5 | **The Sunken Sands** (glassed desert, opened tombs: mummies, tomb priests and guardians, raiders, jackals) | 25 | Sandstorm (Veil of the Dunes) | Tomb salt | Nephrakhet, the Ash Pharaoh (mummy king) | Ankh of Nephrakhet |
| 6 | **The Cinderreach** (black glass, dragons, demons) | 31 | Ash storm (Stormglass Lantern) | Black glass | Scorchmaw, Hound of Vharrax | Dragon egg · Scorchmaw's Collar |
| 7 | **The Ember Throne** | 38 | Living flame (Frostheart Scroll) | | **Vharrax the Ember King** (dragon) | Emberheart · the end of the Great Burning |

- **Getting in:** a continent opens once you've beaten the previous boss *and* reached its level.
- **Hazards:** each land past Cindervale hurts you every turn you fight there (5% of your max HP; it never knocks you out on its own) until you carry its **ward**. Mags crafts the ward from 6 reagents dropped by the *previous* continent's foes (half of all wins drop one, bosses drop 3) plus gold (60 × continent²: 60, 240, 540, 960, 1,500, 2,160). Push on early and suffer, or gather and go in prepared.
- **Foes** are never weaker than their continent's level and keep pace with you above it. A foe above your level hits 5% harder per level and shrugs off 3% of your damage per level. Each boss is a fair fight at the next continent's level (Vharrax at 44).
- **Packs** (three foes at once) turn up more often the further you go (5% in Cindervale, 17.5% at the Ember Throne). Sweeping weapons (halberds, battleaxes, greatswords, morning stars), area rites (Frost Nova, Chain Lightning, Summon Dragonfire, Spectral Charge), special bolts and weapon special attacks hit the whole pack for +50%; sweeping gear says so on its card.

## The Wilds

Off the story's road, three lawless areas drawn on the map between the lands (tap one to head in; while a trip is under way the town signpost takes you straight back). You walk in and keep walking: every step is a surprise, and nothing you find is yours until you get it home.

| Area | Opens when | Foes | Ruled by |
|---|---|---|---|
| **The Ashen Wilds** | Gorbo falls | Cindervale & the Gloomfen, plus bandits | The Ash Baron |
| **The Briarwaste** | Grandmother Bramblecrown falls | the Thornwild & the Grimtusk Badlands, plus bandits | Old Gnasher, the Bear-King |
| **The Smoking Marches** | Nephrakhet falls | the Cinderreach & the Ember Throne, plus bandits | The Cinder Tyrant |

- **Steps:** a fight (now and then a rare foe, a pack, and from step 12 the area's warlord, who always drops epic or legendary gear), or a chest, a cutpurse with his hand in your pack, a snare, an abandoned campfire (+35% HP), Pip the pedlar (potions), a lost traveller, or an unguarded bandit hoard (grab it all and the next step is a fight). HP doesn't come back on its own; drink potions between steps.
- **The pack:** gold and gear from the wilds go in your pack, not your purse. Deeper means tougher foes (+0.3 / 0.55 / 0.65 levels a step in the three areas) and better finds (gold ×0.75 at the edge, +4% a step; better rarity odds; gear up to 4 levels above you).
- **Getting out:** a **waystone** every 5 steps (and the edge you came in by): head home from one and you keep everything. **Run for it** anywhere else and bandits snatch about **40%** of the pack on the way. **Flee a fight** and 15% spills out (you stay in the wilds). **Knocked out**, scavengers take **75%**. The page always shows what leaving right now would cost.
- **Struggling with the story?** Two knock-outs on one land's trail and the trail (and the knock-out screen) points you at the toughest wilds you've opened. Beat that land's boss and the hint goes away.

`dart run tool/balance.dart 16 wilds` plays each area from the moment it opens, three ways, against the story trail at the same moment:

| Per fight | Story trail | Careful (home at step 5) | Bold (step 10) | Greedy (step 20) |
|---|---|---|---|---|
| Ashen Wilds (level ~5) | 48 gold, 0.26 epic+ | 58 gold, 0.42 epic+, 0% KO | 75, 0.55, 0% KO | 55, 0.33, 58% KO |
| Briarwaste (level ~17) | 174, 0.50 | 181, 0.56, 2% | 238, 0.69, 2% | 319, 0.69, 17% |
| Smoking Marches (level ~31) | 427, 0.59 | 401, 0.57, 0% | 489, 0.57, 0% | 453, 0.53, 45% |

A careful trip earns about what the story does; going deeper pays more until greed gets you knocked flat. The story stays the way forward (new lands, bosses, companions, relics); the wilds are where you gear up or take a break from it.

## Balance

`tool/balance.dart` plays the whole game with an auto-player that equips upgrades, buys armour, crossbows and potions, rests at the Inn, grinds to each boss's level, and fights in one of three styles: every tool, no rites, or the blade alone. Current tuning, 16 runs each:

| | Every tool | No rites | Blade only |
|---|---|---|---|
| Turns per regular foe (Cindervale → Ember Throne) | 3.3 → 5.5 | 4.3 → 5.4 | 4.3 → 6.1 |
| HP lost per regular fight | 12–29% | 10–26% | 13–29% |
| Turns to fell Vharrax | ~17 | ~16 | ~23 |
| Fights to beat Vharrax (at about level 37) | ~240 | ~245 | ~250 |

A pure blade knight gets there, just with longer fights against foes aloft; the crossbow and rites make those fights quicker. Foe HP is set from the gear a hero of that level usually carries (`gearPower` in `lib/game/rules.dart`), so a typical fight takes about five turns at any level. Foes hit for (13 + 4.6 × level) × (1 + 5% per continent), before armour.

## How it's organised

- `lib/game/` pure Dart rules: `catalog.dart` (continents, foes, companions), `rules.dart` (the numbers), `engine.dart` (every action, the turn), `models.dart` (the save), `wilds.dart` (the Wilds), `loot.dart`, `spells.dart`, `classes.dart`, `ammo.dart`, `enchants.dart`, `mounts.dart`, and `controller.dart` (ties the engine to the screens).
- `lib/art/` everything is painted in code: jointed 2D heroes and foes, beasts, dragons (Vharrax's look is `emberKing` in `creatures.dart`), battlegrounds, the inn. Soot and shine are in `body.dart` (`_soot`, `_shine`) and `heads.dart` (`_sootyFace`).
- `lib/ui/` screens: `class_picker.dart` (naming your knight), `inn_page.dart` (home), `map_page.dart`, `wilds_page.dart`, `battle_screen.dart` + `battle_stage.dart` (the animated fight), `hero_page.dart` (Kit & rites), `merchant.dart`, `loot_window.dart`.
- `lib/services/storage.dart` keeps the save on the device; `lib/services/cloud.dart` signs in and keeps a copy in Firestore.

## The website

scorchedknight.com is served by GitHub Pages. Every push to `main` runs
`.github/workflows/deploy.yml`, which runs the engine tests, builds the web game and puts it live
(about 3–5 minutes). `web/CNAME` holds the domain.

## Later

- Still to check: app stores, Steam, itch.io and trademarks for "Scorched Knight".
