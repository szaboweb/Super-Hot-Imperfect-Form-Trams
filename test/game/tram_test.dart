import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_game.dart';

void main() {
  final game = FlameTester(TramGame.new);

  game.testGameWidget(
    'accelerating tram moves forward (up on screen)',
    verify: (game, tester) async {
      final startY = game.player.position.y;
      game.player.throttle = 1;
      game.update(0.5);
      expect(game.player.position.y, lessThan(startY));
      expect(game.player.speed, lessThanOrEqualTo(Tram.maxSpeed));
    },
  );
}
