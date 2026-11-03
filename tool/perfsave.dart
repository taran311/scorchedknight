// Writes a save for the frame-rate probe: [level] knight in starter kit (or [weapon] art), mid-fight
// with a foe of [look] that won't fall. Run: dart run tool/perfsave.dart <level> <out.json> [weaponArt] [foeIndex]
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/game/engine.dart';
import '../lib/game/classes.dart';
import '../lib/game/models.dart';
import '../lib/game/rules.dart';

void main(List<String> a) {
  final level = int.parse(a[0]);
  final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
  final s = e.state, k = s.knight..level = level;
  e.takeHobsJob();
  s.innRepaired = true;
  s.settings.name = 'Probe';
  e.explore();
  s.foeMax = s.foeHp = 99999999;
  s.encounter = null;
  File(a[1]).writeAsStringSync(jsonEncode(jsonEncode(s.toJson())));
  stdout.writeln('foe ${foeIn(s).name} level ${k.level} weapon ${k.loadout.weapon?.name}');
}
