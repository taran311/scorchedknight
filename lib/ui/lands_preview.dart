// A dev page for judging the battlegrounds: every land side by side, with the knight standing in
// it as a silhouette. Open http://localhost:5070/?lands

import 'package:flutter/material.dart';

import '../art/battlegrounds.dart';
import '../art/body.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/scenery.dart' show sceneSize;
import '../art/silhouette.dart';
import '../game/classes.dart';
import '../game/models.dart';
import 'theme.dart';

class LandsPreview extends StatelessWidget {
  const LandsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final looks = <Setting, String>{};
    for (final e in foeSettings.entries) {
      looks.putIfAbsent(e.value, () => e.key);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF15100C),
      body: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 16 / 9.6,
        padding: const EdgeInsets.all(6),
        children: [
          for (final s in Setting.values)
            Column(
              children: [
                Expanded(child: CustomPaint(painter: _LandPainter(looks[s] ?? 'rogue'), size: Size.infinite)),
                Text(s.name, style: Txt.label(size: 12, color: Palette.cream)),
              ],
            ),
        ],
      ),
    );
  }
}

class _LandPainter extends CustomPainter {
  _LandPainter(this.look);
  final String look;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / sceneSize.width, size.height / sceneSize.height);
    canvas.drawPicture(battleground(look));
    final hero = lookFor(HeroClass.knight, Loadout.starter(HeroClass.knight)..armour = 'plate');
    silhouette(
      canvas,
      const Rect.fromLTWH(0, 0, 960, 540),
      (c) => drawHumanoid(c, hero, idlePose(hero.stance, 0, still: true), 0, const DrawOptions(at: Offset(230, 470), scale: 1.12), still: true),
      rim: rimFor(specFor(settingFor(look))),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LandPainter old) => old.look != look;
}
