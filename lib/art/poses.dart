// Stances, idle breathing, walking, and keyframed clips (swing, hit, flinch).

import 'dart:math' as math;

import 'looks.dart';
import 'rig.dart';

final Map<Stance, Pose> stances = {
  Stance.knight: Pose.of({J.lean: 4, J.nS: 32, J.nE: 72, J.nW: 62, J.fS: 18, J.fE: 62, J.fW: 90, J.nH: 14, J.nK: 10, J.fH: -12, J.fK: 8}),
  Stance.mage: Pose.of({J.lean: 2, J.head: -2, J.nS: 26, J.nE: 64, J.nW: 86, J.fS: 40, J.fE: 70, J.nH: 16, J.nK: 10, J.fH: -14, J.fK: 8}),
  Stance.ranger: Pose.of({J.lean: 8, J.head: -6, J.nS: 40, J.nE: 26, J.nW: 0, J.fS: 54, J.fE: -2, J.nH: 22, J.nK: 16, J.fH: -20, J.fK: 12}),
  Stance.goblin: Pose.of({J.lean: 20, J.head: -14, J.nS: 40, J.nE: 52, J.nW: 46, J.fS: 8, J.fE: 40, J.fW: 90, J.nH: 20, J.nK: 28, J.fH: -14, J.fK: 24}),
  Stance.rogue: Pose.of({J.lean: 12, J.head: -6, J.nS: 46, J.nE: 62, J.nW: 15, J.fS: 22, J.fE: 78, J.fW: 5, J.nH: 22, J.nK: 20, J.fH: -18, J.fK: 16}),
  Stance.zombie: Pose.of({J.lean: 16, J.head: 14, J.nS: 80, J.nE: 8, J.fS: 72, J.fE: 14, J.nH: 6, J.nK: 6, J.fH: -8, J.fK: 8}),
  Stance.pillager: Pose.of({J.lean: 6, J.head: -4, J.nS: 8, J.nE: 104, J.nW: 100, J.fS: 34, J.fE: 46, J.fW: 90, J.nH: 16, J.nK: 12, J.fH: -14, J.fK: 8}),
  Stance.ent: Pose.of({J.lean: 3, J.head: 4, J.nS: 34, J.nE: 34, J.nW: 20, J.fS: 22, J.fE: 30, J.nH: 9, J.nK: 5, J.fH: -9, J.fK: 5}),
  Stance.rose: Pose.of({J.lean: 4, J.head: -2, J.nS: 30, J.nE: 58, J.nW: 108, J.fS: 36, J.fE: 52, J.fW: 108, J.nH: 16, J.nK: 10, J.fH: -14, J.fK: 8}),
};

/// Breathing and fidgeting on top of a stance. [t] is milliseconds.
Pose idlePose(Stance s, double t, {double phase = 0, bool still = false}) {
  final p = stances[s]!.copy();
  if (still) return p;
  final b = math.sin(t / 640 + phase);
  p[J.lean] += b * 1.2;
  p[J.nS] += math.sin(t / 640 + phase + .6) * 2.2;
  p[J.fS] += math.sin(t / 700 + phase + 1.1) * 1.8;
  p[J.head] -= b;
  p[J.nK] += b * 1.5;
  p[J.fK] += b * 1.5;
  if (s == Stance.zombie) {
    p[J.lean] += math.sin(t / 900 + phase) * 4;
    p[J.head] += math.sin(t / 700 + phase) * 6;
    p[J.nS] += math.sin(t / 820) * 6;
    p[J.fS] += math.sin(t / 760 + 1) * 6;
  }
  if (s == Stance.ent) {
    // Slow, creaking sway, like branches in the wind.
    p[J.lean] += math.sin(t / 1300 + phase) * 2.5;
    p[J.nS] += math.sin(t / 1100 + phase) * 5;
    p[J.fS] += math.sin(t / 1200 + phase + 1) * 5;
    p[J.nE] += math.sin(t / 900 + phase) * 4;
  }
  if (s == Stance.goblin) p[J.dy] = -(math.sin(t / 420 + phase).abs()) * 3;
  return p;
}

