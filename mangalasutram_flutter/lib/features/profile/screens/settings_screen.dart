import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/supabase_service.dart';
import '../../home/services/home_service.dart';
import '../../subscription/models/subscription_status.dart';
import '../../subscription/services/subscription_service.dart';
import '../services/moderation_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _moderationService = getIt<ModerationService>();
  final _authService = getIt<AuthService>();
  final _subService = SubscriptionService.instance;
  final _homeService = HomeService.instance;

  static const Color _burgundy = Color(0xFF6E1732);
  static const Color _gold = Color(0xFFC99A4B);
  static const Color _bgCream = Color(0xFFFBF8F1);

  Profile? _myProfile;
  SubscriptionStatus? _subStatus;
  bool _isLoading = true;

  // Live privacy state
  bool _isHidden = false;
  bool _hideMobile = true;
  bool _hideEmail = true;
  bool _showHoroscope = false;
  bool _allowGuardianProxyChat = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _homeService.getMyProfile(),
        _subService.getMyStatus(),
      ]);
      final profile = results[0] as Profile?;
      final status = results[1] as SubscriptionStatus?;
      if (mounted) {
        setState(() {
          _myProfile = profile;
          _subStatus = status;
          if (profile != null) {
            _isHidden = profile.isHidden;
            _hideMobile = profile.hideMobile ?? true;
            _hideEmail = profile.hideEmail ?? true;
            _showHoroscope = profile.showHoroscope ?? false;
            _allowGuardianProxyChat = profile.allowGuardianProxyChat;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onToggleHidden(bool val) async {
    HapticFeedback.lightImpact();
    setState(() => _isHidden = val);
    final ok = await _homeService.toggleProfileVisibility(val);
    if (!ok && mounted) {
      setState(() => _isHidden = !val);
      _showToast('Could not update profile visibility.');
    } else if (mounted) {
      _showToast(
        val
            ? 'Profile paused. You are hidden from public discovery.'
            : 'Profile is now active and visible to matches.',
      );
    }
  }

  Future<void> _onTogglePrivacyField(
    String column,
    bool val,
    ValueChanged<bool> applyLocal,
  ) async {
    HapticFeedback.lightImpact();
    applyLocal(val);
    final ok = await _homeService.updatePrivacyField(column, val);
    if (!ok && mounted) {
      applyLocal(!val);
      _showToast('Failed to update privacy setting.');
    }
  }

  Future<void> _onToggleGuardianProxy(bool val) async {
    HapticFeedback.lightImpact();
    setState(() => _allowGuardianProxyChat = val);
    final ok = await _homeService.toggleGuardianProxyChat(val);
    if (!ok && mounted) {
      setState(() => _allowGuardianProxyChat = !val);
      _showToast('Could not update family chat permission.');
    } else if (mounted) {
      _showToast(
        val
            ? 'Parents can now reply to matches on your behalf.'
            : 'Guardian proxy chat disabled. Parents have view-only access.',
      );
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showChangePasswordSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ChangePasswordSheet(),
    );
  }

  void _showBlockedUsersSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _BlockedUsersSheet(),
    );
  }

  void _showHelpSupportSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _HelpSupportSheet(),
    );
  }

  void _showLegalSheet({required String title, required List<_LegalSection> sections}) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LegalDocumentSheet(title: title, sections: sections),
    );
  }

  void _confirmSignOut() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Are you sure you want to sign out of Mangalasutram on this device?',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Account Permanently?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'This action is irreversible. Your biodata, photos, horoscope, family circle, and encrypted chats will be permanently erased in compliance with Apple & Google data policies.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Account'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _executeDeleteAccount();
            },
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: _burgundy),
      ),
    );

    try {
      await _moderationService.deleteAccount();
      if (mounted) {
        Navigator.pop(context);
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = _myProfile?.fullName ?? 'Valued Member';
    final memberEmail =
        _myProfile?.email ??
        SupabaseService.client.auth.currentUser?.email ??
        '';
    final isPrime = _subStatus?.isPrime ?? false;
    final tierName = _subStatus?.tier.name.toUpperCase() ?? 'FREE';
    final isGuardian = _myProfile?.isGuardian ?? false;

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
          'Settings & Privacy',
          style: GoogleFonts.playfairDisplay(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2B0912),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 44),
              children: [
                // ── Account Summary Card ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.018),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _burgundy,
                        backgroundImage: _myProfile?.profilePhotoUrl != null
                            ? NetworkImage(_myProfile!.profilePhotoUrl!)
                            : null,
                        child: _myProfile?.profilePhotoUrl == null
                            ? Text(
                                memberName.isNotEmpty
                                    ? memberName[0].toUpperCase()
                                    : 'M',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memberName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: const Color(0xFF1C1917),
                              ),
                            ),
                            if (memberEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                memberEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF7A6A5E),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPrime
                                        ? const Color(0xFFFFF9EE)
                                        : const Color(0xFFF3EEE7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isPrime
                                          ? _gold
                                          : const Color(0xFFD8CFC4),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    isPrime ? '✨ $tierName' : 'FREE PLAN',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isPrime
                                          ? const Color(0xFF8A6218)
                                          : const Color(0xFF6B5E54),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isHidden
                                        ? const Color(0xFFFFF4E5)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _isHidden ? 'Paused' : 'Active',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _isHidden
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF1B5E20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Section 1: Visibility & Discovery (Candidate only) ──
                if (!isGuardian)
                  _buildSection(
                    title: 'Visibility & Discovery',
                    footer:
                        'Pausing your profile hides you from public search and daily recommendations while keeping your existing chats active.',
                    children: [
                      _buildSwitchRow(
                        icon: CupertinoIcons.eye_slash,
                        title: 'Pause / Hide Profile',
                        subtitle: 'Incognito mode during active talks',
                        value: _isHidden,
                        onChanged: _onToggleHidden,
                      ),
                      _buildSwitchRow(
                        icon: CupertinoIcons.phone,
                        title: 'Hide Mobile Number',
                        subtitle: 'Only accepted matches can view',
                        value: _hideMobile,
                        onChanged: (v) => _onTogglePrivacyField(
                          'hide_mobile',
                          v,
                          (val) => setState(() => _hideMobile = val),
                        ),
                      ),
                      _buildSwitchRow(
                        icon: CupertinoIcons.mail,
                        title: 'Hide Email Address',
                        subtitle: 'Keep email private from public profiles',
                        value: _hideEmail,
                        onChanged: (v) => _onTogglePrivacyField(
                          'hide_email',
                          v,
                          (val) => setState(() => _hideEmail = val),
                        ),
                      ),
                      _buildSwitchRow(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Display Horoscope Publicly',
                        subtitle: 'Show Raasi, Nakshatram & Gothram',
                        value: _showHoroscope,
                        onChanged: (v) => _onTogglePrivacyField(
                          'show_horoscope',
                          v,
                          (val) => setState(() => _showHoroscope = val),
                        ),
                      ),
                    ],
                  ),

                // ── Section 2: Family & Guardian Controls (Candidate only) ──
                if (!isGuardian)
                  _buildSection(
                    title: 'Family & Guardian Controls',
                    footer:
                        'When enabled, linked parents can reply to your alliances with a "Sent by Parent" badge.',
                    children: [
                      _buildSwitchRow(
                        icon: CupertinoIcons.person_2,
                        title: 'Allow Parents to Chat on My Behalf',
                        subtitle: 'Candidate Veto control for family proxy chat',
                        value: _allowGuardianProxyChat,
                        onChanged: _onToggleGuardianProxy,
                      ),
                    ],
                  ),

                // ── Section 3: Security & Safety ──
                _buildSection(
                  title: 'Security & Safety',
                  children: [
                    _buildNavRow(
                      icon: CupertinoIcons.lock,
                      title: 'Change Password',
                      subtitle: 'Update your account login password',
                      onTap: _showChangePasswordSheet,
                    ),
                    _buildNavRow(
                      icon: CupertinoIcons.nosign,
                      title: 'Blocked Members',
                      subtitle: 'Manage profiles you have restricted',
                      onTap: _showBlockedUsersSheet,
                    ),
                  ],
                ),

                // ── Section 4: Help, Legal & Compliance ──
                _buildSection(
                  title: 'Support & Legal',
                  children: [
                    _buildNavRow(
                      icon: CupertinoIcons.question_circle,
                      title: 'Help & Vedic Concierge',
                      subtitle: 'FAQs, support email & member assistance',
                      onTap: _showHelpSupportSheet,
                    ),
                    _buildNavRow(
                      icon: CupertinoIcons.doc_text,
                      title: 'Terms of Service',
                      subtitle: 'Membership rules & community standards',
                      onTap: () => _showLegalSheet(
                        title: 'Terms of Service',
                        sections: _termsSections,
                      ),
                    ),
                    _buildNavRow(
                      icon: CupertinoIcons.hand_raised,
                      title: 'Privacy Policy',
                      subtitle: 'End-to-end encryption & data protection',
                      onTap: () => _showLegalSheet(
                        title: 'Privacy Policy',
                        sections: _privacySections,
                      ),
                    ),
                    _buildNavRow(
                      icon: CupertinoIcons.info,
                      title: 'App Version',
                      trailingText: 'v1.0.0 (Build 6)',
                      onTap: null,
                    ),
                  ],
                ),

                // ── Section 5: Account Actions ──
                _buildSection(
                  title: 'Account Actions',
                  children: [
                    _buildNavRow(
                      icon: CupertinoIcons.square_arrow_right,
                      title: 'Sign Out',
                      onTap: _confirmSignOut,
                    ),
                    _buildNavRow(
                      icon: CupertinoIcons.trash,
                      iconColor: const Color(0xFFC62828),
                      title: 'Delete Account',
                      subtitle: 'Permanently erase biodata, photos & chats',
                      titleColor: const Color(0xFFC62828),
                      onTap: _confirmDeleteAccount,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    String? footer,
  }) {
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
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A6A5E),
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
                fontSize: 11.5,
                color: const Color(0xFF8C7E72),
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: const Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF7A6A5E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            activeTrackColor: _burgundy,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final effectiveIconColor = iconColor ?? _burgundy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.5),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: effectiveIconColor == _burgundy
                      ? const Color(0xFFFBF7F2)
                      : effectiveIconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: effectiveIconColor == _burgundy
                        ? const Color(0xFFECE4D9)
                        : effectiveIconColor.withValues(alpha: 0.2),
                    width: 0.6,
                  ),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: titleColor ?? const Color(0xFF1C1917),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF7A6A5E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF8C7E72),
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: Color(0xFFC4B9AE),
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Password Sheet (Apple HIG Modal)
// ─────────────────────────────────────────────────────────────────────────────
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

