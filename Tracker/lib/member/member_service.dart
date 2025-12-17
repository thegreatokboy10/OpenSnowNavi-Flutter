// 会员管理服务
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'member_api_service.dart';
import 'member_models.dart';

class MemberService {
  static MemberService? _instance;
  static const String _memberKey = 'current_member';

  Member? _currentMember;
  bool _isInitialized = false;

  /// 登出时的回调（用于通知其他服务，如 TeamService 清除团队状态）
  Function()? onLogout;

  MemberService._();

  static MemberService get instance {
    _instance ??= MemberService._();
    return _instance!;
  }

  /// 获取当前登录会员
  Member? get currentMember => _currentMember;

  /// 是否已登录
  bool get isLoggedIn => _currentMember != null;

  /// 是否是超级管理员
  bool get isSuperAdmin => _currentMember?.isSuperAdmin ?? false;

  /// 是否是管理员 (admin)
  bool get isAdmin => _currentMember?.isAdmin ?? false;

  /// 是否可以创建团队（super_admin 或 admin 可以）
  bool get canCreateTeam => _currentMember?.canCreateTeam ?? false;

  /// 初始化 - 从本地存储恢复会员信息
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final memberJson = prefs.getString(_memberKey);
    if (memberJson != null) {
      try {
        final json = jsonDecode(memberJson);
        _currentMember = Member.fromJson(json);
        // 刷新会员信息
        await _refreshMember();
      } catch (e) {
        // 解析失败，清除存储
        await prefs.remove(_memberKey);
      }
    }
    _isInitialized = true;
  }

  /// 刷新会员信息
  Future<void> _refreshMember() async {
    if (_currentMember == null) return;

    final result =
        await MemberApiService.instance.getMember(_currentMember!.id);
    if (result.success && result.data != null) {
      _currentMember = result.data;
      await _saveMember();
    }
  }

  /// 通过 email 登录
  Future<MemberApiResult<Member>> loginByEmail(String email) async {
    // 先验证 email
    final verifyResult =
        await MemberApiService.instance.verifyMemberByEmail(email);
    if (!verifyResult.success) {
      return MemberApiResult.failure(verifyResult.error ?? '验证失败');
    }

    if (!verifyResult.data!.isMember) {
      return MemberApiResult.failure(verifyResult.data!.message ?? '该邮箱未注册会员');
    }

    // 获取会员详情
    final memberResult =
        await MemberApiService.instance.getMember(verifyResult.data!.memberId!);
    if (!memberResult.success) {
      return MemberApiResult.failure(memberResult.error ?? '获取会员信息失败');
    }

    _currentMember = memberResult.data;

    // 使用 check-permission API 获取权限级别
    final permResult = await MemberApiService.instance.checkPermission(email);
    if (permResult.success && permResult.data != null) {
      final permLevel = permResult.data!['permission_level'] as String?;
      if (permLevel != null) {
        _currentMember = _currentMember!.copyWithPermission(permLevel);
      }
    }

    await _saveMember();

    return MemberApiResult.success(_currentMember);
  }

  /// 保存会员信息到本地
  Future<void> _saveMember() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentMember != null) {
      await prefs.setString(_memberKey, jsonEncode(_currentMember!.toJson()));
    }
  }

  /// 登出
  Future<void> logout() async {
    _currentMember = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_memberKey);
    // 通知其他服务登出事件
    onLogout?.call();
  }

  /// 刷新会员状态（手动刷新）
  Future<bool> refresh() async {
    if (_currentMember == null) return false;
    await _refreshMember();
    return _currentMember != null;
  }
}
