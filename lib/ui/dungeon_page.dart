// A dungeon run: a torchlit wall with two or three doors in it, and a clue from behind each one.
// Pick a door. Fights open the battle screen; everything else happens at once and shows on a
// card. Six rooms down, one door is left: the boss's. The strip along the bottom is the way you
// came, room by room.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../game/controller.dart';
import '../game/dungeons.dart';
import '../game/rules.dart';
import 'battle_screen.dart';
import 'hud.dart';
import 'loot_window.dart';
import 'theme.dart';

class DungeonPage extends StatefulWidget {
  const DungeonPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<DungeonPage> createState() => _DungeonPageState();
}

class _DungeonPageState extends State<DungeonPage> {
  GameController get c => widget.controller;

  /// What the last room was, and what happened in it (shown until the next door).
  (RoomKind, String)? _last;

  Future<void> _open(int i) async {
    final why = c.whyNotDoor(i);
    if (why != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(why), duration: const Duration(milliseconds: 1400)));
      return;
    }
    final out = c.openDoor(i);
    if (out == null) return;
    setState(() => _last = out);
    if (out.$1.isFight) {
      await _fight(BattleStart.dungeon);
      return;
    }
    Audio.play(switch (out.$1) {
      RoomKind.trap => Sfx.hurt,
      RoomKind.shrine => Sfx.potion,
      RoomKind.treasure || RoomKind.vault => Sfx.coins,
      _ => Sfx.quest,
    });
    if (mounted && c.nextLoot != null) await resolvePendingLoot(context, c, title: out.$1.title);
  }

  Future<void> _fight(BattleStart how) async {
    final exit = await openBattle(context, c, how);
    if (!mounted) return;
    if (exit == BattleExit.inn) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _last = null);
  }

  Future<void> _leave() async {
    if (!c.dungeonCleared && c.state.dungeonRoom > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => _Confirm(dungeon: c.dungeonNow!),
      );
      if (go != true || !mounted) return;
    }
    if (c.dungeonCleared) Audio.play(Sfx.victory);
    c.leaveDungeon();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state, d = c.dungeonNow;
      if (d == null) return const Scaffold(body: SizedBox.shrink());
      final k = s.knight, col = Color(d.argb), cleared = c.dungeonCleared, doors = c.dungeonDoors;
      return MusicZone(
        track: 'travel',
        child: Scaffold(
          body: Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 20 + MediaQuery.paddingOf(context).bottom),
                  child: RepaintBoundary(child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              InnBackButton(label: 'Map', icon: Icons.public, onPressed: () => Navigator.of(context).pop()),
                              const SizedBox(width: 10),
                              Expanded(child: Text(d.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 22, color: col, weight: FontWeight.w800))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // The wall and its doors (or, the boss down, the hoard).
                          Stone(
                            padding: const EdgeInsets.all(3),
                            child: SizedBox(
                              height: 250,
                              child: Stack(
                                children: [
                                  Positioned.fill(child: CustomPaint(painter: _WallPainter(colour: col, seed: s.dungeonRoom + d.id.length * 7, hoard: cleared))),
                                  Positioned(
                                    left: 12,
                                    top: 8,
                                    child: Text(
                                      cleared ? 'THE HOARD' : (s.dungeonRoom >= dungeonRooms ? 'THE LAST DOOR' : 'ROOM ${s.dungeonRoom + 1} OF ${dungeonRooms + 1}'),
                                      style: Txt.label(size: 13, color: Palette.amber),
                                    ),
                                  ),
                                  if (s.dungeonKey)
                                    const Positioned(right: 12, top: 6, child: Tooltip(message: 'You carry a key', child: Icon(Icons.vpn_key, color: Color(0xFFFFD45A), size: 26))),
                                  if (!cleared && !s.inBattle)
                                    Positioned.fill(
                                      top: 30,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          for (var i = 0; i < doors.length; i++) _Door(clue: doors[i], locked: doors[i] == DoorClue.locked && !s.dungeonKey, onTap: () => _open(i)),
                                        ],
                                      ),
                                    ),
                                  if (s.inBattle)
                                    Center(
                                      child: SizedBox(width: 240, child: StoneButton(title: 'Back into the fight', tone: ButtonTone.blood, onPressed: () => _fight(BattleStart.resume))),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // The way you came.
                          SizedBox(height: 46, child: CustomPaint(painter: _PathPainter(path: [for (final p in s.dungeonPath) RoomKind.values.byName(p)], at: s.dungeonRoom, cleared: cleared, colour: col))),
                          const SizedBox(height: 8),
                          if (_last case (final kind, final text)? when !kind.isFight) ...[
                            _Outcome(kind: kind, text: text),
                            const SizedBox(height: 8),
                          ],
                          // You.
                          Stone(
                            child: Row(
                              children: [
                                const Icon(Icons.favorite, color: Color(0xFFE05A4A), size: 20),
                                const SizedBox(width: 6),
                                Expanded(child: Bar(value: k.hp, max: maxHp(k), height: 18, label: '${k.hp} / ${maxHp(k)}', colours: const [Color(0xFFE0604A), Color(0xFF8A1E14)])),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 128,
                                  child: StoneButton(
                                    title: 'Potion · ${k.potions}',
                                    compact: true,
                                    onPressed: k.potions > 0 && k.hp < maxHp(k) && !s.inBattle
                                        ? () {
                                            if (c.drinkPotion() > 0) Audio.play(Sfx.potion);
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          StoneButton(
                            title: cleared ? 'Climb out with the hoard' : 'Climb out',
                            caption: cleared ? null : 'The run ends here',
                            tone: cleared ? ButtonTone.amber : ButtonTone.stone,
                            onPressed: s.inBattle ? null : _leave,
                          ),
                        ],
                      ),
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One door: an arched oak door in the wall, with what you can hear or see from behind it.
class _Door extends StatefulWidget {
  const _Door({required this.clue, required this.locked, required this.onTap});
  final DoorClue clue;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_Door> createState() => _DoorState();
}

class _DoorState extends State<_Door> with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  bool _hover = false;

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boss = widget.clue == DoorClue.boss;
    return Tooltip(
      message: widget.clue.hint,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hover ? 1.06 : 1,
            duration: const Duration(milliseconds: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _glow,
                  builder: (context, child) => CustomPaint(size: Size(boss ? 150 : 104, 168), painter: _DoorPainter(clue: widget.clue, locked: widget.locked, pulse: _glow.value, lit: _hover)),
                ),
                const SizedBox(height: 2),
                Text(widget.clue.label, style: Txt.label(size: 14, color: widget.locked ? Palette.parch2 : Palette.cream)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoorPainter extends CustomPainter {
  _DoorPainter({required this.clue, required this.locked, required this.pulse, required this.lit});
  final DoorClue clue;
  final bool locked, lit;
  final double pulse;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height, boss = clue == DoorClue.boss;
    // The stone frame.
    final frame = Path()
      ..moveTo(0, h)
      ..lineTo(0, w / 2)
      ..arcToPoint(Offset(w, w / 2), radius: Radius.circular(w / 2))
      ..lineTo(w, h)
      ..close();
    c.drawPath(frame, Paint()..color = const Color(0xFF4A4440));
    c.drawPath(frame, Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // The door itself, in planks, with iron bands.
    final inset = w * .1;
    final door = Path()
      ..moveTo(inset, h)
      ..lineTo(inset, w / 2)
      ..arcToPoint(Offset(w - inset, w / 2), radius: Radius.circular(w / 2 - inset))
      ..lineTo(w - inset, h)
      ..close();
    final wood = boss ? const [Color(0xFF3A1E18), Color(0xFF1A0C0A)] : const [Color(0xFF7A5232), Color(0xFF3E2814)];
    c.drawPath(door, Paint()..shader = LinearGradient(colors: wood, begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(Offset.zero & size));
    c.save();
    c.clipPath(door);
    final planks = boss ? 4 : 3;
    for (var i = 1; i < planks; i++) {
      final x = inset + (w - 2 * inset) * i / planks;
      c.drawLine(Offset(x, 0), Offset(x, h), Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 1.6);
    }
    for (final y in [h * .42, h * .78]) {
      c.drawRect(Rect.fromLTWH(0, y, w, 7), Paint()..color = const Color(0xFF2A2A2E));
      for (final x in [inset + 8, w - inset - 8]) {
        c.drawCircle(Offset(x, y + 3.5), 2.2, Paint()..color = const Color(0xFF8A8A92));
      }
    }
    c.restore();
    if (lit) c.drawPath(door, Paint()..color = const Color(0x22FFE6A0));
    // A ring handle.
    c.drawCircle(Offset(w - inset - 12, h * .62), 5, Paint()
      ..color = const Color(0xFF9A8A6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // The clue.
    final gap = Rect.fromLTWH(inset, h - 6, w - 2 * inset, 6);
    switch (clue) {
      case DoorClue.growl:
        // Two red eyes in the crack, and claw marks gouged in the planks.
        for (final dx in [-9.0, 9.0]) {
          c.drawCircle(Offset(w / 2 + dx, h * .3), 6 + pulse * 3, Paint()
            ..color = const Color(0xFFFF3A2A).withValues(alpha: .35 + pulse * .25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          c.drawOval(Rect.fromCenter(center: Offset(w / 2 + dx, h * .3), width: 7, height: 4), Paint()..color = const Color(0xFFFFB04A));
        }
        for (var i = 0; i < 3; i++) {
          c.drawLine(Offset(w * .3 + i * 7, h * .5), Offset(w * .38 + i * 7, h * .68), Paint()
            ..color = const Color(0xFFD8B890)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
        }
      case DoorClue.glitter:
        // Gold light spilling under the door, and sparkles.
        c.drawRect(gap, Paint()..color = const Color(0xFFFFD45A).withValues(alpha: .7 + pulse * .3));
        c.drawOval(Rect.fromCenter(center: Offset(w / 2, h), width: w * 1.1, height: 26), Paint()
          ..color = const Color(0xFFFFD45A).withValues(alpha: .35 + pulse * .2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        for (final (dx, dy, s) in const [(-.25, .25, 1.0), (.2, .18, .7), (.05, .55, .8)]) {
          _sparkle(c, Offset(w / 2 + dx * w, h * dy), 6 * s * (.7 + pulse * .5));
        }
      case DoorClue.quiet:
        // A thin pale light under the door, nothing else.
        c.drawRect(gap, Paint()..color = const Color(0xFFBFE0FF).withValues(alpha: .35 + pulse * .2));
        c.drawOval(Rect.fromCenter(center: Offset(w / 2, h), width: w, height: 18), Paint()
          ..color = const Color(0xFFBFE0FF).withValues(alpha: .15 + pulse * .1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      case DoorClue.locked:
        // Chains across it and a great padlock.
        final chain = Paint()
          ..color = const Color(0xFF8A8A92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        c.drawLine(Offset(inset, h * .4), Offset(w - inset, h * .7), chain);
        c.drawLine(Offset(w - inset, h * .4), Offset(inset, h * .7), chain);
        final lock = Offset(w / 2, h * .56);
        c.drawArc(Rect.fromCenter(center: lock + const Offset(0, -10), width: 20, height: 22), math.pi, math.pi, false, Paint()
          ..color = const Color(0xFFB8A060)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: lock + const Offset(0, 4), width: 28, height: 24), const Radius.circular(4)), Paint()..color = locked ? const Color(0xFF8A7440) : const Color(0xFFFFD45A));
        c.drawCircle(lock + const Offset(0, 3), 3.5, Paint()..color = const Color(0xFF2A1C10));
      case DoorClue.boss:
        // A skull carved over the arch, and red light leaking round the edges.
        c.drawPath(door, Paint()
          ..color = const Color(0xFFFF3A2A).withValues(alpha: .45 + pulse * .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        final sk = Offset(w / 2, w * .36);
        c.drawCircle(sk, 16, Paint()..color = const Color(0xFFD8D0C0));
        c.drawRect(Rect.fromCenter(center: sk + const Offset(0, 14), width: 18, height: 10), Paint()..color = const Color(0xFFD8D0C0));
        for (final dx in [-6.0, 6.0]) {
          c.drawCircle(sk + Offset(dx, 0), 4.5, Paint()..color = const Color(0xFF1A0A08));
          c.drawCircle(sk + Offset(dx, 0), 2, Paint()..color = const Color(0xFFFF4A3A).withValues(alpha: .6 + pulse * .4));
        }
    }
  }

  void _sparkle(Canvas c, Offset at, double r) {
    final p = Path()
      ..moveTo(at.dx, at.dy - r)
      ..lineTo(at.dx + r * .25, at.dy - r * .25)
      ..lineTo(at.dx + r, at.dy)
      ..lineTo(at.dx + r * .25, at.dy + r * .25)
      ..lineTo(at.dx, at.dy + r)
      ..lineTo(at.dx - r * .25, at.dy + r * .25)
      ..lineTo(at.dx - r, at.dy)
      ..lineTo(at.dx - r * .25, at.dy - r * .25)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFFFFF0B0));
  }

  @override
  bool shouldRepaint(_DoorPainter old) => old.pulse != pulse || old.lit != lit || old.locked != locked || old.clue != clue;
}

/// The wall the doors are in: dark stone blocks, a torch at each end, the dungeon's own light. Once
/// the boss is down, the hoard heaped in the middle instead.
class _WallPainter extends CustomPainter {
  _WallPainter({required this.colour, required this.seed, required this.hoard});
  final Color colour;
  final int seed;
  final bool hoard;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height, r = math.Random(seed);
    c.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(colour, Colors.black, .82)!, const Color(0xFF0C0A08)]).createShader(Offset.zero & size));
    // Stone blocks.
    final mortar = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 1.4;
    for (var row = 0; row * 26.0 < h; row++) {
      final y = row * 26.0;
      c.drawLine(Offset(0, y), Offset(w, y), mortar);
      for (var x = (row.isOdd ? 30.0 : 0) + r.nextDouble() * 10; x < w; x += 54 + r.nextDouble() * 14) {
        c.drawLine(Offset(x, y), Offset(x, y + 26), mortar);
      }
    }
    // The floor.
    c.drawRect(Rect.fromLTWH(0, h - 22, w, 22), Paint()..color = const Color(0xFF14100C));
    // Torches.
    for (final x in [24.0, w - 24]) {
      c.drawCircle(Offset(x, 60), 70, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFB04A).withValues(alpha: .35), const Color(0x00FFB04A)]).createShader(Rect.fromCircle(center: Offset(x, 60), radius: 70)));
      c.drawRect(Rect.fromCenter(center: Offset(x, 82), width: 6, height: 26), Paint()..color = const Color(0xFF3A2A1A));
      c.drawOval(Rect.fromCenter(center: Offset(x, 64), width: 12, height: 20), Paint()..color = const Color(0xFFFFC05A));
    }
    if (hoard) _hoard(c, Offset(w / 2, h - 22), r);
  }

  // ---- the hoard: a heap of coin, a chest thrown open, cut gems, a goblet, glints ----
  // (Two-colour gradients only: the phone's renderer throws on more without stops.)

  static const _gold = Color(0xFFFFD45A), _goldLight = Color(0xFFFFF0B0), _goldDark = Color(0xFF9A6A1A), _ink = Color(0xFF2A1808);

  void _hoard(Canvas c, Offset mid, math.Random r) {
    // Light pooled on the floor round it.
    final pool = Rect.fromCenter(center: mid, width: 330, height: 80);
    c.drawOval(pool, Paint()..shader = RadialGradient(colors: [_gold.withValues(alpha: .35), _gold.withValues(alpha: 0)]).createShader(pool));
    _goblet(c, mid + const Offset(-118, 0));
    _coinStack(c, mid + const Offset(-92, 0), 7);
    // The heap: a shaded mound, then coins all over its face.
    const hw = 112.0, hh = 74.0;
    double top(double x) => mid.dy - hh * (1 - math.pow((x - mid.dx) / hw, 2)).clamp(0.0, 1.0);
    final heap = Path()
      ..moveTo(mid.dx - hw, mid.dy)
      ..quadraticBezierTo(mid.dx, mid.dy - hh * 2, mid.dx + hw, mid.dy)
      ..close();
    c.drawPath(heap, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8B84A), Color(0xFF8A5A14)]).createShader(Rect.fromLTRB(mid.dx - hw, mid.dy - hh, mid.dx + hw, mid.dy)));
    // Back to front, so the nearer coins lie over the further ones.
    final coins = <Offset>[
      for (var i = 0; i < 70; i++)
        () {
          final x = mid.dx - hw * .92 + r.nextDouble() * hw * 1.84, t = top(x);
          return Offset(x, t + 3 + math.pow(r.nextDouble(), 1.6) * (mid.dy - t - 5));
        }(),
    ]..sort((a, b) => a.dy.compareTo(b.dy));
    for (final at in coins) {
      _coin(c, at, 5.5 + r.nextDouble() * 2, r.nextDouble() < .25);
    }
    // A few spilled on the floor in front.
    for (var i = 0; i < 9; i++) {
      _coin(c, mid + Offset(-hw + r.nextDouble() * hw * 2.1, 4 + r.nextDouble() * 10), 5 + r.nextDouble() * 1.5, r.nextBool());
    }
    // The chest on the heap's right shoulder, and gems on the gold.
    _chest(c, mid + const Offset(78, -2));
    _gem(c, mid + const Offset(-46, -36), const Color(0xFFE0304A), 9);
    _gem(c, mid + const Offset(-8, -62), const Color(0xFF3A8AE8), 10);
    _gem(c, mid + const Offset(26, -38), const Color(0xFF2EC46A), 8);
    _gem(c, mid + const Offset(-74, -12), const Color(0xFFB05AE8), 7.5);
    // Glints where the torchlight catches.
    for (final g in const [Offset(-20, -66), Offset(40, -30), Offset(-60, -24), Offset(10, -46), Offset(104, -64)]) {
      _glint(c, mid + g, 6 + r.nextDouble() * 4);
    }
  }

  /// One coin lying tilted: a gold ellipse with a darker rim and a shine.
  void _coin(Canvas c, Offset at, double size, bool edgeOn) {
    final face = Rect.fromCenter(center: at, width: size * 2, height: size * (edgeOn ? .55 : .95));
    c.drawOval(face.shift(const Offset(0, 1.6)), Paint()..color = _goldDark);
    c.drawOval(face, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_goldLight, _gold]).createShader(face));
    c.drawOval(face, Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9);
    if (!edgeOn) {
      c.drawOval(face.deflate(size * .32), Paint()
        ..color = _goldDark.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7);
    }
  }

  void _coinStack(Canvas c, Offset base, int n) {
    for (var i = 0; i < n; i++) {
      _coin(c, base + Offset((i.isOdd ? .8 : -.6), -i * 3.2), 7, true);
    }
  }

  /// A gold goblet with a gem set in its bowl.
  void _goblet(Canvas c, Offset base) {
    final gold = Paint()..shader = const LinearGradient(colors: [_goldLight, _goldDark]).createShader(Rect.fromLTWH(base.dx - 12, base.dy - 46, 24, 46));
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final foot = Rect.fromCenter(center: base + const Offset(0, -2), width: 22, height: 6);
    c.drawOval(foot, gold);
    c.drawOval(foot, ink);
    final stem = Rect.fromCenter(center: base + const Offset(0, -13), width: 5, height: 20);
    c.drawRect(stem, gold);
    c.drawRect(stem, ink);
    final bowl = Path()
      ..moveTo(base.dx - 12, base.dy - 44)
      ..quadraticBezierTo(base.dx - 12, base.dy - 22, base.dx, base.dy - 22)
      ..quadraticBezierTo(base.dx + 12, base.dy - 22, base.dx + 12, base.dy - 44)
      ..close();
    c.drawPath(bowl, gold);
    c.drawPath(bowl, ink);
    c.drawOval(Rect.fromCenter(center: base + const Offset(0, -44), width: 24, height: 5), Paint()..color = const Color(0xFF5A3A10));
    _gem(c, base + const Offset(0, -32), const Color(0xFFE0304A), 3.6);
  }

  /// A cut gem: a crown of facets over a pointed pavilion, light on one side, a sparkle.
  void _gem(Canvas c, Offset at, Color col, double s) {
    final light = Color.lerp(col, Colors.white, .5)!, dark = Color.lerp(col, Colors.black, .45)!;
    final girdleL = at + Offset(-s, 0), girdleR = at + Offset(s, 0), tableL = at + Offset(-s * .5, -s * .6), tableR = at + Offset(s * .5, -s * .6), tip = at + Offset(0, s * 1.15);
    // Shadow on the gold.
    c.drawOval(Rect.fromCenter(center: at + Offset(s * .3, s * 1.2), width: s * 2, height: s * .6), Paint()..color = Colors.black.withValues(alpha: .25));
    // Pavilion: the lower half, two faces.
    c.drawPath(Path()..addPolygon([girdleL, at, tip], true), Paint()..color = col);
    c.drawPath(Path()..addPolygon([at, girdleR, tip], true), Paint()..color = dark);
    // Crown: the table on top, a bright face and a darker one.
    c.drawPath(Path()..addPolygon([girdleL, tableL, tableR, girdleR], true), Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, col]).createShader(Rect.fromPoints(girdleL + Offset(0, -s), girdleR)));
    final facet = Paint()
      ..color = dark.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    c.drawLine(tableL, at, facet);
    c.drawLine(tableR, at, facet);
    c.drawLine(girdleL, girdleR, facet);
    c.drawPath(Path()..addPolygon([girdleL, tableL, tableR, girdleR, tip], true), Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1);
    _glint(c, tableL + Offset(s * .15, s * .1), s * .7);
  }

  /// A four-pointed glint of light.
  void _glint(Canvas c, Offset at, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: .9);
    c.drawPath(
      Path()
        ..moveTo(at.dx, at.dy - s)
        ..quadraticBezierTo(at.dx, at.dy, at.dx + s, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + s)
        ..quadraticBezierTo(at.dx, at.dy, at.dx - s, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - s)
        ..close(),
      p,
    );
  }

  /// A treasure chest thrown open, seen a little from the side: oak planks bound in gold, studs,
  /// a lock plate, the arched lid back on its hinges, and gold spilling out over the lip.
  void _chest(Canvas c, Offset base) {
    const w = 70.0, h = 38.0, d = 16.0; // front width, height, how much of the side shows
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final fl = base + const Offset(-w / 2, 0), fr = base + const Offset(w / 2, 0);
    final front = Rect.fromLTRB(fl.dx, fl.dy - h, fr.dx, fr.dy);
    // The side face, going back up to the right.
    final side = Path()..addPolygon([front.topRight, front.topRight + const Offset(d, -d * .6), front.bottomRight + const Offset(d, -d * .6), front.bottomRight], true);
    c.drawPath(side, Paint()..color = const Color(0xFF4A2A12));
    c.drawPath(side, ink);
    // The lid thrown back: its inside showing, arched, leaning away.
    final hingeL = front.topLeft + const Offset(4, -d * .6), hingeR = front.topRight + const Offset(d - 4, -d * .6);
    final lid = Path()
      ..moveTo(hingeL.dx, hingeL.dy)
      ..lineTo(hingeL.dx + 6, hingeL.dy - 34)
      ..quadraticBezierTo((hingeL.dx + hingeR.dx) / 2 + 6, hingeL.dy - 50, hingeR.dx + 6, hingeR.dy - 34)
      ..lineTo(hingeR.dx, hingeR.dy)
      ..close();
    c.drawPath(lid, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6A3E1E), Color(0xFF2E180A)]).createShader(lid.getBounds()));
    // The gold band round the lid's rim, and its planks.
    c.drawPath(lid, Paint()
      ..color = const Color(0xFFD8A040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4);
    c.drawPath(lid, ink);
    for (final f in const [.33, .66]) {
      final x = hingeL.dx + (hingeR.dx - hingeL.dx) * f;
      c.drawLine(Offset(x, hingeL.dy - 2), Offset(x + 6, hingeL.dy - 42), Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 1.2);
    }
    // Light pouring up out of it.
    final glowAt = Offset(base.dx + d / 2, front.top - 6);
    c.drawCircle(glowAt, 46, Paint()..shader = RadialGradient(colors: [_goldLight.withValues(alpha: .55), _goldLight.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: glowAt, radius: 46)));
    // The opening, heaped with gold over the lip.
    final mouth = Path()..addPolygon([front.topLeft, front.topLeft + const Offset(d, -d * .6), front.topRight + const Offset(d, -d * .6), front.topRight], true);
    c.drawPath(mouth, Paint()..color = const Color(0xFF3A220C));
    final spill = Path()
      ..moveTo(front.left + 2, front.top + 2)
      ..quadraticBezierTo(front.left + w * .35, front.top - 18, front.left + w * .6, front.top - 10)
      ..quadraticBezierTo(front.right + d * .6, front.top - 16, front.right + d - 2, front.top - d * .6 + 2)
      ..lineTo(front.right, front.top + 2)
      ..close();
    c.drawPath(spill, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_goldLight, _gold]).createShader(spill.getBounds()));
    for (final o in const [Offset(10, -6), Offset(22, -11), Offset(36, -9), Offset(50, -10), Offset(62, -6)]) {
      _coin(c, front.topLeft + o, 4.5, false);
    }
    // The front: oak planks, gold corner bands and straps, studs, a lock plate.
    c.drawRect(front, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A5228), Color(0xFF5A3216)]).createShader(front));
    for (var y = front.top + h / 3; y < front.bottom - 2; y += h / 3) {
      c.drawLine(Offset(front.left, y), Offset(front.right, y), Paint()
        ..color = const Color(0x55000000)
        ..strokeWidth = 1.2);
    }
    final band = Paint()..shader = const LinearGradient(colors: [Color(0xFFF0C860), Color(0xFFA87420)]).createShader(front);
    c.drawRect(Rect.fromLTWH(front.left, front.top, w, 5), band);
    c.drawRect(Rect.fromLTWH(front.left, front.bottom - 5, w, 5), band);
    for (final x in [front.left, front.right - 7, front.left + w * .3 - 3, front.left + w * .7 - 3]) {
      c.drawRect(Rect.fromLTWH(x, front.top, 7, h), band);
    }
    for (final x in [front.left + 3.5, front.right - 3.5]) {
      for (final y in [front.top + 10, front.bottom - 10]) {
        c.drawCircle(Offset(x, y), 1.6, Paint()..color = _ink);
      }
    }
    final plate = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(base.dx, front.top + 13), width: 14, height: 16), const Radius.circular(3));
    c.drawRRect(plate, Paint()..color = const Color(0xFFE8B850));
    c.drawRRect(plate, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    c.drawCircle(Offset(base.dx, front.top + 11), 2, Paint()..color = _ink);
    c.drawRect(Rect.fromCenter(center: Offset(base.dx, front.top + 15), width: 1.6, height: 4), Paint()..color = _ink);
    c.drawRect(front, ink);
  }

  @override
  bool shouldRepaint(_WallPainter old) => old.seed != seed || old.hoard != hoard || old.colour != colour;
}

