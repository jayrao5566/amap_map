import 'dart:isolate';

import 'package:fluster/fluster.dart';
import 'package:flutter/foundation.dart';
import 'package:x_amap_base/x_amap_base.dart';

/// Configuration for [AMapClusterManager].
@immutable
class AMapClusterOptions {
  const AMapClusterOptions({
    this.minZoom = 3,
    this.unclusteredAtZoom = 20,
    this.radius = 50,
    this.extent = 1024,
    this.nodeSize = 128,
  });

  /// Lowest map zoom that uses this cluster index.
  final int minZoom;

  /// First zoom level at which individual points are returned.
  final int unclusteredAtZoom;

  /// Cluster radius in Fluster pixels.
  final int radius;

  /// Fluster coordinate extent. This should be a power of two.
  final int extent;

  /// KD-tree leaf size. Larger values trade query time for build time.
  final int nodeSize;

  void validate() {
    if (minZoom < 0) {
      throw ArgumentError.value(minZoom, 'minZoom', 'Must be at least zero.');
    }
    if (unclusteredAtZoom <= minZoom || unclusteredAtZoom > 31) {
      throw ArgumentError.value(
        unclusteredAtZoom,
        'unclusteredAtZoom',
        'Must be greater than minZoom and no greater than 31.',
      );
    }
    if (radius <= 0 || extent <= 0 || nodeSize <= 0) {
      throw ArgumentError('radius, extent, and nodeSize must be positive.');
    }
  }
}

/// A business-data-free point used to build a map cluster index.
@immutable
class AMapClusterPoint {
  const AMapClusterPoint({required this.id, required this.position});

  /// Stable ID used to recover application data from the caller's own map.
  final String id;

  /// Point position. All points must use the same coordinate system as AMap.
  final LatLng position;
}

/// A visible item returned by [AMapClusterManager.query].
sealed class AMapClusterNode {
  const AMapClusterNode({required this.position});

  final LatLng position;
}

/// A cluster marker to render at [position].
@immutable
class AMapCluster extends AMapClusterNode {
  const AMapCluster({
    required this.clusterId,
    required this.pointCount,
    required super.position,
  });

  /// Valid only for the [AMapClusterSnapshot.revision] that produced it.
  final int clusterId;

  /// Number of original points represented by this cluster.
  final int pointCount;
}

/// A single original point to render at [position].
@immutable
class AMapClusterLeaf extends AMapClusterNode {
  const AMapClusterLeaf({required this.pointId, required super.position});

  final String pointId;
}

/// The cluster nodes visible for a map bounds and zoom level.
@immutable
class AMapClusterSnapshot {
  const AMapClusterSnapshot({required this.revision, required this.nodes});

  final int revision;
  final List<AMapClusterNode> nodes;
}

/// Builds and queries a Fluster index for AMap markers.
///
/// Call [replacePoints] when the source data changes. It builds the KD-tree in
/// a background isolate. Then call [query] from `onCameraMoveEnd` with the
/// current map bounds and camera zoom.
class AMapClusterManager {
  factory AMapClusterManager({
    AMapClusterOptions options = const AMapClusterOptions(),
  }) {
    options.validate();
    return AMapClusterManager._(options);
  }

  AMapClusterManager._(this._options);

  final AMapClusterOptions _options;
  _AMapClusterIndex? _index;
  int _revision = 0;
  bool _isDisposed = false;

  /// Replaces the whole source set and rebuilds its cluster index off the UI
  /// isolate. A later call wins when multiple rebuilds overlap.
  Future<void> replacePoints(Iterable<AMapClusterPoint> points) async {
    _checkNotDisposed();
    final List<AMapClusterPoint> copiedPoints =
        List<AMapClusterPoint>.unmodifiable(points);
    _validatePoints(copiedPoints);

    final int requestedRevision = ++_revision;
    final AMapClusterOptions options = _options;
    final _AMapClusterIndex builtIndex = await Isolate.run<_AMapClusterIndex>(
      () => _buildIndex(copiedPoints, options, requestedRevision),
    );
    if (!_isDisposed && requestedRevision == _revision) {
      _index = builtIndex;
    }
  }

