// The game's look: every figure is backlit. A soft halo and a crisp rim of the scene's light
// catch its edges, and the figure itself sits in shadow: dimmed and tinted by the light, but with
// its armour, cape and face still showing.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Draws [draw] as a backlit silhouette within [bounds]. [rim] is the colour of the light behind
/// it (the sky's glow, a fire), [light] which way that light sits (it catches those edges).
void silhouette(
  Canvas c,
  Rect bounds,
  void Function(Canvas) draw, {
  required Color rim,
  Offset light = const Offset(1.8, -2.0),
  double detail = .5,
  Color body = const Color(0xFF0D0908),
  double halo = .5,
  bool lite = false,
}) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec, bounds));
  final pic = rec.endRecording();
  // (Not disposed: on the web the frame is drawn later, and still needs it.)
  silhouettePicture(c, pic, bounds, rim: rim, light: light, detail: detail, body: body, halo: halo, lite: lite);
}

/// The same, for figures already recorded into [pic].
void silhouettePicture(
  Canvas c,
  ui.Picture pic,
  Rect bounds, {
  required Color rim,
  Offset light = const Offset(2.4, -2.6),
  double detail = .5,
  Color body = const Color(0xFF0D0908),
  double halo = .5,
  bool lite = false,
}) {
  // [lite] (phones): the halo's blur and the faint second rim are the costliest layers, and on a
  // small screen they barely show, so they're left out there.
  if (lite) halo = 0;
  // A soft halo of light bleeding round the figure.
  if (halo > 0) {
    c.saveLayer(
      bounds,
      Paint()
        ..colorFilter = ColorFilter.mode(rim.withValues(alpha: halo), BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7, tileMode: TileMode.decal),
    );
    c.drawPicture(pic);
    c.restore();
  }
  // The rim: the figure in pure light, nudged toward the light (and a fainter one the other
  // way), so a bright edge shows round the dark shape laid on top.
  c.saveLayer(bounds, Paint()..colorFilter = ColorFilter.mode(rim, BlendMode.srcIn));
  c.save();
  c.translate(light.dx, light.dy);
  c.drawPicture(pic);
  c.restore();
  c.restore();
  if (!lite) {
    c.saveLayer(bounds, Paint()..colorFilter = ColorFilter.mode(rim.withValues(alpha: .45), BlendMode.srcIn));
    c.save();
    c.translate(-light.dx * .7, light.dy * .4);
    c.drawPicture(pic);
    c.restore();
    c.restore();
  }
  // The body: near-black, with a faint ghost of its own colours (a red cape, a gold trim).
  final d = detail, k = 255 * (1 - d);
  c.saveLayer(
    bounds,
    Paint()
      // Dimmed toward shadow, with a little of the scene's light washed in.
      ..colorFilter = ColorFilter.matrix([
        d, 0, 0, 0, body.r * k + rim.r * 18, //
        0, d, 0, 0, body.g * k + rim.g * 18,
        0, 0, d, 0, body.b * k + rim.b * 18,
        0, 0, 0, 1, 0,
      ]),
  );
  c.drawPicture(pic);
  c.restore();
}

/// A stretch of the figures, recorded on its own so a tint or a fade can be laid on it once, in
/// the body's pass, rather than inside the picture where every pass (halo, rims, body) paid for it
/// again: a struck foe's flash, the afterimages of a charge and a hurt knight's red each used to
/// cost a whole extra layer four times over, every frame they showed, which is what dropped
/// frames on a blow. [rim]: whether it catches the light at all (afterimages don't).
class FigureRun {
  const FigureRun(this.pic, {this.tint, this.alpha = 1, this.rim = true, this.bounds});
  final ui.Picture pic;

  /// Where it draws, if known: its tint or fade is then a layer only that big. (A layer the size
  /// of the whole stage, every frame, for a tough foe's darker hue or a pack's shade, was a steady
  /// cost on a phone all fight long.)
  final Rect? bounds;
  final ColorFilter? tint;
  final double alpha;
  final bool rim;
}

/// [silhouettePicture], for figures recorded in [runs].
void silhouetteRuns(
  Canvas c,
  List<FigureRun> runs,
  Rect bounds, {
  required Color rim,
  Offset light = const Offset(2.4, -2.6),
  double detail = .5,
  Color body = const Color(0xFF0D0908),
  double halo = .5,
  bool lite = false,
}) {
  if (lite) halo = 0;
  // In the light's passes only the shape counts: tints are left off, fades kept.
  void shapes() {
    for (final r in runs) {
      if (!r.rim || r.alpha <= 0) continue;
      if (r.alpha < 1) c.saveLayer(r.bounds ?? bounds, Paint()..color = Color.fromRGBO(0, 0, 0, r.alpha));
      c.drawPicture(r.pic);
      if (r.alpha < 1) c.restore();
    }
  }

  if (halo > 0) {
    c.saveLayer(
      bounds,
      Paint()
        ..colorFilter = ColorFilter.mode(rim.withValues(alpha: halo), BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7, tileMode: TileMode.decal),
    );
    shapes();
    c.restore();
  }
  c.saveLayer(bounds, Paint()..colorFilter = ColorFilter.mode(rim, BlendMode.srcIn));
  c.save();
  c.translate(light.dx, light.dy);
  shapes();
  c.restore();
  c.restore();
  if (!lite) {
    c.saveLayer(bounds, Paint()..colorFilter = ColorFilter.mode(rim.withValues(alpha: .45), BlendMode.srcIn));
    c.save();
    c.translate(-light.dx * .7, light.dy * .4);
    shapes();
    c.restore();
    c.restore();
  }
  final d = detail, k = 255 * (1 - d);
  c.saveLayer(
    bounds,
    Paint()
      ..colorFilter = ColorFilter.matrix([
        d, 0, 0, 0, body.r * k + rim.r * 18, //
        0, d, 0, 0, body.g * k + rim.g * 18,
        0, 0, d, 0, body.b * k + rim.b * 18,
        0, 0, 0, 1, 0,
      ]),
  );
  for (final r in runs) {
    if (r.alpha <= 0) continue;
    final layered = r.tint != null || r.alpha < 1;
    if (layered) c.saveLayer(r.bounds ?? bounds, Paint()..color = Color.fromRGBO(0, 0, 0, r.alpha)..colorFilter = r.tint);
    c.drawPicture(r.pic);
    if (layered) c.restore();
  }
  c.restore();
}
