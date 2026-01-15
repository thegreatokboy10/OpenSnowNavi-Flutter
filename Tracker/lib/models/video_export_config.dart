import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 视频质量
enum VideoQuality {
  standard, // 720p
  high, // 1080p
}

/// 媒体导出模式
enum MediaExportMode {
  fullPlayback, // 完整播放
  fixedDuration, // 固定时长后跳过
  skipMedia, // 跳过所有媒体
}

/// 视频导出状态
enum VideoExportState {
  idle, // 空闲
  preparing, // 准备中（检查权限）
  recording, // 录制中
  processing, // 处理中
  completed, // 完成
  failed, // 失败
  cancelled, // 已取消
}

/// 视频导出配置
class VideoExportConfig {
  /// 视频质量
  final VideoQuality quality;

  /// 媒体导出模式
  final MediaExportMode mediaMode;

  /// 视频片段最大时长（秒），仅在 fixedDuration 模式下使用
  final int maxVideoClipDuration;

  const VideoExportConfig({
    this.quality = VideoQuality.high,
    this.mediaMode = MediaExportMode.fixedDuration,
    this.maxVideoClipDuration = 5,
  });

  static const _prefsKey = 'video_export_config';

  /// 复制并修改配置
  VideoExportConfig copyWith({
    VideoQuality? quality,
    MediaExportMode? mediaMode,
    int? maxVideoClipDuration,
  }) {
    return VideoExportConfig(
      quality: quality ?? this.quality,
      mediaMode: mediaMode ?? this.mediaMode,
      maxVideoClipDuration: maxVideoClipDuration ?? this.maxVideoClipDuration,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'quality': quality.index,
      'mediaMode': mediaMode.index,
      'maxVideoClipDuration': maxVideoClipDuration,
    };
  }

  /// 从 JSON Map 创建
  factory VideoExportConfig.fromJson(Map<String, dynamic> json) {
    return VideoExportConfig(
      quality: VideoQuality.values[json['quality'] ?? 1],
      mediaMode: MediaExportMode.values[json['mediaMode'] ?? 1],
      maxVideoClipDuration: json['maxVideoClipDuration'] ?? 5,
    );
  }

  /// 保存到 SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  /// 从 SharedPreferences 加载
  static Future<VideoExportConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        return VideoExportConfig.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      // 加载失败时使用默认配置
    }
    return const VideoExportConfig();
  }

  /// 获取质量显示名称
  String get qualityDisplayName {
    switch (quality) {
      case VideoQuality.standard:
        return '标准 (720p)';
      case VideoQuality.high:
        return '高清 (1080p)';
    }
  }

  /// 获取媒体模式显示名称
  String get mediaModeDisplayName {
    switch (mediaMode) {
      case MediaExportMode.fullPlayback:
        return '完整播放';
      case MediaExportMode.fixedDuration:
        return '固定时长后跳过';
      case MediaExportMode.skipMedia:
        return '不包含视频';
    }
  }
}
