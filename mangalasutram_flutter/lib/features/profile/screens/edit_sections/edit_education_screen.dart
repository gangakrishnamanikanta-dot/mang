import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/lookup_option.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditEducationScreen extends StatefulWidget {
  const EditEducationScreen({super.key});

  @override
  State<EditEducationScreen> createState() => _EditEducationScreenState();
}

class _EditEducationScreenState extends State<EditEducationScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _education = TextEditingController();
  final _college = TextEditingController();
  final _occupation = TextEditingController();
  final _company = TextEditingController();
  final _income = TextEditingController();
  final _workLocation = TextEditingController();

  LookupOption? _educationOpt;
  LookupOption? _occupationOpt;
  LookupOption? _incomeOpt;
  String? _workType;
  String? _careerPreference;

  Map<String, List<LookupOption>>? _lookupData;

  static final List<LookupOption> _workTypeOptions = [
    LookupOption(id: 1, label: 'Work from Office'),
    LookupOption(id: 2, label: 'Hybrid'),
    LookupOption(id: 3, label: 'Remote / WFH'),
    LookupOption(id: 4, label: 'Business / Self-Employed'),
  ];

  static final List<LookupOption> _careerPreferenceOptions = [
    LookupOption(id: 1, label: 'Career-focused & Growth Oriented'),
    LookupOption(id: 2, label: 'Balanced Career & Family Life'),
    LookupOption(id: 3, label: 'Family-first & Flexible Hours'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _education.dispose();
    _college.dispose();
    _occupation.dispose();
    _company.dispose();
    _income.dispose();
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

    _education.text = _labelFor(profile.highestEducationId, 'education_levels');
    _educationOpt = profile.highestEducationId != null
        ? LookupOption(id: profile.highestEducationId!, label: _education.text)
        : null;

    _occupation.text = _labelFor(profile.occupationId, 'occupations');
    _occupationOpt = profile.occupationId != null
        ? LookupOption(id: profile.occupationId!, label: _occupation.text)
        : null;

    _income.text = _labelFor(profile.annualIncomeId, 'annual_incomes');
    _incomeOpt = profile.annualIncomeId != null
        ? LookupOption(id: profile.annualIncomeId!, label: _income.text)
        : null;

    _college.text = profile.college ?? '';
    _company.text = profile.company ?? '';
    _workLocation.text = profile.workLocation ?? '';
    _workType = profile.workType;
    _careerPreference = profile.careerPreference;

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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{};
    if (_educationOpt?.id != null &&
        _educationOpt!.id != _original!.highestEducationId) {
      patch['highest_education_id'] = _educationOpt!.id;
    }
    final collegeTrim = _college.text.trim();
    if (collegeTrim != (_original!.college ?? '')) {
      patch['college'] = collegeTrim.isNotEmpty ? collegeTrim : null;
    }
    if (_occupationOpt?.id != null &&
        _occupationOpt!.id != _original!.occupationId) {
      patch['occupation_id'] = _occupationOpt!.id;
    }
    final companyTrim = _company.text.trim();
    if (companyTrim != (_original!.company ?? '')) {
      patch['company'] = companyTrim.isNotEmpty ? companyTrim : null;
    }
    if (_incomeOpt?.id != null && _incomeOpt!.id != _original!.annualIncomeId) {
      patch['annual_income_id'] = _incomeOpt!.id;
    }
    final workLocTrim = _workLocation.text.trim();
    if (workLocTrim != (_original!.workLocation ?? '')) {
      patch['work_location'] = workLocTrim.isNotEmpty ? workLocTrim : null;
    }
    if (_workType != _original!.workType) {
      patch['work_type'] = _workType;
    }
    if (_careerPreference != _original!.careerPreference) {
      patch['career_preference'] = _careerPreference;
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
            content: Text('Education & career details saved! ✨'),
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

  Future<void> _showLookupSelector(
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

  Future<void> _showStringSelector(
    String title,
    List<LookupOption> options,
    String? currentValue,
    void Function(String) onSelect,
  ) async {
    FocusScope.of(context).unfocus();
    final selectedOpt = currentValue != null && currentValue.isNotEmpty
        ? LookupOption(id: 0, label: currentValue)
        : null;
    final res = await BottomSheetSelector.show(
      context: context,
      title: title,
      options: options,
      selectedOption: selectedOpt,
    );
    if (res != null && mounted) {
      setState(() {
        onSelect(res.label);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Education & Career',
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
                    title: 'Education',
                    children: [
                      AppleFormRow(
                        controller: _education,
                        label: 'Highest Degree',
                        hintText: 'Select Degree',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Highest Degree',
                          'education_levels',
                          _education,
                          _educationOpt,
                          (o) => _educationOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _college,
                        label: 'College / University',
                        hintText: 'Institution Name',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Career & Income',
                    children: [
                      AppleFormRow(
                        controller: _occupation,
                        label: 'Occupation',
                        hintText: 'Select Occupation',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Occupation',
                          'occupations',
                          _occupation,
                          _occupationOpt,
                          (o) => _occupationOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _company,
                        label: 'Company Name',
                        hintText: 'Employer / Organization',
                      ),
                      AppleFormRow(
                        controller: _income,
                        label: 'Annual Income',
                        hintText: 'Select Income',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Annual Income',
                          'annual_incomes',
                          _income,
                          _incomeOpt,
                          (o) => _incomeOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _workLocation,
                        label: 'Work Location',
                        hintText: 'City (e.g. Hyderabad, Bengaluru)',
                      ),
                      AppleFormRow(
                        label: 'Work Arrangement',
                        value: _workType,
                        hintText: 'Select Work Type',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Work Arrangement',
                          _workTypeOptions,
                          _workType,
                          (v) => _workType = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Career Outlook',
                        value: _careerPreference,
                        hintText: 'Select Preference',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Career Outlook',
                          _careerPreferenceOptions,
                          _careerPreference,
                          (v) => _careerPreference = v,
                        ),
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
