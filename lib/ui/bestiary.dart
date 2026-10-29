// A dev page for checking the art: every foe, rare, companion and the knight in each armour, drawn
// large on a plain backdrop (no lighting) so stray lines and odd bits are easy to spot.
// Open http://localhost:5070/?bestiary (&from=N to skip ahead, &cols=N for a denser grid, &foes to
// skip the knights).

import 'package:flutter/material.dart';

import '../art/beast_foes.dart';
import '../art/body.dart';
import '../art/creatures.dart';
import '../art/hounds.dart';
import '../art/kraken.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/rare_looks.dart';
import '../art/rig.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/crafting.dart';
import '../game/models.dart';
import 'theme.dart';

class BestiaryPreview extends StatelessWidget {
  const BestiaryPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, void Function(Canvas, Size))>[];
    // The knight in every armour, hero and heroine.
    for (final female in Uri.base.queryParameters.containsKey('foes') ? const <bool>[] : [false, true]) {
      for (final t in tiersFor(HeroClass.knight)) {
        final look = lookFor(HeroClass.knight, Loadout.starter(HeroClass.knight)..armour = t.id, female: female);
        entries.add(('${female ? 'Heroine' : 'Hero'}: ${t.name}', (c, s) => _humanoid(c, s, look, flip: false)));
      }
    }
    // Every foe and boss.
    for (final f in foes) {
      entries.add((f.name, (c, s) => _foe(c, s, f)));
    }
    // Named rares.
    for (final land in continents) {
      for (final n in land.named) {
        final base = foeLooks[n.base];
        if (base == null) continue;
        final look = auraLook(base, n.aura, named: true);
        entries.add((n.name, (c, s) => _humanoid(c, s, look)));
      }
    }
    // The Hidden Ones, as you meet them (their cursed glow; the Prior as a named foe).
    // ?bestiary&hidden shows only them.
    final hidden = <(String, void Function(Canvas, Size))>[
      for (final MapEntry(key: look, value: rank) in hiddenRanks.entries)
        (rank.$1, (c, s) => _humanoid(c, s, auraLook(foeLooks[look]!, Aura.cursed, named: look == hiddenPrior))),
      for (final look in hiddenRanks.keys) ('${hiddenRanks[look]!.$1} (plain)', (c, s) => _humanoid(c, s, foeLooks[look]!)),
      // Golems, as you meet them and plain.
      for (final m in Metal.values) (m.golemName, (c, s) => _humanoid(c, s, auraLook(foeLooks[m.golemLook]!, m.aura))),
      for (final m in Metal.values) ('${m.golemName} (plain)', (c, s) => _humanoid(c, s, foeLooks[m.golemLook]!)),
    ];
    if (Uri.base.queryParameters.containsKey('hidden')) entries.clear();
    entries.addAll(hidden);
    if (Uri.base.queryParameters.containsKey('hidden')) return _grid(entries);
    // The Ashen Order, Ravenmoor and the Howling Weald, Sir Malric and you as the wolf.
    // ?bestiary&new shows only them.
    final fresh = <(String, void Function(Canvas, Size))>[
      ('Sir Malric the Ashen', (c, s) => _humanoid(c, s, auraLook(foeLooks[malricLook]!, Aura.blazing, named: true))),
      ('You, as the wolf', (c, s) => _humanoid(c, s, wolfformLook, flip: false)),
      for (final look in const ['ashenKnight', 'ashenChampion', 'malric', 'thrall', 'vampireSpawn', 'bloodBride', 'vampireKnight', 'countess', 'woodsman', 'werewolf', 'werewolfStalker', 'werewolfBrute', 'werewolfAlpha', 'elfRanger', 'elfBlade', 'elfWarden', 'elfDruid', 'elfQueen', 'dwarfAxe', 'dwarfShield', 'dwarfXbow', 'dwarfRune', 'dwarfThane', 'elementalEmber', 'elementalFrost', 'elementalMire', 'facelessWanderer', 'facelessMimic', 'facelessChoir', 'facelessWarden', 'facelessMother', 'lizardGuard', 'lizardSkirmisher', 'lizardShaman', 'lizardChampion', 'lizardKing', 'merrowRaider', 'merrowCaller', 'merrowGuard', 'drownedSailor', 'shifter', 'shifterSly', 'shifterHulk', 'thousandfold', 'harpy', 'aerieWarden', 'aerieSkyshot', 'aerieCaller', 'ronin', 'ashigaru', 'shinobi', 'onmyoji', 'oni', 'shogun', 'batkin', 'batkinCaller', 'batkinGuard'])
        (look, (c, s) => _humanoid(c, s, foeLooks[look]!)),
    ];
    fresh.addAll([for (final look in const ['seaSerpent', 'leviathan', 'kraken', 'griffin', 'stormRoc', 'cavebat', 'roostMother']) (look, (Canvas c, Size s) => _foe(c, s, FoeType(look, look)))]);
    if (Uri.base.queryParameters.containsKey('new')) return _grid(fresh);
    entries.addAll(fresh.take(2));
    // Companions.
    entries.add(('Wolf companion', (c, s) => _hound(c, s, wolfLook, 1.2)));
    entries.add(('Hellhound companion', (c, s) => _hound(c, s, hellhoundLook, 1.2)));

    // ?bestiary&pick=N shows just entry N, full screen.
    final pick = int.tryParse(Uri.base.queryParameters['pick'] ?? '');
    if (pick != null && pick >= 0 && pick < entries.length) {
      return Scaffold(
        backgroundColor: const Color(0xFF6E737A),
        body: Column(
          children: [
            Expanded(child: CustomPaint(painter: _Tile(entries[pick].$2), size: Size.infinite)),
            Text(entries[pick].$1, style: Txt.label(size: 16, color: Palette.cream)),
          ],
        ),
      );
    }
    return _grid(entries);
  }

  Widget _grid(List<(String, void Function(Canvas, Size))> entries) {
    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: GridView.count(
        crossAxisCount: int.tryParse(Uri.base.queryParameters['cols'] ?? '') ?? 3,
        padding: const EdgeInsets.all(6),
        childAspectRatio: .8,
        children: [
          for (final (name, paint) in entries.skip(int.tryParse(Uri.base.queryParameters['from'] ?? '') ?? 0))
            Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A8F96), Color(0xFF5E636A)])),
                    child: CustomPaint(painter: _Tile(paint), size: Size.infinite),
                  ),
                ),
                Text(name, style: Txt.label(size: 12, color: Palette.cream), overflow: TextOverflow.ellipsis),
              ],
            ),
        ],
      ),
    );
  }
}

