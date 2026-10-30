// Scorched Knight: survive the ashfall, slay the flame. A cartoony turn-based fantasy RPG.
// The hero is kept on the device; sign in with Google (the first screen, or Settings) and it
// follows you between the browser and the Android app (services/cloud.dart).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio/audio.dart';
import 'services/cloud.dart';

import 'game/controller.dart';
import 'ui/armoury.dart';
import 'ui/bestiary.dart';
import 'ui/lands_preview.dart';
import 'ui/class_picker.dart';
import 'ui/inn_page.dart';
import 'ui/sign_in_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Slow motion for checking animations: open http://localhost:5070/?slow=6
  final slow = double.tryParse(Uri.base.queryParameters['slow'] ?? '');
  if (slow != null && slow >= 1) timeDilation = slow;
  // Browsers keep sound off until the player does something: the first key press turns it on.
  HardwareKeyboard.instance.addHandler((_) {
    Audio.unlock();
    return false;
  });
  // Phones: dark status and navigation bars to match the game.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF14110D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // Cloud saves, if this build has Firebase set up (otherwise this quietly does nothing); and
  // every face of the game's fonts, fetched before the first frame. (They used to load as they
  // were first needed: the title flashed up in a plain font, and the first bold banner or damage
  // number of a session made the text around it jump as its face arrived mid-fight.)
  await Future.wait([CloudSave.instance.init(), _fonts()]);
  runApp(const ScorchedKnightApp());
}

Future<void> _fonts() async {
  try {
    for (final w in const [FontWeight.w400, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900]) {
      GoogleFonts.alegreyaSansSc(fontWeight: w);
      GoogleFonts.alegreyaSans(fontWeight: w);
    }
    GoogleFonts.alegreyaSans(fontStyle: FontStyle.italic);
    GoogleFonts.alegreyaSans(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700);
    GoogleFonts.cinzel(fontWeight: FontWeight.w900);
    GoogleFonts.cinzel(fontWeight: FontWeight.w700);
    // A slow connection doesn't hold the game up for long: anything still on its way arrives late.
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 5));
  } catch (_) {}
}

class ScorchedKnightApp extends StatefulWidget {
  const ScorchedKnightApp({super.key, this.controller});

  /// A ready-made controller (tests pass one in); otherwise the saved hero is loaded.
  final GameController? controller;

  @override
  State<ScorchedKnightApp> createState() => _ScorchedKnightAppState();
}

class _ScorchedKnightAppState extends State<ScorchedKnightApp> {
  late final GameController _game = widget.controller ?? (GameController(cloud: CloudSave.instance.available ? CloudSave.instance : null)..load());
  final _nav = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _life;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    // Put away (tab hidden, app sent to the background): the latest save goes up now.
    _life = AppLifecycleListener(onHide: () => unawaited(_game.flushCloud()), onPause: () => unawaited(_game.flushCloud()));
    _game.addListener(_askAboutCloud);
  }

  @override
  void dispose() {
    _life.dispose();
    _game.removeListener(_askAboutCloud);
    if (widget.controller == null) _game.dispose();
    super.dispose();
  }

  /// A newer save turned up in the cloud than the one here: ask which to play.
  void _askAboutCloud() {
    final copy = _game.cloudChoice, ctx = _nav.currentContext;
    if (copy == null || _asking || ctx == null) return;
    _asking = true;
    final here = GameController.cloudSummary(_game.state);
    showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.stone2,
        title: Text('Two saves found', style: Txt.label(size: 18, color: Palette.amber)),
        content: Text(
          'Your cloud save is newer than the one on this device.\n\nCloud: ${copy.summary}\nThis device: $here\n\nWhich hero do you want to play?',
          style: Txt.onStone(size: 14, color: Palette.cream),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Keep this device\'s', style: Txt.label(size: 14))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Play the cloud save', style: Txt.label(size: 14, color: Palette.amber))),
        ],
      ),
    ).then((cloud) async {
      if (cloud == true) {
        await _game.adoptCloud(copy);
      } else {
        await _game.keepDeviceSave();
      }
      _asking = false;
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    // ...and so does the first click or tap.
    onPointerDown: (_) => Audio.unlock(),
    child: ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        final st = _game.loaded ? _game.state.settings : null;
        if (st != null) Audio.configure(music: st.music, sound: st.sound, muted: st.muted);
        return _app(context);
      },
    ),
  );

  Widget _app(BuildContext context) => MaterialApp(
    navigatorKey: _nav,
    title: 'Scorched Knight',
    // Phones have no hover: every little tip in the game opens with a tap instead.
    builder: (context, child) => isPhone(context)
        ? TooltipTheme(data: TooltipTheme.of(context).copyWith(triggerMode: TooltipTriggerMode.tap, showDuration: const Duration(seconds: 3)), child: child!)
        : child!,
    debugShowCheckedModeBanner: false,
    navigatorObservers: [townRoutes],
    theme: buildTheme(),
    home: ListenableBuilder(
      listenable: Listenable.merge([_game, CloudSave.instance]),
      builder: (context, _) {
        if (Uri.base.queryParameters.containsKey('armoury')) return const ArmouryPreview();
        if (Uri.base.queryParameters.containsKey('lands')) return const LandsPreview();
        if (Uri.base.queryParameters.containsKey('bestiary')) return const BestiaryPreview();
        final cloud = CloudSave.instance;
        if (!_game.loaded || (cloud.available && !cloud.authKnown)) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.amber)));
        // Cloud saves on: sign in (or choose to play without an account) first.
        if (widget.controller == null && cloud.available && !cloud.signedIn && !_game.state.settings.guest) {
          return MusicZone(key: const ValueKey('signin'), track: 'title', child: SignInScreen(controller: _game));
        }
        // Just signed in on a new device: wait for the hero to come down before the cutscene.
        if (cloud.signedIn && _game.syncing && !_game.state.knight.classChosen) return const FetchingHeroScreen();
        // A new hero sits through the cutscene and picks a name first; then a slow fade into the inn.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          switchInCurve: Curves.easeOut,
          child: !_game.state.knight.classChosen
              ? MusicZone(key: const ValueKey('pick'), track: 'title', child: ClassPickerScreen(controller: _game))
              : MusicZone(key: ValueKey('inn-${_game.state.knight.heroClass.name}'), track: 'town', child: InnPage(controller: _game)),
        );
      },
    ),
  );
}
