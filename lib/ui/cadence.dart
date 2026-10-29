// How often an animated scene redraws. It aims for a frame rate (60 on a computer, 30 for gentle
// idle motion on a phone) but always in whole screen refreshes, so the rhythm stays even: every
// refresh on a 60 Hz screen, every other on 120/144 Hz, every third on 165 Hz. (Drawing at a fast
// monitor's full rate is all cost; a timer that ignores the refresh makes an uneven, juddery beat.)

import 'dart:math' as math;

class Cadence {
  double _refresh = 16.7, _last = -1;
  int _since = 0;

  /// Call on every ticker tick with the ticker's time in ms; true when it's time to draw.
  bool tick(double ms, {double fps = 60}) {
    if (_last >= 0) {
      final dt = ms - _last;
      if (dt > 0) _refresh = _refresh * .95 + dt.clamp(2.0, 40.0) * .05;
    }
    _last = ms;
    final every = math.max(1, (1000 / fps / _refresh).round());
    if (++_since >= every) {
      _since = 0;
      return true;
    }
    return false;
  }
}