/// A stride blended in by [amount] (0..1).
Pose walkPose(Stance s, double t, double amount, {bool still = false}) {
  final p = idlePose(s, t, still: still), ph = t / 160, a = amount;
  p[J.nH] = p[J.nH] * (1 - a) + math.sin(ph) * 26 * a;
  p[J.fH] = p[J.fH] * (1 - a) - math.sin(ph) * 26 * a;
  p[J.nK] = p[J.nK] * (1 - a) + math.max(0, math.cos(ph)) * 34 * a;
  p[J.fK] = p[J.fK] * (1 - a) + math.max(0, -math.cos(ph)) * 34 * a;
  if (s == Stance.knight || s == Stance.mage) p[J.fS] += -math.sin(ph) * 14 * a;
  p[J.dy] -= math.cos(ph).abs() * 3 * a;
  return p;
}

typedef Ease = double Function(double);
double easeInOut(double p) => p < .5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;
double easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();
/// Accelerates into the end, hard, but starts already moving: a cubic used to sit still for the
/// first half and then snap, which read as a stutter in the middle of a swing.
double easeIn(double p) => p * (.3 + .7 * p);

class Keyframe {
  const Keyframe(this.ms, this.overrides, [this.ease = easeInOut]);
  final double ms;
  final Map<J, double> overrides;
  final Ease ease;
}

/// Samples a clip at [ms] on top of [base]. Returns null once the clip has finished.
///
/// The limbs flow through the keyframes on a smooth curve (a monotone cubic, so nothing
/// overshoots) instead of easing to a stop at each one; they only come to rest at the start, the
/// end, and wherever a joint turns back. A keyframe marked [easeIn] is a blow: the limb
/// accelerates into it and lands hard.
Pose? sampleClip(Pose base, List<Keyframe> keys, double ms) {
  if (ms <= 0) return base;
  if (ms > keys.last.ms) return null;
  final times = [0.0, for (final k in keys) k.ms];
  final poses = [base, for (final k in keys) base.withOverrides(k.overrides)];
  var i = 1;
  while (ms > times[i]) {
    i++;
  }
  final a = poses[i - 1], b = poses[i], t0 = times[i - 1], h = times[i] - t0;
  final u = h <= 0 ? 1.0 : (ms - t0) / h;
  if (identical(keys[i - 1].ease, easeIn)) return Pose.lerp(a, b, easeIn(u));
  double slope(int from, int to, int j) => (poses[to].v[j] - poses[from].v[j]) / math.max(1, times[to] - times[from]);
  // The joint's speed through a keyframe: zero at the ends and at turns, else a blend of the two sides.
  double tangent(int at, int j) {
    if (at == 0 || at == poses.length - 1) return 0;
    if (identical(keys[at - 1].ease, easeIn)) return 0; // a blow lands and stops
    final l = slope(at - 1, at, j), r = slope(at, at + 1, j);
    if (l * r <= 0) return 0;
    return 2 * l * r / (l + r);
  }

  final u2 = u * u, u3 = u2 * u;
  final h00 = 2 * u3 - 3 * u2 + 1, h10 = u3 - 2 * u2 + u, h01 = -2 * u3 + 3 * u2, h11 = u3 - u2;
  return Pose(List.generate(a.v.length, (j) => h00 * a.v[j] + h10 * tangent(i - 1, j) * h + h01 * b.v[j] + h11 * tangent(i, j) * h));
}

/// Wind-up, lunge with a step, slash, recover. The blade connects at [swingHitMs], the same pace
/// a foe's blow lands at.
const swingClip = <Keyframe>[
  Keyframe(120, {J.nS: -40, J.nE: 120, J.nW: 70, J.lean: -6, J.nH: 4, J.nK: 14, J.fH: -8, J.fK: 10, J.dx: -6}, easeOut),
  Keyframe(260, {J.nS: 96, J.nE: 12, J.nW: 58, J.lean: 16, J.nH: 40, J.nK: 22, J.fH: -26, J.fK: 6, J.dx: 190, J.head: 6}, easeIn),
  Keyframe(340, {J.nS: 92, J.nE: 10, J.nW: 56, J.lean: 14, J.nH: 40, J.nK: 24, J.fH: -26, J.fK: 6, J.dx: 190}),
  Keyframe(680, {}),
];

