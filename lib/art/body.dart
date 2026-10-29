// Draws a full humanoid from a look and a pose: limbs, torso, tabard, cape, shield and weapons.
// Heads live in heads.dart.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'heads.dart';
import 'looks.dart';
import 'paint_kit.dart';
import 'rig.dart';
import 'sprites.dart';

class DrawOptions {
  const DrawOptions({required this.at, this.scale = 1, this.flip = false, this.alpha = 1, this.rotation = 0, this.tint, this.shadow = true, this.legs = true});
  final Offset at;
  final double scale, alpha, rotation;
  final bool flip, shadow;

  /// False for a rider in the saddle or a centaur's upper half (the legs are drawn elsewhere).
  final bool legs;
  final ColorFilter? tint;
}

/// Brightens toward white; used for hit flashes.
ColorFilter flashFilter(double k) {
  final m = 1 + k * 1.4, add = k * 40;
  return ColorFilter.matrix([m, 0, 0, 0, add, 0, m, 0, 0, add, 0, 0, m, 0, add, 0, 0, 0, 1, 0]);
}

/// Pushes toward red; used when the knight takes damage.
ColorFilter hurtFilter(double k) {
  return ColorFilter.matrix([1 + k * .6, 0, 0, 0, k * 60, 0, 1 - k * .35, 0, 0, 0, 0, 0, 1 - k * .45, 0, 0, 0, 0, 0, 1, 0]);
}

Skeleton drawHumanoid(Canvas c, Look look, Pose pose, double t, DrawOptions o, {bool still = false}) {
  final b = builds[look.build]!;
  final sk = Skeleton.solve(b, pose);
  final painted = o.legs ? Sprites.get(look.sprite) : null;
  if (painted != null) {
    _drawSprite(c, painted, b, sk, look, t, o, still);
    return sk;
  }
  c.save();
  c.translate(o.at.dx, o.at.dy);
  if (o.flip) c.scale(-1, 1);
  c.scale(o.scale, o.scale);
  if (o.rotation != 0) c.rotate(o.rotation * deg);
  final legs = o.legs && !look.ghostly;
  if (o.shadow && o.legs) {
    c.drawOval(Rect.fromCenter(center: Offset(sk.pelvis.dx + 4, 1), width: b.hip * 4.6, height: 14), Paint()..color = Color.fromRGBO(0, 0, 0, (look.ghostly ? .2 : .45) * o.alpha));
  }
  if (look.ghostly) {
    // A cold glow around a spirit.
    final glow = look.eyeGlow ?? const Color(0xFFB8E0F0);
    c.drawOval(Rect.fromCenter(center: sk.chest, width: b.chest * 5, height: b.spine * 4.5), Paint()..color = glow.withValues(alpha: .22 * o.alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  }
  final aura = look.armourGlow;
  if (aura != null) {
    // Enchanted wyrmscale: a slow, soft glow in its dragon's colour.
    final pulse = still ? .85 : .7 + .3 * math.sin(t / 520);
    c.drawOval(Rect.fromCenter(center: sk.chest, width: b.chest * 4.4, height: b.spine * 3.8), Paint()..color = aura.withValues(alpha: .26 * pulse * o.alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    c.drawCircle(sk.head, b.head * 1.9, Paint()..color = aura.withValues(alpha: .2 * pulse * o.alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  }
  final alpha = o.alpha * (look.ghostly ? .74 : 1);
  final layered = alpha < 1 || o.tint != null;
  if (layered) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
    if (o.tint != null) p.colorFilter = o.tint;
    c.saveLayer(null, p);
  }
  final cape = look.cape;
  if (look.tail != null) _tail(c, sk, look.tail!, t, still);
  if (look.wings != null) _wings(c, sk, look.wings!, t, still, feathered: look.feathered);
  if (cape != null) _cape(c, sk, look, cape, t, still);
  if (look.quiver != null) _quiver(c, sk, look);
  _arm(c, sk, sk.armFar, darker(look.upper), darker(look.fore), darker(look.hand), look.elbow == null ? null : darker(look.elbow!), _bulge(look));
  if (look.bandaged) _bandageArm(c, sk, sk.armFar, darker(look.fore), 3, t, still);
  if (look.kitDetail) _armKit(c, sk, sk.armFar, look, far: true);
  _armHorns(c, sk, sk.armFar, look, far: true);
  final bark = look.torsoKind == TorsoKind.bark;
  if (bark) _barkArm(c, sk, sk.armFar, look, far: true);
  final nAngle = sk.armNear.foreAngle + pose[J.nW], fAngle = sk.armFar.foreAngle + pose[J.fW];
  final heldInFront = look.offhand == Weapon.tome || look.offhand == Weapon.orb;
  if (look.offhand != Weapon.none && !heldInFront) drawWeapon(c, sk.armFar.hand, fAngle, look.offhand, look, t: t, glow: look.offhandGlow, still: still);
  if (look.weapon.bigBlade) drawWeapon(c, sk.armNear.hand, nAngle, look.weapon, look, t: t, glow: look.weaponGlow, still: still, tint: look.weaponTint, rarity: look.weaponRarity);
  if (legs) {
    // Ents stand on roots and skeletons on bare bone; everyone else wears boots.
    // (Feet the same as the shins, like a ghoul's, are bare.)
    final foot = bark
        ? _Foot.root
        : look.head == HeadKind.bull
        ? _Foot.hoof
        : (look.talons || look.head == HeadKind.demon || look.head == HeadKind.gargoyle || look.head == HeadKind.cyclops)
        ? _Foot.claw
        : (look.build == 'skeleton' || identical(look.boot, look.shin) ? _Foot.bone : _Foot.boot);
    _leg(c, sk, sk.legFar, darker(look.thigh), darker(look.shin), darker(look.boot), look.knee == null ? null : darker(look.knee!), look.wraps, foot, _bulge(look));
    if (look.bandaged) _bandageLeg(c, sk, sk.legFar, darker(look.shin), 5, t, still);
    if (look.kitDetail) _legKit(c, sk, sk.legFar, look, far: true);
    _legHorns(c, sk, sk.legFar, look, far: true);
    _leg(c, sk, sk.legNear, look.thigh, look.shin, look.boot, look.knee, look.wraps, foot, _bulge(look));
    if (look.bandaged) _bandageLeg(c, sk, sk.legNear, look.shin, 7, t, still);
    if (look.kitDetail) _legKit(c, sk, sk.legNear, look);
    _legHorns(c, sk, sk.legNear, look);
  } else if (look.ghostly) {
    _wisp(c, sk, look.skirt ?? look.torso, t, still);
  }
  if (bark && legs) {
    for (final l in [sk.legFar, sk.legNear]) {
      _grain(c, l.hip, l.knee, sk.build.thigh.$1);
      _grain(c, l.knee, l.ankle, sk.build.shin.$1);
      _roots(c, l.ankle, sk.build.foot, look.boot);
    }
  }
  if (look.skirt != null) _skirt(c, sk, look);
  _torso(c, sk, look);
  if (look.bandaged) _bandageTorso(c, sk, look);
  if (look.usekh) _usekh(c, sk);
  if (look.engrave > 0) _armourWork(c, sk, look, t, still);
  if (look.tabard != null) _tabard(c, sk, look);
  if (look.kitDetail && look.knee != null && look.tabard == null) _faulds(c, sk, look);
  _belt(c, sk, look);
  drawHead(c, sk, look, t, still: still);
  if (heldInFront) drawWeapon(c, sk.armFar.hand, fAngle, look.offhand, look, t: t, glow: look.offhandGlow, still: still);
  if (look.shield != null) _shield(c, sk.armFar, look.shield!);
  if (look.weapon != Weapon.none && !look.weapon.bigBlade) {
    drawWeapon(c, sk.armNear.hand, nAngle, look.weapon, look, t: t, glow: look.weaponGlow, still: still, tint: look.weaponTint, rarity: look.weaponRarity);
    if (look.weapon == Weapon.bow || look.weapon == Weapon.longbow || look.weapon == Weapon.orkbow || look.weapon == Weapon.heartbow || look.weapon == Weapon.runebow) {
      _bowString(c, sk, nAngle, look.weapon == Weapon.bow ? 56 : (look.weapon == Weapon.orkbow || look.weapon == Weapon.heartbow ? 66 : 70));
    }
    if (look.weapon == Weapon.yumi) _bowString(c, sk, nAngle, 52, upper: 92);
  }
  _arm(c, sk, sk.armNear, look.upper, look.fore, look.hand, look.elbow, _bulge(look));
  if (look.bandaged) _bandageArm(c, sk, sk.armNear, look.fore, 11, t, still);
  if (look.kitDetail) _armKit(c, sk, sk.armNear, look);
  if (bark) _barkArm(c, sk, sk.armNear, look);
  if (look.pauldron != null) _pauldron(c, sk, sk.armNear, look.pauldron!, look);
  if (look.ruff != null) _ruff(c, sk, look.ruff!);
  if (look.fangCollar) _fangCollar(c, sk, look);
  _armHorns(c, sk, sk.armNear, look);
  if (look.weapon.bigBlade) blob(c, sk.armFar.hand, b.hand, darker(look.hand));
  if (look.blackIron && look.kitDetail) _smoulder(c, sk, look, t, still);
  if (look.soot > 0) _soot(c, sk, look, t, still);
  if (look.shine) _shine(c, sk, t, still);
  if (layered) c.restore();
  c.restore();
  return sk;
}

/// Soot from the Great Burning: smudges on the kit, a couple of scorch marks and, while the hero
/// is still very sooty, a thin wisp of smoke from the top of their head. Fades as [Look.soot] does.
void _soot(Canvas c, Skeleton sk, Look look, double t, bool still) {
  final s = look.soot, b = sk.build;
  final smudge = Paint()
    ..color = Color.fromRGBO(34, 26, 22, .5 * s)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
  c.drawOval(Rect.fromCenter(center: sk.at(sk.chest, b.chest * .15, -b.spine * .2), width: b.chest * 1.1, height: b.spine * .32), smudge);
  c.drawOval(Rect.fromCenter(center: sk.at(sk.pelvis, -b.hip * .2, b.spine * .35), width: b.chest * .9, height: b.spine * .22), smudge);
  final knee = sk.legNear.knee;
  c.drawOval(Rect.fromCenter(center: knee + const Offset(2, -6), width: b.thigh.$1 * 1.8, height: b.thigh.$1 * 1.2), smudge);
  final hand = sk.armNear.elbow;
  c.drawOval(Rect.fromCenter(center: hand, width: b.upper.$1 * 1.8, height: b.upper.$1 * 1.4), smudge);
  if (s > .5 && !still) {
    // A wisp of smoke, still rising after all this time.
    final top = sk.head - sk.up * -(b.head * 1.1);
    final sway = math.sin(t / 380) * 4;
    final wisp = Path()
      ..moveTo(top.dx, top.dy)
      ..cubicTo(top.dx + 6 + sway, top.dy - 10, top.dx - 6 + sway, top.dy - 20, top.dx + 3 + sway * 1.5, top.dy - 32);
    c.drawPath(wisp, strokePaint(Color.fromRGBO(150, 140, 132, .45 * (s - .4)), 3.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }
}

/// A hero who has scrubbed off every speck of soot: a polished gleam and twinkling stars.
void _shine(Canvas c, Skeleton sk, double t, bool still) {
  final b = sk.build;
  final pulse = still ? .8 : .55 + .45 * math.sin(t / 300);
  for (final (i, at) in [sk.at(sk.chest, b.chest * .3, -b.spine * .1), sk.head + Offset(-b.head * .4, -b.head * .9), sk.armNear.shoulder].indexed) {
    final k = still ? .8 : (.5 + .5 * math.sin(t / 260 + i * 2.1)).clamp(0.0, 1.0) * pulse;
    if (k < .15) continue;
    final r = 3.5 + 3 * k;
    final star = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
      ..close();
    c.drawPath(star, Paint()..color = Color.fromRGBO(255, 248, 220, .9 * k));
    c.drawCircle(at, r * .9, Paint()..color = Color.fromRGBO(255, 236, 170, .35 * k)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
}

/// A spirit's trailing wisp where its legs would be.
void _wisp(Canvas c, Skeleton sk, Ramp col, double t, bool still) {
  final b = sk.build, p = sk.pelvis, sway = still ? 0.0 : math.sin(t / 420) * 8;
  final len = b.thighLen + b.shinLen;
  final wisp = Path()
    ..moveTo(p.dx - b.hip * .9, p.dy - 4)
    ..quadraticBezierTo(p.dx - b.hip * 1.1, p.dy + len * .5, p.dx - 6 + sway, p.dy + len * .8)
    ..quadraticBezierTo(p.dx - 16 + sway * 1.6, p.dy + len, p.dx - 30 + sway * 2, p.dy + len * .96)
    ..quadraticBezierTo(p.dx + 2 + sway, p.dy + len * .78, p.dx + b.hip * .4, p.dy + len * .5)
    ..quadraticBezierTo(p.dx + b.hip * 1.1, p.dy + len * .3, p.dx + b.hip * .9, p.dy - 4)
    ..close();
  c.drawPath(wisp, Paint()..shader = ui.Gradient.linear(Offset(0, p.dy), Offset(0, p.dy + len), [col[1], col[1].withValues(alpha: .5), col[1].withValues(alpha: 0)], const [0, .55, 1]));
}

enum _Foot { boot, bone, root, claw, hoof }

const _bones = -1.0;

/// Bare bones along [joints]: a slim shaft per segment with a knobbly joint at each end, and a
/// second, thinner bone beside the lower one (the shin's fibula, the forearm's ulna).
void _boneLimb(Canvas c, List<(Offset, double)> joints, Ramp col) {
  double shaft(double r) => math.max(1.8, r * .42);
  final last = joints.length - 1;
  for (var i = 0; i < last; i++) {
    final (a, ra) = joints[i];
    final (b, rb) = joints[i + 1];
    final s = shaft(math.min(ra, rb));
    if (i == last - 1 && last >= 2) {
      final d = b - a, n = Offset(-d.dy, d.dx) / math.max(d.distance, 1);
      capsule(c, a + n * s * 1.3, s * .55, b + n * s * 1.1, s * .5, darker(col));
    }
    capsule(c, a, s * 1.05, b, s, col);
    // A faint line down the shaft, for roundness.
    c.drawLine(Offset.lerp(a, b, .2)!, Offset.lerp(a, b, .8)!, strokePaint(col[0].withValues(alpha: .7), math.max(.8, s * .35)));
  }
  for (var i = 0; i < joints.length; i++) {
    final (p, r) = joints[i];
    final s = shaft(r);
    final next = i < last ? joints[i + 1].$1 : joints[i - 1].$1;
    final d = next - p, n = Offset(-d.dy, d.dx) / math.max(d.distance, 1);
    // Two rounded knuckles side by side make the end of a bone.
    final k = s * (i == 0 ? 1.15 : 1.0);
    blob(c, p + n * k * .6, k * .95, col);
    blob(c, p - n * k * .6, k * .95, col);
  }
}

/// How much a figure's limbs swell with muscle: none for bones, bark and stone; more for brutes.
/// (A skeleton's limbs, [_bones], are drawn as bare bones instead.)
double _bulge(Look look) => switch (look.torsoKind) {
  TorsoKind.ribs => _bones,
  TorsoKind.bark || TorsoKind.stone => 0,
  _ => look.ghostly ? 0 : (look.build == 'brute' || look.build == 'giant' ? .3 : .22),
};

void _leg(Canvas c, Skeleton sk, Leg l, Ramp thigh, Ramp shin, Ramp boot, Ramp? knee, bool wraps, [_Foot foot = _Foot.boot, double bulge = 0]) {
  final b = sk.build;
  // Thigh and shin as one piece (no seam at the knee), the knee joint sized between them.
  final kr = (b.thigh.$2 + b.shin.$1) / 2;
  if (bulge == _bones) {
    final toe = l.ankle + Offset(b.foot, 3);
    _boneLimb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2)], shin);
    // A bony foot: a heel, a long instep and three toe bones.
    capsule(c, l.ankle + const Offset(-2, 2), b.shin.$2 * .55, toe, b.shin.$2 * .4, boot);
    for (final dy in const [-1.5, .5, 2.5]) {
      capsule(c, toe + Offset(0, dy), 1.2, toe + Offset(4, dy + 1), 1, boot);
    }
    if (knee != null) _poleyn(c, l.hip, l.knee, l.ankle, b.thigh.$2 * 1.1, knee);
    return;
  }
  if (foot == _Foot.boot) {
    limb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2)], [thigh, shin], bulge: bulge);
    _boot(c, l.ankle, b.shin.$2, b.foot, boot);
  } else if (foot == _Foot.hoof) {
    // A bull's leg ends in a cloven hoof.
    limb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2)], [thigh, shin], bulge: bulge);
    final s = b.shin.$2 + 1.5;
    final hoof = Path()
      ..moveTo(l.ankle.dx - s, l.ankle.dy - s * .4)
      ..lineTo(l.ankle.dx + s * 1.1, l.ankle.dy - s * .4)
      ..lineTo(l.ankle.dx + s * 1.6, l.ankle.dy + s * 1.2)
      ..lineTo(l.ankle.dx - s * 1.1, l.ankle.dy + s * 1.2)
      ..close();
    fillPath(c, hoof, boot, Offset(0, l.ankle.dy - s), Offset(0, l.ankle.dy + s * 1.2));
    c.drawLine(Offset(l.ankle.dx + s * .4, l.ankle.dy + s * .2), Offset(l.ankle.dx + s * .5, l.ankle.dy + s * 1.2), strokePaint(const Color(0x88000000), 1.2));
  } else {
    // Bare bone, roots, or a clawed foot: the foot is part of the same continuous limb.
    final toe = l.ankle + Offset(b.foot, 3);
    limb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2), (toe, b.shin.$2 * .75)], [thigh, shin, foot == _Foot.claw ? shin : boot], bulge: bulge);
    if (foot == _Foot.claw) {
      for (final dy in const [-2.5, 1.0, 4.0]) {
        final at = toe + Offset(b.shin.$2 * .5, dy);
        c.drawPath(Path()..moveTo(at.dx - 1, at.dy - 1.4)..quadraticBezierTo(at.dx + 4, at.dy - 1, at.dx + 5, at.dy + 2)..quadraticBezierTo(at.dx + 2, at.dy + .6, at.dx - 1, at.dy + 1.4)..close(), Paint()..color = const Color(0xFFE8E2D0));
      }
    }
  }
  if (knee != null) _poleyn(c, l.hip, l.knee, l.ankle, b.thigh.$2 * 1.1, knee);
  if (wraps) {
    final p = strokePaint(const Color(0x59000000), 1.2);
    for (var i = .2; i < .9; i += .18) {
      final q = Offset.lerp(l.knee, l.ankle, i)!;
      c.drawLine(q + Offset(-b.shin.$1, -2), q + Offset(b.shin.$1, 2), p);
    }
  }
}

void _arm(Canvas c, Skeleton sk, Arm a, Ramp upper, Ramp fore, Ramp hand, Ramp? elbow, [double bulge = 0]) {
  final b = sk.build;
  if (bulge == _bones) {
    _boneLimb(c, [(a.shoulder, b.upper.$1), (a.elbow, (b.upper.$2 + b.fore.$1) / 2), (a.hand, b.fore.$2)], upper);
  } else {
    limb(c, [(a.shoulder, b.upper.$1), (a.elbow, (b.upper.$2 + b.fore.$1) / 2), (a.hand, b.fore.$2)], [upper, fore], bulge: bulge);
  }
  if (elbow != null) _poleyn(c, a.shoulder, a.elbow, a.hand, b.upper.$2 * 1.05, elbow);
  _fist(c, a.elbow, a.hand, b.hand, hand);
}

/// A boot: a shaft that hugs the shin, a rounded heel, a flat sole and a rounded toe, with a
/// darker sole and a turned-down cuff.
void _boot(Canvas c, Offset ankle, double s, double foot, Ramp col) {
  final r = s + .6, f = foot + 1.5, top = ankle.dy - s * 2.6;
  final boot = Path()
    ..moveTo(ankle.dx - r, top)
    ..lineTo(ankle.dx - r * 1.05, ankle.dy + r * .5)
    ..quadraticBezierTo(ankle.dx - r * 1.12, ankle.dy + r * 1.3, ankle.dx - r * .25, ankle.dy + r * 1.3)
    ..lineTo(ankle.dx + f - r * .6, ankle.dy + r * 1.3)
    ..quadraticBezierTo(ankle.dx + f + r * .7, ankle.dy + r * 1.3, ankle.dx + f + r * .5, ankle.dy + r * .55)
    ..quadraticBezierTo(ankle.dx + f * .75, ankle.dy - r * .25, ankle.dx + r * .9, ankle.dy - r * .45)
    ..lineTo(ankle.dx + r, top)
    ..close();
  fillPath(c, boot, col, Offset(ankle.dx, top), Offset(ankle.dx, ankle.dy + r * 1.3));
  // Sole, and a cuff folded over at the top.
  c.drawLine(Offset(ankle.dx - r * .7, ankle.dy + r * 1.2), Offset(ankle.dx + f, ankle.dy + r * 1.2), strokePaint(shade(col[2], -.35), 1.5));
  final cuff = RRect.fromRectAndRadius(Rect.fromLTRB(ankle.dx - r * 1.12, top - r * .15, ankle.dx + r * 1.12, top + r * .7), Radius.circular(r * .35));
  fillPath(c, Path()..addRRect(cuff), [shade(col[0], .08), shade(col[1], .05), col[2]], Offset(0, top), Offset(0, top + r * .7));
}

/// A closed hand at the end of the forearm: a squared fist with knuckles and a thumb, turned to
/// follow the arm.
void _fist(Canvas c, Offset elbow, Offset hand, double r, Ramp col) {
  final d = hand - elbow, len = d.distance;
  final ang = len < .1 ? 0.0 : math.atan2(d.dy, d.dx);
  c.save();
  c.translate(hand.dx, hand.dy);
  c.rotate(ang);
  final fist = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(r * .15, 0), width: r * 2.2, height: r * 2.0), Radius.circular(r * .75));
  fillPath(c, Path()..addRRect(fist), col, Offset(0, -r), Offset(0, r));
  // Knuckles across the front, and the thumb along the top.
  final crease = strokePaint(const Color(0x40000000), .9);
  for (final y in [-r * .45, 0.0, r * .45]) {
    c.drawLine(Offset(r * .55, y), Offset(r * 1.05, y), crease);
  }
  final thumb = capsulePath(Offset(-r * .45, -r * .78), r * .42, Offset(r * .55, -r * .95), r * .36);
  c.drawPath(thumb, Paint()..color = col[0]);
  c.drawPath(thumb, strokePaint(const Color(0xB3100B07), .9));
  c.restore();
}

/// A knee or elbow guard (poleyn or couter): a small fan wing on the outside of the joint and a
/// domed cop over it, catching the light.
void _poleyn(Canvas c, Offset a, Offset joint, Offset b, double r, Ramp col) {
  final out = (joint - a) / math.max(.1, (joint - a).distance) + (joint - b) / math.max(.1, (joint - b).distance);
  final dir = out.distance < .05 ? const Offset(1, 0) : out / out.distance;
  c.save();
  c.translate(joint.dx, joint.dy);
  c.rotate(math.atan2(dir.dy, dir.dx));
  final fan = Path()
    ..moveTo(-r * .1, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .7, r * .9, 0)
    ..quadraticBezierTo(r * .95, r * .7, -r * .1, r * .95)
    ..close();
  fillPath(c, fan, [shade(col[0], -.12), shade(col[1], -.18), col[2]], Offset(0, -r), Offset(0, r));
  final cop = Path()..addOval(Rect.fromCenter(center: Offset(r * .15, 0), width: r * 1.7, height: r * 1.55));
  fillPath(c, cop, col, Offset(-r * .4, -r * .8), Offset(r * .5, r * .8));
  c.drawArc(Rect.fromCenter(center: Offset(r * .1, -r * .05), width: r * 1.1, height: r * .95), math.pi * 1.05, math.pi * .55, false, strokePaint(shade(col[0], .25).withValues(alpha: .8), 1.1));
  c.restore();
}

Path _torsoPath(Skeleton sk) {
  final b = sk.build, c = sk.chest, p = sk.pelvis;
  Offset pt(Offset base, double fw, double up) => sk.at(base, fw, up);
  final sb = pt(c, -b.chest * .62, -2), sf = pt(c, b.chest * .38, -4), cf = pt(c, b.chest * .62, -b.spine * .28);
  final wf = pt(p, b.waist * .55, b.spine * .32), hf = pt(p, b.hip * .6, -4), hb = pt(p, -b.hip * .58, -4);
  final wb = pt(p, -b.waist * .58, b.spine * .34), cb = pt(c, -b.chest * .66, -b.spine * .3), top = pt(c, 0, 3);
  void q(Path path, Offset ctrl, Offset end) => path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
  final path = Path()..moveTo(sb.dx, sb.dy);
  q(path, top, sf);
  q(path, pt(c, b.chest * .66, -b.spine * .08), cf);
  q(path, pt(p, b.waist * .62, b.spine * .55), wf);
  q(path, pt(p, b.hip * .62, b.spine * .12), hf);
  q(path, pt(p, 0, -8), hb);
  q(path, pt(p, -b.hip * .62, b.spine * .12), wb);
  q(path, pt(c, -b.chest * .74, -b.spine * .55), cb);
  q(path, pt(c, -b.chest * .7, -b.spine * .08), sb);
  return path..close();
}

