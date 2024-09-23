import 'package:flutter/material.dart';
import 'mapbox_view.dart';  // Make sure to import your mapbox_view.dart

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GeneratorPage _generatorPage = GeneratorPage();  // Persistent instance of GeneratorPage

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultimate Ski Route Planner | SnowNavi',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: MyHomePage(generatorPage: _generatorPage),  // Pass the persistent instance
    );
  }
}

class MyHomePage extends StatefulWidget {
  final GeneratorPage generatorPage;

  MyHomePage({required this.generatorPage});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;  // Control which page to show on top

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Stack(
            children: [
              // GeneratorPage is always visible
              widget.generatorPage,

              // FavoritePage is shown on top when selectedIndex == 1
              if (selectedIndex == 1)
                FavoritePage(),  // Overlay the FavoritePage
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: selectedIndex,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
            ],
            onTap: (index) {
              setState(() {
                selectedIndex = index;  // Change the index to show/hide FavoritePage
              });
            },
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
      backgroundColor: Colors.white.withOpacity(0.8),  // Semi-transparent background
      body: Center(
        child: Text(
          'Favorites Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
