import 'package:flutter/material.dart';
import '../meeting_point/meeting_point_model.dart';
import '../meeting_point/meeting_point_service.dart';
import '../timer_flag.dart';

/// 集合点列表回调
typedef OnMeetingPointTapped = void Function(MeetingPoint point);
typedef OnNavigateToMeetingPoint = void Function(MeetingPoint point);

/// 集合点面板 - 显示团队集合点列表
class MeetingPointPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final OnMeetingPointTapped? onPointTapped;
  final OnNavigateToMeetingPoint? onNavigate;
  final TimerFlag? timerFlag; // 用于阻止点击事件传递到地图

  const MeetingPointPanel({
    super.key,
    this.onClose,
    this.onPointTapped,
    this.onNavigate,
    this.timerFlag,
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
    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          _buildHeader(),
          Divider(height: 1),
          // 内容
          Flexible(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _service.meetingPoints.isEmpty
                    ? _buildEmptyState()
                    : _buildPointsList(),
          ),
        ],
      ),
    );
  }

  /// 设置 timerFlag 防止点击事件传递到地图
  void _setTimerFlag() {
    widget.timerFlag?.flag = true;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text(
                '集合点',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.deepOrange),
                onPressed: () {
                  _setTimerFlag();
                  _loadPoints();
                },
                tooltip: '刷新',
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  _setTimerFlag();
                  widget.onClose?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '暂无集合点',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            '在地图上选择位置后点击"添加集合点"来添加',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
    return ListTile(
      leading: Icon(
        // active用终点图标，非active用五角星
        point.isActive ? Icons.flag : Icons.star,
        color: point.isActive ? Colors.deepOrange : Colors.deepOrange.shade300,
        size: 28,
      ),
      title: Text(
        point.name,
        style: TextStyle(
          fontWeight: point.isActive ? FontWeight.bold : FontWeight.normal,
          color: point.isActive ? Colors.deepOrange : null,
        ),
      ),
      subtitle: Text(
        '由 ${point.creatorNickname} 创建',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 设为当前集合点
          IconButton(
            icon: Icon(
              point.isActive ? Icons.check_circle : Icons.check_circle_outline,
              color: point.isActive ? Colors.deepOrange : Colors.grey,
            ),
            onPressed: () {
              _setTimerFlag();
              _toggleActive(point);
            },
            tooltip: point.isActive ? '取消设为当前集合点' : '设为当前集合点',
          ),
          // 编辑名称
          IconButton(
            icon: Icon(Icons.edit, color: Colors.deepOrange.shade300),
            onPressed: () {
              _setTimerFlag();
              _editPointName(point);
            },
            tooltip: '编辑名称',
          ),
          // 删除
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade300),
            onPressed: () {
              _setTimerFlag();
              _deletePoint(point);
            },
            tooltip: '删除',
          ),
          // 导航
          IconButton(
            icon: Icon(Icons.navigation, color: Colors.deepOrange),
            onPressed: () {
              _setTimerFlag();
              widget.onNavigate?.call(point);
            },
            tooltip: '导航到此处',
          ),
        ],
      ),
      onTap: () {
        _setTimerFlag();
        widget.onPointTapped?.call(point);
      },
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
    final controller = TextEditingController(text: point.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑集合点名称'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('保存'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != point.name) {
      await _service.updateMeetingPointName(point.id, newName);
    }
  }

  Future<void> _deletePoint(MeetingPoint point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除集合点'),
        content: Text('确定要删除集合点 "${point.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteMeetingPoint(point.id);
    }
  }
}
