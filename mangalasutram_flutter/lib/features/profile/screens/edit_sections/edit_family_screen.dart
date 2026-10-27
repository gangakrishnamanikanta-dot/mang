import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/lookup_option.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditFamilyScreen extends StatefulWidget {
  const EditFamilyScreen({super.key});

  @override
  State<EditFamilyScreen> createState() => _EditFamilyScreenState();
}

class _EditFamilyScreenState extends State<EditFamilyScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _fatherName = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _motherName = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _brothers = TextEditingController();
  final _sisters = TextEditingController();
  final _nativePlace = TextEditingController();
  final _familyDescription = TextEditingController();

  LookupOption? _familyTypeOpt;
  String? _familyValues;
  Map<String, List<LookupOption>>? _lookupData;

  static final List<LookupOption> _familyValuesOptions = [
    LookupOption(id: 1, label: 'Traditional & Orthodox'),
    LookupOption(id: 2, label: 'Traditional Modern'),
    LookupOption(id: 3, label: 'Moderate & Cultured'),
    LookupOption(id: 4, label: 'Liberal'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fatherName.dispose();
    _fatherOccupation.dispose();
    _motherName.dispose();
    _motherOccupation.dispose();
    _brothers.dispose();
    _sisters.dispose();
    _nativePlace.dispose();
    _familyDescription.dispose();
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
    _fatherName.text = profile.fatherName ?? '';
    _fatherOccupation.text = profile.fatherOccupation ?? '';
    _motherName.text = profile.motherName ?? '';
    _motherOccupation.text = profile.motherOccupation ?? '';
    _brothers.text = (profile.brothersCount ?? '').toString();
    _sisters.text = (profile.sistersCount ?? '').toString();
    _nativePlace.text = profile.nativePlace ?? '';
    _familyDescription.text = profile.familyDescription ?? '';
    _familyValues = profile.familyValues;

    final familyTypes = _lookupData?['family_types'] ?? [];
    if (profile.familyTypeId != null && familyTypes.isNotEmpty) {
      try {
        _familyTypeOpt = familyTypes.firstWhere(
          (e) => e.id == profile.familyTypeId,
        );
      } catch (_) {}
    }

    setState(() => _loading = false);
  }

  Future<void> _showFamilyTypeSelector() async {
    FocusScope.of(context).unfocus();
    final options = _lookupData?['family_types'] ?? [];
    final res = await BottomSheetSelector.show(
      context: context,
      title: 'Family Type',
      options: options,
      selectedOption: _familyTypeOpt,
    );
    if (res != null && mounted) {
      setState(() {
        _familyTypeOpt = res;
      });
    }
  }

  Future<void> _showFamilyValuesSelector() async {
    FocusScope.of(context).unfocus();
    final selectedOpt = _familyValues != null && _familyValues!.isNotEmpty
        ? LookupOption(id: 0, label: _familyValues!)
        : null;
    final res = await BottomSheetSelector.show(
      context: context,
      title: 'Family Values',
      options: _familyValuesOptions,
      selectedOption: selectedOpt,
    );
    if (res != null && mounted) {
      setState(() {
        _familyValues = res.label;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{};
    if (_familyTypeOpt?.id != _original!.familyTypeId) {
      patch['family_type_id'] = _familyTypeOpt?.id;
    }
    if (_familyValues != _original!.familyValues) {
      patch['family_values'] = _familyValues;
    }
    final fatherNameTrim = _fatherName.text.trim();
    if (fatherNameTrim != (_original!.fatherName ?? '')) {
      patch['father_name'] = fatherNameTrim.isNotEmpty ? fatherNameTrim : null;
    }
    final fatherOccTrim = _fatherOccupation.text.trim();
    if (fatherOccTrim != (_original!.fatherOccupation ?? '')) {
      patch['father_occupation'] =
          fatherOccTrim.isNotEmpty ? fatherOccTrim : null;
    }
    final motherNameTrim = _motherName.text.trim();
    if (motherNameTrim != (_original!.motherName ?? '')) {
      patch['mother_name'] = motherNameTrim.isNotEmpty ? motherNameTrim : null;
    }
    final motherOccTrim = _motherOccupation.text.trim();
    if (motherOccTrim != (_original!.motherOccupation ?? '')) {
      patch['mother_occupation'] =
          motherOccTrim.isNotEmpty ? motherOccTrim : null;
    }
    final nativePlaceTrim = _nativePlace.text.trim();
    if (nativePlaceTrim != (_original!.nativePlace ?? '')) {
      patch['native_place'] =
          nativePlaceTrim.isNotEmpty ? nativePlaceTrim : null;
    }
    final familyDescTrim = _familyDescription.text.trim();
    if (familyDescTrim != (_original!.familyDescription ?? '')) {
      patch['family_description'] =
          familyDescTrim.isNotEmpty ? familyDescTrim : null;
    }

    final br = int.tryParse(_brothers.text.trim());
    if (br != _original!.brothersCount) {
      patch['brothers_count'] = br;
    }

    final sr = int.tryParse(_sisters.text.trim());
    if (sr != _original!.sistersCount) {
      patch['sisters_count'] = sr;
    }

    if (patch.isEmpty) {
      setState(() => _saving = false);
      Navigator.pop(context);
      return;
    }

    try {
      await _profileService.saveProfile(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Family details saved successfully! ✨'),
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
          'Family Details',
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
                    title: 'Family Structure & Values',
                    children: [
                      AppleFormRow(
                        label: 'Family Type',
                        value: _familyTypeOpt?.label,
                        hintText: 'Select Family Type',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: _showFamilyTypeSelector,
                      ),
                      AppleFormRow(
                        label: 'Family Values',
                        value: _familyValues,
                        hintText: 'Select Values',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: _showFamilyValuesSelector,
                      ),
                      AppleFormRow(
                        controller: _nativePlace,
                        label: 'Native Place',
                        hintText: 'Ancestral Town / District',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Parents',
                    children: [
                      AppleFormRow(
                        controller: _fatherName,
                        label: "Father's Name",
                        hintText: 'Full Name',
                      ),
                      AppleFormRow(
                        controller: _fatherOccupation,
                        label: "Father's Occupation",
                        hintText: 'Profession / Retired',
                      ),
                      AppleFormRow(
                        controller: _motherName,
                        label: "Mother's Name",
                        hintText: 'Full Name',
                      ),
                      AppleFormRow(
                        controller: _motherOccupation,
                        label: "Mother's Occupation",
                        hintText: 'Homemaker / Profession',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Siblings',
                    children: [
                      AppleFormRow(
                        controller: _brothers,
                        label: 'Brothers',
                        hintText: '0',
                        keyboardType: TextInputType.number,
                      ),
                      AppleFormRow(
                        controller: _sisters,
                        label: 'Sisters',
                        hintText: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'About Family',
                    children: [
                      AppleFormRow(
                        controller: _familyDescription,
                        label: 'Family Background',
                        hintText:
                            'Share a few lines about your family traditions, heritage, and members...',
                        maxLines: 4,
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
