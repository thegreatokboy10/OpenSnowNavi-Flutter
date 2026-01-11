/// Explore mode routing - find diverse paths with different first edges
library;

import 'models.dart';
import 'results.dart';
import 'ski_graph.dart';
import 'path_finder.dart';
import 'snapper.dart';
import 'utils.dart';

/// Router for explore mode - finds paths starting with different edges
class ExploreRouter {
  final SkiGraph graph;
  final PathFinder pathFinder;
  final CoordinateSnapper snapper;

  ExploreRouter(this.graph, this.pathFinder, this.snapper);

  /// Find diverse routes starting with different first edges
  ExploreResult findExploreRoutes(
    int startNode,
    int endNode, {
    RoutePreferences? prefs,
    int maxRoutes = 5,
    double maxOverlap = 0.7,
  }) {
    prefs ??= const RoutePreferences();

    if (!graph.nodes.containsKey(startNode)) {
      return ExploreResult.failure('起点节点不存在: $startNode');
    }
    if (!graph.nodes.containsKey(endNode)) {
      return ExploreResult.failure('终点节点不存在: $endNode');
    }

    // Get all outgoing edges from start node
    final outEdges = graph.adjacency[startNode] ?? [];
    if (outEdges.isEmpty) {
      return ExploreResult.failure('起点没有可用的出边');
    }

    final routes = <RoutePath>[];
    final firstEdges = <int>[];
    final firstEdgeNames = <String>[];
    final usedFirstEdges = <int>{};

    for (final (edgeId, nextNode) in outEdges) {
      if (usedFirstEdges.contains(edgeId)) continue;

      final edge = graph.directedEdges[edgeId];
      if (edge == null) continue;

      // Check difficulty constraint
      final edgeDiff = Difficulty.fromString(edge.difficulty);
      if (edgeDiff.level > prefs.maxDifficulty.level) continue;

      // Find path from next node to end
      final subPath = pathFinder.findPath(nextNode, endNode, prefs);
      if (subPath == null) continue;

      // Combine first edge with sub-path
      final fullEdges = [edgeId, ...subPath.edges];
      final fullNodes = [startNode, ...subPath.nodes];

      var totalLength = edge.lengthM + subPath.totalLength;
      var totalCost = pathFinder.edgeCost(edge, prefs) + subPath.totalCost;

      final route = RoutePath(
        edges: fullEdges,
        nodes: fullNodes,
        totalCost: totalCost,
        totalLength: totalLength,
      );

      // Check overlap with existing routes
      var tooSimilar = false;
      for (final existing in routes) {
        if (calculateOverlap(route.edges, existing.edges) > maxOverlap) {
          tooSimilar = true;
          break;
        }
      }

      if (!tooSimilar) {
        routes.add(route);
        firstEdges.add(edgeId);
        firstEdgeNames.add(edge.name ?? '未命名');
        usedFirstEdges.add(edgeId);

        if (routes.length >= maxRoutes) break;
      }
    }

    if (routes.isEmpty) {
      return ExploreResult.failure('无法找到任何可行路径');
    }

    // Sort by cost
    final sortedIndices = List.generate(routes.length, (i) => i);
    sortedIndices.sort((a, b) => routes[a].totalCost.compareTo(routes[b].totalCost));

    return ExploreResult(
      routes: sortedIndices.map((i) => routes[i]).toList(),
      firstEdges: sortedIndices.map((i) => firstEdges[i]).toList(),
      firstEdgeNames: sortedIndices.map((i) => firstEdgeNames[i]).toList(),
      startNode: startNode,
      endNode: endNode,
      success: true,
    );
  }

  /// Find explore routes by coordinates
  ExploreResult findExploreRoutesByCoords(
    double startLon, double startLat,
    double endLon, double endLat, {
    RoutePreferences? prefs,
    int maxRoutes = 5,
    double maxOverlap = 0.7,
  }) {
    final startSnapped = snapper.snapToNode(startLon, startLat);
    final endSnapped = snapper.snapToNode(endLon, endLat);

    if (startSnapped == null) {
      return ExploreResult.failure('无法找到起点附近的节点');
    }
    if (endSnapped == null) {
      return ExploreResult.failure('无法找到终点附近的节点');
    }

    final result = findExploreRoutes(
      startSnapped.nodeId,
      endSnapped.nodeId,
      prefs: prefs,
      maxRoutes: maxRoutes,
      maxOverlap: maxOverlap,
    );

    // Add snapped points to result
    return ExploreResult(
      routes: result.routes,
      firstEdges: result.firstEdges,
      firstEdgeNames: result.firstEdgeNames,
      startNode: result.startNode,
      endNode: result.endNode,
      success: result.success,
      error: result.error,
      startSnapped: startSnapped,
      endSnapped: endSnapped,
    );
  }
}

