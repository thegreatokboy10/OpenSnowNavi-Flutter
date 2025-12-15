import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';
import '../config/mapbox_config.dart';
import '../services/session_manager.dart';

/// 地图视图 - 用于滑雪路线规划
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapboxMap? _mapboxMap;

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionManager>(
      builder: (context, manager, child) {
        final position = manager.currentPosition;
        final initialCenter = position != null
            ? Point(coordinates: Position(position.longitude, position.latitude))
            : Point(coordinates: Position(8.2275, 46.8182)); // 默认瑞士中心

        return Scaffold(
          body: SafeArea(
            child: MapWidget(
              cameraOptions: CameraOptions(
                center: initialCenter,
                zoom: 14,
              ),
              styleUri: MapboxConfig.styleUrl,
              onMapCreated: (mapboxMap) async {
                _mapboxMap = mapboxMap;

                // 启用用户位置显示，使用 Mapbox 内置的 puck
                await mapboxMap.location.updateSettings(
                  LocationComponentSettings(
                    enabled: true,
                    pulsingEnabled: true,
                    pulsingColor: 0xFF007AFF, // Apple Maps 蓝色
                    showAccuracyRing: true,
                    puckBearingEnabled: true,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

