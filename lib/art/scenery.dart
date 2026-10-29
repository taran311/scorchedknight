// Painted backdrops for each realm and the Inn at night. Each is recorded once into a picture
// at 960 x 540 and scaled to fit, so redrawing it every frame is cheap.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

const sceneSize = Size(960, 540);

class RealmTheme {
  const RealmTheme({
    required this.sky,
    required this.glow,
    required this.mountains,
    required this.ridge,
    required this.castle,
    required this.hill,
    required this.trees,
    required this.ground,
    required this.road,
    required this.grass,
    required this.mote,
    required this.haze,
    required this.mist,
  });
  final List<Color> sky, ground, road;
  final Color glow, mountains, ridge, castle, hill, trees, grass, mote, haze, mist;
}

const realmThemes = <RealmTheme>[
  RealmTheme(
    sky: [Color(0xFF2A3640), Color(0xFF56686F), Color(0xFFA3A48A), Color(0xFFCDBB8C)],
    glow: Color(0xFFF2D9A2),
    mountains: Color(0xFF46525A),
    ridge: Color(0xFF36413F),
    castle: Color(0xFF2F3940),
    hill: Color(0xFF34402F),
    trees: Color(0xFF1C2619),
    ground: [Color(0xFF4A5634), Color(0xFF262E1A)],
    road: [Color(0xFF8A7454), Color(0xFF5A4732)],
    grass: Color(0xFF151D12),
    mote: Color(0x8CFFF6D8),
    haze: Color(0x66E8E2D2),
    mist: Color(0x21FFFFFF),
  ),
  RealmTheme(
    sky: [Color(0xFF1E1416), Color(0xFF4E2A22), Color(0xFF9E5434), Color(0xFFD48A4E)],
    glow: Color(0xFFFFBF7A),
    mountains: Color(0xFF3E2C2A),
    ridge: Color(0xFF2F2222),
    castle: Color(0xFF251B1B),
    hill: Color(0xFF2E2420),
    trees: Color(0xFF160F0E),
    ground: [Color(0xFF40342C), Color(0xFF1E1814)],
    road: [Color(0xFF6E5848), Color(0xFF3E3126)],
    grass: Color(0xFF130E0C),
    mote: Color(0xCCFF9646),
    haze: Color(0x803A1E1A),
    mist: Color(0x21C46A3A),
  ),
  // The Orkmarch: dusty badlands under a smoky green-gold sky, war-camp fires on the ridge.
  RealmTheme(
    sky: [Color(0xFF1C2018), Color(0xFF3E4A2C), Color(0xFF8A8A4A), Color(0xFFC8A860)],
    glow: Color(0xFFE8C870),
    mountains: Color(0xFF3A3A2A),
    ridge: Color(0xFF2C2C20),
    castle: Color(0xFF22221A),
    hill: Color(0xFF34301E),
    trees: Color(0xFF16160E),
    ground: [Color(0xFF5A4E30), Color(0xFF2A2416)],
    road: [Color(0xFF7A6646), Color(0xFF463A28)],
    grass: Color(0xFF1A1A10),
    mote: Color(0x99E8D08A),
    haze: Color(0x66504A2A),
    mist: Color(0x21D8C88A),
  ),
  // The Wyrmspine Peaks: jagged violet mountains above a lava-lit pass.
  RealmTheme(
    sky: [Color(0xFF0E0A18), Color(0xFF2A1A3A), Color(0xFF6A2A3A), Color(0xFFC0583A)],
    glow: Color(0xFFFF8A4A),
    mountains: Color(0xFF2A2234),
    ridge: Color(0xFF1E1826),
    castle: Color(0xFF16101C),
    hill: Color(0xFF241C24),
    trees: Color(0xFF0E0A0E),
    ground: [Color(0xFF3A2E30), Color(0xFF161012)],
    road: [Color(0xFF5E4A44), Color(0xFF2E2420)],
    grass: Color(0xFF0E0A0A),
    mote: Color(0xCCFF7A3A),
    haze: Color(0x80301A2A),
    mist: Color(0x21FF6A3A),
  ),
];

