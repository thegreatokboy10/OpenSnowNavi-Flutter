import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/mapbox_config.dart';
import '../models/session.dart';
import '../models/location_point.dart';
import '../models/session_media.dart';
import '../services/session_manager.dart';
import '../services/media_gallery_service.dart';
import 'package:photo_manager/photo_manager.dart' show PermissionState;
import '../utils/gpx_exporter.dart';
import '../utils/statistics.dart';
import '../widgets/media_marker_icon_generator.dart';
import '../widgets/media_viewer_dialog.dart';

/// Session 详情视图
class SessionDetailView extends StatefulWidget {
  final Session session;

  const SessionDetailView({super.key, required this.session});

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView> {
  List<LocationPoint> _points = [];
  bool _isLoading = true;
  SessionStatistics? _stats;

  // 媒体标注相关状态
  List<SessionMedia> _mediaItems = [];
  bool _isLoadingMedia = false;
  bool _showMediaMarkers = true;
  bool _hasMediaPermission = false;
  PointAnnotationManager? _mediaMarkerManager;
  final Map<String, SessionMedia> _mediaAnnotationMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mediaMarkerManager = null;
    super.dispose();
  }

  Future<void> _loadData() async {
    final manager = context.read<SessionManager>();
    final points = await manager.fetchLocationPoints(widget.session.id);

    // 检测统计数据是否有效（中断的轨迹可能统计数据为0）
    final sessionStats = SessionStatistics.fromSession(widget.session);
    final needRecalculate = points.isNotEmpty &&
        sessionStats.totalDistance == 0 &&
        sessionStats.maxSpeed == 0 &&
        sessionStats.totalElevationGain == 0;

    SessionStatistics stats;
    if (needRecalculate) {
      // 从轨迹点重新计算统计数据
      stats = SessionStatistics.fromPoints(points);
      debugPrint(
          '[SessionDetailView] Recalculated stats from ${points.length} points: '
          'distance=${stats.totalDistance}m, maxSpeed=${stats.maxSpeed}m/s');

      // 保存重新计算的统计数据到数据库
      widget.session.totalDistance = stats.totalDistance;
      widget.session.skiingDistance = stats.totalDistance;
      widget.session.maxSpeed = stats.maxSpeed;
      widget.session.totalElevationGain = stats.totalElevationGain;
      widget.session.totalElevationLoss = stats.totalElevationLoss;
      await manager.updateSession(widget.session);
    } else {
      stats = sessionStats;
    }

    setState(() {
      _points = points;
      _stats = stats;
      _isLoading = false;
    });

    // 加载媒体（在轨迹加载完成后）
    _loadSessionMedia();
  }

  /// 加载滑行期间拍摄的照片和视频
  Future<void> _loadSessionMedia() async {
    if (widget.session.endTime == null) return;

    setState(() => _isLoadingMedia = true);

    try {
      final mediaService = MediaGalleryService();

      // 请求权限
      final permission = await mediaService.requestPermission();
      // 检查是否有权限（authorized 或 limited 都可以访问）
      _hasMediaPermission = permission == PermissionState.authorized ||
          permission == PermissionState.limited;

      if (!_hasMediaPermission) {
        debugPrint('[SessionDetailView] Photo library permission denied');
        if (mounted) {
          setState(() => _isLoadingMedia = false);
        }
        return;
      }

      // 加载时间范围内的媒体
      _mediaItems = await mediaService.loadSessionMedia(
        startTime: widget.session.startTime,
        endTime: widget.session.endTime!,
      );

      debugPrint(
          '[SessionDetailView] Found ${_mediaItems.length} media items with GPS');

      // 如果地图已经加载，添加媒体标注
      if (_mapboxMap != null && _showMediaMarkers && _mediaItems.isNotEmpty) {
        await _addMediaMarkers(_mapboxMap!);
      }
    } catch (e) {
      debugPrint('[SessionDetailView] Failed to load media: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  Future<void> _exportGPX() async {
    final path = await GPXExporter.exportToFile(widget.session, _points);
    if (path != null) {
      await Share.shareXFiles([XFile(path)], text: 'Ski Session GPX');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export GPX')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          // 媒体标注开关
          if (_mediaItems.isNotEmpty)
            IconButton(
              icon: Icon(
                _showMediaMarkers ? Icons.photo_library : Icons.photo_library_outlined,
                color: _showMediaMarkers ? Colors.orange : null,
              ),
              onPressed: _toggleMediaMarkers,
              tooltip: _showMediaMarkers ? '隐藏照片' : '显示照片',
            ),
          // 加载媒体指示器
          if (_isLoadingMedia)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _points.isEmpty ? null : _exportGPX,
            tooltip: 'Export GPX',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(flex: 2, child: _buildMap()),
                Expanded(flex: 1, child: _buildStats()),
              ],
            ),
    );
  }

