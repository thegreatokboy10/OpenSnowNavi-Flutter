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
  Color connection_piste_color = Color.fromARGB(255, 52, 124, 40);
  Color novice_piste_color = Color.fromARGB(255, 52, 124, 40);
  Color easy_piste_color = Color.fromARGB(255, 63, 162, 246);
  Color intermediate_piste_color = Color.fromARGB(255, 199, 37, 62);
  Color advanced_piste_color = Color.fromARGB(200, 27, 27, 27);
  Color expert_piste_color = Color.fromARGB(255, 255, 136, 91);
  Color lift_color = Color.fromARGB(255, 0, 0, 0);
  // Icon size
  double iconSize = 30;
  // Piste/Lift name
  double fontSize = 13;
  double nameOffset = 0.6;
  // Floating button
  double floatingbuttonopacity = 0.8;

  // Variable to track whether the map is in 3D mode or not
  bool is3DMode = false;

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
  Future<void> _loadGeoJsonFromAssets(String filepath) async {
    String data = await rootBundle.loadString(filepath);
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
    final connectionPisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        // 检查 feature['properties'] 中是否包含 'piste:type' 键
        // 并且 'piste:type' 的值为 'downhill'
        // 同时排除包含 'area' 键的条目
        final pisteType = feature['properties']['piste:type'];
        final difficulty = feature['properties']['piste:difficulty'];
        return feature['properties'].containsKey('piste:type') &&
              pisteType == 'connection' && 
              !feature['properties'].containsKey('area');
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
              pisteType == 'downhill' && 
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
              pisteType == 'downhill' &&
              difficulty == 'easy' &&
              !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Separate piste:type features and filter out those that have the 'area' key
    final intermediatePisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        // 检查 feature['properties'] 中是否包含 'piste:type' 键
        // 并且 'piste:type' 的值为 'downhill'
        // 同时排除包含 'area' 键的条目
        final pisteType = feature['properties']['piste:type'];
        final difficulty = feature['properties']['piste:difficulty'];
        return feature['properties'].containsKey('piste:type') &&
              pisteType == 'downhill' &&
              difficulty == 'intermediate' &&
              !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Separate piste:type features and filter out those that have the 'area' key
    final advancedPisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        // 检查 feature['properties'] 中是否包含 'piste:type' 键
        // 并且 'piste:type' 的值为 'downhill'
        // 同时排除包含 'area' 键的条目
        final pisteType = feature['properties']['piste:type'];
        final difficulty = feature['properties']['piste:difficulty'];
        return feature['properties'].containsKey('piste:type') &&
              pisteType == 'downhill' &&
              difficulty == 'advanced' &&
              !feature['properties'].containsKey('area');
      }).toList(),
    };

    // Separate piste:type features and filter out those that have the 'area' key
    final expertPisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        // 检查 feature['properties'] 中是否包含 'piste:type' 键
        // 并且 'piste:type' 的值为 'downhill'
        // 同时排除包含 'area' 键的条目
        final pisteType = feature['properties']['piste:type'];
        final difficulty = feature['properties']['piste:difficulty'];
        return feature['properties'].containsKey('piste:type') &&
              pisteType == 'downhill' &&
              difficulty == 'expert' &&
              !feature['properties'].containsKey('area');
      }).toList(),
    };

    ////////////////////////////////////////////////////////////////
    // Add connection piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the connection piste source
    mapController?.addSource(
      'connection-piste-source',
      GeojsonSourceProperties(data: connectionPisteFeatures),
    );

    // Add green polyline for connection pistes
    mapController?.addLineLayer(
      'connection-piste-source',
      'connection-piste-layer',
      LineLayerProperties(
        lineColor: connection_piste_color.toHexStringRGB(),
        lineWidth: 2.0,
      ),
    );

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

    // Add piste name labels along the piste lines
    mapController?.addSymbolLayer(
      'novice-piste-source',
      'novice-piste-name-layer',
      SymbolLayerProperties(
        textField: ['get', 'name'],  // Use 'piste:name' property from GeoJSON
        textSize: fontSize,
        symbolPlacement: 'line',  // Place labels along the line
        textAnchor: 'center',  // Anchor the text in the center
        textAllowOverlap: false,  // Prevent overlapping text
        textOffset: [0, nameOffset],  // Adjust text position slightly
        textColor: novice_piste_color.toHexStringRGB(),  // Set text color
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

    // Add piste name labels along the piste lines
    mapController?.addSymbolLayer(
      'easy-piste-source',
      'easy-piste-name-layer',
      SymbolLayerProperties(
        textField: ['get', 'name'],  // Use 'piste:name' property from GeoJSON
        textSize: fontSize,
        symbolPlacement: 'line',  // Place labels along the line
        textAnchor: 'center',  // Anchor the text in the center
        textAllowOverlap: false,  // Prevent overlapping text
        textOffset: [0, nameOffset],  // Adjust text position slightly
        textColor: easy_piste_color.toHexStringRGB(),  // Set text color
      ),
      minzoom: 14.0,
    );

    ////////////////////////////////////////////////////////////////
    // Add intermediate piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the intermediate piste source
    mapController?.addSource(
      'intermediate-piste-source',
      GeojsonSourceProperties(data: intermediatePisteFeatures),
    );

    // Add red polyline for intermediate pistes
    mapController?.addLineLayer(
      'intermediate-piste-source',
      'intermediate-piste-layer',
      LineLayerProperties(
        lineColor: intermediate_piste_color.toHexStringRGB(),
        lineWidth: 2.0,
      ),
    );

    // Add arrows for piste:type (one arrow per line)
    mapController?.addSymbolLayer(
      'intermediate-piste-source',
      'intermediate-piste-arrow-layer',
      SymbolLayerProperties(
        iconImage: "intermediate-piste-arrow", // Built-in arrow icon
        symbolPlacement: 'line', // Place along the line
        symbolSpacing: 300, // Ensures only one arrow is placed on the line
        iconAllowOverlap: false,
        iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
        iconRotationAlignment: 'map',
      ),
      minzoom: 14.0,
    );

    // Add piste name labels along the piste lines
    mapController?.addSymbolLayer(
      'intermediate-piste-source',
      'intermediate-piste-name-layer',
      SymbolLayerProperties(
        textField: ['get', 'name'],  // Use 'piste:name' property from GeoJSON
        textSize: fontSize,
        symbolPlacement: 'line',  // Place labels along the line
        textAnchor: 'center',  // Anchor the text in the center
        textAllowOverlap: false,  // Prevent overlapping text
        textOffset: [0, nameOffset],  // Adjust text position slightly
        textColor: intermediate_piste_color.toHexStringRGB(),  // Set text color
      ),
      minzoom: 14.0,
    );

    ////////////////////////////////////////////////////////////////
    // Add advanced piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the advanced piste source
    mapController?.addSource(
      'advanced-piste-source',
      GeojsonSourceProperties(data: advancedPisteFeatures),
    );

    // Add black polyline for advanced pistes
    mapController?.addLineLayer(
      'advanced-piste-source',
      'advanced-piste-layer',
      LineLayerProperties(
        lineColor: advanced_piste_color.toHexStringRGB(),
        lineWidth: 2.0,
      ),
    );

    // Add arrows for piste:type (one arrow per line)
    mapController?.addSymbolLayer(
      'advanced-piste-source',
      'advanced-piste-arrow-layer',
      SymbolLayerProperties(
        iconImage: "advanced-piste-arrow", // Built-in arrow icon
        symbolPlacement: 'line', // Place along the line
        symbolSpacing: 300, // Ensures only one arrow is placed on the line
        iconAllowOverlap: false,
        iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
        iconRotationAlignment: 'map',
      ),
      minzoom: 14.0,
    );

    // Add piste name labels along the piste lines
    mapController?.addSymbolLayer(
      'advanced-piste-source',
      'advanced-piste-name-layer',
      SymbolLayerProperties(
        textField: ['get', 'name'],  // Use 'piste:name' property from GeoJSON
        textSize: fontSize,
        symbolPlacement: 'line',  // Place labels along the line
        textAnchor: 'center',  // Anchor the text in the center
        textAllowOverlap: false,  // Prevent overlapping text
        textOffset: [0, nameOffset],  // Adjust text position slightly
        textColor: advanced_piste_color.toHexStringRGB(),  // Set text color
      ),
      minzoom: 14.0,
    );

    ////////////////////////////////////////////////////////////////
    // Add expert piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the expert piste source
    mapController?.addSource(
      'expert-piste-source',
      GeojsonSourceProperties(data: expertPisteFeatures),
    );

    // Add black polyline for expert pistes
    mapController?.addLineLayer(
      'expert-piste-source',
      'expert-piste-layer',
      LineLayerProperties(
        lineColor: expert_piste_color.toHexStringRGB(),
        lineWidth: 2.0,
      ),
    );

    // Add arrows for piste:type (one arrow per line)
    mapController?.addSymbolLayer(
      'expert-piste-source',
      'expert-piste-arrow-layer',
      SymbolLayerProperties(
        iconImage: "expert-piste-arrow", // Built-in arrow icon
        symbolPlacement: 'line', // Place along the line
        symbolSpacing: 300, // Ensures only one arrow is placed on the line
        iconAllowOverlap: false,
        iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
        iconRotationAlignment: 'map',
      ),
      minzoom: 14.0,
    );

    // Add piste name labels along the piste lines
    mapController?.addSymbolLayer(
      'expert-piste-source',
      'expert-piste-name-layer',
      SymbolLayerProperties(
        textField: ['get', 'name'],  // Use 'piste:name' property from GeoJSON
        textSize: fontSize,
        symbolPlacement: 'line',  // Place labels along the line
        textAnchor: 'center',  // Anchor the text in the center
        textAllowOverlap: false,  // Prevent overlapping text
        textOffset: [0, nameOffset],  // Adjust text position slightly
        textColor: expert_piste_color.toHexStringRGB(),  // Set text color
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

    // Add piste name labels along the piste lines
    mapController?.addSymbolLayer(
      'aerialway-source',
      'aerialway-name-layer',
      SymbolLayerProperties(
        textField: ['get', 'name'],  // Use 'piste:name' property from GeoJSON
        textSize: fontSize,
        symbolPlacement: 'line',  // Place labels along the line
        textAnchor: 'center',  // Anchor the text in the center
        textAllowOverlap: false,  // Prevent overlapping text
        textOffset: [0, nameOffset],  // Adjust text position slightly
        textColor: lift_color.toHexStringRGB(),  // Set text color
      ),
      minzoom: 14.0,
    );

    print('Layers for aerialway and piste added successfully');
  }

  ///////////////////////////////////////////////////////////////////
  
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
      size: iconSize,
      imageName: 'lift-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: novice_piste_color,
      size: iconSize,
      imageName: 'novice-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: easy_piste_color,
      size: iconSize,
      imageName: 'easy-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: intermediate_piste_color,
      size: iconSize,
      imageName: 'intermediate-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: advanced_piste_color,
      size: iconSize,
      imageName: 'advanced-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: expert_piste_color,
      size: iconSize,
      imageName: 'expert-piste-arrow',
    );
    _loadGeoJsonFromAssets('assets/les_2_alps.geojson');
  }

  // Callback when the Mapbox map is created
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
  }

  void _onCameraIdle() async {
    // Get the current zoom level and print it
    print('Current zoom level: ${mapController?.cameraPosition?.zoom}');
  }

  void _toggle2D3DView() {
    if (mapController != null) {
      setState(() {
        is3DMode = !is3DMode;
      });

      // Get the current camera position
      final currentCameraPosition = mapController!.cameraPosition;

      // Update only the tilt, keeping other values unchanged
      mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentCameraPosition!.target,
          zoom: currentCameraPosition.zoom,
          bearing: currentCameraPosition.bearing,
          tilt: is3DMode ? 60.0 : 0.0,  // Change tilt only
        ),
      ));
    }
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
            compassEnabled: true, // Disable the compass button
            compassViewPosition: CompassViewPosition.BottomRight,
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
          Positioned(
            bottom: 40, // Position at the bottom
            left: 20, // Align to the left
            child: FloatingActionButton(
              backgroundColor: Colors.white.withOpacity(floatingbuttonopacity),
              onPressed: _toggle2D3DView,
              child: Text(
                is3DMode ? '2D' : '3D',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
