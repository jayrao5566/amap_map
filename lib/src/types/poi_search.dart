import 'package:flutter/foundation.dart';
import 'package:x_amap_base/x_amap_base.dart';

/// Parameters for a keyword POI search.
@immutable
class PoiSearchQuery {
  const PoiSearchQuery({
    required this.keyword,
    this.city,
    this.types,
    this.page = 1,
    this.pageSize = 20,
    this.cityLimit = false,
  }) : assert(keyword != ''),
       assert(page >= 1 && page <= 100),
       assert(pageSize >= 1 && pageSize <= 25);

  /// Search keyword. Multiple keywords can be separated with `|`.
  final String keyword;

  /// Optional city name, city code, or administrative district code.
  final String? city;

  /// Optional POI category names or codes, separated with `|`.
  final String? types;

  /// One-based page number, from 1 to 100.
  final int page;

  /// Number of results per page, from 1 to 25.
  final int pageSize;

  /// Whether results must be constrained to [city].
  final bool cityLimit;

  Map<String, Object?> toMap() => <String, Object?>{
    'keyword': keyword,
    'city': city,
    'types': types,
    'page': page,
    'pageSize': pageSize,
    'cityLimit': cityLimit,
  };
}

/// A page of POI keyword-search results.
@immutable
class PoiSearchResult {
  const PoiSearchResult({required this.count, required this.pois});

  /// Number of POIs reported by the native search SDK.
  final int count;

  /// POIs on the requested page.
  final List<PoiSearchItem> pois;

  factory PoiSearchResult.fromMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw ArgumentError.value(value, 'value', 'Expected a POI result map.');
    }
    final Object? rawPois = value['pois'];
    final Iterable<Object?> pois = rawPois is Iterable<Object?>
        ? rawPois
        : const <Object?>[];
    return PoiSearchResult(
      count: (value['count'] as num?)?.toInt() ?? 0,
      pois: pois
          .whereType<Map<Object?, Object?>>()
          .map(PoiSearchItem.fromMap)
          .toList(growable: false),
    );
  }
}

/// A POI returned by a keyword search.
@immutable
class PoiSearchItem {
  const PoiSearchItem({
    required this.id,
    required this.name,
    this.address,
    this.latLng,
    this.type,
    this.typeCode,
    this.province,
    this.city,
    this.district,
    this.adCode,
  });

  final String id;
  final String name;
  final String? address;
  final LatLng? latLng;
  final String? type;
  final String? typeCode;
  final String? province;
  final String? city;
  final String? district;
  final String? adCode;

  factory PoiSearchItem.fromMap(Map<Object?, Object?> value) {
    return PoiSearchItem(
      id: value['id'] as String? ?? '',
      name: value['name'] as String? ?? '',
      address: value['address'] as String?,
      latLng: LatLng.fromJson(value['latLng']),
      type: value['type'] as String?,
      typeCode: value['typeCode'] as String?,
      province: value['province'] as String?,
      city: value['city'] as String?,
      district: value['district'] as String?,
      adCode: value['adCode'] as String?,
    );
  }
}
