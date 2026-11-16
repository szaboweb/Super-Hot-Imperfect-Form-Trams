import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../core/game_log.dart';
import '../../input/tram_controls.dart';
import '../graphics/pixel_art.dart';
import '../graphics/render_layer.dart';
import '../systems/track_path.dart';
import '../systems/turntable_ride.dart';
import '../systems/turntable_switch_system.dart';

/// Layer 4 (entities): tram that rides a [TrackPath]; drawn from a pixel-art
/// [sprite] (Blender render cleaned up in Aseprite) or, when none is set, with Canvas shapes.
/// On a turntable it rides the rotating disc and leaves on the other loop.
class TramComponent extends PositionComponent with KeyboardHandler {
  TramComponent({
    required this.path,
    this.sprite,
    this.controls,
    this.trackDistance = 0,
    this.speed = 0,
    this.color = const Color(0xFFE4572E),
  }) : super(
         size: Vector2(20, 56),
         anchor: Anchor.center,
         priority: RenderLayer.entities.priority,
       ) {
    _snapToPath();
  }

  /// The path the tram rides; changes to the other loop after a turntable turn.
  TrackPath path;
  Sprite? sprite;

  static const double maxSpeed = 320;
  static const double acceleration = 220;
  static const double drag = 0.8;

  /// Half the tram length in px (the nose/tail reach used by turntables).
  static const double halfLength = 28;

  /// Minimum |speed| (px/s) at which braking leaves skid marks.
  static const double skidMinSpeed = 60;

  /// Minimum braking multiplier when brakes are fully overheated (0..1).
  static const double minBrakeEfficiency = 0.25;

  /// -1 (brake/reverse) .. 1 (accelerate)
  double throttle = 0;

  /// Signed speed along the path in px/s.
  double speed;

  /// Px the tram has travelled along [path].
  double trackDistance;

  /// 0 (cool) .. 1 (overheated); rises while braking hard.
  double brakeHeat = 0;

  /// True once this tram has crashed; freezes movement and ignores turn signals.
  bool isCrashed = false;

  /// Current braking multiplier from 1.0 (cool) down to [minBrakeEfficiency] (overheated).
  double get brakeEfficiency => 1.0 - brakeHeat * (1.0 - minBrakeEfficiency);

  /// Called every frame the tram is skidding (braking while moving).
  void Function(Vector2 position, double angle)? onSkid;

  /// Body colour of the Canvas fallback; also used by the HUD and mini-map.
  final Color color;

  /// Keyboard layout that drives this tram; null = not player controlled.
  final TramControls? controls;

  TurntableRide? _ride;

  /// Seconds until this tram may send another SHIFT signal.
  double _signalCooldown = 0;

  /// Latest screen-space directional input held by the player.
  math.Point<double>? _desiredDirection;

  /// The level's turntable rules; null = no turntables (SHIFT does nothing).
  TurntableSwitchSystem? switches;

  /// Optional provider returning platform centres currently occupied by another tram.
  Iterable<math.Point<double>> Function()? occupiedPlatformCenters;

  /// The turntable ride in progress, null while on a normal path.
  TurntableRide? get ride => _ride;

  /// Short name for log lines (the controls label, or AUTO).
  String get label => controls?.label ?? 'AUTO';

  /// Marks this tram as crashed, halting motion and clearing any active turn ride.
  void markCrashed() {
    isCrashed = true;
    speed = 0;
    throttle = 0;
    _ride = null;
  }

  /// The tram's own SHIFT signal: puts this tram on the disc it is on right now (any part of
  /// the tram on the disc counts). Presses closer than [TurntableSwitchSystem.signalCooldownSeconds]
  /// to the previous one are ignored. False (logged as MISS) if it is on no disc.
  bool requestTurn({math.Point<double>? desiredDirection}) {
    final system = switches;
    if (system == null || _ride != null || speed == 0 || isCrashed) {
      return false;
    }
    final key = controls?.switchLabel ?? 'SHIFT';
    if (_signalCooldown > 0) {
      GameLog.event(
        'switch',
        '$label $key: ignored, ${_signalCooldown.toStringAsFixed(2)}s cooldown left',
      );
      return false;
    }
    _signalCooldown = TurntableSwitchSystem.signalCooldownSeconds;
    final decision = system.decide(
      path: path,
      distance: trackDistance,
      speed: speed,
      halfLength: halfLength,
      desiredDirection: desiredDirection ?? _desiredDirection,
      occupiedCenters: occupiedPlatformCenters?.call() ?? const [],
    );
    GameLog.event('switch', decision.describe(tramLabel: label, keyLabel: key));
    _ride = decision.ride;
    return decision.isHit;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final controls = this.controls;
    if (controls == null || isCrashed) return true;
    throttle = controls.throttleFor(keysPressed);
    _desiredDirection = controls.desiredDirectionFor(keysPressed);
    if (event is KeyDownEvent && event.logicalKey == controls.switchKey) {
      requestTurn(desiredDirection: _desiredDirection);
    }
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCrashed) return;
    _signalCooldown = math.max(0, _signalCooldown - dt);
    final isBraking = throttle * speed < 0;
    final effectiveAccel = isBraking
        ? acceleration * brakeEfficiency
        : acceleration;
    final skidding = isBraking && speed.abs() > skidMinSpeed;
    brakeHeat = (brakeHeat + (skidding ? 0.4 : -0.15) * dt).clamp(0.0, 1.0);
    speed += throttle * effectiveAccel * dt;
    speed *= math.pow(drag, dt).toDouble();
    speed = speed.clamp(-maxSpeed / 3, maxSpeed);
    final ride = _ride;
    if (ride == null) {
      trackDistance += speed * dt;
      _snapToPath();
    } else {
      _followRide(ride, dt);
    }
    if (skidding) onSkid?.call(position, angle);
  }

  void _followRide(TurntableRide ride, double dt) {
    ride.advance(dt, speed);
    final p = ride.position;
    position.setValues(p.x, p.y);
    angle = ride.heading;
    if (!ride.finished) return;
    path = ride.exitPath;
    trackDistance = ride.exitDistance;
    _ride = null;
    GameLog.event('tram', '$label left the turntable, now rides ${path.name}');
  }

  void _snapToPath() {
    final p = path.positionAt(trackDistance);
    position.setValues(p.x, p.y);
    angle = path.headingAt(trackDistance);
  }

  @override
  void render(Canvas canvas) {
    final sprite = this.sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: pixelArtPaint());
      if (isCrashed) _renderCrashCross(canvas);
      return;
    }
    // Canvas fallback: used until pixel-art textures exist.
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      Paint()..color = isCrashed ? const Color(0xFF3A3E48) : color,
    );
    if (isCrashed) {
      _renderCrashCross(canvas);
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.x - 4, 10),
      Paint()..color = const Color(0xFFF3E9D2),
    );
  }

  void _renderCrashCross(Canvas canvas) {
    final crossPaint = Paint()
      ..color = const Color(0xFFFF5A36)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(3, 4),
      Offset(size.x - 3, size.y - 4),
      crossPaint,
    );
    canvas.drawLine(Offset(size.x - 3, 4), Offset(3, size.y - 4), crossPaint);
  }
}
