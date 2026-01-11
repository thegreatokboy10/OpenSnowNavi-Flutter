/// Core data models for SnowNavi navigation engine
library;

/// Difficulty levels for ski runs
enum Difficulty {
  novice(0, '初级'),
  easy(1, '简单'),
  intermediate(2, '中级'),
  advanced(3, '高级'),
  expert(4, '专家');

  final int level;
  final String chineseName;
  const Difficulty(this.level, this.chineseName);

  static Difficulty fromString(String? value) {
    if (value == null || value.isEmpty) return Difficulty.novice;
    return Difficulty.values.firstWhere(
      (d) => d.name == value.toLowerCase(),
      orElse: () => Difficulty.novice,
    );
  }
}

/// A node in the ski graph (junction point)
class SkiNode {
  final int nodeId;
  final double lon;
  final double lat;
  final double? ele;
  final String? name;
  final String? kind;

  const SkiNode({
    required this.nodeId,
    required this.lon,
    required this.lat,
    this.ele,
    this.name,
    this.kind,
  });

  @override
  String toString() => 'SkiNode($nodeId: [$lon, $lat])';
}

/// A base edge (undirected) in the ski graph
class SkiEdge {
  final int edgeId;
  final int fromNode;
  final int toNode;
  final String? name;
  final String srcFeatType; // 'run' or 'lift'
  final String? difficulty;
  final double lengthM;
  final double? duration;
  final String? liftType;
  final bool isOneway;
  final String? geom; // WKT LINESTRING

  const SkiEdge({
    required this.edgeId,
    required this.fromNode,
    required this.toNode,
    this.name,
    required this.srcFeatType,
    this.difficulty,
    required this.lengthM,
    this.duration,
    this.liftType,
    this.isOneway = false,
    this.geom,
  });
}

/// A directed edge in the ski graph
class DirectedEdge {
  final int directedId;
  final int baseEdgeId;
  final int fromNode;
  final int toNode;
  final bool isReversed;
  final String? name;
  final String srcFeatType;
  final String? difficulty;
  final double lengthM;
  final double duration;
  final String? liftType;

  const DirectedEdge({
    required this.directedId,
    required this.baseEdgeId,
    required this.fromNode,
    required this.toNode,
    required this.isReversed,
    this.name,
    required this.srcFeatType,
    this.difficulty,
    required this.lengthM,
    required this.duration,
    this.liftType,
  });

  /// Calculate travel time based on edge type and difficulty
  double get estimatedDuration {
    if (srcFeatType == 'lift') {
      return duration > 0 ? duration : lengthM / 5.0;
    }
    final diffLevel = Difficulty.fromString(difficulty).level;
    final speed = 18 - diffLevel * 2; // m/s
    return lengthM / speed;
  }
}

/// Result of snapping a coordinate to the graph
class SnappedPoint {
  final double originalLon;
  final double originalLat;
  final double snappedLon;
  final double snappedLat;
  final int nodeId;
  final int? edgeId;
  final double distanceM;
  final bool isOnNode;

  const SnappedPoint({
    required this.originalLon,
    required this.originalLat,
    required this.snappedLon,
    required this.snappedLat,
    required this.nodeId,
    this.edgeId,
    required this.distanceM,
    this.isOnNode = true,
  });
}

/// A computed route path
class RoutePath {
  final List<int> edges;
  final List<int> nodes;
  final double totalCost;
  final double totalLength;
  final List<Map<String, dynamic>> segments;

  const RoutePath({
    required this.edges,
    required this.nodes,
    required this.totalCost,
    required this.totalLength,
    this.segments = const [],
  });
}

/// Route planning preferences
class RoutePreferences {
  final Difficulty maxDifficulty;
  final bool preferLifts;

  const RoutePreferences({
    this.maxDifficulty = Difficulty.expert,
    this.preferLifts = false,
  });
}
