import 'package:amap_map/amap_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_amap_base/x_amap_base.dart';

void main() {
  final LatLngBounds beijingBounds = LatLngBounds(
    southwest: const LatLng(39.0, 116.0),
    northeast: const LatLng(40.0, 117.0),
  );

  test(
    'builds clusters off the UI isolate and returns cluster nodes',
    () async {
      final AMapClusterManager manager = AMapClusterManager(
        options: const AMapClusterOptions(minZoom: 3, unclusteredAtZoom: 20),
      );
      addTearDown(manager.dispose);

      await manager.replacePoints(const <AMapClusterPoint>[
        AMapClusterPoint(id: 'one', position: LatLng(39.9000, 116.3900)),
        AMapClusterPoint(id: 'two', position: LatLng(39.9001, 116.3901)),
        AMapClusterPoint(id: 'three', position: LatLng(39.9002, 116.3902)),
      ]);

      final AMapClusterSnapshot snapshot = await manager.query(
        bounds: beijingBounds,
        zoom: 5,
      );

      expect(snapshot.revision, 1);
      expect(snapshot.nodes, hasLength(1));
      expect(snapshot.nodes.single, isA<AMapCluster>());
      expect((snapshot.nodes.single as AMapCluster).pointCount, 3);
    },
  );

  test('returns original points at the configured unclustered zoom', () async {
    final AMapClusterManager manager = AMapClusterManager();
    addTearDown(manager.dispose);

    await manager.replacePoints(const <AMapClusterPoint>[
      AMapClusterPoint(id: 'one', position: LatLng(39.9000, 116.3900)),
      AMapClusterPoint(id: 'two', position: LatLng(39.9001, 116.3901)),
    ]);

    final AMapClusterSnapshot snapshot = await manager.query(
      bounds: beijingBounds,
      zoom: 20,
    );

    expect(snapshot.nodes, everyElement(isA<AMapClusterLeaf>()));
    expect(
      snapshot.nodes.map(
        (AMapClusterNode node) => (node as AMapClusterLeaf).pointId,
      ),
      unorderedEquals(<String>['one', 'two']),
    );
  });

  test('rejects duplicate point IDs before rebuilding', () async {
    final AMapClusterManager manager = AMapClusterManager();
    addTearDown(manager.dispose);

    await expectLater(
      manager.replacePoints(const <AMapClusterPoint>[
        AMapClusterPoint(id: 'same', position: LatLng(39.9, 116.3)),
        AMapClusterPoint(id: 'same', position: LatLng(39.8, 116.4)),
      ]),
      throwsArgumentError,
    );
  });
}
