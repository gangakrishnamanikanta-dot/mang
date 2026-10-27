import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/lookup_option.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../../shared/widgets/luxury_time_picker.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditReligionScreen extends StatefulWidget {
  const EditReligionScreen({super.key});

  @override
  State<EditReligionScreen> createState() => _EditReligionScreenState();
}

class _EditReligionScreenState extends State<EditReligionScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);

  bool _loading = true;
  bool _saving = false;

  final _subCaste = TextEditingController();
  final _pravara = TextEditingController();
  final _kuladevata = TextEditingController();
  final _timeOfBirth = TextEditingController();
  final _placeOfBirth = TextEditingController();

  LookupOption? _casteOpt;
  LookupOption? _gothramOpt;
  LookupOption? _vedaShakhaOpt;
  LookupOption? _nakshatraOpt;
  LookupOption? _rashiOpt;
  LookupOption? _padaOpt;

  String? _sampradayam;
  String? _kujaDosham;
  String? _dailyPooja;
  String? _sandhyavandanam;
  String? _slokaChanting;
  String? _templeVisits;
  String? _festivalParticipation;

  Map<String, List<LookupOption>>? _lookupData;

  static final List<LookupOption> _sampradayamOptions = [
    LookupOption(id: 1, label: 'Smarta'),
    LookupOption(id: 2, label: 'Sri Vaishnava'),
    LookupOption(id: 3, label: 'Madhwa'),
    LookupOption(id: 4, label: 'Shaiva'),
    LookupOption(id: 5, label: 'Shakta'),
    LookupOption(id: 6, label: 'Vedic Traditional'),
    LookupOption(id: 7, label: 'General Hindu'),
  ];

  static final List<LookupOption> _kujaDoshamOptions = [
    LookupOption(id: 1, label: 'No'),
    LookupOption(id: 2, label: 'Yes'),
    LookupOption(id: 3, label: 'Anshik (Partial)'),
    LookupOption(id: 4, label: "Don't Know"),
  ];

  static final List<LookupOption> _dailyPoojaOptions = [
    LookupOption(id: 1, label: 'Daily'),
    LookupOption(id: 2, label: 'Weekly / Auspicious Days'),
    LookupOption(id: 3, label: 'Festivals Only'),
    LookupOption(id: 4, label: 'Occasionally'),
  ];

  static final List<LookupOption> _sandhyavandanamOptions = [
    LookupOption(id: 1, label: 'Trikala (3 times daily)'),
    LookupOption(id: 2, label: 'Daily (Morning/Evening)'),
    LookupOption(id: 3, label: 'Occasionally / Festivals'),
    LookupOption(id: 4, label: 'Not Applicable'),
  ];

  static final List<LookupOption> _slokaOptions = [
    LookupOption(id: 1, label: 'Daily'),
    LookupOption(id: 2, label: 'Regularly'),
    LookupOption(id: 3, label: 'Occasionally'),
    LookupOption(id: 4, label: 'Interested to Learn'),
  ];

  static final List<LookupOption> _templeVisitOptions = [
    LookupOption(id: 1, label: 'Multiple times a week'),
    LookupOption(id: 2, label: 'Weekly'),
    LookupOption(id: 3, label: 'Festivals & Auspicious Days'),
    LookupOption(id: 4, label: 'Occasionally'),
  ];

  static final List<LookupOption> _festivalOptions = [
    LookupOption(id: 1, label: 'Active & Traditional'),
    LookupOption(id: 2, label: 'With Family'),
    LookupOption(id: 3, label: 'Moderate'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subCaste.dispose();
    _pravara.dispose();
    _kuladevata.dispose();
    _timeOfBirth.dispose();
    _placeOfBirth.dispose();
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

    _subCaste.text = profile.subCaste ?? '';
    _pravara.text = profile.pravara ?? '';
    _kuladevata.text = profile.kuladevata ?? '';
    _timeOfBirth.text = profile.timeOfBirth ?? '';
    _placeOfBirth.text = profile.placeOfBirth ?? '';

    _casteOpt = profile.casteId != null
        ? LookupOption(
            id: profile.casteId!,
            label: _labelFor(profile.casteId, 'castes'),
          )
        : null;
    _gothramOpt = profile.gothramId != null
        ? LookupOption(
            id: profile.gothramId!,
            label: _labelFor(profile.gothramId, 'gothrams'),
          )
        : null;
    _vedaShakhaOpt = profile.vedaShakhaId != null
        ? LookupOption(
            id: profile.vedaShakhaId!,
            label: _labelFor(profile.vedaShakhaId, 'veda_shakhas'),
          )
        : null;
    _nakshatraOpt = profile.nakshatraId != null
        ? LookupOption(
            id: profile.nakshatraId!,
            label: _labelFor(profile.nakshatraId, 'nakshatras'),
          )
        : null;
    _rashiOpt = profile.rashiId != null
        ? LookupOption(
            id: profile.rashiId!,
            label: _labelFor(profile.rashiId, 'rashis'),
          )
        : null;

    final effectivePadaId = profile.padaId;
    _padaOpt = effectivePadaId != null
        ? LookupOption(
            id: effectivePadaId,
            label: _labelFor(effectivePadaId, 'padas').isNotEmpty
                ? _labelFor(effectivePadaId, 'padas')
                : 'Pada $effectivePadaId',
          )
        : null;

    _sampradayam = profile.sampradayam;
    _kujaDosham = profile.kujaDosham;
    _dailyPooja = profile.dailyPooja;
    _sandhyavandanam = profile.sandhyavandanam;
    _slokaChanting = profile.slokaChanting;
    _templeVisits = profile.templeVisits;
    _festivalParticipation = profile.festivalParticipation;

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
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'caste_id': _casteOpt?.id,
      'sub_caste':
          _subCaste.text.trim().isNotEmpty ? _subCaste.text.trim() : null,
      'gothram_id': _gothramOpt?.id,
      'pravara': _pravara.text.trim().isNotEmpty ? _pravara.text.trim() : null,
      'veda_shakha_id': _vedaShakhaOpt?.id,
      'sampradayam': _sampradayam,
      'kuladevata':
          _kuladevata.text.trim().isNotEmpty ? _kuladevata.text.trim() : null,
      'nakshatra_id': _nakshatraOpt?.id,
      'rashi_id': _rashiOpt?.id,
      'pada_id': _padaOpt?.id,
      'pada': _padaOpt?.id,
      'kuja_dosham': _kujaDosham,
      'is_manglik': _kujaDosham == 'Yes' || _kujaDosham == 'Anshik (Partial)',
      'time_of_birth': _timeOfBirth.text.trim().isNotEmpty
          ? _timeOfBirth.text.trim()
          : null,
      'place_of_birth': _placeOfBirth.text.trim().isNotEmpty
          ? _placeOfBirth.text.trim()
          : null,
      'daily_pooja': _dailyPooja,
      'sandhyavandanam': _sandhyavandanam,
      'sloka_chanting': _slokaChanting,
      'temple_visits': _templeVisits,
      'festival_participation': _festivalParticipation,
    };

    try {
      await _profileService.saveProfile(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vedic & Astrology details saved! ✨'),
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

  Future<void> _pickTimeOfBirth() async {
    FocusScope.of(context).unfocus();
    TimeOfDay initialTime = TimeOfDay.now();
    if (_timeOfBirth.text.trim().isNotEmpty) {
      try {
        final parts = _timeOfBirth.text.trim().split(':');
        int hour = int.parse(parts[0]);
        final minPeriod = parts[1].split(' ');
        int minute = int.parse(minPeriod[0]);
        if (minPeriod.length > 1 &&
            minPeriod[1].toUpperCase() == 'PM' &&
            hour < 12) {
          hour += 12;
        } else if (minPeriod.length > 1 &&
            minPeriod[1].toUpperCase() == 'AM' &&
            hour == 12) {
          hour = 0;
        }
        initialTime = TimeOfDay(hour: hour, minute: minute);
      } catch (_) {}
    }

    final picked = await LuxuryTimePicker.show(
      context: context,
      initialTime: initialTime,
      title: 'Select Time of Birth',
    );
    if (picked != null && mounted) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.pm ? 'PM' : 'AM';
      setState(() {
        _timeOfBirth.text = '$hour:$minute $period';
      });
    }
  }

  Future<void> _showLookupSelector(
    String title,
    String tableKey,
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
          'Vedic & Astrology',
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
                    title: 'Community & Lineage',
                    children: [
                      AppleFormRow(
                        label: 'Caste / Community',
                        value: _casteOpt?.label,
                        hintText: 'Select Community',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Community',
                          'castes',
                          _casteOpt,
                          (o) => _casteOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _subCaste,
                        label: 'Sub-caste',
                        hintText: 'e.g. Vaidiki Velanadu, Niyogi',
                      ),
                      AppleFormRow(
                        label: 'Gothram',
                        value: _gothramOpt?.label,
                        hintText: 'Select Gothram',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Gothram',
                          'gothrams',
                          _gothramOpt,
                          (o) => _gothramOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        controller: _pravara,
                        label: 'Pravara',
                        hintText: 'e.g. Trayarsheya, Pancharsheya',
                      ),
                      AppleFormRow(
                        label: 'Veda Shakha',
                        value: _vedaShakhaOpt?.label,
                        hintText: 'Select Shakha',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Veda Shakha',
                          'veda_shakhas',
                          _vedaShakhaOpt,
                          (o) => _vedaShakhaOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Sampradayam',
                        value: _sampradayam,
                        hintText: 'Select Tradition',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Select Sampradayam',
                          _sampradayamOptions,
                          _sampradayam,
                          (v) => _sampradayam = v,
                        ),
                      ),
                      AppleFormRow(
                        controller: _kuladevata,
                        label: 'Kuladevata',
                        hintText: 'Family Deity (Optional)',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Horoscope & Birth Star',
                    footer:
                        'Nakshatra and Pada power authentic Ashta-Koota (36-point Guna Milan) compatibility.',
                    children: [
                      AppleFormRow(
                        label: 'Nakshatra',
                        value: _nakshatraOpt?.label,
                        hintText: 'Select Birth Star',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Nakshatra',
                          'nakshatras',
                          _nakshatraOpt,
                          (o) => _nakshatraOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Rashi (Moon Sign)',
                        value: _rashiOpt?.label,
                        hintText: 'Select Rashi',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Rashi',
                          'rashis',
                          _rashiOpt,
                          (o) => _rashiOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Pada (Quarter)',
                        value: _padaOpt?.label,
                        hintText: 'Select Pada (1–4)',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Select Pada',
                          'padas',
                          _padaOpt,
                          (o) => _padaOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Kuja Dosham / Manglik',
                        value: _kujaDosham,
                        hintText: 'Select Status',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Kuja Dosham / Manglik',
                          _kujaDoshamOptions,
                          _kujaDosham,
                          (v) => _kujaDosham = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Time of Birth',
                        value: _timeOfBirth.text.isNotEmpty
                            ? _timeOfBirth.text
                            : null,
                        hintText: 'Optional (e.g. 10:30 AM)',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: _pickTimeOfBirth,
                      ),
                      AppleFormRow(
                        controller: _placeOfBirth,
                        label: 'Place of Birth',
                        hintText: 'City / Town (Optional)',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Spiritual & Vedic Observance',
                    children: [
                      AppleFormRow(
                        label: 'Daily Pooja',
                        value: _dailyPooja,
                        hintText: 'Select Frequency',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Daily Pooja',
                          _dailyPoojaOptions,
                          _dailyPooja,
                          (v) => _dailyPooja = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Sandhyavandanam',
                        value: _sandhyavandanam,
                        hintText: 'Select Practice',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Sandhyavandanam',
                          _sandhyavandanamOptions,
                          _sandhyavandanam,
                          (v) => _sandhyavandanam = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Sloka / Mantra Chanting',
                        value: _slokaChanting,
                        hintText: 'Select Practice',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Sloka / Mantra Chanting',
                          _slokaOptions,
                          _slokaChanting,
                          (v) => _slokaChanting = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Temple Visits',
                        value: _templeVisits,
                        hintText: 'Select Frequency',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Temple Visits',
                          _templeVisitOptions,
                          _templeVisits,
                          (v) => _templeVisits = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Festival Participation',
                        value: _festivalParticipation,
                        hintText: 'Select Level',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Festival Participation',
                          _festivalOptions,
                          _festivalParticipation,
                          (v) => _festivalParticipation = v,
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
