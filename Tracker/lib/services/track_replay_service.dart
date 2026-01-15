import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/location_point.dart';
import '../models/replay_point.dart';
import '../models/replay_state.dart';
import '../models/session_media.dart';

/// 轨迹回放服务
/// 负责轨迹预处理、回放状态管理和进度控制
class TrackReplayService extends ChangeNotifier {
  // 处理后的轨迹数据
  List<ReplayPoint> _processedPoints = [];
  double _totalDistance = 0;

  // 回放状态
  ReplayPlaybackState _playbackState = ReplayPlaybackState.idle;
  double _currentProgress = 0.0; // 0.0 到 1.0
  ReplayConfig _config = const ReplayConfig();

  // 动画定时器
  Timer? _animationTimer;
  DateTime? _playStartTime;
  double _playStartProgress = 0;

  // 媒体回放相关
  List<MediaReplayInfo> _mediaReplayList = []; // 按轨迹顺序排列的媒体
  int _currentMediaIndex = 0; // 当前处理到的媒体索引
  SessionMedia? _currentShowingMedia; // 当前正在展示的媒体
  bool _isShowingMedia = false; // 是否正在展示媒体

  // Getters
  List<ReplayPoint> get processedPoints => _processedPoints;
  double get totalDistance => _totalDistance;
  ReplayPlaybackState get playbackState => _playbackState;
  double get currentProgress => _currentProgress;
  ReplayConfig get config => _config;
  SessionMedia? get currentShowingMedia => _currentShowingMedia;
  bool get isShowingMedia => _isShowingMedia;

  /// 加载保存的配置
  Future<void> loadSavedConfig() async {
    _config = await ReplayConfig.load();
    notifyListeners();
  }

  /// 当前位置（基于进度）
  ReplayPoint? get currentPoint {
    if (_processedPoints.isEmpty) return null;
    return _getPointAtProgress(_currentProgress);
  }

  /// 当前可见轨迹坐标（用于渐进式绘制）
  List<Position> get visibleTrackCoordinates {
    if (_processedPoints.isEmpty) return [];
    final targetDistance = _totalDistance * _currentProgress;

    final coords = <Position>[];
    for (final point in _processedPoints) {
      coords.add(Position(point.longitude, point.latitude));
      if (point.cumulativeDistance >= targetDistance) break;
    }
    return coords;
  }

  /// 处理原始轨迹点为回放点
  ///
  /// 处理步骤：
  /// 1. 去除重复点（距离小于 minDistance）
  /// 2. 去除异常跳点（瞬时位移大于 maxJumpDistance）
  /// 3. 移动平均平滑
  /// 4. 计算累计距离
  /// 5. 计算前瞻方向
  Future<void> processTrack(
    List<LocationPoint> rawPoints, {
    double minDistance = 2.0, // 最小点间距（米）
    double maxJumpDistance = 100.0, // 最大允许跳跃（米）
    int smoothingWindow = 3, // 平滑窗口大小
  }) async {
    if (rawPoints.length < 2) {
      _processedPoints = [];
      _totalDistance = 0;
      notifyListeners();
      return;
    }

    // 步骤 1: 去除重复点
    final deduped = _removeDuplicates(rawPoints, minDistance);
    debugPrint('[TrackReplayService] After dedup: ${deduped.length} points');

    // 步骤 2: 去除异常跳点
    final cleaned = _removeOutliers(deduped, maxJumpDistance);
    debugPrint(
        '[TrackReplayService] After outlier removal: ${cleaned.length} points');

    // 步骤 3: 移动平均平滑
    final smoothed = _applySmoothing(cleaned, smoothingWindow);
    debugPrint('[TrackReplayService] After smoothing: ${smoothed.length} points');

    // 步骤 4 & 5: 计算累计距离和方向
    _processedPoints = _calculateDistancesAndBearings(smoothed);
    _totalDistance = _processedPoints.isNotEmpty
        ? _processedPoints.last.cumulativeDistance
        : 0;

    debugPrint(
        '[TrackReplayService] Total distance: ${_totalDistance.toStringAsFixed(0)}m');
    notifyListeners();
  }

