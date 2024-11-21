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
      print("get location demo...");
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
