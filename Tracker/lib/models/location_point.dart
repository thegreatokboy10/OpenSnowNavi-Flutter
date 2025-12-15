import 'package:latlong2/latlong.dart';

/// 位置点数据模型
class LocationPoint {
  final String id;
  final String sessionId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitude;
  final double horizontalAccuracy;
  final double verticalAccuracy;
  final double speed;      // m/s, -1 if invalid
  final double heading;    // degrees, -1 if invalid
  final bool isMoving;
  final bool isAutoPaused;

  LocationPoint({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.horizontalAccuracy = 0,
    this.verticalAccuracy = 0,
    this.speed = -1,
    this.heading = -1,
    this.isMoving = true,
    this.isAutoPaused = false,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// 从数据库 Map 创建
  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      horizontalAccuracy: (map['horizontal_accuracy'] as num).toDouble(),
      verticalAccuracy: (map['vertical_accuracy'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      heading: (map['heading'] as num).toDouble(),
      isMoving: (map['is_moving'] as int) == 1,
      isAutoPaused: (map['is_auto_paused'] as int) == 1,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'horizontal_accuracy': horizontalAccuracy,
      'vertical_accuracy': verticalAccuracy,
      'speed': speed,
      'heading': heading,
      'is_moving': isMoving ? 1 : 0,
      'is_auto_paused': isAutoPaused ? 1 : 0,
    };
  }
}