void _torso(Canvas c, Skeleton sk, Look look) {
  if (look.torsoKind == TorsoKind.ribs) return _ribcage(c, sk, look);
  final b = sk.build, path = _torsoPath(sk);
  fillPath(c, path, look.torso, sk.at(sk.chest, -b.chest * .7, 0), sk.at(sk.chest, b.chest * .7, 0));
  if (look.torsoKind == TorsoKind.plain && look.build == 'giant' && !look.ghostly) {
    // A giant's pot belly, sagging forward over the belt.
    final skin = look.torso;
    final belly = Rect.fromCenter(center: sk.at(sk.pelvis, b.waist * .42, b.spine * .3), width: b.waist * 1.45, height: b.spine * .6);
    c.drawOval(belly, Paint()..shader = RadialGradient(center: const Alignment(.3, -.4), radius: .9, colors: [shade(skin[0], .08), skin[1], shade(skin[2], .1)]).createShader(belly));
    c.drawArc(belly, -.9, 2.9, false, strokePaint(outline, 1.6));
  }
  c.save();
  c.clipPath(path);
  switch (look.torsoKind) {
    case TorsoKind.mail:
      c.restore();
      mailTexture(c, path, glint: look.blackIron ? const Color(0x80B4BCC6) : null);
      c.save();
    case TorsoKind.plate:
      final a = sk.at(sk.chest, -b.chest * .2, -6), e = sk.at(sk.pelvis, -b.waist * .15, b.spine * .4), ctrl = a - sk.forward * 8;
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, e.dx, e.dy),
        strokePaint(const Color(0x59FFFFFF), 4),
      );
    case TorsoKind.leather when look.kitDetail:
      _quilt(c, path, look.torso);
      // A laced opening at the throat.
      final top = sk.at(sk.chest, b.chest * .42, -2), bottom = sk.at(sk.chest, b.chest * .38, -b.spine * .32);
      c.drawLine(top, bottom, strokePaint(const Color(0x8C1A100A), 2.2));
      for (var i = 0; i < 3; i++) {
        final q = Offset.lerp(top, bottom, .2 + i * .28)!;
        c.drawLine(q - sk.forward * 3 + sk.up * 1.5, q + sk.forward * 3 - sk.up * 1.5, strokePaint(const Color(0xFFD8C8A0), 1));
      }
    case TorsoKind.leather:
      final p = strokePaint(const Color(0x59000000), 1.2), a = sk.at(sk.chest, b.chest * .35, 0);
      for (var i = 0; i < 5; i++) {
        final q = a + sk.up * (-10.0 - i * 8);
        c.drawLine(q - sk.forward * 4, q + sk.forward * 3, p);
      }
    case TorsoKind.studded:
      final p = strokePaint(const Color(0x59000000), 1.2), a = sk.at(sk.chest, b.chest * .35, 0);
      for (var i = 0; i < 5; i++) {
        final q = a + sk.up * (-10.0 - i * 8);
        c.drawLine(q - sk.forward * 4, q + sk.forward * 3, p);
      }
      final stud = Paint()..color = const Color(0xFFCFC6B0);
      for (var row = 0; row < 4; row++) {
        for (var col = 0; col < 3; col++) {
          c.drawCircle(sk.at(sk.chest, -b.chest * .45 + col * b.chest * .32, -8.0 - row * 12), 1.6, stud);
        }
      }
    case TorsoKind.dragonplate:
      // Dragonslayer plate: ridged layers sweeping round the body like a dragon's ribs, each edge
      // catching the light, a keel down the front, and (on the finest) embers between the plates.
      // (Edges are lifted towards white, so even black Obsidian plate shows its shape.)
      final edge = Color.lerp(look.torso[0], const Color(0xFFFFFFFF), .4)!, dark = shade(look.torso[2], -.4);
      final ember = look.armourGlow;
      for (var row = 0; row < 7; row++) {
        final y = -6.0 - row * 10.5;
        final back = sk.at(sk.chest, -b.chest * .95, y + 4), front = sk.at(sk.chest, b.chest * .95, y + 1);
        final dip = sk.at(sk.chest, b.chest * .2, y - 7);
        final ridge = Path()
          ..moveTo(back.dx, back.dy)
          ..quadraticBezierTo(dip.dx, dip.dy, front.dx, front.dy);
        if (ember != null) {
          c.drawPath(ridge.shift(const Offset(0, 2.4)), strokePaint(ember.withValues(alpha: .5), 4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
          c.drawPath(ridge.shift(const Offset(0, 2.4)), strokePaint(ember.withValues(alpha: .95), 1.4));
        }
        c.drawPath(ridge.shift(const Offset(0, 1.2)), strokePaint(dark.withValues(alpha: .85), 2.2));
        c.drawPath(ridge, strokePaint(edge.withValues(alpha: .9), 1.4));
      }
      // The keel: a raised spine down the front of the breastplate.
      final k0 = sk.at(sk.chest, b.chest * .55, -2), k1 = sk.at(sk.pelvis, b.waist * .5, b.spine * .05);
      c.drawLine(k0, k1, strokePaint(dark, 3.4));
      c.drawLine(k0 + const Offset(-1, 0), k1 + const Offset(-1, 0), strokePaint(edge, 1.2));
    case TorsoKind.lamellar:
      // Lacquered lamellar: rows of small plates, laced together top to bottom with silk cord.
      final lace = look.trim ?? const Color(0xFFE8C060);
      final band = strokePaint(shade(look.torso[2], -.3).withValues(alpha: .8), 1.4);
      final shine = strokePaint(const Color(0x40FFFFFF), 1);
      for (var row = 0; row < 7; row++) {
        final y = -6.0 - row * 9;
        final a = sk.at(sk.chest, -b.chest * .9, y), e = sk.at(sk.chest, b.chest * .9, y);
        c.drawLine(a, e, band);
        c.drawLine(a + sk.up * -1.6, e + sk.up * -1.6, shine);
        for (var col = 0; col < 6; col++) {
          final q = sk.at(sk.chest, -b.chest * .75 + col * b.chest * .3, y - 4.5);
          c.drawLine(q - sk.up * 3, q + sk.up * 3, strokePaint(lace, 1.4));
        }
      }
    case TorsoKind.scales:
      // Overlapping dragon scales, rows offset like roof tiles.
      final scale = Paint()..color = shade(look.torso[1], .18);
      final edge = strokePaint(const Color(0x66000000), 1);
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 5; col++) {
          final q = sk.at(sk.chest, -b.chest * .7 + col * b.chest * .36 + (row.isOdd ? b.chest * .18 : 0), -4.0 - row * 9);
          final r = Rect.fromCenter(center: q, width: 9, height: 8);
          c.drawArc(r, 0, 3.14, true, scale);
          c.drawArc(r, 0, 3.14, false, edge);
        }
      }
    case TorsoKind.robe:
      final trim = look.trim ?? const Color(0xFFC9A24E);
      final top = sk.at(sk.chest, b.chest * .3, 2), bottom = sk.at(sk.pelvis, b.waist * .4, -6);
      // (Spirits wear no belt, so a front stripe would end in mid-air: they go without.)
      if (!look.ghostly) {
        c.drawLine(top, bottom, strokePaint(shade(trim, -.35), 6));
        c.drawLine(top, bottom, strokePaint(trim, 3.5));
      }
      final l = sk.at(sk.chest, -b.chest * .25, 1), v = sk.at(sk.chest, b.chest * .3, -b.spine * .3), r = sk.at(sk.chest, b.chest * .6, -2);
      c.drawPath(
        Path()
          ..moveTo(l.dx, l.dy)
          ..lineTo(v.dx, v.dy)
          ..lineTo(r.dx, r.dy),
        strokePaint(trim, 2.4),
      );
    case TorsoKind.fur:
      final p = Paint()..color = shade(look.torso[1], .25);
      for (var i = 0; i < 14; i++) {
        final q = sk.at(sk.chest, b.chest * .15 + (i % 2) * 3, -i * 5.0);
        c.save();
        c.translate(q.dx, q.dy);
        c.rotate(sk.lean * deg);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 14), p);
        c.restore();
      }
    case TorsoKind.rags:
      final p = strokePaint(const Color(0x4D000000), 1.2);
      for (var i = 0; i < 3; i++) {
        final q = sk.at(sk.chest, -6.0 + i * 5, -14.0 - i * 14);
        c.drawLine(q, q + const Offset(4, 9), p);
      }
    case TorsoKind.stone:
      // Cracked, weathered stone with a few lichen speckles.
      final crack = strokePaint(const Color(0x66000000), 1.3);
      for (final (fw, up, dx, dy) in const [(.2, .2, 8.0, 14.0), (-.3, .55, -6.0, 18.0), (.35, .7, 10.0, 10.0)]) {
        final a = sk.at(sk.chest, b.chest * fw, -b.spine * up);
        c.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(a.dx + dx * .5, a.dy + dy * .4)
            ..lineTo(a.dx + dx * .2, a.dy + dy * .7)
            ..lineTo(a.dx + dx, a.dy + dy),
          crack,
        );
      }
      final ore = look.trim;
      if (ore != null) {
        // A golem: a vein of ore runs through it, glinting, with lumps where it breaks the surface.
        final pts = [for (final (fw, up) in const [(-.45, .1), (-.1, .3), (-.25, .5), (.2, .65), (.05, .9)]) sk.at(sk.chest, b.chest * fw, -b.spine * up)];
        final vein = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) {
          vein.lineTo(p.dx, p.dy);
        }
        c.drawPath(vein, strokePaint(ore.withValues(alpha: .45), 6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        c.drawPath(vein, strokePaint(ore, 2.4));
        for (final (i, s) in const [(1, 5.5), (3, 6.5), (4, 4.5)]) {
          final p = pts[i];
          c.drawPath(poly([p + Offset(-s, -s * .3), p + Offset(-s * .2, -s), p + Offset(s, -s * .2), p + Offset(s * .3, s * .8)]), Paint()..color = ore);
          c.drawCircle(p + Offset(-s * .2, -s * .3), 1.3, Paint()..color = const Color(0xCCFFFFFF));
        }
      } else {
        final lichen = Paint()..color = const Color(0x557A9A5A);
        for (final (fw, up) in const [(-.4, .15), (.1, .4), (-.1, .8)]) {
          c.drawCircle(sk.at(sk.chest, b.chest * fw, -b.spine * up), 2.6, lichen);
        }
      }
    case TorsoKind.bark:
      // Grain running down the trunk, a couple of knots, and moss on the shoulders.
      final grain = strokePaint(const Color(0x47000000), 1.4);
      for (var i = -3; i <= 3; i++) {
        final a = sk.at(sk.chest, i * b.chest * .2, 4), e = sk.at(sk.pelvis, i * b.hip * .17, -6), m = Offset.lerp(a, e, .5)! + sk.forward * (i.isEven ? 3 : -3);
        c.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(m.dx, m.dy, e.dx, e.dy),
          grain,
        );
      }
      for (final (fw, up) in const [(.25, -.35), (-.35, -.65)]) {
        final k = sk.at(sk.chest, b.chest * fw, b.spine * up);
        c.drawOval(Rect.fromCenter(center: k, width: 8, height: 11), Paint()..color = shade(look.torso[2], -.2));
        c.drawOval(Rect.fromCenter(center: k, width: 8, height: 11), strokePaint(shade(look.torso[0], .1), 1.2));
      }
      final moss = look.beard;
      if (moss != null) {
        for (var i = 0; i < 6; i++) {
          c.drawCircle(sk.at(sk.chest, -b.chest * .5 + i * b.chest * .2, -2.0 - (i % 2) * 5), 6, Paint()..color = shade(moss, (i % 3 - 1) * .15));
        }
      }
    case TorsoKind.plain when !look.ghostly:
      _bareChest(c, sk, look);
    case TorsoKind.plain || TorsoKind.ribs:
      break;
  }
  if (look.thorns) {
    // Thorns down the back.
    final thorn = Paint()..color = shade(look.torso[2], -.1);
    for (var i = 0; i < 6; i++) {
      final base = sk.at(sk.chest, -b.chest * .62, -6.0 - i * b.spine * .13), tip = base - sk.forward * 9 + sk.up * 4;
      c.restore();
      c.drawPath(poly([base + sk.up * 3, tip, base - sk.up * 3]), thorn);
      c.drawPath(poly([base + sk.up * 3, tip, base - sk.up * 3]), strokePaint(outline, .8));
      c.save();
      c.clipPath(path);
    }
  }
  final embers = look.embers;
  if (embers != null) {
    // Cracks of fire through the hide, glowing from inside.
    final glow = strokePaint(embers.withValues(alpha: .55), 4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = strokePaint(Color.lerp(embers, const Color(0xFFFFF0B0), .5)!, 1.3);
    for (final pts in [
      [(.1, -.12), (.3, -.22), (.25, -.34), (.45, -.42)],
      [(-.3, -.5), (-.1, -.58), (.05, -.72), (.3, -.78)],
      [(.4, -.05), (.55, -.16)],
    ]) {
      final path = Path();
      for (final (i, (fw, up)) in pts.indexed) {
        final q = sk.at(sk.chest, b.chest * fw, b.spine * up);
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, glow);
      c.drawPath(path, core);
    }
  }
  if (look.gore) {
    final q = sk.at(sk.chest, 6, -22);
    c.save();
    c.translate(q.dx, q.dy);
    c.rotate(.3);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 18), Paint()..color = const Color(0x8C3C140F));
    c.restore();
  }
  c.restore();
}

/// Two dark lines of bark grain along a limb.
void _grain(Canvas c, Offset a, Offset b, double r) {
  final d = b - a, n = Offset(-d.dy, d.dx) / math.max(1, d.distance);
  final p = strokePaint(const Color(0x42000000), 1.2);
  c.drawLine(a + n * r * .35, b + n * r * .3, p);
  c.drawLine(a - n * r * .25, b - n * r * .2, p);
}

/// Root toes splaying from an ent's foot.
void _roots(Canvas c, Offset ankle, double foot, Ramp bark) {
  final p = strokePaint(bark[2], 3.2)..strokeCap = StrokeCap.round;
  for (final (dx, dy) in [(foot * .9, 4.0), (foot * 1.2, 1.0), (-foot * .5, 3.0)]) {
    c.drawPath(
      Path()
        ..moveTo(ankle.dx, ankle.dy + 2)
        ..quadraticBezierTo(ankle.dx + dx * .5, ankle.dy - 2, ankle.dx + dx, ankle.dy + dy),
      p,
    );
  }
}

/// An ent's arm: bark grain, twig fingers, leaves on the shoulder and thorns on the forearm.
void _barkArm(Canvas c, Skeleton sk, Arm a, Look look, {bool far = false}) {
  final b = sk.build;
  _grain(c, a.shoulder, a.elbow, b.upper.$1);
  _grain(c, a.elbow, a.hand, b.fore.$1);
  final d = a.hand - a.elbow, u = d / math.max(1, d.distance);
  final twig = strokePaint(far ? shade(look.hand[2], -.2) : look.hand[2], 2.6)..strokeCap = StrokeCap.round;
  for (final turn in const [-.55, 0.0, .5]) {
    final dir = Offset(u.dx * math.cos(turn) - u.dy * math.sin(turn), u.dx * math.sin(turn) + u.dy * math.cos(turn));
    final tip = a.hand + dir * b.hand * 2.2;
    c.drawLine(a.hand, tip, twig);
    c.drawLine(Offset.lerp(a.hand, tip, .6)!, Offset.lerp(a.hand, tip, .6)! + dir * 4 + Offset(-dir.dy, dir.dx) * 4, strokePaint(twig.color, 1.6));
  }
  if (look.thorns) {
    final thorn = Paint()..color = look.fore[2];
    final n = Offset(-u.dy, u.dx);
    for (final k in const [.3, .6]) {
      final base = Offset.lerp(a.elbow, a.hand, k)!;
      c.drawPath(poly([base - u * 3, base + n * 8, base + u * 3]), thorn);
    }
  }
  final foliage = look.foliage;
  if (foliage != null) leafCluster(c, a.shoulder + const Offset(0, -6), b.upper.$1 * 1.7, far ? shade(foliage, -.25) : foliage, seed: far ? 3 : 5);
}

/// Bare skin: the line under the chest, a hint of ribs at the side and a navel; on a giant, a pot
/// belly sagging over the belt and a thatch of chest hair.
void _bareChest(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, skin = look.torso;
  final big = look.build == 'giant';
  final under = strokePaint(shade(skin[2], -.1).withValues(alpha: .55), big ? 2.2 : 1.6);
  final a = sk.at(sk.chest, b.chest * .02, -b.spine * .2), m = sk.at(sk.chest, b.chest * .4, -b.spine * .32), e = sk.at(sk.chest, b.chest * .66, -b.spine * .2);
  c.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(m.dx, m.dy, e.dx, e.dy),
    under,
  );
  // Ribs at the side, under the arm.
  for (var i = 0; i < 3; i++) {
    final q = sk.at(sk.chest, -b.chest * .2, -b.spine * (.3 + i * .09));
    c.drawLine(q, q + sk.forward * b.chest * .25 - sk.up * 3, strokePaint(shade(skin[2], -.1).withValues(alpha: .25), 1.2));
  }
  // A navel.
  final navel = sk.at(sk.pelvis, b.waist * (big ? .55 : .45), b.spine * (big ? .34 : .3));
  c.drawOval(Rect.fromCenter(center: navel, width: 3.5, height: 2.4), Paint()..color = shade(skin[2], -.3).withValues(alpha: .7));
  if (big) {
    final hair = strokePaint(look.hair.withValues(alpha: .6), 1.1);
    final rng = math.Random(7);
    for (var i = 0; i < 16; i++) {
      final q = sk.at(sk.chest, b.chest * (.15 + rng.nextDouble() * .4), -b.spine * (.06 + rng.nextDouble() * .2));
      c.drawLine(q, q + Offset(rng.nextDouble() * 3 - 1.5, 3), hair);
    }
  }
}

/// A skeleton's spine, ribcage and pelvis instead of a filled torso.
void _ribcage(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, bone = look.torso;
  // Pelvis: a broad, flared hip bone with a hole through it.
  final pl = sk.at(sk.pelvis, -b.hip * .9, 2), pr = sk.at(sk.pelvis, b.hip * .9, 2);
  final pelvis = Path()
    ..moveTo(pl.dx, pl.dy)
    ..quadraticBezierTo(sk.at(sk.pelvis, -b.hip * .4, 18).dx, sk.at(sk.pelvis, -b.hip * .4, 18).dy, sk.at(sk.pelvis, 0, 10).dx, sk.at(sk.pelvis, 0, 10).dy)
    ..quadraticBezierTo(sk.at(sk.pelvis, b.hip * .4, 18).dx, sk.at(sk.pelvis, b.hip * .4, 18).dy, pr.dx, pr.dy)
    ..quadraticBezierTo(sk.at(sk.pelvis, b.hip * .5, -6).dx, sk.at(sk.pelvis, b.hip * .5, -6).dy, sk.at(sk.pelvis, 0, -7).dx, sk.at(sk.pelvis, 0, -7).dy)
    ..quadraticBezierTo(sk.at(sk.pelvis, -b.hip * .5, -6).dx, sk.at(sk.pelvis, -b.hip * .5, -6).dy, pl.dx, pl.dy)
    ..close();
  fillPath(c, pelvis, bone, pl, pr);
  c.drawOval(Rect.fromCenter(center: sk.at(sk.pelvis, b.hip * .2, 1), width: b.hip * .5, height: 5), Paint()..color = const Color(0xCC1A1410));
  // Spine: a column of small vertebrae.
  for (var i = 0; i <= 8; i++) {
    final q = Offset.lerp(sk.at(sk.pelvis, -2, 10), sk.at(sk.chest, -4, 4), i / 8)!;
    blob(c, q, 3.2, bone);
  }
  // A great dead one burns with cold fire inside its ribs.
  final fire = look.embers;
  if (fire != null) {
    final heart = sk.at(sk.chest, b.chest * .3, -b.spine * .3);
    c.drawCircle(heart, b.chest * .7, Paint()
      ..color = fire.withValues(alpha: .45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.chest * .35));
    c.drawCircle(heart, b.chest * .22, Paint()
      ..color = Color.lerp(fire, const Color(0xFFFFFFFF), .5)!.withValues(alpha: .8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }
  // Ribs: curved arcs from the spine forward, longest in the middle.
  final edge = strokePaint(outline, 4.6), fill = strokePaint(bone[1], 3), hi = strokePaint(bone[0], 1.1);
  // The far side's ribs first, darker, peeking out past the near ones.
  final farEdge = strokePaint(outline, 3.6), farFill = strokePaint(shade(bone[1], -.3), 2);
  for (var i = 0; i < 5; i++) {
    final y = -6.0 - i * 7.5, reach = b.chest * (1.05 - (i - 2).abs() * .12);
    final back = sk.at(sk.chest, -4, y), front = sk.at(sk.chest, reach * .9, y + 3), ctrl = sk.at(sk.chest, reach * .5, y - 10);
    final rib = Path()
      ..moveTo(back.dx, back.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, front.dx, front.dy);
    c.drawPath(rib, farEdge);
    c.drawPath(rib, farFill);
  }
  for (var i = 0; i < 5; i++) {
    final y = -6.0 - i * 7.5, reach = b.chest * (1.05 - (i - 2).abs() * .12);
    final back = sk.at(sk.chest, -4, y), front = sk.at(sk.chest, reach, y + 6), ctrl = sk.at(sk.chest, reach * .7, y - 7);
    final rib = Path()
      ..moveTo(back.dx, back.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, front.dx, front.dy);
    c.drawPath(rib, edge);
    c.drawPath(rib, fill);
    c.drawPath(rib, hi);
  }
  // Sternum and collarbone.
  capsule(c, sk.at(sk.chest, b.chest * .78, -6), 2.2, sk.at(sk.chest, b.chest * .7, -34), 2, bone);
  capsule(c, sk.at(sk.chest, -6, 2), 2.2, sk.at(sk.chest, b.chest * .7, 0), 2.2, bone);
}

void _tabard(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, ch = sk.chest, p = sk.pelvis, colour = look.tabard!;
  Offset pt(Offset base, double fw, double up) => sk.at(base, fw, up);
  Offset along(Leg l, double s, double off) => Offset.lerp(l.hip, l.knee, s)! + Offset(off, 0);
  final a = pt(ch, -b.chest * .38, -b.spine * .36), e = pt(ch, b.chest * .48, -b.spine * .36);
  final path = poly([
    a,
    e,
    pt(p, b.hip * .62, -4),
    along(sk.legNear, .58, 9),
    along(sk.legNear, .62, -7),
    pt(p, 0, -4),
    along(sk.legFar, .56, -8),
    pt(p, -b.hip * .6, -4),
  ]);
  fillPath(c, path, [shade(colour, .18), colour, shade(colour, -.4)], a, pt(p, 0, -b.thighLen * .5));
  if (look.kitDetail) {
    c.save();
    c.clipPath(path);
    // Weight in the cloth: an inner shadow round the edge, soft folds falling from the belt, and
    // an embroidered border.
    c.drawPath(path, strokePaint(shade(colour, -.55).withValues(alpha: .45), 7));
    for (final (s, off) in [(sk.legNear, 4.0), (sk.legFar, -4.0)]) {
      final from = pt(p, off * .6, -2), to = along(s, .55, off);
      c.drawLine(from, to, strokePaint(shade(colour, -.5).withValues(alpha: .45), 3));
      c.drawLine(from + const Offset(2, 0), to + const Offset(2, 0), strokePaint(shade(colour, .3).withValues(alpha: .35), 1.2));
    }
    final trim = look.trim ?? const Color(0xFFC9A24E);
    c.drawPath(path, strokePaint(trim.withValues(alpha: .9), 5.5));
    c.drawPath(path, strokePaint(shade(colour, -.3), 3.2));
    final dots = Paint()..color = trim;
    final m = path.computeMetrics().toList();
    for (final metric in m) {
      for (var d = 4.0; d < metric.length; d += 7) {
        final tan = metric.getTangentForOffset(d);
        if (tan != null) c.drawCircle(tan.position, .9, dots);
      }
    }
    c.restore();
  }
  if (look.trim != null) c.drawPath(path, strokePaint(look.trim!, 2));
  final em = pt(ch, b.chest * .08, -b.spine * .6);
  c.save();
  c.translate(em.dx, em.dy);
  c.rotate(sk.lean * deg);
  if (look.emblem == 'flame') {
    // The survivor's crest: a little flame on a shield, the fire you walked out of.
    c.drawPath(
      Path()
        ..moveTo(-7, -8)
        ..lineTo(7, -8)
        ..lineTo(7, 2)
        ..quadraticBezierTo(7, 9, 0, 12)
        ..quadraticBezierTo(-7, 9, -7, 2)
        ..close(),
      Paint()..color = const Color(0xFFE8DCBC),
    );
    final flame = Path()
      ..moveTo(0, 8)
      ..quadraticBezierTo(-5, 6, -4, 1)
      ..quadraticBezierTo(-3, -2, -1, -5)
      ..quadraticBezierTo(0, -2, 1, -1)
      ..quadraticBezierTo(2, -4, 3, -6)
      ..quadraticBezierTo(5, 0, 4, 3)
      ..quadraticBezierTo(3, 7, 0, 8)
      ..close();
    c.drawPath(flame, Paint()..color = const Color(0xFFD8502A));
    c.drawPath(
      Path()
        ..moveTo(0, 7)
        ..quadraticBezierTo(-2, 5, -1, 2)
        ..quadraticBezierTo(1, 3, 2, 1)
        ..quadraticBezierTo(2.5, 5, 0, 7)
        ..close(),
      Paint()..color = const Color(0xFFF6C34A),
    );
  } else if (look.emblem == 'rose') {
    final petal = Paint()..color = const Color(0xFF1A0A0A);
    for (var i = 0; i < 5; i++) {
      c.save();
      c.translate(math.cos(i * 1.26) * 4, math.sin(i * 1.26) * 4);
      c.rotate(i * 1.26);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 9, height: 6.4), petal);
      c.restore();
    }
    c.drawCircle(Offset.zero, 2.6, Paint()..color = const Color(0xFFC23A30));
    c.drawLine(const Offset(0, 7), const Offset(0, 15), strokePaint(const Color(0xFF1A0A0A), 1.6));
  }
  c.restore();
}