class _Tile extends CustomPainter {
  _Tile(this.draw);
  final void Function(Canvas, Size) draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    draw(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Tile old) => false;
}

/// Scales so a figure of height [h] (at its own scale) fills the tile, feet at the bottom.
void _fit(Canvas c, Size s, double h, {double width = 0}) {
  final k = s.height * .82 / h;
  final kw = width > 0 ? s.width * .9 / width : k;
  c.translate(s.width / 2, s.height * .94);
  c.scale(k < kw ? k : kw);
}

void _humanoid(Canvas c, Size s, Look look, {bool flip = true}) {
  final scale = look.scale * 1.1;
  _fit(c, s, builds[look.build]!.height * scale * 1.15);
  drawHumanoid(c, look, idlePose(look.stance, 0, still: true), 0, DrawOptions(at: Offset.zero, scale: scale, flip: flip), still: true);
}

void _hound(Canvas c, Size s, HoundLook look, double scale) {
  _fit(c, s, 92 * scale * 1.2, width: 200 * scale);
  c.scale(-1, 1);
  drawHound(c, look, Offset.zero, scale, 0, still: true);
}

void _foe(Canvas c, Size s, FoeType f) {
  if (f.dragon) {
    final look = dragonLookOf(f);
    _fit(c, s, dragonHeight * .78 * look.scale * 1.2, width: 330 * .78 * look.scale);
    drawFoeDragon(c, look, Offset.zero, .78, 0, still: true);
  } else if (f.hound) {
    _fit(c, s, 92 * 2.5 * 1.2, width: 200 * 2.5);
    c.scale(-1, 1);
    drawHound(c, demonHoundLook, Offset.zero, 2.5, 0, still: true);
  } else if (isSeaLook(f.look)) {
    _fit(c, s, seaHeight(f.look) * .82 * 1.1, width: 420 * .82);
    drawSeaBeast(c, f.look, Offset.zero, .82, 0, still: true);
  } else if (isBeastLook(f.look)) {
    _fit(c, s, beastHeight(f.look) * 1.15, width: beastHeight(f.look) * (f.look.startsWith('spider') ? 2.6 : 1.6));
    drawBeastFoe(c, f.look, Offset.zero, 0, still: true, rider: f.look.startsWith('centaur') ? foeLookOf(f) : null);
  } else {
    _humanoid(c, s, foeLookOf(f));
  }
}
