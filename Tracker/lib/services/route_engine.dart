import 'dart:convert';
import 'package:http/http.dart' as http;
import 'search_service.dart';

/// 路线信息
class Route {
  final double distance; // 总距离（米）
  final double duration; // 总时长（秒）
  final String summary; // 路线摘要
  final List<RouteStep> steps; // 路线步骤列表

  Route({
    required this.distance,
    required this.duration,
    required this.summary,
    required this.steps,
  });

  /// 从 JSON 解析路线
  factory Route.fromJson(Map<String, dynamic> json) {
    final routeData = json['routes']?.first;
    if (routeData == null) {
      throw Exception('No routes found in response');
    }

    final legs = routeData['legs'] as List;
    final steps = legs
        .expand((leg) =>
            (leg['steps'] as List).map((step) => RouteStep.fromJson(step)))
        .toList();

    return Route(
      distance: (routeData['distance'] as num).toDouble(),
      duration: (routeData['duration'] as num).toDouble(),
      summary: routeData['summary'] ?? '',
      steps: steps,
    );
  }
}

/// 路线步骤
class RouteStep {
  final String name; // 步骤名称
  final String geometry; // 编码的折线几何
  final double distance; // 距离（米）
  final double duration; // 时长（秒）
  final String mode; // 交通方式
  final Maneuver maneuver; // 机动信息

  RouteStep({
    required this.name,
    required this.geometry,
    required this.distance,
    required this.duration,
    required this.mode,
    required this.maneuver,
  });

  /// 从 JSON 解析步骤
  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      name: json['name'] ?? '',
      geometry: json['geometry'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
      mode: json['mode'] ?? '',
      maneuver: Maneuver.fromJson(json['maneuver']),
    );
  }
}

/// 机动信息
class Maneuver {
  final String type; // 类型（如 depart, turn）
  final String? modifier; // 修饰符（如 left, right）
  final List<double> location; // 坐标

  Maneuver({
    required this.type,
    this.modifier,
    required this.location,
  });

  /// 从 JSON 解析机动信息
  factory Maneuver.fromJson(Map<String, dynamic> json) {
    return Maneuver(
      type: json['type'],
      modifier: json['modifier'],
      location: (json['location'] as List<dynamic>)
          .cast<num>()
          .map((e) => e.toDouble())
          .toList(),
    );
  }
}

/// 路线引擎 - 调用 SnowNavi 路线规划 API
class RouteEngine {
  final String baseUrl;

  RouteEngine({this.baseUrl = 'https://snownavi.ski/route/v1'});

  /// 生成路线
  /// [startCoordinate] 起点坐标
  /// [endCoordinate] 终点坐标
  /// [stopovers] 途径点列表（可选）
  /// [selectedResortKey] 雪场标识
  Future<Route?> generateRoute({
    required LatLng startCoordinate,
    required LatLng endCoordinate,
    List<LatLng>? stopovers,
    String? selectedResortKey,
  }) async {
    // 构建坐标字符串
    String coordinates = [
      '${startCoordinate.longitude},${startCoordinate.latitude}',
      if (stopovers != null && stopovers.isNotEmpty)
        ...stopovers.map((stop) => '${stop.longitude},${stop.latitude}'),
      '${endCoordinate.longitude},${endCoordinate.latitude}',
    ].join(';');

    // 构造 API URL
    String url =
        '$baseUrl/$coordinates?alternatives=false&overview=false&steps=true';

    if (selectedResortKey != null && selectedResortKey != '3valley') {
      url =
          'https://snownavi.ski/route/$selectedResortKey/v1/$coordinates?alternatives=false&overview=false&steps=true';
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final route = Route.fromJson(jsonResponse);
        return route;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
