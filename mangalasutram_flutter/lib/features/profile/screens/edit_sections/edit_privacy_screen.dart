import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/di.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../services/profile_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditPrivacyScreen extends StatefulWidget {
  const EditPrivacyScreen({super.key});

  @override
  State<EditPrivacyScreen> createState() => _EditPrivacyScreenState();
}

class _EditPrivacyScreenState extends State<EditPrivacyScreen> {
  final ProfileService _profileService = getIt<ProfileService>();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  bool _hideMobile = false;
  bool _hideEmail = false;
  bool _showHoroscope = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileService.getProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }
    _original = profile;
    _hideMobile = profile.hideMobile ?? false;
    _hideEmail = profile.hideEmail ?? false;
    _showHoroscope = profile.showHoroscope ?? false;

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{};
    if (_hideMobile != (_original!.hideMobile ?? false)) {
      patch['hide_mobile'] = _hideMobile;
    }
    if (_hideEmail != (_original!.hideEmail ?? false)) {
      patch['hide_email'] = _hideEmail;
    }
    if (_showHoroscope != (_original!.showHoroscope ?? false)) {
      patch['show_horoscope'] = _showHoroscope;
    }

    if (patch.isEmpty) {
      setState(() => _saving = false);
      Navigator.pop(context);
      return;
    }

    try {
      await _profileService.saveProfile(patch);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException
                  ? e.message
                  : 'Something went wrong. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSwitchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value,
            activeTrackColor: _burgundy,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Privacy Settings',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: _burgundy),
        actions: [
          _saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _burgundy,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: _burgundy,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : SingleChildScrollView(
              child: Column(
                children: [
                  AppleFormSection(
                    title: 'Contact Privacy',
                    children: [
                      _buildSwitchRow(
                        'Hide Mobile Number',
                        'Only premium members can see your number',
                        _hideMobile,
                        (val) => setState(() => _hideMobile = val),
                      ),
                      _buildSwitchRow(
                        'Hide Email Address',
                        'Keep your email private from all users',
                        _hideEmail,
                        (val) => setState(() => _hideEmail = val),
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Profile Privacy',
                    children: [
                      _buildSwitchRow(
                        'Show Horoscope',
                        'Allow others to view your matched compatibility',
                        _showHoroscope,
                        (val) => setState(() => _showHoroscope = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
