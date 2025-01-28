// global_constants.dart
// TODO: check what's the best way to store multi-language
import 'package:flutter/material.dart';

class GlobalConstants {
  // 定义一个static和final的Map来存储多语言滑雪胜地的key-value对
  static final Map<String, Map<String, dynamic>> skiResortList = {
    '3valley': { // assets文件夹名称
      'name': { // 雪场名
        'en': 'The Three Valleys',
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
    'morzine': { // assets文件夹名称
      'name': { // 雪场名
        'en': 'Morzine - Portes du Soleil',
        'fr': 'Morzine - Portes du Soleil',
        'cn': 'Morzine - 太阳门',
      },
      'coordinate': { // 雪场坐标
        'lat': 46.18151,
        'lng': 6.704120,
      },
      'country': 'France',
      'zoom': 12.0,
    },
    'beidahu': { // assets文件夹名称
      'name': { // 雪场名
        'en': 'Beidahu',
        'fr': 'Beidahu',
        'cn': '北大湖',
      },
      'coordinate': { // 雪场坐标
        'lat': 43.4141444,
        'lng': 126.6177757,
      },
      'country': 'China',
      'zoom': 13.0,
    },
    // 可以继续添加其他雪场
  };

  // Colors for the map
  static Color connection_piste_color = Color.fromARGB(255, 52, 124, 40);
  static Color novice_piste_color = Color.fromARGB(255, 52, 124, 40);
  static Color easy_piste_color = Color.fromARGB(255, 63, 162, 246);
  static Color intermediate_piste_color = Color.fromARGB(255, 199, 37, 62);
  static Color advanced_piste_color = Color.fromARGB(200, 27, 27, 27);
  static Color expert_piste_color = Color.fromARGB(255, 255, 136, 91);
  static Color lift_color =  Color.fromRGBO(216, 59, 59, 1); // RGB values from hsl(0, 82%, 42%) and opacity set to 1 (fully opaque)
  static Color lift_stroke_color =  Color.fromRGBO(255, 255, 255, 1); // RGB values from hsl(0, 82%, 42%) and opacity set to 1 (fully opaque)
  static Color piste_default_color = Color.fromARGB(255, 255, 255, 255);
  static double strokeOpacity = 0.5;
  static double liftStrokeOpacity = 0.8;
  // Min zoom level
  static double minZoomPiste = 14.0;
  static double minZoomLift = 12.0;
  // Icon size
  static IconData arrowIcon = Icons.arrow_forward_ios_rounded;
  static IconData liftArrowIcon = Icons.arrow_right;
  static double iconSize = 40;
  static double arrowIconSize = 16;
  // Piste/Lift name
  static double fontSize = 13;
  static double nameOffset = 0.6;
  // Line size
  static double pisteLineWidth = 1.5;
  static double liftLineWidth = 4.0;
  // Floating button
  static double floatingbuttonopacity = 0.9;
  static double floatingActionButtonScale = 0.8;
  // Route
  static String routeLayerId = "route-layer";
  static String routeSourceId = "route-source";
  static double lowlightFeatureOpacity = 0.3;
}