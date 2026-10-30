// A new knight: a name, hero or heroine, and a first look at the three tools every knight
// carries (blade, Ember Rites and crossbow). Shown once.

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart' show shinesAt, sootFor;
import '../game/models.dart';
import 'hero_view.dart';
import 'hud.dart' show CrestPainter;
import 'intro.dart';
import 'item_icons.dart';
import 'theme.dart';

class ClassPickerScreen extends StatefulWidget {
  const ClassPickerScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<ClassPickerScreen> createState() => _ClassPickerScreenState();
}

class _ClassPickerScreenState extends State<ClassPickerScreen> {
  late bool _female = widget.controller.state.knight.female;
  bool _introDone = false;
  late final _name = TextEditingController(text: widget.controller.state.settings.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setOut() {
    final c = widget.controller;
    c.setName(_name.text);
    c.setFemale(_female);
    c.chooseClass(HeroClass.knight);
  }

  @override
  Widget build(BuildContext context) {
    if (!_introDone) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: IntroScreen(female: _female, onDone: () => setState(() => _introDone = true)),
      );
    }
    final look = lookFor(HeroClass.knight, Loadout.starter(HeroClass.knight), female: _female, soot: sootFor(1), shine: shinesAt(1));
    // A phone gets everything smaller and closer together, so the whole page (button and all)
    // fits on the screen without scrolling.
    final phone = isPhone(context);
    // What you carry, as symbols: the first fights teach the rest.
    final tools = <(Widget, String)>[
      (const ItemIcon(Item.swords, size: 30), 'Blade'),
      (const Icon(Icons.local_fire_department, color: Color(0xFFFF8A3A), size: 30), 'Ember Rites'),
      (const Icon(Icons.gps_fixed, color: Palette.parch, size: 28), 'Crossbow'),
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -.35), radius: 1.1, colors: [Color(0xFF3A2218), Color(0xFF15100C), Color(0xFF0C0907)], stops: [0, .55, 1]),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(phone ? 12 : 16, phone ? 10 : 24, phone ? 12 : 16, phone ? 10 : 24),
              child: RepaintBoundary(child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight - (phone ? 20 : 48)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: phone ? 34 : 52, height: phone ? 40 : 62, child: const CustomPaint(painter: CrestPainter())),
                        SizedBox(height: phone ? 6 : 12),
                        // One line, whatever the width.
                        FittedBox(fit: BoxFit.scaleDown, child: Text('SCORCHED KNIGHT', maxLines: 1, style: Txt.logo().copyWith(fontSize: phone ? 30 : 36, letterSpacing: 2))),
                        const SizedBox(height: 2),
                        Text('One knight walked out of the ashes.', textAlign: TextAlign.center, style: Txt.label(size: phone ? 15 : 18, color: Palette.parch2)),
                        SizedBox(height: phone ? 10 : 20),
                        Stone(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final figure = Container(
                                width: phone ? 130 : 210,
                                height: phone ? 170 : 290,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF4A4038), Palette.stone0]),
                                ),
                                child: HeroFigure(look: look),
                              );
                              final form = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Who are you?', style: Txt.label(size: phone ? 17 : 20, color: Palette.amber, weight: FontWeight.w800)),
                                  SizedBox(height: phone ? 4 : 6),
                                  TextField(
                                    controller: _name,
                                    maxLength: 24,
                                    textCapitalization: TextCapitalization.words,
                                    style: Txt.body(size: 18),
                                    decoration: InputDecoration(hintText: 'Sir Smudge', counterText: '', isDense: phone),
                                  ),
                                  SizedBox(height: phone ? 8 : 10),
                                  Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: HeroOrHeroine(female: _female, onChanged: (f) => setState(() => _female = f)))),
                                  SizedBox(height: phone ? 10 : 18),
                                  Text('You carry', style: Txt.label(size: 13, color: Palette.amber)),
                                  SizedBox(height: phone ? 2 : 6),
                                  // Shrinks rather than overflow on the narrowest phones.
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: phone ? Alignment.center : Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final (i, (icon, name)) in tools.indexed) ...[
                                          if (i > 0) SizedBox(width: phone ? 16 : 22),
                                          Column(children: [SizedBox(height: phone ? 28 : 34, child: Center(child: icon)), Text(name, style: Txt.label(size: phone ? 13 : 14, color: Palette.cream))]),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                              if (box.maxWidth < 480) return Column(children: [figure, SizedBox(height: phone ? 8 : 12), form]);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [figure, const SizedBox(width: 14), Expanded(child: form)],
                              );
                            },
                          ),
                        ),
                        SizedBox(height: phone ? 10 : 14),
                        SizedBox(
                          width: double.infinity,
                          child: StoneButton(
                            title: 'Walk to the Soot & Kettle',
                            tone: ButtonTone.blood,
                            onPressed: _setOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero or heroine: two stone tabs. Cosmetic only, and free to change later in Settings.
class HeroOrHeroine extends StatelessWidget {
  const HeroOrHeroine({super.key, required this.female, required this.onChanged});
  final bool female;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final on = female == value;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: stoneDecoration(fill: on ? Palette.stone3 : Palette.stone1).copyWith(
              border: Border.all(color: on ? Palette.amber : Palette.stone0, width: 2),
            ),
            child: Text(label, style: Txt.label(size: 15, color: on ? Palette.amber : Palette.cream, weight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [tab('Hero', false), const SizedBox(width: 8), tab('Heroine', true)],
    );
  }
}
