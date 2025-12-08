// 团队管理服务 - 整合设备识别和存储
import 'dart:async';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../location_service.dart';
import 'device_service.dart';
import 'team_api_service.dart';
import 'team_models.dart';
import 'team_storage_service.dart';

class TeamService {
  static TeamService? _instance;

  final DeviceService _deviceService = DeviceService.instance;
  final TeamStorageService _storageService = TeamStorageService.instance;
  final LocationService _locationService = LocationService();

  Team? _currentTeam;
  Timer? _locationUpdateTimer;
  Timer? _teamRefreshTimer;
  bool _isRefreshing = false;

  // 位置更新回调
  Function(List<TeamMember> members)? onMembersLocationUpdate;
  // 团队数据变化回调
  Function(Team? team)? onTeamUpdated;

  TeamService._();

  static TeamService get instance {
    _instance ??= TeamService._();
    return _instance!;
  }

  /// 获取当前设备ID
  String get deviceId => _deviceService.getDeviceId();

  /// 获取当前团队
  Team? get currentTeam => _currentTeam;

  /// 获取当前成员
  TeamMember? get currentMember {
    if (_currentTeam == null) return null;
    return _currentTeam!.members.cast<TeamMember?>().firstWhere(
          (m) => m?.deviceId == deviceId,
          orElse: () => null,
        );
  }

  /// 是否是队长
  bool get isLeader => currentMember?.isLeader ?? false;

  /// 检查用户权限
  Future<PermissionResult> checkPermission(String email) async {
    final result = await TeamApiService.instance.checkPermission(email);
    if (result.success && result.data != null) {
      return result.data!;
    }
    // 返回无权限结果
    return PermissionResult(
      permissionLevel: 'none',
      canAccess: false,
      userRole: null,
    );
  }

  /// 初始化 - 尝试恢复之前的团队
  Future<void> initialize() async {
    // 如果已有团队数据，不需要重新初始化
    if (_currentTeam != null) {
      print(
          '[TeamService] initialize: already have team ${_currentTeam!.id}, skipping');
      return;
    }

    // 优先使用本地保存的团队 ID
    final savedTeamId = _deviceService.getCurrentTeamId();
    print('[TeamService] initialize: savedTeamId = $savedTeamId');

    if (savedTeamId != null) {
      // 尝试从本地保存的团队 ID 恢复
      final fetchedTeam = await _storageService.getTeam(savedTeamId);
      print('[TeamService] initialize: fetched team = ${fetchedTeam?.id}');
      if (fetchedTeam != null) {
        await _restoreTeam(fetchedTeam);
        return;
      } else {
        print(
            '[TeamService] initialize: saved team not found, clearing saved team ID');
        _deviceService.saveCurrentTeamId(null);
      }
    }

    // 如果本地没有保存的团队 ID，或者保存的团队已失效，尝试通过 deviceId 查询
    print('[TeamService] initialize: trying to find team by deviceId');
    final result = await _storageService.getTeamByDeviceId(deviceId);
    if (result != null && result.found && result.firstTeam != null) {
      print(
          '[TeamService] initialize: found team ${result.firstTeam!.id} by deviceId');
      await _restoreTeam(result.firstTeam!);
    } else {
      print('[TeamService] initialize: no team found for deviceId');
    }
  }

  /// 恢复团队状态（设置当前团队、检查签到、启动刷新定时器）
  Future<void> _restoreTeam(Team team) async {
    _currentTeam = team;
    _deviceService.saveCurrentTeamId(team.id);

    // 检查是否需要今日签到
    final member = currentMember;
    if (member != null && !member.hasCheckedInToday) {
      print('[TeamService] _restoreTeam: need to check in today');
      await _storageService.checkIn(
        teamId: team.id,
        deviceId: deviceId,
        nickname: member.nickname,
      );
      final refreshedTeam = await _storageService.getTeam(team.id);
      if (refreshedTeam != null) {
        _currentTeam = refreshedTeam;
      }
    }

    _startRefreshTimer();
    print('[TeamService] _restoreTeam: team ${team.id} restored successfully');
  }

