// The balance sweep: every build (a plain knight on found gear, and each class's suit) with every
// legendary weapon, played down the whole road by the audit's careful player, side by side.
// Run: dart run tool/sweep.dart [seeds] [suits,comma] [weapons,comma]
//
// Each row: games won, fights and knockouts a game; knockouts from level 15 on (once legendaries
// drop); a common fight from level 18 on (turns, share of health lost); a boss fight from 18 on
// (turns, and the share lost); and the first-try odds at the bosses from level 15 on.

import 'dart:io';

import 'package:scorchedknight/game/loot.dart' show legendaryNames, legendWeaponEdge;

import 'road_audit.dart' as ra;

const knightWeapons = ['Oathkeeper', 'Dawnbreaker', 'Grimtooth', 'Gambler\'s Edge', 'Gravewarden', 'Legion\'s Due', 'Wyrmcaller', 'Moonfang', 'The Bat-King\'s Flail'];

void main(List<String> args) {
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 8;
  final suits = args.length > 1 && args[1] != '-' ? args[1].split(',') : ['plain', 'nightblood', 'deepforge', 'drakesworn'];
  final weapons = args.length > 2 && args[2] != '-' ? args[2].split(',') : ['own', ...knightWeapons];
  for (final w in weapons) {
    if (w != 'own' && !legendaryNames.contains(w)) throw 'No legendary named $w';
  }
  // EDGES="Oathkeeper=.8;Grimtooth=.9": try weapons' powers without rebuilding.
  for (final kv in (Platform.environment['EDGES'] ?? '').split(';').where((x) => x.contains('='))) {
    final [name, v] = kv.split('=');
    legendWeaponEdge[name] = double.parse(v);
  }
  print('${'build'.padRight(34)} won  fights  KO  KO15+ | common18+ turns hp% | boss18+ turns hp% lost | boss odds15+');
  for (final suit in suits) {
    for (final w in weapons) {
      ra.buildSuit = suit == 'plain' ? null : suit;
      ra.buildWeapon = w == 'own' ? null : w;
      ra.odds.clear();
      var won = 0, fights = 0, kos = 0, late = 0;
      var cN = 0, cT = 0, cH = 0.0, bN = 0, bT = 0, bH = 0.0, bL = 0;
      ra.onFight = (e, f, turns, lost, ko) {
        if (e.state.knight.level < 18) return;
        if (f.boss) {
          bN++;
          bT += turns;
          bH += lost.clamp(0, 1);
          if (ko) bL++;
        } else {
          cN++;
          cT += turns;
          cH += lost.clamp(0, 1);
        }
      };
      for (var seed = 1; seed <= seeds; seed++) {
        final a = ra.play(seed, 'road');
        if (a.won) won++;
        fights += a.fights;
        kos += a.knockouts;
        for (final st in a.steps) {
          if (st.level >= 15) late += st.kos;
        }
      }
      final oddsLate = [for (final e in ra.odds.values) if (e.$3 / e.$1 >= 15) e.$2 / e.$1];
      final odds = oddsLate.isEmpty ? 0 : oddsLate.reduce((a, b) => a + b) / oddsLate.length;
      String f1(num x) => x.toStringAsFixed(1);
      print('${'$suit + $w'.padRight(34)} ${'$won/$seeds'.padLeft(5)} ${(fights / seeds).round().toString().padLeft(6)} ${f1(kos / seeds).padLeft(4)} ${f1(late / seeds).padLeft(5)} | ${f1(cT / (cN == 0 ? 1 : cN)).padLeft(13)} ${(cH / (cN == 0 ? 1 : cN) * 100).round().toString().padLeft(3)} | ${f1(bT / (bN == 0 ? 1 : bN)).padLeft(11)} ${(bH / (bN == 0 ? 1 : bN) * 100).round().toString().padLeft(3)} ${(bL / (bN == 0 ? 1 : bN) * 100).round().toString().padLeft(4)}% | ${(odds * 100).round().toString().padLeft(4)}%');
    }
  }
}
