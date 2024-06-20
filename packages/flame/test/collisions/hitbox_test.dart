import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('polygon', () {
    final box1 = PolygonHitbox([
          Vector2(0, 0),
          Vector2(0, 200),
          Vector2(100, 200),
          Vector2(100, 100),
          Vector2(200, 100),
          Vector2(200, 0),
        ]),
        box2 = PolygonHitbox([
          Vector2(150, 150),
          Vector2(150, 250),
          Vector2(250, 250),
          Vector2(250, 150),
        ]);

    expect(box1.intersections(box2), isEmpty);
  });
}
