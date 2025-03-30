import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/map_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (Mapbox token)
  await dotenv.load(fileName: '.env');
  
  // Set Mapbox access token globally
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_TOKEN'] ?? '');
  
  runApp(const NoteZApp());
}

class NoteZApp extends StatelessWidget {
  const NoteZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note-Z',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