  /// 创建团队
  Future<TeamResult> createTeam({
    required String name,
    required String resortKey,
    String? nickname,
    int maxMembers = 6,
  }) async {
    final memberNickname = nickname ?? _deviceService.getDefaultNickname();
    _deviceService.saveNickname(memberNickname);

    final result = await _storageService.createTeam(
      name: name,
      resortKey: resortKey,
      leaderDeviceId: deviceId,
      leaderNickname: memberNickname,
      maxMembers: maxMembers,
    );

    if (result.success && result.team != null) {
      _currentTeam = result.team;
      _deviceService.saveCurrentTeamId(_currentTeam!.id);
      _startRefreshTimer();
      onTeamUpdated?.call(_currentTeam);
    }

    return result;
  }

  /// 加入团队
  Future<JoinResult> joinTeam(String teamId, {String? nickname}) async {
    final memberNickname = nickname ?? _deviceService.getDefaultNickname();
    _deviceService.saveNickname(memberNickname);

    final result = await _storageService.joinTeam(
      teamId: teamId,
      deviceId: deviceId,
      nickname: memberNickname,
    );

    if (result.success && result.team != null) {
      _currentTeam = result.team;
      _deviceService.saveCurrentTeamId(teamId);
      _startRefreshTimer();
      onTeamUpdated?.call(_currentTeam);
    }

    return result;
  }

  /// 离开团队（队长离开时会删除整个团队）
  Future<bool> leaveTeam() async {
    if (_currentTeam == null) return false;

    bool success;
    success = await _storageService.leaveTeam(_currentTeam!.id, deviceId);

    if (success) {
      _stopTimers();
      _currentTeam = null;
      _deviceService.saveCurrentTeamId(null);
      onTeamUpdated?.call(null);
    }
    return success;
  }

  /// 删除成员（仅队长）
  Future<bool> removeMember(String memberDeviceId) async {
    if (_currentTeam == null) return false;

    final success = await _storageService.removeMember(
      teamId: _currentTeam!.id,
      memberDeviceId: memberDeviceId,
    );

    if (success) {
      await _refreshTeam();
    }
    return success;
  }

  /// 设置位置共享
  Future<bool> setLocationSharing(bool share) async {
    if (_currentTeam == null) {
      print('[TeamService] setLocationSharing: currentTeam is null');
      return false;
    }

    print(
        '[TeamService] setLocationSharing: $share for team ${_currentTeam!.id}');
    final updatedTeam = await _storageService.setLocationSharing(
      teamId: _currentTeam!.id,
      deviceId: deviceId,
      shareLocation: share,
    );

    print('[TeamService] setLocationSharing result: ${updatedTeam?.id}');
    if (updatedTeam != null) {
      _currentTeam = updatedTeam;

      // 通知团队更新
      onTeamUpdated?.call(_currentTeam);

      if (share) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
      return true;
    }
    return false;
  }

  /// 获取分享链接
  String getShareLink() {
    if (_currentTeam == null) return '';
    return '${Uri.base.origin}/?team=${_currentTeam!.id}';
  }

  /// 刷新团队数据
  Future<void> _refreshTeam() async {
    if (_currentTeam == null || _isRefreshing) return;
    _isRefreshing = true;

    final teamId = _currentTeam!.id;
    print('[TeamService] _refreshTeam: fetching team $teamId');

    try {
      final fetchedTeam = await _storageService.getTeam(teamId);
      print(
          '[TeamService] _refreshTeam: got team ${fetchedTeam?.id}, members: ${fetchedTeam?.members.length}');

      // 只有成功获取到团队数据才更新，避免 API 临时失败导致状态丢失
      if (fetchedTeam != null) {
        _currentTeam = fetchedTeam;

        // 通知团队更新
        onTeamUpdated?.call(_currentTeam);

        // 通知位置更新
        if (onMembersLocationUpdate != null) {
          final membersWithLocation = _currentTeam!.members
              .where((m) => m.shareLocation && m.lastLocation != null)
              .toList();
          print(
              '[TeamService] _refreshTeam: members with location: ${membersWithLocation.length}');
          for (final m in membersWithLocation) {
            print(
                '[TeamService]   - ${m.nickname}: ${m.lastLocation?.lat}, ${m.lastLocation?.lng}');
          }
          onMembersLocationUpdate!(membersWithLocation);
        }
      } else {
        print(
            '[TeamService] _refreshTeam: API returned null, keeping current team state');
      }
    } catch (e) {
      print('[TeamService] _refreshTeam error: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// 开始定时刷新团队数据
  void _startRefreshTimer() {
    _teamRefreshTimer?.cancel();
    _teamRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshTeam(),
    );
  }

  /// 手动刷新团队数据（供外部调用）
  Future<void> refreshTeam() async {
    await _refreshTeam();
  }

  /// 开始位置更新
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _updateLocation(); // 立即更新一次
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _updateLocation(),
    );
  }

