import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import 'tram_component.dart';

class _SmokePuff {
  _SmokePuff({required this.x, required this.y, required this.dark});

  double x;
  double y;
  double age = 0;
  final bool dark;
}

/// Layer 6 (atmosphere): rising brake-overheat puffs and dark wreck smoke.
class SmokeComponent extends Component {
  /// Creates an atmospheric smoke emitter observing [trams].
  SmokeComponent({required this.trams})
    : super(priority: RenderLayer.atmosphere.priority + 2);

  /// Active trams monitored for brake overheat and surface wreck smoke.
  final List<TramComponent> trams;

  /// Maximum number of live smoke puffs retained at once.
  static const int maxPuffs = 64;

  /// Lifetime of each emitted puff in seconds.
  static const double puffDurationSec = 0.9;

  final List<_SmokePuff> _puffs = [];
  final Map<TramComponent, double> _cooldowns = {};
  int _serial = 0;

  /// Current number of active smoke puffs in flight.
  int get puffCount => _puffs.length;

  @override
  void update(double dt) {
    super.update(dt);
    for (final puff in _puffs) {
      puff.age += dt;
      puff.x += 10 * dt;
      puff.y -= 18 * dt;
    }
    _puffs.removeWhere((p) => p.age >= puffDurationSec);

    for (final tram in trams) {
      final hotBrakes = !tram.isCrashed && tram.brakeHeat > 0.7;
      final surfaceWreck =
          tram.isCrashed && tram.priority >= RenderLayer.entities.priority;
      if (!hotBrakes && !surfaceWreck) {
        _cooldowns.remove(tram);
        continue;
      }
      final interval = hotBrakes ? 0.09 : 0.18;
      final remaining = (_cooldowns[tram] ?? 0) - dt;
      if (remaining <= 0) {
        _cooldowns[tram] = interval;
        _emitPuff(tram.position, dark: surfaceWreck);
      } else {
        _cooldowns[tram] = remaining;
      }
    }
  }

  void _emitPuff(Vector2 origin, {required bool dark}) {
    if (_puffs.length >= maxPuffs) {
      _puffs.removeAt(0);
    }
    final jitter = ((_serial++ % 5) - 2) * 1.5;
    _puffs.add(
      _SmokePuff(x: origin.x + jitter, y: origin.y - jitter, dark: dark),
    );
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    for (final puff in _puffs) {
      final t = (puff.age / puffDurationSec).clamp(0.0, 1.0);
      final radius = 4.0 + 9.0 * t;
      final maxAlpha = puff.dark ? 165 : 120;
      final alpha = ((1.0 - t) * maxAlpha).round();
      paint.color = puff.dark
          ? Color.fromARGB(alpha, 0x1E, 0x20, 0x26)
          : Color.fromARGB(alpha, 0x4A, 0x4E, 0x58);
      canvas.drawCircle(Offset(puff.x, puff.y), radius, paint);
    }
  }
}
