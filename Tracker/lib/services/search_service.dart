import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 坐标类
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}

/// POI 搜索服务 - 基于 Nominatim OpenStreetMap API
class SearchService {
  static const String baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const double earthRadius = 6371.0; // 地球半径（公里）

  /// 计算两点之间的 Haversine 距离（公里）
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 搜索指定中心点周围的 POI
  /// [query] 搜索关键词
  /// [center] 中心坐标
  /// [radiusKm] 搜索半径（公里）
  static Future<List<Map<String, dynamic>>> searchPOI(
    String query,
    LatLng center,
    double radiusKm,
  ) async {
    // 计算边界框
    double lat = center.latitude;
    double lon = center.longitude;
    double deltaLat = radiusKm / earthRadius * (180 / pi);
    double deltaLon =
        radiusKm / (earthRadius * cos(lat * pi / 180)) * (180 / pi);

    double minLat = lat - deltaLat;
    double maxLat = lat + deltaLat;
    double minLon = lon - deltaLon;
    double maxLon = lon + deltaLon;

    // 构造 viewbox 参数
    String viewbox = '$minLon,$minLat,$maxLon,$maxLat';

    // 构造 API 请求 URL
    final Uri url = Uri.parse(
      '$baseUrl?q=$query&format=json&addressdetails=1&viewbox=$viewbox&bounded=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SnowNaviTracker/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = jsonDecode(response.body);

        // 映射并按距离排序结果
        List<Map<String, dynamic>> results = jsonResponse.map((result) {
          double lat = double.parse(result['lat']);
          double lon = double.parse(result['lon']);
          double distance = _calculateDistance(
            center.latitude,
            center.longitude,
            lat,
            lon,
          );
          return {
            'name': result['display_name'] ?? 'Unknown',
            'lat': lat,
            'lng': lon,
            'distance': distance,
          };
        }).toList();

        // 按距离排序
        results.sort((a, b) => a['distance'].compareTo(b['distance']));

        return results;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