  /// 停止位置更新
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  /// 更新当前位置
  Future<void> _updateLocation() async {
    if (_currentTeam == null) return;

    try {
      final location = await _locationService.getCurrentLocation();
      await _storageService.updateMemberLocation(
        teamId: _currentTeam!.id,
        deviceId: deviceId,
        latitude: location['latitude'] as double,
        longitude: location['longitude'] as double,
        accuracy: location['accuracy'] as double?,
      );
      await _refreshTeam();
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  /// 停止所有定时器
  void _stopTimers() {
    _teamRefreshTimer?.cancel();
    _teamRefreshTimer = null;
    _stopLocationUpdates();
  }

  /// 销毁服务
  void dispose() {
    _stopTimers();
  }

  /// 获取成员位置列表（用于地图显示）
  /// [includeMyself] 是否包含自己的位置，默认 true
  List<MemberLocation> getMemberLocations({bool includeMyself = true}) {
    if (_currentTeam == null) {
      print('[TeamService] getMemberLocations: no current team');
      return [];
    }

    // 获取所有成员用于计算颜色索引
    final allMembers = _currentTeam!.members;
    print(
        '[TeamService] getMemberLocations: ${allMembers.length} total members, deviceId=$deviceId, includeMyself=$includeMyself');
    for (final m in allMembers) {
      print(
          '[TeamService]   - ${m.nickname}: shareLocation=${m.shareLocation}, hasLocation=${m.lastLocation != null}, deviceId=${m.deviceId}, isMe=${m.deviceId == deviceId}');
    }

    final result = allMembers.where((m) {
      // 必须开启位置共享且有位置数据
      if (!m.shareLocation || m.lastLocation == null) return false;
      // 如果不包含自己，过滤掉自己
      if (!includeMyself && m.deviceId == deviceId) return false;
      return true;
    }).map((m) {
      // 计算颜色索引（基于成员在列表中的位置）
      final colorIndex = allMembers.indexOf(m);
      final isMe = m.deviceId == deviceId;
      return MemberLocation(
        deviceId: m.deviceId,
        nickname: isMe ? '${m.nickname} (我)' : m.nickname,
        location: m.lastLocation!.latLng,
        lastUpdate: m.lastLocationUpdate,
        colorIndex: colorIndex,
        isLeader: m.isLeader,
        isMe: isMe,
      );
    }).toList();

    print(
        '[TeamService] getMemberLocations: returning ${result.length} locations');
    return result;
  }

  /// 根据设备ID获取成员信息
  MemberLocation? getMemberLocationByDeviceId(String targetDeviceId) {
    if (_currentTeam == null) return null;

    final allMembers = _currentTeam!.members;
    final member = allMembers.cast<TeamMember?>().firstWhere(
          (m) => m?.deviceId == targetDeviceId,
          orElse: () => null,
        );

    if (member == null || member.lastLocation == null) return null;

    final colorIndex = allMembers.indexOf(member);
    return MemberLocation(
      deviceId: member.deviceId,
      nickname: member.nickname,
      location: member.lastLocation!.latLng,
      lastUpdate: member.lastLocationUpdate,
      colorIndex: colorIndex,
      isLeader: member.isLeader,
    );
  }
}

/// 成员位置信息（用于地图显示）
class MemberLocation {
  final String deviceId;
  final String nickname;
  final LatLng location;
  final DateTime? lastUpdate;
  final int colorIndex; // 用于区分不同成员的颜色索引
  final bool isLeader;
  final bool isMe; // 是否是自己

  MemberLocation({
    required this.deviceId,
    required this.nickname,
    required this.location,
    this.lastUpdate,
    this.colorIndex = 0,
    this.isLeader = false,
    this.isMe = false,
  });

  /// 成员标记颜色列表
  static const List<int> memberColors = [
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF2196F3, // Blue
    0xFF009688, // Teal
    0xFFFF9800, // Orange
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFF4CAF50, // Green
    0xFFF44336, // Red
    0xFF3F51B5, // Indigo
  ];

  /// 获取成员颜色
  int get color => memberColors[colorIndex % memberColors.length];
}
