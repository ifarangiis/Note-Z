import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Request location permissions
  Future<bool> requestLocationPermission() async {
    final locationStatus = await Permission.location.request();
    return locationStatus.isGranted;
  }

  // Check if location permission is granted
  Future<bool> checkLocationPermission() async {
    return await Permission.location.isGranted;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkLocationPermission();
    
    if (!hasPermission) {
      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        return null;
      }
    }
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  // Calculate distance between two points in meters
  double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Check if user is near a specific location (within the threshold in meters)
  bool isNearLocation(
    double userLat, 
    double userLon, 
    double noteLat, 
    double noteLon, 
    {double thresholdMeters = 100}
  ) {
    final distance = calculateDistance(userLat, userLon, noteLat, noteLon);
    return distance <= thresholdMeters;
  }
} 