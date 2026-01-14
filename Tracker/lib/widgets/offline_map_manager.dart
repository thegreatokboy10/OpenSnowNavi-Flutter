import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../config/ski_resorts.dart';
import '../services/offline_cache_service.dart';
import '../services/offline_route_service.dart';

/// 离线地图管理器 - 显示雪场离线地图下载状态和操作
class OfflineMapManager extends StatefulWidget {
  final VoidCallback? onClose;

  const OfflineMapManager({super.key, this.onClose});

  @override
  State<OfflineMapManager> createState() => _OfflineMapManagerState();
}

class _OfflineMapManagerState extends State<OfflineMapManager>
    with SingleTickerProviderStateMixin {
  final OfflineMapCacheService _cacheService = OfflineMapCacheService.instance;
  final OfflineRouteService _routeService = OfflineRouteService.instance;
  late TabController _tabController;
  bool _isInitialized = false;
  Map<String, String> _importedNavFiles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _cacheService.initialize();
    await _routeService.initialize();
    _importedNavFiles = await _routeService.getImportedNavFiles();

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

    return Container(
      constraints: const BoxConstraints(maxWidth: 350, maxHeight: 550),
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.download_for_offline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '离线数据管理',
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
            // Tab 栏
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: '离线地图'),
                Tab(text: '导航数据'),
              ],
            ),
            // Tab 内容
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMapTab(),
                  _buildNavigationTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 离线地图 Tab
  Widget _buildMapTab() {
    final cachedResorts = _cacheService.getCachedResorts();

    return Column(
      children: [
        // 说明文字
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '下载雪场地图后，可在无网络时查看地图',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        // 雪场列表
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SkiResorts.list.length,
            itemBuilder: (context, index) {
              final resortKey = SkiResorts.list.keys.elementAt(index);
              final isCached = cachedResorts.contains(resortKey);
              final isDownloading = _cacheService.isDownloading(resortKey);
              final progress = _cacheService.getDownloadProgress(resortKey);

              return _buildMapResortItem(
                resortKey: resortKey,
                isCached: isCached,
                isDownloading: isDownloading,
                progress: progress,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapResortItem({
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

  /// 导航数据 Tab
  Widget _buildNavigationTab() {
    return Column(
      children: [
        // 说明文字
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '导入雪场导航数据后，可使用离线路线规划',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        // 导入按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _importNavigationFile,
              icon: const Icon(Icons.add),
              label: const Text('导入导航文件'),
            ),
          ),
        ),
        const Divider(),
        // 已导入的文件列表
        Expanded(
          child: _importedNavFiles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.navigation_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          '暂无导航数据',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '点击上方按钮导入 .sqlite 文件',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _importedNavFiles.length,
                  itemBuilder: (context, index) {
                    final entry = _importedNavFiles.entries.elementAt(index);
                    return _buildNavFileItem(entry.key, entry.value);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNavFileItem(String resortKey, String displayName) {
    final resort = SkiResorts.list[resortKey];
    String title = displayName;
    String? subtitle;
    String? flag;

    if (resort != null) {
      final names = resort['name'] as Map<String, dynamic>;
      final country = resort['country'] as String;
      flag = SkiResorts.getFlagEmoji(country);
      title = names['cn'] ?? names['en'] ?? resortKey;
      subtitle = displayName;
    }

    return ListTile(
      leading: flag != null
          ? Text(flag, style: const TextStyle(fontSize: 24))
          : const Icon(Icons.navigation, color: Colors.green),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _deleteNavFile(resortKey, displayName),
        tooltip: '删除',
      ),
    );
  }

  Future<void> _importNavigationFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        _showError('无法访问文件');
        return;
      }

      // 检查文件扩展名
      if (!file.name.endsWith('.sqlite')) {
        _showError('请选择 .sqlite 格式的导航文件');
        return;
      }

      // 显示选择雪场对话框
      final selectedResort = await _showResortSelectionDialog(file.name);
      if (selectedResort == null) return;

      // 导入文件
      final success = await _routeService.importNavFile(
        file.path!,
        selectedResort,
        file.name,
      );

      if (success) {
        _importedNavFiles = await _routeService.getImportedNavFiles();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('导航数据导入成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showError('导入失败，文件可能无效');
      }
    } catch (e) {
      _showError('导入失败: $e');
    }
  }

  Future<String?> _showResortSelectionDialog(String fileName) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择关联雪场'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: SkiResorts.list.length,
            itemBuilder: (context, index) {
              final resortKey = SkiResorts.list.keys.elementAt(index);
              final resort = SkiResorts.list[resortKey]!;
              final names = resort['name'] as Map<String, dynamic>;
              final country = resort['country'] as String;
              final flag = SkiResorts.getFlagEmoji(country);
              final hasImported = _importedNavFiles.containsKey(resortKey);

              return ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 20)),
                title: Text(names['cn'] ?? names['en'] ?? resortKey),
                trailing: hasImported
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, resortKey),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNavFile(String resortKey, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除导航数据'),
        content: Text('确定要删除 "$displayName" 吗？'),
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
      await _routeService.removeImportedNavFile(resortKey);
      _importedNavFiles = await _routeService.getImportedNavFiles();
      setState(() {});
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
