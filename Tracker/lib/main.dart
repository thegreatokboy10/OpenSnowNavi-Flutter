import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'config/mapbox_config.dart';
import 'services/session_manager.dart';
import 'services/deep_link_service.dart';
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
    final origin = routeData.origin?.name ?? '未知';
    final destination = routeData.destination?.name ?? '未知';
    final resortKey = routeData.resortKey ?? '未知雪场';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.route, color: Colors.blue),
            SizedBox(width: 8),
            Text('发现分享路线'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('检测到剪贴板中有分享的路线，是否导入？'),
            const SizedBox(height: 16),
            Text('雪场: $resortKey',
                style: TextStyle(color: Colors.grey.shade600)),
            Text('路线: $origin → $destination',
                style: TextStyle(color: Colors.grey.shade600)),
            if (routeData.stopovers.isNotEmpty)
              Text('途径点: ${routeData.stopovers.length}个',
                  style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('忽略'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('导入路线'),
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
    final session = manager.interruptedSession!;
    final duration = DateTime.now().difference(session.startTime);
    final durationStr = _formatDuration(duration);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Recording Interrupted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A recording session was interrupted. Would you like to continue?',
            ),
            const SizedBox(height: 16),
            Text(
              'Started: ${_formatDateTime(session.startTime)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              'Duration: $durationStr',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Recording'),
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
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${mins} min';
    }
    return '$mins min';
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
    // 初始化期间显示加载界面
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.grey.shade600)),
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
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked),
            selectedIcon: Icon(Icons.radio_button_checked, color: Colors.red),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: Colors.blue),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history, color: Colors.orange),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.deepPurple),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
