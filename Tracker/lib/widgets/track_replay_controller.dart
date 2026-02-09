import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/replay_state.dart';
import '../models/replay_point.dart';
import '../services/track_replay_service.dart';

/// 轨迹回放控制面板
class TrackReplayController extends StatelessWidget {
  final TrackReplayService replayService;
  final VoidCallback? onClose;
  final VoidCallback? onTap; // 用于通知父组件用户交互
  final VoidCallback? onExport; // 导出视频按钮回调
  final VoidCallback? onSeekWhileShowingMedia; // 展示媒体时拖动进度条的回调

  const TrackReplayController({
    super.key,
    required this.replayService,
    this.onClose,
    this.onTap,
    this.onExport,
    this.onSeekWhileShowingMedia,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // 触发显示控制面板
      behavior: HitTestBehavior.opaque,
      child: ListenableBuilder(
        listenable: replayService,
        builder: (context, _) {
          final state = replayService.playbackState;
          final progress = replayService.currentProgress;
          final point = replayService.currentPoint;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Row(
                  children: [
                    const Icon(Icons.play_circle,
                        color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      '3D 回放',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    // 导出视频按钮
                    if (onExport != null)
                      IconButton(
                        icon:
                            const Icon(Icons.ios_share, color: Colors.white70),
                        onPressed: () {
                          onTap?.call();
                          onExport?.call();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: '导出视频',
                      ),
                    if (onExport != null) const SizedBox(width: 8),
                    // 设置按钮
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white70),
                      onPressed: () => _showSettingsDialog(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '回放设置',
                    ),
                    const SizedBox(width: 8),
                    if (onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 海拔折线图
                if (replayService.processedPoints.isNotEmpty)
                  _ElevationChart(
                    points: replayService.processedPoints,
                    progress: progress,
                    onSeek: (value) {
                      onTap?.call();
                      // 如果正在展示媒体，先退出媒体展示
                      if (replayService.isShowingMedia) {
                        onSeekWhileShowingMedia?.call();
                      }
                      replayService.seekTo(value);
                    },
                  ),

                // 距离和进度信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDistance(replayService.totalDistance * progress),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      _formatDistance(replayService.totalDistance),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 播放控制按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 速度选择
                    _buildSpeedButton(context),
                    const SizedBox(width: 24),

                    // 主播放/暂停按钮
                    _buildPlayButton(state),
                    const SizedBox(width: 24),

                    // 重播按钮
                    IconButton(
                      icon: const Icon(Icons.replay, color: Colors.white),
                      onPressed: () {
                        onTap?.call();
                        replayService.stop();
                        replayService.play();
                      },
                    ),
                  ],
                ),

                // 当前高度信息
                if (point != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '高度: ${point.altitude.toStringAsFixed(0)}m',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayButton(ReplayPlaybackState state) {
    final isPlaying = state == ReplayPlaybackState.playing;
    final isShowingMedia = state == ReplayPlaybackState.showingMedia;

    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orange,
      ),
      child: IconButton(
        icon: Icon(
          // 展示媒体时显示跳过图标
          isShowingMedia
              ? Icons.skip_next
              : (isPlaying ? Icons.pause : Icons.play_arrow),
          color: Colors.white,
          size: 32,
        ),
        onPressed: () {
          onTap?.call();
          if (isShowingMedia) {
            // 展示媒体时点击等同于跳过
            onSeekWhileShowingMedia?.call();
            replayService.skipCurrentMedia();
          } else if (isPlaying) {
            replayService.pause();
          } else {
            replayService.play();
          }
        },
      ),
    );
  }

  Widget _buildSpeedButton(BuildContext context) {
    final config = replayService.config;
    final duration = config.totalDuration.inSeconds;
    final label = duration <= 15 ? '2x' : (duration <= 30 ? '1x' : '0.5x');

    return PopupMenuButton<ReplayConfig>(
      onOpened: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: ReplayConfig.fast,
          child: Text('快速 (15s)'),
        ),
        const PopupMenuItem(
          value: ReplayConfig.normal,
          child: Text('标准 (30s)'),
        ),
        const PopupMenuItem(
          value: ReplayConfig.scenic,
          child: Text('慢速 (45s)'),
        ),
      ],
      onSelected: (config) => replayService.setConfig(config),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    onTap?.call();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ReplaySettingsSheet(
        replayService: replayService,
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

/// 回放设置面板
class _ReplaySettingsSheet extends StatefulWidget {
  final TrackReplayService replayService;

  const _ReplaySettingsSheet({required this.replayService});

  @override
  State<_ReplaySettingsSheet> createState() => _ReplaySettingsSheetState();
}

class _ReplaySettingsSheetState extends State<_ReplaySettingsSheet> {
  late ReplayConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.replayService.config;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  '回放设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _config = const ReplayConfig());
                    _applyConfig();
                  },
                  child: const Text('重置'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 预设选择
            const Text('预设', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPresetChip('快速', ReplayConfig.fast),
                const SizedBox(width: 8),
                _buildPresetChip('标准', ReplayConfig.normal),
                const SizedBox(width: 8),
                _buildPresetChip('慢速', ReplayConfig.scenic),
              ],
            ),
            const SizedBox(height: 20),

            // 回放时长
            _buildSliderSetting(
              label: '回放时长',
              value: _config.totalDuration.inSeconds.toDouble(),
              min: 10,
              max: 120,
              divisions: 22,
              unit: '秒',
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(
                    totalDuration: Duration(seconds: value.toInt()),
                  );
                });
                _applyConfig();
              },
            ),

            // 相机缩放
            _buildSliderSetting(
              label: '相机缩放',
              value: _config.cameraZoom,
              min: 10,
              max: 20,
              divisions: 20,
              unit: '',
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(cameraZoom: value);
                });
                _applyConfig();
              },
            ),

