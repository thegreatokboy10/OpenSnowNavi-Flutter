/// Navigation instruction generation
library;

import 'models.dart';
import 'results.dart';
import 'ski_graph.dart';
import 'utils.dart';

/// Generates turn-by-turn navigation instructions
class InstructionGenerator {
  final SkiGraph graph;

  InstructionGenerator(this.graph);

  /// Generate navigation steps from a route path
  List<NavigationStep> generateSteps(RoutePath path) {
    final steps = <NavigationStep>[];
    var cumulativeDistance = 0.0;
    var cumulativeTime = 0.0;

    for (var i = 0; i < path.edges.length; i++) {
      final edgeId = path.edges[i];
      final edge = graph.directedEdges[edgeId];
      if (edge == null) continue;

      final baseEdge = graph.getBaseEdge(edgeId);
      final coords = baseEdge != null
          ? parseWktToCoords(baseEdge.geom)
          : <List<double>>[];

      // Reverse coords if edge is reversed
      final geometry = edge.isReversed ? coords.reversed.toList() : coords;

      final instruction = _generateInstruction(edge, i, path.edges.length);
      final duration = edge.estimatedDuration;

      cumulativeDistance += edge.lengthM;
      cumulativeTime += duration;

      steps.add(
        NavigationStep(
          stepIndex: i,
          instruction: instruction,
          distanceM: edge.lengthM,
          durationS: duration,
          cumulativeDistanceM: cumulativeDistance,
          cumulativeTimeS: cumulativeTime,
          featType: edge.srcFeatType,
          name: edge.name,
          difficulty: edge.difficulty,
          liftType: edge.liftType,
          geometry: geometry,
          edgeId: edgeId,
          fromNode: edge.fromNode,
          toNode: edge.toNode,
        ),
      );
    }

    return steps;
  }

  String _generateInstruction(DirectedEdge edge, int index, int totalEdges) {
    final name = edge.name ?? '未命名';

    if (index == 0) {
      if (edge.srcFeatType == 'lift') {
        return '乘坐 $name 缆车';
      } else {
        final diff = Difficulty.fromString(edge.difficulty);
        return '从 $name (${diff.chineseName}) 开始滑行';
      }
    }

    if (index == totalEdges - 1) {
      return '到达目的地';
    }

    if (edge.srcFeatType == 'lift') {
      return '换乘 $name 缆车';
    } else {
      final diff = Difficulty.fromString(edge.difficulty);
      return '继续沿 $name (${diff.chineseName}) 滑行';
    }
  }

  /// Generate OSRM-compatible maneuvers
  List<OsrmManeuver> generateManeuvers(List<NavigationStep> steps) {
    final maneuvers = <OsrmManeuver>[];

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.geometry.isEmpty) continue;

      final startCoord = step.geometry.first;

      // Calculate bearing
      int bearingBefore = 0;
      int bearingAfter = 0;

      if (step.geometry.length >= 2) {
        bearingAfter = calculateBearing(
          startCoord[0],
          startCoord[1],
          step.geometry[1][0],
          step.geometry[1][1],
        );
      }

      if (i > 0 && steps[i - 1].geometry.length >= 2) {
        final prevGeom = steps[i - 1].geometry;
        bearingBefore = calculateBearing(
          prevGeom[prevGeom.length - 2][0],
          prevGeom[prevGeom.length - 2][1],
          prevGeom.last[0],
          prevGeom.last[1],
        );
      }

      String type;
      String? modifier;

      if (i == 0) {
        type = 'depart';
      } else if (i == steps.length - 1) {
        type = 'arrive';
      } else if (step.featType == 'lift') {
        type = 'notification';
      } else {
        type = 'turn';
        modifier = getTurnModifier(bearingBefore, bearingAfter);
      }

      maneuvers.add(
        OsrmManeuver(
          bearingAfter: bearingAfter,
          bearingBefore: bearingBefore,
          location: startCoord,
          type: type,
          modifier: modifier,
        ),
      );
    }

    return maneuvers;
  }

  /// Merge consecutive steps on the same edge/run
  List<NavigationStep> mergeConsecutiveSteps(List<NavigationStep> steps) {
    if (steps.isEmpty) return steps;

    final merged = <NavigationStep>[];
    var current = steps.first;

    for (var i = 1; i < steps.length; i++) {
      final next = steps[i];

      // Merge if same name and type
      if (current.name == next.name && current.featType == next.featType) {
        current = NavigationStep(
          stepIndex: current.stepIndex,
          instruction: current.instruction,
          distanceM: current.distanceM + next.distanceM,
          durationS: current.durationS + next.durationS,
          cumulativeDistanceM: next.cumulativeDistanceM,
          cumulativeTimeS: next.cumulativeTimeS,
          featType: current.featType,
          name: current.name,
          difficulty: current.difficulty,
          liftType: current.liftType,
          geometry: [...current.geometry, ...next.geometry],
          edgeId: current.edgeId,
          fromNode: current.fromNode,
          toNode: next.toNode,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    return merged;
  }
}
