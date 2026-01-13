/// Utility functions for navigation calculations
library;

import 'dart:math';

/// Haversine distance between two points in meters
double haversineDistance(double lon1, double lat1, double lon2, double lat2) {
  const R = 6371000.0; // Earth radius in meters
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

double _toRadians(double degrees) => degrees * pi / 180;

/// Calculate bearing between two points (0-360, north = 0)
int calculateBearing(double lon1, double lat1, double lon2, double lat2) {
  final lat1Rad = _toRadians(lat1);
  final lat2Rad = _toRadians(lat2);
  final dLon = _toRadians(lon2 - lon1);

  final x = sin(dLon) * cos(lat2Rad);
  final y = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

  final bearing = atan2(x, y) * 180 / pi;
  return ((bearing + 360) % 360).round();
}

/// Get turn modifier based on bearing difference
String getTurnModifier(int bearingBefore, int bearingAfter) {
  var turnAngle = (bearingAfter - bearingBefore + 360) % 360;
  if (turnAngle > 180) turnAngle -= 360;

  if (turnAngle.abs() < 15) return 'straight';
  if (turnAngle >= 15 && turnAngle < 45) return 'slight right';
  if (turnAngle >= 45 && turnAngle < 120) return 'right';
  if (turnAngle >= 120) return 'sharp right';
  if (turnAngle <= -15 && turnAngle > -45) return 'slight left';
  if (turnAngle <= -45 && turnAngle > -120) return 'left';
  return 'sharp left';
}

/// Encode coordinates to Google Polyline format
String encodePolyline(List<List<double>> coordinates, {int precision = 5}) {
  final result = StringBuffer();
  int prevLat = 0;
  int prevLon = 0;
  final factor = pow(10, precision).toInt();

  for (final coord in coordinates) {
    if (coord.length < 2) continue;
    final lon = coord[0];
    final lat = coord[1];

    final latInt = (lat * factor).round();
    final lonInt = (lon * factor).round();

    final dLat = latInt - prevLat;
    final dLon = lonInt - prevLon;

    prevLat = latInt;
    prevLon = lonInt;

    _encodeValue(dLat, result);
    _encodeValue(dLon, result);
  }

  return result.toString();
}

void _encodeValue(int value, StringBuffer result) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    result.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  result.writeCharCode(v + 63);
}

/// Decode Google Polyline to coordinates
List<List<double>> decodePolyline(String encoded, {int precision = 5}) {
  final factor = pow(10, precision);
  final len = encoded.length;
  var index = 0;
  var lat = 0;
  var lng = 0;
  final coordinates = <List<double>>[];

  while (index < len) {
    var shift = 0;
    var result = 0;
    int b;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    shift = 0;
    result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    coordinates.add([lng / factor, lat / factor]);
  }

  return coordinates;
}

/// Parse WKT LINESTRING to coordinates
List<List<double>> parseWktToCoords(String? wkt) {
  if (wkt == null || wkt.isEmpty) return [];

  final match = RegExp(r'LINESTRING\((.+)\)').firstMatch(wkt);
  if (match == null) return [];

  final coords = <List<double>>[];
  for (final point in match.group(1)!.split(', ')) {
    final parts = point.trim().split(' ');
    if (parts.length >= 2) {
      try {
        final lon = double.parse(parts[0]);
        final lat = double.parse(parts[1]);
        coords.add([lon, lat]);
      } catch (_) {}
    }
  }
  return coords;
}

/// Calculate overlap ratio between two edge lists (Jaccard similarity)
double calculateOverlap(List<int> edges1, List<int> edges2) {
  if (edges1.isEmpty || edges2.isEmpty) return 0;
  final set1 = edges1.toSet();
  final set2 = edges2.toSet();
  final intersection = set1.intersection(set2).length;
  final union = set1.union(set2).length;
  return union > 0 ? intersection / union : 0;
}

