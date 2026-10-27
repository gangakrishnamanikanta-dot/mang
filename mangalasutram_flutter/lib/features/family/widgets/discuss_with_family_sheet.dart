import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/family_service.dart';

class DiscussWithFamilySheet extends StatefulWidget {
  final String targetProfileId;
  final String candidateName;
  final String? candidatePhoto;
  final String? candidateCity;

  const DiscussWithFamilySheet({
    super.key,
    required this.targetProfileId,
    required this.candidateName,
    this.candidatePhoto,
    this.candidateCity,
  });

  static Future<void> show({
    required BuildContext context,
    required String targetProfileId,
    required String candidateName,
    String? candidatePhoto,
    String? candidateCity,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DiscussWithFamilySheet(
        targetProfileId: targetProfileId,
        candidateName: candidateName,
        candidatePhoto: candidatePhoto,
        candidateCity: candidateCity,
      ),
    );
  }

  @override
  State<DiscussWithFamilySheet> createState() => _DiscussWithFamilySheetState();
}

class _DiscussWithFamilySheetState extends State<DiscussWithFamilySheet> {
  final _familyService = FamilyService.instance;
  final _noteController = TextEditingController();
  String _selectedVerdict = 'discuss';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    final circle = await _familyService.getOrCreateCircle();
    if (circle == null || circle['circle_id'] == null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to Family Room. Please try again.'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
      return;
    }

    final circleId = circle['circle_id'] as String;
    final success = await _familyService.addReview(
      circleId: circleId,
      targetProfileId: widget.targetProfileId,
      reaction: _selectedVerdict,
      note: _noteController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Shared ${widget.candidateName} with your Family Room!'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFEADBCE),
                    child: widget.candidatePhoto != null
                        ? Image.network(widget.candidatePhoto!, fit: BoxFit.cover)
                        : const Icon(Icons.person, color: Color(0xFF6E1732)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discuss in Family Room',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6E1732),
                        ),
                      ),
                      Text(
                        widget.candidateName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A4A42),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Your Family Verdict / అభిప్రాయం:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF332D28)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildVerdictChip('shortlist', 'Shortlist (అనుకూలం)', const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _buildVerdictChip('discuss', 'Deliberate (చర్చించాలి)', const Color(0xFFC99A4B)),
                const SizedBox(width: 8),
                _buildVerdictChip('decline', 'Decline (వద్దు)', const Color(0xFFD32F2F)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add private note for family (e.g. Horoscope verified by Shastri garu, package confirmed)...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1978E)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                fillColor: const Color(0xFFFBF8F1),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6E1732),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add to Family Discussion'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictChip(String value, String label, Color activeColor) {
    final isSelected = _selectedVerdict == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedVerdict = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : const Color(0xFFF3EAE0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected ? activeColor : const Color(0xFF6D635B),
            ),
          ),
        ),
      ),
    );
  }
}
