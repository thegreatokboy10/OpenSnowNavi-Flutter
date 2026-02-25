/// Mapbox 配置
///
/// Token 通过 --dart-define 传递，确保安全性
/// 运行时使用: flutter run --dart-define=MAPBOX_ACCESS_TOKEN=your_token
class MapboxConfig {
  /// 从环境变量获取 Mapbox Access Token
  /// 如果没有设置，使用默认 token（仅用于开发）
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: 'your-mapbox-access-token',
  );

  /// 自定义 Mapbox 样式 URL
  static const String styleUrl =
      'mapbox://styles/okboy2008/cmm2fxt4p001b01qt1dow2pu9';

  /// 默认样式（户外地图）
  static const String defaultStyleUrl = 'mapbox://styles/mapbox/outdoors-v12';
}
