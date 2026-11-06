# Scorched Knight on Google Play

Everything for the Play Console, in the order you'll need it. Same developer account as The Calorie
Card (Hayer Software Limited). App ID: `com.scorchedknight.scorchedknight` (permanent once uploaded).

## 1. On your PC (once)

1. **Upload key**: `powershell -ExecutionPolicy Bypass -File scripts\make_upload_key.ps1`
   - Its own key, in `%USERPROFILE%\ScorchedKnightKeys`, separate from The Calorie Card's.
   - Back the folder up and keep the password in your password manager.
   - It prints SHA-1 and SHA-256: add both to **Firebase → Scorched Knight → Project settings →
     Android app → Add fingerprint**.
2. **Build**: double-click `build_release.bat`. Out comes
   `build\app\outputs\bundle\release\app-release.aab`.
3. **Website pages**: push to GitHub as usual. `scorchedknight.com/privacy.html` and
   `scorchedknight.com/delete-account.html` go live with the next deploy. Play needs both links.

## 2. Play Console: create the app

play.google.com/console → **Create app**
- App name: **Scorched Knight**
- Default language: English (United Kingdom)
- App or game: **Game** · Free or paid: **Free**

## 3. Store listing (Grow users → Store presence → Main store listing)

**App name** (30): Scorched Knight

**Short description** (80):
> Survive the ashfall. Slay the flame. A turn-based knight RPG of fire and ash.

**Full description** (4000):
> The world burned. You didn't.
>
> Vharrax the Ember King turned the kingdom to ash in a single night. You crawled out of the cinders
> with a dented sword and a borrowed shield, at an inn that's barely standing. Now the road runs
> through seven scorched lands to his throne, and you're the only knight left to walk it.
>
> **A turn-based RPG made for one-handed play**
> Quick, punchy fights: strike, Mighty Blow, crossbow bolts, potions and rites. Every hit is a roll
> of the dice, every special a lucky break. Fights fit your phone screen, no scrolling.
>
> **Three knights in one**
> Forge the suits of the Blood Knight, the Forge Knight and the Dragon Knight. Each has its own blows,
> its own rites and its own way to fight, and you can change suits between fights.
>
> **Nineteen lands to burn through**
> Seven lands on the road to the Ember King, twelve wild lands off it: werewolf woods, vampire
> castles, dwarf holds, sunken seas and dragon roosts. Break the seals on the Ember Throne by beating
> their lords.
>
> **Legendary steel and lost relics**
> Nine legendary weapons, each with a special you'll want to see again: ghost wolves, a host of the
> dead, a dragon from the sky. Gather the parts of lost relics across the world and have the smith
> forge them.
>
> **Your own keep**
> Rebuild your tent into a cottage, a keep and a fortress. Send your runners on errands while you
> fight, and rack your favourite outfits in the armoury.
>
> **When you've won**
> New Game+ brings tougher foes and better spoils. Hardcore gives you one life.
>
> No adverts. No energy timers. Sign in (optional) to carry your hero between your phone and
> scorchedknight.com.

**App icon**: `web\icons\Icon-512.png` (512×512).

**Feature graphic** (1024×500): `docs\play\feature_graphic.png`.

**Phone screenshots** (2 to 8, portrait): from your phone, e.g. the town, a boss fight with a
legendary special going off, the map, Your Tent with a class suit on, the forge.

**Category**: Role Playing. **Tags**: Role Playing, Turn-based RPG, Fantasy, Offline, Single player.
**Contact email**: support@thecaloriecard.com (or a Scorched Knight address once you have one).
**Website**: https://scorchedknight.com

## 4. App content (Policy → App content)

- **Privacy policy**: https://scorchedknight.com/privacy.html
- **Ads**: No, the app doesn't contain ads.
- **App access**: All functionality is available without special access (sign-in is optional).
- **Content rating** (IARC questionnaire): category **Game**.
  - Violence: yes, fantasy violence (non-realistic characters, cartoon style). Blood: no realistic
    blood. Not against realistic humans.
  - Fear: mild (skeletons, vampires, werewolves). Sexuality, language, drugs, gambling: none.
    (The "Gambler's Edge" dice are a weapon effect, not gambling: no real money, nothing to buy.)
  - User interaction: no chat, no sharing, no purchases. Shares location: no.
  - Expect around PEGI 7 / 12 and Everyone 10+.
- **Target audience**: 13 and over (13–15, 16–17, 18+). Not designed for children.
- **Data safety**:
  - Collects data: **Yes** (only if the player signs in).
  - Email address: collected, not shared. Purpose: account management. Optional.
  - Name (from Google sign-in): collected, not shared. Purpose: account management. Optional.
  - User IDs: collected, not shared. Purpose: account management, app functionality. Optional.
  - App activity → other user-generated content (the game save): collected, not shared. Purpose:
    app functionality. Optional.
  - Encrypted in transit: **Yes**. Users can request deletion: **Yes**.
  - Account deletion URL: https://scorchedknight.com/delete-account.html
- **Government app / financial features / health**: No.
- **News app**: No.

## 5. Release

1. **Test and release → Testing → Internal testing** first: create a release, upload the `.aab`,
   add yourself as a tester, install it from the Play link and check Google sign-in works.
2. **App signing**: Play Console → **Test and release → App integrity → App signing**. Copy the
   **App signing key** SHA-1 and SHA-256 into Firebase (as in step 1). Without this, Google sign-in
   fails in the copy people install from Play (the one Play signs), even though your own builds work.
3. **Production** (Test and release → Production → Create new release), or **Closed testing**
   first if Play asks for it:
   - A personal developer account made after November 2023 needs a closed test with at least 12
     testers for 14 days before production.
   - An organisation account (Hayer Software Limited with a D-U-N-S number) doesn't.
   - The Calorie Card went the same way, so you'll know which applies.
4. Each new version: raise `version:` in `pubspec.yaml` (1.0.0+1 → 1.0.1+2), run
   `build_release.bat`, upload.
