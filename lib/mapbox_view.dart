import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class GeneratorPage extends StatefulWidget {
  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  MapboxMapController? mapController;
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

    // Separate piste:type features
    final pisteFeatures = {
      "type": "FeatureCollection",
      "features": (parsedGeoJson['features'] as List).where((feature) {
        return feature['properties'].containsKey('piste:type') &&
        !feature['properties'].containsKey('area'); // Filter out areas;
      }).toList(),
    };

    // Add the aerialway source
    mapController?.addSource(
      'aerialway-source',
      GeojsonSourceProperties(data: aerialwayFeatures),
    );

    // Add the piste source
    mapController?.addSource(
      'piste-source',
      GeojsonSourceProperties(data: pisteFeatures),
    );

    // Add black polyline for aerialway
    mapController?.addLineLayer(
      'aerialway-source',
      'aerialway-layer',
      LineLayerProperties(
        lineColor: '#000000',
        lineWidth: 3.0,
      ),
    );

    // Add blue polyline for piste:type
    mapController?.addLineLayer(
      'piste-source',
      'piste-layer',
      LineLayerProperties(
        lineColor: '#0000ff',
        lineWidth: 3.0,
      ),
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
    // _addPistesLayer();
    _loadGeoJsonFromAssets();
  }

  // Callback when the Mapbox map is created
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
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
