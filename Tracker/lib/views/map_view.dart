import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';
import '../config/mapbox_config.dart';
import '../config/ski_resorts.dart';
import '../models/piste.dart';
import '../models/lift.dart';
import '../models/route_planning_state.dart';
import '../services/session_manager.dart';
import '../services/route_engine.dart' as re;
import '../services/search_service.dart';
import '../widgets/route_planning_panel.dart';
import '../widgets/poi_info_panel.dart';

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
  bool _showOpenSnowMap = false; // OpenSnowMap 图层开关
  bool _showResortSelector = false; // 雪场选择器弹窗
  bool _showLayerSelector = false; // 图层选择器弹窗
  bool _initialLocationSet = false; // 是否已设置初始位置

  // 路线规划相关状态
  final RoutePlanningData _routePlanningData = RoutePlanningData();
  re.Route? _currentRoute;
  bool _showRoutePlanningPanel = false;
  Position? _selectedPOIPosition;
  String? _selectedPOIName;
  bool _showPOIPanel = false;
  EditingPointType _currentEditingType = EditingPointType.none;
  int _currentEditingStopoverIndex = -1;
  final re.RouteEngine _routeEngine = re.RouteEngine();

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
                  onTapListener: _onMapTap,
                ),

                // 左上角：路线规划面板（避开比例尺，放在下方）
                if (_showRoutePlanningPanel)
                  Positioned(
                    left: 16,
                    top: 60, // 避开比例尺
                    child: RoutePlanningPanel(
                      data: _routePlanningData,
                      route: _currentRoute,
                      resortCoordinate: _getResortLatLng(),
                      onClose: _closeRoutePlanningPanel,
                      onPointSelected: _onRoutePointSelected,
                      onRemovePoint: _onRemoveRoutePoint,
                      onReorderPoints: _onReorderRoutePoints,
                      onUseCurrentLocation: _onUseCurrentLocationForRoute,
                      onEditingTypeChanged: _onEditingTypeChanged,
                    ),
                  ),

                // 右侧按钮（避开指南针，从下方开始）
                Positioned(
                  right: 16,
                  top: 60, // 避开指南针
                  child: _buildSideButtons(),
                ),

                // 底部 POI 详情面板
                if (_showPOIPanel && _selectedPOIPosition != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: POIInfoPanel(
                      name: _selectedPOIName,
                      coordinates: _selectedPOIPosition!,
                      onClose: _closePOIPanel,
                      onSetAsOrigin: () =>
                          _setPOIAsRoutePoint(RoutePointType.origin),
                      onSetAsDestination: () =>
                          _setPOIAsRoutePoint(RoutePointType.destination),
                      onAddAsStopover: () =>
                          _setPOIAsRoutePoint(RoutePointType.stopover),
                    ),
                  ),

                // 雪场选择器弹窗
                if (_showResortSelector) _buildResortSelectorOverlay(),

                // 图层选择器弹窗
                if (_showLayerSelector) _buildLayerSelectorOverlay(),
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

    // 找到离当前位置最近的雪场并设置
    await _findAndSetNearestResort();

    // 加载雪场数据
    if (_showResortData) {
      await _loadSkiResortData();
    }

    // 自动定位到当前位置
    await _goToCurrentLocation();
    _initialLocationSet = true;
  }

  /// 找到离当前位置最近的雪场
  Future<void> _findAndSetNearestResort() async {
    final manager = Provider.of<SessionManager>(context, listen: false);
    final position = manager.currentPosition;

    if (position == null) return;

    String nearestResortKey = _selectedResortKey;
    double minDistance = double.infinity;

    for (final entry in SkiResorts.list.entries) {
      final coord = entry.value['coordinate'] as Map<String, dynamic>;
      final resortLat = coord['lat'] as double;
      final resortLng = coord['lng'] as double;

      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        resortLat,
        resortLng,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestResortKey = entry.key;
      }
    }

    if (nearestResortKey != _selectedResortKey) {
      setState(() {
        _selectedResortKey = nearestResortKey;
      });
      debugPrint(
          'Set nearest resort: $nearestResortKey (${minDistance / 1000} km)');
    }
  }

  /// 计算两点之间的距离（米）
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final deltaLat = (lat2 - lat1) * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Widget _buildSideButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 路线规划按钮
        _buildFloatingButton(
          icon: Icons.directions,
          onPressed: _toggleRoutePlanningPanel,
          isActive: _showRoutePlanningPanel,
        ),
        const SizedBox(height: 8),

        // 雪场选择按钮（山峰图标）
        _buildFloatingButton(
          icon: Icons.terrain,
          onPressed: () => setState(() => _showResortSelector = true),
          isActive: _showResortSelector,
        ),
        const SizedBox(height: 8),

        // 图层按钮
        _buildFloatingButton(
          icon: Icons.layers,
          onPressed: () => setState(() => _showLayerSelector = true),
          isActive: _showLayerSelector,
        ),
        const SizedBox(height: 8),

        // 3D/2D 切换按钮（使用文字）
        _build3DToggleButton(),
        const SizedBox(height: 8),

        // 定位到当前位置
        _buildFloatingButton(
          icon: Icons.my_location,
          onPressed: _goToCurrentLocation,
        ),

        // 加载指示器
        if (_isLoadingResort)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: isActive ? Colors.blue : Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 24,
            color: isActive ? Colors.white : Colors.blue,
          ),
        ),
      ),
    );
  }

  /// 3D/2D 切换按钮（使用文字）
  Widget _build3DToggleButton() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: InkWell(
        onTap: _toggle3DMode,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Text(
            _is3DMode ? '3D' : '2D',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  /// 雪场选择器弹窗
  Widget _buildResortSelectorOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showResortSelector = false),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // 阻止点击穿透
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '选择雪场',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _showResortSelector = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  ...SkiResorts.list.entries.map((entry) {
                    final name = entry.value['name'] as Map<String, dynamic>;
                    final country = entry.value['country'] as String;
                    final flag = SkiResorts.getFlagEmoji(country);
                    final isSelected = entry.key == _selectedResortKey;

                    return ListTile(
                      leading: Text(flag, style: const TextStyle(fontSize: 24)),
                      title: Text(name['en'] as String),
                      subtitle: Text(name['cn'] as String),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      selected: isSelected,
                      onTap: () {
                        setState(() => _showResortSelector = false);
                        if (entry.key != _selectedResortKey) {
                          _onResortChanged(entry.key);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 图层选择器弹窗
  Widget _buildLayerSelectorOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showLayerSelector = false),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // 阻止点击穿透
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '图层设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _showLayerSelector = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('雪道和缆车'),
                    subtitle: const Text('显示当前雪场的雪道和缆车数据'),
                    value: _showResortData,
                    onChanged: (value) {
                      setState(() => _showLayerSelector = false);
                      _toggleResortData();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('OpenSnowMap'),
                    subtitle: const Text('显示 OpenSnowMap 滑雪地图图层'),
                    value: _showOpenSnowMap,
                    onChanged: (value) {
                      setState(() {
                        _showOpenSnowMap = value;
                        _showLayerSelector = false;
                      });
                      _toggleOpenSnowMapLayer();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换 OpenSnowMap 图层
  Future<void> _toggleOpenSnowMapLayer() async {
    if (_mapboxMap == null) return;

    const sourceId = 'opensnowmap-source';
    const layerId = 'opensnowmap-layer';

    if (_showOpenSnowMap) {
      // 添加 OpenSnowMap 瓦片图层
      try {
        await _mapboxMap!.style.addSource(
          RasterSource(
            id: sourceId,
            tiles: ['https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png'],
            tileSize: 256,
          ),
        );
        await _mapboxMap!.style.addLayer(
          RasterLayer(
            id: layerId,
            sourceId: sourceId,
            rasterOpacity: 0.7,
          ),
        );
        debugPrint('OpenSnowMap layer added');
      } catch (e) {
        debugPrint('Error adding OpenSnowMap layer: $e');
      }
    } else {
      // 移除 OpenSnowMap 图层
      try {
        await _mapboxMap!.style.removeStyleLayer(layerId);
        await _mapboxMap!.style.removeStyleSource(sourceId);
        debugPrint('OpenSnowMap layer removed');
      } catch (e) {
        debugPrint('Error removing OpenSnowMap layer: $e');
      }
    }
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

  // ==================== 路线规划相关方法 ====================

  /// 获取当前雪场的 LatLng 坐标
  LatLng? _getResortLatLng() {
    final resortData = SkiResorts.list[_selectedResortKey];
    if (resortData == null) return null;
    final coord = resortData['coordinate'] as Map<String, dynamic>;
    return LatLng(coord['lat'] as double, coord['lng'] as double);
  }

  /// 切换路线规划面板
  void _toggleRoutePlanningPanel() {
    setState(() {
      _showRoutePlanningPanel = !_showRoutePlanningPanel;
      if (!_showRoutePlanningPanel) {
        // 关闭面板时重置状态
        _routePlanningData.reset();
        _currentRoute = null;
        _removeRouteLayer();
      }
    });
  }

  /// 关闭路线规划面板
  void _closeRoutePlanningPanel() {
    setState(() {
      _showRoutePlanningPanel = false;
      _routePlanningData.reset();
      _currentRoute = null;
      _removeRouteLayer();
    });
  }

  /// 关闭 POI 面板
  void _closePOIPanel() {
    setState(() {
      _showPOIPanel = false;
      _selectedPOIPosition = null;
      _selectedPOIName = null;
    });
  }

  /// 地图点击事件处理
  void _onMapTap(MapContentGestureContext context) {
    final point = context.point;
    final coordinates = point.coordinates;

    // 如果正在编辑路线点，直接设置该点
    if (_currentEditingType != EditingPointType.none) {
      _handleMapTapForRouteEditing(coordinates);
      return;
    }

    // 否则显示 POI 面板
    setState(() {
      _selectedPOIPosition = coordinates;
      _selectedPOIName = null; // 可以后续通过反向地理编码获取名称
      _showPOIPanel = true;
    });
  }

  /// 处理地图点击用于路线编辑
  void _handleMapTapForRouteEditing(Position coordinates) {
    final name =
        '${coordinates.lat.toStringAsFixed(4)}, ${coordinates.lng.toStringAsFixed(4)}';

    switch (_currentEditingType) {
      case EditingPointType.origin:
        _routePlanningData.setOrigin(RoutePoint(
          id: 'origin',
          name: name,
          coordinates: coordinates,
          type: RoutePointType.origin,
        ));
        break;
      case EditingPointType.destination:
        _routePlanningData.setDestination(RoutePoint(
          id: 'destination',
          name: name,
          coordinates: coordinates,
          type: RoutePointType.destination,
        ));
        break;
      case EditingPointType.stopover:
        _routePlanningData.replaceStopover(
          _currentEditingStopoverIndex,
          RoutePoint(
            id: 'stopover_$_currentEditingStopoverIndex',
            name: name,
            coordinates: coordinates,
            type: RoutePointType.stopover,
          ),
        );
        break;
      case EditingPointType.newStopover:
        _routePlanningData.addStopover(RoutePoint(
          id: 'stopover_${_routePlanningData.stopovers.length}',
          name: name,
          coordinates: coordinates,
          type: RoutePointType.stopover,
        ));
        break;
      default:
        break;
    }

    setState(() {
      _currentEditingType = EditingPointType.none;
      _currentEditingStopoverIndex = -1;
    });

    // 尝试生成路线
    _tryGenerateRoute();
  }

  /// 编辑类型变化回调
  void _onEditingTypeChanged(EditingPointType type, int stopoverIndex) {
    setState(() {
      _currentEditingType = type;
      _currentEditingStopoverIndex = stopoverIndex;
    });
  }

  /// 路线点选择回调
  void _onRoutePointSelected(
    Position coordinates,
    String name,
    RoutePointType type,
    int stopoverIndex,
  ) {
    switch (type) {
      case RoutePointType.origin:
        _routePlanningData.setOrigin(RoutePoint(
          id: 'origin',
          name: name,
          coordinates: coordinates,
          type: RoutePointType.origin,
        ));
        break;
      case RoutePointType.destination:
        _routePlanningData.setDestination(RoutePoint(
          id: 'destination',
          name: name,
          coordinates: coordinates,
          type: RoutePointType.destination,
        ));
        break;
      case RoutePointType.stopover:
        if (stopoverIndex >= 0) {
          _routePlanningData.replaceStopover(
            stopoverIndex,
            RoutePoint(
              id: 'stopover_$stopoverIndex',
              name: name,
              coordinates: coordinates,
              type: RoutePointType.stopover,
            ),
          );
        } else {
          _routePlanningData.addStopover(RoutePoint(
            id: 'stopover_${_routePlanningData.stopovers.length}',
            name: name,
            coordinates: coordinates,
            type: RoutePointType.stopover,
          ));
        }
        break;
    }

    setState(() {});
    _tryGenerateRoute();
  }

  /// 删除路线点
  void _onRemoveRoutePoint(int index) {
    _routePlanningData.removePointAt(index);
    setState(() {});
    _tryGenerateRoute();
  }

  /// 重新排序路线点
  void _onReorderRoutePoints(int oldIndex, int newIndex) {
    _routePlanningData.reorderAllPoints(oldIndex, newIndex);
    setState(() {});
    _tryGenerateRoute();
  }

  /// 使用当前位置作为路线点
  void _onUseCurrentLocationForRoute(RoutePointType type) {
    final manager = Provider.of<SessionManager>(context, listen: false);
    final position = manager.currentPosition;

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取当前位置')),
      );
      return;
    }

    final coordinates = Position(position.longitude, position.latitude);
    final name = '当前位置';

    _onRoutePointSelected(coordinates, name, type, -1);
  }

  /// 将 POI 设置为路线点
  void _setPOIAsRoutePoint(RoutePointType type) {
    if (_selectedPOIPosition == null) return;

    final name = _selectedPOIName ??
        '${_selectedPOIPosition!.lat.toStringAsFixed(4)}, ${_selectedPOIPosition!.lng.toStringAsFixed(4)}';

    // 如果路线规划面板未打开，先打开
    if (!_showRoutePlanningPanel) {
      setState(() {
        _showRoutePlanningPanel = true;
      });
    }

    _onRoutePointSelected(_selectedPOIPosition!, name, type, -1);
    _closePOIPanel();
  }

  /// 尝试生成路线
  Future<void> _tryGenerateRoute() async {
    if (!_routePlanningData.canGenerateRoute) {
      setState(() {
        _currentRoute = null;
      });
      _removeRouteLayer();
      return;
    }

    final origin = _routePlanningData.origin!;
    final destination = _routePlanningData.destination!;
    final stopovers = _routePlanningData.stopovers
        .map((s) =>
            LatLng(s.coordinates.lat.toDouble(), s.coordinates.lng.toDouble()))
        .toList();

    try {
      final route = await _routeEngine.generateRoute(
        startCoordinate: LatLng(origin.coordinates.lat.toDouble(),
            origin.coordinates.lng.toDouble()),
        endCoordinate: LatLng(destination.coordinates.lat.toDouble(),
            destination.coordinates.lng.toDouble()),
        stopovers: stopovers.isNotEmpty ? stopovers : null,
        selectedResortKey: _selectedResortKey,
      );

      setState(() {
        _currentRoute = route;
      });

      if (route != null) {
        await _displayRoute(route);
      }
    } catch (e) {
      debugPrint('Error generating route: $e');
    }
  }

  /// 显示路线
  Future<void> _displayRoute(re.Route route) async {
    if (_mapboxMap == null) return;

    // 先移除旧的路线图层
    await _removeRouteLayer();

    // 从路线步骤中提取坐标
    final coordinates = <List<double>>[];
    for (final step in route.steps) {
      for (final loc in [step.maneuver.location]) {
        coordinates.add(loc);
      }
    }

    if (coordinates.isEmpty) return;

    // 创建 GeoJSON
    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
          'properties': {},
        }
      ],
    };

    try {
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'route_source', data: json.encode(geojson)),
      );

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'route_layer',
          sourceId: 'route_source',
          lineColor: 0xFF1A5AD0, // 路线颜色
          lineWidth: 8.0,
          lineOpacity: 0.8,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );
    } catch (e) {
      debugPrint('Error displaying route: $e');
    }
  }

  /// 移除路线图层
  Future<void> _removeRouteLayer() async {
    if (_mapboxMap == null) return;

    try {
      await _mapboxMap!.style.removeStyleLayer('route_layer');
    } catch (e) {
      // 图层可能不存在
    }

    try {
      await _mapboxMap!.style.removeStyleSource('route_source');
    } catch (e) {
      // 数据源可能不存在
    }
  }
}
