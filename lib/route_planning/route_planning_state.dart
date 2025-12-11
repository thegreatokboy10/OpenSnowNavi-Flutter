import 'package:mapbox_gl/mapbox_gl.dart';

/// 路线规划流程状态
enum RoutePlanningMode {
  /// 初始状态，未进入路线规划
  idle,

  /// 已选择终点，正在选择起点
  selectingOrigin,

  /// 已选择起点，可以添加途径点或查看路线
  planning,
}

/// 路线规划中的一个点
class RoutePoint {
  final String id;
  final String name;
  final LatLng coordinates;
  final RoutePointType type;

  RoutePoint({
    required this.id,
    required this.name,
    required this.coordinates,
    required this.type,
  });

  RoutePoint copyWith({
    String? id,
    String? name,
    LatLng? coordinates,
    RoutePointType? type,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      name: name ?? this.name,
      coordinates: coordinates ?? this.coordinates,
      type: type ?? this.type,
    );
  }
}

/// 路线点类型
enum RoutePointType {
  origin, // 起点
  destination, // 终点
  stopover, // 途径点
}

/// 路线规划数据
class RoutePlanningData {
  RoutePlanningMode mode;
  RoutePoint? origin; // 起点
  RoutePoint? destination; // 终点
  List<RoutePoint> stopovers; // 途径点列表

  RoutePlanningData({
    this.mode = RoutePlanningMode.idle,
    this.origin,
    this.destination,
    List<RoutePoint>? stopovers,
  }) : stopovers = stopovers ?? [];

  /// 重置为初始状态
  void reset() {
    mode = RoutePlanningMode.idle;
    origin = null;
    destination = null;
    stopovers.clear();
  }

  /// 设置终点并进入选择起点模式
  void setDestination(RoutePoint point) {
    destination = point.copyWith(type: RoutePointType.destination);
    mode = RoutePlanningMode.selectingOrigin;
  }

  /// 设置起点并进入规划模式
  void setOrigin(RoutePoint point) {
    origin = point.copyWith(type: RoutePointType.origin);
    mode = RoutePlanningMode.planning;
  }

  /// 添加途径点
  void addStopover(RoutePoint point) {
    stopovers.add(point.copyWith(
      id: 'stopover_${stopovers.length}',
      type: RoutePointType.stopover,
    ));
  }

  /// 替换指定索引的途径点
  void replaceStopover(int index, RoutePoint point) {
    if (index >= 0 && index < stopovers.length) {
      stopovers[index] = point.copyWith(
        id: 'stopover_$index',
        type: RoutePointType.stopover,
      );
    }
  }

  /// 删除途径点
  void removeStopover(int index) {
    if (index >= 0 && index < stopovers.length) {
      stopovers.removeAt(index);
      // 重新编号
      for (int i = 0; i < stopovers.length; i++) {
        stopovers[i] = stopovers[i].copyWith(id: 'stopover_$i');
      }
    }
  }

  /// 重新排序途径点
  void reorderStopovers(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = stopovers.removeAt(oldIndex);
    stopovers.insert(newIndex, item);
    // 重新编号
    for (int i = 0; i < stopovers.length; i++) {
      stopovers[i] = stopovers[i].copyWith(id: 'stopover_$i');
    }
  }

  /// 重新排序所有点（起点、途径点、终点）
  /// index 0 = 起点, 1..n = 途径点, n+1 = 终点
  void reorderAllPoints(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // 构建完整列表
    List<RoutePoint?> allPointsList = [origin, ...stopovers, destination];

    // 移动元素
    final item = allPointsList.removeAt(oldIndex);
    allPointsList.insert(newIndex, item);

    // 重新分配角色
    origin = allPointsList.isNotEmpty && allPointsList[0] != null
        ? allPointsList[0]!.copyWith(type: RoutePointType.origin, id: 'origin')
        : null;

    destination = allPointsList.length > 1 && allPointsList.last != null
        ? allPointsList.last!
            .copyWith(type: RoutePointType.destination, id: 'destination')
        : null;

    // 中间的都是途径点
    stopovers = [];
    for (int i = 1; i < allPointsList.length - 1; i++) {
      if (allPointsList[i] != null) {
        stopovers.add(allPointsList[i]!
            .copyWith(type: RoutePointType.stopover, id: 'stopover_${i - 1}'));
      }
    }
  }

  /// 删除指定索引的点（0=起点, 1..n=途径点, n+1=终点）
  void removePointAt(int index) {
    final totalPoints =
        1 + stopovers.length + 1; // origin + stopovers + destination
    if (index == 0) {
      // 删除起点
      origin = null;
      if (mode == RoutePlanningMode.planning) {
        mode = RoutePlanningMode.selectingOrigin;
      }
    } else if (index == totalPoints - 1 ||
        (origin == null && index == stopovers.length)) {
      // 删除终点
      destination = null;
      mode = RoutePlanningMode.idle;
    } else {
      // 删除途径点
      final stopoverIndex = origin != null ? index - 1 : index;
      if (stopoverIndex >= 0 && stopoverIndex < stopovers.length) {
        stopovers.removeAt(stopoverIndex);
        // 重新编号
        for (int i = 0; i < stopovers.length; i++) {
          stopovers[i] = stopovers[i].copyWith(id: 'stopover_$i');
        }
      }
    }
  }

  /// 获取所有点的坐标列表（起点 -> 途径点 -> 终点）
  List<LatLng> getAllCoordinates() {
    List<LatLng> coords = [];
    if (origin != null) coords.add(origin!.coordinates);
    for (var stopover in stopovers) {
      coords.add(stopover.coordinates);
    }
    if (destination != null) coords.add(destination!.coordinates);
    return coords;
  }

  /// 是否可以生成路线
  bool get canGenerateRoute => origin != null && destination != null;

  /// 获取所有点用于显示 marker
  List<RoutePoint> get allPoints {
    List<RoutePoint> points = [];
    if (origin != null) points.add(origin!);
    points.addAll(stopovers);
    if (destination != null) points.add(destination!);
    return points;
  }
}
