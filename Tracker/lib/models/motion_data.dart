/// 运动数据模型
class MotionData {
  final String id;
  final String sessionId;
  final DateTime timestamp;
  
  // Accelerometer (m/s²)
  final double accelX;
  final double accelY;
  final double accelZ;
  
  // Gyroscope (rad/s)
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  MotionData({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    this.accelX = 0,
    this.accelY = 0,
    this.accelZ = 0,
    this.gyroX = 0,
    this.gyroY = 0,
    this.gyroZ = 0,
  });

  /// 从数据库 Map 创建
  factory MotionData.fromMap(Map<String, dynamic> map) {
    return MotionData(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      accelX: (map['accel_x'] as num).toDouble(),
      accelY: (map['accel_y'] as num).toDouble(),
      accelZ: (map['accel_z'] as num).toDouble(),
      gyroX: (map['gyro_x'] as num).toDouble(),
      gyroY: (map['gyro_y'] as num).toDouble(),
      gyroZ: (map['gyro_z'] as num).toDouble(),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'accel_x': accelX,
      'accel_y': accelY,
      'accel_z': accelZ,
      'gyro_x': gyroX,
      'gyro_y': gyroY,
      'gyro_z': gyroZ,
    };
  }
}

