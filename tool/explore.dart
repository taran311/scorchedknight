// How much of the world a hero has seen by the time the Ember King's card comes up, and how long
// the road took. Run: dart run tool/explore.dart [seeds] [players,comma]

import 'road_audit.dart' as ra;

void main(List<String> args) {
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 8;
  final players = args.length > 1 ? args[1].split(',') : ['road', 'cards', 'wander'];
  for (final p in players) {
    ra.atKing.clear();
    var won = 0, fights = 0;
    for (var seed = 1; seed <= seeds; seed++) {
      final a = ra.play(seed, p);
      if (a.won) won++;
      fights += a.fights;
    }
    final n = ra.atKing.length;
    double avg(int Function((String, int, int, int, int)) f) => n == 0 ? 0 : ra.atKing.map(f).reduce((a, b) => a + b) / n;
    final lords = [for (final e in ra.atKing) e.$3]..sort();
    print('$p: won $won/$seeds, ${(fights / seeds).round()} fights a game | at the King: level ${avg((e) => e.$2).toStringAsFixed(1)}, '
        'side lords ${avg((e) => e.$3).toStringAsFixed(1)} (min ${lords.firstOrNull}, max ${lords.lastOrNull}) of 12, side lands seen ${avg((e) => e.$4).toStringAsFixed(1)}, after ${avg((e) => e.$5).round()} fights');
  }
}
