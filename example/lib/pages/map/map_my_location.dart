import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MyLocationPage extends StatefulWidget {
  const MyLocationPage({super.key});
  @override
  State<MyLocationPage> createState() => _BodyState();
}

class _BodyState extends State<MyLocationPage> {
  @override
  void initState() {
    super.initState();
    _requestLocaitonPermission();
  }

  @override
  void reassemble() {
    super.reassemble();
    _requestLocaitonPermission();
  }

  void _requestLocaitonPermission() async {
    PermissionStatus status = await Permission.location.request();
    print('permissionStatus=====> $status');
  }

  @override
  Widget build(BuildContext context) {
    final AMapWidget amap = AMapWidget(
      myLocationStyleOptions: MyLocationStyleOptions(
        true,
        circleFillColor: Colors.lightBlue,
        circleStrokeColor: Colors.blue,
        circleStrokeWidth: 1,
        trackingMode: AMapUserTrackingMode.followWithHeading,
      ),
    );

    return Container(child: amap);
  }
}
