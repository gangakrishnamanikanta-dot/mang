import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../services/profile_service.dart';
import 'edit_sections/edit_basic_info_screen.dart';
import 'edit_sections/edit_education_screen.dart';
import 'edit_sections/edit_family_screen.dart';
import 'edit_sections/edit_religion_screen.dart';
import 'edit_sections/edit_privacy_screen.dart';
import 'partner_preferences_screen.dart';
import 'edit_sections/edit_photos_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = getIt<ProfileService>();

  static const Color _burgundy = Color(0xFF6E1732);
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

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 8, top: 24),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _burgundy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(String title, IconData icon, Widget destination) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => destination),
          );
          _load(); // Reload profile data when returning to update any stats
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: _burgundy, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCream, // Match app branding
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _bgCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _burgundy),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : ListView(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: _profile?.profilePhotoUrl != null
                            ? NetworkImage(_profile!.profilePhotoUrl!)
                            : null,
                        child: _profile?.profilePhotoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: _burgundy,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _profile?.fullName ?? 'User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: MS${_profile?.id.substring(0, 5).toUpperCase() ?? ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completion: ${_profile?.completionScore ?? 0}%',
                        style: const TextStyle(
                          color: _burgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSection('Public Profile', [
                  _buildTile(
                    'Basic Info',
                    Icons.person_outline,
                    const EditBasicInfoScreen(),
                  ),
                  const Divider(
                    height: 1,
                    indent: 54,
                    color: Color(0xFFF0F0F0),
                  ),
                  _buildTile(
                    'Photos',
                    Icons.photo_library_outlined,
                    const EditPhotosScreen(),
                  ),
                ]),
                _buildSection('Background & Details', [
                  _buildTile(
                    'Education & Career',
                    Icons.work_outline,
                    const EditEducationScreen(),
                  ),
                  const Divider(
                    height: 1,
                    indent: 54,
                    color: Color(0xFFF0F0F0),
                  ),
                  _buildTile(
                    'Family Details',
                    Icons.family_restroom,
                    const EditFamilyScreen(),
                  ),
                  const Divider(
                    height: 1,
                    indent: 54,
                    color: Color(0xFFF0F0F0),
                  ),
                  _buildTile(
                    'Religious Background',
                    Icons.temple_hindu_outlined,
                    const EditReligionScreen(),
                  ),
                ]),
                _buildSection('Account Settings', [
                  _buildTile(
                    'Partner Preferences',
                    Icons.tune,
                    const EditPartnerPreferencesScreen(),
                  ),
                  const Divider(
                    height: 1,
                    indent: 54,
                    color: Color(0xFFF0F0F0),
                  ),
                  _buildTile(
                    'Privacy Settings',
                    Icons.lock_outline,
                    const EditPrivacyScreen(),
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
