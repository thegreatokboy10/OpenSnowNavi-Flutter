/// Session 状态枚举
enum SessionState {
  recording,
  paused,
  stopped,
}

/// Session 数据模型
class Session {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  SessionState state;
  double totalDistance;      // 总距离 (米)
  double skiingDistance;     // 滑行距离 (米)
  double maxSpeed;           // 最高速度 (m/s)
  double totalElevationGain; // 累计爬升 (米)
  double totalElevationLoss; // 累计下降 (米)
  double pausedDuration;     // 累计暂停时长 (秒)

  Session({
    required this.id,
    required this.startTime,
    this.endTime,
    this.state = SessionState.recording,
    this.totalDistance = 0,
    this.skiingDistance = 0,
    this.maxSpeed = 0,
    this.totalElevationGain = 0,
    this.totalElevationLoss = 0,
    this.pausedDuration = 0,
  });

  /// 总时长(秒)
  double get totalDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMilliseconds / 1000.0;
  }

  /// 滑行时长(秒)
  double get skiingDuration => totalDuration - pausedDuration;

  /// 平均滑行速度 (m/s)
  double get averageSkiingSpeed {
    if (skiingDuration <= 0) return 0;
    return skiingDistance / skiingDuration;
  }

  /// 从数据库 Map 创建
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
          : null,
      state: SessionState.values[map['state'] as int],
      totalDistance: (map['total_distance'] as num).toDouble(),
      skiingDistance: (map['skiing_distance'] as num).toDouble(),
      maxSpeed: (map['max_speed'] as num).toDouble(),
      totalElevationGain: (map['total_elevation_gain'] as num).toDouble(),
      totalElevationLoss: (map['total_elevation_loss'] as num).toDouble(),
      pausedDuration: (map['paused_duration'] as num).toDouble(),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'state': state.index,
      'total_distance': totalDistance,
      'skiing_distance': skiingDistance,
      'max_speed': maxSpeed,
      'total_elevation_gain': totalElevationGain,
      'total_elevation_loss': totalElevationLoss,
      'paused_duration': pausedDuration,
    };
  }
}

