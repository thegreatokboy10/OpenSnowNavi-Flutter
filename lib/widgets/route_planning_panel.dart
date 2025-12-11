import 'package:flutter/material.dart';
import '../route_planning/route_planning_state.dart';
import '../timer_flag.dart';

class RoutePlanningPanel extends StatefulWidget {
  final RoutePlanningData data;
  final VoidCallback onClose;
  final VoidCallback onGenerateRoute;
  final VoidCallback onAddStopover;
  final Function(int) onRemoveStopover;
  final Function(int, int) onReorderStopovers;
  final TimerFlag? timerFlag;

  const RoutePlanningPanel({
    Key? key,
    required this.data,
    required this.onClose,
    required this.onGenerateRoute,
    required this.onAddStopover,
    required this.onRemoveStopover,
    required this.onReorderStopovers,
    this.timerFlag,
  }) : super(key: key);

  @override
  State<RoutePlanningPanel> createState() => _RoutePlanningPanelState();
}

class _RoutePlanningPanelState extends State<RoutePlanningPanel> {
  void _setTimerFlag() {
    if (widget.timerFlag != null) {
      widget.timerFlag!.flag = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.directions, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '路线规划',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _setTimerFlag();
                    widget.onClose();
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),

          // 起点
          _buildRoutePointTile(
            icon: Icons.trip_origin,
            color: Colors.green,
            label: '起点',
            point: widget.data.origin,
          ),

          Divider(height: 1),

          // 途径点列表（可拖拽排序）
          if (widget.data.stopovers.isNotEmpty) ...[
            _buildStopoversList(),
            Divider(height: 1),
          ],

          // 终点
          _buildRoutePointTile(
            icon: Icons.location_on,
            color: Colors.blue,
            label: '终点',
            point: widget.data.destination,
          ),

          Divider(height: 1),

          // 操作按钮
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // 添加途径点按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _setTimerFlag();
                      widget.onAddStopover();
                    },
                    icon: Icon(Icons.add_location),
                    label: Text('添加途径点'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // 查看路线按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.data.canGenerateRoute
                        ? () {
                            _setTimerFlag();
                            widget.onGenerateRoute();
                          }
                        : null,
                    icon: Icon(Icons.navigation),
                    label: Text('查看路线'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePointTile({
    required IconData icon,
    required Color color,
    required String label,
    RoutePoint? point,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(
        point?.name ?? '点击地图选择$label',
        style: TextStyle(
          color: point != null ? Colors.black87 : Colors.grey,
          fontStyle: point != null ? FontStyle.normal : FontStyle.italic,
        ),
      ),
      subtitle: point != null
          ? Text(
              '${point.coordinates.latitude.toStringAsFixed(5)}, ${point.coordinates.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      dense: true,
    );
  }

  Widget _buildStopoversList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: widget.data.stopovers.length,
      onReorder: (oldIndex, newIndex) {
        _setTimerFlag();
        widget.onReorderStopovers(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final stopover = widget.data.stopovers[index];
        return ListTile(
          key: ValueKey(stopover.id),
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            stopover.name,
            style: TextStyle(fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_handle, color: Colors.grey),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: () {
                  _setTimerFlag();
                  widget.onRemoveStopover(index);
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          dense: true,
        );
      },
    );
  }
}