void _belt(Canvas c, Skeleton sk, Look look) {
  // Ents, gargoyles, skeletons and spirits wear no belts.
  if (look.ghostly || const {TorsoKind.bark, TorsoKind.stone, TorsoKind.ribs}.contains(look.torsoKind)) return;
  final b = sk.build;
  final a = sk.at(sk.pelvis, -b.waist * .7, b.spine * .2), e = sk.at(sk.pelvis, b.waist * .72, b.spine * .2);
  c.drawLine(a, e, strokePaint(outline, 8));
  c.drawLine(a, e, strokePaint(look.belt, 5.5));
  final m = Offset.lerp(a, e, .62)!;
  final r = Rect.fromCenter(center: m, width: 7, height: 8);
  c.drawRect(r, Paint()..color = const Color(0xFFC9A24E));
  c.drawRect(r, strokePaint(outline, 1));
  if (look.pouch) {
    final q = Offset.lerp(a, e, .2)!;
    final pr = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(q.dx - 6, q.dy + 2, 12, 12), const Radius.circular(3)));
    fillPath(c, pr, ramp(0xFF6B4A2E), q, q + const Offset(0, 14));
  }
}

/// Dragonslayer plate's gorget: a high collar of fangs standing up round the throat, in front of
/// the arm so it always shows.
void _fangCollar(Canvas c, Skeleton sk, Look look) {
  final far = sk.armFar.shoulder, near = sk.armNear.shoulder, neck = sk.at(sk.chest, sk.build.chest * .25, 4);
  final metal = look.torso;
  // The gorget itself: a band of plate from shoulder to shoulder.
  final band = Path()
    ..moveTo(far.dx, far.dy + 2)
    ..quadraticBezierTo(neck.dx, neck.dy + 6, near.dx + 4, near.dy + 2)
    ..lineTo(near.dx + 2, near.dy - 6)
    ..quadraticBezierTo(neck.dx, neck.dy - 4, far.dx, far.dy - 6)
    ..close();
  fillPath(c, band, metal, far, near, width: 1.4);
  final tooth = <Color>[const Color(0xFFFFF8E8), const Color(0xFFE0D6BC), const Color(0xFF6A5E48)];
  for (var i = 0; i < 7; i++) {
    final u = (i + .5) / 7;
    final base = (u <= .5 ? Offset.lerp(far, neck, u * 2)! : Offset.lerp(neck, near, (u - .5) * 2)!) + const Offset(0, -4);
    final h = (i == 3) ? 14.0 : (i == 2 || i == 4 ? 11.0 : 8.0);
    final lean = (u - .5) * 6;
    final fang = poly([base + const Offset(-3, 0), base + Offset(lean, -h), base + const Offset(3, 0)]);
    fillPath(c, fang, tooth, base, base + Offset(0, -h), width: .9);
  }
}

/// A fur mantle: a thick shaggy collar across both shoulders.
void _ruff(Canvas c, Skeleton sk, Color fur) {
  final far = sk.armFar.shoulder, near = sk.armNear.shoulder, b = sk.build;
  final neck = sk.at(sk.chest, 0, 2);
  final fill = rampOf(fur, .25, .5);
  for (var i = 0; i <= 8; i++) {
    final u = i / 8;
    final p = u < .5 ? Offset.lerp(far, neck, u * 2)! : Offset.lerp(neck, near, (u - .5) * 2)!;
    final r = b.chest * (.2 + .06 * (i % 3));
    blob(c, p + sk.up * 2, r, fill);
  }
  for (var i = 0; i < 7; i++) {
    final p = Offset.lerp(far, near, (i + .5) / 7)!;
    c.drawLine(p, p - sk.up * 5 + sk.forward * (i.isEven ? 2 : -2), strokePaint(shade(fur, -.4), 1));
  }
}

void _pauldron(Canvas c, Skeleton sk, Arm a, Ramp col, Look look) {
  // Plate gets a big layered spaulder over the whole shoulder; mail a smaller one.
  final heavy = look.kitDetail && look.knee != null;
  final w = sk.build.upper.$1 * (heavy ? 1.55 : (look.kitDetail ? 1.2 : 1)), fine = look.engrave;
  c.save();
  c.translate(a.shoulder.dx + 1, a.shoulder.dy + 2);
  // Turned partway with the upper arm (most of the way for big plate pauldrons, which ride on it).
  c.rotate((sk.lean * .5 + (a.upperAngle - sk.lean * .5) * (heavy ? .45 : .25)) * deg);
  if (fine > 0) {
    // Lames hanging below the cap down the upper arm, each a little narrower and overlapped by
    // the one above, like proper plate. They stay over the arm, not across the chest.
    for (var i = 1; i >= 1; i--) {
      final top = w * .1 + i * w * .42, half = w * (1.2 - i * .14);
      final lame = Path()
        ..moveTo(-half, top)
        ..quadraticBezierTo(0, top + w * .3, half, top - w * .04)
        ..lineTo(half * .94, top + w * .4)
        ..quadraticBezierTo(0, top + w * .74, -half * .94, top + w * .44)
        ..close();
      fillPath(c, lame, [shade(col[0], -.08 * i), shade(col[1], -.1 * i), col[2]], Offset(0, top), Offset(0, top + w * .7), width: 1.2);
      c.drawPath(
        Path()
          ..moveTo(-half * .9, top + w * .4)
          ..quadraticBezierTo(0, top + w * .68, half * .9, top + w * .36),
        strokePaint(shade(col[0], .3).withValues(alpha: .8), .9),
      );
    }
  }
  final p = Path()
    ..moveTo(-w * 1.6, 4)
    ..quadraticBezierTo(-w * 1.4, -w * 1.6, w * .4, -w * 1.5)
    ..quadraticBezierTo(w * 1.9, -w * .8, w * 1.5, w * .9)
    ..quadraticBezierTo(0, w * .3, -w * 1.6, 4)
    ..close();
  fillPath(c, p, col, const Offset(-10, -12), const Offset(10, 8));
  if (fine > 0) {
    // A raised, bevelled rim, a fluted ridge over the top, rivets and engraving along the edge.
    final rim = Path()
      ..moveTo(-w * 1.45, 2)
      ..quadraticBezierTo(0, w * .22, w * 1.4, w * .8);
    c.drawPath(rim, strokePaint(shade(col[2], -.3), 3));
    c.drawPath(rim, strokePaint(shade(col[0], .35), 1.2));
    final ridge = Path()
      ..moveTo(-w * 1.1, -w * .6)
      ..quadraticBezierTo(w * .2, -w * 1.5, w * 1.35, -w * .2);
    c.drawPath(ridge, strokePaint(const Color(0xFFFFFFFF).withValues(alpha: .55), 1.6));
    c.drawPath(ridge.shift(const Offset(0, 2)), strokePaint(const Color(0xFF000000).withValues(alpha: .3), 1.2));
    final ink = look.engraveCol ?? shade(col[1], -.5);
    final scroll = Path()
      ..moveTo(-w * 1.05, -w * .05)
      ..cubicTo(-w * .5, -w * .65, w * .1, w * .15, w * .55, -w * .35)
      ..cubicTo(w * .85, -w * .6, w * 1.2, -w * .1, w * 1.05, w * .3);
    c.drawPath(scroll, strokePaint(ink.withValues(alpha: fine >= 2 ? .95 : .7), fine >= 2 ? 1.3 : 1));
    for (final r in [Offset(-w * 1.15, 1), Offset(w * 1.15, w * .65)]) {
      c.drawCircle(r, 1.6, Paint()..color = shade(col[2], -.2));
      c.drawCircle(r - const Offset(.5, .5), .7, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .8));
    }
  } else {
    c.drawPath(
      Path()
        ..moveTo(-w * 1.1, 1)
        ..quadraticBezierTo(0, -4, w * 1.3, 3),
      strokePaint(const Color(0x59000000), 1.2),
    );
  }
  c.restore();
}

/// The fine work on a knight's armour, over the chest above the tabard: a gorget at the throat,
/// a bevelled centre ridge, a polished sheen, rivets and engraved scrollwork. Gilt from plate up,
/// and the finest armour carries an ember sigil that glows with its wearer's spark.
void _armourWork(Canvas c, Skeleton sk, Look look, double t, bool still) {
  final b = sk.build, path = _torsoPath(sk), m = look.torso, fine = look.engrave;
  final ink = look.engraveCol ?? shade(m[1], -.5);
  Offset pt(double fw, double up) => sk.at(sk.chest, b.chest * fw, -b.spine * up);
  c.save();
  c.clipPath(path);
  final plate = look.torsoKind == TorsoKind.plate || look.torsoKind == TorsoKind.scales;
  if (plate) {
    // A polished sheen across the breastplate, bright down the front.
    final from = pt(-.5, .2), to = pt(.75, .2);
    c.drawRect(
      path.getBounds(),
      Paint()
        ..shader = ui.Gradient.linear(from, to, [const Color(0x00FFFFFF), const Color(0x00FFFFFF), const Color(0x59FFFFFF), const Color(0x14FFFFFF), const Color(0x00FFFFFF)], const [0, .35, .55, .7, 1]),
    );
    // A dark rim down the back edge, so the plate reads as round and hard.
    c.drawPath(path, strokePaint(shade(m[2], -.35).withValues(alpha: .7), 6));
    // The centre ridge, bevelled: light on one face, shadow on the other.
    final top = pt(.12, .04), bottom = pt(.04, .5);
    c.drawLine(top - sk.forward * 1.4, bottom - sk.forward * 1.4, strokePaint(const Color(0xFFFFFFFF).withValues(alpha: .6), 1.4));
    c.drawLine(top + sk.forward * 1.4, bottom + sk.forward * 1.4, strokePaint(const Color(0xFF000000).withValues(alpha: .35), 1.4));
  } else {
    // Mail gets a plate gorget and a leather baldric across it.
    final a = pt(-.55, .05), e = pt(.6, .5);
    c.drawLine(a, e, strokePaint(const Color(0xFF3A2414), 6));
    c.drawLine(a, e, strokePaint(const Color(0xFF6A4628), 3.5));
    for (final f in const [.25, .55, .8]) {
      c.drawCircle(Offset.lerp(a, e, f)!, 1.5, Paint()..color = const Color(0xFFD8C9A0));
    }
  }
  // The gorget at the throat: a curved collar of plate with a highlighted lip.
  final gl = pt(-.55, -.02), gm = pt(.05, .12), gr = pt(.6, .02);
  final collar = Path()
    ..moveTo(gl.dx, gl.dy)
    ..quadraticBezierTo(gm.dx, gm.dy + 8, gr.dx, gr.dy);
  c.drawPath(collar, strokePaint(shade(m[2], -.25), 9));
  c.drawPath(collar, strokePaint(m[1], 6.5));
  c.drawPath(collar.shift(const Offset(0, -2)), strokePaint(shade(m[0], .3).withValues(alpha: .9), 1.4));
  for (final r in [gl + const Offset(3, 1), gr - const Offset(3, -1)]) {
    c.drawCircle(r, 1.7, Paint()..color = shade(m[2], -.2));
    c.drawCircle(r - const Offset(.5, .6), .7, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .85));
  }
  if (plate) {
    // Engraved scrollwork either side of the ridge: two mirrored scrolls ending in curls.
    final w = fine >= 2 ? 1.4 : 1.0, line = strokePaint(ink.withValues(alpha: fine >= 2 ? .95 : .7), w);
    for (final side in const [-1.0, 1.0]) {
      final s0 = pt(.08 + side * .06, .14), s1 = pt(.08 + side * .5, .08), s2 = pt(.08 + side * .55, .3), s3 = pt(.08 + side * .3, .27);
      final scroll = Path()
        ..moveTo(s0.dx, s0.dy)
        ..cubicTo(s1.dx, s1.dy, s2.dx, s2.dy, s3.dx, s3.dy);
      c.drawPath(scroll, line);
      c.drawCircle(s3 + sk.forward * (side * 1.6), 2.2, line);
      if (fine >= 2) {
        // A second line inside the first, and little leaves along it: gilt filigree.
        c.drawPath(scroll.shift(const Offset(0, 2.4)), strokePaint(ink.withValues(alpha: .55), .8));
        for (final f in const [.35, .65]) {
          final q = Offset.lerp(Offset.lerp(s0, s1, f)!, Offset.lerp(s2, s3, f)!, f)!;
          c.save();
          c.translate(q.dx, q.dy);
          c.rotate(side * .7);
          c.drawOval(Rect.fromCenter(center: const Offset(0, -2.2), width: 2.4, height: 4.4), Paint()..color = ink);
          c.restore();
        }
      }
    }
    if (fine >= 3) {
      // The ember sigil over the heart: a small flame in a ring, breathing with a soft glow.
      final at = pt(.1, .22), pulse = still ? .8 : .6 + .4 * math.sin(t / 450);
      c.drawCircle(at, 9, Paint()..color = const Color(0xFFFF8A3A).withValues(alpha: .35 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      c.drawCircle(at, 5.6, strokePaint(ink, 1.3));
      final flame = Path()
        ..moveTo(at.dx, at.dy + 3.6)
        ..quadraticBezierTo(at.dx - 3.2, at.dy + 1.5, at.dx - 1, at.dy - 1.6)
        ..quadraticBezierTo(at.dx, at.dy - 3.6, at.dx + .4, at.dy - 4.2)
        ..quadraticBezierTo(at.dx + 3.4, at.dy, at.dx, at.dy + 3.6)
        ..close();
      c.drawPath(flame, Paint()..color = Color.lerp(const Color(0xFFFF7A2A), const Color(0xFFFFE08A), pulse)!);
    }
  }
  if (look.blackIron) _blackIron(c, sk, look, path, plate);
  c.restore();
  // A crisp outline, so the armour reads sharp against any background.
  c.drawPath(path, strokePaint(const Color(0xE6100B07), 1.8));
}

/// Blackened iron, inside the torso clip: a warm ember glint from below (the fire it came out
/// of), cold bright edges, and on plate a skirt of overlapping lames at the waist held with brass
/// rivets.
void _blackIron(Canvas c, Skeleton sk, Look look, Path path, bool plate) {
  final b = sk.build, m = look.torso, bounds = path.getBounds();
  const brass = Color(0xFFC9A24E);
  // Soot scorched up the plate from below, as the fire left it.
  c.drawRect(
    bounds,
    Paint()..shader = ui.Gradient.linear(Offset(0, bounds.bottom), Offset(0, bounds.top), [const Color(0x9914100E), const Color(0x0014100E)], const [0, .7]),
  );
  // Embers reflected up from below.
  c.drawRect(
    bounds,
    Paint()..shader = ui.Gradient.linear(Offset(0, bounds.bottom), Offset(0, bounds.top), [const Color(0x40FF7A2A), const Color(0x00FF7A2A)], const [0, .55]),
  );
  // A cold rim of light down the front edge, where iron meets the sky.
  c.drawPath(path.shift(sk.forward * -1.5), strokePaint(const Color(0x59C8D2DC), 2));
  if (!plate) return;
  // Three lames across the belly, each overlapping the one below.
  for (var i = 0; i < 3; i++) {
    final up = .62 + i * .13;
    final l = sk.at(sk.chest, -b.chest * .8, -b.spine * up), r = sk.at(sk.chest, b.chest * .8, -b.spine * up);
    final mid = Offset.lerp(l, r, .5)! + sk.up * -4;
    final lip = Path()
      ..moveTo(l.dx, l.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, r.dx, r.dy);
    c.drawPath(lip.shift(const Offset(0, 1.6)), strokePaint(shade(m[2], -.4), 2.6));
    c.drawPath(lip, strokePaint(shade(m[0], .15).withValues(alpha: .85), 1.1));
    for (final f in const [.12, .88]) {
      final q = Offset.lerp(l, r, f)! + const Offset(0, 3);
      c.drawCircle(q, 1.5, Paint()..color = shade(brass, -.35));
      c.drawCircle(q - const Offset(.4, .4), .8, Paint()..color = brass);
    }
  }
  // The survivor's crest etched over the heart in gilt: a flame in a shield.
  final em = sk.at(sk.chest, b.chest * .2, -b.spine * .36);
  c.save();
  c.translate(em.dx, em.dy);
  c.rotate(sk.lean * deg);
  final gilt = strokePaint(const Color(0xE6E8C060), 1.1);
  c.drawPath(
    Path()
      ..moveTo(-6, -7)
      ..lineTo(6, -7)
      ..lineTo(6, 1)
      ..quadraticBezierTo(6, 7, 0, 10)
      ..quadraticBezierTo(-6, 7, -6, 1)
      ..close(),
    gilt,
  );
  c.drawPath(
    Path()
      ..moveTo(0, 6)
      ..quadraticBezierTo(-4, 4, -3, 0)
      ..quadraticBezierTo(-2, -2, -.5, -4.5)
      ..quadraticBezierTo(.5, -1.5, 1.2, -1)
      ..quadraticBezierTo(2, -3, 2.6, -4.5)
      ..quadraticBezierTo(4.4, 0, 3, 2.6)
      ..quadraticBezierTo(2, 5.5, 0, 6),
    gilt,
  );
  c.restore();
  // Brass rivets down the front edge of the breastplate.
  for (var i = 0; i < 4; i++) {
    final q = sk.at(sk.chest, b.chest * .5, -b.spine * (.12 + i * .12));
    c.drawCircle(q, 1.4, Paint()..color = shade(brass, -.35));
    c.drawCircle(q - const Offset(.4, .4), .7, Paint()..color = brass);
  }
}

/// A demon's tail, curling out behind with a barbed tip.
void _tail(Canvas c, Skeleton sk, Ramp col, double t, bool still) {
  final root = sk.at(sk.pelvis, -sk.build.hip * .6, 0);
  final swish = still ? 0.0 : math.sin(t / 420) * 12;
  final mid = root + Offset(-50, 24 + swish * .5), tip = root + Offset(-70, -30 + swish);
  final path = Path()
    ..moveTo(root.dx, root.dy)
    ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
  c.drawPath(path, strokePaint(outline, 7)..strokeCap = StrokeCap.round);
  c.drawPath(path, strokePaint(col[1], 4.6)..strokeCap = StrokeCap.round);
  final barb = poly([tip + const Offset(-8, 4), tip + const Offset(2, -14), tip + const Offset(8, 4), tip]);
  fillPath(c, barb, col, tip + const Offset(-8, -14), tip + const Offset(8, 4));
}

/// Stone bat wings rising from the shoulders, half-spread, with finger bones.
void _wings(Canvas c, Skeleton sk, Ramp stone, double t, bool still, {bool feathered = false}) {
  final b = sk.build, root = sk.at(sk.chest, -b.chest * .45, -4);
  final flex = still ? 0.0 : math.sin(t / 700) * 6;
  if (feathered) {
    // A bird's wings: long flight feathers fanned up and back, two layers.
    for (final (side, dark) in [(1.0, -.25), (.8, 0.0)]) {
      final col = [for (final x in stone) shade(x, dark)];
      for (var i = 0; i < 8; i++) {
        final a = math.pi + .5 + i * .16, len = (70.0 + i * 7) * side;
        final tip = root + Offset(math.cos(a) * len, math.sin(a) * len - flex * (i / 8));
        final dir = tip - root, n = Offset(-dir.dy, dir.dx) / dir.distance;
        final f = Path()
          ..moveTo(root.dx, root.dy)
          ..quadraticBezierTo(root.dx + dir.dx * .55 + n.dx * 7, root.dy + dir.dy * .55 + n.dy * 7, tip.dx, tip.dy)
          ..quadraticBezierTo(root.dx + dir.dx * .55 - n.dx * 7, root.dy + dir.dy * .55 - n.dy * 7, root.dx, root.dy)
          ..close();
        fillPath(c, f, col, tip, root, width: 1);
      }
    }
    return;
  }
  for (final (side, shade_) in [(1.0, -.25), (.75, 0.0)]) {
    final tip = root + Offset(-90 * side, -70 - flex);
    final mid = root + Offset(-60 * side, -96 - flex * .6);
    final low = root + Offset(-100 * side, 10);
    final membrane = Path()
      ..moveTo(root.dx, root.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(tip.dx, tip.dy)
      ..quadraticBezierTo(tip.dx + 8 * side, tip.dy + 40, low.dx, low.dy)
      ..quadraticBezierTo(root.dx - 50 * side, root.dy + 10, root.dx - 30 * side, root.dy + 34)
      ..close();
    final col = [for (final x in stone) shade(x, shade_)];
    fillPath(c, membrane, col, tip, root);
    final bone = strokePaint(shade(col[2], -.2), 3)..strokeCap = StrokeCap.round;
    c.drawLine(root, mid, bone);
    c.drawLine(mid, tip, bone);
    c.drawLine(mid, low, bone);
    c.drawLine(mid, Offset.lerp(low, root, .5)! + Offset(-10 * side, 20), bone);
    c.drawPath(poly([tip, tip + Offset(-6 * side, -10), tip + Offset(4 * side, -4)]), Paint()..color = col[1]);
  }
}

void _cape(Canvas c, Skeleton sk, Look look, Color colour, double t, bool still) {
  final b = sk.build, sway = still ? 0.0 : math.sin(t / 900) * 6;
  final a = sk.at(sk.chest, -b.chest * .55, -2), e = sk.at(sk.chest, b.chest * .1, 1);
  final groundY = math.max(sk.legNear.ankle.dy, sk.legFar.ankle.dy) + 4;
  final back = sk.pelvis.dx - b.hip * 2.2 - look.capeFlow + sway, mid = sk.pelvis.dx - b.hip * 1.2 + sway * .5;
  final path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(e.dx, e.dy)
    ..quadraticBezierTo(sk.pelvis.dx - b.hip * .2, sk.pelvis.dy, sk.pelvis.dx - b.hip * .6 + sway * .3, groundY - 16);
  if (look.tattered) {
    var x = sk.pelvis.dx - b.hip * .6 + sway * .3;
    for (var i = 0; i < 5; i++) {
      path.lineTo(x - 6, groundY - 4 - (i % 2) * 10);
      x -= (x - back) / (5 - i);
      path.lineTo(x, groundY - 14);
    }
  } else {
    path.quadraticBezierTo(mid, groundY + 2, back, groundY - 8);
  }
  path
    ..quadraticBezierTo(back + 10, sk.pelvis.dy - 20, a.dx, a.dy)
    ..close();
  fillPath(c, path, [shade(colour, .12), colour, shade(colour, -.55)], Offset(back, 0), Offset(a.dx + 10, 0));
  c.drawPath(
    Path()
      ..moveTo(a.dx + 4, a.dy + 10)
      ..quadraticBezierTo(mid - 4, sk.pelvis.dy, mid - 6, groundY - 14),
    strokePaint(const Color(0x47000000), 3),
  );
  if (look.kitDetail) {
    c.save();
    c.clipPath(path);
    // Deep folds fanning from the shoulders, each with a lit ridge beside its shadow.
    for (final (k, w) in const [(.25, 4.0), (.5, 5.0), (.75, 3.5)]) {
      final x = a.dx + (back - a.dx) * k;
      final fold = Path()
        ..moveTo(a.dx - 2 - k * 6, a.dy + 6)
        ..quadraticBezierTo(x + 6, sk.pelvis.dy - 10, x + sway * k, groundY);
      c.drawPath(fold, strokePaint(shade(colour, -.6).withValues(alpha: .5), w));
      c.drawPath(fold.shift(const Offset(3, 0)), strokePaint(shade(colour, .35).withValues(alpha: .3), 1.4));
    }
    // The lining showing at the leading edge, and a darker hem.
    c.drawPath(
      Path()
        ..moveTo(e.dx, e.dy)
        ..quadraticBezierTo(sk.pelvis.dx - b.hip * .2, sk.pelvis.dy, sk.pelvis.dx - b.hip * .6 + sway * .3, groundY - 16),
      strokePaint(const Color(0xFF2A1A12), 4),
    );
    c.drawRect(Rect.fromLTRB(back - 20, groundY - 12, a.dx + 40, groundY + 10), Paint()..color = shade(colour, -.5).withValues(alpha: .35));
    c.restore();
  }
}

void _shield(Canvas c, Arm a, ShieldLook s) => drawShield(c, a.hand + const Offset(4, -4), (a.foreAngle - 90) * .25, s);

/// A shield centred at [at], tilted by [tiltDeg].
void drawShield(Canvas c, Offset at, double tiltDeg, ShieldLook s) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(tiltDeg * deg);
  final field = [shade(s.field, .22), s.field, shade(s.field, -.45)];
  switch (s.kind) {
    case ShieldKind.round:
      final p = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 30));
      fillPath(c, p, field, const Offset(-30, -30), const Offset(30, 30), width: 2);
      c.save();
      c.clipPath(p);
      final plank = strokePaint(const Color(0x4D000000), 1.2);
      for (var i = -2; i <= 2; i++) {
        c.drawLine(Offset(i * 11.0, -30), Offset(i * 11.0, 30), plank);
      }
      c.restore();
      c.drawCircle(Offset.zero, 28, strokePaint(const Color(0xFF6E737A), 4));
      blob(c, Offset.zero, 8, ramp(0xFF9AA0A8));
    case ShieldKind.buckler:
      final p = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 17));
      fillPath(c, p, const [Color(0xFFE6EAEE), Color(0xFF9AA3AE), Color(0xFF3E454F)], const Offset(-17, -17), const Offset(17, 17), width: 1.8);
      c.drawCircle(Offset.zero, 12, strokePaint(s.field, 3));
      blob(c, Offset.zero, 6, _goldRamp);
    case ShieldKind.tower:
      final rect = RRect.fromRectAndCorners(
        const Rect.fromLTWH(-25, -50, 50, 102),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
      );
      final p = Path()..addRRect(rect);
      fillPath(c, p, field, const Offset(-25, -50), const Offset(25, 52), width: 2);
      c.save();
      c.clipPath(p);
      c.drawRect(const Rect.fromLTWH(-25, -50, 50, 16), Paint()..color = const Color(0x29FFFFFF));
      final band = Paint()..color = shade(s.field, .35);
      c.drawRect(const Rect.fromLTWH(-4, -50, 8, 102), band);
      c.drawRect(const Rect.fromLTWH(-25, -6, 50, 8), band);
      c.restore();
      c.drawRRect(rect.deflate(1.5), strokePaint(s.trim, 3));
      for (final q in const [Offset(-18, -42), Offset(18, -42), Offset(-18, 42), Offset(18, 42)]) {
        c.drawCircle(q, 2.2, Paint()..color = s.trim);
      }
    case ShieldKind.dragon:
      // A dragonslayer's heater: blackened steel with winged top corners, a panel of the dragon's
      // own scales, and its head run through by a sword. Dark fields get a gold head instead.
      Path heater(double sx, double sy, double dy) => Path()
        ..moveTo(-31 * sx, -38 * sy + dy)
        ..quadraticBezierTo(-14 * sx, -29 * sy + dy, 0, -33 * sy + dy)
        ..quadraticBezierTo(14 * sx, -29 * sy + dy, 31 * sx, -38 * sy + dy)
        ..cubicTo(33 * sx, -4 * sy + dy, 22 * sx, 28 * sy + dy, 0, 50 * sy + dy)
        ..cubicTo(-22 * sx, 28 * sy + dy, -33 * sx, -4 * sy + dy, -31 * sx, -38 * sy + dy)
        ..close();
      final p = heater(1, 1, 0);
      fillPath(c, p, const [Color(0xFF7A7E88), Color(0xFF383A42), Color(0xFF15161A)], const Offset(-30, -38), const Offset(30, 50), width: 2);
      final inner = heater(.78, .8, 1.5);
      fillPath(c, inner, [shade(s.field, .25), s.field, shade(s.field, -.5)], const Offset(-24, -30), const Offset(24, 40), line: false);
      c.save();
      c.clipPath(inner);
      final scaleEdge = strokePaint(shade(s.field, -.55).withValues(alpha: .55), .8);
      for (var row = 0; row < 10; row++) {
        for (var col = 0; col < 7; col++) {
          final o = Offset(-30 + col * 9.0 + (row.isOdd ? 4.5 : 0), -32 + row * 8.0);
          c.drawArc(Rect.fromCenter(center: o, width: 9, height: 7), 0, math.pi, false, scaleEdge);
        }
      }
      c.drawRect(const Rect.fromLTRB(-30, -34, 30, -22), Paint()..color = const Color(0x22FFFFFF));
      c.restore();
      c.drawPath(inner, strokePaint(s.trim, 1.6));
      c.drawPath(inner, strokePaint(const Color(0x99000000), .6));
      const steel = [Color(0xFFF4F6F8), Color(0xFFB8C0CA), Color(0xFF5A626E)];
      fillPath(c, poly(const [Offset(-2.6, -17), Offset(2.6, -17), Offset(2.2, 30), Offset(0, 36), Offset(-2.2, 30)]), steel, const Offset(-3, 0), const Offset(3, 0), width: 1);
      // The head in profile, facing out: long snout, open jaws, two horns swept back.
      final head = Path()
        ..moveTo(-24, -2)
        ..quadraticBezierTo(-23, -5, -19, -5)
        ..quadraticBezierTo(-12, -5, -6, -7)
        ..lineTo(-1, -12)
        ..quadraticBezierTo(8, -13, 24, -21)
        ..quadraticBezierTo(14, -9, 11, -7)
        ..lineTo(21, -11)
        ..quadraticBezierTo(15, -3, 12, 0)
        ..quadraticBezierTo(17, 8, 12, 15)
        ..quadraticBezierTo(9, 21, 12, 28)
        ..lineTo(4, 26)
        ..quadraticBezierTo(2, 18, 4, 11)
        ..lineTo(-2, 13)
        ..lineTo(-4, 8.5)
        ..quadraticBezierTo(-12, 9, -20, 8)
        ..lineTo(-15, 4.6)
        ..lineTo(-6, 3.4)
        ..lineTo(-23, 1)
        ..close();
      final dark = s.field.computeLuminance() > .14 ? shade(s.field, -.78) : shade(s.trim, -.05);
      fillPath(c, head, [shade(dark, .25), dark, shade(dark, -.45)], const Offset(-20, -12), const Offset(18, 22), width: 1.2);
      for (final q in const [Offset(16, 5), Offset(15.5, 12), Offset(12.5, 19)]) {
        fillPath(c, poly([q + const Offset(-1, -2.5), q + const Offset(4.5, 0), q + const Offset(-1, 2.5)]), dark, Offset.zero, Offset.zero, width: .8);
      }
      for (final x in const [-21.0, -17.0, -13.0, -9.0]) {
        c.drawPath(poly([Offset(x, 1.2), Offset(x + 1.1, 3.8), Offset(x + 2.1, 1.5)]), Paint()..color = const Color(0xFFF0E8D4));
      }
      c.drawCircle(const Offset(-4, -5.5), 4, Paint()..color = const Color(0xAAFF7A2A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      c.drawPath(poly(const [Offset(-8, -5), Offset(-.5, -8.2), Offset(-2.5, -4.4)]), Paint()..color = const Color(0xFFFFC04A));
      // The hilt above the head, and the blade again below its jaw: run through.
      fillPath(c, poly(const [Offset(-12, -19), Offset(12, -19), Offset(10, -15), Offset(-10, -15)]), rampOf(s.trim, .35, .45), const Offset(0, -19), const Offset(0, -15), width: 1);
      fillPath(c, poly(const [Offset(-1.8, -27), Offset(1.8, -27), Offset(1.8, -19), Offset(-1.8, -19)]), const [Color(0xFF6A4A30), Color(0xFF4A3020), Color(0xFF2A1A10)], const Offset(-2, 0), const Offset(2, 0), width: .8);
      c.drawCircle(const Offset(0, -28.5), 2.8, Paint()..color = s.trim);
      c.drawCircle(const Offset(0, -28.5), 2.8, strokePaint(outline, .8));
      fillPath(c, poly(const [Offset(-2.4, 8), Offset(2.4, 8), Offset(2.2, 30), Offset(0, 36), Offset(-2.2, 30)]), steel, const Offset(-3, 0), const Offset(3, 0), width: 1);
      for (final q in const [Offset(-26, -30), Offset(26, -30), Offset(-24, 6), Offset(24, 6), Offset(0, 43), Offset(-12, -30.5), Offset(12, -30.5)]) {
        c.drawCircle(q, 1.6, Paint()..color = const Color(0xFFB0B4BC));
        c.drawCircle(q, 1.6, strokePaint(outline, .6));
      }
      c.drawPath(p, strokePaint(const Color(0x55FFFFFF), .8));
    case ShieldKind.kite:
      final p = Path()
        ..moveTo(-26, -34)
        ..lineTo(26, -34)
        ..quadraticBezierTo(30, 6, 0, 46)
        ..quadraticBezierTo(-30, 6, -26, -34)
        ..close();
      fillPath(c, p, field, const Offset(-26, -34), const Offset(26, 46), width: 2);
      c.save();
      c.clipPath(p);
      c.drawRect(const Rect.fromLTWH(-26, -34, 52, 14), Paint()..color = const Color(0x29FFFFFF));
      final cross = Paint()..color = shade(s.field, .35);
      c.drawRect(const Rect.fromLTWH(-4, -34, 8, 80), cross);
      c.drawRect(const Rect.fromLTWH(-26, -12, 52, 8), cross);
      c.restore();
      c.drawPath(p, strokePaint(s.trim, 3));
  }
  c.restore();
}

