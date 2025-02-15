import 'package:flutter/material.dart';
import '../timer_flag.dart';
import '../lift.dart';
import '../geojson_helper.dart';

class LiftInfoPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    double computedLength = _calculateLiftLength(lift.coordinates);
    String iconPath = _getLiftIconPath(lift.type);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
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
                errorBuilder: (context, error, stackTrace) => Icon(Icons.error, size: 20, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lift.name.isNotEmpty ? lift.name : "Unknown Lift",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 24),
                onPressed: () {
                  timerFlag.flag = true;
                  if (onClose != null) onClose!();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Lift Reference (Ref)
          if (lift.ref.isNotEmpty)
            Text(
              'Ref: ${lift.ref}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 6),

          // Lift Type
          Text(
            'Type: ${lift.type}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),

          // Lift Length (Computed)
          Text(
            'Length: ${computedLength.toStringAsFixed(0)} m',
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
