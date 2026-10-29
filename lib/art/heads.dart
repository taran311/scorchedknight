// Heads and helmets, drawn in a head-local frame that faces +x.

import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'looks.dart';
import 'paint_kit.dart';
import 'rig.dart';

void drawHead(Canvas c, Skeleton sk, Look look, double t, {bool still = false}) {
  final r = sk.build.head;
  c.save();
  c.translate(sk.head.dx, sk.head.dy);
  c.rotate(sk.headAngle * deg);
  if (look.female) _heroineHair(c, r, look);
  switch (look.head) {
    case HeadKind.coif || HeadKind.zombie || HeadKind.pillager || HeadKind.pillagerCap:
      _humanHead(c, r, look);
    case HeadKind.bare || HeadKind.nasal || HeadKind.wizardhat || HeadKind.cowl || HeadKind.circlet || HeadKind.scoutcap || HeadKind.rangerhood:
      _humanHead(c, r, look);
      _headwear(c, r, look, t, still);
    case HeadKind.greathelm:
      _greatHelm(c, r, look, t, still);
    case HeadKind.sallet:
      _helm(c, r, look, t, still);
    case HeadKind.goblin || HeadKind.goblinChief:
      _goblinHead(c, r, look);
    case HeadKind.ork || HeadKind.orkShaman || HeadKind.orkWarlord:
      _orkHead(c, r, look, t, still);
    case HeadKind.skull || HeadKind.skullHood || HeadKind.skullHelm || HeadKind.skullHorned:
      _skullHead(c, r, look);
    case HeadKind.hood || HeadKind.rangermask:
      _hoodHead(c, r, look);
    case HeadKind.ent:
      _entHead(c, r, look);
    case HeadKind.cyclops:
      _cyclopsHead(c, r, look, t, still);
    case HeadKind.gargoyle:
      _gargoyleHead(c, r, look);
    case HeadKind.pumpkin:
      _pumpkinHead(c, r, t, still);
    case HeadKind.demon:
      _demonHead(c, r, look);
    case HeadKind.bull:
      _bullHead(c, r, look);
    case HeadKind.ghoul:
      _ghoulHead(c, r, look);
    case HeadKind.banshee:
      _bansheeHead(c, r, look, t, still);
    case HeadKind.witch:
      _witchHead(c, r, look);
    case HeadKind.magemask:
      _humanHead(c, r, look);
      _mageMask(c, r, look, t, still);
    case HeadKind.wyrmhelm:
      _wyrmHelm(c, r, look, t, still);
    case HeadKind.wyrmcirclet:
      _humanHead(c, r, look);
      _hair(c, r, look);
      _wyrmCirclet(c, r, look);
    case HeadKind.mummy:
      _mummyHead(c, r, look, t, still);
    case HeadKind.pharaoh:
      _nemes(c, r, back: true);
      _mummyHead(c, r, look, t, still);
      _nemes(c, r, back: false);
    case HeadKind.veiled:
      _veiledHead(c, r, look, t, still);
    case HeadKind.golem:
      _golemHead(c, r, look, t, still);
    case HeadKind.vampire:
      _vampireHead(c, r, look);
    case HeadKind.wolf:
      _wolfHead(c, r, look);
    case HeadKind.elf:
      _elfHead(c, r, look);
    case HeadKind.dwarf:
      _dwarfHead(c, r, look);
    case HeadKind.faceless:
      _facelessHead(c, r, look);
    case HeadKind.lizard:
      _lizardHead(c, r, look);
    case HeadKind.shifter:
      _shifterHead(c, r, look, t, still);
    case HeadKind.bird:
      _birdHead(c, r, look);
    case HeadKind.kabuto:
      _kabuto(c, r, look);
    case HeadKind.jingasa:
      _humanHead(c, r, look);
      _jingasa(c, r, look);
    case HeadKind.eboshi:
      _humanHead(c, r, look);
      _hair(c, r, look);
      _eboshi(c, r);
    case HeadKind.topknot:
      _humanHead(c, r, look);
      _topknot(c, r, look);
    case HeadKind.oni:
      _oniHead(c, r, look);
    case HeadKind.bat:
      _batHead(c, r, look);
    case HeadKind.yeti:
      _yetiHead(c, r, look);
  }
  if (look.crown && look.head == HeadKind.shifter) {
    // The Thousandfold: a ring of faces, like the Mother of Masks, but every one of them its own.
    _maskRing(c, r);
  } else if (look.crown && look.head == HeadKind.faceless) {
    // The Mother of Masks: every face she took, hung in a ring round her head.
    _maskRing(c, r);
  } else if (look.crown && look.head != HeadKind.wizardhat && look.head != HeadKind.orkShaman && look.head != HeadKind.veiled) {
    _crown(c, r);
  }
  if (look.soot > 0) _sootyFace(c, r, look.soot);
  c.restore();
}

/// Soot on the face (or helm): a smudge on the cheek, one on the brow and a sooty nose. The hero
/// still grins through it.
void _sootyFace(Canvas c, double r, double s) {
  final smudge = Paint()
    ..color = Color.fromRGBO(34, 26, 22, .55 * s)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .12);
  _ellipse(c, Offset(r * .42, r * .3), r * .3, r * .16, smudge, -.3);
  _ellipse(c, Offset(-r * .1, -r * .65), r * .38, r * .14, smudge, .2);
  if (s > .3) _ellipse(c, Offset(r * 1.0, r * .02), r * .1, r * .09, Paint()..color = Color.fromRGBO(30, 22, 18, .6 * s));
}

/// A gold crown sat snugly on the head: a solid band with a red jewel, five points tipped with
/// little gold balls, and a glint along the band.
void _crown(Canvas c, double r) {
  const gold = [Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
  final left = -r * .78, right = r * .78, base = -r * .92, top = -r * 1.18;
  final points = Path()..moveTo(left, top + 1);
  for (var i = 0; i < 5; i++) {
    final x0 = left + (right - left) * i / 5, x1 = left + (right - left) * (i + 1) / 5;
    final tip = -r * (i == 2 ? 1.72 : (i.isEven ? 1.58 : 1.5));
    points
      ..lineTo((x0 + x1) / 2, tip)
      ..lineTo(x1, top + 1);
  }
  points.close();
  fillPath(c, points, gold, Offset(0, -r * 1.75), Offset(0, top));
  for (var i = 0; i < 5; i++) {
    final x = left + (right - left) * (i + .5) / 5;
    final tip = -r * (i == 2 ? 1.72 : (i.isEven ? 1.58 : 1.5));
    c.drawCircle(Offset(x, tip), r * .07, Paint()..color = gold[0]);
    c.drawCircle(Offset(x, tip), r * .07, strokePaint(outline, .8));
  }
  final band = Path()..addRRect(RRect.fromLTRBR(left - 1, top, right + 1, base, Radius.circular(r * .06)));
  fillPath(c, band, gold, Offset(0, top), Offset(0, base));
  c.drawLine(Offset(left + 2, top + 1.5), Offset(right - 2, top + 1.5), strokePaint(const Color(0xAAFFF6D0), 1));
  c.drawOval(Rect.fromCenter(center: Offset(0, (top + base) / 2), width: r * .22, height: r * .17), Paint()..color = const Color(0xFFD23A3A));
  c.drawCircle(Offset(-r * .03, (top + base) / 2 - r * .03), r * .035, Paint()..color = const Color(0xCCFFFFFF));
  for (final x in [left + r * .3, right - r * .3]) {
    c.drawCircle(Offset(x, (top + base) / 2), r * .05, Paint()..color = const Color(0xFF3A7AD2));
  }
}

void _ellipse(Canvas c, Offset centre, double rx, double ry, Paint p, [double rot = 0]) {
  if (rot == 0) {
    c.drawOval(Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2), p);
    return;
  }
  c.save();
  c.translate(centre.dx, centre.dy);
  c.rotate(rot);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
  c.restore();
}

void _humanHead(Canvas c, double r, Look look) {
  final zombie = look.head == HeadKind.zombie;
  final face = Path()
    ..moveTo(-r * .9, r * .2)
    ..quadraticBezierTo(-r * 1.05, -r * 1.15, r * .15, -r * 1.05)
    ..quadraticBezierTo(r * .95, -r * .95, r * .98, -r * .2)
    ..lineTo(r * 1.12, r * .05)
    ..lineTo(r * .95, r * .18)
    ..quadraticBezierTo(r * 1.0, r * .55, r * .86, r * .72);
  if (zombie) {
    face
      ..lineTo(r * .7, r * .75)
      ..lineTo(r * .72, r * 1.12)
      ..quadraticBezierTo(r * .2, r * 1.2, -r * .1, r * .95);
  } else {
    face.quadraticBezierTo(r * .55, r * 1.12, r * .05, r * 1.0);
  }
  face
    ..quadraticBezierTo(-r * .55, r * .9, -r * .9, r * .2)
    ..close();
  fillPath(c, face, look.skin, Offset(-r, -r), Offset(r, r));
  blob(c, Offset(-r * .15, r * .05), r * .22, [shade(look.skin[1], .1), look.skin[1], look.skin[2]]);
  c.drawArc(Rect.fromCircle(center: Offset(-r * .15, r * .05), radius: r * .11), -1, 3, false, strokePaint(const Color(0x66000000), 1.1));
  _ellipse(c, Offset(r * .6, -r * .22), r * .13, r * .08, Paint()..color = zombie ? const Color(0xFF2A2A20) : const Color(0xFFF0E8DA));
  c.drawCircle(Offset(r * .66, -r * .22), r * .055, Paint()..color = zombie ? const Color(0xFFD8E0B0) : const Color(0xFF2A1B10));
  c.drawPath(
    Path()
      ..moveTo(r * .38, -r * .4)
      ..quadraticBezierTo(r * .62, -r * .48, r * .86, -r * .36),
    strokePaint(look.hair, look.female ? 1.5 : 2.2),
  );
  if (look.female) {
    // Lashes, and a touch of colour on the lips.
    final lash = strokePaint(const Color(0xFF2A1B10), 1.1);
    c.drawLine(Offset(r * .72, -r * .29), Offset(r * .84, -r * .37), lash);
    c.drawLine(Offset(r * .64, -r * .3), Offset(r * .71, -r * .4), lash);
    c.drawLine(Offset(r * .72, r * .5), Offset(r * .88, r * .49), strokePaint(const Color(0xFFB0605A), 2));
  } else {
    c.drawLine(Offset(r * .7, r * .5), Offset(r * .88, r * .5), strokePaint(const Color(0x66000000), 1.2));
  }

  if (zombie) {
    c.drawPath(
      poly([Offset(r * .88, r * .55), Offset(r * .72, r * .62), Offset(r * .72, r * 1.0), Offset(r * .86, r * .82)]),
      Paint()..color = const Color(0xFF1A0E0A),
    );
    final hair = strokePaint(look.hair, 1.6);
    for (var i = 0; i < 6; i++) {
      c.drawLine(Offset(-r * .6 + i * r * .2, -r * .95 + (i - 2.5).abs() * 1.5), Offset(-r * .75 + i * r * .2, -r * .6), hair);
    }
    final scar = strokePaint(const Color(0xB35A140F), 1.5);
    c.drawLine(Offset(-r * .5, -r * .5), Offset(r * .1, -r * .2), scar);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-r * .4 + i * r * .15, -r * .52 + i * 2), Offset(-r * .32 + i * r * .15, -r * .3 + i * 2), scar);
    }
  }

  final pillager = look.head == HeadKind.pillager || look.head == HeadKind.pillagerCap;
  if (!pillager && !zombie && look.beard != null) _beard(c, r, look.beard!);
  if (pillager) {
    final beardCol = look.beard ?? const Color(0xFF7A4A24);
    final beard = Path()
      ..moveTo(r * .2, r * .05)
      ..quadraticBezierTo(r * 1.15, r * .1, r * 1.05, r * .6)
      ..quadraticBezierTo(r * .9, r * 1.55, r * .2, r * 1.6)
      ..quadraticBezierTo(-r * .2, r * 1.1, -r * .35, r * .4)
      ..quadraticBezierTo(-r * .1, r * .5, r * .2, r * .05)
      ..close();
    fillPath(c, beard, [shade(beardCol, .2), beardCol, shade(beardCol, -.45)], Offset.zero, Offset(0, r * 1.6));
    final strands = strokePaint(const Color(0x4D000000), 1);
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(r * (.2 + i * .16), r * .5), Offset(r * (.1 + i * .16), r * 1.4), strands);
    }
    final helm = Path()
      ..moveTo(-r * 1.02, -r * .15)
      ..quadraticBezierTo(-r * 1.0, -r * 1.25, r * .1, -r * 1.22)
      ..quadraticBezierTo(r * 1.1, -r * 1.1, r * 1.0, -r * .28)
      ..lineTo(-r * 1.02, -r * .15)
      ..close();
    fillPath(c, helm, ramp(0xFF8A9098, .3, .5), Offset(-r, -r), Offset(r, 0));
    fillPath(c, Path()..addRect(Rect.fromLTWH(-r * 1.05, -r * .38, r * 2.1, r * .22)), ramp(0xFF6E737A), Offset(0, -r * .4), Offset(0, -r * .15));
    fillPath(
      c,
      poly([Offset(r * .86, -r * .3), Offset(r * 1.0, -r * .3), Offset(r * 1.02, r * .25), Offset(r * .9, r * .3)]),
      ramp(0xFF6E737A),
      Offset.zero,
      Offset(r, 0),
    );
    final big = look.head == HeadKind.pillagerCap ? 1.35 : 1.0;
    for (final s in const [1.0, -.7]) {
      final bx = s > 0 ? r * .55 : -r * .65;
      final h = Path()
        ..moveTo(bx, -r * .95)
        ..quadraticBezierTo(bx + s * r * .9 * big, -r * 1.3 * big, bx + s * r * .85 * big, -r * 2.1 * big)
        ..quadraticBezierTo(bx + s * r * .4, -r * 1.4, bx - s * r * .25, -r * .85)
        ..close();
      fillPath(c, h, const [Color(0xFFF2EAD2), Color(0xFFCFC2A0), Color(0xFF7E7058)], Offset(bx, -r * 2), Offset(bx, -r * .8));
    }
  }

  if (look.head == HeadKind.coif) {
    // The hood, falling into a skirt of mail over the neck and shoulders.
    final hood = Path()
      ..moveTo(-r * 1.35, r * 2.05)
      ..quadraticBezierTo(-r * 1.15, r * 1.4, -r * 1.08, r * .9)
      ..quadraticBezierTo(-r * 1.35, -r * 1.3, r * .15, -r * 1.25)
      ..quadraticBezierTo(r * 1.25, -r * 1.1, r * 1.05, -r * .3)
      ..quadraticBezierTo(r * .55, -r * .75, r * .25, -r * .55)
      ..quadraticBezierTo(-r * .05, r * .1, r * .35, r * .85)
      ..quadraticBezierTo(r * .7, r * .95, r * .98, r * .95)
      ..lineTo(r * 1.02, r * 1.3)
      ..quadraticBezierTo(r * 1.25, r * 1.7, r * 1.2, r * 2.0)
      ..quadraticBezierTo(0, r * 2.25, -r * 1.35, r * 2.05)
      ..close();
    fillPath(c, hood, const [Color(0xFFB9BEC4), Color(0xFF7D838B), Color(0xFF353A40)], Offset(-r, -r), Offset(r, r));
    mailTexture(c, hood);
  }
}

