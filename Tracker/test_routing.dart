import 'dart:io';
import 'package:path/path.dart' as path;
import 'lib/snownavi_engine/lib/snownavi_engine.dart';

void main() async {
  // Load the navigation engine
  final dbPath = path.join(Directory.current.path, 'assets/ski_resorts/morzine/navigation.sqlite');
  print('Loading database from: $dbPath');
  
  final engine = await NavigationEngine.fromSqlite(dbPath);
  print('Engine loaded successfully\n');
  
  // Route from node 845 to node 12
  final result = engine.routeByNodes(845, 12);
  
  if (result.success) {
    final route = result.routes[0];
    print('Flutter Engine Result:');
    print('Nodes: ${route.nodes}');
    print('Edges (directed IDs): ${route.edges}');
    print('Total cost: ${route.totalCost.toStringAsFixed(2)}');
    print('Total length: ${route.totalLength.toStringAsFixed(2)}m');
    
    print('\nEdge details:');
    for (var i = 0; i < route.edges.length; i++) {
      final directedId = route.edges[i];
      final directedEdge = engine.graph.directedEdges[directedId];
      if (directedEdge != null) {
        final baseId = directedEdge.baseEdgeId;
        final isReversed = directedEdge.isReversed;
        print('  ${i + 1}. DirectedEdge $directedId (base=$baseId, reversed=$isReversed): ${directedEdge.name} (${directedEdge.fromNode}->${directedEdge.toNode})');
      }
    }
  } else {
    print('Failed: ${result.error}');
  }
}
