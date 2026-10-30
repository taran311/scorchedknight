// ?trace: a frame-by-frame record of the fight (how long each frame took, where the knight and
// the foe were, which move was playing), so animations can be checked as numbers instead of by
// eye. In the browser, window.skTrace() returns it as JSON and window.skTraceClear() empties it.

import 'dart:convert';

import 'trace_hook_stub.dart' if (dart.library.js_interop) 'trace_hook_web.dart';

final bool tracing = Uri.base.queryParameters.containsKey('trace');

final List<Map<String, Object?>> _rows = [];
bool _hooked = false;

/// Records one frame (only with ?trace in the address).
void traceFrame(Map<String, Object?> row) {
  if (!tracing) return;
  if (!_hooked) {
    _hooked = true;
    hookTrace(() => jsonEncode(_rows), _rows.clear);
  }
  _rows.add(row);
  if (_rows.length > 6000) _rows.removeRange(0, 1000);
}

/// The record so far, as JSON (compact: only the frames of the last few moves).
String traceDump() => jsonEncode(_rows.length > 700 ? _rows.sublist(_rows.length - 700) : _rows);

/// Marks a moment worth finding in the record (a move starting, a blow landing).
void traceMark(String what) => traceFrame({'mark': what});