  /// Returns the cluster and leaf nodes visible inside [bounds] at [zoom].
  Future<AMapClusterSnapshot> query({
    required LatLngBounds bounds,
    required double zoom,
  }) async {
    _checkNotDisposed();
    final _AMapClusterIndex? index = _index;
    if (index == null) {
      return AMapClusterSnapshot(
        revision: _revision,
        nodes: const <AMapClusterNode>[],
      );
    }
    return index.query(bounds, zoom);
  }

  /// Releases the current index and makes outstanding rebuilds inactive.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _revision++;
    _index = null;
  }

  void _checkNotDisposed() {
    if (_isDisposed) {
      throw StateError('AMapClusterManager has been disposed.');
    }
  }
}

void _validatePoints(List<AMapClusterPoint> points) {
  final Set<String> pointIds = <String>{};
  for (final AMapClusterPoint point in points) {
    if (point.id.isEmpty) {
      throw ArgumentError.value(point.id, 'point.id', 'Must not be empty.');
    }
    if (!pointIds.add(point.id)) {
      throw ArgumentError.value(point.id, 'point.id', 'Must be unique.');
    }
    if (!point.position.latitude.isFinite ||
        !point.position.longitude.isFinite) {
      throw ArgumentError.value(
        point.position,
        'point.position',
        'Must be finite.',
      );
    }
  }
}

_AMapClusterIndex _buildIndex(
  List<AMapClusterPoint> points,
  AMapClusterOptions options,
  int revision,
) {
  final List<_FlusterPoint> flusterPoints = points
      .map(_FlusterPoint.fromPoint)
      .toList(growable: false);
  return _AMapClusterIndex(
    Fluster<_FlusterPoint>(
      minZoom: options.minZoom,
      maxZoom: options.unclusteredAtZoom - 1,
      radius: options.radius,
      extent: options.extent,
      nodeSize: options.nodeSize,
      points: flusterPoints,
      createCluster: _createFlusterCluster,
    ),
    revision,
  );
}

_FlusterPoint _createFlusterCluster(
  BaseCluster cluster,
  double longitude,
  double latitude,
) {
  return _FlusterPoint.cluster(
    latitude: latitude,
    longitude: longitude,
    clusterId: cluster.id,
    pointsSize: cluster.pointsSize,
    childMarkerId: cluster.childMarkerId,
  );
}

class _AMapClusterIndex {
  const _AMapClusterIndex(this._fluster, this.revision);

  final Fluster<_FlusterPoint> _fluster;
  final int revision;

  AMapClusterSnapshot query(LatLngBounds bounds, double zoom) {
    if (!zoom.isFinite) {
      throw ArgumentError.value(zoom, 'zoom', 'Must be finite.');
    }
    final List<_FlusterPoint> rawNodes = _fluster.clusters(<double>[
      bounds.southwest.longitude,
      bounds.southwest.latitude,
      bounds.northeast.longitude,
      bounds.northeast.latitude,
    ], zoom.floor());
    return AMapClusterSnapshot(
      revision: revision,
      nodes: List<AMapClusterNode>.unmodifiable(rawNodes.map(_toPublicNode)),
    );
  }
}

AMapClusterNode _toPublicNode(_FlusterPoint point) {
  final LatLng position = LatLng(point.latitude!, point.longitude!);
  if (point.isCluster == true) {
    return AMapCluster(
      clusterId: point.clusterId!,
      pointCount: point.pointsSize!,
      position: position,
    );
  }
  return AMapClusterLeaf(pointId: point.pointId!, position: position);
}

class _FlusterPoint extends Clusterable {
  _FlusterPoint.fromPoint(AMapClusterPoint point)
    : pointId = point.id,
      super(
        latitude: point.position.latitude,
        longitude: point.position.longitude,
        markerId: point.id,
      );

  _FlusterPoint.cluster({
    required super.latitude,
    required super.longitude,
    required super.clusterId,
    required super.pointsSize,
    required super.childMarkerId,
  }) : pointId = null,
       super(isCluster: true);

  final String? pointId;
}
