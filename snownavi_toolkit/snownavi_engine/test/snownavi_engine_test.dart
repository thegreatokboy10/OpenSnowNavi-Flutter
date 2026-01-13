import 'package:flutter_test/flutter_test.dart';
import 'package:snownavi_engine/snownavi_engine.dart';

void main() {
  group('Difficulty', () {
    test('fromString parses difficulty levels correctly', () {
      expect(Difficulty.fromString('novice'), Difficulty.novice);
      expect(Difficulty.fromString('easy'), Difficulty.easy);
      expect(Difficulty.fromString('intermediate'), Difficulty.intermediate);
      expect(Difficulty.fromString('advanced'), Difficulty.advanced);
      expect(Difficulty.fromString('expert'), Difficulty.expert);
    });

    test('fromString handles null and empty strings', () {
      expect(Difficulty.fromString(null), Difficulty.novice);
      expect(Difficulty.fromString(''), Difficulty.novice);
      expect(Difficulty.fromString('unknown'), Difficulty.novice);
    });
  });

  group('Haversine Distance', () {
    test('calculates distance between two points', () {
      // Beijing to Shanghai approximately 1068 km
      final distance = haversineDistance(116.4074, 39.9042, 121.4737, 31.2304);
      expect(distance, greaterThan(1000000)); // > 1000 km
      expect(distance, lessThan(1200000)); // < 1200 km
    });

    test('returns 0 for same point', () {
      final distance = haversineDistance(116.4074, 39.9042, 116.4074, 39.9042);
      expect(distance, equals(0));
    });
  });

  group('Polyline Encoding', () {
    test('encodes and decodes coordinates correctly', () {
      final coords = [
        [116.4074, 39.9042],
        [116.4084, 39.9052],
        [116.4094, 39.9062],
      ];

      final encoded = encodePolyline(coords);
      expect(encoded, isNotEmpty);

      final decoded = decodePolyline(encoded);
      expect(decoded.length, equals(3));

      // Check coordinates are approximately equal (within precision)
      for (var i = 0; i < coords.length; i++) {
        expect(decoded[i][0], closeTo(coords[i][0], 0.00001));
        expect(decoded[i][1], closeTo(coords[i][1], 0.00001));
      }
    });
  });

  group('SkiGraph', () {
    test('creates graph from JSON', () {
      final json = {
        'nodes': [
          {'node_id': 1, 'lon': 116.0, 'lat': 40.0, 'name': 'Node 1'},
          {'node_id': 2, 'lon': 116.1, 'lat': 40.1, 'name': 'Node 2'},
          {'node_id': 3, 'lon': 116.2, 'lat': 40.2, 'name': 'Node 3'},
        ],
        'edges': [
          {
            'edge_id': 1,
            'from_node': 1,
            'to_node': 2,
            'name': 'Run A',
            'src_feat_type': 'run',
            'difficulty': 'easy',
            'length_m': 500,
            'is_oneway': false,
          },
          {
            'edge_id': 2,
            'from_node': 2,
            'to_node': 3,
            'name': 'Lift B',
            'src_feat_type': 'lift',
            'length_m': 800,
            'duration': 180,
            'is_oneway': true,
          },
        ],
      };

      final graph = SkiGraph.fromJson(json);

      expect(graph.nodes.length, equals(3));
      expect(graph.edges.length, equals(2));
      expect(
        graph.directedEdges.length,
        equals(3),
      ); // 2 for bidirectional + 1 for oneway
    });
  });

  group('NavigationEngine', () {
    late NavigationEngine engine;

    setUp(() {
      final json = {
        'nodes': [
          {'node_id': 1, 'lon': 116.0, 'lat': 40.0},
          {'node_id': 2, 'lon': 116.01, 'lat': 40.01},
          {'node_id': 3, 'lon': 116.02, 'lat': 40.02},
        ],
        'edges': [
          {
            'edge_id': 1,
            'from_node': 1,
            'to_node': 2,
            'name': 'Easy Run',
            'src_feat_type': 'run',
            'difficulty': 'easy',
            'length_m': 500,
            'is_oneway': false,
          },
          {
            'edge_id': 2,
            'from_node': 2,
            'to_node': 3,
            'name': 'Intermediate Run',
            'src_feat_type': 'run',
            'difficulty': 'intermediate',
            'length_m': 600,
            'is_oneway': false,
          },
        ],
      };
      engine = NavigationEngine.fromJson(json);
    });

    test('routes between nodes', () {
      final result = engine.routeByNodes(1, 3);

      expect(result.success, isTrue);
      expect(result.routes.length, equals(1));
      expect(result.routes.first.nodes, equals([1, 2, 3]));
    });

    test('respects difficulty constraints', () {
      final prefs = RoutePreferences(maxDifficulty: Difficulty.easy);
      final result = engine.routeByNodes(1, 3, prefs: prefs);

      // Should fail because intermediate run is required
      expect(result.success, isFalse);
    });

    test('returns error for non-existent nodes', () {
      final result = engine.routeByNodes(1, 999);

      expect(result.success, isFalse);
      expect(result.error, contains('999'));
    });
  });

  group('RoutePreferences', () {
    test('default preferences allow all difficulties', () {
      const prefs = RoutePreferences();
      expect(prefs.maxDifficulty, equals(Difficulty.expert));
      expect(prefs.preferLifts, isFalse);
    });

    test('custom preferences are respected', () {
      const prefs = RoutePreferences(
        maxDifficulty: Difficulty.intermediate,
        preferLifts: true,
      );
      expect(prefs.maxDifficulty, equals(Difficulty.intermediate));
      expect(prefs.preferLifts, isTrue);
    });
  });
}
