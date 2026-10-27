import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/subscription_service.dart';
import '../screens/plans_screen.dart';

class ContactUnlockDialog extends StatefulWidget {
  final String targetProfileId;
  final String targetProfileName;

  const ContactUnlockDialog({
    super.key,
    required this.targetProfileId,
    required this.targetProfileName,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetProfileId,
    required String targetProfileName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactUnlockDialog(
        targetProfileId: targetProfileId,
        targetProfileName: targetProfileName,
      ),
    );
  }

  @override
  State<ContactUnlockDialog> createState() => _ContactUnlockDialogState();
}

class _ContactUnlockDialogState extends State<ContactUnlockDialog> {
  final _subService = SubscriptionService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _unlockResult;

  @override
  void initState() {
    super.initState();
    _performUnlock();
  }

  Future<void> _performUnlock() async {
    final result = await _subService.unlockContact(widget.targetProfileId);
    if (mounted) {
      setState(() {
        _unlockResult = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: _isLoading
          ? const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6E1732)),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final allowed = _unlockResult?['allowed'] == true;
    final error = _unlockResult?['error']?.toString();
    final phone = _unlockResult?['phone_number']?.toString();
    final remaining = _unlockResult?['remaining_contacts'] ?? 0;
    final alreadyUnlocked = _unlockResult?['already_unlocked'] == true;

    if (allowed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Verified Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8F5E9),
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Color(0xFF2E7D32),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '${widget.targetProfileName}\'s Contact',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B2118),
            ),
          ),
          const SizedBox(height: 6),

          Text(
            alreadyUnlocked
                ? 'You previously unlocked this contact number.'
                : 'Contact credit used successfully.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF706053),
            ),
          ),
          const SizedBox(height: 20),

          // Phone Number Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF4EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEADBCE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified Phone Number',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF8A7A6E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone ?? 'Not provided',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6E1732),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    if (phone != null && phone.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number copied to clipboard!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF6E1732)),
                  tooltip: 'Copy Number',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Remaining Balance Text
          Text(
            '$remaining Contact Unlocks remaining this cycle',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8A7A6E),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      );
    }

    // Locked / Upgrade Required
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFF3E0),
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: Color(0xFFE65100),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          error == 'contact_quota_exceeded'
              ? 'Contact Credits Exhausted'
              : 'Unlock Contact Numbers',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2B2118),
          ),
        ),
        const SizedBox(height: 8),

        Text(
          error == 'contact_quota_exceeded'
              ? 'You have used all available contact unlocks for this billing cycle. Upgrade to Prime VIP for 60 contacts.'
              : 'Direct phone numbers and horoscopes are exclusive to Prime members. Upgrade to unlock ${widget.targetProfileName}\'s contact immediately.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF706053),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6E1732),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              'View Prime Membership Plans',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Maybe Later',
            style: GoogleFonts.inter(color: const Color(0xFF8A7A6E)),
          ),
        ),
      ],
    );
  }
}
