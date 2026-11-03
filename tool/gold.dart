// Gold held at each main boss's fall, for the balance auto-player (which buys armour, potions,
// the crossbow, mounts, tempering and enchants, but never hones or opens crates), and what the
// sinks it skips would cost at that level.
import 'dart:math';
import '../lib/game/catalog.dart';
import '../lib/game/loot.dart';
import 'balance.dart';

void main(List<String> args) {
  final runs = args.isEmpty ? 20 : int.parse(args.first);
  side = args.contains('side');
  final held = List.generate(mainLands, (_) => <int>[]), lvl = List.generate(mainLands, (_) => <int>[]);
  for (var i = 0; i < runs; i++) {
    run('all', 2000 + i, Stats(), onBoss: (e, c) {
      if (c < mainLands) {
        held[c].add(e.state.knight.coins);
        lvl[c].add(e.state.knight.level);
      }
    });
  }
  for (var c = 0; c < mainLands; c++) {
    if (held[c].isEmpty) continue;
    final l = (lvl[c].reduce((a, b) => a + b) / lvl[c].length).round();
    final h = held[c]..sort();
    print('${continents[c].name.padRight(22)} lvl $l  gold held: median ${h[h.length ~/ 2]}, max ${h.last}   crate ${crateCost(l)}');
  }
}
