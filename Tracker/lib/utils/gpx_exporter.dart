import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';
import '../models/location_point.dart';

/// GPX 文件导出器
class GPXExporter {
  static final _iso8601Format = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

  /// 生成 GPX 内容
  static String generate(Session session, List<LocationPoint> points) {
    final startTimeStr = _iso8601Format.format(session.startTime.toUtc());

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="SnowNavi Tracker"');
    buffer.writeln('     xmlns="http://www.topografix.com/GPX/1/1"');
    buffer.writeln(
        '     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
    buffer.writeln(
        '     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>Ski Session $startTimeStr</name>');
    buffer.writeln('    <time>$startTimeStr</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>Ski Track</name>');
    buffer.writeln('    <type>skiing</type>');
    buffer.writeln('    <trkseg>');

    for (final point in points) {
      final timeStr = _iso8601Format.format(point.timestamp.toUtc());
      buffer.writeln(
          '      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      buffer.writeln(
          '        <ele>${point.altitude.toStringAsFixed(1)}</ele>');
      buffer.writeln('        <time>$timeStr</time>');
      if (point.speed >= 0) {
        buffer.writeln(
            '        <speed>${point.speed.toStringAsFixed(2)}</speed>');
      }
      if (point.heading >= 0) {
        buffer.writeln(
            '        <course>${point.heading.toStringAsFixed(1)}</course>');
      }
      buffer.writeln(
          '        <hdop>${point.horizontalAccuracy.toStringAsFixed(1)}</hdop>');
      buffer.writeln('        <extensions>');
      buffer.writeln('          <isMoving>${point.isMoving}</isMoving>');
      buffer.writeln(
          '          <isAutoPaused>${point.isAutoPaused}</isAutoPaused>');
      buffer.writeln('        </extensions>');
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// 导出到文件并返回路径
  static Future<String?> exportToFile(
      Session session, List<LocationPoint> points) async {
    try {
      final gpxContent = generate(session, points);
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final fileName = 'SnowNavi_${dateFormat.format(session.startTime)}.gpx';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(gpxContent);

      return file.path;
    } catch (e) {
      print('Failed to export GPX: $e');
      return null;
    }
  }
}

