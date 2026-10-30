// The parchment journal (the adventure log) and number formatting.

import 'package:flutter/material.dart';

import '../game/models.dart';
import 'theme.dart';

String fmt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// The battle log, newest first.
class JournalEntryList extends StatelessWidget {
  const JournalEntryList({super.key, required this.entries});
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final list = entries.reversed.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: list.length,
        itemBuilder: (context, i) {
          final e = list[i];
          final style = switch (e.kind) {
            EntryKind.damage => Txt.body(size: 14.5, color: const Color(0xFF7A1D14)),
            EntryKind.gold => Txt.body(size: 14.5, color: Palette.goldText),
            EntryKind.good => Txt.body(size: 14.5, color: Palette.good),
            EntryKind.day => Txt.inkLabel(size: 14.5),
            EntryKind.plain => Txt.body(size: 14.5),
          };
          return Container(
            padding: EdgeInsets.only(top: e.kind == EntryKind.day ? 8 : 3, bottom: 3),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x66AE9A72))),
            ),
            child: Text(e.text, style: style),
          );
        },
      ),
    );
  }
}
