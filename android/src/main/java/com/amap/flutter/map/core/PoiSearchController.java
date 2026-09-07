package com.amap.flutter.map.core;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.amap.api.services.core.AMapException;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.core.PoiItemV2;
import com.amap.api.services.poisearch.PoiResultV2;
import com.amap.api.services.poisearch.PoiSearchV2;
import com.amap.flutter.map.MyMethodCallHandler;
import com.amap.flutter.map.utils.Const;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Bridges keyword POI search requests to AMap's search SDK. */
public final class PoiSearchController implements MyMethodCallHandler {
    private final Context context;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private volatile boolean disposed;

    public PoiSearchController(Context context) {
        this.context = context.getApplicationContext();
    }

    @Override
    public String[] getRegisterMethodIdArray() {
        return new String[]{Const.METHOD_POI_SEARCH};
    }

    @Override
    public void doMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!Const.METHOD_POI_SEARCH.equals(call.method)) {
            result.notImplemented();
            return;
        }
        searchPoi(call, result);
    }

    public void dispose() {
        disposed = true;
    }

    private void searchPoi(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        final String keyword = call.argument("keyword");
        if (keyword == null || keyword.trim().isEmpty()) {
            completeError(result, "invalid_argument", "keyword must not be empty.", null);
            return;
        }

        final int page = intArgument(call, "page", 1);
        final int pageSize = intArgument(call, "pageSize", 20);
        if (page < 1 || page > 100 || pageSize < 1 || pageSize > 25) {
            completeError(result, "invalid_argument", "page must be 1-100 and pageSize must be 1-25.", null);
            return;
        }

        try {
            final PoiSearchV2.Query query = new PoiSearchV2.Query(
                    keyword,
                    stringArgument(call, "types"),
                    stringArgument(call, "city"));
            query.setPageNum(page);
            query.setPageSize(pageSize);
            query.setCityLimit(Boolean.TRUE.equals(call.argument("cityLimit")));

            final PoiSearchV2 poiSearch = new PoiSearchV2(context, query);
            final AtomicBoolean completed = new AtomicBoolean(false);
            poiSearch.setOnPoiSearchListener(new PoiSearchV2.OnPoiSearchListener() {
                @Override
                public void onPoiSearched(PoiResultV2 poiResult, int errorCode) {
                    if (!completed.compareAndSet(false, true)) {
                        return;
                    }
                    if (errorCode == AMapException.CODE_AMAP_SUCCESS && poiResult != null) {
                        completeSuccess(result, toResultMap(poiResult));
                    } else {
                        completeError(result, "amap_poi_search", "AMap POI search failed.", errorCode);
                    }
                }

                @Override
                public void onPoiItemSearched(PoiItemV2 poiItem, int errorCode) {
                    // This bridge only issues keyword searches.
                }

                @Override
                public void onVisualSearched(com.amap.api.services.poisearch.VisualSearchResult result, int errorCode) {
                    // This bridge only issues keyword searches.
                }
            });
            poiSearch.searchPOIAsyn();
        } catch (AMapException exception) {
            completeError(result, "amap_poi_search", exception.getErrorMessage(), exception.getErrorCode());
        } catch (RuntimeException exception) {
            completeError(result, "amap_poi_search", exception.getMessage(), null);
        }
    }

    private static int intArgument(MethodCall call, String key, int defaultValue) {
        final Object value = call.argument(key);
        return value instanceof Number ? ((Number) value).intValue() : defaultValue;
    }

    private static String stringArgument(MethodCall call, String key) {
        final Object value = call.argument(key);
        return value instanceof String ? (String) value : "";
    }

    private static Map<String, Object> toResultMap(PoiResultV2 result) {
        final ArrayList<Map<String, Object>> pois = new ArrayList<>();
        if (result.getPois() != null) {
            for (PoiItemV2 poi : result.getPois()) {
                final Map<String, Object> item = new HashMap<>();
                addIfPresent(item, "id", poi.getPoiId());
                addIfPresent(item, "name", poi.getTitle());
                addIfPresent(item, "address", poi.getSnippet());
                addIfPresent(item, "type", poi.getTypeDes());
                addIfPresent(item, "typeCode", poi.getTypeCode());
                addIfPresent(item, "province", poi.getProvinceName());
                addIfPresent(item, "city", poi.getCityName());
                addIfPresent(item, "district", poi.getAdName());
                addIfPresent(item, "adCode", poi.getAdCode());
                final LatLonPoint point = poi.getLatLonPoint();
                if (point != null) {
                    final ArrayList<Double> latLng = new ArrayList<>(2);
                    latLng.add(point.getLatitude());
                    latLng.add(point.getLongitude());
                    item.put("latLng", latLng);
                }
                pois.add(item);
            }
        }

        final Map<String, Object> data = new HashMap<>();
        data.put("count", result.getCount());
        data.put("pois", pois);
        return data;
    }

    private static void addIfPresent(Map<String, Object> map, String key, String value) {
        if (value != null) {
            map.put(key, value);
        }
    }

    private void completeSuccess(MethodChannel.Result result, Map<String, Object> data) {
        mainHandler.post(() -> {
            if (!disposed) {
                result.success(data);
            }
        });
    }

    private void completeError(MethodChannel.Result result, String code, String message, Object details) {
        mainHandler.post(() -> {
            if (!disposed) {
                result.error(code, message, details);
            }
        });
    }
}
