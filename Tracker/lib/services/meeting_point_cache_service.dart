import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../meeting_point/meeting_point_model.dart';

/// 集合点缓存服务 - 离线时也能查看集合点信息
class MeetingPointCacheService {
  static final MeetingPointCacheService _instance = MeetingPointCacheService._internal();
  static MeetingPointCacheService get instance => _instance;
  MeetingPointCacheService._internal();

  SharedPreferences? _prefs;

  static const String _meetingPointsKey = 'snownavi_cached_meeting_points';
  static const String _activePointKey = 'snownavi_cached_active_point';
  static const String _teamIdKey = 'snownavi_cached_team_id';
  static const String _lastUpdateKey = 'snownavi_meeting_points_last_update';

  /// 初始化服务
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 缓存集合点列表
  Future<void> cacheMeetingPoints({
    required String teamId,
    required List<MeetingPoint> points,
  }) async {
    await initialize();

    // 序列化集合点
    final pointsJson = points.map((p) => _serializeMeetingPoint(p)).toList();

    await _prefs?.setString(_meetingPointsKey, jsonEncode(pointsJson));
    await _prefs?.setString(_teamIdKey, teamId);
    await _prefs?.setString(_lastUpdateKey, DateTime.now().toIso8601String());

    // 同时缓存活动集合点
    final activePoint = points.where((p) => p.isActive).firstOrNull;
    if (activePoint != null) {
      await _prefs?.setString(_activePointKey, jsonEncode(_serializeMeetingPoint(activePoint)));
    } else {
      await _prefs?.remove(_activePointKey);
    }

    debugPrint('[MeetingPointCache] Cached ${points.length} points for team $teamId');
  }

  /// 获取缓存的集合点
  Future<List<MeetingPoint>> getCachedMeetingPoints() async {
    await initialize();

    final json = _prefs?.getString(_meetingPointsKey);
    if (json == null) return [];

    try {
      final List<dynamic> pointsJson = jsonDecode(json);
      return pointsJson.map((p) => MeetingPoint.fromJson(p)).toList();
    } catch (e) {
      debugPrint('[MeetingPointCache] Failed to parse cached points: $e');
      return [];
    }
  }

  /// 获取缓存的活动集合点
  Future<MeetingPoint?> getCachedActiveMeetingPoint() async {
    await initialize();

    final json = _prefs?.getString(_activePointKey);
    if (json == null) return null;

    try {
      return MeetingPoint.fromJson(jsonDecode(json));
    } catch (e) {
      debugPrint('[MeetingPointCache] Failed to parse active point: $e');
      return null;
    }
  }

  /// 获取缓存对应的团队ID
  Future<String?> getCachedTeamId() async {
    await initialize();
    return _prefs?.getString(_teamIdKey);
  }

  /// 获取上次更新时间
  Future<DateTime?> getLastUpdateTime() async {
    await initialize();
    final timeStr = _prefs?.getString(_lastUpdateKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await initialize();
    await _prefs?.remove(_meetingPointsKey);
    await _prefs?.remove(_activePointKey);
    await _prefs?.remove(_teamIdKey);
    await _prefs?.remove(_lastUpdateKey);
    debugPrint('[MeetingPointCache] Cache cleared');
  }

  /// 序列化集合点
  Map<String, dynamic> _serializeMeetingPoint(MeetingPoint point) {
    return {
      'id': point.id,
      'teamId': point.teamId,
      'name': point.name,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'createdBy': point.createdBy,
      'creatorNickname': point.creatorNickname,
      'createdAt': point.createdAt.toIso8601String(),
      'isActive': point.isActive,
    };
  }

  /// 检查缓存是否有效（1小时内）
  Future<bool> isCacheValid() async {
    final lastUpdate = await getLastUpdateTime();
    if (lastUpdate == null) return false;
    return DateTime.now().difference(lastUpdate).inHours < 1;
  }
}

