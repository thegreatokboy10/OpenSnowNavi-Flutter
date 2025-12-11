import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../route_planning/route_planning_state.dart';
import '../timer_flag.dart';
import '../route_engine.dart' as re;
import '../search_service.dart';
import '../global_constants.dart';
import '../l10n/locale_service.dart';

/// 正在编辑的点位类型
enum EditingPointType { none, origin, destination, stopover, newStopover }

class RoutePlanningPanel extends StatefulWidget {
  final RoutePlanningData data;
  final re.Route? route; // 当前路线结果
  final LatLng? resortCoordinate; // 雪场中心坐标，用于搜索
  final VoidCallback onClose;
  final Function(LatLng coordinates, String name, RoutePointType type,
      int stopoverIndex) onPointSelected; // 选择点位回调，stopoverIndex=-1表示新增途径点
  final Function(int) onRemovePoint; // 删除点位回调（支持起点、终点、途径点）
  final Function(int, int) onReorderPoints; // 重新排序回调
  final Function(RoutePointType type) onPickPhoto; // 从图片选择位置回调，传递当前编辑的类型
  final Function(RoutePointType type) onUseCurrentLocation; // 使用当前位置回调
  final Function(EditingPointType type, int stopoverIndex)?
      onEditingTypeChanged; // 编辑类型变化回调，stopoverIndex=-1表示新增
  final MapboxMapController? mapController; // 用于显示路线详情的高亮
  final TimerFlag? timerFlag;

  const RoutePlanningPanel({
    Key? key,
    required this.data,
    this.route,
    this.resortCoordinate,
    required this.onClose,
    required this.onPointSelected,
    required this.onRemovePoint,
    required this.onReorderPoints,
    required this.onPickPhoto,
    required this.onUseCurrentLocation,
    this.onEditingTypeChanged,
    this.mapController,
    this.timerFlag,
  }) : super(key: key);

  @override
  State<RoutePlanningPanel> createState() => _RoutePlanningPanelState();
}

class _RoutePlanningPanelState extends State<RoutePlanningPanel> {
  // 搜索相关状态
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // 正在编辑的点位
  EditingPointType _editingType = EditingPointType.none;
  int _editingStopoverIndex = -1;

  // 路线详情展开状态
  bool _isRouteDetailsExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _setTimerFlag() {
    if (widget.timerFlag != null) {
      widget.timerFlag!.flag = true;
    }
  }

  /// 根据当前编辑类型获取 RoutePointType
  RoutePointType _getRoutePointType() {
    switch (_editingType) {
      case EditingPointType.origin:
        return RoutePointType.origin;
      case EditingPointType.destination:
        return RoutePointType.destination;
      case EditingPointType.stopover:
      case EditingPointType.newStopover:
        return RoutePointType.stopover;
      default:
        return RoutePointType.stopover;
    }
  }

  /// 格式化时间
  String _formatDuration(double seconds) {
    int minutes = (seconds ~/ 60);
    int remainingSeconds = (seconds % 60).round();

    if (minutes > 0) {
      return "$minutes min ${remainingSeconds}s";
    } else {
      return "$remainingSeconds sec";
    }
  }

  /// 获取导航图标
  IconData _getManeuverIcon(String type, String? modifier) {
    switch (type) {
      case 'depart':
        return Icons.straight;
      case 'arrive':
        return Icons.flag;
      default:
        return _getTurnIcon(modifier);
    }
  }

