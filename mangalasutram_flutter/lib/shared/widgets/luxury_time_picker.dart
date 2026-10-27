import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuxuryTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const LuxuryTimePicker({
    super.key,
    required this.initialTime,
    this.title = 'Select Time of Birth',
  });

  static Future<TimeOfDay?> show({
    required BuildContext context,
    TimeOfDay? initialTime,
    String title = 'Select Time of Birth',
  }) {
    FocusScope.of(context).unfocus();

    final effectiveInitial = initialTime ?? TimeOfDay.now();

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      enableDrag: true,
      builder: (ctx) => LuxuryTimePicker(
        initialTime: effectiveInitial,
        title: title,
      ),
    );
  }

  @override
  State<LuxuryTimePicker> createState() => _LuxuryTimePickerState();
}

class _LuxuryTimePickerState extends State<LuxuryTimePicker> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  String _formatTime() {
    final hour = _selectedDateTime.hour;
    final minute = _selectedDateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8E8E93),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF231F20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6E1732),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    final time = TimeOfDay(
                      hour: _selectedDateTime.hour,
                      minute: _selectedDateTime.minute,
                    );
                    Navigator.pop(context, time);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6E1732),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF2EBE3)),

          // Cupertino Time Wheel
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _selectedDateTime,
              use24hFormat: false,
              onDateTimeChanged: (DateTime newDateTime) {
                setState(() {
                  _selectedDateTime = newDateTime;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