void _helm(Canvas c, double r, Look look, double t, bool still) {
  final sallet = look.head == HeadKind.sallet;
  final h = Path();
  if (sallet) {
    h
      ..moveTo(-r * 1.9, r * .35)
      ..quadraticBezierTo(-r * 1.3, -r * .2, -r * 1.05, -r * .6)
      ..quadraticBezierTo(-r * .7, -r * 1.3, r * .2, -r * 1.25)
      ..quadraticBezierTo(r * 1.1, -r * 1.1, r * 1.12, -r * .2)
      ..lineTo(r * 1.15, r * .7)
      ..quadraticBezierTo(r * .4, r * 1.15, -r * .4, r * .9)
      ..quadraticBezierTo(-r * 1.2, r * .6, -r * 1.9, r * .35);
  } else {
    h
      ..moveTo(-r * .98, r * 1.05)
      ..lineTo(-r * 1.02, -r * .45)
      ..quadraticBezierTo(-r * .95, -r * 1.25, r * .12, -r * 1.25)
      ..quadraticBezierTo(r * 1.1, -r * 1.2, r * 1.12, -r * .4)
      ..lineTo(r * 1.16, r * 1.05)
      ..quadraticBezierTo(0, r * 1.25, -r * .98, r * 1.05);
  }
  h.close();
  final plume = look.plume;
  if (plume != null) {
    final sw = still ? 0.0 : math.sin(t / 700) * 3;
    final p = Path()
      ..moveTo(-r * .1, -r * 1.15)
      ..cubicTo(-r * .9, -r * 2.4, -r * 2.6 + sw, -r * 1.9, -r * 3.0 + sw, -r * .2)
      ..cubicTo(-r * 2.3 + sw, -r * 1.1, -r * 1.4, -r * 1.25, -r * .5, -r * .95)
      ..close();
    fillPath(c, p, [shade(plume, .25), plume, shade(plume, -.45)], Offset(-r * 3, -r * 2), Offset(0, -r));
    c.drawPath(
      Path()
        ..moveTo(-r * .3, -r * 1.3)
        ..cubicTo(-r * 1.1, -r * 2.1, -r * 2.2 + sw, -r * 1.7, -r * 2.6 + sw, -r * .6),
      strokePaint(const Color(0x40000000), 1.2),
    );
  }
  final steel = look.helm ?? ramp(0xFF8B939C);
  fillPath(c, h, steel, Offset(-r, -r), Offset(r * 1.1, r));
  c.save();
  c.clipPath(h);
  _ellipse(c, Offset(-r * .2, -r * .75), r * .6, r * .25, Paint()..color = const Color(0x33FFFFFF), -.2);
  if (look.engrave > 0) {
    // Fine helms: a hard specular stripe down the crown, a dark rim at the back, and an engraved
    // brow band over the visor (gilt on the best).
    c.drawPath(
      Path()
        ..moveTo(-r * .55, -r * 1.05)
        ..quadraticBezierTo(r * .35, -r * 1.25, r * .95, -r * .65),
      strokePaint(const Color(0xB3FFFFFF), 1.6),
    );
    c.drawPath(h, strokePaint(shade(steel[2], -.35).withValues(alpha: .7), 4));
    final ink = look.engraveCol ?? shade(steel[1], -.5);
    final band = Path()
      ..moveTo(-r * 1.05, -r * .5)
      ..quadraticBezierTo(r * .1, -r * .66, r * 1.14, -r * .5);
    c.drawPath(band, strokePaint(shade(steel[2], -.2), 4.2));
    c.drawPath(band, strokePaint(ink.withValues(alpha: look.engrave >= 2 ? 1 : .8), look.engrave >= 2 ? 2.2 : 1.4));
    if (look.engrave >= 2) {
      for (final x in const [-.6, -.1, .4, .9]) {
        c.drawCircle(Offset(r * x, -r * .58 + (x * x) * r * .05), 1.2, Paint()..color = ink);
      }
    }
  }
  c.restore();
  if (look.engrave > 0) c.drawPath(h, strokePaint(const Color(0xE6100B07), 1.6));
  final glow = look.eyeGlow;
  final slit = Rect.fromLTWH(r * .12, -r * .32, r * 1.06, r * .17);
  if (glow != null) {
    c.drawRect(
      slit.inflate(2),
      Paint()
        ..color = glow.withValues(alpha: .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  c.drawRect(slit, Paint()..color = glow ?? const Color(0xFF08090B));
  if (look.engrave >= 2) c.drawRect(slit.inflate(1.2), strokePaint(look.engraveCol ?? const Color(0xFFE8C060), 1.1));
  if (!sallet) {
    final dot = Paint()..color = const Color(0xFF08090B);
    for (final (x, y) in const [(.8, .2), (.95, .35), (.8, .5), (.95, .65)]) {
      c.drawCircle(Offset(r * x, r * y), 1.3, dot);
    }
    c.drawLine(Offset(r * .62, -r * 1.2), Offset(r * .62, r * 1.1), strokePaint(const Color(0x59000000), 2));
  }
}

/// The iron full helm: a flat-topped great helm with a pair of eye slits (you can just see a glint
/// of the eyes inside), rows of breathing slots, a riveted brow band and face-plate seam, and a
/// rolled rim at the bottom. On blackened iron the edges catch a cold light and an ember glow.
void _greatHelm(Canvas c, double r, Look look, double t, bool still) {
  final steel = look.helm ?? ramp(0xFF8B939C);
  final plume = look.plume;
  if (plume != null) {
    final sw = still ? 0.0 : math.sin(t / 700) * 3;
    final p = Path()
      ..moveTo(-r * .1, -r * 1.2)
      ..cubicTo(-r * .9, -r * 2.45, -r * 2.6 + sw, -r * 1.95, -r * 3.0 + sw, -r * .25)
      ..cubicTo(-r * 2.3 + sw, -r * 1.15, -r * 1.4, -r * 1.3, -r * .5, -r * 1.0)
      ..close();
    fillPath(c, p, [shade(plume, .25), plume, shade(plume, -.45)], Offset(-r * 3, -r * 2), Offset(0, -r));
    c.drawPath(
      Path()
        ..moveTo(-r * .3, -r * 1.35)
        ..cubicTo(-r * 1.1, -r * 2.15, -r * 2.2 + sw, -r * 1.75, -r * 2.6 + sw, -r * .65),
      strokePaint(const Color(0x40000000), 1.2),
    );
  }
  // The shell: a near-flat top, straight sides, the face a touch proud of the rest.
  final h = Path()
    ..moveTo(-r * 1.0, r * 1.08)
    ..lineTo(-r * 1.08, -r * .35)
    ..cubicTo(-r * 1.1, -r * 1.25, -r * .35, -r * 1.45, r * .2, -r * 1.42)
    ..cubicTo(r * .85, -r * 1.38, r * 1.18, -r * 1.0, r * 1.2, -r * .45)
    ..lineTo(r * 1.26, r * .25)
    ..lineTo(r * 1.16, r * 1.08)
    ..quadraticBezierTo(r * .1, r * 1.3, -r * 1.0, r * 1.08)
    ..close();
  fillPath(c, h, steel, Offset(-r, -r * 1.2), Offset(r * 1.2, r));
  final dark = shade(steel[2], -.4), edge = shade(steel[0], .25);
  const brass = Color(0xFFC9A24E);
  final ink = look.engrave >= 2 ? (look.engraveCol ?? brass) : brass;
  void rivet(Offset at, [double s = 1.3]) {
    c.drawCircle(at, s, Paint()..color = shade(ink, -.4));
    c.drawCircle(at - Offset(s * .3, s * .3), s * .55, Paint()..color = ink);
  }

  c.save();
  c.clipPath(h);
  // Rounded light: a soft sheen on the crown and a hard vertical stripe down the cheek.
  _ellipse(c, Offset(-r * .2, -r * .95), r * .7, r * .18, Paint()..color = const Color(0x33FFFFFF), -.05);
  c.drawLine(Offset(-r * .35, -r * 1.0), Offset(-r * .3, r * .95), strokePaint(const Color(0x40FFFFFF), r * .16));
  c.drawLine(Offset(-r * .42, -r * .95), Offset(-r * .38, r * .9), strokePaint(const Color(0x8CFFFFFF), 1.1));
  // Shadow at the back, so it reads round.
  c.drawRect(
    Rect.fromLTRB(-r * 1.1, -r * 1.3, -r * .6, r * 1.2),
    Paint()..shader = ui.Gradient.linear(Offset(-r * 1.1, 0), Offset(-r * .6, 0), [dark.withValues(alpha: .7), dark.withValues(alpha: 0)]),
  );
  if (look.blackIron) {
    // Embers reflected from below, and a cold rim along the face.
    c.drawRect(
      Rect.fromLTRB(-r * 1.2, -r * 1.3, r * 1.3, r * 1.3),
      Paint()..shader = ui.Gradient.linear(Offset(0, r * 1.1), Offset(0, -r * .2), [const Color(0x4DFF7A2A), const Color(0x00FF7A2A)]),
    );
    c.drawLine(Offset(r * 1.08, -r * .6), Offset(r * 1.14, r * 1.0), strokePaint(const Color(0x80C8D2DC), 1.4));
  }
  // A raised comb running over the crown, front to back.
  final comb = Path()
    ..moveTo(-r * .95, -r * .9)
    ..cubicTo(-r * .55, -r * 1.42, r * .45, -r * 1.48, r * 1.12, -r * .75);
  c.drawPath(comb.shift(const Offset(0, 1.6)), strokePaint(dark.withValues(alpha: .7), 2.2));
  c.drawPath(comb, strokePaint(edge, 1.3));
  // The face-plate seam, where the front overlaps the sides, with a line of rivets.
  final seam = Path()
    ..moveTo(r * .3, -r * 1.27)
    ..quadraticBezierTo(r * .22, 0, r * .32, r * 1.15);
  c.drawPath(seam.shift(const Offset(-1.4, 0)), strokePaint(dark, 2.2));
  c.drawPath(seam, strokePaint(edge.withValues(alpha: .7), 1));
  for (final y in const [-.95, .45, .8]) {
    rivet(Offset(r * .2, r * y));
  }
  // The brow band, riveted (engraved on fine helms).
  final band = Rect.fromLTRB(-r * 1.1, -r * .62, r * 1.25, -r * .5);
  c.drawRect(band, Paint()..color = shade(steel[1], -.15));
  c.drawLine(band.topLeft, band.topRight, strokePaint(edge.withValues(alpha: .85), 1.1));
  c.drawLine(band.bottomLeft, band.bottomRight, strokePaint(dark, 1.6));
  if (look.engrave >= 2) {
    c.drawPath(
      Path()
        ..moveTo(-r * .9, -r * .585)
        ..cubicTo(-r * .55, -r * .69, -r * .35, -r * .48, -r * .05, -r * .585),
      strokePaint(ink.withValues(alpha: .9), 1),
    );
  }
  for (final x in const [-.8, -.2, .55]) {
    rivet(Offset(r * x, -r * .585), 1.2);
  }
  // Two eye slits across the face, a bar of iron between them. Each has a lit lower lip and a
  // shadowed upper one; behind the top slit, a glint of the eyes.
  final glow = look.eyeGlow;
  for (final (top, h2, from) in [(-.4, .13, .34), (-.19, .1, .44)]) {
    final s = Rect.fromLTRB(r * from, r * top, r * 1.3, r * (top + h2));
    if (glow != null) {
      c.drawRect(s.inflate(2), Paint()..color = glow.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    c.drawRRect(RRect.fromRectAndRadius(s, Radius.circular(r * .04)), Paint()..color = glow ?? const Color(0xFF040405));
    c.drawLine(Offset(s.left + 1, s.bottom + .8), Offset(s.right, s.bottom + .8), strokePaint(edge.withValues(alpha: .9), 1.1));
    c.drawLine(Offset(s.left, s.top - .6), Offset(s.right, s.top - .6), strokePaint(dark, 1.3));
  }
  if (look.eyeGlow == null) {
    final blink = still ? 1.0 : (math.sin(t / 1700) > .97 ? 0.0 : 1.0);
    c.drawCircle(Offset(r * .78, -r * .335), r * .045 * blink, Paint()..color = const Color(0xCCF2E6C8));
  }
  // Breaths: rows of small slots on the lower face, near side only.
  // Breaths: a cluster of round holes on the lower face, near side only.
  final hole = Paint()..color = const Color(0xFF040405);
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3 - (row == 2 ? 1 : 0); col++) {
      final x = r * (.66 + col * .18 + (row.isOdd ? .09 : 0)), y = r * (.2 + row * .2);
      c.drawCircle(Offset(x, y), r * .055, hole);
      c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: r * .075), .3, 2.2, false, strokePaint(edge.withValues(alpha: .7), .8));
    }
  }
  // A rolled rim at the bottom edge.
  final rim = Path()
    ..moveTo(-r * 1.0, r * .98)
    ..quadraticBezierTo(r * .1, r * 1.2, r * 1.2, r * .98);
  c.drawPath(rim, strokePaint(dark, 3.2));
  c.drawPath(rim.shift(const Offset(0, -1.4)), strokePaint(edge.withValues(alpha: .8), 1));
  c.restore();
  // A crisp outline.
  c.drawPath(h, strokePaint(const Color(0xE6100B07), 1.6));
}

/// A carved pumpkin with a candle inside: ribbed, stalked, grinning, and glowing through its eyes.
void _pumpkinHead(Canvas c, double r, double t, bool still) {
  final flicker = still ? .9 : .75 + .25 * math.sin(t / 90) * math.sin(t / 53);
  final w = r * 1.35, h = r * 1.15;
  // Ribbed body: three overlapping lobes, darker at the creases.
  for (final (dx, sw, col) in [(-w * .42, .62, const Color(0xFFC8641A)), (w * .42, .62, const Color(0xFFC8641A)), (0.0, .7, const Color(0xFFE07A22))]) {
    final lobe = Rect.fromCenter(center: Offset(dx, 0), width: w * 2 * sw, height: h * 2);
    c.drawOval(lobe, Paint()..shader = ui.Gradient.radial(lobe.center + Offset(-lobe.width * .15, -lobe.height * .2), lobe.longestSide * .6, [shade(col, .25), col, shade(col, -.45)], const [0, .5, 1]));
  }
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2), strokePaint(const Color(0xFF3A1A06), 1.6));
  for (final dx in [-w * .3, w * .3]) {
    c.drawLine(Offset(dx, -h * .85), Offset(dx * 1.1, h * .85), strokePaint(const Color(0x664A2006), 1.4));
  }
  // The stalk.
  c.drawPath(
    Path()
      ..moveTo(-r * .12, -h * .9)
      ..quadraticBezierTo(-r * .1, -h * 1.3, r * .2, -h * 1.45)
      ..lineTo(r * .26, -h * 1.3)
      ..quadraticBezierTo(r * .1, -h * 1.2, r * .14, -h * .9)
      ..close(),
    Paint()..color = const Color(0xFF4A5A2A),
  );
  // The carving, lit from inside: triangle eyes and a jagged grin.
  final glow = Color.lerp(const Color(0xFFFF8A1A), const Color(0xFFFFE07A), flicker)!;
  c.drawCircle(const Offset(0, 0), r * 1.1, Paint()..color = const Color(0xFFFFA040).withValues(alpha: .25 * flicker)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  final carve = Paint()..color = glow;
  c.save();
  c.translate(r * .28, 0);
  c.scale(.82, 1);
  for (final s in [-1.0, 1.0]) {
    c.drawPath(poly([Offset(s * r * .55, -h * .12), Offset(s * r * .15, -h * .18), Offset(s * r * .4, -h * .5)]), carve);
  }
  final mouth = Path()..moveTo(-w * .62, h * .18);
  for (var i = 0; i <= 6; i++) {
    final x = -w * .62 + i * w * 1.24 / 6;
    mouth.lineTo(x, h * (i.isEven ? .22 : .36));
  }
  mouth
    ..quadraticBezierTo(0, h * .82, -w * .62, h * .18)
    ..close();
  c.drawPath(mouth, carve);
  c.restore();
}

void _goblinHead(Canvas c, double r, Look look) {
  final ear = Path()
    ..moveTo(-r * .2, -r * .5)
    ..quadraticBezierTo(-r * 1.4, -r * 1.5, -r * 2.2, -r * 1.25)
    ..quadraticBezierTo(-r * 1.3, -r * .6, -r * .5, r * .15)
    ..close();
  fillPath(c, ear, look.skin, Offset(-r * 2, -r), Offset.zero);
  c.drawPath(
    Path()
      ..moveTo(-r * .5, -r * .35)
      ..quadraticBezierTo(-r * 1.2, -r * .9, -r * 1.8, -r * 1.1),
    strokePaint(const Color(0x4D000000), 1.2),
  );
  final head = Path()
    ..moveTo(-r * .85, r * .3)
    ..quadraticBezierTo(-r * 1.05, -r * 1.0, r * .1, -r * 1.0)
    ..quadraticBezierTo(r * .9, -r * .95, r * .95, -r * .35)
    ..quadraticBezierTo(r * 1.55, -r * .1, r * 1.6, r * .45)
    ..quadraticBezierTo(r * 1.3, r * .38, r * 1.0, r * .3)
    ..quadraticBezierTo(r * 1.15, r * .85, r * .75, r * .95)
    ..quadraticBezierTo(r * .1, r * 1.1, -r * .4, r * .8)
    ..quadraticBezierTo(-r * .75, r * .65, -r * .85, r * .3)
    ..close();
  fillPath(c, head, look.skin, Offset(-r, -r), Offset(r, r));
  c.drawPath(
    Path()
      ..moveTo(r * .25, -r * .5)
      ..quadraticBezierTo(r * .6, -r * .62, r * .95, -r * .4),
    strokePaint(shade(look.skin[2], -.2), 3),
  );
  final eye = Offset(r * .62, -r * .28);
  _ellipse(
    c,
    eye,
    r * .16,
    r * .11,
    Paint()
      ..color = const Color(0x99FFD34A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    .1,
  );
  _ellipse(c, eye, r * .12, r * .075, Paint()..color = const Color(0xFFFFD34A), .1);
  c.drawCircle(Offset(r * .66, -r * .28), 1.4, Paint()..color = const Color(0xFF1A0E08));
  c.drawPath(
    Path()
      ..moveTo(r * .35, r * .62)
      ..quadraticBezierTo(r * .7, r * .72, r * .92, r * .6),
    strokePaint(const Color(0xFF1A0E08), 1.5),
  );
  c.drawPath(poly([Offset(r * .78, r * .66), Offset(r * .86, r * .34), Offset(r * .9, r * .64)]), Paint()..color = const Color(0xFFECE2C6));
  c.drawPath(
    Path()
      ..moveTo(r * .2, -r * .15)
      ..quadraticBezierTo(r * .35, r * .2, r * .25, r * .45),
    strokePaint(const Color(0x40000000), 1),
  );
  if (look.head == HeadKind.goblinChief) {
    final paint = strokePaint(const Color(0xFFA8291F), 2.5);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(r * (.2 + i * .18), -r * .05), Offset(r * (.1 + i * .18), r * .35), paint);
    }
    const bone = [Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];
    for (final s in const [-1.0, 1.0]) {
      final bx = s > 0 ? r * .5 : -r * .6;
      final h = Path()
        ..moveTo(bx, -r * 1.0)
        ..quadraticBezierTo(bx + s * r * .3, -r * 1.7, bx + s * r * .05, -r * 2.1)
        ..quadraticBezierTo(bx + s * r * .05, -r * 1.5, bx - s * r * .25, -r * 1.05)
        ..close();
      fillPath(c, h, bone, Offset(0, -r * 2), Offset(0, -r));
    }
    final cap = Path()
      ..moveTo(-r * .95, -r * .3)
      ..quadraticBezierTo(-r * .9, -r * 1.3, r * .2, -r * 1.2)
      ..quadraticBezierTo(r * .9, -r * 1.05, r * .85, -r * .45)
      ..quadraticBezierTo(0, -r * .65, -r * .95, -r * .3)
      ..close();
    fillPath(c, cap, bone, Offset(0, -r * 1.2), Offset(0, -r * .3));
    final socket = Paint()..color = const Color(0xFF1A120C);
    _ellipse(c, Offset(r * .35, -r * .75), r * .14, r * .1, socket);
    _ellipse(c, Offset(-r * .15, -r * .8), r * .13, r * .1, socket);
  }
}

void _hoodHead(Canvas c, double r, Look look) {
  final hood = Path()
    ..moveTo(-r * 1.2, r * 1.15)
    ..quadraticBezierTo(-r * 1.45, -r * 1.1, -r * .2, -r * 1.45)
    ..quadraticBezierTo(r * 1.0, -r * 1.4, r * 1.2, -r * .2)
    ..quadraticBezierTo(r * 1.3, r * .5, r * 1.15, r * 1.15)
    ..quadraticBezierTo(0, r * 1.45, -r * 1.2, r * 1.15)
    ..close();
  fillPath(c, hood, look.hood ?? ramp(0xFF3B4436), Offset(-r, -r), Offset(r, r));
  final face = Path()
    ..moveTo(r * .2, -r * .75)
    ..quadraticBezierTo(r * 1.05, -r * .75, r * 1.08, -r * .05)
    ..lineTo(r * 1.08, r * .9)
    ..quadraticBezierTo(r * .45, r * 1.0, r * .2, r * .7)
    ..quadraticBezierTo(-r * .1, 0, r * .2, -r * .75)
    ..close();
  fillPath(c, face, const [Color(0xFF3A2A20), Color(0xFF24180F), Color(0xFF0E0906)], Offset(0, -r), Offset(0, r), line: false);
  _ellipse(c, Offset(r * .72, -r * .25), r * .32, r * .2, Paint()..color = shade(look.skin[1], -.1));
  _ellipse(c, Offset(r * .78, -r * .25), r * .11, r * .06, Paint()..color = look.eyeGlow ?? const Color(0xFFE8DCC4));
  c.drawCircle(Offset(r * .82, -r * .25), 1.3, Paint()..color = const Color(0xFF120A06));
  final mask = Path()
    ..moveTo(r * .32, -r * .02)
    ..lineTo(r * 1.12, -r * .04)
    ..lineTo(r * 1.1, r * .85)
    ..quadraticBezierTo(r * .55, r * .95, r * .3, r * .65)
    ..close();
  fillPath(c, mask, look.mask ?? ramp(0xFF2A2A26), Offset.zero, Offset(0, r), line: false);
  final trim = look.maskTrim;
  if (trim != null) {
    c.drawPath(
      Path()
        ..moveTo(r * 1.15, -r * .2)
        ..quadraticBezierTo(r * 1.3, r * .5, r * 1.15, r * 1.15),
      strokePaint(trim, 2),
    );
  }
}

/// A golem's head: a boulder sunk between its shoulders, a heavy brow, eyes glowing deep in the
/// rock, a crack across the crown and a lump of ore set in it.
void _golemHead(Canvas c, double r, Look look, double t, bool still) {
  final stone = look.skin;
  final rock = Path()
    ..moveTo(-r * 1.15, r * .9)
    ..lineTo(-r * 1.3, -r * .2)
    ..quadraticBezierTo(-r * 1.2, -r * 1.05, -r * .3, -r * 1.15)
    ..lineTo(r * .55, -r * 1.1)
    ..quadraticBezierTo(r * 1.3, -r * .95, r * 1.35, -r * .15)
    ..lineTo(r * 1.25, r * .7)
    ..quadraticBezierTo(r * .4, r * 1.2, -r * 1.15, r * .9)
    ..close();
  fillPath(c, rock, stone, Offset(-r, -r), Offset(r, r));
  // The brow: a ledge of rock over the eyes.
  final brow = Path()
    ..moveTo(r * .05, -r * .5)
    ..lineTo(r * 1.4, -r * .42)
    ..lineTo(r * 1.32, -r * .18)
    ..lineTo(r * .1, -r * .22)
    ..close();
  c.drawPath(brow, Paint()..color = shade(stone[2], -.15));
  // Eyes in the dark under it.
  final glow = look.eyeGlow ?? const Color(0xFFFF9A4A);
  final pulse = still ? 1.0 : .8 + .2 * math.sin(t / 380);
  for (final x in const [.55, 1.05]) {
    final eye = Offset(r * x, -r * .05);
    c.drawCircle(eye, r * .22, Paint()
      ..color = glow.withValues(alpha: .45 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .15));
    _ellipse(c, eye, r * .13, r * .07, Paint()..color = glow);
  }
  // A dark slit of a mouth, and a crack across the crown.
  c.drawLine(Offset(r * .5, r * .5), Offset(r * 1.15, r * .45), strokePaint(const Color(0xAA0E0A08), 2));
  c.drawPath(
    Path()
      ..moveTo(-r * .9, -r * .7)
      ..lineTo(-r * .45, -r * .45)
      ..lineTo(-r * .3, -r * .75)
      ..lineTo(r * .1, -r * .6),
    strokePaint(const Color(0x88000000), 1.4),
  );
  // A lump of ore set in the rock.
  final ore = look.trim;
  if (ore != null) {
    final nugget = poly([Offset(-r * .7, -r * .15), Offset(-r * .35, -r * .3), Offset(-r * .2, r * .05), Offset(-r * .55, r * .2)]);
    c.drawPath(nugget, Paint()..color = ore);
    c.drawPath(nugget, strokePaint(shade(ore, -.45), 1));
    c.drawCircle(Offset(-r * .42, -r * .12), r * .06, Paint()..color = const Color(0xCCFFFFFF));
  }
}

