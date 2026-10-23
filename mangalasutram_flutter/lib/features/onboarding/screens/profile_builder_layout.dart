import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/di.dart';
import '../../../models/lookup_option.dart';
import '../../../models/profile.dart';
import '../../../models/partner_preference.dart';
import '../../auth/services/auth_service.dart';
import '../../../features/profile/services/profile_service.dart';
import '../../shared/services/lookup_service.dart';
import '../../auth/services/supabase_service.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../main.dart';
import '../steps/step1_basic_info.dart';
import '../steps/step2_traditional.dart';
import '../steps/step3_education.dart';
import '../steps/step4_family.dart';
import '../steps/step5_lifestyle.dart';
import '../steps/step6_location.dart';
import '../steps/step7_partner_preferences.dart';
import '../steps/step7_review.dart';
import '../widgets/onboarding_progress_header.dart';
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

  static const List<String> _stepCtaLabels = [
    'Continue to Vedic Horoscope →',
    'Continue to Education & Career →',
    'Continue to Family Details →',
    'Continue to Lifestyle & Values →',
    'Continue to Location Details →',
    'Continue to Partner Preferences →',
    'Review Sacred Profile →',
    'Complete & Find Matches ✨',
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
              if (profile.dateOfBirth != null) 'date_of_birth': profile.dateOfBirth,
              if (profile.heightInches != null) 'height_inches': profile.heightInches,
              if (profile.maritalStatusId != null) 'marital_status_id': profile.maritalStatusId,
              if (profile.motherTongueId != null) 'mother_tongue_id': profile.motherTongueId,
              if (profile.casteId != null) 'caste_id': profile.casteId,
              if (profile.subCaste != null) 'sub_caste': profile.subCaste,
              if (profile.gothramId != null) 'gothram_id': profile.gothramId,
              if (profile.pravara != null) 'pravara': profile.pravara,
              if (profile.vedaShakhaId != null) 'veda_shakha_id': profile.vedaShakhaId,
              if (profile.nakshatraId != null) 'nakshatra_id': profile.nakshatraId,
              if (profile.rashiId != null) 'rashi_id': profile.rashiId,
              if (profile.padaId != null) 'pada_id': profile.padaId,
              if (profile.timeOfBirth != null) 'time_of_birth': profile.timeOfBirth,
              if (profile.placeOfBirth != null) 'place_of_birth': profile.placeOfBirth,
              if (profile.horoscopeUrl != null) 'horoscope_url': profile.horoscopeUrl,
              if (profile.highestEducationId != null) 'highest_education_id': profile.highestEducationId,
              if (profile.college != null) 'college': profile.college,
              if (profile.occupationId != null) 'occupation_id': profile.occupationId,
              if (profile.company != null) 'company': profile.company,
              if (profile.annualIncomeId != null) 'annual_income_id': profile.annualIncomeId,
              if (profile.workLocation != null) 'work_location': profile.workLocation,
              if (profile.fatherName != null) 'father_name': profile.fatherName,
              if (profile.fatherOccupation != null) 'father_occupation': profile.fatherOccupation,
              if (profile.motherName != null) 'mother_name': profile.motherName,
              if (profile.motherOccupation != null) 'mother_occupation': profile.motherOccupation,
              if (profile.familyTypeId != null) 'family_type_id': profile.familyTypeId,
              if (profile.nativePlace != null) 'native_place': profile.nativePlace,
              if (profile.brothersCount != null) 'brothers_count': profile.brothersCount,
              if (profile.sistersCount != null) 'sisters_count': profile.sistersCount,
              if (profile.countryId != null) 'country_id': profile.countryId,
              if (profile.state != null) 'state': profile.state,
              if (profile.city != null) 'city': profile.city,
              if (profile.foodPreferenceId != null) 'food_preference_id': profile.foodPreferenceId,
              if (profile.smokingId != null) 'smoking_id': profile.smokingId,
              if (profile.drinkingId != null) 'drinking_id': profile.drinkingId,
              if (profile.aboutMe != null) 'about_me': profile.aboutMe,
              if (profile.hobbies != null) 'hobbies': profile.hobbies,
              if (profile.createdFor != null) 'created_for': profile.createdFor,
              if (profile.profilePhotoUrl != null) 'profile_photo_url': profile.profilePhotoUrl,
              if (profile.additionalPhotoUrls != null) 'additional_photo_urls': profile.additionalPhotoUrls,
            };
          } else {
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
              e is AppException ? e.message : 'Something went wrong. Please try again.',
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
    FocusScope.of(context).unfocus();

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
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please provide: ${missing.join(', ')}'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
        return;
      }
    }

    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
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

      await supabase
          .from('profiles')
          .update({'welcome_email_sent': true})
          .eq('id', _existingProfile?.id ?? _formData['id'] as String? ?? '');
    } catch (e) {
      debugPrint('[ProfileBuilder] Welcome email failed: $e');
    }
  }

  List<String> _getMissingRequiredFields() {
    final missing = <String>[];

    // Basic & Personal
    if ((_formData['full_name'] as String?)?.trim().isEmpty ?? true) missing.add('Full Name');
    if ((_formData['gender'] as String?)?.trim().isEmpty ?? true) missing.add('Gender');
    if ((_formData['date_of_birth'] as String?)?.trim().isEmpty ?? true) missing.add('Date of Birth');
    if (_formData['height_inches'] == null) missing.add('Height');
    if (_formData['marital_status_id'] == null) missing.add('Marital Status');
    if (_formData['mother_tongue_id'] == null) missing.add('Mother Tongue');
    if ((_formData['created_for'] as String?)?.trim().isEmpty ?? true) missing.add('Profile Created For');

    // Traditional & Vedic Astrology (Mandatory for Brahmin community)
    if (_formData['caste_id'] == null) missing.add('Caste / Sect');
    if (_formData['gothram_id'] == null) missing.add('Gothram');
    if (_formData['veda_shakha_id'] == null) missing.add('Veda Shakha');
    if (_formData['nakshatra_id'] == null) missing.add('Nakshatra (Birth Star)');
    if (_formData['rashi_id'] == null) missing.add('Rashi (Moon Sign)');

    // Education & Career
    if (_formData['highest_education_id'] == null) missing.add('Education');
    if (_formData['occupation_id'] == null) missing.add('Occupation');
    if (_formData['annual_income_id'] == null) missing.add('Annual Income');

    // Location
    if (_formData['country_id'] == null) missing.add('Country');
    if ((_formData['state'] as String?)?.trim().isEmpty ?? true) missing.add('State');
    if ((_formData['city'] as String?)?.trim().isEmpty ?? true) missing.add('City');

    return missing;
  }

  int _findStepForMissingField(String fieldName) {
    switch (fieldName) {
      case 'Full Name':
      case 'Gender':
      case 'Date of Birth':
      case 'Height':
      case 'Marital Status':
      case 'Mother Tongue':
      case 'Profile Created For':
        return 0;
      case 'Caste / Sect':
      case 'Gothram':
      case 'Veda Shakha':
      case 'Nakshatra (Birth Star)':
      case 'Rashi (Moon Sign)':
        return 1;
      case 'Education':
      case 'Occupation':
      case 'Annual Income':
        return 2;
      case 'Country':
      case 'State':
      case 'City':
        return 5;
      default:
        return 0;
    }
  }

  Future<void> _submit({bool allowIncomplete = false}) async {
    FocusScope.of(context).unfocus();

    final missing = _getMissingRequiredFields();
    if (missing.isNotEmpty && !allowIncomplete) {
      HapticFeedback.heavyImpact();
      final firstMissingStep = _findStepForMissingField(missing.first);

      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDF9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFC99A4B), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Complete Your Sacred Biodata',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6E1732),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mangalasutram authentic Guna Milan and Brahmin matchmaking requires these core details:',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5D4A3A)),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8DFD5)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: missing
                        .map((f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: Color(0xFF8B1E2D)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4A121A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Complete Details (${missing.first})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8B1E2D),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Save Draft & Explore',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        setState(() => _currentStep = firstMissingStep);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _submitError = null;
    });
    if (!mounted) return;

    try {
      final Map<String, dynamic> dataToSave = Map<String, dynamic>.from(
        _formData,
      );
      dataToSave['profile_completed'] = missing.isEmpty;
      final dynamic preferences = dataToSave.remove('preferences');

      await _profileService.saveProfile(dataToSave);

      if (preferences != null) {
        final prefsData = Map<String, dynamic>.from(preferences);
        final prefModel = PartnerPreference(
          profileId: '',
          minAge: prefsData['min_age'] as int?,
          maxAge: prefsData['max_age'] as int?,
          minHeightInches: prefsData['min_height_inches'] as int?,
          maxHeightInches: prefsData['max_height_inches'] as int?,
          kujaDoshamPreference: prefsData['kuja_dosham_preference'] as String?,
          preferredMaritalStatusIds: prefsData['preferred_marital_status_ids'] != null
              ? List<int>.from(prefsData['preferred_marital_status_ids'])
              : null,
          preferredMotherTongueIds: prefsData['preferred_mother_tongue_ids'] != null
              ? List<int>.from(prefsData['preferred_mother_tongue_ids'])
              : null,
          preferredCasteIds: prefsData['preferred_caste_ids'] != null
              ? List<int>.from(prefsData['preferred_caste_ids'])
              : null,
          preferredFoodIds: prefsData['preferred_food_ids'] != null
              ? List<int>.from(prefsData['preferred_food_ids'])
              : null,
          horoscopeMatchingRequired: prefsData['horoscope_matching_required'] as String?,
          preferredCountryIds: prefsData['preferred_country_ids'] != null
              ? List<int>.from(prefsData['preferred_country_ids'])
              : null,
          marriageVision: prefsData['marriage_vision'] as String?,
        );
        await _profileService.savePartnerPreferences(prefModel);
      }

      _sendWelcomeEmail();

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      await authProvider.refreshProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sacred Profile Created! A blessed union awaits your arrival. ✨'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthRouter()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[ProfileBuilderLayout _submit Error]: $e');
      if (!mounted) return;
      setState(() => _submitError = 'Failed to save profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          duration: const Duration(seconds: 8),
        ),
      );
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
    final ctaText = _stepCtaLabels[_currentStep];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F4EB), // Rich warm Vedic Cream canvas
      body: _lookupData == null
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6E1732),
                strokeWidth: 3,
              ),
            )
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Animated Progress & Header
                  OnboardingProgressHeader(
                    currentStep: _currentStep,
                    totalSteps: _totalSteps,
                    onBack: _prevStep,
                  ),

                  // Step Content with soft transition
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Container(
                        key: ValueKey<int>(_currentStep),
                        color: const Color(0xFFF9F4EB),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: MediaQuery.of(context).padding.bottom + 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        top: BorderSide(color: Color(0xFFEADBCE), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6E1732).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_submitError != null) ...[
                          Text(
                            _submitError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_currentStep < _totalSteps - 1)
                          ScaleButton(
                            onPressed: _nextStep,
                            text: ctaText,
                            color: const Color(0xFF6E1732),
                            textColor: Colors.white,
                            hasShadow: true,
                          )
                        else
                          ScaleButton(
                            onPressed: _isLoading ? null : () => _submit(),
                            text: ctaText,
                            color: const Color(0xFF6E1732),
                            textColor: Colors.white,
                            isLoading: _isLoading,
                            hasShadow: true,
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
