import 'package:amap_map/amap_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes native camera movement reasons', () {
    expect(AMapCameraMoveReason.gesture.name, 'gesture');
    expect(AMapCameraMoveReason.nonGesture.name, 'nonGesture');
    expect(AMapCameraMoveReason.unknown.name, 'unknown');
  });
}
