// 团队存储服务 - 通过后端 API 实现
// 使用 JSON 文件存储，后端通过 fcntl 文件锁保证并发安全
import 'dart:html' as html;
import 'team_api_service.dart';
import 'team_models.dart';

class TeamStorageService {
  static const String _currentTeamKey = 'snownavi_current_team';

  static TeamStorageService? _instance;
  final TeamApiService _api = TeamApiService.instance;

  TeamStorageService._();

  static TeamStorageService get instance {
    _instance ??= TeamStorageService._();
    return _instance!;
  }

  /// 保存当前团队ID到本地（用于恢复会话）
  void saveCurrentTeamId(String? teamId) {
    if (teamId == null) {
      html.window.localStorage.remove(_currentTeamKey);
    } else {
      html.window.localStorage[_currentTeamKey] = teamId;
    }
  }

  /// 获取本地保存的当前团队ID
  String? getSavedTeamId() {
    return html.window.localStorage[_currentTeamKey];
  }

  /// 创建新团队
  Future<TeamResult> createTeam({
    required String name,
    required String resortKey,
    required String leaderDeviceId,
    required String leaderNickname,
    int maxMembers = 6,
  }) async {
    // 1. 创建团队
    final createResult = await _api.createTeam(
      name: name,
      resort: resortKey,
      maxSize: maxMembers,
    );

    if (!createResult.success || createResult.data == null) {
      return TeamResult(success: false, error: createResult.error ?? '创建团队失败');
    }

    final team = createResult.data!;

    // 2. 队长加入团队
    final joinResult = await _api.joinTeam(
      teamId: team.id,
      deviceId: leaderDeviceId,
      nickname: leaderNickname,
      shareLocation: false,
    );

    if (!joinResult.success || joinResult.data == null) {
      return TeamResult(success: false, error: joinResult.error ?? '队长加入团队失败');
    }

    // 3. 设置为队长
    final updateResult = await _api.updateMember(
      teamId: team.id,
      deviceId: leaderDeviceId,
      isLeader: true,
    );

    if (!updateResult.success || updateResult.data == null) {
      // 即使设置队长失败，团队也已创建，返回当前状态
      return TeamResult(success: true, team: joinResult.data);
    }

    saveCurrentTeamId(team.id);
    return TeamResult(success: true, team: updateResult.data);
  }

  /// 获取团队
  Future<Team?> getTeam(String teamId) async {
    final result = await _api.getTeam(teamId);
    return result.success ? result.data : null;
  }

  /// 加入团队
  Future<JoinResult> joinTeam({
    required String teamId,
    required String deviceId,
    required String nickname,
  }) async {
    final result = await _api.joinTeam(
      teamId: teamId,
      deviceId: deviceId,
      nickname: nickname,
      shareLocation: false,
    );

    if (result.success && result.data != null) {
      saveCurrentTeamId(teamId);
      // 检查是否是重新加入（成员已存在）
      final member = result.data!.members.cast<TeamMember?>().firstWhere(
            (m) => m?.deviceId == deviceId,
            orElse: () => null,
          );
      final isRejoin = member != null &&
          member.checkinTime
              .isBefore(DateTime.now().subtract(const Duration(seconds: 5)));
      return JoinResult(success: true, team: result.data, isRejoin: isRejoin);
    }

    return JoinResult(success: false, error: result.error ?? '加入团队失败');
  }

  /// 更新成员位置
  Future<bool> updateMemberLocation({
    required String teamId,
    required String deviceId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? heading,
    double? speed,
  }) async {
    final result = await _api.updateMemberLocation(
      teamId: teamId,
      deviceId: deviceId,
      lat: latitude,
      lng: longitude,
      accuracy: accuracy,
      altitude: altitude,
      heading: heading,
      speed: speed,
    );
    return result.success;
  }

  /// 设置位置共享状态
  Future<Team?> setLocationSharing({
    required String teamId,
    required String deviceId,
    required bool shareLocation,
  }) async {
    final result = await _api.updateMember(
      teamId: teamId,
      deviceId: deviceId,
      shareLocation: shareLocation,
    );
    print(
        '[TeamStorageService] setLocationSharing result: success=${result.success}, data=${result.data?.id}');
    return result.success ? result.data : null;
  }

  /// 更新成员昵称
  Future<Team?> updateMemberNickname({
    required String teamId,
    required String deviceId,
    required String nickname,
  }) async {
    final result = await _api.updateMember(
      teamId: teamId,
      deviceId: deviceId,
      nickname: nickname,
    );
    print(
        '[TeamStorageService] updateMemberNickname result: success=${result.success}, data=${result.data?.id}');
    return result.success ? result.data : null;
  }

  /// 删除成员（使用 leave API）
  Future<bool> removeMember({
    required String teamId,
    required String memberDeviceId,
  }) async {
    final result = await _api.leaveTeam(
      teamId: teamId,
      deviceId: memberDeviceId,
    );
    return result.success;
  }

  /// 离开团队
  Future<bool> leaveTeam(String teamId, String deviceId) async {
    final result = await _api.leaveTeam(
      teamId: teamId,
      deviceId: deviceId,
    );
    if (result.success) {
      saveCurrentTeamId(null);
    }
    return result.success;
  }

  /// 签到（重新加入以更新 checkinTime）
  Future<bool> checkIn({
    required String teamId,
    required String deviceId,
    required String nickname,
  }) async {
    final result = await _api.joinTeam(
      teamId: teamId,
      deviceId: deviceId,
      nickname: nickname,
    );
    return result.success;
  }

  /// 根据 deviceId 查找用户所在的团队
  Future<TeamsByDeviceResult?> getTeamByDeviceId(String deviceId) async {
    final result = await _api.getTeamByDeviceId(deviceId);
    print(
        '[TeamStorageService] getTeamByDeviceId: success=${result.success}, found=${result.data?.found}, teams=${result.data?.teams.length}');
    return result.success ? result.data : null;
  }
}

/// 团队操作结果
class TeamResult {
  final bool success;
  final String? error;
  final Team? team;

  TeamResult({
    required this.success,
    this.error,
    this.team,
  });
}

/// 加入团队结果
class JoinResult {
  final bool success;
  final String? error;
  final Team? team;
  final bool isRejoin;

  JoinResult({
    required this.success,
    this.error,
    this.team,
    this.isRejoin = false,
  });
}
