import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video_export_config.dart';
import '../services/video_export_service.dart';

/// 视频导出设置对话框
class VideoExportSettingsDialog extends StatefulWidget {
  final VideoExportConfig initialConfig;
  final VoidCallback onStartExport;

  const VideoExportSettingsDialog({
    super.key,
    required this.initialConfig,
    required this.onStartExport,
  });

  @override
  State<VideoExportSettingsDialog> createState() =>
      _VideoExportSettingsDialogState();

  /// 显示导出设置对话框
  static Future<VideoExportConfig?> show(
    BuildContext context, {
    VideoExportConfig? initialConfig,
  }) async {
    final config = initialConfig ?? await VideoExportConfig.load();

    if (!context.mounted) return null;

    return showModalBottomSheet<VideoExportConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VideoExportSettingsSheet(initialConfig: config),
    );
  }
}

class _VideoExportSettingsDialogState extends State<VideoExportSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

/// 导出设置底部弹窗
class _VideoExportSettingsSheet extends StatefulWidget {
  final VideoExportConfig initialConfig;

  const _VideoExportSettingsSheet({required this.initialConfig});

  @override
  State<_VideoExportSettingsSheet> createState() =>
      _VideoExportSettingsSheetState();
}

class _VideoExportSettingsSheetState extends State<_VideoExportSettingsSheet> {
  late VideoExportConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    '导出视频',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 设置项
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 媒体导出模式
                  const Text(
                    '轨迹上的视频',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMediaModeOption(
                    MediaExportMode.fullPlayback,
                    '完整播放',
                    '播放轨迹上的完整视频',
                  ),
                  _buildMediaModeOption(
                    MediaExportMode.fixedDuration,
                    '固定时长后跳过',
                    '播放固定秒数后跳过',
                  ),
                  // 时长滑块
                  if (_config.mediaMode == MediaExportMode.fixedDuration)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, right: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _config.maxVideoClipDuration.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '${_config.maxVideoClipDuration}秒',
                              onChanged: (value) {
                                setState(() {
                                  _config = _config.copyWith(
                                    maxVideoClipDuration: value.toInt(),
                                  );
                                });
                              },
                            ),
                          ),
                          Text(
                            '${_config.maxVideoClipDuration}秒',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildMediaModeOption(
                    MediaExportMode.skipMedia,
                    '不包含视频',
                    '跳过所有照片和视频',
                  ),

                  const SizedBox(height: 16),

                  // 音频录制提示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.mic, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '需要麦克风权限才能录制视频中的声音',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 开始导出按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _config.save();
                    if (mounted) {
                      Navigator.pop(context, _config);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '开始导出',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaModeOption(
    MediaExportMode mode,
    String title,
    String subtitle,
  ) {
    return RadioListTile<MediaExportMode>(
      value: mode,
      groupValue: _config.mediaMode,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _config = _config.copyWith(mediaMode: value);
          });
        }
      },
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 录制进度覆盖层
class VideoExportRecordingOverlay extends StatefulWidget {
  final VideoExportService exportService;
  final VoidCallback onCancel;
  final Duration estimatedDuration;

  const VideoExportRecordingOverlay({
    super.key,
    required this.exportService,
    required this.onCancel,
    required this.estimatedDuration,
  });

  @override
  State<VideoExportRecordingOverlay> createState() =>
      _VideoExportRecordingOverlayState();
}

class _VideoExportRecordingOverlayState
    extends State<VideoExportRecordingOverlay> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = widget.exportService.recordingDuration;
      });
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 录制指示器
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'REC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            // 时间
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            // 取消按钮
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导出完成对话框
class VideoExportCompletionDialog extends StatelessWidget {
  final VideoExportService exportService;
  final VoidCallback onSaveToGallery;
  final VoidCallback onShare;
  final VoidCallback onClose;

  const VideoExportCompletionDialog({
    super.key,
    required this.exportService,
    required this.onSaveToGallery,
    required this.onShare,
    required this.onClose,
  });

  /// 显示完成对话框
  static Future<void> show(
    BuildContext context, {
    required VideoExportService exportService,
    required VoidCallback onSaveToGallery,
    required VoidCallback onShare,
    required VoidCallback onClose,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VideoExportCompletionDialog(
        exportService: exportService,
        onSaveToGallery: onSaveToGallery,
        onShare: onShare,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '导出完成',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 视频预览（缩略图）
            FutureBuilder<Map<String, dynamic>?>(
              future: exportService.getVideoInfo(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 视频缩略图
                      if (exportService.outputPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      // 视频信息
                      if (info != null)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              info['sizeFormatted'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSaveToGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('保存相册'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('分享'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
