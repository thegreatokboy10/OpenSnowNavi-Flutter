import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:snownavi/web_title_helper.dart';
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

import 'widgets/lift_info_panel.dart';
import 'widgets/piste_info_panel.dart';
import 'widgets/route_instruction_panel.dart'; // Add this for opening URLs
import 'widgets/team_panel.dart';
import 'widgets/route_planning_panel.dart';
import 'team/team_service.dart';
import 'meeting_point/meeting_point_model.dart';
import 'meeting_point/meeting_point_service.dart';
import 'route_planning/route_planning_state.dart';

class GeneratorPage extends StatefulWidget {
  final List<List<double>>? coordinates; // List of lat-lng pairs
  final String? resortKey; // Resort key for the map
  final String? teamId; // Team ID for joining a team from shared link

  const GeneratorPage({Key? key, this.coordinates, this.resortKey, this.teamId})
      : super(key: key);

  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  bool _zoomGesturesEnabled = true;
  List<GlobalKey> _childWidgetKeys = []; // Store GlobalKeys of child widgets

  // Create an instance of RouteEngine
  final routeEngine = re.RouteEngine();
  re.Route? route;
  List<LatLng> stopovers =
      []; // TODO: think about how to properly support stopovers
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

  Symbol? _redMarker;
  bool _circleTextSourceExists = false;
  List<Map<String, dynamic>> _circleTextFeatures = [];

  Uint8List? _photoBytes;
  LatLng? _photoLocation;

  bool _isLoading = true; // Track loading state

  // Team feature
  bool _showTeamPanel = false;
  final TeamService _teamService = TeamService.instance;
  List<Symbol> _teamMemberSymbols = [];
  Map<String, String> _memberSymbolToDeviceId = {}; // Symbol ID -> Device ID 映射
  Set<String> _addedMemberIconImages = {}; // 已添加的成员图标图片名称

  // Meeting point feature
  bool _showMeetingPointPanel = false;
  bool _showMeetingPointsLayer = true; // 是否显示集合点图层
  final MeetingPointService _meetingPointService = MeetingPointService.instance;
  List<Symbol> _meetingPointNameSymbols = []; // 所有集合点的名称标记
  List<Map<String, dynamic>> _meetingPointCircleFeatures =
      []; // 集合点圆圈 features（用于清理）

  // 路线规划流程状态
  final RoutePlanningData _routePlanningData = RoutePlanningData();
  bool _showRoutePlanningPanel = false; // 是否显示路线规划面板
  bool _isAddingStopover = false; // 是否正在添加途径点
  RoutePointType? _pendingPhotoPointType; // 从图片选择位置时的目标点位类型
  EditingPointType _currentEditingType = EditingPointType.none; // 当前路线规划面板编辑类型

  // 当前位置标记
  Circle? _myLocationCircle; // 位置圆点
  Circle? _myLocationPulseCircle; // 呼吸动画圆圈
  Symbol? _myLocationDirectionSymbol; // 朝向箭头
  Symbol? _myLocationHeadingText; // 朝向读数文本
  bool _myLocationIconAdded = false; // 是否已添加朝向图标
  Timer? _locationPulseTimer; // 呼吸动画定时器
  double _pulseRadius = 12.0; // 呼吸圆圈半径
  bool _pulseExpanding = true; // 是否正在扩大

  // 移动端检测
  bool get _isMobile {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobile') ||
        userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad');
  }

  void _initializeCircleTextSource() {
    if (mapController == null) return;

    // Create a new GeoJSON source
    mapController?.addSource(
      'circle-text-source',
      GeojsonSourceProperties(
        data: {
          "type": "FeatureCollection",
          "features": []
        }, // Start with empty features
      ),
    );

    // Add a layer to render circles
    mapController?.addCircleLayer(
      'circle-text-source',
      'circle-layer',
      CircleLayerProperties(
        circleColor: ['get', 'color'], // Use color from GeoJSON properties
        circleRadius: 15, // Adjust size as needed
        circleOpacity: 0.6,
      ),
    );

    // Add a layer to render text labels
    mapController?.addSymbolLayer(
      'circle-text-source',
      'circle-text-layer',
      SymbolLayerProperties(
        textField: ['get', 'text'], // Fetch text from properties
        textSize: 12,
        textColor: ['get', 'textColor'], // Dynamic text color
        textHaloColor: "#000000", // Black outline for better visibility
        textHaloWidth: 1.5,
        textAnchor: "center",
      ),
    );

    _circleTextSourceExists = true;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    needRestore = _restoreParameters();
    _childWidgetKeys = List.generate(3, (index) => GlobalKey());
    _initializeTeam();
  }

