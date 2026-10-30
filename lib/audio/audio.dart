// Sound for Scorched Knight: synthesised sound effects (no files needed) and music tracks played
// from web/music/. In the browser they're built live with Web Audio (audio_web.dart); in the app
// the same recipes are rendered to little WAV files and played natively (audio_native.dart). Browsers only allow sound after the player has clicked or pressed a key, so the app
// calls [Audio.unlock] on the first one.

import 'package:flutter/widgets.dart';

import 'audio_stub.dart' if (dart.library.js_interop) 'audio_web.dart' if (dart.library.io) 'audio_native.dart' as impl;

/// Every sound effect the game makes.
enum Sfx {
  swing, // a blade cuts the air
  hit, // a blow lands on flesh
  crit, // a big one
  bash, // a shield or Mighty Blow thud
  boneHit, // on skeletons: a dry crack
  stoneHit, // on gargoyles and golems: a chip of rock
  miss, // a whiff
  clang, // steel on steel: a parry
  block, // a blow caught on a shield
  hurt, // you're hit
  shoot, // the crossbow
  castFire,
  castFrost,
  castHoly,
  castDark,
  potion, // glug
  coins,
  levelUp,
  victory,
  defeat,
  flee,
  quest, // a quest accepted or done
  click, // a button
  rareDrop, // a blue or better drop: a bright sparkle
  epicDrop, // purple: a rising chime
  legendaryDrop, // orange: a bell, a shimmer and a choir-ish swell
}

class Audio {
  Audio._();

  /// Call on the player's first click or key press: browsers keep sound off until then.
  static void unlock() => impl.unlock();

  /// Plays a sound effect. [power] (about 0.5 to 1.5) makes it softer or bigger.
  static void play(Sfx s, {double power = 1}) => impl.play(s, power);

  /// Fades to [track] (a file name in web/music/ without ".mp3"), or to silence with null.
  static void music(String? track) => impl.music(track);

  /// Volumes from the settings.
  static void configure({required double music, required double sound, required bool muted}) => impl.configure(music, sound, muted);
}

/// Plays [track] while this widget is on screen; leaving it brings back whatever was playing
/// before (so the battle music hands back to the trail's when you return).
class MusicZone extends StatefulWidget {
  const MusicZone({super.key, required this.track, required this.child});
  final String track;
  final Widget child;

  @override
  State<MusicZone> createState() => _MusicZoneState();
}

final _zones = <_MusicZoneState>[];

class _MusicZoneState extends State<MusicZone> {
  @override
  void initState() {
    super.initState();
    _zones.add(this);
    Audio.music(widget.track);
  }

  @override
  void didUpdateWidget(MusicZone old) {
    super.didUpdateWidget(old);
    if (old.track != widget.track && identical(_zones.lastOrNull, this)) Audio.music(widget.track);
  }

  @override
  void dispose() {
    final top = identical(_zones.lastOrNull, this);
    _zones.remove(this);
    if (top) Audio.music(_zones.lastOrNull?.widget.track);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
