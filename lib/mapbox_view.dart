import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'geojson_helper.dart';
import 'lift.dart';
import 'piste.dart';
import 'route_engine.dart' as re;
import 'timer_flag.dart';
import 'global_constants.dart';
import 'global_data.dart';
import 'search_service.dart';
import 'location_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/route_instruction_panel.dart'; // Add this for opening URLs

class GeneratorPage extends StatefulWidget {
  final List<List<double>>? coordinates; // List of lat-lng pairs
  final String? resortKey; // Resort key for the map

  const GeneratorPage({Key? key, this.coordinates, this.resortKey}) : super(key: key);

  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  bool _zoomGesturesEnabled = true;
  List<GlobalKey> _childWidgetKeys = []; // Store GlobalKeys of child widgets

  // Create an instance of RouteEngine
  final routeEngine = re.RouteEngine();
  re.Route? route;
  List<LatLng>? stopovers; // TODO: think about how to properly support stopovers
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

  // Variable to track whether the map is in 3D mode or not
  bool is3DMode = false;

  // isUiOpen is a flag to track if the UI panels are open or not
  TimerFlag isUiOpen = TimerFlag(); // Initialize flag

  var layerIds = <String>[];

  // Layer ID for the route polyline
  LatLng? startCoordinate;
  LatLng? endCoordinate;

  // Coordinate for ski resort center
  LatLng? resortCoordinate;
  final LocationService _locationService = LocationService();

  // POI search
  List<Map<String, dynamic>> poiResults = [];
  late TextEditingController _searchController;
  bool hasSearched = false; // Tracks if a search has been performed
  Timer? _debounce;

  List<String> routeLayers = [];
  List<String> routeSources = [];

  MapboxMapController? mapController;

