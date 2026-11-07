// Connects the pure-Dart engine to Flutter: holds state, saves it, and tells the battle stage
// what to animate. The stage reports back as blows land, so HP bars drop on the hit, not the tap.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/storage.dart';
import 'brews.dart';
import 'catalog.dart';
import 'classes.dart';
import 'crafting.dart';
import 'engine.dart';
import 'loot.dart';
import 'tasks.dart';
import 'models.dart';
import 'events.dart';
import 'rules.dart' show Trait, suitWorn, maxHp;
import 'spells.dart' show spellById;
import 'tarot.dart';
import 'vault.dart';
import 'wilds.dart';
import 'dungeons.dart';
import 'knight_classes.dart' show classOf;

sealed class StageEvent {}

/// One turn: your action and the foe's reply.
class SwingEvent extends StageEvent {
  SwingEvent(this.result);
  final SwingResult result;
}

/// A new foe walks onto the field, with a banner.
class EnterEvent extends StageEvent {
  EnterEvent(this.foe, this.banner);
  final FoeType foe;
  final String? banner;
}

/// Mounted: the free charge that opens the fight, once the foe has walked in.
class ChargeEvent extends StageEvent {
  ChargeEvent(this.result);
  final SwingResult result;
}

/// A new adventure started: the stage drops any animation still playing.
class ResetEvent extends StageEvent {}

class KillEvent extends StageEvent {
  KillEvent(this.kill);
  final KillResult kill;
}

/// How a fight ended, for the battle screen.
enum Outcome { won, fled, knockedOut }

class GameController extends ChangeNotifier {
  GameController({GameStorage? storage, GameStorage? hardcoreStorage, this.cloud}) : storage = storage ?? GameStorage(), _hcStorage = hardcoreStorage ?? GameStorage(slot: 'hardcore'), _hcPrefs = storage == null {
    _mainStorage = this.storage;
    cloud?.addListener(_cloudChanged);
  }

  /// Where the hero being played is kept: your main hero's save, or (on a hardcore road) its own.
  GameStorage storage;
  late final GameStorage _mainStorage;
  final GameStorage _hcStorage;

  /// Whether the last-played save is remembered on the device (not for a game kept in memory, as
  /// the tests and previews keep theirs).
  final bool _hcPrefs;

  /// Cloud saves, if this build has them (null in tests and until Firebase is set up).
  final SaveCloud? cloud;

  /// A newer save found in the cloud than the one on this device: the player picks which to keep.
  CloudCopy? cloudChoice;

  Timer? _pushTimer;
  bool _dirty = false, _wasSignedIn = false;
  GameEngine engine = GameEngine(GameEngine.newGame());
  bool loaded = false;

  /// True while a turn (or a foe walking in, or falling) is animating; buttons wait for it.
  bool busy = false;

  /// The foe the stage is showing (kept after the fight ends, so it can fall or watch you run).
  int shownFoe = 0;
  Rare? shownRare;

  /// The shape a shapeshifter is shown in (it changes when the stage plays the shift).
  int? shownForm;
  FoeType get shownFoeType => formed(encounterType(shownFoe, shownRare), shownForm);

  /// Foe HP as the player sees it: drops when the blade lands, not when the button is tapped.
  int shownFoeHp = 0, shownFoeMax = 1;

  /// The most recent turn, for the battle screen's summary line.
  SwingResult? lastSwing;

  /// Set when a fight ends and its animation has played: the battle screen shows the result.
  Outcome? outcome;
  KillResult? lastKill;

  /// How fast the battle stage plays.
  /// How fast fights play: a touch brisker than the animations' own timing, and Fast fights quicker
  /// still.
  double get stageSpeed => state.settings.fastFights ? 1.7 : 1.15;

  final _events = StreamController<StageEvent>.broadcast();
  Stream<StageEvent> get events => _events.stream;

  GameState get state => engine.state;

  Future<void> load() async {
    final saved = await storage.load();
    if (saved != null) engine = GameEngine(saved);
    // Last played on a hardcore road: open there again (it says so on the hero card).
    if (_hcPrefs && await GameStorage.activeSlot() == 'hardcore') {
      final run = await _hcStorage.load();
      if (run != null && run.hardcore) {
        storage = _hcStorage;
        engine = GameEngine(run);
      }
    }
    _syncShown();
    loaded = true;
    notifyListeners();
    _wasSignedIn = cloud?.signedIn ?? false;
    if (_wasSignedIn) unawaited(_firstSync());
  }

  void _syncShown() {
    _lastClass = classOf(state.knight)?.id;
    shownFoe = state.foe;
    shownRare = state.rare;
    shownForm = state.form;
    shownSummons = state.summons;
    shownFoeHp = state.foeHp;
    shownFoeMax = state.foeMax;
  }

  void _save() {
    unawaited(storage.save(state));
    _schedulePush();
  }

