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

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final manager = context.read<SessionManager>();
    await manager.requestPermission();
  }

  /// 导航到 Me 页面（用于从其他页面跳转）
  void _navigateToMePage() {
    setState(() {
      _selectedIndex = 3; // Me 页面的索引
    });
  }

  @override
  Widget build(BuildContext context) {
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
