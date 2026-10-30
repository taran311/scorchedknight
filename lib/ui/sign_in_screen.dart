// The first screen when cloud saves are on: sign in (Google, email, or Facebook when it's on) so your hero is kept safe and
// follows you between the browser and the Android app, or play without an account (the hero stays
// on this device, and you can sign in later from Settings).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/looks.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart' show shinesAt, sootFor;
import '../game/models.dart';
import 'account_panel.dart';
import 'hero_view.dart';
import 'hud.dart' show CrestPainter;
import 'theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller, k = c.state.knight;
    // Your own hero if this device has one; otherwise a fresh, sooty knight.
    final look = k.classChosen ? heroLook(k) : lookFor(HeroClass.knight, Loadout.starter(HeroClass.knight), soot: sootFor(1), shine: shinesAt(1));
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xFF4A2618), Color(0xFF17100C), Color(0xFF0B0806)], stops: [0, .55, 1]),
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _Embers())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                // On a short phone everything tightens up, so the buttons are on screen without scrolling.
                final short = viewport.maxHeight < 760;
                return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, short ? 8 : 24, 20, short ? 8 : 24),
                child: RepaintBoundary(child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight - (short ? 16 : 48)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!short) ...[
                            const SizedBox(width: 52, height: 62, child: CustomPaint(painter: CrestPainter())),
                            const SizedBox(height: 12),
                          ],
                          FittedBox(child: Text('SCORCHED KNIGHT', style: Txt.logo().copyWith(fontSize: 38, letterSpacing: 2))),
                          const SizedBox(height: 4),
                          Text('Survive the ashfall. Slay the flame.', textAlign: TextAlign.center, style: Txt.label(size: 17, color: Palette.parch2)),
                          SizedBox(height: short ? 6 : 18),
                          SizedBox(height: short ? 96 : 230, width: short ? 80 : 180, child: HeroFigure(look: look)),
                          SizedBox(height: short ? 6 : 18),
                          Stone(
                            padding: EdgeInsets.all(short ? 10 : 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(k.classChosen ? 'Welcome back, ${c.state.settings.name}' : 'Sign in to begin', style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text('Your hero is saved to your account: safe if this device is lost, and waiting for you on your phone or in any browser.', style: Txt.onStone(size: short ? 12.5 : 13.5)),
                                SizedBox(height: short ? 8 : 14),
                                // On success the app moves on by itself (and fetches your hero from the cloud).
                                AccountPanel(compact: short),
                                SizedBox(height: short ? 4 : 10),
                                TextButton(
                                  onPressed: c.playAsGuest,
                                  child: Text('Play without an account', style: Txt.label(size: 14, color: Palette.parch)),
                                ),
                                Text('Your hero stays on this device. You can sign in any time from Settings.', textAlign: TextAlign.center, style: Txt.onStone(size: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
              );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while your hero comes down from the cloud after signing in.
class FetchingHeroScreen extends StatelessWidget {
  const FetchingHeroScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Palette.amber),
          const SizedBox(height: 14),
          Text('Fetching your hero…', style: Txt.label(size: 16, color: Palette.parch)),
        ],
      ),
    ),
  );
}

/// Google's "G", drawn in its four colours (no image needed).
class GoogleGPainter extends CustomPainter {
  const GoogleGPainter();

  @override
  void paint(Canvas c, Size size) {
    final r = size.width / 2, centre = Offset(r, r), w = size.width * .2;
    final rect = Rect.fromCircle(center: centre, radius: r - w / 2);
    Paint arc(int argb) => Paint()
      ..color = Color(argb)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    // Red top, yellow left-bottom, green bottom, blue right (going round from the top right).
    c.drawArc(rect, -math.pi * .25, -math.pi * .55, false, arc(0xFFEA4335));
    c.drawArc(rect, -math.pi * .8, -math.pi * .45, false, arc(0xFFFBBC05));
    c.drawArc(rect, math.pi * .75, -math.pi * .5, false, arc(0xFF34A853));
    c.drawArc(rect, math.pi * .25, -math.pi * .25, false, arc(0xFF4285F4));
    c.drawRect(Rect.fromLTWH(r, r - w / 2, r - w * .2, w), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(GoogleGPainter old) => false;
}

/// Embers drifting up the screen.
class _Embers extends StatefulWidget {
  const _Embers();

  @override
  State<_Embers> createState() => _EmbersState();
}

class _EmbersState extends State<_Embers> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1000.0);
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _EmberPainter(_t)));
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.t) : super(repaint: t);
  final ValueNotifier<double> t;

  @override
  void paint(Canvas c, Size size) {
    final time = t.value;
    for (var i = 0; i < 46; i++) {
      final speed = .02 + (i % 7) * .006, x0 = (i * 97.3) % size.width;
      final p = ((time * speed / size.height) + i * .137) % 1.0;
      final x = x0 + math.sin(time / 900 + i) * 18;
      final y = size.height * (1 - p);
      final a = math.sin(p * math.pi) * (.35 + (i % 4) * .15);
      c.drawCircle(Offset(x, y), 1.2 + (i % 3) * .8, Paint()..color = Color.fromRGBO(255, 150 + (i % 5) * 18, 70, a));
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => false;
}
