# amap_map 集成指南

本文说明如何将当前仓库中的 `amap_map` 插件接入另一个 Flutter 项目。

## 1. 能力和系统要求

插件支持 Android 和 iOS，不支持 Web、Windows、macOS 或 Linux。

| 平台 | 最低系统版本 | 构建要求 |
| --- | --- | --- |
| Android | API 21，Android 5.0 | `minSdkVersion >= 21`，当前插件使用 `compileSdkVersion 36` |
| iOS | iOS 15.0 | Podfile 与 Xcode Deployment Target 均应为 15.0 或更高 |

当前插件包含：地图展示、相机控制、Marker、Polyline、Polygon、定位事件、地图/覆盖物点击、坐标转换、截图、POI 关键词搜索，以及 Dart 层 Fluster 聚合。

高德地图在中国大陆使用 GCJ-02 坐标。传给 `LatLng` 的业务坐标必须先转换到与高德地图一致的坐标系，否则 Marker、路线和聚合结果会发生偏移。

## 2. 添加依赖

接入未发布的当前版本时，建议锁定提交，而不是跟随分支：

```yaml
dependencies:
  flutter:
    sdk: flutter
  amap_map:
    git:
      url: https://github.com/jayrao5566/amap_map.git
      ref: <插件提交 SHA>
  x_amap_base: 1.0.3
```

本地联调可改为：

```yaml
  amap_map:
    path: ../amap_map
  x_amap_base: 1.0.3
```

执行：

```bash
flutter pub get
```

`x_amap_base` 定义了 `LatLng`、`AMapApiKey`、`AMapPrivacyStatement` 等宿主应用需要直接使用的公开类型，因此宿主项目应将它声明为直接依赖。

## 3. 原生工程配置

### Android

宿主 `android/app/build.gradle` 的最低版本不得低于 21：

```gradle
android {
    compileSdkVersion 36

    defaultConfig {
        minSdkVersion 21
    }
}
```

基础地图至少需要网络相关权限。在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

启用定位蓝点或监听位置时，再声明并在运行时向用户申请：

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

不需要在 Manifest 中写高德 Key。`AMapInitializer.init` 会把 Dart 中提供的 Key 传给两端原生 SDK。

### iOS

在宿主 `ios/Podfile` 中设置：

```ruby
platform :ios, '15.0'
```

同时将 Xcode 项目的 iOS Deployment Target 设为 15.0 或更高。插件的 Pod 依赖会由 Flutter 自动安装，无需手动添加 `AMap3DMap` 或 `AMapSearch`。

仅在使用定位时，在 `ios/Runner/Info.plist` 添加合适的用途说明：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>用于在地图上显示当前位置</string>
```

若应用确实需要后台定位，再按 Apple 审核要求增加对应的 Always 定位说明和能力；普通地图展示不应申请后台定位。

## 4. Key 和合规初始化

先在高德开放平台创建 Android 与 iOS Key。Android Key 应匹配宿主应用的包名和签名证书，iOS Key 应匹配 Bundle Identifier。

地图 SDK 在首次渲染前必须获得用户隐私同意。隐私政策已包含高德内容、已展示且已取得同意后，再创建 `AMapWidget`：

```dart
import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:x_amap_base/x_amap_base.dart';

const AMapApiKey amapKey = AMapApiKey(
  androidKey: String.fromEnvironment('AMAP_ANDROID_KEY'),
  iosKey: String.fromEnvironment('AMAP_IOS_KEY'),
);

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    // 仅在用户已完成隐私授权后执行。
    AMapInitializer.init(context, apiKey: amapKey);
    AMapInitializer.updatePrivacyAgree(
      const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
    );

    return const MapPage();
  }
}
```

不要把真实 Key 提交到代码仓库。上例使用 `--dart-define`：

```bash
flutter run \
  --dart-define=AMAP_ANDROID_KEY=your_android_key \
  --dart-define=AMAP_IOS_KEY=your_ios_key
