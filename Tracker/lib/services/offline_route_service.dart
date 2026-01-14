import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snownavi_engine/snownavi_engine.dart';

/// 离线路由服务 - 管理各雪场的 NavigationEngine 实例
class OfflineRouteService {
  static final OfflineRouteService _instance = OfflineRouteService._internal();
  static OfflineRouteService get instance => _instance;

  OfflineRouteService._internal();

  /// 缓存已加载的引擎实例
  final Map<String, NavigationEngine> _engines = {};

  /// SharedPreferences key for imported navigation files
  static const String _importedNavFilesKey = 'snownavi_imported_nav_files';

  SharedPreferences? _prefs;

  /// 初始化
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取用户导入的导航文件目录
  Future<Directory> _getNavFilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final navDir = Directory('${appDir.path}/navigation_files');
    if (!await navDir.exists()) {
      await navDir.create(recursive: true);
    }
    return navDir;
  }

  /// 获取已导入的导航文件列表
  /// 返回 Map<resortKey, displayName>
  Future<Map<String, String>> getImportedNavFiles() async {
    await initialize();
    final list = _prefs?.getStringList(_importedNavFilesKey) ?? [];
    final result = <String, String>{};
    for (final item in list) {
      final parts = item.split('|');
      if (parts.length >= 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }

  /// 导入导航文件
  /// [sourcePath] 用户选择的源文件路径
  /// [resortKey] 关联的雪场标识
  /// [displayName] 显示名称
  Future<bool> importNavFile(
      String sourcePath, String resortKey, String displayName) async {
    try {
      await initialize();
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('[OfflineRouteService] Source file not found: $sourcePath');
        return false;
      }

      // 复制到应用目录
      final navDir = await _getNavFilesDirectory();
      final destFile = File('${navDir.path}/${resortKey}_navigation.sqlite');
      await sourceFile.copy(destFile.path);

      // 验证文件是否有效
      try {
        final engine = await NavigationEngine.fromSqlite(destFile.path);
        _engines[resortKey] = engine;
        debugPrint(
            '[OfflineRouteService] Validated and cached engine for $resortKey');
      } catch (e) {
        // 文件无效，删除
        await destFile.delete();
        debugPrint('[OfflineRouteService] Invalid navigation file: $e');
        return false;
      }

      // 保存到配置
      final imported = await getImportedNavFiles();
      imported[resortKey] = displayName;
      final list = imported.entries.map((e) => '${e.key}|${e.value}').toList();
      await _prefs?.setStringList(_importedNavFilesKey, list);

      debugPrint('[OfflineRouteService] Imported nav file for $resortKey');
      return true;
    } catch (e) {
      debugPrint('[OfflineRouteService] Failed to import nav file: $e');
      return false;
    }
  }

  /// 删除导入的导航文件
  Future<void> removeImportedNavFile(String resortKey) async {
    await initialize();

    // 删除文件
    final navDir = await _getNavFilesDirectory();
    final file = File('${navDir.path}/${resortKey}_navigation.sqlite');
    if (await file.exists()) {
      await file.delete();
    }

    // 从缓存移除
    _engines.remove(resortKey);

    // 从配置移除
    final imported = await getImportedNavFiles();
    imported.remove(resortKey);
    final list = imported.entries.map((e) => '${e.key}|${e.value}').toList();
    await _prefs?.setStringList(_importedNavFilesKey, list);

    debugPrint(
        '[OfflineRouteService] Removed imported nav file for $resortKey');
  }

  /// 检查雪场是否支持离线路由（包括内置和用户导入）
  Future<bool> hasOfflineRouting(String resortKey) async {
    // 先检查用户导入的文件
    final imported = await getImportedNavFiles();
    if (imported.containsKey(resortKey)) {
      return true;
    }

    // 再检查 assets 中是否存在 navigation.sqlite
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

    // 优先检查用户导入的文件
    final imported = await getImportedNavFiles();
    if (imported.containsKey(resortKey)) {
      final dbPath = await _getImportedFilePath(resortKey);
      if (dbPath != null) {
        try {
          final engine = await NavigationEngine.fromSqlite(dbPath);
          _engines[resortKey] = engine;
          debugPrint(
              '[OfflineRouteService] Loaded imported engine for $resortKey');
          return engine;
        } catch (e) {
          debugPrint(
              '[OfflineRouteService] Failed to load imported engine: $e');
        }
      }
    }

    // 再检查内置的 assets
    final assetPath = 'assets/ski_resorts/$resortKey/navigation.sqlite';
    try {
      await rootBundle.load(assetPath);
    } catch (e) {
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
      debugPrint(
          '[OfflineRouteService] Failed to load engine for $resortKey: $e');
      return null;
    }
  }

  /// 获取用户导入文件的路径
  Future<String?> _getImportedFilePath(String resortKey) async {
    final navDir = await _getNavFilesDirectory();
    final file = File('${navDir.path}/${resortKey}_navigation.sqlite');
    if (await file.exists()) {
      return file.path;
    }
    return null;
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

      debugPrint(
          '[OfflineRouteService] Generated route with ${result.routes.length} alternatives');
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
