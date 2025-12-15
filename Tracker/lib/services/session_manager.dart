import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/location_point.dart';
import '../models/motion_data.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'motion_service.dart';

/// Session 管理器 - 核心业务逻辑
class SessionManager extends ChangeNotifier {
  final _db = DatabaseService();
  final _locationService = LocationService();
  final _motionService = MotionService();
  final _uuid = const Uuid();

  Session? _currentSession;
  bool _isRecording = false;
  bool _isPaused = false;
  Position? _currentPosition;
  double _currentSpeed = 0;
  double _currentHeading = 0;

  // 实时统计
  double _totalDistance = 0;
  double _skiingDistance = 0;
  double _maxSpeed = 0;
  double _elevationGain = 0;
  double _elevationLoss = 0;

  Position? _lastPosition;
  double? _lastAltitude;
  DateTime? _pauseStartTime;
  double _totalPausedDuration = 0;

  // 运动数据采样计数器
  int _motionSampleCounter = 0;
  static const int _motionSampleInterval = 10;

  // Getters
  Session? get currentSession => _currentSession;
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get isAutoPaused => _locationService.isAutoPaused;
  Position? get currentPosition => _currentPosition;
  double get currentSpeed => _currentSpeed;
  double get currentHeading => _currentHeading;
  double get totalDistance => _totalDistance;
  double get skiingDistance => _skiingDistance;
  double get maxSpeed => _maxSpeed;
  double get elevationGain => _elevationGain;
  double get elevationLoss => _elevationLoss;
  GpsSignalStrength get gpsSignalStrength => _locationService.signalStrength;

  SessionManager() {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _locationService.onLocationUpdate = _handleLocationUpdate;
    _motionService.onMotionUpdate = _handleMotionUpdate;
  }

  /// 请求位置权限并开始监听 GPS（用于信号强度指示）
  Future<bool> requestPermission() async {
    final granted = await _locationService.requestPermission();
    if (granted) {
      // 立即开始监听 GPS 信号以获取信号强度
      await _locationService.startTracking();
    }
    return granted;
  }

  /// 开始 Session
  Future<void> startSession() async {
    final session = Session(
      id: _uuid.v4(),
      startTime: DateTime.now(),
    );
    _currentSession = session;
    await _db.insertSession(session);

    // 重置统计
    _totalDistance = 0;
    _skiingDistance = 0;
    _maxSpeed = 0;
    _elevationGain = 0;
    _elevationLoss = 0;
    _lastPosition = null;
    _lastAltitude = null;
    _totalPausedDuration = 0;

    _isRecording = true;
    _isPaused = false;

    // Location tracking 已经在 requestPermission 中启动，这里只需重置状态
    _locationService.resetAutoPauseState();
    _motionService.startTracking();

    notifyListeners();
  }

  /// 暂停 Session
  void pauseSession() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _currentSession?.state = SessionState.paused;
    _db.updateSession(_currentSession!);
    notifyListeners();
  }

  /// 恢复 Session
  void resumeSession() {
    if (!_isRecording || !_isPaused) return;
    if (_pauseStartTime != null) {
      _totalPausedDuration +=
          DateTime.now().difference(_pauseStartTime!).inMilliseconds / 1000.0;
    }
    _isPaused = false;
    _pauseStartTime = null;
    _currentSession?.state = SessionState.recording;
    _db.updateSession(_currentSession!);
    notifyListeners();
  }

  /// 停止 Session
  Future<void> stopSession() async {
    if (!_isRecording) return;

    _locationService.stopTracking();
    _motionService.stopTracking();

    // 计算最终暂停时长
    if (_isPaused && _pauseStartTime != null) {
      _totalPausedDuration +=
          DateTime.now().difference(_pauseStartTime!).inMilliseconds / 1000.0;
    }

    // 更新 Session
    _currentSession?.endTime = DateTime.now();
    _currentSession?.state = SessionState.stopped;
    _currentSession?.totalDistance = _totalDistance;
    _currentSession?.skiingDistance = _skiingDistance;
    _currentSession?.maxSpeed = _maxSpeed;
    _currentSession?.totalElevationGain = _elevationGain;
    _currentSession?.totalElevationLoss = _elevationLoss;
    _currentSession?.pausedDuration = _totalPausedDuration;

    await _db.updateSession(_currentSession!);

    _isRecording = false;
    _isPaused = false;
    _currentSession = null;

    notifyListeners();
  }

  // ==================== 数据处理 ====================

  void _handleLocationUpdate(
      Position position, bool isMoving, bool isAutoPaused) {
    _currentPosition = position;
    _currentSpeed = position.speed >= 0 ? position.speed : 0;
    // 从 LocationService 获取 compass heading（更准确）
    _currentHeading = _locationService.currentHeading;

    if (!_isRecording || _currentSession == null) {
      notifyListeners();
      return;
    }

    // 如果手动暂停，不记录数据
    if (_isPaused) {
      notifyListeners();
      return;
    }

    // 保存位置点（使用 compass 的 heading）
    final point = LocationPoint(
      id: _uuid.v4(),
      sessionId: _currentSession!.id,
      timestamp: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      horizontalAccuracy: position.accuracy,
      verticalAccuracy: position.altitudeAccuracy,
      speed: position.speed,
      heading: _currentHeading,
      isMoving: isMoving,
      isAutoPaused: isAutoPaused,
    );
    _db.insertLocationPoint(point);

    // 计算距离
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistance += distance;

      if (isMoving) {
        _skiingDistance += distance;
      }

      // 更新最高速度
      if (position.speed > _maxSpeed) {
        _maxSpeed = position.speed;
      }
    }

    // 计算爬升/下降
    if (_lastAltitude != null) {
      final altDiff = position.altitude - _lastAltitude!;
      if (altDiff > 0) {
        _elevationGain += altDiff;
      } else {
        _elevationLoss += altDiff.abs();
      }
    }

    _lastPosition = position;
    _lastAltitude = position.altitude;

    notifyListeners();
  }

  void _handleMotionUpdate(AccelerometerEvent? accel, GyroscopeEvent? gyro) {
    if (!_isRecording || _isPaused || _currentSession == null) return;

    // 降低保存频率
    _motionSampleCounter++;
    if (_motionSampleCounter < _motionSampleInterval) return;
    _motionSampleCounter = 0;

    final data = MotionData(
      id: _uuid.v4(),
      sessionId: _currentSession!.id,
      timestamp: DateTime.now(),
      accelX: accel?.x ?? 0,
      accelY: accel?.y ?? 0,
      accelZ: accel?.z ?? 0,
      gyroX: gyro?.x ?? 0,
      gyroY: gyro?.y ?? 0,
      gyroZ: gyro?.z ?? 0,
    );
    _db.insertMotionData(data);
  }

  // ==================== Session 管理 ====================

  Future<List<Session>> fetchSessions() async {
    return await _db.getAllSessions();
  }

  Future<List<LocationPoint>> fetchLocationPoints(String sessionId) async {
    return await _db.getLocationPoints(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    await _db.deleteSession(sessionId);
    notifyListeners();
  }
}
