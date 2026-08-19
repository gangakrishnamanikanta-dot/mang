import 'package:flutter/material.dart';
import '../../../../core/di.dart';
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

  Map<String, List<LookupOption>>? _lookupData;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{};
    if (_educationOpt?.id != null &&
        _educationOpt!.id != _original!.highestEducationId) {
      patch['highest_education_id'] = _educationOpt!.id;
    }
    if (_college.text != (_original!.college ?? '')) {
      patch['college'] = _college.text;
    }
    if (_occupationOpt?.id != null &&
        _occupationOpt!.id != _original!.occupationId) {
      patch['occupation_id'] = _occupationOpt!.id;
    }
    if (_company.text != (_original!.company ?? '')) {
      patch['company'] = _company.text;
    }
    if (_incomeOpt?.id != null && _incomeOpt!.id != _original!.annualIncomeId) {
      patch['annual_income_id'] = _incomeOpt!.id;
    }
    if (_workLocation.text != (_original!.workLocation ?? '')) {
      patch['work_location'] = _workLocation.text;
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

  void _showSelector(
    String type,
    TextEditingController c,
    void Function(LookupOption) onSelect,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _burgundy)),
    );

    String table = type;
    if (type == 'education') table = 'education_levels';
    if (type == 'occupation') table = 'occupations';
    if (type == 'income') table = 'annual_incomes';

    final options = await _lookupService.fetchTable(table);
    if (!mounted) return;
    Navigator.pop(context);

    if (!mounted) return;
    final res = await BottomSheetSelector.show(
      context: context,
      title: type.toUpperCase(),
      options: options,
    );
    if (res != null) {
      setState(() {
        c.text = res.label;
        onSelect(res);
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
                    title: 'Education',
                    children: [
                      AppleFormRow(
                        controller: _education,
                        label: 'Highest Degree',
                        hintText: 'Select Degree',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showSelector(
                          'education',
                          _education,
                          (o) => _educationOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _college,
                        label: 'College',
                        hintText: 'College / University Name',
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
                        onTap: () => _showSelector(
                          'occupation',
                          _occupation,
                          (o) => _occupationOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _company,
                        label: 'Company Name',
                        hintText: 'Where do you work?',
                      ),
                      AppleFormRow(
                        controller: _income,
                        label: 'Annual Income',
                        hintText: 'Select Income',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showSelector(
                          'income',
                          _income,
                          (o) => _incomeOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _workLocation,
                        label: 'Work Location',
                        hintText: 'City',
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
