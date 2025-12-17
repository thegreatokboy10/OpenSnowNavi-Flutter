import '../services/search_service.dart' show LatLng;

/// 集合点模型
class MeetingPoint {
  final String id;
  final String teamId;
  String name;
  final double latitude;
  final double longitude;
  final String createdBy; // 创建者的 deviceId
  final String creatorNickname; // 创建者昵称
  final DateTime createdAt;
  bool isActive; // 是否为当前有效集合点

  MeetingPoint({
    required this.id,
    required this.teamId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdBy,
    required this.creatorNickname,
    required this.createdAt,
    this.isActive = false,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory MeetingPoint.fromJson(Map<String, dynamic> json) {
    return MeetingPoint(
      id: json['id'] as String? ?? '',
      teamId: json['teamId'] as String? ?? '',
      name: json['name'] as String? ?? '集合点',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      createdBy: json['createdBy'] as String? ?? '',
      creatorNickname: json['creatorNickname'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teamId': teamId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'createdBy': createdBy,
      'creatorNickname': creatorNickname,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  MeetingPoint copyWith({
    String? id,
    String? teamId,
    String? name,
    double? latitude,
    double? longitude,
    String? createdBy,
    String? creatorNickname,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return MeetingPoint(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdBy: createdBy ?? this.createdBy,
      creatorNickname: creatorNickname ?? this.creatorNickname,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'MeetingPoint(id: $id, name: $name, lat: $latitude, lng: $longitude, isActive: $isActive)';
  }
}

