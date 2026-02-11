// 团队管理服务 - 整合设备识别和存储
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../config/team_config.dart';
import '../services/search_service.dart' show LatLng;
import '../member/member_service.dart';
import 'device_service.dart';
import 'team_api_service.dart';
import 'team_models.dart';
import 'team_storage_service.dart';

class TeamService {
  static TeamService? _instance;

  final DeviceService _deviceService = DeviceService.instance;
  final TeamStorageService _storageService = TeamStorageService.instance;
  final MemberService _memberService = MemberService.instance;

  Team? _currentTeam;
  Timer? _locationUpdateTimer;
  Timer? _teamRefreshTimer;
  bool _isRefreshing = false;
  String? _cachedDeviceId;

  // 智能位置上传相关状态
  Position? _lastUploadedPosition; // 上次上传的位置
  DateTime? _lastUploadTime; // 上次上传时间
  bool _isMoving = false; // 当前是否在移动
  int _currentLocationUploadInterval =
      TeamConfig.locationUploadIntervalStationarySeconds; // 当前上传间隔

  // 团队刷新模式
  bool _isForegroundMode = false; // 是否在前台模式
  int _currentRefreshInterval =
      TeamConfig.teamRefreshIntervalBackgroundSeconds; // 当前刷新间隔

  // 位置更新回调
  Function(List<TeamMember> members)? onMembersLocationUpdate;
  // 团队数据变化回调
  Function(Team? team)? onTeamUpdated;

  TeamService._();

  static TeamService get instance {
    _instance ??= TeamService._();
    return _instance!;
  }

  /// 获取当前设备ID（已废弃，请使用 effectiveId）
  @Deprecated('Use effectiveId instead')
  Future<String> getDeviceId() async {
    _cachedDeviceId ??= _memberService.currentMember?.id ?? '';
    return _cachedDeviceId!;
  }

  /// 同步获取设备ID（已废弃，请使用 effectiveId）
  /// 注意：这里返回 effectiveId 以确保所有调用都使用正确的ID
  @Deprecated('Use effectiveId instead')
  String get deviceId => effectiveId;

  /// 获取有效的ID（使用 memberId 作为身份标识）
  /// 所有 API 调用都应该使用这个 ID
  /// 如果用户未登录，返回空字符串
  String get effectiveId {
    return _memberService.currentMember?.id ?? '';
  }

  /// 获取有效的昵称（优先使用会员姓名）
  Future<String> getEffectiveNickname() async {
    if (_memberService.isLoggedIn &&
        _memberService.currentMember?.name != null) {
      return _memberService.currentMember!.name!;
    }
    return await _deviceService.getDefaultNickname();
  }

  /// 是否已登录会员
  bool get isMemberLoggedIn => _memberService.isLoggedIn;

  /// 是否可以创建团队（super_admin 或 admin 可以）
  bool get canCreateTeam => _memberService.canCreateTeam;

  /// 获取当前团队
  Team? get currentTeam => _currentTeam;

  /// 获取当前成员
  TeamMember? get currentMember {
    if (_currentTeam == null) return null;
    return _currentTeam!.members.cast<TeamMember?>().firstWhere(
          (m) => m?.deviceId == effectiveId,
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
    // 初始化设备服务和会员服务
    await _deviceService.initialize();
    await _storageService.initialize();
    await _memberService.initialize();
    _cachedDeviceId = await _deviceService.getDeviceId();

    // 注册会员登出回调 - 会员退出登录时清除团队状态
    _memberService.onLogout = () {
      clearTeam();
    };

    // 如果已有团队数据，不需要重新初始化
    if (_currentTeam != null) {
      print(
          '[TeamService] initialize: already have team ${_currentTeam!.id}, skipping');
      return;
    }

    // 优先使用本地保存的团队 ID
    final savedTeamId = await _deviceService.getCurrentTeamId();
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
        await _deviceService.saveCurrentTeamId(null);
      }
    }

    // 如果用户未登录，跳过通过 effectiveId 查询
    if (!_memberService.isLoggedIn) {
      print(
          '[TeamService] initialize: user not logged in, skipping team lookup');
      return;
    }

