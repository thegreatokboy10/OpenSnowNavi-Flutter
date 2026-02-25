import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/mapbox_config.dart';
import '../models/elevation_point.dart';

/// 海拔数据服务 - 使用 Mapbox Terrain-RGB Tiles 获取精确海拔信息
class ElevationService {
  static final ElevationService _instance = ElevationService._internal();
  static ElevationService get instance => _instance;
  ElevationService._internal();

  /// Terrain-RGB tile zoom level (14 gives ~10m resolution)
  static const int _tileZoom = 14;

  /// Tile cache to avoid re-fetching same tiles
  final Map<String, Uint8List?> _tileCache = {};

  /// 两点之间的最大插值距离 (米)
  static const double _maxPointDistance = 10.0;

  /// 对坐标列表进行插值，确保相邻两点之间的距离不超过 [_maxPointDistance]
  ///
  /// [coordinates] - 原始坐标列表，格式为 [[lng, lat], ...]
  /// 返回插值后的坐标列表
  List<List<double>> interpolateCoordinates(List<List<double>> coordinates) {
    if (coordinates.length < 2) return coordinates;

    final result = <List<double>>[coordinates.first];

    for (int i = 1; i < coordinates.length; i++) {
      final prev = coordinates[i - 1];
      final curr = coordinates[i];

      final distance = ElevationPoint.haversineDistance(
        prev[1], prev[0], curr[1], curr[0],
      );

      if (distance > _maxPointDistance) {
        // 需要插值
        final segments = (distance / _maxPointDistance).ceil();
        for (int j = 1; j < segments; j++) {
          final t = j / segments;
          final lng = prev[0] + (curr[0] - prev[0]) * t;
          final lat = prev[1] + (curr[1] - prev[1]) * t;
          result.add([lng, lat]);
        }
      }

      result.add(curr);
    }

    return result;
  }

  /// 获取雪道的海拔剖面数据
  ///
  /// [coordinates] - 坐标列表，格式为 [[lng, lat], ...]
  /// 返回 [ElevationProfile] 包含完整的海拔数据和统计信息
  Future<ElevationProfile> getElevationProfile(
    List<List<double>> coordinates,
  ) async {
    if (coordinates.isEmpty) {
      return ElevationProfile.fromPoints([]);
    }

    // 插值坐标，确保相邻点间距不超过阈值
    final interpolated = interpolateCoordinates(coordinates);
    debugPrint('[ElevationService] Interpolated ${coordinates.length} -> ${interpolated.length} points');

    // 使用插值后的坐标
    coordinates = interpolated;

    debugPrint('[ElevationService] Fetching elevation for ${coordinates.length} points using Terrain-RGB');

    // 获取所有需要的 tiles
    final tileKeys = <String>{};
    for (final coord in coordinates) {
      final tileKey = _getTileKey(coord[0], coord[1], _tileZoom);
      tileKeys.add(tileKey);
    }

    debugPrint('[ElevationService] Need ${tileKeys.length} unique tiles');

    // 批量获取所有 tiles
    await _fetchTiles(tileKeys.toList());

    // 从 tiles 解码每个点的海拔
    final elevations = <double>[];
    for (final coord in coordinates) {
      final elevation = await _getElevationFromTile(coord[0], coord[1]);
      elevations.add(elevation);
    }

    // 输出海拔值用于调试
    final elevationStr = elevations.map((e) => e.toStringAsFixed(1)).join(', ');
    debugPrint('[ElevationService] Elevations: $elevationStr');

    // 计算每个点的累计距离
    final distances = <double>[0.0];
    for (int i = 1; i < coordinates.length; i++) {
      final prevCoord = coordinates[i - 1];
      final coord = coordinates[i];
      final segmentDistance = ElevationPoint.haversineDistance(
        prevCoord[1],
        prevCoord[0],
        coord[1],
        coord[0],
      );
      distances.add(distances.last + segmentDistance);
    }

    // 构建 ElevationPoint 列表并计算坡度
    final points = <ElevationPoint>[];

    for (int i = 0; i < coordinates.length; i++) {
      final coord = coordinates[i];
      double? slope;

      if (i > 0 && elevations[i] > 0 && elevations[i - 1] > 0) {
        final elevDiff = elevations[i - 1] - elevations[i]; // 下降为正
        final distDiff = distances[i] - distances[i - 1];
        if (distDiff > 0) {
          slope = (elevDiff / distDiff) * 100; // 百分比坡度
        }
      }

      points.add(ElevationPoint(
        longitude: coord[0],
        latitude: coord[1],
        elevation: elevations[i],
        cumulativeDistance: distances[i],
        slope: slope,
      ));
    }

    final profile = ElevationProfile.fromPoints(points);
    debugPrint('[ElevationService] Profile: distance=${profile.totalDistance.toStringAsFixed(0)}m, '
        'verticalDrop=${profile.verticalDrop.toStringAsFixed(0)}m, '
        'avgSlope=${profile.averageSlope.toStringAsFixed(1)}%, '
        'maxSlope=${profile.maxSlope.toStringAsFixed(1)}%');
    return profile;
  }

