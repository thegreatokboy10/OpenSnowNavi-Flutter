/// GeoJSON 解析辅助类 - 复刻网页版 lib/geojson_helper.dart
class GeoJsonHelper {
  /// 解析 LineString 坐标
  /// 复刻自网页版 GeoJsonHelper.parseCoordinates
  static List<List<double>> parseCoordinates(dynamic geometry) {
    if (geometry['type'] == 'LineString') {
      // Map coordinates explicitly to List<List<double>> for LineString
      return (geometry['coordinates'] as List)
          .map<List<double>>(
              (e) => (e as List).map<double>((coord) => coord.toDouble()).toList())
          .toList();
    } else {
      throw Exception('Unsupported geometry type: ${geometry['type']}');
    }
  }
}