/// One of the Hidden Ones: a tall peaked hood that droops behind, and in its shadow a blank white
/// mask with a single narrow eye-slit, and the clan's red mark run down through it like a tear.
void _veiledHead(Canvas c, double r, Look look, double t, bool still) {
  final hoodCol = look.hood ?? ramp(0xFF2A2428);
  final sway = still ? 0.0 : math.sin(t / 700) * r * .08;
  final hood = Path()
    ..moveTo(-r * 1.25, r * 1.3)
    ..quadraticBezierTo(-r * 1.6, -r * .5, -r * 1.1, -r * 1.45)
    ..quadraticBezierTo(-r * 1.2, -r * 2.0, -r * 1.75 + sway, -r * 2.3)
    ..quadraticBezierTo(-r * .4, -r * 2.15, r * .55, -r * 1.35)
    ..quadraticBezierTo(r * 1.35, -r * .65, r * 1.28, r * .35)
    ..quadraticBezierTo(r * 1.24, r * 1.1, r * 1.02, r * 1.35)
    ..quadraticBezierTo(0, r * 1.6, -r * 1.25, r * 1.3)
    ..close();
  fillPath(c, hood, hoodCol, Offset(-r, -r * 2), Offset(r, r));
  // A deep seam down the back of the hood.
  c.drawPath(
    Path()
      ..moveTo(-r * 1.6 + sway, -r * 2.15)
      ..quadraticBezierTo(-r * 1.05, -r * 1.2, -r * 1.0, r * 1.1),
    strokePaint(shade(hoodCol[1], -.35), 1.4),
  );
  // The shadow inside the hood.
  final opening = Path()
    ..moveTo(r * .25, -r * .95)
    ..quadraticBezierTo(r * 1.12, -r * .95, r * 1.14, -r * .05)
    ..lineTo(r * 1.1, r * 1.0)
    ..quadraticBezierTo(r * .45, r * 1.1, r * .18, r * .75)
    ..quadraticBezierTo(-r * .12, 0, r * .25, -r * .95)
    ..close();
  c.drawPath(opening, Paint()..color = const Color(0xFF07050A));
  // The mask: smooth, white, without a mouth.
  final maskCol = look.mask ?? const [Color(0xFFF4EEE2), Color(0xFFD6CCBA), Color(0xFF8E8472)];
  final mask = Path()
    ..moveTo(r * .48, -r * .78)
    ..quadraticBezierTo(r * 1.06, -r * .8, r * 1.07, -r * .1)
    ..quadraticBezierTo(r * 1.06, r * .62, r * .68, r * .88)
    ..quadraticBezierTo(r * .36, r * .66, r * .38, -r * .05)
    ..quadraticBezierTo(r * .34, -r * .55, r * .48, -r * .78)
    ..close();
  fillPath(c, mask, maskCol, Offset(r * .3, -r * .8), Offset(r * 1.1, r * .9), width: 1);
  // The hood's rim throws a shadow across the top of the mask.
  c.drawPath(
    Path()
      ..moveTo(r * .4, -r * .8)
      ..quadraticBezierTo(r * .95, -r * .9, r * 1.08, -r * .3)
      ..quadraticBezierTo(r * .8, -r * .55, r * .4, -r * .5)
      ..close(),
    Paint()..color = const Color(0x8C07050A),
  );
  // One narrow eye-slit, lit when the wearer has power.
  final slit = Offset(r * .84, -r * .2);
  final glow = look.eyeGlow;
  if (glow != null) {
    c.drawOval(Rect.fromCenter(center: slit, width: r * .6, height: r * .3), Paint()
      ..color = glow.withValues(alpha: .55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .2));
  }
  c.drawPath(
    Path()
      ..moveTo(slit.dx - r * .2, slit.dy + r * .02)
      ..quadraticBezierTo(slit.dx, slit.dy - r * .08, slit.dx + r * .2, slit.dy)
      ..quadraticBezierTo(slit.dx, slit.dy + r * .06, slit.dx - r * .2, slit.dy + r * .02)
      ..close(),
    Paint()..color = glow ?? const Color(0xFF120A0C),
  );
  // The clan's mark: a red line run down through the eye, like a tear.
  final mark = look.maskTrim ?? const Color(0xFFA0222A);
  c.drawPath(
    Path()
      ..moveTo(slit.dx + r * .02, slit.dy - r * .42)
      ..lineTo(slit.dx - r * .02, slit.dy + r * .55),
    strokePaint(mark, math.max(1.4, r * .09))..strokeCap = StrokeCap.round,
  );
  c.drawCircle(Offset(slit.dx - r * .03, slit.dy + r * .62), math.max(1.2, r * .07), Paint()..color = mark);
}

/// A heroine's hair, drawn behind the head: long and loose when the head is open, a braid hanging
/// below a helm, nothing under a wrapped hood.
void _heroineHair(Canvas c, double r, Look look) {
  final col = look.hair, ramp3 = [shade(col, .25), col, shade(col, -.45)];
  switch (look.head) {
    case HeadKind.bare || HeadKind.circlet || HeadKind.wizardhat || HeadKind.scoutcap || HeadKind.magemask || HeadKind.wyrmcirclet:
      final hair = Path()
        ..moveTo(-r * .1, -r * 1.12)
        ..quadraticBezierTo(-r * 1.25, -r * 1.05, -r * 1.3, -r * .1)
        ..quadraticBezierTo(-r * 1.35, r * .9, -r * 1.05, r * 1.7)
        ..quadraticBezierTo(-r * .75, r * 1.85, -r * .45, r * 1.55)
        ..quadraticBezierTo(-r * .6, r * 1.0, -r * .35, r * .55)
        ..lineTo(-r * .2, -r * .2)
        ..close();
      fillPath(c, hair, ramp3, Offset(-r, -r), Offset(-r * .4, r * 1.7));
      final strand = strokePaint(shade(col, -.35), 1);
      for (var i = 0; i < 3; i++) {
        c.drawPath(
          Path()
            ..moveTo(-r * (.7 + i * .17), -r * .5)
            ..quadraticBezierTo(-r * (1.05 + i * .1), r * .5, -r * (.75 + i * .12), r * 1.5),
          strand,
        );
      }
    case HeadKind.coif || HeadKind.nasal || HeadKind.greathelm || HeadKind.sallet || HeadKind.wyrmhelm:
      // A braid falling from under the helm, tied off with a band.
      for (var i = 0; i < 5; i++) {
        final ctr = Offset(-r * (.95 + i * .07), r * (.55 + i * .3));
        final link = Path()..addOval(Rect.fromCenter(center: ctr, width: r * .42, height: r * .38));
        fillPath(c, link, ramp3, ctr - Offset(r * .2, r * .2), ctr + Offset(r * .2, r * .2));
        c.drawPath(link, strokePaint(shade(col, -.5), .8));
      }
      final tie = Offset(-r * 1.32, r * 2.0);
      c.drawLine(tie - Offset(r * .14, 0), tie + Offset(r * .14, 0), strokePaint(look.trim ?? const Color(0xFF9A2A22), 2.4));
      final tuft = Path()
        ..moveTo(tie.dx - r * .12, tie.dy)
        ..quadraticBezierTo(tie.dx - r * .05, tie.dy + r * .45, tie.dx + r * .02, tie.dy + r * .5)
        ..quadraticBezierTo(tie.dx + r * .1, tie.dy + r * .3, tie.dx + r * .12, tie.dy)
        ..close();
      fillPath(c, tuft, ramp3, Offset(tie.dx, tie.dy), Offset(tie.dx, tie.dy + r * .5));
    default:
      break;
  }
}

void _beard(Canvas c, double r, Color col) {
  final beard = Path()
    ..moveTo(r * .25, r * .1)
    ..quadraticBezierTo(r * 1.1, r * .15, r * 1.0, r * .6)
    ..quadraticBezierTo(r * .85, r * 1.9, r * .3, r * 2.0)
    ..quadraticBezierTo(-r * .1, r * 1.2, -r * .3, r * .45)
    ..quadraticBezierTo(-r * .05, r * .5, r * .25, r * .1)
    ..close();
  fillPath(c, beard, [shade(col, .25), col, shade(col, -.4)], Offset.zero, Offset(0, r * 2));
  final strands = strokePaint(const Color(0x33000000), 1);
  for (var i = 0; i < 4; i++) {
    c.drawLine(Offset(r * (.3 + i * .16), r * .55), Offset(r * (.2 + i * .14), r * 1.7), strands);
  }
}

/// A hood or cowl that wraps the back of the head and leaves the face open.
Path _openHood(double r) => Path()
  ..moveTo(-r * 1.1, r * 1.1)
  ..quadraticBezierTo(-r * 1.4, -r * 1.35, r * .15, -r * 1.32)
  ..quadraticBezierTo(r * 1.3, -r * 1.15, r * 1.1, -r * .3)
  ..quadraticBezierTo(r * .55, -r * .78, r * .25, -r * .58)
  ..quadraticBezierTo(-r * .08, r * .1, r * .35, r * .88)
  ..quadraticBezierTo(r * .7, r * .98, r * .98, r * .98)
  ..lineTo(r * 1.0, r * 1.32)
  ..quadraticBezierTo(0, r * 1.55, -r * 1.1, r * 1.1)
  ..close();

void _hair(Canvas c, double r, Look look) {
  final hair = Path()
    ..moveTo(-r * .95, r * .35)
    ..quadraticBezierTo(-r * 1.2, -r * 1.25, r * .2, -r * 1.18)
    ..quadraticBezierTo(r * .95, -r * 1.05, r * .92, -r * .55)
    ..quadraticBezierTo(r * .6, -r * .78, r * .35, -r * .62)
    ..quadraticBezierTo(r * .05, -r * .85, -r * .2, -r * .55)
    ..quadraticBezierTo(-r * .45, -r * .2, -r * .5, r * .45)
    ..close();
  fillPath(c, hair, [shade(look.hair, .25), look.hair, shade(look.hair, -.45)], Offset(0, -r), Offset(0, r * .4));
}

void _headwear(Canvas c, double r, Look look, double t, bool still) {
  final cloth = look.torso, accent = look.hatColour ?? const Color(0xFF9A2A22);
  switch (look.head) {
    case HeadKind.bare:
      _hair(c, r, look);
    case HeadKind.circlet:
      _hair(c, r, look);
      final band = Path()
        ..moveTo(-r * .95, -r * .4)
        ..quadraticBezierTo(0, -r * .78, r * .95, -r * .58);
      c.drawPath(band, strokePaint(outline, 4.6));
      c.drawPath(band, strokePaint(const Color(0xFFE2C46A), 2.8));
      final gem = Offset(r * .72, -r * .64);
      c.drawCircle(gem, r * .2, Paint()..color = const Color(0xFF7FC8FF));
      c.drawCircle(gem, r * .2, strokePaint(outline, 1));
    case HeadKind.wizardhat:
      _hair(c, r, look);
      final sway = still ? 0.0 : math.sin(t / 800) * r * .12;
      final cone = Path()
        ..moveTo(-r * .95, -r * .72)
        ..quadraticBezierTo(-r * .55, -r * 1.9, -r * 1.2 + sway, -r * 3.1)
        ..quadraticBezierTo(-r * .1, -r * 2.2, r * .85, -r * .8)
        ..close();
      fillPath(c, cone, cloth, Offset(-r, -r * 3), Offset(r, -r));
      final brim = Path()..addOval(Rect.fromCenter(center: Offset(-r * .05, -r * .72), width: r * 3.1, height: r * .62));
      fillPath(c, brim, cloth, Offset(0, -r), Offset(0, -r * .4));
      c.drawPath(
        Path()
          ..moveTo(-r * .9, -r * .95)
          ..quadraticBezierTo(0, -r * 1.25, r * .8, -r * 1.0),
        strokePaint(look.trim ?? accent, 3),
      );
      final star = Offset(-r * .45, -r * 1.8);
      c.drawCircle(star, r * .12, Paint()..color = const Color(0xFFF3DC8E));
    case HeadKind.cowl:
      fillPath(c, _openHood(r), cloth, Offset(-r, -r), Offset(r, r));
      c.drawPath(
        Path()
          ..moveTo(r * .25, -r * .58)
          ..quadraticBezierTo(-r * .08, r * .1, r * .35, r * .88),
        strokePaint(look.trim ?? accent, 2.4),
      );
    case HeadKind.rangerhood:
      final hood = look.hood ?? ramp(0xFF3E5232);
      final tail = Path()
        ..moveTo(-r * .9, -r * .7)
        ..quadraticBezierTo(-r * 1.9, -r * .6, -r * 2.3, r * .6)
        ..quadraticBezierTo(-r * 1.6, -r * .1, -r * 1.0, r * .2)
        ..close();
      fillPath(c, tail, hood, Offset(-r * 2, 0), Offset(-r, 0));
      fillPath(c, _openHood(r), hood, Offset(-r, -r), Offset(r, r));
      c.drawPath(
        Path()
          ..moveTo(r * .25, -r * .58)
          ..quadraticBezierTo(-r * .08, r * .1, r * .35, r * .88),
        strokePaint(shade(hood[1], -.35), 2.2),
      );
    case HeadKind.scoutcap:
      _hair(c, r, look);
      final cap = Path()
        ..moveTo(-r * 1.05, -r * .35)
        ..quadraticBezierTo(-r * 1.05, -r * 1.45, r * .2, -r * 1.35)
        ..quadraticBezierTo(r * 1.0, -r * 1.25, r * 1.0, -r * .65)
        ..lineTo(r * 1.65, -r * .5)
        ..quadraticBezierTo(r * .4, -r * .72, -r * 1.05, -r * .35)
        ..close();
      fillPath(c, cap, look.hood ?? ramp(0xFF3E5232), Offset(0, -r * 1.4), Offset(0, -r * .4));
      final sw = still ? 0.0 : math.sin(t / 700) * r * .1;
      final feather = Path()
        ..moveTo(-r * .6, -r * 1.1)
        ..quadraticBezierTo(-r * 1.4, -r * 2.2, -r * 2.2 + sw, -r * 2.3)
        ..quadraticBezierTo(-r * 1.3, -r * 1.6, -r * .4, -r * .95)
        ..close();
      fillPath(c, feather, [shade(accent, .3), accent, shade(accent, -.4)], Offset(-r * 2, -r * 2), Offset(-r * .5, -r));
    case HeadKind.nasal:
      final dome = Path()
        ..moveTo(-r * 1.05, -r * .15)
        ..quadraticBezierTo(-r * 1.0, -r * 1.2, r * .05, -r * 1.42)
        ..quadraticBezierTo(r * 1.05, -r * 1.15, r * 1.02, -r * .3)
        ..lineTo(-r * 1.05, -r * .15)
        ..close();
      final steel = look.helm ?? ramp(0xFF8B939C);
      fillPath(c, _openHood(r * .98), const [Color(0xFFB9BEC4), Color(0xFF7D838B), Color(0xFF353A40)], Offset(-r, -r), Offset(r, r));
      mailTexture(c, _openHood(r * .98));
      fillPath(c, dome, steel, Offset(-r, -r), Offset(r, 0));
      fillPath(c, Path()..addRect(Rect.fromLTWH(-r * 1.08, -r * .42, r * 2.14, r * .22)), darker(steel), Offset(0, -r * .4), Offset(0, -r * .2));
      fillPath(c, Path()..addRect(Rect.fromLTWH(r * .82, -r * .3, r * .2, r * .72)), steel, Offset(r * .8, 0), Offset(r, 0));
    default:
      break;
  }
}

/// A broad ork head: heavy brow, small swept-back ear, underbite with tusks, topknot. Shamans wear
/// a bone-and-feather headdress; the warlord a horned iron helm.
void _orkHead(Canvas c, double r, Look look, double t, bool still) {
  final ear = Path()
    ..moveTo(-r * .55, -r * .25)
    ..quadraticBezierTo(-r * 1.25, -r * .7, -r * 1.55, -r * .45)
    ..quadraticBezierTo(-r * 1.05, -r * .05, -r * .6, r * .25)
    ..close();
  fillPath(c, ear, look.skin, Offset(-r * 1.5, -r), Offset.zero);
  final head = Path()
    ..moveTo(-r * .95, r * .35)
    ..quadraticBezierTo(-r * 1.15, -r * 1.05, r * .05, -r * 1.08)
    ..quadraticBezierTo(r * .95, -r * 1.05, r * 1.05, -r * .45)
    ..quadraticBezierTo(r * 1.25, -r * .1, r * 1.12, r * .25)
    ..quadraticBezierTo(r * 1.3, r * .55, r * 1.15, r * .95)
    ..quadraticBezierTo(r * .55, r * 1.3, -r * .2, r * 1.1)
    ..quadraticBezierTo(-r * .8, r * .85, -r * .95, r * .35)
    ..close();
  fillPath(c, head, look.skin, Offset(-r, -r), Offset(r, r));
  // Heavy brow.
  c.drawPath(
    Path()
      ..moveTo(r * .15, -r * .48)
      ..quadraticBezierTo(r * .6, -r * .7, r * 1.05, -r * .42),
    strokePaint(shade(look.skin[2], -.25), 4.2),
  );
  final eye = Offset(r * .64, -r * .26);
  c.drawCircle(eye, r * .13, Paint()..color = const Color(0xFFFF4A2A).withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _ellipse(c, eye, r * .11, r * .07, Paint()..color = const Color(0xFFFF5A2A));
  c.drawCircle(eye + Offset(r * .03, 0), 1.3, Paint()..color = const Color(0xFF1A0E08));
  // Flat nose and underbite.
  c.drawPath(
    Path()
      ..moveTo(r * .95, -r * .1)
      ..quadraticBezierTo(r * 1.25, r * .15, r * 1.0, r * .3),
    strokePaint(const Color(0x59000000), 1.4),
  );
  c.drawPath(
    Path()
      ..moveTo(r * .45, r * .62)
      ..quadraticBezierTo(r * .85, r * .78, r * 1.18, r * .6),
    strokePaint(const Color(0xFF1A0E08), 1.8),
  );
  const tusk = [Color(0xFFF6EEDA), Color(0xFFD8CCAA), Color(0xFF8A7C5E)];
  for (final x in const [.62, 1.0]) {
    fillPath(c, poly([Offset(r * (x - .08), r * .7), Offset(r * (x + .06), r * .2), Offset(r * (x + .1), r * .72)]), tusk, Offset(0, r * .2), Offset(0, r * .7), width: 1);
  }
  c.drawLine(Offset(-r * .3, r * .1), Offset(-r * .05, r * .45), strokePaint(const Color(0x40000000), 1.2));
  switch (look.head) {
    case HeadKind.orkWarlord:
      final steel = look.helm ?? ramp(0xFF4A4D55);
      final helm = Path()
        ..moveTo(-r * 1.05, -r * .1)
        ..quadraticBezierTo(-r * 1.05, -r * 1.3, r * .1, -r * 1.3)
        ..quadraticBezierTo(r * 1.1, -r * 1.25, r * 1.08, -r * .35)
        ..lineTo(r * .3, -r * .5)
        ..lineTo(-r * 1.05, -r * .1)
        ..close();
      fillPath(c, helm, steel, Offset(-r, -r * 1.3), Offset(r, -r * .1));
      for (final s in const [-1.0, 1.0]) {
        final bx = s > 0 ? r * .45 : -r * .6;
        final horn = Path()
          ..moveTo(bx, -r * 1.1)
          ..quadraticBezierTo(bx + s * r * 1.1, -r * 1.4, bx + s * r * 1.2, -r * 2.3)
          ..quadraticBezierTo(bx + s * r * .5, -r * 1.6, bx - s * r * .2, -r * 1.0)
          ..close();
        fillPath(c, horn, const [Color(0xFFF2EAD2), Color(0xFFCFC2A0), Color(0xFF7E7058)], Offset(bx, -r * 2.2), Offset(bx, -r));
      }
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(-r * .8 + i * r * .45, -r * .5 + (i == 3 ? -r * .05 : 0)), 1.6, Paint()..color = const Color(0xFFC9A24E));
      }
    case HeadKind.orkShaman:
      final sw = still ? 0.0 : math.sin(t / 600) * r * .08;
      const bone = [Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];
      final colours = [const Color(0xFF7A1D14), const Color(0xFF2E5F35), const Color(0xFFB98A2E)];
      for (var i = 0; i < 3; i++) {
        final x = -r * .7 + i * r * .45;
        final f = Path()
          ..moveTo(x, -r * .95)
          ..quadraticBezierTo(x - r * .35 + sw, -r * 1.8, x - r * .2 + sw, -r * 2.3)
          ..quadraticBezierTo(x + r * .1 + sw, -r * 1.7, x + r * .15, -r * .95)
          ..close();
        fillPath(c, f, [shade(colours[i], .3), colours[i], shade(colours[i], -.4)], Offset(x, -r * 2.2), Offset(x, -r));
      }
      final band = Path()
        ..moveTo(-r * 1.0, -r * .55)
        ..quadraticBezierTo(0, -r * 1.05, r * .95, -r * .65)
        ..lineTo(r * .9, -r * .45)
        ..quadraticBezierTo(0, -r * .82, -r * .98, -r * .35)
        ..close();
      fillPath(c, band, bone, Offset(0, -r), Offset(0, -r * .4));
      c.drawCircle(Offset(r * .05, -r * .78), r * .14, Paint()..color = const Color(0xFF8BE05A));
    default:
      // Topknot.
      final knot = Path()
        ..moveTo(-r * .45, -r * .95)
        ..quadraticBezierTo(-r * .9, -r * 1.6, -r * 1.5, -r * 1.3)
        ..quadraticBezierTo(-r * 1.0, -r * 1.25, -r * .15, -r * .95)
        ..close();
      fillPath(c, knot, [shade(look.hair, .2), look.hair, shade(look.hair, -.4)], Offset(-r, -r * 1.5), Offset(0, -r));
  }
}

