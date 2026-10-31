// The browser side of [Audio]: every sound effect is built on the fly from oscillators and
// filtered noise with the Web Audio API (so there are no sound files to ship), and music plays
// from web/music/<track>.mp3 with a slow crossfade between tracks. A missing music file is
// simply silence.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'audio.dart';

// ---------------------------------------------------------------- Web Audio bindings

@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external _Ctx();
  external double get currentTime;
  external double get sampleRate;
  external String get state;
  external _Node get destination;
  external JSPromise<JSAny?> resume();
  external _Gain createGain();
  external _Osc createOscillator();
  external _Filter createBiquadFilter();
  external _Source createBufferSource();
  external _Buffer createBuffer(int channels, int length, double sampleRate);
}

extension type _Node._(JSObject _) implements JSObject {
  external _Node connect(_Node to);
}

extension type _Param._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double v, double t);
  external void linearRampToValueAtTime(double v, double t);
  external void exponentialRampToValueAtTime(double v, double t);
}

extension type _Gain._(JSObject _) implements _Node {
  external _Param get gain;
}

extension type _Osc._(JSObject _) implements _Node {
  external set type(String t);
  external _Param get frequency;
  external void start(double when);
  external void stop(double when);
}

extension type _Filter._(JSObject _) implements _Node {
  external set type(String t);
  external _Param get frequency;
  // ignore: non_constant_identifier_names
  external _Param get Q;
}

extension type _Source._(JSObject _) implements _Node {
  external set buffer(_Buffer b);
  external _Param get playbackRate;
  external void start(double when, double offset, double duration);
}

extension type _Buffer._(JSObject _) implements JSObject {
  external void copyToChannel(JSFloat32Array source, int channel);
}

@JS('Audio')
extension type _Track._(JSObject _) implements JSObject {
  external _Track(String src);
  external set volume(double v);
  external set loop(bool l);
  external JSPromise<JSAny?> play();
  external void pause();
}

// ---------------------------------------------------------------- state

_Ctx? _ctx;
_Gain? _sfxBus;
_Buffer? _noise;
double _musicVol = .5, _soundVol = .8;
bool _muted = false;
final _rng = math.Random();

void unlock() {
  try {
    _ctx ??= _Ctx();
    final c = _ctx!;
    if (_sfxBus == null) {
      _sfxBus = c.createGain()..connect(c.destination);
      // A second of white noise, the raw stuff of whooshes, thumps and crackles.
      final n = c.sampleRate.round();
      final data = Float32List(n);
      for (var i = 0; i < n; i++) {
        data[i] = _rng.nextDouble() * 2 - 1;
      }
      _noise = c.createBuffer(1, n, c.sampleRate)..copyToChannel(data.toJS, 0);
      _applyVolumes();
    }
    if (c.state == 'suspended') c.resume();
    // Music asked for before the first click starts now.
    if (_wanted != null && _playing == null) music(_wanted);
  } catch (_) {
    // No Web Audio here: stay silent.
  }
}

void configure(double music, double sound, bool muted) {
  _musicVol = music;
  _soundVol = sound;
  _muted = muted;
  _applyVolumes();
}

void _applyVolumes() {
  final bus = _sfxBus;
  if (bus != null) bus.gain.value = _muted ? 0 : _soundVol * .9;
  final p = _playing;
  if (p != null) p.track.volume = _muted ? 0 : _musicVol * p.level;
}

// ---------------------------------------------------------------- building blocks

/// A gain envelope starting at [t]: up to [peak] over [attack] seconds, then down to nothing
/// over [decay].
_Gain _env(_Ctx c, double t, double peak, double attack, double decay) {
  final g = c.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(math.max(.0002, peak), t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + attack + decay);
  g.connect(_sfxBus!);
  return g;
}

