import 'package:flutter/material.dart';
import '../color_helper.dart';
import '../piste.dart';
import '../timer_flag.dart';

class PisteInfoPanel extends StatelessWidget {
  final Piste piste;
  final TimerFlag timerFlag; // Pass TimerFlag instance
  final VoidCallback? onClose; // Callback function

  const PisteInfoPanel({
    Key? key,
    required this.piste,
    required this.timerFlag,
    this.onClose, // Allow optional callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          // Row with difficulty indicator, name, and close button
          Row(
            children: [
              _buildDifficultyIndicator(piste.color), // Difficulty color indicator
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  piste.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 24),
                onPressed: () {
                  timerFlag.flag = true;
                  if (onClose != null) {
                    onClose!(); // Call the callback function if provided
                  }
                  Navigator.pop(context); // Close the BottomSheet
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Difficulty: ${piste.difficulty}',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Generates a colored circle based on piste difficulty (HSL color)
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
}
