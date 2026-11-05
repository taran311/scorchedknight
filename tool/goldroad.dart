// Gold held by the road player as each main boss falls, and at the end.
import 'package:scorchedknight/game/catalog.dart';
import 'road_audit.dart' as ra;

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 8;
  final at = <int, List<int>>{};
  final seen = <int>{};
  ra.onFight = (e, f, t, l, ko) {
    final s = e.state;
    for (final c in s.bossesDown) {
      if (c < mainLands && seen.add(c)) (at[c] ??= []).add(s.knight.coins);
    }
  };
  final end = <int>[];
  for (var i = 1; i <= games; i++) {
    seen.clear();
    final a = ra.play(i, 'road');
    end.add(a.coins);
  }
  for (final c in at.keys.toList()..sort()) {
    final v = at[c]!..sort();
    print('${continents[c].name.padRight(24)} median ${v[v.length ~/ 2]}  max ${v.last}');
  }
  end.sort();
  print('end: median ${end[end.length ~/ 2]} max ${end.last}');
}
