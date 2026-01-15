import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_export_config.dart';

/// 视频导出服务
class VideoExportService extends ChangeNotifier {
  VideoExportState _state = VideoExportState.idle;
  String? _errorMessage;
  String? _outputPath;
  double _progress = 0;
  DateTime? _recordingStartTime;
  Duration? _estimatedDuration;

  /// 当前导出状态
  VideoExportState get state => _state;

  /// 错误消息
  String? get errorMessage => _errorMessage;

  /// 导出的视频路径
  String? get outputPath => _outputPath;

  /// 导出进度 (0.0 - 1.0)
  double get progress => _progress;

  /// 录制开始时间
  DateTime? get recordingStartTime => _recordingStartTime;

  /// 是否正在录制
  bool get isRecording => _state == VideoExportState.recording;

  /// 预估总时长
  Duration? get estimatedDuration => _estimatedDuration;

  /// 设置预估时长（用于计算进度）
  void setEstimatedDuration(Duration duration) {
    _estimatedDuration = duration;
  }

  /// 更新录制进度
  void updateProgress(double replayProgress) {
    if (_state == VideoExportState.recording) {
      _progress = replayProgress;
      notifyListeners();
    }
  }

  /// 开始录制
  Future<bool> startRecording() async {
    if (_state == VideoExportState.recording) {
      return false;
    }

    _state = VideoExportState.preparing;
    _errorMessage = null;
    _outputPath = null;
    _progress = 0;
    notifyListeners();

    try {
      // 检查并请求权限
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        _state = VideoExportState.failed;
        _errorMessage = '录屏权限被拒绝';
        notifyListeners();
        return false;
      }

      // 开始屏幕录制（带音频，用于录制视频播放声音）
      _state = VideoExportState.recording;
      _recordingStartTime = DateTime.now();
      notifyListeners();

      final started = await FlutterScreenRecording.startRecordScreenAndAudio(
        'snownavi_replay_${DateTime.now().millisecondsSinceEpoch}',
        titleNotification: 'SnowNavi',
        messageNotification: '正在录制轨迹回放...',
      );

      if (!started) {
        _state = VideoExportState.failed;
        _errorMessage = '无法启动屏幕录制';
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      _state = VideoExportState.failed;
      _errorMessage = '录制失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 停止录制
  Future<String?> stopRecording() async {
    if (_state != VideoExportState.recording) {
      return null;
    }

    _state = VideoExportState.processing;
    notifyListeners();

    try {
      final path = await FlutterScreenRecording.stopRecordScreen;

      if (path.isEmpty) {
        _state = VideoExportState.failed;
        _errorMessage = '录制失败，未生成视频文件';
        notifyListeners();
        return null;
      }

      _outputPath = path;
      _state = VideoExportState.completed;
      _progress = 1.0;
      notifyListeners();

      return path;
    } catch (e) {
      _state = VideoExportState.failed;
      _errorMessage = '停止录制失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 取消录制
  Future<void> cancelRecording() async {
    if (_state == VideoExportState.recording) {
      try {
        await FlutterScreenRecording.stopRecordScreen;
      } catch (e) {
        // 忽略取消时的错误
      }
    }

    _state = VideoExportState.cancelled;
    _outputPath = null;
    notifyListeners();
  }

  /// 保存到相册
  Future<bool> saveToGallery() async {
    if (_outputPath == null) {
      return false;
    }

    try {
      final file = File(_outputPath!);
      if (!await file.exists()) {
        _errorMessage = '视频文件不存在';
        notifyListeners();
        return false;
      }

      // 请求相册写入权限
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        _errorMessage = '相册权限被拒绝';
        notifyListeners();
        return false;
      }

      // 保存视频到相册
      await PhotoManager.editor.saveVideo(
        file,
        title: 'SnowNavi轨迹回放_${DateTime.now().millisecondsSinceEpoch}',
      );

      return true;
    } catch (e) {
      _errorMessage = '保存失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 分享视频
  Future<void> shareVideo() async {
    if (_outputPath == null) {
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(_outputPath!)],
        text: 'SnowNavi 轨迹回放',
      );
    } catch (e) {
      _errorMessage = '分享失败: $e';
      notifyListeners();
    }
  }

  /// 获取视频信息
  Future<Map<String, dynamic>?> getVideoInfo() async {
    if (_outputPath == null) {
      return null;
    }

    try {
      final file = File(_outputPath!);
      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final sizeInMB = stat.size / (1024 * 1024);

      return {
        'path': _outputPath,
        'size': sizeInMB,
        'sizeFormatted': '${sizeInMB.toStringAsFixed(1)} MB',
      };
    } catch (e) {
      return null;
    }
  }

  /// 清理临时文件
  Future<void> cleanup() async {
    if (_outputPath != null) {
      try {
        final file = File(_outputPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略清理错误
      }
    }
    reset();
  }

  /// 重置状态
  void reset() {
    _state = VideoExportState.idle;
    _errorMessage = null;
    _outputPath = null;
    _progress = 0;
    _recordingStartTime = null;
    _estimatedDuration = null;
    notifyListeners();
  }

  /// 检查权限
  Future<bool> _checkPermissions() async {
    // flutter_screen_recording 会在录制时自动请求权限
    // 这里可以提前检查相册权限
    final permission = await PhotoManager.requestPermissionExtend();
    return permission.isAuth;
  }

  /// 获取录制时长
  Duration get recordingDuration {
    if (_recordingStartTime == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_recordingStartTime!);
  }
}
