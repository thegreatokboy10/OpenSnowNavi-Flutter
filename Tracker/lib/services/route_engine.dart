import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'search_service.dart';
import 'offline_route_service.dart';

/// 路线信息
class Route {
  final double distance; // 总距离（米）
  final double duration; // 总时长（秒）
  final String summary; // 路线摘要
  final List<RouteStep> steps; // 路线步骤列表
  final Map<String, dynamic>? rawJson; // 原始 OSRM JSON 响应（用于反馈）

  Route({
    required this.distance,
    required this.duration,
    required this.summary,
    required this.steps,
    this.rawJson,
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
      rawJson: json, // 保存原始响应
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

/// 路线引擎 - 支持离线优先、在线 fallback 的混合模式
class RouteEngine {
  final String baseUrl;
  final OfflineRouteService _offlineService = OfflineRouteService.instance;

  RouteEngine({this.baseUrl = 'https://snownavi.ski/route/v1'});

  /// 生成路线
  /// [startCoordinate] 起点坐标
  /// [endCoordinate] 终点坐标
  /// [stopovers] 途径点列表（可选）
  /// [selectedResortKey] 雪场标识
  ///
  /// 优先使用离线路由（如果雪场有 navigation.sqlite），否则使用在线 API
  Future<Route?> generateRoute({
    required LatLng startCoordinate,
    required LatLng endCoordinate,
    List<LatLng>? stopovers,
    String? selectedResortKey,
  }) async {
    // 1. 尝试离线路由
    if (selectedResortKey != null) {
      final offlineRoute = await _tryOfflineRoute(
        resortKey: selectedResortKey,
        startCoordinate: startCoordinate,
        endCoordinate: endCoordinate,
        stopovers: stopovers,
      );
      if (offlineRoute != null) {
        debugPrint('[RouteEngine] Using offline route for $selectedResortKey');
        return offlineRoute;
      }
    }

    // 2. Fallback 到在线路由
    debugPrint('[RouteEngine] Using online route for $selectedResortKey');
    return _tryOnlineRoute(
      startCoordinate: startCoordinate,
      endCoordinate: endCoordinate,
      stopovers: stopovers,
      selectedResortKey: selectedResortKey,
    );
  }

  /// 尝试离线路由
  Future<Route?> _tryOfflineRoute({
    required String resortKey,
    required LatLng startCoordinate,
    required LatLng endCoordinate,
    List<LatLng>? stopovers,
  }) async {
    try {
      // 检查是否支持离线路由
      if (!await _offlineService.hasOfflineRouting(resortKey)) {
        return null;
      }

      // 构建途经点列表
      List<(double, double)>? waypointTuples;
      if (stopovers != null && stopovers.isNotEmpty) {
        waypointTuples =
            stopovers.map((s) => (s.longitude, s.latitude)).toList();
      }

      // 调用离线路由
      final osrmResponse = await _offlineService.generateRoute(
        resortKey: resortKey,
        startLon: startCoordinate.longitude,
        startLat: startCoordinate.latitude,
        endLon: endCoordinate.longitude,
        endLat: endCoordinate.latitude,
        waypoints: waypointTuples,
      );

      if (osrmResponse == null) return null;

      // 解析 OSRM 格式响应
      return Route.fromJson(osrmResponse);
    } catch (e) {
      debugPrint('[RouteEngine] Offline route failed: $e');
      return null;
    }
  }

  /// 在线路由（原有逻辑）
  Future<Route?> _tryOnlineRoute({
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
      debugPrint('[RouteEngine] Online route failed: $e');
      return null;
    }
  }
}
