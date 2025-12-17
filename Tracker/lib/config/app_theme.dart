import 'package:flutter/material.dart';

/// App 主题颜色规范
///
/// 统一定义所有面板、按钮、控件的颜色，确保整个应用风格一致
class AppTheme {
  AppTheme._();

  // ============ 主色调 ============

  /// 主色调 - 蓝色 (用于标题栏、按钮、强调色)
  static const Color primaryColor = Color(0xFF2196F3);

  /// 主色调浅色 (用于背景高亮、选中状态)
  static const Color primaryLightColor = Color(0xFFE3F2FD);

  /// 主色调深色 (用于深色文字、图标)
  static const Color primaryDarkColor = Color(0xFF1976D2);

  // ============ 面板颜色 ============

  /// 面板背景色
  static const Color panelBackground = Colors.white;

  /// 面板标题栏背景色 (黑色，与路线规划面板一致)
  static const Color panelHeaderBackground = Color(0xFF212121);

  /// 面板标题栏文字色
  static const Color panelHeaderText = Colors.white;

  /// Toggle 开启时的颜色 (蓝色)
  static Color get toggleActiveColor => primaryColor;

  /// Toggle 关闭时的轨道颜色
  static const Color toggleInactiveTrackColor = Color(0xFFE0E0E0);

  /// 面板阴影
  static List<BoxShadow> get panelShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  // ============ 按钮颜色 ============

  /// 主按钮背景色
  static Color get buttonPrimaryBackground => primaryColor;

  /// 主按钮文字色
  static const Color buttonPrimaryText = Colors.white;

  /// 按钮激活时背景色
  static Color get buttonActiveBackground => primaryColor;

  /// 按钮非激活时背景色
  static const Color buttonInactiveBackground = Colors.white;

  /// 按钮非激活时图标/文字色
  static Color get buttonInactiveIconColor => primaryColor;

  /// 按钮激活时图标/文字色
  static const Color buttonActiveIconColor = Colors.white;

  // ============ 状态颜色 ============

  /// 成功/正常状态 - 绿色
  static const Color successColor = Color(0xFF4CAF50);

  /// 警告状态 - 橙色
  static const Color warningColor = Color(0xFFFF9800);

  /// 错误状态 - 红色
  static const Color errorColor = Color(0xFFF44336);

  /// 信息状态 - 蓝色
  static Color get infoColor => primaryColor;

  // ============ 文字颜色 ============

  /// 主文字色
  static const Color textPrimary = Color(0xFF212121);

  /// 次要文字色
  static const Color textSecondary = Color(0xFF757575);

  /// 提示文字色
  static const Color textHint = Color(0xFF9E9E9E);

  // ============ 辅助颜色 ============

  /// 分割线颜色
  static const Color dividerColor = Color(0xFFE0E0E0);

  /// 遮罩层颜色
  static Color get overlayColor => Colors.black.withOpacity(0.3);

  // ============ 路线规划特定颜色 (来自 SkiResorts) ============

  /// 起点颜色 - 绿色
  static const Color originColor = Color(0xFF4CAF50);

  /// 终点颜色 - 蓝色
  static const Color destinationColor = Color(0xFF2196F3);

  /// 途径点颜色 - 橙色
  static const Color stopoverColor = Color(0xFFFF9800);

  // ============ 团队功能特定颜色 ============

  /// 集合点颜色 - 星星黄色
  static const Color meetingPointColor = Color(0xFFFFC107);

  /// 集合点激活颜色
  static const Color meetingPointActiveColor = Color(0xFFFF9800);

  /// 集合点颜色 (int 格式，用于 Mapbox)
  static const int meetingPointColorInt = 0xFFFFC107;

  /// 集合点激活颜色 (int 格式，用于 Mapbox)
  static const int meetingPointActiveColorInt = 0xFFFF9800;

  // ============ 图标尺寸配置 ============

  /// 队员头像图标尺寸
  static const double memberIconSize = 160;

  /// 队员头像图标显示缩放比例
  static const double memberIconScale = 0.9;

  /// 集合点星标图标尺寸（激活状态）
  static const double meetingPointIconActiveSize = 150;

  /// 集合点星标图标尺寸（普通状态）
  static const double meetingPointIconSize = 120;

  /// 集合点图标显示缩放比例
  static const double meetingPointIconScale = 0.8;

  /// 起点图标尺寸（与星标一致）
  static const double originIconSize = 120;

  /// 终点图标尺寸（与星标一致）
  static const double destinationIconSize = 120;

  /// 途径点图标尺寸
  static const double waypointIconSize = 100;

  /// 路线点图标缩放比例
  static const double routePointIconScale = 0.8;

  /// 图标描边宽度
  static const double markerStrokeWidth = 10.0;

  // ============ 地图标签和箭头显示阈值 ============

  /// 显示雪道/缆车名称的最小缩放级别
  static const double labelMinZoom = 14.0;

  /// 显示雪道方向箭头的最小缩放级别
  static const double arrowMinZoom = 14.0;

  /// 雪道名称字体大小
  static const double pisteNameFontSize = 12.0;

  /// 缆车名称字体大小
  static const double liftNameFontSize = 12.0;

  /// 名称标签文字光晕宽度（用于增加可读性）
  static const double labelHaloWidth = 1.5;

  /// 方向箭头间距（像素）
  static const double arrowSpacing = 300.0;

  /// 方向箭头图标大小（像素，用于生成图标）
  static const double arrowIconSize = 32.0;

  /// 方向箭头显示缩放比例
  static const double arrowSize = 0.5;

  // ============ 装饰方法 ============

  /// 获取面板装饰
  static BoxDecoration get panelDecoration => BoxDecoration(
        color: panelBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: panelShadow,
      );

  /// 获取面板头部装饰
  static const BoxDecoration panelHeaderDecoration = BoxDecoration(
    color: panelHeaderBackground,
    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
  );
}
