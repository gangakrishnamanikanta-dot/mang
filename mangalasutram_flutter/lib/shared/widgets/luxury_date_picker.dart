import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuxuryDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;
  final String title;

  const LuxuryDatePicker({
    super.key,
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
    this.title = 'Select Date of Birth',
  });

  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    String title = 'Select Date of Birth',
    int minimumAge = 18,
  }) {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final effectiveMaxDate = maxDate ?? DateTime(now.year - minimumAge, now.month, now.day);
    final effectiveMinDate = minDate ?? DateTime(now.year - 75, 1, 1);
    final effectiveInitial = initialDate != null
        ? (initialDate.isAfter(effectiveMaxDate)
            ? effectiveMaxDate
            : (initialDate.isBefore(effectiveMinDate)
                ? effectiveMinDate
                : initialDate))
        : DateTime(now.year - 24, now.month, now.day);

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      enableDrag: true,
      builder: (ctx) => LuxuryDatePicker(
        initialDate: effectiveInitial,
        minDate: effectiveMinDate,
        maxDate: effectiveMaxDate,
        title: title,
      ),
    );
  }

  @override
  State<LuxuryDatePicker> createState() => _LuxuryDatePickerState();
}

class _LuxuryDatePickerState extends State<LuxuryDatePicker> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().year - _selectedDate.year;

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
                      '$age Years Old',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC99A4B),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedDate),
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

          // Cupertino Date Wheel
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selectedDate,
              minimumDate: widget.minDate,
              maximumDate: widget.maxDate,
              dateOrder: DatePickerDateOrder.dmy,
              onDateTimeChanged: (DateTime newDate) {
                setState(() {
                  _selectedDate = newDate;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
