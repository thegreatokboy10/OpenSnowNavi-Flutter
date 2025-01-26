import 'package:flutter/material.dart';
import 'geojson_helper.dart';

class Piste {
  final String id;
  final String name;
  final String difficulty;
  final String color;
  final List<List<double>> coordinates;
  final List<String> uses;
  double lineWidth;
  Color secondColor;
  bool visible; // Flag to control visibility
  static Set<String> addedLayers = {}; // Track added layers

  Piste({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.color,
    required this.coordinates,
    required this.uses,
    this.visible = true, // Default to visible
    this.lineWidth = 2, // Default line width
    this.secondColor = Colors.white,
  });

  // Factory constructor to parse the GeoJSON feature into a Piste object
  factory Piste.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    return Piste(
      id: properties['id'] ?? 'Unknown',
      name: properties['name'] ?? 'Unknown',
      difficulty: properties['difficulty'] ?? 'unknown',
      color: properties['color'] ?? 'gray',
      coordinates: GeoJsonHelper.parseCoordinates(geometry), // Use helper to parse coordinates
      uses: List<String>.from(properties['uses'] ?? []),
    );
  }
}