/// How long any blow takes to land, yours or a foe's, so the two sides fight at the same pace.
const strikeMs = 260.0;
const swingHitMs = strikeMs;

/// The stunning blow: the weapon goes up over your head and comes crashing straight down, the
/// knees bending into it. Lands at [swingHitMs], like the plain swing.
const crushClip = <Keyframe>[
  Keyframe(130, {J.nS: 172, J.nE: 40, J.nW: 10, J.fS: 70, J.fE: 60, J.lean: -10, J.head: -6, J.nH: 6, J.nK: 10, J.fH: -6, J.fK: 8, J.dx: 20}, easeOut),
  Keyframe(260, {J.nS: 62, J.nE: 0, J.nW: 40, J.fS: 40, J.fE: 30, J.lean: 26, J.head: 10, J.nH: 46, J.nK: 40, J.fH: -30, J.fK: 26, J.dx: 180}, easeIn),
  Keyframe(360, {J.nS: 58, J.nE: 0, J.nW: 42, J.fS: 40, J.fE: 30, J.lean: 24, J.head: 8, J.nH: 46, J.nK: 42, J.fH: -30, J.fK: 28, J.dx: 180}),
  Keyframe(720, {}),
];

const hitClip = <Keyframe>[
  Keyframe(80, {J.lean: -14, J.head: -12, J.dx: -22}, easeOut),
  Keyframe(460, {}, easeOut),
];

const flinchClip = <Keyframe>[
  Keyframe(90, {J.lean: -12, J.head: -10, J.dx: -14}, easeOut),
  Keyframe(480, {}, easeOut),
];

/// The mage lifts the staff overhead, then thrusts it at the foe. The bolt leaves at [castReleaseMs].
const castClip = <Keyframe>[
  Keyframe(240, {J.lean: -6, J.head: -8, J.nS: 150, J.nE: 14, J.nW: 14, J.fS: 30, J.fE: 80, J.nH: 14, J.nK: 12, J.fH: -14, J.fK: 8}, easeOut),
  Keyframe(340, {J.lean: 12, J.head: 4, J.nS: 84, J.nE: 10, J.nW: 60, J.fS: 88, J.fE: 4, J.nH: 26, J.nK: 18, J.fH: -18, J.fK: 6, J.dx: 14}, easeIn),
  Keyframe(520, {J.lean: 10, J.head: 4, J.nS: 80, J.nE: 12, J.nW: 64, J.fS: 84, J.fE: 6, J.nH: 26, J.nK: 18, J.fH: -18, J.fK: 6, J.dx: 14}),
  Keyframe(900, {}),
];
const castReleaseMs = 340.0;

/// The ranger raises the bow, draws to the chest, looses, and lowers. The arrow leaves at [shootReleaseMs].
const shootClip = <Keyframe>[
  Keyframe(160, {J.lean: 6, J.head: -4, J.nS: 86, J.nE: 4, J.nW: 0, J.fS: 86, J.fE: 0}, easeOut),
  Keyframe(330, {J.lean: 6, J.head: -4, J.nS: 86, J.nE: 4, J.nW: 0, J.fS: 22, J.fE: 122, J.nH: 24, J.fH: -22}, easeInOut),
  Keyframe(400, {J.lean: 6, J.head: -4, J.nS: 86, J.nE: 4, J.nW: 0, J.fS: 20, J.fE: 124, J.nH: 24, J.fH: -22}),
  Keyframe(470, {J.lean: 3, J.head: -2, J.nS: 88, J.nE: 2, J.nW: 0, J.fS: -70, J.fE: 120, J.nH: 24, J.fH: -22}, easeOut),
  Keyframe(950, {}),
];
const shootReleaseMs = 400.0;
