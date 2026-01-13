/// OSRM-compatible response formatting
library;

import 'models.dart';
import 'results.dart';
import 'ski_graph.dart';
import 'utils.dart';

/// Formats navigation results in OSRM-compatible format
class OsrmFormatter {
  final SkiGraph graph;

  OsrmFormatter(this.graph);

  /// Format a route result as OSRM response
  Map<String, dynamic> formatRouteResponse(
    RouteResult result,
    List<List<NavigationStep>> allSteps,
  ) {
    if (!result.success) {
      return {
        'code': 'NoRoute',
        'message': result.error ?? 'No route found',
        'routes': [],
      };
    }

    final routes = <Map<String, dynamic>>[];

    for (var i = 0; i < result.routes.length; i++) {
      final path = result.routes[i];
      final steps = i < allSteps.length ? allSteps[i] : <NavigationStep>[];

      routes.add(_formatRoute(path, steps));
    }

    return {
      'code': 'Ok',
      'routes': routes,
      'waypoints': _formatWaypoints(result),
    };
  }

  Map<String, dynamic> _formatRoute(RoutePath path, List<NavigationStep> steps) {
    // Collect all geometry
    final allCoords = <List<double>>[];
    for (final step in steps) {
      allCoords.addAll(step.geometry);
    }

    // Calculate totals
    var totalDistance = 0.0;
    var totalDuration = 0.0;
    for (final step in steps) {
      totalDistance += step.distanceM;
      totalDuration += step.durationS;
    }

    return {
      'geometry': encodePolyline(allCoords),
      'legs': [_formatLeg(steps, totalDistance, totalDuration)],
      'distance': totalDistance,
      'duration': totalDuration,
      'weight': path.totalCost,
      'weight_name': 'time',
    };
  }

  Map<String, dynamic> _formatLeg(
    List<NavigationStep> steps,
    double distance,
    double duration,
  ) {
    return {
      'steps': steps.map(_formatStep).toList(),
      'distance': distance,
      'duration': duration,
      'summary': _generateSummary(steps),
    };
  }

  Map<String, dynamic> _formatStep(NavigationStep step) {
    final maneuver = <String, dynamic>{
      'type': _getManeuverType(step),
      'location': step.geometry.isNotEmpty ? step.geometry.first : [0, 0],
    };

    if (step.geometry.length >= 2) {
      maneuver['bearing_after'] = calculateBearing(
        step.geometry[0][0], step.geometry[0][1],
        step.geometry[1][0], step.geometry[1][1],
      );
    }

    return {
      'geometry': encodePolyline(step.geometry),
      'maneuver': maneuver,
      'mode': step.featType == 'lift' ? 'lift' : 'skiing',
      'name': step.name ?? '',
      'distance': step.distanceM,
      'duration': step.durationS,
      'driving_side': 'right',
      // Custom ski-specific fields
      'ski_info': {
        'feat_type': step.featType,
        'difficulty': step.difficulty,
        'lift_type': step.liftType,
      },
    };
  }

  String _getManeuverType(NavigationStep step) {
    if (step.stepIndex == 0) return 'depart';
    if (step.featType == 'lift') return 'notification';
    return 'turn';
  }

  String _generateSummary(List<NavigationStep> steps) {
    final names = steps
        .where((s) => s.name != null && s.name!.isNotEmpty)
        .map((s) => s.name!)
        .toSet()
        .take(3)
        .toList();
    return names.join(', ');
  }

  List<Map<String, dynamic>> _formatWaypoints(RouteResult result) {
    final waypoints = <Map<String, dynamic>>[];

    if (result.startSnapped != null) {
      waypoints.add({
        'name': '',
        'location': [result.startSnapped!.snappedLon, result.startSnapped!.snappedLat],
        'hint': 'start',
      });
    }

    for (final wp in result.waypointsSnapped) {
      waypoints.add({
        'name': '',
        'location': [wp.snappedLon, wp.snappedLat],
        'hint': 'waypoint',
      });
    }

    if (result.endSnapped != null) {
      waypoints.add({
        'name': '',
        'location': [result.endSnapped!.snappedLon, result.endSnapped!.snappedLat],
        'hint': 'end',
      });
    }

    return waypoints;
  }
}

