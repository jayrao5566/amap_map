import 'package:amap_map/amap_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes the native heading tracking mode', () {
    final MyLocationStyleOptions options = MyLocationStyleOptions(
      true,
      trackingMode: AMapUserTrackingMode.followWithHeading,
    );

    expect(options.toMap()['trackingMode'], 2);
    expect(
      options.clone().trackingMode,
      AMapUserTrackingMode.followWithHeading,
    );
  });

  test('defaults to showing the location indicator without map tracking', () {
    final MyLocationStyleOptions options = MyLocationStyleOptions(true);

    expect(options.trackingMode, AMapUserTrackingMode.none);
    expect(options.toMap()['trackingMode'], 0);
  });

  test('falls back to no tracking for an unsupported platform value', () {
    final MyLocationStyleOptions options = MyLocationStyleOptions.fromMap(
      <String, Object?>{'enabled': true, 'trackingMode': 99},
    )!;

    expect(options.trackingMode, AMapUserTrackingMode.none);
  });
}
