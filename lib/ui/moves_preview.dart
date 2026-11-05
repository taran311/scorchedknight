// A contact sheet of the class moves, for checking them by eye: each class in its whole suit, its
// stance and its attack or bash frozen at a row of moments, the stroke drawn where the stage draws
// it. Open http://localhost:5070/?moves (add &move=skill, &cls=ashen,bushido, &ms=0,200,320).
// With &play, each cell plays its move on a loop instead.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/body.dart';
import '../art/class_moves.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/rig.dart' show Pose;
import '../game/crafting.dart' show setPieceSlots;
import '../game/classes.dart' show HeroClass, setArmourId;
import '../game/engine.dart';
import '../game/loot.dart';
import '../game/models.dart';
import '../game/rules.dart' show suitArts;
import 'battle_stage.dart' show drawClassStroke, classStrokeMs, inClassStance;
import 'theme.dart';

const _knightX = 230.0, _groundY = 470.0, _foeX = 725.0, _scale = 1.12, _reach = 255.0, _hit = 320.0;

class MovesPreview extends StatefulWidget {
  const MovesPreview({super.key});

  @override
  State<MovesPreview> createState() => _MovesPreviewState();
}

class _MovesPreviewState extends State<MovesPreview> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1000)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = Uri.base.queryParameters;
    if (q.containsKey('dual')) {
      // ?moves&dual: the off hand's strike laid over each move (the plain knight's and each class's
      // attack and bash), frozen at moments around it.
      final times = (q['ms'] ?? '330,440,500,590,650,760,1000').split(',').map(double.parse).toList();
      final rows = [for (final id in [null, ...classMoves.keys]) for (final skill in [false, true]) (id, skill)];
      return Scaffold(
        backgroundColor: const Color(0xFF15100C),
        body: ListView(children: [
          for (final (id, skill) in rows)
            SizedBox(
              height: 130,
              child: Row(children: [
                SizedBox(width: 60, child: Text('${id ?? 'knight'}\n${skill ? 'bash' : 'attack'}', style: Txt.label(size: 10, color: Palette.cream))),
                for (final ms in times) Expanded(child: CustomPaint(painter: _DualPainter(ms, id, skill), size: Size.infinite)),
              ]),
            ),
        ]),
      );
    }
    final ids = (q['cls'] ?? classMoves.keys.join(',')).split(',').where(classMoves.containsKey).toList();
    final skill = q['move'] == 'skill', play = q.containsKey('play');
    final times = play ? const [0.0] : (q['ms'] ?? '0,150,220,270,320,420,620').split(',').map(double.parse).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: ListView(
        padding: const EdgeInsets.all(4),
        children: [
          for (final id in ids)
            SizedBox(
              height: double.tryParse(q['h'] ?? '') ?? 150,
              child: Row(
                children: [
                  SizedBox(width: 54, child: Text(id, style: Txt.label(size: 10, color: Palette.cream))),
                  for (final ms in times)
                    Expanded(
                      child: CustomPaint(painter: _MovePainter(id, skill, play ? null : ms, _time), size: Size.infinite),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A knight in suit [id], every piece at level 40.
Knight _knightIn(String id) {
  final k = GameEngine.newGame(heroClass: HeroClass.knight).knight, loot = LootTable(math.Random(1));
  final l = k.loadout..armour = setArmourId(id);
  for (final slot in setPieceSlots) {
    if (slot == GearSlot.armour) continue;
    final g = loot.setPiece(id, slot, HeroClass.knight, 40);
    if (slot == GearSlot.ring) {
      k.ring = g;
    } else {
      l.put(g);
    }
  }
  return k;
}

final _knights = <String, Knight>{};

class _MovePainter extends CustomPainter {
  _MovePainter(this.id, this.skill, this.ms, this.time) : super(repaint: time);
  final String id;
  final bool skill;
  final double? ms;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final k = _knights.putIfAbsent(id, () => _knightIn(id)), look = heroLook(k), moves = classMoves[id]!;
    final move = skill ? moves.skill : moves.attack;
    final at = ms ?? (time.value % 1500);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A221C));
    // The stage is 900 wide; frame its middle.
    final s = size.height / 560;
    canvas.translate(size.width / 2 - 470 * s, -40 * s);
    canvas.scale(s);
    canvas.drawLine(const Offset(0, _groundY), const Offset(1000, _groundY), Paint()..color = const Color(0xFF6A5A48)..strokeWidth = 3);
    // The foe: a dummy, chest-high mark where the stroke aims.
    const chest = Offset(_foeX, _groundY - 150);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(_foeX + 20, _groundY - 120), width: 90, height: 240), const Radius.circular(30)), Paint()..color = const Color(0xFF4A3A30));
    final back = move.clip[move.clip.length - 2].ms - 20;
    double ease(double x) => easeInOut(x.clamp(0.0, 1.0));
    final reach = move.reach;
    var dash = switch (move.dash) {
      DashStyle.blink => at < _hit - 110 ? 0.0 : reach,
      _ => reach * ease(at / (_hit - 60)),
    };
    if (at > back) dash = move.dash == DashStyle.blink ? (at > back + 70 ? 0 : dash) : dash * (1 - ease((at - back) / 380));
    final vanish = move.dash == DashStyle.blink && ((at > _hit - 170 && at < _hit - 100) || (at > back && at < back + 80)) ? .85 : 0.0;
    final pose = sampleClip(inClassStance(idlePose(look.stance, 0, still: true), moves.stance), move.clip, at) ?? inClassStance(idlePose(look.stance, 0, still: true), moves.stance);
    drawHumanoid(canvas, look, pose, 0, DrawOptions(at: Offset(_knightX + dash * _reach, _groundY), scale: _scale, alpha: 1 - vanish), still: true);
    final start = _hit - 110, age = (at - start) / classStrokeMs(move.stroke);
    final col = Color(suitArts[id]!.argb);
    if (age >= 0 && age <= 1) drawClassStroke(canvas, move.stroke, age, chest, skill ? col : Color.lerp(col, Colors.white, .3)!, false);
    canvas.restore();
    final tp = TextPainter(text: TextSpan(text: '${at.round()}', style: TextStyle(fontSize: 9, color: at == _hit ? const Color(0xFFFF7070) : const Color(0xFFB0A090))), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, const Offset(2, 2));
  }

  @override
  bool shouldRepaint(_MovePainter old) => true;
}


