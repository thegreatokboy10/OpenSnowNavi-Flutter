import 'package:flutter/material.dart';
import '../config/ski_resorts.dart';
import '../services/offline_cache_service.dart';

/// 离线地图管理器 - 显示雪场离线地图下载状态和操作
class OfflineMapManager extends StatefulWidget {
  final VoidCallback? onClose;

  const OfflineMapManager({super.key, this.onClose});

  @override
  State<OfflineMapManager> createState() => _OfflineMapManagerState();
}

class _OfflineMapManagerState extends State<OfflineMapManager> {
  final OfflineMapCacheService _cacheService = OfflineMapCacheService.instance;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _cacheService.initialize();

    // 使用 Service 层的回调来更新 UI
    _cacheService.onDownloadProgress = (resortKey, progress) {
      if (mounted) {
        setState(() {}); // 触发重绘，从 Service 获取最新状态
      }
    };

    _cacheService.onDownloadComplete = (resortKey) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getResortName(resortKey)} 离线地图下载完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    };

    _cacheService.onDownloadError = (resortKey, error) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    setState(() => _isInitialized = true);
  }

  String _getResortName(String resortKey) {
    final resort = SkiResorts.list[resortKey];
    if (resort == null) return resortKey;
    final names = resort['name'] as Map<String, dynamic>?;
    return names?['cn'] ?? names?['en'] ?? resortKey;
  }

  Future<void> _downloadResort(String resortKey) async {
    // Service 层会处理状态管理
    await _cacheService.downloadResortMap(resortKey);
    if (mounted) setState(() {});
  }

  Future<void> _deleteResort(String resortKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除离线地图'),
        content: Text('确定要删除 ${_getResortName(resortKey)} 的离线地图吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cacheService.removeResortCache(resortKey);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final cachedResorts = _cacheService.getCachedResorts();

    return Container(
      constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.download_for_offline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '离线地图',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 说明文字
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '下载雪场地图后，可在无网络时查看地图',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            // 雪场列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: SkiResorts.list.length,
                itemBuilder: (context, index) {
                  final resortKey = SkiResorts.list.keys.elementAt(index);
                  final isCached = cachedResorts.contains(resortKey);
                  // 从 Service 层获取下载状态
                  final isDownloading = _cacheService.isDownloading(resortKey);
                  final progress = _cacheService.getDownloadProgress(resortKey);

                  return _buildResortItem(
                    resortKey: resortKey,
                    isCached: isCached,
                    isDownloading: isDownloading,
                    progress: progress,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResortItem({
    required String resortKey,
    required bool isCached,
    required bool isDownloading,
    double? progress,
  }) {
    final resort = SkiResorts.list[resortKey]!;
    final names = resort['name'] as Map<String, dynamic>;
    final country = resort['country'] as String;
    final flag = SkiResorts.getFlagEmoji(country);

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(names['cn'] ?? names['en'] ?? resortKey),
      subtitle: isDownloading && progress != null
          ? LinearProgressIndicator(value: progress)
          : Text(isCached ? '已下载' : '未下载'),
      trailing: isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCached
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteResort(resortKey),
                  tooltip: '删除',
                )
              : IconButton(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  onPressed: () => _downloadResort(resortKey),
                  tooltip: '下载',
                ),
    );
  }
}
