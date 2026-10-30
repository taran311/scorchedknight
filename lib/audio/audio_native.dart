// The app side of [Audio] (Android and iOS): there's no Web Audio to build sounds on the fly, so
// each sound effect is rendered once (synth.dart: the browser's own recipes, sample by sample)
// into a little WAV file in the app's cache, and played from a small pool of low-latency players.
// Sounds mix with whatever else is playing on the phone (a podcast keeps going). Music: none yet
// (web/music/ has no tracks), so it stays silent here too.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'audio.dart';
import 'synth.dart';

/// Bump when a recipe changes, so phones render the new sounds instead of the cached ones.
const _version = 1;

/// Each sound's players, loaded once and taken in turn. (Not audioplayers' AudioPool: in
/// low-latency mode it never gets a player back, so every later sound built a new player and
/// loaded the file again first, which is what made sounds land late on phones.)
final _pools = <Sfx, _Ring>{};

class _Ring {
  _Ring(this.players);
  final List<AudioPlayer> players;
  int _next = 0;

  void play(double volume) {
    final p = players[_next];
    _next = (_next + 1) % players.length;
    // Fire and forget: the calls reach the phone in order, and nothing here waits on a reply.
    unawaited(_go(p, volume));
  }

  static Future<void> _go(AudioPlayer p, double volume) async {
    try {
      p.stop().ignore();
      p.setVolume(volume).ignore();
      await p.resume();
    } catch (_) {}
  }
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
      final f = File('${dir.path}/${s.name}.wav');
      if (!await f.exists()) await f.writeAsBytes(renderSfx(s), flush: true);
      final players = <AudioPlayer>[];
      for (var i = 0; i < (_busy.contains(s) ? 4 : 2); i++) {
        // No position tracking: by default each player asks the phone where it's up to on every
        // frame while it plays, and these short sounds never report finishing, so a fight piled
        // up dozens of those calls per frame and the whole game stuttered.
        final p = AudioPlayer()..positionUpdater = null;
        // Low latency: a blow's sound lands with the blow.
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setAudioContext(_context);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(DeviceFileSource(f.path));
        players.add(p);
      }
      _pools[s] = _Ring(players);
      // (A breath between sounds, so the first screen never stutters while they're made.)
      await Future<void>.delayed(Duration.zero);
    }
  } catch (_) {
    // Nowhere to write, or no player: stay silent rather than fall over.
  }
}

const _early = {Sfx.click, Sfx.swing, Sfx.hit, Sfx.hurt, Sfx.miss, Sfx.coins};
const _busy = {Sfx.swing, Sfx.hit, Sfx.hurt, Sfx.click, Sfx.coins, Sfx.miss};

void play(Sfx s, double power) {
  if (_muted || _soundVol <= 0) return;
  final pool = _pools[s];
  if (pool == null) return;
  pool.play((_soundVol * .9 * power.clamp(.3, 2.0)).clamp(0.0, 1.0).toDouble());
}

void music(String? track) {}

void configure(double music, double sound, bool muted) {
  _soundVol = sound;
  _muted = muted;
}