/// A skull with glowing sockets and a hinged jaw; archers wear a ragged hood, champions a rusted
/// helm, the Dragonbone Warden a pair of great horns.
void _skullHead(Canvas c, double r, Look look) {
  final bone = look.skin;
  if (look.head == HeadKind.skullHood) {
    final hood = Path()
      ..moveTo(-r * 1.25, r * 1.2)
      ..quadraticBezierTo(-r * 1.5, -r * 1.15, -r * .2, -r * 1.5)
      ..quadraticBezierTo(r * 1.05, -r * 1.45, r * 1.25, -r * .2)
      ..lineTo(r * .9, r * .2)
      ..quadraticBezierTo(r * .2, -r * .4, -r * .1, r * 1.3)
      ..close();
    fillPath(c, hood, look.hood ?? ramp(0xFF3A3630), Offset(-r, -r), Offset(r, r));
  }
  // Cranium.
  final cranium = Path()
    ..moveTo(-r * .85, r * .25)
    ..quadraticBezierTo(-r * 1.05, -r * 1.05, r * .1, -r * 1.05)
    ..quadraticBezierTo(r * 1.0, -r * 1.0, r * 1.05, -r * .3)
    ..quadraticBezierTo(r * 1.12, r * .1, r * .95, r * .3)
    ..lineTo(r * .9, r * .55)
    ..lineTo(r * .2, r * .55)
    ..quadraticBezierTo(-r * .5, r * .55, -r * .85, r * .25)
    ..close();
  fillPath(c, cranium, bone, Offset(-r, -r), Offset(r, r));
  // Jaw.
  final jaw = Path()
    ..moveTo(r * .15, r * .58)
    ..lineTo(r * .95, r * .62)
    ..quadraticBezierTo(r * .95, r * .95, r * .6, r * 1.0)
    ..quadraticBezierTo(r * .25, r * 1.0, r * .15, r * .58)
    ..close();
  fillPath(c, jaw, bone, Offset(0, r * .5), Offset(0, r));
  final tooth = strokePaint(const Color(0x88000000), 1);
  for (var i = 0; i < 5; i++) {
    final x = r * (.3 + i * .14);
    c.drawLine(Offset(x, r * .44), Offset(x, r * .72), tooth);
  }
  // Sockets with a glow, and the nose.
  final glow = look.eyeGlow ?? const Color(0xFF7FE8FF);
  for (final (x, y, w) in [(.62, -.22, .3), (.12, -.24, .24)]) {
    final centre = Offset(r * x, r * y);
    _ellipse(c, centre, r * w / 1.4, r * .2, Paint()..color = const Color(0xFF120C08));
    c.drawCircle(centre, r * .12, Paint()..color = glow.withValues(alpha: .7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawCircle(centre, r * .055, Paint()..color = glow);
  }
  c.drawPath(poly([Offset(r * .95, r * .05), Offset(r * .82, r * .3), Offset(r * 1.0, r * .3)]), Paint()..color = const Color(0xFF120C08));
  c.drawLine(Offset(-r * .35, -r * .7), Offset(-r * .05, -r * .4), strokePaint(const Color(0x55000000), 1.1));
  switch (look.head) {
    case HeadKind.skullHelm:
      final steel = look.helm ?? ramp(0xFF8A7A6A);
      final helm = Path()
        ..moveTo(-r * 1.05, -r * .05)
        ..quadraticBezierTo(-r * 1.05, -r * 1.3, r * .1, -r * 1.3)
        ..quadraticBezierTo(r * 1.1, -r * 1.25, r * 1.1, -r * .45)
        ..lineTo(-r * 1.05, -r * .05)
        ..close();
      fillPath(c, helm, steel, Offset(-r, -r * 1.3), Offset(r, 0));
      fillPath(c, Path()..addRect(Rect.fromLTWH(r * .38, -r * .5, r * .16, r * .75)), steel, Offset(r * .38, 0), Offset(r * .54, 0));
      final rust = Paint()..color = const Color(0x667A3A1A);
      for (final (x, y) in const [(-.5, -.8), (.3, -1.0), (-.8, -.4)]) {
        c.drawCircle(Offset(r * x, r * y), r * .12, rust);
      }
    case HeadKind.skullHorned:
      const horn = [Color(0xFF6A5A4A), Color(0xFF3A2E24), Color(0xFF16100A)];
      for (final s in const [-1.0, 1.0]) {
        final bx = s > 0 ? r * .4 : -r * .55;
        final h = Path()
          ..moveTo(bx, -r * .95)
          ..cubicTo(bx + s * r * 1.4, -r * 1.2, bx + s * r * 1.6, -r * 2.0, bx + s * r * .9, -r * 2.6)
          ..cubicTo(bx + s * r * 1.0, -r * 1.9, bx + s * r * .6, -r * 1.4, bx - s * r * .3, -r * .8)
          ..close();
        fillPath(c, h, horn, Offset(bx, -r * 2.5), Offset(bx, -r));
      }
    default:
      break;
  }
}


/// A cluster of leaves around [at] (also used for ents' shoulders).
void leafCluster(Canvas c, Offset at, double size, Color colour, {int seed = 0}) {
  final rnd = SeededRandom(seed + 11);
  for (var i = 0; i < 7; i++) {
    final a = rnd.next() * 6.28, d = rnd.next() * size * .6;
    final p = at + Offset(math.cos(a) * d, math.sin(a) * d * .7);
    final tone = shade(colour, (rnd.next() - .5) * .5);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: size * .7, height: size * .42), Paint()..color = tone);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: size * .7, height: size * .42), strokePaint(const Color(0x55000000), .8));
    c.restore();
  }
}

/// A long bark face: knot-hole eyes that glow, a cracked mouth, a twig nose, a moss beard and a
/// crown of branches in leaf.
void _entHead(Canvas c, double r, Look look) {
  final bark = look.skin, dark = shade(bark[2], -.2);
  // Branches first, behind the head, reaching up into the crown.
  final k = look.canopy;
  final branch = strokePaint(bark[2], 4.2)..strokeCap = StrokeCap.round;
  final twig = strokePaint(bark[1], 2.6)..strokeCap = StrokeCap.round;
  const tips = [(-.2, -1.15, -.95, -2.35), (.25, -1.2, .35, -2.6), (-.55, -1.0, -1.65, -1.75), (.6, -1.05, 1.25, -2.0)];
  Offset tipOf(double x1, double y1) => Offset(r * x1 * (.5 + .9 * k), r * (-1 + (y1 + 1) * (.5 + .9 * k)));
  for (final (x0, y0, x1, y1) in tips) {
    final a = Offset(r * x0, r * y0), b = tipOf(x1, y1), m = Offset.lerp(a, b, .55)! + Offset(r * .15, 0);
    c.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy), strokePaint(outline, 6.2)..strokeCap = StrokeCap.round);
    c.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy), branch);
    c.drawLine(m, m + Offset(r * .35, -r * .3), twig);
    if (look.bareBranches) {
      // Dead wood: the branches fork into crooked, leafless twigs.
      for (final turn in const [-.6, .5]) {
        final d = b - m, u = d / math.max(1, d.distance);
        final dir = Offset(u.dx * math.cos(turn) - u.dy * math.sin(turn), u.dx * math.sin(turn) + u.dy * math.cos(turn));
        c.drawLine(b, b + dir * r * .6, strokePaint(bark[2], 2.2)..strokeCap = StrokeCap.round);
        c.drawLine(b + dir * r * .35, b + dir * r * .35 + Offset(-dir.dy, dir.dx) * r * .25, strokePaint(bark[2], 1.4));
      }
    }
  }
  final foliage = look.foliage;
  if (foliage != null && look.bareBranches) {
    // A few last, sickly leaves.
    for (final (i, (_, _, x1, y1)) in tips.indexed) {
      if (i.isOdd) leafCluster(c, tipOf(x1, y1), r * .5, foliage, seed: i);
    }
  } else if (foliage != null) {
    // A full, rounded canopy: a dark layer of leaves at the back, a lighter one in front, and
    // sunlight on the top.
    final centre = Offset(-r * .1, -r * (1.3 + 1.1 * k)), rx = r * 2.3 * k, ry = r * 1.4 * k;
    for (var i = 0; i < 10; i++) {
      final a = math.pi + i / 9 * math.pi;
      leafCluster(c, centre + Offset(math.cos(a) * rx, math.sin(a) * ry * .9 + ry * .25), r * (1.1 + .45 * k), shade(foliage, -.28), seed: i + 20);
    }
    leafCluster(c, centre + Offset(-rx * .5, ry * .45), r * 1.3 * k, shade(foliage, -.3), seed: 41);
    leafCluster(c, centre + Offset(rx * .5, ry * .45), r * 1.3 * k, shade(foliage, -.3), seed: 42);
    leafCluster(c, centre + Offset(0, ry * .2), r * 1.6 * k, shade(foliage, -.2), seed: 43);
    for (var i = 0; i < 7; i++) {
      final a = math.pi * 1.1 + i / 6 * math.pi * .8;
      leafCluster(c, centre + Offset(math.cos(a) * rx * .7, math.sin(a) * ry * .7 + ry * .2), r * (1.0 + .4 * k), foliage, seed: i + 50);
    }
    leafCluster(c, centre + Offset(0, ry * .1), r * (1.1 + .5 * k), shade(foliage, .12), seed: 60);
    leafCluster(c, centre + Offset(-rx * .25, -ry * .45), r * .9 * k, shade(foliage, .3), seed: 61);
    leafCluster(c, centre + Offset(rx * .3, -ry * .3), r * .8 * k, shade(foliage, .25), seed: 62);
    final berries = look.berries;
    if (berries != null) {
      final rnd = SeededRandom(77);
      for (var i = 0; i < (6 * k).round() + 3; i++) {
        final a = math.pi * (1.05 + rnd.next() * .9), d = .35 + rnd.next() * .55;
        final p = centre + Offset(math.cos(a) * rx * d, math.sin(a) * ry * d + ry * .2);
        c.drawCircle(p, r * .11, Paint()..color = berries);
        c.drawCircle(p, r * .11, strokePaint(outline, .8));
        c.drawCircle(p + Offset(-r * .03, -r * .04), r * .03, Paint()..color = const Color(0xAAFFFFFF));
      }
    }
    // Mossy ents trail long strands of moss from the canopy.
    final moss = look.beard;
    if (moss != null && k > 1) {
      for (var i = 0; i < 6; i++) {
        final x = centre.dx - rx * .8 + i * rx * .32, top = centre.dy + ry * (.55 + (i % 2) * .1);
        final strand = Path()
          ..moveTo(x, top)
          ..quadraticBezierTo(x + 4, top + r * .5, x - 2, top + r * (.8 + (i % 3) * .25));
        c.drawPath(strand, strokePaint(shade(moss, -.15), 3)..strokeCap = StrokeCap.round);
      }
    }
  }
  final head = Path()
    ..moveTo(-r * .85, r * .9)
    ..quadraticBezierTo(-r * 1.05, -r * .6, -r * .55, -r * 1.2)
    ..quadraticBezierTo(r * .2, -r * 1.5, r * .85, -r * 1.05)
    ..quadraticBezierTo(r * 1.15, -r * .4, r * 1.05, r * .4)
    ..quadraticBezierTo(r * 1.0, r * 1.2, r * .3, r * 1.3)
    ..quadraticBezierTo(-r * .4, r * 1.35, -r * .85, r * .9)
    ..close();
  fillPath(c, head, bark, Offset(-r, -r), Offset(r, r));
  c.save();
  c.clipPath(head);
  final grain = strokePaint(const Color(0x47000000), 1.3);
  for (var i = 0; i < 6; i++) {
    final x = -r * .8 + i * r * .32;
    c.drawPath(Path()..moveTo(x, -r * 1.4)..quadraticBezierTo(x + r * .18, 0, x - r * .05, r * 1.4), grain);
  }
  c.restore();
  // Heavy brow ridge.
  c.drawPath(Path()..moveTo(r * .05, -r * .5)..quadraticBezierTo(r * .55, -r * .78, r * 1.08, -r * .48), strokePaint(dark, 5));
  // Knot-hole eyes.
  final glow = look.eyeGlow ?? const Color(0xFFE8F07A);
  for (final (e, size) in [(Offset(r * .42, -r * .22), r * .2), (Offset(r * .88, -r * .2), r * .14)]) {
    c.drawOval(Rect.fromCenter(center: e, width: size * 2.2, height: size * 1.7), Paint()..color = const Color(0xFF140C06));
    c.drawCircle(e, size * 1.3, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawCircle(e, size * .55, Paint()..color = glow);
  }
  // Twig nose.
  c.drawPath(poly([Offset(r * .8, -r * .05), Offset(r * 1.45, r * .18), Offset(r * .85, r * .25)]), Paint()..color = bark[1]);
  c.drawPath(poly([Offset(r * .8, -r * .05), Offset(r * 1.45, r * .18), Offset(r * .85, r * .25)]), strokePaint(outline, 1));
  // Cracked mouth.
  c.drawPath(
    Path()
      ..moveTo(r * .2, r * .62)
      ..lineTo(r * .45, r * .55)
      ..lineTo(r * .62, r * .66)
      ..lineTo(r * .98, r * .55),
    strokePaint(const Color(0xFF140C06), 2.4),
  );
  final moss = look.beard;
  if (moss != null) {
    final beard = Path()
      ..moveTo(r * .05, r * .8)
      ..quadraticBezierTo(r * .5, r * 1.0, r * 1.0, r * .75)
      ..quadraticBezierTo(r * .95, r * 1.6, r * .55, r * 2.1)
      ..quadraticBezierTo(r * .4, r * 1.6, r * .2, r * 1.9)
      ..quadraticBezierTo(r * .05, r * 1.4, r * .05, r * .8)
      ..close();
    fillPath(c, beard, [shade(moss, .25), moss, shade(moss, -.4)], Offset(0, r * .8), Offset(0, r * 2));
  }
}


/// A giant's bald head with one great eye, a heavy brow, a stubby horn and tusks.
void _cyclopsHead(Canvas c, double r, Look look, double t, bool still) {
  // A cyclops's head is big for its body: everything about it is drawn a third larger.
  c.save();
  c.scale(1.3, 1.3);
  final skin = look.skin;
  // A broad bald dome, a heavy jaw that juts past the brow, and jowls.
  final head = Path()
    ..moveTo(-r * .85, r * .55)
    ..quadraticBezierTo(-r * 1.15, -r * .85, r * .05, -r * 1.05)
    ..quadraticBezierTo(r * .95, -r * 1.05, r * 1.08, -r * .35)
    ..quadraticBezierTo(r * 1.32, -r * .1, r * 1.22, r * .3)
    ..quadraticBezierTo(r * 1.38, r * .55, r * 1.25, r * .92)
    ..quadraticBezierTo(r * .55, r * 1.3, -r * .25, r * 1.08)
    ..quadraticBezierTo(-r * .8, r * .95, -r * .85, r * .55)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  c.save();
  c.clipPath(head);
  // Light on the dome, shadow under the jaw, and a rough stubble.
  _ellipse(c, Offset(-r * .1, -r * .7), r * .55, r * .22, Paint()
    ..color = shade(skin[0], .25).withValues(alpha: .55)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .15));
  _ellipse(c, Offset(r * .4, r * 1.05), r * .9, r * .3, Paint()..color = shade(skin[2], -.2).withValues(alpha: .35));
  final stubble = Paint()..color = shade(skin[2], -.35).withValues(alpha: .35);
  final rng = math.Random(3);
  for (var i = 0; i < 26; i++) {
    c.drawCircle(Offset(r * (.1 + rng.nextDouble() * 1.1), r * (.55 + rng.nextDouble() * .45)), .9, stubble);
  }
  c.restore();
  c.drawPath(head, strokePaint(outline, 1.6));
  // A big, lumpy ear.
  _ellipse(c, Offset(-r * .55, r * .08), r * .22, r * .34, Paint()..color = skin[1]);
  _ellipse(c, Offset(-r * .55, r * .08), r * .22, r * .34, strokePaint(outline, 1.2));
  _ellipse(c, Offset(-r * .52, r * .1), r * .09, r * .18, Paint()..color = shade(skin[2], -.2).withValues(alpha: .6));
  // A greasy topknot.
  final hair = look.hair;
  final knot = Path()
    ..moveTo(-r * .3, -r * .98)
    ..quadraticBezierTo(-r * .55, -r * 1.55, -r * .05, -r * 1.5)
    ..quadraticBezierTo(r * .05, -r * 1.2, -r * .02, -r * 1.02)
    ..close();
  fillPath(c, knot, [shade(hair, .2), hair, shade(hair, -.3)], Offset(0, -r * 1.5), Offset(0, -r));
  // Forehead wrinkles.
  for (var i = 0; i < 2; i++) {
    c.drawPath(
      Path()
        ..moveTo(r * .2, -r * (.82 + i * .12))
        ..quadraticBezierTo(r * .55, -r * (.92 + i * .12), r * .9, -r * (.78 + i * .1)),
      strokePaint(shade(skin[2], -.1).withValues(alpha: .5), 1.1),
    );
  }
  // The great eye, bloodshot, blinking now and then.
  final blink = !still && (t % 4200) < 140;
  final eye = Offset(r * .64, -r * .3);
  if (blink) {
    c.drawLine(eye - Offset(r * .38, 0), eye + Offset(r * .38, 0), strokePaint(const Color(0xFF2A1A10), 2.4));
  } else {
    _ellipse(c, eye, r * .42, r * .34, Paint()..color = shade(skin[2], -.3));
    _ellipse(c, eye, r * .38, r * .3, Paint()..color = const Color(0xFFF4EEDC));
    final vein = strokePaint(const Color(0x99C0402A), .8);
    for (final (dx, dy) in const [(-.32, -.08), (-.3, .12), (.3, .14)]) {
      c.drawLine(eye + Offset(r * dx, r * dy), eye + Offset(r * dx * .55, r * dy * .4), vein);
    }
    c.drawCircle(eye + Offset(r * .08, 0), r * .2, Paint()..color = const Color(0xFF8A3A1A));
    c.drawCircle(eye + Offset(r * .08, 0), r * .2, strokePaint(const Color(0xFF4A1A0A), 1));
    c.drawCircle(eye + Offset(r * .1, 0), r * .09, Paint()..color = const Color(0xFF120A06));
    c.drawCircle(eye + Offset(r * .02, -r * .08), r * .05, Paint()..color = const Color(0xCCFFFFFF));
    _ellipse(c, eye, r * .38, r * .3, strokePaint(outline, 1.4));
  }
  // A low, furrowed brow over the eye.
  c.drawPath(
    Path()
      ..moveTo(r * .15, -r * .58)
      ..quadraticBezierTo(r * .6, -r * .86, r * 1.1, -r * .6),
    strokePaint(shade(skin[2], -.25), 6),
  );
  c.drawLine(Offset(r * .58, -r * .82), Offset(r * .64, -r * .7), strokePaint(shade(skin[2], -.3), 1.4));
  // A broad, squashed nose.
  final nose = Path()
    ..moveTo(r * .95, r * .02)
    ..quadraticBezierTo(r * 1.35, r * .18, r * 1.18, r * .34)
    ..quadraticBezierTo(r * 1.0, r * .38, r * .92, r * .28);
  c.drawPath(nose, Paint()..color = shade(skin[1], -.05));
  c.drawPath(nose, strokePaint(outline, 1.2));
  // A wide underbite with tusks pointing up out of the lower jaw.
  c.drawPath(
    Path()
      ..moveTo(r * .35, r * .62)
      ..quadraticBezierTo(r * .8, r * .8, r * 1.22, r * .6),
    strokePaint(const Color(0xFF2A1A10), 2.2),
  );
  for (final (x, h) in const [(.55, .32), (1.02, .28)]) {
    final tusk = Path()
      ..moveTo(r * x - 3.5, r * .74)
      ..quadraticBezierTo(r * x - 2, r * (.66 - h), r * x + 1, r * (.64 - h))
      ..quadraticBezierTo(r * x + 2, r * .55, r * x + 3.5, r * .72)
      ..close();
    c.drawPath(tusk, Paint()..color = const Color(0xFFF2EAD2));
    c.drawPath(tusk, strokePaint(outline, 1));
  }
  c.restore();
}