/// A pitched tone of [type] gliding from [f0] to [f1] Hz.
void _tone(_Ctx c, double t, {String type = 'sine', required double f0, double? f1, double vol = .3, double attack = .005, double decay = .2, double? lowpass}) {
  final o = c.createOscillator()..type = type;
  o.frequency.setValueAtTime(f0, t);
  if (f1 != null) o.frequency.exponentialRampToValueAtTime(math.max(20, f1), t + attack + decay);
  final out = _env(c, t, vol, attack, decay);
  if (lowpass != null) {
    final f = c.createBiquadFilter()..type = 'lowpass';
    f.frequency.value = lowpass;
    o.connect(f).connect(out);
  } else {
    o.connect(out);
  }
  o.start(t);
  o.stop(t + attack + decay + .05);
}

/// Filtered noise, its filter sweeping from [f0] to [f1] Hz.
void _hiss(_Ctx c, double t, {String filter = 'bandpass', required double f0, double? f1, double q = 1, double vol = .3, double attack = .005, double decay = .2, double rate = 1}) {
  final src = c.createBufferSource()..buffer = _noise!;
  src.playbackRate.value = rate;
  final f = c.createBiquadFilter()..type = filter;
  f.frequency.setValueAtTime(f0, t);
  if (f1 != null) f.frequency.exponentialRampToValueAtTime(math.max(20, f1), t + attack + decay);
  f.Q.value = q;
  src.connect(f).connect(_env(c, t, vol, attack, decay));
  src.start(t, _rng.nextDouble() * .5, attack + decay + .05);
}

// ---------------------------------------------------------------- the sounds

