import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/lookup_option.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../../shared/widgets/luxury_date_picker.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditBasicInfoScreen extends StatefulWidget {
  const EditBasicInfoScreen({super.key});

  @override
  State<EditBasicInfoScreen> createState() => _EditBasicInfoScreenState();
}

class _EditBasicInfoScreenState extends State<EditBasicInfoScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _fullName = TextEditingController();
  final _dob = TextEditingController();
  final _height = TextEditingController();
  final _aboutMe = TextEditingController();
  final _maritalStatus = TextEditingController();
  final _motherTongue = TextEditingController();
  final _createdFor = TextEditingController();
  final _gender = TextEditingController();

  final List<LookupOption> _heightOptions = List.generate(48, (index) {
    final inches = 48 + index;
    final ft = inches ~/ 12;
    final ins = inches % 12;
    return LookupOption(id: inches, label: "$ft'$ins\"");
  });

  final List<LookupOption> _createdForOptions = [
    LookupOption(id: 1, label: 'Self'),
    LookupOption(id: 2, label: 'Son'),
    LookupOption(id: 3, label: 'Daughter'),
    LookupOption(id: 4, label: 'Brother'),
    LookupOption(id: 5, label: 'Sister'),
    LookupOption(id: 6, label: 'Friend'),
    LookupOption(id: 7, label: 'Relative'),
  ];

  final List<LookupOption> _genderOptions = [
    LookupOption(id: 1, label: 'Male'),
    LookupOption(id: 2, label: 'Female'),
  ];

  int? _selectedHeightId;
  LookupOption? _maritalStatusOpt;
  LookupOption? _motherTongueOpt;

  Map<String, List<LookupOption>>? _lookupData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _dob.dispose();
    _height.dispose();
    _aboutMe.dispose();
    _maritalStatus.dispose();
    _motherTongue.dispose();
    _createdFor.dispose();
    _gender.dispose();
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
    _fullName.text = profile.fullName;
    _dob.text = profile.dateOfBirth?.split('T')[0] ?? '';
    _selectedHeightId = profile.heightInches;
    if (_selectedHeightId != null) {
      final opt = _heightOptions.firstWhere(
        (e) => e.id == _selectedHeightId,
        orElse: () => LookupOption(id: 0, label: ''),
      );
      _height.text = opt.label;
    }

    _maritalStatus.text = _labelFor(
      profile.maritalStatusId,
      'marital_statuses',
    );
    _maritalStatusOpt = profile.maritalStatusId != null
        ? LookupOption(id: profile.maritalStatusId!, label: _maritalStatus.text)
        : null;

    _motherTongue.text = _labelFor(profile.motherTongueId, 'mother_tongues');
    _motherTongueOpt = profile.motherTongueId != null
        ? LookupOption(id: profile.motherTongueId!, label: _motherTongue.text)
        : null;

    _createdFor.text = profile.createdFor ?? '';
    _gender.text = profile.gender ?? '';

    _aboutMe.text = profile.aboutMe ?? '';

    setState(() => _loading = false);
  }

  String _labelFor(int? id, String tableKey) {
    if (id == null || _lookupData == null) return '';
    final list = _lookupData![tableKey] ?? [];
    try {
      return list.firstWhere((e) => e.id == id).label;
    } catch (_) {
      return '';
    }
  }

  Future<void> _showSelector(
    String title,
    String tableKey,
    TextEditingController c,
    LookupOption? currentOpt,
    void Function(LookupOption) onSelect,
  ) async {
    FocusScope.of(context).unfocus();
    final options = _lookupData?[tableKey] ?? [];

    final res = await BottomSheetSelector.show(
      context: context,
      title: title,
      options: options,
      selectedOption: currentOpt,
    );
    if (res != null && mounted) {
      setState(() {
        c.text = res.label;
        onSelect(res);
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    DateTime? initialDate;
    if (_dob.text.trim().isNotEmpty) {
      try {
        initialDate = DateTime.parse(_dob.text.trim());
      } catch (_) {}
    }

    final picked = await LuxuryDatePicker.show(
      context: context,
      initialDate: initialDate,
      title: 'Select Date of Birth',
    );

    if (picked != null && mounted) {
      setState(() {
        _dob.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_original == null) return;
    setState(() => _saving = true);

    final missing = <String>[];
    if (_fullName.text.trim().isEmpty) missing.add('Full Name');
    if (_dob.text.trim().isEmpty) missing.add('Date of Birth');
    if (_gender.text.trim().isEmpty) missing.add('Gender');
    if (_selectedHeightId == null) missing.add('Height');
    if (_maritalStatusOpt == null && _original?.maritalStatusId == null) {
      missing.add('Marital Status');
    }
    if (_motherTongueOpt == null && _original?.motherTongueId == null) {
      missing.add('Mother Tongue');
    }
    if (_createdFor.text.trim().isEmpty) missing.add('Created For');

    if (missing.isNotEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot leave critical fields empty: ${missing.join(', ')}',
          ),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
      return;
    }

    final patch = <String, dynamic>{};
    if (_fullName.text.trim() != (_original!.fullName)) {
      patch['full_name'] = _fullName.text.trim();
    }
    if (_dob.text.trim() != (_original!.dateOfBirth?.split('T')[0] ?? '')) {
      patch['date_of_birth'] = _dob.text.trim();
    }
    if (_selectedHeightId != null &&
        _selectedHeightId != _original!.heightInches) {
      patch['height_inches'] = _selectedHeightId;
    }
    final trimmedAbout = _aboutMe.text.trim();
    if (trimmedAbout != (_original!.aboutMe ?? '')) {
      patch['about_me'] = trimmedAbout.isNotEmpty ? trimmedAbout : null;
    }

    if (_maritalStatusOpt?.id != null &&
        _maritalStatusOpt!.id != _original!.maritalStatusId) {
      patch['marital_status_id'] = _maritalStatusOpt!.id;
    }
    if (_motherTongueOpt?.id != null &&
        _motherTongueOpt!.id != _original!.motherTongueId) {
      patch['mother_tongue_id'] = _motherTongueOpt!.id;
    }
    if (_createdFor.text.trim() != (_original!.createdFor ?? '')) {
      patch['created_for'] = _createdFor.text.trim();
    }
    if (_gender.text.trim() != (_original!.gender ?? '')) {
      patch['gender'] = _gender.text.trim();
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
            content: Text('Basic details saved successfully! ✨'),
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
          'Basic Details',
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
                    title: 'Personal Details',
                    children: [
                      AppleFormRow(
                        controller: _fullName,
                        label: 'Full Name',
                        hintText: 'Required',
                      ),
                      AppleFormRow(
                        controller: _dob,
                        label: 'Date of Birth',
                        hintText: 'Select Date of Birth',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: _pickDateOfBirth,
                      ),
                      AppleFormRow(
                        controller: _height,
                        label: 'Height',
                        hintText: 'Select Height',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final selectedOpt = _selectedHeightId != null
                              ? LookupOption(
                                  id: _selectedHeightId!,
                                  label: _height.text,
                                )
                              : null;
                          final result = await BottomSheetSelector.show(
                            context: context,
                            title: 'Select Height',
                            options: _heightOptions,
                            selectedOption: selectedOpt,
                          );
                          if (result != null && mounted) {
                            setState(() {
                              _selectedHeightId = result.id;
                              _height.text = result.label;
                            });
                          }
                        },
                      ),
                      AppleFormRow(
                        controller: _maritalStatus,
                        label: 'Marital Status',
                        hintText: 'Select Status',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showSelector(
                          'Marital Status',
                          'marital_statuses',
                          _maritalStatus,
                          _maritalStatusOpt,
                          (o) => _maritalStatusOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _motherTongue,
                        label: 'Mother Tongue',
                        hintText: 'Select Language',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showSelector(
                          'Mother Tongue',
                          'mother_tongues',
                          _motherTongue,
                          _motherTongueOpt,
                          (o) => _motherTongueOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _createdFor,
                        label: 'Created For',
                        hintText: 'Select',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final selectedOpt = _createdFor.text.isNotEmpty
                              ? LookupOption(id: 0, label: _createdFor.text)
                              : null;
                          final result = await BottomSheetSelector.show(
                            context: context,
                            title: 'Created For',
                            options: _createdForOptions,
                            selectedOption: selectedOpt,
                          );
                          if (result != null && mounted) {
                            setState(() => _createdFor.text = result.label);
                          }
                        },
                      ),
                      AppleFormRow(
                        controller: _gender,
                        label: 'Gender',
                        hintText: 'Select Gender',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final selectedOpt = _gender.text.isNotEmpty
                              ? LookupOption(id: 0, label: _gender.text)
                              : null;
                          final result = await BottomSheetSelector.show(
                            context: context,
                            title: 'Gender',
                            options: _genderOptions,
                            selectedOption: selectedOpt,
                          );
                          if (result != null && mounted) {
                            setState(() => _gender.text = result.label);
                          }
                        },
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'About',
                    children: [
                      AppleFormRow(
                        controller: _aboutMe,
                        label: 'About Me',
                        hintText: 'Write a few words about yourself...',
                        maxLines: 5,
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
