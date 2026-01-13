/// Path finding algorithms for ski navigation
library;

import 'dart:collection';
import 'models.dart';
import 'ski_graph.dart';

/// Priority queue entry for Dijkstra
class _PQEntry implements Comparable<_PQEntry> {
  final double cost;
  final int nodeId;
  final int? prevEdge;
  final int? prevNode;

  _PQEntry(this.cost, this.nodeId, this.prevEdge, this.prevNode);

  @override
  int compareTo(_PQEntry other) => cost.compareTo(other.cost);
}

/// Path finder using Dijkstra's algorithm
class PathFinder {
  final SkiGraph graph;

  PathFinder(this.graph);

  /// Calculate edge cost based on preferences
  double edgeCost(DirectedEdge edge, RoutePreferences prefs) {
    // Check difficulty constraint
    final edgeDiff = Difficulty.fromString(edge.difficulty);
    if (edgeDiff.level > prefs.maxDifficulty.level) {
      return double.infinity;
    }

    // Base cost is estimated duration
    var cost = edge.estimatedDuration;

    // Prefer lifts if requested
    if (prefs.preferLifts && edge.srcFeatType == 'lift') {
      cost *= 0.8;
    }

    return cost;
  }

  /// Find shortest path from start to end
  RoutePath? findPath(int startNode, int endNode, RoutePreferences prefs) {
    if (!graph.nodes.containsKey(startNode) || !graph.nodes.containsKey(endNode)) {
      return null;
    }

    final dist = <int, double>{startNode: 0};
    final prev = <int, (int, int)?>{}; // nodeId -> (edgeId, prevNode)
    final visited = <int>{};

    final pq = SplayTreeSet<_PQEntry>((a, b) {
      final cmp = a.cost.compareTo(b.cost);
      return cmp != 0 ? cmp : a.nodeId.compareTo(b.nodeId);
    });
    pq.add(_PQEntry(0, startNode, null, null));

    while (pq.isNotEmpty) {
      final current = pq.first;
      pq.remove(current);

      if (visited.contains(current.nodeId)) continue;
      visited.add(current.nodeId);

      if (current.nodeId == endNode) break;

      final neighbors = graph.adjacency[current.nodeId] ?? [];
      for (final (edgeId, toNode) in neighbors) {
        if (visited.contains(toNode)) continue;

        final edge = graph.directedEdges[edgeId];
        if (edge == null) continue;

        final cost = edgeCost(edge, prefs);
        if (cost == double.infinity) continue;

        final newDist = current.cost + cost;
        if (newDist < (dist[toNode] ?? double.infinity)) {
          dist[toNode] = newDist;
          prev[toNode] = (edgeId, current.nodeId);
          pq.add(_PQEntry(newDist, toNode, edgeId, current.nodeId));
        }
      }
    }

    // Reconstruct path
    if (!prev.containsKey(endNode) && startNode != endNode) {
      return null;
    }

    final edges = <int>[];
    final nodes = <int>[endNode];
    var current = endNode;

    while (prev[current] != null) {
      final (edgeId, prevNode) = prev[current]!;
      edges.insert(0, edgeId);
      nodes.insert(0, prevNode);
      current = prevNode;
    }

    // Calculate total length
    var totalLength = 0.0;
    for (final edgeId in edges) {
      final edge = graph.directedEdges[edgeId];
      if (edge != null) totalLength += edge.lengthM;
    }

    return RoutePath(
      edges: edges,
      nodes: nodes,
      totalCost: dist[endNode] ?? 0,
      totalLength: totalLength,
    );
  }

  /// Find K shortest paths using Yen's algorithm
  List<RoutePath> findKPaths(int startNode, int endNode, RoutePreferences prefs, {int k = 3}) {
    final paths = <RoutePath>[];

    // Find first shortest path
    final firstPath = findPath(startNode, endNode, prefs);
    if (firstPath == null) return paths;
    paths.add(firstPath);

    if (k == 1) return paths;

    // Yen's algorithm for k-shortest paths
    final candidates = <RoutePath>[];

    for (var i = 1; i < k; i++) {
      final prevPath = paths[i - 1];

      for (var j = 0; j < prevPath.nodes.length - 1; j++) {
        final spurNode = prevPath.nodes[j];
        final rootPath = prevPath.edges.sublist(0, j);

        // Temporarily remove edges that would lead to duplicate paths
        // (simplified version - full implementation would modify graph)
        final spurPath = findPath(spurNode, endNode, prefs);
        if (spurPath != null && spurPath.edges.isNotEmpty) {
          final totalEdges = [...rootPath, ...spurPath.edges];
          final totalNodes = [...prevPath.nodes.sublist(0, j), ...spurPath.nodes];

          var totalLength = 0.0;
          var totalCost = 0.0;
          for (final edgeId in totalEdges) {
            final edge = graph.directedEdges[edgeId];
            if (edge != null) {
              totalLength += edge.lengthM;
              totalCost += edgeCost(edge, prefs);
            }
          }

          final candidate = RoutePath(
            edges: totalEdges,
            nodes: totalNodes,
            totalCost: totalCost,
            totalLength: totalLength,
          );

          // Check if this path is unique
          if (!_pathExists(candidates, candidate) && !_pathExists(paths, candidate)) {
            candidates.add(candidate);
          }
        }
      }

      if (candidates.isEmpty) break;

      // Sort candidates by cost and add best one
      candidates.sort((a, b) => a.totalCost.compareTo(b.totalCost));
      paths.add(candidates.removeAt(0));
    }

    return paths;
  }

  bool _pathExists(List<RoutePath> paths, RoutePath candidate) {
    for (final p in paths) {
      if (p.edges.length == candidate.edges.length) {
        var same = true;
        for (var i = 0; i < p.edges.length; i++) {
          if (p.edges[i] != candidate.edges[i]) {
            same = false;
            break;
          }
        }
        if (same) return true;
      }
    }
    return false;
  }
}

