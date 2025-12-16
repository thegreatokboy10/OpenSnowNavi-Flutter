import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';
import '../config/mapbox_config.dart';
import '../config/ski_resorts.dart';
import '../models/piste.dart';
import '../models/lift.dart';
import '../services/session_manager.dart';

/// 地图视图 - 用于滑雪路线规划
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapboxMap? _mapboxMap;
  bool _is3DMode = false;
  String _selectedResortKey = 'palarinsal';
  bool _isLoadingResort = false;
  bool _showResortData = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionManager>(
      builder: (context, manager, child) {
        // 获取选中雪场的坐标
        final resortData = SkiResorts.list[_selectedResortKey]!;
        final resortCoord = resortData['coordinate'] as Map<String, dynamic>;
        final resortZoom = resortData['zoom'] as double;

        final initialCenter = Point(
          coordinates: Position(resortCoord['lng'], resortCoord['lat']),
        );

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                // 地图
                MapWidget(
                  cameraOptions: CameraOptions(
                    center: initialCenter,
                    zoom: resortZoom,
                    pitch: _is3DMode ? 60.0 : 0.0,
                  ),
                  styleUri: MapboxConfig.styleUrl,
                  onMapCreated: _onMapCreated,
                ),

                // 顶部控制栏
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _buildTopControls(),
                ),

                // 右侧按钮
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: _buildSideButtons(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // 启用用户位置显示
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: 0xFF007AFF,
        showAccuracyRing: true,
        puckBearingEnabled: true,
      ),
    );

    // 加载雪场数据
    if (_showResortData) {
      await _loadSkiResortData();
    }
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 雪场选择下拉框
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedResortKey,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: SkiResorts.list.entries.map((entry) {
                  final name = entry.value['name'] as Map<String, dynamic>;
                  final country = entry.value['country'] as String;
                  final flag = SkiResorts.getFlagEmoji(country);
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name['en'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isLoadingResort
                    ? null
                    : (value) {
                        if (value != null && value != _selectedResortKey) {
                          _onResortChanged(value);
                        }
                      },
              ),
            ),
          ),

          // 加载指示器
          if (_isLoadingResort)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3D/2D 切换按钮
        _buildFloatingButton(
          icon: _is3DMode ? Icons.view_in_ar : Icons.map,
          label: _is3DMode ? '2D' : '3D',
          onPressed: _toggle3DMode,
        ),
        const SizedBox(height: 12),

        // 显示/隐藏雪道按钮
        _buildFloatingButton(
          icon: _showResortData ? Icons.visibility : Icons.visibility_off,
          label: '雪道',
          onPressed: _toggleResortData,
        ),
        const SizedBox(height: 12),

        // 定位到当前位置
        _buildFloatingButton(
          icon: Icons.my_location,
          label: '定位',
          onPressed: _goToCurrentLocation,
        ),
        const SizedBox(height: 12),

        // 定位到雪场
        _buildFloatingButton(
          icon: Icons.downhill_skiing,
          label: '雪场',
          onPressed: _goToResort,
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: Colors.blue),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onResortChanged(String resortKey) async {
    setState(() {
      _selectedResortKey = resortKey;
      _isLoadingResort = true;
    });

    // 移除旧的图层和数据源
    await _removeSkiResortLayers();

    // 移动到新雪场
    await _goToResort();

    // 加载新雪场数据
    if (_showResortData) {
      await _loadSkiResortData();
    }

    setState(() {
      _isLoadingResort = false;
    });
  }

  Future<void> _toggle3DMode() async {
    setState(() {
      _is3DMode = !_is3DMode;
    });

    if (_mapboxMap != null) {
      final currentCamera = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: _is3DMode ? 60.0 : 0.0,
          bearing: currentCamera.bearing,
        ),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  Future<void> _toggleResortData() async {
    setState(() {
      _showResortData = !_showResortData;
    });

    if (_showResortData) {
      await _loadSkiResortData();
    } else {
      await _removeSkiResortLayers();
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_mapboxMap == null) return;

    final manager = Provider.of<SessionManager>(context, listen: false);
    final position = manager.currentPosition;

    if (position != null) {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 15,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  Future<void> _goToResort() async {
    if (_mapboxMap == null) return;

    final resortData = SkiResorts.list[_selectedResortKey]!;
    final resortCoord = resortData['coordinate'] as Map<String, dynamic>;
    final resortZoom = resortData['zoom'] as double;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(resortCoord['lng'], resortCoord['lat']),
        ),
        zoom: resortZoom,
        pitch: _is3DMode ? 60.0 : 0.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _loadSkiResortData() async {
    if (_mapboxMap == null) return;

    try {
      // 加载雪道数据
      await _loadGeoJsonLayer(
        'runs',
        'assets/ski_resorts/$_selectedResortKey/runs.geojson',
        isRuns: true,
      );

      // 加载缆车数据
      await _loadGeoJsonLayer(
        'lifts',
        'assets/ski_resorts/$_selectedResortKey/lifts.geojson',
        isRuns: false,
      );
    } catch (e) {
      debugPrint('Error loading ski resort data: $e');
    }
  }

  Future<void> _loadGeoJsonLayer(
    String layerId,
    String assetPath, {
    required bool isRuns,
  }) async {
    if (_mapboxMap == null) return;

    try {
      // 读取 GeoJSON 文件
      final String geojsonString = await rootBundle.loadString(assetPath);
      final geojsonData = json.decode(geojsonString);

      // 使用模型解析数据
      // 复刻网页版：在读取时就使用 Piste.fromGeoJson / Lift.fromGeoJson 进行解析和筛选
      String processedGeojson;
      if (isRuns) {
        final pistes = _parsePistesFromGeoJson(geojsonData);
        debugPrint('Parsed ${pistes.length} pistes (downhill/connection only)');
        // 转换回 GeoJSON 用于 Mapbox
        processedGeojson = json.encode(_pistesToGeoJson(pistes));
      } else {
        final lifts = _parseLiftsFromGeoJson(geojsonData);
        debugPrint('Parsed ${lifts.length} lifts');
        // 转换回 GeoJSON 用于 Mapbox
        processedGeojson = json.encode(_liftsToGeoJson(lifts));
      }

      // 添加数据源
      final sourceId = '${layerId}_source';
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: processedGeojson),
      );

      // 根据类型添加不同的图层
      if (isRuns) {
        await _addRunsLayers(sourceId, layerId);
      } else {
        await _addLiftsLayer(sourceId, layerId);
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON layer $layerId: $e');
    }
  }

  /// 解析雪道数据 - 复刻网页版逻辑
  /// 使用 Piste.fromGeoJson 进行解析，只保留 downhill 和 connection 类型
  List<Piste> _parsePistesFromGeoJson(Map<String, dynamic> geojsonData) {
    final features = geojsonData['features'] as List<dynamic>? ?? [];
    final pistes = <Piste>[];

    for (final feature in features) {
      try {
        // Piste.fromGeoJson 会自动筛选，不支持的类型会抛出异常
        final piste = Piste.fromGeoJson(feature as Map<String, dynamic>);
        pistes.add(piste);
      } catch (e) {
        // 不支持的类型会被跳过（如 nordic, sled 等）
        // 这与网页版的行为一致
      }
    }

    return pistes;
  }

  /// 解析缆车数据 - 复刻网页版逻辑
  List<Lift> _parseLiftsFromGeoJson(Map<String, dynamic> geojsonData) {
    final features = geojsonData['features'] as List<dynamic>? ?? [];
    final lifts = <Lift>[];

    for (final feature in features) {
      try {
        final lift = Lift.fromGeoJson(feature as Map<String, dynamic>);
        lifts.add(lift);
      } catch (e) {
        debugPrint('Error parsing lift: $e');
      }
    }

    return lifts;
  }

  /// 将 Piste 列表转换为 GeoJSON FeatureCollection
  Map<String, dynamic> _pistesToGeoJson(List<Piste> pistes) {
    return {
      'type': 'FeatureCollection',
      'features': pistes.map((p) => p.toFeature()).toList(),
    };
  }

  /// 将 Lift 列表转换为 GeoJSON FeatureCollection
  Map<String, dynamic> _liftsToGeoJson(List<Lift> lifts) {
    return {
      'type': 'FeatureCollection',
      'features': lifts.map((l) => l.toFeature()).toList(),
    };
  }

  Future<void> _addRunsLayers(
    String sourceId,
    String layerId,
  ) async {
    if (_mapboxMap == null) return;

    // 按难度分组添加图层 - 使用网页版相同的难度列表
    final difficulties = [
      'novice',
      'easy',
      'intermediate',
      'advanced',
      'expert',
      'freeride',
    ];

    for (final difficulty in difficulties) {
      final color = SkiResorts.difficultyColors[difficulty] ?? 0xFF888888;

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: '${layerId}_$difficulty',
          sourceId: sourceId,
          lineColor: color,
          lineWidth: SkiResorts.pisteLineWidth, // 使用配置的线宽
          lineOpacity: SkiResorts.strokeOpacity, // 使用配置的透明度
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          filter: [
            '==',
            ['get', 'difficulty'],
            difficulty
          ],
        ),
      );
    }
  }

  Future<void> _addLiftsLayer(String sourceId, String layerId) async {
    if (_mapboxMap == null) return;

    // 使用网页版相同的缆车样式
    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: layerId,
        sourceId: sourceId,
        lineColor: SkiResorts.liftColor,
        lineWidth: SkiResorts.liftLineWidth, // 使用配置的线宽
        lineOpacity: SkiResorts.liftStrokeOpacity, // 使用配置的透明度
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Future<void> _removeSkiResortLayers() async {
    if (_mapboxMap == null) return;

    final layersToRemove = [
      'runs_novice',
      'runs_easy',
      'runs_intermediate',
      'runs_advanced',
      'runs_expert',
      'runs_freeride',
      'lifts',
    ];

    final sourcesToRemove = ['runs_source', 'lifts_source'];

    for (final layerId in layersToRemove) {
      try {
        await _mapboxMap!.style.removeStyleLayer(layerId);
      } catch (e) {
        // 图层可能不存在，忽略错误
      }
    }

    for (final sourceId in sourcesToRemove) {
      try {
        await _mapboxMap!.style.removeStyleSource(sourceId);
      } catch (e) {
        // 数据源可能不存在，忽略错误
      }
    }
  }
}