```

未完成隐私授权时，应展示应用自己的隐私授权页面，不要创建 `AMapWidget`。三个隐私字段任一为 `false` 都可能导致地图无法正常工作。

## 5. 创建地图

下面是一个可直接放入页面的基础地图：

```dart
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  AMapController? _controller;
  Set<Marker> _markers = <Marker>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AMapWidget(
        initialCameraPosition: const CameraPosition(
          target: LatLng(39.909187, 116.397451),
          zoom: 12,
        ),
        markers: _markers,
        trafficEnabled: true,
        compassEnabled: true,
        scaleEnabled: true,
        onMapCreated: (AMapController controller) {
          _controller = controller;
          _addStationMarker();
        },
        onTap: (LatLng position) {
          debugPrint('map tap: $position');
        },
        onCameraMoveEnd: (CameraPosition position) {
          debugPrint('camera: ${position.zoom}');
        },
      ),
    );
  }

  void _addStationMarker() {
    setState(() {
      _markers = <Marker>{
        Marker(
          position: const LatLng(39.909187, 116.397451),
          infoWindow: const InfoWindow(title: '示例充电站'),
          onTap: (String markerId) => debugPrint('marker: $markerId'),
        ),
      };
    });
  }
}
```

`AMapWidget` 由 Flutter Widget 状态驱动。传入新的 `markers`、`polylines` 或 `polygons` 集合并调用 `setState` 后，插件会自动向原生地图增删改覆盖物。

常用 `AMapWidget` 参数：

| 参数 | 用途 |
| --- | --- |
| `initialCameraPosition` | 初始中心点、缩放、倾斜和朝向 |
| `markers` / `polylines` / `polygons` | 覆盖物集合 |
| `mapType` | 普通、卫星等地图类型 |
| `customStyleOptions` | 自定义地图样式 |
| `myLocationStyleOptions` | 定位蓝点样式；需要先申请定位权限 |
| `minMaxZoomPreference` / `limitBounds` | 限制缩放级别或地图可移动范围 |
| `trafficEnabled`、`buildingsEnabled`、`labelsEnabled` | 路况、建筑物、底图文字开关 |
| `zoomGesturesEnabled`、`scrollGesturesEnabled`、`rotateGesturesEnabled`、`tiltGesturesEnabled` | 手势开关 |
| `onMapCreated`、`onCameraMoveEnd`、`onTap`、`onLongPress` | 地图生命周期与交互事件 |
| `onPoiTouched`、`onLocationChanged` | 底图 POI 点击与定位事件 |
| `mapLanguage`、`logoPosition`、`logoBottomMargin`、`logoLeftMargin` | 地图语言与 Logo 位置配置 |
| `gestureRecognizers`、`infoWindowAdapter` | Flutter 手势竞争处理与自定义信息窗 |

`AMapWidget` 销毁时会释放其控制器。页面代码通常不需要手动调用控制器的释放方法。

## 6. 覆盖物

### Marker

```dart
final Marker station = Marker(
  position: const LatLng(39.90, 116.39),
  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
  infoWindow: const InfoWindow(
    title: '朝阳充电站',
    snippet: '空闲 4 个',
  ),
  draggable: true,
  onTap: (String id) {},
  onDragEnd: (String id, LatLng position) {},
);

setState(() {
  _markers = <Marker>{..._markers, station};
});
```

自定义图标可使用 `BitmapDescriptor.fromAssetImage` 或 `BitmapDescriptor.fromBytes`。先异步加载图标，完成后再通过 `setState` 更新覆盖物。

每个覆盖物在创建时有内部 ID。更新已有覆盖物时，应从原对象调用 `copyWith`，以保留 ID；重新创建对象会被视为删除旧覆盖物并新增一个覆盖物：

```dart
final Marker moved = station.copyWith(
  positionParam: const LatLng(39.91, 116.40),
);
```

### Polyline 和 Polygon

```dart
final Polyline route = Polyline(
  points: const <LatLng>[
    LatLng(39.90, 116.39),
    LatLng(39.91, 116.42),
  ],
  width: 8,
  color: Colors.blue,
  onTap: (String id) {},
);

final Polygon serviceArea = Polygon(
  points: const <LatLng>[
    LatLng(39.90, 116.39),
    LatLng(39.90, 116.42),
    LatLng(39.92, 116.42),
    LatLng(39.92, 116.39),
  ],
  strokeColor: Colors.blue,
  fillColor: const Color(0x33007AFF),
);

setState(() {
  _polylines = <Polyline>{route};
  _polygons = <Polygon>{serviceArea};
});
```

## 7. 控制地图

`onMapCreated` 返回的 `AMapController` 可用于以下操作：

```dart
final AMapController controller = _controller!;

await controller.moveCamera(
  CameraUpdate.newLatLngZoom(const LatLng(39.90, 116.39), 16),
);

await controller.moveCamera(CameraUpdate.zoomIn());
await controller.moveCamera(CameraUpdate.scrollBy(40, 0));

await controller.moveCamera(
  CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: const LatLng(39.88, 116.35),
      northeast: const LatLng(39.93, 116.45),
    ),
    48,
  ),
);

