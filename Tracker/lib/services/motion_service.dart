import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// 运动数据回调
typedef MotionUpdateCallback = void Function(
    AccelerometerEvent? accel, GyroscopeEvent? gyro);

/// 运动数据服务
class MotionService {
  static final MotionService _instance = MotionService._internal();
  factory MotionService() => _instance;
  MotionService._internal();

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;

  MotionUpdateCallback? onMotionUpdate;

  /// 开始追踪
  void startTracking() {
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      _lastAccel = event;
      _notifyUpdate();
    });

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      _lastGyro = event;
    });
  }

  /// 停止追踪
  void stopTracking() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _lastAccel = null;
    _lastGyro = null;
  }

  void _notifyUpdate() {
    onMotionUpdate?.call(_lastAccel, _lastGyro);
  }

  AccelerometerEvent? get lastAccel => _lastAccel;
  GyroscopeEvent? get lastGyro => _lastGyro;
}

