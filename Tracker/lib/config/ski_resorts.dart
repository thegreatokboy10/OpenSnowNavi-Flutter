/// 雪场列表配置 - 与网页版 GlobalConstants 保持一致
class SkiResorts {
  static final Map<String, Map<String, dynamic>> list = {
    'palarinsal': {
      'name': {
        'en': 'Pal Arinsal',
        'cn': 'Pal Arinsal',
      },
      'coordinate': {
        'lat': 42.563015,
        'lng': 1.454209,
      },
      'country': 'Andorra',
      'zoom': 13.0,
    },
    '3valley': {
      'name': {
        'en': 'The Three Valleys',
        'cn': '三峡谷',
      },
      'coordinate': {
        'lat': 45.318460699999996,
        'lng': 6.578992100000002,
      },
      'country': 'France',
      'zoom': 12.0,
    },
    'morzine': {
      'name': {
        'en': 'Morzine - Portes du Soleil',
        'cn': 'Morzine - 太阳门',
      },
      'coordinate': {
        'lat': 46.18151,
        'lng': 6.704120,
      },
      'country': 'France',
      'zoom': 12.0,
    },
    'beidahu': {
      'name': {
        'en': 'Beidahu',
        'cn': '北大湖',
      },
      'coordinate': {
        'lat': 43.4141444,
        'lng': 126.6177757,
      },
      'country': 'China',
      'zoom': 13.0,
    },
  };

  /// 获取国家 emoji 旗帜
  static String getFlagEmoji(String country) {
    switch (country.toLowerCase()) {
      case 'andorra':
        return '🇦🇩';
      case 'france':
        return '🇫🇷';
      case 'china':
        return '🇨🇳';
      case 'switzerland':
        return '🇨🇭';
      case 'austria':
        return '🇦🇹';
      case 'italy':
        return '🇮🇹';
      default:
        return '🏔️';
    }
  }

  // ============ 颜色设置 - 与网页版 GlobalConstants 完全一致 ============

  /// 雪道难度颜色 (从 GlobalConstants 复制)
  /// connection_piste_color = Color.fromARGB(255, 52, 124, 40)
  /// novice_piste_color = Color.fromARGB(255, 52, 124, 40)
  /// easy_piste_color = Color.fromARGB(255, 63, 162, 246)
  /// intermediate_piste_color = Color.fromARGB(255, 199, 37, 62)
  /// advanced_piste_color = Color.fromARGB(200, 27, 27, 27)
  /// expert_piste_color = Color.fromARGB(255, 255, 136, 91)
  static const Map<String, int> difficultyColors = {
    'connection': 0xFF347C28, // Color.fromARGB(255, 52, 124, 40)
    'novice': 0xFF347C28, // Color.fromARGB(255, 52, 124, 40)
    'easy': 0xFF3FA2F6, // Color.fromARGB(255, 63, 162, 246)
    'intermediate': 0xFFC7253E, // Color.fromARGB(255, 199, 37, 62)
    'advanced': 0xC81B1B1B, // Color.fromARGB(200, 27, 27, 27)
    'expert': 0xFFFF885B, // Color.fromARGB(255, 255, 136, 91)
    'freeride': 0xFFFF885B, // 与 expert 相同
  };

  /// 缆车颜色 - 改为深紫色，与雪道区分
  static const int liftColor = 0xFF6B3FA0; // 深紫色

  /// 缆车描边颜色 - lift_stroke_color = Color.fromRGBO(255, 255, 255, 1)
  static const int liftStrokeColor = 0xFFFFFFFF;

  // ============ 线宽设置 ============

  /// 雪道线宽 - pisteLineWidth = 2.5
  static const double pisteLineWidth = 2.5;

  /// 缆车线宽 - 加粗
  static const double liftLineWidth = 6.0;

  // ============ 透明度设置 ============

  /// 默认透明度 - strokeOpacity = 0.5 (用于雪道)
  static const double strokeOpacity = 0.8;

  /// 缆车透明度 - liftStrokeOpacity = 0.8
  static const double liftStrokeOpacity = 0.8;

  /// 淡化透明度（显示路线时）
  static const double lowlightOpacity = 0.3;

  // ============ 缩放级别 ============

  /// 雪道最小缩放级别 - minZoomPiste = 14.0
  static const double minZoomPiste = 14.0;

  /// 缆车最小缩放级别 - minZoomLift = 12.0
  static const double minZoomLift = 12.0;

  /// 支持的雪道类型（只显示 downhill 和 connection）
  static const List<String> supportedPisteUses = ['downhill', 'connection'];

  // ============ 路线设置 ============

  /// 路线颜色
  static const int routeColor = 0xFF1A5AD0;

  /// 路线线宽
  static const double routeLineWidth = 8.0;

  // ============ Marker 颜色 ============

  /// POI 未选中时的颜色（红色）
  static const int poiMarkerColor = 0xFFE53935;

  /// 起点颜色（绿色）
  static const int originMarkerColor = 0xFF4CAF50;

  /// 终点颜色（蓝色）
  static const int destinationMarkerColor = 0xFF2196F3;

  /// 途径点颜色（橙色）
  static const int stopoverMarkerColor = 0xFFFF9800;

  /// 高亮路段颜色（路线详情点击时）
  static const int highlightRouteColor = 0xFFFFD700;
}
