/// Coordinate snapping to graph nodes and edges
library;

import 'models.dart';
import 'ski_graph.dart';
import 'utils.dart';

/// Snaps coordinates to the nearest graph node or edge
class CoordinateSnapper {
  final SkiGraph graph;
  final double maxSnapDistanceM;

  CoordinateSnapper(this.graph, {this.maxSnapDistanceM = 500});

  /// Snap a coordinate to the nearest node
  SnappedPoint? snapToNode(double lon, double lat) {
    double minDist = double.infinity;
    SkiNode? nearestNode;

    for (final node in graph.nodes.values) {
      final dist = haversineDistance(lon, lat, node.lon, node.lat);
      if (dist < minDist) {
        minDist = dist;
        nearestNode = node;
      }
    }

    if (nearestNode == null || minDist > maxSnapDistanceM) {
      return null;
    }

    return SnappedPoint(
      originalLon: lon,
      originalLat: lat,
      snappedLon: nearestNode.lon,
      snappedLat: nearestNode.lat,
      nodeId: nearestNode.nodeId,
      distanceM: minDist,
      isOnNode: true,
    );
  }

  /// Snap to nearest point on any edge (including edge interior)
  SnappedPoint? snapToEdge(double lon, double lat) {
    double minDist = double.infinity;
    SkiNode? nearestNode;
    int? nearestEdgeId;
    double? snappedLon;
    double? snappedLat;
    bool isOnNode = true;

    // First check nodes
    for (final node in graph.nodes.values) {
      final dist = haversineDistance(lon, lat, node.lon, node.lat);
      if (dist < minDist) {
        minDist = dist;
        nearestNode = node;
        snappedLon = node.lon;
        snappedLat = node.lat;
        isOnNode = true;
      }
    }

    // Then check edge segments
    for (final edge in graph.edges.values) {
      final coords = parseWktToCoords(edge.geom);
      if (coords.length < 2) continue;

      for (var i = 0; i < coords.length - 1; i++) {
        final p1 = coords[i];
        final p2 = coords[i + 1];

        final (projLon, projLat, dist) = _projectToSegment(
          lon,
          lat,
          p1[0],
          p1[1],
          p2[0],
          p2[1],
        );

        if (dist < minDist) {
          minDist = dist;
          snappedLon = projLon;
          snappedLat = projLat;
          nearestEdgeId = edge.edgeId;
          isOnNode = false;

          // Find nearest node on this edge
          final distToFrom = haversineDistance(
            projLon,
            projLat,
            graph.nodes[edge.fromNode]!.lon,
            graph.nodes[edge.fromNode]!.lat,
          );
          final distToTo = haversineDistance(
            projLon,
            projLat,
            graph.nodes[edge.toNode]!.lon,
            graph.nodes[edge.toNode]!.lat,
          );

          nearestNode = distToFrom < distToTo
              ? graph.nodes[edge.fromNode]
              : graph.nodes[edge.toNode];
        }
      }
    }

    if (nearestNode == null || minDist > maxSnapDistanceM) {
      return null;
    }

    return SnappedPoint(
      originalLon: lon,
      originalLat: lat,
      snappedLon: snappedLon!,
      snappedLat: snappedLat!,
      nodeId: nearestNode.nodeId,
      edgeId: nearestEdgeId,
      distanceM: minDist,
      isOnNode: isOnNode,
    );
  }

  /// Project point to line segment, return (projLon, projLat, distance)
  (double, double, double) _projectToSegment(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      return (x1, y1, haversineDistance(px, py, x1, y1));
    }

    var t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    final projX = x1 + t * dx;
    final projY = y1 + t * dy;
    final dist = haversineDistance(px, py, projX, projY);

    return (projX, projY, dist);
  }

  /// Find K nearest nodes
  List<SnappedPoint> findKNearestNodes(double lon, double lat, int k) {
    final distances = <(double, SkiNode)>[];

    for (final node in graph.nodes.values) {
      final dist = haversineDistance(lon, lat, node.lon, node.lat);
      if (dist <= maxSnapDistanceM) {
        distances.add((dist, node));
      }
    }

    distances.sort((a, b) => a.$1.compareTo(b.$1));

    return distances.take(k).map((entry) {
      final (dist, node) = entry;
      return SnappedPoint(
        originalLon: lon,
        originalLat: lat,
        snappedLon: node.lon,
        snappedLat: node.lat,
        nodeId: node.nodeId,
        distanceM: dist,
        isOnNode: true,
      );
    }).toList();
  }
}