final Map<int, ui.Picture> _cache = {};
ui.Picture realmBackdrop(int realm) => _cache.putIfAbsent(realm, () => _record((c) => _paintRealm(c, realm)));
final Map<bool, ui.Picture> _inn = {};

/// The Soot & Kettle: smouldering and holed until Hob's job is done, patched up after.
ui.Picture innBackdrop({bool repaired = true}) => _inn.putIfAbsent(repaired, () => _record((c) => _paintInn(c, repaired)));

ui.Picture _record(void Function(Canvas) paint) {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec, Offset.zero & sceneSize));
  return rec.endRecording();
}

Paint _vertical(List<Color> cs, double top, double bottom) =>
    Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), cs, List.generate(cs.length, (i) => i / (cs.length - 1)));

Paint _glow(Offset centre, double radius, Color colour, List<double> alphas, List<double> stops) =>
    Paint()..shader = ui.Gradient.radial(centre, radius, [for (final a in alphas) colour.withValues(alpha: a)], stops);

void _paintRealm(Canvas c, int realm) {
  final th = realmThemes[realm], r = SeededRandom(const [31, 77, 19, 53][realm % 4]);
  c.drawRect(Offset.zero & sceneSize, _vertical(th.sky, 0, 540));
  final sun = realm == 1 ? const Offset(250, 300) : const Offset(300, 270);
  c.drawCircle(sun, 300, _glow(sun, 300, th.glow, const [.9, .5, 0], const [0, .2, 1]));
  c.drawCircle(sun, realm == 1 ? 34 : 26, Paint()..color = th.glow.withValues(alpha: .85));
  final haze = Paint()
    ..color = th.haze
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  c.drawOval(Rect.fromCenter(center: const Offset(160, 110), width: 280, height: 36), haze);
  c.drawOval(Rect.fromCenter(center: const Offset(620, 70), width: 360, height: 44), haze);

  final far = Path()..moveTo(0, 330), ridge = Path()..moveTo(0, 340), hill = Path()..moveTo(0, 368);
  for (var x = 0.0; x <= 960; x += 16) {
    far.lineTo(x, 300 - 70 * math.sin(x / 140 + 1).abs() - 30 * math.sin(x / 53) - 12 * r.next());
    ridge.lineTo(x, 326 - 36 * math.sin(x / 90 + 2).abs() - 10 * math.sin(x / 31));
    hill.lineTo(x, 356 - 14 * math.sin(x / 120 + .5) - 6 * math.sin(x / 41));
  }
  for (final p in [far, ridge, hill]) {
    p
      ..lineTo(960, 540)
      ..lineTo(0, 540)
      ..close();
  }
  c.drawPath(far, Paint()..color = th.mountains.withValues(alpha: .9));
  final castle = Paint()..color = th.castle;
  if (realm == 0) {
    for (final d in const [
      'M690,268 L690,236 L698,236 L698,230 L704,230 L704,236 L712,236 L712,230 L718,230 L718,236 L726,236 L726,268 Z',
      'M726,268 L726,248 L800,248 L800,268 Z',
      'M736,248 L736,214 L760,214 L760,248 Z',
      'M732,214 L748,186 L764,214 Z',
      'M786,248 L786,226 L804,226 L804,268 L786,268 Z',
      'M783,226 L795,206 L807,226 Z',
      'M660,290 Q720,258 840,282 L840,300 L660,300 Z',
    ]) {
      c.drawPath(svgPath(d), castle);
    }
    final lit = Paint()..color = const Color(0xCCFFCF7A);
    c.drawRect(const Rect.fromLTWH(746, 224, 3, 5), lit);
    c.drawRect(const Rect.fromLTWH(706, 246, 3, 5), lit);
  } else {
    for (final d in const [
      'M720,282 L724,214 L732,206 L738,216 L744,200 L752,212 L756,282 Z',
      'M700,292 Q740,270 800,290 L800,300 L700,300 Z',
      'M770,284 L772,250 L780,258 L786,246 L788,284 Z',
    ]) {
      c.drawPath(svgPath(d), castle);
    }
  }
  c.drawPath(ridge, Paint()..color = th.ridge);
  c.drawRect(
    const Rect.fromLTWH(-200, 300, 1360, 70),
    Paint()
      ..color = th.mist
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );
  c.drawPath(hill, Paint()..color = th.hill);

  final trees = Path();
  for (var x = -10.0; x < 980; x += 10 + r.next() * 16) {
    final h = 34 + r.next() * 56, w = 9 + r.next() * 7, y = 372 - 10 * math.sin(x / 120 + .5);
    if (realm == 0) {
      trees.addPolygon([
        Offset(x - w, y),
        Offset(x - w * .55, y - h * .45),
        Offset(x - w * .8, y - h * .45),
        Offset(x, y - h),
        Offset(x + w * .8, y - h * .45),
        Offset(x + w * .55, y - h * .45),
        Offset(x + w, y),
      ], true);
    } else if (r.next() < .55) {
      trees
        ..moveTo(x, y)
        ..lineTo(x, y - h)
        ..moveTo(x, y - h * .6)
        ..lineTo(x - w, y - h * .8)
        ..moveTo(x, y - h * .45)
        ..lineTo(x + w, y - h * .7);
    }
  }
  if (realm == 0) {
    c.drawPath(trees, Paint()..color = th.trees);
  } else {
    c.drawPath(trees, strokePaint(th.trees, 3));
    final scrub = Path()..moveTo(0, 372);
    for (var i = 0; i < 49; i++) {
      scrub.lineTo(i * 20.0, 366 - 6 * math.sin(i.toDouble()));
    }
    scrub
      ..lineTo(960, 380)
      ..lineTo(0, 380)
      ..close();
    c.drawPath(scrub, Paint()..color = th.trees);
  }

  c.drawRect(const Rect.fromLTWH(0, 372, 960, 168), _vertical(th.ground, 372, 540));
  final road = svgPath('M0,418 C160,412 300,424 480,416 C660,408 800,420 960,414 L960,488 C800,494 640,482 480,490 C320,498 160,486 0,492 Z');
  c.drawPath(road, _vertical(th.road, 410, 495));
  c.drawPath(svgPath('M0,418 C160,412 300,424 480,416 C660,408 800,420 960,414'), strokePaint(const Color(0x40000000), 3));
  final stone = Paint()..color = const Color(0x33000000);
  for (var i = 0; i < 14; i++) {
    final x = r.next() * 960, y = 432 + r.next() * 50, w = 4 + r.next() * 8;
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w * 2, height: w * .9), stone);
  }
  final grass = Path();
  for (var x = 0.0; x < 960; x += 6 + r.next() * 10) {
    final y = 508 + r.next() * 30, h = 10 + r.next() * 16;
    final cx = x + 2 + r.next() * 4, ex = x + r.next() * 8 - 2;
    grass
      ..moveTo(x, y)
      ..quadraticBezierTo(cx, y - h * .6, ex, y - h);
  }
  c.drawPath(grass, strokePaint(th.grass, 2.4));
}

