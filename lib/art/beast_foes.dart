// Beasts as foes on the battle stage: wolves, bears, giant spiders, unicorns and centaurs (a
// rider's upper half on a headless horse). Each faces the hero (left), rocks back when [hit], and
// slumps and fades when [dying].

import 'package:flutter/painting.dart';

import 'bats.dart';
import 'beasts.dart';
import 'body.dart';
import 'hounds.dart';
import 'looks.dart';
import 'poses.dart';

/// A desert jackal: lean, sand-coloured, with a dark back and amber eyes.
const _jackal = HoundLook(
  coat: [Color(0xFFE0BC84), Color(0xFFB08850), Color(0xFF4A3420)],
  belly: Color(0xFFF2DEB4),
  eye: Color(0xFFFFB84A),
);

const _alphaWolf = HoundLook(
  coat: [Color(0xFF8A8E98), Color(0xFF4A4E58), Color(0xFF16181E)],
  belly: Color(0xFFB8BCC4),
  eye: Color(0xFF9ADFFF),
  mane: Color(0xFFD8DCE4),
);

/// A Frostmarch snow wolf: white, with a pale blue back and ice-blue eyes.
const _snowWolf = HoundLook(
  coat: [Color(0xFFF4F6FA), Color(0xFFB8C8D8), Color(0xFF4A5A6E)],
  belly: Color(0xFFFFFFFF),
  eye: Color(0xFF7AD8FF),
  mane: Color(0xFFFFFFFF),
);

/// Scale and height (for health bars and aura) of each beast foe.
const _beasts = <String, (double scale, double height)>{
  'wolf': (1.55, 140),
  'jackal': (1.4, 128),
  'alphawolf': (2.3, 205),
  'snowwolf': (1.7, 150),
  'bear': (1.25, 150),
  'cavebear': (1.7, 205),
  'spider': (1.25, 120),
  'spiderqueen': (1.75, 175),
  'unicorn': (1.05, 205),
  'moonhorn': (1.3, 255),
  'centaur': (1.1, 230),
  'centaurchief': (1.25, 270),
  // The Hollowdeep's bats hover, so their height runs from the ground to the tips of their ears.
  'cavebat': (1.15, 195),
  'roostMother': (1.7, 290),
};

bool isBeastLook(String look) => _beasts.containsKey(look);
double beastHeight(String look) => _beasts[look]?.$2 ?? 150;

/// [look] drawn at [at] facing left. [rider] is the centaur's upper body (its own [Look]).
void drawBeastFoe(Canvas c, String look, Offset at, double t, {double hit = 0, double dying = 0, double alpha = 1, ColorFilter? tint, bool still = false, Look? rider}) {
  final scale = _beasts[look]?.$1 ?? 1;
  c.save();
  c.translate(at.dx + hit * 16, at.dy);
  c.scale(-1, 1); // face the hero
  c.rotate(-dying * .5);
  final layered = alpha < 1 || tint != null;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha)..colorFilter = tint);
  switch (look) {
    case 'wolf' || 'alphawolf' || 'jackal' || 'snowwolf':
      drawHound(c, switch (look) { 'wolf' => wolfLook, 'jackal' => _jackal, 'snowwolf' => _snowWolf, _ => _alphaWolf }, Offset.zero, scale, t, still: still);
    case 'bear' || 'cavebear':
      drawBear(c, look == 'bear' ? brownBear : caveBear, Offset.zero, scale, t, hit: hit, still: still);
    case 'spider' || 'spiderqueen':
      drawSpider(c, look == 'spider' ? giantSpider : spiderQueen, Offset.zero, scale, t, hit: hit, still: still);
    case 'cavebat' || 'roostMother':
      drawBat(c, look == 'cavebat' ? caveBat : roostMother, Offset.zero, scale, t, hit: hit, still: still);
    case 'unicorn' || 'moonhorn':
      drawHorse(c, look == 'unicorn' ? unicornLook : moonhornLook, Offset.zero, scale, t, still: still);
    case 'centaur' || 'centaurchief':
      drawHorse(c, look == 'centaur' ? centaurLook : centaurChiefLook, Offset.zero, scale, t, headless: true, still: still);
      if (rider != null) {
        // The rider's waist sits where the horse's neck would rise.
        final s = rider.scale * scale * .95;
        drawHumanoid(c, rider, idlePose(rider.stance, t, still: still), t, DrawOptions(at: Offset(44 * scale, -horseBack * scale - 2 + 98 * s), scale: s, legs: false, shadow: false), still: still);
      }
  }
  if (layered) c.restore();
  c.restore();
}
