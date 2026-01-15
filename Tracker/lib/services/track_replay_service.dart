import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/location_point.dart';
import '../models/replay_point.dart';
import '../models/replay_state.dart';

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

  // Getters
  List<ReplayPoint> get processedPoints => _processedPoints;
  double get totalDistance => _totalDistance;
  ReplayPlaybackState get playbackState => _playbackState;
  double get currentProgress => _currentProgress;
  ReplayConfig get config => _config;

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

      // 计算到前瞻点的方向
      final lookAhead = math.min(i + _config.lookAheadPoints, points.length - 1);
      final bearing = ReplayPoint.calculateBearing(
        points[i].latitude,
        points[i].longitude,
        points[lookAhead].latitude,
        points[lookAhead].longitude,
      );

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

  /// 开始或恢复播放
  void play() {
    if (_processedPoints.isEmpty) return;

    if (_playbackState == ReplayPlaybackState.finished) {
      _currentProgress = 0;
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