void play(Sfx s, double power) {
  final c = _ctx, bus = _sfxBus;
  if (c == null || bus == null || _muted || _soundVol <= 0) return;
  final t = c.currentTime + .005, p = power.clamp(.3, 2.0);
  // A touch of random pitch so repeated blows don't sound copied.
  final v = .94 + _rng.nextDouble() * .12;
  switch (s) {
    case Sfx.swing:
      _hiss(c, t, f0: 700 * v, f1: 2600 * v, q: 1.4, vol: .22 * p, attack: .06, decay: .16);
    case Sfx.hit:
      _hiss(c, t, filter: 'lowpass', f0: 1800, f1: 300, vol: .5 * p, attack: .002, decay: .14);
      _tone(c, t, f0: 150 * v, f1: 55, vol: .45 * p, decay: .16);
    case Sfx.crit:
      _hiss(c, t, filter: 'lowpass', f0: 2600, f1: 260, vol: .6 * p, attack: .002, decay: .2);
      _tone(c, t, f0: 120 * v, f1: 40, vol: .6 * p, decay: .25);
      _tone(c, t + .01, type: 'triangle', f0: 1200 * v, f1: 900, vol: .12 * p, decay: .3);
    case Sfx.bash:
      _tone(c, t, f0: 95 * v, f1: 38, vol: .7 * p, decay: .3);
      _hiss(c, t, filter: 'lowpass', f0: 900, f1: 120, vol: .5 * p, attack: .003, decay: .22);
    case Sfx.boneHit:
      _hiss(c, t, filter: 'highpass', f0: 1800 * v, q: .7, vol: .35 * p, attack: .001, decay: .07);
      _tone(c, t, type: 'square', f0: 420 * v, f1: 200, vol: .1 * p, decay: .08, lowpass: 2000);
      _hiss(c, t + .05, filter: 'bandpass', f0: 2600, q: 3, vol: .15 * p, attack: .001, decay: .05);
    case Sfx.stoneHit:
      _hiss(c, t, filter: 'bandpass', f0: 900 * v, f1: 400, q: 1.5, vol: .5 * p, attack: .001, decay: .12);
      _tone(c, t, f0: 220 * v, f1: 90, vol: .25 * p, decay: .1);
    case Sfx.miss:
      _hiss(c, t, f0: 500 * v, f1: 1600 * v, q: 1, vol: .14, attack: .05, decay: .12);
    case Sfx.clang:
      for (final (f, a) in const [(880.0, .16), (1318.0, .1), (2093.0, .06)]) {
        _tone(c, t, type: 'triangle', f0: f * v, vol: a * p, decay: .45);
      }
      _hiss(c, t, filter: 'highpass', f0: 3000, vol: .2 * p, attack: .001, decay: .05);
    case Sfx.block:
      _tone(c, t, f0: 160 * v, f1: 70, vol: .5 * p, decay: .18);
      _tone(c, t, type: 'triangle', f0: 620 * v, vol: .08 * p, decay: .25);
      _hiss(c, t, filter: 'lowpass', f0: 1200, f1: 200, vol: .3 * p, attack: .002, decay: .12);
    case Sfx.hurt:
      _hiss(c, t, filter: 'lowpass', f0: 1200, f1: 200, vol: .4 * p, attack: .002, decay: .16);
      _tone(c, t, type: 'sawtooth', f0: 170 * v, f1: 95, vol: .12 * p, attack: .01, decay: .2, lowpass: 900);
    case Sfx.shoot:
      _tone(c, t, type: 'triangle', f0: 340 * v, f1: 180, vol: .3, decay: .18);
      _hiss(c, t, filter: 'highpass', f0: 2400, vol: .2, attack: .001, decay: .04);
      _hiss(c, t + .02, f0: 1400, f1: 3200, q: 2, vol: .1, attack: .02, decay: .14);
    case Sfx.castFire:
      _hiss(c, t, filter: 'lowpass', f0: 300, f1: 2400, vol: .4, attack: .12, decay: .35);
      for (var i = 0; i < 6; i++) {
        _hiss(c, t + .05 + i * .05 * _rng.nextDouble() * 2, filter: 'highpass', f0: 2500 + _rng.nextDouble() * 2000, vol: .08, attack: .001, decay: .02);
      }
    case Sfx.castFrost:
      for (final (i, f) in const [1568.0, 2093.0, 2637.0, 3136.0].indexed) {
        _tone(c, t + i * .04, f0: f * v, vol: .07, attack: .005, decay: .5);
      }
      _hiss(c, t, filter: 'highpass', f0: 5000, vol: .12, attack: .05, decay: .3);
    case Sfx.castHoly:
      for (final (i, f) in const [523.0, 659.0, 784.0, 1047.0].indexed) {
        _tone(c, t + i * .05, type: 'triangle', f0: f, vol: .1, attack: .02, decay: .6);
      }
    case Sfx.castDark:
      _tone(c, t, type: 'sawtooth', f0: 110 * v, f1: 55, vol: .18, attack: .08, decay: .5, lowpass: 600);
      _hiss(c, t, filter: 'bandpass', f0: 400, f1: 150, q: 4, vol: .2, attack: .1, decay: .4);
    case Sfx.potion:
      for (var i = 0; i < 4; i++) {
        _tone(c, t + i * .09, f0: (240 + _rng.nextDouble() * 160) * v, f1: 520, vol: .16, attack: .01, decay: .07);
      }
      _tone(c, t + .4, type: 'triangle', f0: 880, f1: 1320, vol: .08, attack: .02, decay: .3);
    case Sfx.coins:
      for (var i = 0; i < 5; i++) {
        _tone(c, t + i * .045 + _rng.nextDouble() * .02, type: 'triangle', f0: 2200 + _rng.nextDouble() * 1400, vol: .07, attack: .001, decay: .12);
      }
    case Sfx.levelUp:
      for (final (i, f) in const [523.0, 659.0, 784.0, 1047.0, 1319.0].indexed) {
        _tone(c, t + i * .09, type: 'triangle', f0: f, vol: .14, attack: .01, decay: .4);
        _tone(c, t + i * .09, f0: f * 2, vol: .04, attack: .01, decay: .3);
      }
    case Sfx.victory:
      for (final (i, (f, d)) in const [(392.0, .14), (523.0, .14), (659.0, .14), (784.0, .5)].indexed) {
        _tone(c, t + i * .13, type: 'square', f0: f, vol: .07, attack: .01, decay: d, lowpass: 2400);
        _tone(c, t + i * .13, type: 'triangle', f0: f / 2, vol: .1, attack: .01, decay: d);
      }
    case Sfx.defeat:
      for (final (i, f) in const [392.0, 349.0, 311.0, 262.0].indexed) {
        _tone(c, t + i * .2, type: 'triangle', f0: f, vol: .12, attack: .02, decay: .4);
      }
    case Sfx.flee:
      for (var i = 0; i < 4; i++) {
        _hiss(c, t + i * .1, filter: 'lowpass', f0: 600, f1: 200, vol: .2, attack: .002, decay: .05);
      }
      _hiss(c, t, f0: 600, f1: 2000, vol: .1, attack: .1, decay: .25);
    case Sfx.quest:
      for (final (i, f) in const [784.0, 988.0, 1175.0].indexed) {
        _tone(c, t + i * .08, type: 'triangle', f0: f, vol: .1, attack: .01, decay: .5);
      }
    case Sfx.click:
      _tone(c, t, type: 'triangle', f0: 900, f1: 600, vol: .06, attack: .001, decay: .04);
    case Sfx.rareDrop:
      for (final (i, f) in const [1319.0, 1760.0].indexed) {
        _tone(c, t + i * .07, type: 'triangle', f0: f, vol: .09, attack: .005, decay: .35);
      }
      _hiss(c, t, filter: 'highpass', f0: 6000, vol: .05, attack: .02, decay: .25);
    case Sfx.epicDrop:
      for (final (i, f) in const [659.0, 880.0, 1109.0, 1319.0].indexed) {
        _tone(c, t + i * .07, type: 'triangle', f0: f, vol: .1, attack: .008, decay: .55);
        _tone(c, t + i * .07, f0: f * 2, vol: .03, attack: .01, decay: .4);
      }
      _hiss(c, t + .1, filter: 'highpass', f0: 5000, vol: .07, attack: .1, decay: .5);
    case Sfx.legendaryDrop:
      // A deep bell, then a rising shimmer and a held chord.
      _tone(c, t, f0: 196, vol: .25, attack: .005, decay: 1.6);
      _tone(c, t, type: 'triangle', f0: 392, vol: .1, attack: .005, decay: 1.2);
      for (final (i, f) in const [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0].indexed) {
        _tone(c, t + .15 + i * .06, type: 'triangle', f0: f, vol: .08, attack: .01, decay: .9);
      }
      for (final f in const [523.0, 659.0, 784.0]) {
        _tone(c, t + .55, type: 'sawtooth', f0: f, vol: .025, attack: .3, decay: 1.4, lowpass: 1800);
      }
      _hiss(c, t + .15, filter: 'highpass', f0: 4500, vol: .1, attack: .2, decay: 1.0);
  }
}

