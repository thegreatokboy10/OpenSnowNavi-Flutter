import 'package:mapbox_gl/mapbox_gl.dart';

import 'geojson_helper.dart';

class Lift {
  final String id;
  final String name;
  final String color;
  final String type;
  final String ref;
  final List<List<double>> coordinates;
  final String bearing;
  double lineWidth;
  double highlightOpacity;
  bool visible; // Flag to control visibility

  Lift({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    required this.ref,
    required this.coordinates,
    required this.bearing,
    this.visible = true, // Default to visible
    this.lineWidth = 2, // Default line width
    this.highlightOpacity = 0.8, // Default highlight opacity
  });

  // Factory constructor to parse the GeoJSON feature into a Lift object
  factory Lift.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    return Lift(
      id: properties['id'] ?? 'Unknown',
      name: properties['name'] ?? 'Unknown',
      color: properties['color'] ?? 'gray',
      type: properties['liftType'] ?? 'Lift',
      ref: properties['ref'] ?? '',
      coordinates: GeoJsonHelper.parseCoordinates(geometry), // Use helper to parse coordinates
      bearing: properties['bearing']?.toString() ?? '0', // Handle null bearings
    );
  }

  // Method to generate GeoJSON feature for this lift
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
        "type": type,
        "id": id,
        "ref": ref,
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

    print('Highlighted layer and source added for lift: $name');
  }
}
