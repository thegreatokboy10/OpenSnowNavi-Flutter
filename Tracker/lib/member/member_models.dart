// 会员数据模型
/// 会员模型
class Member {
  final String id;
  final String? name;
  final String? email;
  final bool isActive;
  final String? role; // super_admin, admin, instructor, none
  final String? permissionLevel; // super_admin, admin, instructor, none
  final String? validityPeriodStr; // 原始有效期字符串
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Member({
    required this.id,
    this.name,
    this.email,
    this.isActive = true,
    this.role,
    this.permissionLevel,
    this.validityPeriodStr,
    this.createdAt,
    this.updatedAt,
  });

  /// 获取姓名首字母（用于头像）
  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  /// 是否是超级管理员
  /// 检查 permissionLevel 或 role
  bool get isSuperAdmin =>
      permissionLevel == 'super_admin' || role == 'super_admin';

  /// 是否是管理员 (admin)
  bool get isAdmin => permissionLevel == 'admin' || role == 'admin';

  /// 是否可以创建团队（super_admin 或 admin 可以）
  bool get canCreateTeam => isSuperAdmin || isAdmin;

  /// 会员状态文字
  String get statusText {
    if (!isActive) return '未激活';
    return '有效';
  }

  /// 有效期显示
  String get validityDisplay => validityPeriodStr ?? '未设置';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isActive': isActive,
        'role': role,
        'permissionLevel': permissionLevel,
        'validityPeriodStr': validityPeriodStr,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Member.fromJson(Map<String, dynamic> json) {
    // 解析有效期 - 可能是字符串或对象
    String? validityStr;
    final validityPeriod = json['validityPeriod'];
    if (validityPeriod is String) {
      validityStr = validityPeriod;
    } else if (validityPeriod is Map) {
      // 尝试从对象中获取，优先使用 en, zh, nl
      validityStr = validityPeriod['en'] as String? ??
          validityPeriod['zh'] as String? ??
          validityPeriod['nl'] as String?;
    }

    return Member(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      role: json['role'] as String?,
      permissionLevel: json['permissionLevel'] as String?,
      validityPeriodStr: validityStr ?? json['validityPeriodStr'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// 使用 check-permission API 结果更新权限
  Member copyWithPermission(String permissionLevel) {
    return Member(
      id: id,
      name: name,
      email: email,
      isActive: isActive,
      role: role,
      permissionLevel: permissionLevel,
      validityPeriodStr: validityPeriodStr,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// 会员验证结果
class MemberVerifyResult {
  final bool isMember;
  final String? memberId;
  final String? memberName;
  final String? message;

  MemberVerifyResult({
    required this.isMember,
    this.memberId,
    this.memberName,
    this.message,
  });

  factory MemberVerifyResult.fromJson(Map<String, dynamic> json) {
    return MemberVerifyResult(
      isMember: json['isMember'] as bool? ?? false,
      memberId: json['memberId'] as String?,
      memberName: json['memberName'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// API 结果封装
class MemberApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  MemberApiResult.success(this.data)
      : success = true,
        error = null;

  MemberApiResult.failure(this.error)
      : success = false,
        data = null;
}
