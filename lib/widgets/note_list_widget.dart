import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/note.dart';
import '../utils/date_util.dart';
import '../utils/color_util.dart';

class NoteListWidget extends StatefulWidget {
  final List<Note> notes;
  final Function(Note) onNoteTap;
  
  const NoteListWidget({
    super.key,
    required this.notes,
    required this.onNoteTap,
  });

  @override
  State<NoteListWidget> createState() => _NoteListWidgetState();
}

class _NoteListWidgetState extends State<NoteListWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _weekdayNames = ['All', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Sort notes by deadline
    final sortedNotes = List<Note>.from(widget.notes);
    sortedNotes.sort((a, b) {
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });
    
    // Group notes by weekday
    final Map<int, List<Note>> notesByWeekday = {};
    
    // Initialize all weekdays with empty lists (1-7)
    for (int i = 1; i <= 7; i++) {
      notesByWeekday[i] = [];
    }
    
    // Group notes by weekday
    for (final note in sortedNotes) {
      if (note.deadline != null) {
        notesByWeekday[note.deadline!.weekday]!.add(note);
      } else {
        // Add notes without deadline to all weekdays
        for (int i = 1; i <= 7; i++) {
          notesByWeekday[i]!.add(note);
        }
      }
    }
    
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom tab header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Filter by Day',
              style: TextStyle(
                color: ColorUtil.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          
          // Tab bar for filtering by weekday
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(8, (index) {
                final isSelected = _tabController.index == index;
                
                if (index == 0) {
                  // "All" tab
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabController.animateTo(index);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: isSelected 
                          ? const LinearGradient(
                              colors: ColorUtil.primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                        color: isSelected ? null : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: ColorUtil.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                      ),
                      child: Center(
                        child: Text(
                          'All',
                          style: TextStyle(
                            color: isSelected ? Colors.white : ColorUtil.textMuted,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                
                // Weekday tabs
                final weekday = index;
                final hasNotes = notesByWeekday[weekday]!.isNotEmpty;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tabController.animateTo(index);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected 
                        ? const LinearGradient(
                            colors: ColorUtil.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                      color: isSelected ? null : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ColorUtil.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekdayNames[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : ColorUtil.textMuted,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        if (hasNotes) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.3)
                                  : ColorUtil.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                notesByWeekday[weekday]!.length.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : ColorUtil.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Tab view content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // "All" tab
                _buildNotesList(sortedNotes),
                // Weekday tabs
                ...List.generate(7, (index) {
                  final weekday = index + 1;
                  return _buildNotesList(notesByWeekday[weekday]!);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotesList(List<Note> notes) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/empty_notes.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  CupertinoIcons.doc_text_search,
                  size: 80,
                  color: ColorUtil.textMuted.withOpacity(0.5),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'No notes here yet',
              style: TextStyle(
                fontSize: 18,
                color: ColorUtil.textDark.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Tap on the map to add a new note ✨',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: ColorUtil.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteCard(note);
      },
    );
  }
  
  Widget _buildNoteCard(Note note) {
    // Determine card styling based on deadline
    final List<Color> cardGradient = note.deadline != null
        ? ColorUtil.getUrgencyGradient(note.urgencyLevel)
        : [note.color.withOpacity(0.8), note.color.withOpacity(0.6)];
    
    // Get emoji based on urgency
    String emoji = '📝';
    if (note.deadline != null) {
      switch (note.urgencyLevel) {
        case 1: emoji = '🟢'; break;  // Low priority
        case 2: emoji = '🟠'; break;  // Medium priority
        case 3: emoji = '⚠️'; break;  // High priority
        case 4: emoji = '🔥'; break;  // Past due
      }
    }
    
    return GestureDetector(
      onTap: () => widget.onNoteTap(note),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (note.deadline != null
                    ? ColorUtil.getUrgencyColor(note.urgencyLevel)
                    : note.color).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note header with colored accent
            Container(
              height: 12,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cardGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            
            // Note content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with deadline badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title area
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              style: TextStyle(
                                color: ColorUtil.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Location pill
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.location_fill,
                                  color: Colors.grey.shade400,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Pinned on map',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Deadline indicator or emoji
                      if (note.deadline != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: cardGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emoji,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateUtil.formatDeadline(note.deadline),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      note.description,
                      style: TextStyle(
                        color: ColorUtil.textDark.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Creation date at bottom
                  Text(
                    'Created ${DateUtil.formatDate(note.creationDate)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 