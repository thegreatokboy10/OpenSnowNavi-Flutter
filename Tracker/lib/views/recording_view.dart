import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/session_manager.dart';
import '../services/location_service.dart';

/// 录制视图
class RecordingView extends StatefulWidget {
  const RecordingView({super.key});

  @override
  State<RecordingView> createState() => _RecordingViewState();
}

class _RecordingViewState extends State<RecordingView>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _lastMapCenter;

  // 呼吸动画控制器
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // 监听 SessionManager 的位置更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionManager>().addListener(_onPositionUpdate);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathingController.dispose();
    context.read<SessionManager>().removeListener(_onPositionUpdate);
    super.dispose();
  }

  void _onPositionUpdate() {
    final manager = context.read<SessionManager>();
    final position = manager.currentPosition;
    if (position != null && _mapReady) {
      final newCenter = LatLng(position.latitude, position.longitude);
      // 只有当位置变化超过一定距离时才移动地图
      if (_lastMapCenter == null ||
          _calculateDistance(_lastMapCenter!, newCenter) > 5) {
        _lastMapCenter = newCenter;
        _mapController.move(newCenter, _mapController.camera.zoom);
      }
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    // 简单的距离计算（米）
    const double earthRadius = 6371000;
    final lat1Rad = p1.latitude * math.pi / 180;
    final lat2Rad = p2.latitude * math.pi / 180;
    final deltaLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final deltaLon = (p2.longitude - p1.longitude) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _startTimer() {
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final manager = context.read<SessionManager>();
      if (!manager.isPaused) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _elapsed = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionManager>(
      builder: (context, manager, child) {
        return SafeArea(
          child: Column(
            children: [
              // 地图区域
              Expanded(
                flex: 2,
                child: _buildMap(manager),
              ),
              // 控制面板区域
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 状态指示器和GPS信号
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatusBadge(manager),
                          const SizedBox(width: 16),
                          _buildGpsSignalIndicator(manager),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 计时器
                      Text(
                        _formatDuration(_elapsed),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: manager.isPaused ? Colors.grey : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 速度
                      _buildSpeedGauge(manager),
                      const SizedBox(height: 16),
                      // 实时统计
                      if (manager.isRecording) _buildLiveStats(manager),
                      const Spacer(),
                      // 控制按钮
                      _buildControlButtons(manager),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(SessionManager manager) {
    final position = manager.currentPosition;
    final center = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(46.8182, 8.2275); // 默认瑞士中心

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        onMapReady: () {
          _mapReady = true;
          _lastMapCenter = center;
          // 初始化时如果有位置就跳转
          if (position != null) {
            _mapController.move(center, 16);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.snownavi.tracker',
        ),
        if (position != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(position.latitude, position.longitude),
                width: 60,
                height: 60,
                child: _buildCurrentLocationMarker(manager),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCurrentLocationMarker(SessionManager manager) {
    final heading = manager.currentHeading;
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 呼吸效果圆圈
            Container(
              width: 50 * _breathingAnimation.value,
              height: 50 * _breathingAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.orange.withOpacity(0.3 * _breathingAnimation.value),
              ),
            ),
            // 方向指示器
            Transform.rotate(
              angle: heading * math.pi / 180,
              child: CustomPaint(
                size: const Size(40, 40),
                painter: _HeadingArrowPainter(
                  isRecording: manager.isRecording,
                ),
              ),
            ),
            // 中心点
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: manager.isRecording ? Colors.red : Colors.orange,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGpsSignalIndicator(SessionManager manager) {
    final signal = manager.gpsSignalStrength;
    Color color;
    String text;
    int bars;

    switch (signal) {
      case GpsSignalStrength.none:
        color = Colors.grey;
        text = 'No GPS';
        bars = 0;
        break;
      case GpsSignalStrength.weak:
        color = Colors.red;
        text = 'Weak';
        bars = 1;
        break;
      case GpsSignalStrength.fair:
        color = Colors.orange;
        text = 'Fair';
        bars = 2;
        break;
      case GpsSignalStrength.good:
        color = Colors.lightGreen;
        text = 'Good';
        bars = 3;
        break;
      case GpsSignalStrength.excellent:
        color = Colors.green;
        text = 'Excellent';
        bars = 4;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, color: color, size: 16),
          const SizedBox(width: 6),
          Row(
            children: List.generate(4, (i) {
              return Container(
                width: 4,
                height: 8 + i * 3.0,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: i < bars ? color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(SessionManager manager) {
    Color color;
    String text;

    if (!manager.isRecording) {
      color = Colors.grey;
      text = 'Ready';
    } else if (manager.isPaused) {
      color = Colors.orange;
      text = 'Paused';
    } else if (manager.isAutoPaused) {
      color = Colors.yellow.shade700;
      text = 'Auto-Paused';
    } else {
      color = Colors.green;
      text = 'Recording';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge(SessionManager manager) {
    final speedKmh = manager.currentSpeed * 3.6;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            speedKmh.toStringAsFixed(1),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
          ),
          const Text('km/h', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLiveStats(SessionManager manager) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Distance',
            '${(manager.totalDistance / 1000).toStringAsFixed(2)} km'),
        _buildStatItem(
            'Max Speed', '${(manager.maxSpeed * 3.6).toStringAsFixed(1)} km/h'),
        _buildStatItem(
            'Elevation', '+${manager.elevationGain.toStringAsFixed(0)} m'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildControlButtons(SessionManager manager) {
    if (!manager.isRecording) {
      return ElevatedButton.icon(
        onPressed: () async {
          await manager.startSession();
          _startTimer();
        },
        icon: const Icon(Icons.play_arrow, size: 32),
        label: const Text('Start', style: TextStyle(fontSize: 20)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            if (manager.isPaused) {
              manager.resumeSession();
            } else {
              manager.pauseSession();
            }
          },
          icon:
              Icon(manager.isPaused ? Icons.play_arrow : Icons.pause, size: 28),
          label: Text(manager.isPaused ? 'Resume' : 'Pause',
              style: const TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: manager.isPaused ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Stop Recording?'),
                content:
                    const Text('Are you sure you want to stop this session?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Stop')),
                ],
              ),
            );
            if (confirm == true) {
              await manager.stopSession();
              _stopTimer();
            }
          },
          icon: const Icon(Icons.stop, size: 28),
          label: const Text('Stop', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
        ),
      ],
    );
  }
}

/// 方向箭头绘制器
class _HeadingArrowPainter extends CustomPainter {
  final bool isRecording;

  _HeadingArrowPainter({required this.isRecording});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isRecording ? Colors.red : Colors.orange
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final arrowLength = size.width / 2 - 4;

    // 绘制箭头（指向上方，会通过 Transform.rotate 旋转）
    final path = ui.Path();
    path.moveTo(center.dx, center.dy - arrowLength); // 箭头顶点
    path.lineTo(center.dx - 6, center.dy - arrowLength + 12); // 左边
    path.lineTo(center.dx, center.dy - arrowLength + 8); // 凹陷
    path.lineTo(center.dx + 6, center.dy - arrowLength + 12); // 右边
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadingArrowPainter oldDelegate) {
    return oldDelegate.isRecording != isRecording;
  }
}
