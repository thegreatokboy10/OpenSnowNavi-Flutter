import 'dart:math' as math;

/// 海拔点数据模型 - 用于雪道海拔剖面图
class ElevationPoint {
  final double longitude;
  final double latitude;
  final double elevation; // 海拔 (米)
  final double cumulativeDistance; // 从起点的累计距离 (米)
  final double? slope; // 到下一点的坡度 (%), 负值表示下坡

  const ElevationPoint({
    required this.longitude,
    required this.latitude,
    required this.elevation,
    required this.cumulativeDistance,
    this.slope,
  });

  /// 坡度的角度表示 (度)
  double? get slopeDegrees {
    if (slope == null) return null;
    return math.atan(slope! / 100) * 180 / math.pi;
  }

  /// 使用 Haversine 公式计算两点间的距离 (米)
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // 地球半径 (米)

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// 计算两点间的坡度百分比
  /// 正值表示上坡，负值表示下坡
  static double calculateSlope(ElevationPoint from, ElevationPoint to) {
    final horizontalDistance = haversineDistance(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (horizontalDistance < 0.1) return 0; // 距离太近，无法计算坡度

    final elevationChange = to.elevation - from.elevation;
    return (elevationChange / horizontalDistance) * 100;
  }

  @override
  String toString() =>
      'ElevationPoint(lon: $longitude, lat: $latitude, ele: ${elevation.toStringAsFixed(0)}m, dist: ${(cumulativeDistance / 1000).toStringAsFixed(2)}km, slope: ${slope?.toStringAsFixed(1)}%)';
}

/// 海拔剖面数据 - 包含完整的海拔点列表和统计信息
class ElevationProfile {
  final List<ElevationPoint> points;
  final double totalDistance; // 总距离 (米)
  final double minElevation; // 最低海拔 (米)
  final double maxElevation; // 最高海拔 (米)
  final double elevationGain; // 总爬升 (米)
  final double elevationLoss; // 总下降 (米)
  final double averageSlope; // 平均坡度 (%)
  final double maxSlope; // 最大坡度 (%)

  const ElevationProfile({
    required this.points,
    required this.totalDistance,
    required this.minElevation,
    required this.maxElevation,
    required this.elevationGain,
    required this.elevationLoss,
    required this.averageSlope,
    required this.maxSlope,
  });

  /// 从海拔点列表创建剖面数据
  factory ElevationProfile.fromPoints(List<ElevationPoint> points) {
    if (points.isEmpty) {
      return const ElevationProfile(
        points: [],
        totalDistance: 0,
        minElevation: 0,
        maxElevation: 0,
        elevationGain: 0,
        elevationLoss: 0,
        averageSlope: 0,
        maxSlope: 0,
      );
    }

    double minEle = points.first.elevation;
    double maxEle = points.first.elevation;
    double gain = 0;
    double loss = 0;
    double maxSlopeAbs = 0;
    double totalSlopeSum = 0;
    int slopeCount = 0;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // 更新最高/最低海拔
      if (point.elevation < minEle) minEle = point.elevation;
      if (point.elevation > maxEle) maxEle = point.elevation;

      // 计算爬升/下降和坡度统计
      if (i > 0) {
        final prevPoint = points[i - 1];
        final elevationDiff = point.elevation - prevPoint.elevation;

        if (elevationDiff > 0) {
          gain += elevationDiff;
        } else {
          loss += elevationDiff.abs();
        }

        if (point.slope != null) {
          totalSlopeSum += point.slope!.abs();
          slopeCount++;
          if (point.slope!.abs() > maxSlopeAbs) {
            maxSlopeAbs = point.slope!.abs();
          }
        }
      }
    }

    final totalDist = points.isNotEmpty ? points.last.cumulativeDistance : 0.0;
    final avgSlope = slopeCount > 0 ? totalSlopeSum / slopeCount : 0.0;

    return ElevationProfile(
      points: points,
      totalDistance: totalDist,
      minElevation: minEle,
      maxElevation: maxEle,
      elevationGain: gain,
      elevationLoss: loss,
      averageSlope: avgSlope,
      maxSlope: maxSlopeAbs,
    );
  }

  /// 平均坡度角度 (度)
  double get averageSlopeDegrees =>
      math.atan(averageSlope / 100) * 180 / math.pi;

  /// 最大坡度角度 (度)
  double get maxSlopeDegrees => math.atan(maxSlope / 100) * 180 / math.pi;

  /// 垂直落差 (起点海拔 - 终点海拔)
  double get verticalDrop {
    if (points.isEmpty) return 0;
    return points.first.elevation - points.last.elevation;
  }

  /// 起点海拔
  double get startElevation => points.isNotEmpty ? points.first.elevation : 0;

  /// 终点海拔
  double get endElevation => points.isNotEmpty ? points.last.elevation : 0;
}
