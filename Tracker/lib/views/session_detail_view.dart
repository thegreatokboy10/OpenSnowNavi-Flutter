import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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

  Widget _buildMap() {
    if (_points.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: Text('No track data')),
      );
    }

    final polylinePoints = _points.map((p) => p.latLng).toList();
    final bounds = LatLngBounds.fromPoints(polylinePoints);

    return FlutterMap(
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: 14,
        initialCameraFit:
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.snownavi.tracker',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: polylinePoints,
              strokeWidth: 4,
              color: Colors.orange,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: polylinePoints.first,
              child:
                  const Icon(Icons.play_circle, color: Colors.green, size: 32),
            ),
            Marker(
              point: polylinePoints.last,
              child: const Icon(Icons.stop_circle, color: Colors.red, size: 32),
            ),
          ],
        ),
      ],
    );
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
