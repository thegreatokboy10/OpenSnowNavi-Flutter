import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();

  /// Request permission and get the current location
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      print("get current location now");

      // Check and request location permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print("Location permissions are denied");
          throw Exception('Location permissions are denied.');
        } else {
          print("Location permissions are granted");
        }
      }

      // Get the current location
      final locationData = await _location.getLocation();

      print("locationData: $locationData");

      return {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'heading': locationData.heading, // 朝向角度 (0-360度，0为正北)
      };
    } catch (e) {
      print("error obtaining location: $e");
      throw Exception('Error obtaining location: $e');
    }
  }

  void enableBackgroundMode(bool enable) {
    _location.enableBackgroundMode(enable: enable);
  }
}
