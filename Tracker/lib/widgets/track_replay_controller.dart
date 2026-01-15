import 'package:flutter/material.dart';
import '../models/replay_state.dart';
import '../services/track_replay_service.dart';

/// 轨迹回放控制面板
class TrackReplayController extends StatelessWidget {
  final TrackReplayService replayService;
  final VoidCallback? onClose;

  const TrackReplayController({
    super.key,
    required this.replayService,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
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
                  onChanged: (value) => replayService.seekTo(value),
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
        onPressed: isPlaying ? replayService.pause : replayService.play,
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

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}
