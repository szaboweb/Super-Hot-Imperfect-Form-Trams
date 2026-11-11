import 'dart:ui';

/// Paint for crisp pixel-art: nearest-neighbour sampling, no smoothing.
Paint pixelArtPaint() => Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false;
