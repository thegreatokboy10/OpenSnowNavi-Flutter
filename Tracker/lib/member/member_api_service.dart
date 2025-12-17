// 会员 API 服务 - 与后端交互
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'member_models.dart';

class MemberApiService {
  static MemberApiService? _instance;
  static const String _baseUrl = 'https://snownavi.ski';

  MemberApiService._();

  static MemberApiService get instance {
    _instance ??= MemberApiService._();
    return _instance!;
  }

  String _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return json['error'] ?? '未知错误';
    } catch (_) {
      return '请求失败: ${response.statusCode}';
    }
  }

  /// 通过 email 验证会员
  Future<MemberApiResult<MemberVerifyResult>> verifyMemberByEmail(
      String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/verify-member'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MemberApiResult.success(MemberVerifyResult.fromJson(json));
      } else {
        return MemberApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MemberApiResult.failure('网络错误: $e');
    }
  }

  /// 获取会员详情
  Future<MemberApiResult<Member>> getMember(String memberId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/member/$memberId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MemberApiResult.success(Member.fromJson(json));
      } else if (response.statusCode == 404) {
        return MemberApiResult.failure('会员不存在');
      } else {
        return MemberApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MemberApiResult.failure('网络错误: $e');
    }
  }

  /// 检查用户权限
  Future<MemberApiResult<Map<String, dynamic>>> checkPermission(
      String email) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/api/check-permission?email=${Uri.encodeComponent(email)}&page=team'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MemberApiResult.success(json);
      } else {
        return MemberApiResult.failure(_parseError(response));
      }
    } catch (e) {
      return MemberApiResult.failure('网络错误: $e');
    }
  }
}