/// The way you came: a node for every room, each marked with what it was, the boss's skull at the
/// end.
class _PathPainter extends CustomPainter {
  _PathPainter({required this.path, required this.at, required this.cleared, required this.colour});
  final List<RoomKind> path;
  final int at;
  final bool cleared;
  final Color colour;

  static const _glyphs = <RoomKind, (IconData, Color)>{
    RoomKind.fight: (Icons.shield, Color(0xFFD8C8A8)),
    RoomKind.elite: (Icons.local_fire_department, Color(0xFFFF8A4A)),
    RoomKind.ambush: (Icons.flash_on, Color(0xFFFFC04A)),
    RoomKind.treasure: (Icons.inventory_2, Color(0xFFFFD45A)),
    RoomKind.trap: (Icons.warning_amber, Color(0xFFE06A4A)),
    RoomKind.shrine: (Icons.self_improvement, Color(0xFF9ADFFF)),
    RoomKind.key: (Icons.vpn_key, Color(0xFFFFD45A)),
    RoomKind.vault: (Icons.diamond, Color(0xFFB08AFF)),
    RoomKind.boss: (Icons.whatshot, Color(0xFFFF4A3A)),
  };

  @override
  void paint(Canvas c, Size size) {
    const n = dungeonRooms + 1;
    final w = size.width, y = size.height / 2;
    Offset node(int i) => Offset(22 + (w - 44) * i / (n - 1), y);
    c.drawLine(node(0), node(n - 1), Paint()
      ..color = const Color(0xFF3A3028)
      ..strokeWidth = 4);
    c.drawLine(node(0), node(math.min(at, n - 1)), Paint()
      ..color = colour
      ..strokeWidth = 4);
    for (var i = 0; i < n; i++) {
      final p = node(i), done = i < path.length && (i < at || cleared), here = i == at && !cleared;
      c.drawCircle(p, here ? 17 : 14, Paint()..color = done ? const Color(0xFF2A2018) : const Color(0xFF15110C));
      c.drawCircle(p, here ? 17 : 14, Paint()
        ..color = here ? Palette.amber : (done ? colour : const Color(0xFF4A4038))
        ..style = PaintingStyle.stroke
        ..strokeWidth = here ? 3 : 2);
      final (icon, col) = done
          ? _glyphs[path[i]]!
          : i == n - 1
          ? (Icons.whatshot, const Color(0xFF8A3A2A))
          : (Icons.help_outline, const Color(0xFF6A5E50));
      final tp = TextPainter(
        text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: 17, fontFamily: icon.fontFamily, package: icon.fontPackage, color: col)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.path.length != path.length || old.at != at || old.cleared != cleared;
}

/// What the last room turned out to be.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.kind, required this.text});
  final RoomKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (icon, col) = _PathPainter._glyphs[kind]!;
    return Stone(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A140E), border: Border.all(color: col, width: 2)),
            child: Icon(icon, color: col, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.title, style: Txt.label(size: 18, color: col, weight: FontWeight.w800)),
                Text(text, style: Txt.onStone(size: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.dungeon});
  final Dungeon dungeon;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Stone(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Climb out?', style: Txt.label(size: 20, color: Palette.amber, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('You keep what you found, but the run ends. Next time you start from the top.', style: Txt.onStone(size: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StoneButton(title: 'Climb out', onPressed: () => Navigator.of(context).pop(true))),
                const SizedBox(width: 10),
                Expanded(child: StoneButton(title: 'Stay', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop(false))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
