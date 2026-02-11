import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../models/session_media.dart';
import '../services/media_gallery_service.dart';

/// 全屏媒体查看器对话框 - 支持滑动浏览所有媒体和筛选功能
class MediaViewerDialog extends StatefulWidget {
  /// 所有媒体列表（按时间排序）
  final List<SessionMedia> allMedia;

  /// 初始显示的媒体索引
  final int initialIndex;

  /// 当前选中的媒体ID（用于筛选功能）
  final Set<String>? selectedIds;

  /// 选择变更回调
  final ValueChanged<Set<String>>? onSelectionChanged;

  const MediaViewerDialog({
    super.key,
    required this.allMedia,
    required this.initialIndex,
    this.selectedIds,
    this.onSelectionChanged,
  });

  /// 是否启用筛选模式
  bool get hasSelectionMode => selectedIds != null && onSelectionChanged != null;

  @override
  State<MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<MediaViewerDialog> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;

  // 媒体文件缓存
  final Map<int, File?> _fileCache = {};
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _loadingStates = {};

  // 缩略图缓存
  final Map<String, Uint8List?> _thumbnailCache = {};

  // 筛选相关状态
  bool _isSelectionMode = false;
  late Set<String> _selectedIds;

  static const double _thumbnailSize = 60;
  static const double _thumbnailSpacing = 8;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    // 初始化选中状态
    _selectedIds = widget.selectedIds != null
        ? Set.from(widget.selectedIds!)
        : widget.allMedia.map((m) => m.id).toSet();

    // 预加载当前和相邻媒体
    _preloadMedia(_currentIndex);
    _loadAllThumbnails();

    // 初始滚动到当前位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailToIndex(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    // 释放所有视频控制器
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  /// 加载所有缩略图
  Future<void> _loadAllThumbnails() async {
    final mediaService = MediaGalleryService();
    for (final media in widget.allMedia) {
      if (_thumbnailCache.containsKey(media.id)) continue;
      final thumbnail = await mediaService.getThumbnail(media.id, size: 100);
      if (mounted) {
        setState(() {
          _thumbnailCache[media.id] = thumbnail;
        });
      }
    }
  }

  /// 预加载媒体文件
  Future<void> _preloadMedia(int index) async {
    // 加载当前
    await _loadMediaAt(index);
    // 预加载前后
    if (index > 0) _loadMediaAt(index - 1);
    if (index < widget.allMedia.length - 1) _loadMediaAt(index + 1);
  }

  /// 加载指定索引的媒体
  Future<void> _loadMediaAt(int index) async {
    if (_fileCache.containsKey(index)) return;
    if (_loadingStates[index] == true) return;

    _loadingStates[index] = true;

    try {
      final media = widget.allMedia[index];
      final mediaService = MediaGalleryService();

      File? file;
      if (media.type == MediaType.video) {
        file = await mediaService.getOriginFile(media.id);
      } else {
        file = await mediaService.getMediaFile(media.id);
      }

      _fileCache[index] = file;

      // 初始化视频控制器
      if (file != null && media.type == MediaType.video) {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        await controller.setLooping(true);
        _videoControllers[index] = controller;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[MediaViewerDialog] Failed to load media at $index: $e');
      _fileCache[index] = null;
    } finally {
      _loadingStates[index] = false;
    }
  }

  /// 滚动缩略图列表到指定索引
  void _scrollThumbnailToIndex(int index, {bool animate = true}) {
    if (!_thumbnailScrollController.hasClients) return;

    const itemWidth = _thumbnailSize + _thumbnailSpacing;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    final maxOffset = _thumbnailScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    if (animate) {
      _thumbnailScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _thumbnailScrollController.jumpTo(clampedOffset);
    }
  }

  /// 切换到指定索引
  void _goToIndex(int index) {
    if (index == _currentIndex) return;

    // 暂停当前视频
    _videoControllers[_currentIndex]?.pause();

    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _scrollThumbnailToIndex(index);
    _preloadMedia(index);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 主要媒体区域 - PageView
            Positioned.fill(
              bottom: 100 + MediaQuery.of(context).padding.bottom,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.allMedia.length,
                onPageChanged: (index) {
                  // 暂停之前的视频
                  _videoControllers[_currentIndex]?.pause();
                  setState(() => _currentIndex = index);
                  _scrollThumbnailToIndex(index);
                  _preloadMedia(index);
                },
                itemBuilder: (context, index) => _buildMediaPage(index),
              ),
            ),

            // 顶部工具栏
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _isSelectionMode
                  ? _buildSelectionToolbar()
                  : _buildNormalToolbar(),
            ),

