import 'package:flutter/material.dart';
import '../timer_flag.dart';
import '../lift.dart';
import '../geojson_helper.dart';
import '../web_title_helper.dart';
import '../l10n/locale_service.dart';

class LiftInfoPanel extends StatefulWidget {
  final Lift lift;
  final TimerFlag timerFlag;
  final VoidCallback? onClose;

  const LiftInfoPanel({
    Key? key,
    required this.lift,
    required this.timerFlag,
    this.onClose,
  }) : super(key: key);

  @override
  _LiftInfoPanelState createState() => _LiftInfoPanelState();
}

class _LiftInfoPanelState extends State<LiftInfoPanel> {
  @override
  void initState() {
    super.initState();
    WebTitleHelper.updateTitle("Lift: ${widget.lift.name}"); // Update title
    print("update title to lift: ${widget.lift.name}");
  }

  @override
  void dispose() {
    WebTitleHelper.resetTitle(); // Reset title when panel closes
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double computedLength = _calculateLiftLength(widget.lift.coordinates);
    String iconPath = _getLiftIconPath(widget.lift.type);

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
          // Lift Name and Close Button
          Row(
            children: [
              // Lift Type Icon
              Image.asset(
                iconPath,
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.error, size: 20, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.lift.name.isNotEmpty
                      ? widget.lift.name
                      : LocaleService.S.unknown,
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

          // Lift Reference (Ref)
          if (widget.lift.ref.isNotEmpty)
            Text(
              '${LocaleService.S.ref}: ${widget.lift.ref}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          const SizedBox(height: 6),

          // Lift Type
          Text(
            '${LocaleService.S.liftType}: ${widget.lift.type}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),

          // Lift Length (Computed)
          Text(
            '${LocaleService.S.length}: ${computedLength.toStringAsFixed(0)} m',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// **Computes the total lift length using coordinates**
  double _calculateLiftLength(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0;

    return GeoJsonHelper.calculateTotalDistance(coordinates);
  }

  /// **Returns the correct lift icon path based on lift type**
  String _getLiftIconPath(String liftType) {
    switch (liftType.toLowerCase()) {
      case 'gondola':
        return 'assets/icons/cable-car.png';
      case 'chair_lift':
        return 'assets/icons/chair_lift.png';
      case 'drag_lift':
        return 'assets/icons/drag_lift.png';
      case 'rope_tow':
        return 'assets/icons/drag_lift.png';
      case 'platter':
        return 'assets/icons/drag_lift.png';
      case 'cable_car':
        return 'assets/icons/cable-car.png';
      default:
        return 'assets/icons/piste.png'; // Default icon
    }
  }
}