// ---------------------------------------------------------------- music

class _Playing {
  _Playing(this.name, this.track);
  final String name;
  final _Track track;

  /// Where its fade has got to, 0 to 1.
  double level = 0;
}

_Playing? _playing;
final _fading = <_Playing>[];
String? _wanted;
Timer? _fader;

void music(String? name) {
  _wanted = name;
  if (_ctx == null) return; // before the first click: starts on unlock
  if (_playing?.name == name) return;
  final old = _playing;
  if (old != null) _fading.add(old);
  _playing = null;
  if (name != null) {
    try {
      final tr = _Track('music/$name.mp3')
        ..loop = true
        ..volume = 0;
      final p = _Playing(name, tr);
      _playing = p;
      // A missing file just never plays.
      tr.play().toDart.then((_) {}, onError: (Object _) {
        if (identical(_playing, p)) _playing = null;
      });
    } catch (_) {
      _playing = null;
    }
  }
  _fader ??= Timer.periodic(const Duration(milliseconds: 50), (_) => _fade());
}

/// One step of the crossfade: the new track up, the old ones down (about 1.5 seconds).
void _fade() {
  const step = .035;
  final p = _playing;
  if (p != null && p.level < 1) p.level = math.min(1, p.level + step);
  for (final f in List.of(_fading)) {
    f.level = math.max(0, f.level - step);
    f.track.volume = _muted ? 0 : _musicVol * f.level;
    if (f.level <= 0) {
      f.track.pause();
      _fading.remove(f);
    }
  }
  if (p != null) p.track.volume = _muted ? 0 : _musicVol * p.level;
  if ((p == null || p.level >= 1) && _fading.isEmpty) {
    _fader?.cancel();
    _fader = null;
  }
}

/// A line on how sound is doing (the app only).
String? report() => null;
