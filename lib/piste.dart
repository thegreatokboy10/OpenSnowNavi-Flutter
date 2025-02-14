import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'geojson_helper.dart';

class Piste {
  final String id;
  final String name;
  final String difficulty;
  final String color;
  final List<List<double>> coordinates;
  final List<String> uses;
  final List<double>? elevation; // Elevation data is optional
  double lineWidth;
  double highlightOpacity;
  Color secondColor;
  bool visible; // Flag to control visibility

  Piste({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.color,
    required this.coordinates,
    required this.uses, // Type of piste
    this.elevation, // Elevation profile is optional
    this.visible = true, // Default to visible
    this.lineWidth = 2, // Default line width
    this.highlightOpacity = 0.8, // Default highlight opacity
    this.secondColor = Colors.white,
  });

  // Factory constructor to parse the GeoJSON feature into a Piste object
  factory Piste.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    // print("Parsing Piste from GeoJSON...");
    // print("Properties: $properties");

    // Check if the geometry type is LineString
    if (geometry['type'] != 'LineString') {
      throw Exception('Unsupported geometry type: ${geometry['type']}');
    }

    // Only allow "downhill" and "connection" runs
    if (!(properties['uses'].contains('downhill')) && !(properties['uses'].contains('connection'))) {
      throw Exception('Unsupported uses: ${properties['uses']}');
    }

    List<double>? elevationData;
    if (properties.containsKey('elevationProfile') && properties['elevationProfile']?['heights'] != null) {
      elevationData = (properties['elevationProfile']['heights'] as List).map((e) => (e as num).toDouble()).toList();
      print("Elevation data found: ${elevationData.length} points");
    } else {
      print("No elevation data available for piste: ${properties['name']}");
    }

    return Piste(
      id: properties['id'] ?? 'Unknown',
      name: properties['name'] ?? 'Cat Track',
      difficulty: properties['difficulty'] ?? 'unknown',
      color: properties['color'] ?? 'gray',
      coordinates: GeoJsonHelper.parseCoordinates(geometry), // Use helper to parse coordinates
      uses: (properties['uses'] ?? []).toList().cast<String>(), // Safely cast uses to List<String>
      elevation: elevationData,
    );
  }

  // Method to generate GeoJSON feature for this piste
  Map<String, dynamic> toFeature() {
    return {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": coordinates,
      },
      "properties": {
        "color": color,
        "name": name,
        "difficulty": difficulty,
        "id": id,
        "uses": uses,
        if (elevation != null) "elevationProfile": {"heights": elevation}, // Include elevation data if available
      },
    };
  }

  void highlightMe(MapboxMapController mapController) {
    const highlightedSourceId = 'highlighted-feature';
    const highlightedLayerId = 'highlighted-layer';

    // Add the highlighted source
    GeoJsonHelper.addHighlightedFeatureSource(
      mapController: mapController,
      sourceId: highlightedSourceId,
      geometry: {
        "type": "LineString",
        "coordinates": coordinates,
      },
      color: color, // Use the piste's color for the highlighted feature
    );

    // Add the highlighted layer
    GeoJsonHelper.addHighlightedLineLayer(
      mapController: mapController,
      sourceId: highlightedSourceId,
      layerId: highlightedLayerId,
      color: color, // Use the piste's color for the highlighted line
      lineWidth: lineWidth * 5, // Make the highlighted line wider
      lineOpacity: highlightOpacity, // Set a default opacity for highlighting
    );

    print('Highlighted layer and source added for piste: $name');
  }

  void unhighlightMe(MapboxMapController mapController) {
    mapController.removeLayer('highlighted-layer');
    mapController.removeSource('highlighted-feature');
  }
}
