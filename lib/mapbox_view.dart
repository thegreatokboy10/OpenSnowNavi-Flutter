import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

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
  Color lift_color =  Color.fromRGBO(216, 59, 59, 1); // RGB values from hsl(0, 82%, 42%) and opacity set to 1 (fully opaque)
  Color lift_stroke_color =  Color.fromRGBO(216, 59, 59, 1); // RGB values from hsl(0, 82%, 42%) and opacity set to 1 (fully opaque)
  Color piste_default_color = Color.fromARGB(255, 255, 255, 255);
  double strokeOpacity = 0.5;
  double liftStrokeOpacity = 0.8;

  // Icon size
  double iconSize = 40;
  // Piste/Lift name
  double fontSize = 13;
  double nameOffset = 0.6;
  // Line size
  double pisteLineWidth = 2.0;
  double liftLineWidth = 3.0;
  // Floating button
  double floatingbuttonopacity = 0.9;

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

  ///////////////////////////////////////////////////////////////////////////////
  /// Function to add GeoJSON data as a source and layer using Pipeline Exports
  ///////////////////////////////////////////////////////////////////////////////
  Future<void> _loadGeoJsonFromAssets(String filepath) async {
    String data = await rootBundle.loadString(filepath);
    // print load from filepath
    print('load from $filepath');
    setState(() {
      geojsonData = data;
    });
  }

  void _addSourceAndLayer(String? geojsonData) {
    if (geojsonData == null) {
      print("GeoJSON data is null in _addLiftSourceAndLayer");
      return;
    }

    final parsedGeoJson = json.decode(geojsonData);

    String type = '';

    // Separate features
    final features = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        type = feature['properties']['type'];
        if (type == 'lift') {
          return feature['properties'].containsKey('type') && type == 'lift';
        } else {
          // piste "run"
          final uses = feature['properties']['uses'];
          print("uses: $uses");
          return feature['properties'].containsKey('type') && 
          type == 'run' &&
          (uses == 'downhill' || uses == 'connection');
        }
      }).toList(),
    };

    // line layer helper function
    void _addLineWithStroke(String lineSourceString, String lineLayerString, double lineWidth, String? strokeSourceString, String? strokeLayerString, double? strokeWidth, double? strokeOpacity) {
      if (type == 'lift') {
        // lift: no stroke, line color is ['get', 'color']
        // line
        mapController?.addLineLayer(
          lineSourceString,
          lineLayerString,
          LineLayerProperties(
            lineColor: ['get', 'color'], // Use 'color' property from GeoJSON
            lineWidth: lineWidth, 
          ),
        );
      } else {
        // piste: stroke color is ['get', 'color'], line color is piste_default_color
        // stroke
        if (strokeSourceString != null && strokeLayerString != null && strokeWidth != null && strokeOpacity != null) {
          mapController?.addLineLayer(
            strokeSourceString,
            strokeLayerString,
            LineLayerProperties(
              lineColor: ['get', 'color'], // Use 'color' property from GeoJSON
              lineOpacity: strokeOpacity,
              lineWidth: strokeWidth,
            ),
          );
        }

        // line
        mapController?.addLineLayer(
          lineSourceString,
          lineLayerString,
          LineLayerProperties(
            lineColor: piste_default_color, // Use piste_default_color
            lineWidth: lineWidth, 
          ),
        );
      }
    }

    if (type != '') {
      // Add Layer Data Source
      mapController?.addSource(
        '$type-source',
        GeojsonSourceProperties(data: features),
      );

      // Decide line properties based on type
      var _lineWidth = 0.0;
      var _strokeSourceString = null;
      var _strokeLayerString = null;
      var _strokeWidth = null;
      var _strokeOpacity = null;

      if (type == 'lift') {
        // only line, no stroke
        _lineWidth = liftLineWidth;
      } else {
        // piste: line and stroke
        _lineWidth = pisteLineWidth;
        _strokeSourceString = '$type-source';
        _strokeLayerString = '$type-stroke-layer';
        _strokeWidth = pisteLineWidth * 3;
        _strokeOpacity = strokeOpacity;
      }
      // Add Line Layer
      _addLineWithStroke('$type-source', '$type-layer', _lineWidth, _strokeSourceString, _strokeLayerString, _strokeWidth, _strokeOpacity);

      // Add Name Layer
      mapController?.addSymbolLayer(
        '$type-source',
        '$type-name-layer',
        SymbolLayerProperties(
          textField: ['get', 'name'],  // Use 'name' property from GeoJSON
          textSize: fontSize,
          symbolPlacement: 'line',  // Place labels along the line
          textAnchor: 'center',  // Anchor the text in the center
          textAllowOverlap: false,  // Prevent overlapping text
          textOffset: [0, nameOffset],  // Adjust text position slightly
          textColor: ['get', 'color'] // Use 'color' property from GeoJSON
        ),
        minzoom: 14.0,
      );

      // Add Arrow Layer
      if (type == 'lift') {
        mapController?.addSymbolLayer(
          '$type-source',
          '$type-arrow-layer',
          SymbolLayerProperties(
            iconImage: 'lift-arrow',
            symbolPlacement: 'line-center', // Place along the line
            symbolSpacing: 5000000, // Ensures only one arrow is placed on the line
            iconAllowOverlap: false,
            iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
            iconRotationAlignment: 'map',
          ),
          minzoom: 12,
        );
      } else {
        mapController?.addSymbolLayer(
          '$type-source',
          '$type-arrow-layer',
          SymbolLayerProperties(
            iconImage:[
              'concat', ['get', 'difficulty'], '-piste-arrow'
            ],
            symbolPlacement: 'line-center', // Place along the line
            symbolSpacing: 5000000, // Ensures only one arrow is placed on the line
            iconAllowOverlap: false,
            iconRotate: ['get', 'bearing'], // Rotate arrow based on line bearing
            iconRotationAlignment: 'map',
          ),
          minzoom: 12,
        );
      }

    }

    print('Layers for $type added successfully');
  }

  Future<void> _addLayersFromGeoJsonAssets(String filepath) async {
    await _loadGeoJsonFromAssets(filepath);
    _addSourceAndLayer(geojsonData);
  }
  ///////////////////////////////////////////////////////////////////////////////
  /// outdated: Function to add GeoJSON data as a source and layer
  ///////////////////////////////////////////////////////////////////////////////

  // Function to load GeoJSON from assets
  Future<void> _loadGeoJsonFromAssets_outdated(String filepath) async {
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

    void _addLineWithStroke(String lineSourceString, String lineLayerString, Color lineColor, double lineWidth, String? strokeSourceString, String? strokeLayerString, Color? strokeColor, double? strokeWidth, double? strokeOpacity) {
      // stroke
      if (strokeSourceString != null && strokeLayerString != null && strokeColor != null && strokeWidth != null && strokeOpacity != null) {
        mapController?.addLineLayer(
          strokeSourceString,
          strokeLayerString,
          LineLayerProperties(
            lineColor: strokeColor.toHexStringRGB(), 
            lineOpacity: strokeOpacity,
            lineWidth: strokeWidth,
          ),
        );
      }

      // line
      mapController?.addLineLayer(
        lineSourceString,
        lineLayerString,
        LineLayerProperties(
          lineColor: lineColor.toHexStringRGB(), 
          lineWidth: lineWidth, 
        ),
      );
    }

    ////////////////////////////////////////////////////////////////
    // Add connection piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the connection piste source
    mapController?.addSource(
      'connection-piste-source',
      GeojsonSourceProperties(data: connectionPisteFeatures),
    );

    // Add green polyline for connection pistes
    _addLineWithStroke('connection-piste-source', 'connection-piste-layer', connection_piste_color, pisteLineWidth, null, null, null, null, null);

    ////////////////////////////////////////////////////////////////
    // Add novice piste features
    ////////////////////////////////////////////////////////////////
    
    // Add the novice piste source
    mapController?.addSource(
      'novice-piste-source',
      GeojsonSourceProperties(data: novicePisteFeatures),
    );

    // Add green polyline for novice pistes
    _addLineWithStroke('novice-piste-source', 'novice-piste-layer', piste_default_color, pisteLineWidth, 'novice-piste-source', 'novice-piste-stroke-layer', novice_piste_color, pisteLineWidth * 3, strokeOpacity);

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
    _addLineWithStroke('easy-piste-source', 'easy-piste-layer', piste_default_color, pisteLineWidth, 'easy-piste-source', 'easy-piste-stroke-layer', easy_piste_color, pisteLineWidth * 3, strokeOpacity);

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
    _addLineWithStroke('intermediate-piste-source', 'intermediate-piste-layer', piste_default_color, pisteLineWidth, 'intermediate-piste-source', 'intermediate-piste-stroke-layer', intermediate_piste_color, pisteLineWidth * 3, strokeOpacity);

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
    _addLineWithStroke('advanced-piste-source', 'advanced-piste-layer', piste_default_color, pisteLineWidth, 'advanced-piste-source', 'advanced-piste-stroke-layer', advanced_piste_color, pisteLineWidth * 3, strokeOpacity);

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
    _addLineWithStroke('expert-piste-source', 'expert-piste-layer', piste_default_color, pisteLineWidth, 'expert-piste-source', 'expert-piste-stroke-layer', expert_piste_color, pisteLineWidth * 3, strokeOpacity);

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

    _addLineWithStroke('aerialway-source', 'aerialway-layer', lift_color, liftLineWidth, null, null, null, null, null);

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
  
  void onFeatureTap(dynamic featureId, Point<double> point, LatLng latLng) async {
  List features = await mapController!.queryRenderedFeatures(point, [], null);
  
  if (features.isNotEmpty) {
    dynamic type = features[0]["properties"]["aerialway"] ?? features[0]["properties"]["piste:type"] + " piste" ;
    dynamic name = features[0]["properties"]["name"] ?? "No name";
    dynamic difficulty = features[0]["properties"]["piste:difficulty"] ?? "N/A";
    print(features[0]["properties"]["name"]);

    // Show bottom sheet instead of SnackBar
    showBottomSheet(
      context: context,
      backgroundColor: Colors.white.withOpacity(floatingbuttonopacity),
      enableDrag: true,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              width: double.infinity, // Ensure full width
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$type: $name',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Difficulty: $difficulty',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20.0),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
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
    _loadGeoJsonFromAssets_outdated('assets/les_2_alps.geojson');
    _addLayersFromGeoJsonAssets('assets/3valley/runs.geojson');
    _addLayersFromGeoJsonAssets('assets/3valley/lifts.geojson');
  }

  // Callback when the Mapbox map is created
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    mapController?.onFeatureTapped.add(onFeatureTap);
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
