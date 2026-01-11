import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ski_resorts.dart';
import '../config/mapbox_config.dart';

/// 离线地图缓存服务 - 管理雪场地图瓦片的离线缓存
class OfflineMapCacheService {
  static final OfflineMapCacheService _instance =
      OfflineMapCacheService._internal();
  static OfflineMapCacheService get instance => _instance;
  OfflineMapCacheService._internal();

  TileStore? _tileStore;
  OfflineManager? _offlineManager;
  SharedPreferences? _prefs;

  static const String _cachedResortsKey = 'snownavi_offline_cached_resorts';

  /// 下载状态管理 - 在 Service 层跟踪，UI 可以重新进入时恢复状态
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloading = {};

  /// 下载进度回调
  Function(String resortKey, double progress)? onDownloadProgress;
  Function(String resortKey)? onDownloadComplete;
  Function(String resortKey, String error)? onDownloadError;

  /// 获取正在下载的雪场集合
  Set<String> get downloadingResorts => Set.from(_downloading);

  /// 获取下载进度
  double? getDownloadProgress(String resortKey) => _downloadProgress[resortKey];

  /// 检查是否正在下载
  bool isDownloading(String resortKey) => _downloading.contains(resortKey);

  /// 初始化服务
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _offlineManager ??= await OfflineManager.create();
    _tileStore ??= await TileStore.createDefault();
  }

  /// 获取已缓存的雪场列表
  Set<String> getCachedResorts() {
    final list = _prefs?.getStringList(_cachedResortsKey) ?? [];
    return list.toSet();
  }

  /// 检查雪场是否已缓存
  bool isResortCached(String resortKey) {
    return getCachedResorts().contains(resortKey);
  }

  /// 下载雪场地图瓦片
  Future<bool> downloadResortMap(String resortKey) async {
    // 防止重复下载
    if (_downloading.contains(resortKey)) {
      debugPrint('[OfflineMapCache] $resortKey is already downloading');
      return false;
    }

    await initialize();

    final resort = SkiResorts.list[resortKey];
    if (resort == null) {
      debugPrint('[OfflineMapCache] Resort not found: $resortKey');
      return false;
    }

    // 标记开始下载
    _downloading.add(resortKey);
    _downloadProgress[resortKey] = 0.0;

    try {
      final lat = resort['coordinate']['lat'] as double;
      final lng = resort['coordinate']['lng'] as double;
      final zoom = (resort['zoom'] as double?) ?? 13.0;

      // 创建覆盖雪场区域的边界框（约 20km 范围）
      const delta = 0.2; // 约 20km
      final bounds = _createBoundsGeometry(
        minLat: lat - delta,
        maxLat: lat + delta,
        minLng: lng - delta,
        maxLng: lng + delta,
      );

      // 1. 下载样式包
      await _downloadStylePack(resortKey);

      // 2. 下载瓦片区域
      final tileRegionId = 'resort_$resortKey';
      final tileRegionLoadOptions = TileRegionLoadOptions(
        geometry: bounds,
        descriptorsOptions: [
          TilesetDescriptorOptions(
            styleURI: MapboxConfig.styleUrl,
            minZoom: (zoom - 2).toInt().clamp(0, 22),
            maxZoom: (zoom + 4).toInt().clamp(0, 22),
          ),
        ],
        acceptExpired: true,
        networkRestriction: NetworkRestriction.NONE,
      );

      final completer = Completer<bool>();

      _tileStore?.loadTileRegion(tileRegionId, tileRegionLoadOptions,
          (progress) {
        final percentage =
            progress.completedResourceCount / progress.requiredResourceCount;
        _downloadProgress[resortKey] = percentage;
        onDownloadProgress?.call(resortKey, percentage);
        debugPrint(
            '[OfflineMapCache] $resortKey: ${(percentage * 100).toStringAsFixed(1)}%');
      }).then((_) {
        _downloading.remove(resortKey);
        _downloadProgress.remove(resortKey);
        _markResortCached(resortKey);
        onDownloadComplete?.call(resortKey);
        debugPrint('[OfflineMapCache] $resortKey download complete');
        completer.complete(true);
      }).catchError((e) {
        _downloading.remove(resortKey);
        _downloadProgress.remove(resortKey);
        onDownloadError?.call(resortKey, e.toString());
        debugPrint('[OfflineMapCache] $resortKey download failed: $e');
        completer.complete(false);
      });

      return await completer.future;
    } catch (e) {
      _downloading.remove(resortKey);
      _downloadProgress.remove(resortKey);
      debugPrint('[OfflineMapCache] Failed to download $resortKey: $e');
      onDownloadError?.call(resortKey, e.toString());
      return false;
    }
  }

  /// 下载样式包
  Future<void> _downloadStylePack(String resortKey) async {
    final stylePackLoadOptions = StylePackLoadOptions(
      glyphsRasterizationMode:
          GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
      metadata: {'resort': resortKey},
      acceptExpired: false,
    );

    try {
      await _offlineManager?.loadStylePack(
        MapboxConfig.styleUrl,
        stylePackLoadOptions,
        (progress) {
          // 样式包下载进度（通常很快）
        },
      );
    } catch (e) {
      debugPrint('[OfflineMapCache] Style pack download failed: $e');
    }
  }

  /// 创建边界框几何
  Map<String, dynamic> _createBoundsGeometry({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    return {
      'type': 'Polygon',
      'coordinates': [
        [
          [minLng, minLat],
          [maxLng, minLat],
          [maxLng, maxLat],
          [minLng, maxLat],
          [minLng, minLat],
        ]
      ],
    };
  }

  /// 标记雪场已缓存
  void _markResortCached(String resortKey) {
    final cached = getCachedResorts();
    cached.add(resortKey);
    _prefs?.setStringList(_cachedResortsKey, cached.toList());
  }

  /// 删除雪场缓存
  Future<void> removeResortCache(String resortKey) async {
    await initialize();
    final tileRegionId = 'resort_$resortKey';
    await _tileStore?.removeRegion(tileRegionId);
    final cached = getCachedResorts();
    cached.remove(resortKey);
    _prefs?.setStringList(_cachedResortsKey, cached.toList());
    debugPrint('[OfflineMapCache] Removed cache for $resortKey');
  }
}
