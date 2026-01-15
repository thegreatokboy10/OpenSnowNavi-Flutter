import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../config/mapbox_config.dart';
import '../models/session.dart';
import '../models/location_point.dart';
import '../models/session_media.dart';
import '../models/replay_state.dart';
import '../services/session_manager.dart';
import '../services/media_gallery_service.dart';
import '../services/track_replay_service.dart';
import 'package:photo_manager/photo_manager.dart' show PermissionState;
import '../utils/gpx_exporter.dart';
import '../utils/statistics.dart';
import '../widgets/media_marker_icon_generator.dart';
import '../widgets/media_viewer_dialog.dart';
import '../widgets/track_replay_controller.dart';

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
  Set<String> _selectedMediaIds = {}; // 筛选后显示的媒体ID
  bool _isLoadingMedia = false;
  bool _showMediaMarkers = true;
  bool _hasMediaPermission = false;
  PointAnnotationManager? _mediaMarkerManager;
  final Map<String, SessionMedia> _mediaAnnotationMap = {};

  // 3D 回放相关状态
  TrackReplayService? _replayService;
  bool _isReplayMode = false;
  Timer? _lineUpdateTimer;
  double _lastCameraBearing = 0;

  // 回放 UI 自动隐藏
  bool _showReplayControls = true;
  Timer? _hideControlsTimer;
  static const _autoHideDelay = Duration(seconds: 3);

  // 用户位置标注
  PointAnnotationManager? _userMarkerManager;
  PointAnnotation? _userMarker;

  // 媒体回放相关
  Timer? _mediaOrbitTimer;
  double _orbitAngle = 0;
  Timer? _photoDisplayTimer;
  VideoPlayerController? _replayVideoController;
  File? _currentMediaFile; // 当前媒体文件
  Offset? _mediaScreenPosition; // 媒体在屏幕上的位置

  @override
  void initState() {
    super.initState();
    _replayService = TrackReplayService();
    _loadData();
  }

  @override
  void dispose() {
    _lineUpdateTimer?.cancel();
    _hideControlsTimer?.cancel();
    _mediaOrbitTimer?.cancel();
    _photoDisplayTimer?.cancel();
    _replayVideoController?.dispose();
    _replayService?.dispose();
    _mediaMarkerManager = null;
    _userMarkerManager = null;
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

      // 默认全选所有媒体
      _selectedMediaIds = _mediaItems.map((m) => m.id).toSet();

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
      appBar: _isReplayMode
          ? null // 回放模式隐藏导航栏
          : AppBar(
              title: const Text('Session Details'),
              actions: [
                // 3D 回放按钮
                if (_points.length >= 2)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: _startReplay,
                    tooltip: '3D 回放',
                  ),
                // 媒体标注开关
                if (_mediaItems.isNotEmpty)
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _showMediaMarkers
                              ? Icons.photo_library
                              : Icons.photo_library_outlined,
                          color: _showMediaMarkers ? Colors.orange : null,
                        ),
                        // 显示选中数量徽章
                        if (_selectedMediaIds.length < _mediaItems.length)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_selectedMediaIds.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: _toggleMediaMarkers,
                    tooltip: '显示/隐藏照片',
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
          : _isReplayMode
              ? _buildReplayView()
              : Column(
                  children: [
                    Expanded(flex: 2, child: _buildMap()),
                    Expanded(flex: 1, child: _buildStats()),
                  ],
                ),
    );
  }

  /// 构建回放模式视图
  Widget _buildReplayView() {
    return ListenableBuilder(
      listenable: _replayService!,
      builder: (context, _) {
        final isShowingMedia = _replayService?.isShowingMedia ?? false;
        final currentMedia = _replayService?.currentShowingMedia;

        return GestureDetector(
      onTap: _onReplayScreenTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 全屏地图
          Positioned.fill(child: _buildMap()),

          // 媒体预览（定位到GPS坐标上方，悬浮效果）
          if (isShowingMedia && currentMedia != null && _mediaScreenPosition != null)
            _buildPositionedMediaPreview(currentMedia),

          // 回放控制面板（带自动隐藏动画）
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 16,
            right: 16,
            bottom: _showReplayControls
                ? 32 + MediaQuery.of(context).padding.bottom
                : -200, // 隐藏时滑出屏幕
            child: TrackReplayController(
              replayService: _replayService!,
              onClose: _exitReplay,
              onTap: _onReplayControlInteraction,
            ),
          ),
          // 安全区域内的返回按钮（带自动隐藏动画）
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _showReplayControls
                ? MediaQuery.of(context).padding.top + 16
                : -60, // 隐藏时滑出屏幕
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _exitReplay,
              ),
            ),
          ),
          // 点击提示（控件隐藏时显示）
          if (!_showReplayControls && !isShowingMedia)
            Positioned(
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '点击屏幕显示控制面板',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
      },
    );
  }

  /// 构建定位到GPS坐标上方的媒体预览
  Widget _buildPositionedMediaPreview(SessionMedia media) {
    final screenSize = MediaQuery.of(context).size;
    final position = _mediaScreenPosition!;

    // 计算预览尺寸（屏幕宽度的50%，保持媒体比例）
    final previewWidth = screenSize.width * 0.5;
    final previewHeight = previewWidth * 4 / 3; // 默认4:3比例

    // 计算悬浮窗位置：在GPS坐标点上方，留出一定间距
    const markerOffset = 30.0; // 标记点到悬浮窗的间距
    const connectorHeight = 20.0; // 连接线高度

    // 悬浮窗底部对齐到标记点上方
    double left = position.dx - previewWidth / 2;
    double top = position.dy - previewHeight - markerOffset - connectorHeight;

    // 确保不超出屏幕边界
    final padding = MediaQuery.of(context).padding;
    left = left.clamp(8.0, screenSize.width - previewWidth - 8);
    top = top.clamp(padding.top + 8, screenSize.height - previewHeight - padding.bottom - 8);

    // 计算连接线的位置（从悬浮窗底部中心到GPS坐标点）
    final connectorStartX = left + previewWidth / 2;
    final connectorStartY = top + previewHeight;
    final connectorEndX = position.dx;
    final connectorEndY = position.dy - markerOffset / 2;

    return Stack(
      children: [
        // 连接线（从悬浮窗到标记点）
        CustomPaint(
          size: screenSize,
          painter: _ConnectorPainter(
            start: Offset(connectorStartX, connectorStartY),
            end: Offset(connectorEndX, connectorEndY),
          ),
        ),
        // 标记点
        Positioned(
          left: position.dx - 8,
          top: position.dy - 8,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        // 悬浮媒体预览
        Positioned(
          left: left,
          top: top,
          child: _buildMapMediaPreview(media, previewWidth, previewHeight),
        ),
      ],
    );
  }

  /// 构建地图上的媒体预览
  Widget _buildMapMediaPreview(SessionMedia media, double previewWidth, double previewHeight) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 媒体内容
              _buildMediaContent(media),

              // 跳过按钮
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _finishMediaOrbit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.skip_next, color: Colors.white, size: 20),
                        SizedBox(width: 4),
                        Text('跳过', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),

              // 视频进度条
              if (media.type == MediaType.video && _replayVideoController != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: VideoProgressIndicator(
                    _replayVideoController!,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(
                      playedColor: Colors.orange,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建媒体内容（照片或视频）
  Widget _buildMediaContent(SessionMedia media) {
    if (media.type == MediaType.video) {
      // 视频播放
      final controller = _replayVideoController;
      if (controller != null && controller.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      }
      // 视频加载中
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    } else {
      // 照片显示
      if (_currentMediaFile != null) {
        return Image.file(
          _currentMediaFile!,
          fit: BoxFit.cover,
        );
      }
      // 照片加载中，显示缩略图
      return FutureBuilder<Uint8List?>(
        future: _loadMediaThumbnail(media),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return Container(
            color: Colors.grey.shade800,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        },
      );
    }
  }

  /// 加载媒体缩略图
  Future<Uint8List?> _loadMediaThumbnail(SessionMedia media) async {
    if (media.thumbnailData != null) {
      return media.thumbnailData;
    }
    final mediaService = MediaGalleryService();
    return mediaService.getThumbnail(media.id, size: 300);
  }

  /// 回放屏幕点击事件
  void _onReplayScreenTap() {
    if (!_showReplayControls) {
      _showControlsTemporarily();
    }
  }

  /// 回放控件交互事件
  void _onReplayControlInteraction() {
    _showControlsTemporarily();
  }

  /// 临时显示控件
  void _showControlsTemporarily() {
    setState(() => _showReplayControls = true);
    _resetHideControlsTimer();
  }

  /// 重置自动隐藏定时器
  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_autoHideDelay, () {
      if (mounted && _isReplayMode) {
        setState(() => _showReplayControls = false);
      }
    });
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
  Map<String, int> _calculateLocationCounts(List<SessionMedia> mediaList) {
    const double threshold = 0.00001; // 约1米的经纬度差异
    final counts = <String, int>{};

    for (int i = 0; i < mediaList.length; i++) {
      final media = mediaList[i];
      int count = 1;

      // 检查有多少其他媒体在相同位置
      for (int j = 0; j < mediaList.length; j++) {
        if (i == j) continue;
        final other = mediaList[j];
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

    // 过滤出选中的媒体
    final selectedMedia = _mediaItems
        .where((m) => _selectedMediaIds.contains(m.id))
        .toList();

    if (selectedMedia.isEmpty) {
      await _removeMediaMarkers();
      return;
    }

    // 清理现有的媒体标注管理器
    await _removeMediaMarkers();

    // 计算每个位置的媒体数量（只计算选中的）
    final locationCounts = _calculateLocationCounts(selectedMedia);

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

    // 为每个选中的媒体创建标注
    final mediaService = MediaGalleryService();
    for (final media in selectedMedia) {
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

  /// 显示媒体查看器（带筛选功能）
  void _showMediaViewer(SessionMedia media) {
    // 找到当前媒体在列表中的索引
    final index = _mediaItems.indexWhere((m) => m.id == media.id);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MediaViewerDialog(
        allMedia: _mediaItems,
        initialIndex: index >= 0 ? index : 0,
        selectedIds: _selectedMediaIds,
        onSelectionChanged: _onMediaSelectionChanged,
      ),
    );
  }

  /// 媒体筛选变更回调
  Future<void> _onMediaSelectionChanged(Set<String> newSelection) async {
    setState(() => _selectedMediaIds = newSelection);

    // 刷新媒体标注
    if (_showMediaMarkers && _mapboxMap != null) {
      await _addMediaMarkers(_mapboxMap!);
    }
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

  // ==================== 3D 回放功能 ====================

  /// 开始回放模式
  Future<void> _startReplay() async {
    if (_points.isEmpty || _replayService == null) return;

    // 加载保存的配置
    await _replayService!.loadSavedConfig();

    // 处理轨迹
    await _replayService!.processTrack(_points);

    // 设置回放媒体（使用筛选后的媒体）
    final selectedMedia = _mediaItems
        .where((m) => _selectedMediaIds.contains(m.id))
        .toList();
    _replayService!.setMediaForReplay(selectedMedia);

    if (_replayService!.processedPoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('轨迹数据不足，无法回放')),
        );
      }
      return;
    }

    setState(() {
      _isReplayMode = true;
      _showReplayControls = true;
    });

    // 等待地图准备好
    await Future.delayed(const Duration(milliseconds: 100));

    if (_mapboxMap != null) {
      // 隐藏静态轨迹和标注
      await _hideStaticTrack();
      await _removeMediaMarkers();

      // 初始化回放轨迹图层
      await _initReplayTrackLayers();

      // 初始化用户标注
      await _initUserMarker();

      // 监听回放更新
      _replayService!.addListener(_onReplayUpdate);

      // 启动轨迹线更新定时器（频率低于相机更新）
      _lineUpdateTimer = Timer.periodic(
        Duration(milliseconds: _replayService!.config.lineUpdateIntervalMs),
        (_) => _updateReplayTrackLine(),
      );

      // 启动自动隐藏定时器
      _resetHideControlsTimer();

      // 开始播放
      _replayService!.play();
    }
  }

  /// 退出回放模式
  Future<void> _exitReplay() async {
    _lineUpdateTimer?.cancel();
    _lineUpdateTimer = null;
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
    _mediaOrbitTimer?.cancel();
    _mediaOrbitTimer = null;
    _photoDisplayTimer?.cancel();
    _photoDisplayTimer = null;
    _replayService?.removeListener(_onReplayUpdate);
    _replayService?.stop();

    if (_mapboxMap != null) {
      await _removeUserMarker();
      await _removeReplayTrackLayers();
      await _showStaticTrack();
      await _resetCameraToOverview();

      // 恢复媒体标注
      if (_mediaItems.isNotEmpty && _showMediaMarkers) {
        await _addMediaMarkers(_mapboxMap!);
      }
    }

    setState(() => _isReplayMode = false);
  }

  /// 回放更新回调
  void _onReplayUpdate() {
    final point = _replayService!.currentPoint;
    if (point != null && _isReplayMode && _mapboxMap != null) {
      // 检查是否正在展示媒体
      if (_replayService!.isShowingMedia) {
        return; // 展示媒体时不更新相机
      }

      // 检查是否到达媒体位置
      final media = _replayService!.checkMediaAtProgress(
        _replayService!.currentProgress,
      );
      if (media != null) {
        _startMediaOrbit(media);
        return;
      }

      _updateReplayCamera(point);
      _updateUserMarkerPosition(point);
    }

    // 检查是否结束
    if (_replayService!.playbackState == ReplayPlaybackState.finished) {
      // 回放结束，显示控件
      if (!_showReplayControls) {
        setState(() => _showReplayControls = true);
      }
      _hideControlsTimer?.cancel();
    }
  }

  /// 更新相机跟随回放位置
  Future<void> _updateReplayCamera(dynamic point) async {
    if (_mapboxMap == null) return;

    final config = _replayService!.config;

    // 计算目标方向差
    final targetBearing = point.bearing as double;
    double bearingDiff = ((targetBearing - _lastCameraBearing + 540) % 360) - 180;

    // 限制最大角速度（每帧最多转动的角度）
    // 基于更新间隔计算合理的最大角速度
    // 假设最大转速为 90°/秒
    const maxDegreesPerSecond = 90.0;
    final maxDeltaPerFrame = maxDegreesPerSecond * config.cameraUpdateIntervalMs / 1000;

    // 应用角速度限制
    if (bearingDiff.abs() > maxDeltaPerFrame) {
      bearingDiff = bearingDiff.sign * maxDeltaPerFrame;
    }

    // 应用平滑系数
    _lastCameraBearing =
        (_lastCameraBearing + bearingDiff * config.bearingSmoothingFactor + 360) % 360;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: point.point,
        zoom: config.cameraZoom,
        pitch: config.cameraPitch,
        bearing: _lastCameraBearing,
      ),
      MapAnimationOptions(duration: config.cameraUpdateIntervalMs),
    );
  }

  /// 初始化回放轨迹图层
  Future<void> _initReplayTrackLayers() async {
    if (_mapboxMap == null) return;

    try {
      // 添加 GeoJSON source（初始为空）
      await _mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'replay-track-source',
          data: '{"type":"FeatureCollection","features":[]}',
        ),
      );

      // 添加轨迹外边框（更宽、更深的颜色）
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'replay-track-outline-layer',
          sourceId: 'replay-track-source',
          lineColor: 0xFFCC6600, // 深橙色
          lineWidth: 6.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      // 添加主轨迹层
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'replay-track-layer',
          sourceId: 'replay-track-source',
          lineColor: Colors.orange.value,
          lineWidth: 4.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );
    } catch (e) {
      debugPrint('[SessionDetailView] Error initializing replay layers: $e');
    }
  }

  /// 更新回放轨迹线
  Future<void> _updateReplayTrackLine() async {
    if (_mapboxMap == null || _replayService == null) return;

    final coordinates = _replayService!.visibleTrackCoordinates;
    if (coordinates.length < 2) return;

    final geoJson = jsonEncode({
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates.map((p) => [p.lng, p.lat]).toList(),
      },
    });

    try {
      // 更新 source 数据
      final source =
          await _mapboxMap!.style.getSource('replay-track-source');
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geoJson);
      }
    } catch (e) {
      debugPrint('[SessionDetailView] Error updating replay track: $e');
    }
  }

  /// 移除回放轨迹图层
  Future<void> _removeReplayTrackLayers() async {
    if (_mapboxMap == null) return;

    try {
      await _mapboxMap!.style.removeStyleLayer('replay-track-layer');
      await _mapboxMap!.style.removeStyleLayer('replay-track-outline-layer');
      await _mapboxMap!.style.removeStyleSource('replay-track-source');
    } catch (e) {
      debugPrint('[SessionDetailView] Error removing replay layers: $e');
    }
  }

  /// 隐藏静态轨迹
  Future<void> _hideStaticTrack() async {
    if (_mapboxMap == null) return;

    try {
      await _mapboxMap!.style
          .setStyleLayerProperty('track-layer', 'visibility', 'none');
    } catch (e) {
      debugPrint('[SessionDetailView] Error hiding track: $e');
    }
  }

  /// 显示静态轨迹
  Future<void> _showStaticTrack() async {
    if (_mapboxMap == null) return;

    try {
      await _mapboxMap!.style
          .setStyleLayerProperty('track-layer', 'visibility', 'visible');
    } catch (e) {
      debugPrint('[SessionDetailView] Error showing track: $e');
    }
  }

  /// 重置相机到概览视角
  Future<void> _resetCameraToOverview() async {
    if (_mapboxMap == null || _points.isEmpty) return;

    // 计算边界
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final p in _points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // 重置相机（包括 pitch 和 bearing）
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = CoordinateBounds(
      southwest: Point(
          coordinates: Position(minLng - lngPadding, minLat - latPadding)),
      northeast: Point(
          coordinates: Position(maxLng + lngPadding, maxLat + latPadding)),
      infiniteBounds: false,
    );

    final cameraForBounds = await _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
      null,
      null,
      null,
      null,
    );

    // 重置 pitch 和 bearing
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: cameraForBounds.center,
        zoom: cameraForBounds.zoom,
        pitch: 0, // 恢复水平视角
        bearing: 0, // 恢复北向
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  // ==================== 用户标注 ====================

  /// 初始化用户位置标注
  Future<void> _initUserMarker() async {
    if (_mapboxMap == null) return;

    try {
      _userMarkerManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();

      // 获取初始位置
      final initialPoint = _replayService?.currentPoint;
      if (initialPoint == null) return;

      // 生成滑雪者图标
      final iconData = await MediaMarkerIconGenerator.generateUserMarkerIcon(
        size: 60,
      );

      // 创建用户标注
      _userMarker = await _userMarkerManager!.create(
        PointAnnotationOptions(
          geometry: initialPoint.point,
          image: iconData,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (e) {
      debugPrint('[SessionDetailView] Error creating user marker: $e');
    }
  }

  /// 更新用户标注位置
  Future<void> _updateUserMarkerPosition(dynamic point) async {
    if (_userMarker == null || _userMarkerManager == null) return;

    try {
      _userMarker!.geometry = point.point;
      await _userMarkerManager!.update(_userMarker!);
    } catch (e) {
      // 忽略更新错误，避免刷屏
    }
  }

  /// 移除用户标注
  Future<void> _removeUserMarker() async {
    if (_userMarkerManager != null && _mapboxMap != null) {
      try {
        await _mapboxMap!.annotations.removeAnnotationManager(_userMarkerManager!);
      } catch (e) {
        debugPrint('[SessionDetailView] Error removing user marker: $e');
      }
      _userMarkerManager = null;
      _userMarker = null;
    }
  }

  // ==================== 媒体环绕动画 ====================

  /// 开始媒体环绕展示
  Future<void> _startMediaOrbit(SessionMedia media) async {
    debugPrint('[SessionDetailView] Starting orbit for media: ${media.id}');

    // 暂停回放
    _replayService!.startShowingMedia(media);
    _orbitAngle = _lastCameraBearing; // 从当前角度开始

    // 初始化屏幕位置
    await _updateMediaScreenPosition(media);

    // 显示控件
    setState(() => _showReplayControls = true);
    _hideControlsTimer?.cancel();

    // 加载媒体文件
    await _loadMediaForReplay(media);

    // 开始环绕动画
    _mediaOrbitTimer?.cancel();
    _mediaOrbitTimer = Timer.periodic(
      const Duration(milliseconds: 50), // 20fps
      (timer) => _updateMediaOrbit(media),
    );

    // 处理照片/视频
    if (media.type == MediaType.photo) {
      // 照片：固定展示时长后自动继续
      final displaySeconds = _replayService!.config.photoDisplayDuration;
      _photoDisplayTimer?.cancel();
      _photoDisplayTimer = Timer(
        Duration(seconds: displaySeconds),
        () => _finishMediaOrbit(),
      );
    } else {
      // 视频：自动播放，播放完成后继续
      if (_replayVideoController != null) {
        _replayVideoController!.addListener(_onVideoPlaybackChanged);
        _replayVideoController!.play();
      }
    }
  }

  /// 加载媒体文件用于回放展示
  Future<void> _loadMediaForReplay(SessionMedia media) async {
    // 清理之前的视频控制器
    _replayVideoController?.removeListener(_onVideoPlaybackChanged);
    _replayVideoController?.dispose();
    _replayVideoController = null;
    _currentMediaFile = null;

    final mediaService = MediaGalleryService();

    if (media.type == MediaType.video) {
      // 加载视频文件
      final file = await mediaService.getOriginFile(media.id);
      if (file != null) {
        _currentMediaFile = file;
        _replayVideoController = VideoPlayerController.file(file);
        await _replayVideoController!.initialize();
        await _replayVideoController!.setLooping(false);
        if (mounted) setState(() {});
      }
    } else {
      // 加载图片文件
      final file = await mediaService.getMediaFile(media.id);
      _currentMediaFile = file;
      if (mounted) setState(() {});
    }
  }

  /// 视频播放状态监听
  void _onVideoPlaybackChanged() {
    final controller = _replayVideoController;
    if (controller == null) return;

    // 检查视频是否播放完成
    if (controller.value.isInitialized &&
        controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying) {
      debugPrint('[SessionDetailView] Video playback finished');
      _finishMediaOrbit();
    }
  }

  /// 更新环绕动画
  Future<void> _updateMediaOrbit(SessionMedia media) async {
    if (_mapboxMap == null) return;

    // 使用固定的环绕速度：10秒完成360度，与媒体类型和时长无关
    const orbitDurationSeconds = 10;
    const degreesPerFrame = 360.0 / (orbitDurationSeconds * 20); // 20fps

    _orbitAngle = (_orbitAngle + degreesPerFrame) % 360;

    try {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: media.point,
          zoom: 17.0, // 更近的缩放级别
          pitch: 60.0, // 更倾斜的视角
          bearing: _orbitAngle,
        ),
        MapAnimationOptions(duration: 50),
      );

      // 更新媒体在屏幕上的位置
      await _updateMediaScreenPosition(media);
    } catch (e) {
      debugPrint('[SessionDetailView] Error updating orbit: $e');
    }
  }

  /// 更新媒体在屏幕上的位置
  Future<void> _updateMediaScreenPosition(SessionMedia media) async {
    if (_mapboxMap == null) return;

    try {
      final screenCoord = await _mapboxMap!.pixelForCoordinate(media.point);
      if (mounted) {
        setState(() {
          _mediaScreenPosition = Offset(screenCoord.x, screenCoord.y);
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 结束媒体环绕展示
  void _finishMediaOrbit() {
    debugPrint('[SessionDetailView] Finishing media orbit');

    _mediaOrbitTimer?.cancel();
    _mediaOrbitTimer = null;
    _photoDisplayTimer?.cancel();
    _photoDisplayTimer = null;

    // 停止视频播放并清理
    _replayVideoController?.removeListener(_onVideoPlaybackChanged);
    _replayVideoController?.pause();
    _replayVideoController?.dispose();
    _replayVideoController = null;
    _currentMediaFile = null;
    _mediaScreenPosition = null;

    // 恢复上次的相机方向
    _lastCameraBearing = _orbitAngle;

    // 继续回放
    _replayService?.finishShowingMedia();

    // 重新启动自动隐藏定时器
    _resetHideControlsTimer();

    if (mounted) setState(() {});
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

/// 连接线绘制器 - 从悬浮窗到标记点的连接线
class _ConnectorPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _ConnectorPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 绘制连接线
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    canvas.drawPath(path, paint);

    // 在连接线上画阴影效果
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}