void _paintInn(Canvas c, bool repaired) {
  c.drawRect(Offset.zero & sceneSize, _vertical(const [Color(0xFF070A16), Color(0xFF141D36), Color(0xFF2A3350)], 0, 540));
  final r = SeededRandom(9);
  for (var i = 0; i < 46; i++) {
    final x = r.next() * 960, y = r.next() * 230, rad = r.next() * 1.4 + .4, a = r.next() * .6 + .3;
    c.drawCircle(Offset(x, y), rad, Paint()..color = const Color(0xFFF4ECD8).withValues(alpha: a));
  }
  const moon = Offset(790, 96);
  c.drawCircle(moon, 120, _glow(moon, 120, const Color(0xFFF4E6B8), const [.9, .25, 0], const [0, .3, 1]));
  c.drawCircle(moon, 30, Paint()..color = const Color(0xFFF8EFCF));
  c.drawPath(svgPath('M0,380 C200,350 400,372 600,352 C760,338 880,356 960,348 L960,540 L0,540 Z'), Paint()..color = const Color(0xFF151C1A));
  c.drawRect(const Rect.fromLTWH(0, 410, 960, 130), _vertical(const [Color(0xFF1D2419), Color(0xFF0B0E0A)], 410, 540));
  c.drawPath(svgPath('M0,470 C200,462 330,470 470,456 L620,456 C700,462 820,470 960,466 L960,500 L0,510 Z'), Paint()..color = const Color(0xFF2E2A22));
  const ink = Color(0xFF120E0B), beam = Color(0xFF2A1A10);
  c.drawRect(const Rect.fromLTWH(460, 232, 320, 226), _vertical(const [Color(0xFFB9A684), Color(0xFF7C6A50)], 232, 458));
  c.drawRect(const Rect.fromLTWH(460, 232, 320, 226), strokePaint(ink, 3));
  c.drawPath(
    svgPath('M460,232 L780,232 M460,344 L780,344 M520,232 L520,458 M720,232 L720,458 M460,232 L520,344 M520,232 L460,344 M720,232 L780,344 M780,232 L720,344'),
    strokePaint(beam, 7)..strokeCap = StrokeCap.butt,
  );
  final roof = svgPath('M440,236 L620,120 L800,236 Z');
  c.drawPath(roof, _vertical(const [Color(0xFF4A2E26), Color(0xFF22140F)], 120, 236));
  c.drawPath(roof, strokePaint(ink, 3));
  c.drawPath(svgPath('M470,216 L770,216 M500,196 L740,196 M530,176 L710,176 M560,156 L680,156'), strokePaint(const Color(0x59000000), 2));
  c.drawRect(const Rect.fromLTWH(700, 128, 30, 70), Paint()..color = const Color(0xFF3A2A20));
  c.drawRect(const Rect.fromLTWH(700, 128, 30, 70), strokePaint(ink, 3));
  for (final w in const [Offset(555, 290), Offset(685, 290)]) {
    c.drawCircle(w, 70, _glow(w, 70, const Color(0xFFFFB04A), const [.9, .35, 0], const [0, .5, 1]));
    final rect = Rect.fromCenter(center: w, width: 40, height: 44);
    c.drawRect(rect, Paint()..color = const Color(0xFFFFCF7A));
    c.drawRect(rect, strokePaint(beam, 5)..strokeCap = StrokeCap.butt);
    c.drawLine(Offset(w.dx, rect.top), Offset(w.dx, rect.bottom), strokePaint(beam, 3));
    c.drawLine(Offset(rect.left, w.dy), Offset(rect.right, w.dy), strokePaint(beam, 3));
  }
  final door = RRect.fromRectAndRadius(const Rect.fromLTWH(596, 372, 48, 86), const Radius.circular(3));
  c.drawRRect(door, Paint()..color = beam);
  c.drawRRect(door, strokePaint(ink, 3));
  c.drawPath(svgPath('M420,300 L420,246 L470,246'), strokePaint(beam, 5));
  c.drawRect(const Rect.fromLTWH(422, 256, 44, 40), Paint()..color = const Color(0xFF5E3D22));
  c.drawRect(const Rect.fromLTWH(422, 256, 44, 40), strokePaint(ink, 2));
  c.drawPath(svgPath('M432,268 L452,268 L450,288 L434,288 Z M452,272 Q462,276 452,284'), strokePaint(const Color(0xFFE8C96F), 2.5));
  if (repaired) {
    _innPatched(c);
  } else {
    _innScorched(c);
  }
}

