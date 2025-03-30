import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxService {
  static String get mapboxAccessToken {
    return dotenv.env['MAPBOX_TOKEN'] ?? '';
  }

  // Get a cartoon-style map style URI
  static String get cartoonStyleUri {
    // Use Mapbox Streets with custom parameters for cartoon-like appearance
    // You could also create a custom style in Mapbox Studio and use its style URL
    return 'mapbox://styles/mapbox/streets-v12';
  }

  // Configure the map with cartoon-style settings
  static Future<void> configureMapForCartoonStyle(MapboxMap mapboxMap) async {
    await mapboxMap.style.setStyleURI(cartoonStyleUri);
    
    // Since we can't directly modify style layers as in earlier example due to API limitations,
    // we'll use a simpler approach to make the map more cartoon-like
    
    // Set the pitch and bearing for a more dynamic view
    await mapboxMap.setCamera(
      CameraOptions(
        pitch: 45.0,
        bearing: 15.0,
        zoom: 15.0
      )
    );
  }

  // Create a styled marker for the map
  static Future<PointAnnotation> createNoteMarker(
    PointAnnotationManager annotationManager, 
    Point point,
    {String? id}
  ) async {
    // Create a marker at the specified point
    var options = PointAnnotationOptions(
      geometry: point,
      iconSize: 5, // Make it slightly larger
      iconOffset: [0, 0],
      iconImage: "marker", // This should be a registered image resource
      textField: "Note",
      textOffset: [0, 1.5],
      textSize: 12.0,
    );
    
    return await annotationManager.create(options);
  }
} 