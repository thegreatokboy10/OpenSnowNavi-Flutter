// 团队数据模型
import '../services/search_service.dart' show LatLng;

/// 成员位置详细信息
class MemberLocationData {
  final double lat;
  final double lng;
  final double? accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime? timestamp;

  MemberLocationData({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    this.timestamp,
  });

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  factory MemberLocationData.fromJson(Map<String, dynamic> json) {
    return MemberLocationData(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      altitude: json['altitude'] != null
          ? (json['altitude'] as num).toDouble()
          : null,
      heading:
          json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}

/// 团队成员模型
class TeamMember {
  final String deviceId;
  String nickname;
  bool isLeader;
  bool shareLocation;
  MemberLocationData? lastLocation;
  DateTime checkinTime;

  TeamMember({
    required this.deviceId,
    required this.nickname,
    this.isLeader = false,
    this.shareLocation = false,
    this.lastLocation,
    DateTime? checkinTime,
  }) : checkinTime = checkinTime ?? DateTime.now();

  /// 获取位置的 LatLng
  LatLng? get lastLocationLatLng => lastLocation?.latLng;

  /// 获取位置更新时间
  DateTime? get lastLocationUpdate => lastLocation?.timestamp;

  /// 检查今天是否已签到
  bool get hasCheckedInToday {
    final now = DateTime.now();
    return checkinTime.year == now.year &&
        checkinTime.month == now.month &&
        checkinTime.day == now.day;
  }

  /// 获取位置更新时长
  Duration? get locationUpdateAge {
    if (lastLocationUpdate == null) return null;
    return DateTime.now().difference(lastLocationUpdate!);
  }

  /// 位置是否在10分钟内更新（活跃状态）
  bool get isLocationActive {
    final age = locationUpdateAge;
    return age != null && age.inMinutes < 10;
  }

  /// 位置是否在24小时内更新（可显示状态）
  bool get isLocationValid {
    final age = locationUpdateAge;
    return age != null && age.inHours < 24;
  }

  /// 是否正在共享位置（开启共享 + 有位置数据 + 24小时内更新）
  bool get isSharingLocation =>
      shareLocation && lastLocation != null && isLocationValid;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'nickname': nickname,
        'isLeader': isLeader,
        'shareLocation': shareLocation,
        'lastLocation': lastLocation?.toJson(),
        'checkinTime': checkinTime.toIso8601String(),
      };

  factory TeamMember.fromApiJson(Map<String, dynamic> json) {
    MemberLocationData? location;
    if (json['lastLocation'] != null) {
      location = MemberLocationData.fromJson(
          json['lastLocation'] as Map<String, dynamic>);
    }
    return TeamMember(
      deviceId: json['deviceId'] as String,
      nickname: json['nickname'] as String? ?? '未知',
      isLeader: json['isLeader'] as bool? ?? false,
      shareLocation: json['shareLocation'] as bool? ?? false,
      lastLocation: location,
      checkinTime: json['checkinTime'] != null
          ? DateTime.parse(json['checkinTime'] as String)
          : DateTime.now(),
    );
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember.fromApiJson(json);
  }
}

/// 团队模型
class Team {
  final String id;
  String name;
  final String resortKey;
  int maxMembers;
  List<TeamMember> members;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Team({
    required this.id,
    required this.name,
    required this.resortKey,
    this.maxMembers = 6,
    List<TeamMember>? members,
    DateTime? createdAt,
    this.updatedAt,
  })  : members = members ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// 获取队长
  TeamMember? get leader => members.cast<TeamMember?>().firstWhere(
        (m) => m?.isLeader == true,
        orElse: () => null,
      );

  /// 获取今日有效成员
  List<TeamMember> get activeMembers =>
      members.where((m) => m.hasCheckedInToday).toList();

  /// 是否可以加入更多成员
  bool get canJoin => activeMembers.length < maxMembers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'resort': resortKey,
        'maxSize': maxMembers,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory Team.fromApiJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      resortKey: json['resort'] as String? ?? '',
      maxMembers: json['maxSize'] as int? ?? 6,
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => TeamMember.fromApiJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      resortKey: (json['resort'] ?? json['resortKey']) as String? ?? '',
      maxMembers: (json['maxSize'] ?? json['maxMembers']) as int? ?? 6,
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// 团队操作结果
class TeamResult {
  final bool success;
  final Team? team;
  final String? error;

  TeamResult({required this.success, this.team, this.error});
}

/// 加入团队结果
class JoinResult {
  final bool success;
  final Team? team;
  final String? error;

  JoinResult({required this.success, this.team, this.error});
}
