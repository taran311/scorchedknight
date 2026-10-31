// Sound effects rendered off-line into little WAV files, for the app (no Web Audio there): the
// very same recipes as the browser's (audio_web.dart), worked out sample by sample here. Pure Dart.

import 'dart:math' as math;
import 'dart:typed_data';

import 'audio.dart' show Sfx;

const _rate = 22050;

/// Samples a second in the rendered WAVs.
const sfxRate = _rate;

/// One voice of a sound: a tone or filtered noise, with its envelope and glides.
class _Voice {
  _Voice(this.start, this.osc, this.f0, this.f1, this.vol, this.attack, this.decay, this.filter, this.ff0, this.ff1, this.q);
  final double start, f0, vol, attack, decay, q;
  final double? f1, ff0, ff1;
  final String osc; // sine, square, sawtooth, triangle, or noise
  final String? filter; // lowpass, highpass, bandpass
  double get end => start + attack + decay + .05;
}

/// Gathers the voices of one sound, as the browser recipes lay them out.
class _Score {
  final voices = <_Voice>[];
  void tone(double t, {String type = 'sine', required double f0, double? f1, double vol = .3, double attack = .005, double decay = .2, double? lowpass}) =>
      voices.add(_Voice(t, type, f0, f1, vol, attack, decay, lowpass == null ? null : 'lowpass', lowpass, null, .707));
  void hiss(double t, {String filter = 'bandpass', required double f0, double? f1, double q = 1, double vol = .3, double attack = .005, double decay = .2, double rate = 1}) =>
      voices.add(_Voice(t, 'noise', 0, null, vol, attack, decay, filter, f0, f1, q));
}

/// The sound [s] as a mono 16-bit WAV file.
Uint8List renderSfx(Sfx s, {int seed = 7}) {
  final sc = _Score(), rng = math.Random(seed);
  _recipe(sc, s, rng);
  final len = ((sc.voices.map((v) => v.end).fold(0.0, math.max)) * _rate).ceil();
  final mix = Float64List(len);
  for (final v in sc.voices) {
    _render(v, mix, rng);
  }
  return _wav(mix);
}

void _render(_Voice v, Float64List mix, math.Random rng) {
  final from = (v.start * _rate).round(), n = ((v.attack + v.decay + .05) * _rate).round();
  final span = v.attack + v.decay;
  var phase = 0.0;
  // A biquad filter, its coefficients refreshed every few samples as its frequency sweeps.
  var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0, x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
  void coeffs(double f) {
    final w = 2 * math.pi * f.clamp(20.0, _rate * .45) / _rate, cw = math.cos(w), alpha = math.sin(w) / (2 * v.q);
    final a0 = 1 + alpha;
    switch (v.filter) {
      case 'lowpass':
        b0 = (1 - cw) / 2 / a0;
        b1 = (1 - cw) / a0;
        b2 = b0;
      case 'highpass':
        b0 = (1 + cw) / 2 / a0;
        b1 = -(1 + cw) / a0;
        b2 = b0;
      default: // bandpass, 0 dB at the peak
        b0 = alpha / a0;
        b1 = 0;
        b2 = -alpha / a0;
    }
    a1 = -2 * cw / a0;
    a2 = (1 - alpha) / a0;
  }

  for (var i = 0; i < n && from + i < mix.length; i++) {
    final t = i / _rate;
    final k = (t / span).clamp(0.0, 1.0);
    // The glide (exponential, like the browser's ramps).
    final f = v.f1 == null ? v.f0 : v.f0 * math.pow(math.max(20, v.f1!) / v.f0, k);
    double x;
    if (v.osc == 'noise') {
      x = rng.nextDouble() * 2 - 1;
    } else {
      phase = (phase + f / _rate) % 1;
      x = switch (v.osc) {
        'square' => phase < .5 ? 1.0 : -1.0,
        'sawtooth' => phase * 2 - 1,
        'triangle' => 1 - 4 * (phase - .5).abs(),
        _ => math.sin(phase * 2 * math.pi),
      };
    }
    if (v.filter != null) {
      if (i % 16 == 0) {
        final ff = v.ff1 == null ? v.ff0! : v.ff0! * math.pow(math.max(20, v.ff1!) / v.ff0!, k);
        coeffs(ff);
      }
      final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      x = y;
    }
    // The envelope: up to its peak over the attack, then away to nothing over the decay.
    final peak = math.max(.0002, v.vol);
    final g = t < v.attack ? .0001 * math.pow(peak / .0001, t / v.attack) : (t < span ? peak * math.pow(.0001 / peak, (t - v.attack) / v.decay) : 0.0);
    mix[from + i] += x * g;
  }
}