/// A snarling stone face: swept-back horns, pointed ears, a heavy jaw and glowing eyes.
void _gargoyleHead(Canvas c, double r, Look look) {
  final stone = look.skin;
  for (final dx in const [-.3, .15]) {
    final horn = Path()
      ..moveTo(r * dx, -r * .8)
      ..quadraticBezierTo(r * (dx - .7), -r * 1.6, r * (dx - 1.1), -r * 1.3)
      ..quadraticBezierTo(r * (dx - .5), -r * 1.15, r * (dx + .3), -r * .7)
      ..close();
    fillPath(c, horn, [shade(stone[0], -.1), shade(stone[1], -.2), stone[2]], Offset(r * (dx - 1.1), -r * 1.6), Offset(r * dx, -r * .7));
  }
  final ear = poly([Offset(-r * .55, -r * .25), Offset(-r * 1.3, -r * .75), Offset(-r * .7, r * .15)]);
  fillPath(c, ear, stone, Offset(-r * 1.3, -r), Offset(-r * .5, 0));
  final head = Path()
    ..moveTo(-r * .85, r * .4)
    ..quadraticBezierTo(-r * 1.0, -r * .9, r * .1, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.05, -r * .3)
    ..lineTo(r * 1.3, r * .1)
    ..quadraticBezierTo(r * 1.3, r * .7, r * .9, r * .95)
    ..quadraticBezierTo(r * .1, r * 1.15, -r * .5, r * .9)
    ..close();
  fillPath(c, head, stone, Offset(-r, -r), Offset(r, r));
  c.drawPath(Path()..moveTo(r * .1, -r * .5)..quadraticBezierTo(r * .55, -r * .2, r * 1.05, -r * .48), strokePaint(shade(stone[2], -.3), 4));
  final glow = look.eyeGlow ?? const Color(0xFFB07AFF);
  final eye = Offset(r * .66, -r * .28);
  c.drawCircle(eye, r * .2, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _ellipse(c, eye, r * .14, r * .08, Paint()..color = glow);
  // Snarling mouth with fangs.
  c.drawPath(Path()..moveTo(r * .35, r * .5)..quadraticBezierTo(r * .8, r * .7, r * 1.2, r * .45), strokePaint(const Color(0xFF1A1418), 2.4));
  for (final x in const [.55, .95]) {
    c.drawPath(poly([Offset(r * x - 2.5, r * .5), Offset(r * x, r * .8), Offset(r * x + 2.5, r * .5)]), Paint()..color = const Color(0xFFE8E4DA));
  }
  c.drawLine(Offset(-r * .2, -r * .7), Offset(r * .05, -r * .35), strokePaint(const Color(0x55000000), 1.2));
}


/// A demon's head: great curling horns, a sharp face, burning eyes, a goatee and fangs.
void _demonHead(Canvas c, double r, Look look) {
  final hide = look.skin;
  // Horns curling back and up.
  for (final (dx, far) in const [(-.25, true), (.25, false)]) {
    final horn = Path()
      ..moveTo(r * dx - r * .3, -r * .7)
      ..cubicTo(r * (dx - .3), -r * 2.2, r * (dx + .9), -r * 2.6, r * (dx + 1.1), -r * 1.9)
      ..cubicTo(r * (dx + .6), -r * 2.1, r * (dx + .1), -r * 1.7, r * dx + r * .3, -r * .65)
      ..close();
    fillPath(c, horn, far ? const [Color(0xFF5A5048), Color(0xFF2A2420), Color(0xFF0E0A08)] : const [Color(0xFF8A7E70), Color(0xFF3E362E), Color(0xFF14100C)], Offset(r * (dx - .3), -r * 2.6), Offset(r * (dx + 1.1), -r * .65));
    // Ridged rings round the horn.
    c.save();
    c.clipPath(horn);
    for (var i = 0; i < 4; i++) {
      final y = -r * (.95 + i * .32);
      c.drawLine(Offset(r * (dx - 1), y + r * .25), Offset(r * (dx + 1.2), y - r * .2), strokePaint(const Color(0x66000000), 1.4));
    }
    c.restore();
  }
  final ear = poly([Offset(-r * .5, -r * .2), Offset(-r * 1.15, -r * .6), Offset(-r * .6, r * .2)]);
  fillPath(c, ear, hide, Offset(-r * 1.1, -r * .6), Offset(-r * .5, r * .2));
  final head = Path()
    ..moveTo(-r * .8, r * .3)
    ..quadraticBezierTo(-r * .95, -r * .9, r * .1, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.05, -r * .2)
    ..quadraticBezierTo(r * 1.15, r * .5, r * .75, r * 1.05)
    ..quadraticBezierTo(r * .2, r * 1.2, -r * .45, r * .85)
    ..close();
  fillPath(c, head, hide, Offset(-r, -r), Offset(r, r));
  c.drawPath(Path()..moveTo(r * .1, -r * .52)..lineTo(r * .65, -r * .3)..lineTo(r * 1.05, -r * .5), strokePaint(shade(hide[2], -.3), 3.6));
  final glow = look.eyeGlow ?? const Color(0xFFFFD45A);
  final eye = Offset(r * .66, -r * .2);
  c.drawCircle(eye, r * .22, Paint()..color = glow.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _ellipse(c, eye, r * .15, r * .07, Paint()..color = glow);
  // Cheekbone, a darker snout, and a goatee.
  c.save();
  c.clipPath(head);
  _ellipse(c, Offset(r * .95, r * .55), r * .45, r * .5, Paint()..color = shade(hide[2], -.15).withValues(alpha: .45));
  c.drawPath(Path()..moveTo(r * .2, r * .1)..quadraticBezierTo(r * .5, r * .3, r * .55, r * .05), strokePaint(shade(hide[2], -.2).withValues(alpha: .6), 1.6));
  c.restore();
  c.drawPath(poly([Offset(r * .55, r * .9), Offset(r * .75, r * 1.45), Offset(r * .85, r * .9)]), Paint()..color = const Color(0xFF1A0A08));
  // A grin with fire glowing inside it.
  final grin = Path()
    ..moveTo(r * .35, r * .5)
    ..quadraticBezierTo(r * .75, r * .78, r * 1.05, r * .45)
    ..quadraticBezierTo(r * .75, r * .6, r * .35, r * .5)
    ..close();
  c.drawPath(grin, Paint()..color = (look.embers ?? const Color(0xFFFF7A2A)).withValues(alpha: .9));
  c.drawPath(grin, Paint()
    ..color = (look.embers ?? const Color(0xFFFF7A2A)).withValues(alpha: .5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawPath(Path()..moveTo(r * .35, r * .5)..quadraticBezierTo(r * .75, r * .72, r * 1.05, r * .45), strokePaint(const Color(0xFF1A0A08), 2.2));
  for (final x in const [.5, .9]) {
    c.drawPath(poly([Offset(r * x - 2.2, r * .52), Offset(r * x, r * .76), Offset(r * x + 2.2, r * .52)]), Paint()..color = const Color(0xFFF2EAD2));
  }
}


/// A minotaur: a bull's head with a broad muzzle, flaring nostrils, a nose ring and great horns.
void _bullHead(Canvas c, double r, Look look) {
  final hide = look.skin;
  // Horns sweeping out and forward.
  for (final (dx, far) in const [(-.35, true), (.15, false)]) {
    final horn = Path()
      ..moveTo(r * dx - r * .25, -r * .6)
      ..cubicTo(r * (dx - 1.1), -r * .9, r * (dx - 1.0), -r * 2.0, r * (dx + .2), -r * 2.1)
      ..cubicTo(r * (dx - .4), -r * 1.7, r * (dx - .5), -r * 1.1, r * dx + r * .25, -r * .8)
      ..close();
    fillPath(c, horn, far ? const [Color(0xFFCFC2A0), Color(0xFF8A7E62), Color(0xFF3E3626)] : const [Color(0xFFF2EAD2), Color(0xFFB8AC8A), Color(0xFF4E4636)], Offset(r * (dx - 1.1), -r * 2), Offset(r * dx, -r * .6));
  }
  // Ear sticking out sideways.
  final ear = Path()
    ..moveTo(-r * .45, -r * .35)
    ..quadraticBezierTo(-r * 1.25, -r * .6, -r * 1.2, -r * .1)
    ..quadraticBezierTo(-r * .9, r * .05, -r * .45, -r * .05)
    ..close();
  fillPath(c, ear, hide, Offset(-r * 1.2, -r * .6), Offset(-r * .45, 0));
  // Long skull and a heavy muzzle jutting forward.
  final head = Path()
    ..moveTo(-r * .7, r * .5)
    ..quadraticBezierTo(-r * .95, -r * .95, r * .2, -r * .95)
    ..quadraticBezierTo(r * .9, -r * .85, r * 1.15, -r * .1)
    ..lineTo(r * 1.55, r * .3)
    ..quadraticBezierTo(r * 1.7, r * .95, r * 1.15, r * 1.05)
    ..quadraticBezierTo(r * .3, r * 1.25, -r * .45, r * .95)
    ..close();
  fillPath(c, head, hide, Offset(-r, -r), Offset(r * 1.6, r));
  final muzzle = Path()..addOval(Rect.fromCenter(center: Offset(r * 1.25, r * .65), width: r * .95, height: r * .75));
  fillPath(c, muzzle, [shade(hide[0], .15), shade(hide[1], .1), hide[2]], Offset(r * .8, r * .3), Offset(r * 1.7, r));
  c.drawCircle(Offset(r * 1.5, r * .55), r * .09, Paint()..color = const Color(0xFF1A0E08));
  c.drawCircle(Offset(r * 1.25, r * .6), r * .08, Paint()..color = const Color(0xFF1A0E08));
  c.drawArc(Rect.fromCenter(center: Offset(r * 1.42, r * .95), width: r * .38, height: r * .38), 0, math.pi * 2, false, strokePaint(const Color(0xFFE8C060), 2.2));
  // Angry little eye under a heavy brow, and a shaggy forelock.
  final glow = look.eyeGlow ?? const Color(0xFFE84A2A);
  final eye = Offset(r * .55, -r * .25);
  c.drawCircle(eye, r * .16, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  _ellipse(c, eye, r * .12, r * .08, Paint()..color = glow);
  c.drawPath(Path()..moveTo(r * .2, -r * .5)..quadraticBezierTo(r * .55, -r * .65, r * .95, -r * .42), strokePaint(shade(hide[2], -.3), 4));
  final tuft = Path()..moveTo(-r * .2, -r * .9);
  for (var i = 0; i < 5; i++) {
    tuft.lineTo(r * (-.1 + i * .16), -r * (1.2 + (i % 2) * .15));
    tuft.lineTo(r * (-.02 + i * .16), -r * .85);
  }
  c.drawPath(tuft, Paint()..color = shade(hide[1], -.35));
}

/// A ghoul: bald, grey-green and gaunt, sunken glowing eyes, pointed ears and a jaw of needle teeth.
void _ghoulHead(Canvas c, double r, Look look) {
  final skin = look.skin;
  final ear = poly([Offset(-r * .45, -r * .3), Offset(-r * 1.25, -r * .9), Offset(-r * .55, r * .15)]);
  fillPath(c, ear, skin, Offset(-r * 1.2, -r * .9), Offset(-r * .45, r * .15));
  final head = Path()
    ..moveTo(-r * .8, r * .2)
    ..quadraticBezierTo(-r * 1.0, -r * 1.05, r * .15, -r * 1.05)
    ..quadraticBezierTo(r * 1.0, -r * 1.0, r * 1.05, -r * .2)
    ..quadraticBezierTo(r * 1.1, r * .3, r * .95, r * .55)
    ..lineTo(r * .9, r * 1.1)
    ..quadraticBezierTo(r * .3, r * 1.25, -r * .35, r * .85)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // Hollow cheek and sunken eye socket.
  c.drawPath(Path()..moveTo(r * .2, r * .25)..quadraticBezierTo(r * .45, r * .55, r * .3, r * .8), strokePaint(const Color(0x55000000), 2.4));
  _ellipse(c, Offset(r * .62, -r * .25), r * .26, r * .2, Paint()..color = const Color(0xAA0E1210));
  final glow = look.eyeGlow ?? const Color(0xFFD8F07A);
  c.drawCircle(Offset(r * .66, -r * .25), r * .15, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  c.drawCircle(Offset(r * .66, -r * .25), r * .08, Paint()..color = glow);
  // A gaping mouth full of needles.
  c.drawPath(Path()..moveTo(r * .4, r * .55)..lineTo(r * 1.0, r * .5)..lineTo(r * .95, r * .95)..lineTo(r * .45, r * .85)..close(), Paint()..color = const Color(0xFF2A0A0A));
  for (var i = 0; i < 5; i++) {
    final x = r * (.45 + i * .12);
    c.drawPath(poly([Offset(x - 1.6, r * .54), Offset(x, r * .72), Offset(x + 1.6, r * .54)]), Paint()..color = const Color(0xFFE8E2C8));
    c.drawPath(poly([Offset(x - 1.6, r * .88), Offset(x, r * .72), Offset(x + 1.6, r * .88)]), Paint()..color = const Color(0xFFE8E2C8));
  }
  // A few lank strands.
  for (final x in const [-.4, -.1, .2]) {
    c.drawPath(Path()..moveTo(r * x, -r * .95)..quadraticBezierTo(r * (x - .3), -r * .3, r * (x - .25), r * .3), strokePaint(look.hair, 1.4));
  }
}

/// A banshee: a pale, hollow-eyed face, its mouth open in a wail, and long hair streaming back.
void _bansheeHead(Canvas c, double r, Look look, double t, bool still) {
  final skin = look.skin, hair = look.hair, flow = still ? 0.0 : math.sin(t / 300);
  // Hair streaming far behind, as if in a gale.
  for (var i = 0; i < 6; i++) {
    final y = -r * .9 + i * r * .32, len = r * (3.2 + (i % 3) * .5);
    final strand = Path()
      ..moveTo(r * .2, y)
      ..cubicTo(-r * .8, y - r * .4, -len * .6, y + r * (.6 + flow * .3), -len, y + r * (.2 + flow * .4 + i * .1))
      ..cubicTo(-len * .6, y + r * (.9 + flow * .2), -r * .8, y + r * .4, r * .2, y + r * .25)
      ..close();
    c.drawPath(strand, Paint()..color = hair.withValues(alpha: .55 + (i % 2) * .2));
  }
  final head = Path()
    ..moveTo(-r * .75, r * .2)
    ..quadraticBezierTo(-r * .9, -r * .95, r * .15, -r * 1.0)
    ..quadraticBezierTo(r * .95, -r * .95, r * 1.0, -r * .2)
    ..quadraticBezierTo(r * 1.05, r * .45, r * .75, r * 1.0)
    ..quadraticBezierTo(r * .2, r * 1.2, -r * .4, r * .85)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // Hollow black eyes with pinpoint lights.
  final glow = look.eyeGlow ?? const Color(0xFF9ADFFF);
  _ellipse(c, Offset(r * .6, -r * .22), r * .2, r * .26, Paint()..color = const Color(0xFF0A0E14));
  c.drawCircle(Offset(r * .64, -r * .2), r * .07, Paint()..color = glow);
  c.drawCircle(Offset(r * .64, -r * .2), r * .2, Paint()..color = glow.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  // The wail: a long dark open mouth.
  _ellipse(c, Offset(r * .72, r * .55), r * .18, r * .34, Paint()..color = const Color(0xFF0A0E14));
  // A hood of hair over the brow.
  final fringe = Path()
    ..moveTo(-r * .8, r * .1)
    ..quadraticBezierTo(-r * .9, -r * 1.15, r * .3, -r * 1.12)
    ..quadraticBezierTo(r * .9, -r * 1.05, r * .95, -r * .55)
    ..quadraticBezierTo(r * .4, -r * .8, -r * .1, -r * .55)
    ..quadraticBezierTo(-r * .5, -r * .3, -r * .8, r * .1)
    ..close();
  c.drawPath(fringe, Paint()..color = hair);
}

/// A witch: a sallow face with a long hooked nose, a wart, a sly grin and a tall crooked hat.
void _witchHead(Canvas c, double r, Look look) {
  final skin = look.skin, hat = look.hatColour ?? const Color(0xFF1E1A24);
  // Straggly hair behind.
  c.drawPath(
    Path()
      ..moveTo(-r * .2, -r * .7)
      ..quadraticBezierTo(-r * 1.4, -r * .2, -r * 1.1, r * 1.3)
      ..quadraticBezierTo(-r * .6, r * .6, -r * .4, r * .2)
      ..close(),
    Paint()..color = look.hair,
  );
  final head = Path()
    ..moveTo(-r * .75, r * .2)
    ..quadraticBezierTo(-r * .9, -r * .9, r * .15, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.0, -r * .2)
    ..quadraticBezierTo(r * 1.0, r * .5, r * .8, r * 1.0)
    ..quadraticBezierTo(r * .2, r * 1.15, -r * .4, r * .85)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // The nose, hooked down over the lip, and a wart.
  final nose = Path()
    ..moveTo(r * .85, -r * .15)
    ..quadraticBezierTo(r * 1.55, r * .15, r * 1.25, r * .5)
    ..quadraticBezierTo(r * 1.1, r * .35, r * .9, r * .3)
    ..close();
  fillPath(c, nose, skin, Offset(r * .85, -r * .15), Offset(r * 1.5, r * .5));
  c.drawCircle(Offset(r * 1.22, r * .12), r * .07, Paint()..color = shade(skin[1], -.3));
  final glow = look.eyeGlow ?? const Color(0xFFB8F05A);
  c.drawCircle(Offset(r * .58, -r * .25), r * .14, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  _ellipse(c, Offset(r * .58, -r * .25), r * .1, r * .06, Paint()..color = glow);
  c.drawPath(Path()..moveTo(r * .4, r * .66)..quadraticBezierTo(r * .75, r * .78, r * .95, r * .58), strokePaint(const Color(0xFF2A1010), 1.8));
  // A tall, bent, pointed hat with a broad brim.
  final brim = Path()..addOval(Rect.fromCenter(center: Offset(r * .05, -r * .78), width: r * 3.2, height: r * .6));
  fillPath(c, brim, [shade(hat, .2), hat, shade(hat, -.5)], Offset(-r * 1.5, -r), Offset(r * 1.6, -r * .5));
  final cone = Path()
    ..moveTo(-r * .85, -r * .85)
    ..quadraticBezierTo(-r * .4, -r * 2.2, r * .2, -r * 2.6)
    ..quadraticBezierTo(r * .5, -r * 2.75, r * 1.0, -r * 2.3)
    ..quadraticBezierTo(r * .55, -r * 2.3, r * .45, -r * 2.05)
    ..quadraticBezierTo(r * .5, -r * 1.4, r * .95, -r * .85)
    ..close();
  fillPath(c, cone, [shade(hat, .2), hat, shade(hat, -.5)], Offset(-r * .9, -r * 2.6), Offset(r * 1, -r * .8));
  c.drawLine(Offset(-r * .8, -r * 1.02), Offset(r * .92, -r * 1.02), strokePaint(look.trim ?? const Color(0xFF6A3A8A), 3));
}


/// A mage's mask over the face: a smooth shell from brow to chin with glowing eye slits, a rim
/// and a gem on the brow. Its colour is the mask's (silver, gold or porcelain).
void _mageMask(Canvas c, double r, Look look, double t, bool still) {
  final col = look.helm ?? const [Color(0xFFD8E2EE), Color(0xFF9AA6B4), Color(0xFF3E4652)];
  final glow = look.weaponGlow ?? const Color(0xFF9ADFFF);
  final mask = Path()
    ..moveTo(r * .05, -r * .95)
    ..quadraticBezierTo(r * .8, -r * 1.05, r * 1.12, -r * .45)
    ..quadraticBezierTo(r * 1.25, r * .1, r * 1.05, r * .55)
    ..quadraticBezierTo(r * .85, r * 1.05, r * .45, r * 1.0)
    ..quadraticBezierTo(r * .1, r * .9, r * .05, r * .4)
    ..quadraticBezierTo(r * -.05, -r * .3, r * .05, -r * .95)
    ..close();
  fillPath(c, mask, col, Offset(r * .1, -r), Offset(r * 1.1, r));
  // A raised rim and a cheek line.
  c.drawPath(Path()..moveTo(r * .1, -r * .8)..quadraticBezierTo(r * .75, -r * .92, r * 1.05, -r * .4), strokePaint(shade(col[0], .2), 1.4));
  c.drawPath(Path()..moveTo(r * .55, r * .2)..quadraticBezierTo(r * .75, r * .45, r * .95, r * .35), strokePaint(shade(col[2], .1).withValues(alpha: .6), 1.1));
  // The eye slit, glowing.
  final pulse = still ? 1.0 : .75 + .25 * math.sin(t / 420);
  final eye = Path()
    ..moveTo(r * .48, -r * .28)
    ..quadraticBezierTo(r * .78, -r * .42, r * 1.02, -r * .26)
    ..quadraticBezierTo(r * .78, -r * .18, r * .48, -r * .28)
    ..close();
  c.drawPath(eye, Paint()..color = const Color(0xFF0A0C12));
  c.drawCircle(Offset(r * .8, -r * .29), r * .18, Paint()..color = glow.withValues(alpha: .45 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(Offset(r * .8, -r * .29), r * .05, Paint()..color = glow);
  // A gem on the brow.
  c.drawCircle(Offset(r * .55, -r * .7), r * .13, Paint()..color = glow);
  c.drawCircle(Offset(r * .55, -r * .7), r * .13, strokePaint(shade(col[2], -.2), .9));
}

/// A swept-back horn from the temple ([dir] -1 behind), ivory with ridges.
void _horn(Canvas c, Offset root, double r, {double size = 1}) {
  const ivory = [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)];
  final p = Path()
    ..moveTo(root.dx + r * .25 * size, root.dy)
    ..quadraticBezierTo(root.dx - r * .5 * size, root.dy - r * .9 * size, root.dx - r * 1.7 * size, root.dy - r * .95 * size)
    ..quadraticBezierTo(root.dx - r * .7 * size, root.dy - r * .5 * size, root.dx - r * .25 * size, root.dy + r * .25 * size)
    ..close();
  fillPath(c, p, ivory, root - Offset(r * 1.7 * size, r), root + Offset(r * .3, r * .3), width: 1.4);
  for (var i = 1; i <= 3; i++) {
    final k = i / 4;
    final a = Offset(root.dx - r * (.15 + 1.1 * k) * size, root.dy - r * (.15 + .55 * k) * size);
    c.drawLine(a, a + Offset(r * .08, r * .22 * size * (1 - k)), strokePaint(const Color(0x667A6A48), 1));
  }
}

/// The wyrmhelm: a close helm in the dragon's colour, its crest a row of spines running back, two
/// horns swept back from the temples, scaled cheek guards, and a dark visor slit that glows when
/// the armour does.
void _wyrmHelm(Canvas c, double r, Look look, double t, bool still) {
  final col = look.helm ?? ramp(0xFF8B939C);
  // Spines along the crest, behind the helm.
  for (var i = 0; i < 5; i++) {
    final x = r * .5 - i * r * .42, y = -r * 1.12 + i * r * .12;
    fillPath(
      c,
      Path()
        ..moveTo(x, y + r * .12)
        ..lineTo(x - r * .35, y - r * (.55 - i * .06))
        ..lineTo(x - r * .3, y + r * .2)
        ..close(),
      col,
      Offset(x - r * .3, y - r * .5),
      Offset(x, y + r * .2),
      width: 1.2,
    );
  }
  _horn(c, Offset(-r * .2, -r * .7), r);
  final h = Path()
    ..moveTo(-r * 1.0, r * 1.0)
    ..lineTo(-r * 1.05, -r * .4)
    ..quadraticBezierTo(-r * .95, -r * 1.22, r * .15, -r * 1.22)
    ..quadraticBezierTo(r * 1.08, -r * 1.15, r * 1.18, -r * .35)
    // The face plate juts forward into a brow ridge.
    ..lineTo(r * 1.32, -r * .05)
    ..lineTo(r * 1.14, r * .3)
    ..lineTo(r * 1.2, r * .95)
    ..quadraticBezierTo(r * .1, r * 1.25, -r * 1.0, r * 1.0)
    ..close();
  fillPath(c, h, col, Offset(-r, -r), Offset(r * 1.1, r));
  c.save();
  c.clipPath(h);
  // Scales over the cheek guard.
  final edge = strokePaint(shade(col[1], -.35).withValues(alpha: .7), .9);
  for (var row = 0; row < 3; row++) {
    for (var col2 = 0; col2 < 3; col2++) {
      final o = Offset(-r * .55 + col2 * r * .42 + (row.isOdd ? r * .21 : 0), r * .1 + row * r * .3);
      c.drawArc(Rect.fromCenter(center: o, width: r * .42, height: r * .34), 0, math.pi, false, edge);
    }
  }
  _ellipse(c, Offset(-r * .2, -r * .78), r * .6, r * .22, Paint()..color = const Color(0x33FFFFFF), -.2);
  c.restore();
  // The near horn, over the helm.
  _horn(c, Offset(r * .05, -r * .62), r, size: 1.1);
  final glow = look.armourGlow;
  final slit = Path()
    ..moveTo(r * .35, -r * .28)
    ..lineTo(r * 1.22, -r * .12)
    ..lineTo(r * 1.15, r * .02)
    ..lineTo(r * .38, -r * .12)
    ..close();
  if (glow != null) {
    final pulse = still ? .8 : .65 + .35 * math.sin(t / 400);
    c.drawPath(slit, Paint()..color = glow.withValues(alpha: .7 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
  c.drawPath(slit, Paint()..color = glow ?? const Color(0xFF08090B));
  // The visor is a dragon's upper jaw: a row of teeth hanging over the slit.
  final fang = Paint()..color = const Color(0xFFEDE6D2);
  for (var i = 0; i < 6; i++) {
    final x = r * (.45 + i * .14), y = -r * (.26 - i * .025);
    c.drawPath(poly([Offset(x - r * .05, y), Offset(x, y + r * (i.isEven ? .2 : .13)), Offset(x + r * .05, y)]), fang);
  }
  // And a lower jaw guarding the chin, its own teeth pointing up.
  for (var i = 0; i < 4; i++) {
    final x = r * (.6 + i * .15), y = r * (.32 + i * .02);
    c.drawPath(poly([Offset(x - r * .045, y), Offset(x, y - r * .14), Offset(x + r * .045, y)]), fang);
  }
}

/// A wyrmhorn circlet: a band in the dragon's colour with a gem, and two small horns swept back.
void _wyrmCirclet(Canvas c, double r, Look look) {
  final col = look.helm ?? ramp(0xFFC9A24E);
  _horn(c, Offset(-r * .35, -r * .62), r, size: .7);
  final band = Path()
    ..moveTo(-r * .95, -r * .4)
    ..quadraticBezierTo(0, -r * .78, r * .95, -r * .58);
  c.drawPath(band, strokePaint(outline, 5));
  c.drawPath(band, strokePaint(col[1], 3.2));
  c.drawPath(band, strokePaint(col[0].withValues(alpha: .7), 1));
  _horn(c, Offset(-r * .05, -r * .66), r, size: .78);
  final gem = Offset(r * .72, -r * .62);
  c.drawCircle(gem, r * .16, Paint()..color = outline);
  c.drawCircle(gem, r * .12, Paint()..color = look.armourGlow ?? const Color(0xFFE0502A));
}

/// A mummy's head: a skull shape wound in linen, the bands crossing it at angles, a dark slit
/// where the eyes are with two coals glowing in it, and a loose end trailing from the back.
void _mummyHead(Canvas c, double r, Look look, double t, bool still) {
  final linen = look.skin;
  final head = Path()
    ..moveTo(-r * .9, r * .25)
    ..quadraticBezierTo(-r * 1.08, -r * 1.12, r * .15, -r * 1.06)
    ..quadraticBezierTo(r * 1.0, -r * .98, r * 1.04, -r * .2)
    ..quadraticBezierTo(r * 1.1, r * .3, r * .9, r * .72)
    ..quadraticBezierTo(r * .55, r * 1.12, r * .02, r * 1.02)
    ..quadraticBezierTo(-r * .55, r * .92, -r * .9, r * .25)
    ..close();
  // The trailing end, behind the head.
  final sway = still ? 0.0 : math.sin(t / 380) * 3;
  final tail = Path()
    ..moveTo(-r * .75, -r * .1)
    ..quadraticBezierTo(-r * 1.35, r * .35 + sway * .3, -r * 1.25 + sway, r * 1.75)
    ..lineTo(-r * .95 + sway, r * 1.7)
    ..quadraticBezierTo(-r * 1.0, r * .5, -r * .6, r * .2)
    ..close();
  fillPath(c, tail, darker(linen), Offset(-r * 1.9, 0), Offset(-r * .6, 0), width: 1);
  fillPath(c, head, linen, Offset(-r, -r), Offset(r, r));
  // Bands across the head, clipped to it.
  c.save();
  c.clipPath(head);
  final dark = strokePaint(shade(linen[2], -.35).withValues(alpha: .6), 1.2);
  final lit = strokePaint(Color.lerp(linen[0], const Color(0xFFFFFFFF), .3)!.withValues(alpha: .55), .9);
  for (var i = 0; i < 7; i++) {
    final y = -r * .95 + i * r * .3, tilt = (i.isEven ? 1 : -1) * r * .22;
    if (i == 3) continue; // the eye slit
    c.drawLine(Offset(-r * 1.2, y - tilt), Offset(r * 1.2, y + tilt), dark);
    c.drawLine(Offset(-r * 1.2, y - tilt - 1.4), Offset(r * 1.2, y + tilt - 1.4), lit);
  }
  c.restore();
  // The eye slit, dark, with two glowing eyes.
  final slit = Path()
    ..moveTo(r * .05, -r * .32)
    ..quadraticBezierTo(r * .6, -r * .42, r * 1.05, -r * .3)
    ..lineTo(r * 1.04, -r * .1)
    ..quadraticBezierTo(r * .6, -r * .18, r * .1, -r * .1)
    ..close();
  c.drawPath(slit, Paint()..color = const Color(0xFF140C06));
  final glow = look.eyeGlow ?? const Color(0xFFFFB84A);
  final pulse = still ? 1.0 : .8 + .2 * math.sin(t / 260);
  for (final x in const [.42, .82]) {
    final at = Offset(r * x, -r * .22);
    c.drawCircle(at, r * .16 * pulse, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawCircle(at, r * .065, Paint()..color = glow);
  }
  // A rotted gap at the jaw.
  c.drawPath(
    Path()
      ..moveTo(r * .55, r * .5)
      ..quadraticBezierTo(r * .75, r * .62, r * .92, r * .52)
      ..quadraticBezierTo(r * .78, r * .78, r * .55, r * .5),
    Paint()..color = const Color(0xCC1A0E06),
  );
}

/// A pharaoh's striped headcloth: [back] draws the cloth behind the head (the flaring sides and
/// the tail), the front pass the band across the brow, the rearing cobra and the plaited beard.
void _nemes(Canvas c, double r, {required bool back}) {
  const gold = [Color(0xFFFFE08A), Color(0xFFE0B040), Color(0xFF7A5A18)], blue = Color(0xFF2A4E9A);
  if (back) {
    final cloth = Path()
      ..moveTo(r * .2, -r * 1.25)
      ..quadraticBezierTo(-r * 1.3, -r * 1.3, -r * 1.55, r * .2)
      ..lineTo(-r * 1.2, r * 1.9)
      ..lineTo(-r * .2, r * 1.6)
      ..lineTo(-r * .1, r * .5)
      ..close();
    fillPath(c, cloth, gold, Offset(-r * 1.5, 0), Offset(r * .2, 0));
    c.save();
    c.clipPath(cloth);
    for (var i = -6; i < 8; i++) {
      final x = i * r * .28;
      c.drawLine(Offset(x - r, -r * 1.4), Offset(x + r * .2, r * 2), strokePaint(blue, r * .11));
    }
    c.restore();
    c.drawPath(cloth, strokePaint(outline, 1.3));
    return;
  }
  // Over the top of the head, striped, down to a band at the brow.
  final cap = Path()
    ..moveTo(-r * 1.0, r * .1)
    ..quadraticBezierTo(-r * 1.15, -r * 1.35, r * .25, -r * 1.25)
    ..quadraticBezierTo(r * 1.1, -r * 1.15, r * 1.12, -r * .5)
    ..lineTo(r * .95, -r * .45)
    ..quadraticBezierTo(r * .2, -r * .62, -r * .55, -r * .2)
    ..close();
  fillPath(c, cap, gold, Offset(0, -r * 1.3), Offset(0, -r * .3));
  c.save();
  c.clipPath(cap);
  for (var i = 0; i < 9; i++) {
    final y = -r * 1.3 + i * r * .2;
    c.drawLine(Offset(-r * 1.2, y), Offset(r * 1.2, y + r * .35), strokePaint(blue, r * .09));
  }
  c.restore();
  c.drawPath(cap, strokePaint(outline, 1.3));
  // The brow band, and the cobra rearing from it.
  c.drawLine(Offset(-r * .55, -r * .26), Offset(r * 1.02, -r * .5), strokePaint(const Color(0xFFFFD86A), r * .12));
  final cobra = Path()
    ..moveTo(r * .82, -r * .5)
    ..quadraticBezierTo(r * .78, -r * .95, r * .98, -r * 1.05)
    ..quadraticBezierTo(r * 1.18, -r * 1.0, r * 1.08, -r * .82)
    ..quadraticBezierTo(r * 1.0, -r * .72, r * .98, -r * .5)
    ..close();
  fillPath(c, cobra, gold, Offset(r * .8, -r), Offset(r * 1.1, -r * .5), width: 1);
  c.drawCircle(Offset(r * 1.02, -r * .95), r * .045, Paint()..color = const Color(0xFFD23A3A));
  // The plaited beard under the chin.
  final beard = Path()
    ..moveTo(r * .55, r * .88)
    ..lineTo(r * .78, r * .9)
    ..lineTo(r * .76, r * 1.55)
    ..lineTo(r * .6, r * 1.6)
    ..close();
  fillPath(c, beard, gold, Offset(r * .55, 0), Offset(r * .8, 0), width: 1);
  for (var i = 1; i < 4; i++) {
    c.drawLine(Offset(r * .57, r * (.9 + i * .17)), Offset(r * .77, r * (.92 + i * .17)), strokePaint(blue, 1.4));
  }
}


/// A vampire: a pale human face with glowing red eyes, a pointed ear, black hair slicked back to a
/// sharp widow's peak, and two small fangs over the lip.
void _vampireHead(Canvas c, double r, Look look) {
  _humanHead(c, r, look);
  // The ear comes to a point.
  final ear = poly([Offset(-r * .32, -r * .05), Offset(-r * .42, -r * .78), Offset(-r * .02, -r * .12)]);
  fillPath(c, ear, look.skin, Offset(-r * .4, -r * .8), Offset.zero);
  // Slicked-back hair with a widow's peak.
  final hair = Path()
    ..moveTo(-r * .92, r * .3)
    ..quadraticBezierTo(-r * 1.18, -r * 1.2, r * .25, -r * 1.2)
    ..quadraticBezierTo(r * .85, -r * 1.1, r * .92, -r * .72)
    ..lineTo(r * .7, -r * .66)
    ..lineTo(r * .5, -r * .5)
    ..lineTo(r * .32, -r * .78)
    ..quadraticBezierTo(-r * .05, -r * .72, -r * .4, -r * .62)
    ..quadraticBezierTo(-r * .62, -r * .3, -r * .62, r * .25)
    ..close();
  final col = look.hair;
  fillPath(c, hair, [shade(col, .35), col, shade(col, -.5)], Offset(-r, -r * 1.2), Offset(r, r * .3));
  c.drawPath(Path()..moveTo(-r * .7, -r * .55)..quadraticBezierTo(-r * .2, -r * 1.05, r * .55, -r * .95), strokePaint(shade(col, .55).withValues(alpha: .5), 1.4));
  // Red eyes, glowing.
  final glow = look.eyeGlow ?? const Color(0xFFFF2A3A);
  c.drawCircle(Offset(r * .64, -r * .22), r * .17, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  c.drawCircle(Offset(r * .66, -r * .22), r * .06, Paint()..color = glow);
  // Fangs.
  final fang = Paint()..color = const Color(0xFFF8F4EA);
  c.drawPath(poly([Offset(r * .74, r * .5), Offset(r * .77, r * .68), Offset(r * .8, r * .5)]), fang);
  c.drawPath(poly([Offset(r * .84, r * .5), Offset(r * .86, r * .64), Offset(r * .89, r * .5)]), fang);
}

/// A werewolf: a wolf's long head, ears laid back, a ruff of fur at the neck, glowing eyes and a
/// mouth full of teeth.
void _wolfHead(Canvas c, double r, Look look) {
  final fur = look.skin, dark = [shade(fur[1], -.25), shade(fur[2], -.2), shade(fur[2], -.5)];
  // Ears, swept up and back (the far one darker).
  for (final (x, ramp) in [(.05, dark), (-.35, fur)]) {
    final ear = poly([Offset(r * (x - .35), -r * .55), Offset(r * (x - .55), -r * 1.75), Offset(r * (x + .3), -r * .78)]);
    fillPath(c, ear, ramp, Offset(r * (x - .5), -r * 1.7), Offset(r * x, -r * .6));
    c.drawPath(poly([Offset(r * (x - .25), -r * .7), Offset(r * (x - .45), -r * 1.45), Offset(r * (x + .12), -r * .82)]), Paint()..color = const Color(0x553A1A1A));
  }
  // The ruff: a ragged mane down the back of the head and neck.
  const spikes = [(-.1, -.95), (-.75, -1.05), (-.6, -.75), (-1.25, -.6), (-.95, -.3), (-1.4, -.05), (-1.0, .2), (-1.35, .55), (-.9, .6), (-1.05, 1.0), (-.5, .85), (-.3, 1.15), (.1, .9)];
  final ruff = poly([for (final (x, y) in spikes) Offset(r * x, r * y)]);
  fillPath(c, ruff, dark, Offset(-r * 1.4, -r), Offset(0, r));
  // Skull and a long muzzle.
  final head = Path()
    ..moveTo(-r * .8, r * .55)
    ..quadraticBezierTo(-r * 1.0, -r * .95, r * .15, -r * .95)
    ..quadraticBezierTo(r * .8, -r * .9, r * 1.0, -r * .4)
    ..quadraticBezierTo(r * 1.4, -r * .2, r * 1.75, -r * .05)
    ..quadraticBezierTo(r * 1.98, r * .1, r * 1.82, r * .32)
    ..lineTo(r * .95, r * .45)
    ..lineTo(r * 1.55, r * .55)
    ..quadraticBezierTo(r * 1.45, r * .82, r * .9, r * .82)
    ..quadraticBezierTo(r * .2, r * 1.15, -r * .45, r * .95)
    ..close();
  fillPath(c, head, fur, Offset(-r, -r), Offset(r * 1.9, r));
  // Lighter fur under the jaw.
  c.drawPath(Path()..moveTo(r * .2, r * .9)..quadraticBezierTo(r * .9, r * .9, r * 1.4, r * .68)..lineTo(r * .9, r * .55)..close(), Paint()..color = shade(fur[0], .2).withValues(alpha: .6));
  // The mouth, and teeth.
  c.drawPath(poly([Offset(r * 1.78, r * .34), Offset(r * .9, r * .44), Offset(r * 1.5, r * .55)]), Paint()..color = const Color(0xFF2A0A0A));
  final tooth = Paint()..color = const Color(0xFFF2EAD6);
  for (var i = 0; i < 4; i++) {
    final x = r * (1.0 + i * .18);
    c.drawPath(poly([Offset(x, r * (.43 - i * .02)), Offset(x + r * .05, r * (.55 - i * .02)), Offset(x + r * .1, r * (.42 - i * .02))]), tooth);
  }
  c.drawPath(poly([Offset(r * 1.5, r * .36), Offset(r * 1.55, r * .5), Offset(r * 1.6, r * .35)]), tooth);
  // The nose.
  _ellipse(c, Offset(r * 1.82, r * .06), r * .13, r * .1, Paint()..color = const Color(0xFF141010));
  // A heavy brow and a glowing, slanted eye.
  c.drawPath(Path()..moveTo(r * .3, -r * .52)..quadraticBezierTo(r * .65, -r * .6, r * 1.0, -r * .4), strokePaint(shade(fur[2], -.35), 3.6));
  final glow = look.eyeGlow ?? const Color(0xFFFFD84A);
  final eye = Offset(r * .66, -r * .3);
  c.drawCircle(eye, r * .2, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  _ellipse(c, eye, r * .14, r * .07, Paint()..color = glow, -.25);
  c.drawCircle(eye.translate(r * .03, 0), r * .035, Paint()..color = const Color(0xFF1A0A06));
}


/// An elf: a fine face, hair falling long down the back, and a long ear swept back through it.
void _elfHead(Canvas c, double r, Look look) {
  final col = look.hair;
  // Long hair down the back, behind the head.
  final back = Path()
    ..moveTo(-r * .2, -r * 1.05)
    ..quadraticBezierTo(-r * 1.35, -r * .9, -r * 1.25, r * .6)
    ..quadraticBezierTo(-r * 1.2, r * 1.6, -r * .85, r * 2.1)
    ..quadraticBezierTo(-r * .55, r * 1.4, -r * .3, r * .7)
    ..close();
  fillPath(c, back, [shade(col, .3), col, shade(col, -.45)], Offset(-r * 1.3, -r), Offset(-r * .3, r * 2));
  _humanHead(c, r, look);
  _hair(c, r, look);
  // The ear: long and pointed, swept up and back.
  final ear = Path()
    ..moveTo(-r * .3, r * .2)
    ..quadraticBezierTo(-r * .55, -r * .2, -r * 1.05, -r * .85)
    ..quadraticBezierTo(-r * .45, -r * .45, -r * .05, -r * .1)
    ..close();
  fillPath(c, ear, look.skin, Offset(-r, -r * .8), Offset(0, r * .2));
  c.drawPath(Path()..moveTo(-r * .3, r * .05)..quadraticBezierTo(-r * .55, -r * .3, -r * .85, -r * .65), strokePaint(const Color(0x33000000), 1));
  if (look.eyeGlow case final glow?) {
    c.drawCircle(Offset(r * .64, -r * .22), r * .14, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(Offset(r * .66, -r * .22), r * .05, Paint()..color = glow);
  }
}

/// A dwarf: an iron cap with a nose-guard, a big nose, and a beard down to the belt, braided.
void _dwarfHead(Canvas c, double r, Look look) {
  _humanHead(c, r, look);
  // The nose.
  blob(c, Offset(r * 1.0, r * .05), r * .26, [shade(look.skin[0], .05), look.skin[1], look.skin[2]]);
  // The beard: long and wide, with two braids at the bottom.
  final col = look.beard ?? const Color(0xFF8A4A22);
  final beard = Path()
    ..moveTo(-r * .55, -r * .1)
    ..quadraticBezierTo(-r * .15, r * .35, r * .55, r * .25)
    ..quadraticBezierTo(r * 1.3, r * .25, r * 1.2, r * .75)
    ..quadraticBezierTo(r * 1.15, r * 1.9, r * .6, r * 2.6)
    ..lineTo(r * .25, r * 2.3)
    ..quadraticBezierTo(-r * .2, r * 2.0, -r * .4, r * 1.2)
    ..quadraticBezierTo(-r * .6, r * .6, -r * .55, -r * .1)
    ..close();
  fillPath(c, beard, [shade(col, .25), col, shade(col, -.45)], Offset.zero, Offset(0, r * 2.6));
  final strands = strokePaint(const Color(0x33000000), 1);
  for (var i = 0; i < 5; i++) {
    c.drawLine(Offset(r * (.0 + i * .22), r * .7), Offset(r * (-.05 + i * .2), r * 2.0), strands);
  }
  final band = Paint()..color = const Color(0xFFD8B860);
  for (final y in const [1.7, 2.1]) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(r * .55, r * y), width: r * .45, height: r * .16), Radius.circular(r * .05)), band);
  }
  // The moustache over the mouth.
  final tache = Path()
    ..moveTo(r * .55, r * .35)
    ..quadraticBezierTo(r * 1.0, r * .2, r * 1.15, r * .6)
    ..quadraticBezierTo(r * .9, r * .5, r * .55, r * .55)
    ..close();
  fillPath(c, tache, [shade(col, .35), shade(col, .1), shade(col, -.3)], Offset(r * .5, r * .2), Offset(r * 1.1, r * .6));
  // The iron cap, with a rim and a nose-guard.
  final helm = look.helm ?? const [Color(0xFFB8BEC6), Color(0xFF6E747C), Color(0xFF2A2E34)];
  final cap = Path()
    ..moveTo(-r * 1.02, -r * .25)
    ..quadraticBezierTo(-r * 1.05, -r * 1.35, r * .15, -r * 1.32)
    ..quadraticBezierTo(r * 1.05, -r * 1.25, r * 1.0, -r * .45)
    ..close();
  fillPath(c, cap, helm, Offset(-r, -r * 1.3), Offset(r, -r * .3));
  c.drawPath(Path()..moveTo(-r * 1.05, -r * .25)..quadraticBezierTo(0, -r * .55, r * 1.05, -r * .42), strokePaint(helm[2], r * .22));
  c.drawPath(Path()..moveTo(-r * 1.05, -r * .25)..quadraticBezierTo(0, -r * .55, r * 1.05, -r * .42), strokePaint(helm[0], r * .12));
  c.drawLine(Offset(r * .85, -r * .5), Offset(r * .92, r * .02), strokePaint(helm[2], r * .2));
  c.drawLine(Offset(r * .85, -r * .5), Offset(r * .92, r * .02), strokePaint(helm[1], r * .1));
  // Rivets.
  for (final x in const [-.6, -.1, .4]) {
    c.drawCircle(Offset(r * x, -r * .45 + x.abs() * r * .05), r * .06, Paint()..color = helm[0]);
  }
  if (look.eyeGlow case final glow?) {
    c.drawCircle(Offset(r * .64, -r * .22), r * .12, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }
}


/// A samurai's kabuto: a lacquered bowl with a flared, laced neck-guard sweeping down behind, turned-
/// back flaps at the sides, a gilt crest rising from the brow, and (with [Look.mask]) a menpo over
/// the lower face: a snarling iron mask with a bristling moustache.
void _kabuto(Canvas c, double r, Look look) {
  final shell = look.helm ?? const [Color(0xFF5A4A4A), Color(0xFF2A2024), Color(0xFF0E0A0C)];
  final lace = look.trim ?? const Color(0xFFB8322A), gold = look.plume ?? const Color(0xFFE8C060);
  // The shikoro: three flared lames down the back of the neck.
  for (var i = 2; i >= 0; i--) {
    final y = -r * .35 + i * r * .32;
    final lame = Path()
      ..moveTo(-r * .2, y - r * .2)
      ..quadraticBezierTo(-r * 1.25, y - r * .1, -r * (1.55 + i * .12), y + r * .55)
      ..lineTo(-r * (1.3 + i * .1), y + r * .7)
      ..quadraticBezierTo(-r * .9, y + r * .25, -r * .1, y + r * .2)
      ..close();
    fillPath(c, lame, shell, Offset(-r * 1.5, y), Offset(0, y + r * .6));
    c.drawPath(Path()..moveTo(-r * .3, y + r * .14)..quadraticBezierTo(-r * .95, y + r * .3, -r * (1.38 + i * .1), y + r * .62), strokePaint(lace, 1.6));
  }
  _humanHead(c, r, look);
  if (look.mask case final menpo?) {
    // The menpo: iron cheeks and chin, a hooked nose, teeth bared, a white moustache.
    final m = Path()
      ..moveTo(r * .1, -r * .05)
      ..lineTo(r * 1.1, -r * .1)
      ..lineTo(r * 1.22, r * .12)
      ..lineTo(r * 1.05, r * .3)
      ..quadraticBezierTo(r * 1.0, r * .95, r * .45, r * .98)
      ..quadraticBezierTo(r * .05, r * .8, r * .1, -r * .05)
      ..close();
    fillPath(c, m, menpo, Offset(0, -r * .1), Offset(0, r));
    c.drawPath(poly([Offset(r * .62, r * .45), Offset(r * 1.02, r * .42), Offset(r * .98, r * .58), Offset(r * .64, r * .6)]), Paint()..color = const Color(0xFF1A0806));
    final tooth = Paint()..color = const Color(0xFFF2EAD6);
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(r * (.67 + i * .08), r * .45, r * .05, r * .06), tooth);
    }
    c.drawPath(Path()..moveTo(r * .55, r * .38)..quadraticBezierTo(r * .85, r * .28, r * 1.1, r * .4), strokePaint(const Color(0xFFE8E4DA), 2.4));
  }
  // The bowl, ribbed, with a peak over the brow.
  final bowl = Path()
    ..moveTo(-r * 1.05, -r * .2)
    ..quadraticBezierTo(-r * 1.1, -r * 1.42, r * .15, -r * 1.4)
    ..quadraticBezierTo(r * 1.1, -r * 1.3, r * 1.08, -r * .45)
    ..quadraticBezierTo(r * 1.35, -r * .38, r * 1.3, -r * .3)
    ..lineTo(r * .9, -r * .38)
    ..close();
  fillPath(c, bowl, shell, Offset(-r, -r * 1.4), Offset(r, -r * .2));
  for (var i = 0; i < 5; i++) {
    final x = -r * .8 + i * r * .38;
    c.drawPath(Path()..moveTo(x, -r * .35)..quadraticBezierTo(x * .7, -r * 1.2, r * .1, -r * 1.36), strokePaint(const Color(0x40FFFFFF), 1));
  }
  // The fukigaeshi: a flap turned back at the temple, edged in gold.
  final flap = poly([Offset(-r * .1, -r * .55), Offset(r * .35, -r * .55), Offset(r * .25, r * .05), Offset(-r * .25, -r * .1)]);
  fillPath(c, flap, shell, Offset(-r * .25, -r * .55), Offset(r * .35, 0));
  c.drawPath(flap, strokePaint(gold, 1.4));
  // The maedate: a pair of gilt horns sweeping up from the brow, with a crest disc between.
  for (final side in const [-1.0, 1.0]) {
    final horn = Path()
      ..moveTo(r * .55, -r * 1.05)
      ..quadraticBezierTo(r * (.55 + side * .55), -r * 1.6, r * (.5 + side * .45), -r * 2.25)
      ..quadraticBezierTo(r * (.55 + side * .3), -r * 1.6, r * .7, -r * 1.05)
      ..close();
    fillPath(c, horn, [shade(gold, .3), gold, shade(gold, -.45)], Offset(r * .3, -r * 2.2), Offset(r * .8, -r));
  }
  c.drawCircle(Offset(r * .62, -r * 1.12), r * .16, Paint()..color = gold);
  c.drawCircle(Offset(r * .62, -r * 1.12), r * .16, strokePaint(outline, 1));
  c.drawCircle(Offset(r * .62, -r * 1.12), r * .07, Paint()..color = lace);
  if (look.eyeGlow case final glow?) {
    c.drawCircle(Offset(r * .64, -r * .22), r * .14, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(Offset(r * .66, -r * .22), r * .05, Paint()..color = glow);
  }
}

/// An ashigaru's jingasa: a wide, shallow cone of lacquered iron, with a mon painted on the front.
void _jingasa(Canvas c, double r, Look look) {
  final hat = look.helm ?? const [Color(0xFF4A4A50), Color(0xFF24242A), Color(0xFF0A0A0C)];
  final cone = poly([Offset(-r * 1.55, -r * .55), Offset(r * .1, -r * 1.35), Offset(r * 1.6, -r * .5), Offset(r * .1, -r * .7)]);
  fillPath(c, cone, hat, Offset(0, -r * 1.35), Offset(0, -r * .5));
  c.drawCircle(Offset(r * .75, -r * .8), r * .16, Paint()..color = look.trim ?? const Color(0xFFE8C060));
  c.drawLine(Offset(r * .55, -r * .62), Offset(r * .7, r * .55), strokePaint(const Color(0xFF3A2A20), 1.2)); // the chin cord
}

/// A court magician's eboshi: a tall cap of black lacquered gauze, leaning back.
void _eboshi(Canvas c, double r) {
  final cap = Path()
    ..moveTo(-r * .85, -r * .65)
    ..quadraticBezierTo(-r * .9, -r * 1.6, -r * .55, -r * 2.25)
    ..quadraticBezierTo(-r * .05, -r * 2.05, r * .35, -r * 1.55)
    ..quadraticBezierTo(r * .85, -r * 1.1, r * .8, -r * .72)
    ..close();
  fillPath(c, cap, const [Color(0xFF4A4A54), Color(0xFF1A1A20), Color(0xFF050508)], Offset(-r, -r * 2.2), Offset(r, -r * .6));
  c.drawLine(Offset(-r * .85, -r * .7), Offset(r * .82, -r * .75), strokePaint(const Color(0xFF2A2A30), r * .14));
  c.drawLine(Offset(r * .55, -r * .72), Offset(r * .62, r * .5), strokePaint(const Color(0xFFE8E4DA), 1));
}

/// A topknot: the crown shaved, the hair oiled back and tied in a short queue folded over the top.
void _topknot(Canvas c, double r, Look look) {
  final col = look.hair;
  final sides = Path()
    ..moveTo(-r * .95, r * .2)
    ..quadraticBezierTo(-r * 1.1, -r * .7, -r * .45, -r * .95)
    ..quadraticBezierTo(-r * .15, -r * .7, -r * .35, -r * .3)
    ..quadraticBezierTo(-r * .55, 0, -r * .5, r * .3)
    ..close();
  fillPath(c, sides, [shade(col, .3), col, shade(col, -.45)], Offset(-r, -r), Offset(0, r * .3));
  final knot = Path()
    ..moveTo(-r * .5, -r * 1.0)
    ..quadraticBezierTo(-r * .2, -r * 1.35, r * .45, -r * 1.25)
    ..quadraticBezierTo(r * .55, -r * 1.12, r * .4, -r * 1.08)
    ..quadraticBezierTo(-r * .1, -r * 1.15, -r * .38, -r * .9)
    ..close();
  fillPath(c, knot, [shade(col, .3), col, shade(col, -.45)], Offset(-r * .5, -r * 1.3), Offset(r * .5, -r));
  c.drawLine(Offset(-r * .42, -r * 1.12), Offset(-r * .3, -r * .92), strokePaint(const Color(0xFFE8E4DA), 1.4));
}

/// An oni: a great red (or blue) face, two horns, a shock of wild hair, bulging eyes and tusks.
void _oniHead(Canvas c, double r, Look look) {
  final skin = look.skin, hair = look.hair;
  final mane = Path()
    ..moveTo(-r * .2, -r * 1.1)
    ..quadraticBezierTo(-r * 1.7, -r * 1.2, -r * 1.45, r * .2)
    ..quadraticBezierTo(-r * 1.6, r * .9, -r * .9, r * 1.1)
    ..quadraticBezierTo(-r * .6, r * .4, -r * .3, -r * .2)
    ..close();
  fillPath(c, mane, [shade(hair, .25), hair, shade(hair, -.5)], Offset(-r * 1.5, -r), Offset(0, r));
  final head = Path()
    ..moveTo(-r * .85, r * .5)
    ..quadraticBezierTo(-r * 1.05, -r * 1.05, r * .2, -r * 1.05)
    ..quadraticBezierTo(r * 1.15, -r * .95, r * 1.2, -r * .1)
    ..quadraticBezierTo(r * 1.3, r * .7, r * .9, r * 1.0)
    ..quadraticBezierTo(r * .1, r * 1.2, -r * .85, r * .5)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // Horns from the brow.
  for (final (x, h) in const [(.0, 1.0), (.55, .85)]) {
    final horn = poly([Offset(r * (x - .18), -r * .9), Offset(r * (x + .05), -r * (1.0 + h)), Offset(r * (x + .2), -r * .92)]);
    fillPath(c, horn, const [Color(0xFFF8F0DC), Color(0xFFD8C8A0), Color(0xFF6A5A3A)], Offset(r * x, -r * 2), Offset(r * x, -r * .9));
  }
  // A heavy scowling brow and bulging gold eyes.
  c.drawPath(Path()..moveTo(r * .2, -r * .5)..lineTo(r * .7, -r * .3)..lineTo(r * 1.15, -r * .5), strokePaint(shade(skin[2], -.3), r * .16));
  final eye = Offset(r * .72, -r * .15);
  _ellipse(c, eye, r * .2, r * .15, Paint()..color = look.eyeGlow ?? const Color(0xFFFFD84A));
  c.drawCircle(eye.translate(r * .05, 0), r * .07, Paint()..color = const Color(0xFF1A0A06));
  // A great grin full of teeth, and tusks jutting up.
  c.drawPath(Path()..moveTo(r * .35, r * .5)..quadraticBezierTo(r * .8, r * .78, r * 1.18, r * .45)..lineTo(r * 1.1, r * .62)..quadraticBezierTo(r * .75, r * .92, r * .4, r * .62)..close(), Paint()..color = const Color(0xFF2A0606));
  final tusk = Paint()..color = const Color(0xFFF2EAD6);
  for (final x in const [.48, 1.02]) {
    c.drawPath(poly([Offset(r * (x - .06), r * .66), Offset(r * x, r * .3), Offset(r * (x + .06), r * .64)]), tusk);
  }
  for (var i = 0; i < 4; i++) {
    c.drawRect(Rect.fromLTWH(r * (.55 + i * .11), r * .54, r * .07, r * .08), tusk);
  }
}

/// One of the Faceless: a head as smooth as an egg, porcelain-pale, with nothing on it at all (and
/// a hood over it for the Choir).
void _facelessHead(Canvas c, double r, Look look) {
  if (look.hood != null) fillPath(c, _openHood(r), look.hood!, Offset(-r, -r), Offset(r, r));
  final head = Path()..addOval(Rect.fromCenter(center: Offset(r * .1, -r * .05), width: r * 2.0, height: r * 2.3));
  fillPath(c, head, look.skin, Offset(-r, -r), Offset(r, r));
  // A soft sheen where a face should be, and a hairline crack.
  c.drawOval(Rect.fromCenter(center: Offset(r * .55, -r * .35), width: r * .6, height: r * .9), Paint()..color = const Color(0x44FFFFFF));
  c.drawPath(Path()..moveTo(r * .2, -r * 1.1)..lineTo(r * .32, -r * .7)..lineTo(r * .22, -r * .45)..lineTo(r * .34, -r * .15), strokePaint(const Color(0x553A3430), 1));
  if (look.hood != null) {
    final brim = Path()
      ..moveTo(-r * 1.1, r * .9)
      ..quadraticBezierTo(-r * 1.3, -r * 1.4, r * .3, -r * 1.35)
      ..quadraticBezierTo(r * 1.2, -r * 1.2, r * 1.1, -r * .6)
      ..quadraticBezierTo(r * .4, -r * 1.0, -r * .3, -r * .6)
      ..close();
    fillPath(c, brim, look.hood!, Offset(-r, -r), Offset(r, 0));
  }
}

/// The Mother of Masks' crown: a ring of small porcelain masks, each with a different face.
void _maskRing(Canvas c, double r) {
  for (var i = 0; i < 5; i++) {
    final a = -math.pi * .95 + i * math.pi * .32;
    final at = Offset(math.cos(a) * r * 1.55, math.sin(a) * r * 1.35 - r * .3);
    c.drawOval(Rect.fromCenter(center: at, width: r * .55, height: r * .7), Paint()..color = const Color(0xFFF2ECE2));
    c.drawOval(Rect.fromCenter(center: at, width: r * .55, height: r * .7), strokePaint(const Color(0xFF3A3430), 1));
    final eye = Paint()..color = const Color(0xFF1A1618);
    c.drawCircle(at + Offset(-r * .1, -r * .08), r * .05, eye);
    c.drawCircle(at + Offset(r * .1, -r * .08), r * .05, eye);
    c.drawArc(Rect.fromCenter(center: at + Offset(0, r * .12), width: r * .22, height: r * .12), i.isEven ? 0 : math.pi, math.pi, false, strokePaint(const Color(0xFF1A1618), 1));
  }
}


/// A lizardfolk: a long, flat scaled snout, a crest of spines down the back of the head, a yellow
/// slit eye and a row of small teeth.
void _lizardHead(Canvas c, double r, Look look) {
  final hide = look.skin;
  // The crest: spines down the back of the skull and neck, webbed in a darker hide.
  final crest = Path()..moveTo(r * .3, -r * .9);
  const spines = [(-.05, -1.55), (-.25, -1.0), (-.45, -1.55), (-.65, -.85), (-.9, -1.3), (-1.0, -.55), (-1.35, -.8), (-1.15, -.1), (-1.45, .15), (-.95, .5)];
  for (final (x, y) in spines) {
    crest.lineTo(r * x, r * y);
  }
  crest
    ..lineTo(-r * .6, r * .7)
    ..close();
  final fin = look.plume ?? const Color(0xFFB0502A);
  fillPath(c, crest, [shade(fin, .35), fin, shade(fin, -.5)], Offset(-r * 1.4, -r * 1.5), Offset(0, r * .6));
  // Skull and long snout.
  final head = Path()
    ..moveTo(-r * .8, r * .6)
    ..quadraticBezierTo(-r * 1.0, -r * .9, r * .2, -r * .9)
    ..quadraticBezierTo(r * .9, -r * .85, r * 1.2, -r * .35)
    ..quadraticBezierTo(r * 1.7, -r * .2, r * 1.9, r * .05)
    ..quadraticBezierTo(r * 1.95, r * .3, r * 1.7, r * .35)
    ..lineTo(r * .9, r * .45)
    ..lineTo(r * 1.6, r * .5)
    ..quadraticBezierTo(r * 1.5, r * .72, r * 1.0, r * .75)
    ..quadraticBezierTo(r * .2, r * 1.0, -r * .45, r * .95)
    ..close();
  fillPath(c, head, hide, Offset(-r, -r), Offset(r * 1.9, r));
  // Paler throat and scale spots.
  c.drawPath(Path()..moveTo(r * .1, r * .9)..quadraticBezierTo(r * .9, r * .85, r * 1.4, r * .62)..lineTo(r * .9, r * .5)..close(), Paint()..color = const Color(0x88E8D8A0));
  final spot = Paint()..color = shade(hide[2], -.2).withValues(alpha: .45);
  for (final (x, y, s) in const [(-.3, -.5, .12), (.0, -.6, .1), (-.5, -.15, .1), (.3, -.55, .08), (1.3, -.15, .07), (1.55, -.05, .06)]) {
    c.drawCircle(Offset(r * x, r * y), r * s, spot);
  }
  // The mouth line and little teeth.
  c.drawPath(Path()..moveTo(r * 1.75, r * .36)..lineTo(r * .85, r * .46), strokePaint(const Color(0xFF1A140A), 1.6));
  final tooth = Paint()..color = const Color(0xFFF2EAD6);
  for (var i = 0; i < 5; i++) {
    final x = r * (1.0 + i * .15);
    c.drawPath(poly([Offset(x, r * (.44 - i * .015)), Offset(x + r * .04, r * (.53 - i * .015)), Offset(x + r * .08, r * (.43 - i * .015))]), tooth);
  }
  // Nostril.
  c.drawCircle(Offset(r * 1.78, r * .02), r * .05, Paint()..color = const Color(0xFF1A140A));
  // A heavy brow ridge and a yellow slit eye.
  c.drawPath(Path()..moveTo(r * .3, -r * .55)..quadraticBezierTo(r * .65, -r * .68, r * 1.0, -r * .45), strokePaint(shade(hide[2], -.3), 3.4));
  final glow = look.eyeGlow ?? const Color(0xFFE8D040);
  final eye = Offset(r * .68, -r * .3);
  _ellipse(c, eye, r * .15, r * .11, Paint()..color = glow);
  _ellipse(c, eye, r * .03, r * .1, Paint()..color = const Color(0xFF14100A));
}


/// A shapeshifter's own head: lumpy and half-made, a nose that hasn't decided, and three eyes that
/// don't match (a person's, a goat's and something else's) drifting slowly about.
void _shifterHead(Canvas c, double r, Look look, double t, bool still) {
  final drift = still ? 0.0 : t / 900;
  final head = Path()
    ..moveTo(-r * .9, r * .3)
    ..quadraticBezierTo(-r * 1.15, -r * .6, -r * .5, -r * 1.0)
    ..quadraticBezierTo(r * .1, -r * 1.25, r * .6, -r * .9)
    ..quadraticBezierTo(r * 1.15, -r * .55, r * 1.0, r * .05)
    ..quadraticBezierTo(r * 1.2, r * .4, r * .85, r * .75)
    ..quadraticBezierTo(r * .3, r * 1.15, -r * .3, r * .95)
    ..quadraticBezierTo(-r * .8, r * .8, -r * .9, r * .3)
    ..close();
  fillPath(c, head, look.skin, Offset(-r, -r), Offset(r, r));
  // Lumps rising and sinking under the skin.
  for (var i = 0; i < 4; i++) {
    final p = Offset(r * (-.5 + i * .35), r * (-.55 + .1 * math.sin(drift + i * 1.7)));
    c.drawCircle(p, r * (.14 + .04 * math.sin(drift * 1.3 + i)), Paint()..color = shade(look.skin[1], .15).withValues(alpha: .7));
  }
  // A nose that hasn't made its mind up.
  c.drawPath(Path()..moveTo(r * .95, -r * .2)..quadraticBezierTo(r * 1.25, r * .05, r * .95, r * .2), strokePaint(shade(look.skin[2], -.1), 2));
  // Three mismatched eyes.
  final glow = look.eyeGlow ?? const Color(0xFFA0F0E0);
  final eyes = [
    (Offset(r * .55, -r * .3 + r * .05 * math.sin(drift)), r * .14, 0),
    (Offset(r * .15, -r * .55 + r * .06 * math.cos(drift * 1.2)), r * .1, 1),
    (Offset(r * .7, r * .2 + r * .05 * math.sin(drift * .8 + 2)), r * .08, 2),
  ];
  for (final (p, s, kind) in eyes) {
    c.drawCircle(p, s * 1.7, Paint()..color = glow.withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(p, s, Paint()..color = kind == 2 ? const Color(0xFFFF6A5A) : const Color(0xFFF2F6F0));
    if (kind == 1) {
      c.drawRect(Rect.fromCenter(center: p, width: s * 1.4, height: s * .45), Paint()..color = const Color(0xFF14101A));
    } else {
      c.drawCircle(p, s * .5, Paint()..color = const Color(0xFF14101A));
    }
  }
  // A mouth that's partly somebody else's.
  c.drawPath(Path()..moveTo(r * .45, r * .55)..quadraticBezierTo(r * .7, r * .7, r * .95, r * .5), strokePaint(const Color(0xAA2A1A30), 1.8));
}


/// One of the aeriekin: a hawk's head, feathered smooth, a crest swept back, a hooked gold beak and
/// a fierce eye.
void _birdHead(Canvas c, double r, Look look) {
  final f = look.skin;
  // The crest.
  for (final (x, y, l) in const [(-.4, -.8, 1.0), (-.65, -.55, .9), (-.85, -.25, .75)]) {
    final base = Offset(r * x, r * y);
    c.drawPath(poly([base + Offset(r * .25, 0), base + Offset(-r * l, -r * .35), base + Offset(r * .1, r * .3)]), Paint()..color = shade(f[1], -.1));
  }
  final head = Path()
    ..moveTo(-r * .85, r * .5)
    ..quadraticBezierTo(-r * 1.05, -r * .9, r * .2, -r * 1.0)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.0, -r * .1)
    ..quadraticBezierTo(r * .9, r * .5, r * .35, r * .85)
    ..quadraticBezierTo(-r * .3, r * 1.0, -r * .85, r * .5)
    ..close();
  fillPath(c, head, f, Offset(-r, -r), Offset(r, r));
  // Pale cheek feathers and a dark stripe behind the eye.
  c.drawPath(Path()..moveTo(r * .1, r * .1)..quadraticBezierTo(r * .5, r * .6, r * .9, r * .2)..lineTo(r * .8, -r * .05)..close(), Paint()..color = const Color(0x88F2EEE4));
  c.drawPath(Path()..moveTo(r * .55, -r * .25)..quadraticBezierTo(r * .1, -r * .2, -r * .3, r * .1), strokePaint(shade(f[2], -.3), 3));
  // The hooked beak.
  final beak = Path()
    ..moveTo(r * .85, -r * .35)
    ..quadraticBezierTo(r * 1.65, -r * .35, r * 1.6, r * .25)
    ..quadraticBezierTo(r * 1.4, -r * .05, r * 1.1, r * .1)
    ..lineTo(r * .85, r * .15)
    ..close();
  fillPath(c, beak, const [Color(0xFFFFE07A), Color(0xFFE0A030), Color(0xFF6A4A10)], Offset(r * .85, -r * .35), Offset(r * 1.6, r * .25));
  // The eye.
  final eye = Offset(r * .6, -r * .3);
  c.drawCircle(eye, r * .14, Paint()..color = look.eyeGlow ?? const Color(0xFFFFD84A));
  c.drawCircle(eye, r * .07, Paint()..color = const Color(0xFF14100A));
  c.drawLine(eye + Offset(-r * .2, -r * .16), eye + Offset(r * .22, -r * .1), strokePaint(shade(f[2], -.35), 2.2));
}

/// A batkin's head: broad pointed ears splayed back and forward (ridged inside), a round furry
/// skull, a short snout with an upturned leaf nose, small fangs and glowing eyes.
void _batHead(Canvas c, double r, Look look) {
  final fur = look.skin, dark = [shade(fur[1], -.25), shade(fur[2], -.2), shade(fur[2], -.5)];
  for (final (b0, b1, tip, ramp, inner) in [(-.75, .0, const Offset(-.95, -2.05), dark, const Color(0xFF5A3640)), (-.2, .55, const Offset(.62, -2.0), fur, const Color(0xFF9A6070))]) {
    final ear = Path()
      ..moveTo(r * b0, -r * .6)
      ..quadraticBezierTo(r * (b0 - .05), -r * 1.4, r * tip.dx, r * tip.dy)
      ..quadraticBezierTo(r * (b1 + .1), -r * 1.3, r * b1, -r * .75)
      ..close();
    fillPath(c, ear, ramp, tip * r, Offset(r * (b0 + b1) / 2, -r * .6));
    final cx = (b0 + b1) / 2;
    c.drawPath(
      Path()
        ..moveTo(r * (b0 + .15), -r * .75)
        ..quadraticBezierTo(r * (b0 + .05), -r * 1.35, r * (tip.dx * .8 + cx * .2), r * (tip.dy * .85 - .05))
        ..quadraticBezierTo(r * (b1 - .05), -r * 1.25, r * (b1 - .12), -r * .82)
        ..close(),
      Paint()..color = inner,
    );
    for (final k in const [.35, .6]) {
      c.drawLine(Offset(r * (cx + (tip.dx - cx) * k * .6), -r * (.8 + .2 * k)), Offset(r * (cx + (tip.dx - cx) * (k + .25)), r * (-.8 + (tip.dy + .8) * (k + .15))), strokePaint(shade(inner, -.4).withValues(alpha: .6), 1.2));
    }
  }
  final head = Path()
    ..moveTo(-r * .85, r * .55)
    ..quadraticBezierTo(-r * 1.05, -r * .9, r * .1, -r * .92)
    ..quadraticBezierTo(r * .85, -r * .88, r * .95, -r * .35)
    ..quadraticBezierTo(r * 1.2, -r * .2, r * 1.22, r * .15)
    ..quadraticBezierTo(r * 1.2, r * .55, r * .9, r * .6)
    ..quadraticBezierTo(r * .3, r * 1.1, -r * .45, r * .95)
    ..close();
  fillPath(c, head, fur, Offset(-r, -r), Offset(r * 1.3, r));
  // Tufts of fur at the cheek and throat.
  for (final (x, y) in const [(-.7, .7), (-.4, .95), (-.05, 1.0)]) {
    c.drawPath(poly([Offset(r * (x - .15), r * (y - .25)), Offset(r * (x - .05), r * (y + .25)), Offset(r * (x + .15), r * (y - .2))]), Paint()..color = fur[1]);
  }
  final leaf = Path()
    ..moveTo(r * 1.0, -r * .05)
    ..quadraticBezierTo(r * 1.0, -r * .5, r * 1.12, -r * .62)
    ..quadraticBezierTo(r * 1.3, -r * .4, r * 1.26, -r * .02)
    ..close();
  fillPath(c, leaf, [shade(fur[1], -.1), shade(fur[1], -.3), shade(fur[1], -.6)], Offset(r, -r * .6), Offset(r * 1.3, 0), width: 1.1);
  _ellipse(c, Offset(r * 1.16, r * .1), r * .13, r * .09, Paint()..color = const Color(0xFF1A1012));
  c.drawPath(poly([Offset(r * 1.18, r * .3), Offset(r * .55, r * .36), Offset(r * 1.0, r * .56)]), Paint()..color = const Color(0xFF240A10));
  for (final x in const [.72, 1.02]) {
    c.drawPath(poly([Offset(r * x - 2, r * .33), Offset(r * x, r * .62), Offset(r * x + 2, r * .33)]), Paint()..color = const Color(0xFFF2ECE0));
  }
  c.drawPath(Path()..moveTo(r * .2, -r * .52)..quadraticBezierTo(r * .55, -r * .66, r * .9, -r * .46), strokePaint(shade(fur[2], -.35), 3.2));
  final glow = look.eyeGlow ?? const Color(0xFFFFB04A), eye = Offset(r * .6, -r * .28);
  c.drawCircle(eye, r * .24, Paint()..color = glow.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  _ellipse(c, eye, r * .16, r * .12, Paint()..color = glow);
}

/// A yeti's head: a shaggy mane of white fur round the back and under the chin, horns curling
/// forward, a blue face, a heavy fur brow over glowing eyes, and two tusks.
void _yetiHead(Canvas c, double r, Look look) {
  final fur = look.skin, dark = [shade(fur[0], -.15), shade(fur[1], -.2), shade(fur[2], -.2)];
  const n = 13;
  final mane = Path();
  for (var i = 0; i <= n; i++) {
    final a = (60 + i * 250 / n) * math.pi / 180;
    final rr = r * (1.12 + .06 * math.sin(i * 1.9));
    final p = Offset(math.cos(a) * rr - r * .15, math.sin(a) * rr * 1.05 + r * .15);
    if (i == 0) {
      mane.moveTo(p.dx, p.dy);
    } else {
      final a2 = (60 + (i - .5) * 250 / n) * math.pi / 180;
      final rc = r * (1.5 + .12 * math.sin(i * 2.3));
      mane.quadraticBezierTo(math.cos(a2) * rc - r * .15, math.sin(a2) * rc * 1.05 + r * .15, p.dx, p.dy);
    }
  }
  mane
    ..lineTo(r * .2, r * .2)
    ..close();
  fillPath(c, mane, dark, Offset(-r * 1.4, -r * 1.4), Offset(r, r));
  for (final (x, far) in const [(-.1, true), (.35, false)]) {
    final horn = Path()
      ..moveTo(r * (x - .25), -r * .75)
      ..quadraticBezierTo(r * (x - .1), -r * 1.6, r * (x + .55), -r * 1.45)
      ..quadraticBezierTo(r * (x + .15), -r * 1.25, r * (x + .15), -r * .7)
      ..close();
    fillPath(c, horn, far ? const [Color(0xFFA8A090), Color(0xFF6A6458), Color(0xFF2A2620)] : const [Color(0xFFD8D0C0), Color(0xFF9A9080), Color(0xFF4A4438)], Offset(r * (x - .2), -r * 1.6), Offset(r * (x + .5), -r * .7));
  }
  final head = Path()
    ..moveTo(-r * .9, r * .6)
    ..quadraticBezierTo(-r * 1.05, -r * .95, r * .15, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.1, -r * .2)
    ..quadraticBezierTo(r * 1.25, r * .6, r * .7, r * 1.0)
    ..quadraticBezierTo(-r * .1, r * 1.25, -r * .9, r * .6)
    ..close();
  fillPath(c, head, fur, Offset(-r, -r), Offset(r, r));
  final face = Path()
    ..moveTo(r * .1, -r * .55)
    ..quadraticBezierTo(r * .95, -r * .65, r * 1.05, -r * .05)
    ..quadraticBezierTo(r * 1.1, r * .65, r * .55, r * .85)
    ..quadraticBezierTo(r * .05, r * .7, r * .05, r * .1)
    ..close();
  fillPath(c, face, ramp(0xFF5A7AA8, .2, .5), Offset(r * .1, -r * .6), Offset(r * 1.1, r * .8), width: 1.1);
  for (final (x0, len) in const [(.05, .5), (.35, .55), (.65, .45)]) {
    c.drawPath(poly([Offset(r * x0, -r * .6), Offset(r * (x0 + .15), -r * .85), Offset(r * (x0 + len), -r * .42), Offset(r * (x0 + .2), -r * .5)]), Paint()..color = fur[0]);
  }
  final glow = look.eyeGlow ?? const Color(0xFF9ADFFF), eye = Offset(r * .62, -r * .28);
  c.drawCircle(eye, r * .22, Paint()..color = glow.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  _ellipse(c, eye, r * .14, r * .1, Paint()..color = glow);
  _ellipse(c, Offset(r * 1.0, r * .08), r * .13, r * .09, Paint()..color = const Color(0xFF1A2230));
  c.drawPath(poly([Offset(r * 1.0, r * .42), Offset(r * .35, r * .45), Offset(r * .85, r * .68)]), Paint()..color = const Color(0xFF14101A));
  for (final x in const [.48, .9]) {
    c.drawPath(poly([Offset(r * x - 2.4, r * .43), Offset(r * x + .5, r * .15), Offset(r * x + 2.4, r * .44)]), Paint()..color = const Color(0xFFF2EEE0));
  }
}
