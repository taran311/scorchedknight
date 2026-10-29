// Runs Scorched Knight's dev server and keeps it up to date by itself:
// - by default it's a release build: smooth to play, and any change rebuilds it from scratch
//   (about a minute; refresh the page when it says it's ready). `run_web.bat debug` runs the
//   debug build instead, which picks up changes in seconds but plays noticeably slower;
// - a change to any .dart file under lib/ recompiles the game (refresh the page to see it);
// - a change to pubspec.yaml or assets/ (new packages or art) relaunches it from scratch;
// - if the game fails to compile, it waits for the next change and tries again.
// Started by run_web.bat: dart tool/dev.dart [extra flutter run arguments]
//
// It drives `flutter run --machine`, the same JSON channel VS Code uses, so restarts don't depend
// on keypresses reaching Flutter. Keys still work here: r or R recompiles, q quits.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const url = 'http://localhost:5070';

/// Everything printed here also goes to .dart_tool/dev.log, so problems can be read afterwards.
final _log = File('.dart_tool/dev.log')..createSync(recursive: true);

void say(String s) {
  stdout.writeln(s);
  _log.writeAsStringSync('$s\n', mode: FileMode.append);
}

/// A server from an earlier run can outlive its window and keep hold of the port. Stops it if
/// it's a Dart process (Flutter's); anything else on the port is left alone and reported.
Future<void> _freePort() async {
  if (!Platform.isWindows) return;
  final net = await Process.run('netstat', ['-ano', '-p', 'TCP']);
  final pids = <String>{};
  for (final line in (net.stdout as String).split('\n')) {
    final cols = line.trim().split(RegExp(r'\s+'));
    if (cols.length >= 5 && cols[1].endsWith(':5070') && cols[3] == 'LISTENING') pids.add(cols[4]);
  }
  for (final pid in pids) {
    final task = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH']);
    if ((task.stdout as String).toLowerCase().contains('dart')) {
      say('[dev] An earlier Scorched Knight server is still running (process $pid). Stopping it.');
      await Process.run('taskkill', ['/F', '/T', '/PID', pid]);
    } else {
      say('[dev] Port 5070 is in use by another program (process $pid): ${(task.stdout as String).trim()}');
    }
  }
  if (pids.isNotEmpty) await Future<void>.delayed(const Duration(seconds: 2));
}

/// One `flutter run`: from launch until it exits.
class _Session {
  _Session(this.flutter);
  final Process flutter;
  String? appId;
  var nextId = 1, busy = false, again = false;

  void send(String method, Map<String, Object?> params) {
    try {
      flutter.stdin.writeln(jsonEncode([
        {'id': nextId++, 'method': method, 'params': params},
      ]));
    } catch (_) {
      // It has already gone.
    }
  }

  void restart(String why) {
    if (appId == null) return;
    if (busy) {
      again = true;
      return;
    }
    busy = true;
    say('[dev] $why: recompiling...');
    send('app.restart', {'appId': appId, 'fullRestart': true, 'pause': false, 'reason': 'manual'});
  }

  void stop() {
    if (appId != null) send('app.stop', {'appId': appId});
    Timer(const Duration(seconds: 4), flutter.kill);
  }
}

var _opened = false, _quitting = false;
_Session? _current;
Completer<String>? _waiting;

