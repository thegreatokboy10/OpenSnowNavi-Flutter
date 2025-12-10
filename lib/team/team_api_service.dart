// 团队 API 服务 - 与后端交互
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'team_models.dart';

class TeamApiService {
  static TeamApiService? _instance;

  // API 基础 URL - 生产环境
  static const String _baseUrl =
      "http://localhost:8899"; //'https://snownavi.ski';

  TeamApiService._();

  static TeamApiService get instance {
    _instance ??= TeamApiService._();
    return _instance!;
  }

  /// 检查用户权限
  Future<ApiResult<PermissionResult>> checkPermission(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/check-permission?email=$email'),
        headers: {'X-User-Email': email},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(PermissionResult(
          permissionLevel: json['permission_level'] ?? 'none',
          canAccess: json['can_access'] ?? false,
          userRole: json['user_role'],
        ));
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 创建团队
  Future<ApiResult<Team>> createTeam({
    required String name,
    required String resort,
    int maxSize = 6,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/team'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'resort': resort,
          'maxSize': maxSize,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final team = Team.fromApiJson(json['team']);
        return ApiResult.success(team);
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 获取团队详情
  Future<ApiResult<Team>> getTeam(String teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/team/$teamId'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final team = Team.fromApiJson(json['team']);
        return ApiResult.success(team);
      } else if (response.statusCode == 404) {
        return ApiResult.failure('团队不存在');
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 加入团队
  Future<ApiResult<Team>> joinTeam({
    required String teamId,
    required String deviceId,
    required String nickname,
    bool shareLocation = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/team/$teamId/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': deviceId,
          'nickname': nickname,
          'shareLocation': shareLocation,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final team = Team.fromApiJson(json['team']);
        return ApiResult.success(team);
      } else if (response.statusCode == 409) {
        return ApiResult.failure('团队已满');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('团队不存在');
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 更新成员位置
  Future<ApiResult<void>> updateMemberLocation({
    required String teamId,
    required String deviceId,
    required double lat,
    required double lng,
    double? accuracy,
    double? altitude,
    double? heading,
    double? speed,
  }) async {
    try {
      final body = <String, dynamic>{
        'lat': lat,
        'lng': lng,
      };
      if (accuracy != null) body['accuracy'] = accuracy;
      if (altitude != null) body['altitude'] = altitude;
      if (heading != null) body['heading'] = heading;
      if (speed != null) body['speed'] = speed;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/team/$teamId/member/$deviceId/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 成员退出团队
  Future<ApiResult<void>> leaveTeam({
    required String teamId,
    required String deviceId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/team/$teamId/member/$deviceId'),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 更新成员信息（用于更新昵称、位置共享设置等）
  Future<ApiResult<Team>> updateMember({
    required String teamId,
    required String deviceId,
    String? nickname,
    bool? shareLocation,
    bool? isLeader,
  }) async {
    try {
      final body = <String, dynamic>{
        'deviceId': deviceId,
      };
      if (nickname != null) body['nickname'] = nickname;
      if (shareLocation != null) body['shareLocation'] = shareLocation;
      if (isLeader != null) body['isLeader'] = isLeader;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/team/$teamId/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final team = Team.fromApiJson(json['team']);
        return ApiResult.success(team);
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  /// 根据 deviceId 查找用户所在的团队
  Future<ApiResult<TeamsByDeviceResult>> getTeamByDeviceId(
      String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/team/by-device/$deviceId'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final found = json['found'] as bool? ?? false;
        final teams = <Team>[];

        if (found) {
          // 优先使用 teams 数组（可能有多个团队）
          if (json['teams'] != null) {
            for (final t in json['teams']) {
              teams.add(Team.fromApiJson(t));
            }
          } else if (json['team'] != null) {
            teams.add(Team.fromApiJson(json['team']));
          }
        }

        return ApiResult.success(TeamsByDeviceResult(
          found: found,
          deviceId: deviceId,
          teams: teams,
        ));
      } else {
        final error = _parseError(response);
        return ApiResult.failure(error);
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
    }
  }

  String _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return json['error'] ?? json['message'] ?? '未知错误';
    } catch (e) {
      return '服务器错误 (${response.statusCode})';
    }
  }
}

/// 根据 deviceId 查询团队的结果
class TeamsByDeviceResult {
  final bool found;
  final String deviceId;
  final List<Team> teams;

  TeamsByDeviceResult({
    required this.found,
    required this.deviceId,
    required this.teams,
  });

  /// 获取第一个团队（如果有）
  Team? get firstTeam => teams.isNotEmpty ? teams.first : null;
}

/// 权限检查结果
class PermissionResult {
  final String permissionLevel;
  final bool canAccess;
  final String? userRole;

  PermissionResult({
    required this.permissionLevel,
    required this.canAccess,
    this.userRole,
  });

  /// 是否是超级管理员
  bool get isSuperAdmin => permissionLevel == 'super_admin';

  /// 是否有管理权限（super_admin 或 admin）
  bool get hasAdminAccess =>
      permissionLevel == 'super_admin' || permissionLevel == 'admin';
}

/// API 调用结果
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult._({required this.success, this.data, this.error});

  factory ApiResult.success(T? data) => ApiResult._(success: true, data: data);
  factory ApiResult.failure(String error) =>
      ApiResult._(success: false, error: error);
}
