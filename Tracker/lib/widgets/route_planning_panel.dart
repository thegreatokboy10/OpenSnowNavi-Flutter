import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;
import '../models/route_planning_state.dart';
import '../services/route_engine.dart' as re;
import '../services/search_service.dart';

/// 正在编辑的点位类型
enum EditingPointType { none, origin, destination, stopover, newStopover }

class RoutePlanningPanel extends StatefulWidget {
  final RoutePlanningData data;
  final re.Route? route;
  final LatLng? resortCoordinate;
  final VoidCallback onClose;
  final Function(Position coordinates, String name, RoutePointType type,
      int stopoverIndex) onPointSelected;
  final Function(int) onRemovePoint;
  final Function(int, int) onReorderPoints;
  final Function(RoutePointType type) onUseCurrentLocation;
  final Function(EditingPointType type, int stopoverIndex)?
      onEditingTypeChanged;
  final Function(int stepIndex)? onStepTap;

  const RoutePlanningPanel({
    super.key,
    required this.data,
    this.route,
    this.resortCoordinate,
    required this.onClose,
    required this.onPointSelected,
    required this.onRemovePoint,
    required this.onReorderPoints,
    required this.onUseCurrentLocation,
    this.onEditingTypeChanged,
    this.onStepTap,
  });

  @override
  State<RoutePlanningPanel> createState() => _RoutePlanningPanelState();
}

class _RoutePlanningPanelState extends State<RoutePlanningPanel> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  EditingPointType _editingType = EditingPointType.none;
  int _editingStopoverIndex = -1;
  bool _isRouteDetailsExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String _formatDuration(double seconds) {
    int minutes = (seconds ~/ 60);
    int remainingSeconds = (seconds % 60).round();
    if (minutes > 0) {
      return "$minutes min ${remainingSeconds}s";
    } else {
      return "$remainingSeconds sec";
    }
  }

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
    final coordinates = Position(poi['lng'], poi['lat']);
    final name = poi['name'].toString().split(',').first;

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

    final stopoverIndex =
        _editingType == EditingPointType.stopover ? _editingStopoverIndex : -1;
    widget.onPointSelected(coordinates, name, type, stopoverIndex);

    setState(() {
      _editingType = EditingPointType.none;
      _editingStopoverIndex = -1;
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _startEditing(EditingPointType type, [int stopoverIndex = -1]) {
    setState(() {
      _editingType = type;
      _editingStopoverIndex = stopoverIndex;
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
    widget.onEditingTypeChanged?.call(type, stopoverIndex);
  }

  void _cancelEditing() {
    setState(() {
      _editingType = EditingPointType.none;
      _editingStopoverIndex = -1;
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
    widget.onEditingTypeChanged?.call(EditingPointType.none, -1);
  }

  RoutePointType _getRoutePointType() {
    switch (_editingType) {
      case EditingPointType.origin:
        return RoutePointType.origin;
      case EditingPointType.destination:
        return RoutePointType.destination;
      default:
        return RoutePointType.stopover;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF212121), // 黑色标题栏
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '路线规划',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.route != null)
            Text(
              '${(widget.route!.distance / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsList() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: widget.onReorderPoints,
      children: _buildAllPointTiles(),
    );
  }

  List<Widget> _buildAllPointTiles() {
    List<Widget> tiles = [];

    // 起点
    tiles.add(_buildPointTile(
      key: const ValueKey('origin'),
      index: 0,
      icon: Icons.trip_origin,
      color: Colors.green,
      label: '起点',
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
        label: '途径点 ${i + 1}',
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
      key: const ValueKey('destination'),
      index: destIndex,
      icon: Icons.location_on,
      color: Colors.blue,
      label: '终点',
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
        dense: true,
        leading: showNumber != null
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text('$showNumber',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              )
            : Icon(icon, color: color, size: 24),
        title: Text(
          point?.name ?? '点击选择$label',
          style: TextStyle(
            color: point != null ? Colors.black87 : Colors.grey,
            fontStyle: point != null ? FontStyle.normal : FontStyle.italic,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey, size: 18),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close, color: Colors.red, size: 16),
              ),
            ],
          ],
        ),
        // 点击整行直接开启搜索编辑
        onTap: onEdit,
      ),
    );
  }

  Widget _buildSearchSection() {
    String editingLabel = '';
    switch (_editingType) {
      case EditingPointType.origin:
        editingLabel = '搜索起点';
        break;
      case EditingPointType.destination:
        editingLabel = '搜索终点';
        break;
      case EditingPointType.stopover:
        editingLabel = '搜索途径点 ${_editingStopoverIndex + 1}';
        break;
      case EditingPointType.newStopover:
        editingLabel = '搜索新途径点';
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
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
                child: Text(editingLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).primaryColor)),
              ),
              TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(40, 28)),
                child: const Text('取消', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '搜索地点',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              RoutePointType type = _getRoutePointType();
              widget.onUseCurrentLocation(type);
              _cancelEditing();
            },
            icon: const Icon(Icons.my_location, size: 14),
            label: const Text('使用当前位置', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(double.infinity, 32),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              margin: const EdgeInsets.only(top: 8),
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
                  final fullName = poi['name'].toString();
                  final displayName = fullName.split(',').first;
                  final distance = '${poi['distance'].toStringAsFixed(2)} km';

                  return ListTile(
                    dense: true,
                    title: Text(displayName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text(distance, style: const TextStyle(fontSize: 10)),
                    onTap: () => _selectSearchResult(poi),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddStopoverButton() {
    if (_editingType == EditingPointType.newStopover) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: OutlinedButton.icon(
        onPressed: () => _startEditing(EditingPointType.newStopover),
        icon: const Icon(Icons.add_location, size: 16),
        label: const Text('添加途径点', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: const BorderSide(color: Colors.orange),
          minimumSize: const Size(double.infinity, 32),
        ),
      ),
    );
  }

  Widget _buildRouteDetails() {
    final route = widget.route!;

    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
                () => _isRouteDetailsExpanded = !_isRouteDetailsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.route, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('路线详情',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          '${(route.distance / 1000).toStringAsFixed(1)} km • ${(route.duration / 60).toStringAsFixed(0)} min',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(_isRouteDetailsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
          if (_isRouteDetailsExpanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: route.steps.length,
                itemBuilder: (context, index) {
                  final step = route.steps[index];
                  return ListTile(
                    dense: true,
                    onTap: () {
                      // 点击路线步骤，触发回调
                      widget.onStepTap?.call(index);
                    },
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                    title: Text(
                      step.name.isNotEmpty ? step.name : '未命名雪道',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${step.distance.toStringAsFixed(0)} m • ${_formatDuration(step.duration)}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: Icon(
                      _getManeuverIcon(
                          step.maneuver.type, step.maneuver.modifier),
                      color: Theme.of(context).primaryColor,
                      size: 18,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
