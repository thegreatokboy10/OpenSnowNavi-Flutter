/// SnowNavi Navigation Engine
///
/// A Flutter package for ski resort navigation with support for:
/// - Route planning with difficulty constraints
/// - Multiple route alternatives
/// - Explore mode with diverse path options
/// - Turn-by-turn navigation instructions
/// - OSRM-compatible response formatting
library;

// Core models
export 'src/models.dart';

// Result types
export 'src/results.dart';

// Graph structure
export 'src/ski_graph.dart';

// Path finding
export 'src/path_finder.dart';

// Coordinate snapping
export 'src/snapper.dart';

// Navigation instructions
export 'src/instruction_generator.dart';

// Main navigation engine
export 'src/navigation_engine.dart';

// Explore mode routing
export 'src/explore_router.dart';

// OSRM formatting
export 'src/osrm_formatter.dart';

// Utilities
export 'src/utils.dart' show haversineDistance, encodePolyline, decodePolyline;
