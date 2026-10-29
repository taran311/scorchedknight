// The skeleton every humanoid shares: proportions, a pose of joint angles, and forward kinematics
// that turns the pose into joint positions. Angles are degrees; 0 points straight down and positive
// angles swing toward the foe (the character faces +x before any flip).

import 'dart:math' as math;
import 'dart:ui';

import 'paint_kit.dart';

class Build {
  const Build({
    required this.thighLen,
    required this.shinLen,
    required this.foot,
    required this.upperArm,
    required this.forearm,
    required this.spine,
    required this.neck,
    required this.head,
    required this.chest,
    required this.waist,
    required this.hip,
    required this.thigh,
    required this.shin,
    required this.upper,
    required this.fore,
    required this.hand,
  });
  final double thighLen, shinLen, foot, upperArm, forearm, spine, neck, head, chest, waist, hip, hand;
  final (double, double) thigh, shin, upper, fore; // radius at each end

  double get height => thighLen + shinLen + spine + neck + head * 2;
}

const builds = <String, Build>{
  'human': Build(
    thighLen: 50,
    shinLen: 48,
    foot: 20,
    upperArm: 38,
    forearm: 35,
    spine: 66,
    neck: 9,
    head: 17,
    chest: 25,
    waist: 19,
    hip: 21,
    thigh: (11.5, 8.5),
    shin: (8.5, 6),
    upper: (8, 7),
    fore: (7, 5.6),
    hand: 6.6,
  ),
  'goblin': Build(
    thighLen: 30,
    shinLen: 28,
    foot: 15,
    upperArm: 28,
    forearm: 26,
    spine: 40,
    neck: 6,
    head: 19,
    chest: 18,
    waist: 15,
    hip: 16,
    thigh: (8, 6),
    shin: (6, 4.6),
    upper: (5.6, 5),
    fore: (5, 4.2),
    hand: 5.2,
  ),
  'brute': Build(
    thighLen: 52,
    shinLen: 47,
    foot: 22,
    upperArm: 40,
    forearm: 37,
    spine: 70,
    neck: 8,
    head: 18,
    chest: 32,
    waist: 28,
    hip: 26,
    thigh: (14.5, 10.5),
    shin: (10.5, 7.5),
    upper: (11, 9),
    fore: (9, 7.2),
    hand: 8.4,
  ),
  'skeleton': Build(
    thighLen: 52,
    shinLen: 50,
    foot: 18,
    upperArm: 40,
    forearm: 38,
    spine: 64,
    neck: 10,
    head: 16,
    chest: 20,
    waist: 7,
    hip: 15,
    thigh: (4.6, 3.8),
    shin: (3.8, 3.2),
    upper: (4.2, 3.6),
    fore: (3.6, 3),
    hand: 4.6,
  ),
  'ent': Build(
    thighLen: 46,
    shinLen: 50,
    foot: 26,
    upperArm: 48,
    forearm: 46,
    spine: 84,
    neck: 6,
    head: 21,
    chest: 34,
    waist: 26,
    hip: 25,
    thigh: (14, 11),
    shin: (10.5, 13),
    upper: (11.5, 8.5),
    fore: (8.5, 6.5),
    hand: 7.5,
  ),
  'giant': Build(
    thighLen: 54,
    shinLen: 46,
    foot: 26,
    upperArm: 46,
    forearm: 44,
    spine: 74,
    neck: 8,
    head: 22,
    chest: 40,
    waist: 36,
    hip: 30,
    thigh: (17, 13),
    shin: (13, 10),
    upper: (14, 11),
    fore: (11.5, 9),
    hand: 10.5,
  ),
  // Dwarves: short in the leg, long in the arm, broad as a door.
  'dwarf': Build(
    thighLen: 34,
    shinLen: 30,
    foot: 20,
    upperArm: 33,
    forearm: 31,
    spine: 56,
    neck: 6,
    head: 18,
    chest: 31,
    waist: 28,
    hip: 24,
    thigh: (13, 10),
    shin: (10, 7.5),
    upper: (10, 8.5),
    fore: (8.5, 7),
    hand: 8,
  ),
  'lean': Build(
    thighLen: 52,
    shinLen: 50,
    foot: 19,
    upperArm: 40,
    forearm: 38,
    spine: 64,
    neck: 10,
    head: 16,
    chest: 21,
    waist: 15,
    hip: 18,
    thigh: (9.5, 7),
    shin: (7, 5.2),
    upper: (6.8, 5.8),
    fore: (5.8, 4.8),
    hand: 5.8,
  ),
};

