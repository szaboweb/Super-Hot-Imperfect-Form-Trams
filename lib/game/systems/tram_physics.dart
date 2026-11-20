/// Single source of truth for tram kinematics and hull constants shared by
/// pure-Dart systems (such as `TramAiSystem`) and `TramComponent`. Pure Dart.
abstract final class TramPhysics {
  /// Top forward speed in px/s (reverse cap is `maxSpeed / 3`).
  static const double maxSpeed = 320;

  /// Linear throttle and nominal braking acceleration in px/s².
  static const double acceleration = 220;

  /// Per-second velocity retention factor (rolling drag).
  static const double drag = 0.8;

  /// Half the tram hull length in px (nose/tail reach used by turntables).
  static const double halfLength = 28;

  /// Minimum |speed| (px/s) at which braking leaves skid marks.
  static const double skidMinSpeed = 60;

  /// Minimum braking multiplier when brakes are fully overheated (0..1).
  static const double minBrakeEfficiency = 0.25;

  /// Duration in seconds of the river/pit submersion animation.
  static const double sinkDurationSec = 0.65;
}
