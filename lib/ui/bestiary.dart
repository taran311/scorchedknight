// A dev page for checking the art: every foe, rare, companion and the knight in each armour, drawn
// large on a plain backdrop (no lighting) so stray lines and odd bits are easy to spot.
// Open http://localhost:5070/?bestiary (&from=N to skip ahead, &cols=N for a denser grid, &foes to
// skip the knights).

import 'battle_screen.dart' show BraceRing;
import 'dart:math' as math;

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
import '../game/arena.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/crafting.dart';
import '../game/hall.dart';
import '../game/loot.dart';
import '../game/models.dart';
import 'theme.dart';

class BestiaryPreview extends StatelessWidget {
  const BestiaryPreview({super.key});

  /// ?bestiary&check: every foe whose art and the way it attacks disagree (a bow but a melee
  /// lunge, a caster with a sword...), as a list.
  Widget _check() {
    final out = <String>[];
    final seen = <String>{};
    for (final (i, land) in continents.indexed) {
      for (final f in [...land.foes, land.boss]) {
        if (!seen.add('${f.look}|${f.name}')) continue;
        final look = foeLooks[f.look];
        if (look == null) continue;
        final w = look.weapon;
        final shoots = w.isBow || w.isThrown || w.isGun || w == Weapon.crossbow || w == Weapon.handcrossbow;
        final casts = w.isStaff || const {Weapon.wand, Weapon.orb, Weapon.tome, Weapon.sceptre, Weapon.crystalstaff}.contains(w);
        final issues = <String>[
          if (shoots && f.strike != Strike.arrow) 'holds a ${w.name} but attacks ${f.strike.name}',
          if (f.strike == Strike.arrow && !shoots) 'shoots arrows holding ${w.name}',
          if (f.strike == Strike.magic && !casts && w != Weapon.none) 'casts holding ${w.name}',
          if (f.kind == FoeKind.ranged && f.strike != Strike.arrow) 'archer kind, ${f.strike.name} attack',
          if (f.kind == FoeKind.caster && f.strike != Strike.magic && f.strike != Strike.fire) 'caster kind, ${f.strike.name} attack',
          if (casts && f.strike == Strike.melee && f.kind != FoeKind.caster) 'staff/wand but melee (${f.kind.name})',
        ];
        if (issues.isNotEmpty) out.add('$i ${land.name} · ${f.name} [${f.look}]: ${issues.join('; ')}');
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: ListView(padding: const EdgeInsets.all(12), children: [for (final l in out.isEmpty ? ['All consistent'] : out) SelectableText(l, style: const TextStyle(color: Colors.white, fontSize: 13))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Uri.base.queryParameters.containsKey('check')) return _check();
    // ?bestiary&brace: the brace ring on its own, over and over, with how each tap counted.
    if (Uri.base.queryParameters.containsKey('brace')) return const _BraceDemo();
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
      for (final look in const ['ashenKnight', 'ashenChampion', 'malric', 'thrall', 'vampireSpawn', 'bloodBride', 'vampireKnight', 'countess', 'woodsman', 'werewolf', 'werewolfStalker', 'werewolfBrute', 'werewolfAlpha', 'elfRanger', 'elfBlade', 'elfWarden', 'elfDruid', 'elfQueen', 'dwarfAxe', 'dwarfShield', 'dwarfXbow', 'dwarfRune', 'dwarfThane', 'elementalEmber', 'elementalFrost', 'elementalMire', 'facelessWanderer', 'facelessMimic', 'facelessChoir', 'facelessWarden', 'facelessMother', 'lizardGuard', 'lizardSkirmisher', 'lizardShaman', 'lizardChampion', 'lizardKing', 'merrowRaider', 'merrowCaller', 'merrowGuard', 'drownedSailor', 'shifter', 'shifterSly', 'shifterHulk', 'thousandfold', 'harpy', 'aerieWarden', 'aerieSkyshot', 'aerieCaller', 'ronin', 'ashigaru', 'shinobi', 'onmyoji', 'oni', 'shogun', 'batkin', 'batkinCaller', 'batkinGuard', 'frostReaver', 'frostSkald', 'frostGiant', 'iceWraith', 'yeti', 'frostJarl'])
        (look, (c, s) => _humanoid(c, s, foeLooks[look]!)),
    ];
    fresh.addAll([for (final look in const ['seaSerpent', 'leviathan', 'kraken', 'griffin', 'stormRoc', 'cavebat', 'roostMother', 'snowwolf']) (look, (Canvas c, Size s) => _foe(c, s, FoeType(look, look)))]);
    if (Uri.base.queryParameters.containsKey('new')) return _grid(fresh);
    // ?bestiary&hall: the Hall of the Slain's warriors, as you meet them and plain.
    if (Uri.base.queryParameters.containsKey('hall')) {
      final seen = <String>{};
      return _grid([
        for (final w in hallWaves)
          for (final e in w.warriors)
            if (seen.add(e.look)) (e.name, (Canvas c, Size s) => _humanoid(c, s, auraLook(foeLooks[e.look]!, Aura.ancient, named: true))),
        for (final look in seen) ('$look (plain)', (Canvas c, Size s) => _humanoid(c, s, foeLooks[look]!)),
      ]);
    }
    // ?bestiary&arena: the Ash Colosseum's gladiators, and a knight in the Champion's set.
    if (Uri.base.queryParameters.containsKey('arena')) {
      final loot = LootTable(math.Random(1));
      Loadout kit({bool full = true}) {
        final l = Loadout.starter(HeroClass.knight)..armour = full ? setArmourId('arena') : 'plate';
        l.helm = loot.setPiece('arena', GearSlot.helm, HeroClass.knight, 30);
        if (full) {
          l
            ..gloves = loot.setPiece('arena', GearSlot.gloves, HeroClass.knight, 30)
            ..boots = loot.setPiece('arena', GearSlot.boots, HeroClass.knight, 30);
        }
        return l;
      }
      final ring = loot.setPiece('arena', GearSlot.ring, HeroClass.knight, 30);
      final arena = <(String, void Function(Canvas, Size))>[
        for (final b in arenaBouts) (b.name, (Canvas c, Size s) => _humanoid(c, s, auraLook(foeLooks[b.look]!, arenaAura(arenaBouts.indexOf(b)), named: true))),
        for (final b in arenaBouts) ('${b.school} (plain)', (Canvas c, Size s) => _humanoid(c, s, foeLooks[b.look]!)),
        ('Hero: Champion\'s set', (Canvas c, Size s) => _humanoid(c, s, lookFor(HeroClass.knight, kit(), ring: ring), flip: false)),
        ('Heroine: Champion\'s set', (Canvas c, Size s) => _humanoid(c, s, lookFor(HeroClass.knight, kit(), ring: ring, female: true), flip: false)),
        ('Hero: just the galea', (Canvas c, Size s) => _humanoid(c, s, lookFor(HeroClass.knight, kit(full: false)), flip: false)),
      ];
      // (&pick=N: one of them, full screen.)
      final one = int.tryParse(Uri.base.queryParameters['pick'] ?? '');
      if (one != null && one >= 0 && one < arena.length) {
        return Scaffold(
          backgroundColor: const Color(0xFF6E737A),
          body: Column(children: [Expanded(child: CustomPaint(painter: _Tile(arena[one].$2), size: Size.infinite)), Text(arena[one].$1, style: Txt.label(size: 16, color: Palette.cream))]),
        );
      }
      return _grid(arena);
    }
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

class _BraceDemo extends StatefulWidget {
  const _BraceDemo();
  @override
  State<_BraceDemo> createState() => _BraceDemoState();
}

class _BraceDemoState extends State<_BraceDemo> {
  var _round = 0;
  final _said = <String>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0E0B08),
    body: Center(
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BraceRing(
              key: ValueKey(_round),
              onBrace: (q) => setState(() {
                _said.insert(0, q >= 1 ? 'perfect' : (q > 0 ? 'in time' : 'missed'));
                _round++;
              }),
            ),
            const SizedBox(height: 12),
            Text(_said.take(8).join(' · '), style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    ),
  );
}
