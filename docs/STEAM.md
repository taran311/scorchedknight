# Scorched Knight on Steam

The Steam version is the Windows build of the same game:

- **The whole game is unlocked.** Players buy it on Steam, so there's no Google Play purchase and no free-lands lock.
- **No sign-in screen.** Saves are kept on the PC, and Steam Cloud carries them between computers.
- **Fullscreen by default.** F11 or Alt+Enter switches between fullscreen and a window, and so does the Fullscreen switch in Settings. The game remembers the last choice.
- **Settings has "Quit to desktop".** It saves before closing. The Vibration switch is hidden on PC.

## 1. Build it (once per update)

1. Install **Visual Studio 2022 Community** and tick **Desktop development with C++**. This is Visual Studio itself, not VS Code. Flutter needs it to build for Windows.
2. In `C:\scorchedknight`, run `flutter pub get` once. The fonts are now built into the game.
3. Run **`build_steam.bat`**. It builds the game and makes `build\steam\ScorchedKnight-windows.zip`.
4. To try it, run `build\windows\x64\runner\Release\ScorchedKnight.exe`.

Raise `version:` in `pubspec.yaml` for each update, as for Google Play.

## 2. Steamworks account (once)

1. Sign up at **partner.steamgames.com** as **Hayer Software Limited**.
2. Fill in the bank, tax (the W-8BEN-E form for a UK company) and identity checks.
3. Pay the **Steam Direct fee: $100 per game**. It's paid back once the game earns $1,000.
4. You can't release until **30 days** after paying the fee. Start now and let that clock run.

## 3. Store page

Fill these in under **App Admin → Store page**.

**Graphical assets** are ready-made in `docs\steam\`:

| Steamworks field | File | Size |
|---|---|---|
| Header capsule | `header_capsule.png` | 920×430 |
| Small capsule | `small_capsule.png` | 462×174 |
| Main capsule | `main_capsule.png` | 1232×706 |
| Vertical capsule | `vertical_capsule.png` | 748×896 |
| Page background (optional) | `page_background.png` | 1438×810 |
| Library capsule | `library_capsule.png` | 600×900 |
| Library header | `library_header.png` | 920×430 |
| Library hero | `library_hero.png` | 3840×1240 |
| Library logo | `library_logo.png` | 1280×720, transparent |
| Client icon (Installation → Client images) | `app_icon.ico` | |

**Screenshots:** Steam wants at least 5, ideally 1920×1080. Take them yourself from the Windows build in fullscreen with **Win+Shift+S**, or press F12 once the game runs through Steam. Good shots are:
- a big special mid-animation
- the town
- the world map
- the forge or the Tent
- a boss fight

**Text:**
- **Short description:**
  > A cartoony turn-based knight RPG. Forge your gear, swear yourself to one of the old knightly orders, and fight across the ash-wastes to the Ember King's throne.
- **About this game:** reuse the long description from `docs\PLAY_STORE.md`. Leave out anything about the free lands and the one-time unlock, because on Steam the whole game is the purchase.
- **Genre and tags:** RPG, Turn-Based Combat, Fantasy, Medieval, Singleplayer, Casual, Loot, Cartoony, 2D.

**Content survey:** answer **frequent fantasy violence with cartoon blood**. The blood is on by default and can be switched off in Settings, so say so. There's no sexual content and no real gambling.

**Price:** £4.99 is a sensible Steam price, matching Google Play. Pick it from Steam's price tiers and let Steam suggest the other currencies.

**Coming soon:** publish the "Coming soon" page at least **2 weeks** before release, so people can wishlist it.

## 4. Upload the build (SteamPipe)

1. In **App Admin → SteamPipe → Depots**, keep the one depot Steam made and set it to **Windows**.
2. In **Installation → General → Launch options**, add one: executable **`ScorchedKnight.exe`**, operating system **Windows**.
3. In **SteamPipe → Builds**, use **Upload depot** to upload `build\steam\ScorchedKnight-windows.zip`. The web uploader takes zips up to 2 GB; the game is far smaller.
4. Set the new build live on the **default** branch.
5. **Publish** the changes. Steamworks keeps a draft until you do.

## 5. Steam Cloud (keeps the hero safe and on every PC)

The game's save is one file, so this needs no code, only Steam's **Auto-Cloud**.

1. Go to **App Admin → Steam Cloud**.
2. Set **Byte quota per user** to `10000000` and **Number of files allowed per user** to `10`.
3. Under **Root paths**, add:
   - **Root:** `WinAppDataRoaming`
   - **Subdirectory:** `Hayer Software Limited/Scorched Knight`
   - **Pattern:** `shared_preferences.json`
   - **OS:** Windows
4. Save and **Publish**.

## 6. Steam Deck

The game is drawn for 1280×800, the Deck's own screen, and the touchscreen works. Under **Steam Input**, set the default controller layout to **Gamepad with mouse trackpad**. Steam then checks the game for Deck compatibility on its own after release.

## 7. Release

1. **Request review** for the store page and the build. Each takes a few working days.
2. Once both pass, the 30 days are up and the page has been "Coming soon" for 2 weeks, press **Release**.
