import 'package:amap_map/amap_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_amap_base/x_amap_base.dart' show LatLng;

void main() {
  test('serializes a keyword POI query', () {
    const PoiSearchQuery query = PoiSearchQuery(
      keyword: '充电站',
      city: '北京',
      types: '汽车服务',
      page: 2,
      pageSize: 10,
      cityLimit: true,
    );

    expect(query.toMap(), <String, Object?>{
      'keyword': '充电站',
      'city': '北京',
      'types': '汽车服务',
      'page': 2,
      'pageSize': 10,
      'cityLimit': true,
    });
  });

  test('deserializes a POI result from a platform response', () {
    final PoiSearchResult result = PoiSearchResult.fromMap(<Object?, Object?>{
      'count': 1,
      'pois': <Object?>[
        <Object?, Object?>{
          'id': 'B000A',
          'name': '测试充电站',
          'address': '北京市朝阳区',
          'latLng': <double>[39.9, 116.4],
          'type': '汽车服务',
          'adCode': '110105',
        },
      ],
    });

    expect(result.count, 1);
    expect(result.pois, hasLength(1));
    expect(result.pois.single.name, '测试充电站');
    expect(result.pois.single.latLng, const LatLng(39.9, 116.4));
  });
}
