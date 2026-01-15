import 'dart:typed_data';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// 媒体类型枚举
enum MediaType { photo, video }

/// 滑行记录中的媒体项（照片或视频）
class SessionMedia {
  final String id; // AssetEntity.id from photo_manager
  final MediaType type;
  final DateTime captureTime;
  final double latitude;
  final double longitude;
  final double? altitude;
  final int width;
  final int height;
  final Duration? duration; // 仅视频有效

  // 缓存的缩略图数据
  Uint8List? thumbnailData;

  SessionMedia({
    required this.id,
    required this.type,
    required this.captureTime,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.width,
    required this.height,
    this.duration,
    this.thumbnailData,
  });

  /// 获取 Mapbox Point 用于标注放置
  Point get point => Point(coordinates: Position(longitude, latitude));

  /// 检查坐标是否有效
  bool get hasValidLocation =>
      latitude != 0 &&
      longitude != 0 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  /// 复制并更新缩略图数据
  SessionMedia copyWithThumbnail(Uint8List? thumbnail) {
    return SessionMedia(
      id: id,
      type: type,
      captureTime: captureTime,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      width: width,
      height: height,
      duration: duration,
      thumbnailData: thumbnail,
    );
  }
}
