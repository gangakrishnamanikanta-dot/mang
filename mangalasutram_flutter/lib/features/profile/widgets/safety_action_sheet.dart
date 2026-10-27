import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/di.dart';
import '../services/moderation_service.dart';

class SafetyActionSheet extends StatefulWidget {
  final String profileId;
  final String fullName;
  final VoidCallback? onBlocked;
  final ModerationService? moderationService;

  const SafetyActionSheet({
    super.key,
    required this.profileId,
    required this.fullName,
    this.onBlocked,
    this.moderationService,
  });

  static Future<void> show(
    BuildContext context, {
    required String profileId,
    required String fullName,
    VoidCallback? onBlocked,
    ModerationService? moderationService,
  }) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafetyActionSheet(
        profileId: profileId,
        fullName: fullName,
        onBlocked: onBlocked,
        moderationService: moderationService,
      ),
    );
  }

  @override
  State<SafetyActionSheet> createState() => _SafetyActionSheetState();
}

class _SafetyActionSheetState extends State<SafetyActionSheet> {
  late final ModerationService _moderationService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _moderationService = widget.moderationService ??
        (getIt.isRegistered<ModerationService>()
            ? getIt<ModerationService>()
            : ModerationService());
  }

  void _showBlockConfirmation() {
    Navigator.pop(context); // Close initial sheet
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Block ${widget.fullName}?',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF54121F),
          ),
        ),
        content: Text(
          'They will not be able to view your profile, send you interests, or message you. Any existing conversation or connection will be severed.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF5A4A42),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7A6B63),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeBlock();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1E2D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'Block Member',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBlock() async {
    setState(() => _isProcessing = true);
    try {
      await _moderationService.blockUser(widget.profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.fullName} has been blocked.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: const Color(0xFF2B2118),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        widget.onBlocked?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block user: $e'),
            backgroundColor: const Color(0xFF8B1E2D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showReportSheet() {
    Navigator.pop(context); // Close initial sheet
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReportReasonSheet(
        profileId: widget.profileId,
        fullName: widget.fullName,
        moderationService: _moderationService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4C8BE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Trust & Safety',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A121A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Options for ${widget.fullName}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7A6B63),
              ),
            ),
            const SizedBox(height: 20),

            // Option 1: Report
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flag_outlined, color: Color(0xFFE65100), size: 22),
              ),
              title: Text(
                'Report Member',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF231F20),
                ),
              ),
              subtitle: Text(
                'Flag fake profiles, harassment, or inappropriate photos',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7A6B63)),
              ),
              onTap: _isProcessing ? null : _showReportSheet,
            ),
            const Divider(height: 1, color: Color(0xFFEFE7DE)),

            // Option 2: Block
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block_outlined, color: Color(0xFFC62828), size: 22),
              ),
              title: Text(
                'Block ${widget.fullName}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC62828),
                ),
              ),
              subtitle: Text(
                'Sever all communication and hide each other\'s profiles',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7A6B63)),
              ),
              onTap: _isProcessing ? null : _showBlockConfirmation,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ReportReasonSheet extends StatefulWidget {
  final String profileId;
  final String fullName;
  final ModerationService? moderationService;

  const _ReportReasonSheet({
    required this.profileId,
    required this.fullName,
    this.moderationService,
  });

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  late final ModerationService _moderationService;
  final _detailsController = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _moderationService = widget.moderationService ??
        (getIt.isRegistered<ModerationService>()
            ? getIt<ModerationService>()
            : ModerationService());
  }

  final List<Map<String, String>> _categories = [
    {
      'id': 'fake_profile',
      'label': 'Fake or Impersonated Profile',
      'desc': 'Using someone else\'s photos or fabricated information',
    },
    {
      'id': 'inappropriate_photo',
      'label': 'Inappropriate or Indecent Photos',
      'desc': 'Obscene, offensive, or non-compliant imagery',
    },
    {
      'id': 'harassment',
      'label': 'Harassment or Abusive Behavior',
      'desc': 'Disrespectful language, threats, or unsolicited demands',
    },
    {
      'id': 'already_married',
      'label': 'Already Married / Misrepresented Status',
      'desc': 'Violating single/unmarried eligibility requirements',
    },
    {
      'id': 'scam_or_commercial',
      'label': 'Financial Scam or Commercial Solicitation',
      'desc': 'Asking for money, crypto, or promoting business services',
    },
    {
      'id': 'other',
      'label': 'Other Concern',
      'desc': 'Any other violation of Vedic community standards',
    },
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    final catObj = _categories.firstWhere((c) => c['id'] == _selectedCategory);

    try {
      await _moderationService.reportUser(
        widget.profileId,
        category: _selectedCategory!,
        reason: catObj['label']!,
        details: _detailsController.text.trim().isNotEmpty ? _detailsController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report submitted. Our safety team will review it within 24 hours.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: const Color(0xFF8B1E2D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4C8BE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Report Member',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF54121F),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Why are you reporting ${widget.fullName}? Your report is completely confidential.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF6B5E55),
                ),
              ),
              const SizedBox(height: 16),

              // Categories List
              ..._categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat['id']),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF9F1E6) : const Color(0xFFFBF8F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFC99A4B) : const Color(0xFFECE4D8),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? const Color(0xFF6E1732) : const Color(0xFF8C7A6B),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['label']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF231F20),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat['desc']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF6B5E55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              Text(
                'Additional details (optional):',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A4A42),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF231F20)),
                decoration: InputDecoration(
                  hintText: 'Provide any helpful context or specific incident details...',
                  hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF9E8E81)),
                  filled: true,
                  fillColor: const Color(0xFFFBF8F1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFECE4D8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC99A4B)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedCategory == null || _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6E1732),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD4C8BE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Submit Confidential Report',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