  /// 获取转向图标
  IconData _getTurnIcon(String? modifier) {
    switch (modifier) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'slight left':
        return Icons.turn_slight_left;
      case 'slight right':
        return Icons.turn_slight_right;
      case 'sharp left':
        return Icons.turn_sharp_left;
      case 'sharp right':
        return Icons.turn_sharp_right;
      case 'uturn':
        return Icons.u_turn_left;
      default:
        return Icons.straight;
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.length >= 2 && widget.resortCoordinate != null) {
        final results = await SearchService.searchPOI(
          query,
          widget.resortCoordinate!,
          15.0,
        );
        setState(() {
          _searchResults = results;
          _isSearching = true;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> poi) {
    _setTimerFlag();
    final coordinates = LatLng(poi['lat'], poi['lng']);
    final name = poi['name'].toString().split(',').first; // 取第一部分作为名称

    RoutePointType type;
    switch (_editingType) {
      case EditingPointType.origin:
        type = RoutePointType.origin;
        break;
      case EditingPointType.destination:
        type = RoutePointType.destination;
        break;
      case EditingPointType.stopover:
      case EditingPointType.newStopover:
        type = RoutePointType.stopover;
        break;
      default:
        return;
    }

    // 传递途径点索引：编辑现有途径点时使用 _editingStopoverIndex，新增时使用 -1
    final stopoverIndex =
        _editingType == EditingPointType.stopover ? _editingStopoverIndex : -1;
    widget.onPointSelected(coordinates, name, type, stopoverIndex);

    // 重置编辑状态
    setState(() {
      _editingType = EditingPointType.none;
      _editingStopoverIndex = -1;
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _startEditing(EditingPointType type, [int stopoverIndex = -1]) {
    _setTimerFlag();
    setState(() {
      _editingType = type;
      _editingStopoverIndex = stopoverIndex;
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
    // 通知父组件当前编辑类型和索引
    widget.onEditingTypeChanged?.call(type, stopoverIndex);
  }

  void _cancelEditing() {
    _setTimerFlag();
    setState(() {
      _editingType = EditingPointType.none;
      _editingStopoverIndex = -1;
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
    // 通知父组件编辑已取消
    widget.onEditingTypeChanged?.call(EditingPointType.none, -1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: GlobalConstants.searchboxWidth,
      constraints: BoxConstraints(maxHeight: 600),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildPointsList(),
            if (_editingType != EditingPointType.none) _buildSearchSection(),
            _buildAddStopoverButton(),
            if (widget.route != null) _buildRouteDetails(),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.directions, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              LocaleService.S.routePlanning,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.route != null) ...[
            Text(
              LocaleService.S.routeDistanceKm(widget.route!.distance / 1000),
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            SizedBox(width: 8),
          ],
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
    );
  }

  /// 构建点位列表（起点 + 途径点 + 终点）
  Widget _buildPointsList() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) {
        _setTimerFlag();
        widget.onReorderPoints(oldIndex, newIndex);
      },
      children: _buildAllPointTiles(),
    );
  }

  List<Widget> _buildAllPointTiles() {
    List<Widget> tiles = [];

    // 起点
    tiles.add(_buildPointTile(
      key: ValueKey('origin'),
      index: 0,
      icon: Icons.trip_origin,
      color: Colors.green,
      label: LocaleService.S.origin,
      point: widget.data.origin,
      isEditing: _editingType == EditingPointType.origin,
      onEdit: () => _startEditing(EditingPointType.origin),
      onRemove:
          widget.data.origin != null ? () => widget.onRemovePoint(0) : null,
    ));

    // 途径点
    for (int i = 0; i < widget.data.stopovers.length; i++) {
      tiles.add(_buildPointTile(
        key: ValueKey('stopover_$i'),
        index: i + 1,
        icon: Icons.more_vert,
        color: Colors.orange,
        label: LocaleService.S.stopoverN(i + 1),
        point: widget.data.stopovers[i],
        isEditing: _editingType == EditingPointType.stopover &&
            _editingStopoverIndex == i,
        onEdit: () => _startEditing(EditingPointType.stopover, i),
        onRemove: () => widget.onRemovePoint(i + 1),
        showNumber: i + 1,
      ));
    }

    // 终点
    final destIndex = widget.data.stopovers.length + 1;
    tiles.add(_buildPointTile(
      key: ValueKey('destination'),
      index: destIndex,
      icon: Icons.location_on,
      color: Colors.blue,
      label: LocaleService.S.destination,
      point: widget.data.destination,
      isEditing: _editingType == EditingPointType.destination,
      onEdit: () => _startEditing(EditingPointType.destination),
      onRemove: widget.data.destination != null
          ? () => widget.onRemovePoint(destIndex)
          : null,
    ));

    return tiles;
  }

  Widget _buildPointTile({
    required Key key,
    required int index,
    required IconData icon,
    required Color color,
    required String label,
    RoutePoint? point,
    required bool isEditing,
    required VoidCallback onEdit,
    VoidCallback? onRemove,
    int? showNumber,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: isEditing ? Colors.blue.shade50 : Colors.white,
      ),
      child: ListTile(
        leading: showNumber != null
            ? Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$showNumber',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : Icon(icon, color: color, size: 28),
        title: Text(
          point?.name ?? '点击选择$label',
          style: TextStyle(
            color: point != null ? Colors.black87 : Colors.grey,
            fontStyle: point != null ? FontStyle.normal : FontStyle.italic,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.grey, size: 18),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              tooltip: LocaleService.S.select,
            ),
            SizedBox(width: 4),
            Icon(Icons.drag_handle, color: Colors.grey, size: 20),
            if (onRemove != null) ...[
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red, size: 18),
                onPressed: () {
                  _setTimerFlag();
                  onRemove();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                tooltip: LocaleService.S.delete,
              ),
            ],
          ],
        ),
        dense: true,
        onTap: point == null ? onEdit : null,
      ),
    );
  }

  /// 构建搜索区域
  Widget _buildSearchSection() {
    String editingLabel = '';
    switch (_editingType) {
      case EditingPointType.origin:
        editingLabel = LocaleService.S.searchOrigin;
        break;
      case EditingPointType.destination:
        editingLabel = LocaleService.S.searchDestination;
        break;
      case EditingPointType.stopover:
        editingLabel =
            LocaleService.S.searchStopoverN(_editingStopoverIndex + 1);
        break;
      case EditingPointType.newStopover:
        editingLabel = LocaleService.S.searchNewStopover;
        break;
      default:
        break;
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  editingLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(40, 30),
                ),
                child: Text(LocaleService.S.cancel),
              ),
            ],
          ),
          SizedBox(height: 8),
          // 搜索框
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: LocaleService.S.searchPlace,
              prefixIcon: Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          // 按钮行：使用当前位置 + 从图片选择
          Row(
            children: [
              // 使用当前位置按钮
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _setTimerFlag();
                    RoutePointType type = _getRoutePointType();
                    widget.onUseCurrentLocation(type);
                    _cancelEditing();
                  },
                  icon: Icon(Icons.my_location, size: 16),
                  label: Text(LocaleService.S.myLocation),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size(0, 32),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // 从图片选择按钮
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _setTimerFlag();
                    RoutePointType type = _getRoutePointType();
                    widget.onPickPhoto(type);
                  },
                  icon: Icon(Icons.photo_camera, size: 16),
                  label: Text(LocaleService.S.fromPhoto),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
          // 搜索结果列表
          if (_searchResults.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              margin: EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final poi = _searchResults[index];
                  // 完整名称包含地址
                  final fullName = poi['name'].toString();
                  // 第一部分作为标题
                  final displayName = fullName.split(',').first;
                  // 距离信息
                  final distance = '${poi['distance'].toStringAsFixed(2)} km';

                  return ListTile(
                    dense: true,
                    title: Text(
                      displayName,
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName.contains(','))
                          Text(
                            fullName.substring(displayName.length + 1).trim(),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          distance,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    isThreeLine: fullName.contains(','),
                    onTap: () => _selectSearchResult(poi),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 构建添加途径点按钮
  Widget _buildAddStopoverButton() {
    if (_editingType == EditingPointType.newStopover) {
      return SizedBox.shrink(); // 正在添加途径点时隐藏按钮
    }

    return Padding(
      padding: EdgeInsets.all(12),
      child: OutlinedButton.icon(
        onPressed: () => _startEditing(EditingPointType.newStopover),
        icon: Icon(Icons.add_location, size: 18),
        label: Text(LocaleService.S.addStopover),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: BorderSide(color: Colors.orange),
          minimumSize: Size(double.infinity, 36),
        ),
      ),
    );
  }

  /// 构建路线详情区域
  Widget _buildRouteDetails() {
    final route = widget.route!;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // 路线概要（可点击展开/收起）
          InkWell(
            onTap: () {
              _setTimerFlag();
              setState(() {
                _isRouteDetailsExpanded = !_isRouteDetailsExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.route, color: Theme.of(context).primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleService.S.routeDetails,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          LocaleService.S.routeSummary(
                              route.distance / 1000, route.duration / 60),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isRouteDetailsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
          // 展开的路线步骤列表
          if (_isRouteDetailsExpanded)
            Container(
              constraints: BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: route.steps.length,
                itemBuilder: (context, index) {
                  final step = route.steps[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                    title: Text(
                      step.name.isNotEmpty ? step.name : 'Unnamed Piste',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${step.distance.toStringAsFixed(0)} m • ${_formatDuration(step.duration)}',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: Icon(
                      _getManeuverIcon(
                          step.maneuver.type, step.maneuver.modifier),
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    onTap: () {
                      _setTimerFlag();
                      // 点击步骤时移动地图到该位置
                      widget.mapController?.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(
                            step.maneuver.location[1],
                            step.maneuver.location[0],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
