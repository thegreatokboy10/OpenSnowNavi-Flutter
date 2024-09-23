import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class GeneratorPage extends StatefulWidget {
  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  MapboxMapController? mapController;

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
    _addPistesLayer();
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
