import 'package:scorchedknight/game/catalog.dart';
import 'package:scorchedknight/game/rules.dart';
void main() {
  for (var c = 0; c < continents.length; c++) {
    final s = sightingsIn(c, cindervaleClear: true);
    final tot = s.fold(0.0, (a, b) => a + b.$2);
    print('${c.toString().padLeft(2)} ${continents[c].name.padRight(16)} tier ${landTier(c)}  total ${(tot*100).toStringAsFixed(1)}%  aura-rare ${(rareChance*100).toStringAsFixed(1)}%');
    for (final (r, o) in s) {
      print('      ${sightingRarity(o).name.padRight(10)} 1/${(1/o).round().toString().padRight(5)} ${r.name ?? r.look ?? '?'}${r.pack ? ' (pack)' : ''}');
    }
  }
}
