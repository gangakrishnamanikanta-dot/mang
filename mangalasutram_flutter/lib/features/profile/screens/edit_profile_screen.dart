import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../services/profile_service.dart';
import 'profile_detail_screen.dart';
import 'edit_sections/edit_basic_info_screen.dart';
import 'edit_sections/edit_education_screen.dart';
import 'edit_sections/edit_family_screen.dart';
import 'edit_sections/edit_religion_screen.dart';
import 'edit_sections/edit_location_screen.dart';
import 'edit_sections/edit_lifestyle_screen.dart';
import 'edit_sections/edit_photos_screen.dart';
import 'partner_preferences_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = getIt<ProfileService>();

  static const Color _burgundy = Color(0xFF6E1732);
  static const Color _gold = Color(0xFFC99A4B);
  static const Color _bgCream = Color(0xFFFBF8F1);

  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _profileService.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  String _formatHeight(int? inches) {
    if (inches == null || inches <= 0) return '';
    final ft = inches ~/ 12;
    final rem = inches % 12;
    return "$ft'$rem\"";
  }

  String _basicSummary(Profile? p) {
    if (p == null) return 'Edit';
    final parts = <String>[];
    if (p.age != null) parts.add('${p.age} yrs');
    final h = _formatHeight(p.heightInches);
    if (h.isNotEmpty) parts.add(h);
    return parts.isEmpty ? 'Add details' : parts.join(' • ');
  }

  String _photoSummary(Profile? p) {
    if (p == null) return 'Add photos';
    int count = (p.profilePhotoUrl != null && p.profilePhotoUrl!.isNotEmpty) ? 1 : 0;
    count += p.additionalPhotoUrls?.length ?? 0;
    return count == 0 ? 'Add photos' : '$count uploaded';
  }

  String _horoscopeSummary(Profile? p) {
    if (p == null) return 'Add details';
    if (p.placeOfBirth != null && p.placeOfBirth!.trim().isNotEmpty) {
      return p.placeOfBirth!.trim();
    }
    if (p.gothramId != null || p.nakshatraId != null) {
      return 'Configured';
    }
    return 'Add birth star';
  }

  String _careerSummary(Profile? p) {
    if (p == null) return 'Add details';
    if (p.company != null && p.company!.trim().isNotEmpty) {
      return p.company!.trim();
    }
    if (p.college != null && p.college!.trim().isNotEmpty) {
      return p.college!.trim();
    }
    if (p.occupationId != null || p.highestEducationId != null) {
      return 'Configured';
    }
    return 'Add career';
  }

  String _familySummary(Profile? p) {
    if (p == null) return 'Add details';
    if (p.nativePlace != null && p.nativePlace!.trim().isNotEmpty) {
      return p.nativePlace!.trim();
    }
    if (p.fatherName != null && p.fatherName!.trim().isNotEmpty) {
      return 'Configured';
    }
    return 'Add family';
  }

  String _locationSummary(Profile? p) {
    if (p == null) return 'Add details';
    final parts = <String>[
      if (p.city != null && p.city!.trim().isNotEmpty) p.city!.trim(),
      if (p.state != null && p.state!.trim().isNotEmpty) p.state!.trim(),
    ];
    return parts.isEmpty ? 'Add location' : parts.join(', ');
  }

  String _lifestyleSummary(Profile? p) {
    if (p == null) return 'Add details';
    if (p.aboutMe != null && p.aboutMe!.trim().isNotEmpty) {
      return 'Bio & habits';
    }
    if (p.foodPreferenceId != null) return 'Configured';
    return 'Add bio & habits';
  }

  Widget _buildSection(String title, List<Widget> children, {String? footer}) {
    final List<Widget> rows = [];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          const Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 52,
            color: Color(0xFFEDE7DF),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 30, bottom: 7, top: 22),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF7A6A5E),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.018),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(children: rows),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 24, top: 6),
            child: Text(
              footer,
              style: GoogleFonts.inter(
                color: const Color(0xFF8C7E72),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTile({
    required String title,
    required String trailingValue,
    required IconData icon,
    required Widget destination,
  }) {
    final bool isPlaceholder = trailingValue.startsWith('Add ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.selectionClick();
          await Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => destination),
          );
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF7F2),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFECE4D9), width: 0.6),
                ),
                child: Icon(icon, color: _burgundy, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: const Color(0xFF1C1917),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 135),
                child: Text(
                  trailingValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w400,
                    letterSpacing: -0.1,
                    color: isPlaceholder ? _gold : const Color(0xFF7A6A5E),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: Color(0xFFC4B9AE),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int score = _profile?.completionScore ?? 0;
    final String matrimonyId = _profile != null && _profile!.id.length >= 6
        ? 'MS-${_profile!.id.substring(0, 6).toUpperCase()}'
        : 'MS-MEMBER';

    return Scaffold(
      backgroundColor: _bgCream,
      appBar: AppBar(
        backgroundColor: _bgCream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: _burgundy, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Biodata',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF2B0912),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_profile != null)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => ProfileDetailScreen(profile: _profile!),
                  ),
                );
              },
              child: Text(
                'Preview',
                style: GoogleFonts.inter(
                  color: _burgundy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 44),
              children: [
                // ── Apple-Style Inset Profile Header Card ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const EditPhotosScreen(),
                                ),
                              );
                              _load();
                            },
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _gold, width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 32,
                                    backgroundColor: const Color(0xFFF6F1EA),
                                    backgroundImage:
                                        _profile?.profilePhotoUrl != null
                                        ? NetworkImage(_profile!.profilePhotoUrl!)
                                        : null,
                                    child: _profile?.profilePhotoUrl == null
                                        ? const Icon(
                                            CupertinoIcons.person_fill,
                                            size: 28,
                                            color: _burgundy,
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _burgundy,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.camera_fill,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.fullName ?? 'Valued Member',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1C1917),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: matrimonyId),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Copied $matrimonyId',
                                          style: GoogleFonts.inter(fontSize: 12.5),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ID: $matrimonyId',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF7A6A5E),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        CupertinoIcons.doc_on_doc,
                                        size: 12,
                                        color: Color(0xFF9E8F82),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Progress Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF8F3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFEDE5D8),
                            width: 0.7,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Biodata Completeness',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF5A4E44),
                                  ),
                                ),
                                Text(
                                  '$score%',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _burgundy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (score / 100).clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: const Color(0xFFE8DFD3),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  _gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _buildSection(
                  'Identity & Gallery',
                  [
                    _buildTile(
                      title: 'Basic Information',
                      trailingValue: _basicSummary(_profile),
                      icon: CupertinoIcons.person,
                      destination: const EditBasicInfoScreen(),
                    ),
                    _buildTile(
                      title: 'Photos & Gallery',
                      trailingValue: _photoSummary(_profile),
                      icon: CupertinoIcons.photo_on_rectangle,
                      destination: const EditPhotosScreen(),
                    ),
                  ],
                ),

                _buildSection(
                  'Vedic & Horoscope',
                  [
                    _buildTile(
                      title: 'Horoscope & Tradition',
                      trailingValue: _horoscopeSummary(_profile),
                      icon: Icons.auto_awesome_outlined,
                      destination: const EditReligionScreen(),
                    ),
                  ],
                  footer:
                      'Authentic Nakshatram, Raasi, and Gothram details ensure accurate 36-Guna Milan matching.',
                ),

                _buildSection(
                  'Background & Lifestyle',
                  [
                    _buildTile(
                      title: 'Education & Career',
                      trailingValue: _careerSummary(_profile),
                      icon: CupertinoIcons.briefcase,
                      destination: const EditEducationScreen(),
                    ),
                    _buildTile(
                      title: 'Family Details',
                      trailingValue: _familySummary(_profile),
                      icon: CupertinoIcons.person_2,
                      destination: const EditFamilyScreen(),
                    ),
                    _buildTile(
                      title: 'Location & Residency',
                      trailingValue: _locationSummary(_profile),
                      icon: CupertinoIcons.location,
                      destination: const EditLocationScreen(),
                    ),
                    _buildTile(
                      title: 'Lifestyle & Bio',
                      trailingValue: _lifestyleSummary(_profile),
                      icon: CupertinoIcons.sparkles,
                      destination: const EditLifestyleScreen(),
                    ),
                  ],
                ),

                _buildSection(
                  'Partner Expectations',
                  [
                    _buildTile(
                      title: 'Partner Preferences',
                      trailingValue: 'Configure criteria',
                      icon: CupertinoIcons.heart_circle,
                      destination: const EditPartnerPreferencesScreen(),
                    ),
                  ],
                  footer:
                      'Your partner preferences directly power your Top Matches and compatibility scores.',
                ),
              ],
            ),
    );
  }
}
