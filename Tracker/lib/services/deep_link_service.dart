import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;
import '../models/route_planning_state.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'route_feedback_service.dart';

/// 深度链接服务 - 处理路线分享链接和剪贴板检测
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static DeepLinkService get instance => _instance;

  // 路线数据回调
  Function(SharedRouteData routeData)? onRouteReceived;

  // 接收的路线数据
  SharedRouteData? _pendingRouteData;
  SharedRouteData? get pendingRouteData => _pendingRouteData;

  // 已处理的剪贴板内容，避免重复提示
  String? _lastProcessedClipboard;

  /// 清除待处理的路线数据
  void clearPendingRoute() {
    _pendingRouteData = null;
  }

  /// 检查剪贴板中是否有路线分享数据
  /// 返回解析到的路线数据，如果没有则返回 null
  Future<SharedRouteData?> checkClipboardForRoute() async {
    try {
      debugPrint('[DeepLinkService] Checking clipboard for route...');
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null) {
        debugPrint('[DeepLinkService] Clipboard is empty');
        return null;
      }

      final text = clipboardData.text!;
      debugPrint('[DeepLinkService] Clipboard text length: ${text.length}');

      // 检查是否与上次处理的相同，避免重复提示
      if (text == _lastProcessedClipboard) {
        debugPrint('[DeepLinkService] Same as last processed, skipping');
        return null;
      }

      // 尝试解析分享文本中的路线数据
      final routeData = parseRouteFromShareText(text);
      if (routeData != null) {
        debugPrint('[DeepLinkService] Route data parsed successfully');
        _lastProcessedClipboard = text;
        return routeData;
      }

      debugPrint('[DeepLinkService] No route data found in clipboard');
      return null;
    } catch (e) {
      debugPrint('[DeepLinkService] Error checking clipboard: $e');
      return null;
    }
  }

  /// 从分享文本中解析路线数据
  /// 文本格式: 【SNOWNAVI_ROUTE】compactData【/SNOWNAVI_ROUTE】
  /// 紧凑格式: r:resortKey|o:lat,lng,name|d:lat,lng,name|s:lat,lng,name;lat,lng,name
  SharedRouteData? parseRouteFromShareText(String text) {
    try {
      const prefix = RouteFeedbackService.routeSharePrefix;
      const suffix = RouteFeedbackService.routeShareSuffix;

      final startIndex = text.indexOf(prefix);
      if (startIndex == -1) {
        debugPrint('[DeepLinkService] Share prefix not found');
        return null;
      }

      final endIndex = text.indexOf(suffix, startIndex);
      if (endIndex == -1) {
        debugPrint('[DeepLinkService] Share suffix not found');
        return null;
      }

      final compactData =
          text.substring(startIndex + prefix.length, endIndex).trim();
      if (compactData.isEmpty) {
        debugPrint('[DeepLinkService] Empty compact data');
        return null;
      }

      debugPrint('[DeepLinkService] Parsing compact data: $compactData');
      return parseRouteFromCompactString(compactData);
    } catch (e) {
      debugPrint('[DeepLinkService] Error parsing share text: $e');
      return null;
    }
  }

  /// 从紧凑字符串解析路线数据
  /// 格式: r:resortKey|o:lat,lng,name|d:lat,lng,name|s:lat,lng,name;lat,lng,name
  SharedRouteData? parseRouteFromCompactString(String compactData) {
    try {
      String? resortKey;
      RoutePointData? origin;
      RoutePointData? destination;
      List<RoutePointData> stopovers = [];

      final parts = compactData.split('|');
      for (final part in parts) {
        if (part.isEmpty) continue;

        final colonIndex = part.indexOf(':');
        if (colonIndex == -1) continue;

        final key = part.substring(0, colonIndex);
        final value = part.substring(colonIndex + 1);

        switch (key) {
          case 'r':
            resortKey = value;
            break;
          case 'o':
            origin = _parsePointFromCompact(value);
            break;
          case 'd':
            destination = _parsePointFromCompact(value);
            break;
          case 's':
            // 多个途径点用分号分隔
            final stopoverParts = value.split(';');
            for (final sp in stopoverParts) {
              final point = _parsePointFromCompact(sp);
              if (point != null) {
                stopovers.add(point);
              }
            }
            break;
        }
      }

      if (origin == null && destination == null) {
        debugPrint('[DeepLinkService] No origin or destination found');
        return null;
      }

      debugPrint(
          '[DeepLinkService] Parsed route: resort=$resortKey, origin=${origin?.name}, destination=${destination?.name}, stopovers=${stopovers.length}');
      return SharedRouteData(
        resortKey: resortKey,
        origin: origin,
        destination: destination,
        stopovers: stopovers,
      );
    } catch (e) {
      debugPrint('[DeepLinkService] Error parsing compact string: $e');
      return null;
    }
  }

  /// 从紧凑格式解析单个点
  /// 格式: lat,lng,name
  RoutePointData? _parsePointFromCompact(String value) {
    try {
      final commaIndex1 = value.indexOf(',');
      if (commaIndex1 == -1) return null;

      final commaIndex2 = value.indexOf(',', commaIndex1 + 1);
      if (commaIndex2 == -1) return null;

      final lat = double.parse(value.substring(0, commaIndex1));
      final lng = double.parse(value.substring(commaIndex1 + 1, commaIndex2));
      final name = Uri.decodeComponent(value.substring(commaIndex2 + 1));

      return RoutePointData(name: name, lat: lat, lng: lng);
    } catch (e) {
      debugPrint('[DeepLinkService] Error parsing point: $e');
      return null;
    }
  }

  /// 标记剪贴板内容已处理（用户忽略后不再提示）
  void markClipboardAsProcessed(String text) {
    _lastProcessedClipboard = text;
  }

  /// 清除剪贴板处理记录（允许再次检测）
  void clearClipboardRecord() {
    _lastProcessedClipboard = null;
  }

  /// 从 URL 解析路线数据
  SharedRouteData? parseRouteFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host != 'snownavi.ski') return null;
      if (uri.path != '/route') return null;

      final data = uri.queryParameters['data'];
      if (data == null || data.isEmpty) return null;

      return parseRouteFromBase64(data);
    } catch (e) {
      debugPrint('[DeepLinkService] Error parsing URL: $e');
      return null;
    }
  }

  /// 从 Base64 编码解析路线数据
  SharedRouteData? parseRouteFromBase64(String encodedData) {
    try {
      final decoded = utf8.decode(base64Decode(encodedData));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return SharedRouteData.fromJson(json);
    } catch (e) {
      debugPrint('[DeepLinkService] Error parsing Base64: $e');
      return null;
    }
  }

  /// 从 JSON 文件解析路线数据
  Future<SharedRouteData?> parseRouteFromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 检查是否为反馈格式（包含 request 和 response）
      if (json.containsKey('request')) {
        final request = json['request'] as Map<String, dynamic>;
        return SharedRouteData.fromFeedbackJson(request, json['resortKey']);
      }

      // 标准紧凑格式
      return SharedRouteData.fromJson(json);
    } catch (e) {
      debugPrint('[DeepLinkService] Error parsing JSON file: $e');
      return null;
    }
  }

  /// 导入路线文件
  Future<SharedRouteData?> importRouteFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.path == null) return null;

      return parseRouteFromJsonFile(file.path!);
    } catch (e) {
      debugPrint('[DeepLinkService] Error importing file: $e');
      return null;
    }
  }

  /// 处理接收到的路线数据
  void handleRouteData(SharedRouteData routeData) {
    _pendingRouteData = routeData;
    onRouteReceived?.call(routeData);
  }
}

