/// 团队功能配置参数
class TeamConfig {
  TeamConfig._();

  /// 团队数据刷新间隔 - 前台模式（秒）
  /// 当地图页面在前台时使用
  static const int teamRefreshIntervalForegroundSeconds = 15;

  /// 团队数据刷新间隔 - 后台模式（秒）
  /// 当地图页面不在前台时使用
  static const int teamRefreshIntervalBackgroundSeconds = 300; // 5分钟

  /// 位置上传间隔 - 移动时（秒）
  /// 当用户在移动时使用
  static const int locationUploadIntervalMovingSeconds = 15;

  /// 位置上传间隔 - 静止时（秒）
  /// 当用户静止时使用
  static const int locationUploadIntervalStationarySeconds = 300; // 5分钟

  /// 判断是否移动的速度阈值（米/秒）
  /// 低于此速度视为静止
  static const double movementSpeedThreshold = 0.5; // 0.5 m/s ≈ 1.8 km/h

  /// 判断是否移动的距离阈值（米）
  /// 与上次位置相比，移动距离超过此值视为移动
  static const double movementDistanceThreshold = 10.0; // 10米

  /// 团队默认最大人数
  static const int defaultMaxMembers = 6;

  /// 团队最小人数
  static const int minMaxMembers = 4;

  /// 团队最大人数上限
  static const int maxMaxMembers = 30;

  /// 兼容旧代码的别名
  @Deprecated('Use teamRefreshIntervalForegroundSeconds instead')
  static const int teamRefreshIntervalSeconds =
      teamRefreshIntervalForegroundSeconds;

  @Deprecated('Use locationUploadIntervalMovingSeconds instead')
  static const int locationUploadIntervalSeconds =
      locationUploadIntervalMovingSeconds;
}
