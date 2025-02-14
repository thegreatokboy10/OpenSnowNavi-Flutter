import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:polyline_codec/polyline_codec.dart';
import 'package:snownavi/global_constants.dart';
import 'dart:typed_data'; 
import 'dart:ui';
import 'dart:async';
import 'lift.dart';
import 'piste.dart';
import 'route_engine.dart' as re;

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
    double lineOpacity = 0.8,
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
          lineOpacity: lineOpacity,
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
    double iconOpacity = 0.8, // Opacity for the arrow
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
          iconOpacity: iconOpacity,
        ),
        minzoom: minZoom,
      );
      print('Arrow layer added: $layerId (source: $sourceId)');
    } catch (e) {
      print('Error adding arrow layer $layerId: $e');
    }
  }

  // Method to add a name layer
  static void addNameLayer({
    required MapboxMapController mapController,
    required String sourceId, // Source ID to reference
    required String layerId, // Layer ID for the name layer
    required double textSize, // Font size for the text
    required double minZoom, // Minimum zoom level for rendering the text
    required double textOffset, // Text offset to slightly adjust its position
    double textOpacity = 0.8, // Text opacity
  }) {
    try {
      mapController.addSymbolLayer(
        sourceId,
        layerId,
        SymbolLayerProperties(
          textField: ['get', 'name'], // Use 'name' property from GeoJSON
          textSize: textSize,
          symbolPlacement: 'line', // Place labels along the line
          textAnchor: 'center', // Anchor the text in the center
          textAllowOverlap: false, // Prevent overlapping text
          textOffset: [0, textOffset], // Adjust text position slightly
          textColor: ['get', 'color'], // Use 'color' property from GeoJSON
          textOpacity: textOpacity,
        ),
        minzoom: minZoom,
      );
      print('Name layer added: $layerId (source: $sourceId)');
    } catch (e) {
      print('Error adding name layer $layerId: $e');
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

  // Method to draw a Route object on the map
  static void drawRoute({
    required MapboxMapController mapController,
    required re.Route route,
    required String routeSourceId,
    required String routeLayerId,
    String routeColor = '#FF0000', // Default route color
    double routeLineWidth = 6.0, // Default route line width
    String? beforeLayerId, // Optional parameter to specify layer ordering
  }) {
    try {
      // Decode all route steps and build GeoJSON features
      List<Map<String, dynamic>> features = route.steps.map((step) {
        return {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": PolylineCodec.decode(
              step.geometry,
              precision: 5,
            ).map((coords) => [coords[1], coords[0]]).toList(),
          },
          "properties": {
            "name": step.name,
          },
        };
      }).toList();

      // Decode all points for bounds calculation
      final allPoints = route.steps
          .expand((step) => PolylineCodec.decode(step.geometry, precision: 5))
          .toList();

      // Compute bounds and adjust the camera
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              allPoints.map((point) => point[0].toDouble()).reduce((a, b) => a < b ? a : b), // Minimum latitude
              allPoints.map((point) => point[1].toDouble()).reduce((a, b) => a < b ? a : b), // Minimum longitude
            ),
            northeast: LatLng(
              allPoints.map((point) => point[0].toDouble()).reduce((a, b) => a > b ? a : b), // Maximum latitude
              allPoints.map((point) => point[1].toDouble()).reduce((a, b) => a > b ? a : b), // Maximum longitude
            ),
          ),
        ),
      );

      // Add the GeoJSON source for the route
      mapController.addSource(
        routeSourceId,
        GeojsonSourceProperties(
          data: {
            "type": "FeatureCollection",
            "features": features,
          },
        ),
      );

      // Add the route layer to the map
      mapController.addLineLayer(
        routeSourceId,
        routeLayerId,
        LineLayerProperties(
          lineColor: routeColor, // Set the route line color
          lineWidth: routeLineWidth, // Set the route line width
          lineOpacity: 1, // Set the line opacity
          lineCap: 'round', // Rounded ends for the line
        ),
        belowLayerId: beforeLayerId,
      );

      print('Route drawn and camera fitted to route bounds. Source ID: $routeSourceId, Layer ID: $routeLayerId');
    } catch (e) {
      print('Error drawing route on map: $e');
    }
  }

  static  Future<Uint8List> createCircleMarker() async {
    final int size = GlobalConstants.routeHighlightCircleSize; // Marker size
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(size.toDouble(), size.toDouble())));

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = GlobalConstants.routeHighlightCircleStrokeWidth;

    final fillPaint = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.5, fillPaint);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.5, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Converts coordinates into distances along the piste
  static List<double> calculateDistances(List<List<double>> coordinates) {
    List<double> distances = [0.0];

    for (int i = 1; i < coordinates.length; i++) {
      final prev = coordinates[i - 1];
      final curr = coordinates[i];

      double distance = _haversineDistance(prev[1], prev[0], curr[1], curr[0]); // (lat, lon)
      distances.add(distances.last + distance);
    }

    return distances;
  }

  // Calculates total piste length
  static double calculateTotalDistance(List<List<double>> coordinates) {
    double totalDistance = 0.0;
    for (int i = 1; i < coordinates.length; i++) {
      totalDistance += _haversineDistance(
        coordinates[i - 1][1], coordinates[i - 1][0],
        coordinates[i][1], coordinates[i][0],
      );
    }
    return totalDistance;
  }

  // Haversine formula for distance between two lat/lon points
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth radius in meters
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLon = (lon2 - lon1) * pi / 180.0;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // m
  }

}