const _char = Color(0xFF0E0907);

/// The inn after the Burning: soot up the walls, a hole burnt through the roof with charred
/// rafters and a glowing edge, a boarded window and a broken one, fallen beams and rubble.
void _innScorched(Canvas c) {
  // Soot climbing the walls from the burnt roof, and plumes above the windows.
  c.drawRect(const Rect.fromLTWH(460, 232, 320, 226), _vertical(const [Color(0xB3100A08), Color(0x59100A08), Color(0x26100A08)], 232, 458));
  for (final x in const [555.0, 685.0]) {
    c.drawPath(
      svgPath('M${x - 22},270 Q${x - 26},240 ${x - 8},234 Q$x,250 ${x + 10},234 Q${x + 28},244 ${x + 22},270 Z'),
      Paint()
        ..color = const Color(0xCC0E0907)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
  // Charred roof, and the hole burnt through it.
  c.drawPath(svgPath('M440,236 L620,120 L800,236 Z'), Paint()..color = const Color(0x8C0E0907));
  final hole = svgPath('M500,214 L528,170 L560,160 L590,176 L604,204 L582,226 L540,232 L512,228 Z');
  c.drawPath(hole, Paint()..color = _char);
  c.drawPath(
    svgPath('M512,226 L540,172 M540,230 L568,164 M566,228 L590,178 M500,200 L600,196'),
    strokePaint(const Color(0xFF2A1A12), 5)..strokeCap = StrokeCap.butt,
  );
  c.drawPath(hole, strokePaint(const Color(0xFFE0582A), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  c.drawPath(hole, strokePaint(const Color(0xFFFFB04A), 1.2));
  final small = svgPath('M664,182 L684,172 L700,190 L682,204 L666,198 Z');
  c.drawPath(small, Paint()..color = _char);
  c.drawPath(small, strokePaint(const Color(0xFFE0582A), 2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  // The left window boarded up; the right one broken, a dim glow behind.
  for (final (dy, tilt) in const [(-10.0, -4.0), (4.0, 3.0), (14.0, -2.0)]) {
    c.drawPath(svgPath('M528,${290 + dy - tilt} L582,${290 + dy + tilt} L582,${296 + dy + tilt} L528,${296 + dy - tilt} Z'), Paint()..color = const Color(0xFF4A3220));
    c.drawPath(svgPath('M528,${290 + dy - tilt} L582,${290 + dy + tilt} L582,${296 + dy + tilt} L528,${296 + dy - tilt} Z'), strokePaint(_char, 1.5));
  }
  c.drawRect(const Rect.fromLTWH(665, 268, 40, 44), Paint()..color = const Color(0xCC1A0E08));
  c.drawPath(svgPath('M665,268 L680,286 L672,300 L686,312 M705,268 L692,284 L700,296'), strokePaint(const Color(0x99D8C8A0), 1.2));
  // A beam come down from the roof, leaning on the wall, and rubble at its foot.
  c.drawPath(svgPath('M772,250 L800,246 L846,452 L818,456 Z'), Paint()..color = const Color(0xFF1E140E));
  c.drawPath(svgPath('M772,250 L800,246 L846,452 L818,456 Z'), strokePaint(_char, 2));
  for (final (x, y, r) in const [(800.0, 452.0, 14.0), (826.0, 456.0, 10.0), (782.0, 456.0, 9.0), (848.0, 458.0, 8.0)]) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 2.4, height: r * 1.4), Paint()..color = const Color(0xFF241A14));
  }
  _ruinSilhouette(c);
  // A modest, readable pile of salvage: what Hob needs for the roof repairs.
  _repairSupplies(c, collected: false);
  // Scorch on the sign.
  c.drawRect(const Rect.fromLTWH(422, 256, 44, 18), Paint()..color = const Color(0x8C0E0907));
}

/// The inn patched up: fresh planks over the hole in the roof, a new beam, the boards off the
/// window, and only a little old soot left.
void _innPatched(Canvas c) {
  c.drawRect(const Rect.fromLTWH(460, 232, 320, 60), _vertical(const [Color(0x40100A08), Color(0x00100A08)], 232, 292));
  final patch = svgPath('M504,212 L530,172 L592,172 L604,206 L580,226 L512,226 Z');
  c.drawPath(patch, _vertical(const [Color(0xFFB08A5A), Color(0xFF7A5A36)], 172, 226));
  for (var x = 516.0; x < 600; x += 14) {
    c.drawLine(Offset(x, 176), Offset(x - 6, 224), strokePaint(const Color(0x66000000), 1.4));
  }
  c.drawPath(patch, strokePaint(const Color(0xFF120E0B), 2));
  for (final p in const [Offset(520, 186), Offset(586, 186), Offset(522, 216), Offset(584, 216)]) {
    c.drawCircle(p, 1.6, Paint()..color = const Color(0xFF3A3A3A));
  }
  c.drawLine(const Offset(462, 346), const Offset(778, 346), strokePaint(const Color(0xFF8A6238), 4));
  _repairedSilhouette(c);
  _repairSupplies(c, collected: true);
}

/// Large-scale burnt roof silhouette and collapsing beams; cached in the inn picture.
void _ruinSilhouette(Canvas c) {
  const charcoal=Color(0xFF120D0C);
  // A missing central roof section with broken, upward-pointing rafters.
  final jagged=svgPath('M438,238 L487,201 L501,185 L512,208 L539,174 L552,204 L577,153 L592,187 L621,167 L650,200 L672,177 L690,205 L725,181 L758,212 L803,237 L770,235 L736,218 L702,225 L674,211 L643,224 L605,209 L577,231 L544,215 L517,239 L485,227 Z');
  c.drawPath(jagged,Paint()..color=charcoal);
  c.drawPath(jagged,strokePaint(const Color(0xFF4A241B),3));
  for(final (x,y,dx) in const [(505.0,183.0,-21.0),(577.0,154.0,24.0),(672.0,177.0,-16.0),(725.0,181.0,18.0)]) {
    c.drawLine(Offset(x,y),Offset(x+dx,y-35),strokePaint(const Color(0xFF201612),8));
    c.drawLine(Offset(x-2,y),Offset(x+dx-2,y-35),strokePaint(const Color(0xFF7E432A),1.7));
  }
  // Blackened facade, broken timbers and orange embers near the foundation.
  for(final (x,y) in const [(476.0,327.0),(758.0,333.0),(527.0,421.0),(710.0,418.0)]) {
    c.drawLine(Offset(x,y-24),Offset(x+7,y+30),strokePaint(const Color(0xBB140E0C),13));
    c.drawLine(Offset(x+2,y-19),Offset(x+5,y+20),strokePaint(const Color(0x996F3922),1.5));
  }
  for(final (x,y,r) in const [(476.0,459.0,19.0),(508.0,465.0,12.0),(748.0,461.0,18.0),(789.0,466.0,14.0),(836.0,473.0,11.0)]) {
    c.drawOval(Rect.fromCenter(center:Offset(x,y),width:r*2.3,height:r),Paint()..color=const Color(0xFF211815));
    c.drawLine(Offset(x-r*.5,y),Offset(x+r*.2,y-2),strokePaint(const Color(0xFFCA5D28),1.7));
  }
}

/// The restored inn feels inhabited: new roof, glowing lanterns, balcony and flower boxes.
void _repairedSilhouette(Canvas c) {
  const timber=Color(0xFF82552E);
  final roof=svgPath('M436,236 L620,113 L805,236 L782,242 L620,138 L459,244 Z');
  fillPath(c,roof,[const Color(0xFFD4A36A),timber,const Color(0xFF302018)],const Offset(620,113),const Offset(620,242),width:3);
  for(var i=0;i<10;i++) {
    final x=477.0+i*30;
    c.drawLine(Offset(x,222-(1-(x-620).abs()/190)*73),Offset(x+16,230-(1-(x-620).abs()/190)*72),strokePaint(const Color(0xAA372217),2));
  }
  // Warm awning and small hanging lanterns.
  final awning=svgPath('M515,321 L731,321 L746,351 L503,351 Z');
  fillPath(c,awning,[const Color(0xFFB84932),const Color(0xFF762A24),const Color(0xFF321B1A)],const Offset(600,320),const Offset(600,354));
  for(final x in const [528.0,712.0]) {
    c.drawLine(Offset(x,351),Offset(x,366),strokePaint(const Color(0xFF24180F),2));
    c.drawCircle(Offset(x,372),13,_glow(Offset(x,372),13,const Color(0xFFFFB04A),const [.8,.3,0],const [0,.5,1]));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(x,372),width:12,height:19),const Radius.circular(3)),Paint()..color=const Color(0xFFFFD17D));
    c.drawRect(Rect.fromCenter(center:Offset(x,372),width:12,height:19),strokePaint(const Color(0xFF34231A),2));
  }
  for(final x in const [554.0,685.0]) {
    c.drawRect(Rect.fromLTWH(x-24,316,48,10),Paint()..color=timber);
    for(var k=0;k<5;k++) c.drawCircle(Offset(x-18+k*9,315-(k%2)*4),4,Paint()..color=const Color(0xFF638047));
  }
}

