# SnowNavi Tracker 主题颜色规范

本文档定义了应用中所有面板、按钮、控件的统一颜色规范。

## 颜色定义文件

所有颜色定义在 `lib/config/app_theme.dart` 文件中。

## 主色调

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| primaryColor | `#2196F3` (蓝色) | 标题栏、按钮、强调色 |
| primaryLightColor | `#E3F2FD` | 背景高亮、选中状态 |
| primaryDarkColor | `#1976D2` | 深色文字、图标 |

## 面板颜色

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| panelBackground | `#FFFFFF` (白色) | 面板背景 |
| panelHeaderBackground | 同 primaryColor | 面板标题栏背景 |
| panelHeaderText | `#FFFFFF` (白色) | 面板标题栏文字 |

## 按钮颜色

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| buttonPrimaryBackground | 同 primaryColor | 主按钮背景 |
| buttonPrimaryText | `#FFFFFF` (白色) | 主按钮文字 |
| buttonActiveBackground | 同 primaryColor | 激活状态按钮背景 |
| buttonInactiveBackground | `#FFFFFF` (白色) | 非激活状态按钮背景 |
| buttonActiveIconColor | `#FFFFFF` (白色) | 激活状态图标颜色 |
| buttonInactiveIconColor | 同 primaryColor | 非激活状态图标颜色 |

## 状态颜色

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| successColor | `#4CAF50` (绿色) | 成功/正常状态 |
| warningColor | `#FF9800` (橙色) | 警告状态 |
| errorColor | `#F44336` (红色) | 错误状态 |
| infoColor | 同 primaryColor | 信息状态 |

## 文字颜色

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| textPrimary | `#212121` | 主文字 |
| textSecondary | `#757575` | 次要文字 |
| textHint | `#9E9E9E` | 提示文字 |

## 路线规划颜色

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| originColor | `#4CAF50` (绿色) | 起点标记 |
| destinationColor | `#2196F3` (蓝色) | 终点标记 |
| stopoverColor | `#FF9800` (橙色) | 途径点标记 |

## 团队功能颜色

| 名称 | 颜色值 | 用途 |
|------|--------|------|
| meetingPointColor | `#FFC107` (黄色) | 集合点标记 |
| meetingPointActiveColor | `#FF9800` (橙色) | 活动集合点标记 |

## 使用方法

### 在 Flutter Widget 中使用

```dart
import '../config/app_theme.dart';

// 使用颜色
Container(
  color: AppTheme.primaryColor,
  child: Text(
    '标题',
    style: TextStyle(color: AppTheme.panelHeaderText),
  ),
);

// 使用装饰
Container(
  decoration: AppTheme.panelDecoration,
  child: ...
);

// 使用面板头部装饰
Container(
  decoration: AppTheme.panelHeaderDecoration,
  child: ...
);
```

### 在 Mapbox 标记中使用 (需要 int 格式)

```dart
CircleAnnotationOptions(
  circleColor: AppTheme.meetingPointColorInt,  // 使用 Int 后缀的版本
);
```

## 注意事项

1. **所有面板标题栏**应使用 `panelHeaderBackground` 和 `panelHeaderText`
2. **所有主按钮**应使用 `buttonPrimaryBackground` 和 `buttonPrimaryText`
3. **浮动按钮**激活状态使用 `buttonActiveBackground`，非激活状态使用 `buttonInactiveBackground`
4. **Mapbox 标记**需要使用 int 格式的颜色值（如 `meetingPointColorInt`）
5. **新增颜色**时应在 `app_theme.dart` 中定义，并更新本文档

