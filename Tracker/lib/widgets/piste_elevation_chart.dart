import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/elevation_point.dart';

/// 雪道海拔剖面图组件 - 支持交互拖动
class PisteElevationChart extends StatefulWidget {
  final ElevationProfile profile;
  final double height;
  final Color chartColor;
  final ValueChanged<int>? onPositionChanged;

  const PisteElevationChart({
    super.key,
    required this.profile,
    this.height = 100,
    this.chartColor = Colors.blue,
    this.onPositionChanged,
  });

  @override
  State<PisteElevationChart> createState() => _PisteElevationChartState();
}

class _PisteElevationChartState extends State<PisteElevationChart> {
  int? _selectedIndex;
  double _progress = 0;

  ElevationPoint? get _selectedPoint {
    if (_selectedIndex == null || widget.profile.points.isEmpty) return null;
    return widget.profile.points[_selectedIndex!];
  }

  void _handleTap(TapDownDetails details, BuildContext context) {
    _updatePosition(details.localPosition.dx, context);
  }

  void _handleDrag(DragUpdateDetails details, BuildContext context) {
    _updatePosition(details.localPosition.dx, context);
  }

  void _handleDragEnd(DragEndDetails details) {
    // 保持当前选中状态
  }

  void _updatePosition(double localX, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final progress = (localX / box.size.width).clamp(0.0, 1.0);

    // 找到对应的点索引
    final totalDist = widget.profile.totalDistance;
    if (totalDist == 0) return;

    final targetDist = progress * totalDist;
    int index = 0;
    for (int i = 0; i < widget.profile.points.length; i++) {
      if (widget.profile.points[i].cumulativeDistance >= targetDist) {
        index = i;
        break;
      }
      index = i;
    }

    setState(() {
      _selectedIndex = index;
      _progress = progress;
    });

    widget.onPositionChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No elevation data', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 海拔图
        GestureDetector(
          onTapDown: (details) => _handleTap(details, context),
          onHorizontalDragUpdate: (details) => _handleDrag(details, context),
          onHorizontalDragEnd: _handleDragEnd,
          child: SizedBox(
            height: widget.height,
            child: CustomPaint(
              size: Size(double.infinity, widget.height),
              painter: _PisteElevationChartPainter(
                profile: widget.profile,
                progress: _progress,
                selectedIndex: _selectedIndex,
                chartColor: widget.chartColor,
              ),
            ),
          ),
        ),
        // 选中点信息提示
        if (_selectedPoint != null) _buildTooltip(_selectedPoint!),
      ],
    );
  }

  Widget _buildTooltip(ElevationPoint point) {
    final slopeColor = _getSlopeColor(point.slope);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 海拔
          _buildInfoItem(
            icon: Icons.terrain,
            label: '海拔',
            value: '${point.elevation.toStringAsFixed(0)} m',
            color: widget.chartColor,
          ),
          // 坡度
          if (point.slope != null)
            _buildInfoItem(
              icon: Icons.trending_down,
              label: '坡度',
              value: '${point.slope!.toStringAsFixed(1)}% / ${point.slopeDegrees!.toStringAsFixed(1)}°',
              color: slopeColor,
            ),
          // 距离
          _buildInfoItem(
            icon: Icons.straighten,
            label: '距起点',
            value: _formatDistance(point.cumulativeDistance),
            color: Colors.grey[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  Color _getSlopeColor(double? slope) {
    if (slope == null) return Colors.grey;
    final absSlope = slope.abs();
    if (absSlope < 15) return Colors.green;
    if (absSlope < 30) return Colors.orange;
    return Colors.red;
  }
}

/// 海拔剖面图绘制器
class _PisteElevationChartPainter extends CustomPainter {
  final ElevationProfile profile;
  final double progress;
  final int? selectedIndex;
  final Color chartColor;

  _PisteElevationChartPainter({
    required this.profile,
    required this.progress,
    this.selectedIndex,
    required this.chartColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.isEmpty) return;

    final points = profile.points;

    // 计算海拔范围
    double minAlt = profile.minElevation;
    double maxAlt = profile.maxElevation;

    // 确保有最小范围
    final altRange = math.max(maxAlt - minAlt, 50.0);
    final padding = altRange * 0.1;
    minAlt -= padding;
    maxAlt += padding;

    final totalDistance = profile.totalDistance;
    if (totalDistance == 0) return;

    // 绘制网格线
    _drawGrid(canvas, size, minAlt, maxAlt);

    // 绘制渐变填充和折线
    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.cumulativeDistance / totalDistance) * size.width;
      final y = size.height - ((p.elevation - minAlt) / (maxAlt - minAlt)) * size.height;

      if (i == 0) {
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    // 闭合填充路径
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 绘制渐变填充
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          chartColor.withOpacity(0.4),
          chartColor.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 绘制折线
    final linePaint = Paint()
      ..color = chartColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    // 绘制海拔标签
    _drawElevationLabels(canvas, size, minAlt, maxAlt);

    // 绘制选中位置指示器
    if (selectedIndex != null) {
      _drawIndicator(canvas, size, minAlt, maxAlt, totalDistance);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double minAlt, double maxAlt) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // 绘制水平网格线 (3条)
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawElevationLabels(Canvas canvas, Size size, double minAlt, double maxAlt) {
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 9,
    );

    // 最高海拔标签
    final maxLabel = TextPainter(
      text: TextSpan(text: '${maxAlt.toStringAsFixed(0)}m', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    maxLabel.layout();
    maxLabel.paint(canvas, const Offset(2, 2));

    // 最低海拔标签
    final minLabel = TextPainter(
      text: TextSpan(text: '${minAlt.toStringAsFixed(0)}m', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    minLabel.layout();
    minLabel.paint(canvas, Offset(2, size.height - minLabel.height - 2));
  }

  void _drawIndicator(
    Canvas canvas,
    Size size,
    double minAlt,
    double maxAlt,
    double totalDistance,
  ) {
    if (selectedIndex == null || selectedIndex! >= profile.points.length) return;

    final point = profile.points[selectedIndex!];
    final x = (point.cumulativeDistance / totalDistance) * size.width;
    final y = size.height - ((point.elevation - minAlt) / (maxAlt - minAlt)) * size.height;

    // 垂直指示线
    final indicatorLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), indicatorLinePaint);

    // 绘制当前位置圆点
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(x, y), 6, dotPaint);
    final dotBorderPaint = Paint()
      ..color = chartColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), 6, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _PisteElevationChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.profile != profile;
  }
}

/// 雪道统计信息组件
class PisteElevationStats extends StatelessWidget {
  final ElevationProfile profile;

  const PisteElevationStats({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.straighten,
            label: '长度',
            value: _formatDistance(profile.totalDistance),
          ),
          _buildStatItem(
            icon: Icons.height,
            label: '落差',
            value: '${profile.verticalDrop.toStringAsFixed(0)} m',
          ),
          _buildStatItem(
            icon: Icons.trending_down,
            label: '平均坡度',
            value: '${profile.averageSlope.toStringAsFixed(1)}% / ${profile.averageSlopeDegrees.toStringAsFixed(1)}°',
          ),
          _buildStatItem(
            icon: Icons.warning_amber,
            label: '最大坡度',
            value: '${profile.maxSlope.toStringAsFixed(1)}% / ${profile.maxSlopeDegrees.toStringAsFixed(1)}°',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}