            // 底部缩略图列表
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildThumbnailStrip(),
            ),

            // 筛选模式下的确认按钮
            if (_isSelectionMode)
              Positioned(
                bottom: 110 + MediaQuery.of(context).padding.bottom,
                left: 16,
                right: 16,
                child: _buildSelectionActions(),
              ),
          ],
        ),
      ),
    );
  }

  /// 普通模式工具栏
  Widget _buildNormalToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 筛选按钮（仅在有筛选功能时显示）
        if (widget.hasSelectionMode)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list, color: Colors.white, size: 24),
                  if (_selectedIds.length < widget.allMedia.length)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_selectedIds.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => setState(() => _isSelectionMode = true),
              tooltip: '筛选媒体',
            ),
          )
        else
          const SizedBox(width: 48),

        // 页码指示器
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${_currentIndex + 1} / ${widget.allMedia.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // 关闭按钮
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  /// 筛选模式工具栏
  Widget _buildSelectionToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isSelectionMode = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '已选 ${_selectedIds.length}/${widget.allMedia.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(
              _selectedIds.length == widget.allMedia.length ? '取消全选' : '全选',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 筛选模式操作按钮
  Widget _buildSelectionActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _toggleCurrentSelection,
            icon: Icon(
              _selectedIds.contains(widget.allMedia[_currentIndex].id)
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
            label: Text(
              _selectedIds.contains(widget.allMedia[_currentIndex].id)
                  ? '已选中'
                  : '未选中',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedIds.contains(widget.allMedia[_currentIndex].id)
                  ? Colors.orange
                  : Colors.grey.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(S.of(context)!.confirmFilter),
          ),
        ),
      ],
    );
  }

  /// 切换全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == widget.allMedia.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = widget.allMedia.map((m) => m.id).toSet();
      }
    });
  }

  /// 切换当前媒体选中状态
  void _toggleCurrentSelection() {
    final currentId = widget.allMedia[_currentIndex].id;
    setState(() {
      if (_selectedIds.contains(currentId)) {
        _selectedIds.remove(currentId);
      } else {
        _selectedIds.add(currentId);
      }
    });
  }

  /// 确认筛选
  void _confirmSelection() {
    widget.onSelectionChanged?.call(_selectedIds);
    setState(() => _isSelectionMode = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.filteredMediaCount(_selectedIds.length)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 构建单个媒体页面
  Widget _buildMediaPage(int index) {
    final media = widget.allMedia[index];
    final file = _fileCache[index];
    final isLoading = _loadingStates[index] == true || !_fileCache.containsKey(index);

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (file == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 媒体内容
        media.type == MediaType.photo
            ? _buildPhotoViewer(file)
            : _buildVideoViewer(index),

        // 媒体信息
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildMediaInfo(media),
        ),
      ],
    );
  }

  Widget _buildPhotoViewer(File file) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: Image.file(file, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildVideoViewer(int index) {
    final controller = _videoControllers[index];
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 56),
            ),
          Positioned(
            bottom: 80,
            left: 32,
            right: 32,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.orange,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaInfo(SessionMedia media) {
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(media.captureTime);
    final durationStr = media.duration != null ? _formatDuration(media.duration!) : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                media.type == MediaType.photo ? Icons.photo : Icons.videocam,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (durationStr != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.timer, color: Colors.white.withOpacity(0.7), size: 14),
                const SizedBox(width: 4),
                Text(
                  durationStr,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white.withOpacity(0.7), size: 14),
              const SizedBox(width: 4),
              Text(
                '${media.latitude.toStringAsFixed(6)}, ${media.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建底部缩略图列表
  Widget _buildThumbnailStrip() {
    return Container(
      height: 100 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.builder(
              controller: _thumbnailScrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: (MediaQuery.of(context).size.width - _thumbnailSize) / 2,
              ),
              itemCount: widget.allMedia.length,
              itemBuilder: (context, index) => _buildThumbnailItem(index),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  /// 构建单个缩略图项
  Widget _buildThumbnailItem(int index) {
    final media = widget.allMedia[index];
    final isCurrent = index == _currentIndex;
    final isMediaSelected = _selectedIds.contains(media.id);
    final thumbnail = _thumbnailCache[media.id];

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          // 筛选模式下，点击切换选中状态
          setState(() {
            if (isMediaSelected) {
              _selectedIds.remove(media.id);
            } else {
              _selectedIds.add(media.id);
            }
          });
        } else {
          _goToIndex(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _thumbnailSize,
        height: _thumbnailSize,
        margin: const EdgeInsets.only(right: _thumbnailSpacing),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? Colors.orange : Colors.white30,
            width: isCurrent ? 3 : 1,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 缩略图
              if (thumbnail != null)
                Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  color: isCurrent ? null : Colors.white.withOpacity(0.7),
                  colorBlendMode: BlendMode.modulate,
                )
              else
                Container(
                  color: Colors.grey.shade800,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                ),
              // 视频图标
              if (media.type == MediaType.video)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              // 筛选模式选中指示器
              if (_isSelectionMode)
                Positioned(
                  left: 2,
                  top: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isMediaSelected ? Colors.orange : Colors.black54,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isMediaSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                ),
              // 未选中遮罩（筛选模式）
              if (_isSelectionMode && !isMediaSelected)
                Container(
                  color: Colors.black.withOpacity(0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
