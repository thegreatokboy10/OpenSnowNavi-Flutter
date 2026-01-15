import 'package:flutter/material.dart';
import '../models/replay_state.dart';
import '../services/track_replay_service.dart';

/// 轨迹回放控制面板
class TrackReplayController extends StatelessWidget {
  final TrackReplayService replayService;
  final VoidCallback? onClose;
  final VoidCallback? onTap; // 用于通知父组件用户交互

  const TrackReplayController({
    super.key,
    required this.replayService,
    this.onClose,
    this.onTap,
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
                    const Icon(Icons.play_circle, color: Colors.orange, size: 24),
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

                // 进度条
                SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: Colors.orange,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.orange,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (value) {
                      onTap?.call();
                      replayService.seekTo(value);
                    },
                  ),
                ),

                // 距离和进度信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDistance(replayService.totalDistance * progress),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      _formatDistance(replayService.totalDistance),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orange,
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
        onPressed: () {
          onTap?.call();
          if (isPlaying) {
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
    final label = duration <= 15
        ? '2x'
        : (duration <= 30 ? '1x' : '0.5x');

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
