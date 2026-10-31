// The app side of [Audio] (Android and iOS): there's no Web Audio to build sounds on the fly, so
// each sound effect is rendered once (synth.dart: the browser's own recipes, sample by sample)
// into a little WAV file in the app's cache, and played from a small pool of low-latency players.
// Sounds mix with whatever else is playing on the phone (a podcast keeps going). Music: none yet
// (web/music/ has no tracks), so it stays silent here too.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'audio.dart';
import 'synth.dart';

/// Bump when a recipe changes, so phones render the new sounds instead of the cached ones.
const _version = 2;

/// Each sound's players, loaded once and taken in turn. (Not audioplayers' AudioPool: in
/// low-latency mode it never gets a player back, so every later sound built a new player and
/// loaded the file again first, which is what made sounds land late on phones.)
final _pools = <Sfx, _Ring>{};

class _Ring {
  _Ring(this.sfx, this.players, this.length);
  final Sfx sfx;
  final List<AudioPlayer> players;

  /// How long the sound runs.
  final Duration length;
  int _next = 0;
  final _turn = <AudioPlayer, int>{};

  void play(double volume) {
    final p = players[_next];
    _next = (_next + 1) % players.length;
    unawaited(_go(p, volume));
  }

  // audioplayers skips a play on a player it thinks is still playing, and skips a stop that a
  // play has already overtaken. These sounds never report finishing, so without care every
  // player made its sound once and then never again. So: each player is stopped once its sound
  // has run (free for next time), and one still sounding is stopped first, waited for.
  Future<void> _go(AudioPlayer p, double volume) async {
    final turn = (_turn[p] ?? 0) + 1;
    _turn[p] = turn;
    try {
      if (p.state == PlayerState.playing) await p.stop();
      p.setVolume(volume).then((_) {}, onError: (Object e) => _fail(sfx, 'vol', e));
      await p.resume();
      Timer(length + const Duration(milliseconds: 60), () {
        if (_turn[p] == turn && p.state == PlayerState.playing) p.stop().then((_) {}, onError: (Object e) => _fail(sfx, 'stop', e));
      });
    } catch (e) {
      _fail(sfx, 'play', e);
    }
  }
}

// What Settings shows: sounds loaded, plays asked for, and the last thing that went wrong.
int _plays = 0, _missing = 0;
final _hitPlays = <Sfx, int>{};
String? _lastError, _loadError;
void _fail(Sfx s, String what, Object e) {
  final msg = '$e';
  _lastError = '${s.name} $what: ${msg.length > 140 ? msg.substring(0, 140) : msg}';
}

String? report() {
  final want = Sfx.values.length;
  final hits = [for (final s in const [Sfx.swing, Sfx.hit, Sfx.crit, Sfx.boneHit]) '${s.name} ${_pools[s]?.players.length ?? 0}p/${_hitPlays[s] ?? 0}x'].join(', ');
  return [
    'Sounds ${_pools.length}/$want loaded${_started ? '' : ' (not started)'}, $_plays played, $_missing not ready',
    hits,
    if (_loadError != null) 'Load: $_loadError',
    if (_lastError != null) 'Play: $_lastError',
  ].join('\n');
}

/// A game's sound effects: don't pause the player's music or podcast, just mix in.
final _context = AudioContext(
  android: const AudioContextAndroid(contentType: AndroidContentType.sonification, usageType: AndroidUsageType.game, audioFocus: AndroidAudioFocus.none),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);
bool _started = false;
double _soundVol = .8;
bool _muted = false;

void unlock() {
  if (_started) return;
  _started = true;
  unawaited(_load());
}

Future<void> _load() async {
  try {
    await AudioPlayer.global.setAudioContext(_context);
  } catch (_) {}
  try {
    final dir = Directory('${(await getTemporaryDirectory()).path}/sfx$_version');
    await dir.create(recursive: true);
    // The everyday sounds first, so a fight has its blows straight away.
    for (final s in [...Sfx.values.where(_early.contains), ...Sfx.values.where((s) => !_early.contains(s))]) {
      final players = <AudioPlayer>[];
      Uint8List? wav;
      for (var i = 0; i < (_busy.contains(s) ? 4 : 2); i++) {
        // Each player its own copy of the file: players sharing one file share a single loaded
        // sound on Android, and some of them were left without it (a blow with no sound).
        final f = File('${dir.path}/${s.name}_$i.wav');
        if (!await f.exists()) await f.writeAsBytes(wav ??= renderSfx(s), flush: true);
        // No position tracking: by default each player asks the phone where it's up to on every
        // frame while it plays, and these short sounds never report finishing, so a fight piled
        // up dozens of those calls per frame and the whole game stuttered.
        try {
          final p = AudioPlayer()..positionUpdater = null;
          // Low latency: a blow's sound lands with the blow.
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setAudioContext(_context);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(DeviceFileSource(f.path));
          players.add(p);
        } catch (e) {
          // One player that won't load shouldn't silence the rest.
          _loadError = '${s.name}#$i: ${'$e'.length > 140 ? '$e'.substring(0, 140) : e}';
        }
      }
      if (players.isNotEmpty) _pools[s] = _Ring(s, players, Duration(milliseconds: (await File('${dir.path}/${s.name}_0.wav').length() - 44) * 1000 ~/ (2 * sfxRate)));
      // (A breath between sounds, so the first screen never stutters while they're made.)
      await Future<void>.delayed(Duration.zero);
    }
  } catch (e) {
    // Nowhere to write, or no player: stay silent rather than fall over.
    _loadError = '$e';
  }
}

const _early = {Sfx.click, Sfx.swing, Sfx.hit, Sfx.hurt, Sfx.miss, Sfx.crit, Sfx.bash, Sfx.boneHit, Sfx.stoneHit, Sfx.coins};
const _busy = {Sfx.swing, Sfx.hit, Sfx.hurt, Sfx.click, Sfx.coins, Sfx.miss, Sfx.crit, Sfx.bash, Sfx.boneHit, Sfx.stoneHit, Sfx.block, Sfx.clang};

void play(Sfx s, double power) {
  if (_muted || _soundVol <= 0) return;
  _plays++;
  _hitPlays[s] = (_hitPlays[s] ?? 0) + 1;
  final pool = _pools[s];
  if (pool == null) {
    _missing++;
    return;
  }
  pool.play((_soundVol * .9 * power.clamp(.3, 2.0)).clamp(0.0, 1.0).toDouble());
}

void music(String? track) {}

void configure(double music, double sound, bool muted) {
  _soundVol = sound;
  _muted = muted;
}