/// Salvage changes from scattered burnt beams to a tidy stack of spare timber.
/// Drawn at the edge of the stage so the hero and Hob remain unobstructed.
void _repairSupplies(Canvas c, {required bool collected}) {
  const dark = Color(0xFF211710), wood = Color(0xFF765037);
  final y = collected ? 475.0 : 478.0;
  c.drawOval(Rect.fromCenter(center: Offset(330, y + 9), width: 170, height: 16), Paint()..color = const Color(0x66000000));
  for (var i = 0; i < (collected ? 4 : 3); i++) {
    final left = 260.0 + (i.isEven ? 0 : 9), top = y - i * 10;
    final beam = Path()..moveTo(left, top)..lineTo(left + 125, top - (collected ? 0 : 8))
      ..lineTo(left + 129, top + 8 - (collected ? 0 : 8))..lineTo(left + 3, top + 10)..close();
    c.drawPath(beam, Paint()..color = collected ? wood : const Color(0xFF38251D));
    c.drawPath(beam, strokePaint(dark, 2));
    c.drawLine(Offset(left + 12, top + 3), Offset(left + 110, top + (collected ? 3 : -3)), strokePaint(collected ? const Color(0xFFB08B5E) : const Color(0xFF6B3B28), 1.3));
  }
  if (!collected) {
    for (final (x, y) in const [(245.0, 478.0), (400.0, 489.0), (424.0, 480.0)]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 15, height: 7), Paint()..color = const Color(0xFF534B43));
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 15, height: 7), strokePaint(dark, 1.4));
    }
  } else {
    // Two little metal bands make the finished stack look ready for building.
    for (final x in const [287.0, 364.0]) {
      c.drawLine(Offset(x, 439), Offset(x + 4, 483), strokePaint(const Color(0xFF8D9699), 3));
    }
  }
}

