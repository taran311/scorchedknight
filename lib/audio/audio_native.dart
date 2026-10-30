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

final _pools = <Sfx, AudioPool>{};

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
      _pools[s] = await AudioPool.create(
        source: DeviceFileSource(f.path),
        maxPlayers: _busy.contains(s) ? 4 : 2,
        audioContext: _context,
        // Low latency: a blow's sound lands with the blow.
        playerMode: PlayerMode.lowLatency,
      );
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
  unawaited(pool.start(volume: (_soundVol * .9 * power.clamp(.3, 2.0)).clamp(0.0, 1.0)).then((_) {}, onError: (Object _) {}));
}

void music(String? track) {}

void configure(double music, double sound, bool muted) {
  _soundVol = sound;
  _muted = muted;
}
