// 设备识别服务 - 使用 SharedPreferences 存储设备ID和昵称
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const String _deviceIdKey = 'snownavi_device_id';
  static const String _nicknameKey = 'snownavi_nickname';
  static const String _teamIdKey = 'snownavi_current_team';

  static DeviceService? _instance;
  SharedPreferences? _prefs;
  String? _cachedDeviceId;

  DeviceService._();

  static DeviceService get instance {
    _instance ??= DeviceService._();
    return _instance!;
  }

  /// 初始化服务
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  /// 获取或创建设备ID
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    await _ensureInitialized();
    String? deviceId = _prefs!.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await _prefs!.setString(_deviceIdKey, deviceId);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// 同步获取设备ID（需要先调用 initialize）
  String getDeviceIdSync() {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    if (_prefs != null) {
      final deviceId = _prefs!.getString(_deviceIdKey);
      if (deviceId != null && deviceId.isNotEmpty) {
        _cachedDeviceId = deviceId;
        return deviceId;
      }
    }
    // 如果没有初始化，生成一个临时的
    final tempId = _generateDeviceId();
    _cachedDeviceId = tempId;
    // 异步保存
    _ensureInitialized().then((_) {
      _prefs!.setString(_deviceIdKey, tempId);
    });
    return tempId;
  }

  /// 生成唯一设备ID
  String _generateDeviceId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart =
        List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'dev_${timestamp.toRadixString(16)}_$randomPart';
  }

  /// 获取保存的昵称
  Future<String?> getNickname() async {
    await _ensureInitialized();
    return _prefs!.getString(_nicknameKey);
  }

  /// 同步获取昵称
  String? getNicknameSync() {
    return _prefs?.getString(_nicknameKey);
  }

  /// 保存昵称
  Future<void> saveNickname(String nickname) async {
    await _ensureInitialized();
    await _prefs!.setString(_nicknameKey, nickname);
  }

  /// 获取当前加入的团队ID
  Future<String?> getCurrentTeamId() async {
    await _ensureInitialized();
    return _prefs!.getString(_teamIdKey);
  }

  /// 同步获取当前团队ID
  String? getCurrentTeamIdSync() {
    return _prefs?.getString(_teamIdKey);
  }

  /// 保存当前团队ID
  Future<void> saveCurrentTeamId(String? teamId) async {
    await _ensureInitialized();
    if (teamId == null) {
      await _prefs!.remove(_teamIdKey);
    } else {
      await _prefs!.setString(_teamIdKey, teamId);
    }
  }

  /// 获取默认昵称
  Future<String> getDefaultNickname() async {
    final saved = await getNickname();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    return _generateRandomNickname();
  }

  /// 同步获取默认昵称
  String getDefaultNicknameSync() {
    final saved = getNicknameSync();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    return _generateRandomNickname();
  }

  /// 生成随机昵称
  String _generateRandomNickname() {
    final adjectives = ['快乐', '飞翔', '自由', '勇敢', '闪电', '雪山'];
    final nouns = ['滑雪者', '雪兔', '雪豹', '极客', '冒险家', '探险者'];
    final random = Random();
    return '${adjectives[random.nextInt(adjectives.length)]}${nouns[random.nextInt(nouns.length)]}';
  }
}

