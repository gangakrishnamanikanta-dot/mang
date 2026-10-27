import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeclineReasonSheet extends StatelessWidget {
  final String candidateName;
  final ValueChanged<String> onReasonSelected;

  const DeclineReasonSheet({
    super.key,
    required this.candidateName,
    required this.onReasonSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String candidateName,
    required ValueChanged<String> onReasonSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeclineReasonSheet(
        candidateName: candidateName,
        onReasonSelected: onReasonSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [
      'Location / Distance',
      'Horoscope / Guna Mismatch',
      'Age Gap',
      'Career / Education',
      'Lifestyle / Diet',
      'Looking for Different Subsect',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6C8B4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Refine Your Alliances',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6E1732),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Why did you pass on $candidateName? (Helps your family and algorithm adjust)',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6D635B)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reasons.map((reason) {
              return ActionChip(
                label: Text(
                  reason,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5A4A42)),
                ),
                backgroundColor: const Color(0xFFF3EAE0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  Navigator.pop(context);
                  onReasonSelected(reason);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Noted: $reason. Refining future matches.'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF6E1732),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
