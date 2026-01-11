import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'config/mapbox_config.dart';
import 'services/session_manager.dart';
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

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
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
      }
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
