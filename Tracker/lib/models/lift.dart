import '../utils/geojson_helper.dart';

/// 缆车模型 - 复刻网页版 lib/lift.dart
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

  /// Factory constructor to parse the GeoJSON feature into a Lift object
  /// 复刻自网页版 Lift.fromGeoJson
  factory Lift.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    return Lift(
      id: properties['id'] ?? 'Unknown',
      name: properties['name'] ?? 'Unknown',
      color: properties['color'] ?? 'gray',
      type: properties['liftType'] ?? 'Lift',
      ref: properties['ref'] ?? '',
      coordinates: GeoJsonHelper.parseCoordinates(geometry),
      bearing: properties['bearing']?.toString() ?? '0',
    );
  }

  /// Method to generate GeoJSON feature for this lift
  /// 复刻自网页版 Lift.toFeature
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
}

