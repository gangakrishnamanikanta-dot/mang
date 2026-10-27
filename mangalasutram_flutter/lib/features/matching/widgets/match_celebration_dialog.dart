import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/profile.dart';
import '../../messaging/screens/chat_conversation_screen.dart';
import '../../shared/services/vedic_astrology_service.dart';

class MatchCelebrationDialog extends StatefulWidget {
  final Profile myProfile;
  final Profile matchedProfile;
  final int? precomputedGunaScore;
  final VoidCallback? onChatStarted;

  const MatchCelebrationDialog({
    super.key,
    required this.myProfile,
    required this.matchedProfile,
    this.precomputedGunaScore,
    this.onChatStarted,
  });

  /// Displays the luxury Vedic match celebration dialog.
  static Future<void> show(
    BuildContext context, {
    required Profile myProfile,
    required Profile matchedProfile,
    int? precomputedGunaScore,
    VoidCallback? onChatStarted,
  }) async {
    FocusScope.of(context).unfocus();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Match Celebration',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) => MatchCelebrationDialog(
        myProfile: myProfile,
        matchedProfile: matchedProfile,
        precomputedGunaScore: precomputedGunaScore,
        onChatStarted: onChatStarted,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<MatchCelebrationDialog> createState() => _MatchCelebrationDialogState();
}

class _MatchCelebrationDialogState extends State<MatchCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _pulseAnimation;
  AshtakootResult? _astrologyResult;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    _computeGunaMilan();
  }

  void _computeGunaMilan() {
    final isMyFemale = widget.myProfile.gender?.toLowerCase() == 'female';
    final boy = isMyFemale ? widget.matchedProfile : widget.myProfile;
    final girl = isMyFemale ? widget.myProfile : widget.matchedProfile;

    _astrologyResult = VedicAstrologyService.calculate(
      boyRashiId: boy.rashiId,
      boyNakshatraId: boy.nakshatraId,
      boyPada: boy.padaId,
      girlRashiId: girl.rashiId,
      girlNakshatraId: girl.nakshatraId,
      girlPada: girl.padaId,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _startChat() {
    Navigator.pop(context);
    widget.onChatStarted?.call();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          profileId: widget.matchedProfile.id,
          name: widget.matchedProfile.fullName,
          photoUrl: widget.matchedProfile.profilePhotoUrl,
          subcaste: widget.matchedProfile.subCaste,
          isVerified: widget.matchedProfile.isVerified,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidateName = widget.matchedProfile.fullName;
    final location = [widget.matchedProfile.city, widget.matchedProfile.state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    final int? displayScore =
        _astrologyResult?.roundedScore ?? widget.precomputedGunaScore;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.90,
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF330914), // Deep Royal Burgundy
                Color(0xFF1E040B), // Midnight Burgundy
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFC99A4B).withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC99A4B).withValues(alpha: 0.25),
                blurRadius: 36,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Auspicious Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC99A4B).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFFF3D289), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'AUSPICIOUS ALLIANCE',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF3D289),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Title
                Text(
                  'Shubhamastu!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFFDF9),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "It's a Sacred Match!",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2B768),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Dual Interlocking Circular Avatars ──
                SizedBox(
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // User Avatar (Left)
                      Positioned(
                        left: 45,
                        child: _buildAvatar(
                          url: widget.myProfile.profilePhotoUrl,
                          fallbackText: widget.myProfile.fullName.isNotEmpty
                              ? widget.myProfile.fullName[0].toUpperCase()
                              : 'M',
                        ),
                      ),

                      // Matched Candidate Avatar (Right)
                      Positioned(
                        right: 45,
                        child: _buildAvatar(
                          url: widget.matchedProfile.profilePhotoUrl,
                          fallbackText: candidateName.isNotEmpty
                              ? candidateName[0].toUpperCase()
                              : 'A',
                        ),
                      ),

                      // Sacred Heart Knot in Center with Pulse Animation
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFC99A4B), Color(0xFF8B1E2D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC99A4B).withValues(alpha: 0.6),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Candidate Name & Details
                Text(
                  candidateName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.matchedProfile.subCaste != null || location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [widget.matchedProfile.subCaste, location]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' • '),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFFD8C7B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 18),

                // ── Authentic Guna Milan Compatibility Badge ──
                if (displayScore != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC99A4B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFC99A4B).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFFE2B768), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '$displayScore / 36 Gunas Compatible',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFFFDF9),
                              ),
                            ),
                          ],
                        ),
                        if (_astrologyResult != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _astrologyResult!.verdict,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFE2B768),
                            ),
                          ),
                          if (_astrologyResult!.nadiDoshaCancelled)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '✓ Authentic Nadi Parihara Applied',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF81C784),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handshake_outlined, color: Color(0xFFE2B768), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Mutual Interest Expressed & Accepted',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFAF6F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Primary Action: Start Sacred Chat ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _startChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC99A4B),
                      foregroundColor: const Color(0xFF2A0812),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: Text(
                      'Start Sacred Chat',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Secondary Action: Keep Exploring ──
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Keep Exploring',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD4C8BE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildAvatar({required String? url, required String fallbackText}) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC99A4B), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(fallbackText),
              )
            : _buildFallbackAvatar(fallbackText),
      ),
    );
  }

  Widget _buildFallbackAvatar(String text) {
    return Container(
      color: const Color(0xFF54121F),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