/// A robe skirt from the waist to mid-shin that follows the legs.
void _skirt(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, col = look.skirt!;
  Offset hem(Leg l, double off) => Offset.lerp(l.knee, l.ankle, .62)! + Offset(off, 0);
  final wb = sk.at(sk.pelvis, -b.hip * .75, b.spine * .22), wf = sk.at(sk.pelvis, b.hip * .75, b.spine * .22);
  final front = sk.legNear.knee.dx > sk.legFar.knee.dx ? sk.legNear : sk.legFar;
  final back = identical(front, sk.legNear) ? sk.legFar : sk.legNear;
  // The hem reaches past both knees, so a striding leg never pokes out of the robe's side.
  var hf = hem(front, 13), hb = hem(back, -13);
  hf = Offset(math.max(hf.dx, front.knee.dx + 13), hf.dy);
  hb = Offset(math.min(hb.dx, back.knee.dx - 13), hb.dy);
  final fx = math.max(hf.dx, front.knee.dx + 14) + 2, bx = math.min(hb.dx, back.knee.dx - 14) - 4;
  final mid = Offset((hf.dx + hb.dx) / 2, math.max(hf.dy, hb.dy) + 6);
  final path = Path()
    ..moveTo(wb.dx, wb.dy)
    ..lineTo(wf.dx, wf.dy)
    ..quadraticBezierTo(fx, (wf.dy + hf.dy) / 2, hf.dx, hf.dy);
  if (look.tattered) {
    // A ragged hem: torn into tongues of cloth.
    for (var i = 1; i <= 6; i++) {
      final q = Offset.lerp(hf, hb, i / 6)!;
      path
        ..lineTo(q.dx + (hb.dx - hf.dx) / 12, q.dy + (i.isEven ? 10 : 2))
        ..lineTo(q.dx, q.dy - 4);
    }
  } else {
    path.quadraticBezierTo(mid.dx, mid.dy, hb.dx, hb.dy);
  }
  path
    ..quadraticBezierTo(bx, (wb.dy + hb.dy) / 2, wb.dx, wb.dy)
    ..close();
  fillPath(c, path, col, Offset(hb.dx, 0), Offset(hf.dx, 0));
  final fold = strokePaint(const Color(0x40000000), 1.4);
  for (final k in const [.35, .65]) {
    final top = Offset.lerp(wb, wf, k)!, bottom = Offset.lerp(hb, hf, k)!;
    c.drawLine(top + const Offset(0, 8), bottom - const Offset(0, 4), fold);
  }
  final trim = look.trim;
  if (trim != null) {
    c.drawPath(
      Path()
        ..moveTo(hf.dx, hf.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, hb.dx, hb.dy),
      strokePaint(trim, 3),
    );
  }
}

void _quiver(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, col = look.quiver!;
  final top = sk.at(sk.chest, -b.chest * .85, 18), bottom = sk.at(sk.pelvis, -b.hip * 1.35, b.spine * .28);
  final fletch = [const Color(0xFFE8DCC4), look.cape ?? const Color(0xFF9A2A22), const Color(0xFFE8DCC4)];
  for (var i = 0; i < 3; i++) {
    final base = top + sk.forward * (i * 4.0 - 4);
    final tip = base + (top - bottom) / (top - bottom).distance * 16 + sk.forward * (i - 1) * 3;
    c.drawLine(base, tip, strokePaint(const Color(0xFF6E4C31), 1.6));
    c.drawPath(poly([tip, tip + const Offset(-4, 6), tip + const Offset(4, 6)]), Paint()..color = fletch[i]);
  }
  capsule(c, top, 8.5, bottom, 7, [shade(col, .25), col, shade(col, -.5)]);
  c.drawLine(Offset.lerp(top, bottom, .15)! - sk.forward * 7, Offset.lerp(top, bottom, .15)! + sk.forward * 7, strokePaint(shade(col, -.4), 2));
}

Offset _toLocal(Offset at, double angleDeg, Offset w) {
  final a = angleDeg * deg, d = w - at;
  return Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a));
}

Offset _toWorld(Offset at, double angleDeg, Offset l) {
  final a = -angleDeg * deg;
  return at + Offset(l.dx * math.cos(a) - l.dy * math.sin(a), l.dx * math.sin(a) + l.dy * math.cos(a));
}

/// The bow string, pulled to the far hand while drawing, with a nocked arrow.
void _bowString(Canvas c, Skeleton sk, double angle, double half, {double? upper}) {
  final h = sk.armNear.hand, fh = sk.armFar.hand;
  final a = _toWorld(h, angle, Offset(-(upper ?? half), -6)), e = _toWorld(h, angle, Offset(half, -6));
  final local = _toLocal(h, angle, fh);
  final string = strokePaint(const Color(0xFFE8E0CC), 1.1);
  if (local.dy < -10 && local.dx.abs() < 30) {
    c.drawLine(a, fh, string);
    c.drawLine(fh, e, string);
    final tip = _toWorld(h, angle, const Offset(0, 24));
    c.drawLine(fh, tip, strokePaint(const Color(0xFF8A6440), 2));
    c.drawPath(poly([tip + (tip - fh) / (tip - fh).distance * 7, tip + Offset((tip - fh).dy, -(tip - fh).dx) / (tip - fh).distance * 3, tip - Offset((tip - fh).dy, -(tip - fh).dx) / (tip - fh).distance * 3]), Paint()..color = const Color(0xFFC3CBD4));
  } else {
    c.drawLine(a, e, string);
  }
}

const _goldRamp = <Color>[Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
const _gripRamp = <Color>[Color(0xFF6E4C31), Color(0xFF3A2516), Color(0xFF1A0F08)];
const _woodRamp = <Color>[Color(0xFF9A7048), Color(0xFF6B4A2E), Color(0xFF2E1E10)];
const _silverRamp = <Color>[Color(0xFFF2F4F6), Color(0xFFAEB6C0), Color(0xFF545C66)];

/// Glowing runes carved along a blade, a bow's limbs or a staff.
void _runes(Canvas c, Offset at, double angleDeg, Weapon shape, double t, bool still) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(-angleDeg * deg);
  final pulse = still ? 1.0 : .75 + .25 * math.sin(t / 300);
  final glow = Paint()
    ..color = const Color(0xFF7FE0FF).withValues(alpha: .6 * pulse)
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final line = Paint()
    ..color = const Color(0xFFE6FBFF).withValues(alpha: .95)
    ..strokeWidth = 1.3
    ..style = PaintingStyle.stroke;
  // Small angular glyphs, each a different shape.
  Path glyph(Offset o, int n, double s) {
    final p = Path()..moveTo(o.dx, o.dy - s);
    switch (n % 4) {
      case 0:
        p
          ..lineTo(o.dx, o.dy + s)
          ..moveTo(o.dx - s * .6, o.dy - s * .3)
          ..lineTo(o.dx + s * .6, o.dy + s * .2);
      case 1:
        p
          ..lineTo(o.dx + s * .6, o.dy)
          ..lineTo(o.dx, o.dy + s)
          ..lineTo(o.dx - s * .6, o.dy);
      case 2:
        p
          ..lineTo(o.dx, o.dy + s)
          ..moveTo(o.dx, o.dy - s * .2)
          ..lineTo(o.dx + s * .7, o.dy - s * .8);
      default:
        p
          ..lineTo(o.dx - s * .5, o.dy + s)
          ..moveTo(o.dx, o.dy - s)
          ..lineTo(o.dx + s * .5, o.dy + s);
    }
    return p;
  }

  final spots = switch (shape) {
    Weapon.longbow => [for (var i = 0; i < 6; i++) Offset(-52.0 + i * 21 + (i >= 3 ? 0 : 0), 4.0 + 7 * math.sin((i + .5) / 6 * math.pi))],
    Weapon.staff => [for (var i = 0; i < 6; i++) Offset(0, -34.0 + i * 20)],
    _ => [for (var i = 0; i < 5; i++) Offset(0, 26.0 + i * 18)],
  };
  for (final (i, o) in spots.indexed) {
    final g = glyph(o, i, shape == Weapon.longbow ? 3.2 : 3.8);
    c.drawPath(g, glow);
    c.drawPath(g, line);
  }
  c.restore();
}

