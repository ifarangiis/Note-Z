import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

class Note {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime creationDate;
  final DateTime? deadline;
  final Color color;

  Note({
    String? id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    DateTime? creationDate,
    this.deadline,
    Color? color,
  }) : 
    id = id ?? const Uuid().v4(),
    creationDate = creationDate ?? DateTime.now(),
    color = color ?? _getRandomColor();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'creationDate': creationDate.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'color': color.value,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      creationDate: DateTime.parse(json['creationDate']),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      color: json['color'] != null ? Color(json['color']) : null,
    );
  }
  
  static Color _getRandomColor() {
    final colors = [
      Colors.deepPurple,
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.amber,
      Colors.orange,
      Colors.pink,
    ];
    
    return colors[DateTime.now().microsecond % colors.length];
  }
  
  // Calculate urgency level based on deadline
  // 0 = no deadline
  // 1 = more than 3 days
  // 2 = 1-3 days
  // 3 = less than 1 day
  // 4 = past deadline
  int get urgencyLevel {
    if (deadline == null) return 0;
    
    final now = DateTime.now();
    final daysRemaining = deadline!.difference(now).inDays;
    
    if (deadline!.isBefore(now)) return 4;
    if (daysRemaining < 1) return 3;
    if (daysRemaining < 3) return 2;
    return 1;
  }
  
  // Get color based on urgency level
  Color get urgencyColor {
    switch (urgencyLevel) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.deepOrange;
      case 4:
        return Colors.red;
      default:
        return color; // Use the note's assigned color if no deadline
    }
  }
} 