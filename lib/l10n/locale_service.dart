import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'app_strings.dart';
import 'strings_zh.dart';
import 'strings_en.dart';

/// 支持的语言枚举
enum AppLocale {
  zh, // 中文
  en, // 英文
}

/// 语言管理服务
/// 单例模式，管理应用的语言设置
class LocaleService extends ChangeNotifier {
  static final LocaleService _instance = LocaleService._internal();
  static LocaleService get instance => _instance;

  LocaleService._internal() {
    _initLocale();
  }

  AppLocale _currentLocale = AppLocale.en;
  AppStrings _strings = StringsEn();

  /// 当前语言
  AppLocale get currentLocale => _currentLocale;

  /// 当前语言的字符串
  AppStrings get strings => _strings;

  /// 快捷访问当前语言字符串
  static AppStrings get S => _instance._strings;

  /// 初始化语言设置
  void _initLocale() {
    // 1. 先检查 localStorage 中是否有保存的语言设置
    final savedLocale = html.window.localStorage['app_locale'];
    if (savedLocale != null) {
      if (savedLocale == 'zh') {
        _setLocale(AppLocale.zh, save: false);
      } else {
        _setLocale(AppLocale.en, save: false);
      }
      return;
    }

    // 2. 根据系统语言自动选择
    final systemLanguage = html.window.navigator.language.toLowerCase();
    print('[LocaleService] System language: $systemLanguage');

    if (systemLanguage.startsWith('zh')) {
      _setLocale(AppLocale.zh, save: false);
    } else {
      // 默认英文
      _setLocale(AppLocale.en, save: false);
    }
  }

  /// 设置语言
  void _setLocale(AppLocale locale, {bool save = true}) {
    _currentLocale = locale;
    switch (locale) {
      case AppLocale.zh:
        _strings = StringsZh();
        break;
      case AppLocale.en:
        _strings = StringsEn();
        break;
    }

    if (save) {
      // 保存到 localStorage
      html.window.localStorage['app_locale'] = locale == AppLocale.zh ? 'zh' : 'en';
    }
  }

  /// 切换语言
  void setLocale(AppLocale locale) {
    if (_currentLocale == locale) return;
    _setLocale(locale);
    notifyListeners();
  }

  /// 切换到中文
  void setChineseLocale() => setLocale(AppLocale.zh);

  /// 切换到英文
  void setEnglishLocale() => setLocale(AppLocale.en);

  /// 切换语言（中英文切换）
  void toggleLocale() {
    if (_currentLocale == AppLocale.zh) {
      setLocale(AppLocale.en);
    } else {
      setLocale(AppLocale.zh);
    }
  }

  /// 是否是中文
  bool get isChinese => _currentLocale == AppLocale.zh;

  /// 是否是英文
  bool get isEnglish => _currentLocale == AppLocale.en;

  /// 获取当前语言名称
  String get currentLocaleName => isChinese ? '中文' : 'English';

  /// 获取语言图标
  String get localeIcon => isChinese ? '🇨🇳' : '🇬🇧';
}

