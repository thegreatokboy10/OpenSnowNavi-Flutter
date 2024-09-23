import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class GeneratorPage extends StatefulWidget {
  @override
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  MapboxMapController? mapController;

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapboxMap(
        accessToken: 'pk.eyJ1Ijoib2tib3kyMDA4IiwiYSI6ImNsdGE1dzd6OTAxbHQyanA0aWM1MjU5c24ifQ.vbbY3gzL8nnUFctmDv9UBQ', // Replace with your Mapbox access token
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(45.009487, 6.124711), // Coordinates for les 2 alps
          zoom: 13,
        ),
        styleString: 'mapbox://styles/okboy2008/clx1zai3s01ck01rb5zsv600u',
      ),
    );
  }
}