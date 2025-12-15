import 'dart:async';
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

  LocationUpdateCallback? onLocationUpdate;

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

  /// 开始追踪
  Future<void> startTracking() async {
    _isAutoPaused = false;
    _lowSpeedStartTime = null;
    _highSpeedStartTime = null;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handlePosition);

    // 启动 compass 订阅来获取真实的 heading
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _currentHeading = event.heading!;
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
