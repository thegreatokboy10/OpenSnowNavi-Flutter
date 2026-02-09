import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// GPS 信号强度等级
enum GpsSignalStrength {
  none, // 无信号
  weak, // 弱 (accuracy > 50m)
  fair, // 一般 (20m < accuracy <= 50m)
  good, // 良好 (10m < accuracy <= 20m)
  excellent // 优秀 (accuracy <= 10m)
}

/// 位置追踪配置
class LocationTrackerConfig {
  double pauseSpeedThreshold; // m/s，低于此速度视为暂停
  double resumeSpeedThreshold; // m/s，高于此速度视为恢复
  Duration pauseDelay; // 连续低速多久后暂停
  Duration resumeDelay; // 连续高速多久后恢复

  LocationTrackerConfig({
    this.pauseSpeedThreshold = 1.0,
    this.resumeSpeedThreshold = 2.0,
    this.pauseDelay = const Duration(seconds: 5),
    this.resumeDelay = const Duration(seconds: 2),
  });
}

/// 位置更新回调
typedef LocationUpdateCallback = void Function(
    Position position, bool isMoving, bool isAutoPaused);

/// 位置服务
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final config = LocationTrackerConfig();
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  bool _isAutoPaused = false;
  DateTime? _lowSpeedStartTime;
  DateTime? _highSpeedStartTime;

  Position? _lastPosition;
  GpsSignalStrength _signalStrength = GpsSignalStrength.none;
  double _currentHeading = 0; // 从 compass 获取的真实 heading

  /// 是否处于后台追踪模式（录制轨迹时使用）
  bool _isBackgroundMode = false;

  LocationUpdateCallback? onLocationUpdate;
  // Heading 更新回调，用于实时更新 UI
  void Function(double heading)? onHeadingUpdate;

  /// 是否正在追踪
  bool get isTracking => _positionSubscription != null;

  /// 是否处于后台追踪模式
  bool get isBackgroundMode => _isBackgroundMode;

  /// 请求位置权限
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 检查是否有 "Always" 后台位置权限
  Future<bool> hasAlwaysPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// 请求 "Always" 后台位置权限
  /// 返回是否成功获取权限
  Future<bool> requestAlwaysPermission() async {
    final permission = await Geolocator.checkPermission();

    // 如果已经是 always，直接返回 true
    if (permission == LocationPermission.always) {
      return true;
    }

    // 如果是 whileInUse，需要引导用户去设置中开启 always
    if (permission == LocationPermission.whileInUse) {
      // 无法直接请求升级到 always，需要用户手动去设置
      return false;
    }

    // 如果还没有权限，先请求基本权限
    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      return newPermission == LocationPermission.always;
    }

    return false;
  }

  /// 开始追踪
  /// [backgroundMode] - 是否启用后台追踪模式（录制轨迹时使用）
  /// 前台模式：不启用后台位置更新，省电
  /// 后台模式：启用后台位置更新，用于录制轨迹
  Future<void> startTracking({bool backgroundMode = false}) async {
    // 如果已经在追踪，且模式相同，则不重复启动
    if (_positionSubscription != null && _isBackgroundMode == backgroundMode) {
      return;
    }

    // 如果模式不同，先停止当前追踪
    if (_positionSubscription != null) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
    }

    _isBackgroundMode = backgroundMode;
    _isAutoPaused = false;
    _lowSpeedStartTime = null;
    _highSpeedStartTime = null;

    LocationSettings locationSettings;

    if (backgroundMode) {
      // 后台模式：用于录制轨迹，启用后台位置更新
      // 使用 Apple 平台特定设置来确保后台位置追踪稳定
      // allowBackgroundLocationUpdates: 允许后台位置更新
      // pauseLocationUpdatesAutomatically: 禁止系统自动暂停位置更新
      // showBackgroundLocationIndicator: 显示后台位置指示器（蓝条）
      // activityType: 设置为 fitness 以获得更好的位置追踪
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
      debugPrint('[LocationService] Started background tracking mode');
    } else {
      // 前台模式：仅用于显示当前位置和信号强度，不启用后台更新
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 更大的距离过滤，减少更新频率
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: true, // 允许系统自动暂停
        allowBackgroundLocationUpdates: false, // 不允许后台更新
        showBackgroundLocationIndicator: false,
      );
      debugPrint('[LocationService] Started foreground tracking mode');
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).handleError((error) {
      // 处理位置服务错误，避免应用崩溃
      debugPrint('Location error: $error');
      _signalStrength = GpsSignalStrength.none;
    }).listen(_handlePosition);

    // 启动 compass 订阅来获取真实的 heading（如果还没启动）
    _compassSubscription ??= FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _currentHeading = event.heading!;
        // 通知 heading 更新，实时刷新 UI
        onHeadingUpdate?.call(_currentHeading);
      }
    });
  }

  /// 停止追踪
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  /// 重置自动暂停状态
  void resetAutoPauseState() {
    _isAutoPaused = false;
    _lowSpeedStartTime = null;
    _highSpeedStartTime = null;
  }

  void _handlePosition(Position position) {
    _lastPosition = position;
    _updateSignalStrength(position.accuracy);

    final speed = position.speed >= 0 ? position.speed : 0.0;
    _checkAutoPause(speed);

    final isMoving = !_isAutoPaused && speed >= config.pauseSpeedThreshold;
    onLocationUpdate?.call(position, isMoving, _isAutoPaused);
  }

  void _updateSignalStrength(double accuracy) {
    if (accuracy <= 10) {
      _signalStrength = GpsSignalStrength.excellent;
    } else if (accuracy <= 20) {
      _signalStrength = GpsSignalStrength.good;
    } else if (accuracy <= 50) {
      _signalStrength = GpsSignalStrength.fair;
    } else {
      _signalStrength = GpsSignalStrength.weak;
    }
  }

  void _checkAutoPause(double speed) {
    final now = DateTime.now();

    if (_isAutoPaused) {
      // 当前已暂停，检测是否应该恢复
      if (speed >= config.resumeSpeedThreshold) {
        _highSpeedStartTime ??= now;
        if (now.difference(_highSpeedStartTime!) >= config.resumeDelay) {
          _isAutoPaused = false;
          _highSpeedStartTime = null;
          _lowSpeedStartTime = null;
        }
      } else {
        _highSpeedStartTime = null;
      }
    } else {
      // 当前未暂停，检测是否应该暂停
      if (speed < config.pauseSpeedThreshold) {
        _lowSpeedStartTime ??= now;
        if (now.difference(_lowSpeedStartTime!) >= config.pauseDelay) {
          _isAutoPaused = true;
          _lowSpeedStartTime = null;
          _highSpeedStartTime = null;
        }
      } else {
        _lowSpeedStartTime = null;
      }
    }
  }

  bool get isAutoPaused => _isAutoPaused;
  GpsSignalStrength get signalStrength => _signalStrength;
  Position? get lastPosition => _lastPosition;
  double get currentHeading => _currentHeading;
}
