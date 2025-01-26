import 'package:mapbox_gl/mapbox_gl.dart';
import 'lift.dart';
import 'piste.dart';

class GeoJsonHelper {
  // Helper method to generate a source and layer for a list of objects
  static void addAggregateSourceAndLayer({
    required MapboxMapController mapController,
    required List<dynamic> items, // List of Lift or Piste objects
    required String sourceId,
    required String layerId,
    required double lineWidth,
    required List<String> sourceList, // List to track sources
    required List<String> layerList, // List to track layers
    String colorProperty = 'color',
  }) {
    // Validate input
    if (items.isEmpty) {
      print('No items to add for $sourceId');
      return;
    }

    // Generate GeoJSON features
    List<Map<String, dynamic>> features = items.map((item) {
      // Check the object type (Lift or Piste) and map properties accordingly
      if (item is Lift) {
        return {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": item.coordinates,
          },
          "properties": {
            "color": item.color,
            "name": item.name,
          },
        };
      } else if (item is Piste) {
        return {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": item.coordinates,
          },
          "properties": {
            "color": item.color,
            "name": item.name,
            "difficulty": item.difficulty,
          },
        };
      } else {
        throw Exception('Unsupported object type: ${item.runtimeType}');
      }
    }).toList();

    try {
      // Add GeoJSON source
      mapController.addSource(
        sourceId,
        GeojsonSourceProperties(data: {
          "type": "FeatureCollection",
          "features": features,
        }),
      );
      print('GeoJSON source added: $sourceId with ${features.length} features');
      sourceList.add(sourceId); // Track the created source ID

      // Add line layer
      mapController.addLineLayer(
        sourceId,
        layerId,
        LineLayerProperties(
          lineColor: ['get', colorProperty], // Use color property from GeoJSON
          lineWidth: lineWidth,
          lineOpacity: 0.8,
          lineCap: 'round',
        ),
      );
      print('Line layer added: $layerId (source: $sourceId)');
      print('Line width: $lineWidth');
      layerList.add(layerId); // Track the created layer ID
    } catch (e) {
      print('Error adding source or layer for $sourceId: $e');
    }
  }

  // Helper function to parse coordinates for LineString geometry
  static List<List<double>> parseCoordinates(dynamic geometry) {
    if (geometry['type'] == 'LineString') {
      // Map coordinates explicitly to List<List<double>> for LineString
      return (geometry['coordinates'] as List)
          .map<List<double>>((e) => (e as List).map<double>((coord) => coord.toDouble()).toList())
          .toList();
    } else {
      throw Exception('Unsupported geometry type: ${geometry['type']}');
    }
  }
}
