// Beasts that walk on four (or eight) legs: bears, giant spiders and horses. Horses carry the
// unicorn, the centaurs (a rider's upper half on a headless horse) and every mount, including the
// ghostly steed of Spectral Charge. Drawn facing right with the feet at the origin; flip the canvas
// for a foe.

import 'dart:math' as math;
import 'package:flutter/painting.dart';

import 'paint_kit.dart';

// ------------------------------------------------------------------ horses

class HorseLook {
  const HorseLook({required this.coat, required this.mane, this.hoof = const Color(0xFF2A2220), this.eye = const Color(0xFF1A1210), this.horn, this.fire = false, this.barding, this.saddle, this.ghost = false, this.glow});
  final Ramp coat;
  final Color mane, hoof, eye;

  /// A unicorn's spiral horn.
  final Color? horn;

  /// A burning mane and tail and smouldering hooves (the Nightmare).
  final bool fire;

  /// A caparison over the body (warhorses), and a saddle.
  final Color? barding, saddle;

  /// See-through and glowing (Spectral Charge).
  final bool ghost;
  final Color? glow;
}

const ponyLook = HorseLook(coat: [Color(0xFFC89A6A), Color(0xFF8A5E36), Color(0xFF3A2614)], mane: Color(0xFFE8D8B0), saddle: Color(0xFF6A3A1E));
const warhorseLook = HorseLook(coat: [Color(0xFF6A4A36), Color(0xFF3A2618), Color(0xFF140C06)], mane: Color(0xFF1A120C), barding: Color(0xFF8A1E22), saddle: Color(0xFF3A2414));
const unicornLook = HorseLook(coat: [Color(0xFFFFFFFF), Color(0xFFD8DCE8), Color(0xFF7A80A0)], mane: Color(0xFFE8D8FF), hoof: Color(0xFFE8C060), eye: Color(0xFF3A6AB8), horn: Color(0xFFF6E2A0), glow: Color(0xFFE8D8FF));
const moonhornLook = HorseLook(coat: [Color(0xFFE8F0FF), Color(0xFFA8B8E0), Color(0xFF3A4A7A)], mane: Color(0xFF9AD8FF), hoof: Color(0xFFC8D8F0), eye: Color(0xFF9ADFFF), horn: Color(0xFFCFF0FF), glow: Color(0xFF9ADFFF));
const nightmareLook = HorseLook(coat: [Color(0xFF4A3A3E), Color(0xFF1E1418), Color(0xFF060304)], mane: Color(0xFFFF6A1A), hoof: Color(0xFFFF8A2A), eye: Color(0xFFFFD24A), fire: true, saddle: Color(0xFF2A1A1A));
const spectralLook = HorseLook(coat: [Color(0xFFE8FAFF), Color(0xFF9AD8F0), Color(0xFF3A7A9A)], mane: Color(0xFFCFF4FF), hoof: Color(0xFF9AD8F0), eye: Color(0xFFFFFFFF), ghost: true, glow: Color(0xFF9ADFFF));
const centaurLook = HorseLook(coat: [Color(0xFFB08458), Color(0xFF6E4A2A), Color(0xFF2A1A0E)], mane: Color(0xFF3A2A1A));
const centaurChiefLook = HorseLook(coat: [Color(0xFF7A7A80), Color(0xFF3E3E44), Color(0xFF141418)], mane: Color(0xFFE8E4DA), barding: Color(0xFF2E4A2A));

/// The horse for a mount id.
HorseLook horseFor(String id) => switch (id) {
  'pony' => ponyLook,
  'unicorn' => unicornLook,
  'nightmare' => nightmareLook,
  _ => warhorseLook,
};

/// Height of a horse's back above the ground at scale 1 (where a rider or a centaur's waist sits).
const horseBack = 92.0;

