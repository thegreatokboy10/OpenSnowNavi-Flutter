// global_constants.dart
// todo: check what's the best way to store multi-language
class GlobalConstants {
  // 定义一个static和final的Map来存储多语言滑雪胜地的key-value对
  static final Map<String, Map<String, dynamic>> skiResortList = {
    '3valley': { // assets文件夹名称
      'name': { // 雪场名
        'en': 'The 3 Valleys',
        'fr': 'Les Trois Vallées',
        'cn': '三峡谷',
      },
      'coordinate': { // 雪场坐标
        'lat': 45.318460699999996,
        'lng': 6.578992100000002,
      },
      'country': 'France',
      'zoom': 12.0,
    },
    // 可以继续添加其他雪场
  };
}