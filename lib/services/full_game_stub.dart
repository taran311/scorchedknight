// No buying on the web: the full game is in the Android app.
import 'full_game.dart';

bool get supported => false;
Future<void> init(FullGame g) async {}
Future<void> buy(FullGame g) async {}
Future<void> restore(FullGame g) async {}
