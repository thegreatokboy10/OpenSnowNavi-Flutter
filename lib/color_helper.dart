import 'package:flutter/material.dart';

class ColorHelper {
  // Parses HSL string like "hsl(0, 0%, 35%)" and converts it to a Flutter Color
  static Color hslToColor(String hslString) {
    final regex = RegExp(r'hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)');
    final match = regex.firstMatch(hslString);

    if (match != null) {
      double h = double.parse(match.group(1)!);
      double s = double.parse(match.group(2)!) / 100.0;
      double l = double.parse(match.group(3)!) / 100.0;

      return hslToRgb(h, s, l);
    } else {
      print("Invalid HSL format: $hslString");
      return Colors.grey; // Fallback color
    }
  }

  // Converts HSL values to a Flutter Color
  static Color hslToRgb(double h, double s, double l) {
    double c = (1 - (2 * l - 1).abs()) * s;
    double x = c * (1 - ((h / 60) % 2 - 1).abs());
    double m = l - c / 2;

    double r = 0, g = 0, b = 0;

    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }

    return Color.fromARGB(
      255,
      ((r + m) * 255).round(),
      ((g + m) * 255).round(),
      ((b + m) * 255).round(),
    );
  }
}