/// A living briar along [pts] (weapon-local space): a green-brown vine with thorns, a few leaves,
/// and small flowers at the given distances along it.
void _briar(Canvas c, List<Offset> pts, double t, bool still, {double width = 2.4, List<double> flowers = const []}) {
  final vine = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    vine.lineTo(p.dx, p.dy);
  }
  c.drawPath(vine, strokePaint(const Color(0xFF1E2E14), width + 2)..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  c.drawPath(vine, strokePaint(const Color(0xFF4E7A32), width)..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  c.drawPath(vine, strokePaint(const Color(0x669BD06A), width * .35));
  final thorn = Paint()..color = const Color(0xFFD8CCA0);
  for (var i = 1; i < pts.length - 1; i += 2) {
    final d = pts[i + 1] - pts[i - 1], len = d.distance;
    if (len == 0) continue;
    final n = Offset(-d.dy, d.dx) / len * (i.isEven ? 1.0 : -1.0);
    final base = pts[i], along = d / len;
    c.drawPath(poly([base + along * 1.6, base + n * (width + 3.6), base - along * 1.6]), thorn);
  }
  final leaf = Paint()..color = const Color(0xFF6FA84A);
  for (var i = 3; i < pts.length; i += 6) {
    final p = pts[i];
    c.drawOval(Rect.fromCenter(center: p + Offset(i % 12 == 3 ? 4 : -4, 0), width: 6, height: 3.4), leaf);
  }
  final bloom = still ? 1.0 : .9 + .1 * math.sin(t / 400);
  for (final (i, y) in flowers.indexed) {
    final p = pts.reduce((a, b) => (a.dy - y).abs() < (b.dy - y).abs() ? a : b);
    final petal = Paint()..color = i.isEven ? const Color(0xFFF4B8D0) : const Color(0xFFFFF4F8);
    for (var k = 0; k < 5; k++) {
      final a = k * math.pi * 2 / 5 + i;
      c.drawCircle(p + Offset(math.cos(a), math.sin(a)) * 2.6 * bloom, 2.2, petal);
    }
    c.drawCircle(p, 1.4, Paint()..color = const Color(0xFFF2C14E));
  }
}

/// The glowing stretch of each weapon, in weapon-local space (start, end, width).
(Offset, Offset, double)? _glowSpan(Weapon kind) => switch (kind) {
  Weapon.longsword => (const Offset(0, 14), const Offset(0, 112), 9),
  Weapon.greatsword => (const Offset(0, 14), const Offset(0, 144), 11),
  Weapon.wyrmblade => (const Offset(0, 14), const Offset(0, 150), 13),
  Weapon.kingsfall => (const Offset(0, 16), const Offset(0, 156), 14),
  Weapon.shortsword => (const Offset(0, 12), const Offset(0, 58), 8),
  Weapon.falchion => (const Offset(3, 14), const Offset(3, 92), 12),
  Weapon.dagger => (const Offset(0, 10), const Offset(0, 38), 6),
  Weapon.axe || Weapon.greataxe => (const Offset(20, 64), const Offset(30, 84), 22),
  Weapon.mace => (const Offset(0, 60), const Offset(0, 74), 22),
  Weapon.morningstar => (const Offset(0, 62), const Offset(0, 74), 26),
  Weapon.hammer => (const Offset(-10, 92), const Offset(28, 92), 22),
  Weapon.staff => (const Offset(0, 104), const Offset(0, 116), 18),
  Weapon.crystalstaff => (const Offset(0, 100), const Offset(0, 130), 18),
  Weapon.wand => (const Offset(0, 36), const Offset(0, 44), 10),
  Weapon.sceptre => (const Offset(0, 58), const Offset(0, 68), 18),
  Weapon.bow => (const Offset(-50, -2), const Offset(50, -2), 8),
  Weapon.longbow => (const Offset(-64, -2), const Offset(64, -2), 8),
  Weapon.crossbow => (const Offset(-28, 32), const Offset(28, 32), 9),
  Weapon.handcrossbow => (const Offset(-15, 18), const Offset(15, 18), 7),
  Weapon.orb => (const Offset(8, -24), const Offset(8, -20), 26),
  Weapon.tome => (const Offset(-4, -10), const Offset(14, -10), 16),
  Weapon.dragondagger => (const Offset(0, 10), const Offset(0, 46), 9),
  Weapon.orkclub => (const Offset(0, 50), const Offset(0, 90), 24),
  Weapon.halberd => (const Offset(0, 96), const Offset(0, 128), 22),
  Weapon.spear => (const Offset(0, 100), const Offset(0, 124), 12),
  Weapon.scimitar => (const Offset(4, 14), const Offset(10, 90), 12),
  Weapon.chakram => (const Offset(10, -6), const Offset(10, -6), 30),
  Weapon.throwingknives => (const Offset(6, -14), const Offset(14, -22), 14),
  Weapon.handcannon => (const Offset(0, 40), const Offset(0, 56), 14),
  Weapon.cannon => (const Offset(0, 60), const Offset(0, 84), 22),
  Weapon.orkbow => (const Offset(-60, -2), const Offset(60, -2), 9),
  Weapon.orkstaff => (const Offset(0, 100), const Offset(0, 124), 20),
  Weapon.dragonstaff => (const Offset(0, 100), const Offset(0, 128), 22),
  Weapon.heartmaul => (const Offset(0, 80), const Offset(0, 104), 30),
  Weapon.runeblade => (const Offset(0, 14), const Offset(0, 112), 9),
  Weapon.runebow => (const Offset(-64, -2), const Offset(64, -2), 8),
  Weapon.runestaff => (const Offset(0, 104), const Offset(0, 116), 18),
  Weapon.heartbow => (const Offset(-62, -2), const Offset(62, -2), 9),
  Weapon.livingstaff => (const Offset(0, 100), const Offset(0, 128), 22),
  Weapon.trident => (const Offset(0, 104), const Offset(0, 140), 26),
  Weapon.hook => (const Offset(0, 40), const Offset(10, 70), 18),
  Weapon.sickle => (const Offset(-6, 34), const Offset(-24, 66), 16),
  Weapon.scythe => (const Offset(-10, 118), const Offset(-50, 112), 18),
  Weapon.whip => (const Offset(0, 30), const Offset(10, 112), 10),
  Weapon.flail => (const Offset(0, 74), const Offset(0, 92), 22),
  Weapon.tomahawk => (const Offset(4, 50), const Offset(14, 66), 18),
  Weapon.thornblade => (const Offset(0, 14), const Offset(0, 112), 9),
  Weapon.flamberge => (const Offset(0, 14), const Offset(0, 118), 11),
  Weapon.frostbrand => (const Offset(0, 14), const Offset(0, 116), 12),
  Weapon.dawnblade => (const Offset(0, 14), const Offset(0, 116), 12),
  Weapon.shadowblade => (const Offset(0, 14), const Offset(0, 116), 11),
  Weapon.rapier => (const Offset(0, 12), const Offset(0, 118), 5),
  Weapon.glaive => (const Offset(0, 104), const Offset(4, 146), 14),
  Weapon.cleaver => (const Offset(0, 16), const Offset(0, 132), 22),
  Weapon.katana => (const Offset(0, 10), const Offset(8, 108), 7),
  Weapon.wakizashi => (const Offset(0, 10), const Offset(5, 66), 7),
  Weapon.naginata => (const Offset(0, 108), const Offset(-2, 150), 12),
  Weapon.kanabo => (const Offset(0, 30), const Offset(0, 104), 18),
  Weapon.yumi => (const Offset(-92, -2), const Offset(52, -2), 8),
  Weapon.shuriken => (const Offset(6, -10), const Offset(15, -18), 16),
  Weapon.shakujo => (const Offset(0, 104), const Offset(0, 130), 22),
  Weapon.fan => (const Offset(-6, -14), const Offset(22, -14), 22),
  _ => null,
};

/// Draws a weapon held at [at], pointing along [angleDeg] (same convention as limb angles).
/// [glow] adds an element aura (poison, fire, frost, holy); legendary looks add drifting sparks.
void drawWeapon(Canvas c, Offset at, double angleDeg, Weapon kind, Look look, {double t = 0, Color? glow, bool still = false, Color? tint, Color? rarity}) {
  if (kind.shape != kind) {
    // Rune-engraved: the weapon in pale runesteel or silverwood, then its runes, glowing.
    drawWeapon(c, at, angleDeg, kind.shape, look, t: t, glow: glow, still: still, tint: const Color(0xFFB8C8E0), rarity: rarity);
    _runes(c, at, angleDeg, kind.shape, t, still);
    return;
  }
  if (kind == Weapon.thornblade) {
    // The elves' Thornbloom: a pale longsword with a flowering briar wound up the blade.
    drawWeapon(c, at, angleDeg, Weapon.longsword, look, t: t, glow: glow, still: still, tint: tint ?? const Color(0xFFD8E8D0), rarity: rarity);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-angleDeg * deg);
    _briar(c, [for (var y = 8.0; y <= 104; y += 4) Offset(5.5 * math.sin(y / 9), y)], t, still, flowers: const [26, 58, 90]);
    c.restore();
    return;
  }
  c.save();
  c.translate(at.dx, at.dy);
  // Tomes, orbs and things held in the palm stay upright whatever the wrist does.
  if (!const {Weapon.tome, Weapon.orb, Weapon.chakram, Weapon.throwingknives, Weapon.shuriken, Weapon.fan}.contains(kind)) c.rotate(-angleDeg * deg);
  final span = _glowSpan(kind);
  // A soft highlight in the weapon's rarity colour (green, blue, purple, orange), under any element.
  if (rarity != null && span != null) {
    c.drawLine(
      span.$1,
      span.$2,
      Paint()
        ..color = rarity.withValues(alpha: .45)
        ..strokeWidth = span.$3 + 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
  if (glow != null && span != null) {
    final pulse = still ? 1.0 : .8 + .2 * math.sin(t / 260);
    c.drawLine(
      span.$1,
      span.$2,
      Paint()
        ..color = glow.withValues(alpha: .55 * pulse)
        ..strokeWidth = span.$3 + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }
  final wooden = const {Weapon.staff, Weapon.wand, Weapon.bow, Weapon.longbow}.contains(kind);
  final wood = wooden && tint != null ? rampOf(tint, .3, .55) : _woodRamp;
  final steel = tint != null && !wooden
      ? rampOf(tint, .45, .5)
      : look.poisoned && glow == null
      ? const [Color(0xFFE7FFD8), Color(0xFF8FD36A), Color(0xFF3E7A2A)]
      : look.rusty
      ? const [Color(0xFFB9ADA0), Color(0xFF8A7A6A), Color(0xFF4A3A2E)]
      : const [Color(0xFFFFFFFF), Color(0xFFC3CBD4), Color(0xFF6E7884)];
  final gem = glow ?? const Color(0xFF7FB8E8);
  switch (kind) {
    case Weapon.longsword || Weapon.greatsword || Weapon.shortsword:
      final len = kind == Weapon.greatsword
          ? 150.0
          : kind == Weapon.shortsword
          ? 62.0
          : 118.0;
      final w = kind == Weapon.greatsword
          ? 6.0
          : kind == Weapon.shortsword
          ? 4.4
          : 5.0;
      final grip = kind == Weapon.greatsword ? -26.0 : -16.0;
      capsule(c, Offset(0, grip), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      _wraps(c, grip + 3, 4, 3.2);
      // Pommel: a ball with a bright cap.
      blob(c, Offset(0, grip - 2.4), 4.6, _goldRamp);
      c.drawCircle(Offset(-1.2, grip - 3.6), 1.4, Paint()..color = const Color(0xCCFFF4C8));
      fillPath(
        c,
        poly([Offset(-w + 1, 10), Offset(w - 1, 10), Offset(w - 1.5, len - 12), Offset(0, len), Offset(-w + 1.5, len - 12)]),
        steel,
        Offset(-w, 0),
        Offset(w, 0),
      );
      // The fuller (a dark groove with a lit lip) and a bright bevel down the edge.
      if (kind != Weapon.shortsword) {
        c.drawLine(const Offset(-.6, 15), Offset(-.6, len * .72), strokePaint(const Color(0x8C3A4A52), 1.8));
        c.drawLine(const Offset(1.1, 15), Offset(1.1, len * .72), strokePaint(const Color(0x66FFFFFF), .8));
      } else {
        c.drawLine(const Offset(0, 14), Offset(0, len - 18), strokePaint(const Color(0x80465A5A), 1.4));
      }
      c.drawPath(
        Path()
          ..moveTo(w - 1.9, 12)
          ..lineTo(w - 2.3, len - 12.5)
          ..lineTo(.4, len - 1.5),
        strokePaint(const Color(0x8CFFFFFF), .9),
      );
      // Crossguard: tapered quillons curling forward at the tips, and a block over the blade.
      final guard = look.rusty ? const [Color(0xFF8A7A6A), Color(0xFF5A4A3A), Color(0xFF2A1E14)] : _goldRamp;
      final q = w * 4;
      fillPath(
        c,
        Path()
          ..moveTo(-q, 9)
          ..quadraticBezierTo(-q - 2, 4, -q + 3, 4.5)
          ..quadraticBezierTo(0, 5.5, q - 3, 4.5)
          ..quadraticBezierTo(q + 2, 4, q, 9)
          ..quadraticBezierTo(0, 12, -q, 9)
          ..close(),
        guard,
        const Offset(0, 4),
        const Offset(0, 11),
      );
      fillPath(c, _rrectPath(Rect.fromCenter(center: const Offset(0, 9.5), width: w * 1.9, height: 7), 1.5), guard, const Offset(0, 6), const Offset(0, 13));
    case Weapon.wyrmblade:
      _wyrmblade(c, steel, look);
    case Weapon.kingsfall:
      _kingsfall(c, t, still);
    case Weapon.falchion:
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      blob(c, const Offset(0, -16), 4.2, _goldRamp);
      final blade = Path()
        ..moveTo(-4, 10)
        ..lineTo(4, 10)
        ..quadraticBezierTo(14, 60, 10, 84)
        ..quadraticBezierTo(6, 96, -3, 98)
        ..quadraticBezierTo(-2, 70, -4, 10)
        ..close();
      fillPath(c, blade, steel, const Offset(-4, 0), const Offset(12, 0));
      c.drawLine(const Offset(-1, 14), const Offset(-1, 86), strokePaint(const Color(0x66465A5A), 1.2));
      fillPath(c, poly(const [Offset(-14, 6), Offset(14, 6), Offset(12, 10), Offset(-12, 10)]), _goldRamp, const Offset(0, 6), const Offset(0, 10));
    case Weapon.dagger:
      capsule(c, const Offset(0, -8), 2.4, const Offset(0, 6), 2.4, const [Color(0xFF5A3A22), Color(0xFF3A2516), Color(0xFF1A0F08)]);
      fillPath(c, poly(const [Offset(-4, 9), Offset(4, 9), Offset(2.6, 34), Offset(0, 40), Offset(-2.6, 34)]), steel, const Offset(-4, 0), const Offset(4, 0));
      fillPath(
        c,
        poly(const [Offset(-8, 6), Offset(8, 6), Offset(7, 10), Offset(-7, 10)]),
        const [Color(0xFFCFD4DA), Color(0xFF8A929C), Color(0xFF40464E)],
        const Offset(0, 6),
        const Offset(0, 10),
      );
    case Weapon.axe || Weapon.greataxe:
      final len = kind == Weapon.greataxe ? 120.0 : 84.0;
      capsule(c, const Offset(0, -20), 3.4, Offset(0, len), 3.6, _woodRamp);
      _wraps(c, -16, 6, 3.6);
      blob(c, const Offset(0, -21), 4.2, const [Color(0xFFCFD4DA), Color(0xFF7A828C), Color(0xFF30363E)]);
      final h = Path()
        ..moveTo(2, len - 30)
        ..quadraticBezierTo(26, len - 40, 34, len - 52)
        ..quadraticBezierTo(44, len - 22, 34, len + 4)
        ..quadraticBezierTo(24, len - 8, 2, len - 12)
        ..close();
      fillPath(c, h, steel, const Offset(2, 0), const Offset(40, 0), width: 1.6);
      // A honed edge, brighter than the head, and the iron socket gripping the haft.
      c.drawPath(
        Path()
          ..moveTo(34.5, len - 49)
          ..quadraticBezierTo(42.5, len - 22, 34.5, len + 1),
        strokePaint(const Color(0xB3FFFFFF), 1.4),
      );
      if (kind == Weapon.greataxe) {
        c.drawPath(
          Path()
            ..moveTo(-28.5, len - 45)
            ..quadraticBezierTo(-34.5, len - 22, -28.5, len - 1),
          strokePaint(const Color(0x99FFFFFF), 1.2),
        );
      }
      fillPath(c, _rrectPath(Rect.fromLTWH(-5, len - 34, 10, 26), 2), const [Color(0xFF9AA2AC), Color(0xFF5A626C), Color(0xFF22282E)], const Offset(-5, 0), const Offset(5, 0));
      for (final y in [len - 30, len - 12]) {
        c.drawCircle(Offset(0, y), 1.3, Paint()..color = const Color(0xFFE0E4EA));
      }
      if (kind == Weapon.greataxe) {
        final h2 = Path()
          ..moveTo(-2, len - 30)
          ..quadraticBezierTo(-22, len - 38, -28, len - 48)
          ..quadraticBezierTo(-36, len - 22, -28, len + 2)
          ..quadraticBezierTo(-20, len - 8, -2, len - 12)
          ..close();
        fillPath(c, h2, steel, const Offset(-34, 0), const Offset(-2, 0), width: 1.6);
      }
    case Weapon.club:
      capsule(c, const Offset(0, -10), 4, const Offset(0, 70), 10, const [Color(0xFF8A6440), Color(0xFF5E4026), Color(0xFF2A1A0C)]);
      final spike = Paint()..color = const Color(0xFF9AA0A8);
      for (final (x, y) in const [(-10.0, 50.0), (10.0, 56.0), (-9.0, 66.0), (9.0, 70.0), (0.0, 78.0)]) {
        c.drawPath(
          Path()
            ..moveTo(x * .7, y)
            ..lineTo(x * 1.5, y - 2)
            ..lineTo(x * .7, y + 4)
            ..close(),
          spike,
        );
      }
    case Weapon.mace:
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 58), 3.4, _gripRamp);
      blob(c, const Offset(0, -16), 4, steel);
      for (final dx in const [-1.0, 1.0]) {
        fillPath(c, poly([const Offset(0, 54), Offset(dx * 14, 58), Offset(dx * 15, 72), const Offset(0, 80)]), steel, const Offset(0, 54), Offset(dx * 15, 70));
      }
      blob(c, const Offset(0, 66), 8, steel);
      c.drawLine(const Offset(0, 56), const Offset(0, 78), strokePaint(const Color(0x59000000), 1.2));
    case Weapon.morningstar:
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 54), 3.4, _woodRamp);
      final spike = Paint()..color = const Color(0xFFDCE0E4);
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5 + .3, d = Offset(math.sin(a), math.cos(a));
        final base = const Offset(0, 66) + d * 9, tip = const Offset(0, 66) + d * 19;
        final n = Offset(-d.dy, d.dx) * 3.4;
        c.drawPath(poly([base + n, tip, base - n]), spike);
        c.drawPath(poly([base + n, tip, base - n]), strokePaint(outline, 1));
      }
      blob(c, const Offset(0, 66), 12, steel);
    case Weapon.hammer:
      capsule(c, const Offset(0, -18), 3.4, const Offset(0, 96), 3.6, _woodRamp);
      final head = RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 80, 34, 24), const Radius.circular(3));
      fillPath(c, Path()..addRRect(head), steel, const Offset(0, 80), const Offset(0, 104), width: 1.6);
      fillPath(c, poly(const [Offset(-14, 84), Offset(-30, 92), Offset(-14, 100)]), steel, const Offset(-30, 0), const Offset(-14, 0));
      c.drawLine(const Offset(20, 82), const Offset(20, 102), strokePaint(const Color(0x66FFFFFF), 2));
      for (final y in const [62.0, 70.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y + 2), strokePaint(const Color(0xFF3A2516), 1.6));
      }
    case Weapon.staff:
      capsule(c, const Offset(0, -50), 3.2, const Offset(0, 102), 3.8, wood);
      c.drawLine(const Offset(-1, -44), const Offset(-.6, 96), strokePaint(wood[2].withValues(alpha: .45), .9)); // grain
      // Bronze bindings at the grip and under the head, and a wrapped hand-hold.
      _wraps(c, -6, 14, 3.5);
      for (final y in const [-8.0, 16.0, 92.0]) {
        fillPath(c, _rrectPath(Rect.fromCenter(center: Offset(0, y), width: 9, height: 3.4), 1.2), _goldRamp, Offset(0, y - 2), Offset(0, y + 2));
      }
      final curl = Path()
        ..moveTo(-2, 100)
        ..cubicTo(-14, 106, -12, 124, 2, 124)
        ..cubicTo(14, 124, 14, 110, 4, 106);
      c.drawPath(curl, strokePaint(outline, 7));
      c.drawPath(curl, strokePaint(wood[1], 4.4));
      _gem(c, const Offset(1, 113), 6, gem, t, still);
    case Weapon.crystalstaff:
      capsule(c, const Offset(0, -50), 2.8, const Offset(0, 98), 3.2, _silverRamp);
      for (final dx in const [-6.0, 6.0]) {
        c.drawLine(Offset(dx * .4, 92), Offset(dx, 104), strokePaint(outline, 4));
        c.drawLine(Offset(dx * .4, 92), Offset(dx, 104), strokePaint(_goldRamp[1], 2.4));
      }
      final crystal = poly(const [Offset(0, 96), Offset(8, 108), Offset(5, 128), Offset(0, 136), Offset(-5, 128), Offset(-8, 108)]);
      fillPath(c, crystal, [shade(gem, .65), shade(gem, .2), shade(gem, -.35)], const Offset(-8, 0), const Offset(8, 0));
      c.drawLine(const Offset(0, 100), const Offset(0, 132), strokePaint(const Color(0x88FFFFFF), 1.4));
    case Weapon.wand:
      capsule(c, const Offset(0, -6), 2.6, const Offset(0, 38), 1.6, tint != null ? wood : const [Color(0xFFD8D0C0), Color(0xFF9A8A6A), Color(0xFF4A3E2A)]);
      capsule(c, const Offset(0, -6), 2.8, const Offset(0, 6), 2.8, _gripRamp);
      _gem(c, const Offset(0, 41), 3.2, gem, t, still);
    case Weapon.sceptre:
      capsule(c, const Offset(0, -10), 2.8, const Offset(0, 52), 3, _goldRamp);
      blob(c, const Offset(0, -12), 3.6, _goldRamp);
      for (final dx in const [-7.0, 0.0, 7.0]) {
        c.drawLine(Offset(dx * .3, 52), Offset(dx, 66 - dx.abs() * .4), strokePaint(outline, 3.6));
        c.drawLine(Offset(dx * .3, 52), Offset(dx, 66 - dx.abs() * .4), strokePaint(_goldRamp[0], 2));
      }
      _gem(c, const Offset(0, 62), 7, gem, t, still);
    case Weapon.bow || Weapon.longbow:
      final half = kind == Weapon.longbow ? 70.0 : 56.0, bulge = kind == Weapon.longbow ? 22.0 : 26.0;
      final limb = Path()
        ..moveTo(-half, -6)
        ..quadraticBezierTo(-half * .45, bulge * .9, 0, 10)
        ..quadraticBezierTo(half * .45, bulge * .9, half, -6);
      // Limbs taper from a thick riser to slim tips: the inner third is drawn again, heavier.
      // The riser: the same curve as the limbs, sampled over their inner part.
      Offset q(double u, double side) {
        final p0 = Offset(-half * side, -6), cp = Offset(-half * .45 * side, bulge * .9), p1 = const Offset(0, 10);
        return p0 * ((1 - u) * (1 - u)) + cp * (2 * u * (1 - u)) + p1 * (u * u);
      }
      final riser = Path()..moveTo(q(.62, 1).dx, q(.62, 1).dy);
      for (var u = .66; u <= 1.001; u += .04) {
        riser.lineTo(q(u, 1).dx, q(u, 1).dy);
      }
      for (var u = .96; u >= .619; u -= .04) {
        riser.lineTo(q(u, -1).dx, q(u, -1).dy);
      }
      c.drawPath(limb, strokePaint(outline, 6.4));
      c.drawPath(riser, strokePaint(outline, 7.4));
      c.drawPath(limb, strokePaint(wood[1], 4.2));
      c.drawPath(riser, strokePaint(wood[1], 5.2));
      // The belly in shade, the back catching the light.
      for (final (dy, paint) in [(1.3, strokePaint(wood[2].withValues(alpha: .7), 1.3)), (-1.2, strokePaint(const Color(0x4DFFFFFF), 1.1))]) {
        c.save();
        c.translate(0, dy);
        c.drawPath(limb, paint);
        c.restore();
      }
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 8), width: 15, height: 8.5), const Radius.circular(2))), _gripRamp, const Offset(0, 4), const Offset(0, 12));
      _wrapsAcross(c, -6.5, 6.5, 8, 4);
      // Horn nocks at the tips.
      for (final x in [-half, half]) {
        capsule(c, Offset(x, -6), 2.4, Offset(x * 1.04, -11), 1.5, const [Color(0xFFF0E6D0), Color(0xFFBFAE8A), Color(0xFF5A4A30)]);
      }
    case Weapon.crossbow:
      capsule(c, const Offset(0, -24), 4.2, const Offset(0, 40), 3.6, _woodRamp);
      final prod = Path()
        ..moveTo(-32, 28)
        ..quadraticBezierTo(0, 46, 32, 28);
      c.drawPath(prod, strokePaint(outline, 6));
      c.drawPath(prod, strokePaint(steel[1], 3.8));
      final string = strokePaint(const Color(0xFFE8E0CC), 1.1);
      c.drawLine(const Offset(-32, 28), const Offset(0, 10), string);
      c.drawLine(const Offset(32, 28), const Offset(0, 10), string);
      c.drawLine(const Offset(0, 10), const Offset(0, 46), strokePaint(const Color(0xFF8A6440), 2.2));
      c.drawPath(poly(const [Offset(0, 52), Offset(-3, 45), Offset(3, 45)]), Paint()..color = steel[1]);
      c.drawLine(const Offset(-4, -4), const Offset(-8, 4), strokePaint(steel[2], 2));
    case Weapon.runeblade || Weapon.runebow || Weapon.runestaff || Weapon.thornblade:
      break; // drawn on their base shape above
    case Weapon.handcrossbow:
      // A small one-handed crossbow, held in the off hand.
      capsule(c, const Offset(0, -10), 3, const Offset(0, 22), 2.6, _woodRamp);
      final prod = Path()
        ..moveTo(-17, 16)
        ..quadraticBezierTo(0, 26, 17, 16);
      c.drawPath(prod, strokePaint(outline, 4.6));
      c.drawPath(prod, strokePaint(steel[1], 2.8));
      final string = strokePaint(const Color(0xFFE8E0CC), 1);
      c.drawLine(const Offset(-17, 16), const Offset(0, 7), string);
      c.drawLine(const Offset(17, 16), const Offset(0, 7), string);
      c.drawLine(const Offset(0, 7), const Offset(0, 27), strokePaint(const Color(0xFF8A6440), 1.8));
      c.drawPath(poly(const [Offset(0, 31), Offset(-2.4, 26), Offset(2.4, 26)]), Paint()..color = steel[1]);
    case Weapon.tome:
      final cover = look.skirt ?? ramp(0xFF5A2E2A);
      fillPath(c, poly(const [Offset(-8, -18), Offset(4, -14), Offset(4, 4), Offset(-8, 0)]), cover, const Offset(-8, 0), const Offset(4, 0));
      fillPath(c, poly(const [Offset(4, -14), Offset(18, -20), Offset(18, -2), Offset(4, 4)]), cover, const Offset(4, 0), const Offset(18, 0));
      fillPath(c, poly(const [Offset(-6, -19), Offset(4, -16), Offset(16, -21), Offset(16, -19), Offset(4, -14), Offset(-6, -17)]), const Color(0xFFEFE6CC), Offset.zero, Offset.zero, width: 1);
      c.drawLine(const Offset(10, -16), const Offset(10, -4), strokePaint(look.trim ?? const Color(0xFFC9A24E), 1.6));
      if (glow != null) _gem(c, const Offset(11, -10), 2.4, glow, t, still);
    case Weapon.orb:
      final bob = still ? 0.0 : math.sin(t / 420) * 3;
      final centre = Offset(8, -24 + bob);
      c.drawCircle(
        centre,
        16,
        Paint()
          ..color = gem.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.drawCircle(centre, 10, Paint()..shader = ui.Gradient.radial(centre - const Offset(3, 3), 12, [const Color(0xFFFFFFFF), shade(gem, .2), shade(gem, -.45)], const [0, .35, 1]));
      c.drawCircle(centre, 10, strokePaint(outline, 1.4));
      c.drawArc(Rect.fromCircle(center: centre, radius: 6.5), 3.6, 1.2, false, strokePaint(const Color(0xAAFFFFFF), 1.6));
    case Weapon.dragondagger:
      // A crimson-bladed dagger with a gold, dragon-wing guard.
      const blade = [Color(0xFFFFB3A0), Color(0xFFC0392B), Color(0xFF5E120C)];
      capsule(c, const Offset(0, -10), 2.8, const Offset(0, 6), 2.8, _gripRamp);
      blob(c, const Offset(0, -12), 3.6, _goldRamp);
      final edge = Path()
        ..moveTo(-4.5, 9)
        ..lineTo(4.5, 9)
        ..quadraticBezierTo(5, 30, 1.5, 44)
        ..lineTo(0, 50)
        ..lineTo(-1.5, 44)
        ..quadraticBezierTo(-5, 30, -4.5, 9)
        ..close();
      fillPath(c, edge, blade, const Offset(-5, 0), const Offset(5, 0));
      c.drawLine(const Offset(0, 12), const Offset(0, 42), strokePaint(const Color(0x66FFFFFF), 1.1));
      for (final dx in const [-1.0, 1.0]) {
        fillPath(c, poly([const Offset(0, 5), Offset(dx * 14, 2), Offset(dx * 11, 8), Offset(dx * 5, 10)]), _goldRamp, Offset(dx * 14, 0), Offset.zero);
      }
    case Weapon.dragonstaff:
      // A dark staff topped with a dragon's skull holding a burning gem.
      capsule(c, const Offset(0, -50), 3.2, const Offset(0, 100), 3.8, const [Color(0xFF6A3A2A), Color(0xFF3A1E14), Color(0xFF160A06)]);
      for (final y in const [70.0, 82.0]) {
        c.drawLine(Offset(-4, y), Offset(4, y + 2), strokePaint(_goldRamp[1], 2));
      }
      final skull = Path()
        ..moveTo(-9, 100)
        ..quadraticBezierTo(-14, 116, -4, 126)
        ..lineTo(14, 132)
        ..lineTo(9, 122)
        ..quadraticBezierTo(14, 110, 8, 100)
        ..close();
      fillPath(c, skull, const [Color(0xFFEFE6CC), Color(0xFFBDAE8A), Color(0xFF6A5C42)], const Offset(-12, 0), const Offset(12, 0));
      for (final dx in const [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(dx * 6, 118)
          ..quadraticBezierTo(dx * 18, 124, dx * 16, 140)
          ..quadraticBezierTo(dx * 12, 128, dx * 3, 122)
          ..close();
        fillPath(c, horn, const [Color(0xFFE8DCB8), Color(0xFFA8987A), Color(0xFF5A4C36)], Offset.zero, Offset(dx * 16, 0));
      }
      _gem(c, const Offset(0, 112), 5.5, glow ?? const Color(0xFFFF6A2A), t, still);
    case Weapon.heartmaul:
      // A living branch for a haft and a gnarled knot of heartwood for a head, still in leaf.
      const heart = [Color(0xFFB08A5A), Color(0xFF6E4E2C), Color(0xFF2E1E0E)];
      capsule(c, const Offset(0, -20), 3.8, const Offset(0, 84), 4.4, heart);
      final knot = Path()
        ..moveTo(-16, 78)
        ..quadraticBezierTo(-22, 92, -14, 106)
        ..quadraticBezierTo(0, 114, 16, 106)
        ..quadraticBezierTo(24, 92, 16, 78)
        ..quadraticBezierTo(0, 70, -16, 78)
        ..close();
      fillPath(c, knot, heart, const Offset(-20, 0), const Offset(20, 0), width: 1.6);
      for (final y in const [84.0, 94.0, 102.0]) {
        c.drawPath(Path()..moveTo(-14, y)..quadraticBezierTo(0, y + 4, 14, y), strokePaint(const Color(0x55000000), 1.2));
      }
      c.drawPath(Path()..moveTo(-3, 40)..quadraticBezierTo(4, 52, -2, 66), strokePaint(const Color(0xFF4E7A2E), 2.2));
      leafCluster(c, const Offset(12, 76), 14, const Color(0xFF5E9A3A), seed: 2);
      _gem(c, const Offset(0, 92), 4, glow ?? const Color(0xFF8BE05A), t, still);
    case Weapon.heartbow:
      // A longbow of pale heartwood that still puts out leaves.
      final limb = Path()
        ..moveTo(-66, -8)
        ..quadraticBezierTo(-30, 22, 0, 10)
        ..quadraticBezierTo(30, 22, 66, -8);
      c.drawPath(limb, strokePaint(outline, 7));
      c.drawPath(limb, strokePaint(const Color(0xFFC8A06A), 4.6));
      c.drawPath(limb, strokePaint(const Color(0x40FFFFFF), 1.2));
      for (final x in const [-66.0, 66.0]) {
        leafCluster(c, Offset(x * .92, -6), 11, const Color(0xFF6AAA3E), seed: x > 0 ? 1 : 4);
      }
      c.drawPath(Path()..moveTo(-40, 12)..quadraticBezierTo(-20, 22, -6, 14), strokePaint(const Color(0xFF4E7A2E), 1.8));
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 10), width: 14, height: 8), const Radius.circular(2))), const [Color(0xFF6A9A4A), Color(0xFF3E6A2A), Color(0xFF1A2E10)], const Offset(0, 6), const Offset(0, 14));
    case Weapon.livingstaff:
      // A staff that is still growing: roots at the foot, a crown of leaves around a green light.
      const living = [Color(0xFF9A7A4E), Color(0xFF5E4428), Color(0xFF241608)];
      capsule(c, const Offset(0, -50), 3.6, const Offset(0, 104), 4.2, living);
      for (final dx in const [-1.0, 1.0]) {
        c.drawPath(Path()..moveTo(0, -46)..quadraticBezierTo(dx * 6, -54, dx * 9, -58), strokePaint(living[2], 2));
        c.drawPath(Path()..moveTo(0, 98)..quadraticBezierTo(dx * 14, 104, dx * 12, 122), strokePaint(outline, 5));
        c.drawPath(Path()..moveTo(0, 98)..quadraticBezierTo(dx * 14, 104, dx * 12, 122), strokePaint(living[1], 3));
      }
      c.drawPath(Path()..moveTo(-2, 20)..quadraticBezierTo(6, 40, -2, 60)..quadraticBezierTo(-6, 76, 2, 90), strokePaint(const Color(0xFF4E7A2E), 2));
      leafCluster(c, const Offset(-12, 118), 13, const Color(0xFF5E9A3A), seed: 6);
      leafCluster(c, const Offset(12, 120), 13, const Color(0xFF6AAA3E), seed: 7);
      _gem(c, const Offset(0, 114), 6.5, glow ?? const Color(0xFF8BE05A), t, still);
    case Weapon.orkclub:
      // A heavy, iron-banded club studded with nails.
      capsule(c, const Offset(0, -14), 4.2, const Offset(0, 88), 12, const [Color(0xFF8A6440), Color(0xFF5A3C22), Color(0xFF24160A)]);
      for (final y in const [24.0, 58.0]) {
        c.drawLine(Offset(-6 - y * .04, y), Offset(6 + y * .04, y + 2), strokePaint(outline, 5));
        c.drawLine(Offset(-6 - y * .04, y), Offset(6 + y * .04, y + 2), strokePaint(steel[1], 3));
      }
      final nail = Paint()..color = const Color(0xFFD6DBE1);
      for (final (x, y) in const [(-11.0, 66.0), (11.0, 70.0), (-12.0, 80.0), (12.0, 84.0), (-6.0, 94.0), (6.0, 96.0), (0.0, 99.0)]) {
        final d = x == 0 ? 1.0 : x.sign;
        c.drawPath(poly([Offset(x * .85, y - 3), Offset(x * .85 + d * 9, y), Offset(x * .85, y + 3)]), nail);
        c.drawPath(poly([Offset(x * .85, y - 3), Offset(x * .85 + d * 9, y), Offset(x * .85, y + 3)]), strokePaint(outline, .8));
      }
    case Weapon.orkbow:
      // A big crude recurve with bone tips and a bound grip.
      final limb = Path()
        ..moveTo(-66, -12)
        ..quadraticBezierTo(-62, 4, -36, 14)
        ..quadraticBezierTo(0, 22, 36, 14)
        ..quadraticBezierTo(62, 4, 66, -12);
      c.drawPath(limb, strokePaint(outline, 8));
      c.drawPath(limb, strokePaint(const Color(0xFF4A3220), 5.6));
      c.drawPath(limb, strokePaint(const Color(0x30FFFFFF), 1.4));
      for (final x in const [-66.0, 66.0]) {
        fillPath(c, poly([Offset(x, -12), Offset(x + (x > 0 ? 6 : -6), -20), Offset(x + (x > 0 ? -2 : 2), -8)]), const [Color(0xFFF2EAD2), Color(0xFFCFC2A0), Color(0xFF7E7058)], Offset(x, -20), Offset(x, -8));
      }
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 18), width: 18, height: 10), const Radius.circular(2))), const [Color(0xFF8A2A1E), Color(0xFF5A1A12), Color(0xFF2A0A06)], const Offset(0, 13), const Offset(0, 23));
    case Weapon.orkstaff:
      // A crooked totem staff: a horned skull, feathers and a green-burning eye.
      capsule(c, const Offset(0, -50), 3.4, const Offset(0, 100), 4, const [Color(0xFF7A5A3A), Color(0xFF4A3420), Color(0xFF1E140A)]);
      for (final (i, col) in [const Color(0xFF7A1D14), const Color(0xFF2E5F35)].indexed) {
        final y = 80.0 + i * 6, dx = i == 0 ? -1.0 : 1.0;
        c.drawPath(
          Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(dx * 14, y - 4, dx * 18, y - 22)
            ..quadraticBezierTo(dx * 8, y - 12, 0, y + 4)
            ..close(),
          Paint()..color = col,
        );
      }
      final skull = Path()
        ..moveTo(-10, 100)
        ..quadraticBezierTo(-13, 118, -2, 126)
        ..quadraticBezierTo(10, 126, 12, 112)
        ..quadraticBezierTo(12, 100, 6, 98)
        ..close();
      fillPath(c, skull, const [Color(0xFFEFE6CC), Color(0xFFBDAE8A), Color(0xFF6A5C42)], const Offset(-12, 0), const Offset(12, 0));
      c.drawCircle(const Offset(-3, 116), 2.6, Paint()..color = const Color(0xFF1A120C));
      _gem(c, const Offset(4, 116), 3.4, glow ?? const Color(0xFF8BE05A), t, still);
      for (final dx in const [-1.0, 1.0]) {
        c.drawPath(
          Path()
            ..moveTo(dx * 7, 120)
            ..quadraticBezierTo(dx * 16, 128, dx * 12, 138)
            ..quadraticBezierTo(dx * 10, 130, dx * 3, 124)
            ..close(),
          Paint()..color = const Color(0xFFD8CCAA),
        );
      }
    case Weapon.halberd:
      // A long haft with an axe blade, a top spike and a back hook.
      capsule(c, const Offset(0, -40), 3.2, const Offset(0, 112), 3.4, _woodRamp);
      fillPath(c, poly(const [Offset(-3, 108), Offset(3, 108), Offset(1.5, 134), Offset(0, 140), Offset(-1.5, 134)]), steel, const Offset(-3, 0), const Offset(3, 0));
      final blade = Path()
        ..moveTo(2, 92)
        ..quadraticBezierTo(22, 86, 28, 96)
        ..quadraticBezierTo(32, 108, 26, 120)
        ..quadraticBezierTo(16, 114, 2, 114)
        ..close();
      fillPath(c, blade, steel, const Offset(2, 0), const Offset(30, 0), width: 1.5);
      fillPath(c, poly(const [Offset(-2, 98), Offset(-16, 104), Offset(-2, 110)]), steel, const Offset(-16, 0), const Offset(-2, 0));
      for (final y in const [88.0, 116.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y), strokePaint(_goldRamp[1], 2.2));
      }
    case Weapon.trident:
      // A long sea-worn haft and three barbed prongs of sea-gold.
      final sea = tint == null ? _goldRamp : rampOf(tint, .4, .5);
      capsule(c, const Offset(0, -44), 3.2, const Offset(0, 104), 3.4, _woodRamp);
      for (final y in const [-30.0, 20.0, 70.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y + 3), strokePaint(_goldRamp[1], 2));
      }
      fillPath(c, poly(const [Offset(-16, 104), Offset(16, 104), Offset(13, 112), Offset(-13, 112)]), _goldRamp, const Offset(-16, 0), const Offset(16, 0));
      for (final x in const [-12.0, 0.0, 12.0]) {
        final len = x == 0 ? 146.0 : 136.0, lean = x * .12;
        final prong = Path()
          ..moveTo(x - 2.4, 110)
          ..lineTo(x + lean - 1.6, len - 10)
          ..lineTo(x + lean, len)
          ..lineTo(x + lean + 1.6, len - 10)
          ..lineTo(x + 2.4, 110)
          ..close();
        fillPath(c, prong, sea, Offset(x - 3, 0), Offset(x + 3, 0));
        // A barb on each prong.
        c.drawPath(poly([Offset(x + lean + (x < 0 ? -1 : 1) * 1.5, len - 14), Offset(x + lean + (x < 0 ? -6 : 6), len - 20), Offset(x + lean + (x < 0 ? -1 : 1) * 1.5, len - 22)]), Paint()..color = sea[1]);
      }
      blob(c, const Offset(0, 100), 4.5, rampOf(const Color(0xFF6AD8E8), .4, .5));
    case Weapon.flamberge:
      // A flame-bladed sword: the edges ripple like a candle flame, and the steel runs ember-red.
      capsule(c, const Offset(0, -18), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      _wraps(c, -15, 4, 3.2);
      blob(c, const Offset(0, -20), 4.6, _goldRamp);
      final fire = tint == null ? const [Color(0xFFFFE0B0), Color(0xFFD86A2A), Color(0xFF5A1A0E)] : steel;
      final edge = Path()..moveTo(-4.6, 10);
      for (var y = 10.0; y <= 112; y += 2) {
        edge.lineTo(-4.6 + 1.6 * math.sin(y / 5) - (y > 100 ? (y - 100) * .3 : 0), y);
      }
      edge.lineTo(0, 124);
      for (var y = 112.0; y >= 10; y -= 2) {
        edge.lineTo(4.6 + 1.6 * math.sin(y / 5 + 1) + (y > 100 ? -(y - 100) * .3 : 0), y);
      }
      edge.close();
      fillPath(c, edge, fire, const Offset(-6, 0), const Offset(6, 0));
      c.drawLine(const Offset(0, 16), const Offset(0, 100), strokePaint(const Color(0x99FFF0C0), 1.1));
      fillPath(c, _rrectPath(Rect.fromCenter(center: const Offset(0, 9), width: 28, height: 5), 2), _goldRamp, const Offset(0, 6), const Offset(0, 12));
      for (final dx in const [-14.0, 14.0]) {
        blob(c, Offset(dx, 9), 3, _goldRamp);
      }
      if (!still) {
        for (var i = 0; i < 4; i++) {
          final y = 30 + ((t / 6 + i * 23) % 90);
          c.drawCircle(Offset(5 * math.sin(t / 200 + i), y), 2.4 - (y - 30) / 60, Paint()..color = const Color(0xCCFFB050));
        }
      }
    case Weapon.frostbrand:
      // A sword of living ice: a faceted crystal blade grown from a guard of frozen spikes.
      capsule(c, const Offset(0, -16), 3.2, const Offset(0, 6), 3.2, const [Color(0xFFE8F4FA), Color(0xFF7A98AE), Color(0xFF2A3A4A)]);
      _wraps(c, -13, 4, 3.2);
      final ice = tint == null ? const [Color(0xFFFFFFFF), Color(0xFFA8DCF4), Color(0xFF3A7AA8)] : steel;
      final shard = poly(const [Offset(-5, 10), Offset(-6.5, 50), Offset(-4, 96), Offset(0, 122), Offset(4, 96), Offset(6.5, 50), Offset(5, 10)]);
      fillPath(c, shard, ice, const Offset(-7, 0), const Offset(7, 0));
      for (final (a, b) in const [(Offset(0, 12), Offset(0, 118)), (Offset(-5, 30), Offset(0, 50)), (Offset(5, 60), Offset(0, 80)), (Offset(-4, 88), Offset(0, 102))]) {
        c.drawLine(a, b, strokePaint(const Color(0xAAFFFFFF), 1));
      }
      for (final (x, y, l) in const [(-1.0, 8.0, 14.0), (1.0, 8.0, 14.0), (-1.0, 4.0, 8.0), (1.0, 4.0, 8.0)]) {
        fillPath(c, poly([Offset(0, y - 3), Offset(x * l, y - 6), Offset(0, y + 3)]), ice, Offset(0, y - 6), Offset(x * l, y));
      }
    case Weapon.dawnblade:
      // A sun-bright blade: broad, gilded at the root, with a sunburst for a guard.
      capsule(c, const Offset(0, -18), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      _wraps(c, -15, 4, 3.2);
      blob(c, const Offset(0, -20), 4.8, _goldRamp);
      final sunSteel = tint == null ? const [Color(0xFFFFFFF4), Color(0xFFE8E0C4), Color(0xFF8A7A4E)] : steel;
      fillPath(c, poly(const [Offset(-6.5, 12), Offset(6.5, 12), Offset(5, 104), Offset(0, 122), Offset(-5, 104)]), sunSteel, const Offset(-7, 0), const Offset(7, 0));
      fillPath(c, poly(const [Offset(-3, 12), Offset(3, 12), Offset(0, 40)]), _goldRamp, const Offset(-3, 0), const Offset(3, 0));
      c.drawLine(const Offset(0, 42), const Offset(0, 104), strokePaint(const Color(0x88FFFFFF), 1.2));
      for (var i = 0; i < 9; i++) {
        final a = math.pi + i * math.pi / 8, d = Offset(math.cos(a), math.sin(a) * .7);
        c.drawPath(poly([const Offset(0, 9) + Offset(-d.dy, d.dx) * 2.2, const Offset(0, 9) + d * (i.isEven ? 16 : 11), const Offset(0, 9) - Offset(-d.dy, d.dx) * 2.2]), Paint()..color = _goldRamp[i.isEven ? 1 : 0]);
      }
      blob(c, const Offset(0, 9), 4.4, _goldRamp);
    case Weapon.shadowblade:
      // A blade of night: black steel, a jagged back edge, a violet line along the cut, and smoke.
      capsule(c, const Offset(0, -16), 3.2, const Offset(0, 6), 3.2, const [Color(0xFF6A5A7A), Color(0xFF2A2234), Color(0xFF0C0A10)]);
      _wraps(c, -13, 4, 3.2);
      final night = tint == null ? const [Color(0xFF6A6478), Color(0xFF2A2632), Color(0xFF08070C)] : steel;
      final blade = poly(const [Offset(-4, 10), Offset(-7, 30), Offset(-4, 36), Offset(-7, 58), Offset(-4, 64), Offset(-7, 86), Offset(-3, 98), Offset(2, 122), Offset(5, 96), Offset(5, 10)]);
      fillPath(c, blade, night, const Offset(-7, 0), const Offset(6, 0));
      c.drawLine(const Offset(4.4, 14), const Offset(3, 108), strokePaint(const Color(0xCCC08AFF), 1.2));
      fillPath(c, poly(const [Offset(-12, 6), Offset(12, 6), Offset(16, 14), Offset(0, 11), Offset(-16, 14)]), night, const Offset(0, 6), const Offset(0, 14));
      if (!still) {
        for (var i = 0; i < 4; i++) {
          final y = 20 + ((t / 9 + i * 25) % 100);
          c.drawCircle(Offset(-8 - 4 * math.sin(t / 300 + i), y), 3.4, Paint()..color = const Color(0x55302840));
        }
      }
    case Weapon.rapier:
      // A duellist's blade: needle-thin, with a swept hilt of curling rings.
      capsule(c, const Offset(0, -16), 2.8, const Offset(0, 6), 2.8, _gripRamp);
      _wraps(c, -13, 4, 2.8);
      blob(c, const Offset(0, -18), 4, _silverRamp);
      fillPath(c, poly(const [Offset(-2, 8), Offset(2, 8), Offset(1, 112), Offset(0, 124), Offset(-1, 112)]), steel, const Offset(-2, 0), const Offset(2, 0), width: 1);
      final swept = Path()
        ..moveTo(-12, 8)
        ..quadraticBezierTo(-14, -6, 0, -14)
        ..moveTo(12, 8)
        ..quadraticBezierTo(16, -2, 6, -10)
        ..addOval(Rect.fromCenter(center: const Offset(0, 10), width: 18, height: 6));
      c.drawPath(swept, strokePaint(outline, 3.6));
      c.drawPath(swept, strokePaint(_silverRamp[1], 2));
      c.drawLine(const Offset(-14, 8), const Offset(14, 8), strokePaint(outline, 3.4));
      c.drawLine(const Offset(-14, 8), const Offset(14, 8), strokePaint(_silverRamp[0], 1.8));
    case Weapon.glaive:
      // A pole with a long single-edged blade, like a great knife on a stick.
      capsule(c, const Offset(0, -40), 3.2, const Offset(0, 104), 3.4, _woodRamp);
      final gblade = Path()
        ..moveTo(-3, 100)
        ..lineTo(3, 100)
        ..quadraticBezierTo(14, 120, 4, 150)
        ..quadraticBezierTo(-2, 128, -3, 100)
        ..close();
      fillPath(c, gblade, steel, const Offset(-3, 0), const Offset(12, 0), width: 1.4);
      c.drawLine(const Offset(-6, 104), const Offset(-12, 110), strokePaint(outline, 3.4));
      c.drawLine(const Offset(-6, 104), const Offset(-12, 110), strokePaint(steel[1], 1.8));
      for (final y in const [96.0, 80.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y), strokePaint(_goldRamp[1], 2.2));
      }
    case Weapon.cleaver:
      // A great cleaver: a slab of a blade, notched near the tip, riveted at the root.
      capsule(c, const Offset(0, -30), 3.6, const Offset(0, 8), 3.6, _gripRamp);
      _wraps(c, -26, 4, 3.6);
      blob(c, const Offset(0, -32), 5, steel);
      final slab = poly(const [Offset(-10, 12), Offset(10, 12), Offset(12, 120), Offset(4, 134), Offset(4, 126), Offset(-2, 130), Offset(-10, 140)]);
      fillPath(c, slab, steel, const Offset(-10, 0), const Offset(12, 0), width: 1.8);
      c.drawLine(const Offset(10.6, 16), const Offset(12, 116), strokePaint(const Color(0x99FFFFFF), 1.4));
      for (final y in const [22.0, 34.0]) {
        blob(c, Offset(-4, y), 2, _gripRamp);
        blob(c, Offset(4, y), 2, _gripRamp);
      }
      fillPath(c, _rrectPath(Rect.fromCenter(center: const Offset(0, 10), width: 30, height: 6), 2), steel, const Offset(0, 7), const Offset(0, 13));
    case Weapon.katana || Weapon.wakizashi:
      // A gently curved single-edged blade, a round guard, and a long grip bound in diamonds.
      final long = kind == Weapon.katana, len = long ? 112.0 : 70.0, grip = long ? -30.0 : -18.0;
      fillPath(c, _rrectPath(Rect.fromLTRB(-3.2, grip, 3.2, 4), 2), const [Color(0xFF3A3A44), Color(0xFF16161C), Color(0xFF08080A)], const Offset(-3, 0), const Offset(3, 0));
      for (var y = grip + 4; y < 2; y += 6) {
        c.drawPath(poly([Offset(0, y - 2.4), Offset(2.4, y), Offset(0, y + 2.4), Offset(-2.4, y)]), Paint()..color = const Color(0xFFE8DCC0));
      }
      blob(c, Offset(0, grip - 1), 3.4, _goldRamp);
      final curve = len * .08;
      final edge = Path()
        ..moveTo(-2.6, 8)
        ..quadraticBezierTo(-2.6 + curve * .6, len * .55, curve - 1, len - 6)
        ..lineTo(curve + 1.6, len)
        ..quadraticBezierTo(2.8 + curve * .7, len * .5, 2.6, 8)
        ..close();
      fillPath(c, edge, steel, const Offset(-3, 0), const Offset(4, 0), width: 1.1);
      // The temper line, misty along the edge.
      c.drawPath(
        Path()
          ..moveTo(-1.2, 12)
          ..quadraticBezierTo(-1 + curve * .6, len * .55, curve - .4, len - 8),
        strokePaint(const Color(0xAAFFFFFF), .9),
      );
      c.drawOval(Rect.fromCenter(center: const Offset(0, 6), width: 13, height: 5.5), Paint()..color = const Color(0xFF2A2420));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 6), width: 13, height: 5.5), strokePaint(_goldRamp[1], 1.1));
    case Weapon.naginata:
      // A long lacquered pole and a curved blade like a sword's, behind a small round guard.
      capsule(c, const Offset(0, -44), 3.2, const Offset(0, 104), 3.4, const [Color(0xFF7A3A2A), Color(0xFF4A1A12), Color(0xFF1A0806)]);
      for (final y in const [-30.0, 60.0, 98.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y), strokePaint(_goldRamp[1], 2));
      }
      c.drawOval(Rect.fromCenter(center: const Offset(0, 104), width: 12, height: 5), Paint()..color = const Color(0xFF2A2420));
      final nblade = Path()
        ..moveTo(-2.6, 106)
        ..lineTo(2.6, 106)
        ..quadraticBezierTo(8, 130, -4, 156)
        ..quadraticBezierTo(2, 130, -2.6, 106)
        ..close();
      fillPath(c, nblade, steel, const Offset(-4, 0), const Offset(8, 0), width: 1.2);
    case Weapon.kanabo:
      // An oni's club: a long tapering iron-shod staff studded all over.
      final shaft = tint == null ? const [Color(0xFF6A6A70), Color(0xFF34343A), Color(0xFF101014)] : steel;
      capsule(c, const Offset(0, -14), 3.4, const Offset(0, 20), 3.8, _gripRamp);
      fillPath(c, poly(const [Offset(-4, 18), Offset(4, 18), Offset(9, 104), Offset(0, 110), Offset(-9, 104)]), shaft, const Offset(-9, 0), const Offset(9, 0), width: 1.6);
      final stud = Paint()..color = const Color(0xFFD0D4D8);
      for (var y = 30.0; y < 104; y += 10) {
        final w = 4 + (y - 18) / 86 * 5;
        for (final x in [-w * .6, w * .6]) {
          c.drawCircle(Offset(x, y + (x > 0 ? 5 : 0)), 1.8, stud);
        }
      }
    case Weapon.yumi:
      // The tall eastern bow: its grip a third of the way up, the upper limb far longer.
      const top = 92.0, bottom = 52.0;
      final limb = Path()
        ..moveTo(-top, -4)
        ..quadraticBezierTo(-top * .5, 22, 0, 10)
        ..quadraticBezierTo(bottom * .5, 20, bottom, -4);
      c.drawPath(limb, strokePaint(outline, 6));
      c.drawPath(limb, strokePaint(tint == null ? const Color(0xFF3A2A24) : wood[1], 3.8));
      for (final x in const [-70.0, -40.0, 30.0]) {
        c.drawCircle(Offset(x, x < 0 ? 12 + x * .05 : 10), 2.2, Paint()..color = const Color(0xFFB8322A));
      }
      fillPath(c, _rrectPath(Rect.fromCenter(center: const Offset(0, 9), width: 12, height: 8), 2), const [Color(0xFFE8DCC0), Color(0xFFB8A880), Color(0xFF5A4A30)], const Offset(0, 5), const Offset(0, 13));
    case Weapon.shuriken:
      // Throwing stars fanned in the palm.
      for (var j = 0; j < 2; j++) {
        final at0 = Offset(6.0 + j * 9, -10.0 - j * 8);
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + j * .4, d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
          fillPath(c, poly([at0 + n * 3, at0 + d * 11, at0 - n * 3]), steel, at0 - const Offset(10, 10), at0 + const Offset(10, 10), width: 1);
        }
        c.drawCircle(at0, 2, Paint()..color = const Color(0xFF1A1A1E));
      }
    case Weapon.shakujo:
      // A monk's ringed staff: a dark shaft crowned with a loop of jingling rings.
      capsule(c, const Offset(0, -50), 3, const Offset(0, 98), 3.2, tint == null ? _woodRamp : wood);
      _wraps(c, -6, 14, 3.3);
      c.drawLine(const Offset(0, 96), const Offset(0, 104), strokePaint(_goldRamp[1], 3));
      final loop = Path()
        ..moveTo(0, 102)
        ..cubicTo(-16, 104, -14, 132, 0, 132)
        ..cubicTo(14, 132, 16, 104, 0, 102);
      c.drawPath(loop, strokePaint(outline, 5));
      c.drawPath(loop, strokePaint(_goldRamp[1], 3));
      final jingle = still ? 0.0 : 1.5 * math.sin(t / 120);
      for (final (x, y) in const [(-11.0, 112.0), (11.0, 112.0), (-9.0, 124.0), (9.0, 124.0)]) {
        c.drawCircle(Offset(x + (x < 0 ? -jingle : jingle) * .5, y), 3.4, strokePaint(_goldRamp[0], 1.6));
      }
      _gem(c, const Offset(0, 118), 4.4, gem, t, still);
    case Weapon.fan:
      // A war fan held open in the palm: iron ribs and painted paper.
      final fanCol = tint ?? const Color(0xFFB8322A);
      const hub = Offset(8, -2);
      final open = Path()
        ..moveTo(hub.dx, hub.dy)
        ..arcTo(Rect.fromCircle(center: hub, radius: 26), -math.pi * .95, math.pi * .9, false)
        ..close();
      fillPath(c, open, rampOf(fanCol, .3, .45), hub + const Offset(0, -26), hub, width: 1.4);
      for (var i = 0; i <= 8; i++) {
        final a = -math.pi * .95 + i * math.pi * .9 / 8;
        c.drawLine(hub, hub + Offset(math.cos(a), math.sin(a)) * 25, strokePaint(const Color(0x88201810), 1));
      }
      c.drawCircle(hub + const Offset(0, -14), 4, Paint()..color = const Color(0xFFF2E6C8));
      blob(c, hub, 2.6, _goldRamp);
    case Weapon.whip:
      // The Bramblelash: a bound grip, then a living briar for a lash, swaying, thorned and in flower.
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 26), 3, _gripRamp);
      for (final y in const [-8.0, 2.0, 12.0, 22.0]) {
        c.drawLine(Offset(-3.2, y), Offset(3.2, y + 2), strokePaint(const Color(0xFF2E4A1E), 1.3));
      }
      blob(c, const Offset(0, -15), 3.8, _goldRamp);
      final sway = still ? 0.0 : math.sin(t / 340);
      final lash = [
        for (var i = 0; i <= 24; i++)
          Offset((10 + 6 * sway) * math.sin(i / 24 * math.pi * 1.4) * (i / 24), 26 + i * 4.0),
      ];
      _briar(c, lash, t, still, width: 3.4, flowers: const [40, 70, 102]);
    case Weapon.flail:
      // A short haft, a few links of chain, and a spiked iron ball that swings with you.
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 50), 3.6, _woodRamp);
      _wraps(c, -8, 8, 3.4);
      fillPath(c, _rrectPath(Rect.fromCenter(center: const Offset(0, 52), width: 10, height: 5), 1.4), steel, const Offset(0, 49), const Offset(0, 55));
      final swing = still ? .25 : .25 * math.sin(t / 300);
      final ball = Offset(math.sin(swing) * 32, 54 + math.cos(swing) * 32);
      for (var i = 0; i < 5; i++) {
        final p = Offset.lerp(const Offset(0, 56), ball, (i + .5) / 5.5)!;
        c.drawOval(Rect.fromCenter(center: p, width: i.isEven ? 4 : 6, height: 6.5), strokePaint(outline, 3.2));
        c.drawOval(Rect.fromCenter(center: p, width: i.isEven ? 4 : 6, height: 6.5), strokePaint(steel[1], 1.6));
      }
      final spike = Paint()..color = const Color(0xFFDCE0E4);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + .2, d = Offset(math.sin(a), math.cos(a));
        final base = ball + d * 8, tip = ball + d * 16, n = Offset(-d.dy, d.dx) * 3;
        c.drawPath(poly([base + n, tip, base - n]), spike);
        c.drawPath(poly([base + n, tip, base - n]), strokePaint(outline, 1));
      }
      blob(c, ball, 10, steel);
    case Weapon.tomahawk:
      // A throwing axe: a slim curved haft, a flared bit on one side and a spike on the other.
      final haft = Path()
        ..moveTo(0, -12)
        ..quadraticBezierTo(3, 30, 0, 66);
      c.drawPath(haft, strokePaint(_woodRamp[2], 6)..strokeCap = StrokeCap.round);
      c.drawPath(haft, strokePaint(_woodRamp[1], 3.8)..strokeCap = StrokeCap.round);
      for (final y in const [-6.0, 0.0, 6.0]) {
        c.drawLine(Offset(-2.8, y), Offset(2.8, y + 2), strokePaint(const Color(0xFF6A3A1E), 1.4));
      }
      fillPath(c, poly(const [Offset(1, 50), Offset(16, 44), Offset(22, 58), Offset(16, 70), Offset(1, 62)]), steel, const Offset(0, 0), const Offset(22, 0));
      c.drawLine(const Offset(19, 46), const Offset(21, 68), strokePaint(const Color(0x99FFFFFF), 1.2));
      fillPath(c, poly(const [Offset(-1, 52), Offset(-12, 56), Offset(-1, 60)]), steel, const Offset(-12, 0), const Offset(0, 0));
      // Two feathers tied under the head.
      for (final (dx, col) in const [(-2.0, Color(0xFFE8E0C8)), (2.0, Color(0xFFB0563A))]) {
        c.drawPath(
          Path()
            ..moveTo(dx * .5, 46)
            ..quadraticBezierTo(dx * 4, 38, dx * 3, 30)
            ..quadraticBezierTo(dx * 1.5, 38, dx * .5, 46),
          Paint()..color = col,
        );
      }
    case Weapon.sickle:
      // A cultist's sickle: a short bound grip and a thin crescent of dark steel.
      capsule(c, const Offset(0, -10), 3, const Offset(0, 26), 3, _gripRamp);
      for (final y in const [-4.0, 6.0, 16.0]) {
        c.drawLine(Offset(3.2, y), Offset(-3.2, y + 2), strokePaint(const Color(0xFF5A1A1A), 1.4));
      }
      final crescent = Path()
        ..moveTo(2.4, 24)
        ..cubicTo(12, 62, -22, 90, -44, 62)
        ..cubicTo(-24, 76, -4, 60, -3, 24)
        ..close();
      fillPath(c, crescent, steel, const Offset(4, 0), const Offset(-40, 0), width: 1.2);
      c.drawPath(
        Path()
          ..moveTo(-3, 28)
          ..cubicTo(-4, 58, -24, 74, -42, 63),
        strokePaint(const Color(0xCCFFFFFF), 1),
      );
    case Weapon.scythe:
      // The Prior's scythe: a long crooked haft and a great curved blade, like the Reaper's own.
      final haft = Path()
        ..moveTo(0, -16)
        ..quadraticBezierTo(-5, 56, 0, 124);
      c.drawPath(haft, strokePaint(_woodRamp[2], 6.4)..strokeCap = StrokeCap.round);
      c.drawPath(haft, strokePaint(_woodRamp[1], 4)..strokeCap = StrokeCap.round);
      // A short grip jutting from the haft.
      capsule(c, const Offset(-2, 44), 2.6, const Offset(-14, 50), 2.6, _gripRamp);
      final blade = Path()
        ..moveTo(2, 116)
        ..cubicTo(-18, 136, -58, 132, -76, 100)
        ..cubicTo(-56, 118, -24, 120, -3, 106)
        ..close();
      fillPath(c, blade, steel, const Offset(0, 100), const Offset(0, 130), width: 1.3);
      c.drawPath(
        Path()
          ..moveTo(-4, 108)
          ..cubicTo(-26, 121, -56, 118, -74, 101),
        strokePaint(const Color(0xCCFFFFFF), 1.1),
      );
      c.drawRect(Rect.fromCenter(center: const Offset(0, 112), width: 9, height: 10), Paint()..color = const Color(0xFF2A2624));
    case Weapon.hook:
      // A fisherman's gaff: a short grip and a great barbed hook.
      final brass = tint == null ? steel : rampOf(tint, .4, .5);
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 30), 3.2, _gripRamp);
      for (final y in const [-8.0, 2.0, 12.0, 22.0]) {
        c.drawLine(Offset(-3.4, y), Offset(3.4, y + 2), strokePaint(const Color(0xFF2A1A10), 1.2));
      }
      final hook = Path()
        ..moveTo(-2.6, 30)
        ..lineTo(-2.6, 64)
        ..quadraticBezierTo(-2, 88, 14, 86)
        ..quadraticBezierTo(26, 82, 22, 66)
        ..lineTo(18, 70)
        ..quadraticBezierTo(20, 80, 13, 80)
        ..quadraticBezierTo(3, 80, 3, 62)
        ..lineTo(3, 30)
        ..close();
      fillPath(c, hook, brass, const Offset(-3, 0), const Offset(24, 0), width: 1.2);
      c.drawPath(poly(const [Offset(22, 66), Offset(28, 60), Offset(19, 62)]), Paint()..color = brass[0]);
      c.drawCircle(const Offset(0, 30), 3.6, Paint()..color = brass[1]);
    case Weapon.fishingrod:
      // A long bending rod, its line and a little hook.
      final rod = Path()
        ..moveTo(0, -10)
        ..quadraticBezierTo(2, 60, 14, 120);
      c.drawPath(rod, strokePaint(_woodRamp[2], 5)..strokeCap = StrokeCap.round);
      c.drawPath(rod, strokePaint(_woodRamp[1], 3)..strokeCap = StrokeCap.round);
      c.drawCircle(const Offset(-2, 8), 4, Paint()..color = const Color(0xFF6A6E74));
      final sway = still ? 0.0 : math.sin(t / 500) * 4;
      c.drawPath(
        Path()
          ..moveTo(14, 120)
          ..quadraticBezierTo(30 + sway, 90, 26 + sway, 60),
        strokePaint(const Color(0xAAE8E8E0), .8),
      );
      c.drawPath(
        Path()
          ..moveTo(26 + sway, 60)
          ..quadraticBezierTo(22 + sway, 52, 28 + sway, 50),
        strokePaint(const Color(0xFFB8BEC4), 1.4),
      );
    case Weapon.spear:
      // An ash shaft with a leaf-shaped head.
      capsule(c, const Offset(0, -40), 3, const Offset(0, 104), 3.2, _woodRamp);
      final head = Path()
        ..moveTo(0, 100)
        ..quadraticBezierTo(8, 110, 5, 122)
        ..lineTo(0, 134)
        ..lineTo(-5, 122)
        ..quadraticBezierTo(-8, 110, 0, 100)
        ..close();
      fillPath(c, head, steel, const Offset(-6, 0), const Offset(6, 0));
      c.drawLine(const Offset(0, 104), const Offset(0, 128), strokePaint(const Color(0x66465A5A), 1.1));
      c.drawLine(const Offset(-3.4, 98), const Offset(3.4, 99), strokePaint(const Color(0xFF7A1D14), 2.4));
    case Weapon.scimitar:
      // A deeply curved single-edged blade.
      capsule(c, const Offset(0, -14), 3, const Offset(0, 6), 3, _gripRamp);
      blob(c, const Offset(0, -16), 4, _goldRamp);
      final blade = Path()
        ..moveTo(-3, 9)
        ..lineTo(4, 9)
        ..quadraticBezierTo(16, 50, 4, 96)
        ..quadraticBezierTo(14, 52, -3, 9)
        ..close();
      final back = Path()
        ..moveTo(-3, 9)
        ..quadraticBezierTo(10, 52, 4, 96)
        ..quadraticBezierTo(-2, 50, -3, 9)
        ..close();
      fillPath(c, blade, steel, const Offset(-3, 0), const Offset(14, 0));
      fillPath(c, back, steel, const Offset(-3, 0), const Offset(10, 0));
      fillPath(c, Path()..addOval(Rect.fromCenter(center: const Offset(0, 8), width: 20, height: 6)), _goldRamp, const Offset(0, 5), const Offset(0, 11));
    case Weapon.chakram:
      // A bladed ring resting in the palm.
      final centre = const Offset(10, -6);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
        fillPath(c, poly([centre + d * 12 + n * 3, centre + d * 18 - n, centre + d * 12 - n * 3]), steel, centre - const Offset(18, 18), centre + const Offset(18, 18), width: 1);
      }
      c.drawCircle(centre, 10.5, strokePaint(outline, 7));
      c.drawCircle(centre, 10.5, strokePaint(steel[1], 5));
      c.drawCircle(centre, 10.5, strokePaint(const Color(0x55FFFFFF), 1));
    case Weapon.throwingknives:
      // A fan of three balanced knives.
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(6, -2);
        c.rotate((-.55 + i * .35) - .4);
        capsule(c, const Offset(0, 0), 1.8, const Offset(0, -8), 1.8, _gripRamp);
        fillPath(c, poly(const [Offset(-2.6, -8), Offset(2.6, -8), Offset(0, -26)]), steel, const Offset(-3, 0), const Offset(3, 0), width: 1);
        c.restore();
      }
    case Weapon.handcannon:
      // A short iron barrel on a wooden stock, flared at the muzzle.
      capsule(c, const Offset(0, -18), 4.6, const Offset(0, 14), 4.2, _woodRamp);
      final barrel = Path()
        ..moveTo(-5, 6)
        ..lineTo(5, 6)
        ..lineTo(5, 46)
        ..lineTo(8, 56)
        ..lineTo(-8, 56)
        ..lineTo(-5, 46)
        ..close();
      fillPath(c, barrel, steel, const Offset(-8, 0), const Offset(8, 0));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 56), width: 13, height: 4), Paint()..color = const Color(0xFF120E0A));
      for (final y in const [14.0, 34.0]) {
        c.drawLine(Offset(-5.4, y), Offset(5.4, y), strokePaint(_goldRamp[1], 2.2));
      }
      c.drawLine(const Offset(-6, 10), const Offset(-10, 4), strokePaint(const Color(0xFFD8CCAA), 1.4));
    case Weapon.cannon:
      // A shoulder bombard: a fat banded barrel braced on the forearm.
      final barrel = Path()
        ..moveTo(-9, -20)
        ..lineTo(9, -20)
        ..lineTo(11, 74)
        ..lineTo(15, 86)
        ..lineTo(-15, 86)
        ..lineTo(-11, 74)
        ..close();
      fillPath(c, barrel, steel, const Offset(-15, 0), const Offset(15, 0), width: 1.6);
      c.drawOval(Rect.fromCenter(center: const Offset(0, 86), width: 24, height: 7), Paint()..color = const Color(0xFF0E0A08));
      for (final y in const [-12.0, 20.0, 52.0, 74.0]) {
        c.drawLine(Offset(-10.5, y), Offset(10.5, y), strokePaint(outline, 4));
        c.drawLine(Offset(-10.5, y), Offset(10.5, y), strokePaint(_goldRamp[1], 2.4));
      }
      blob(c, const Offset(0, -22), 7, steel);
    case Weapon.none:
      break;
  }
  if (look.legendary && span != null && !still && kind != Weapon.tome) {
    final spark = Paint()..color = const Color(0xFFFFE7A6);
    for (var i = 0; i < 3; i++) {
      final ph = (t / 900 + i / 3) % 1;
      final q = Offset.lerp(span.$1, span.$2, (i * .37 + ph * .3) % 1)! + Offset(math.sin(t / 300 + i * 2) * 8, -ph * 18);
      final r = 3.2 * math.sin(ph * math.pi);
      c.drawPath(poly([q + Offset(0, -r * 1.6), q + Offset(r * .4, 0), q + Offset(0, r * 1.6), q + Offset(-r * .4, 0)]), spark);
      c.drawPath(poly([q + Offset(-r * 1.6, 0), q + Offset(0, r * .4), q + Offset(r * 1.6, 0), q + Offset(0, -r * .4)]), spark);
    }
  }
  c.restore();
}

