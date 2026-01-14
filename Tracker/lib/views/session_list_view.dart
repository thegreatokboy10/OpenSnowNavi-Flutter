import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../services/session_manager.dart';
import '../services/track_export_service.dart';
import 'session_detail_view.dart';

/// 历史记录列表视图
class SessionListView extends StatefulWidget {
  const SessionListView({super.key});

  @override
  State<SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends State<SessionListView> {
  List<Session> _sessions = [];
  bool _isLoading = true;
  bool _wasRecording = false; // 追踪上一次的录制状态

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // 监听 SessionManager 变化以自动刷新（仅在录制结束时）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<SessionManager>();
      _wasRecording = manager.isRecording;
      manager.addListener(_onSessionManagerChanged);
    });
  }

  @override
  void dispose() {
    // 移除监听
    context.read<SessionManager>().removeListener(_onSessionManagerChanged);
    super.dispose();
  }

  void _onSessionManagerChanged() {
    // 只在录制状态从 true 变为 false 时刷新列表（即录制结束时）
    final manager = context.read<SessionManager>();
    final isRecording = manager.isRecording;

    if (_wasRecording && !isRecording) {
      // 录制刚结束，刷新列表
      debugPrint('[SessionListView] Recording ended, refreshing list');
      _loadSessions();
    }

    _wasRecording = isRecording;
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final manager = context.read<SessionManager>();
    final sessions = await manager.fetchSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _exportTracks() async {
    final filePath = await TrackExportService.exportAllTracks();
    if (filePath != null && mounted) {
      await TrackExportService.shareExport();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的轨迹')),
      );
    }
  }

  Future<void> _importTracks() async {
    final result = await TrackExportService.importTracks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success && result.importedCount > 0) {
        _loadSessions();
      }
    }
  }

  void _showExportImportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '数据管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('导出所有轨迹'),
              subtitle: const Text('备份到 ZIP 文件并分享'),
              onTap: () {
                Navigator.pop(ctx);
                _exportTracks();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('导入轨迹'),
              subtitle: const Text('从备份文件恢复'),
              onTap: () {
                Navigator.pop(ctx);
                _importTracks();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: '数据管理',
            onPressed: _showExportImportMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _buildSessionCard(session);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No sessions yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Start recording to see your sessions here',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final distanceKm = session.totalDistance / 1000;
    final maxSpeedKmh = session.maxSpeed * 3.6;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SessionDetailView(session: session)),
          );
          _loadSessions();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateFormat.format(session.startTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(session),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                      'Duration', _formatDuration(session.totalDuration)),
                  _buildStatColumn(
                      'Distance', '${distanceKm.toStringAsFixed(2)} km'),
                  _buildStatColumn(
                      'Max Speed', '${maxSpeedKmh.toStringAsFixed(1)} km/h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Future<void> _confirmDelete(Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final manager = context.read<SessionManager>();
      await manager.deleteSession(session.id);
      _loadSessions();
    }
  }
}
