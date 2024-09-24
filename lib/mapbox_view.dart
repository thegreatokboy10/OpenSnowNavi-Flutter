import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class GeneratorPage extends StatefulWidget {
  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  Color novicePisteColor = Color.fromARGB(255, 52, 124, 40);
  Color easyPisteColor = Color.fromARGB(255, 63, 162, 246);
  Color intermediatePisteColor = Color.fromARGB(255, 199, 37, 62);
  Color advancedPisteColor = Color.fromARGB(200, 27, 27, 27);
  Color liftColor = Color.fromARGB(255, 0, 0, 0);
  double iconSize = 50;

  late MapboxMap _mapboxMap;
  String? geojsonData;

  Future<Uint8List> _createFlutterIconAsImage(IconData iconData, Color color, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(0.0, 0.0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _addFlutterIconToMap(IconData icon, Color color, double size, String imageName) async {
    Uint8List iconImage = await _createFlutterIconAsImage(icon, color, size);
    // _mapboxMap.addImage(imageName, iconImage);
  }

  Future<void> _loadGeoJsonFromAssets() async {
    String data = await rootBundle.loadString('assets/les_2_alps.geojson');
    setState(() {
      geojsonData = data;
    });
    _addGeoJsonSourceAndLayer();
  }

  void _addGeoJsonSourceAndLayer() {
    if (geojsonData == null) return;

    final parsedGeoJson = json.decode(geojsonData!);

    // Novice Pistes
    final novicePisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('piste:type') &&
               feature['properties']['piste:type'] == 'downhill' &&
               feature['properties']['piste:difficulty'] == 'novice' &&
               !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Easy Pistes
    final easyPisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('piste:type') &&
               feature['properties']['piste:type'] == 'downhill' &&
               feature['properties']['piste:difficulty'] == 'easy' &&
               !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Intermediate Pistes
    final intermediatePisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('piste:type') &&
               feature['properties']['piste:type'] == 'downhill' &&
               feature['properties']['piste:difficulty'] == 'intermediate' &&
               !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Advanced Pistes
    final advancedPisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('piste:type') &&
               feature['properties']['piste:type'] == 'downhill' &&
               feature['properties']['piste:difficulty'] == 'advanced' &&
               !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Lifts
    final liftFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('lift:type');
      }).toList(),
    };
  }

  void _onStyleLoadedCallback() {
     _addFlutterIconToMap(Icons.arrow_right, liftColor, iconSize, 'lift-arrow');
     _addFlutterIconToMap(Icons.arrow_right, novicePisteColor, iconSize, 'novice-piste-arrow');
     _addFlutterIconToMap(Icons.arrow_right, easyPisteColor, iconSize, 'easy-piste-arrow');
     _addFlutterIconToMap(Icons.arrow_right, intermediatePisteColor, iconSize, 'intermediate-piste-arrow');
     _addFlutterIconToMap(Icons.arrow_right, advancedPisteColor, iconSize, 'advanced-piste-arrow');
     _loadGeoJsonFromAssets();
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
  }

  @override
  Widget build(BuildContext context) {
    MapboxOptions.setAccessToken(
      "pk.eyJ1Ijoib2tib3kyMDA4IiwiYSI6ImNsdGE1dzd6OTAxbHQyanA0aWM1MjU5c24ifQ.vbbY3gzL8nnUFctmDv9UBQ");
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            styleUri: 'mapbox://styles/okboy2008/clx1zai3s01ck01rb5zsv600u',
            cameraOptions: CameraOptions(
              zoom: 13,
              center: Point(
                coordinates: Position(6.124711, 45.009487), // Your coordinates
              ),
              pitch: 80,
              bearing: 41,
            ),
          ),
          SafeArea(
            child: Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),  // Set opacity to 0.6
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search location',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