/// Leather wrapped across a horizontal grip (a bow's), from x [from] to [to] at height [y].
void _wrapsAcross(Canvas c, double from, double to, double y, double r) {
  final dark = strokePaint(const Color(0x8C140C06), 1.1);
  for (var x = from; x < to; x += 3.2) {
    c.drawLine(Offset(x, y - r), Offset(x + 2.2, y + r), dark);
  }
}

/// Leather wrapped diagonally round a grip from [from] to [to] (along the weapon's length).
void _wraps(Canvas c, double from, double to, double r) {
  final dark = strokePaint(const Color(0x8C140C06), 1.1), lit = strokePaint(const Color(0x40FFE8C8), .7);
  for (var y = from; y < to; y += 3.6) {
    c.drawLine(Offset(-r, y), Offset(r, y + 2.4), dark);
    c.drawLine(Offset(-r + .6, y + .9), Offset(r - .4, y + 3), lit);
  }
}

Path _rrectPath(Rect r, double radius) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));

void _gem(Canvas c, Offset at, double r, Color col, double t, bool still) {
  final pulse = still ? 1.0 : .85 + .15 * math.sin(t / 300);
  c.drawCircle(
    at,
    r * 2.2 * pulse,
    Paint()
      ..color = col.withValues(alpha: .4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
  );
  c.drawCircle(at, r, Paint()..shader = ui.Gradient.radial(at - Offset(r * .3, r * .3), r * 1.2, [const Color(0xFFFFFFFF), shade(col, .15), shade(col, -.4)], const [0, .4, 1]));
  c.drawCircle(at, r, strokePaint(outline, 1));
}

/// Records a single still frame of a look into a picture (used for portraits and the hero preview).
ui.Picture snapshot(Look look, Pose pose, {required Size size, required Offset at, double scale = 1}) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & size);
  drawHumanoid(c, look, pose, 0, DrawOptions(at: at, scale: scale, shadow: false), still: true);
  return rec.endRecording();
}

