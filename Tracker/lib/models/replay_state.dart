import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 回放播放状态
enum ReplayPlaybackState {
  idle, // 未开始
  playing, // 播放中
  paused, // 已暂停
  finished, // 已结束
  showingMedia, // 正在展示媒体
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

  /// 是否在回放时自动展示媒体
  final bool showMediaDuringReplay;

  /// 照片展示时长（秒）
  final int photoDisplayDuration;

  const ReplayConfig({
    this.totalDuration = const Duration(seconds: 30),
    this.cameraZoom = 12.0,
    this.cameraPitch = 20.0,
    this.lookAheadPoints = 3,
    this.bearingSmoothingFactor = 0.4,
    this.lineUpdateIntervalMs = 100,
    this.cameraUpdateIntervalMs = 33,
    this.showMediaDuringReplay = false,
    this.photoDisplayDuration = 3,
  });

  static const _prefsKey = 'replay_config';

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
    bool? showMediaDuringReplay,
    int? photoDisplayDuration,
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
      showMediaDuringReplay:
          showMediaDuringReplay ?? this.showMediaDuringReplay,
      photoDisplayDuration: photoDisplayDuration ?? this.photoDisplayDuration,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'totalDurationSeconds': totalDuration.inSeconds,
      'cameraZoom': cameraZoom,
      'cameraPitch': cameraPitch,
      'lookAheadPoints': lookAheadPoints,
      'bearingSmoothingFactor': bearingSmoothingFactor,
      'lineUpdateIntervalMs': lineUpdateIntervalMs,
      'cameraUpdateIntervalMs': cameraUpdateIntervalMs,
      'showMediaDuringReplay': showMediaDuringReplay,
      'photoDisplayDuration': photoDisplayDuration,
    };
  }

  /// 从 JSON Map 创建
  factory ReplayConfig.fromJson(Map<String, dynamic> json) {
    return ReplayConfig(
      totalDuration: Duration(seconds: json['totalDurationSeconds'] ?? 30),
      cameraZoom: (json['cameraZoom'] ?? 12.0).toDouble(),
      cameraPitch: (json['cameraPitch'] ?? 20.0).toDouble(),
      lookAheadPoints: json['lookAheadPoints'] ?? 3,
      bearingSmoothingFactor:
          (json['bearingSmoothingFactor'] ?? 0.4).toDouble(),
      lineUpdateIntervalMs: json['lineUpdateIntervalMs'] ?? 100,
      cameraUpdateIntervalMs: json['cameraUpdateIntervalMs'] ?? 33,
      showMediaDuringReplay: json['showMediaDuringReplay'] ?? false,
      photoDisplayDuration: json['photoDisplayDuration'] ?? 3,
    );
  }

  /// 保存到 SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  /// 从 SharedPreferences 加载
  static Future<ReplayConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        return ReplayConfig.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      // 加载失败时使用默认配置
    }
    return const ReplayConfig();
  }
}
