import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/y_turn_path.dart';

void main() {
  test('the Y starts and ends on the stem, entry px behind the fork', () {
    final y = yTurnPath(radius: 48, entry: 76);
    expect(y.points.first.x, 0);
    expect(y.points.first.y, 76);
    expect(y.points.last.x, 0);
    expect(y.points.last.y, 76);
    expect(y.isClosed, isTrue);
  });

  test('the arms run forward of the fork (up = negative y)', () {
    final y = yTurnPath(radius: 48, entry: 76);
    final farthest = y.points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    expect(farthest, lessThan(-20));
    expect(y.length, greaterThan(2 * 76));
  });

  test('radius scales the Y', () {
    final small = yTurnPath(radius: 24, entry: 40);
    final big = yTurnPath(radius: 48, entry: 40);
    expect(big.length, greaterThan(small.length));
  });
}