/// The Wyrmbane greatsword: a broad blade in the dragon's colour, its edge a row of ivory teeth and
/// its spine a ridge of little spikes; a guard of two horns swept forward; a fang for a pommel.
/// Kingsfall: a broad blade of black ember-steel with a molten crack running down its heart, a
/// crossguard of jagged crown shards, and a coal of a gem in the pommel.
void _kingsfall(Canvas c, double t, bool still) {
  const len = 158.0, w = 8.5;
  final pulse = still ? .85 : .7 + .3 * math.sin(t / 220);
  // The grip, long enough for two hands, wrapped in dark leather.
  capsule(c, const Offset(0, -30), 3.6, const Offset(0, 6), 3.6, const [Color(0xFF4A2A1A), Color(0xFF2A160C), Color(0xFF120804)]);
  _wraps(c, -26, 6, 3.6);
  // Pommel: a gold claw holding an ember.
  fillPath(c, poly(const [Offset(0, -42), Offset(6, -35), Offset(0, -29), Offset(-6, -35)]), _goldRamp, const Offset(-6, -42), const Offset(6, -29));
  c.drawCircle(const Offset(0, -35.5), 6, Paint()..color = Color.fromRGBO(255, 120, 40, .45 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  c.drawCircle(const Offset(0, -35.5), 2.6, Paint()..color = const Color(0xFFFFC060));
  // The blade: black steel, broad at the guard, a long taper to a hard point.
  final blade = poly(const [Offset(-w, 12), Offset(w, 12), Offset(w - .5, 40), Offset(w - 2, len - 22), Offset(0, len), Offset(-w + 2, len - 22), Offset(-w + .5, 40)]);
  fillPath(c, blade, const [Color(0xFF6E6C78), Color(0xFF2C2A32), Color(0xFF0E0D12)], const Offset(-w, 0), const Offset(w, 0), width: 1.6);
  // Bright honed edges.
  c.drawLine(const Offset(w - .8, 14), const Offset(w - 2.3, len - 22), strokePaint(const Color(0x88D8D8E8), 1));
  c.drawLine(const Offset(w - 2.3, len - 22), const Offset(.4, len - 1.5), strokePaint(const Color(0x88D8D8E8), 1));
  // The ember crack down the middle: a jagged seam of fire with a glow around it.
  final crack = Path()..moveTo(0, 18);
  var y = 18.0, x = 0.0;
  var i = 0;
  while (y < len - 30) {
    y += 9 + (i * 7 % 5);
    x = (i.isEven ? 1.0 : -1.0) * (1.2 + (i * 3 % 4) * .5);
    crack.lineTo(x, y);
    i++;
  }
  c.drawPath(crack, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeJoin = StrokeJoin.round
    ..color = Color.fromRGBO(255, 110, 30, .45 * pulse)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  c.drawPath(crack, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeJoin = StrokeJoin.round
    ..color = Color.lerp(const Color(0xFFFF6A1A), const Color(0xFFFFD27A), pulse)!);
  c.drawPath(crack, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..color = const Color(0xFFFFF4C8));
  // The crossguard: a bar of gold with five crown shards rising along the blade.
  fillPath(c, poly(const [Offset(-24, 6), Offset(24, 6), Offset(22, 13), Offset(-22, 13)]), _goldRamp, const Offset(0, 6), const Offset(0, 13));
  for (final (sx, h) in const [(-19.0, 12.0), (-10.0, 17.0), (0.0, 24.0), (10.0, 17.0), (19.0, 12.0)]) {
    fillPath(c, poly([Offset(sx - 3.4, 12), Offset(sx + 3.4, 12), Offset(sx + (sx == 0 ? 0 : sx.sign * 1.5), 12 + h)]), _goldRamp, Offset(sx - 3.4, 12), Offset(sx + 3.4, 12));
  }
  c.drawCircle(const Offset(0, 9.5), 2.6, Paint()..color = const Color(0xFFFF8A3A));
}

void _wyrmblade(Canvas c, Ramp blade, Look look) {
  const len = 152.0, w = 8.0;
  const ivory = [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)];
  capsule(c, const Offset(0, -28), 3.4, const Offset(0, 6), 3.4, const [Color(0xFF5A2E22), Color(0xFF3A1A12), Color(0xFF1A0A06)]);
  // Pommel: a curved fang.
  fillPath(
    c,
    Path()
      ..moveTo(-3.5, -28)
      ..quadraticBezierTo(-6, -36, -1, -42)
      ..quadraticBezierTo(1, -36, 3.5, -28)
      ..close(),
    ivory,
    const Offset(-4, -40),
    const Offset(4, -28),
  );
  // Teeth down the cutting edge (drawn first, so the blade overlaps their roots).
  for (var y = 22.0; y < len - 24; y += 11) {
    fillPath(
      c,
      Path()
        ..moveTo(w - 1.5, y)
        ..lineTo(w + 5.5, y + 4)
        ..lineTo(w - 1.5, y + 8)
        ..close(),
      ivory,
      Offset(w, y),
      Offset(w + 5, y + 8),
    );
  }
  // Spikes along the spine.
  for (var y = 30.0; y < len - 40; y += 16) {
    fillPath(
      c,
      Path()
        ..moveTo(-w + 1, y)
        ..lineTo(-w - 4, y + 6)
        ..lineTo(-w + 1, y + 9)
        ..close(),
      blade,
      Offset(-w - 4, y),
      Offset(-w, y + 9),
    );
  }
  final b = Path()
    ..moveTo(-w + 1, 10)
    ..lineTo(w - 1, 10)
    ..lineTo(w, len - 30)
    ..quadraticBezierTo(w - 1, len - 10, 0, len)
    ..quadraticBezierTo(-w * .6, len - 16, -w + 1, len - 34)
    ..close();
  fillPath(c, b, blade, const Offset(-w, 0), const Offset(w, 0), width: 1.6);
  // A groove down the middle, lit along one lip.
  c.drawLine(const Offset(-1, 16), const Offset(-1, len - 40), strokePaint(const Color(0x80000000), 2));
  c.drawLine(const Offset(1.2, 16), const Offset(1.2, len - 40), strokePaint(const Color(0x55FFFFFF), .9));
  // The guard: two horns curving forward, and a bar over the blade.
  for (final side in const [-1.0, 1.0]) {
    fillPath(
      c,
      Path()
        ..moveTo(0, 6)
        ..quadraticBezierTo(side * 14, 4, side * 24, 14)
        ..quadraticBezierTo(side * 15, 9, 0, 11)
        ..close(),
      ivory,
      Offset(side * 24, 4),
      const Offset(0, 12),
      width: 1.2,
    );
  }
  fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 8.5), width: 14, height: 7), const Radius.circular(2))), blade, const Offset(0, 5), const Offset(0, 12));
  c.drawCircle(const Offset(0, 8.5), 2.2, Paint()..color = look.armourGlow ?? const Color(0xFFE0502A));
}

const _hornIvory = [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)];
const _hornIvoryFar = [Color(0xFFD8CCB0), Color(0xFFB0A282), Color(0xFF4E4430)];

/// A small curved horn from [base] pointing along [angle] (radians), [len] long and [w] wide at
/// the root; it curls a little towards [curl] (+1 or -1).
void _spike(Canvas c, Offset base, double angle, double len, double w, {bool far = false, double curl = 1}) {
  c.save();
  c.translate(base.dx, base.dy);
  c.rotate(angle);
  final p = Path()
    ..moveTo(0, -w / 2)
    ..quadraticBezierTo(len * .55, -w * .45 - curl * len * .12, len, -curl * len * .22)
    ..quadraticBezierTo(len * .5, w * .4 - curl * len * .05, 0, w / 2)
    ..close();
  fillPath(c, p, far ? _hornIvoryFar : _hornIvory, Offset(0, -w), Offset(0, w), width: 1.1);
  c.restore();
}

Offset _polar(double angle, double d) => Offset(math.cos(angle) * d, math.sin(angle) * d);

double _dir(Offset from, Offset to) => math.atan2(to.dy - from.dy, to.dx - from.dx);

