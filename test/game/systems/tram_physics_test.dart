import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/tram_ai_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/tram_physics.dart';

void main() {
  test('TramComponent and TramAiSystem share TramPhysics SSOT constants', () {
    expect(TramComponent.maxSpeed, TramPhysics.maxSpeed);
    expect(TramComponent.acceleration, TramPhysics.acceleration);
    expect(TramComponent.drag, TramPhysics.drag);
    expect(TramComponent.halfLength, TramPhysics.halfLength);
    expect(TramComponent.skidMinSpeed, TramPhysics.skidMinSpeed);
    expect(TramComponent.minBrakeEfficiency, TramPhysics.minBrakeEfficiency);
    expect(TramComponent.sinkDurationSec, TramPhysics.sinkDurationSec);

    expect(TramAiSystem.vehicleAcceleration, TramPhysics.acceleration);
    expect(TramAiSystem.vehicleDrag, TramPhysics.drag);
    expect(TramAiSystem.vehicleHalfLength, TramPhysics.halfLength);
  });
}
