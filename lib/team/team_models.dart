// 团队数据模型
import 'package:mapbox_gl/mapbox_gl.dart';

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
  DateTime checkinTime; // 签到时间

  TeamMember({
    required this.deviceId,
    required this.nickname,
    this.isLeader = false,
    this.shareLocation = false,
    this.lastLocation,
    DateTime? checkinTime,
  }) : checkinTime = checkinTime ?? DateTime.now();

  /// 获取位置的 LatLng（兼容旧代码）
  LatLng? get lastLocationLatLng => lastLocation?.latLng;

  /// 获取位置更新时间（兼容旧代码）
  DateTime? get lastLocationUpdate => lastLocation?.timestamp;

  /// 检查今天是否已占位
  bool get hasCheckedInToday {
    final now = DateTime.now();
    return checkinTime.year == now.year &&
        checkinTime.month == now.month &&
        checkinTime.day == now.day;
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'nickname': nickname,
        'isLeader': isLeader,
        'shareLocation': shareLocation,
        'lastLocation': lastLocation?.toJson(),
        'checkinTime': checkinTime.toIso8601String(),
      };

  /// 从后端 API 响应解析
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

  /// 兼容旧的 fromJson（用于 localStorage）
  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember.fromApiJson(json);
  }
}

/// 团队模型
class Team {
  final String id;
  String name;
  final String resortKey; // 对应后端的 resort
  int maxMembers; // 对应后端的 maxSize
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

  /// 获取今日有效成员（已占位的）
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

  /// 从后端 API 响应解析
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

  /// 兼容旧的 fromJson
  factory Team.fromJson(Map<String, dynamic> json) {
    // 兼容两种格式
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
