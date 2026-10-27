import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di.dart';
import '../../../../models/lookup_option.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditLifestyleScreen extends StatefulWidget {
  const EditLifestyleScreen({super.key});

  @override
  State<EditLifestyleScreen> createState() => _EditLifestyleScreenState();
}

class _EditLifestyleScreenState extends State<EditLifestyleScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);
  static const Color _gold = Color(0xFFC99A4B);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _aboutMe = TextEditingController();
  final _hobbies = TextEditingController();

  LookupOption? _foodPreferenceOpt;
  LookupOption? _smokingOpt;
  LookupOption? _drinkingOpt;

  String? _fitnessHabits;
  String? _personalityType;
  String? _spiritualLevel;
  Set<String> _selectedCulturalInterests = {};

  Map<String, List<LookupOption>>? _lookupData;

  static final List<LookupOption> _fitnessOptions = [
    LookupOption(id: 1, label: 'Daily Workout / Yoga'),
    LookupOption(id: 2, label: 'Regular Exercise (3-4x/week)'),
    LookupOption(id: 3, label: 'Active Lifestyle / Walking'),
    LookupOption(id: 4, label: 'Occasional'),
  ];

  static final List<LookupOption> _personalityOptions = [
    LookupOption(id: 1, label: 'Warm & Family-Oriented'),
    LookupOption(id: 2, label: 'Calm & Spiritual'),
    LookupOption(id: 3, label: 'Ambitious & Grounded'),
    LookupOption(id: 4, label: 'Creative & Expressive'),
    LookupOption(id: 5, label: 'Intellectual & Thoughtful'),
  ];

  static final List<LookupOption> _spiritualLevelOptions = [
    LookupOption(id: 1, label: 'Deeply Spiritual & Observant'),
    LookupOption(id: 2, label: 'Balanced Traditional & Modern'),
    LookupOption(id: 3, label: 'Culturally Rooted'),
    LookupOption(id: 4, label: 'Spiritual at Heart'),
  ];

  static const List<String> _culturalInterestPresets = [
    'Carnatic Music',
    'Classical Dance',
    'Vedic Literature',
    'Temple Architecture',
    'Sanskrit & Shlokas',
    'Traditional Cuisine',
    'Pilgrimage & Travel',
    'Yoga & Meditation',
    'Fine Arts',
    'Classical Instruments',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _aboutMe.dispose();
    _hobbies.dispose();
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
    _aboutMe.text = profile.aboutMe ?? '';
    _hobbies.text = (profile.hobbies ?? []).join(', ');
    _fitnessHabits = profile.fitnessHabits;
    _personalityType = profile.personalityType;
    _spiritualLevel = profile.spiritualLevel;
    _selectedCulturalInterests = Set<String>.from(
      profile.culturalInterests ?? [],
    );

    final foodOpts = _lookupData?['food_preferences'] ?? [];
    if (profile.foodPreferenceId != null && foodOpts.isNotEmpty) {
      try {
        _foodPreferenceOpt = foodOpts.firstWhere(
          (e) => e.id == profile.foodPreferenceId,
        );
      } catch (_) {}
    }

    final smokeOpts = _lookupData?['smoking_habits'] ?? [];
    if (profile.smokingId != null && smokeOpts.isNotEmpty) {
      try {
        _smokingOpt = smokeOpts.firstWhere((e) => e.id == profile.smokingId);
      } catch (_) {}
    }

    final drinkOpts = _lookupData?['drinking_habits'] ?? [];
    if (profile.drinkingId != null && drinkOpts.isNotEmpty) {
      try {
        _drinkingOpt = drinkOpts.firstWhere((e) => e.id == profile.drinkingId);
      } catch (_) {}
    }

    setState(() => _loading = false);
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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_original == null) return;
    setState(() => _saving = true);

    final hobbiesList = _hobbies.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final culturalList = _selectedCulturalInterests.toList();

    final patch = <String, dynamic>{
      'about_me':
          _aboutMe.text.trim().isNotEmpty ? _aboutMe.text.trim() : null,
      'hobbies': hobbiesList.isNotEmpty ? hobbiesList : null,
      'cultural_interests': culturalList.isNotEmpty ? culturalList : null,
      'food_preference_id': _foodPreferenceOpt?.id,
      'smoking_id': _smokingOpt?.id,
      'drinking_id': _drinkingOpt?.id,
      'fitness_habits': _fitnessHabits,
      'personality_type': _personalityType,
      'spiritual_level': _spiritualLevel,
    };

    try {
      await _profileService.saveProfile(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lifestyle details updated successfully! ✨'),
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
    final allCulturalOptions = <String>{
      ..._culturalInterestPresets,
      ..._selectedCulturalInterests,
    }.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Habits & Lifestyle',
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
                    title: 'Diet & Daily Habits',
                    children: [
                      AppleFormRow(
                        label: 'Food Preference',
                        value: _foodPreferenceOpt?.label,
                        hintText: 'Select Diet',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Food Preference',
                          'food_preferences',
                          _foodPreferenceOpt,
                          (o) => _foodPreferenceOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Smoking Habits',
                        value: _smokingOpt?.label,
                        hintText: 'Select Option',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Smoking Habits',
                          'smoking_habits',
                          _smokingOpt,
                          (o) => _smokingOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Drinking Habits',
                        value: _drinkingOpt?.label,
                        hintText: 'Select Option',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showLookupSelector(
                          'Drinking Habits',
                          'drinking_habits',
                          _drinkingOpt,
                          (o) => _drinkingOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Fitness & Wellness',
                        value: _fitnessHabits,
                        hintText: 'Select Routine',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Fitness & Wellness',
                          _fitnessOptions,
                          _fitnessHabits,
                          (v) => _fitnessHabits = v,
                        ),
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Personality & Spiritual Outlook',
                    children: [
                      AppleFormRow(
                        label: 'Personality Type',
                        value: _personalityType,
                        hintText: 'Select Nature',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Personality Type',
                          _personalityOptions,
                          _personalityType,
                          (v) => _personalityType = v,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Spiritual Outlook',
                        value: _spiritualLevel,
                        hintText: 'Select Outlook',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showStringSelector(
                          'Spiritual Outlook',
                          _spiritualLevelOptions,
                          _spiritualLevel,
                          (v) => _spiritualLevel = v,
                        ),
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Cultural & Artistic Interests',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: allCulturalOptions.map((item) {
                            final selected = _selectedCulturalInterests
                                .contains(item);
                            return FilterChip(
                              label: Text(
                                item,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF2C2520),
                                ),
                              ),
                              selected: selected,
                              selectedColor: _burgundy,
                              checkmarkColor: _gold,
                              backgroundColor: const Color(0xFFFBF8F1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected
                                      ? _burgundy
                                      : const Color(0xFFE0D6C8),
                                ),
                              ),
                              onSelected: (val) {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  if (val) {
                                    _selectedCulturalInterests.add(item);
                                  } else {
                                    _selectedCulturalInterests.remove(item);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Hobbies & Bio',
                    children: [
                      AppleFormRow(
                        controller: _hobbies,
                        label: 'Hobbies & Interests',
                        hintText: 'e.g. Classical Music, Reading, Chess',
                      ),
                      AppleFormRow(
                        controller: _aboutMe,
                        label: 'About Me',
                        hintText: 'Share a brief summary about your values...',
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
