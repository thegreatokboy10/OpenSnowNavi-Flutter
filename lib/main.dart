import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Import for URL strategy
import 'package:go_router/go_router.dart';
import 'mapbox_view.dart';

void main() {
  setUrlStrategy(PathUrlStrategy()); // Enable clean URLs
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          // Debugging: Print the received parameters
          print("Received route query parameters: $params");

          // Get optional parameters
          final coordsString = params['coords'];
          final resortKey = params['resortKey'];
          final teamId = params['team']; // 团队邀请链接参数

          List<List<double>>? parsedCoordinates;

          if (coordsString != null && coordsString.isNotEmpty) {
            parsedCoordinates = coordsString.split(';').map((coord) {
              final parts = coord.split(',');
              if (parts.length == 2) {
                return [double.parse(parts[0]), double.parse(parts[1])]; // Convert to lat-lng pair
              }
              return null;
            }).where((element) => element != null).cast<List<double>>().toList();
          }

          return MyHomePage(
            coordinates: parsedCoordinates,
            resortKey: resortKey,
            teamId: teamId,
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ultimate Ski Route Planner | SnowNavi',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      routerConfig: _router, // Use GoRouter for routing
    );
  }
}

class MyHomePage extends StatefulWidget {
  final List<List<double>>? coordinates;  // Nullable list of lat-lng pairs
  final String? resortKey; // Nullable resort identifier
  final String? teamId; // 团队ID（从邀请链接获取）

  const MyHomePage({super.key, this.coordinates, this.resortKey, this.teamId});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  late GeneratorPage generatorPage;

  @override
  void initState() {
    super.initState();
    generatorPage = GeneratorPage(
      coordinates: widget.coordinates,
      resortKey: widget.resortKey,
      teamId: widget.teamId,
    ); // Pass parsed data
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Stack(
            children: [
              generatorPage,  // Always visible
              if (selectedIndex == 1) FavoritePage(), // Overlay FavoritePage
            ],
          ),
        );
      }
    );
  }
}

class FavoritePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.8),
      body: Center(
        child: Text(
          'Favorites Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
