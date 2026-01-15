import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/session_media.dart';

/// 相册媒体访问服务
class MediaGalleryService {
  static final MediaGalleryService _instance = MediaGalleryService._internal();
  factory MediaGalleryService() => _instance;
  MediaGalleryService._internal();

  /// 请求相册访问权限
  Future<PermissionState> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
        androidPermission: AndroidPermission(
          type: RequestType.common,
          mediaLocation: true,
        ),
      ),
    );
    return result;
  }

  /// 检查是否有权限
  Future<bool> hasPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  /// 打开系统设置
  Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }

  /// 加载指定时间范围内的媒体（照片和视频）
  Future<List<SessionMedia>> loadSessionMedia({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // 创建日期筛选条件
    final filterOption = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: startTime,
        max: endTime,
      ),
      orders: [
        const OrderOption(
          type: OrderOptionType.createDate,
          asc: true,
        ),
      ],
    );

    // 查询所有相册
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // 照片和视频
      filterOption: filterOption,
    );

    // 收集所有资源
    final List<AssetEntity> allAssets = [];
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count > 0) {
        final assets = await album.getAssetListRange(start: 0, end: count);
        allAssets.addAll(assets);
      }
    }

    // 去重并排序
    final uniqueAssets = <String, AssetEntity>{};
    for (final asset in allAssets) {
      uniqueAssets[asset.id] = asset;
    }
    final sortedAssets = uniqueAssets.values.toList()
      ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));

    debugPrint(
        '[MediaGalleryService] Found ${sortedAssets.length} assets in time range');

    // 提取每个资源的 GPS 信息
    final mediaItems = <SessionMedia>[];
    for (final asset in sortedAssets) {
      final media = await _extractMediaWithGps(asset);
      if (media != null && media.hasValidLocation) {
        mediaItems.add(media);
      }
    }

    debugPrint(
        '[MediaGalleryService] ${mediaItems.length} assets have valid GPS');

    return mediaItems;
  }

  /// 从资源中提取 GPS 坐标
  Future<SessionMedia?> _extractMediaWithGps(AssetEntity asset) async {
    try {
      // 使用 photo_manager 内置的 GPS 获取方法
      final latLng = await asset.latlngAsync();

      // 检查 latLng 和 GPS 是否有效
      if (latLng == null) {
        return null;
      }
      final lat = latLng.latitude;
      final lng = latLng.longitude;
      if (lat == 0 && lng == 0) {
        return null;
      }

      return SessionMedia(
        id: asset.id,
        type: asset.type == AssetType.image ? MediaType.photo : MediaType.video,
        captureTime: asset.createDateTime,
        latitude: lat,
        longitude: lng,
        width: asset.width,
        height: asset.height,
        duration:
            asset.type == AssetType.video ? Duration(seconds: asset.duration) : null,
      );
    } catch (e) {
      debugPrint('[MediaGalleryService] Failed to extract GPS from ${asset.id}: $e');
      return null;
    }
  }

  /// 获取媒体缩略图
  Future<Uint8List?> getThumbnail(String assetId, {int size = 150}) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;

    return await asset.thumbnailDataWithSize(
      ThumbnailSize(size, size),
      quality: 85,
    );
  }

  /// 获取原始媒体文件
  Future<File?> getMediaFile(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return await asset.file;
  }

  /// 获取原始媒体文件（用于视频播放）
  Future<File?> getOriginFile(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return await asset.originFile;
  }
}
