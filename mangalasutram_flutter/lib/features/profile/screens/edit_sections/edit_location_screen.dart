import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/lookup_option.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditLocationScreen extends StatefulWidget {
  const EditLocationScreen({super.key});

  @override
  State<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends State<EditLocationScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _city = TextEditingController();
  final _state = TextEditingController();
  final _nativePlace = TextEditingController();
  final _workLocation = TextEditingController();

  LookupOption? _countryOpt;
  Map<String, List<LookupOption>>? _lookupData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _city.dispose();
    _state.dispose();
    _nativePlace.dispose();
    _workLocation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _profileService.getProfile(),
      _lookupService.fetchAllProfileLookups(),
    ]);
    if (!mounted) return;

    final profile = results[0] as Profile?;
    _lookupData = results[1] as Map<String, List<LookupOption>>?;

    if (profile == null) {
      setState(() => _loading = false);
      return;
    }
    _original = profile;
    _city.text = profile.city ?? '';
    _state.text = profile.state ?? '';
    _nativePlace.text = profile.nativePlace ?? '';
    _workLocation.text = profile.workLocation ?? '';

    final countries = _lookupData?['countries'] ?? [];
    if (profile.countryId != null && countries.isNotEmpty) {
      try {
        _countryOpt = countries.firstWhere((c) => c.id == profile.countryId);
      } catch (_) {}
    }

    setState(() => _loading = false);
  }

  Future<void> _showCountrySelector() async {
    FocusScope.of(context).unfocus();
    final countries = _lookupData?['countries'] ?? [];
    final res = await BottomSheetSelector.show(
      context: context,
      title: 'Select Country',
      options: countries,
      selectedOption: _countryOpt,
    );
    if (res != null && mounted) {
      setState(() {
        _countryOpt = res;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{
      'city': _city.text.trim().isNotEmpty ? _city.text.trim() : null,
      'state': _state.text.trim().isNotEmpty ? _state.text.trim() : null,
      'native_place': _nativePlace.text.trim().isNotEmpty
          ? _nativePlace.text.trim()
          : null,
      'work_location': _workLocation.text.trim().isNotEmpty
          ? _workLocation.text.trim()
          : null,
      'country_id': _countryOpt?.id,
    };

    try {
      await _profileService.saveProfile(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location details updated successfully! 📍'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Location & Residency',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
                    title: 'Current Residence',
                    children: [
                      AppleFormRow(
                        label: 'Country',
                        value: _countryOpt?.label,
                        hintText: 'Select Country',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: _showCountrySelector,
                      ),
                      AppleFormRow(
                        controller: _state,
                        label: 'State / Province',
                        hintText: 'e.g. Telangana, Andhra Pradesh',
                      ),
                      AppleFormRow(
                        controller: _city,
                        label: 'City',
                        hintText: 'e.g. Hyderabad, Vijayawada',
                      ),
                      AppleFormRow(
                        controller: _workLocation,
                        label: 'Work City',
                        hintText: 'Where you currently work (Optional)',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Ancestral Roots',
                    children: [
                      AppleFormRow(
                        controller: _nativePlace,
                        label: 'Native Place',
                        hintText: 'Ancestral Town / Village (Optional)',
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
