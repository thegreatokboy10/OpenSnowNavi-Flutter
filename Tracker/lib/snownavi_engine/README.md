# SnowNavi Engine

A Flutter package for ski resort navigation with route planning, difficulty constraints, and OSRM-compatible output.

## Features

- **Route Planning**: Dijkstra shortest path algorithm with difficulty constraints
- **Alternative Routes**: Yen's K-shortest paths algorithm for multiple route options
- **Explore Mode**: Generate diverse routes starting with different edges
- **Coordinate Snapping**: Snap GPS coordinates to nearest graph nodes/edges
- **Navigation Instructions**: Chinese turn-by-turn navigation instructions
- **OSRM Compatible**: Output routes in OSRM-compatible JSON format
- **SQLite & JSON Support**: Load graph data from SQLite database or JSON

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  snownavi_engine:
    path: ../snownavi_engine  # or publish to pub.dev
```

## Usage

### Basic Routing

```dart
import 'package:snownavi_engine/snownavi_engine.dart';

// Load graph from JSON
final engine = NavigationEngine.fromJson(graphData);

// Route between coordinates
final result = engine.routeByCoords(
  116.0, 40.0,  // start lon, lat
  116.1, 40.1,  // end lon, lat
  prefs: RoutePreferences(
    maxDifficulty: Difficulty.intermediate,
    preferLifts: false,
  ),
  alternatives: 3,  // number of alternative routes
);

if (result.success) {
  for (final route in result.routes) {
    print('Distance: ${route.totalLength}m');
    print('Nodes: ${route.nodes}');
  }
}
```

### Route by Node IDs

```dart
final result = engine.routeByNodes(1, 10, alternatives: 2);
```

### Route with Waypoints

```dart
final result = engine.routeWithWaypoints([
  (116.0, 40.0),   // start
  (116.05, 40.05), // waypoint 1
  (116.1, 40.1),   // end
]);
```

### Navigation Steps

```dart
final steps = engine.getNavigationSteps(result.routes.first);
for (final step in steps) {
  print('${step.instruction} - ${step.distanceM}m');
}
```

### Explore Mode

```dart
final exploreRouter = ExploreRouter(
  engine.graph,
  engine.pathFinder,
  engine.snapper,
);

final exploreResult = exploreRouter.findExploreRoutes(
  startNode, endNode,
  maxRoutes: 5,
  maxOverlap: 0.7,
);

for (var i = 0; i < exploreResult.routes.length; i++) {
  print('Route via ${exploreResult.firstEdgeNames[i]}');
}
```

### OSRM Format

```dart
final formatter = OsrmFormatter(engine.graph);
final allSteps = result.routes.map((r) => engine.getNavigationSteps(r)).toList();
final osrmJson = formatter.formatRouteResponse(result, allSteps);
```

### Load from SQLite

```dart
final engine = await NavigationEngine.fromSqlite('path/to/ski_graph.sqlite');
```

## Data Model

### Graph Structure

- **SkiNode**: Junction points with coordinates and optional elevation
- **SkiEdge**: Connections between nodes (runs or lifts)
- **DirectedEdge**: Directed version of edges for routing

### Difficulty Levels

| Level | Name | Chinese |
|-------|------|---------|
| 0 | novice | 初级 |
| 1 | easy | 简单 |
| 2 | intermediate | 中级 |
| 3 | advanced | 高级 |
| 4 | expert | 专家 |

### Edge Types

- `run`: Ski run (bidirectional by default)
- `lift`: Ski lift (one-way)

## API Reference

### NavigationEngine

| Method | Description |
|--------|-------------|
| `fromSqlite(path)` | Create engine from SQLite database |
| `fromJson(json)` | Create engine from JSON data |
| `routeByCoords(...)` | Route between coordinates |
| `routeByNodes(...)` | Route between node IDs |
| `routeWithWaypoints(...)` | Route through multiple waypoints |
| `getNavigationSteps(path)` | Generate navigation instructions |

### RoutePreferences

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `maxDifficulty` | `Difficulty` | `expert` | Maximum allowed difficulty |
| `preferLifts` | `bool` | `false` | Prefer lift routes |

### RouteResult

| Property | Type | Description |
|----------|------|-------------|
| `routes` | `List<RoutePath>` | List of route alternatives |
| `success` | `bool` | Whether routing succeeded |
| `error` | `String?` | Error message if failed |
| `startSnapped` | `SnappedPoint?` | Snapped start point |
| `endSnapped` | `SnappedPoint?` | Snapped end point |

## License

MIT License
