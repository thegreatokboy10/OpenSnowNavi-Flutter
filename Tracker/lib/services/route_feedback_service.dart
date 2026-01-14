import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/route_planning_state.dart';
import 'route_engine.dart' as re;

/// 路线反馈服务 - 用于导出路线数据并反馈 Bug
class RouteFeedbackService {
  static const String _feedbackEmail = 'info@snownavi.ski';

  /// 生成反馈数据
  static Map<String, dynamic> generateFeedbackData({
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) {
    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'resortKey': resortKey,
      'request': {
        'origin': planningData.origin != null
            ? {
                'name': planningData.origin!.name,
                'coordinates': {
                  'lng': planningData.origin!.coordinates.lng.toDouble(),
                  'lat': planningData.origin!.coordinates.lat.toDouble(),
                },
              }
            : null,
        'destination': planningData.destination != null
            ? {
                'name': planningData.destination!.name,
                'coordinates': {
                  'lng': planningData.destination!.coordinates.lng.toDouble(),
                  'lat': planningData.destination!.coordinates.lat.toDouble(),
                },
              }
            : null,
        'stopovers': planningData.stopovers
            .map((s) => {
                  'name': s.name,
                  'coordinates': {
                    'lng': s.coordinates.lng.toDouble(),
                    'lat': s.coordinates.lat.toDouble(),
                  },
                })
            .toList(),
      },
      'response': route.rawJson,
    };
  }

  /// 生成邮件主题
  static String generateEmailSubject({
    required RoutePlanningData planningData,
    String? resortKey,
  }) {
    final origin = planningData.origin?.name ?? '未知起点';
    final destination = planningData.destination?.name ?? '未知终点';
    final resort = resortKey ?? 'unknown';
    return '[路线反馈] $resort: $origin → $destination';
  }

  /// 生成邮件正文
  static String generateEmailBody({
    required RoutePlanningData planningData,
    required re.Route route,
  }) {
    final origin = planningData.origin;
    final destination = planningData.destination;
    final stopovers = planningData.stopovers;

    final buffer = StringBuffer();
    buffer.writeln('您好，');
    buffer.writeln();
    buffer.writeln('我发现以下路线存在问题：');
    buffer.writeln();
    buffer.writeln('【路线信息】');
    if (origin != null) {
      buffer.writeln(
          '起点: ${origin.name} (${origin.coordinates.lat.toStringAsFixed(6)}, ${origin.coordinates.lng.toStringAsFixed(6)})');
    }
    for (int i = 0; i < stopovers.length; i++) {
      final s = stopovers[i];
      buffer.writeln(
          '途径点${i + 1}: ${s.name} (${s.coordinates.lat.toStringAsFixed(6)}, ${s.coordinates.lng.toStringAsFixed(6)})');
    }
    if (destination != null) {
      buffer.writeln(
          '终点: ${destination.name} (${destination.coordinates.lat.toStringAsFixed(6)}, ${destination.coordinates.lng.toStringAsFixed(6)})');
    }
    buffer.writeln();
    buffer.writeln('路线距离: ${(route.distance / 1000).toStringAsFixed(2)} km');
    buffer.writeln('预计时间: ${(route.duration / 60).toStringAsFixed(0)} 分钟');
    buffer.writeln();
    buffer.writeln('【问题描述】');
    buffer.writeln('（请在此描述您发现的问题）');
    buffer.writeln();
    buffer.writeln('详细路线数据请查看附件。');
    buffer.writeln();
    buffer.writeln('感谢您的反馈！');

    return buffer.toString();
  }