class _DualPainter extends CustomPainter {
  _DualPainter(this.ms, this.id, this.skill);
  final double ms;
  final String? id;
  final bool skill;
  static final _ks = <String, Knight>{};

  @override
  void paint(Canvas canvas, Size size) {
    final k = _ks.putIfAbsent(id ?? '', () {
      final k = id == null ? GameEngine.newGame(heroClass: HeroClass.knight).knight : _knightIn(id!);
      final w = k.loadout.weapon!, j = w.toJson();
      k.loadout.weapon = GearItem.fromJson({...j, 'art': 'katana', 'name': 'Katana'});
      k.loadout.offhand = GearItem.fromJson({...j, 'id': 'off', 'art': 'wakizashi', 'name': 'Wakizashi', 'slot': GearSlot.offhand.name, 'rarity': 'common', 'sp': null, 'set': null});
      return k;
    });
    final look = heroLook(k), moves = id == null ? null : classMoves[id];
    final clip = moves == null ? (skill ? crushClip : swingClip) : (skill ? moves.skill.clip : moves.attack.clip);
    var idle = idlePose(look.stance, 0, still: true);
    if (moves != null) idle = inClassStance(idle, moves.stance);
    // As the stage plays it: the move holds as the off hand's strike begins, and goes on after.
    const offStart = swingHitMs + 60;
    final Pose pose;
    if (ms < offStart) {
      pose = sampleClip(idle, clip, ms) ?? idle;
    } else if (ms < offStart + offhandMs) {
      final held = sampleClip(idle, clip, offStart) ?? idle;
      pose = sampleClip(held, offhandClip, ms - offStart) ?? held;
    } else {
      pose = sampleClip(idle, clip, ms - offhandMs) ?? idle;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A221C));
    final s = size.height / 330;
    canvas.translate(size.width / 2 - (_knightX + _reach + 40) * s, -(_groundY - 300) * s);
    canvas.scale(s);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(_foeX + 20, _groundY - 120), width: 90, height: 240), const Radius.circular(30)), Paint()..color = const Color(0xFF4A3A30));
    drawHumanoid(canvas, look, pose, 0, DrawOptions(at: const Offset(_knightX + _reach, _groundY), scale: _scale), still: true);
    canvas.restore();
    final hit = ms == offStart + offhandHitMs;
    final tp = TextPainter(text: TextSpan(text: '${ms.round()}', style: TextStyle(fontSize: 10, color: hit ? const Color(0xFFFF7070) : const Color(0xFFB0A090))), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, const Offset(2, 2));
  }

  @override
  bool shouldRepaint(_DualPainter old) => old.ms != ms || old.id != id || old.skill != skill;
}