  MapboxMap? _mapboxMap;

  Widget _buildMap() {
    if (_points.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: Text('No track data')),
      );
    }

    // 计算边界
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final p in _points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final center = Point(coordinates: Position(centerLng, centerLat));

    return MapWidget(
      cameraOptions: CameraOptions(
        center: center,
        zoom: 14,
      ),
      styleUri: MapboxConfig.styleUrl,
      onMapCreated: (mapboxMap) async {
        _mapboxMap = mapboxMap;
        // 先添加 OpenSnowMap 图层（在轨迹下面）
        await _addOpenSnowMapLayer(mapboxMap);
        await _addTrackLine(mapboxMap);
        await _addMarkers(mapboxMap);
        // 调整相机以适应轨迹
        await _fitBounds(mapboxMap, minLat, maxLat, minLng, maxLng);
        // 添加媒体标注（如果已加载）
        if (_mediaItems.isNotEmpty && _showMediaMarkers) {
          await _addMediaMarkers(mapboxMap);
        }
      },
    );
  }

  /// 添加 OpenSnowMap 图层用于对照轨迹和雪道
  Future<void> _addOpenSnowMapLayer(MapboxMap mapboxMap) async {
    const sourceId = 'opensnowmap-source';
    const layerId = 'opensnowmap-layer';

    try {
      await mapboxMap.style.addSource(
        RasterSource(
          id: sourceId,
          tiles: ['https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png'],
          tileSize: 256,
        ),
      );
      await mapboxMap.style.addLayer(
        RasterLayer(
          id: layerId,
          sourceId: sourceId,
          rasterOpacity: 0.7,
        ),
      );
    } catch (e) {
      debugPrint('Error adding OpenSnowMap layer: $e');
    }
  }

  Future<void> _addTrackLine(MapboxMap mapboxMap) async {
    // 创建 GeoJSON LineString
    final coordinates = _points.map((p) => [p.longitude, p.latitude]).toList();
    final geoJson = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
    };

    // 添加 source
    await mapboxMap.style.addSource(
      GeoJsonSource(id: 'track-source', data: jsonEncode(geoJson)),
    );

    // 添加 line layer
    await mapboxMap.style.addLayer(
      LineLayer(
        id: 'track-layer',
        sourceId: 'track-source',
        lineColor: Colors.orange.value,
        lineWidth: 4.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Future<void> _addMarkers(MapboxMap mapboxMap) async {
    final startPoint = _points.first;
    final endPoint = _points.last;

    // 添加起点和终点标记
    final pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // 起点标记 (绿色)
    await pointAnnotationManager.create(
      PointAnnotationOptions(
        geometry: Point(
            coordinates: Position(startPoint.longitude, startPoint.latitude)),
        iconSize: 1.5,
        textField: '▶',
        textSize: 24.0,
        textColor: Colors.green.value,
      ),
    );

    // 终点标记 (红色)
    await pointAnnotationManager.create(
      PointAnnotationOptions(
        geometry:
            Point(coordinates: Position(endPoint.longitude, endPoint.latitude)),
        iconSize: 1.5,
        textField: '■',
        textSize: 24.0,
        textColor: Colors.red.value,
      ),
    );
  }

  /// 计算每个位置的媒体数量（用于显示数量徽章）
  /// 返回: Map<媒体ID, 该位置的媒体数量>
  Map<String, int> _calculateLocationCounts() {
    const double threshold = 0.00001; // 约1米的经纬度差异
    final counts = <String, int>{};

    for (int i = 0; i < _mediaItems.length; i++) {
      final media = _mediaItems[i];
      int count = 1;

      // 检查有多少其他媒体在相同位置
      for (int j = 0; j < _mediaItems.length; j++) {
        if (i == j) continue;
        final other = _mediaItems[j];
        if ((media.latitude - other.latitude).abs() < threshold &&
            (media.longitude - other.longitude).abs() < threshold) {
          count++;
        }
      }

      counts[media.id] = count;
    }

    return counts;
  }

  /// 添加媒体标注（照片/视频）- 不做手动聚合，让 Mapbox 自然处理重叠
  Future<void> _addMediaMarkers(MapboxMap mapboxMap) async {
    if (_mediaItems.isEmpty) return;

    // 清理现有的媒体标注管理器
    await _removeMediaMarkers();

    // 计算每个位置的媒体数量
    final locationCounts = _calculateLocationCounts();

    // 创建新的标注管理器
    _mediaMarkerManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    // 不允许图标重叠 - Mapbox 会自动隐藏重叠的标注，放大后再显示
    await _mediaMarkerManager!.setIconAllowOverlap(false);
    await _mediaMarkerManager!.setIconIgnorePlacement(false);

    // 注册点击事件
    _mediaMarkerManager!.tapEvents(
      onTap: (PointAnnotation annotation) {
        debugPrint('[SessionDetailView] Tapped annotation: ${annotation.id}');
        final media = _mediaAnnotationMap[annotation.id];
        if (media != null) {
          _showMediaViewer(media);
        }
      },
    );

    // 为每个媒体创建标注
    final mediaService = MediaGalleryService();
    for (final media in _mediaItems) {
      // 获取缩略图
      Uint8List? thumbnail = media.thumbnailData;
      thumbnail ??= await mediaService.getThumbnail(media.id, size: 150);

      if (thumbnail == null) continue;

      // 获取该位置的媒体数量
      final count = locationCounts[media.id] ?? 1;

      // 生成圆形缩略图标注（如果同位置有多个媒体，显示数量徽章）
      Uint8List iconData;
      if (count > 1) {
        iconData = await MediaMarkerIconGenerator.generateClusterIcon(
          thumbnailData: thumbnail,
          count: count,
          hasVideo: media.type == MediaType.video,
          size: 100,
        );
      } else {
        iconData = await MediaMarkerIconGenerator.generateThumbnailIcon(
          thumbnailData: thumbnail,
          isVideo: media.type == MediaType.video,
          size: 100,
        );
      }

      // 创建标注
      final annotation = await _mediaMarkerManager!.create(
        PointAnnotationOptions(
          geometry: media.point,
          image: iconData,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );

      // 保存映射关系
      _mediaAnnotationMap[annotation.id] = media;
    }

    debugPrint(
        '[SessionDetailView] Added ${_mediaAnnotationMap.length} media markers');
  }

  /// 移除媒体标注
  Future<void> _removeMediaMarkers() async {
    if (_mediaMarkerManager != null && _mapboxMap != null) {
      try {
        await _mapboxMap!.annotations
            .removeAnnotationManager(_mediaMarkerManager!);
      } catch (e) {
        debugPrint('[SessionDetailView] Error removing annotation manager: $e');
      }
      _mediaMarkerManager = null;
    }
    _mediaAnnotationMap.clear();
  }

  /// 显示媒体查看器
  void _showMediaViewer(SessionMedia media) {
    // 找到当前媒体在列表中的索引
    final index = _mediaItems.indexWhere((m) => m.id == media.id);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MediaViewerDialog(
        allMedia: _mediaItems,
        initialIndex: index >= 0 ? index : 0,
      ),
    );
  }

  /// 切换媒体标注显示/隐藏
  Future<void> _toggleMediaMarkers() async {
    setState(() => _showMediaMarkers = !_showMediaMarkers);

    if (_mapboxMap == null) return;

    if (_showMediaMarkers) {
      await _addMediaMarkers(_mapboxMap!);
    } else {
      await _removeMediaMarkers();
    }
  }

  Future<void> _fitBounds(MapboxMap mapboxMap, double minLat, double maxLat,
      double minLng, double maxLng) async {
    // 添加一些 padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = CoordinateBounds(
      southwest: Point(
          coordinates: Position(minLng - lngPadding, minLat - latPadding)),
      northeast: Point(
          coordinates: Position(maxLng + lngPadding, maxLat + latPadding)),
      infiniteBounds: false,
    );

    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(
            coordinates:
                Position((minLng + maxLng) / 2, (minLat + maxLat) / 2)),
      ),
    );

    // 使用 easeTo 来适应边界
    final cameraForBounds = await mapboxMap.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
      null,
      null,
      null,
      null,
    );
    await mapboxMap.flyTo(cameraForBounds, MapAnimationOptions(duration: 500));
  }

  Widget _buildStats() {
    if (_stats == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Total Duration',
                      _stats!.formattedTotalDuration, Icons.timer)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Skiing Duration',
                      _stats!.formattedSkiingDuration, Icons.downhill_skiing)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Total Distance',
                      _stats!.formattedTotalDistance, Icons.straighten)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Skiing Distance',
                      _stats!.formattedSkiingDistance, Icons.route)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Max Speed', _stats!.formattedMaxSpeed, Icons.speed)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Avg Speed',
                      _stats!.formattedAverageSpeed, Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Elevation Gain',
                      _stats!.formattedElevationGain, Icons.arrow_upward)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Elevation Loss',
                      _stats!.formattedElevationLoss, Icons.arrow_downward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