Uint8List _wav(Float64List mix) {
  final n = mix.length, data = ByteData(44 + n * 2);
  void str(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (mix[i].clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// The browser's recipes (audio_web.dart), voice for voice.
void _recipe(_Score sc, Sfx s, math.Random rng) {
  const t = 0.0, p = 1.0, v = 1.0;
  switch (s) {
    case Sfx.swing:
      sc.hiss(t, f0: 700 * v, f1: 2600 * v, q: 1.4, vol: .22 * p, attack: .06, decay: .16);
    case Sfx.hit:
      sc.hiss(t, filter: 'lowpass', f0: 1800, f1: 300, vol: .5 * p, attack: .002, decay: .14);
      sc.tone(t, f0: 150 * v, f1: 55, vol: .45 * p, decay: .16);
    case Sfx.crit:
      sc.hiss(t, filter: 'lowpass', f0: 2600, f1: 260, vol: .6 * p, attack: .002, decay: .2);
      sc.tone(t, f0: 120 * v, f1: 40, vol: .6 * p, decay: .25);
      sc.tone(t + .01, type: 'triangle', f0: 1200 * v, f1: 900, vol: .12 * p, decay: .3);
    case Sfx.bash:
      sc.tone(t, f0: 95 * v, f1: 38, vol: .7 * p, decay: .3);
      sc.hiss(t, filter: 'lowpass', f0: 900, f1: 120, vol: .5 * p, attack: .003, decay: .22);
    case Sfx.boneHit:
      sc.hiss(t, filter: 'highpass', f0: 1800 * v, q: .7, vol: .35 * p, attack: .001, decay: .07);
      sc.tone(t, type: 'square', f0: 420 * v, f1: 200, vol: .1 * p, decay: .08, lowpass: 2000);
      sc.hiss(t + .05, filter: 'bandpass', f0: 2600, q: 3, vol: .15 * p, attack: .001, decay: .05);
    case Sfx.stoneHit:
      sc.hiss(t, filter: 'bandpass', f0: 900 * v, f1: 400, q: 1.5, vol: .5 * p, attack: .001, decay: .12);
      sc.tone(t, f0: 220 * v, f1: 90, vol: .25 * p, decay: .1);
    case Sfx.miss:
      sc.hiss(t, f0: 500 * v, f1: 1600 * v, q: 1, vol: .14, attack: .05, decay: .12);
    case Sfx.clang:
      for (final (f, a) in const [(880.0, .16), (1318.0, .1), (2093.0, .06)]) {
        sc.tone(t, type: 'triangle', f0: f * v, vol: a * p, decay: .45);
      }
      sc.hiss(t, filter: 'highpass', f0: 3000, vol: .2 * p, attack: .001, decay: .05);
    case Sfx.block:
      sc.tone(t, f0: 160 * v, f1: 70, vol: .5 * p, decay: .18);
      sc.tone(t, type: 'triangle', f0: 620 * v, vol: .08 * p, decay: .25);
      sc.hiss(t, filter: 'lowpass', f0: 1200, f1: 200, vol: .3 * p, attack: .002, decay: .12);
    case Sfx.hurt:
      sc.hiss(t, filter: 'lowpass', f0: 1200, f1: 200, vol: .4 * p, attack: .002, decay: .16);
      sc.tone(t, type: 'sawtooth', f0: 170 * v, f1: 95, vol: .12 * p, attack: .01, decay: .2, lowpass: 900);
    case Sfx.shoot:
      sc.tone(t, type: 'triangle', f0: 340 * v, f1: 180, vol: .3, decay: .18);
      sc.hiss(t, filter: 'highpass', f0: 2400, vol: .2, attack: .001, decay: .04);
      sc.hiss(t + .02, f0: 1400, f1: 3200, q: 2, vol: .1, attack: .02, decay: .14);
    case Sfx.castFire:
      sc.hiss(t, filter: 'lowpass', f0: 300, f1: 2400, vol: .4, attack: .12, decay: .35);
      for (var i = 0; i < 6; i++) {
        sc.hiss(t + .05 + i * .05 * rng.nextDouble() * 2, filter: 'highpass', f0: 2500 + rng.nextDouble() * 2000, vol: .08, attack: .001, decay: .02);
      }
    case Sfx.castFrost:
      for (final (i, f) in const [1568.0, 2093.0, 2637.0, 3136.0].indexed) {
        sc.tone(t + i * .04, f0: f * v, vol: .07, attack: .005, decay: .5);
      }
      sc.hiss(t, filter: 'highpass', f0: 5000, vol: .12, attack: .05, decay: .3);
    case Sfx.castHoly:
      for (final (i, f) in const [523.0, 659.0, 784.0, 1047.0].indexed) {
        sc.tone(t + i * .05, type: 'triangle', f0: f, vol: .1, attack: .02, decay: .6);
      }
    case Sfx.castDark:
      sc.tone(t, type: 'sawtooth', f0: 110 * v, f1: 55, vol: .18, attack: .08, decay: .5, lowpass: 600);
      sc.hiss(t, filter: 'bandpass', f0: 400, f1: 150, q: 4, vol: .2, attack: .1, decay: .4);
    case Sfx.potion:
      for (var i = 0; i < 4; i++) {
        sc.tone(t + i * .09, f0: (240 + rng.nextDouble() * 160) * v, f1: 520, vol: .16, attack: .01, decay: .07);
      }
      sc.tone(t + .4, type: 'triangle', f0: 880, f1: 1320, vol: .08, attack: .02, decay: .3);
    case Sfx.coins:
      for (var i = 0; i < 5; i++) {
        sc.tone(t + i * .045 + rng.nextDouble() * .02, type: 'triangle', f0: 2200 + rng.nextDouble() * 1400, vol: .07, attack: .001, decay: .12);
      }
    case Sfx.levelUp:
      for (final (i, f) in const [523.0, 659.0, 784.0, 1047.0, 1319.0].indexed) {
        sc.tone(t + i * .09, type: 'triangle', f0: f, vol: .14, attack: .01, decay: .4);
        sc.tone(t + i * .09, f0: f * 2, vol: .04, attack: .01, decay: .3);
      }
    case Sfx.victory:
      for (final (i, (f, d)) in const [(392.0, .14), (523.0, .14), (659.0, .14), (784.0, .5)].indexed) {
        sc.tone(t + i * .13, type: 'square', f0: f, vol: .07, attack: .01, decay: d, lowpass: 2400);
        sc.tone(t + i * .13, type: 'triangle', f0: f / 2, vol: .1, attack: .01, decay: d);
      }
    case Sfx.defeat:
      for (final (i, f) in const [392.0, 349.0, 311.0, 262.0].indexed) {
        sc.tone(t + i * .2, type: 'triangle', f0: f, vol: .12, attack: .02, decay: .4);
      }
    case Sfx.flee:
      for (var i = 0; i < 4; i++) {
        sc.hiss(t + i * .1, filter: 'lowpass', f0: 600, f1: 200, vol: .2, attack: .002, decay: .05);
      }
      sc.hiss(t, f0: 600, f1: 2000, vol: .1, attack: .1, decay: .25);
    case Sfx.quest:
      for (final (i, f) in const [784.0, 988.0, 1175.0].indexed) {
        sc.tone(t + i * .08, type: 'triangle', f0: f, vol: .1, attack: .01, decay: .5);
      }
    case Sfx.click:
      sc.tone(t, type: 'triangle', f0: 900, f1: 600, vol: .06, attack: .001, decay: .04);
    case Sfx.rareDrop:
      for (final (i, f) in const [1319.0, 1760.0].indexed) {
        sc.tone(t + i * .07, type: 'triangle', f0: f, vol: .09, attack: .005, decay: .35);
      }
      sc.hiss(t, filter: 'highpass', f0: 6000, vol: .05, attack: .02, decay: .25);
    case Sfx.epicDrop:
      for (final (i, f) in const [659.0, 880.0, 1109.0, 1319.0].indexed) {
        sc.tone(t + i * .07, type: 'triangle', f0: f, vol: .1, attack: .008, decay: .55);
        sc.tone(t + i * .07, f0: f * 2, vol: .03, attack: .01, decay: .4);
      }
      sc.hiss(t + .1, filter: 'highpass', f0: 5000, vol: .07, attack: .1, decay: .5);
    case Sfx.legendaryDrop:
      // A deep bell, then a rising shimmer and a held chord.
      sc.tone(t, f0: 196, vol: .25, attack: .005, decay: 1.6);
      sc.tone(t, type: 'triangle', f0: 392, vol: .1, attack: .005, decay: 1.2);
      for (final (i, f) in const [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0].indexed) {
        sc.tone(t + .15 + i * .06, type: 'triangle', f0: f, vol: .08, attack: .01, decay: .9);
      }
      for (final f in const [523.0, 659.0, 784.0]) {
        sc.tone(t + .55, type: 'sawtooth', f0: f, vol: .025, attack: .3, decay: 1.4, lowpass: 1800);
      }
      sc.hiss(t + .15, filter: 'highpass', f0: 4500, vol: .1, attack: .2, decay: 1.0);
  }
}
