import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../../../models/partner_preference.dart';
import '../../auth/services/auth_service.dart';
import '../../../features/profile/services/profile_service.dart';
import '../../shared/services/lookup_service.dart';
import '../../auth/services/supabase_service.dart';
import '../../../shared/widgets/apple_scale_button.dart';
import '../../../main.dart';
import '../steps/step1_basic_info.dart';
import '../steps/step2_traditional.dart';
import '../steps/step3_education.dart';
import '../steps/step4_family.dart';
import '../steps/step5_lifestyle.dart';
import '../steps/step6_location.dart';
import '../steps/step7_partner_preferences.dart';
import '../steps/step7_review.dart';
import '../../../core/exceptions/app_exception.dart';

class ProfileBuilderLayout extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const ProfileBuilderLayout({super.key, this.initialData = const {}});

  @override
  State<ProfileBuilderLayout> createState() => _ProfileBuilderLayoutState();
}

class _ProfileBuilderLayoutState extends State<ProfileBuilderLayout> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();
  final AuthService _authService = getIt<AuthService>();

  late Map<String, dynamic> _formData;
  Map<String, List<LookupOption>>? _lookupData;
  int _currentStep = 0;
  final int _totalSteps = 8;
  bool _isLoading = false;
  String? _submitError;

  static const _steps = [
    'Basic Info',
    'Traditional',
    'Education & Career',
    'Family',
    'Lifestyle',
    'Location',
    'Partner Preferences',
    'Review & Submit',
  ];

  Profile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _lookupService.fetchAllProfileLookups(),
        _authService.getCurrentProfile(),
      ]);
      final profile = results[1] as Profile?;

      if (mounted) {
        setState(() {
          _lookupData = results[0] as Map<String, List<LookupOption>>?;
          _existingProfile = profile;
          if (profile != null) {
            _formData = {
              ...widget.initialData,
              if (profile.fullName.isNotEmpty) 'full_name': profile.fullName,
              if (profile.email.isNotEmpty) 'email': profile.email,
              if (profile.phone != null) 'phone': profile.phone,
              if (profile.gender != null) 'gender': profile.gender,
              if (profile.dateOfBirth != null)
                'date_of_birth': profile.dateOfBirth,
              if (profile.heightInches != null)
                'height_inches': profile.heightInches,
              if (profile.maritalStatusId != null)
                'marital_status_id': profile.maritalStatusId,
              if (profile.motherTongueId != null)
                'mother_tongue_id': profile.motherTongueId,
              if (profile.casteId != null) 'caste_id': profile.casteId,
              if (profile.subCaste != null) 'sub_caste': profile.subCaste,
              if (profile.gothramId != null) 'gothram_id': profile.gothramId,
              if (profile.pravara != null) 'pravara': profile.pravara,
              if (profile.vedaShakhaId != null)
                'veda_shakha_id': profile.vedaShakhaId,
              if (profile.nakshatraId != null)
                'nakshatra_id': profile.nakshatraId,
              if (profile.rashiId != null) 'rashi_id': profile.rashiId,
              if (profile.padaId != null) 'pada_id': profile.padaId,
              if (profile.horoscopeUrl != null)
                'horoscope_url': profile.horoscopeUrl,
              if (profile.highestEducationId != null)
                'highest_education_id': profile.highestEducationId,
              if (profile.college != null) 'college': profile.college,
              if (profile.occupationId != null)
                'occupation_id': profile.occupationId,
              if (profile.company != null) 'company': profile.company,
              if (profile.annualIncomeId != null)
                'annual_income_id': profile.annualIncomeId,
              if (profile.workLocation != null)
                'work_location': profile.workLocation,
              if (profile.fatherName != null) 'father_name': profile.fatherName,
              if (profile.fatherOccupation != null)
                'father_occupation': profile.fatherOccupation,
              if (profile.motherName != null) 'mother_name': profile.motherName,
              if (profile.motherOccupation != null)
                'mother_occupation': profile.motherOccupation,
              if (profile.familyTypeId != null)
                'family_type_id': profile.familyTypeId,
              if (profile.nativePlace != null)
                'native_place': profile.nativePlace,
              if (profile.brothersCount != null)
                'brothers_count': profile.brothersCount,
              if (profile.sistersCount != null)
                'sisters_count': profile.sistersCount,
              if (profile.countryId != null) 'country_id': profile.countryId,
              if (profile.state != null) 'state': profile.state,
              if (profile.city != null) 'city': profile.city,
              if (profile.foodPreferenceId != null)
                'food_preference_id': profile.foodPreferenceId,
              if (profile.smokingId != null) 'smoking_id': profile.smokingId,
              if (profile.drinkingId != null) 'drinking_id': profile.drinkingId,
              if (profile.aboutMe != null) 'about_me': profile.aboutMe,
              if (profile.hobbies != null) 'hobbies': profile.hobbies,
              if (profile.createdFor != null) 'created_for': profile.createdFor,
              if (profile.profilePhotoUrl != null)
                'profile_photo_url': profile.profilePhotoUrl,
              if (profile.additionalPhotoUrls != null)
                'additional_photo_urls': profile.additionalPhotoUrls,
            };
          } else {
            // New user: pre-fill email from Supabase Auth (Google/OTP sign-ups)
            final authEmail = SupabaseService.client.auth.currentUser?.email;
            if (authEmail != null && authEmail.isNotEmpty) {
              _formData = {...widget.initialData, 'email': authEmail};
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException
                  ? e.message
                  : 'Something went wrong. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final missing = <String>[];
      if ((_formData['full_name'] as String?)?.trim().isEmpty ?? true) {
        missing.add('Full Name');
      }
      if ((_formData['gender'] as String?)?.trim().isEmpty ?? true) {
        missing.add('Gender');
      }
      if ((_formData['date_of_birth'] as String?)?.trim().isEmpty ?? true) {
        missing.add('Date of Birth');
      }
      if (_formData['height_inches'] == null) missing.add('Height');
      if ((_formData['created_for'] as String?)?.trim().isEmpty ?? true) {
        missing.add('Profile Created For');
      }

      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Required fields: ${missing.join(', ')}'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      final missing = <String>[];
      if (_formData['marital_status_id'] == null) missing.add('Marital Status');
      if (_formData['mother_tongue_id'] == null) missing.add('Mother Tongue');
      if (_formData['caste_id'] == null) missing.add('Caste');

      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Required fields: ${missing.join(', ')}'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        getIt<AuthService>().signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthRouter()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _sendWelcomeEmail() async {
    // Only send once per user — check the flag on the existing profile
    if (_existingProfile?.welcomeEmailSent == true) return;

    try {
      final email = _formData['email'] as String?;
      final name = _formData['full_name'] as String? ?? 'User';
      if (email == null || email.isEmpty) return;

      final supabase = SupabaseService.client;
      await supabase.functions.invoke(
        'send-email',
        body: {
          'to': email,
          'type': 'welcome',
          'data': {'name': name, 'email': email},
        },
      );

      // Mark as sent so we never send again
      await supabase
          .from('profiles')
          .update({'welcome_email_sent': true})
          .eq('id', _existingProfile?.id ?? _formData['id'] as String? ?? '');
    } catch (e) {
      debugPrint('[ProfileBuilder] Welcome email failed: $e');
    }
  }

  bool _isEightCriticalFieldsValid() {
    final criticalFields = [
      'full_name',
      'gender',
      'date_of_birth',
      'height_inches',
      'marital_status_id',
      'mother_tongue_id',
      'caste_id',
      'created_for',
    ];

    int filled = 0;
    for (final field in criticalFields) {
      final value = _formData[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        filled++;
      }
    }
    return filled == criticalFields.length;
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _submitError = null;
    });
    if (!mounted) return;

    try {
      final Map<String, dynamic> dataToSave = Map<String, dynamic>.from(
        _formData,
      );
      final dynamic preferences = dataToSave.remove('preferences');

      await _profileService.saveProfile(dataToSave);

      if (preferences != null) {
        final prefsData = Map<String, dynamic>.from(preferences);
        final prefModel = PartnerPreference(
          profileId: '',
          minAge: prefsData['min_age'],
          maxAge: prefsData['max_age'],
          minHeightInches: prefsData['min_height_inches'],
          maxHeightInches: prefsData['max_height_inches'],
          kujaDoshamPreference: prefsData['kuja_dosham_preference'],
          preferredMaritalStatusIds: prefsData['preferred_marital_status_ids'],
          preferredMotherTongueIds: prefsData['preferred_mother_tongue_ids'],
          preferredCasteIds: prefsData['preferred_caste_ids'],
          preferredFoodIds: prefsData['preferred_food_ids'],
        );
        await _profileService.savePartnerPreferences(prefModel);
      }

      // Fire welcome email via edge function (non-blocking, only once per user)
      _sendWelcomeEmail();

      if (!mounted) return;

      // Tell the AuthProvider we updated the profile
      final navigator = Navigator.of(context);
      final authProvider = context.read<AuthProvider>();
      await authProvider.refreshProfile();

      if (!mounted) return;

      if (navigator.canPop()) {
        navigator.pop(); // Return to HomeScreen if in Edit Mode
      } else {
        // If we're at the root, force re-evaluation by AuthRouter
        navigator.pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = 'Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Step1BasicInfo(
          formData: _formData,
          onUpdate: _updateField,
          lookupData: _lookupData,
        );
      case 1:
        return Step2Traditional(
          formData: _formData,
          onUpdate: _updateField,
          lookupData: _lookupData,
        );
      case 2:
        return Step3Education(
          formData: _formData,
          onUpdate: _updateField,
          lookupData: _lookupData,
        );
      case 3:
        return Step4Family(
          formData: _formData,
          onUpdate: _updateField,
          lookupData: _lookupData,
        );
      case 4:
        return Step5Lifestyle(
          formData: _formData,
          onUpdate: _updateField,
          lookupData: _lookupData,
        );
      case 5:
        return Step6Location(
          formData: _formData,
          onUpdate: _updateField,
          lookupData: _lookupData,
        );
      case 6:
        return Step7PartnerPreferences(
          formData: _formData,
          onUpdate: _updateField,
        );
      case 7:
        return Step7Review(formData: _formData, lookupData: _lookupData);
      default:
        return Center(
          child: Text(
            'Step ${_currentStep + 1} Under Construction',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8f1), // Soft cream
      body: _lookupData == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6E1732)),
            )
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _prevStep,
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Color(0xFF1C1C1E),
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Step ${_currentStep + 1} of $_totalSteps',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8E8E93),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _steps[_currentStep],
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1C1E),
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20), // Balance back icon
                      ],
                    ),
                  ),

                  // Progress Bar
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: const Color(0xFFE5E5EA),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_currentStep + 1) / _totalSteps,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E1732),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(child: _buildStepContent()),

                  // Bottom CTA
                  Container(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E5EA), width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_submitError != null) ...[
                          Text(
                            _submitError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_currentStep < _totalSteps - 1)
                          AppleScaleButton(
                            onPressed: _nextStep,
                            text: 'Continue',
                            color: const Color(0xFF6E1732),
                            textColor: Colors.white,
                          )
                        else
                          AppleScaleButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (_isEightCriticalFieldsValid()) {
                                      _submit();
                                    } else {
                                      setState(() {
                                        _submitError =
                                            'Please complete the 8 critical fields (Name, Gender, DOB, Height, Marital Status, Mother Tongue, Caste, Created For) to activate your profile.';
                                      });
                                    }
                                  },
                            text: 'Complete Profile',
                            color: const Color(0xFF6E1732),
                            textColor: Colors.white,
                            isLoading: _isLoading,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
