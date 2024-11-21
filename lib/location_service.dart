import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();

  /// Request permission and get the current location
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      print("get current location now");
      // Check if location services are enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          print("Location services are disabled");
          throw Exception('Location services are disabled.');
        }
      }

      // Check and request location permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print("Location permissions are denied");
          throw Exception('Location permissions are denied.');
        }
      }

      // Get the current location
      final locationData = await _location.getLocation();
      return {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
      };
    } catch (e) {
      print("error obtaining location: $e");
      throw Exception('Error obtaining location: $e');
    }
  }
}
