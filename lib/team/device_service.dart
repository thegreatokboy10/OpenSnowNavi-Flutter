// 设备识别服务 - 使用localStorage存储设备ID和昵称
import 'dart:html' as html;
import 'dart:math';

class DeviceService {
  static const String _deviceIdKey = 'snownavi_device_id';
  static const String _nicknameKey = 'snownavi_nickname';
  static const String _teamIdKey = 'snownavi_current_team';
  
  static DeviceService? _instance;
  
  DeviceService._();
  
  static DeviceService get instance {
    _instance ??= DeviceService._();
    return _instance!;
  }
  
  /// 获取或创建设备ID
  String getDeviceId() {
    String? deviceId = html.window.localStorage[_deviceIdKey];
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      html.window.localStorage[_deviceIdKey] = deviceId;
    }
    return deviceId;
  }
  
  /// 生成唯一设备ID（结合时间戳和随机数）
  String _generateDeviceId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'dev_${timestamp.toRadixString(16)}_$randomPart';
  }
  
  /// 获取保存的昵称
  String? getNickname() {
    return html.window.localStorage[_nicknameKey];
  }
  
  /// 保存昵称
  void saveNickname(String nickname) {
    html.window.localStorage[_nicknameKey] = nickname;
  }
  
  /// 获取当前加入的团队ID
  String? getCurrentTeamId() {
    return html.window.localStorage[_teamIdKey];
  }
  
  /// 保存当前团队ID
  void saveCurrentTeamId(String? teamId) {
    if (teamId == null) {
      html.window.localStorage.remove(_teamIdKey);
    } else {
      html.window.localStorage[_teamIdKey] = teamId;
    }
  }
  
  /// 获取默认昵称
  String getDefaultNickname() {
    final saved = getNickname();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    // 生成一个随机的滑雪主题昵称
    final adjectives = ['快乐', '飞翔', '自由', '勇敢', '闪电', '雪山'];
    final nouns = ['滑雪者', '雪兔', '雪豹', '极客', '冒险家', '探险者'];
    final random = Random();
    return '${adjectives[random.nextInt(adjectives.length)]}${nouns[random.nextInt(nouns.length)]}';
  }
}

