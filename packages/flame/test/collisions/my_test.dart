import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('description', () {
    // final byteData = ByteData(8);

    // byteData.setFloat32(0, 1);
    // byteData.setFloat32(4, 2);

    // print(byteData.getFloat32(0));
    // print(byteData.getFloat32(4));

    // final float32List = Float32List.view(byteData.buffer);

    // float32List[0] = 3;

    // print(byteData.getFloat32(0));

    final float32List = Float32List.fromList([1, 2, 3]);

    float32List[0] = 3;

    print(float32List);
  });
}
