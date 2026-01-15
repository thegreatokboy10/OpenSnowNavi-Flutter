import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 生成媒体标注图标（圆形缩略图）
class MediaMarkerIconGenerator {
  /// 生成圆形缩略图标注
  /// [thumbnailData] 缩略图数据
  /// [isVideo] 是否为视频（显示播放图标）
  /// [size] 图标尺寸
  /// [borderWidth] 边框宽度
  static Future<Uint8List> generateThumbnailIcon({
    required Uint8List thumbnailData,
    required bool isVideo,
    double size = 80,
    double borderWidth = 4,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - borderWidth;

    // 1. 绘制白色边框
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, paint);

    // 2. 绘制阴影效果
    paint.color = Colors.black.withOpacity(0.2);
    canvas.drawCircle(Offset(center.dx + 1, center.dy + 2), radius, paint);

    // 3. 裁剪为圆形并绘制缩略图
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // 解码并绘制缩略图
    final codec = await ui.instantiateImageCodec(thumbnailData);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // 缩放并居中图片以填充圆形
    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    canvas.restore();

    // 4. 如果是视频，绘制播放图标
    if (isVideo) {
      _drawPlayButton(canvas, center, radius * 0.35);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 生成聚合标注图标（带数量徽章）
  /// [thumbnailData] 第一张缩略图数据
  /// [count] 聚合数量
  /// [hasVideo] 聚合中是否包含视频
  static Future<Uint8List> generateClusterIcon({
    required Uint8List thumbnailData,
    required int count,
    bool hasVideo = false,
    double size = 90,
    double borderWidth = 4,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - borderWidth - 8; // 留空间给徽章

    // 1. 绘制白色边框
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + borderWidth, paint);

    // 2. 绘制阴影效果
    paint.color = Colors.black.withOpacity(0.2);
    canvas.drawCircle(Offset(center.dx + 1, center.dy + 2), radius, paint);

    // 3. 裁剪为圆形并绘制缩略图
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final codec = await ui.instantiateImageCodec(thumbnailData);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    canvas.restore();

    // 4. 绘制半透明遮罩（表示有多张）
    paint.color = Colors.black.withOpacity(0.3);
    canvas.drawCircle(center, radius, paint);

    // 5. 绘制数量徽章（右上角）
    final badgeRadius = size * 0.18;
    final badgeCenter = Offset(
      center.dx + radius * 0.7,
      center.dy - radius * 0.7,
    );

    // 白色边框
    paint.color = Colors.white;
    canvas.drawCircle(badgeCenter, badgeRadius + 2, paint);

    // 橙色填充
    paint.color = Colors.orange;
    canvas.drawCircle(badgeCenter, badgeRadius, paint);

    // 数量文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: badgeRadius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx - textPainter.width / 2,
        badgeCenter.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 绘制播放按钮
  static void _drawPlayButton(Canvas canvas, Offset center, double size) {
    final paint = Paint();

    // 半透明背景圆
    paint.color = Colors.black.withOpacity(0.5);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, size, paint);

    // 白色播放三角形
    paint.color = Colors.white.withOpacity(0.9);
    final path = Path();
    final triangleSize = size * 0.6;
    // 三角形顶点朝右
    path.moveTo(center.dx + triangleSize * 0.5, center.dy);
    path.lineTo(center.dx - triangleSize * 0.3, center.dy - triangleSize * 0.5);
    path.lineTo(center.dx - triangleSize * 0.3, center.dy + triangleSize * 0.5);
    path.close();
    canvas.drawPath(path, paint);
  }
}