    // 如果本地没有保存的团队 ID，或者保存的团队已失效，尝试通过 effectiveId 查询
    print('[TeamService] initialize: trying to find team by effectiveId');
    final result = await _storageService.getTeamByDeviceId(effectiveId);
    if (result != null && result.found && result.firstTeam != null) {
      print(
          '[TeamService] initialize: found team ${result.firstTeam!.id} by effectiveId');
      await _restoreTeam(result.firstTeam!);
    } else {
      print('[TeamService] initialize: no team found for effectiveId');
    }
  }

  /// 恢复团队状态（设置当前团队、检查签到、启动刷新定时器）
  Future<void> _restoreTeam(Team team) async {
    _currentTeam = team;
    await _deviceService.saveCurrentTeamId(team.id);

    // 检查是否需要今日签到
    final member = currentMember;
    if (member != null && !member.hasCheckedInToday) {
      print('[TeamService] _restoreTeam: need to check in today');
      await _storageService.checkIn(
        teamId: team.id,
        deviceId: effectiveId,
        nickname: member.nickname,
      );
      final refreshedTeam = await _storageService.getTeam(team.id);
      if (refreshedTeam != null) {
        _currentTeam = refreshedTeam;
      }
    }

    _startRefreshTimer();
    print('[TeamService] _restoreTeam: team ${team.id} restored successfully');
    onTeamUpdated?.call(_currentTeam);
  }

  /// 创建团队（必须是 super_admin 会员）
  Future<TeamResult> createTeam({
    required String name,
    required String resortKey,
    int maxMembers = 6,
  }) async {
    // 检查是否已登录且有权限
    if (!isMemberLoggedIn) {
      return TeamResult(success: false, error: '请先登录会员账号');
    }
    if (!canCreateTeam) {
      return TeamResult(success: false, error: '只有管理员可以创建团队');
    }

    final memberNickname = await getEffectiveNickname();

    final result = await _storageService.createTeam(
      name: name,
      resortKey: resortKey,
      leaderDeviceId: effectiveId, // 使用 memberId
      leaderNickname: memberNickname, // 使用会员姓名
      maxMembers: maxMembers,
    );

    if (result.success && result.team != null) {
      _currentTeam = result.team;
      await _deviceService.saveCurrentTeamId(_currentTeam!.id);
      _startRefreshTimer();
      onTeamUpdated?.call(_currentTeam);
    }

    return result;
  }

  /// 加入团队（必须是登录会员）
  Future<JoinResult> joinTeam(String teamId) async {
    // 检查是否已登录
    if (!isMemberLoggedIn) {
      return JoinResult(success: false, error: '请先登录会员账号');
    }

    final memberNickname = await getEffectiveNickname();

    final result = await _storageService.joinTeam(
      teamId: teamId,
      deviceId: effectiveId, // 使用 memberId
      nickname: memberNickname, // 使用会员姓名
    );

    if (result.success && result.team != null) {
      _currentTeam = result.team;
      await _deviceService.saveCurrentTeamId(teamId);
      _startRefreshTimer();
      onTeamUpdated?.call(_currentTeam);
    }

    return JoinResult(
      success: result.success,
      team: result.team,
      error: result.error,
    );
  }

  /// 离开团队（队长离开时会删除整个团队）
  Future<bool> leaveTeam() async {
    if (_currentTeam == null) return false;

    bool success;
    // 使用 effectiveId - 如果是会员登录，使用 memberId；否则使用 deviceId
    success = await _storageService.leaveTeam(_currentTeam!.id, effectiveId);

    if (success) {
      _clearTeamLocally();
    }
    return success;
  }

  /// 清除本地团队状态（不调用 API，仅在本地清除）
  /// 用于会员登出时清除团队数据
  void _clearTeamLocally() {
    _stopTimers();
    _currentTeam = null;
    _deviceService.saveCurrentTeamId(null);
    onTeamUpdated?.call(null);
  }

  /// 清除团队状态（公共方法，供外部调用）
  void clearTeam() {
    _clearTeamLocally();
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
      deviceId: effectiveId,
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

  /// 更新当前用户昵称
  Future<bool> updateNickname(String newNickname) async {
    if (_currentTeam == null) {
      print('[TeamService] updateNickname: currentTeam is null');
      return false;
    }

    print('[TeamService] updateNickname: $newNickname');
    final updatedTeam = await _storageService.updateMemberNickname(
      teamId: _currentTeam!.id,
      deviceId: effectiveId,
      nickname: newNickname,
    );

    if (updatedTeam != null) {
      _currentTeam = updatedTeam;
      await _deviceService.saveNickname(newNickname);
      onTeamUpdated?.call(_currentTeam);
      return true;
    }
    return false;
  }

  /// 获取分享链接
  String getShareLink() {
    if (_currentTeam == null) return '';
    return 'https://snownavi.ski?team=${_currentTeam!.id}';
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
      Duration(seconds: _currentRefreshInterval),
      (_) => _refreshTeam(),
    );
  }

  /// 设置前台/后台模式
  /// [isForeground] true 表示地图页面在前台，使用更频繁的刷新间隔
  void setForegroundMode(bool isForeground) {
    if (_isForegroundMode == isForeground) return;

    _isForegroundMode = isForeground;
    _currentRefreshInterval = isForeground
        ? TeamConfig.teamRefreshIntervalForegroundSeconds
        : TeamConfig.teamRefreshIntervalBackgroundSeconds;

    print(
        '[TeamService] setForegroundMode: $isForeground, refresh interval: $_currentRefreshInterval s');

    // 如果有团队，重新启动刷新定时器
    if (_currentTeam != null) {
      _startRefreshTimer();
      // 前台模式时立即刷新一次
      if (isForeground) {
        _refreshTeam();
      }
    }
  }

  /// 获取当前是否在前台模式
  bool get isForegroundMode => _isForegroundMode;

  /// 手动刷新团队数据（供外部调用）
  Future<void> refreshTeam() async {
    await _refreshTeam();
  }

  /// 开始位置更新
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _updateLocation(); // 立即更新一次
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _currentLocationUploadInterval),
      (_) => _updateLocation(),
    );
  }

  /// 停止位置更新
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _lastUploadedPosition = null;
    _lastUploadTime = null;
    _isMoving = false;
  }

  /// 更新当前位置
  Future<void> _updateLocation() async {
    if (_currentTeam == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 检测是否在移动
      final wasMoving = _isMoving;
      _isMoving = _checkIfMoving(position);

      // 如果移动状态改变，调整上传间隔
      if (_isMoving != wasMoving) {
        _adjustLocationUploadInterval();
      }

      // 上传位置
      await _storageService.updateMemberLocation(
        teamId: _currentTeam!.id,
        deviceId: effectiveId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
      );

      // 更新上传状态
      _lastUploadedPosition = position;
      _lastUploadTime = DateTime.now();

      await _refreshTeam();
    } catch (e) {
      // 位置更新失败，静默处理
      print('[TeamService] _updateLocation error: $e');
    }
  }

  /// 检测是否在移动
  bool _checkIfMoving(Position currentPosition) {
    // 方法1：通过速度判断
    if (currentPosition.speed > TeamConfig.movementSpeedThreshold) {
      return true;
    }

    // 方法2：通过与上次位置的距离判断
    if (_lastUploadedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastUploadedPosition!.latitude,
        _lastUploadedPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      if (distance > TeamConfig.movementDistanceThreshold) {
        return true;
      }
    }

    return false;
  }

  /// 调整位置上传间隔
  void _adjustLocationUploadInterval() {
    final newInterval = _isMoving
        ? TeamConfig.locationUploadIntervalMovingSeconds
        : TeamConfig.locationUploadIntervalStationarySeconds;

    if (newInterval != _currentLocationUploadInterval) {
      _currentLocationUploadInterval = newInterval;
      print(
          '[TeamService] Location upload interval changed: $_currentLocationUploadInterval s (moving: $_isMoving)');

      // 重新启动定时器
      if (_locationUpdateTimer != null) {
        _locationUpdateTimer!.cancel();
        _locationUpdateTimer = Timer.periodic(
          Duration(seconds: _currentLocationUploadInterval),
          (_) => _updateLocation(),
        );
      }
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
  /// 注意：只返回24小时内有位置更新的成员
  List<MemberLocation> getMemberLocations({bool includeMyself = true}) {
    if (_currentTeam == null) {
      return [];
    }

    // 获取所有成员用于计算颜色索引
    final allMembers = _currentTeam!.members;

    final result = allMembers
        .where((m) {
          // 必须开启位置共享且有位置数据
          if (!m.shareLocation || m.lastLocation == null) return false;
          // 如果不包含自己，过滤掉自己
          if (!includeMyself && m.deviceId == effectiveId) return false;
          return true;
        })
        .map((m) {
          // 计算颜色索引（基于成员在列表中的位置）
          final colorIndex = allMembers.indexOf(m);
          final isMe = m.deviceId == effectiveId;
          return MemberLocation(
            deviceId: m.deviceId,
            nickname: isMe ? '${m.nickname} (我)' : m.nickname,
            location: m.lastLocation!.latLng,
            lastUpdate: m.lastLocationUpdate,
            colorIndex: colorIndex,
            isLeader: m.isLeader,
            isMe: isMe,
          );
        })
        .where((m) => m.shouldShowOnMap) // 过滤掉超过24小时的成员
        .toList();

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

/// 位置状态枚举
enum LocationStatus {
  active, // 10分钟内更新 - 绿色
  stale, // 10分钟到24小时 - 灰色
  expired, // 超过24小时 - 不显示
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

  /// 获取位置更新时长
  Duration? get updateAge {
    if (lastUpdate == null) return null;
    return DateTime.now().difference(lastUpdate!);
  }

  /// 获取位置状态
  LocationStatus get locationStatus {
    final age = updateAge;
    if (age == null) return LocationStatus.expired;
    if (age.inMinutes < 10) return LocationStatus.active;
    if (age.inHours < 24) return LocationStatus.stale;
    return LocationStatus.expired;
  }

  /// 是否应该在地图上显示（24小时内有更新）
  bool get shouldShowOnMap => locationStatus != LocationStatus.expired;

  /// 状态圆圈颜色
  int get statusColor {
    switch (locationStatus) {
      case LocationStatus.active:
        return 0xFF4CAF50; // 绿色
      case LocationStatus.stale:
        return 0xFF9E9E9E; // 灰色
      case LocationStatus.expired:
        return 0xFF9E9E9E; // 灰色
    }
  }
}
