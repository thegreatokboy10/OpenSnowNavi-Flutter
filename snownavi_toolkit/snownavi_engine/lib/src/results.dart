/// Result classes for navigation operations
library;

import 'models.dart';

/// Result of route planning
class RouteResult {
  final List<RoutePath> routes;
  final List<int> waypoints;
  final int startNode;
  final int endNode;
  final bool success;
  final String? error;
  final SnappedPoint? startSnapped;
  final SnappedPoint? endSnapped;
  final List<SnappedPoint> waypointsSnapped;

  const RouteResult({
    required this.routes,
    this.waypoints = const [],
    required this.startNode,
    required this.endNode,
    required this.success,
    this.error,
    this.startSnapped,
    this.endSnapped,
    this.waypointsSnapped = const [],
  });

  factory RouteResult.failure(String message) => RouteResult(
    routes: [],
    startNode: -1,
    endNode: -1,
    success: false,
    error: message,
  );
}

/// Result of explore mode routing
class ExploreResult {
  final List<RoutePath> routes;
  final List<int> firstEdges;
  final List<String> firstEdgeNames;
  final int startNode;
  final int endNode;
  final bool success;
  final String? error;
  final SnappedPoint? startSnapped;
  final SnappedPoint? endSnapped;

  const ExploreResult({
    required this.routes,
    required this.firstEdges,
    required this.firstEdgeNames,
    required this.startNode,
    required this.endNode,
    required this.success,
    this.error,
    this.startSnapped,
    this.endSnapped,
  });

  factory ExploreResult.failure(String message) => ExploreResult(
    routes: [],
    firstEdges: [],
    firstEdgeNames: [],
    startNode: -1,
    endNode: -1,
    success: false,
    error: message,
  );
}

/// A single navigation step
class NavigationStep {
  final int stepIndex;
  final String instruction;
  final double distanceM;
  final double durationS;
  final double cumulativeDistanceM;
  final double cumulativeTimeS;
  final String featType;
  final String? name;
  final String? difficulty;
  final String? liftType;
  final List<List<double>> geometry;
  final int? edgeId;
  final int? fromNode;
  final int? toNode;

  const NavigationStep({
    required this.stepIndex,
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    this.cumulativeDistanceM = 0,
    this.cumulativeTimeS = 0,
    required this.featType,
    this.name,
    this.difficulty,
    this.liftType,
    required this.geometry,
    this.edgeId,
    this.fromNode,
    this.toNode,
  });

  Map<String, dynamic> toJson() => {
    'step_index': stepIndex,
    'instruction': instruction,
    'distance_m': distanceM,
    'duration_s': durationS,
    'cumulative_distance_m': cumulativeDistanceM,
    'cumulative_time_s': cumulativeTimeS,
    'feat_type': featType,
    'name': name,
    'difficulty': difficulty,
    'lift_type': liftType,
    'geometry': geometry,
    'edge_id': edgeId,
    'from_node': fromNode,
    'to_node': toNode,
  };
}

/// OSRM-compatible maneuver
class OsrmManeuver {
  final int bearingAfter;
  final int bearingBefore;
  final List<double> location;
  final String type;
  final String? modifier;

  const OsrmManeuver({
    required this.bearingAfter,
    required this.bearingBefore,
    required this.location,
    required this.type,
    this.modifier,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'bearing_after': bearingAfter,
      'bearing_before': bearingBefore,
      'location': location,
      'type': type,
    };
    if (modifier != null && modifier != 'straight') {
      json['modifier'] = modifier!;
    }
    return json;
  }
}
