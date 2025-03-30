import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/color_util.dart';
import '../utils/date_util.dart';

class CoolDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final String label;

  const CoolDatePicker({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.label = 'Set Deadline',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDatePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selectedDate != null
                ? ColorUtil.getUrgencyGradient(_getUrgencyLevel(selectedDate!))
                : [Colors.grey.shade100, Colors.grey.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              selectedDate != null
                  ? CupertinoIcons.calendar_badge_minus
                  : CupertinoIcons.calendar_badge_plus,
              color: selectedDate != null
                  ? Colors.white
                  : ColorUtil.textMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selectedDate != null
                          ? Colors.white.withOpacity(0.8)
                          : ColorUtil.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedDate != null
                        ? DateUtil.formatDateTime(selectedDate!)
                        : 'Tap to set',
                    style: TextStyle(
                      color: selectedDate != null
                          ? Colors.white
                          : ColorUtil.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: () {
                  // Clear the date
                  onDateSelected(DateTime(0));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.clear,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    // Start with today or the currently selected date
    DateTime now = DateTime.now();
    DateTime initialDate = selectedDate ?? now;
    
    // Ensure initialDate isn't before now
    if (initialDate.isBefore(now)) {
      initialDate = now;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 350,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Date picker header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: ColorUtil.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Text(
                      'Choose Deadline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        onDateSelected(initialDate);
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Date picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initialDate,
                  minimumDate: now,
                  maximumDate: now.add(const Duration(days: 365)),
                  onDateTimeChanged: (DateTime newDate) {
                    initialDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Calculate urgency level based on deadline
  int _getUrgencyLevel(DateTime deadline) {
    final now = DateTime.now();
    final daysRemaining = deadline.difference(now).inDays;
    
    if (deadline.isBefore(now)) return 4;
    if (daysRemaining < 1) return 3;
    if (daysRemaining < 3) return 2;
    return 1;
  }
} 