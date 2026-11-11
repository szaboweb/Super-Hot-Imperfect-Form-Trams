import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/graphics/render_layer.dart';

void main() {
  test('layers are ordered bottom to top', () {
    expect(RenderLayer.values, [
      RenderLayer.depth,
      RenderLayer.ground,
      RenderLayer.track,
      RenderLayer.entities,
      RenderLayer.canopy,
      RenderLayer.atmosphere,
    ]);
    final priorities = RenderLayer.values.map((l) => l.priority).toList();
    expect(priorities, [...priorities]..sort());
    expect(priorities.toSet().length, priorities.length);
  });
}