typedef _ChangePasswordSheet = ChangePasswordSheet;

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPass = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (currentPass.isEmpty) {
      setState(() => _error = 'Please enter your current password.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters long.');
      return;
    }
    if (newPass == currentPass) {
      setState(() => _error = 'New password must be different from current password.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }

    final user = SupabaseService.client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      setState(() => _error = 'Session expired. Please log in again.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // Step 1: Re-authenticate with current password to satisfy fresh session requirement
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: currentPass,
      );
    } on AuthException catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Current password is incorrect.';
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not verify current password. Please try again.';
        });
      }
      return;
    }

    // Step 2: Update password with freshly authenticated session
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password updated successfully.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message.contains('Database error')
              ? 'Unable to update password. Please use Forgot Password from login.'
              : e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to update password. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8CFC4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Change Password',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2B0912),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Color(0xFFB8AEA4),
                  size: 22,
                ),
              ),
            ],
          ),
          Text(
            'Enter a strong password of at least 8 characters to secure your Mangalasutram account.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF7A6A5E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _currentPassCtrl,
                  obscureText: _obscureCurrent,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Current Password',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFFB8AEA4),
                      fontSize: 14.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 18,
                        color: const Color(0xFF8C7E72),
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const Divider(height: 0.5, thickness: 0.5, indent: 16),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'New Password',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFFB8AEA4),
                      fontSize: 14.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 18,
                        color: const Color(0xFF8C7E72),
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const Divider(height: 0.5, thickness: 0.5, indent: 16),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Confirm New Password',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFFB8AEA4),
                      fontSize: 14.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 18,
                        color: const Color(0xFF8C7E72),
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFC62828),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Update Password',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help & Support Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _HelpSupportSheet extends StatelessWidget {
  const _HelpSupportSheet();

  @override
  Widget build(BuildContext context) {
    final faqs = [
      (
        'How does Family Room & Guardian Login work?',
        'Share your 6-character Family Invite Code (found in the Sidebar or Family Room) with your parents. When they sign up as a Family Guardian and enter your code, they can review your matches and deliberate in your private Family Group Chat.',
      ),
      (
        'How is the 36-Guna Milan score calculated?',
        'Mangalasutram computes authentic Vedic Ashta-Koota compatibility (Varna, Vashya, Tara, Yoni, Graha Maitri, Gana, Bhakoot, and Nadi) strictly from your Nakshatram and Raasi.',
      ),
      (
        'What happens when I Pause / Hide my profile?',
        'Your profile is immediately hidden from public discovery and daily match feeds. Your existing accepted connections and family chats remain active until you unpause.',
      ),
      (
        'Are my chat messages private?',
        'Yes. All 1-on-1 alliance messages use deterministic End-to-End Encryption (E2EE) so only you, your match, and authorized family guardians can read them.',
      ),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8CFC4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Help & Vedic Concierge',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B0912),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Color(0xFFB8AEA4),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF8EE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.mail_solid,
                          color: Color(0xFF6E1732),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Priority Concierge Desk',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1917),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'support@mangalasutram.com • Responds within 24h',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF7A6A5E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(
                              text: 'support@mangalasutram.com',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Copied support@mangalasutram.com',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Text(
                          'Copy',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6E1732),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 8),
                  child: Text(
                    'FREQUENTLY ASKED QUESTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7A6A5E),
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < faqs.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faqs[i].$1,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C1917),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                faqs[i].$2,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF6B5E54),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < faqs.length - 1)
                          const Divider(height: 0.5, thickness: 0.5, indent: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal Document Sheet (Terms of Service & Privacy Policy)
// ─────────────────────────────────────────────────────────────────────────────
class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection(this.heading, this.body);
}

