import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/spawn_system.dart';

void main() {
  SpawnData spawn(String seg, double time, {double speed = 100}) =>
      SpawnData(segment: seg, time: time, speed: speed);

  test('advance(0) emits t <= 0 spawns and holds future ones', () {
    final sys = SpawnSystem([
      spawn('late', 2.0),
      spawn('immediate', 0.0),
      spawn('pre', -0.5),
    ]);

    expect(sys.elapsedSeconds, 0.0);
    expect(sys.pendingCount, 3);
    expect(sys.hasPending, isTrue);

    final emitted = sys.advance(0);
    expect(emitted.map((s) => s.segment).toList(), ['pre', 'immediate']);
    expect(sys.pendingCount, 1);
    expect(sys.hasPending, isTrue);
    expect(sys.advance(0), isEmpty);
  });

  test('sorts ascending by time and preserves order on equal times', () {
    final sys = SpawnSystem([
      spawn('t2_first', 2.0, speed: 10),
      spawn('t5', 5.0),
      spawn('t2_second', 2.0, speed: 20),
      spawn('t0', 0.0),
      spawn('t2_third', 2.0, speed: 30),
    ]);

    expect(sys.advance(0).map((s) => s.segment).toList(), ['t0']);

    final batch = sys.advance(2.0);
    expect(batch.map((s) => s.segment).toList(), [
      't2_first',
      't2_second',
      't2_third',
    ]);
    expect(sys.pendingCount, 1);

    final last = sys.advance(3.0);
    expect(last.map((s) => s.segment).toList(), ['t5']);
    expect(sys.pendingCount, 0);
    expect(sys.hasPending, isFalse);
  });

  test('handles float tolerance (+1e-9) and ignores negative or NaN dt', () {
    final sys = SpawnSystem([spawn('s1', 1.0), spawn('s2', 2.0)]);

    for (var i = 0; i < 10; i++) {
      sys.advance(0.1 - 5e-11);
    }
    expect(sys.pendingCount, 1);

    sys.advance(-1.0);
    sys.advance(double.nan);
    expect(sys.elapsedSeconds, closeTo(1.0, 1e-6));
    expect(sys.pendingCount, 1);

    final finalBatch = sys.advance(1.0);
    expect(finalBatch.map((s) => s.segment).toList(), ['s2']);
    expect(sys.hasPending, isFalse);
  });

  test('handles empty spawn list cleanly', () {
    final sys = SpawnSystem(const []);
    expect(sys.hasPending, isFalse);
    expect(sys.pendingCount, 0);
    expect(sys.advance(1.0), isEmpty);
    expect(sys.elapsedSeconds, 1.0);
  });
}
