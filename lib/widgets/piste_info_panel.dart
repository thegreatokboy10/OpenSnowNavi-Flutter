import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../color_helper.dart';
import '../piste.dart';
import '../timer_flag.dart';
import '../geojson_helper.dart';
import '../web_title_helper.dart';
import '../l10n/locale_service.dart';

class PisteInfoPanel extends StatefulWidget {
  final Piste piste;
  final TimerFlag timerFlag;
  final VoidCallback? onClose;

  const PisteInfoPanel({
    Key? key,
    required this.piste,
    required this.timerFlag,
    this.onClose,
  }) : super(key: key);

  @override
  _PisteInfoPanelState createState() => _PisteInfoPanelState();
}

class _PisteInfoPanelState extends State<PisteInfoPanel> {
  int? touchedIndex; // For hover interaction

  @override
  void initState() {
    super.initState();
    WebTitleHelper.updateTitle("Piste: ${widget.piste.name}"); // Update title
  }

  @override
  void dispose() {
    WebTitleHelper.resetTitle(); // Reset title when panel closes
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double averageSlope = _calculateAverageSlope();
    double maxSlope = _calculateMaxSlope();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Piste Name and Close Button
          Row(
            children: [
              _buildDifficultyIndicator(
                  widget.piste.color), // 🔹 Included here!
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.piste.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 24),
                onPressed: () {
                  widget.timerFlag.flag = true;
                  if (widget.onClose != null) widget.onClose!();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Piste Difficulty
          Text(
            '${LocaleService.S.difficulty}: ${widget.piste.difficulty}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),

          // Piste Info: Distance, Ascent, Descent
          const SizedBox(height: 6),
          Text(
            '${LocaleService.S.distance}: ${_formatDistance(widget.piste.coordinates)}   '
            '${LocaleService.S.ascent}: ${_calculateAscent().toInt()}m   '
            '${LocaleService.S.descent}: ${_calculateDescent().toInt()}m',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),

          // Slope Information
          const SizedBox(height: 6),
          Text(
            '${LocaleService.S.avgSlope}: ${averageSlope.toInt()}° (${_slopeToPercentage(averageSlope).toInt()}%)   ',
            // 'Max Slope: ${maxSlope.toStringAsFixed(1)}° (${_slopeToPercentage(maxSlope)}%)',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),

          const SizedBox(height: 16),

          // Elevation Graph
          widget.piste.elevation != null && widget.piste.elevation!.isNotEmpty
              ? _buildElevationChart()
              : Text(LocaleService.S.noElevationData),
        ],
      ),
    );
  }

  /// **🔹 Generates a colored circle to indicate piste difficulty**
  Widget _buildDifficultyIndicator(String hslColorString) {
    Color color = ColorHelper.hslToColor(hslColorString);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildElevationChart() {
    final elevationData = widget.piste.elevation!;
    final distanceData =
        GeoJsonHelper.calculateDistances(widget.piste.coordinates);

    // Get min and max elevation to determine Y-axis range
    double minElevation = elevationData.reduce(min);
    double maxElevation = elevationData.reduce(max);

    // Adjust min elevation to the nearest lower multiple of 50
    double adjustedMinElevation = (minElevation / 50).floor() * 50;
    double adjustedMaxElevation = (maxElevation / 50).ceil() * 50;

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minY: adjustedMinElevation, // Set Y-axis starting point
          maxY: adjustedMaxElevation, // Set Y-axis ending point
          gridData:
              FlGridData(show: false), // Hide grid lines for a cleaner look
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (adjustedMaxElevation - adjustedMinElevation) /
                    5, // Display Y-axis labels every 50 meters
                getTitlesWidget: (value, meta) {
                  // Only display values that are multiples of 50
                  if (value >= adjustedMinElevation &&
                      value <= adjustedMaxElevation) {
                    return Text(
                      '${value.toInt()}',
                      style: TextStyle(fontSize: 10),
                      textAlign: TextAlign.right,
                    );
                  }
                  return Container(); // Hide non-matching values
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  // Avoid showing the last X-axis value to prevent overcrowding
                  if (value != distanceData.last) {
                    return Text(
                      '${value.toInt()}',
                      style: TextStyle(fontSize: 10),
                    );
                  }
                  return Container();
                },
              ),
            ),
            topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false)), // Hide top labels
            rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false)), // Hide right labels
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: Colors.black26),
              bottom: BorderSide(color: Colors.black26),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                min(distanceData.length,
                    elevationData.length), // Prevent index errors
                (index) => FlSpot(distanceData[index], elevationData[index]),
              ),
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 2,
              belowBarData: BarAreaData(
                  show: true, color: Colors.blueAccent.withOpacity(0.3)),
              dotData: FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black54,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((FlSpot spot) {
                  return LineTooltipItem(
                    '${spot.x.toStringAsFixed(1)} m\n${spot.y.toStringAsFixed(1)} m',
                    TextStyle(color: Colors.white, fontSize: 10),
                  );
                }).toList();
              },
            ),
            touchCallback:
                (FlTouchEvent event, LineTouchResponse? touchResponse) {
              if (event is FlTapUpEvent) {
                setState(() {
                  touchedIndex = touchResponse?.lineBarSpots?.first.spotIndex;
                });
              }
            },
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  /// **🔹 Safe Average Slope Calculation**
  double _calculateAverageSlope() {
    if (widget.piste.elevation == null || widget.piste.elevation!.length < 2)
      return 0;

    double elevationChange =
        widget.piste.elevation!.first - widget.piste.elevation!.last;
    double totalDistance =
        GeoJsonHelper.calculateTotalDistance(widget.piste.coordinates);

    if (totalDistance <= 0) return 0;

    return atan(elevationChange / totalDistance) * (180 / pi);
  }

  /// **🔹 Safe Maximum Slope Calculation**
  double _calculateMaxSlope() {
    if (widget.piste.elevation == null || widget.piste.elevation!.length < 2)
      return 0;

    final distances =
        GeoJsonHelper.calculateDistances(widget.piste.coordinates);
    if (distances.length < 2) return 0;

    double maxSlope = 0;

    for (int i = 1;
        i < min(widget.piste.elevation!.length, distances.length);
        i++) {
      double elevationChange =
          widget.piste.elevation![i - 1] - widget.piste.elevation![i];
      double distanceChange = (distances[i] - distances[i - 1]);

      if (distanceChange > 0) {
        double slope = atan(elevationChange / distanceChange) * (180 / pi);
        maxSlope = max(maxSlope, slope);
      }
    }

    return maxSlope;
  }

  /// Converts slope from degrees to percentage
  double _slopeToPercentage(double slope) {
    return tan(slope * (pi / 180)) * 100;
  }

  /// Calculates total piste distance
  String _formatDistance(List<List<double>> coordinates) {
    double totalDistance = GeoJsonHelper.calculateTotalDistance(coordinates);
    return '${totalDistance.toStringAsFixed(0)}m';
  }

  /// **🔹 Calculates ascent safely**
  double _calculateAscent() {
    if (widget.piste.elevation == null || widget.piste.elevation!.length < 2)
      return 0;

    double ascent = 0;
    for (int i = 1; i < widget.piste.elevation!.length; i++) {
      if (widget.piste.elevation![i] > widget.piste.elevation![i - 1]) {
        ascent += widget.piste.elevation![i] - widget.piste.elevation![i - 1];
      }
    }
    return ascent;
  }

  /// **🔹 Calculates descent safely**
  double _calculateDescent() {
    if (widget.piste.elevation == null || widget.piste.elevation!.length < 2)
      return 0;

    double descent = 0;
    for (int i = 1; i < widget.piste.elevation!.length; i++) {
      if (widget.piste.elevation![i] < widget.piste.elevation![i - 1]) {
        descent += widget.piste.elevation![i - 1] - widget.piste.elevation![i];
      }
    }
    return descent;
  }
}