            // 相机倾斜
            _buildSliderSetting(
              label: '相机倾斜',
              value: _config.cameraPitch,
              min: 0,
              max: 80,
              divisions: 16,
              unit: '°',
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(cameraPitch: value);
                });
                _applyConfig();
              },
            ),

            // 前瞻点数
            _buildSliderSetting(
              label: '前瞻点数',
              value: _config.lookAheadPoints.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              unit: '点',
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(lookAheadPoints: value.toInt());
                });
                _applyConfig();
              },
            ),

            // 方向平滑系数
            _buildSliderSetting(
              label: '方向平滑',
              value: _config.bearingSmoothingFactor,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              unit: '',
              valueFormatter: (v) => v.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(bearingSmoothingFactor: value);
                });
                _applyConfig();
              },
            ),

            const Divider(color: Colors.white24),
            const SizedBox(height: 8),

            // 媒体播放设置
            const Text(
              '媒体播放',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 回放时自动展示媒体开关
            SwitchListTile(
              title: const Text(
                '回放时展示照片/视频',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              subtitle: const Text(
                '轨迹经过媒体位置时自动环绕展示',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              value: _config.showMediaDuringReplay,
              activeColor: Colors.orange,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(showMediaDuringReplay: value);
                });
                _applyConfig();
              },
            ),

            // 照片展示时长
            if (_config.showMediaDuringReplay)
              _buildSliderSetting(
                label: '照片展示时长',
                value: _config.photoDisplayDuration.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                unit: '秒',
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      photoDisplayDuration: value.toInt(),
                    );
                  });
                  _applyConfig();
                },
              ),

            const SizedBox(height: 16),

            // 保存和完成按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveConfig,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('保存设置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    await _config.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildPresetChip(String label, ReplayConfig preset) {
    final isSelected = _config.totalDuration == preset.totalDuration &&
        _config.cameraPitch == preset.cameraPitch;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.orange,
      backgroundColor: Colors.grey.shade800,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _config = preset);
          _applyConfig();
        }
      },
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    String Function(double)? valueFormatter,
  }) {
    final displayValue = valueFormatter?.call(value) ??
        (value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(1));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(
                '$displayValue$unit',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.orange,
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: Colors.orange,
              overlayColor: Colors.orange.withOpacity(0.2),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _applyConfig() {
    widget.replayService.setConfig(_config);
  }
}

/// 海拔折线图组件
class _ElevationChart extends StatelessWidget {
  final List<ReplayPoint> points;
  final double progress;
  final ValueChanged<double> onSeek;

  const _ElevationChart({
    required this.points,
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTap(details, context),
      onHorizontalDragUpdate: (details) => _handleDrag(details, context),
      child: SizedBox(
        height: 60,
        child: CustomPaint(
          size: const Size(double.infinity, 60),
          painter: _ElevationChartPainter(
            points: points,
            progress: progress,
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final localX = details.localPosition.dx;
    final progress = (localX / box.size.width).clamp(0.0, 1.0);
    onSeek(progress);
  }

  void _handleDrag(DragUpdateDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final localX = details.localPosition.dx;
    final progress = (localX / box.size.width).clamp(0.0, 1.0);
    onSeek(progress);
  }
}

/// 海拔折线图绘制器
class _ElevationChartPainter extends CustomPainter {
  final List<ReplayPoint> points;
  final double progress;

  _ElevationChartPainter({
    required this.points,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 计算海拔范围
    double minAlt = double.infinity;
    double maxAlt = double.negativeInfinity;
    for (final p in points) {
      if (p.altitude < minAlt) minAlt = p.altitude;
      if (p.altitude > maxAlt) maxAlt = p.altitude;
    }

    // 确保有最小范围
    final altRange = math.max(maxAlt - minAlt, 50.0);
    final padding = altRange * 0.1;
    minAlt -= padding;
    maxAlt += padding;

    final totalDistance = points.last.cumulativeDistance;
    if (totalDistance == 0) return;

    // 绘制渐变填充
    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.cumulativeDistance / totalDistance) * size.width;
      final y = size.height -
          ((p.altitude - minAlt) / (maxAlt - minAlt)) * size.height;

      if (i == 0) {
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    // 闭合填充路径
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 绘制渐变填充
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.orange.withOpacity(0.4),
          Colors.orange.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 绘制折线
    final linePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    // 绘制当前位置指示器
    final indicatorX = progress * size.width;

    // 垂直指示线
    final indicatorLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(indicatorX, 0),
      Offset(indicatorX, size.height),
      indicatorLinePaint,
    );

    // 当前海拔点
    final currentDistance = progress * totalDistance;
    double currentAlt = points.first.altitude;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i + 1].cumulativeDistance >= currentDistance) {
        final t = (currentDistance - points[i].cumulativeDistance) /
            (points[i + 1].cumulativeDistance - points[i].cumulativeDistance);
        currentAlt = points[i].altitude +
            (points[i + 1].altitude - points[i].altitude) * t;
        break;
      }
    }
    final currentY =
        size.height - ((currentAlt - minAlt) / (maxAlt - minAlt)) * size.height;

    // 绘制当前位置圆点
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(indicatorX, currentY), 5, dotPaint);
    final dotBorderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(indicatorX, currentY), 5, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _ElevationChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.points != points;
  }
}