  // flag to track if route needs to be restored from url
  bool needRestore = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    needRestore = _restoreParameters();
    _childWidgetKeys = List.generate(3, (index) => GlobalKey()); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Parses coordinates and restores class variables
  bool _restoreParameters() {
    bool hasResortKey = widget.resortKey != null && widget.resortKey!.isNotEmpty;
    bool hasCoordinates = widget.coordinates != null && widget.coordinates!.isNotEmpty;

    if (!hasResortKey || !hasCoordinates) {
      print("no route needs to restored");
      return false; // One or both parameters are missing
    }

    // Assign resortKey only if it's non-empty and non-null
    selectedResortKey = widget.resortKey!;

    // Assign coordinates only if they exist
    startCoordinate = LatLng(widget.coordinates!.first[1], widget.coordinates!.first[0]);
    endCoordinate = LatLng(widget.coordinates!.last[1], widget.coordinates!.last[0]);

    if (widget.coordinates!.length > 2) {
      stopovers = widget.coordinates!
          .sublist(1, widget.coordinates!.length - 1)
          .map((coord) => LatLng(coord[0], coord[1]))
          .toList();
    } else {
      stopovers = [];
    }

    print("route needs to be restored with $selectedResortKey and $startCoordinate to $endCoordinate via $stopovers");
    return true; // Both parameters are present
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel(); // Cancel any active timer

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.length >= 3) {
        hasSearched = true; // Set to true when a search is triggered
        LatLng center = resortCoordinate!;
        double radiusKm = 15.0;
        List<Map<String, dynamic>> results = await SearchService.searchPOI(query, center, radiusKm);
        setState(() {
          poiResults = results;
        });
      } else {
        setState(() {
          hasSearched = false; // Reset if query is cleared
          poiResults = [];
        });
      }
    });
  }

  void _onSearchSubmitted(String query) async {
    if (query.isNotEmpty) {
      hasSearched = true;
      LatLng center = resortCoordinate!;
      double radiusKm = 15.0;

      // Fetch POIs using the NominatimSearchService
      List<Map<String, dynamic>> results =
          await SearchService.searchPOI(query, center, radiusKm);
      setState(() {
        poiResults = results;
      });
    } else {
      setState(() {
        hasSearched = false;
        poiResults = [];
      });
    }
  }

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
      print("GeoJSON data is null in _addSourceAndLayer");
      return;
    }

    final parsedGeoJson = json.decode(geojsonData);

    // Iterate over features and create Lift or Piste objects
    for (var feature in parsedGeoJson['features']) {
      final type = feature['properties']['type'];

      if (type == 'lift') {
        try {
          // Create a Lift object and add it to GlobalData
          var lift = Lift.fromGeoJson(feature);
          lift.lineWidth = GlobalConstants.liftLineWidth;
          lift.highlightOpacity = GlobalConstants.strokeOpacity;
          GlobalData.lifts.add(lift);
        } catch (e) {
          print("Error parsing lift feature: $e");
        }
      } else if (type == 'run') {
        try {
          // Create a Piste object and add it to GlobalData
          var piste = Piste.fromGeoJson(feature);
          piste.lineWidth = GlobalConstants.pisteLineWidth;
          piste.secondColor = GlobalConstants.piste_default_color;
          piste.highlightOpacity = GlobalConstants.strokeOpacity;
          GlobalData.pistes.add(piste);
        } catch (e) {
          print("Error parsing piste feature: $e");
        }
      } else {
        print("Unsupported feature type: $type");
      }
    }

    _refreshPisteAndLiftLayers();
  }

  void _refreshPisteAndLiftLayers({double opacity = 0.8}) {
    _clearLayers(layerIds);
    _clearLayers(pisteLayers);
    _clearLayers(liftLayers);
    // Add layers for pistes
    GeoJsonHelper.addAggregateSourceAndLayer(
      mapController: mapController!,
      items: GlobalData.pistes, // Pass the list of Piste objects
      sourceId: GlobalConstants.pisteSourceId,
      layerId: GlobalConstants.pisteLayerId,
      lineWidth: GlobalConstants.pisteLineWidth,
      lineOpacity: opacity,
      sourceList: pisteSources,
      layerList: pisteLayers,
    );
    layerIds.add(GlobalConstants.pisteLayerId);
    GeoJsonHelper.addNameLayer(
      mapController: mapController!,
      sourceId: GlobalConstants.pisteSourceId,
      layerId: 'run-name-layer',
      textSize: 10.0, // Adjust font size for lift names
      minZoom: GlobalConstants.minZoomPiste, // Use the predefined minimum zoom for pistes
      textOffset: 0.5, // Slight vertical adjustment for text
      textOpacity: opacity,
    );
    pisteLayers.add('run-name-layer');
    GeoJsonHelper.addArrowLayer(
      mapController: mapController!,
      sourceId: GlobalConstants.pisteSourceId,
      layerId: 'run-arrow-layer',
      iconImage: 'default-piste-arrow', // Fallback icon if no dynamic expression is provided
      iconOpacity: opacity,
      minZoom: GlobalConstants.minZoomPiste,
      iconImageExpression: [
        'concat',
        ['get', 'difficulty'],
        '-piste-arrow',
      ], // Dynamic icon expression for pistes
    );
    pisteLayers.add('run-arrow-layer');

    // Add layers for lifts
    GeoJsonHelper.addAggregateSourceAndLayer(
      mapController: mapController!,
      items: GlobalData.lifts, // Pass the list of Lift objects
      sourceId: GlobalConstants.liftSourceId,
      layerId: GlobalConstants.liftLayerId,
      lineWidth: GlobalConstants.liftLineWidth,
      lineOpacity: opacity,
      sourceList: liftSources,
      layerList: liftLayers,
    );
    layerIds.add(GlobalConstants.liftLayerId);
    GeoJsonHelper.addNameLayer(
      mapController: mapController!,
      sourceId: GlobalConstants.liftSourceId,
      layerId: 'lift-name-layer',
      textSize: 12.0, // Adjust font size for lift names
      minZoom: GlobalConstants.minZoomLift, // Use the predefined minimum zoom for lifts
      textOffset: 0.5, // Slight vertical adjustment for text
      textOpacity: opacity,
    );
    liftLayers.add('lift-name-layer');
    GeoJsonHelper.addArrowLayer(
      mapController: mapController!,
      sourceId: GlobalConstants.liftSourceId,
      layerId: 'lift-arrow-layer',
      iconImage: 'lift-arrow',
      iconOpacity: opacity,
      minZoom: GlobalConstants.minZoomLift,
    );
    liftLayers.add('lift-arrow-layer');

    print('Layers for lifts and pistes added successfully');
  }

  void _resetLayersAndSources() {
    pisteLayers.clear();
    liftLayers.clear();
    layerIds.clear();
    pisteSources.clear();
    liftSources.clear();
    routeLayers.clear();
    routeSources.clear();
  }

  void _clearLayers(List<String> layerIds) {
    if (mapController != null) {
      for (String layerId in layerIds) {
        try {
          mapController!.removeLayer(layerId);
        } catch (e) {
          // Handle the case where the layer or source does not exist
          print("Layer $layerId not found: $e");
        }
      }
    }
  }

  void _clearSources(List<String> sourceIds) {
    if (mapController != null) {
      for (String sourceId in sourceIds) {
        try {
          mapController!.removeSource(sourceId);
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
    _clearLayers(routeLayers);
    _clearSources(routeSources);
    _resetLayersAndSources();
    GlobalData.lifts.clear();
    GlobalData.pistes.clear();

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

    // Piste and Lift features
    List features = await mapController!.queryRenderedFeatures(point, layerIds, null);
    
    if (features.isNotEmpty) {
      dynamic type = features[0]["properties"]["type"];
      type ??= features[0]["properties"]["uses"];
      type ??= "N/A";
      dynamic name = features[0]["properties"]["name"] ?? "No name";
      dynamic ref = features[0]["properties"]["ref"];
      if (ref != null && ref.isNotEmpty) {
        name = "$ref $name";
      }
      dynamic difficulty = features[0]["properties"]["difficulty"];
      difficulty ??= "N/A";

      print("$ref $name of $type is clicked");

      // Get the geometry and calculate bounds
      var geometry = features[0]["geometry"];
      if (geometry["type"] == "LineString") {
        print("find geometry for $type");
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

        // First, get the current camera position to preserve bearing
        double currentBearing = mapController!.cameraPosition!.bearing;

        // Create the LatLngBounds object
        LatLngBounds bounds = LatLngBounds(southwest: southwest, northeast: northeast);

        // Change camera to focus on the LineString bounds
        await mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, top: 50.0, bottom: 3 * 50.0, left: 50.0, right: 50.0), // 50 is padding
        );

        await Future.delayed(Duration(milliseconds: 100));

        // Apply the stored bearing after zooming into bounds
        await mapController!.animateCamera(
          CameraUpdate.bearingTo(currentBearing),
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

      // highlight selected feature
      final id = features[0]["properties"]["id"];
      var featureFound = false;
      for (var piste in GlobalData.pistes) {
        if (piste.id == id) {
          piste.highlightMe(mapController!);
          featureFound = true;
          break;
        }
      }
      if (!featureFound) {
        for (var lift in GlobalData.lifts) {
          if (lift.id == id) {
            lift.highlightMe(mapController!);
            featureFound = true;
            break;
          }
        }
      }

      // Show bottom sheet
      showBottomSheet(
        context: context,
        backgroundColor: Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
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

    // POI features
  }

  void _onStyleLoadedCallback() async {
    _addFlutterIconToMap(
      icon: GlobalConstants.liftArrowIcon,
      color: GlobalConstants.lift_color,
      size: GlobalConstants.iconSize,
      imageName: 'lift-arrow',
    );
    _addFlutterIconToMap(
      icon: GlobalConstants.arrowIcon,
      color: GlobalConstants.novice_piste_color,
      size: GlobalConstants.arrowIconSize,
      imageName: 'novice-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: GlobalConstants.arrowIcon,
      color: GlobalConstants.easy_piste_color,
      size: GlobalConstants.arrowIconSize,
      imageName: 'easy-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: GlobalConstants.arrowIcon,
      color: GlobalConstants.intermediate_piste_color,
      size: GlobalConstants.arrowIconSize,
      imageName: 'intermediate-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: GlobalConstants.arrowIcon,
      color: GlobalConstants.advanced_piste_color,
      size: GlobalConstants.arrowIconSize,
      imageName: 'advanced-piste-arrow',
    );
    _addFlutterIconToMap(
      icon: GlobalConstants.arrowIcon,
      color: GlobalConstants.expert_piste_color,
      size: GlobalConstants.arrowIconSize,
      imageName: 'expert-piste-arrow',
    );
    Uint8List markerImage = await GeoJsonHelper.createCircleMarker();
    mapController!.addImage(GlobalConstants.routeHighlightImageName, markerImage);  

    // Add layers from GeoJSON assets
    await _loadSkiResortData();

    // Restore route
    if (needRestore) {
      print("restore route $startCoordinate, $endCoordinate");

      // 安全地处理起点和终点
      if (startCoordinate != null && endCoordinate != null) {
        // 设置起点和终点
        _setRouteCoordinates(startCoordinate!, endCoordinate!);
        
        // 生成路线
        _generateRoute(startCoordinate!, endCoordinate!);
        
        // 标记为已恢复
        needRestore = false;
      } else {
        print("Start or end coordinate is null, cannot restore route.");
      }
    }
  }

  void _setRouteCoordinates(LatLng start, LatLng end) {
    _clearAllCircles(); // 清除现有的圆
    _addCircleWithText(start, circleColor: "#00FF00", text: "A"); // 添加起点圆和文本
    _addCircleWithText(end, circleColor: "#0000FF", text: "B"); // 添加终点圆和文本
  }

  // Callback when the Mapbox map is created
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    mapController?.onFeatureTapped.add(onFeatureTap);
    _locationService.enableBackgroundMode(true);
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
      .map((entry) => entry.key) // 将 difficulty 的名称转换为带引号的字符串
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
      'China': 'CN',
      'Andorra': 'AD',
      'Switzerland': 'CH',  // 添加瑞士
      'Austria': 'AT',      // 添加奥地利
      'Germany': 'DE',      // 添加德国
      'Italy': 'IT'         // 添加意大利
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

  void _moveToSelectedResort() async {
    final selectedResort = GlobalConstants.skiResortList[selectedResortKey];
    final lat = selectedResort?['coordinate']['lat'];
    final lng = selectedResort?['coordinate']['lng'];
    resortCoordinate = LatLng(lat, lng);
    final zoom = selectedResort?['zoom'] ?? 13.0; // Default zoom if not provided
    if (lat != null && lng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom),
        ),
      );
      // Wait for the camera to move
      await Future.delayed(Duration(milliseconds: 100));
      print("Moving camera to $lat, $lng and load ski resort data");
      _loadSkiResortData();
    }
  }

  // Get initial camera position based on the default selected resort
  CameraPosition _getInitialCameraPosition() {
    final selectedResort = GlobalConstants.skiResortList[selectedResortKey];
    final lat = selectedResort?['coordinate']['lat'] ?? 0.0;
    final lng = selectedResort?['coordinate']['lng'] ?? 0.0;
    resortCoordinate = LatLng(lat, lng);
    final zoom = selectedResort?['zoom'] ?? 13.0;
    
    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom,
    );
  }

  Future<void> _removeExistingRoute() async {
    setState(() {
      route = null;
    });
    try {
      _clearLayers(routeLayers);
      _clearSources(routeSources);
      // restore piste and lift layers
      _refreshPisteAndLiftLayers();
    } catch (e) {
      print('No existing route layer to remove: $e');
    }
  }

  
  String _generateSkiPlannerUrl(String selectedResortKey, LatLng? startCoordinate, LatLng? endCoordinate, List<LatLng>? stopovers) {
    // Get the current full URL (including existing parameters)
    final String currentFullPath = html.window.location.href; // Example: http://localhost:60423/preview/?coords=...
    final Uri currentUri = Uri.parse(currentFullPath);

    // Remove existing query parameters and keep only domain + path
    final String baseUrl = "${currentUri.origin}${currentUri.path}";
    
    // Ensure start and end coordinates exist
    if (startCoordinate == null || endCoordinate == null) {
      return baseUrl;
    }

    // Collect all coordinates (start → stopovers → end)
    List<LatLng> allCoordinates = [startCoordinate, if (stopovers != null) ...stopovers, endCoordinate];

    // Convert coordinates to the required format (lng,lat;lng,lat)
    final String coordsString = allCoordinates
        .map((coord) => "${coord.longitude},${coord.latitude}") // Ensure correct order
        .join(';');

    // Build query parameters
    final Uri uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'coords': coordsString,
        if (selectedResortKey.isNotEmpty) 'resortKey': selectedResortKey, // Include only if not empty
      },
    );

    print("generated route url: ${uri.toString()}");
    return uri.toString();
  }

  void _generateRoute(LatLng startCoordinate, LatLng endCoordinate, {List<LatLng>? stopovers}) async {
    re.Route? newRoute = await routeEngine.generateRoute(
      startCoordinate: startCoordinate,
      endCoordinate: endCoordinate,
      stopovers: stopovers,
      selectedResortKey: selectedResortKey,
    );

    if (newRoute != null) {
      // 如果存在，则移除现有的路线图层和源
      await _removeExistingRoute();
      
      setState(() {
        route = newRoute;
      });

      GeoJsonHelper.drawRoute(
        mapController: mapController!, 
        route: route!, 
        routeSourceId: GlobalConstants.routeSourceId, 
        routeLayerId: GlobalConstants.routeLayerId,
        routeColor: GlobalConstants.routeColor,
        routeLineWidth: GlobalConstants.routeLineWidth,
        beforeLayerId: GlobalConstants.pisteLayerId,
      );
      routeSources.add(GlobalConstants.routeSourceId);
      routeLayers.add(GlobalConstants.routeLayerId);

      // refresh piste and lift layers to apply lowlight opacity
      _refreshPisteAndLiftLayers(opacity: GlobalConstants.lowlightFeatureOpacity);
      
    }
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    // Handle map click event
  }

  // web does not support long click, it maps double click to long click
  void _onMapLongClick(Point<double> point, LatLng coordinates) async {
    print('Long-click at: ${coordinates.latitude}, ${coordinates.longitude}');
    
    if (startCoordinate != null && endCoordinate != null) {
      // Case: Both coordinates are already set. Clear all and reset startCoordinate
      print("clear all and set startCoordinate: $coordinates");
      _clearAllCircles(); // Clear existing circles
      // Remove existing route layer and source if they exist
        await _removeExistingRoute();
      startCoordinate = coordinates;
      endCoordinate = null;
      _addCircleWithText(
        coordinates,
        circleColor: "#00FF00", // Green circle for start
        text: "A",
      );
    } else if (startCoordinate != null && endCoordinate == null) {
      // Case: Start is set, set endCoordinate
      print("set endCoordinate: $coordinates and start generating route");
      endCoordinate = coordinates;
      _addCircleWithText(
        coordinates,
        circleColor: "#0000FF", // Blue circle for end
        text: "B",
      );
      _generateRoute(startCoordinate!, endCoordinate!);
      _generateSkiPlannerUrl(selectedResortKey, startCoordinate, endCoordinate, stopovers);
    } else {
      // Case: Neither is set, set startCoordinate
      print("set startCoordinate: $coordinates");
      startCoordinate = coordinates;
      _addCircleWithText(
        coordinates,
        circleColor: "#00FF00", // Green circle for start
        text: "A",
      );
    }
  }

  void _addCircleWithText(
    LatLng coordinates, {
    required String circleColor,
    required String text,
    String textColor = "#FFFFFF", // Default text color is white
  }) {
    mapController?.addCircle(
      CircleOptions(
        geometry: coordinates,
        circleRadius: 15,         // Radius in pixels
        circleColor: circleColor, // Configurable circle color
        circleOpacity: 0.6,       // Adjust opacity as needed
      ),
    );

    mapController?.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        textField: text,          // Configurable text
        textSize: 12,
        textColor: textColor,     // Configurable text color, defaults to white
        textHaloColor: "#000000", // Optional: black outline for better visibility
        textHaloWidth: 1.5,
        textAnchor: "center",     // Center the text in the circle
      ),
    );
  }

  void _addCurrentLocation(
    LatLng coordinates) {
    mapController?.addCircle(
      CircleOptions(
        geometry: coordinates,
        circleRadius: 8,         // Radius in pixels
        circleColor: Colors.lightBlue.toHexStringRGB(), // Configurable circle color
        circleOpacity: 0.9,       // Adjust opacity as needed
        circleStrokeColor: const Color.fromARGB(255, 188, 179, 179).toHexStringRGB(),
        circleStrokeWidth: 3,
        circleBlur: 0.1,
      ),
    );
  }

  void _clearAllCircles() {
    // Clear all circles and symbols from the map
    mapController?.clearCircles(); // Clear circles
    mapController?.clearSymbols(); // Clear symbols
  }

  Future<void> _launchUrl(String _url) async {
    if (!await launchUrl(Uri.parse(_url))) {
      throw Exception('Could not launch $_url');
    }
  }

  void _locateCurrentPosition() async {
    try {
      final location = await _locationService.getCurrentLocation();
      LatLng currentLocation = LatLng(location['latitude'], location['longitude']);
      print("current location: $currentLocation");
      setState(() {
        resortCoordinate = currentLocation;
      });
      
      // Animate the map to the current location
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLocation, 14));
      // Draw the blue icon on the map
      _addCurrentLocation(
        currentLocation
      );
    } catch (error) {
      print('Error: $error');
    }
  }

  /// Draw a blue icon at the user's current location
  Future<void> _drawCurrentLocationIcon(LatLng currentLocation) async {
    try {
      // Add the GeoJSON source for the current location
      await mapController?.addSource(
        "current_location_source",
        GeojsonSourceProperties(data: {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [currentLocation.longitude, currentLocation.latitude],
              },
            }
          ],
        }),
      );

      // Add the symbol layer with a blue icon
      await mapController?.addSymbolLayer(
        "current_location_source",
        "current_location_layer",
        SymbolLayerProperties(
          iconImage: "marker-15", // Default Mapbox marker
          iconColor: "#007AFF",   // Blue color for the icon
          iconSize: 1.5,          // Adjust icon size
          iconAnchor: "center",   // Center the icon
        ),
      );

      print("Blue icon added at $currentLocation");
    } catch (error) {
      print("Error drawing current location icon: $error");
    }
  }

  void _showSharePopup() {
    final String generatedUrl = _generateSkiPlannerUrl(selectedResortKey, startCoordinate, endCoordinate, stopovers);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Share SnowNavi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                generatedUrl,
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  html.window.navigator.clipboard?.writeText(generatedUrl);
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("URL copied to clipboard!")),
                  );
                },
                icon: Icon(Icons.copy),
                label: Text("Copy URL"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _setZoomGestures(bool? flag) {
    setState(() {
      if (flag != null) {
        _zoomGesturesEnabled = flag;
      } else {
        _zoomGesturesEnabled = !_zoomGesturesEnabled;
      }
      print("setZoomEnabled to $_zoomGesturesEnabled");
    });
  }
  void _toggleZoomGestures() {
    _setZoomGestures(null);
  }

  void _checkIfInsideChildWidget(PointerEvent event) {
    print("checking pointerEvent $event");
    for (var key in _childWidgetKeys) {
      final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final Offset position = box.localToGlobal(Offset.zero); // Top-left position
        final Size size = box.size;

        // Check if mouse event is inside this widget's bounds
        if (event.position.dx >= position.dx &&
            event.position.dx <= position.dx + size.width &&
            event.position.dy >= position.dy &&
            event.position.dy <= position.dy + size.height) {
          _setZoomGestures(false); // Disable zoom if inside
          return;
        }
      }
    }
    _setZoomGestures(true); // Enable zoom if outside
  }

  void _handleRouteClose() {
    // Additional actions after closing the route
    _removeExistingRoute();  // Clears the drawn route from the map
    _clearAllCircles();
    print("Route panel closed, map layers restored.");
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _checkIfInsideChildWidget, 
      child: Scaffold(
        body: Stack(
          children: [
            MapboxMap(
              accessToken:
                  'pk.eyJ1Ijoib2tib3kyMDA4IiwiYSI6ImNsdGE1dzd6OTAxbHQyanA0aWM1MjU5c24ifQ.vbbY3gzL8nnUFctmDv9UBQ',
              onMapCreated: _onMapCreated,
              onCameraIdle: _onCameraIdle,
              onMapClick: _onMapClick,
              onMapLongClick: _onMapLongClick,
              onStyleLoadedCallback: _onStyleLoadedCallback,
              initialCameraPosition: _getInitialCameraPosition(),
              doubleClickZoomEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: _zoomGesturesEnabled,
              styleString: 'mapbox://styles/okboy2008/clx1zai3s01ck01rb5zsv600u', // Your custom Mapbox style
              compassEnabled: true, // Disable the compass button
              compassViewPosition: CompassViewPosition.BottomRight,
            ),
            // Floating Route Panel (Between Search Box & Filter Button)
            if (route != null) 
              FloatingRouteInstructionPanel(
                key: _childWidgetKeys[0],
                route: route!,
                onClose: _handleRouteClose,
                panelWidth: GlobalConstants.searchboxWidth,
                timerFlag: isUiOpen,
                mapController: mapController!,
              ),
            // Attribution
            Positioned(
              bottom: 5,
              left: 100,
              child: GestureDetector(
                onTap: () {
                  _launchUrl('https://www.xiaohongshu.com/user/profile/5ffeddbb000000000100388d');
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'Follow me on 小红书 @了不起的okboy',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 209, 6, 6),
                      fontSize: 12,
                      decoration: TextDecoration.none, // Add underline for link effect
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              key: _childWidgetKeys[1],
              top: 20,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Container(
                        width: GlobalConstants.searchboxWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSearchSubmitted,
                          decoration: InputDecoration(
                            hintText: 'Search POI',
                            prefixIcon: Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (poiResults.isNotEmpty)
                    Container(
                      width: 250,
                      height: 600,
                      margin: EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        itemCount: poiResults.length,
                        itemBuilder: (context, index) {
                          final poi = poiResults[index];
                          return ListTile(
                            title: Text(poi['name']),
                            subtitle: Text(
                              '${poi['distance'].toStringAsFixed(2)} km',
                              style: TextStyle(height: 1.5), // Adjust line spacing for readability
                            ),
                            isThreeLine: true, // Allows multiple lines in the subtitle
                            onTap: () {
                              LatLng coord = LatLng(poi['lat'], poi['lng']);
                              _onMapLongClick(Point(0,0), coord);
                              mapController?.animateCamera(
                                CameraUpdate.newLatLng(
                                  coord,
                                ),
                              );
                              setState(() {
                                hasSearched = false;
                                poiResults = [];
                                _searchController.clear();
                              });
                            },
                          );
                        },
                      ),
                    )
                  else if (hasSearched)
                    Container(
                      width: 250,
                      height: 50,
                      margin: EdgeInsets.only(top: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No results found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 筛选按钮
            Positioned(
              bottom: 38,
              left: 20, 
              child: Transform.scale(
                scale: GlobalConstants.floatingActionButtonScale, // 缩放比例
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity), // 按钮颜色
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
                scale: GlobalConstants.floatingActionButtonScale,
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
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
            Positioned(
              top: 68,
              right: 20, 
              child: Transform.scale(
                scale: GlobalConstants.floatingActionButtonScale,
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
                  onPressed: _locateCurrentPosition,
                  tooltip: 'Locate Me',
                  child: Icon(Icons.my_location),
                ),
              ),
            ),
            Positioned(
              top: 118, // Below "Locate Me" button
              right: 20,
              child: Transform.scale(
                scale: GlobalConstants.floatingActionButtonScale,
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
                  onPressed: _showSharePopup, // Show popup with URL
                  tooltip: 'Share SnowNavi',
                  child: Icon(Icons.share),
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
                    // print('Flag emoji for $country: $flagEmoji');
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(
                        '$flagEmoji ${resort?['name']['en'] ?? 'Unknown Resort'}',
                        style: TextStyle(
                          fontFamily: 'NotoEmoji',  // Specify Noto Emoji font family
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.left, // Align text to the left
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
      ),
    );
  }
}
