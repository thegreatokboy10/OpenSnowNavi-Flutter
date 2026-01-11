import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snownavi_engine/snownavi_engine.dart';

/// 离线路由服务 - 管理各雪场的 NavigationEngine 实例
class OfflineRouteService {
  static final OfflineRouteService _instance = OfflineRouteService._internal();
  static OfflineRouteService get instance => _instance;

  OfflineRouteService._internal();

  /// 缓存已加载的引擎实例
  final Map<String, NavigationEngine> _engines = {};

  /// 检查雪场是否支持离线路由
  Future<bool> hasOfflineRouting(String resortKey) async {
    // 检查 assets 中是否存在 navigation.sqlite
    final assetPath = 'assets/ski_resorts/$resortKey/navigation.sqlite';
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取雪场的路由引擎（懒加载）
  Future<NavigationEngine?> getEngine(String resortKey) async {
    // 如果已缓存，直接返回
    if (_engines.containsKey(resortKey)) {
      return _engines[resortKey];
    }

    // 检查是否支持离线路由
    if (!await hasOfflineRouting(resortKey)) {
      debugPrint('[OfflineRouteService] No offline routing for $resortKey');
      return null;
    }

    try {
      // 复制 asset 到临时目录（SQLite 需要文件路径）
      final dbPath = await _copyAssetToFile(resortKey);
      if (dbPath == null) return null;

      // 加载引擎
      final engine = await NavigationEngine.fromSqlite(dbPath);
      _engines[resortKey] = engine;
      debugPrint('[OfflineRouteService] Loaded engine for $resortKey');
      return engine;
    } catch (e) {
      debugPrint('[OfflineRouteService] Failed to load engine for $resortKey: $e');
      return null;
    }
  }

  /// 复制 asset 到临时文件
  Future<String?> _copyAssetToFile(String resortKey) async {
    try {
      final assetPath = 'assets/ski_resorts/$resortKey/navigation.sqlite';
      final data = await rootBundle.load(assetPath);

      final tempDir = await getTemporaryDirectory();
      final dbFile = File('${tempDir.path}/${resortKey}_navigation.sqlite');

      // 只在文件不存在时复制
      if (!await dbFile.exists()) {
        await dbFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        debugPrint('[OfflineRouteService] Copied $assetPath to ${dbFile.path}');
      }

      return dbFile.path;
    } catch (e) {
      debugPrint('[OfflineRouteService] Failed to copy asset: $e');
      return null;
    }
  }

  /// 使用离线引擎生成路线
  /// 返回 OSRM 格式的 JSON，与在线 API 兼容
  Future<Map<String, dynamic>?> generateRoute({
    required String resortKey,
    required double startLon,
    required double startLat,
    required double endLon,
    required double endLat,
    List<(double, double)>? waypoints,
  }) async {
    final engine = await getEngine(resortKey);
    if (engine == null) return null;

    try {
      RouteResult result;

      if (waypoints != null && waypoints.isNotEmpty) {
        // 带途经点的路由
        final allPoints = [
          (startLon, startLat),
          ...waypoints,
          (endLon, endLat),
        ];
        result = engine.routeWithWaypoints(allPoints);
      } else {
        // 直接路由
        result = engine.routeByCoords(startLon, startLat, endLon, endLat);
      }

      if (!result.success) {
        debugPrint('[OfflineRouteService] Route failed: ${result.error}');
        return null;
      }

      // 获取导航步骤
      final allSteps = result.routes
          .map((route) => engine.getNavigationSteps(route))
          .toList();

      // 格式化为 OSRM 格式
      final formatter = OsrmFormatter(engine.graph);
      final osrmResponse = formatter.formatRouteResponse(result, allSteps);

      debugPrint('[OfflineRouteService] Generated route with ${result.routes.length} alternatives');
      return osrmResponse;
    } catch (e) {
      debugPrint('[OfflineRouteService] Route generation failed: $e');
      return null;
    }
  }

  /// 清理缓存的引擎
  void dispose() {
    _engines.clear();
  }
}