/// Joint angles for one frame. n = near limb (toward the viewer), f = far limb.
/// S/E/W = shoulder/elbow/wrist(weapon); H/K = hip/knee.
enum J { dx, dy, lean, head, nS, nE, nW, fS, fE, fW, nH, nK, fH, fK }

class Pose {
  Pose(List<double> v) : v = List.of(v, growable: false);
  Pose.of(Map<J, double> m) : v = List.generate(J.values.length, (i) => m[J.values[i]] ?? 0, growable: false);
  final List<double> v;

  double operator [](J j) => v[j.index];
  void operator []=(J j, double x) => v[j.index] = x;

  Pose copy() => Pose(v);

  Pose withOverrides(Map<J, double> m) {
    final p = copy();
    m.forEach((k, x) => p[k] = x);
    return p;
  }

  static Pose lerp(Pose a, Pose b, double t) => Pose(List.generate(a.v.length, (i) => a.v[i] + (b.v[i] - a.v[i]) * t));
}

class Leg {
  const Leg(this.hip, this.knee, this.ankle);
  final Offset hip, knee, ankle;
}

class Arm {
  const Arm(this.shoulder, this.elbow, this.hand, this.upperAngle, this.foreAngle);
  final Offset shoulder, elbow, hand;
  final double upperAngle, foreAngle;
}

class Skeleton {
  Skeleton._(
    this.build,
    this.pelvis,
    this.chest,
    this.neck,
    this.head,
    this.forward,
    this.up,
    this.lean,
    this.headAngle,
    this.legNear,
    this.legFar,
    this.armNear,
    this.armFar,
  );

  factory Skeleton.solve(Build b, Pose p) {
    final lean = p[J.lean];
    final f = Offset(math.cos(lean * deg), math.sin(lean * deg));
    final u = Offset(math.sin(lean * deg), -math.cos(lean * deg));
    (Offset, Offset, Offset) leg(double h, double k, double ox) {
      final hip = Offset(ox, 0);
      final knee = hip + polar(h, b.thighLen);
      final ankle = knee + polar(h - k, b.shinLen);
      return (hip, knee, ankle);
    }

    final ln = leg(p[J.nH], p[J.nK], 3), lf = leg(p[J.fH], p[J.fK], -4);
    final ground = math.max(ln.$3.dy, lf.$3.dy) + b.shin.$2 + 1;
    final pel = Offset(p[J.dx], -ground + p[J.dy]);
    Leg place((Offset, Offset, Offset) l) => Leg(pel + l.$1, pel + l.$2, pel + l.$3);
    final chest = pel + u * b.spine, neck = chest + u * b.neck;
    final ha = lean + p[J.head];
    final head = neck + Offset(math.sin(ha * deg), -math.cos(ha * deg)) * (b.head * .82);
    Arm arm(Offset s, double sa, double ea) {
      final a1 = sa + lean * .5, a2 = sa + ea + lean * .5;
      final el = s + polar(a1, b.upperArm);
      return Arm(s, el, el + polar(a2, b.forearm), a1, a2);
    }

    final shN = chest + f * 2 - u * 6, shF = chest - f * 8 - u * 4;
    return Skeleton._(b, pel, chest, neck, head, f, u, lean, ha, place(ln), place(lf), arm(shN, p[J.nS], p[J.nE]), arm(shF, p[J.fS], p[J.fE]));
  }

  final Build build;
  final Offset pelvis, chest, neck, head, forward, up;
  final double lean, headAngle;
  final Leg legNear, legFar;
  final Arm armNear, armFar;

  /// A point offset from [base] along the body's forward and up axes.
  Offset at(Offset base, double fw, double upAmt) => base + forward * fw + up * upAmt;
}
