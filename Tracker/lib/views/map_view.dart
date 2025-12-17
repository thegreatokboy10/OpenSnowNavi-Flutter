import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:polyline_codec/polyline_codec.dart';
import 'package:provider/provider.dart';
import '../config/mapbox_config.dart';
import '../config/ski_resorts.dart';
import '../config/app_theme.dart';
import '../models/piste.dart';
import '../models/lift.dart';
import '../models/route_planning_state.dart';
import '../services/session_manager.dart';
import '../services/route_engine.dart' as re;
import '../services/search_service.dart';
import '../widgets/route_planning_panel.dart';
import '../widgets/poi_info_panel.dart';
import '../widgets/team_panel.dart';
import '../team/team_service.dart';
import '../meeting_point/meeting_point_service.dart';
import '../meeting_point/meeting_point_model.dart';

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

  // Marker 管理器
  CircleAnnotationManager? _poiCircleManager;
  CircleAnnotationManager? _routePointsCircleManager;
  CircleAnnotationManager? _stepCircleManager;

  // ✅ Route polyline managers (用 annotations 画整条路线，保证稳定显示)
  PolylineAnnotationManager? _routePolylineManager;
  PolylineAnnotationManager? _routeOutlinePolylineManager;

  // 团队相关状态
  bool _showTeamPanel = false;
  List<MemberLocation> _memberLocations = [];
  CircleAnnotationManager? _memberCircleManager;
  CircleAnnotationManager? _meetingPointCircleManager;
  List<MeetingPoint> _meetingPoints = [];
  bool _showMeetingPointsLayer = true;

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
                      onStepTap: _highlightRouteStep,
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
                      isInTeamMode: TeamService.instance.currentTeam != null,
                      onAddAsMeetingPoint: _addPOIAsMeetingPoint,
                    ),
                  ),

                // 雪场选择器弹窗
                if (_showResortSelector) _buildResortSelectorOverlay(),

                // 图层选择器弹窗
                if (_showLayerSelector) _buildLayerSelectorOverlay(),

                // 团队面板
                if (_showTeamPanel)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 60,
                    child: TeamPanel(
                      resortKey: _selectedResortKey,
                      onClose: () => setState(() => _showTeamPanel = false),
                      onMemberLocationsUpdate: _onMemberLocationsUpdate,
                      onMemberTapped: _onMemberTapped,
                      onTeamJoined: _onTeamJoined,
                    ),
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

    // 等待样式完全加载
    await Future.delayed(const Duration(milliseconds: 500));

    // 先尝试获取位置并选择最近的雪场
    await _selectNearestResortAndReload();

    // 如果 _selectNearestResortAndReload 没有加载数据（因为已经是默认雪场）
    // 则在这里加载默认雪场数据
    if (_showResortData) {
      // 检查是否已经加载过数据
      bool hasData = false;
      try {
        await _mapboxMap!.style.getSource('runs_source');
        hasData = true;
      } catch (e) {
        hasData = false;
      }

      if (!hasData) {
        debugPrint('Loading default resort data...');
        await _loadSkiResortData();
      }
    }

    // 自动定位到当前位置
    await _goToCurrentLocation();
    _initialLocationSet = true;
  }

  /// 选择最近的雪场并重新加载数据
  Future<void> _selectNearestResortAndReload() async {
    final manager = Provider.of<SessionManager>(context, listen: false);
    var position = manager.currentPosition;

    // 如果 SessionManager 中没有位置，等待一小段时间再试
    if (position == null) {
      debugPrint('Position not available, waiting 500ms...');
      await Future.delayed(const Duration(milliseconds: 500));
      position = manager.currentPosition;
    }

    if (position == null) {
      debugPrint(
          'Still no position, using default resort: $_selectedResortKey');
      return;
    }

    debugPrint(
        'Finding nearest resort from: ${position.latitude}, ${position.longitude}');

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

      debugPrint(
          'Resort ${entry.key}: ${(distance / 1000).toStringAsFixed(1)} km');

      if (distance < minDistance) {
        minDistance = distance;
        nearestResortKey = entry.key;
      }
    }

    debugPrint(
        'Nearest resort: $nearestResortKey (${(minDistance / 1000).toStringAsFixed(1)} km)');

    if (nearestResortKey != _selectedResortKey) {
      // 切换到最近的雪场
      setState(() {
        _selectedResortKey = nearestResortKey;
      });
      // 重新加载该雪场的数据
      if (_showResortData) {
        await _loadSkiResortData();
      }
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

        // 团队滑雪按钮
        _buildFloatingButton(
          icon: Icons.group,
          onPressed: () => setState(() => _showTeamPanel = !_showTeamPanel),
          isActive: _showTeamPanel,
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
    Color? color,
  }) {
    final buttonColor = color ?? Colors.blue;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: isActive ? buttonColor : Colors.white,
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
            color: isActive ? Colors.white : buttonColor,
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

    // 先移除旧的图层
    await _removeSkiResortLayers();

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

      String processedGeojson;
      if (isRuns) {
        final pistes = _parsePistesFromGeoJson(geojsonData);
        debugPrint('Parsed ${pistes.length} pistes (downhill/connection only)');
        processedGeojson = json.encode(_pistesToGeoJson(pistes));
      } else {
        final lifts = _parseLiftsFromGeoJson(geojsonData);
        debugPrint('Parsed ${lifts.length} lifts');
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
  List<Piste> _parsePistesFromGeoJson(Map<String, dynamic> geojsonData) {
    final features = geojsonData['features'] as List<dynamic>? ?? [];
    final pistes = <Piste>[];

    for (final feature in features) {
      try {
        final piste = Piste.fromGeoJson(feature as Map<String, dynamic>);
        pistes.add(piste);
      } catch (e) {
        // skip
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

  Map<String, dynamic> _pistesToGeoJson(List<Piste> pistes) {
    return {
      'type': 'FeatureCollection',
      'features': pistes.map((p) => p.toFeature()).toList(),
    };
  }

  Map<String, dynamic> _liftsToGeoJson(List<Lift> lifts) {
    return {
      'type': 'FeatureCollection',
      'features': lifts.map((l) => l.toFeature()).toList(),
    };
  }

  Future<void> _addRunsLayers(
    String sourceId,
    String layerId, {
    double? opacity,
  }) async {
    if (_mapboxMap == null) return;

    final difficulties = [
      'connection',
      'novice',
      'easy',
      'intermediate',
      'advanced',
      'expert',
      'freeride',
    ];

    final effectiveOpacity = opacity ?? SkiResorts.strokeOpacity;

    for (final difficulty in difficulties) {
      final color = SkiResorts.difficultyColors[difficulty] ?? 0xFF888888;

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: '${layerId}_$difficulty',
          sourceId: sourceId,
          lineColor: color,
          lineWidth: SkiResorts.pisteLineWidth,
          lineOpacity: effectiveOpacity,
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

  Future<void> _addLiftsLayer(String sourceId, String layerId,
      {double? opacity}) async {
    if (_mapboxMap == null) return;

    final effectiveOpacity = opacity ?? SkiResorts.liftStrokeOpacity;

    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: layerId,
        sourceId: sourceId,
        lineColor: SkiResorts.liftColor,
        lineWidth: SkiResorts.liftLineWidth,
        lineOpacity: effectiveOpacity,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Future<void> _removeSkiResortLayers() async {
    if (_mapboxMap == null) return;

    final layersToRemove = [
      'runs_connection',
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
      } catch (e) {}
    }

    for (final sourceId in sourcesToRemove) {
      try {
        await _mapboxMap!.style.removeStyleSource(sourceId);
      } catch (e) {}
    }
  }

  // ==================== 路线规划相关方法 ====================

  LatLng? _getResortLatLng() {
    final resortData = SkiResorts.list[_selectedResortKey];
    if (resortData == null) return null;
    final coord = resortData['coordinate'] as Map<String, dynamic>;
    return LatLng(coord['lat'] as double, coord['lng'] as double);
  }

  void _toggleRoutePlanningPanel() {
    setState(() {
      _showRoutePlanningPanel = !_showRoutePlanningPanel;
      if (!_showRoutePlanningPanel) {
        _routePlanningData.reset();
        _currentRoute = null;
        _removeRouteLayer();
      }
    });
  }

  void _closeRoutePlanningPanel() {
    setState(() {
      _showRoutePlanningPanel = false;
      _routePlanningData.reset();
      _currentRoute = null;
    });
    _removeRouteLayer();
    _removeRoutePointMarkers();
    _removePOIMarker();
    _removeStepMarker();
  }

  void _closePOIPanel() {
    setState(() {
      _showPOIPanel = false;
      _selectedPOIPosition = null;
      _selectedPOIName = null;
    });
    _removePOIMarker();
  }

  void _onMapTap(MapContentGestureContext context) {
    final point = context.point;
    final coordinates = point.coordinates;

    debugPrint('Map tapped at: ${coordinates.lat}, ${coordinates.lng}');

    if (_currentEditingType != EditingPointType.none) {
      _handleMapTapForRouteEditing(coordinates);
      return;
    }

    setState(() {
      _selectedPOIPosition = coordinates;
      _selectedPOIName = null;
      _showPOIPanel = true;
    });

    _showPOIMarker(coordinates);
  }

  Future<void> _showPOIMarker(Position coordinates) async {
    if (_mapboxMap == null) return;

    debugPrint('Showing POI marker at: ${coordinates.lat}, ${coordinates.lng}');

    await _removePOIMarker();

    try {
      final manager =
          await _mapboxMap!.annotations.createCircleAnnotationManager();
      _poiCircleManager = manager;

      final options = CircleAnnotationOptions(
        geometry: Point(coordinates: coordinates),
        circleRadius: 10.0,
        circleColor: SkiResorts.poiMarkerColor,
        circleStrokeColor: Colors.white.value,
        circleStrokeWidth: 2.0,
      );

      final annotation = await manager.create(options);
      debugPrint('POI marker created: ${annotation.id}');
    } catch (e) {
      debugPrint('Error showing POI marker: $e');
    }
  }

  Future<void> _removePOIMarker() async {
    if (_poiCircleManager != null && _mapboxMap != null) {
      try {
        await _mapboxMap!.annotations
            .removeAnnotationManager(_poiCircleManager!);
        _poiCircleManager = null;
      } catch (e) {}
    }
  }

  Future<void> _updateRoutePointMarkers() async {
    if (_mapboxMap == null) return;

    await _removeRoutePointMarkers();

    try {
      final manager =
          await _mapboxMap!.annotations.createCircleAnnotationManager();
      _routePointsCircleManager = manager;

      final List<CircleAnnotationOptions> options = [];

      if (_routePlanningData.origin != null) {
        options.add(CircleAnnotationOptions(
          geometry: Point(coordinates: _routePlanningData.origin!.coordinates),
          circleRadius: 12.0,
          circleColor: SkiResorts.originMarkerColor,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 3.0,
        ));
      }

      if (_routePlanningData.destination != null) {
        options.add(CircleAnnotationOptions(
          geometry:
              Point(coordinates: _routePlanningData.destination!.coordinates),
          circleRadius: 12.0,
          circleColor: SkiResorts.destinationMarkerColor,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 3.0,
        ));
      }

      for (final stopover in _routePlanningData.stopovers) {
        options.add(CircleAnnotationOptions(
          geometry: Point(coordinates: stopover.coordinates),
          circleRadius: 10.0,
          circleColor: SkiResorts.stopoverMarkerColor,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2.0,
        ));
      }

      if (options.isNotEmpty) {
        debugPrint('Creating ${options.length} route point markers');
        final annotations = await manager.createMulti(options);
        debugPrint('Created ${annotations.length} route point markers');
      }
    } catch (e) {
      debugPrint('Error updating route point markers: $e');
    }
  }

  Future<void> _removeRoutePointMarkers() async {
    if (_routePointsCircleManager != null && _mapboxMap != null) {
      try {
        await _mapboxMap!.annotations
            .removeAnnotationManager(_routePointsCircleManager!);
        _routePointsCircleManager = null;
      } catch (e) {}
    }
  }

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

    _updateRoutePointMarkers();
    _removePOIMarker();
    _tryGenerateRoute();
  }

  void _onEditingTypeChanged(EditingPointType type, int stopoverIndex) {
    setState(() {
      _currentEditingType = type;
      _currentEditingStopoverIndex = stopoverIndex;
    });
  }

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
    _updateRoutePointMarkers();
    _removePOIMarker();
    _tryGenerateRoute();
  }

  void _onRemoveRoutePoint(int index) {
    _routePlanningData.removePointAt(index);
    setState(() {});
    _updateRoutePointMarkers();
    _tryGenerateRoute();
  }

  void _onReorderRoutePoints(int oldIndex, int newIndex) {
    _routePlanningData.reorderAllPoints(oldIndex, newIndex);
    setState(() {});
    _updateRoutePointMarkers();
    _tryGenerateRoute();
  }

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
    const name = '当前位置';

    _onRoutePointSelected(coordinates, name, type, -1);
  }

  void _setPOIAsRoutePoint(RoutePointType type) {
    if (_selectedPOIPosition == null) return;

    final name = _selectedPOIName ??
        '${_selectedPOIPosition!.lat.toStringAsFixed(4)}, ${_selectedPOIPosition!.lng.toStringAsFixed(4)}';

    if (!_showRoutePlanningPanel) {
      setState(() {
        _showRoutePlanningPanel = true;
      });
    }

    _onRoutePointSelected(_selectedPOIPosition!, name, type, -1);
    _closePOIPanel();
  }

  /// 将当前选中的 POI 添加为集合点
  Future<void> _addPOIAsMeetingPoint() async {
    if (_selectedPOIPosition == null) return;

    final team = TeamService.instance.currentTeam;
    if (team == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先加入或创建团队')),
      );
      return;
    }

    // 弹出对话框让用户输入集合点名称
    final nameController = TextEditingController(
      text: _selectedPOIName ?? '集合点',
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加集合点'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '集合点名称',
            hintText: '请输入集合点名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await MeetingPointService.instance.addMeetingPoint(
        name: name,
        latitude: _selectedPOIPosition!.lat.toDouble(),
        longitude: _selectedPOIPosition!.lng.toDouble(),
      );

      // 刷新集合点列表
      await MeetingPointService.instance.loadMeetingPoints();

      _closePOIPanel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('集合点 "$name" 已添加')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加集合点失败: $e')),
        );
      }
    }
  }

  /// ✅ 整段替换后的版本：先 displayRoute，再 setState（你之前已经替换过也没问题）
  Future<void> _tryGenerateRoute() async {
    if (!_routePlanningData.canGenerateRoute) {
      await _removeRouteLayer();
      if (!mounted) return;
      setState(() {
        _currentRoute = null;
      });
      return;
    }

    final origin = _routePlanningData.origin!;
    final destination = _routePlanningData.destination!;
    final stopovers = _routePlanningData.stopovers
        .map((s) => LatLng(
              s.coordinates.lat.toDouble(),
              s.coordinates.lng.toDouble(),
            ))
        .toList();

    try {
      final route = await _routeEngine.generateRoute(
        startCoordinate: LatLng(
          origin.coordinates.lat.toDouble(),
          origin.coordinates.lng.toDouble(),
        ),
        endCoordinate: LatLng(
          destination.coordinates.lat.toDouble(),
          destination.coordinates.lng.toDouble(),
        ),
        stopovers: stopovers.isNotEmpty ? stopovers : null,
        selectedResortKey: _selectedResortKey,
      );

      if (route == null) {
        await _removeRouteLayer();
        if (!mounted) return;
        setState(() {
          _currentRoute = null;
        });
        return;
      }

      // ✅ 关键：先画整条路线（现在用 annotations，稳定显示）
      await _displayRoute(route);

      if (!mounted) return;
      setState(() {
        _currentRoute = route;
      });
    } catch (e, st) {
      debugPrint('Error generating route: $e');
      debugPrint(st.toString());
    }
  }

  /// ✅ 显示路线：用 PolylineAnnotationManager 绘制（稳定显示）
  Future<void> _displayRoute(re.Route route) async {
    if (_mapboxMap == null) return;

    debugPrint('Displaying route with ${route.steps.length} steps');

    // 先移除旧路线
    await _removeRouteLayer();

    // 淡化雪道和缆车图层
    await _fadeRunsAndLiftsLayers(true);

    final List<List<double>> allCoordinates = [];

    for (int i = 0; i < route.steps.length; i++) {
      final step = route.steps[i];
      debugPrint(
          'Step $i: ${step.name}, geometry length: ${step.geometry.length}');

      if (step.geometry.isEmpty) continue;

      final decoded = PolylineCodec.decode(step.geometry, precision: 5);
      debugPrint('Decoded ${decoded.length} coordinates for step $i');

      if (decoded.isEmpty) continue;

      // decoded: [lat,lng] -> [lng,lat]
      final coords =
          decoded.map((c) => [c[1].toDouble(), c[0].toDouble()]).toList();

      // 过滤掉连续重复点（可选：能避免某些 step 只有 1 点导致视觉怪）
      for (final c in coords) {
        if (allCoordinates.isEmpty) {
          allCoordinates.add(c);
        } else {
          final last = allCoordinates.last;
          if (last[0] != c[0] || last[1] != c[1]) {
            allCoordinates.add(c);
          }
        }
      }
    }

    debugPrint('Total coordinates: ${allCoordinates.length}');
    if (allCoordinates.length < 2) {
      debugPrint('Not enough coordinates to draw route polyline.');
      return;
    }

    final positions = allCoordinates.map((c) => Position(c[0], c[1])).toList();

    try {
      // 1) 描边（白色）
      _routeOutlinePolylineManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();

      await _routeOutlinePolylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: positions),
          lineColor: 0xFFFFFFFF,
          lineOpacity: 0.95,
          lineWidth: math.max(8.0, SkiResorts.routeLineWidth + 4.0),
          lineJoin: LineJoin.ROUND,
        ),
      );

      // 2) 主线（盖在描边上）
      _routePolylineManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();

      await _routePolylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: positions),
          lineColor: SkiResorts.routeColor,
          lineOpacity: 1.0,
          lineWidth: math.max(6.0, SkiResorts.routeLineWidth),
          lineJoin: LineJoin.ROUND,
        ),
      );

      debugPrint('Route polyline + outline created via annotations');

      await _fitCameraToRoute(allCoordinates);
    } catch (e, st) {
      debugPrint('Error displaying route with polyline annotations: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _fadeRunsAndLiftsLayers(bool fade) async {
    if (_mapboxMap == null) return;

    final opacity =
        fade ? SkiResorts.lowlightOpacity : SkiResorts.strokeOpacity;
    final liftOpacity =
        fade ? SkiResorts.lowlightOpacity : SkiResorts.liftStrokeOpacity;

    final difficulties = [
      'connection',
      'novice',
      'easy',
      'intermediate',
      'advanced',
      'expert',
      'freeride',
    ];

    for (final difficulty in difficulties) {
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
          'runs_$difficulty',
          'line-opacity',
          opacity,
        );
      } catch (e) {}
    }

    try {
      await _mapboxMap!.style.setStyleLayerProperty(
        'lifts',
        'line-opacity',
        liftOpacity,
      );
    } catch (e) {}
  }

  Future<void> _fitCameraToRoute(List<List<double>> coordinates) async {
    if (_mapboxMap == null || coordinates.isEmpty) return;

    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;

    for (final coord in coordinates) {
      final lng = coord[0];
      final lat = coord[1];
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    const padding = 0.002;
    minLng -= padding;
    maxLng += padding;
    minLat -= padding;
    maxLat += padding;

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    try {
      final edgeInsets = _showRoutePlanningPanel
          ? MbxEdgeInsets(top: 420, left: 20, bottom: 100, right: 70)
          : MbxEdgeInsets(top: 100, left: 20, bottom: 100, right: 70);

      final camera = await _mapboxMap!.cameraForCoordinateBounds(
        bounds,
        edgeInsets,
        null,
        null,
        null,
        null,
      );

      await _mapboxMap!.flyTo(
        camera,
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('Error fitting camera to route: $e');
    }
  }

  /// ✅ 移除路线：清理 polyline managers + 高亮层
  Future<void> _removeRouteLayer() async {
    if (_mapboxMap == null) return;

    // 移除高亮图层
    try {
      await _mapboxMap!.style.removeStyleLayer('route_highlight_layer');
    } catch (e) {}
    try {
      await _mapboxMap!.style.removeStyleSource('route_highlight_source');
    } catch (e) {}

    // 清理整条路线（Polyline annotations）
    try {
      if (_routePolylineManager != null) {
        await _routePolylineManager!.deleteAll();
        await _mapboxMap!.annotations
            .removeAnnotationManager(_routePolylineManager!);
        _routePolylineManager = null;
      }
    } catch (e) {}

    try {
      if (_routeOutlinePolylineManager != null) {
        await _routeOutlinePolylineManager!.deleteAll();
        await _mapboxMap!.annotations
            .removeAnnotationManager(_routeOutlinePolylineManager!);
        _routeOutlinePolylineManager = null;
      }
    } catch (e) {}

    // 兼容旧残留（你之前用 style layer 画 route 时留下的）
    try {
      await _mapboxMap!.style.removeStyleLayer('route_layer');
    } catch (e) {}
    try {
      await _mapboxMap!.style.removeStyleLayer('route_layer_outline');
    } catch (e) {}
    try {
      await _mapboxMap!.style.removeStyleSource('route_source');
    } catch (e) {}

    await _fadeRunsAndLiftsLayers(false);
  }

  /// 高亮显示路线中的某一步（保持你原来的实现）
  Future<void> _highlightRouteStep(int stepIndex) async {
    if (_mapboxMap == null || _currentRoute == null) return;
    if (stepIndex < 0 || stepIndex >= _currentRoute!.steps.length) return;

    final step = _currentRoute!.steps[stepIndex];
    if (step.geometry.isEmpty) return;

    final decoded = PolylineCodec.decode(step.geometry, precision: 5);
    final coords =
        decoded.map((c) => [c[1].toDouble(), c[0].toDouble()]).toList();

    if (coords.isEmpty) return;

    try {
      await _mapboxMap!.style.removeStyleLayer('route_highlight_layer');
    } catch (e) {}
    try {
      await _mapboxMap!.style.removeStyleSource('route_highlight_source');
    } catch (e) {}

    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
          'properties': {'name': step.name},
        }
      ],
    };

    try {
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'route_highlight_source', data: json.encode(geojson)),
      );

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'route_highlight_layer',
          sourceId: 'route_highlight_source',
          lineColor: SkiResorts.highlightRouteColor,
          lineWidth: 12.0,
          lineOpacity: 0.9,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      await _fitCameraToRoute(coords);
      await _addStepMarker(coords.first);
    } catch (e) {
      debugPrint('Error highlighting route step: $e');
    }
  }

  Future<void> _addStepMarker(List<double> coord) async {
    if (_mapboxMap == null) return;

    await _removeStepMarker();

    try {
      final manager =
          await _mapboxMap!.annotations.createCircleAnnotationManager();
      _stepCircleManager = manager;

      final options = CircleAnnotationOptions(
        geometry: Point(coordinates: Position(coord[0], coord[1])),
        circleRadius: 14.0,
        circleColor: SkiResorts.highlightRouteColor,
        circleStrokeColor: Colors.white.value,
        circleStrokeWidth: 3.0,
      );

      await manager.create(options);
    } catch (e) {
      debugPrint('Error adding step marker: $e');
    }
  }

  Future<void> _removeStepMarker() async {
    if (_stepCircleManager != null) {
      try {
        await _mapboxMap!.annotations
            .removeAnnotationManager(_stepCircleManager!);
        _stepCircleManager = null;
      } catch (e) {}
    }
  }

  // ==================== 团队功能 ====================

  /// 成员位置更新回调
  void _onMemberLocationsUpdate(List<MemberLocation> locations) {
    _memberLocations = locations;
    _updateMemberMarkers();
  }

  /// 成员点击回调 - 定位到成员位置
  void _onMemberTapped(MemberLocation member) {
    if (_mapboxMap == null) return;

    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates:
              Position(member.location.longitude, member.location.latitude),
        ),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  /// 团队加入成功回调 - 初始化集合点服务
  void _onTeamJoined() {
    final teamService = TeamService.instance;
    final team = teamService.currentTeam;
    if (team != null) {
      MeetingPointService.instance.setContext(
        teamId: team.id,
        deviceId: teamService.deviceId,
        nickname: teamService.currentMember?.nickname ?? '',
      );
      _initializeMeetingPointService();
      MeetingPointService.instance.loadMeetingPoints();
    }
  }

  /// 更新成员位置标记
  Future<void> _updateMemberMarkers() async {
    if (_mapboxMap == null) return;

    // 移除旧的标记
    if (_memberCircleManager != null) {
      try {
        await _mapboxMap!.annotations
            .removeAnnotationManager(_memberCircleManager!);
        _memberCircleManager = null;
      } catch (e) {}
    }

    if (_memberLocations.isEmpty) return;

    // 创建新的标记管理器
    _memberCircleManager =
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    // 为每个成员创建标记
    for (final member in _memberLocations) {
      await _memberCircleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              member.location.longitude,
              member.location.latitude,
            ),
          ),
          circleRadius: 12.0,
          circleColor: member.color,
          circleStrokeWidth: 3.0,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    }
  }

  /// 初始化集合点服务
  void _initializeMeetingPointService() {
    final meetingPointService = MeetingPointService.instance;

    // 设置回调 - 集合点列表更新时刷新图层
    meetingPointService.onMeetingPointsUpdated = (points) {
      _meetingPoints = points;
      _updateMeetingPointMarkers();
    };

    // 设置回调 - 活动集合点变化时更新图层和规划路线
    meetingPointService.onActiveMeetingPointChanged = (activePoint) {
      _updateMeetingPointMarkers();
      // 如果有活动集合点，自动规划路线
      if (activePoint != null && _currentRoute == null) {
        _planRouteToMeetingPoint(activePoint);
      }
    };
  }

  /// 更新集合点标记
  Future<void> _updateMeetingPointMarkers() async {
    if (_mapboxMap == null) return;

    // 移除旧的标记
    if (_meetingPointCircleManager != null) {
      try {
        await _mapboxMap!.annotations
            .removeAnnotationManager(_meetingPointCircleManager!);
        _meetingPointCircleManager = null;
      } catch (e) {}
    }

    if (!_showMeetingPointsLayer || _meetingPoints.isEmpty) return;

    // 创建新的标记管理器
    _meetingPointCircleManager =
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    // 为每个集合点创建标记
    for (final point in _meetingPoints) {
      // 活动集合点使用更大的圆圈和不同的颜色
      final isActive = point.isActive;
      await _meetingPointCircleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(point.longitude, point.latitude),
          ),
          circleRadius: isActive ? 15.0 : 12.0,
          circleColor: isActive
              ? AppTheme.meetingPointActiveColorInt
              : AppTheme.meetingPointColorInt,
          circleStrokeWidth: isActive ? 4.0 : 2.0,
          circleStrokeColor: isActive ? 0xFFFFFFFF : 0xFFE3F2FD,
        ),
      );
    }
  }

  /// 规划路线到集合点
  Future<void> _planRouteToMeetingPoint(MeetingPoint meetingPoint) async {
    try {
      // 获取当前位置作为起点
      final currentPosition = await _getCurrentPosition();
      if (currentPosition == null) {
        debugPrint('Cannot plan route: current position not available');
        return;
      }

      // 设置起点和终点
      _routePlanningData.origin = RoutePoint(
        id: 'origin',
        name: '当前位置',
        coordinates: currentPosition,
        type: RoutePointType.origin,
      );
      _routePlanningData.destination = RoutePoint(
        id: 'destination',
        name: meetingPoint.name,
        coordinates: Position(meetingPoint.longitude, meetingPoint.latitude),
        type: RoutePointType.destination,
      );

      // 显示路线规划面板
      setState(() {
        _showRoutePlanningPanel = true;
      });

      // 自动算路
      await _tryGenerateRoute();

      debugPrint('Auto-planned route to meeting point: ${meetingPoint.name}');
    } catch (e) {
      debugPrint('Failed to plan route to meeting point: $e');
    }
  }

  /// 获取当前位置
  Future<Position?> _getCurrentPosition() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      return Position(position.longitude, position.latitude);
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }
}
