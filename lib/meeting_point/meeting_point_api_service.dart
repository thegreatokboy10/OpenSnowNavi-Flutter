import 'dart:convert';
import 'package:http/http.dart' as http;
import 'meeting_point_model.dart';

/// API 调用结果
class MeetingPointApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  MeetingPointApiResult._({required this.success, this.data, this.error});

  factory MeetingPointApiResult.success(T? data) =>
      MeetingPointApiResult._(success: true, data: data);
  factory MeetingPointApiResult.failure(String error) =>
      MeetingPointApiResult._(success: false, error: error);
}

/// 集合点 API 服务
class MeetingPointApiService {
  static MeetingPointApiService? _instance;
  static const String _baseUrl =
      "http://localhost:8899"; //'https://snownavi.ski';

  MeetingPointApiService._();

  static MeetingPointApiService get instance {
    _instance ??= MeetingPointApiService._();
    return _instance!;
  }

  /// 获取团队的所有集合点
  Future<MeetingPointApiResult<List<MeetingPoint>>> getMeetingPoints(
      String teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/team/$teamId/meeting-points'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['meetingPoints'] ?? [];
        final points = data.map((p) => MeetingPoint.fromJson(p)).toList();
        return MeetingPointApiResult.success(points);
      } else {
        return MeetingPointApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MeetingPointApiResult.failure('网络错误: $e');
    }
  }

  /// 添加集合点
  Future<MeetingPointApiResult<MeetingPoint>> addMeetingPoint({
    required String teamId,
    required String name,
    required double latitude,
    required double longitude,
    required String deviceId,
    required String nickname,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/team/$teamId/meeting-points'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'createdBy': deviceId,
          'creatorNickname': nickname,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return MeetingPointApiResult.success(
            MeetingPoint.fromJson(json['meetingPoint']));
      } else {
        return MeetingPointApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MeetingPointApiResult.failure('网络错误: $e');
    }
  }

  /// 更新集合点（名称）
  Future<MeetingPointApiResult<MeetingPoint>> updateMeetingPoint({
    required String teamId,
    required String pointId,
    required String name,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/team/$teamId/meeting-points/$pointId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MeetingPointApiResult.success(
            MeetingPoint.fromJson(json['meetingPoint']));
      } else {
        return MeetingPointApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MeetingPointApiResult.failure('网络错误: $e');
    }
  }

  /// 删除集合点
  Future<MeetingPointApiResult<void>> deleteMeetingPoint({
    required String teamId,
    required String pointId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/team/$teamId/meeting-points/$pointId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return MeetingPointApiResult.success(null);
      } else {
        return MeetingPointApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MeetingPointApiResult.failure('网络错误: $e');
    }
  }

  /// 设置当前有效集合点
  Future<MeetingPointApiResult<void>> setActiveMeetingPoint({
    required String teamId,
    required String pointId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$_baseUrl/api/team/$teamId/meeting-points/$pointId/activate'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return MeetingPointApiResult.success(null);
      } else {
        return MeetingPointApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MeetingPointApiResult.failure('网络错误: $e');
    }
  }

  /// 取消当前有效集合点
  Future<MeetingPointApiResult<void>> clearActiveMeetingPoint(
      String teamId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/team/$teamId/meeting-points/clear-active'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return MeetingPointApiResult.success(null);
      } else {
        return MeetingPointApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MeetingPointApiResult.failure('网络错误: $e');
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
