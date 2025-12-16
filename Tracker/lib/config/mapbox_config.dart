/// Mapbox 配置
///
/// Token 通过 --dart-define 传递，确保安全性
/// 运行时使用: flutter run --dart-define=MAPBOX_ACCESS_TOKEN=your_token
class MapboxConfig {
  /// 从环境变量获取 Mapbox Access Token
  /// 如果没有设置，使用默认 token（仅用于开发）
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue:
        'pk.eyJ1Ijoib2tib3kyMDA4IiwiYSI6ImNsdGE1dzd6OTAxbHQyanA0aWM1MjU5c24ifQ.vbbY3gzL8nnUFctmDv9UBQ',
  );

  /// 自定义 Mapbox 样式 URL
  static const String styleUrl =
      'mapbox://styles/okboy2008/clx1zai3s01ck01rb5zsv600u';

  /// 默认样式（户外地图）
  static const String defaultStyleUrl = 'mapbox://styles/mapbox/outdoors-v12';
}
