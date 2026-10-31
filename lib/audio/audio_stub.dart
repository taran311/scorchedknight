// No sound off the web (tests, other platforms).
import 'audio.dart';

void unlock() {}
void play(Sfx s, double power) {}
void music(String? track) {}
void configure(double music, double sound, bool muted) {}

/// A line on how sound is doing (the app only).
String? report() => null;
