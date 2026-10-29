// Painted art: the knight in each armour tier, Vharrax, the inn and the burning village. Loaded
// once at start-up from assets/art/. Anything missing falls back to the art drawn in code.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class Sprites {
  Sprites._();

  static final Map<String, ui.Image> _images = {};

  static const _files = [
    'knight_padded.png',
    'knight_mail.png',
    'knight_plate.png',
    'knight_gilded.png',
    'heroine_padded.png',
    'heroine_mail.png',
    'heroine_plate.png',
    'heroine_gilded.png',
    'vharrax.png',
    'inn_ruined.jpg',
    'inn_repaired.jpg',
    'village_burning.jpg',
  ];

  /// The image called [name] (its file name without the extension), once loaded.
  static ui.Image? get(String? name) => name == null ? null : _images[name];

  static Future<void> load() async {
    await Future.wait([
      for (final f in _files)
        () async {
          try {
            final data = await rootBundle.load('assets/art/$f');
            final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
            _images[f.substring(0, f.lastIndexOf('.'))] = (await codec.getNextFrame()).image;
          } catch (_) {
            // Missing or unreadable: the drawn-in-code art stands in.
          }
        }(),
    ]);
  }

  /// Draws [img] so it covers [dst] like a background photo (cropping the overflow, centred).
  static void cover(ui.Canvas c, ui.Image img, ui.Rect dst, {ui.Paint? paint, double alignY = .5}) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final k = (dst.width / iw) > (dst.height / ih) ? dst.width / iw : dst.height / ih;
    final w = dst.width / k, h = dst.height / k;
    final src = ui.Rect.fromLTWH((iw - w) / 2, (ih - h) * alignY, w, h);
    c.drawImageRect(img, src, dst, paint ?? (ui.Paint()..filterQuality = ui.FilterQuality.medium));
  }
}
