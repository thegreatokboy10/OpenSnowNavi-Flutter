import 'package:flutter/material.dart';
import '../utils/geojson_helper.dart';

/// 雪道模型 - 复刻网页版 lib/piste.dart
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

  /// Factory constructor to parse the GeoJSON feature into a Piste object
  /// 复刻自网页版 Piste.fromGeoJson
  /// 只允许 "downhill" 和 "connection" 类型的雪道
  factory Piste.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    // Check if the geometry type is LineString
    if (geometry['type'] != 'LineString') {
      throw Exception('Unsupported geometry type: ${geometry['type']}');
    }

    // Only allow "downhill" and "connection" runs
    // 复刻网页版的筛选逻辑
    final uses = properties['uses'];
    if (uses == null) {
      throw Exception('Missing uses property');
    }
    
    bool isValidUse = false;
    if (uses is List) {
      isValidUse = uses.contains('downhill') || uses.contains('connection');
    } else if (uses is String) {
      isValidUse = uses == 'downhill' || uses == 'connection';
    }
    
    if (!isValidUse) {
      throw Exception('Unsupported uses: $uses');
    }

    List<double>? elevationData;
    if (properties.containsKey('elevationProfile') &&
        properties['elevationProfile']?['heights'] != null) {
      elevationData = (properties['elevationProfile']['heights'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    // 将 uses 转换为 List<String>
    List<String> usesList;
    if (uses is List) {
      usesList = uses.map((e) => e.toString()).toList();
    } else {
      usesList = [uses.toString()];
    }

    return Piste(
      id: properties['id'] ?? 'Unknown',
      name: properties['name'] ?? 'Cat Track',
      difficulty: properties['difficulty'] ?? 'unknown',
      color: properties['color'] ?? 'gray',
      coordinates: GeoJsonHelper.parseCoordinates(geometry),
      uses: usesList,
      elevation: elevationData,
    );
  }

  /// Method to generate GeoJSON feature for this piste
  /// 复刻自网页版 Piste.toFeature
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
        if (elevation != null)
          "elevationProfile": {"heights": elevation},
      },
    };
  }
}

