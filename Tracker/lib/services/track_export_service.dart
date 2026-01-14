import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'database_service.dart';
import '../models/session.dart';
import '../models/location_point.dart';
import '../models/motion_data.dart';

/// 轨迹导出导入服务
class TrackExportService {
  static final DatabaseService _db = DatabaseService();

  /// 导出所有轨迹到 ZIP 文件
  static Future<String?> exportAllTracks() async {
    try {
      final sessions = await _db.getAllSessions();
      if (sessions.isEmpty) return null;

      final archive = Archive();

      for (final session in sessions) {
        final sessionData = await _getSessionData(session);
        final jsonBytes = utf8.encode(jsonEncode(sessionData));
        final fileName = 'session_${session.id}.json';
        archive.addFile(ArchiveFile(fileName, jsonBytes.length, jsonBytes));
      }

      // 添加元数据
      final metadata = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'sessionCount': sessions.length,
        'appVersion': '1.0.0',
      };
      final metaBytes = utf8.encode(jsonEncode(metadata));
      archive
          .addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

      // 压缩
      final zipData = ZipEncoder().encode(archive);

      // 保存文件
      final dir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filePath = '${dir.path}/snownavi_tracks_$timestamp.zip';
      final file = File(filePath);
      await file.writeAsBytes(zipData);

      return filePath;
    } catch (e) {
      debugPrint('[TrackExportService] Export error: $e');
      return null;
    }
  }

  /// 导出单个轨迹
  static Future<String?> exportSession(Session session) async {
    try {
      final sessionData = await _getSessionData(session);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = session.startTime
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final filePath = '${dir.path}/session_$timestamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonEncode(sessionData));

      return filePath;
    } catch (e) {
      debugPrint('[TrackExportService] Export session error: $e');
      return null;
    }
  }

  /// 获取 session 的完整数据
  static Future<Map<String, dynamic>> _getSessionData(Session session) async {
    final points = await _db.getLocationPoints(session.id);
    final motionData = await _db.getMotionData(session.id);

    return {
      'session': session.toMap(),
      'locationPoints': points.map((p) => p.toMap()).toList(),
      'motionData': motionData.map((m) => m.toMap()).toList(),
    };
  }

  /// 分享导出的文件
  static Future<void> shareExport() async {
    final filePath = await exportAllTracks();
    if (filePath != null) {
      await Share.shareXFiles([XFile(filePath)], text: 'SnowNavi 轨迹备份');
    }
  }

  /// 从文件选择器导入轨迹
  static Future<ImportResult> importTracks() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: '未选择文件');
      }

      final file = result.files.first;
      if (file.path == null) {
        return ImportResult(success: false, message: '无法读取文件');
      }

      final filePath = file.path!;
      if (filePath.endsWith('.zip')) {
        return await _importFromZip(filePath);
      } else if (filePath.endsWith('.json')) {
        return await _importFromJson(filePath);
      }

      return ImportResult(success: false, message: '不支持的文件格式');
    } catch (e) {
      debugPrint('[TrackExportService] Import error: $e');
      return ImportResult(success: false, message: '导入失败: $e');
    }
  }

  /// 从 ZIP 文件导入
  static Future<ImportResult> _importFromZip(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    int imported = 0;
    int skipped = 0;

    for (final archiveFile in archive) {
      if (archiveFile.name.endsWith('.json') &&
          archiveFile.name != 'metadata.json') {
        final content = utf8.decode(archiveFile.content as List<int>);
        final json = jsonDecode(content) as Map<String, dynamic>;
        final result = await _importSessionData(json);
        if (result) {
          imported++;
        } else {
          skipped++;
        }
      }
    }

    return ImportResult(
      success: true,
      message: '导入完成：$imported 条轨迹，跳过 $skipped 条重复',
      importedCount: imported,
      skippedCount: skipped,
    );
  }

  /// 从 JSON 文件导入单个 session
  static Future<ImportResult> _importFromJson(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    final result = await _importSessionData(json);
    if (result) {
      return ImportResult(
        success: true,
        message: '导入成功：1 条轨迹',
        importedCount: 1,
      );
    } else {
      return ImportResult(
        success: false,
        message: '轨迹已存在，跳过导入',
        skippedCount: 1,
      );
    }
  }

  /// 导入 session 数据
  static Future<bool> _importSessionData(Map<String, dynamic> json) async {
    try {
      final sessionMap = json['session'] as Map<String, dynamic>;
      final session = Session.fromMap(sessionMap);

      // 检查是否已存在
      final existing = await _db.getSession(session.id);
      if (existing != null) {
        debugPrint('[TrackExportService] Session ${session.id} already exists');
        return false;
      }

      // 插入 session
      await _db.insertSession(session);

      // 插入位置点
      final pointsList = json['locationPoints'] as List<dynamic>?;
      if (pointsList != null) {
        for (final pointMap in pointsList) {
          final point = LocationPoint.fromMap(pointMap as Map<String, dynamic>);
          await _db.insertLocationPoint(point);
        }
      }

      // 插入运动数据
      final motionList = json['motionData'] as List<dynamic>?;
      if (motionList != null) {
        for (final motionMap in motionList) {
          final motion = MotionData.fromMap(motionMap as Map<String, dynamic>);
          await _db.insertMotionData(motion);
        }
      }

      return true;
    } catch (e) {
      debugPrint('[TrackExportService] Import session error: $e');
      return false;
    }
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final int skippedCount;

  ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.skippedCount = 0,
  });
}