Future<int> _run(List<String> args) async {
  await _freePort();
  final flutter = await Process.start('flutter', ['run', '--machine', '-d', 'web-server', '--web-port', '5070', ...args], runInShell: true);
  final s = _current = _Session(flutter);

  void handle(Map<String, dynamic> m) {
    final event = m['event'] as String?, p = (m['params'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (event == null) {
      // The answer to a restart.
      if (m.containsKey('id') && s.busy) {
        s.busy = false;
        final err = m['error'];
        say(err == null ? '[dev] Done. Refresh the page (F5) to see it.' : '[dev] Restart failed: $err');
        if (s.again) {
          s.again = false;
          s.restart('More changes');
        }
      }
      return;
    }
    switch (event) {
      case 'app.start':
        s.appId = p['appId'] as String?;
      case 'app.started':
        say('[dev] Scorched Knight is running at $url${_opened ? ' (refresh the page to see the changes)' : ''}');
        if (!_opened) {
          _opened = true;
          if (Platform.isWindows) Process.run('cmd', ['/c', 'start', '', url]);
        }
      case 'app.log':
        final log = p['log'];
        if (log is String && log.trim().isNotEmpty) say(log.trimRight());
      case 'daemon.logMessage':
        final msg = p['message'];
        if (msg is String && msg.trim().isNotEmpty) say(msg.trimRight());
      case 'app.progress':
        final msg = p['message'];
        if (msg is String && msg.isNotEmpty && p['finished'] != true) say(msg);
      case 'app.stop':
        say('[dev] Stopped.${p['error'] != null ? ' ${p['error']}' : ''}');
    }
  }

  final out = flutter.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    final t = line.trim();
    if (t.startsWith('[{') && t.endsWith('}]')) {
      try {
        for (final m in (jsonDecode(t) as List).cast<Map<String, dynamic>>()) {
          handle(m);
        }
        return;
      } on FormatException {
        // Not JSON after all: print it as it is.
      }
    }
    if (t.isNotEmpty) say(line);
  }).asFuture<void>();
  final err = flutter.stderr.listen((b) {
    stderr.add(b);
    _log.writeAsBytesSync(b, mode: FileMode.append);
  }).asFuture<void>();

  final code = await flutter.exitCode;
  await Future.wait([out, err]);
  _current = null;
  return code;
}

Future<void> main(List<String> argv) async {
  _log.writeAsStringSync('[dev] started ${DateTime.now()}\n');
  final debug = argv.contains('debug'), wasm = argv.contains('wasm');
  // `run_web.bat wasm`: the WebAssembly build, which draws the scenes noticeably faster (browsers
  // without WebAssembly GC fall back to the normal build on their own).
  final args = [...argv.where((a) => a != 'debug' && a != 'wasm'), if (!debug) '--release', if (wasm) '--wasm'];
  say(debug ? '[dev] Debug build: quick to update, slower to play.' : '[dev] Release build${wasm ? ' (WebAssembly)' : ''}: smooth to play. Each change rebuilds it (about a minute).');

  // Keys typed in this window.
  try {
    stdin
      ..lineMode = false
      ..echoMode = false;
  } on StdinException {
    // Not a console: keys arrive a line at a time instead.
  }
  stdin.transform(utf8.decoder).listen((text) {
    for (final ch in text.split('')) {
      if (ch == 'r' || ch == 'R') {
        if (debug) {
          _current?.restart('You pressed $ch');
        } else {
          say('[dev] You pressed $ch: rebuilding...');
          _current?.stop();
        }
      }
      if (ch == 'q' || ch == 'Q') {
        _quitting = true;
        final s = _current;
        if (s == null) exit(0);
        s.stop();
      }
    }
  }, onError: (_) {});

  // Code changes recompile; pubspec or art changes relaunch. A burst of saves counts once.
  Timer? pending;
  var relaunch = false;
  void changed(String path, {bool full = false}) {
    // A release build can't be patched in place: every change relaunches it.
    relaunch = relaunch || full || !debug;
    pending?.cancel();
    pending = Timer(const Duration(milliseconds: 900), () {
      final w = _waiting;
      if (w != null && !w.isCompleted) {
        w.complete(path);
      } else if (relaunch) {
        say('[dev] $path changed: relaunching...');
        _current?.stop();
      } else {
        _current?.restart('$path changed');
      }
      relaunch = false;
    });
  }

  Directory('lib').watch(recursive: true).listen((e) {
    if (e.path.endsWith('.dart')) changed(e.path);
  });
  File('pubspec.yaml').parent.watch().listen((e) {
    if (e.path.endsWith('pubspec.yaml')) changed('pubspec.yaml', full: true);
  });
  if (Directory('assets').existsSync()) {
    Directory('assets').watch(recursive: true).listen((e) => changed(e.path, full: true));
  }

  while (true) {
    final started = DateTime.now();
    final code = await _run(args);
    if (_quitting) {
      await stdout.flush();
      exit(code);
    }
    // Stopped for a relaunch: go straight round. Failed: wait for the fix.
    if (DateTime.now().difference(started).inSeconds > 5 && code == 0) continue;
    say('[dev] The game stopped. Fix the error above and save: it will start again by itself.');
    _waiting = Completer<String>();
    final path = await _waiting!.future;
    _waiting = null;
    say('[dev] $path changed: trying again...');
  }
}