/// Wyrmscale on an arm: a horn on the shoulder, one swept back from the elbow, two fins along the
/// forearm (the armour), and spiked knuckles (the gloves).
void _armHorns(Canvas c, Skeleton sk, Arm a, Look look, {bool far = false}) {
  final b = sk.build;
  if (look.wyrmHorns) {
    // Shoulder: up and back.
    _spike(c, a.shoulder + Offset(-b.upper.$1 * .2, -b.upper.$1 * 1.1), -math.pi * .72, 19, 8, far: far, curl: -1);
    // Layered blades fanned behind it, like scales standing on end.
    _spike(c, a.shoulder + Offset(-b.upper.$1 * .7, -b.upper.$1 * .6), -math.pi * .85, 15, 7, far: far, curl: -1);
    _spike(c, a.shoulder + Offset(-b.upper.$1 * 1.0, b.upper.$1 * .1), -math.pi * .97, 12, 6, far: far, curl: -1);
    // Elbow: carrying on past the elbow, away from the hand.
    final back = _dir(a.hand, a.elbow);
    _spike(c, a.elbow, back - .35, 17, 7.5, far: far);
    // Fins along the forearm, angled back towards the elbow.
    for (final k in const [.5]) {
      final at = Offset.lerp(a.elbow, a.hand, k)!;
      _spike(c, at + _polar(back - math.pi / 2, b.fore.$1 * .8), back - math.pi / 2 + .7, 10, 5, far: far);
    }
  }
  if (look.wyrmGloves) {
    final along = _dir(a.elbow, a.hand);
    for (final dy in const [-.5, .5]) {
      _spike(c, a.hand + _polar(along + math.pi / 2, dy * b.hand), along - .25, 8, 3.6, far: far);
    }
  }
}

/// Wyrmscale on a leg: a horn jutting forward from the knee (the armour), and a spur at the heel
/// and a horn over the toe (the boots).
void _legHorns(Canvas c, Skeleton sk, Leg l, Look look, {bool far = false}) {
  final b = sk.build;
  if (look.wyrmHorns) {
    final up = _dir(l.ankle, l.knee);
    _spike(c, l.knee + Offset(b.thigh.$2 * .5, 0), up + 1.15, 16, 7.5, far: far, curl: -1);
    // A smaller one at the hip guard.
    _spike(c, Offset.lerp(l.hip, l.knee, .3)! + Offset(-b.thigh.$1 * .9, 0), math.pi * .95, 11, 5.5, far: far);
  }
  if (look.wyrmBoots) {
    _spike(c, l.ankle + Offset(-b.shin.$2 * .9, b.shin.$2 * .4), math.pi * .95, 13, 6, far: far);
    _spike(c, l.ankle + Offset(b.foot * .75, b.shin.$2 * .1), -.75, 10, 4.5, far: far, curl: -1);
  }
}


/// Angular forged vambrace: two-piece shell, broad cuff, high-contrast keel.
void _forgedVambrace(Canvas c, Offset elbow, Offset wrist, double r, Look look, {bool far=false}) {
  final d=wrist-elbow, len=d.distance;
  if(len<4)return;
  final u=d/len,n=Offset(-u.dy,u.dx);
  final a=Offset.lerp(elbow,wrist,.18)!, z=Offset.lerp(elbow,wrist,.83)!;
  final rr=r*(far?1.00:1.2);
  final shell=poly([a+n*rr*.85,a-n*rr*.8,z-n*rr*.72+u*2,z+n*rr*.88+u*2]);
  final metal=far?darker(look.fore):look.fore;
  fillPath(c,shell,[metal[0],metal[1],metal[2]],a+n*rr,z-n*rr,width:2);
  c.drawLine(a+n*rr*.22,z+n*rr*.2,strokePaint(metal[0],1.8));
  c.drawLine(a-n*rr*.48,z-n*rr*.44,strokePaint(const Color(0xA0090909),2.1));
  for(final q in [a,z]) {
    c.drawLine(q+n*rr,q-n*rr,strokePaint(const Color(0xFF211C1B),2.2));
    c.drawLine(q+n*rr-u*1.5,q-n*rr-u*1.5,strokePaint(metal[0],1));
    if(!far)_rivet(c,q+n*rr*.65,1.5,const Color(0xFFC9A36B));
  }
}

/// Shin plate is faceted and pointed at the ankle, rather than a plain capsule.
void _forgedGreave(Canvas c, Offset knee, Offset ankle, double r, Look look,{bool far=false}) {
  final d=ankle-knee,len=d.distance;
  if(len<5)return;
  final u=d/len,n=Offset(-u.dy,u.dx),metal=far?darker(look.shin):look.shin;
  final top=Offset.lerp(knee,ankle,.19)!,bottom=Offset.lerp(knee,ankle,.94)!;
  final shell=poly([top+n*r*1.28,top-n*r*1.08,bottom-n*r*.58,bottom+u*3,bottom+n*r*.76]);
  fillPath(c,shell,[metal[0],metal[1],metal[2]],top+n*r,bottom-n*r,width:2.2);
  c.drawLine(top+n*r*.18,bottom+u*2,strokePaint(metal[0],2));
  c.drawLine(top-n*r*.6,bottom-n*r*.3,strokePaint(const Color(0x88000000),2));
  for(final f in [.27,.68]) {
    final q=Offset.lerp(top,bottom,f)!;
    c.drawLine(q+n*r*.92,q-n*r*.78,strokePaint(const Color(0xBB201915),1.6));
    if(!far)_rivet(c,q+n*r*.7,1.3,const Color(0xFFC9A36B));
  }
}

/// Quilting on a padded jerkin: a diamond grid of stitched seams, each a shadow with a lit edge.
void _quilt(Canvas c, Path path, Ramp col) {
  final b = path.getBounds();
  final seam = strokePaint(shade(col[2], -.3).withValues(alpha: .55), 1.2), lit = strokePaint(shade(col[0], .2).withValues(alpha: .35), .8);
  c.save();
  c.clipPath(path);
  for (var d = -b.height; d < b.width + b.height; d += 9) {
    for (final s in const [1.0, -1.0]) {
      final p0 = Offset(b.left + d, s > 0 ? b.top : b.bottom), p1 = Offset(b.left + d + b.height, s > 0 ? b.bottom : b.top);
      c.drawLine(p0, p1, seam);
      c.drawLine(p0 + const Offset(1.2, 0), p1 + const Offset(1.2, 0), lit);
    }
  }
  c.restore();
}
// Additional stitch knots and reinforced seams stay within the jerkin silhouette.
enum _Kit { quilt, mail, plate }

_Kit _kitOf(Look l) => l.knee != null ? _Kit.plate : (l.torsoKind == TorsoKind.mail ? _Kit.mail : _Kit.quilt);

const _brass = Color(0xFFC9A24E);

void _rivet(Canvas c, Offset at, double s, Color metal) {
  c.drawCircle(at, s, Paint()..color = shade(metal, -.45));
  c.drawCircle(at - Offset(s * .3, s * .3), s * .5, Paint()..color = shade(metal, .35));
}

/// Surface work on one limb segment from [a] (radius [ra]) to [b] (radius [rb]): light along the
/// top, shadow underneath, and then plates, mail or quilting to suit the kit.
void _segment(Canvas c, Offset a, double ra, Offset b, double rb, Ramp col, _Kit kit, Look look, {bool far = false, int lames = 3, bool rivets = true}) {
  final d = b - a, len = d.distance;
  if (len < 2) return;
  final u = d / len;
  var n = Offset(-u.dy, u.dx);
  if (n.dy > 0) n = -n; // n points up, toward the light
  var path = capsulePath(a, ra, b, rb);
  final k = far ? .6 : 1.0;
  if (kit == _Kit.plate) {
    // Plate stands proud of the limb: a fuller shell over it.
    path = capsulePath(a, ra * 1.18, b, rb * 1.18);
    fillPath(c, path, col, a + n * ra, a - n * ra, width: 1.6);
  }
  c.save();
  c.clipPath(path);
  // Light along the top edge, shadow along the bottom: the limb reads round.
  c.drawLine(a + n * ra * .5, b + n * rb * .5, strokePaint(Color.fromRGBO(255, 255, 255, (kit == _Kit.plate ? .3 : .14) * k), math.max(1.2, ra * .32)));
  c.drawLine(a - n * ra * .7, b - n * rb * .7, strokePaint(Color.fromRGBO(0, 0, 0, .28 * k), math.max(1.4, ra * .45)));
  if (look.blackIron) {
    // Soot darkening toward the far end of the limb (the hand or the foot), clipped to it.
    c.drawPath(path, Paint()..shader = ui.Gradient.linear(a, b, [const Color(0x0014100E), const Color(0x8014100E)]));
  }
  switch (kit) {
    case _Kit.plate:
      // Overlapping lames across the limb, each with a dark lip and a lit edge.
      for (var i = 0; i < lames; i++) {
        final f = .14 + i * .16;
        final q = Offset.lerp(a, b, f)!, r = ra + (rb - ra) * f;
        final bend = u * r * .35;
        final lip = Path()
          ..moveTo((q + n * r * 1.2).dx, (q + n * r * 1.2).dy)
          ..quadraticBezierTo((q + bend).dx, (q + bend).dy, (q - n * r * 1.2).dx, (q - n * r * 1.2).dy);
        c.drawPath(lip, strokePaint(Color.fromRGBO(0, 0, 0, .55 * k), 2.2));
        c.drawPath(lip.shift(-u * 1.6), strokePaint(shade(col[0], .3).withValues(alpha: .8 * k), 1));
        if (rivets && !far) _rivet(c, q + n * r * .55 - u * 2.6, 1.15, look.blackIron ? _brass : col[0]);
      }
      // A raised ridge down the middle.
      c.drawLine(a + n * ra * .08, b + n * rb * .08, strokePaint(Color.fromRGBO(255, 255, 255, .35 * k), 1));
      if (look.blackIron) c.drawLine(a - n * ra * .9, b - n * rb * .9, strokePaint(Color.fromRGBO(255, 120, 40, .25 * k), 1.4));
    case _Kit.mail:
      c.restore();
      mailTexture(c, path, glint: look.blackIron ? Color.fromRGBO(180, 188, 198, .5 * k) : null);
      c.save();
    case _Kit.quilt:
      // Stitched channels running along the sleeve or leg.
      for (final o in const [-.35, .35]) {
        c.drawLine(a + n * ra * o, b + n * rb * o, strokePaint(Color.fromRGBO(0, 0, 0, .3 * k), 1.1));
        c.drawLine(a + n * (ra * o + 1.1), b + n * (rb * o + 1.1), strokePaint(Color.fromRGBO(255, 255, 255, .12 * k), .7));
      }
      for (var f = .15; f < .95; f += .22) {
        final q = Offset.lerp(a, b, f)!, r = ra + (rb - ra) * f;
        c.drawLine(q + n * r, q - n * r, strokePaint(Color.fromRGBO(0, 0, 0, .22 * k), 1));
      }
  }
  c.restore();
}

/// Armour work down an arm: plates or mail on the upper arm, a vambrace (or quilted sleeve) on the
/// forearm and a flared cuff at the wrist.
void _armKit(Canvas c, Skeleton sk, Arm arm, Look look, {bool far = false}) {
  final b = sk.build, kit = _kitOf(look);
  final re = (b.upper.$2 + b.fore.$1) / 2;
  // A mail shirt over padding (the starting kit) leaves quilted sleeves; a hauberk has mail ones.
  final sleeve = kit == _Kit.mail && !look.blackIron ? _Kit.quilt : kit;
  _segment(c, arm.shoulder, b.upper.$1, arm.elbow, re, far ? darker(look.upper) : look.upper, sleeve, look, far: far, lames: kit == _Kit.plate ? 2 : 3);
  final foreKit = kit == _Kit.mail ? _Kit.quilt : kit; // leather bracers over mail
  _segment(c, arm.elbow, re, arm.hand, b.fore.$2, far ? darker(look.fore) : look.fore, foreKit, look, far: far, lames: 1);
  if (kit == _Kit.plate) {
    final cop = look.elbow ?? look.upper;
    _poleyn(c, arm.shoulder, arm.elbow, arm.hand, b.upper.$2 * 1.3, far ? darker(cop) : cop);
    _fist(c, arm.elbow, arm.hand, b.hand * 1.12, far ? darker(look.hand) : look.hand);
  }
  if (kit == _Kit.plate) _forgedVambrace(c, arm.elbow, arm.hand, b.fore.$1, look, far: far);
  // The cuff: a flared band just above the hand, plate or leather.
  final d = arm.hand - arm.elbow, len = d.distance;
  if (len < 2) return;
  final u = d / len, n = Offset(-u.dy, u.dx), q = arm.hand - u * b.hand * 1.3, r = b.fore.$2 * 1.35;
  final col = far ? darker(look.hand) : look.hand;
  final cuff = poly([q - u * 3 + n * r * .85, q + u * 2.5 + n * r, q + u * 2.5 - n * r, q - u * 3 - n * r * .85]);
  fillPath(c, cuff, col, q + n * r, q - n * r, width: 1.2);
  c.drawLine(q + u * 2 + n * r * .9, q + u * 2 - n * r * .9, strokePaint(shade(col[0], .3).withValues(alpha: .7), 1));
  if (look.blackIron && !far) _rivet(c, q, 1.1, _brass);
}

/// Armour work down a leg: cuisses or mail on the thigh, greaves (or boot leather) on the shin, and
/// on plate, sabatons over the foot. Every kit gets a strapped and buckled boot.
void _legKit(Canvas c, Skeleton sk, Leg l, Look look, {bool far = false}) {
  final b = sk.build, kit = _kitOf(look);
  final kr = (b.thigh.$2 + b.shin.$1) / 2;
  final legKit = kit == _Kit.mail && !look.blackIron ? _Kit.quilt : kit;
  _segment(c, l.hip, b.thigh.$1, l.knee, kr, far ? darker(look.thigh) : look.thigh, legKit, look, far: far, lames: kit == _Kit.plate ? 2 : 3);
  if (kit == _Kit.plate) {
    _segment(c, l.knee, kr, l.ankle, b.shin.$2, far ? darker(look.shin) : look.shin, kit, look, far: far, lames: 0, rivets: false);
    final cop = look.knee ?? look.thigh;
    _poleyn(c, l.hip, l.knee, l.ankle, b.thigh.$2 * 1.35, far ? darker(cop) : cop);
    _forgedGreave(c, l.knee, l.ankle, b.shin.$1, look, far: far);
    // (The steel boot itself carries the shine; no extra lines across the foot.)
  } else {
    // A strap and buckle round the boot shaft, and stitching down the side.
    final r = b.shin.$2 + .6, y = l.ankle.dy - r * 1.6;
    c.drawLine(Offset(l.ankle.dx - r * .9, y), Offset(l.ankle.dx + r * .9, y + 1), strokePaint(const Color(0xFF2A1A10), 2.4)..strokeCap = StrokeCap.butt);
    if (!far) {
      final buckle = Rect.fromCenter(center: Offset(l.ankle.dx + r * .45, y + .5), width: 4, height: 4.4);
      c.drawRect(buckle, strokePaint(_brass, 1.2));
    }
  }
}


/// The skirt of plate below the breastplate: overlapping lames over the hips, each with a lit
/// lower edge and a rivet at the front, and a glimpse of mail beneath.
void _faulds(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, p = sk.pelvis, m = look.torso;
  Offset pt(double fw, double up) => sk.at(p, b.hip * fw, up);
  // Mail hanging below.
  final mail = poly([pt(-.6, -16), pt(.75, -16), pt(.6, -30), pt(-.45, -28)]);
  fillPath(c, mail, ramp(0xFF5E636A, .3, .5), pt(0, -16), pt(0, -30), width: 1);
  mailTexture(c, mail, glint: const Color(0x66B4BCC6));
  for (var i = 2; i >= 0; i--) {
    final top = 4.0 - i * 7.5, bottom = top - 9;
    final band = Path()
      ..moveTo(pt(-.82, top).dx, pt(-.82, top).dy)
      ..quadraticBezierTo(pt(0, top - 3).dx, pt(0, top - 3).dy, pt(.9, top + 1).dx, pt(.9, top + 1).dy)
      ..lineTo(pt(.98, bottom).dx, pt(.98, bottom).dy)
      ..quadraticBezierTo(pt(0, bottom - 4).dx, pt(0, bottom - 4).dy, pt(-.86, bottom + 1).dx, pt(-.86, bottom + 1).dy)
      ..close();
    fillPath(c, band, [shade(m[0], -.04 * i), shade(m[1], -.06 * i), m[2]], pt(0, top), pt(0, bottom), width: 1.3);
    c.drawPath(
      Path()
        ..moveTo(pt(-.8, bottom + 2).dx, pt(-.8, bottom + 2).dy)
        ..quadraticBezierTo(pt(0, bottom - 2).dx, pt(0, bottom - 2).dy, pt(.94, bottom + 1.5).dx, pt(.94, bottom + 1.5).dy),
      strokePaint(shade(m[0], .3).withValues(alpha: .8), 1),
    );
    _rivet(c, pt(.72, top - 3), 1.2, look.blackIron ? _brass : m[0]);
  }
}

/// Smouldered steel: soot scorched across the plates, warm rust-brown staining, bright worn edges
/// where the soot has rubbed off, and now and then an ember glinting in a seam.
void _smoulder(Canvas c, Skeleton sk, Look look, double t, bool still) {
  final b = sk.build;
  // Worn bright edges: short scratches where the steel shows through.
  final wear = strokePaint(const Color(0x99F2F4F6), .9);
  for (final (at, d) in [
    (sk.at(sk.chest, b.chest * .3, -b.spine * .35), const Offset(5, 2)),
    (sk.at(sk.chest, -b.chest * .2, -b.spine * .1), const Offset(4, -2)),
    (Offset.lerp(sk.legNear.hip, sk.legNear.knee, .3)!, const Offset(3, 4)),
    (Offset.lerp(sk.legNear.knee, sk.legNear.ankle, .3)!, const Offset(1, 5)),
  ]) {
    c.drawLine(at, at + d, wear);
  }
  // Embers caught in the seams.
  for (final (i, at) in [sk.at(sk.chest, b.chest * .5, -b.spine * .62), Offset.lerp(sk.legNear.knee, sk.legNear.ankle, .2)!, sk.armNear.elbow + const Offset(2, 3)].indexed) {
    final k = still ? .6 : (.5 + .5 * math.sin(t / 400 + i * 2.2)).clamp(0.0, 1.0);
    c.drawCircle(at, 3.2, Paint()..color = Color.fromRGBO(255, 120, 40, .3 * k)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    c.drawCircle(at, 1, Paint()..color = Color.fromRGBO(255, 210, 120, .9 * k));
  }
}


/// The painted knight, feet at [DrawOptions.at], sized to the drawn figure it replaces. It sways
/// with the pose (leaning into a swing, bobbing as it breathes), flashes when hit and fades out.
void _drawSprite(Canvas c, ui.Image img, Build b, Skeleton sk, Look look, double t, DrawOptions o, bool still) {
  // The figure (feet to helm) fills about 88% of the image; the sword rises above it.
  final h = b.height / .88, w = h * img.width / img.height;
  final rest = -(b.thighLen + b.shinLen);
  final bob = (sk.pelvis.dy - rest) * .6;
  c.save();
  c.translate(o.at.dx, o.at.dy);
  if (o.flip) c.scale(-1, 1);
  c.scale(o.scale, o.scale);
  if (o.rotation != 0) c.rotate(o.rotation * deg);
  if (o.shadow) {
    c.drawOval(Rect.fromCenter(center: const Offset(4, 1), width: b.hip * 4.6, height: 14), Paint()..color = Color.fromRGBO(0, 0, 0, .45 * o.alpha));
  }
  // Lean with the body, pivoting at the feet.
  c.rotate(sk.lean * deg * .6);
  final paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..color = Color.fromRGBO(0, 0, 0, o.alpha);
  if (o.tint != null) paint.colorFilter = o.tint;
  c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(-w * .5, -h + bob, w, h), paint);
  if (look.shine) _shine(c, sk, t, still);
  c.restore();
}

// ------------------------------------------------------------------- mummies

/// Linen wound round one limb segment, [a] (radius [ra]) to [b] (radius [rb]): each turn a slanted
/// band with a shadowed edge below and a lit edge above, a little uneven, the way old wrappings
/// sit.
void _bandage(Canvas c, Offset a, double ra, Offset b, double rb, Ramp linen, int seed) {
  final d = b - a, len = d.distance;
  if (len < 3) return;
  final u = d / len, n = Offset(-u.dy, u.dx), r = SeededRandom(seed);
  final dark = strokePaint(shade(linen[2], -.35).withValues(alpha: .6), 1.2);
  final lit = strokePaint(Color.lerp(linen[0], const Color(0xFFFFFFFF), .25)!.withValues(alpha: .55), .9);
  for (var s = 1.5 + r.next() * 2; s < len - 1; s += 4 + r.next() * 1.8) {
    final w = (ra + (rb - ra) * (s / len)) * 1.04, tilt = 2.2 + r.next() * 2.4;
    final p1 = a + u * s + n * w, p2 = a + u * (s + tilt) - n * w;
    c.drawLine(p1, p2, dark);
    c.drawLine(p1 - u * 1.4, p2 - u * 1.4, lit);
  }
  // Here and there a gap in the wrappings, dark underneath.
  if (r.next() < .6) {
    final q = Offset.lerp(a, b, .3 + r.next() * .4)! + n * (ra * (r.next() - .5));
    c.drawOval(Rect.fromCenter(center: q, width: ra * .9, height: ra * .5), Paint()..color = const Color(0x66201408));
  }
}

/// A loose end of bandage hanging from [at], swaying.
void _looseEnd(Canvas c, Offset at, double len, Ramp linen, double t, bool still, double phase) {
  final sway = still ? 0.0 : math.sin(t / 420 + phase) * 4;
  final end = at + Offset(sway - 3, len), mid = at + Offset(sway * .4 + 3, len * .5);
  final strip = Path()
    ..moveTo(at.dx - 1.6, at.dy)
    ..quadraticBezierTo(mid.dx - 1.6, mid.dy, end.dx - 1.2, end.dy)
    ..lineTo(end.dx + 1.6, end.dy + 1.5)
    ..quadraticBezierTo(mid.dx + 1.8, mid.dy, at.dx + 1.8, at.dy)
    ..close();
  fillPath(c, strip, linen, at + const Offset(-2, 0), at + const Offset(2, 0), width: 1);
}

void _bandageArm(Canvas c, Skeleton sk, Arm a, Ramp linen, int seed, double t, bool still) {
  final b = sk.build;
  _bandage(c, a.shoulder, b.upper.$1, a.elbow, b.upper.$2, linen, seed);
  _bandage(c, a.elbow, b.fore.$1, a.hand, b.fore.$2, linen, seed + 1);
  _looseEnd(c, Offset.lerp(a.elbow, a.hand, .55)!, b.fore.$1 * 2.6, linen, t, still, seed.toDouble());
}

void _bandageLeg(Canvas c, Skeleton sk, Leg l, Ramp linen, int seed, double t, bool still) {
  final b = sk.build, kr = (b.thigh.$2 + b.shin.$1) / 2;
  _bandage(c, l.hip, b.thigh.$1, l.knee, kr, linen, seed);
  _bandage(c, l.knee, kr, l.ankle, b.shin.$2, linen, seed + 1);
  if (seed == 7) _looseEnd(c, Offset.lerp(l.hip, l.knee, .7)!, b.thigh.$1 * 2.2, linen, t, still, 2);
}

/// Bands wound round the body, clipped to it, slanting alternately.
void _bandageTorso(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, path = _torsoPath(sk), r = SeededRandom(19);
  final dark = strokePaint(shade(look.torso[2], -.35).withValues(alpha: .6), 1.4);
  final lit = strokePaint(Color.lerp(look.torso[0], const Color(0xFFFFFFFF), .25)!.withValues(alpha: .5), 1);
  c.save();
  c.clipPath(path);
  final steps = 9;
  for (var i = 0; i < steps; i++) {
    final k = i / (steps - 1);
    final centre = Offset.lerp(sk.at(sk.chest, 0, 2), sk.at(sk.pelvis, 0, -4), k)!;
    final half = b.chest * 1.2, tilt = (i.isEven ? 1 : -1) * (3 + r.next() * 3);
    final p1 = centre - sk.forward * half + sk.up * tilt, p2 = centre + sk.forward * half - sk.up * tilt;
    c.drawLine(p1, p2, dark);
    c.drawLine(p1 + sk.up * 1.6, p2 + sk.up * 1.6, lit);
  }
  // Two dark rents where the linen has rotted through.
  for (final (fw, up) in const [(.25, -.35), (-.3, -.7)]) {
    c.drawOval(Rect.fromCenter(center: sk.at(sk.chest, b.chest * fw, b.spine * up), width: b.chest * .32, height: b.chest * .18), Paint()..color = const Color(0x77201408));
  }
  c.restore();
}

/// A broad collar of gold and lapis beads across the shoulders.
void _usekh(Canvas c, Skeleton sk) {
  final b = sk.build, centre = sk.at(sk.chest, b.chest * .1, 6);
  final rect = Rect.fromCenter(center: centre, width: b.chest * 2.8, height: b.chest * 2.3);
  final bands = const [Color(0xFFE8B84A), Color(0xFF2E5AA8), Color(0xFFE8B84A), Color(0xFF3AA89A), Color(0xFFE8B84A)];
  c.save();
  c.clipPath(_torsoPath(sk));
  for (var i = bands.length - 1; i >= 0; i--) {
    final grow = 1 - i * .14;
    final r = Rect.fromCenter(center: rect.center, width: rect.width * grow, height: rect.height * grow);
    c.drawArc(r, 0, math.pi, true, Paint()..color = bands[i]);
  }
  c.drawArc(rect, 0, math.pi, false, strokePaint(outline, 1.2));
  c.restore();
}