/// A horse standing or galloping ([gallop] is the stride phase, 0 to stand still). [headless] for a
/// centaur, whose rider's body is drawn on top.
void drawHorse(Canvas c, HorseLook look, Offset at, double scale, double t, {double gallop = 0, bool headless = false, bool still = false, double alpha = 1}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale, scale);
  final a = look.ghost ? alpha * .7 : alpha;
  if (look.glow != null) {
    c.drawOval(Rect.fromCenter(center: const Offset(4, -70), width: 220, height: 130), Paint()..color = look.glow!.withValues(alpha: (look.ghost ? .35 : .18) * alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
  }
  if (!look.ghost) c.drawOval(Rect.fromCenter(center: const Offset(6, 2), width: 150, height: 14), Paint()..color = Color.fromRGBO(0, 0, 0, .4 * alpha));
  final layered = a < 1;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
  final coat = look.coat, dark = [for (final x in coat) shade(x, -.28)];
  final breathe = still ? 0.0 : math.sin(t / 420) * 1.5;
  final run = gallop == 0 ? 0.0 : math.sin(gallop * math.pi * 2);
  final bob = gallop == 0 ? breathe : -run.abs() * 6;

  // Tail.
  final swish = still ? 0.0 : math.sin(t / 300) * 6 + run * 10;
  final tail = Path()
    ..moveTo(-58, -86 + bob)
    ..quadraticBezierTo(-84, -70 + swish, -78 - run * 14, -30 + swish);
  c.drawPath(tail, strokePaint(look.fire ? const Color(0xCCFF6A1A) : shade(look.mane, -.2), 12)..strokeCap = StrokeCap.round);
  c.drawPath(tail, strokePaint(look.fire ? const Color(0xEEFFD27A) : look.mane, 6)..strokeCap = StrokeCap.round);

  // Legs: a jointed foreleg and hind leg on each side, swinging with the stride.
  void leg(Offset hip, double swing, Ramp col, {required bool fore}) {
    final sw = math.sin(swing);
    final List<(Offset, double)> joints;
    if (fore) {
      // Foreleg: forearm down to the knee, a slim cannon bone, the fetlock and the hoof.
      final elbow = hip + Offset(sw * 6, 15);
      final knee = elbow + Offset(sw * 8 + 1, 19);
      final fetlock = knee + Offset(sw * 8, 20);
      joints = [(hip, 11), (elbow, 7.5), (knee, 5.2), (fetlock, 4.2), (fetlock + const Offset(3, 9), 4.6)];
    } else {
      // Hind leg: a heavy gaskin forward to the stifle, back to the hock, then straight down.
      final stifle = hip + Offset(8 + sw * 8, 18);
      final hock = stifle + Offset(-10 + sw * 6, 18);
      final fetlock = hock + Offset(3 + sw * 6, 20);
      joints = [(hip, 14), (stifle, 8.5), (hock, 5.4), (fetlock, 4.2), (fetlock + const Offset(3, 9), 4.6)];
    }
    limb(c, joints, [col, col, col, col]);
    final hoof = joints.last.$1;
    final h = Path()
      ..moveTo(hoof.dx - 5, hoof.dy - 2)
      ..lineTo(hoof.dx + 4, hoof.dy - 2)
      ..lineTo(hoof.dx + 7, hoof.dy + 5)
      ..lineTo(hoof.dx - 6, hoof.dy + 5)
      ..close();
    fillPath(c, h, [shade(look.hoof, .2), look.hoof, shade(look.hoof, -.4)], hoof + const Offset(0, -2), hoof + const Offset(0, 5));
    if (look.fire) c.drawCircle(hoof, 5, Paint()..color = const Color(0x88FF6A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  final y0 = -66 + bob;
  leg(Offset(-44, y0), run * .9 + .1, dark, fore: false);
  leg(Offset(38, y0 + 4), -run * .9, dark, fore: true);

  // Body: a deep chest, a long back and round haunches.
  final body = Path()
    ..moveTo(-62, -74 + bob)
    ..quadraticBezierTo(-68, -102 + bob, -40, -100 + bob)
    ..quadraticBezierTo(-14, -92 + bob, 10, -96 + bob)
    ..quadraticBezierTo(42, -104 + bob, 58, -88 + bob)
    ..quadraticBezierTo(68, -70 + bob, 54, -54 + bob)
    ..quadraticBezierTo(30, -46 + bob, 4, -52 + bob)
    ..quadraticBezierTo(-24, -48 + bob, -46, -54 + bob)
    ..quadraticBezierTo(-62, -58 + bob, -62, -74 + bob)
    ..close();
  fillPath(c, body, coat, Offset(0, -100 + bob), Offset(0, -50 + bob));
  // Near legs grow out from under the body: draw them, then lay the body's fill back over the tops.
  leg(Offset(-38, y0 + 2), -run * .9 - .1, coat, fore: false);
  leg(Offset(44, y0 + 6), run * .9, coat, fore: true);
  fillPath(c, body, coat, Offset(0, -100 + bob), Offset(0, -50 + bob), line: false);
  if (look.barding != null) {
    // A caparison with a trimmed hem.
    final cloth = Path()
      ..moveTo(-52, -92 + bob)
      ..quadraticBezierTo(0, -86 + bob, 50, -92 + bob)
      ..lineTo(54, -50 + bob)
      ..lineTo(30, -42 + bob)
      ..lineTo(0, -48 + bob)
      ..lineTo(-30, -42 + bob)
      ..lineTo(-56, -50 + bob)
      ..close();
    fillPath(c, cloth, [shade(look.barding!, .2), look.barding!, shade(look.barding!, -.45)], Offset(0, -92 + bob), Offset(0, -42 + bob));
    c.drawPath(
      Path()
        ..moveTo(-56, -50 + bob)
        ..lineTo(-30, -42 + bob)
        ..lineTo(0, -48 + bob)
        ..lineTo(30, -42 + bob)
        ..lineTo(54, -50 + bob),
      strokePaint(const Color(0xFFE2C46A), 2.4),
    );
  }
  if (look.saddle != null && !headless) {
    final saddle = Path()
      ..moveTo(-22, -96 + bob)
      ..quadraticBezierTo(-6, -90 + bob, 14, -96 + bob)
      ..lineTo(16, -88 + bob)
      ..quadraticBezierTo(-4, -82 + bob, -24, -88 + bob)
      ..close();
    fillPath(c, saddle, [shade(look.saddle!, .2), look.saddle!, shade(look.saddle!, -.5)], Offset(0, -98 + bob), Offset(0, -84 + bob));
    c.drawLine(Offset(-2, -88 + bob), Offset(-2, -60 + bob), strokePaint(shade(look.saddle!, -.4), 2));
  }


  if (!headless) {
    // Neck, head and mane.
    final neck = Path()
      ..moveTo(36, -96 + bob)
      ..quadraticBezierTo(52, -126 + bob, 66, -146 + bob)
      ..lineTo(86, -136 + bob)
      ..quadraticBezierTo(74, -108 + bob, 62, -74 + bob)
      ..close();
    fillPath(c, neck, coat, Offset(40, -146 + bob), Offset(80, -80 + bob));
    final head = Path()
      ..moveTo(64, -150 + bob)
      ..quadraticBezierTo(80, -160 + bob, 92, -146 + bob)
      ..lineTo(114, -118 + bob)
      ..quadraticBezierTo(118, -108 + bob, 106, -106 + bob)
      ..quadraticBezierTo(90, -110 + bob, 80, -126 + bob)
      ..close();
    fillPath(c, head, coat, Offset(64, -160 + bob), Offset(116, -106 + bob));
    c.drawPath(poly([Offset(70, -150 + bob), Offset(74, -166 + bob), Offset(80, -150 + bob)]), Paint()..color = coat[1]);
    c.drawCircle(Offset(88, -140 + bob), 2.8, Paint()..color = look.eye);
    if (look.ghost || look.fire || look.horn != null) {
      c.drawCircle(Offset(88, -140 + bob), 6, Paint()..color = (look.fire ? const Color(0xFFFFD24A) : (look.glow ?? look.eye)).withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    c.drawCircle(Offset(110, -112 + bob), 1.8, Paint()..color = const Color(0xFF1A1210));
    if (look.horn != null) {
      // A spiral horn on the brow.
      final horn = poly([Offset(80, -156 + bob), Offset(110, -196 + bob), Offset(88, -152 + bob)]);
      fillPath(c, horn, [shade(look.horn!, .3), look.horn!, shade(look.horn!, -.4)], Offset(80, -196 + bob), Offset(110, -150 + bob));
      for (var i = 1; i < 5; i++) {
        final p = Offset.lerp(Offset(84, -154 + bob), Offset(110, -196 + bob), i / 5)!;
        c.drawLine(p + const Offset(-3, 1), p + const Offset(3, -2), strokePaint(shade(look.horn!, -.35), 1));
      }
      c.drawCircle(Offset(110, -196 + bob), 6, Paint()..color = (look.glow ?? look.horn!).withValues(alpha: .6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    // Mane along the neck, flowing back with the stride (flames for the Nightmare).
    for (var i = 0; i < 7; i++) {
      final base = Offset.lerp(Offset(66, -148 + bob), Offset(38, -98 + bob), i / 6)!;
      final flick = still ? 0.0 : math.sin(t / 160 + i) * 3;
      final tip = base + Offset(-16 - gallop.sign * 10 + flick, -6 + i * 1.5);
      final lock = Path()
        ..moveTo(base.dx + 4, base.dy - 3)
        ..quadraticBezierTo(base.dx - 6, base.dy - 10, tip.dx, tip.dy)
        ..quadraticBezierTo(base.dx - 4, base.dy + 2, base.dx + 2, base.dy + 6)
        ..close();
      c.drawPath(lock, Paint()..color = look.fire ? (i.isEven ? const Color(0xEEFF6A1A) : const Color(0xEEFFD27A)) : (i.isEven ? look.mane : shade(look.mane, -.15)));
    }
    if (look.saddle != null) c.drawLine(Offset(108, -116 + bob), Offset(40, -100 + bob), strokePaint(const Color(0xFF3A2414), 1.4));
  }
  if (layered) c.restore();
  c.restore();
}

// ------------------------------------------------------------------ bears

class BearLook {
  const BearLook({required this.fur, this.eye = const Color(0xFF1A0E08), this.scars = false});
  final Ramp fur;
  final Color eye;
  final bool scars;
}

const brownBear = BearLook(fur: [Color(0xFFA07048), Color(0xFF6A4426), Color(0xFF2A180A)]);
const caveBear = BearLook(fur: [Color(0xFF6A6058), Color(0xFF3A3430), Color(0xFF141210)], eye: Color(0xFFE84A2A), scars: true);

/// A bear on all fours, rearing back when [hit].
void drawBear(Canvas c, BearLook look, Offset at, double scale, double t, {double hit = 0, bool still = false}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale, scale);
  c.drawOval(Rect.fromCenter(center: const Offset(4, 2), width: 170, height: 16), Paint()..color = const Color(0x55000000));
  final fur = look.fur, dark = [for (final x in fur) shade(x, -.28)];
  final breathe = still ? 0.0 : math.sin(t / 500) * 2;
  c.rotate(-hit * .12);
  // Legs: thick pillars, the hind ones with a heavy thigh, each on a broad paw with pale claws.
  void paw(Offset p, Ramp col) {
    final pad = Path()
      ..moveTo(p.dx - 12, p.dy + 4)
      ..quadraticBezierTo(p.dx - 13, p.dy - 6, p.dx, p.dy - 7)
      ..quadraticBezierTo(p.dx + 16, p.dy - 6, p.dx + 17, p.dy + 3)
      ..quadraticBezierTo(p.dx + 16, p.dy + 6, p.dx + 10, p.dy + 6)
      ..lineTo(p.dx - 8, p.dy + 6)
      ..close();
    fillPath(c, pad, col, p + const Offset(0, -7), p + const Offset(0, 6));
    for (var i = 0; i < 4; i++) {
      final q = p + Offset(10.0 + i * 2.6, 2.0 + i * .6);
      c.drawPath(Path()..moveTo(q.dx, q.dy - 1.5)..quadraticBezierTo(q.dx + 5, q.dy, q.dx + 4, q.dy + 4), strokePaint(const Color(0xFFE8E2C8), 1.8)..strokeCap = StrokeCap.round);
    }
  }

  void fore(Offset top, Ramp col) {
    final elbow = top + const Offset(-2, 28), wrist = top + const Offset(4, 50);
    limb(c, [(top, 19), (elbow, 15), (wrist, 12.5)], [col, col], bulge: .2);
    paw(wrist + const Offset(2, 4), col);
  }

  void hind(Offset top, Ramp col) {
    final knee = top + const Offset(8, 24), hock = top + const Offset(-6, 40), foot = top + const Offset(0, 52);
    limb(c, [(top, 22), (knee, 15), (hock, 12), (foot, 11)], [col, col, col], bulge: .12);
    paw(foot + const Offset(2, 1), col);
  }

  hind(const Offset(-50, -56), dark);
  fore(const Offset(40, -58), dark);
  // Body: a great hump over the shoulders, the back dipping to a round rump.
  final b = breathe;
  final body = Path()
    ..moveTo(-82, -66)
    ..quadraticBezierTo(-92, -96 - b, -60, -100 - b)
    ..quadraticBezierTo(-24, -104 - b, 4, -118 - b)
    ..quadraticBezierTo(28, -140 - b, 56, -120)
    ..quadraticBezierTo(76, -96, 70, -70)
    ..quadraticBezierTo(64, -50, 40, -50)
    ..quadraticBezierTo(0, -52, -40, -52)
    ..quadraticBezierTo(-74, -50, -82, -66)
    ..close();
  fillPath(c, body, fur, const Offset(0, -130), const Offset(0, -40), width: 1.8);
  hind(const Offset(-40, -56), fur);
  fore(const Offset(50, -58), fur);
  c.save();
  c.clipPath(body);
  fillPath(c, body, fur, const Offset(0, -130), const Offset(0, -40), line: false);
  // Light on the hump, shadow on the belly, and the curve of shoulder and haunch.
  c.drawPath(
    Path()
      ..moveTo(-60, -96 - b)
      ..quadraticBezierTo(0, -110 - b, 30, -130 - b),
    strokePaint(fur[0].withValues(alpha: .45), 8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  c.drawPath(Path()..moveTo(-70, -48)..quadraticBezierTo(0, -40, 66, -50), strokePaint(shade(fur[2], -.1).withValues(alpha: .4), 12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  c.drawArc(Rect.fromCenter(center: const Offset(-48, -70), width: 46, height: 40), math.pi * .9, math.pi * .8, false, strokePaint(fur[2].withValues(alpha: .45), 1.8));
  c.drawArc(Rect.fromCenter(center: const Offset(46, -78), width: 36, height: 44), -math.pi * .1, math.pi * .8, false, strokePaint(fur[2].withValues(alpha: .35), 1.6));
  // Strokes of shaggy fur.
  final hair = strokePaint(fur[2].withValues(alpha: .35), 1.2);
  for (var i = 0; i < 14; i++) {
    final x = -64.0 + i * 9, y = -96.0 - (x > 0 ? x * .5 : 0) + (i.isEven ? 6 : 12);
    c.drawLine(Offset(x, y), Offset(x - 3, y + 7), hair);
  }
  c.restore();
  c.drawPath(body, strokePaint(outline, 1.8));
  // Shaggy tufts along the belly and the back of the haunch.
  final tuft = Paint()..color = shade(fur[1], -.1);
  for (var i = 0; i < 7; i++) {
    final x = -50.0 + i * 13, y = -51.0;
    c.drawPath(poly([Offset(x - 4, y - 2), Offset(x - 1, y + 5), Offset(x + 3, y - 2)]), tuft);
  }
  if (look.scars) {
    for (final y in const [-104.0, -96.0, -88.0]) {
      c.drawLine(Offset(-30, y), Offset(-4, y - 10), strokePaint(const Color(0xFFC8A8A0), 2));
    }
  }
  // Head: a broad skull, round ears, a pale muzzle, and a small, mean eye.
  c.save();
  c.translate(58, -90);
  c.rotate(.22 - hit * .2);
  c.scale(1.08, 1.08);
  for (final (dx, col) in [(2.0, dark), (16.0, fur)]) {
    c.drawCircle(Offset(dx, -22), 10, Paint()..color = col[1]);
    c.drawCircle(Offset(dx, -22), 10, strokePaint(outline, 1.4));
    c.drawCircle(Offset(dx + 1, -21), 5, Paint()..color = shade(look.fur[2], .2));
  }
  final head = Path()
    ..moveTo(-12, 20)
    ..quadraticBezierTo(-18, -20, 14, -26)
    ..quadraticBezierTo(38, -28, 44, -8)
    ..lineTo(62, -2)
    ..quadraticBezierTo(70, 6, 62, 16)
    ..lineTo(36, 22)
    ..quadraticBezierTo(12, 32, -12, 20)
    ..close();
  fillPath(c, head, fur, const Offset(0, -26), const Offset(0, 28));
  c.save();
  c.clipPath(head);
  c.drawPath(
    Path()
      ..moveTo(34, 24)
      ..quadraticBezierTo(34, -4, 48, -6)
      ..lineTo(72, -2)
      ..lineTo(72, 24)
      ..close(),
    Paint()..color = Color.lerp(fur[0], const Color(0xFFD8B890), .55)!,
  );
  c.drawLine(const Offset(2, -22), const Offset(34, -18), strokePaint(fur[0].withValues(alpha: .5), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
  c.restore();
  c.drawPath(head, strokePaint(outline, 1.6));
  c.drawPath(Path()..moveTo(14, -16)..quadraticBezierTo(24, -20, 36, -12), strokePaint(fur[2], 3));
  c.drawOval(Rect.fromCenter(center: const Offset(63, 2), width: 11, height: 8), Paint()..color = const Color(0xFF140C08));
  c.drawCircle(const Offset(61, 0), 1.5, Paint()..color = const Color(0x99FFFFFF));
  c.drawOval(Rect.fromCenter(center: const Offset(28, -9), width: 6, height: 5), Paint()..color = look.eye);
  c.drawCircle(const Offset(29, -9), 1.4, Paint()..color = const Color(0xFF0A0604));
  if (look.eye != const Color(0xFF1A0E08)) c.drawCircle(const Offset(28, -9), 7, Paint()..color = look.eye.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  // A snarl when struck.
  c.drawPath(Path()..moveTo(40, 14)..lineTo(60, 12), strokePaint(const Color(0xFF140C08), 1.8));
  if (hit > .1) {
    c.drawPath(poly(const [Offset(40, 14), Offset(60, 12), Offset(52, 26)]), Paint()..color = const Color(0xFF5A0E0E));
    for (final x in const [44.0, 54.0]) {
      c.drawPath(poly([Offset(x, 13), Offset(x + 2, 19), Offset(x + 4, 13)]), Paint()..color = const Color(0xFFF2EAD2));
    }
  }
  c.restore();
  c.restore();
}

// ------------------------------------------------------------------ spiders

class SpiderLook {
  const SpiderLook({required this.body, this.mark = const Color(0xFFC8302A), this.eyes = const Color(0xFFE8303A), this.crown = false});
  final Ramp body;
  final Color mark, eyes;

  /// The Spider Queen's bony crest.
  final bool crown;
}

const giantSpider = SpiderLook(body: [Color(0xFF5A5048), Color(0xFF2A2420), Color(0xFF0C0A08)]);
const spiderQueen = SpiderLook(body: [Color(0xFF4A3A5A), Color(0xFF221A2E), Color(0xFF0A060E)], mark: Color(0xFFE8C060), eyes: Color(0xFFB8F05A), crown: true);

/// A giant spider: a bulbous abdomen with a mark, a cluster of glowing eyes, eight jointed legs
/// skittering, and fangs.
void drawSpider(Canvas c, SpiderLook look, Offset at, double scale, double t, {double hit = 0, bool still = false}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale, scale);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 190, height: 18), Paint()..color = const Color(0x55000000));
  final body = look.body, dark = [for (final x in body) shade(x, -.2)];
  final step = still ? 0.0 : t / 140;
  final lift = -hit * 10;
  // Legs: four a side, each a raised knee and a long shin down to a point.
  void legs(bool far) {
    for (var i = 0; i < 4; i++) {
      final root = Offset(-6.0 + i * 10, -54 + lift);
      final dir = i < 2 ? -1.0 : 1.0, spread = (i % 2 == 0 ? 1.0 : .7);
      final wiggle = math.sin(step + i * 1.7 + (far ? 1.3 : 0)) * 5;
      final knee = root + Offset(dir * (36 + 14 * spread) * (far ? .8 : 1), -44 - 10 * spread + wiggle);
      final foot = Offset(root.dx + dir * (70 + 30 * spread) * (far ? .8 : 1), 0);
      final col = far ? dark : body;
      // A long femur up to the knee, then a shorter tibia that bends back out, and a fine tarsus
      // down to the tip.
      final ankle = Offset.lerp(knee, foot, .55)! + Offset(dir * 10, -10 - spread * 4);
      limb(c, [(root, 5.2), (knee, 4.0), (ankle, 3.0), (foot, 1.1)], [col, col, col], bulge: .12);
      // Pale bands at the joints and stiff bristles along the femur.
      for (final (j, r) in [(knee, 4.2), (ankle, 3.2)]) {
        c.drawCircle(j, r, strokePaint(shade(col[0], .15).withValues(alpha: .8), 1.4));
      }
      final d = knee - root, n = Offset(d.dy, -d.dx) / d.distance * dir;
      for (var k = 1; k <= 3; k++) {
        final q = Offset.lerp(root, knee, k / 4)!;
        c.drawLine(q + n * 3, q + n * 7 + d / d.distance * 3, strokePaint(col[2], 1));
      }
    }
  }

  legs(true);
  // Abdomen (behind) and the mark on it.
  final abdomen = Path()..addOval(Rect.fromCenter(center: Offset(-46, -70 + lift), width: 96, height: 76));
  fillPath(c, abdomen, body, Offset(-90, -100 + lift), Offset(0, -34 + lift), width: 1.6);
  final mark = Path()
    ..moveTo(-52, -96 + lift)
    ..lineTo(-44, -80 + lift)
    ..lineTo(-56, -68 + lift)
    ..lineTo(-44, -54 + lift)
    ..lineTo(-38, -66 + lift)
    ..lineTo(-30, -80 + lift)
    ..close();
  c.save();
  c.clipPath(abdomen);
  // Banded segments, a sheen and a fuzz of hairs.
  for (var i = 0; i < 4; i++) {
    c.drawArc(Rect.fromCenter(center: Offset(-26.0 + i * 6, -70 + lift), width: 40.0 + i * 22, height: 96), math.pi * .62, math.pi * .76, false, strokePaint(body[2].withValues(alpha: .5), 1.6));
  }
  c.drawOval(Rect.fromCenter(center: Offset(-58, -90 + lift), width: 36, height: 16), Paint()..color = const Color(0x38FFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  c.restore();
  for (var i = 0; i < 14; i++) {
    final a = math.pi * (.85 + i * .07);
    final q = Offset(-46 + math.cos(a) * 48, -70 + lift + math.sin(a) * 38);
    c.drawLine(q, q + Offset(math.cos(a) * 4, math.sin(a) * 4), strokePaint(body[2], 1.2));
  }
  c.drawPath(mark, Paint()..color = look.mark);
  c.drawPath(mark, strokePaint(shade(look.mark, -.4), 1));
  // The near legs grow out from under the head and thorax.
  legs(false);
  // Head and thorax.
  final head = Path()..addOval(Rect.fromCenter(center: Offset(18, -58 + lift), width: 58, height: 44));
  fillPath(c, head, body, Offset(-10, -80 + lift), Offset(46, -36 + lift));
  if (look.crown) {
    for (var i = 0; i < 5; i++) {
      final x = 2.0 + i * 8;
      c.drawPath(poly([Offset(x - 3, -76 + lift), Offset(x + 1, -94 + lift - (i % 2) * 6), Offset(x + 4, -76 + lift)]), Paint()..color = const Color(0xFFE8DCC0));
    }
  }
  // Eyes: two big, four small, glowing.
  for (final (p, r) in [(const Offset(36, -64), 4.6), (const Offset(28, -68), 4.0), (const Offset(40, -56), 2.4), (const Offset(32, -58), 2.2), (const Offset(22, -62), 2.0), (const Offset(42, -66), 2.0)]) {
    final q = p + Offset(0, lift);
    c.drawCircle(q, r + 3, Paint()..color = look.eyes.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(q, r, Paint()..color = look.eyes);
  }
  // A groove across the carapace, and two short feelers in front of the jaws.
  c.drawArc(Rect.fromCenter(center: Offset(10, -58 + lift), width: 30, height: 34), -math.pi * .4, math.pi * .8, false, strokePaint(body[2].withValues(alpha: .6), 1.4));
  c.drawOval(Rect.fromCenter(center: Offset(14, -72 + lift), width: 22, height: 8), Paint()..color = const Color(0x30FFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  for (final (dx, sw) in const [(30.0, 0.0), (40.0, 1.2)]) {
    final wig = still ? 0.0 : math.sin(t / 200 + sw) * 2;
    limb(c, [(Offset(dx, -46 + lift), 3.2), (Offset(dx + 10, -48 + lift + wig), 2.6), (Offset(dx + 14, -36 + lift + wig), 2.2)], [dark, dark]);
  }
  // Fangs.
  for (final dx in const [36.0, 44.0]) {
    final fang = Path()
      ..moveTo(dx, -44 + lift)
      ..quadraticBezierTo(dx + 6, -34 + lift, dx + 1, -26 + lift)
      ..quadraticBezierTo(dx + 1, -36 + lift, dx - 3, -42 + lift)
      ..close();
    c.drawPath(fang, Paint()..color = const Color(0xFFE8E2C8));
  }
  c.restore();
}

/// A dusty trail behind a galloping charge.
void drawDust(Canvas c, Offset at, double t, double strength) {
  final p = Paint()..color = Color.fromRGBO(200, 180, 140, .35 * strength);
  for (var i = 0; i < 6; i++) {
    final x = at.dx - i * 22, r = 10 + i * 3.0;
    c.drawCircle(Offset(x, at.dy - 6 - math.sin(t / 90 + i) * 4), r, p..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
}
