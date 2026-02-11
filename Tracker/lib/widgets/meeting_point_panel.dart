import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../config/app_theme.dart';
import '../meeting_point/meeting_point_model.dart';
import '../meeting_point/meeting_point_service.dart';

/// 集合点列表回调
typedef OnMeetingPointTapped = void Function(MeetingPoint point);
typedef OnNavigateToMeetingPoint = void Function(MeetingPoint point);

/// 集合点面板 - 显示团队集合点列表
class MeetingPointPanel extends StatefulWidget {
  final String teamId;
  final VoidCallback? onClose;
  final OnMeetingPointTapped? onPointTapped;
  final OnNavigateToMeetingPoint? onNavigate;

  const MeetingPointPanel({
    super.key,
    required this.teamId,
    this.onClose,
    this.onPointTapped,
    this.onNavigate,
  });

  @override
  State<MeetingPointPanel> createState() => _MeetingPointPanelState();
}

class _MeetingPointPanelState extends State<MeetingPointPanel> {
  final MeetingPointService _service = MeetingPointService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();

    // 监听更新
    _service.onMeetingPointsUpdated = (points) {
      if (mounted) setState(() {});
    };
  }

  Future<void> _loadPoints() async {
    await _service.loadMeetingPoints();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Flexible(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _service.meetingPoints.isEmpty
                  ? _buildEmptyState()
                  : _buildPointsList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: const BoxDecoration(
        color: AppTheme.panelHeaderBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: AppTheme.panelHeaderText),
              const SizedBox(width: 8),
              Text(
                l10n.meetingPoints,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.panelHeaderText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.refresh, color: AppTheme.panelHeaderText),
                onPressed: _loadPoints,
                tooltip: l10n.refresh,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.panelHeaderText),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_border, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            l10n.noMeetingPoints,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.longPressToAddMeetingPoint,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPointsList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _service.meetingPoints.length,
      itemBuilder: (context, index) {
        final point = _service.meetingPoints[index];
        return _buildPointItem(point);
      },
    );
  }

  Widget _buildPointItem(MeetingPoint point) {
    final l10n = S.of(context)!;
    return ListTile(
      leading: Icon(
        point.isActive ? Icons.flag : Icons.star,
        color: point.isActive
            ? AppTheme.meetingPointActiveColor
            : AppTheme.meetingPointColor,
        size: 28,
      ),
      title: Text(
        point.name,
        style: TextStyle(
          fontWeight: point.isActive ? FontWeight.bold : FontWeight.normal,
          color: point.isActive ? AppTheme.primaryColor : null,
        ),
      ),
      subtitle: Text(
        l10n.createdBy(point.creatorNickname),
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 设为当前集合点
          IconButton(
            icon: Icon(
              point.isActive ? Icons.check_circle : Icons.check_circle_outline,
              color: point.isActive ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            onPressed: () => _toggleActive(point),
            tooltip: point.isActive
                ? l10n.cancelCurrentMeetingPoint
                : l10n.setAsCurrentMeetingPoint,
          ),
          // 编辑名称
          IconButton(
            icon:
                Icon(Icons.edit, color: AppTheme.primaryColor.withOpacity(0.7)),
            onPressed: () => _editPointName(point),
            tooltip: l10n.editMeetingPointName,
          ),
          // 删除
          IconButton(
            icon:
                Icon(Icons.delete, color: AppTheme.errorColor.withOpacity(0.7)),
            onPressed: () => _deletePoint(point),
            tooltip: l10n.delete,
          ),
          // 导航
          IconButton(
            icon: const Icon(Icons.navigation, color: AppTheme.primaryColor),
            onPressed: () => widget.onNavigate?.call(point),
            tooltip: l10n.navigateToMeetingPoint,
          ),
        ],
      ),
      onTap: () => widget.onPointTapped?.call(point),
    );
  }

  Future<void> _toggleActive(MeetingPoint point) async {
    if (point.isActive) {
      await _service.clearActiveMeetingPoint();
    } else {
      await _service.setActiveMeetingPoint(point.id);
    }
  }

  Future<void> _editPointName(MeetingPoint point) async {
    final l10n = S.of(context)!;
    final controller = TextEditingController(text: point.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editMeetingPointName),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.name,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != point.name) {
      await _service.updateMeetingPointName(point.id, newName);
    }
  }

  Future<void> _deletePoint(MeetingPoint point) async {
    final l10n = S.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMeetingPoint),
        content: Text(l10n.deleteMeetingPointConfirm(point.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteMeetingPoint(point.id);
    }
  }
}