/// 共享路线数据模型
class SharedRouteData {
  final int version;
  final String? resortKey;
  final RoutePointData? origin;
  final RoutePointData? destination;
  final List<RoutePointData> stopovers;

  SharedRouteData({
    this.version = 1,
    this.resortKey,
    this.origin,
    this.destination,
    this.stopovers = const [],
  });

  /// 从紧凑 JSON 解析
  factory SharedRouteData.fromJson(Map<String, dynamic> json) {
    return SharedRouteData(
      version: json['v'] ?? 1,
      resortKey: json['r'],
      origin: json['o'] != null ? RoutePointData.fromJson(json['o']) : null,
      destination:
          json['d'] != null ? RoutePointData.fromJson(json['d']) : null,
      stopovers: (json['s'] as List<dynamic>?)
              ?.map((s) => RoutePointData.fromJson(s))
              .toList() ??
          [],
    );
  }

  /// 从反馈格式 JSON 解析
  factory SharedRouteData.fromFeedbackJson(
      Map<String, dynamic> request, dynamic resortKey) {
    return SharedRouteData(
      version: 1,
      resortKey: resortKey?.toString(),
      origin: request['origin'] != null
          ? RoutePointData.fromFeedbackJson(request['origin'])
          : null,
      destination: request['destination'] != null
          ? RoutePointData.fromFeedbackJson(request['destination'])
          : null,
      stopovers: (request['stopovers'] as List<dynamic>?)
              ?.map((s) => RoutePointData.fromFeedbackJson(s))
              .toList() ??
          [],
    );
  }
}

/// 路线点数据
class RoutePointData {
  final String name;
  final double lat;
  final double lng;

  RoutePointData({
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory RoutePointData.fromJson(Map<String, dynamic> json) {
    return RoutePointData(
      name: json['n'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  factory RoutePointData.fromFeedbackJson(Map<String, dynamic> json) {
    return RoutePointData(
      name: json['name'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  /// 转换为 RoutePoint
  RoutePoint toRoutePoint(RoutePointType type) {
    return RoutePoint(
      id: 'shared_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      coordinates: Position(lng, lat),
      type: type,
    );
  }
}
