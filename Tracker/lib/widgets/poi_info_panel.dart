import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;
import '../config/app_theme.dart';

/// POI 信息面板 - 点击地图时显示的位置详情
class POIInfoPanel extends StatelessWidget {
  final String? name;
  final Position coordinates;
  final VoidCallback onClose;
  final VoidCallback onSetAsOrigin;
  final VoidCallback onSetAsDestination;
  final VoidCallback onAddAsStopover;
  final bool isInTeamMode;
  final VoidCallback? onAddAsMeetingPoint;

  const POIInfoPanel({
    super.key,
    this.name,
    required this.coordinates,
    required this.onClose,
    required this.onSetAsOrigin,
    required this.onSetAsDestination,
    required this.onAddAsStopover,
    this.isInTeamMode = false,
    this.onAddAsMeetingPoint,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name ?? l10n.selectedLocation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // 坐标信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${coordinates.lat.toStringAsFixed(6)}, ${coordinates.lng.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.trip_origin,
                        label: l10n.setOrigin,
                        color: Colors.green,
                        onTap: onSetAsOrigin,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.location_on,
                        label: l10n.setDestination,
                        color: Colors.blue,
                        onTap: onSetAsDestination,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    context,
                    icon: Icons.add_location,
                    label: l10n.addStopover,
                    color: Colors.orange,
                    onTap: onAddAsStopover,
                  ),
                ),
                // 组队模式下显示集合点按钮
                if (isInTeamMode && onAddAsMeetingPoint != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      context,
                      icon: Icons.star,
                      label: l10n.addAsMeetingPoint,
                      color: AppTheme.meetingPointActiveColor,
                      onTap: onAddAsMeetingPoint!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
