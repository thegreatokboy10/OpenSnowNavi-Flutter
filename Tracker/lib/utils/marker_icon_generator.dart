import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 生成自定义地图标记图标
class MarkerIconGenerator {
  /// 生成团队成员头像图标（带名字缩写和箭头）
  static Future<Uint8List> generateMemberIcon({
    required String nickname,
    required Color color,
    double size = 160,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 获取名字首字母缩写（最多2个字符）
    final initials = _getInitials(nickname);

    // 动态计算三角形尺寸（根据 size 比例）
    final arrowWidth = size * 0.15; // 三角形宽度为尺寸的 15%
    final arrowHeight = size * 0.125; // 三角形高度为尺寸的 12.5%

    // 画箭头/三角形指向实际位置
    final arrowPath = Path();
    arrowPath.moveTo(size / 2, size); // 底部中心（指向实际位置）
    arrowPath.lineTo(size / 2 - arrowWidth, size - arrowHeight);
    arrowPath.lineTo(size / 2 + arrowWidth, size - arrowHeight);
    arrowPath.close();

    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, paint);

    // 动态计算圆形位置（考虑三角形高度）
    final circleCenter = Offset(size / 2, size / 2 - arrowHeight * 0.25);
    final circleRadius = size / 2 - arrowHeight * 0.5;

    // 外边框（边框宽度根据尺寸动态计算）
    final borderWidth = size * 0.025;
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(circleCenter, circleRadius + borderWidth, paint);

    // 内圆
    paint.color = color;
    canvas.drawCircle(circleCenter, circleRadius, paint);

    // 画文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: circleRadius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - textPainter.width / 2,
        circleCenter.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成星标图标（用于集合点）
  static Future<Uint8List> generateStarIcon({
    required Color color,
    bool isActive = false,
    double size = 120,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 画星形
    final starPath =
        _createStarPath(size / 2, size / 2, size / 2 - 5, size / 4 - 2, 5);

    // 外边框
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawPath(starPath, paint);

    // 填充
    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(starPath, paint);

    // 如果是活动集合点，添加发光效果
    if (isActive) {
      paint.color = color.withOpacity(0.3);
      final glowPath =
          _createStarPath(size / 2, size / 2, size / 2, size / 4, 5);
      canvas.drawPath(glowPath, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成旗帜图标（用于终点）
  static Future<Uint8List> generateFlagIcon({
    Color color = Colors.blue,
    double size = 60,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 画旗杆
    paint.color = Colors.grey.shade700;
    paint.strokeWidth = 3;
    canvas.drawLine(
      Offset(size * 0.3, size * 0.15),
      Offset(size * 0.3, size * 0.95),
      paint,
    );

    // 画旗帜
    final flagPath = Path();
    flagPath.moveTo(size * 0.3, size * 0.15);
    flagPath.lineTo(size * 0.85, size * 0.3);
    flagPath.lineTo(size * 0.3, size * 0.45);
    flagPath.close();

    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(flagPath, paint);

    // 白边
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawPath(flagPath, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成出发图标（用于起点）
  static Future<Uint8List> generateStartIcon({
    Color color = Colors.green,
    double size = 60,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 画圆形背景
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 5;

    // 白色边框
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 3, paint);

    // 填充颜色
    paint.color = color;
    canvas.drawCircle(center, radius, paint);

    // 画播放/出发三角形
    final trianglePath = Path();
    trianglePath.moveTo(size * 0.35, size * 0.25);
    trianglePath.lineTo(size * 0.75, size * 0.5);
    trianglePath.lineTo(size * 0.35, size * 0.75);
    trianglePath.close();

    paint.color = Colors.white;
    canvas.drawPath(trianglePath, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 获取名字的首字母缩写
  static String _getInitials(String name) {
    if (name.isEmpty) return '?';

    // 处理中文名字
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(name)) {
      // 中文：取最后1-2个字
      if (name.length >= 2) {
        return name.substring(name.length - 2);
      }
      return name;
    }

    // 英文名：取单词首字母
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// 创建星形路径
  static Path _createStarPath(
    double cx,
    double cy,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    final path = Path();
    final angle = 3.14159 / points;

    for (int i = 0; i < 2 * points; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final a = i * angle - 3.14159 / 2;
      final x = cx + r * _cos(a);
      final y = cy + r * _sin(a);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  static double _cos(double radians) => math.cos(radians);

  static double _sin(double radians) => math.sin(radians);
}