const _termsSections = <_LegalSection>[
  _LegalSection(
    '1. Eligibility & Authentic Matrimonial Intent',
    'Mangalasutram is strictly a traditional Vedic matrimonial platform for individuals and families seeking lawful marriage alliances. Members must be at least 21 years of age (men) or 18 years of age (women) in accordance with applicable marriage laws. Casual dating or commercial solicitation is strictly prohibited.',
  ),
  _LegalSection(
    '2. Biodata & Horoscope Accuracy',
    'Members and linked Family Guardians warrant that all biographical, educational, professional, and Vedic astrological details (Gothram, Nakshatram, Raasi, and Birth details) provided are truthful and accurate.',
  ),
  _LegalSection(
    '3. Family Room & Guardian Proxy Conduct',
    'Candidates may invite up to 2 verified parents or guardians into their Family Circle. Candidates retain full veto power over Guardian proxy messaging at all times via Settings & Privacy.',
  ),
  _LegalSection(
    '4. Zero Tolerance for Harassment or Fraud',
    'Any profile found misrepresenting identity, marital status, or financial details, or engaging in disrespectful communication, will be permanently suspended without refund.',
  ),
];

const _privacySections = <_LegalSection>[
  _LegalSection(
    '1. End-to-End Encrypted (E2EE) Messaging',
    'All alliance conversations on Mangalasutram are protected using cryptographic room keys. Raw message tables store only encrypted ciphertext.',
  ),
  _LegalSection(
    '2. Contact & Horoscope Visibility Controls',
    'Your mobile number and email address are masked by default. You control whether your horoscope, phone number, and profile visibility are active or paused at any time in Settings & Privacy.',
  ),
  _LegalSection(
    '3. Storage & Photo Protection',
    'Uploaded photographs are protected by Row-Level Security (RLS) bucket policies and restricted to authenticated members.',
  ),
  _LegalSection(
    '4. Right to Permanent Erasure (Apple & Google Compliance)',
    'You may permanently delete your account at any time from Settings & Privacy > Delete Account. Upon confirmation, your biodata, photos, match cache, and conversations are immediately and irreversibly purged.',
  ),
];

