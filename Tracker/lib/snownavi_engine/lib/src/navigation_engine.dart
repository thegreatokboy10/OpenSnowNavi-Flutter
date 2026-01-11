/// Main navigation engine for ski resort routing
library;

import 'models.dart';
import 'results.dart';
import 'ski_graph.dart';
import 'path_finder.dart';
import 'snapper.dart';
import 'instruction_generator.dart';

/// Main navigation engine class
class NavigationEngine {
  final SkiGraph graph;
  late final PathFinder pathFinder;
  late final CoordinateSnapper snapper;
  late final InstructionGenerator instructionGen;

  NavigationEngine(this.graph, {double maxSnapDistance = 500}) {
    pathFinder = PathFinder(graph);
    snapper = CoordinateSnapper(graph, maxSnapDistanceM: maxSnapDistance);
    instructionGen = InstructionGenerator(graph);
  }

  /// Create engine from SQLite database
  static Future<NavigationEngine> fromSqlite(
    String dbPath, {
    double maxSnapDistance = 500,
  }) async {
    final graph = await SkiGraph.fromSqlite(dbPath);
    return NavigationEngine(graph, maxSnapDistance: maxSnapDistance);
  }

  /// Create engine from JSON data
  factory NavigationEngine.fromJson(
    Map<String, dynamic> json, {
    double maxSnapDistance = 500,
  }) {
    final graph = SkiGraph.fromJson(json);
    return NavigationEngine(graph, maxSnapDistance: maxSnapDistance);
  }

  /// Route between two coordinates
  RouteResult routeByCoords(
    double startLon,
    double startLat,
    double endLon,
    double endLat, {
    RoutePreferences? prefs,
    int alternatives = 1,
  }) {
    prefs ??= const RoutePreferences();

    // Snap coordinates to graph
    final startSnapped = snapper.snapToNode(startLon, startLat);
    final endSnapped = snapper.snapToNode(endLon, endLat);

    if (startSnapped == null) {
      return RouteResult.failure('无法找到起点附近的节点');
    }
    if (endSnapped == null) {
      return RouteResult.failure('无法找到终点附近的节点');
    }

    return routeByNodes(
      startSnapped.nodeId,
      endSnapped.nodeId,
      prefs: prefs,
      alternatives: alternatives,
      startSnapped: startSnapped,
      endSnapped: endSnapped,
    );
  }

  /// Route between two node IDs
  RouteResult routeByNodes(
    int startNode,
    int endNode, {
    RoutePreferences? prefs,
    int alternatives = 1,
    SnappedPoint? startSnapped,
    SnappedPoint? endSnapped,
  }) {
    prefs ??= const RoutePreferences();

    if (!graph.nodes.containsKey(startNode)) {
      return RouteResult.failure('起点节点不存在: $startNode');
    }
    if (!graph.nodes.containsKey(endNode)) {
      return RouteResult.failure('终点节点不存在: $endNode');
    }

    final routes = pathFinder.findKPaths(
      startNode,
      endNode,
      prefs,
      k: alternatives,
    );

    if (routes.isEmpty) {
      return RouteResult.failure('无法找到从 $startNode 到 $endNode 的路径');
    }

    return RouteResult(
      routes: routes,
      startNode: startNode,
      endNode: endNode,
      success: true,
      startSnapped: startSnapped,
      endSnapped: endSnapped,
    );
  }

  /// Route with waypoints
  RouteResult routeWithWaypoints(
    List<(double, double)> waypoints, {
    RoutePreferences? prefs,
  }) {
    if (waypoints.length < 2) {
      return RouteResult.failure('至少需要两个路点');
    }

    prefs ??= const RoutePreferences();

    // Snap all waypoints
    final snappedPoints = <SnappedPoint>[];
    for (final (lon, lat) in waypoints) {
      final snapped = snapper.snapToNode(lon, lat);
      if (snapped == null) {
        return RouteResult.failure('无法捕捉路点 ($lon, $lat)');
      }
      snappedPoints.add(snapped);
    }

    // Route between consecutive waypoints
    final allEdges = <int>[];
    final allNodes = <int>[];
    var totalCost = 0.0;
    var totalLength = 0.0;

    for (var i = 0; i < snappedPoints.length - 1; i++) {
      final path = pathFinder.findPath(
        snappedPoints[i].nodeId,
        snappedPoints[i + 1].nodeId,
        prefs,
      );

      if (path == null) {
        return RouteResult.failure('无法找到从路点 $i 到路点 ${i + 1} 的路径');
      }

      allEdges.addAll(path.edges);
      if (allNodes.isEmpty) {
        allNodes.addAll(path.nodes);
      } else {
        allNodes.addAll(path.nodes.skip(1));
      }
      totalCost += path.totalCost;
      totalLength += path.totalLength;
    }

    final combinedPath = RoutePath(
      edges: allEdges,
      nodes: allNodes,
      totalCost: totalCost,
      totalLength: totalLength,
    );

    return RouteResult(
      routes: [combinedPath],
      waypoints: snappedPoints.map((s) => s.nodeId).toList(),
      startNode: snappedPoints.first.nodeId,
      endNode: snappedPoints.last.nodeId,
      success: true,
      startSnapped: snappedPoints.first,
      endSnapped: snappedPoints.last,
      waypointsSnapped: snappedPoints,
    );
  }

  /// Generate navigation steps for a route
  List<NavigationStep> getNavigationSteps(RoutePath path, {bool merge = true}) {
    var steps = instructionGen.generateSteps(path);
    if (merge) {
      steps = instructionGen.mergeConsecutiveSteps(steps);
    }
    return steps;
  }

  /// Get OSRM-compatible maneuvers
  List<OsrmManeuver> getManeuvers(List<NavigationStep> steps) {
    return instructionGen.generateManeuvers(steps);
  }
}
