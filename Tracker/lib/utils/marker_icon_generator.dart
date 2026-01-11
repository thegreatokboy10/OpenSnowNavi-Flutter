import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 生成自定义地图标记图标
class MarkerIconGenerator {
  /// 生成团队成员头像图标（带名字缩写、箭头和状态圆圈）
  /// [statusColor] 状态圆圈颜色，null 表示不显示状态圆圈
  static Future<Uint8List> generateMemberIcon({
    required String nickname,
    required Color color,
    double size = 160,
    Color? statusColor,
  }) async {
    // 为状态圆圈增加画布右上角空间
    final canvasSize = size * 1.15; // 增加15%空间给状态圆圈
    final iconOffset = size * 0.15; // 图标向左下偏移

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
    arrowPath.moveTo(size / 2, size + iconOffset); // 底部中心（指向实际位置）
    arrowPath.lineTo(size / 2 - arrowWidth, size - arrowHeight + iconOffset);
    arrowPath.lineTo(size / 2 + arrowWidth, size - arrowHeight + iconOffset);
    arrowPath.close();

    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, paint);

    // 动态计算圆形位置（考虑三角形高度）
    final circleCenter =
        Offset(size / 2, size / 2 - arrowHeight * 0.25 + iconOffset);
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

    // 画状态圆圈（右上角）
    if (statusColor != null) {
      final statusRadius = size * 0.12;
      // 状态圆圈位于主圆圈的右上角
      final statusCenter = Offset(
        circleCenter.dx + circleRadius * 0.7,
        circleCenter.dy - circleRadius * 0.7,
      );

      // 白色边框
      paint.color = Colors.white;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(statusCenter, statusRadius + 2, paint);

      // 状态颜色填充
      paint.color = statusColor;
      canvas.drawCircle(statusCenter, statusRadius, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成星标图标（用于集合点）
  static Future<Uint8List> generateStarIcon({
    required Color color,
    bool isActive = false,
    double size = 120,
    double strokeWidth = 10,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 画星形
    final outerRadius = size / 2 - strokeWidth - 2;
    final innerRadius = outerRadius * 0.4;
    final starPath =
        _createStarPath(size / 2, size / 2, outerRadius, innerRadius, 5);

    // 白色描边
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = strokeWidth;
    paint.strokeJoin = StrokeJoin.round;
    canvas.drawPath(starPath, paint);

    // 填充
    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(starPath, paint);

    // 如果是活动集合点，添加发光效果
    if (isActive) {
      paint.color = color.withOpacity(0.3);
      final glowPath = _createStarPath(
          size / 2, size / 2, outerRadius + 4, innerRadius + 2, 5);
      paint.style = PaintingStyle.fill;
      canvas.drawPath(glowPath, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成起点图标（绿色圆形带 trip_origin 图标）
  static Future<Uint8List> generateOriginIcon({
    Color color = Colors.green,
    double size = 120,
    double strokeWidth = 4,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - strokeWidth - 2;

    // 白色描边
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + strokeWidth, paint);

    // 填充颜色
    paint.color = color;
    canvas.drawCircle(center, radius, paint);

    // 画 trip_origin 图标（同心圆）
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size * 0.06;
    canvas.drawCircle(center, radius * 0.5, paint);

    // 中心点
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.18, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成终点图标（蓝色圆形带 location_on 图标）
  static Future<Uint8List> generateDestinationIcon({
    Color color = Colors.blue,
    double size = 120,
    double strokeWidth = 4,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - strokeWidth - 2;

    // 白色描边
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + strokeWidth, paint);

    // 填充颜色
    paint.color = color;
    canvas.drawCircle(center, radius, paint);

    // 画 location_on 图标（定位针形状简化）
    final pinRadius = radius * 0.35;
    final pinCenterY = center.dy - radius * 0.1;

    // 外圆
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, pinCenterY), pinRadius, paint);

    // 内圆（空心效果）
    paint.color = color;
    canvas.drawCircle(Offset(center.dx, pinCenterY), pinRadius * 0.4, paint);

    // 下方三角形（针尖）
    final trianglePath = Path();
    trianglePath.moveTo(
        center.dx - pinRadius * 0.5, pinCenterY + pinRadius * 0.6);
    trianglePath.lineTo(center.dx, center.dy + radius * 0.5);
    trianglePath.lineTo(
        center.dx + pinRadius * 0.5, pinCenterY + pinRadius * 0.6);
    trianglePath.close();

    paint.color = Colors.white;
    canvas.drawPath(trianglePath, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成途径点图标（橙色圆形带数字）
  static Future<Uint8List> generateWaypointIcon({
    required int number,
    Color color = Colors.orange,
    double size = 100,
    double strokeWidth = 4,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - strokeWidth - 2;

    // 白色描边
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + strokeWidth, paint);

    // 填充颜色
    paint.color = color;
    canvas.drawCircle(center, radius, paint);

    // 画数字
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

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

  /// 生成方向箭头图标（用于雪道方向指示）
  static Future<Uint8List> generateArrowIcon({
    required Color color,
    double size = 32,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 画向右的三角形箭头（会被 Mapbox 根据线段方向旋转）
    final path = Path();
    final halfSize = size / 2;

    // 三角形顶点朝右
    path.moveTo(size * 0.85, halfSize); // 右边顶点
    path.lineTo(size * 0.15, size * 0.15); // 左上
    path.lineTo(size * 0.15, size * 0.85); // 左下
    path.close();

    // 填充
    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成点击点标记图标（带描边的圆点）
  static Future<Uint8List> generateTapPointIcon({
    required Color color,
    double size = 24,
    double strokeWidth = 3,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final center = size / 2;
    final outerRadius = size / 2 - strokeWidth / 2;
    final innerRadius = outerRadius - strokeWidth;

    // 绘制白色描边
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = strokeWidth;
    canvas.drawCircle(Offset(center, center), outerRadius, paint);

    // 绘制填充圆
    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center, center), innerRadius, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static double _sin(double radians) => math.sin(radians);
}