  /// 保存反馈数据到临时文件
  static Future<File> saveFeedbackToFile({
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) async {
    final data = generateFeedbackData(
      planningData: planningData,
      route: route,
      resortKey: resortKey,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'route_feedback_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );

    return file;
  }

  /// 分享反馈文件
  static Future<void> shareFeedbackFile({
    required BuildContext context,
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) async {
    final file = await saveFeedbackToFile(
      planningData: planningData,
      route: route,
      resortKey: resortKey,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: generateEmailSubject(
        planningData: planningData,
        resortKey: resortKey,
      ),
      text: generateEmailBody(planningData: planningData, route: route),
    );
  }

  /// 通过邮件发送反馈
  static Future<void> sendFeedbackByEmail({
    required BuildContext context,
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) async {
    final file = await saveFeedbackToFile(
      planningData: planningData,
      route: route,
      resortKey: resortKey,
    );

    final subject = Uri.encodeComponent(generateEmailSubject(
      planningData: planningData,
      resortKey: resortKey,
    ));

    final body = Uri.encodeComponent(generateEmailBody(
      planningData: planningData,
      route: route,
    ));

    final mailtoUrl = 'mailto:$_feedbackEmail?subject=$subject&body=$body';
    final uri = Uri.parse(mailtoUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('邮件已打开，请手动添加附件'),
            action: SnackBarAction(
              label: '分享附件',
              onPressed: () async {
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: generateEmailSubject(
          planningData: planningData,
          resortKey: resortKey,
        ),
        text: '请将此文件发送至 $_feedbackEmail\n\n${generateEmailBody(
          planningData: planningData,
          route: route,
        )}',
      );
    }
  }

  /// 路线分享标记前缀和后缀
  static const String routeSharePrefix = '【SNOWNAVI_ROUTE】';
  static const String routeShareSuffix = '【/SNOWNAVI_ROUTE】';

  /// 显示分享选项对话框
  static Future<void> showShareDialog({
    required BuildContext context,
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '分享路线',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share, color: Colors.blue),
              title: const Text('分享到其他应用'),
              subtitle: const Text('微信、QQ 等'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareRoute(
                  context: context,
                  planningData: planningData,
                  route: route,
                  resortKey: resortKey,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.orange),
              title: const Text('复制分享文本'),
              subtitle: const Text('对方复制后打开 App 自动加载'),
              onTap: () async {
                Navigator.pop(ctx);
                await copyRouteText(
                  context: context,
                  planningData: planningData,
                  route: route,
                  resortKey: resortKey,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.red),
              title: const Text('反馈路线问题'),
              subtitle: const Text('发送至 $_feedbackEmail'),
              onTap: () async {
                Navigator.pop(ctx);
                await sendFeedbackByEmail(
                  context: context,
                  planningData: planningData,
                  route: route,
                  resortKey: resortKey,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 生成分享文本
  static String generateShareText({
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) {
    final origin = planningData.origin?.name ?? '未知起点';
    final destination = planningData.destination?.name ?? '未知终点';
    final distanceKm = (route.distance / 1000).toStringAsFixed(1);
    final durationMin = (route.duration / 60).toStringAsFixed(0);

    // 生成紧凑格式的路线数据
    final compactData = _generateCompactString(
      planningData: planningData,
      resortKey: resortKey,
    );

    return '''
🎿 SnowNavi 路线分享

📍 $origin → $destination
📏 距离: $distanceKm km
⏱️ 预计: $durationMin 分钟

复制整段文字，打开 SnowNavi App 自动加载路线
$routeSharePrefix$compactData$routeShareSuffix''';
  }

  /// 生成紧凑格式字符串
  /// 格式: r:resortKey|o:lat,lng,name|d:lat,lng,name|s:lat,lng,name;lat,lng,name
  static String _generateCompactString({
    required RoutePlanningData planningData,
    String? resortKey,
  }) {
    final parts = <String>[];

    // 雪场
    if (resortKey != null && resortKey.isNotEmpty) {
      parts.add('r:$resortKey');
    }

    // 起点
    if (planningData.origin != null) {
      final o = planningData.origin!;
      final lat = o.coordinates.lat.toDouble().toStringAsFixed(6);
      final lng = o.coordinates.lng.toDouble().toStringAsFixed(6);
      // 名称中的特殊字符进行 URL 编码
      final name = Uri.encodeComponent(o.name);
      parts.add('o:$lat,$lng,$name');
    }

    // 终点
    if (planningData.destination != null) {
      final d = planningData.destination!;
      final lat = d.coordinates.lat.toDouble().toStringAsFixed(6);
      final lng = d.coordinates.lng.toDouble().toStringAsFixed(6);
      final name = Uri.encodeComponent(d.name);
      parts.add('d:$lat,$lng,$name');
    }

    // 途径点
    if (planningData.stopovers.isNotEmpty) {
      final stopovers = planningData.stopovers.map((s) {
        final lat = s.coordinates.lat.toDouble().toStringAsFixed(6);
        final lng = s.coordinates.lng.toDouble().toStringAsFixed(6);
        final name = Uri.encodeComponent(s.name);
        return '$lat,$lng,$name';
      }).join(';');
      parts.add('s:$stopovers');
    }

    return parts.join('|');
  }

  /// 分享路线（纯文本）
  static Future<void> shareRoute({
    required BuildContext context,
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) async {
    final shareText = generateShareText(
      planningData: planningData,
      route: route,
      resortKey: resortKey,
    );

    // 直接分享纯文本
    await Share.share(shareText);
  }

  /// 复制路线文本到剪贴板
  static Future<void> copyRouteText({
    required BuildContext context,
    required RoutePlanningData planningData,
    required re.Route route,
    String? resortKey,
  }) async {
    final shareText = generateShareText(
      planningData: planningData,
      route: route,
      resortKey: resortKey,
    );

    await Clipboard.setData(ClipboardData(text: shareText));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('路线分享文本已复制'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
