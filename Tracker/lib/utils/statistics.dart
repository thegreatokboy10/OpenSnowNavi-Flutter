import 'package:latlong2/latlong.dart';
import '../models/session.dart';
import '../models/location_point.dart';

/// 统计数据结构
class SessionStatistics {
  final Duration totalDuration;
  final Duration skiingDuration;
  final double totalDistance;      // 米
  final double skiingDistance;     // 米
  final double maxSpeed;           // m/s
  final double averageSkiingSpeed; // m/s
  final double totalElevationGain; // 米
  final double totalElevationLoss; // 米
  final int pointCount;

  SessionStatistics({
    required this.totalDuration,
    required this.skiingDuration,
    required this.totalDistance,
    required this.skiingDistance,
    required this.maxSpeed,
    required this.averageSkiingSpeed,
    required this.totalElevationGain,
    required this.totalElevationLoss,
    required this.pointCount,
  });

  // 格式化方法
  String get formattedTotalDuration => _formatDuration(totalDuration);
  String get formattedSkiingDuration => _formatDuration(skiingDuration);

  String get formattedTotalDistance {
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(2)} km';
    }
    return '${totalDistance.toStringAsFixed(0)} m';
  }

  String get formattedSkiingDistance {
    if (skiingDistance >= 1000) {
      return '${(skiingDistance / 1000).toStringAsFixed(2)} km';
    }
    return '${skiingDistance.toStringAsFixed(0)} m';
  }

  String get formattedMaxSpeed => '${(maxSpeed * 3.6).toStringAsFixed(1)} km/h';
  String get formattedAverageSpeed =>
      '${(averageSkiingSpeed * 3.6).toStringAsFixed(1)} km/h';
  String get formattedElevationGain =>
      '+${totalElevationGain.toStringAsFixed(0)} m';
  String get formattedElevationLoss =>
      '-${totalElevationLoss.toStringAsFixed(0)} m';

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 从 Session 创建统计
  factory SessionStatistics.fromSession(Session session) {
    return SessionStatistics(
      totalDuration: Duration(seconds: session.totalDuration.toInt()),
      skiingDuration: Duration(seconds: session.skiingDuration.toInt()),
      totalDistance: session.totalDistance,
      skiingDistance: session.skiingDistance,
      maxSpeed: session.maxSpeed,
      averageSkiingSpeed: session.averageSkiingSpeed,
      totalElevationGain: session.totalElevationGain,
      totalElevationLoss: session.totalElevationLoss,
      pointCount: 0,
    );
  }

  /// 从位置点重新计算
  factory SessionStatistics.fromPoints(List<LocationPoint> points) {
    if (points.isEmpty) {
      return SessionStatistics(
        totalDuration: Duration.zero,
        skiingDuration: Duration.zero,
        totalDistance: 0,
        skiingDistance: 0,
        maxSpeed: 0,
        averageSkiingSpeed: 0,
        totalElevationGain: 0,
        totalElevationLoss: 0,
        pointCount: 0,
      );
    }

    const distance = Distance();
    double totalDist = 0;
    double skiingDist = 0;
    double maxSpd = 0;
    double elevGain = 0;
    double elevLoss = 0;
    Duration skiingDur = Duration.zero;

    LocationPoint? lastPoint;
    double? lastAlt;

    for (final point in points) {
      if (lastPoint != null) {
        final dist = distance(lastPoint.latLng, point.latLng);
        totalDist += dist;

        if (point.isMoving) {
          skiingDist += dist;
          skiingDur += point.timestamp.difference(lastPoint.timestamp);
        }
      }

      if (point.speed > maxSpd) maxSpd = point.speed;

      if (lastAlt != null && point.verticalAccuracy >= 0) {
        final altDiff = point.altitude - lastAlt;
        if (altDiff > 0) {
          elevGain += altDiff;
        } else {
          elevLoss += altDiff.abs();
        }
      }

      if (point.verticalAccuracy >= 0) lastAlt = point.altitude;
      lastPoint = point;
    }

    final totalDur = points.last.timestamp.difference(points.first.timestamp);
    final avgSpeed =
        skiingDur.inSeconds > 0 ? skiingDist / skiingDur.inSeconds : 0.0;

    return SessionStatistics(
      totalDuration: totalDur,
      skiingDuration: skiingDur,
      totalDistance: totalDist,
      skiingDistance: skiingDist,
      maxSpeed: maxSpd,
      averageSkiingSpeed: avgSpeed,
      totalElevationGain: elevGain,
      totalElevationLoss: elevLoss,
      pointCount: points.length,
    );
  }
}