  Future<void> _initializeTeam() async {
    await _teamService.initialize();

    // 处理团队邀请链接
    if (widget.teamId != null && widget.teamId!.isNotEmpty) {
      final result = await _teamService.joinTeam(widget.teamId!);
      if (result.success) {
        setState(() => _showTeamPanel = true);
      }
    }

    // 初始化时如果有团队，定位到当前位置
    // 注意：标记更新会在 _onStyleLoadedCallback 中进行，因为此时地图可能还没准备好
    if (_teamService.currentTeam != null) {
      print(
          '[MapboxView] Team restored, will update markers when map is ready');

      // 初始化集合点服务
      _initializeMeetingPointService();

      // 自动定位到当前设备位置
      try {
        final location = await _locationService.getCurrentLocation();
        final currentLatLng =
            LatLng(location['latitude'], location['longitude']);
        // 等待地图控制器准备好
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLatLng, 15),
          );
        }
      } catch (e) {
        print('[MapboxView] Failed to get current location: $e');
      }
    }
  }

  /// 初始化集合点服务
  void _initializeMeetingPointService() {
    final team = _teamService.currentTeam;
    if (team == null) return;

    final deviceId = _teamService.deviceId;
    final currentMember = _teamService.currentMember;
    final nickname = currentMember?.nickname ?? '未知';

    _meetingPointService.setContext(
      teamId: team.id,
      deviceId: deviceId,
      nickname: nickname,
    );

    // 设置回调 - 集合点列表更新时刷新图层
    _meetingPointService.onMeetingPointsUpdated = (points) {
      _updateMeetingPointsLayer();
    };

    // 设置回调 - 活动集合点变化时更新图层和规划路线
    _meetingPointService.onActiveMeetingPointChanged = (activePoint) {
      _updateMeetingPointsLayer();
      // 如果有活动集合点，自动规划路线
      // 但如果是从路线共享链接进入的，不要覆盖共享的路线
      if (activePoint != null && !needRestore && route == null) {
        _planRouteToMeetingPoint(activePoint);
      }
    };

    // 加载集合点
    _meetingPointService.loadMeetingPoints();
  }

  /// 更新所有集合点图层（使用与路线标记相同的 circle-text-source）
  Future<void> _updateMeetingPointsLayer() async {
    if (mapController == null) return;

    // 确保 source 已初始化
    if (!_circleTextSourceExists) {
      _initializeCircleTextSource();
    }

    // 先移除名称 symbols
    for (final symbol in _meetingPointNameSymbols) {
      await mapController!.removeSymbol(symbol);
    }
    _meetingPointNameSymbols.clear();

    // 从 _circleTextFeatures 中移除之前的集合点圆圈
    for (final feature in _meetingPointCircleFeatures) {
      _circleTextFeatures.remove(feature);
    }
    _meetingPointCircleFeatures.clear();

    // 如果图层被关闭，更新 source 后返回
    if (!_showMeetingPointsLayer) {
      mapController?.setGeoJsonSource(
        'circle-text-source',
        {"type": "FeatureCollection", "features": _circleTextFeatures},
      );
      print('[MapboxView] Meeting points layer is hidden');
      return;
    }

    // 获取所有集合点
    final points = _meetingPointService.meetingPoints;
    if (points.isEmpty) {
      mapController?.setGeoJsonSource(
        'circle-text-source',
        {"type": "FeatureCollection", "features": _circleTextFeatures},
      );
      print('[MapboxView] No meeting points to display');
      return;
    }

    // 添加所有集合点标记
    for (final point in points) {
      // 判断是否是当前路线的终点
      final isRouteEndpoint = _isPointRouteEndpoint(point.latLng);

      // 如果是路线终点且非active，跳过（会用路线终点标记）
      if (isRouteEndpoint && !point.isActive) {
        continue;
      }

      // 创建集合点圆圈 feature
      Map<String, dynamic> circleFeature = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [point.latLng.longitude, point.latLng.latitude],
        },
        "properties": {
          "color": "#FF5722", // deepOrange
          "text": point.isActive ? "★" : "", // active显示★，否则不显示
          "textColor": "#FFFFFF",
        },
      };

      // 添加到 _circleTextFeatures 和 _meetingPointCircleFeatures
      _circleTextFeatures.add(circleFeature);
      _meetingPointCircleFeatures.add(circleFeature);

      // 添加名称 symbol（显示在圆圈下方）
      final nameSymbol = await mapController!.addSymbol(
        SymbolOptions(
          geometry: point.latLng,
          textField: point.name,
          textOffset: Offset(0, 1.8),
          textColor: '#FF5722',
          textSize: 12,
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.5,
          textAnchor: 'top',
        ),
      );
      _meetingPointNameSymbols.add(nameSymbol);
    }

    // 更新 GeoJSON source
    mapController?.setGeoJsonSource(
      'circle-text-source',
      {"type": "FeatureCollection", "features": _circleTextFeatures},
    );

    print(
        '[MapboxView] Updated meeting points layer: ${_meetingPointNameSymbols.length} points');
  }

  /// 判断某个点是否是当前路线的终点
  bool _isPointRouteEndpoint(LatLng point) {
    if (endCoordinate == null) return false;
    // 使用较小的误差范围判断是否是同一点
    const epsilon = 0.0001;
    return (point.latitude - endCoordinate!.latitude).abs() < epsilon &&
        (point.longitude - endCoordinate!.longitude).abs() < epsilon;
  }

  /// 自动规划到集合点的路线（使用路线规划面板）
  Future<void> _planRouteToMeetingPoint(MeetingPoint meetingPoint) async {
    try {
      // 获取当前位置
      final location = await _locationService.getCurrentLocation();
      final currentLatLng = LatLng(location['latitude'], location['longitude']);

      // 清除之前的路线
      await _removeExistingRoute();
      _clearAllCirclesWithText();

      // 设置路线规划数据
      setState(() {
        _routePlanningData.reset();
        _routePlanningData.setOrigin(RoutePoint(
          id: 'origin',
          name: '我的位置',
          coordinates: currentLatLng,
          type: RoutePointType.origin,
        ));
        _routePlanningData.setDestination(RoutePoint(
          id: 'destination',
          name: meetingPoint.name,
          coordinates: meetingPoint.latLng,
          type: RoutePointType.destination,
        ));
        _showRoutePlanningPanel = true;
      });

      // 更新标记
      _updateRoutePlanningMarkers();

      // 自动算路
      _autoGenerateRouteIfReady();

      // 更新集合点图层以显示终点标记
      await _updateMeetingPointsLayer();

      print(
          '[MapboxView] Auto-planned route to meeting point: ${meetingPoint.name}');
    } catch (e) {
      print('[MapboxView] Failed to plan route to meeting point: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _teamService.dispose();
    super.dispose();
  }

  // Parses coordinates and restores class variables
  bool _restoreParameters() {
    bool hasResortKey =
        widget.resortKey != null && widget.resortKey!.isNotEmpty;
    bool hasCoordinates =
        widget.coordinates != null && widget.coordinates!.isNotEmpty;

    if (!hasResortKey || !hasCoordinates) {
      print("no route needs to restored");
      return false; // One or both parameters are missing
    }

    // Assign resortKey only if it's non-empty and non-null
    selectedResortKey = widget.resortKey!;

    // Assign coordinates only if they exist
    startCoordinate =
        LatLng(widget.coordinates!.first[1], widget.coordinates!.first[0]);
    endCoordinate =
        LatLng(widget.coordinates!.last[1], widget.coordinates!.last[0]);

    if (widget.coordinates!.length > 2) {
      stopovers = widget.coordinates!
          .sublist(1, widget.coordinates!.length - 1)
          .map((coord) => LatLng(coord[1], coord[0]))
          .toList();
    } else {
      stopovers = [];
    }

    print(
        "route needs to be restored with $selectedResortKey and $startCoordinate to $endCoordinate via $stopovers");
    return true; // Both parameters are present
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false)
      _debounce!.cancel(); // Cancel any active timer

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.length >= 3) {
        hasSearched = true; // Set to true when a search is triggered
        LatLng center = resortCoordinate!;
        double radiusKm = 15.0;
        List<Map<String, dynamic>> results =
            await SearchService.searchPOI(query, center, radiusKm);
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
  Future<Uint8List> _createFlutterIconAsImage(
      IconData iconData, Color color, double size) async {
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
      minZoom: GlobalConstants
          .minZoomPiste, // Use the predefined minimum zoom for pistes
      textOffset: 0.5, // Slight vertical adjustment for text
      textOpacity: opacity,
    );
    pisteLayers.add('run-name-layer');
    GeoJsonHelper.addArrowLayer(
      mapController: mapController!,
      sourceId: GlobalConstants.pisteSourceId,
      layerId: 'run-arrow-layer',
      iconImage:
          'default-piste-arrow', // Fallback icon if no dynamic expression is provided
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
      minZoom: GlobalConstants
          .minZoomLift, // Use the predefined minimum zoom for lifts
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

  void onFeatureTap(
      dynamic featureId, Point<double> point, LatLng latLng) async {
    if (isUiOpen.flag) {
      print("set isUiOpen to false");
      isUiOpen.flag = false;
      return;
    }

    // Piste and Lift features
    List features =
        await mapController!.queryRenderedFeatures(point, layerIds, null);

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
            southwest.latitude < point.latitude
                ? southwest.latitude
                : point.latitude,
            southwest.longitude < point.longitude
                ? southwest.longitude
                : point.longitude,
          );
          northeast = LatLng(
            northeast.latitude > point.latitude
                ? northeast.latitude
                : point.latitude,
            northeast.longitude > point.longitude
                ? northeast.longitude
                : point.longitude,
          );
        }

        // First, get the current camera position to preserve bearing
        double currentBearing = mapController!.cameraPosition!.bearing;

        // Create the LatLngBounds object
        LatLngBounds bounds =
            LatLngBounds(southwest: southwest, northeast: northeast);

        // Change camera to focus on the LineString bounds
        await mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds,
              top: 50.0,
              bottom: 3 * 50.0,
              left: 50.0,
              right: 50.0), // 50 is padding
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
      Piste? selectedPiste;
      for (var piste in GlobalData.pistes) {
        if (piste.id == id) {
          piste.highlightMe(mapController!);
          selectedPiste = piste;
          featureFound = true;
          break;
        }
      }
      Lift? selectedLift;
      if (!featureFound) {
        for (var lift in GlobalData.lifts) {
          if (lift.id == id) {
            lift.highlightMe(mapController!);
            selectedLift = lift;
            featureFound = true;
            break;
          }
        }
      }

      if (selectedPiste != null) {
        showBottomSheet(
          context: context,
          backgroundColor:
              Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
          enableDrag: false,
          builder: (BuildContext context) {
            return PisteInfoPanel(
              piste: selectedPiste!,
              timerFlag: isUiOpen,
              onClose: () => selectedPiste!.unhighlightMe(mapController!),
            );
          },
        );
      } else if (selectedLift != null) {
        // Show bottom sheet
        showBottomSheet(
          context: context,
          backgroundColor:
              Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
          enableDrag: false,
          builder: (BuildContext context) {
            return LiftInfoPanel(
              lift: selectedLift!,
              timerFlag: isUiOpen,
              onClose: () => selectedLift!.unhighlightMe(mapController!),
            );
          },
        );
      }
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
    mapController!
        .addImage(GlobalConstants.routeHighlightImageName, markerImage);

    // Add layers from GeoJSON assets
    await _loadSkiResortData();

    // Restore route
    if (needRestore) {
      print("restore route $startCoordinate, $endCoordinate");

      // 安全地处理起点和终点
      if (startCoordinate != null && endCoordinate != null) {
        // 设置起点和终点
        _setRouteCoordinates(startCoordinate!, endCoordinate!,
            stopovers: stopovers);

        // 生成路线
        _generateRoute(startCoordinate!, endCoordinate!, stopovers: stopovers);

        // 同时设置路线规划面板数据并显示
        _populateRoutePlanningPanelFromSharedRoute();

        // 标记为已恢复
        needRestore = false;
      } else {
        print("Start or end coordinate is null, cannot restore route.");
      }
    }

    // 地图样式加载完成后，更新团队成员标记
    if (_teamService.currentTeam != null) {
      print('[MapboxView] Style loaded, updating team member markers');
      await _updateTeamMemberMarkers();
    }

    setState(() {
      _isLoading = false; // Mark loading as complete
    });
  }

  void _setRouteCoordinates(LatLng start, LatLng end,
      {List<LatLng>? stopovers}) {
    _clearAllCirclesWithText(); // Clear existing circles

    // Add start point
    _addCircleWithText(
      start,
      circleColor: "#00FF00", // Green for start
      text: "A",
    );

    // Add stopovers if they exist
    if (stopovers != null && stopovers.isNotEmpty) {
      for (int i = 0; i < stopovers.length; i++) {
        _addCircleWithText(
          stopovers[i],
          circleColor: "#FFA500", // Orange for stopovers
          text: (i + 1).toString(), // Number each stopover
        );
      }
    }

    // Add end point
    _addCircleWithText(
      end,
      circleColor: "#0000FF", // Blue for destination
      text: "B",
    );
  }

  // Callback when the Mapbox map is created
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    mapController?.onFeatureTapped.add(onFeatureTap);
    mapController?.onSymbolTapped.add(_handleSymbolTapped);
    _locationService.enableBackgroundMode(true);
  }

  /// 处理 Symbol 点击事件
  void _handleSymbolTapped(Symbol symbol) {
    // 检查是否是团队成员标记
    if (_memberSymbolToDeviceId.containsKey(symbol.id)) {
      _onTeamMemberSymbolTapped(symbol);
    }
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
          tilt: is3DMode ? 60.0 : 0.0, // Change tilt only
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
                          print(
                              "FilterDialog inside checkbox onTapDown, set isUiOpen to true");
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
      'Switzerland': 'CH', // 添加瑞士
      'Austria': 'AT', // 添加奥地利
      'Germany': 'DE', // 添加德国
      'Italy': 'IT' // 添加意大利
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
    final zoom =
        selectedResort?['zoom'] ?? 13.0; // Default zoom if not provided
    if (lat != null && lng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom),
        ),
      );
      // Wait for the camera to move
      await Future.delayed(Duration(milliseconds: 1000));
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

  void _removeStopOvers() {
    setState(() {
      startCoordinate = null;
      endCoordinate = null;
      stopovers.clear();
    });
  }

  String _generateSkiPlannerUrl(String selectedResortKey,
      LatLng? startCoordinate, LatLng? endCoordinate, List<LatLng>? stopovers) {
    // Get the current full URL (including existing parameters)
    final String currentFullPath = html.window.location
        .href; // Example: http://localhost:60423/preview/?coords=...
    final Uri currentUri = Uri.parse(currentFullPath);

    // Remove existing query parameters and keep only domain + path
    final String baseUrl = "${currentUri.origin}${currentUri.path}";

    // Ensure start and end coordinates exist
    if (startCoordinate == null || endCoordinate == null) {
      return baseUrl;
    }

    // Collect all coordinates (start → stopovers → end)
    List<LatLng> allCoordinates = [
      startCoordinate,
      if (stopovers != null) ...stopovers,
      endCoordinate
    ];

    // Convert coordinates to the required format (lng,lat;lng,lat)
    final String coordsString = allCoordinates
        .map((coord) =>
            "${coord.longitude},${coord.latitude}") // Ensure correct order
        .join(';');

    // Build query parameters
    final Uri uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'coords': coordsString,
        if (selectedResortKey.isNotEmpty)
          'resortKey': selectedResortKey, // Include only if not empty
      },
    );

    print("generated route url: ${uri.toString()}");
    return uri.toString();
  }

  void _generateRoute(LatLng startCoordinate, LatLng endCoordinate,
      {List<LatLng>? stopovers}) async {
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
      _refreshPisteAndLiftLayers(
          opacity: GlobalConstants.lowlightFeatureOpacity);
    }
  }

  /// Adds a red marker at the clicked location using the best available Mapbox icon.
  void _addRedMarker(LatLng coordinates) async {
    if (mapController == null) return;

    // Remove existing marker before adding a new one
    if (_redMarker != null) {
      await mapController!.removeSymbol(_redMarker!);
    }

    // Add the new marker using the best Mapbox built-in icon
    _redMarker = await mapController!.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        iconImage: 'marker', // Use Mapbox's built-in marker
        iconSize: 2.5, // Adjust size for visibility
      ),
    );

    print(
        "Added red marker at: ${coordinates.latitude}, ${coordinates.longitude}");
  }

  /// 移动端：点击 Select 按钮时获取地图中心点并触发点击处理
  void _onSelectCenterPoint() {
    if (mapController == null) return;

    // 获取当前地图中心点
    final cameraPosition = mapController!.cameraPosition;
    if (cameraPosition != null) {
      final centerCoord = cameraPosition.target;
      print(
          'Select center point: ${centerCoord.latitude}, ${centerCoord.longitude}');
      // 直接调用核心点击处理逻辑，绕过 isUiOpen 检查
      _handleLocationSelect(centerCoord);
    }
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    if (isUiOpen.flag) {
      isUiOpen.flag = false;
      print("Map clicked, set isUiOpen to false");
      return;
    }
    _handleLocationSelect(coordinates);
  }

  /// 核心位置选择逻辑，被 _onMapClick 和 _onSelectCenterPoint 调用
  void _handleLocationSelect(LatLng coordinates) async {
    print(
        'Location selected: ${coordinates.latitude}, ${coordinates.longitude}');
    WebTitleHelper.updateTitle(
        'Map clicked at: ${coordinates.latitude}, ${coordinates.longitude}');
    mapController?.animateCamera(CameraUpdate.newLatLng(coordinates));

    // Add a red marker at the clicked location
    _addRedMarker(coordinates);

    // Show bottom sheet
    showBottomSheet(
      context: context,
      backgroundColor:
          Colors.white.withOpacity(GlobalConstants.floatingbuttonopacity),
      enableDrag: false, // Prevent accidental closing
      builder: (BuildContext context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Capture all events
          onTapDown: (details) {
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          "Selected Location",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            isUiOpen.flag = true;
                            WebTitleHelper.resetTitle();
                            _removePhoto();
                            Navigator.pop(context); // Close bottom sheet
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      "Lat: ${coordinates.latitude.toStringAsFixed(6)}, "
                      "Lng: ${coordinates.longitude.toStringAsFixed(6)}",
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 16.0),

                    // 根据路线规划状态显示不同的按钮
                    _buildLocationDetailButtons(context, coordinates),
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

  void _handleAddToRoute(LatLng coordinates) {
    if (startCoordinate == null) {
      // Case: No start point, set this as start
      print("Setting start coordinate: $coordinates");
      startCoordinate = coordinates;
      _addCircleWithText(
        coordinates,
        circleColor: "#00FF00", // Green for start
        text: "A",
      );
    } else {
      // Case: start exists, add this as a stopover
      print("Adding stopover: $coordinates");
      stopovers.add(coordinates);
      _addCircleWithText(
        coordinates,
        circleColor: "#FFA500", // Orange for stopovers
        text: (stopovers.length).toString(),
      );
    }

    // If both start and destination exist, start generating route
    if (startCoordinate != null && endCoordinate != null) {
      print("Both start and destination exist, generating route...");
      _generateRoute(startCoordinate!, endCoordinate!, stopovers: stopovers);
    }
  }

  void _handleGoButton(LatLng coordinates) {
    print("Setting destination: $coordinates");
    endCoordinate = coordinates;

    _addCircleWithText(
      coordinates,
      circleColor: "#0000FF", // Blue circle for destination
      text: "B",
    );

    // Start route planning only if there's a start point
    if (startCoordinate != null) {
      print("Start point exists, generating route...");
      _generateRoute(startCoordinate!, endCoordinate!, stopovers: stopovers);
    } else {
      print("No start point, waiting for further input.");
    }
  }

  // ========== 新的路线规划流程方法 ==========

  /// 开始路线规划 - 设置终点
  void _startRoutePlanning(LatLng coordinates, String name) {
    setState(() {
      _routePlanningData.setDestination(RoutePoint(
        id: 'destination',
        name: name,
        coordinates: coordinates,
        type: RoutePointType.destination,
      ));
      _showRoutePlanningPanel = true;
      _isAddingStopover = false;
    });
    _updateRoutePlanningMarkers();
  }

  /// 设置起点
  void _setRoutePlanningOrigin(LatLng coordinates, String name) {
    setState(() {
      _routePlanningData.setOrigin(RoutePoint(
        id: 'origin',
        name: name,
        coordinates: coordinates,
        type: RoutePointType.origin,
      ));
    });
    _updateRoutePlanningMarkers();
    // 自动算路
    _autoGenerateRouteIfReady();
  }

  /// 添加途径点
  void _addRoutePlanningStopover(LatLng coordinates, String name) {
    setState(() {
      _routePlanningData.addStopover(RoutePoint(
        id: 'stopover_${_routePlanningData.stopovers.length}',
        name: name,
        coordinates: coordinates,
        type: RoutePointType.stopover,
      ));
      _isAddingStopover = false;
    });
    _updateRoutePlanningMarkers();
    // 自动算路
    _autoGenerateRouteIfReady();
  }

  /// 处理路线规划面板中选择的点位
  void _handleRoutePlanningPointSelected(
      LatLng coordinates, String name, RoutePointType type) {
    setState(() {
      switch (type) {
        case RoutePointType.origin:
          _routePlanningData.setOrigin(RoutePoint(
            id: 'origin',
            name: name,
            coordinates: coordinates,
            type: RoutePointType.origin,
          ));
          break;
        case RoutePointType.destination:
          _routePlanningData.setDestination(RoutePoint(
            id: 'destination',
            name: name,
            coordinates: coordinates,
            type: RoutePointType.destination,
          ));
          break;
        case RoutePointType.stopover:
          _routePlanningData.addStopover(RoutePoint(
            id: 'stopover_${_routePlanningData.stopovers.length}',
            name: name,
            coordinates: coordinates,
            type: RoutePointType.stopover,
          ));
          break;
      }
    });
    _updateRoutePlanningMarkers();
    // 自动算路
    _autoGenerateRouteIfReady();
  }

  /// 处理删除点位
  void _handleRoutePlanningRemovePoint(int index) {
    setState(() {
      _routePlanningData.removePointAt(index);
    });
    _updateRoutePlanningMarkers();
    // 如果删除后仍可算路，重新算路
    _autoGenerateRouteIfReady();
  }

  /// 处理重新排序点位
  void _handleRoutePlanningReorderPoints(int oldIndex, int newIndex) {
    setState(() {
      _routePlanningData.reorderAllPoints(oldIndex, newIndex);
    });
    _updateRoutePlanningMarkers();
    // 重新算路
    _autoGenerateRouteIfReady();
  }

  /// 自动算路（如果起点和终点都存在）
  void _autoGenerateRouteIfReady() {
    if (_routePlanningData.canGenerateRoute) {
      _generateRoutePlanningRoute();
    }
  }

  /// 生成路线
  void _generateRoutePlanningRoute() {
    if (!_routePlanningData.canGenerateRoute) return;

    // 转换为旧的路线生成格式
    startCoordinate = _routePlanningData.origin!.coordinates;
    endCoordinate = _routePlanningData.destination!.coordinates;
    stopovers = _routePlanningData.stopovers.map((s) => s.coordinates).toList();

    // 设置标记
    _setRouteCoordinates(startCoordinate!, endCoordinate!,
        stopovers: stopovers);

    // 生成路线
    _generateRoute(startCoordinate!, endCoordinate!, stopovers: stopovers);
  }

  /// 退出路线规划
  /// 从共享路线链接填充路线规划面板
  void _populateRoutePlanningPanelFromSharedRoute() {
    setState(() {
      _routePlanningData.reset();

      // 设置起点
      if (startCoordinate != null) {
        final originName =
            '${startCoordinate!.latitude.toStringAsFixed(4)}, ${startCoordinate!.longitude.toStringAsFixed(4)}';
        _routePlanningData.setOrigin(RoutePoint(
          id: 'origin',
          name: '起点 ($originName)',
          coordinates: startCoordinate!,
          type: RoutePointType.origin,
        ));
      }

      // 设置终点
      if (endCoordinate != null) {
        final destName =
            '${endCoordinate!.latitude.toStringAsFixed(4)}, ${endCoordinate!.longitude.toStringAsFixed(4)}';
        _routePlanningData.setDestination(RoutePoint(
          id: 'destination',
          name: '终点 ($destName)',
          coordinates: endCoordinate!,
          type: RoutePointType.destination,
        ));
      }

      // 设置途径点
      if (stopovers != null && stopovers!.isNotEmpty) {
        for (int i = 0; i < stopovers!.length; i++) {
          final stopoverName =
              '${stopovers![i].latitude.toStringAsFixed(4)}, ${stopovers![i].longitude.toStringAsFixed(4)}';
          _routePlanningData.addStopover(RoutePoint(
            id: 'stopover_$i',
            name: '途径点 ${i + 1} ($stopoverName)',
            coordinates: stopovers![i],
            type: RoutePointType.stopover,
          ));
        }
      }

      // 设置为规划模式并显示面板
      _routePlanningData.mode = RoutePlanningMode.planning;
      _showRoutePlanningPanel = true;
    });
  }

  void _exitRoutePlanning() {
    setState(() {
      _routePlanningData.reset();
      _showRoutePlanningPanel = false;
      _isAddingStopover = false;
    });
    _clearAllCirclesWithText();
    _removeExistingRoute();
    _removeStopOvers();
  }

  /// 更新路线规划的地图标记
  void _updateRoutePlanningMarkers() {
    _clearAllCirclesWithText();

    // 添加起点标记
    if (_routePlanningData.origin != null) {
      _addCircleWithText(
        _routePlanningData.origin!.coordinates,
        circleColor: "#00FF00",
        text: "A",
      );
    }

    // 添加途径点标记
    for (int i = 0; i < _routePlanningData.stopovers.length; i++) {
      _addCircleWithText(
        _routePlanningData.stopovers[i].coordinates,
        circleColor: "#FFA500",
        text: "${i + 1}",
      );
    }

    // 添加终点标记
    if (_routePlanningData.destination != null) {
      _addCircleWithText(
        _routePlanningData.destination!.coordinates,
        circleColor: "#0000FF",
        text: "B",
      );
    }
  }

  /// 获取当前 POI 详情面板应该显示的按钮类型
  String _getPoiDetailButtonType() {
    switch (_routePlanningData.mode) {
      case RoutePlanningMode.idle:
        return 'initial'; // 显示"路线"和"添加集合点"
      case RoutePlanningMode.selectingOrigin:
        return 'selectOrigin'; // 显示"设为起点"和"添加途径点"
      case RoutePlanningMode.planning:
        // 根据路线规划面板当前编辑的点位类型返回不同的按钮类型
        if (_currentEditingType == EditingPointType.origin) {
          return 'setOrigin'; // 正在编辑起点
        } else if (_currentEditingType == EditingPointType.destination) {
          return 'setDestination'; // 正在编辑终点
        } else if (_isAddingStopover ||
            _currentEditingType == EditingPointType.stopover ||
            _currentEditingType == EditingPointType.newStopover) {
          return 'addStopover'; // 正在添加/编辑途径点
        }
        return 'planning'; // 默认规划模式，显示添加途径点
    }
  }

  /// 构建位置详情面板的按钮
  Widget _buildLocationDetailButtons(BuildContext context, LatLng coordinates) {
    final buttonType = _getPoiDetailButtonType();
    final locationName =
        '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        if (buttonType == 'initial') ...[
          // 初始状态：显示"路线"和"添加集合点"
          GestureDetector(
            onTapDown: (_) => isUiOpen.flag = true,
            child: ElevatedButton.icon(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                _removePhoto();
                _startRoutePlanning(coordinates, locationName);
              },
              icon: Icon(Icons.directions),
              label: Text("路线"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_teamService.currentTeam != null)
            GestureDetector(
              onTapDown: (_) => isUiOpen.flag = true,
              child: ElevatedButton.icon(
                onPressed: () {
                  isUiOpen.flag = true;
                  Navigator.pop(context);
                  _removePhoto();
                  _handleSetMeetingPoint(coordinates, '集合点 $locationName');
                },
                icon: Icon(Icons.star),
                label: Text("添加集合点"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ] else if (buttonType == 'selectOrigin') ...[
          // 选择起点状态：显示"设为起点"和"添加途径点"
          GestureDetector(
            onTapDown: (_) => isUiOpen.flag = true,
            child: ElevatedButton.icon(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                _removePhoto();
                _setRoutePlanningOrigin(coordinates, locationName);
              },
              icon: Icon(Icons.trip_origin),
              label: Text("设为起点"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTapDown: (_) => isUiOpen.flag = true,
            child: ElevatedButton.icon(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                _removePhoto();
                _addRoutePlanningStopover(coordinates, locationName);
              },
              icon: Icon(Icons.add_location),
              label: Text("添加途径点"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ] else if (buttonType == 'setOrigin') ...[
          // 正在编辑起点
          GestureDetector(
            onTapDown: (_) => isUiOpen.flag = true,
            child: ElevatedButton.icon(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                _removePhoto();
                _handleRoutePlanningPointSelected(
                    coordinates, locationName, RoutePointType.origin);
                setState(() => _currentEditingType = EditingPointType.none);
              },
              icon: Icon(Icons.trip_origin),
              label: Text("设为起点"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ] else if (buttonType == 'setDestination') ...[
          // 正在编辑终点
          GestureDetector(
            onTapDown: (_) => isUiOpen.flag = true,
            child: ElevatedButton.icon(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                _removePhoto();
                _handleRoutePlanningPointSelected(
                    coordinates, locationName, RoutePointType.destination);
                setState(() => _currentEditingType = EditingPointType.none);
              },
              icon: Icon(Icons.location_on),
              label: Text("设为终点"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ] else if (buttonType == 'addStopover' || buttonType == 'planning') ...[
          // 添加途径点模式 或 规划模式（从地图添加途径点）
          GestureDetector(
            onTapDown: (_) => isUiOpen.flag = true,
            child: ElevatedButton.icon(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                _removePhoto();
                _addRoutePlanningStopover(coordinates, locationName);
                setState(() => _currentEditingType = EditingPointType.none);
              },
              icon: Icon(Icons.add_location),
              label: Text("添加途径点"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 处理设置集合点
  Future<void> _handleSetMeetingPoint(
      LatLng coordinates, String defaultName) async {
    // 弹出对话框让用户输入集合点名称
    final controller = TextEditingController(text: defaultName);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加集合点'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '集合点名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('添加'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final point = await _meetingPointService.addMeetingPoint(
        name: name,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );

      if (point != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('集合点 "$name" 已添加')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加集合点失败')),
        );
      }
    }
  }

  // web does not support long click, it maps double click to long click
  void _onMapLongClick(Point<double> point, LatLng coordinates) async {
    print('Long-click at: ${coordinates.latitude}, ${coordinates.longitude}');

    // if (startCoordinate != null && endCoordinate != null) {
    //   // Case: Both coordinates are already set. Clear all and reset startCoordinate
    //   print("clear all and set startCoordinate: $coordinates");
    //   _clearAllCircles(); // Clear existing circles
    //   // Remove existing route layer and source if they exist
    //     await _removeExistingRoute();
    //   startCoordinate = coordinates;
    //   endCoordinate = null;
    //   _addCircleWithText(
    //     coordinates,
    //     circleColor: "#00FF00", // Green circle for start
    //     text: "A",
    //   );
    // } else if (startCoordinate != null && endCoordinate == null) {
    //   // Case: Start is set, set endCoordinate
    //   print("set endCoordinate: $coordinates and start generating route");
    //   endCoordinate = coordinates;
    //   _addCircleWithText(
    //     coordinates,
    //     circleColor: "#0000FF", // Blue circle for end
    //     text: "B",
    //   );
    //   _generateRoute(startCoordinate!, endCoordinate!);
    //   _generateSkiPlannerUrl(selectedResortKey, startCoordinate, endCoordinate, stopovers);
    // } else {
    //   // Case: Neither is set, set startCoordinate
    //   print("set startCoordinate: $coordinates");
    //   startCoordinate = coordinates;
    //   _addCircleWithText(
    //     coordinates,
    //     circleColor: "#00FF00", // Green circle for start
    //     text: "A",
    //   );
    // }
  }

  void _addCircleWithText(
    LatLng coordinates, {
    required String circleColor,
    required String text,
    String textColor = "#FFFFFF", // Default text color is white
  }) {
    if (mapController == null) return;

    // Initialize source if not exists
    if (!_circleTextSourceExists) {
      _initializeCircleTextSource();
    }

    // Define new feature for the circle and text
    Map<String, dynamic> newFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [coordinates.longitude, coordinates.latitude],
      },
      "properties": {
        "color": circleColor, // Circle color
        "text": text, // Text label
        "textColor": textColor, // Text color
      },
    };

    // Update the GeoJSON source with the new feature
    _circleTextFeatures.add(newFeature);
    mapController?.setGeoJsonSource(
      'circle-text-source',
      {"type": "FeatureCollection", "features": _circleTextFeatures},
    );
  }

  /// 添加当前位置标记，包含朝向箭头和呼吸动画
  Future<void> _addCurrentLocation(LatLng coordinates, double? heading) async {
    if (mapController == null) return;

    // 先移除旧的位置标记
    await _removeCurrentLocationMarkers();

    // 添加呼吸动画圆圈（外圈，半透明）
    _myLocationPulseCircle = await mapController!.addCircle(
      CircleOptions(
        geometry: coordinates,
        circleRadius: 20,
        circleColor: Colors.lightBlue.toHexStringRGB(),
        circleOpacity: 0.3,
        circleStrokeWidth: 0,
      ),
    );

    // 添加位置圆点（内圈）
    _myLocationCircle = await mapController!.addCircle(
      CircleOptions(
        geometry: coordinates,
        circleRadius: 8,
        circleColor: Colors.lightBlue.toHexStringRGB(),
        circleOpacity: 0.9,
        circleStrokeColor:
            const Color.fromARGB(255, 255, 255, 255).toHexStringRGB(),
        circleStrokeWidth: 3,
        circleBlur: 0.1,
      ),
    );

    // 启动呼吸动画
    _startPulseAnimation(coordinates);

    // 确保朝向图标已添加
    if (!_myLocationIconAdded) {
      await _addMyLocationDirectionIcon();
      _myLocationIconAdded = true;
    }

    // 显示朝向读数（调试用）
    final headingValue = heading ?? -1;
    final headingText =
        headingValue >= 0 ? '${headingValue.toStringAsFixed(0)}°' : 'N/A';

    // 如果有有效的朝向数据，添加朝向箭头
    if (heading != null && heading >= 0) {
      _myLocationDirectionSymbol = await mapController!.addSymbol(
        SymbolOptions(
          geometry: coordinates,
          iconImage: 'my-location-direction',
          iconSize: 0.6,
          iconRotate: heading,
          iconAnchor: 'center',
        ),
      );
    }

    // 添加朝向读数文本（显示在位置下方）
    _myLocationHeadingText = await mapController!.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        textField: '朝向: $headingText',
        textSize: 12,
        textColor: '#000000',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.5,
        textOffset: const Offset(0, 2.5), // 向下偏移
        textAnchor: 'top',
      ),
    );
  }

  /// 启动呼吸动画
  void _startPulseAnimation(LatLng coordinates) {
    _stopPulseAnimation();
    _pulseRadius = 12.0;
    _pulseExpanding = true;

    _locationPulseTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) async {
        if (mapController == null || _myLocationPulseCircle == null) {
          _stopPulseAnimation();
          return;
        }

        // 更新半径
        if (_pulseExpanding) {
          _pulseRadius += 0.8;
          if (_pulseRadius >= 30) {
            _pulseExpanding = false;
          }
        } else {
          _pulseRadius -= 0.8;
          if (_pulseRadius <= 12) {
            _pulseExpanding = true;
          }
        }

        // 计算透明度（随着扩大而变淡）
        final opacity = 0.4 - ((_pulseRadius - 12) / 18) * 0.3;

        try {
          await mapController!.updateCircle(
            _myLocationPulseCircle!,
            CircleOptions(
              circleRadius: _pulseRadius,
              circleOpacity: opacity.clamp(0.1, 0.4),
            ),
          );
        } catch (e) {
          // 圆圈可能已被移除
          _stopPulseAnimation();
        }
      },
    );
  }

  /// 停止呼吸动画
  void _stopPulseAnimation() {
    _locationPulseTimer?.cancel();
    _locationPulseTimer = null;
  }

  /// 移除当前位置标记
  Future<void> _removeCurrentLocationMarkers() async {
    if (mapController == null) return;

    // 停止呼吸动画
    _stopPulseAnimation();

    // 移除呼吸圆圈
    if (_myLocationPulseCircle != null) {
      try {
        await mapController!.removeCircle(_myLocationPulseCircle!);
      } catch (e) {
        print('Error removing pulse circle: $e');
      }
      _myLocationPulseCircle = null;
    }

    // 移除位置圆点
    if (_myLocationCircle != null) {
      try {
        await mapController!.removeCircle(_myLocationCircle!);
      } catch (e) {
        print('Error removing location circle: $e');
      }
      _myLocationCircle = null;
    }

    // 移除朝向箭头
    if (_myLocationDirectionSymbol != null) {
      try {
        await mapController!.removeSymbol(_myLocationDirectionSymbol!);
      } catch (e) {
        print('Error removing direction symbol: $e');
      }
      _myLocationDirectionSymbol = null;
    }

    // 移除朝向文本
    if (_myLocationHeadingText != null) {
      try {
        await mapController!.removeSymbol(_myLocationHeadingText!);
      } catch (e) {
        print('Error removing heading text: $e');
      }
      _myLocationHeadingText = null;
    }
  }

  /// 添加朝向图标到地图
  Future<void> _addMyLocationDirectionIcon() async {
    if (mapController == null) return;

    // 创建一个朝向箭头图标（扇形/三角形）
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 80.0;
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // 绘制扇形（朝向指示器）
    final path = Path();
    final centerX = size / 2;
    final centerY = size / 2;
    final radius = size / 2 - 4;

    // 绘制一个向上的三角形箭头
    path.moveTo(centerX, 4); // 顶点（向上）
    path.lineTo(centerX - radius * 0.5, centerY + radius * 0.3);
    path.lineTo(centerX, centerY);
    path.lineTo(centerX + radius * 0.5, centerY + radius * 0.3);
    path.close();

    canvas.drawPath(path, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final bytes = byteData.buffer.asUint8List();
      await mapController!.addImage('my-location-direction', bytes);
    }
  }

  void _clearAllCirclesWithText() {
    if (mapController == null) return;

    // Remove the GeoJSON source if it exists
    mapController?.removeSource('circle-text-source');

    // Remove the layer that displays the circles & text
    mapController?.removeLayer('circle-text-layer');
    mapController?.removeLayer('circle-layer');
    _circleTextFeatures.clear();
    _circleTextSourceExists = false;

    print("Cleared all circles with text.");
  }

  Future<void> _launchUrl(String _url) async {
    if (!await launchUrl(Uri.parse(_url))) {
      throw Exception('Could not launch $_url');
    }
  }

  void _locateCurrentPosition() async {
    isUiOpen.flag = true;
    try {
      final location = await _locationService.getCurrentLocation();
      LatLng currentLocation =
          LatLng(location['latitude'], location['longitude']);
      final heading = location['heading'] as double?;
      print("current location: $currentLocation, heading: $heading");
      setState(() {
        resortCoordinate = currentLocation;
      });

      // Animate the map to the current location
      mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(currentLocation, 14));
      // Draw the blue icon on the map with heading
      await _addCurrentLocation(currentLocation, heading);
    } catch (error) {
      print('Error: $error');
    }
  }

  /// 更新团队成员在地图上的标记
  Future<void> _updateTeamMemberMarkers() async {
    if (mapController == null) return;

    // 清除旧标记
    for (final symbol in _teamMemberSymbols) {
      await mapController!.removeSymbol(symbol);
    }
    _teamMemberSymbols.clear();
    _memberSymbolToDeviceId.clear();

    // 获取成员位置
    final memberLocations = _teamService.getMemberLocations();

    // 添加新标记
    for (final member in memberLocations) {
      // 为每个成员创建唯一的图标
      final iconName =
          'team-member-${member.colorIndex}-${member.isLeader ? 1 : 0}';

      // 如果图标还没添加过，先添加
      if (!_addedMemberIconImages.contains(iconName)) {
        final iconBytes = await GeoJsonHelper.createTeamMemberMarker(
          color: Color(member.color),
          isLeader: member.isLeader,
          size: 56,
        );
        await mapController!.addImage(iconName, iconBytes);
        _addedMemberIconImages.add(iconName);
      }

      // 获取颜色的十六进制值用于文字
      final colorHex =
          '#${member.color.toRadixString(16).substring(2).toUpperCase()}';

      final symbol = await mapController!.addSymbol(
        SymbolOptions(
          geometry: member.location,
          iconImage: iconName,
          iconSize: 1.0,
          iconAnchor: 'center',
          textField: member.nickname,
          textOffset: const Offset(0, 2.0),
          textSize: 13,
          textColor: colorHex,
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2,
          textAnchor: 'top',
        ),
      );
      _teamMemberSymbols.add(symbol);
      _memberSymbolToDeviceId[symbol.id] = member.deviceId;
    }

    if (mounted) setState(() {});
  }

  /// 显示团队成员信息弹窗
  void _showTeamMemberInfoDialog(MemberLocation member) {
    isUiOpen.flag = true;

    // 格式化更新时间
    String lastUpdateStr = '未知';
    if (member.lastUpdate != null) {
      final now = DateTime.now();
      final diff = now.difference(member.lastUpdate!);
      if (diff.inSeconds < 60) {
        lastUpdateStr = '${diff.inSeconds}秒前';
      } else if (diff.inMinutes < 60) {
        lastUpdateStr = '${diff.inMinutes}分钟前';
      } else {
        lastUpdateStr = '${diff.inHours}小时前';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(member.color),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    member.isLeader ? Icons.star : Icons.downhill_skiing,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nickname,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (member.isLeader)
                      const Text(
                        '队长',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.location_on, '位置',
                  '${member.location.latitude.toStringAsFixed(6)}, ${member.location.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, '更新时间', lastUpdateStr),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                // 飞到成员位置
                mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(member.location, 16),
                );
              },
              child: const Text('定位'),
            ),
            // 不显示"导航到TA"按钮如果是自己
            if (!member.isMe)
              ElevatedButton.icon(
                onPressed: () async {
                  isUiOpen.flag = true;
                  Navigator.pop(context);
                  await _startRouteToMember(member);
                },
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('导航到TA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(member.color),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 开始导航到成员位置（使用路线规划面板）
  Future<void> _startRouteToMember(MemberLocation member) async {
    isUiOpen.flag = true;

    try {
      // 获取当前位置作为起点
      final location = await _locationService.getCurrentLocation();
      final currentLocation =
          LatLng(location['latitude'], location['longitude']);

      // 清除之前的路线
      await _removeExistingRoute();
      _clearAllCirclesWithText();

      // 设置路线规划数据
      setState(() {
        _routePlanningData.reset();
        _routePlanningData.setOrigin(RoutePoint(
          id: 'origin',
          name: '我的位置',
          coordinates: currentLocation,
          type: RoutePointType.origin,
        ));
        _routePlanningData.setDestination(RoutePoint(
          id: 'destination',
          name: member.nickname,
          coordinates: member.location,
          type: RoutePointType.destination,
        ));
        _showRoutePlanningPanel = true;
      });

      // 更新标记
      _updateRoutePlanningMarkers();

      // 自动算路
      _autoGenerateRouteIfReady();

      // 显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在规划到 ${member.nickname} 的路线...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error starting route to member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法获取当前位置，请确保已开启位置权限'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    isUiOpen.flag = false;
  }

  /// 处理成员标记点击
  void _onTeamMemberSymbolTapped(Symbol symbol) {
    isUiOpen.flag = true;

    final deviceId = _memberSymbolToDeviceId[symbol.id];
    if (deviceId == null) return;

    final member = _teamService.getMemberLocationByDeviceId(deviceId);
    if (member == null) return;

    _showTeamMemberInfoDialog(member);
  }

  void _showSharePopup() {
    isUiOpen.flag = true;
    final String generatedUrl = _generateSkiPlannerUrl(
        selectedResortKey, startCoordinate, endCoordinate, stopovers);
    WebTitleHelper.updateTitle(
        "Share SnowNavi - ${GlobalConstants.defaultTitle}");
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
                  isUiOpen.flag = true;
                  WebTitleHelper.updateTitle(
                      "Thanks for sharing SnowNavi - ${GlobalConstants.defaultTitle}");
                  html.window.navigator.clipboard?.writeText(generatedUrl);
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("URL copied to clipboard!")),
                  );
                  WebTitleHelper.resetTitle();
                },
                icon: Icon(Icons.copy),
                label: Text("Copy URL"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                isUiOpen.flag = true;
                Navigator.pop(context);
                WebTitleHelper.resetTitle();
              },
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
      final RenderBox? box =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final Offset position =
            box.localToGlobal(Offset.zero); // Top-left position
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
    _removeExistingRoute(); // Clears the drawn route from the map
    _removeStopOvers();
    _clearAllCirclesWithText();
    print("Route panel closed, map layers restored.");
  }

  Future<void> _pickPhoto() async {
    isUiOpen.flag = true;
    WebTitleHelper.updateTitle(
        "Using photo to plan your ski trip - ${GlobalConstants.defaultTitle}");

    // Pick image from web
    Uint8List? imageBytes = await ImagePickerWeb.getImageAsBytes();

    if (imageBytes == null) return; // User canceled

    _photoBytes = imageBytes;

    // Extract GPS metadata
    LatLng? gpsCoordinates = await _extractGpsCoordinates(imageBytes);
    if (gpsCoordinates != null) {
      print(
          "Extracted GPS: ${gpsCoordinates.latitude}, ${gpsCoordinates.longitude}");
      WebTitleHelper.updateTitle(
          "Find location from photo - ${GlobalConstants.defaultTitle}");
      _photoLocation = gpsCoordinates;
      _onMapClick(Point(0, 0), _photoLocation!);
    } else {
      print("No GPS data found in image.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Unable to find the location, please try another photo.")),
        );
      }
      WebTitleHelper.updateTitle(
          "No location found from photo - ${GlobalConstants.defaultTitle}");
      WebTitleHelper.resetTitle();
    }

    // Update UI
    setState(() {});
  }

  /// 路线规划面板的图片选择
  Future<void> _pickPhotoForRoutePlanning(RoutePointType type) async {
    isUiOpen.flag = true;
    _pendingPhotoPointType = type;

    WebTitleHelper.updateTitle(
        "Using photo to plan your ski trip - ${GlobalConstants.defaultTitle}");

    // Pick image from web
    Uint8List? imageBytes = await ImagePickerWeb.getImageAsBytes();

    if (imageBytes == null) {
      _pendingPhotoPointType = null;
      return; // User canceled
    }

    // Extract GPS metadata
    LatLng? gpsCoordinates = await _extractGpsCoordinates(imageBytes);
    if (gpsCoordinates != null) {
      print(
          "Extracted GPS: ${gpsCoordinates.latitude}, ${gpsCoordinates.longitude}");
      WebTitleHelper.updateTitle(
          "Find location from photo - ${GlobalConstants.defaultTitle}");

      // 使用坐标设置路线规划点位
      final name =
          '图片位置 (${gpsCoordinates.latitude.toStringAsFixed(4)}, ${gpsCoordinates.longitude.toStringAsFixed(4)})';
      _handleRoutePlanningPointSelected(gpsCoordinates, name, type);

      // 移动地图到该位置
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(gpsCoordinates, 16),
      );
    } else {
      print("No GPS data found in image.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("无法从图片中读取位置信息，请尝试其他图片")),
        );
      }
    }

    _pendingPhotoPointType = null;
    WebTitleHelper.resetTitle();
  }

  /// 使用当前位置设置路线规划点位
  Future<void> _useCurrentLocationForRoutePlanning(RoutePointType type) async {
    isUiOpen.flag = true;

    try {
      final location = await _locationService.getCurrentLocation();
      final currentLatLng = LatLng(location['latitude'], location['longitude']);
      final name = '我的位置';

      _handleRoutePlanningPointSelected(currentLatLng, name, type);

      // 移动地图到当前位置
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng, 16),
      );
    } catch (e) {
      print('Failed to get current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("无法获取当前位置，请检查定位权限")),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoLocation = null;
    });
  }

  Future<LatLng?> _extractGpsCoordinates(Uint8List imageBytes) async {
    try {
      final Map<String, IfdTag> data = await readExifFromBytes(imageBytes);

      // Debugging: Print all EXIF data
      print("EXIF Data: $data");

      if (data.containsKey("GPS GPSLatitude") &&
          data.containsKey("GPS GPSLongitude")) {
        List<dynamic> latitudeValues = data["GPS GPSLatitude"]!.values.toList();
        List<dynamic> longitudeValues =
            data["GPS GPSLongitude"]!.values.toList();

        String? latRef = data["GPS GPSLatitudeRef"]?.printable;
        String? lngRef = data["GPS GPSLongitudeRef"]?.printable;

        print("Convert GPS lat: $latitudeValues, $latRef");
        double lat = _convertExifCoordinates(latitudeValues, latRef);
        print("Convert GPS lng: $longitudeValues, $lngRef");
        double lng = _convertExifCoordinates(longitudeValues, lngRef);

        print("Converted GPS: $lat, $lng");

        return LatLng(lat, lng);
      } else {
        print("No GPS metadata found in EXIF.");
      }
    } catch (e) {
      print("Error extracting GPS data: $e");
    }
    return null;
  }

  double _convertExifCoordinates(dynamic exifData, String? ref) {
    print(
        "start GPS Conversion with EXIF Data Type: ${exifData.runtimeType}, Value: $exifData");

    if (exifData is List) {
      // Handle EXIF GPS coordinates stored as a list of Ratios
      if (exifData.length < 3) return 0.0; // Ensure valid GPS format

      double degrees = _parseExifValue(exifData[0]); // Degrees
      double minutes = _parseExifValue(exifData[1]) / 60; // Minutes
      double seconds = _parseExifValue(exifData[2]) / 3600; // Seconds

      double decimal = degrees + minutes + seconds;

      // Convert to negative if South (S) or West (W)
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return decimal;
    }
    return 0.0;
  }

  /// **Helper method to convert EXIF GPS values to double**
  double _parseExifValue(dynamic value) {
    if (value is int || value is double) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else if (value is Ratio) {
      // Convert Ratio object to double
      return value.numerator / value.denominator;
    } else if (value is List && value.length == 2) {
      // Handle rational numbers in EXIF metadata (e.g., [1599, 50] -> 1599/50)
      return value[0] / value[1];
    }
    return 0.0;
  }

  /// **Full-Screen Loading Indicator**
  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            "Loading Map...",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _checkIfInsideChildWidget,
      child: Scaffold(
        body: Stack(
          children: [
            // Show loading screen until the map is fully loaded
            if (_isLoading) _buildLoadingScreen(),

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
              styleString:
                  'mapbox://styles/okboy2008/clx1zai3s01ck01rb5zsv600u', // Your custom Mapbox style
              compassEnabled: true, // Disable the compass button
              compassViewPosition: CompassViewPosition.BottomRight,
            ),
            // 移动端焦点标记和选择按钮
            if (_isMobile) ...[
              // 地图中心焦点标记（十字准星）
              Center(
                child: IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 2,
                        height: 20,
                        color: Colors.red.withOpacity(0.8),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 2,
                            color: Colors.red.withOpacity(0.8),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red, width: 2),
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 2,
                            color: Colors.red.withOpacity(0.8),
                          ),
                        ],
                      ),
                      Container(
                        width: 2,
                        height: 20,
                        color: Colors.red.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ),
              // Select 按钮
              Positioned(
                bottom: MediaQuery.of(context).size.height / 2 - 80,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _onSelectCenterPoint,
                    icon: Icon(Icons.touch_app, size: 18),
                    label: Text('Select'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
            // Floating Route Panel (Between Search Box & Filter Button)
            // if (route != null)
            //   FloatingRouteInstructionPanel(
            //     key: _childWidgetKeys[0],
            //     route: route!,
            //     onClose: _handleRouteClose,
            //     panelWidth: GlobalConstants.searchboxWidth,
            //     timerFlag: isUiOpen,
            //     mapController: mapController!,
            //   ),
            // Attribution
            Positioned(
              bottom: 5,
              left: 100,
              child: GestureDetector(
                onTap: () {
                  _launchUrl(
                      'https://www.xiaohongshu.com/user/profile/5ffeddbb000000000100388d');
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255)
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'Follow me on 小红书 @了不起的okboy',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 209, 6, 6),
                      fontSize: 12,
                      decoration:
                          TextDecoration.none, // Add underline for link effect
                    ),
                  ),
                ),
              ),
            ),
            // 搜索框和图片选择按钮（路线规划面板显示时隐藏）
            if (!_showRoutePlanningPanel)
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
                        SizedBox(width: 5),

                        // Open Photo Button
                        FloatingActionButton(
                          backgroundColor: Colors.white.withOpacity(
                              GlobalConstants.floatingbuttonopacity),
                          mini: true,
                          heroTag: "openPhotoButton",
                          onPressed: _pickPhoto,
                          tooltip: 'Open Photo',
                          child: Icon(Icons.photo_library, color: Colors.black),
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
                                style: TextStyle(
                                    height:
                                        1.5), // Adjust line spacing for readability
                              ),
                              isThreeLine:
                                  true, // Allows multiple lines in the subtitle
                              onTap: () {
                                LatLng coord = LatLng(poi['lat'], poi['lng']);
                                _onMapClick(Point(0, 0), coord);
                                isUiOpen.flag = true;
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
                  backgroundColor: Colors.white.withOpacity(
                      GlobalConstants.floatingbuttonopacity), // 按钮颜色
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
                  backgroundColor: Colors.white
                      .withOpacity(GlobalConstants.floatingbuttonopacity),
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
                  backgroundColor: Colors.white
                      .withOpacity(GlobalConstants.floatingbuttonopacity),
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
                  backgroundColor: Colors.white
                      .withOpacity(GlobalConstants.floatingbuttonopacity),
                  onPressed: _showSharePopup, // Show popup with URL
                  tooltip: 'Share SnowNavi',
                  child: Icon(Icons.share),
                ),
              ),
            ),
            // Team button
            Positioned(
              top: 168,
              right: 20,
              child: Transform.scale(
                scale: GlobalConstants.floatingActionButtonScale,
                child: FloatingActionButton(
                  backgroundColor: _teamService.currentTeam != null
                      ? Colors.deepOrange
                          .withOpacity(GlobalConstants.floatingbuttonopacity)
                      : Colors.white
                          .withOpacity(GlobalConstants.floatingbuttonopacity),
                  onPressed: () {
                    isUiOpen.flag = true;
                    setState(() => _showTeamPanel = !_showTeamPanel);
                  },
                  tooltip: '组队滑雪',
                  child: Icon(
                    Icons.group,
                    color: _teamService.currentTeam != null
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ),
            // Team Panel
            if (_showTeamPanel)
              Positioned(
                top: 70,
                right: 70,
                child: TeamPanel(
                  resortKey: selectedResortKey,
                  timerFlag: isUiOpen,
                  onClose: () => setState(() => _showTeamPanel = false),
                  onMemberLocationsUpdate: (locations) =>
                      _updateTeamMemberMarkers(),
                  onMemberTapped: (member) {
                    isUiOpen.flag = true;
                    // 先将相机移动到成员位置
                    mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(member.location, 16),
                    );
                    // 然后显示成员信息弹窗
                    _showTeamMemberInfoDialog(member);
                  },
                  onShowMeetingPointsLayerChanged: (show) {
                    setState(() {
                      _showMeetingPointsLayer = show;
                    });
                    _updateMeetingPointsLayer();
                  },
                  onTeamJoined: () {
                    // 团队加入/创建成功后初始化集合点服务
                    _initializeMeetingPointService();
                  },
                ),
              ),
            // Route Planning Panel
            if (_showRoutePlanningPanel)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTapDown: (_) => isUiOpen.flag = true,
                  child: RoutePlanningPanel(
                    data: _routePlanningData,
                    route: route,
                    resortCoordinate: resortCoordinate,
                    mapController: mapController,
                    timerFlag: isUiOpen,
                    onClose: () {
                      isUiOpen.flag = true;
                      _exitRoutePlanning();
                    },
                    onPointSelected: (coordinates, name, type) {
                      isUiOpen.flag = true;
                      _handleRoutePlanningPointSelected(
                          coordinates, name, type);
                    },
                    onRemovePoint: (index) {
                      isUiOpen.flag = true;
                      _handleRoutePlanningRemovePoint(index);
                    },
                    onReorderPoints: (oldIndex, newIndex) {
                      isUiOpen.flag = true;
                      _handleRoutePlanningReorderPoints(oldIndex, newIndex);
                    },
                    onPickPhoto: (type) {
                      isUiOpen.flag = true;
                      _pickPhotoForRoutePlanning(type);
                    },
                    onUseCurrentLocation: (type) {
                      isUiOpen.flag = true;
                      _useCurrentLocationForRoutePlanning(type);
                    },
                    onEditingTypeChanged: (type) {
                      setState(() {
                        _currentEditingType = type;
                      });
                    },
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
                          fontFamily:
                              'NotoEmoji', // Specify Noto Emoji font family
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
