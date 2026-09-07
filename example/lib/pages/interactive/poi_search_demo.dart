import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';

class PoiSearchDemoPage extends StatefulWidget {
  const PoiSearchDemoPage({super.key});

  @override
  State<PoiSearchDemoPage> createState() => _PoiSearchDemoPageState();
}

class _PoiSearchDemoPageState extends State<PoiSearchDemoPage> {
  final TextEditingController _keywordController = TextEditingController(
    text: '充电站',
  );
  final TextEditingController _cityController = TextEditingController(
    text: '北京',
  );

  AMapController? _mapController;
  List<PoiSearchItem> _pois = const <PoiSearchItem>[];
  String? _errorMessage;
  bool _isSearching = false;

  @override
  void dispose() {
    _keywordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final AMapController? controller = _mapController;
    final String keyword = _keywordController.text.trim();
    if (controller == null || keyword.isEmpty || _isSearching) {
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final PoiSearchResult result = await controller.searchPoi(
        PoiSearchQuery(
          keyword: keyword,
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          cityLimit: _cityController.text.trim().isNotEmpty,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pois = result.pois;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _pois = const <PoiSearchItem>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          AMapWidget(
            onMapCreated: (AMapController controller) {
              setState(() {
                _mapController = controller;
              });
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _keywordController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: const InputDecoration(
                                labelText: '关键词',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 88,
                            child: TextField(
                              controller: _cityController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: const InputDecoration(
                                labelText: '城市',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isSearching ? null : _search,
                            tooltip: '搜索',
                            icon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_errorMessage != null)
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_errorMessage!),
                      ),
                    )
                  else if (_pois.isNotEmpty)
                    Expanded(
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: ListView.separated(
                          itemCount: _pois.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final PoiSearchItem poi = _pois[index];
                            return ListTile(
                              title: Text(poi.name),
                              subtitle: Text(poi.address ?? poi.type ?? ''),
                              onTap: poi.latLng == null
                                  ? null
                                  : () => _mapController?.moveCamera(
                                      CameraUpdate.newLatLngZoom(
                                        poi.latLng!,
                                        16,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
