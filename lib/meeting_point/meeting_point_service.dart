import 'meeting_point_model.dart';
import 'meeting_point_api_service.dart';

/// 集合点更新回调
typedef OnMeetingPointsUpdated = void Function(List<MeetingPoint> points);
typedef OnActiveMeetingPointChanged = void Function(MeetingPoint? activePoint);

/// 集合点服务 - 管理集合点的业务逻辑
class MeetingPointService {
  static final MeetingPointService _instance = MeetingPointService._internal();
  factory MeetingPointService() => _instance;
  MeetingPointService._internal();

  static MeetingPointService get instance => _instance;

  final MeetingPointApiService _api = MeetingPointApiService.instance;

  List<MeetingPoint> _meetingPoints = [];
  String? _currentTeamId;
  String? _deviceId;
  String? _nickname;

  /// 回调函数
  OnMeetingPointsUpdated? onMeetingPointsUpdated;
  OnActiveMeetingPointChanged? onActiveMeetingPointChanged;

  /// 获取所有集合点
  List<MeetingPoint> get meetingPoints => List.unmodifiable(_meetingPoints);

  /// 获取当前有效的集合点
  MeetingPoint? get activeMeetingPoint {
    try {
      return _meetingPoints.firstWhere((p) => p.isActive);
    } catch (e) {
      return null;
    }
  }

  /// 是否有团队
  bool get hasTeam => _currentTeamId != null && _currentTeamId!.isNotEmpty;

  /// 当前团队ID
  String? get currentTeamId => _currentTeamId;

  /// 设置当前团队和用户信息
  void setContext({
    required String teamId,
    required String deviceId,
    required String nickname,
  }) {
    _currentTeamId = teamId;
    _deviceId = deviceId;
    _nickname = nickname;
    print(
        '[MeetingPointService] Context set: teamId=$teamId, deviceId=$deviceId');
  }

  /// 清除上下文
  void clearContext() {
    _currentTeamId = null;
    _deviceId = null;
    _nickname = null;
    _meetingPoints = [];
    print('[MeetingPointService] Context cleared');
  }

  /// 加载集合点列表
  Future<List<MeetingPoint>> loadMeetingPoints() async {
    if (_currentTeamId == null) {
      print('[MeetingPointService] No team ID set');
      return [];
    }

    final result = await _api.getMeetingPoints(_currentTeamId!);
    if (result.success && result.data != null) {
      _meetingPoints = result.data!;
      print(
          '[MeetingPointService] Loaded ${_meetingPoints.length} meeting points');
      onMeetingPointsUpdated?.call(_meetingPoints);

      // 检查是否有活动集合点
      final active = activeMeetingPoint;
      if (active != null) {
        onActiveMeetingPointChanged?.call(active);
      }

      return _meetingPoints;
    } else {
      print('[MeetingPointService] Failed to load: ${result.error}');
      return [];
    }
  }

  /// 添加集合点
  Future<MeetingPoint?> addMeetingPoint({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    if (_currentTeamId == null || _deviceId == null || _nickname == null) {
      print('[MeetingPointService] No context set');
      return null;
    }

    final result = await _api.addMeetingPoint(
      teamId: _currentTeamId!,
      name: name,
      latitude: latitude,
      longitude: longitude,
      deviceId: _deviceId!,
      nickname: _nickname!,
    );

    if (result.success && result.data != null) {
      _meetingPoints.add(result.data!);
      print('[MeetingPointService] Added meeting point: ${result.data}');
      onMeetingPointsUpdated?.call(_meetingPoints);
      return result.data;
    } else {
      print('[MeetingPointService] Failed to add: ${result.error}');
      return null;
    }
  }

  /// 更新集合点名称
  Future<bool> updateMeetingPointName(String pointId, String newName) async {
    if (_currentTeamId == null) return false;

    final result = await _api.updateMeetingPoint(
      teamId: _currentTeamId!,
      pointId: pointId,
      name: newName,
    );

    if (result.success && result.data != null) {
      final index = _meetingPoints.indexWhere((p) => p.id == pointId);
      if (index >= 0) {
        _meetingPoints[index] = result.data!;
      }
      print('[MeetingPointService] Updated name to: $newName');
      onMeetingPointsUpdated?.call(_meetingPoints);
      return true;
    }
    return false;
  }

  /// 删除集合点
  Future<bool> deleteMeetingPoint(String pointId) async {
    if (_currentTeamId == null) return false;

    final result = await _api.deleteMeetingPoint(
      teamId: _currentTeamId!,
      pointId: pointId,
    );

    if (result.success) {
      final wasActive =
          _meetingPoints.any((p) => p.id == pointId && p.isActive);
      _meetingPoints.removeWhere((p) => p.id == pointId);
      print('[MeetingPointService] Deleted meeting point: $pointId');
      onMeetingPointsUpdated?.call(_meetingPoints);

      // 如果删除的是活动集合点，通知更新
      if (wasActive) {
        onActiveMeetingPointChanged?.call(null);
      }
      return true;
    }
    return false;
  }

  /// 设置当前有效集合点
  Future<bool> setActiveMeetingPoint(String pointId) async {
    if (_currentTeamId == null) return false;

    final result = await _api.setActiveMeetingPoint(
      teamId: _currentTeamId!,
      pointId: pointId,
    );

    if (result.success) {
      // 更新本地状态
      for (var point in _meetingPoints) {
        point.isActive = (point.id == pointId);
      }
      print('[MeetingPointService] Set active meeting point: $pointId');
      onMeetingPointsUpdated?.call(_meetingPoints);
      onActiveMeetingPointChanged?.call(activeMeetingPoint);
      return true;
    }
    return false;
  }

  /// 取消当前有效集合点
  Future<bool> clearActiveMeetingPoint() async {
    if (_currentTeamId == null) return false;

    final result = await _api.clearActiveMeetingPoint(_currentTeamId!);

    if (result.success) {
      // 更新本地状态
      for (var point in _meetingPoints) {
        point.isActive = false;
      }
      print('[MeetingPointService] Cleared active meeting point');
      onMeetingPointsUpdated?.call(_meetingPoints);
      onActiveMeetingPointChanged?.call(null);
      return true;
    }
    return false;
  }
}
