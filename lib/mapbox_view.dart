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
  // Filter set for pistes and lifts
  List<String> pisteDifficultyFilters = [
    'novice',
    'easy',
    'intermediate', 
    'advanced', 
    'expert', 
    'freeride',
  ];

  // Colors for the map
  Color connection_piste_color = Color.fromARGB(255, 52, 124, 40);
  Color novice_piste_color = Color.fromARGB(255, 52, 124, 40);
  Color easy_piste_color = Color.fromARGB(255, 63, 162, 246);
  Color intermediate_piste_color = Color.fromARGB(255, 199, 37, 62);
  Color advanced_piste_color = Color.fromARGB(200, 27, 27, 27);
  Color expert_piste_color = Color.fromARGB(255, 255, 136, 91);
  Color lift_color =  Color.fromRGBO(216, 59, 59, 1); // RGB values from hsl(0, 82%, 42%) and opacity set to 1 (fully opaque)
  Color lift_stroke_color =  Color.fromRGBO(255, 255, 255, 1); // RGB values from hsl(0, 82%, 42%) and opacity set to 1 (fully opaque)
  Color piste_default_color = Color.fromARGB(255, 255, 255, 255);
  double strokeOpacity = 0.5;
  double liftStrokeOpacity = 0.8;
  // Min zoom level
  double minZoomPiste = 14.0;
  double minZoomLift = 12.0;
  // Icon size
  double iconSize = 40;
  double arrowIconSize = 30;
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

  var layerIds = <String>[];

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
          final geometry = feature['geometry']['type'];
          print("uses: $uses");
          return geometry == 'LineString' &&
          (uses.contains('downhill') || uses.contains('connection'));
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
        layerIds.add(lineLayerString);
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
          layerIds.add(strokeLayerString);
        }

        // line
        mapController?.addLineLayer(
          lineSourceString,
          lineLayerString,
          LineLayerProperties(
            lineColor: piste_default_color.toHexStringRGB(), // Use piste_default_color
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
        minzoom: minZoomPiste,
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
          minzoom: minZoomLift,
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
          minzoom: minZoomPiste,
        );
      }

    }

    print('Layers for $type added successfully');
  }

  Future<void> _addLayersFromGeoJsonAssets(String filepath) async {
    await _loadGeoJsonFromAssets(filepath);
    _addSourceAndLayer(geojsonData);
  }
  ///////////////////////////////////////////////////////////////////
  
  void onFeatureTap(dynamic featureId, Point<double> point, LatLng latLng) async {
    List features = await mapController!.queryRenderedFeatures(point, layerIds, null);
    
    if (features.isNotEmpty) {
      dynamic type = features[0]["properties"]["aerialway"];
      type ??= features[0]["properties"]["piste:type"];
      type ??= features[0]["properties"]["uses"];
      type ??= features[0]["properties"]["liftType"];
      type ??= "N/A";
      dynamic name = features[0]["properties"]["name"] ?? "No name";
      dynamic difficulty = features[0]["properties"]["piste:difficulty"];
      difficulty ??= features[0]["properties"]["difficulty"];
      difficulty ??= "N/A";
      dynamic color = features[0]["properties"]["color"] ?? "#FF0000"; // Default color if not specified

      print(features[0]["properties"]["name"]);

      // Get the geometry and calculate bounds
      var geometry = features[0]["geometry"];
      if (geometry["type"] == "LineString") {
        final coordinates = geometry["coordinates"];
        
        // Initialize bounds with the first coordinate
        LatLng southwest = LatLng(coordinates[0][1], coordinates[0][0]);
        LatLng northeast = LatLng(coordinates[0][1], coordinates[0][0]);
        
        for (var coord in coordinates) {
          LatLng point = LatLng(coord[1], coord[0]);
          southwest = LatLng(
            southwest.latitude < point.latitude ? southwest.latitude : point.latitude,
            southwest.longitude < point.longitude ? southwest.longitude : point.longitude,
          );
          northeast = LatLng(
            northeast.latitude > point.latitude ? northeast.latitude : point.latitude,
            northeast.longitude > point.longitude ? northeast.longitude : point.longitude,
          );
        }

        // Create the LatLngBounds object
        LatLngBounds bounds = LatLngBounds(southwest: southwest, northeast: northeast);

        // Change camera to focus on the LineString bounds
        await mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, top: 50.0, bottom: 3 * 50.0, left: 50.0, right: 50.0), // 50 is padding
        );
      }

      // Remove existing highlighted source and layer if they exist
      try {
        await mapController!.removeLayer('highlighted-layer');
        await mapController!.removeSource('highlighted-feature');
      } catch (e) {
        // Handle the case where the layer or source does not exist
        print("Layer or source not found: $e");
      }

      // Highlight the selected feature
      mapController!.addSource(
        'highlighted-feature',
        GeojsonSourceProperties(
          data: {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "geometry": geometry,
                "properties": {
                  "color": color,
                },
              },
            ],
          },
        ),
      );

      // get feature type
      dynamic featureType = features[0]["properties"]["type"];

      if (featureType == "run") {
        mapController!.addLineLayer(
          'highlighted-feature',
          'highlighted-layer',
          LineLayerProperties(
            lineColor: color,
            lineWidth: pisteLineWidth * 10,
            lineOpacity: strokeOpacity,
            lineCap: 'round',
          ),
        );
      } else if (featureType == "lift") {
        mapController!.addLineLayer(
          'highlighted-feature',
          'highlighted-layer',
          LineLayerProperties(
            lineColor: lift_color.toHexStringRGB(),
            lineWidth: liftLineWidth * 5,
            lineOpacity: strokeOpacity,
            lineCap: 'round',
          ),
        );
      }

      // Show bottom sheet
      showBottomSheet(
        context: context,
        backgroundColor: Colors.white.withOpacity(floatingbuttonopacity),
        enableDrag: false,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '$type: $name',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () async {
                            // Remove highlighted layer and source when closing
                            await mapController!.removeLayer('highlighted-layer');
                            await mapController!.removeSource('highlighted-feature');
                            Navigator.pop(context); // Close the BottomSheet
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'Difficulty: $difficulty',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 40.0),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }
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
      size: arrowIconSize,
      imageName: 'novice-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: easy_piste_color,
      size: arrowIconSize,
      imageName: 'easy-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: intermediate_piste_color,
      size: arrowIconSize,
      imageName: 'intermediate-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: advanced_piste_color,
      size: arrowIconSize,
      imageName: 'advanced-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: Icons.arrow_right,
      color: expert_piste_color,
      size: arrowIconSize,
      imageName: 'expert-piste-arrow',
    );

    // Add layers from GeoJSON assets
    await _addLayersFromGeoJsonAssets('assets/3valley/runs.geojson');
    _addLayersFromGeoJsonAssets('assets/3valley/lifts.geojson');
    mapController?.setFilter("run-layer", 
    ['==', 
    ['get', 'difficulty'], 
    'novice'
    ]);
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
              target: LatLng(45.318460699999996, 6.578992100000002), // Coordinates for 3 valleys
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
