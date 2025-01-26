import 'geojson_helper.dart';

class Lift {
  final String id;
  final String name;
  final String color;
  final List<List<double>> coordinates;
  final String bearing;
  double lineWidth;
  bool visible; // Flag to control visibility
  static Set<String> addedLayers = {}; // Track added layers

  Lift({
    required this.id,
    required this.name,
    required this.color,
    required this.coordinates,
    required this.bearing,
    this.visible = true, // Default to visible
    this.lineWidth = 2, // Default line width
  });

  // Factory constructor to parse the GeoJSON feature into a Lift object
  factory Lift.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    return Lift(
      id: properties['id'] ?? 'Unknown',
      name: properties['name'] ?? 'Unknown',
      color: properties['color'] ?? 'gray',
      coordinates: GeoJsonHelper.parseCoordinates(geometry), // Use helper to parse coordinates
      bearing: properties['bearing']?.toString() ?? '0', // Handle null bearings
    );
  }
}
