import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class GeneratorPage extends StatefulWidget {
  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  // Colors for the map
  Color novice_piste_color = Color.fromARGB(255, 52, 124, 40);
  Color easy_piste_color = Color.fromARGB(255, 63, 162, 246);
  Color lift_color = Color.fromARGB(255, 0, 0, 0);

  MapboxMapController? mapController;
  // Function to create a Flutter icon as an image (in memory) that takes the icon as a parameter
  Future<Uint8List> _createFlutterIconAsImage(IconData iconData, Color color, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Create the Flutter icon widget as a picture
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

    // Convert the picture to an image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Add Flutter icon as an image to Mapbox
  Future<void> _addFlutterIconToMap({
    required IconData icon,
    required Color color,
    required double size,
    required String imageName,
  }) async {
    // Create an image from the Flutter icon
    Uint8List iconImage = await _createFlutterIconAsImage(icon, color, size);

    // Add the image to the Mapbox map
    mapController?.addImage(imageName, iconImage);
  }

  String? geojsonData;

  // Function to load GeoJSON from assets
  Future<void> _loadGeoJsonFromAssets() async {
    String data = await rootBundle.loadString('assets/les_2_alps.geojson');
    setState(() {
      geojsonData = data;
    });
    _addGeoJsonSourceAndLayer();
  }

  // Function to add source and layers for the GeoJSON data
  void _addGeoJsonSourceAndLayer() {
    if (geojsonData == null) return;

    final parsedGeoJson = json.decode(geojsonData!);

    // Separate aerialway features
    final aerialwayFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('aerialway');
      }).toList(),
    };

    // Separate piste:type features and filter out those that have the 'area' key
    final novicePisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        // 检查 feature['properties'] 中是否包含 'piste:type' 键
        // 并且 'piste:type' 的值为 'downhill'
        // 同时排除包含 'area' 键的条目
        final pisteType = feature['properties']['piste:type'];
        final difficulty = feature['properties']['piste:difficulty'];
        return feature['properties'].containsKey('piste:type') &&
              (pisteType == 'downhill' || pisteType == 'connection') &&
              difficulty == 'novice' &&
              !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Separate piste:type features and filter out those that have the 'area' key
    final easyPisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        // 检查 feature['properties'] 中是否包含 'piste:type' 键
        // 并且 'piste:type' 的值为 'downhill'
        // 同时排除包含 'area' 键的条目
        final pisteType = feature['properties']['piste:type'];
        final difficulty = feature['properties']['piste:difficulty'];
        return feature['properties'].containsKey('piste:type') &&
              (pisteType == 'downhill' || pisteType == 'connection') &&
              difficulty == 'easy' &&
              !feature['properties'].containsKey('area');
      }).toList(),
    };


    ////////////////////////////////////////////////////////////////
    // Add novice piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the novice piste source
    mapController?.addSource(
      'novice-piste-source',
      GeojsonSourceProperties(data: novicePisteFeatures),
    );

    // Add green polyline for novice pistes
    mapController?.addLineLayer(
      'novice-piste-source',
      'novice-piste-layer',
      LineLayerProperties(
        lineColor: novice_piste_color.toHexStringRGB(),
        lineWidth: 2.0,
      ),
    );

    // Add arrows for piste:type (one arrow per line)
    mapController?.addSymbolLayer(
      'novice-piste-source',
      'novice-piste-arrow-layer',
      SymbolLayerProperties(
        iconImage: "novice-piste-arrow", // Built-in arrow icon
        symbolPlacement: 'line', // Place along the line
        symbolSpacing: 300, // Ensures only one arrow is placed on the line
        iconAllowOverlap: false,
        iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
        iconRotationAlignment: 'map',
      ),
      minzoom: 14.0,
    );

    ////////////////////////////////////////////////////////////////
    // Add easy piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the easy piste source
    mapController?.addSource(
      'easy-piste-source',
      GeojsonSourceProperties(data: easyPisteFeatures),
    );

    // Add blue polyline for easy pistes
    mapController?.addLineLayer(
      'easy-piste-source',
      'easy-piste-layer',
      LineLayerProperties(
        lineColor: easy_piste_color.toHexStringRGB(),
        lineWidth: 2.0,
      ),
    );

    // Add arrows for piste:type (one arrow per line)
    mapController?.addSymbolLayer(
      'easy-piste-source',
      'easy-piste-arrow-layer',
      SymbolLayerProperties(
        iconImage: "easy-piste-arrow", // Built-in arrow icon
        symbolPlacement: 'line', // Place along the line
        symbolSpacing: 300, // Ensures only one arrow is placed on the line
        iconAllowOverlap: false,
        iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
        iconRotationAlignment: 'map',
      ),
      minzoom: 14.0,
    );


    ////////////////////////////////////////////////////////////////
    // Add aerialway features
    ////////////////////////////////////////////////////////////////
    
    // Add the aerialway source
    mapController?.addSource(
      'aerialway-source',
      GeojsonSourceProperties(data: aerialwayFeatures),
    );

    // Add black polyline for aerialway
    mapController?.addLineLayer(
      'aerialway-source',
      'aerialway-layer',
      LineLayerProperties(
        lineColor: lift_color.toHexStringRGB(),
        lineWidth: 1.0,
        lineDasharray: [2, 2],
      ),
    );

    // Add arrows for aerialway (one arrow per line)
    mapController?.addSymbolLayer(
      'aerialway-source',
      'aerialway-arrow-layer',
      SymbolLayerProperties(
        iconImage: "lift-arrow", // Built-in arrow icon
        symbolPlacement: 'line-center', // Place along the line
        symbolSpacing: 5000000, // Ensures only one arrow is placed on the line
        iconAllowOverlap: false,
        iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
        iconRotationAlignment: 'map',
      ),
      minzoom: 12,
    );

    print('Layers for aerialway and piste added successfully');
  }

  // Function to add the OpenSnowMap pistes layer as the top layer
  void _addPistesLayer() {
    // Add raster source with OpenSnowMap tiles
    mapController?.addSource(
      'pistes',
      RasterSourceProperties(
        tiles: ['https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png'],
        tileSize: 256,
      ),
    );
    print('Raster source for OpenSnowMap added successfully');

    // Add the raster layer as the top layer
    mapController?.addRasterLayer(
      'pistes',  // Source ID
      'pistes-layer', // Layer ID
      RasterLayerProperties(),
    );
    print('Raster layer for OpenSnowMap added successfully');
  }

  void _onStyleLoadedCallback() async {
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: lift_color,
      size: 25.0,
      imageName: 'lift-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: novice_piste_color,
      size: 25.0,
      imageName: 'novice-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: easy_piste_color,
      size: 25.0,
      imageName: 'easy-piste-arrow',
    );
    _loadGeoJsonFromAssets();
  }

  // Callback when the Mapbox map is created
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
  }

  void _onCameraIdle() async {
    // Get the current zoom level and print it
    print('Current zoom level: ${mapController?.cameraPosition?.zoom}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapboxMap(
            accessToken:
                'pk.eyJ1Ijoib2tib3kyMDA4IiwiYSI6ImNsdGE1dzd6OTAxbHQyanA0aWM1MjU5c24ifQ.vbbY3gzL8nnUFctmDv9UBQ',
            onMapCreated: _onMapCreated,
            onCameraIdle: _onCameraIdle,
            onStyleLoadedCallback: _onStyleLoadedCallback,
            initialCameraPosition: CameraPosition(
              target: LatLng(45.009487, 6.124711), // Coordinates for Les 2 Alpes
              zoom: 13,  // Adjust the zoom level if necessary
            ),
            styleString: 'mapbox://styles/okboy2008/clx1zai3s01ck01rb5zsv600u', // Your custom Mapbox style
            compassEnabled: false, // Disable the compass button
          ),
          Positioned(
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
        ],
      ),
    );
  }
}
