import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
        final l10n = S.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.offlineMapDownloaded(_getResortName(resortKey))),
            backgroundColor: Colors.green,
          ),
        );
      }
    };

    _cacheService.onDownloadError = (resortKey, error) {
      if (mounted) {
        setState(() {});
        final l10n = S.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.downloadFailed(error)),
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
    final l10n = S.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteOfflineMap),
        content: Text(l10n.deleteOfflineMapConfirm(_getResortName(resortKey))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
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
    final l10n = S.of(context)!;
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
                  Expanded(
                    child: Text(
                      l10n.offlineDataManagement,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
              tabs: [
                Tab(text: l10n.offlineMaps),
                Tab(text: l10n.navigationData),
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
    final l10n = S.of(context)!;
    final cachedResorts = _cacheService.getCachedResorts();

    return Column(
      children: [
        // 说明文字
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.downloadMapsForOffline,
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
    final l10n = S.of(context)!;
    final resort = SkiResorts.list[resortKey]!;
    final names = resort['name'] as Map<String, dynamic>;
    final country = resort['country'] as String;
    final flag = SkiResorts.getFlagEmoji(country);

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(names['cn'] ?? names['en'] ?? resortKey),
      subtitle: isDownloading && progress != null
          ? LinearProgressIndicator(value: progress)
          : Text(isCached ? l10n.downloaded : l10n.notDownloaded),
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
                  tooltip: l10n.delete,
                )
              : IconButton(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  onPressed: () => _downloadResort(resortKey),
                  tooltip: l10n.download,
                ),
    );
  }

  /// 导航数据 Tab
  Widget _buildNavigationTab() {
    final l10n = S.of(context)!;
    return Column(
      children: [
        // 说明文字
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.importNavDataForOffline,
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
              label: Text(l10n.importNavFile),
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
                          l10n.noNavigationData,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.clickToImportSqlite,
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
    final l10n = S.of(context)!;
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
        tooltip: l10n.delete,
      ),
    );
  }

  Future<void> _importNavigationFile() async {
    final l10n = S.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        _showError(l10n.cannotAccessFile);
        return;
      }

      // 检查文件扩展名
      if (!file.name.endsWith('.sqlite')) {
        _showError(l10n.pleaseSelectSqliteFile);
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
            SnackBar(
              content: Text(l10n.navDataImportSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showError(l10n.importFailed);
      }
    } catch (e) {
      _showError('${l10n.importFailed}: $e');
    }
  }

  Future<String?> _showResortSelectionDialog(String fileName) async {
    final l10n = S.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectResortForNavFile),
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
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNavFile(String resortKey, String displayName) async {
    final l10n = S.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNavData),
        content: Text(l10n.deleteNavDataConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
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
