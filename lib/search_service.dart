import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart'; // Import LatLng if needed

class SearchService {
  static const String baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const double earthRadius = 6371.0; // Earth's radius in kilometers

  /// Search for POIs within a given radius from a central coordinate
  static Future<List<Map<String, dynamic>>> searchPOI(
      String query, LatLng center, double radiusKm) async {
    // Calculate the bounding box
    double lat = center.latitude;
    double lon = center.longitude;
    double deltaLat = radiusKm / earthRadius * (180 / pi);
    double deltaLon = radiusKm / (earthRadius * cos(lat * pi / 180)) * (180 / pi);

    double minLat = lat - deltaLat;
    double maxLat = lat + deltaLat;
    double minLon = lon - deltaLon;
    double maxLon = lon + deltaLon;

    // Construct the viewbox parameter
    String viewbox = '$minLon,$minLat,$maxLon,$maxLat';

    // Make the API request
    final Uri url = Uri.parse(
        '$baseUrl?q=$query&format=json&addressdetails=1&viewbox=$viewbox&bounded=1');

    print("search poi url: $url");

    try {
      final response = await http.get(url);


      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = jsonDecode(response.body);
        print("search result: $jsonResponse");
        return jsonResponse.map((result) {
          return {
            'name': result['display_name'] ?? 'Unknown',
            'lat': double.parse(result['lat']),
            'lng': double.parse(result['lon']),
          };
        }).toList();
      } else {
        print('Failed to fetch POIs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching POIs: $e');
      return [];
    }
  }
}
