import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/note.dart';
import '../services/location_service.dart';
import '../services/mapbox_service.dart';
import '../services/storage_service.dart';
import '../utils/date_util.dart';
import '../utils/color_util.dart';
import '../widgets/cool_date_picker.dart';
import '../widgets/note_list_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;
  List<Note> _notes = [];
  PointAnnotationManager? _annotationManager;
  
  // Control map loading state
  bool _isMapInitialized = false;
  bool _isLoading = true;
  final Map<String, Uint8List> _markerImages = {};
  final bool _isBottomSheetVisible = false;
  
  // Text controllers for adding/editing note
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _bottomSheetAnimationController;
  
  // Date for deadline
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _bottomSheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _initializeApp();
    
    // Welcome animation after app loads
    Future.delayed(const Duration(milliseconds: 800), () {
      _playWelcomeAnimation();
    });
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _fabAnimationController.dispose();
    _bottomSheetAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _createMarkerImages();
    await _initializeLocation();
    await _loadNotes();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createMarkerImages() async {
    try {
      // Create marker images for different urgency levels
      _markerImages['default'] = await _createMarkerImage(ColorUtil.primary);
      _markerImages['low'] = await _createMarkerImage(ColorUtil.lowPriority);
      _markerImages['medium'] = await _createMarkerImage(ColorUtil.mediumPriority);
      _markerImages['high'] = await _createMarkerImage(ColorUtil.highPriority);
      _markerImages['past'] = await _createMarkerImage(ColorUtil.pastDue);
    } catch (e) {
      debugPrint('Error creating marker images: $e');
    }
  }
  
  Future<Uint8List> _createMarkerImage(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw gradient circle
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(48, 48),
        [
          color,
          color.withOpacity(0.7),
        ],
      );
    
    // Draw main circle
    canvas.drawCircle(const Offset(24, 24), 16, gradientPaint);
    
    // Add inner circle for better visibility
    final innerCirclePaint = Paint()..color = Colors.white.withOpacity(0.3);
    canvas.drawCircle(const Offset(24, 24), 8, innerCirclePaint);
    
    final image = await recorder.endRecording().toImage(48, 48);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('Failed to create marker image');
    }
    
    return byteData.buffer.asUint8List();
  }

  Future<void> _initializeLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Future<void> _loadNotes() async {
    final notes = await _storageService.loadNotes();
    setState(() {
      _notes = notes;
    });
  }

  // Initialize the map when the widget is rendered
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    // Set initial camera position to current location or default
    final initialCameraPosition = _currentPosition != null
        ? CameraOptions(
            center: Point(
              coordinates: Position(
                _currentPosition!.longitude,
                _currentPosition!.latitude,
              )
            ),
            zoom: 14.0,
          )
        : CameraOptions(
            center: Point(
              coordinates: Position(-74.006, 40.7128), // Default to NYC
            ),
            zoom: 14.0,
          );
    
    await mapboxMap.setCamera(initialCameraPosition);
    
    // Apply cartoon style to the map
    await MapboxService.configureMapForCartoonStyle(mapboxMap);
    
    // Create annotation manager for markers
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    
    // Display notes on the map
    _displayNotes();
    
    setState(() {
      _isMapInitialized = true;
    });
  }

  // Display all notes as markers on the map
  Future<void> _displayNotes() async {
    if (_annotationManager == null || _notes.isEmpty || _markerImages.isEmpty) return;
    
    // Clear existing annotations
    await _annotationManager!.deleteAll();
    
    // Add a marker for each note
    for (var note in _notes) {
      // Determine marker color based on deadline urgency
      String markerKey = 'default';
      if (note.deadline != null) {
        switch (note.urgencyLevel) {
          case 1:
            markerKey = 'low';
            break;
          case 2:
            markerKey = 'medium';
            break;
          case 3:
            markerKey = 'high';
            break;
          case 4:
            markerKey = 'past';
            break;
          default:
            markerKey = 'default';
        }
      }
      
      // Truncate title to 8 characters with ellipsis if needed
      String displayTitle = note.title.length > 8 
          ? '${note.title.substring(0, 8)}...' 
          : note.title;
      
      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(note.longitude, note.latitude),
        ),
        image: _markerImages[markerKey]!,
        iconSize: 1.2,
        textField: displayTitle,
        textColor: Colors.black.value,
        textSize: 12,
        textOffset: [0, 2], // Position text below the marker
        textHaloColor: Colors.white.value,
        textHaloWidth: 1,
      );
      
      await _annotationManager!.create(pointAnnotationOptions);
    }
  }

  // Handle map tap to add a new note or view an existing one
  void _onMapTap(MapContentGestureContext context) async {
    if (_mapboxMap == null) return;
    
    try {
      // Extract the map coordinates from the tap context
      final point = context.point;
      
      // Check if the tap is on an existing note marker (within a small radius)
      final tappedNote = _findNoteNearTap(point.coordinates.lat.toDouble(), point.coordinates.lng.toDouble());
      
      if (tappedNote != null) {
        // If tap is on an existing note, show its details
        _showNoteDetailsSheet(tappedNote);
      } else {
        // If tap is on an empty area, add a new note
        _titleController.clear();
        _descriptionController.clear();
        _selectedDeadline = null;
        _showAddNoteSheet(
          point.coordinates.lat.toDouble(),
          point.coordinates.lng.toDouble(),
        );
      }
    } catch (e) {
      // Handle error
      debugPrint('Error handling map tap: $e');
    }
  }
  
  // Find a note near the tap location
  Note? _findNoteNearTap(double lat, double lng) {
    // Define a small radius for tap detection (in degrees)
    const double tapRadius = 0.0005; // Approximately 50 meters
    
    for (var note in _notes) {
      // Calculate if tap is within the radius of a note marker
      if ((note.latitude - lat).abs() < tapRadius &&
          (note.longitude - lng).abs() < tapRadius) {
        return note;
      }
    }
    
    return null;
  }
  
  void _showAddNoteSheet(double latitude, double longitude) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddNoteBottomSheet(latitude, longitude),
    );
  }
  
  void _showNoteDetailsSheet(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNoteDetailsBottomSheet(note),
    );
  }
  
  void _showNotesListSheet() {
    // Start the animation when the user opens the notes list
    _fabAnimationController.forward();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotesListBottomSheet(),
    ).then((_) {
      // Reset the animation when the sheet is closed
      _fabAnimationController.reverse();
    });
  }
  
  Widget _buildAddNoteBottomSheet(double latitude, double longitude) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        // Header section
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          decoration: BoxDecoration(
                            color: ColorUtil.primary.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and close button
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'New Note',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: ColorUtil.textDark,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        'Add a note at this location',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Close button
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.xmark,
                                        color: ColorUtil.textMuted,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Reset information
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.refresh,
                                      color: Colors.grey.shade700,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Resets in ${DateUtil.daysRemainingInWeek()} days',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Form fields
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, bottom: 8),
                                    child: Text(
                                      'Title',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoTextField(
                                      controller: _titleController,
                                      placeholder: 'Enter a title',
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                      prefix: const Padding(
                                        padding: EdgeInsets.only(left: 16),
                                        child: Icon(
                                          CupertinoIcons.textformat_alt,
                                          color: ColorUtil.primary,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Description field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, bottom: 8),
                                    child: Text(
                                      'Description',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoTextField(
                                      controller: _descriptionController,
                                      placeholder: 'Add more details',
                                      maxLines: 6,
                                      minLines: 3,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                        height: 1.4,
                                      ),
                                      prefix: Padding(
                                        padding: const EdgeInsets.only(left: 16, top: 12),
                                        child: Icon(
                                          CupertinoIcons.text_alignleft,
                                          color: ColorUtil.primary,
                                          size: 18,
                                        ),
                                      ),
                                      keyboardType: TextInputType.multiline,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Deadline field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, bottom: 8),
                                    child: Text(
                                      'Deadline (Optional)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CoolDatePicker(
                                      selectedDate: _selectedDeadline,
                                      onDateSelected: (date) {
                                        if (date.year == 0) {
                                          setState(() {
                                            _selectedDeadline = null;
                                          });
                                        } else {
                                          setState(() {
                                            _selectedDeadline = date;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 36),
                              
                              // Save and Cancel buttons
                              Row(
                                children: [
                                  // Cancel button
                                  Expanded(
                                    flex: 1,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        color: Colors.red.shade400,
                                        size: 16,
                                      ),
                                    ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Save button
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: () async {
                                        // Validate input
                                        if (_titleController.text.trim().isEmpty || 
                                            _descriptionController.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please fill in all fields'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        // Create and save note
                                        final note = Note(
                                          title: _titleController.text.trim(),
                                          description: _descriptionController.text.trim(),
                                          latitude: latitude,
                                          longitude: longitude,
                                          deadline: _selectedDeadline,
                                        );
                                        
                                        await _storageService.addNote(note);
                                        await _loadNotes();
                                        await _displayNotes();
                                        
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: ColorUtil.primary,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: ColorUtil.primary.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.check_mark,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Create',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildNoteDetailsBottomSheet(Note note) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        // Header with title
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                note.urgencyColor.withOpacity(0.2),
                                note.urgencyColor.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and close button
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  // Close button
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.xmark,
                                        color: ColorUtil.textMuted,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Creation date and deadline
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Creation date chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          CupertinoIcons.calendar,
                                          color: ColorUtil.textMuted,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Created ${DateUtil.formatDate(note.creationDate)}",
                                          style: const TextStyle(
                                            color: ColorUtil.textMuted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Deadline pill if exists
                                  if (note.deadline != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: note.urgencyColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: note.urgencyColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            note.urgencyLevel >= 3 
                                                ? CupertinoIcons.alarm_fill
                                                : CupertinoIcons.clock_fill,
                                            color: note.urgencyColor,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateUtil.formatDeadline(note.deadline),
                                            style: TextStyle(
                                              color: note.urgencyColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // Priority indicator based on urgency level
                                  if (note.deadline != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: note.urgencyColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            note.urgencyLevel >= 3
                                                ? CupertinoIcons.exclamationmark_circle_fill
                                                : note.urgencyLevel == 2
                                                    ? CupertinoIcons.flag_fill
                                                    : CupertinoIcons.tag_fill,
                                            color: note.urgencyColor,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            note.urgencyLevel >= 3
                                                ? "High Priority"
                                                : note.urgencyLevel == 2
                                                    ? "Medium Priority"
                                                    : "Low Priority",
                                            style: TextStyle(
                                              color: note.urgencyColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Content sections
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description section
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtil.textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Description content card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  note.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: ColorUtil.textDark,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Location section
                              const Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtil.textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Location preview
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.map,
                                              size: 32,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${note.latitude.toStringAsFixed(4)}, ${note.longitude.toStringAsFixed(4)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: const Text(
                                            'Pinned on map',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: ColorUtil.textDark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Action buttons
                              Row(
                                children: [
                                  // Edit button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _showEditNoteSheet(note);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: ColorUtil.primary,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: ColorUtil.primary.withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.pencil,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Delete button
                                  GestureDetector(
                                    onTap: () async {
                                      final confirm = await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (context) => CupertinoAlertDialog(
                                          title: const Text('Delete Note?'),
                                          content: const Text('This action cannot be undone.'),
                                          actions: [
                                            CupertinoDialogAction(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            CupertinoDialogAction(
                                              onPressed: () => Navigator.pop(context, true),
                                              isDestructiveAction: true,
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (confirm == true) {
                                        await _storageService.deleteNote(note.id);
                                        await _loadNotes();
                                        await _displayNotes();
                                        
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.trash,
                                        color: Colors.red.shade400,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _showEditNoteSheet(Note note) {
    _titleController.text = note.title;
    _descriptionController.text = note.description;
    _selectedDeadline = note.deadline;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditNoteBottomSheet(note),
    );
  }
  
  Widget _buildEditNoteBottomSheet(Note note) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        // Header section
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          decoration: BoxDecoration(
                            color: ColorUtil.secondary.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and close button
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Edit Note',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: ColorUtil.textDark,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        'Update your note details',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Close button
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.xmark,
                                        color: ColorUtil.textMuted,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Creation info
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.calendar,
                                      color: Colors.grey.shade700,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Created on ${DateUtil.formatDate(note.creationDate)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Form fields
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, bottom: 8),
                                    child: Text(
                                      'Title',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoTextField(
                                      controller: _titleController,
                                      placeholder: 'Enter a title',
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                      prefix: const Padding(
                                        padding: EdgeInsets.only(left: 16),
                                        child: Icon(
                                          CupertinoIcons.textformat_alt,
                                          color: ColorUtil.secondary,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Description field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, bottom: 8),
                                    child: Text(
                                      'Description',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoTextField(
                                      controller: _descriptionController,
                                      placeholder: 'Add more details',
                                      maxLines: 6,
                                      minLines: 3,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                        height: 1.4,
                                      ),
                                      prefix: Padding(
                                        padding: const EdgeInsets.only(left: 16, top: 12),
                                        child: Icon(
                                          CupertinoIcons.text_alignleft,
                                          color: ColorUtil.secondary,
                                          size: 18,
                                        ),
                                      ),
                                      keyboardType: TextInputType.multiline,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Deadline field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, bottom: 8),
                                    child: Text(
                                      'Deadline (Optional)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtil.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CoolDatePicker(
                                      selectedDate: _selectedDeadline,
                                      onDateSelected: (date) {
                                        if (date.year == 0) {
                                          setState(() {
                                            _selectedDeadline = null;
                                          });
                                        } else {
                                          setState(() {
                                            _selectedDeadline = date;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 36),
                              
                              // Save and Cancel buttons
                              Row(
                                children: [
                                  // Cancel button
                                  Expanded(
                                    flex: 2,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Save button
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: () async {
                                        // Validate input
                                        if (_titleController.text.trim().isEmpty || 
                                            _descriptionController.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please fill in all fields'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        // Create updated note with same ID
                                        final updatedNote = Note(
                                          id: note.id,
                                          title: _titleController.text.trim(),
                                          description: _descriptionController.text.trim(),
                                          latitude: note.latitude,
                                          longitude: note.longitude,
                                          creationDate: note.creationDate,
                                          deadline: _selectedDeadline,
                                          color: note.color,
                                        );
                                        
                                        await _storageService.updateNote(updatedNote);
                                        await _loadNotes();
                                        await _displayNotes();
                                        
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: ColorUtil.secondary,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: ColorUtil.secondary.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.check_mark,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  // Animate to a specific note location on the map
  void _animateToNote(Note note) {
    if (_mapboxMap == null) return;
    
    final cameraOptions = CameraOptions(
      center: Point(
        coordinates: Position(
          note.longitude,
          note.latitude,
        ),
      ),
      zoom: 15.0,
    );
    
    // First close any open bottom sheets
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Then animate to the note's location
    _mapboxMap!.flyTo(
      cameraOptions,
      MapAnimationOptions(
        duration: 1000,
        startDelay: 0,
      ),
    );
    
    // Show a brief highlight effect on the marker (optional)
    Future.delayed(const Duration(milliseconds: 1200), () {
      _showNoteDetailsSheet(note);
    });
  }
  
  Widget _buildNotesListBottomSheet() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            
              // Title with custom header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: ColorUtil.primary.withOpacity(0.1),
                        child: const Icon(
                          CupertinoIcons.collections,
                          color: ColorUtil.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Notes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: ColorUtil.textDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Organize your thoughts',
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorUtil.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: ColorUtil.textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Reset notification card
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ColorUtil.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.timer,
                        color: ColorUtil.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Reset',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ColorUtil.textDark,
                            ),
                          ),
                          Text(
                            'Notes reset every Sunday',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ColorUtil.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.calendar,
                            color: ColorUtil.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${DateUtil.daysRemainingInWeek()} days',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtil.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Notes list
              Expanded(
                child: NoteListWidget(
                  notes: _notes,
                  onNoteTap: (note) {
                    _animateToNote(note);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Play a welcome animation when the app starts
  void _playWelcomeAnimation() {
    if (_mapboxMap == null || !_isMapInitialized) return;
    
    // Get current camera position
    _mapboxMap!.getCameraState().then((cameraState) {
      // First, zoom out to get a bird's eye view
      _mapboxMap!.flyTo(
        CameraOptions(
          center: cameraState.center,
          zoom: 10.0,
          pitch: 45.0,
        ),
        MapAnimationOptions(
          duration: 1200,
          startDelay: 0,
        ),
      );
      
      // Then, fly back in to the user's location or default location
      Future.delayed(const Duration(milliseconds: 1500), () {
        _mapboxMap!.flyTo(
          CameraOptions(
            center: cameraState.center,
            zoom: 14.0,
            pitch: 0.0,
          ),
          MapAnimationOptions(
            duration: 1000,
            startDelay: 0,
          ),
        );
      });
    });
  }
  
  // Refresh notes and markers - useful for updating deadline colors
  Future<void> _refreshNotes() async {
    setState(() {
      _isLoading = true;
    });
    
    await _loadNotes();
    await _displayNotes();
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ColorUtil.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ColorUtil.primary.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtil.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Note-Z',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // Show days remaining indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ColorUtil.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: ColorUtil.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtil.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.clock_fill,
                        color: Colors.black,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${DateUtil.daysRemainingInWeek()}d',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map widget
          _isLoading
              ? Container(
                  color: const Color(0xFFF7F7F7),
                  child: const Center(
                    child: CupertinoActivityIndicator(
                      color: ColorUtil.primary,
                    ),
                  ),
                )
              : MapWidget(
                  key: const ValueKey('mapWidget'),
                  styleUri: MapboxService.cartoonStyleUri,
                  cameraOptions: _currentPosition != null
                      ? CameraOptions(
                          center: Point(
                            coordinates: Position(
                              _currentPosition!.longitude,
                              _currentPosition!.latitude
                            )
                          ),
                          zoom: 14.0,
                        )
                      : CameraOptions(
                          center: Point(
                            coordinates: Position(-74.006, 40.7128)
                          ),
                          zoom: 14.0,
                        ),
                  onMapCreated: _onMapCreated,
                  onTapListener: _onMapTap,
                ),
          
          // Refresh button
          Positioned(
            top: 100,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorUtil.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtil.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.arrow_clockwise, color: Colors.black),
                    onPressed: _refreshNotes,
                    tooltip: 'Refresh notes',
                  ),
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CupertinoActivityIndicator(
                        radius: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _fabAnimationController.value * 0.5 * 3.14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorUtil.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtil.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: _showNotesListSheet,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    child: AnimatedIcon(
                      icon: AnimatedIcons.menu_close,
                      progress: _fabAnimationController,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 