import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// 处理后的回放点模型（含累计距离和方向）
class ReplayPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double cumulativeDistance; // 从轨迹起点的累计距离（米）
  final double bearing; // 朝向下一点的方向（度，0-360）
  final DateTime originalTimestamp;

  ReplayPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.cumulativeDistance,
    required this.bearing,
    required this.originalTimestamp,
  });

  /// 获取 Mapbox Point
  Point get point => Point(coordinates: Position(longitude, latitude));

  /// 两点间线性插值
  static ReplayPoint lerp(ReplayPoint a, ReplayPoint b, double t) {
    return ReplayPoint(
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: a.longitude + (b.longitude - a.longitude) * t,
      altitude: a.altitude + (b.altitude - a.altitude) * t,
      cumulativeDistance: a.cumulativeDistance +
          (b.cumulativeDistance - a.cumulativeDistance) * t,
      bearing: _lerpBearing(a.bearing, b.bearing, t),
      originalTimestamp: a.originalTimestamp,
    );
  }

  /// 方向角度插值（取最短路径）
  static double _lerpBearing(double a, double b, double t) {
    // 计算最短角度差
    double diff = ((b - a + 540) % 360) - 180;
    return (a + diff * t + 360) % 360;
  }

  /// 计算两点间的 Haversine 距离（米）
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0; // 地球半径（米）
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// 计算从点 A 到点 B 的方位角（度）
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final dLon = _toRadians(lon2 - lon1);
    final x = math.sin(dLon) * math.cos(lat2Rad);
    final y = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    final bearing = math.atan2(x, y) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
