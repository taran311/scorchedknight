// What a fight in each land is worth, materials-wise: a quick auto-hero wins N fights in a land
// (resting every 10, so about 6 by day and 4 by night) and counts what it picks up, then works out
// how many fights each thing the town wants from that land takes.
import 'dart:math';
import '../lib/game/catalog.dart';
import '../lib/game/crafting.dart';
import '../lib/game/engine.dart';
import '../lib/game/loot.dart';
import '../lib/game/rules.dart';
import '../lib/game/classes.dart';

void main(List<String> args) {
  final n = args.isEmpty ? 1500 : int.parse(args.first);
  for (var c = 0; c < continents.length; c++) {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(int.parse(const String.fromEnvironment("SEED", defaultValue: "77")) + c));
    final s = e.state, k = s.knight;
    s.innRepaired = true;
    s.timber = 99;
    s.continent = c;
    s.unlocked = continents.length - 1;
    for (var b = 0; b < c && b < mainLands; b++) {
      s.bossesDown.add(b);
    }
    k.level = continents[c].minLevel + 2;
    final before = Map.of(s.mats), reagents0 = s.reagents[c];
    var legend = 0, gear = 0, fights = 0, bpDone = -1, trophyFirst20 = -1;
    String? setId;
    final golems = <String, int>{}, rares = <String, int>{};
    for (var i = 0; i < n; i++) {
      if (i % 10 == 0) e.rest();
      k.level = continents[c].minLevel + 2;
      k.xp = 0;
      e.explore();
      final f = foeIn(s);
      if (f.look.startsWith('golem') || f.look.startsWith('elemental')) golems[f.look] = (golems[f.look] ?? 0) + 1;
      if (s.rare != null) rares['rare'] = (rares['rare'] ?? 0) + 1;
      var guard = 0;
      while (s.inBattle && guard++ < 30) {
        s.foeHp = 1;
        k.hp = maxHp(k);
        e.takeTurn(BattleAction.attack);
      }
      if (s.inBattle) continue;
      fights++;
      for (final g in s.pendingLoot) {
        gear++;
        if (g.rarity == Rarity.legendary) legend++;
      }
      s.pendingLoot.clear();
      k.stash.clear();
      // The land's forged set: when its blueprints are all in, and when 20 trophies are.
      for (final fs in forgedSets) {
        if (trophyLands(fs.trophy).contains(continents[c].name)) setId ??= fs.id;
      }
      if (setId != null) {
        final fs = forgedSetById(setId)!;
        if (bpDone < 0 && setPieceSlots.every((sl) => s.mat(blueprintKey(fs.id, sl)) > 0)) bpDone = fights;
        if (trophyFirst20 < 0 && s.mat(trophyKey(fs.trophy)) >= 20) trophyFirst20 = fights;
      }
    }
    final got = <String, int>{};
    for (final key in s.mats.keys) {
      final d = s.mat(key) - (before[key] ?? 0);
      if (d > 0 && !key.startsWith('bp:')) got[key] = d;
    }
    String per(String key) => got[key] == null ? '' : '${key.split(':').last} ${(got[key]! / fights).toStringAsFixed(2)}/fight';
    final ores = [for (final m in Metal.values) per(oreKey(m))].where((x) => x.isNotEmpty);
    final troph = [for (final t in Trophy.values) per(trophyKey(t))].where((x) => x.isNotEmpty);
    final cores = [for (final el in Elemental.values) per(coreKey(el))].where((x) => x.isNotEmpty);
    final gems = got.entries.where((x) => x.key.startsWith('gem:')).fold(0, (a, b) => a + b.value);
    print('${c.toString().padLeft(2)} ${continents[c].name.padRight(22)} lv${k.level.toString().padLeft(2)} '
        'reagent ${((s.reagents[c] - reagents0) / fights).toStringAsFixed(2)}  ${troph.join(' ')}  ${ores.join(' ')}  ${cores.join(' ')}  '
        'gems ${(gems / fights).toStringAsFixed(3)}  gear ${(gear / fights).toStringAsFixed(2)} legend ${(1000 * legend / fights).toStringAsFixed(1)}/1000  '
        '${setId == null ? '' : 'set:$setId blueprints@$bpDone trophies20@$trophyFirst20'}  rares ${((rares['rare'] ?? 0) / fights * 100).round()}%  ${golems.isEmpty ? '' : golems}');
  }
}
