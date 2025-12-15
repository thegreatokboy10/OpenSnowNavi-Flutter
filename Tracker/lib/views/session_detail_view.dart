import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/mapbox_config.dart';
import '../models/session.dart';
import '../models/location_point.dart';
import '../services/session_manager.dart';
import '../utils/gpx_exporter.dart';
import '../utils/statistics.dart';

/// Session 详情视图
class SessionDetailView extends StatefulWidget {
  final Session session;

  const SessionDetailView({super.key, required this.session});

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView> {
  List<LocationPoint> _points = [];
  bool _isLoading = true;
  SessionStatistics? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final manager = context.read<SessionManager>();
    final points = await manager.fetchLocationPoints(widget.session.id);
    setState(() {
      _points = points;
      _stats = SessionStatistics.fromSession(widget.session);
      _isLoading = false;
    });
  }

  Future<void> _exportGPX() async {
    final path = await GPXExporter.exportToFile(widget.session, _points);
    if (path != null) {
      await Share.shareXFiles([XFile(path)], text: 'Ski Session GPX');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export GPX')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _points.isEmpty ? null : _exportGPX,
            tooltip: 'Export GPX',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(flex: 2, child: _buildMap()),
                Expanded(flex: 1, child: _buildStats()),
              ],
            ),
    );
  }

  MapboxMap? _mapboxMap;

  Widget _buildMap() {
    if (_points.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: Text('No track data')),
      );
    }

    // 计算边界
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final p in _points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final center = Point(coordinates: Position(centerLng, centerLat));

    return MapWidget(
      cameraOptions: CameraOptions(
        center: center,
        zoom: 14,
      ),
      styleUri: MapboxConfig.styleUrl,
      onMapCreated: (mapboxMap) async {
        _mapboxMap = mapboxMap;
        await _addTrackLine(mapboxMap);
        await _addMarkers(mapboxMap);
        // 调整相机以适应轨迹
        await _fitBounds(mapboxMap, minLat, maxLat, minLng, maxLng);
      },
    );
  }

  Future<void> _addTrackLine(MapboxMap mapboxMap) async {
    // 创建 GeoJSON LineString
    final coordinates = _points.map((p) => [p.longitude, p.latitude]).toList();
    final geoJson = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
    };

    // 添加 source
    await mapboxMap.style.addSource(
      GeoJsonSource(id: 'track-source', data: jsonEncode(geoJson)),
    );

    // 添加 line layer
    await mapboxMap.style.addLayer(
      LineLayer(
        id: 'track-layer',
        sourceId: 'track-source',
        lineColor: Colors.orange.value,
        lineWidth: 4.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Future<void> _addMarkers(MapboxMap mapboxMap) async {
    final startPoint = _points.first;
    final endPoint = _points.last;

    // 添加起点和终点标记
    final pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // 起点标记 (绿色)
    await pointAnnotationManager.create(
      PointAnnotationOptions(
        geometry: Point(
            coordinates: Position(startPoint.longitude, startPoint.latitude)),
        iconSize: 1.5,
        textField: '▶',
        textSize: 24.0,
        textColor: Colors.green.value,
      ),
    );

    // 终点标记 (红色)
    await pointAnnotationManager.create(
      PointAnnotationOptions(
        geometry:
            Point(coordinates: Position(endPoint.longitude, endPoint.latitude)),
        iconSize: 1.5,
        textField: '■',
        textSize: 24.0,
        textColor: Colors.red.value,
      ),
    );
  }

  Future<void> _fitBounds(MapboxMap mapboxMap, double minLat, double maxLat,
      double minLng, double maxLng) async {
    // 添加一些 padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = CoordinateBounds(
      southwest: Point(
          coordinates: Position(minLng - lngPadding, minLat - latPadding)),
      northeast: Point(
          coordinates: Position(maxLng + lngPadding, maxLat + latPadding)),
      infiniteBounds: false,
    );

    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(
            coordinates:
                Position((minLng + maxLng) / 2, (minLat + maxLat) / 2)),
      ),
    );

    // 使用 easeTo 来适应边界
    final cameraForBounds = await mapboxMap.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
      null,
      null,
      null,
      null,
    );
    await mapboxMap.flyTo(cameraForBounds, MapAnimationOptions(duration: 500));
  }

  Widget _buildStats() {
    if (_stats == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Total Duration',
                      _stats!.formattedTotalDuration, Icons.timer)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Skiing Duration',
                      _stats!.formattedSkiingDuration, Icons.downhill_skiing)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Total Distance',
                      _stats!.formattedTotalDistance, Icons.straighten)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Skiing Distance',
                      _stats!.formattedSkiingDistance, Icons.route)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Max Speed', _stats!.formattedMaxSpeed, Icons.speed)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Avg Speed',
                      _stats!.formattedAverageSpeed, Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Elevation Gain',
                      _stats!.formattedElevationGain, Icons.arrow_upward)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('Elevation Loss',
                      _stats!.formattedElevationLoss, Icons.arrow_downward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