  /// 批量获取 tiles
  Future<void> _fetchTiles(List<String> tileKeys) async {
    final futures = <Future<void>>[];

    for (final key in tileKeys) {
      if (!_tileCache.containsKey(key)) {
        futures.add(_fetchTile(key));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// 获取单个 tile
  Future<void> _fetchTile(String tileKey) async {
    final parts = tileKey.split('/');
    final z = parts[0];
    final x = parts[1];
    final y = parts[2];

    final url = Uri.parse(
      'https://api.mapbox.com/v4/mapbox.terrain-rgb/$z/$x/$y@2x.pngraw'
      '?access_token=${MapboxConfig.accessToken}',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _tileCache[tileKey] = response.bodyBytes;
        debugPrint('[ElevationService] Fetched tile $tileKey (${response.bodyBytes.length} bytes)');
      } else {
        debugPrint('[ElevationService] Failed to fetch tile $tileKey: ${response.statusCode}');
        _tileCache[tileKey] = null;
      }
    } catch (e) {
      debugPrint('[ElevationService] Error fetching tile $tileKey: $e');
      _tileCache[tileKey] = null;
    }
  }

  /// 从 tile 获取指定坐标的海拔
  Future<double> _getElevationFromTile(double lng, double lat) async {
    final tileKey = _getTileKey(lng, lat, _tileZoom);
    final tileData = _tileCache[tileKey];

    if (tileData == null) {
      return 0;
    }

    // 计算 tile 内的像素坐标
    final tileSize = 512; // @2x tile
    final tileX = _lngToTileX(lng, _tileZoom);
    final tileY = _latToTileY(lat, _tileZoom);

    // 获取 tile 内的小数部分作为像素位置
    final pixelX = ((tileX - tileX.floor()) * tileSize).round().clamp(0, tileSize - 1);
    final pixelY = ((tileY - tileY.floor()) * tileSize).round().clamp(0, tileSize - 1);

    // 解码 PNG 并获取 RGB 值
    try {
      final codec = await ui.instantiateImageCodec(tileData);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return 0;
      }

      final offset = (pixelY * image.width + pixelX) * 4;
      if (offset + 2 >= byteData.lengthInBytes) {
        return 0;
      }

      final r = byteData.getUint8(offset);
      final g = byteData.getUint8(offset + 1);
      final b = byteData.getUint8(offset + 2);

      // Mapbox Terrain-RGB elevation formula:
      // elevation = -10000 + ((R * 256 * 256 + G * 256 + B) * 0.1)
      final elevation = -10000 + ((r * 256 * 256 + g * 256 + b) * 0.1);

      return elevation;
    } catch (e) {
      debugPrint('[ElevationService] Error decoding tile: $e');
      return 0;
    }
  }

  /// 获取 tile key (z/x/y)
  String _getTileKey(double lng, double lat, int zoom) {
    final x = _lngToTileX(lng, zoom).floor();
    final y = _latToTileY(lat, zoom).floor();
    return '$zoom/$x/$y';
  }

  /// 经度转 tile X
  double _lngToTileX(double lng, int zoom) {
    return (lng + 180) / 360 * math.pow(2, zoom);
  }

  /// 纬度转 tile Y
  double _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180;
    return (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * math.pow(2, zoom);
  }

  /// 清除 tile 缓存
  void clearCache() {
    _tileCache.clear();
  }
}