  /// 去除距离过近的重复点
  List<LocationPoint> _removeDuplicates(
      List<LocationPoint> points, double minDist) {
    if (points.isEmpty) return [];

    final result = <LocationPoint>[points.first];
    for (int i = 1; i < points.length; i++) {
      final last = result.last;
      final current = points[i];
      final dist = ReplayPoint.haversineDistance(
        last.latitude,
        last.longitude,
        current.latitude,
        current.longitude,
      );
      if (dist >= minDist) {
        result.add(current);
      }
    }
    return result;
  }

  /// 去除异常跳点
  List<LocationPoint> _removeOutliers(
      List<LocationPoint> points, double maxJump) {
    if (points.length < 3) return points;

    final result = <LocationPoint>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      final prev = result.last;
      final current = points[i];
      final next = points[i + 1];

      final distToCurrent = ReplayPoint.haversineDistance(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
      final distToNext = ReplayPoint.haversineDistance(
        current.latitude,
        current.longitude,
        next.latitude,
        next.longitude,
      );

      // 如果当前点导致往返跳跃，可能是异常点
      if (distToCurrent < maxJump || distToNext < maxJump) {
        result.add(current);
      }
    }
    result.add(points.last);
    return result;
  }

  /// 移动平均平滑以减少 GPS 抖动
  List<LocationPoint> _applySmoothing(List<LocationPoint> points, int window) {
    if (points.length < window) return points;

    final result = <LocationPoint>[];
    final halfWindow = window ~/ 2;

    for (int i = 0; i < points.length; i++) {
      final start = math.max(0, i - halfWindow);
      final end = math.min(points.length, i + halfWindow + 1);

      double sumLat = 0, sumLng = 0, sumAlt = 0;
      for (int j = start; j < end; j++) {
        sumLat += points[j].latitude;
        sumLng += points[j].longitude;
        sumAlt += points[j].altitude;
      }
      final count = end - start;

      // 创建平滑后的点（保留原始元数据）
      result.add(LocationPoint(
        id: points[i].id,
        sessionId: points[i].sessionId,
        timestamp: points[i].timestamp,
        latitude: sumLat / count,
        longitude: sumLng / count,
        altitude: sumAlt / count,
        horizontalAccuracy: points[i].horizontalAccuracy,
        verticalAccuracy: points[i].verticalAccuracy,
        speed: points[i].speed,
        heading: points[i].heading,
        isMoving: points[i].isMoving,
        isAutoPaused: points[i].isAutoPaused,
      ));
    }
    return result;
  }

  /// 计算累计距离和前瞻方向
  /// 使用加权平均的多点前瞻来获得平滑的方向
  List<ReplayPoint> _calculateDistancesAndBearings(List<LocationPoint> points) {
    if (points.isEmpty) return [];

    final result = <ReplayPoint>[];
    double cumDist = 0;

    for (int i = 0; i < points.length; i++) {
      // 计算与前一点的距离
      if (i > 0) {
        cumDist += ReplayPoint.haversineDistance(
          points[i - 1].latitude,
          points[i - 1].longitude,
          points[i].latitude,
          points[i].longitude,
        );
      }

      // 使用加权平均的多点前瞻计算方向
      final bearing = _calculateWeightedBearing(points, i);

      result.add(ReplayPoint(
        latitude: points[i].latitude,
        longitude: points[i].longitude,
        altitude: points[i].altitude,
        cumulativeDistance: cumDist,
        bearing: bearing,
        originalTimestamp: points[i].timestamp,
      ));
    }

    return result;
  }

