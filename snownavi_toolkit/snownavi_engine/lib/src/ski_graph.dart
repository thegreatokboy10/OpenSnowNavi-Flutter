/// SkiGraph - The core graph structure for ski resort navigation
library;

import 'package:sqflite/sqflite.dart';
import 'models.dart';

/// Main graph structure holding nodes, edges and adjacency lists
class SkiGraph {
  final Map<int, SkiNode> nodes = {};
  final Map<int, SkiEdge> edges = {};
  final Map<int, DirectedEdge> directedEdges = {};

  /// Adjacency list: nodeId -> [(directedEdgeId, toNode), ...]
  final Map<int, List<(int, int)>> adjacency = {};

  /// Reverse adjacency: nodeId -> [(directedEdgeId, fromNode), ...]
  final Map<int, List<(int, int)>> reverseAdj = {};

  int _nextDirectedId = 1;

  SkiGraph();

  /// Load graph from SQLite database
  static Future<SkiGraph> fromSqlite(String dbPath) async {
    final graph = SkiGraph();
    final db = await openDatabase(dbPath, readOnly: true);

    try {
      // Load nodes
      final nodeRows = await db.query('nodes');
      for (final row in nodeRows) {
        final node = SkiNode(
          nodeId: row['node_id'] as int,
          lon: (row['lon'] as num).toDouble(),
          lat: (row['lat'] as num).toDouble(),
          ele: row['ele'] != null ? (row['ele'] as num).toDouble() : null,
          name: row['name'] as String?,
          kind: row['kind'] as String?,
        );
        graph.nodes[node.nodeId] = node;
      }

      // Load edges
      final edgeRows = await db.query('edges');
      for (final row in edgeRows) {
        final edge = SkiEdge(
          edgeId: row['edge_id'] as int,
          fromNode: row['from_node'] as int,
          toNode: row['to_node'] as int,
          name: row['name'] as String?,
          srcFeatType: row['src_feat_type'] as String? ?? 'run',
          difficulty: row['difficulty'] as String?,
          lengthM: (row['length_m'] as num?)?.toDouble() ?? 0,
          duration: row['duration'] != null
              ? (row['duration'] as num).toDouble()
              : null,
          liftType: row['lift_type'] as String?,
          isOneway: (row['is_oneway'] as int?) == 1,
          geom: row['geom'] as String?,
        );
        graph.edges[edge.edgeId] = edge;
        graph._buildDirectedEdges(edge);
      }
    } finally {
      await db.close();
    }

    return graph;
  }

  /// Load graph from JSON data
  factory SkiGraph.fromJson(Map<String, dynamic> json) {
    final graph = SkiGraph();

    // Load nodes
    final nodesList = json['nodes'] as List<dynamic>? ?? [];
    for (final nodeData in nodesList) {
      final node = SkiNode(
        nodeId: nodeData['node_id'] as int,
        lon: (nodeData['lon'] as num).toDouble(),
        lat: (nodeData['lat'] as num).toDouble(),
        ele: nodeData['ele'] != null
            ? (nodeData['ele'] as num).toDouble()
            : null,
        name: nodeData['name'] as String?,
        kind: nodeData['kind'] as String?,
      );
      graph.nodes[node.nodeId] = node;
    }

    // Load edges
    final edgesList = json['edges'] as List<dynamic>? ?? [];
    for (final edgeData in edgesList) {
      final edge = SkiEdge(
        edgeId: edgeData['edge_id'] as int,
        fromNode: edgeData['from_node'] as int,
        toNode: edgeData['to_node'] as int,
        name: edgeData['name'] as String?,
        srcFeatType: edgeData['src_feat_type'] as String? ?? 'run',
        difficulty: edgeData['difficulty'] as String?,
        lengthM: (edgeData['length_m'] as num?)?.toDouble() ?? 0,
        duration: edgeData['duration'] != null
            ? (edgeData['duration'] as num).toDouble()
            : null,
        liftType: edgeData['lift_type'] as String?,
        isOneway: edgeData['is_oneway'] == true || edgeData['is_oneway'] == 1,
        geom: edgeData['geom'] as String?,
      );
      graph.edges[edge.edgeId] = edge;
      graph._buildDirectedEdges(edge);
    }

    return graph;
  }

  void _buildDirectedEdges(SkiEdge edge) {
    // Forward direction
    final fwdId = _nextDirectedId++;
    final fwdEdge = DirectedEdge(
      directedId: fwdId,
      baseEdgeId: edge.edgeId,
      fromNode: edge.fromNode,
      toNode: edge.toNode,
      isReversed: false,
      name: edge.name,
      srcFeatType: edge.srcFeatType,
      difficulty: edge.difficulty,
      lengthM: edge.lengthM,
      duration: edge.duration ?? 0,
      liftType: edge.liftType,
    );
    directedEdges[fwdId] = fwdEdge;
    adjacency.putIfAbsent(edge.fromNode, () => []).add((fwdId, edge.toNode));
    reverseAdj.putIfAbsent(edge.toNode, () => []).add((fwdId, edge.fromNode));

    // Reverse direction (if not one-way)
    if (!edge.isOneway) {
      final revId = _nextDirectedId++;
      final revEdge = DirectedEdge(
        directedId: revId,
        baseEdgeId: edge.edgeId,
        fromNode: edge.toNode,
        toNode: edge.fromNode,
        isReversed: true,
        name: edge.name,
        srcFeatType: edge.srcFeatType,
        difficulty: edge.difficulty,
        lengthM: edge.lengthM,
        duration: edge.duration ?? 0,
        liftType: edge.liftType,
      );
      directedEdges[revId] = revEdge;
      adjacency.putIfAbsent(edge.toNode, () => []).add((revId, edge.fromNode));
      reverseAdj.putIfAbsent(edge.fromNode, () => []).add((revId, edge.toNode));
    }
  }

  SkiEdge? getBaseEdge(int directedId) {
    final de = directedEdges[directedId];
    return de != null ? edges[de.baseEdgeId] : null;
  }
}
