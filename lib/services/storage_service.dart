import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class StorageService {
  static const String _notesKey = 'notes';
  static const String _lastPurgeKey = 'last_purge_date';

  // Save the list of notes to local storage
  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = notes.map((note) => jsonEncode(note.toJson())).toList();
    await prefs.setStringList(_notesKey, notesJson);
  }

  // Load notes from local storage
  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await checkAndPurgeNotes();
    
    final notesJson = prefs.getStringList(_notesKey) ?? [];
    return notesJson
        .map((noteJson) => Note.fromJson(jsonDecode(noteJson)))
        .toList();
  }

  // Add a new note
  Future<void> addNote(Note note) async {
    final notes = await loadNotes();
    notes.add(note);
    await saveNotes(notes);
  }

  // Delete a note by id
  Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((note) => note.id == id);
    await saveNotes(notes);
  }

  // Update a note
  Future<void> updateNote(Note updatedNote) async {
    final notes = await loadNotes();
    final index = notes.indexWhere((note) => note.id == updatedNote.id);
    if (index != -1) {
      notes[index] = updatedNote;
      await saveNotes(notes);
    }
  }

  // Check if notes need to be purged (every Sunday)
  Future<void> checkAndPurgeNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastPurgeDate = prefs.getString(_lastPurgeKey) != null
        ? DateTime.parse(prefs.getString(_lastPurgeKey)!)
        : null;

    // If today is Sunday (weekday == 7 in Dart DateTime) or if we've never purged before
    if (now.weekday == 7 && 
        (lastPurgeDate == null || 
         !_isSameDay(lastPurgeDate, now))) {
      await purgeAllNotes();
      await prefs.setString(_lastPurgeKey, now.toIso8601String());
    }
  }

  // Purge all notes
  Future<void> purgeAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notesKey, []);
  }

  // Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
} 