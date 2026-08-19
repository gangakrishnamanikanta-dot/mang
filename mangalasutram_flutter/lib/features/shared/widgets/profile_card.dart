import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/profile.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../home/services/home_service.dart';

enum ProfileCardVariant { compact, expanded }

class ProfileCard extends StatelessWidget {
  final Profile profile;
  final int matchScore;
  final ProfileCardVariant variant;
  final bool showInfo;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.matchScore,
    required this.variant,
    this.showInfo = true,
    this.onTap,
  });

  int get _ageFromDOB {
    if (profile.dateOfBirth == null) return 0;
    final dob = DateTime.tryParse(profile.dateOfBirth!);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Color get _badgeColor {
    if (matchScore >= 80) return const Color(0xFF2E7D32);
    if (matchScore >= 60) return const Color(0xFFF57C00);
    return const Color(0xFFC62828);
  }

  Widget _buildPlaceholder(BuildContext context, bool isExpanded) {
    return Container(
      color: const Color(0xFFF0EBE5),
      child: Center(
        child: Icon(
          profile.gender?.toLowerCase() == 'female' ? Icons.face_3 : Icons.face,
          size: isExpanded ? 80 : 40,
          color: const Color(0xFFD2C7B8),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    HapticFeedback.selectionClick();
    if (onTap != null) {
      onTap!();
    } else {
      HomeService.instance.recordProfileView(profile.id);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileDetailScreen(profile: profile)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (variant == ProfileCardVariant.compact) {
      return _buildCompact(context);
    }
    return _buildExpanded(context);
  }

  Widget _buildCompact(BuildContext context) {
    final age = _ageFromDOB;
    final city = profile.city ?? profile.workLocation ?? '';
    final state = profile.state ?? '';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 162,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Photo ──────────────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(18),
                      bottom: showInfo
                          ? Radius.zero
                          : const Radius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: double.infinity,
                          width: double.infinity,
                          child: profile.profilePhotoUrl != null
                              ? Image.network(
                                  profile.profilePhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, err, stack) =>
                                      _buildPlaceholder(context, false),
                                )
                              : _buildPlaceholder(context, false),
                        ),
                        // Always show Name overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 50,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              bottom: 8,
                              top: 16,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    profile.fullName,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: Color(0xFFF5B759),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info ───────────────────────────────────────────────
                if (showInfo)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Age • Location
                        Text(
                          age > 0 ? '$age yrs • $location' : location,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF9A8A7A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // About Me snippet or fallback
                        Text(
                          profile.aboutMe != null && profile.aboutMe!.isNotEmpty
                              ? profile.aboutMe!
                              : 'Brahmin • ${profile.city ?? ''}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF9A8A7A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // ── Match % badge ─────────────────────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _badgeColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _badgeColor.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$matchScore%',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final age = _ageFromDOB;
    final location = [
      profile.city,
      profile.state,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    final heightText = profile.heightInches != null
        ? '${profile.heightInches! ~/ 12} ft ${profile.heightInches! % 12} in'
        : '';
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              profile.profilePhotoUrl != null
                  ? Image.network(
                      profile.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPlaceholder(context, true),
                    )
                  : _buildPlaceholder(context, true),

              // Gradient Overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black38,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                      Colors.black,
                    ],
                    stops: [0.0, 0.2, 0.5, 0.85, 1.0],
                  ),
                ),
              ),

              // Top Badges
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$matchScore% Match',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Details
              Positioned(
                bottom:
                    100, // Leave room for action buttons in matches view context if needed
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.fullName,
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFFF5B759),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        age > 0 ? '$age yrs' : null,
                        profile.company ?? 'Professional',
                      ].where((s) => s != null && s.isNotEmpty).join(' • '),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (profile.heightInches != null)
                      Text(
                        '${profile.heightInches! ~/ 12}\'${profile.heightInches! % 12}"',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