/// The parts of the Inn scene that change over time: chimney smoke and the light through the door.
void paintInnLights(Canvas c, double t, double doorLight, {bool repaired = true}) {
  final drift = math.sin(t / 700) * 6, rise = -((t / 40) % 30);
  if (!repaired) {
    // Smoke still pouring from the hole in the roof, embers glowing at its edge, sparks rising.
    for (var i = 0; i < 6; i++) {
      final p = ((t / 3200) + i / 6) % 1.0;
      final at = Offset(552 + math.sin(t / 900 + i) * 10 + p * 30, 196 - p * 190);
      c.drawCircle(at, 12 + p * 30, Paint()..color = Color.fromRGBO(70, 64, 62, .55 * (1 - p)));
    }
    for (final (i, e) in const [Offset(510, 212), Offset(560, 162), Offset(600, 200), Offset(684, 176)].indexed) {
      final k = .5 + .5 * math.sin(t / 260 + i * 1.9);
      c.drawCircle(e, 10, Paint()..color = Color.fromRGBO(255, 110, 40, .35 * k)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    for (var i = 0; i < 8; i++) {
      final p = ((t / 2200) + i * .137) % 1.0;
      c.drawCircle(Offset(520 + (i * 37) % 80 + math.sin(t / 300 + i) * 6, 200 - p * 140), 1.6, Paint()..color = Color.fromRGBO(255, 170, 70, 1 - p));
    }
  }
  final smoke = Paint()..color = const Color(0x599AA2B2);
  for (final (x, y, rad) in const [(716.0, 112.0, 12.0), (726.0, 88.0, 16.0), (712.0, 60.0, 20.0)]) {
    c.drawCircle(Offset(x + drift, y + rise), rad, smoke);
  }
  if (doorLight > 0) {
    c.drawRect(const Rect.fromLTWH(600, 376, 40, 82), Paint()..color = const Color(0xFFFFD98A).withValues(alpha: doorLight));
    c.drawCircle(
      const Offset(620, 440),
      120,
      _glow(const Offset(620, 440), 120, const Color(0xFFFFB04A), [.9 * doorLight, .35 * doorLight, 0], const [0, .5, 1]),
    );
  }
}
