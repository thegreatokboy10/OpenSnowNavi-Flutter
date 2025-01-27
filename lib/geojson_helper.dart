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
      if (item is Lift || item is Piste) {
        return item.toFeature(); // Call the class-specific method
      } else {
        throw Exception('Unsupported object type: ${item.runtimeType}');
      }
    }).toList().cast<Map<String, dynamic>>();

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

  // Method to add an arrow layer
  static void addArrowLayer({
    required MapboxMapController mapController,
    required String sourceId, // Source ID to reference
    required String layerId, // Layer ID for the arrow layer
    required String iconImage, // Icon image for the arrow
    required double minZoom, // Minimum zoom level for the layer
    List<dynamic>? iconImageExpression, // Optional dynamic icon image expression
  }) {
    try {
      mapController.addSymbolLayer(
        sourceId,
        layerId,
        SymbolLayerProperties(
          iconImage: iconImageExpression ?? iconImage,
          symbolPlacement: 'line-center', // Place along the line
          symbolSpacing: 5000000, // Ensures only one arrow is placed on the line
          iconAllowOverlap: false,
          iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
          iconRotationAlignment: 'map',
        ),
        minzoom: minZoom,
      );
      print('Arrow layer added: $layerId (source: $sourceId)');
    } catch (e) {
      print('Error adding arrow layer $layerId: $e');
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

  // Method to add a source for highlighted feature
  static void addHighlightedFeatureSource({
    required MapboxMapController mapController,
    required String sourceId, // The source ID to create
    required Map<String, dynamic> geometry, // Geometry of the highlighted feature
    required String color, // The color of the highlighted feature
  }) {
    try {
      mapController.addSource(
        sourceId,
        GeojsonSourceProperties(
          data: {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "geometry": geometry, // Geometry of the highlighted feature
                "properties": {
                  "color": color, // Color for the highlighted feature
                },
              },
            ],
          },
        ),
      );
      print('GeoJSON source added: $sourceId');
    } catch (e) {
      print('Error adding GeoJSON source $sourceId: $e');
    }
  }

  // Helper method to add a highlighted line layer
  static void addHighlightedLineLayer({
    required MapboxMapController mapController,
    required String sourceId, // The source ID to reference
    required String layerId, // The layer ID for the highlighted layer
    required String color, // The color for the highlighted line
    required double lineWidth, // The width for the highlighted line
    required double lineOpacity, // The opacity for the highlighted line
    dynamic lineCap = 'round',
  }) {
    try {
      mapController.addLineLayer(
        sourceId,
        layerId,
        LineLayerProperties(
          lineColor: color,
          lineWidth: lineWidth,
          lineOpacity: lineOpacity,
          lineCap: lineCap,
        ),
      );
      print('Highlighted line layer added: $layerId (source: $sourceId)');
      print('Color: $color, Width: $lineWidth, Opacity: $lineOpacity');
    } catch (e) {
      print('Error adding highlighted line layer $layerId: $e');
    }
  }
}
