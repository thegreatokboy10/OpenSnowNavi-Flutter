import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'config/mapbox_config.dart';
import 'services/session_manager.dart';
import 'services/deep_link_service.dart';
import 'team/team_service.dart';
import 'views/recording_view.dart';
import 'views/session_list_view.dart';
import 'views/map_view.dart';
import 'views/me_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 Mapbox Access Token
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  runApp(const SnowNaviTrackerApp());
}

class SnowNaviTrackerApp extends StatelessWidget {
  const SnowNaviTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionManager(),
      child: MaterialApp(
        title: 'SnowNavi Tracker',
        // 多语言支持配置
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        // 根据系统语言自动选择，如果不支持则默认英文
        localeResolutionCallback: (locale, supportedLocales) {
          // 如果系统语言在支持列表中，使用系统语言
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale?.languageCode) {
              return supportedLocale;
            }
          }
          // 否则默认使用英文
          return const Locale('en');
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const MainPage(),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台回到前台时检查剪贴板
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForRoute();
    }
  }

  Future<void> _initializeApp() async {
    final manager = context.read<SessionManager>();
    // 先初始化 SessionManager（检查未完成的 session）
    await manager.initialize();
    // 然后请求权限
    await manager.requestPermission();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
      // 检查是否有中断的录制需要恢复
      if (manager.hasInterruptedSession) {
        _showInterruptedSessionDialog(manager);
      } else {
        // 没有中断的录制，检查剪贴板
        _checkClipboardForRoute();
      }
    }
  }

  /// 检查剪贴板中是否有分享的路线
  Future<void> _checkClipboardForRoute() async {
    debugPrint('[MainPage] Checking clipboard for route...');
    final routeData = await DeepLinkService.instance.checkClipboardForRoute();
    debugPrint(
        '[MainPage] Route data: ${routeData != null ? 'found' : 'not found'}');
    if (routeData != null && mounted) {
      debugPrint('[MainPage] Showing route import dialog');
      _showRouteImportDialog(routeData);
    }
  }

  /// 显示路线导入确认对话框
  Future<void> _showRouteImportDialog(SharedRouteData routeData) async {
    final l10n = S.of(context)!;
    final origin = routeData.origin?.name ?? l10n.unknown;
    final destination = routeData.destination?.name ?? l10n.unknown;
    final resortKey = routeData.resortKey ?? l10n.unknownResort;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.route, color: Colors.blue),
            const SizedBox(width: 8),
            Text(l10n.sharedRouteFound),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sharedRouteMessage),
            const SizedBox(height: 16),
            Text(l10n.resort(resortKey),
                style: TextStyle(color: Colors.grey.shade600)),
            Text(l10n.route(origin, destination),
                style: TextStyle(color: Colors.grey.shade600)),
            if (routeData.stopovers.isNotEmpty)
              Text(l10n.stopovers(routeData.stopovers.length),
                  style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ignore),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.importRoute),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // 存储路线数据供 MapView 使用（MapView 会在显示时检测并加载）
      DeepLinkService.instance.handleRouteData(routeData);
      // 切换到地图页面
      setState(() {
        _selectedIndex = 1;
      });
    }
  }

  /// 显示中断录制恢复对话框
  Future<void> _showInterruptedSessionDialog(SessionManager manager) async {
    final l10n = S.of(context)!;
    final session = manager.interruptedSession!;
    final duration = DateTime.now().difference(session.startTime);
    final durationStr = _formatDuration(duration);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.recordingInterrupted),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.recordingInterruptedMessage),
            const SizedBox(height: 16),
            Text(
              l10n.started(_formatDateTime(session.startTime)),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              l10n.duration(durationStr),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.discard),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.continueRecording),
          ),
        ],
      ),
    );

    if (result == true) {
      // 恢复录制
      await manager.resumeInterruptedSession();
      // 切换到录制页面
      setState(() {
        _selectedIndex = 0;
      });
    } else {
      // 放弃录制
      await manager.discardInterruptedSession();
    }
  }

  String _formatDuration(Duration d) {
    final l10n = S.of(context);
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    if (hours > 0) {
      return l10n?.hourMinute(hours, mins) ?? '$hours hr $mins min';
    }
    return l10n?.minuteOnly(mins) ?? '$mins min';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 导航到 Me 页面（用于从其他页面跳转）
  void _navigateToMePage() {
    setState(() {
      _selectedIndex = 3; // Me 页面的索引
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    // 初始化期间显示加载界面
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n?.loading ?? 'Loading...',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const RecordingView(),
          MapView(onNavigateToLogin: _navigateToMePage),
          const SessionListView(),
          const MeView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // 通知 TeamService 地图页面的前台/后台状态
          // index == 1 表示地图页面
          TeamService.instance.setForegroundMode(index == 1);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.radio_button_checked),
            selectedIcon:
                const Icon(Icons.radio_button_checked, color: Colors.red),
            label: l10n?.tabRecord ?? 'Record',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map, color: Colors.blue),
            label: l10n?.tabMap ?? 'Map',
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.history, color: Colors.orange),
            label: l10n?.tabHistory ?? 'History',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: Colors.deepPurple),
            label: l10n?.tabMe ?? 'Me',
          ),
        ],
      ),
    );
  }
}
