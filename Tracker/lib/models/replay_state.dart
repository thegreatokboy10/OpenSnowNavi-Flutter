/// 回放播放状态
enum ReplayPlaybackState {
  idle, // 未开始
  playing, // 播放中
  paused, // 已暂停
  finished, // 已结束
}

/// 回放配置
class ReplayConfig {
  /// 回放总时长
  final Duration totalDuration;

  /// 相机缩放级别
  final double cameraZoom;

  /// 相机倾斜角度（3D 效果）
  final double cameraPitch;

  /// 前瞻点数（用于计算方向）
  final int lookAheadPoints;

  /// 方向平滑系数（0.0-1.0，越大越平滑）
  final double bearingSmoothingFactor;

  /// 轨迹线更新间隔（毫秒）
  final int lineUpdateIntervalMs;

  /// 相机更新间隔（毫秒）
  final int cameraUpdateIntervalMs;

  const ReplayConfig({
    this.totalDuration = const Duration(seconds: 30),
    this.cameraZoom = 12.0,
    this.cameraPitch = 20.0,
    this.lookAheadPoints = 3,
    this.bearingSmoothingFactor = 0.4,
    this.lineUpdateIntervalMs = 100,
    this.cameraUpdateIntervalMs = 33,
  });

  /// 快速回放预设（15秒）
  static const fast = ReplayConfig(
    totalDuration: Duration(seconds: 15),
    cameraPitch: 25.0,
    lookAheadPoints: 2,
    bearingSmoothingFactor: 0.6,
  );

  /// 标准回放预设（30秒）
  static const normal = ReplayConfig();

  /// 慢速回放预设（45秒）
  static const scenic = ReplayConfig(
    totalDuration: Duration(seconds: 45),
    cameraPitch: 25.0,
    lookAheadPoints: 5,
    bearingSmoothingFactor: 0.1,
  );

  /// 复制并修改配置
  ReplayConfig copyWith({
    Duration? totalDuration,
    double? cameraZoom,
    double? cameraPitch,
    int? lookAheadPoints,
    double? bearingSmoothingFactor,
    int? lineUpdateIntervalMs,
    int? cameraUpdateIntervalMs,
  }) {
    return ReplayConfig(
      totalDuration: totalDuration ?? this.totalDuration,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      cameraPitch: cameraPitch ?? this.cameraPitch,
      lookAheadPoints: lookAheadPoints ?? this.lookAheadPoints,
      bearingSmoothingFactor:
          bearingSmoothingFactor ?? this.bearingSmoothingFactor,
      lineUpdateIntervalMs: lineUpdateIntervalMs ?? this.lineUpdateIntervalMs,
      cameraUpdateIntervalMs:
          cameraUpdateIntervalMs ?? this.cameraUpdateIntervalMs,
    );
  }
}
