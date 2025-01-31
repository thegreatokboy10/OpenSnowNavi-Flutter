import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

class Route {
  final double distance; // Total distance of the route in meters
  final double duration; // Total duration of the route in seconds
  final String summary; // Summary of the route
  final List<RouteStep> steps; // List of steps in the route

  Route({
    required this.distance,
    required this.duration,
    required this.summary,
    required this.steps,
  });

  // Factory constructor to parse the route response JSON
  factory Route.fromJson(Map<String, dynamic> json) {
    final routeData = json['routes']?.first;
    if (routeData == null) {
      throw Exception('No routes found in response');
    }

    final legs = routeData['legs'] as List;
    final steps = legs
        .expand((leg) => (leg['steps'] as List)
            .map((step) => RouteStep.fromJson(step))) // Parse each step
        .toList();

    return Route(
      distance: routeData['distance'],
      duration: routeData['duration'],
      summary: routeData['summary'] ?? '',
      steps: steps,
    );
  }
}

class RouteStep {
  final String name; // Name of the step
  final String geometry; // Encoded polyline for the step's path
  final double distance; // Distance of the step in meters
  final double duration; // Duration of the step in seconds
  final String mode; // Mode of transport (e.g., walking, driving)
  final Maneuver maneuver; // Maneuver information

  RouteStep({
    required this.name,
    required this.geometry,
    required this.distance,
    required this.duration,
    required this.mode,
    required this.maneuver,
  });

  // Factory constructor to parse a step
  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      name: json['name'] ?? '',
      geometry: json['geometry'] ?? '',
      distance: json['distance'] ?? 0.0,
      duration: json['duration'] ?? 0.0,
      mode: json['mode'] ?? '',
      maneuver: Maneuver.fromJson(json['maneuver']),
    );
  }
}

class Maneuver {
  final String type; // Type of the maneuver (e.g., depart, turn)
  final String? modifier; // Modifier for the maneuver (e.g., left, right)
  final List<double> location; // Coordinates of the maneuver

  Maneuver({
    required this.type,
    this.modifier,
    required this.location,
  });

  // Factory constructor to parse maneuver
  factory Maneuver.fromJson(Map<String, dynamic> json) {
    return Maneuver(
      type: json['type'],
      modifier: json['modifier'],
      location: (json['location'] as List<dynamic>).cast<num>().map((e) => e.toDouble()).toList(),
    );
  }
}

class RouteEngine {
  final String baseUrl;

  // Constructor to allow the base URL to be specified
  RouteEngine({this.baseUrl = 'https://snownavi.ski/route/v1'});

  // Method to generate a route between two coordinates
  Future<Route?> generateRoute({
    required LatLng startCoordinate,
    required LatLng endCoordinate,
    List<LatLng>? stopovers, // Optional list of stopovers
    String? selectedResortKey,
  }) async {
    // Build coordinate string, ensuring all coordinates are separated by ';'
    String coordinates = [
      '${startCoordinate.longitude},${startCoordinate.latitude}', // Start point
      if (stopovers != null && stopovers.isNotEmpty)
        ...stopovers.map((stop) => '${stop.longitude},${stop.latitude}'), // Stopovers
      '${endCoordinate.longitude},${endCoordinate.latitude}', // End point
    ].join(';'); // Ensure correct separator

    // Construct the API URL
    String url = '$baseUrl/$coordinates?alternatives=false&overview=false&steps=true';

    if (selectedResortKey != '3valley') {
      url = 'https://snownavi.ski/route/$selectedResortKey/v1/$coordinates?alternatives=false&overview=false&steps=true';
    }

    // print("get route from $url");

    try {
      // Await the server's response
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Decode the response body
        final jsonResponse = jsonDecode(response.body);
        print('Raw Route Response: $jsonResponse');

        // Parse the JSON response into a Route object
        final route = Route.fromJson(jsonResponse);

        // Debug prints to verify Route object
        print('Route Object:');
        print('- Summary: ${route.summary}');
        print('- Total Distance: ${route.distance} meters');
        print('- Total Duration: ${route.duration} seconds');
        print('- Steps Count: ${route.steps.length}');
        for (int i = 0; i < route.steps.length; i++) {
          final step = route.steps[i];
          print('  Step ${i + 1}:');
          print('    - Name: ${step.name}');
          print('    - Geometry: ${step.geometry}');
          print('    - Distance: ${step.distance} meters');
          print('    - Duration: ${step.duration} seconds');
          print('    - Mode: ${step.mode}');
          print('    - Maneuver Type: ${step.maneuver.type}');
          print('    - Maneuver Modifier: ${step.maneuver.modifier ?? "none"}');
          print('    - Maneuver Location: ${step.maneuver.location}');
        }

        // Return the parsed Route object
        return route;
      } else {
        print('Failed to fetch route. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error while fetching route: $e');
      return null;
    }
  }
}