  /// Writes the hero away now and waits for it (quitting to the desktop).
  Future<void> saveNow() => storage.save(state);

  // ---- cloud saves ----

  /// Signed in or out: on signing in, match this device's save with the cloud's. Signing out
  /// brings the sign-in screen back (the hero stays on this device).
  void _cloudChanged() {
    final now = cloud?.signedIn ?? false;
    if (now && !_wasSignedIn && loaded) unawaited(_firstSync());
    if (!now && _wasSignedIn && loaded) {
      state.settings.guest = false;
      unawaited(storage.save(state));
      notifyListeners();
    }
    _wasSignedIn = now;
  }

  /// True while this device's save is first matched with the cloud's after signing in (a new
  /// device shows "Fetching your hero…" rather than the opening cutscene).
  bool syncing = false;

  Future<void> _firstSync() async {
    syncing = true;
    notifyListeners();
    try {
      await syncWithCloud();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Plays on without an account: the hero is kept on this device only.
  void playAsGuest() {
    state.settings.guest = true;
    _changed();
  }

  /// Saves go up at most every 20 seconds while you play (and straight away when the app is put
  /// away: see [flushCloud]).
  void _schedulePush() {
    // (A hardcore hero is kept on this device only: the cloud holds your main hero.)
    if (cloud?.signedIn != true || state.hardcore) return;
    _dirty = true;
    _pushTimer ??= Timer(const Duration(seconds: 20), () => unawaited(flushCloud()));
  }

  /// Sends the latest save up now, if anything changed since the last one.
  Future<void> flushCloud() async {
    _pushTimer?.cancel();
    _pushTimer = null;
    final cl = cloud;
    if (!_dirty || cl == null || !cl.signedIn || state.hardcore) return;
    _dirty = false;
    if (!await cl.push(jsonEncode(state.toJson()), storage.savedAt, cloudSummary(state))) _dirty = true;
  }

  static String cloudSummary(GameState s) => '${s.settings.name} · ${s.knight.heroClass.label}, level ${s.knight.level}';

  /// Matches this device with the cloud: the newer save wins, but if both have real progress
  /// and the cloud's is newer, the player is asked ([cloudChoice]).
  Future<void> syncWithCloud() async {
    final cl = cloud;
    if (cl == null || !cl.signedIn || state.hardcore) return;
    final copy = await cl.fetch();
    if (copy == null) {
      // Nothing up there yet: this device's hero goes up.
      _dirty = true;
      await flushCloud();
      return;
    }
    if (copy.savedAt == storage.savedAt) return cl.markSynced();
    final fresh = !state.knight.classChosen || (state.knight.level <= 1 && state.foesFelled == 0);
    if (fresh) return adoptCloud(copy);
    if (copy.savedAt > storage.savedAt) {
      cloudChoice = copy;
      notifyListeners();
      return;
    }
    _dirty = true;
    await flushCloud();
  }

  /// Plays on from the cloud's save (this device's is replaced).
  Future<void> adoptCloud(CloudCopy copy) async {
    try {
      final s = GameState.fromJson((jsonDecode(copy.json) as Map).cast<String, dynamic>());
      engine = GameEngine(s);
      _emit(ResetEvent());
      busy = false;
      outcome = null;
      _syncShown();
      await storage.save(state, at: copy.savedAt);
      cloud?.markSynced();
    } catch (_) {
      // A save that won't read: keep this device's.
    }
    cloudChoice = null;
    notifyListeners();
  }

  /// Keeps this device's save, and sends it up over the cloud's.
  Future<void> keepDeviceSave() async {
    cloudChoice = null;
    notifyListeners();
    await storage.save(state);
    _dirty = true;
    await flushCloud();
  }

  void _changed() {
    // A whole faction suit worn once counts for its task, even after you take a piece off.
    final suit = suitWorn(state.knight), firstTime = suit != null && !state.did.contains('suit:$suit');
    if (suit != null) engine.mark('suit:$suit');
    // The whole suit of a class just went on: you're that knight now. (The awakening plays the first
    // time you become each knight; changing back into a suit you've worn before is just a change.)
    final cls = classOf(state.knight)?.id;
    if (loaded && cls != null && cls != _lastClass && firstTime) classAwakened.value = cls;
    // An order mastered: its ceremony, once the killing blow and the victory have had their moment.
    if (engine.mastered case final id?) {
      engine.mastered = null;
      Future<void>.delayed(const Duration(milliseconds: 3200), () => classAwakened.value = 'master:$id');
    }
    _lastClass = cls;
    // Gear changed out of a fight (a piece swapped, armour reforged): never more HP than the new
    // most.
    final k = state.knight;
    if (!state.inBattle && k.hp > maxHp(k)) k.hp = maxHp(k);
    _save();
    notifyListeners();
  }

  // ---- the map ----

  bool travel(int c) {
    final ok = engine.travel(c);
    if (ok) _changed();
    return ok;
  }

  bool get bossReady => engine.bossReady;

  String? whyNotTravel(int c) => engine.whyNotTravel(c);
  String? whyNotWard(int c) => engine.whyNotWard(c);

  bool craftWard(int c) {
    final ok = engine.craftWard(c);
    if (ok) _changed();
    return ok;
  }

  /// Sets out into the current continent (call with the battle screen open).
  void explore() {
    if (busy || state.inBattle) return;
    engine.explore();
    _arrive();
  }

  /// One of the Ember King's generals, hunted down (call with the battle screen open).
  void huntGeneral() {
    if (busy || state.inBattle || engine.huntGeneral() == null) return;
    _arrive();
  }

  /// The current land's boss, risen (call with the battle screen open).
  void exploreHeroic() {
    if (busy || state.inBattle || !engine.risenReady(state.continent)) return;
    engine.exploreHeroic();
    _arrive();
  }

  bool heroicOpen(int c) => engine.heroicOpen(c);
  bool risenReady(int c) => engine.risenReady(c);
  bool heroicCleared(int c) => engine.heroicCleared(c);
  String? whyNotForge(int c) => engine.whyNotForge(c);

  GearItem? forgeRelic(int c) {
    final item = engine.forgeRelic(c);
    if (item != null) _changed();
    return item;
  }

  List<GearItem> get honeables => engine.honeables;
  String? whyNotHone(GearItem g) => engine.whyNotHone(g);
  bool hone(GearItem g) {
    final ok = engine.hone(g);
    if (ok) _changed();
    return ok;
  }

  String? get whyNotCrate => engine.whyNotCrate();
  GearItem? buyCrate(GearSlot slot) {
    final g = engine.buyCrate(slot);
    if (g != null) _changed();
    return g;
  }

  List<GearItem> get temperables => engine.temperables;
  int temperCost(GearItem g) => engine.temperCost(g);
  String? whyNotTemper(GearItem g) => engine.whyNotTemper(g);

  GearItem? temper(GearItem g) {
    final item = engine.temper(g);
    if (item != null) engine.mark('temper');
    if (item != null) _changed();
    return item;
  }

  // ---- the wilds ----

  bool wildOpen(int a) => engine.wildOpen(a);
  String? whyNotWild(int a) => engine.whyNotWild(a);
  WildEvent? get wildEvent => engine.wildEvent;
  double get leaveShare => engine.leaveShare;
  int? wildHint(int c) => engine.wildHint(c);

  bool enterWild(int a) {
    final ok = engine.enterWild(a);
    if (ok) engine.mark('wilds');
    if (ok) _changed();
    return ok;
  }

  /// One step deeper. A fight is already under way when this returns one: open the battle screen
  /// with BattleStart.wild.
  WildEvent stepWild() {
    final e = engine.stepWild();
    _changed();
    return e;
  }

  String resolveWild(int choice) {
    final out = engine.resolveWild(choice);
    _changed();
    return out;
  }

  WildExit? leaveWild() {
    final exit = engine.leaveWild();
    _changed();
    return exit;
  }

  // ---- dungeons ----

  bool dungeonOpen(Dungeon d) => engine.dungeonOpen(d);
  String? whyNotDungeon(String id) => engine.whyNotDungeon(id);
  Dungeon? get dungeonNow => engine.dungeonNow;
  bool get dungeonCleared => engine.dungeonCleared;
  List<DoorClue> get dungeonDoors => engine.dungeonDoors;
  String? whyNotDoor(int i) => engine.whyNotDoor(i);

  bool enterDungeon(String id) {
    final ok = engine.enterDungeon(id);
    if (ok) engine.mark('delve');
    if (ok) _changed();
    return ok;
  }

  /// Opens a door. A fight is already under way when this returns a fight room: open the battle
  /// screen with BattleStart.dungeon.
  (RoomKind, String)? openDoor(int i) {
    final out = engine.openDoor(i);
    _changed();
    return out;
  }

  bool leaveDungeon() {
    final ok = engine.leaveDungeon();
    _changed();
    return ok;
  }

  int drinkPotion() {
    final healed = engine.drinkPotion();
    if (healed > 0) _changed();
    return healed;
  }

  /// The wild fight the engine just began walks onto the stage (called by the battle screen).
  void arriveWild() {
    if (busy || !state.inBattle) return;
    _arrive();
  }

  /// Plays out the waiting wandering encounter.
  String resolveEncounter(int choice) {
    final out = engine.resolveEncounter(choice);
    // The strongbox was bait: a fight's coming, but it doesn't start (on the stage behind) until
    // the die has landed and you've read what happened: see [springAmbush].
    if (state.inBattle) {
      ambushPending = true;
      _save();
      return out;
    }
    _changed();
    return out;
  }

  /// A strongbox's ambush, waiting for the encounter window to close.
  bool ambushPending = false;

  /// Into the ambush the strongbox sprang.
  void springAmbush() {
    if (!ambushPending) return;
    ambushPending = false;
    if (state.inBattle) _arrive(say: 'Ambush!');
  }

  int get bardFee => engine.bardFee;
  int get migsPrice => engine.migsPrice;

  /// Today's seasonal event (Season.none most of the year).
  Season get season => engine.season;

  /// Announces a seasonal event the first time you're in town for it.
  Season? greetSeason() {
    final s = engine.greetSeason();
    if (s != null) _changed();
    return s;
  }

  /// Chases the bandits who raided the town (call with the battle screen open).
  bool startRaid() {
    if (busy || !engine.startRaid()) return false;
    _arrive();
    return true;
  }

  /// You've been told about the raid (so the town doesn't tell you again).
  /// Marks a one-off notice as seen (a "what's next" window: see journey.dart).
  void seen(String key) {
    engine.mark(key);
    _changed();
  }

  /// The seal screen has seals to show (see GameEngine.sealNews); and it has shown them.
  bool get sealNews => engine.sealNews;
  void sealsSeen() {
    engine.markSealsShown();
    _changed();
  }

  /// A class suit you could finish forging now and haven't been told about (see GameEngine).
  String? get suitToAnnounce => engine.suitToAnnounce;
  List<String> get suitsToFinish => engine.suitsToFinish;

  /// Told about suit [id]: not again.
  void suitAnnounced(String id) {
    engine.mark('suitready:$id');
    _changed();
  }

  void raidSeen() {
    if (state.raid == null || state.raidSeen) return;
    state.raidSeen = true;
    _changed();
  }

  void letRaidGo() {
    engine.letRaidGo();
    _changed();
  }

  /// Faces the current continent's boss (call with the battle screen open).
  bool challengeBoss() {
    if (busy || !engine.challengeBoss()) return false;
    _arrive(boss: true);
    return true;
  }

  void _arrive({bool boss = false, String? say}) {
    outcome = null;
    lastKill = null;
    lastSwing = null;
    busy = true;
    _syncShown();
    _save();
    final f = shownFoeType;
    _emit(
      EnterEvent(
        f,
        say ??
            (boss
            ? f.name
            : f.pack
            ? 'A ${f.name.toLowerCase()} attacks!'
            : f.named
            ? '${f.name} appears!'
            : f.rare
            ? 'A rare foe appears!'
            : null),
      ),
    );
    _openingCharge();
    notifyListeners();
  }

  /// Mounted: ride the foe down as it arrives (the stage plays it after the entrance, and your
  /// turn waits for it).
  bool _charging = false;
  void _openingCharge() {
    final before = state.journal.lastOrNull;
    final r = engine.openingCharge();
    if (r == null) return;
    logHeldAt = before;
    _charging = true;
    lastSwing = r;
    _save();
    _emit(ChargeEvent(r));
  }

  /// Called by the stage once the foe has walked in.
  void foeArrived() {
    if (_charging) return;
    busy = false;
    notifyListeners();
  }

  /// Called by the stage when the opening charge has played.
  void chargeFinished(SwingResult r) {
    _charging = false;
    swingFinished(r);
  }

  /// A fight left open when the app closed: show it as it was, ready for your turn.
  void resumeFight() {
    if (!state.inBattle) return;
    _syncShown();
    // It walks back on (the stage calls foeArrived when it's in place).
    busy = true;
    _emit(EnterEvent(shownFoeType, null));
    _openingCharge();
    notifyListeners();
  }

  // ---- a turn ----

  /// While a turn plays out, the battle log stops at this entry: what happened shows once the
  /// stage has shown it, not before (it used to tell you the foe's blow before it was thrown).
  JournalEntry? logHeldAt;

  String? whyNot(BattleAction a) => engine.whyNot(a);

  /// Takes your turn. [aim] is how well a crossbow bolt was timed (see aimAt).
  void act(BattleAction a, {double aim = 1}) {
    if (busy || !state.inBattle || whyNot(a) != null) return;
    busy = true;
    logHeldAt = state.journal.lastOrNull;
    _heldHeroHp = state.knight.hp;
    final r = engine.takeTurn(a, aim: aim);
    // (A kill holds the bar too: what the win gives back shows when the kill plays, with its label.)
    if (r.counter == null && !r.knockedOut && r.kill == null) _heldHeroHp = null;
    // Knocked out: the bar empties as the blow lands, before the Inn patches you up.
    if (r.knockedOut) _koHp = 0;
    lastSwing = r;
    _save();
    _emit(SwingEvent(r));
    notifyListeners();
  }

  /// Skeletons the stage shows (they rise when the spell lands and crumble after their last blow).
  int shownSummons = 0;
  void showSummons(int n) {
    shownSummons = n;
    notifyListeners();
  }

  /// The hero's HP as the player sees it: the foe's blow only shows once it lands.
  int get shownHeroHp => _koShown ? 0 : (_heldHeroHp ?? state.knight.hp);
  int? _heldHeroHp, _koHp;
  bool _koShown = false;

  /// Ticks when a blow lands and the shown HP changes. Only the HP bars listen to it: a blow
  /// used to rebuild the whole battle screen (log, cards, move tiles) on the very frame it
  /// landed, and on a phone that dropped the impact frame, which read as a hitch in the swing.
  final hpShown = ValueNotifier<int>(0);

  /// You've just become a class (the last piece of its suit put on): its id, for the app to play
  /// the moment; back to null once it's been shown.
  final classAwakened = ValueNotifier<String?>(null);

  /// The class you were last seen as (to notice when it changes).
  String? _lastClass;

  /// Called by the stage when the foe's blow lands (or misses).
  void revealCounter() {
    _heldHeroHp = null;
    if (_koHp != null) _koShown = true;
    hpShown.value++;
  }

  /// Called by the stage when a shapeshifter's shift plays: it shows in its new shape.
  void revealShift() {
    shownForm = state.form;
    notifyListeners();
  }

  /// Called by the stage as a heal plays on your side (life steal as the blade bites, a drink, a
  /// potion): the bar rises then, not later with the foe's blow. ([amount] on top of what's shown;
  /// nothing to do when the bar isn't being held.)
  void revealHeal(int amount) {
    final held = _heldHeroHp;
    if (held == null || amount <= 0) return;
    _heldHeroHp = (held + amount).clamp(0, maxHp(state.knight));
    hpShown.value++;
  }

  /// Called by the stage as you pay HP yourself (Blood Edge's cut, a dice rite's price): the bar
  /// drops then, with the number, not later with the foe's blow (when it looked like the foe did it).
  void revealHurt(int amount) {
    final held = _heldHeroHp;
    if (held == null || amount <= 0) return;
    _heldHeroHp = (held - amount).clamp(1, maxHp(state.knight));
    hpShown.value++;
  }

  /// Called by the stage as the kill plays: the HP the win gives back shows on the bar now.
  void revealHeroHp() {
    _heldHeroHp = null;
    hpShown.value++;
  }

  /// Called by the stage when a blow lands.
  void revealDamage(int amount) {
    shownFoeHp = (shownFoeHp - amount).clamp(0, shownFoeMax);
    hpShown.value++;
  }

  /// Called by the stage when the turn's animation ends.
  void swingFinished(SwingResult r) {
    // A kill keeps the log held until the foe has fallen (killFinished).
    if (r.kill == null) logHeldAt = null;
    if (r.kill == null) _heldHeroHp = null;
    shownSummons = state.summons;
    if (r.kill != null) {
      shownFoeHp = 0;
      _emit(KillEvent(r.kill!));
    } else if (r.fled) {
      busy = false;
      outcome = Outcome.fled;
    } else if (r.knockedOut) {
      busy = false;
      _koHp = null;
      outcome = Outcome.knockedOut;
    } else {
      shownFoeHp = state.foeHp;
      busy = false;
    }
    notifyListeners();
  }

  /// Called by the stage once the defeated foe has fallen.
  void killFinished() {
    busy = false;
    _heldHeroHp = null;
    logHeldAt = null;
    lastKill = lastSwing?.kill;
    outcome = Outcome.won;
    notifyListeners();
  }

  /// The battle screen has shown the result and is closing.
  void leaveBattle() {
    outcome = null;
    _koShown = false;
    _koHp = null;
    _emit(ResetEvent());
    notifyListeners();
    // A hardcore hero who fell: the run is laid to rest, and you're back with your main hero.
    if (state.hardcore && state.fallen) unawaited(_endHardcore());
  }

  // ---- hardcore ----

  /// Hardcore is open (New Game+ beaten), and whether you're on a hardcore road now.
  bool get hardcoreOpen => engine.hardcoreOpen;
  bool get inHardcore => state.hardcore;

  /// Onto a hardcore road: your main hero is saved as they are, and the hardcore hero you have on
  /// the go is picked up (or a new one begins: same name, class chosen afresh, one life).
  Future<void> enterHardcore() async {
    if (busy || state.inBattle || state.hardcore || !hardcoreOpen) return;
    final saved = await _hcStorage.load();
    // (One that fell with the app closed before it could be laid to rest: counted now.)
    if (saved != null && saved.fallen) _recordRun(state, GameEngine.hardcoreSummary(saved));
    final GameState run;
    if (saved != null && saved.hardcore && !saved.fallen) {
      run = saved;
    } else {
      run = GameEngine.newGame()
        ..hardcore = true
        ..settings = state.settings.copy();
      run.settings.tourSeen = true;
    }
    // The main save knows a hardcore hero is on the go, even if the app's closed mid-road.
    state.hcRun = GameEngine.hardcoreSummary(run);
    await _mainStorage.save(state);
    await flushCloud();
    storage = _hcStorage;
    _switchTo(run);
    await storage.save(state);
    if (_hcPrefs) await GameStorage.setActiveSlot('hardcore');
  }

  /// Back to your main hero (the hardcore hero waits in its own save, as you left them).
  Future<void> leaveHardcore() async {
    if (busy || state.inBattle || !state.hardcore) return;
    await _hcStorage.save(state);
    await _backToMain(GameEngine.hardcoreSummary(state), ended: state.won);
  }

  /// The hardcore hero fell (or won and walked away): their save is cleared, the main save keeps
  /// the best run there's been, and you're back with your main hero.
  Future<void> _endHardcore() async {
    final summary = GameEngine.hardcoreSummary(state);
    await _hcStorage.clear();
    await _backToMain(summary, ended: true);
  }

  Future<void> _backToMain(Map<String, dynamic> run, {required bool ended}) async {
    final main = await _mainStorage.load() ?? GameEngine.newGame();
    if (ended || run['won'] == true) _recordRun(main, run);
    main.hcRun = run['fell'] == true ? null : run;
    if (run['fell'] == true) {
      main.journal.add(JournalEntry('Your hardcore hero, ${run['name']}, fell at level ${run['level']}. ${run['lands'] == 0 ? 'Cindervale claims another.' : 'They had beaten ${run['lands']} of the road\'s bosses.'}', EntryKind.damage));
    }
    storage = _mainStorage;
    _switchTo(main);
    await storage.save(state);
    if (_hcPrefs) await GameStorage.setActiveSlot('main');
  }

  /// Keeps [run] as the main save's best hardcore run, if it went further than the last best.
  static void _recordRun(GameState main, Map<String, dynamic> run) {
    int score(Map<String, dynamic>? r) => r == null ? -1 : (r['won'] == true ? 100000 : 0) + ((r['lands'] as num?)?.toInt() ?? 0) * 100 + ((r['level'] as num?)?.toInt() ?? 0);
    if (score(run) > score(main.hcBest)) main.hcBest = run;
  }

  void _switchTo(GameState s) {
    engine = GameEngine(s);
    _emit(ResetEvent());
    busy = false;
    outcome = null;
    _syncShown();
    notifyListeners();
  }

  // ---- the Inn ----

  int rest() {
    final healed = engine.rest();
    _changed();
    return healed;
  }

  String? get whyNotRest => engine.whyNotRest;
  String? get whyNotReading => engine.whyNotReading;
  int get readingPrice => engine.readingCost;
  (Tarot, String)? drawCard() {
    final out = engine.drawCard();
    _changed();
    return out;
  }
  bool get onHobsJob => engine.onHobsJob;
  bool get innReady => engine.innReady;
  bool get jobOffered => engine.jobOffered;
  bool get stashFull => engine.stashFull;
  int get stashCap => engine.stashCap;
  HomeTier? get nextHome => engine.nextHome;
  String? get whyNotBuild => engine.whyNotBuild;

  bool buildHome() {
    final ok = engine.buildHome();
    if (ok) _changed();
    return ok;
  }

  void saveGearSet(int i) {
    engine.saveGearSet(i);
    _changed();
  }

  /// Changes into a whole class suit from the gear chest (see GameEngine.wearSuit).
  int wearSuit(String setId) {
    final n = engine.wearSuit(setId);
    if (n > 0) _changed();
    return n;
  }

  int wearGearSet(int i) {
    final n = engine.wearGearSet(i);
    _changed();
    return n;
  }

  bool keepLoot(String id) {
    final ok = engine.keepLoot(id);
    if (ok) _changed();
    return ok;
  }

  bool equipFromStash(String id) {
    final ok = engine.equipFromStash(id);
    // Something found and kept in the chest counts for "Wear something you found"; the gear you
    // set out with, taken off and put back on, doesn't.
    if (ok && !id.startsWith('starter-')) engine.mark('equip');
    if (ok) _changed();
    return ok;
  }

  void sellFromStash(String id) {
    engine.sellFromStash(id);
    _changed();
  }

  bool takeHobsJob() {
    final ok = engine.takeHobsJob();
    if (ok) _changed();
    return ok;
  }

  bool repairInn() {
    final ok = engine.repairInn();
    if (ok) _changed();
    return ok;
  }

  bool purchase(String id) {
    final ok = engine.purchase(id);
    if (ok && id == 'potion') engine.mark('potion');
    if (ok) _changed();
    return ok;
  }

  // Mags' apothecary.
  String? whyNotBrew(Brew b) => engine.whyNotBrew(b);

  bool brew(Brew b) {
    final ok = engine.brew(b);
    if (ok) engine.mark('brew');
    if (ok) _changed();
    return ok;
  }

  // The forge and the hedge-mage.
  String? whyNotSmelt(Metal m) => engine.whyNotSmelt(m);
  String? whyNotCraft(String id) => engine.whyNotCraft(id);
  String? whyNotFletch(Gem g) => engine.whyNotFletch(g);

  int smelt(Metal m) {
    final n = engine.smelt(m);
    if (n > 0) _changed();
    return n;
  }

  bool craftArmour(String id) {
    final ok = engine.craftArmour(id);
    if (ok) engine.mark('craft');
    if (ok) _changed();
    return ok;
  }

  bool placeShown(Place p) => engine.placeShown(p);
  String? whyNotExplore(String id) => engine.whyNotExplore(id);

  /// Explores a place on the map: a guarded one starts its fight (null comes back); anything else
  /// comes back as what happened.
  /// The next warrior of the Hall of the Slain's wave (a fresh fight the battle screen walks on).
  FoeType? startHallFight() {
    final f = engine.startHallFight();
    if (f != null) {
      outcome = null;
      lastKill = null;
      lastSwing = null;
    }
    _changed();
    return f;
  }

  void abandonHallWave() {
    engine.abandonHallWave();
    _changed();
  }

  /// Out onto the Colosseum's sand for the next bout (a fresh fight the battle screen walks on).
  FoeType? startArenaBout() {
    final f = engine.startArenaBout();
    if (f != null) {
      outcome = null;
      lastKill = null;
      lastSwing = null;
    }
    _changed();
    return f;
  }

  String? explorePlace(String id) {
    final out = engine.explorePlace(id);
    if (state.inBattle) {
      // Its guard: a fresh fight (the battle screen walks it on).
      outcome = null;
      lastKill = null;
      lastSwing = null;
    }
    _changed();
    return out;
  }

  String? whyNotForgePiece(String setId, GearSlot slot) => engine.whyNotForgePiece(setId, slot);
  bool hasSetPiece(String setId, GearSlot slot) => engine.hasSetPiece(setId, slot);
  GearItem? heldSetPiece(String setId, GearSlot slot) => engine.heldSetPiece(setId, slot);
  bool canReforge(String setId, GearSlot slot) => engine.canReforge(setId, slot);

  GearItem? forgePiece(String setId, GearSlot slot) {
    final item = engine.forgePiece(setId, slot);
    if (item != null) engine.mark('piece');
    if (item != null) _changed();
    return item;
  }

  bool fletch(Gem g) {
    final ok = engine.fletch(g);
    if (ok) engine.mark('fletch');
    if (ok) _changed();
    return ok;
  }

  EnchantRoll? enchantOffer(EnchantSlot slot, {bool scroll = false}) {
    final r = engine.enchantOffer(slot, scroll: scroll);
    _changed();
    return r;
  }

  List<EnchantRoll> enchantChoices(EnchantSlot slot, {bool scroll = false}) {
    final r = engine.enchantChoices(slot, scroll: scroll);
    _changed();
    return r;
  }

  String? whyNotBind(Elemental el) => engine.whyNotBind(el);

  EnchantRoll? bindCores(Elemental el) {
    final r = engine.bindCores(el);
    _changed();
    return r;
  }

  String? get whyNotVault => engine.whyNotVault;
  VaultFind? openVault() {
    final out = engine.openVault();
    if (out != null) engine.mark('vault');
    _changed();
    return out;
  }

  GearItem get dailyDeal => engine.dailyDeal;
  int get dealPrice => engine.dealPrice;
  Duration get untilNextDeal => engine.untilNextDeal;
  String? get whyNotDeal => engine.whyNotDeal;
  bool buyDeal() {
    final ok = engine.buyDeal();
    if (ok) engine.mark('deal');
    _changed();
    return ok;
  }

  List<GearItem> get runedSpares => engine.runedSpares;
  int get runeMoveCost => engine.runeMoveCost;
  String? whyNotMoveRune(GearItem from) => engine.whyNotMoveRune(from);
  bool moveRune(GearItem from) {
    final ok = engine.moveRune(from);
    _changed();
    return ok;
  }

  void applyEnchant(EnchantSlot slot, EnchantRoll roll) {
    engine.applyEnchant(slot, roll);
    // Marked as it's done, so taking the enchanted piece off later doesn't undo the task.
    engine.mark(slot == EnchantSlot.weapon ? 'runeWeapon' : 'runeArmour');
    _changed();
  }

  void setCompanion(String id) {
    engine.setCompanion(id);
    _changed();
  }

  void setMount(String? id) {
    engine.setMount(id);
    _changed();
  }

  /// Puts a rite on the hotbar or takes it off. False: the hotbar's full (take one off first).
  bool prepareSpell(String id) {
    final had = state.knight.rites.contains(id), fresh = !had && !state.did.contains('hotbar:$id') && (spellById(id)?.level ?? 0) > 3;
    if (!engine.toggleRite(id)) return false;
    final on = state.knight.rites.contains(id);
    if (on) engine.mark('hotbar:$id');
    // The task: a rite you've learned but never had on the hotbar, swapped on by hand. (The first
    // three, levels 1 to 3, go on by themselves; taking one off and putting it back isn't new.)
    if (fresh && on) engine.mark('rite');
    _changed();
    return true;
  }

  String? whyNotRite(String id) => engine.whyNotRite(id);

  void train(Trait t) {
    if (engine.train(t)) _changed();
  }

  bool resetTraining() {
    final ok = engine.resetTraining();
    if (ok) _changed();
    return ok;
  }

  /// Casts the rite [id] from the hotbar.
  void castRite(String id) {
    if (busy || !state.inBattle || engine.whyNotRite(id) != null) return;
    state.knight
      ..preparedSpell = id
      ..newRites.remove(id);
    act(BattleAction.cast);
  }

  void loadAmmo(String type) {
    engine.loadAmmo(type);
    _changed();
  }

  /// The next kind of bolt (see GameEngine.cycleAmmo).
  void cycleAmmo() {
    engine.cycleAmmo();
    _changed();
  }

  void wearDye(String id) {
    engine.wearDye(id);
    _changed();
  }

  void wearCrest(String id) {
    engine.wearCrest(id);
    _changed();
  }

  void applySettings(Settings s) {
    engine.applySettings(s);
    _changed();
  }

  void markTourSeen() {
    if (state.settings.tourSeen) return;
    state.settings.tourSeen = true;
    _save();
  }

  /// Starts over with a new hero (same name; the class is chosen again).
  Future<void> newAdventure() async {
    if (busy) return;
    final name = state.settings.name, old = state;
    engine = GameEngine(GameEngine.newGame());
    state.settings.name = name;
    // (What you've opened and the best hardcore run stay yours, whoever you start again as.)
    state
      ..hcUnlocked = old.hcUnlocked || engine.hardcoreOpenFor(old)
      ..hcRun = old.hcRun
      ..hcBest = old.hcBest;
    _emit(ResetEvent());
    busy = false;
    outcome = null;
    _syncShown();
    await storage.save(state);
    _schedulePush();
    notifyListeners();
  }

  /// New Game+: why not yet (null: ready), and going round again (see GameEngine.newGamePlus).
  String? get whyNotNewGamePlus => engine.whyNotNewGamePlus();

  List<GearItem> get heirloomChoices => engine.heirloomChoices;

  Future<void> newGamePlus({List<String> heirlooms = const []}) async {
    if (busy || !engine.newGamePlus(heirlooms: heirlooms)) return;
    _emit(ResetEvent());
    outcome = null;
    _syncShown();
    await storage.save(state);
    _schedulePush();
    notifyListeners();
  }

  // ---- tasks ----

  GameTask? get nextTask => engine.nextTask;
  bool taskDone(GameTask t) => engine.taskDone(t);

  String? whyShut(String place) => engine.whyShut(place);

  // Wren's errands.
  String? whyNotErrand(String id) => engine.whyNotErrand(id);
  int get errandLeft => engine.errandLeft;
  bool get errandBack => engine.errandBack;
  int get runners => engine.runners;
  String? errandOf(int r) => engine.errandOf(r);
  int errandLeftOf(int r) => engine.errandLeftOf(r);
  bool errandBackOf(int r) => engine.errandBackOf(r);

  bool sendErrand(String id) {
    final ok = engine.sendErrand(id);
    if (ok) _changed();
    return ok;
  }

  List<String> collectErrand([int r = 0]) {
    final got = engine.collectErrand(r);
    if (got.isNotEmpty) _changed();
    return got;
  }
  int get tasksReady => engine.tasksReady;

  List<String>? claimTask(String id) {
    final got = engine.claimTask(id);
    if (got != null) _changed();
    return got;
  }

  // ---- loot and classes ----

  /// The next drop waiting for "equip or sell", if any.
  GearItem? get nextLoot => state.pendingLoot.firstOrNull;

  int equipLoot(String id) {
    final sold = engine.equipLoot(id);
    // (Not the "wear something" task: that one's for your tent, so you learn the chest and slots.)
    _changed();
    return sold;
  }

  int sellLoot(String id) {
    final got = engine.sellLoot(id);
    _changed();
    return got;
  }

  /// Hero or heroine: cosmetic, free to change any time.
  void setFemale(bool female) {
    if (state.knight.female == female) return;
    state.knight.female = female;
    _changed();
  }

  void setName(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    state.settings.name = n.length > 24 ? n.substring(0, 24) : n;
    _changed();
  }

  void chooseClass(HeroClass c) {
    engine.chooseClass(c);
    _changed();
  }

  bool retrain(HeroClass c) {
    final ok = engine.retrain(c);
    if (ok) _changed();
    return ok;
  }

  bool _disposed = false;

  void _emit(StageEvent e) {
    if (!_disposed) _events.add(e);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pushTimer?.cancel();
    cloud?.removeListener(_cloudChanged);
    _events.close();
    super.dispose();
  }
}