class _LegalDocumentSheet extends StatelessWidget {
  final String title;
  final List<_LegalSection> sections;

  const _LegalDocumentSheet({
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8CFC4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B0912),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Color(0xFFB8AEA4),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final s = sections[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE6DFD5),
                      width: 0.7,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.heading,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.body,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6B5E54),
                          height: 1.48,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blocked Users Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _BlockedUsersSheet extends StatefulWidget {
  const _BlockedUsersSheet();

  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  final _moderationService = getIt<ModerationService>();
  List<BlockedUser> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final list = await _moderationService.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUsers = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    try {
      await _moderationService.unblockUser(user.id);
      setState(() {
        _blockedUsers.removeWhere((u) => u.id == user.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} has been unblocked.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
        minHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8CFC4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Blocked Members',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B0912),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Color(0xFFB8AEA4),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDE7DF)),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6E1732)),
                  )
                : _blockedUsers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_shield,
                            size: 44,
                            color: Color(0xFFC99A4B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Blocked Members',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2B0912),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Members you block will not be able to view your profile or message you.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF7A6A5E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blockedUsers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final u = _blockedUsers[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE6DFD5),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFF3ECE2),
                              backgroundImage: u.profilePhotoUrl != null
                                  ? NetworkImage(u.profilePhotoUrl!)
                                  : null,
                              child: u.profilePhotoUrl == null
                                  ? const Icon(
                                      CupertinoIcons.person_fill,
                                      color: Color(0xFF6E1732),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.fullName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1C1917),
                                    ),
                                  ),
                                  if (u.city != null && u.city!.isNotEmpty)
                                    Text(
                                      u.city!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF7A6A5E),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _unblock(u),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6E1732),
                              ),
                              child: Text(
                                'Unblock',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