  /// 使用加权平均计算前瞻方向
  /// 距离较远的点权重更大，以获得更稳定的方向
  double _calculateWeightedBearing(List<LocationPoint> points, int currentIndex) {
    final lookAheadCount = _config.lookAheadPoints;
    final maxLookAhead = math.min(currentIndex + lookAheadCount, points.length - 1);

    if (currentIndex >= maxLookAhead) {
      // 最后几个点，使用上一个点的方向
      return currentIndex > 0
          ? ReplayPoint.calculateBearing(
              points[currentIndex - 1].latitude,
              points[currentIndex - 1].longitude,
              points[currentIndex].latitude,
              points[currentIndex].longitude,
            )
          : 0;
    }

    // 计算多个前瞻点的加权平均方向
    double sinSum = 0;
    double cosSum = 0;
    double totalWeight = 0;

    for (int j = currentIndex + 1; j <= maxLookAhead; j++) {
      final distance = ReplayPoint.haversineDistance(
        points[currentIndex].latitude,
        points[currentIndex].longitude,
        points[j].latitude,
        points[j].longitude,
      );

      // 距离越远权重越大（因为方向更稳定）
      // 但距离太近的点权重也不能太低
      final weight = math.max(distance, 5.0);

      final bearing = ReplayPoint.calculateBearing(
        points[currentIndex].latitude,
        points[currentIndex].longitude,
        points[j].latitude,
        points[j].longitude,
      );

      // 使用向量法计算平均角度
      final radians = bearing * math.pi / 180;
      sinSum += math.sin(radians) * weight;
      cosSum += math.cos(radians) * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return 0;

    // 从向量和计算平均角度
    final avgRadians = math.atan2(sinSum / totalWeight, cosSum / totalWeight);
    return (avgRadians * 180 / math.pi + 360) % 360;
  }

  /// 开始或恢复播放
  void play() {
    if (_processedPoints.isEmpty) return;

    if (_playbackState == ReplayPlaybackState.finished ||
        _playbackState == ReplayPlaybackState.idle) {
      _currentProgress = 0;
      _resetMediaState(); // 重置媒体状态
    }

    _playbackState = ReplayPlaybackState.playing;
    _playStartTime = DateTime.now();
    _playStartProgress = _currentProgress;

    // 启动动画定时器
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(
      Duration(milliseconds: _config.cameraUpdateIntervalMs),
      _onAnimationTick,
    );

    notifyListeners();
  }

  /// 暂停播放
  void pause() {
    _animationTimer?.cancel();
    _playbackState = ReplayPlaybackState.paused;
    notifyListeners();
  }

  /// 停止并重置
  void stop() {
    _animationTimer?.cancel();
    _playbackState = ReplayPlaybackState.idle;
    _currentProgress = 0;
    _resetMediaState();
    notifyListeners();
  }

  /// 跳转到指定进度（0.0 - 1.0）
  void seekTo(double progress) {
    _currentProgress = progress.clamp(0.0, 1.0);
    if (_playbackState == ReplayPlaybackState.playing) {
      _playStartTime = DateTime.now();
      _playStartProgress = _currentProgress;
    }
    notifyListeners();
  }

  /// 更新配置
  void setConfig(ReplayConfig config) {
    _config = config;
    notifyListeners();
  }

  /// 设置回放时要展示的媒体
  /// 根据媒体的GPS位置，计算它们在轨迹上的进度位置
  void setMediaForReplay(List<SessionMedia> mediaItems) {
    if (_processedPoints.isEmpty || mediaItems.isEmpty) {
      _mediaReplayList = [];
      return;
    }

    final mediaList = <MediaReplayInfo>[];

    for (final media in mediaItems) {
      // 找到轨迹上距离媒体最近的点
      double minDistance = double.infinity;
      double progressAtClosest = 0;

      for (int i = 0; i < _processedPoints.length; i++) {
        final point = _processedPoints[i];
        final distance = ReplayPoint.haversineDistance(
          media.latitude,
          media.longitude,
          point.latitude,
          point.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          progressAtClosest = point.cumulativeDistance / _totalDistance;
        }
      }

      // 只添加距离轨迹较近的媒体（100米内）
      if (minDistance <= 100) {
        mediaList.add(MediaReplayInfo(
          media: media,
          progress: progressAtClosest,
          distanceToTrack: minDistance,
        ));
      }
    }

    // 按进度排序
    mediaList.sort((a, b) => a.progress.compareTo(b.progress));
    _mediaReplayList = mediaList;
    _currentMediaIndex = 0;

    debugPrint(
        '[TrackReplayService] Set ${_mediaReplayList.length} media for replay');
  }

  /// 检查是否到达媒体位置，返回需要展示的媒体
  SessionMedia? checkMediaAtProgress(double progress) {
    if (!_config.showMediaDuringReplay || _mediaReplayList.isEmpty) {
      return null;
    }

    // 找到下一个需要展示的媒体
    while (_currentMediaIndex < _mediaReplayList.length) {
      final mediaInfo = _mediaReplayList[_currentMediaIndex];

      // 如果已经过了这个媒体，跳过
      if (progress > mediaInfo.progress + 0.01) {
        _currentMediaIndex++;
        continue;
      }

      // 如果到达媒体位置（±1%进度内）
      if ((progress - mediaInfo.progress).abs() <= 0.01) {
        return mediaInfo.media;
      }

      break;
    }

    return null;
  }

  /// 开始展示媒体（暂停回放）
  void startShowingMedia(SessionMedia media) {
    _currentShowingMedia = media;
    _isShowingMedia = true;
    _animationTimer?.cancel();
    _playbackState = ReplayPlaybackState.showingMedia;
    notifyListeners();
  }

  /// 结束媒体展示，继续回放
  void finishShowingMedia() {
    _currentShowingMedia = null;
    _isShowingMedia = false;
    _currentMediaIndex++; // 移动到下一个媒体

    // 恢复播放
    if (_currentProgress < 1.0) {
      _playbackState = ReplayPlaybackState.playing;
      _playStartTime = DateTime.now();
      _playStartProgress = _currentProgress;

      _animationTimer?.cancel();
      _animationTimer = Timer.periodic(
        Duration(milliseconds: _config.cameraUpdateIntervalMs),
        _onAnimationTick,
      );
    } else {
      _playbackState = ReplayPlaybackState.finished;
    }

    notifyListeners();
  }

  /// 重置媒体播放状态
  void _resetMediaState() {
    _currentMediaIndex = 0;
    _currentShowingMedia = null;
    _isShowingMedia = false;
  }

  void _onAnimationTick(Timer timer) {
    if (_playbackState != ReplayPlaybackState.playing) return;

    final elapsed = DateTime.now().difference(_playStartTime!);
    final totalMs = _config.totalDuration.inMilliseconds;
    final progressDelta = elapsed.inMilliseconds / totalMs;

    _currentProgress = (_playStartProgress + progressDelta).clamp(0.0, 1.0);

    if (_currentProgress >= 1.0) {
      _animationTimer?.cancel();
      _playbackState = ReplayPlaybackState.finished;
    }

    notifyListeners();
  }

  /// 获取指定进度处的插值点
  ReplayPoint _getPointAtProgress(double progress) {
    final targetDistance = _totalDistance * progress;

    // 二分查找最近的点
    int low = 0, high = _processedPoints.length - 1;
    while (low < high - 1) {
      final mid = (low + high) ~/ 2;
      if (_processedPoints[mid].cumulativeDistance <= targetDistance) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final pointA = _processedPoints[low];
    final pointB = _processedPoints[high];

    if (pointA.cumulativeDistance == pointB.cumulativeDistance) {
      return pointA;
    }

    final segmentProgress = (targetDistance - pointA.cumulativeDistance) /
        (pointB.cumulativeDistance - pointA.cumulativeDistance);

    return ReplayPoint.lerp(pointA, pointB, segmentProgress.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }
}

/// 媒体回放信息
class MediaReplayInfo {
  final SessionMedia media;
  final double progress; // 在轨迹上的进度 (0.0 - 1.0)
  final double distanceToTrack; // 到轨迹的距离（米）

  const MediaReplayInfo({
    required this.media,
    required this.progress,
    required this.distanceToTrack,
  });
}
