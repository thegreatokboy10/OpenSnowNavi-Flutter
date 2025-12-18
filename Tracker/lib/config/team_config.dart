/// 团队功能配置参数
class TeamConfig {
  TeamConfig._();

  /// 团队数据自动刷新间隔（秒）
  /// 用于获取最新的团队成员列表和位置信息
  static const int teamRefreshIntervalSeconds = 90;

  /// 位置上传间隔（秒）
  /// 用于上传当前用户的位置信息到服务器
  static const int locationUploadIntervalSeconds = 120;

  /// 团队默认最大人数
  static const int defaultMaxMembers = 6;

  /// 团队最小人数
  static const int minMaxMembers = 4;

  /// 团队最大人数上限
  static const int maxMaxMembers = 30;
}
