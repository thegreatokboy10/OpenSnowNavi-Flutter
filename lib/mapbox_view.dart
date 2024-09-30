import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'timer_flag.dart';
import 'global_constants.dart';

class GeneratorPage extends StatefulWidget {
  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  // Resort
  String selectedResortKey = '3valley'; // Default selection for 3 Valleys
  // Filter set for pistes and lifts
  List<String> pisteSources = [];
  List<String> pisteLayers = [];
  List<String> liftSources = [];
  List<String> liftLayers = [];
  List<String> pisteDifficultyFilters = [
    'novice',
    'easy',
    'intermediate', 
    'advanced', 
    'expert', 
    'freeride',
  ];

  Map<String, bool> difficultyFilterMap = {
    'novice': true,
    'easy': true,
    'intermediate': true,
    'advanced': true,
    'expert': true,
    'freeride': true
  };

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
  double floatingActionButtonScale = 0.8;

  // Variable to track whether the map is in 3D mode or not
  bool is3DMode = false;

  // isUiOpen is a flag to track if the UI panels are open or not
  TimerFlag isUiOpen = TimerFlag(); // Initialize flag

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
        liftLayers.add(lineLayerString);
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
          pisteLayers.add(strokeLayerString);
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
        pisteLayers.add(lineLayerString);
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
        liftSources.add('$type-source');
      } else {
        // piste: line and stroke
        pisteSources.add('$type-source');
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
      if (type == 'lift') {
        liftLayers.add('$type-name-layer');
      } else {
        pisteLayers.add('$type-name-layer');
      }

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
        liftLayers.add('$type-arrow-layer');
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
        pisteLayers.add('$type-arrow-layer');
      }

    }

    print('Layers for $type added successfully');
  }

  void _clearLayers(List<String> layerIds) async {
    if (mapController != null) {
      for (String layerId in layerIds) {
        try {
          await mapController!.removeLayer(layerId);
        } catch (e) {
          // Handle the case where the layer or source does not exist
          print("Layer $layerId not found: $e");
        }
      }
    }
  }

  void _clearSources(List<String> sourceIds) async {
    if (mapController != null) {
      for (String sourceId in sourceIds) {
        try {
          await mapController!.removeSource(sourceId);
        } catch (e) {
          // Handle the case where the layer or source does not exist
          print("Source $sourceId not found: $e");
        }
      }
    }
  }

  Future<void> _loadSkiResortData() async {
    _clearLayers(pisteLayers);
    _clearSources(pisteSources);
    _clearLayers(liftLayers);
    _clearSources(liftSources);

    final pisteFilePath = 'assets/$selectedResortKey/runs.geojson';
    final liftFilePath = 'assets/$selectedResortKey/lifts.geojson';

    await _addLayersFromGeoJsonAssets(pisteFilePath);
    _addLayersFromGeoJsonAssets(liftFilePath);
    _applyFilters();
  }

  Future<void> _addLayersFromGeoJsonAssets(String filepath) async {
    await _loadGeoJsonFromAssets(filepath);
    _addSourceAndLayer(geojsonData);
  }
  ///////////////////////////////////////////////////////////////////

  void onFeatureTap(dynamic featureId, Point<double> point, LatLng latLng) async {
    if (isUiOpen.flag) {
      print("set isUiOpen to false");
      isUiOpen.flag = false;
      return;
    }
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
          return GestureDetector(
            behavior: HitTestBehavior.opaque, // 捕获所有事件
            onTapDown: (details) {
              // 可以处理点击事件，或者留空来阻止事件传递到 map
              isUiOpen.flag = true;
              print("BottomSheet onTapDown, set isUiOpen to true");
            },
            child: Column(
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
                          GestureDetector(
                            child: IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () async {
                                // Remove highlighted layer and source when closing
                                isUiOpen.flag = true;
                                await mapController!.removeLayer('highlighted-layer');
                                await mapController!.removeSource('highlighted-feature');
                                Navigator.pop(context); // Close the BottomSheet
                              },
                            ),
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
            ),
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
    _loadSkiResortData();
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
    isUiOpen.flag = true;
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

  void _showFilterDialog() {
    isUiOpen.flag = true;
    // 创建 difficultyFilterMap 的副本
    final Map<String, bool> filterMapCopy = Map.from(difficultyFilterMap);

    // 创建筛选对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return GestureDetector(
              onTapDown: (details) {
                isUiOpen.flag = true;
                print("FilterDialog onTapDown, set isUiOpen to true");
              },
              child: AlertDialog(
                title: Text('Filter Pistes'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: filterMapCopy.keys.map((difficulty) {
                      return CheckboxListTile(
                        title: Text(difficulty),
                        value: filterMapCopy[difficulty] ?? false,
                        onChanged: (bool? newValue) {
                          isUiOpen.flag = true;
                          print("FilterDialog inside checkbox onTapDown, set isUiOpen to true");
                          setState(() {
                            // 更新副本中的值
                            filterMapCopy[difficulty] = newValue ?? false;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      // 用户点击取消，不进行任何更改，直接关闭对话框
                      isUiOpen.flag = true;
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('OK'),
                    onPressed: () {
                      // 用户点击确定，将副本的值更新到原始 difficultyFilterMap
                      isUiOpen.flag = true;
                      difficultyFilterMap = Map.from(filterMapCopy);
                      // 应用筛选逻辑
                      _applyFilters();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    // 构建 difficultyList，收集被选中的难度值
    List<String> difficultyList = difficultyFilterMap.entries
      .where((entry) => entry.value) // 过滤出被选中的 difficulty
      .map((entry) => "${entry.key}") // 将 difficulty 的名称转换为带引号的字符串
      .toList();

    pisteLayers.forEach((layerId) {
      print("setting filter for $layerId with $difficultyList");
      if (difficultyList.isNotEmpty) {
        // 如果 difficultyList 不为空，设置过滤器
        mapController?.setFilter(
          layerId,
          [
            'in', // 使用 'in' 过滤条件，匹配多个难度值
            ['get', 'difficulty'],
            ['literal', difficultyList], 
          ],
        );
      } else {
        // 如果 difficultyList 为空，清除过滤器
        mapController?.setFilter(layerId, null);
      }
    });
  }

  // Function to convert country to emoji flag
  String _getFlagEmoji(String country) {
    // Map from country name to ISO country code (for a limited set of countries)
    Map<String, String> countryCodeMap = {
      'France': 'FR',
      // Add other countries and their codes here as needed
    };

    // Get the country code
    String? countryCode = countryCodeMap[country];
    if (countryCode == null) return '';

    // Convert to emoji flag
    return countryCode.toUpperCase().codeUnits.map((unit) {
      return String.fromCharCode(unit + 0x1F1E6 - 65);
    }).join();
  }

  void _moveToSelectedResort() {
    final selectedResort = GlobalConstants.skiResortList[selectedResortKey];
    _loadSkiResortData();
    final lat = selectedResort?['coordinate']['lat'];
    final lng = selectedResort?['coordinate']['lng'];
    final zoom = selectedResort?['zoom'] ?? 13.0; // Default zoom if not provided
    if (lat != null && lng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom),
        ),
      );
    }
  }

  // Get initial camera position based on the default selected resort
  CameraPosition _getInitialCameraPosition() {
    final selectedResort = GlobalConstants.skiResortList[selectedResortKey];
    final lat = selectedResort?['coordinate']['lat'] ?? 0.0;
    final lng = selectedResort?['coordinate']['lng'] ?? 0.0;
    final zoom = selectedResort?['zoom'] ?? 13.0;
    
    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom,
    );
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
            initialCameraPosition: _getInitialCameraPosition(),
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
          // 筛选按钮
          Positioned(
            bottom: 38,
            left: 20, 
            child: Transform.scale(
              scale: floatingActionButtonScale, // 缩放比例
              child: FloatingActionButton(
                backgroundColor: Colors.white.withOpacity(floatingbuttonopacity), // 按钮颜色
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
                child: Icon(Icons.filter_alt), // 使用筛选图标
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 20, 
            child: Transform.scale(
              scale: floatingActionButtonScale,
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
          ),
          // Dropdown for selecting ski resort
          Positioned(
            bottom: 40, // Position at the bottom
            left: 80, // Align to the left
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<String>(
                value: selectedResortKey,
                items: GlobalConstants.skiResortList.keys.map((String key) {
                  final resort = GlobalConstants.skiResortList[key];
                  final country = resort?['country'] ?? '';
                  final flagEmoji = _getFlagEmoji(country);
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(
                      '$flagEmoji ${resort?['name']['en'] ?? 'Unknown Resort'}',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onTap: () {
                  isUiOpen.flag = true;
                },
                onChanged: (newValue) {
                  isUiOpen.flag = true;
                  if (newValue != null && newValue != selectedResortKey) {
                    setState(() {
                      selectedResortKey = newValue;
                      _moveToSelectedResort(); // Move map to the selected resort with zoom
                    });
                  }
                },
                underline: Container(), // Remove default underline
                icon: Icon(Icons.arrow_drop_down),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