final ScreenCoordinate screen = await controller.toScreenCoordinate(
  const LatLng(39.90, 116.39),
);
final LatLng location = await controller.fromScreenCoordinate(screen);
final LatLngBounds visibleBounds = await controller.getVisibleMapBounds();
final snapshot = await controller.takeSnapshot();
```

`CameraUpdate` 还提供 `newCameraPosition`、`newLatLng`、`zoomOut` 和 `zoomTo`。相机动画可通过 `moveCamera` 的 `animated` 与 `duration` 参数控制；iOS 对 `newLatLngBounds` 使用原生默认动画时长。

其他控制器方法：

| 方法 | 用途 |
| --- | --- |
| `clearDisk()` | 清除高德 SDK 磁盘缓存 |
| `getMapContentApprovalNumber()` | 获取地图内容审图号 |
| `getSatelliteImageApprovalNumber()` | 获取卫星图审图号 |
| `searchPoi(PoiSearchQuery)` | 调用高德原生搜索 SDK 进行关键词 POI 搜索 |

## 8. POI 关键词搜索

```dart
final PoiSearchResult result = await _controller!.searchPoi(
  const PoiSearchQuery(
    keyword: '充电站',
    city: '北京',
    cityLimit: true,
    page: 1,
    pageSize: 20,
  ),
);

for (final PoiSearchItem poi in result.pois) {
  debugPrint('${poi.name}: ${poi.latLng}');
}
```

`PoiSearchItem.latLng` 可能为空，应判断后再移动地图或创建 Marker。分页从 1 开始，`page` 范围为 1 到 100，`pageSize` 范围为 1 到 25。

## 9. 大量点聚合

`AMapClusterManager` 使用 Fluster/Supercluster 风格的层级 KD-tree。它不接收业务对象，只接收 ID 和坐标；应用侧以 ID 关联充电站、门店等业务数据。

```dart
final AMapClusterManager clusterManager = AMapClusterManager(
  options: const AMapClusterOptions(
    minZoom: 3,
    unclusteredAtZoom: 20,
    radius: 50,
    extent: 1024,
    nodeSize: 128,
  ),
);

await clusterManager.replacePoints(<AMapClusterPoint>[
  const AMapClusterPoint(
    id: 'station-1',
    position: LatLng(39.9000, 116.3900),
  ),
  const AMapClusterPoint(
    id: 'station-2',
    position: LatLng(39.9001, 116.3901),
  ),
]);

Future<void> refreshClusters(CameraPosition camera) async {
  final AMapClusterSnapshot snapshot = await clusterManager.query(
    bounds: await _controller!.getVisibleMapBounds(),
    zoom: camera.zoom,
  );

  for (final AMapClusterNode node in snapshot.nodes) {
    switch (node) {
      case AMapCluster cluster:
        debugPrint('cluster ${cluster.clusterId}: ${cluster.pointCount} points');
        break;
      case AMapClusterLeaf leaf:
        debugPrint('point: ${leaf.pointId}');
        break;
    }
  }
}
```

推荐工作流：

1. 业务点列表变化后调用一次 `replacePoints`。数万点的索引重建在 `Isolate.run` 执行，不阻塞 Flutter UI。
2. 在 `onCameraMoveEnd` 调用 `refreshClusters`，不要在 `onCameraMove` 中反复重建索引。
3. 将 `AMapCluster` 渲染为带数量的自定义 Marker，将 `AMapClusterLeaf` 渲染为业务 Marker。
4. 点击聚合 Marker 时，移动相机到 `cluster.position` 并提高缩放级别；相机停止后会自动查询下一层结果。
5. 页面销毁时调用 `clusterManager.dispose()`。

`unclusteredAtZoom: 20` 表示从 20 级开始返回原始点。不要在高缩放级别一次性向原生地图提交数万个 Marker；应根据业务需求维持合理的聚合层级或限制可见点数。

## 10. 常见问题

| 现象 | 优先检查项 |
| --- | --- |
| 地图白屏 | 是否在创建地图前完成 `AMapInitializer.init` 和隐私授权；Key 是否与包名/签名或 Bundle ID 匹配 |
| Android 无定位 | 是否声明并运行时授予精确/粗略定位权限；是否启用了 `myLocationStyleOptions` |
| iOS 无定位 | `Info.plist` 是否存在相应的 Location Usage Description，用户是否已授权 |
| Marker 或路线位置偏移 | 坐标是否为 GCJ-02，是否错误传入 WGS-84 或百度 BD-09 坐标 |
| 覆盖物更新成闪烁的删除/新增 | 是否使用原对象的 `copyWith` 保留内部覆盖物 ID |
| 聚合查询结果为空 | 是否已等待 `replacePoints` 完成，且传入的是 `getVisibleMapBounds()` 和当前相机 `zoom` |

## 11. 接入检查清单

- Android `minSdkVersion >= 21`，iOS Deployment Target >= 15.0。
- 已创建与 Android 包名/签名、iOS Bundle ID 对应的高德 Key。
- Key 不提交到仓库，使用构建参数或安全配置注入。
- 用户同意隐私政策后才创建地图。
- 使用定位时才声明和申请定位权限。
- 所有业务坐标统一为高德使用的 GCJ-02。
- 大数据点先重建聚合索引，地图移动结束后按可视范围查询并渲染。
