class Profile {
  final String id;
  final String email;
  final String? phone;

  // Basic Info
  final String fullName;
  final String? gender;
  final String? dateOfBirth;
  final int? heightInches;
  final int? maritalStatusId;
  final int? motherTongueId;
  final int? casteId;
  final String? subCaste;

  // Religious / Traditional (Brahmin-specific)
  final int? gothramId;
  final String? pravara;
  final int? vedaShakhaId;
  final int? nakshatraId;
  final int? rashiId;
  final int? padaId;
  final String? horoscopeUrl;
  final String? kujaDosham;

  // Education & Career
  final int? highestEducationId;
  final String? college;
  final int? occupationId;
  final String? company;
  final int? annualIncomeId;
  final String? workLocation;

  // Family
  final String? fatherName;
  final String? fatherOccupation;
  final String? motherName;
  final String? motherOccupation;
  final int? familyTypeId;
  final String? nativePlace;
  final int? brothersCount;
  final int? sistersCount;
  final int? countryId;
  final String? state;
  final String? city;

  // Lifestyle
  final int? foodPreferenceId;
  final int? smokingId;
  final int? drinkingId;
  final String? aboutMe;
  final List<String>? hobbies;

  // Photos
  final String? profilePhotoUrl;
  final List<String>? additionalPhotoUrls;

  // Privacy
  final bool? hideMobile;
  final bool? hideEmail;
  final bool? showHoroscope;
  final int? profileVisibilityId;

  // Meta
  final bool profileCompleted;
  final bool? termsAccepted;
  final bool welcomeEmailSent;
  final String? createdFor;
  final bool isVerified;
  final String createdAt;
  final String updatedAt;

  Profile({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    this.heightInches,
    this.maritalStatusId,
    this.motherTongueId,
    this.casteId,
    this.subCaste,
    this.gothramId,
    this.pravara,
    this.vedaShakhaId,
    this.nakshatraId,
    this.rashiId,
    this.padaId,
    this.horoscopeUrl,
    this.kujaDosham,
    this.highestEducationId,
    this.college,
    this.occupationId,
    this.company,
    this.annualIncomeId,
    this.workLocation,
    this.fatherName,
    this.fatherOccupation,
    this.motherName,
    this.motherOccupation,
    this.familyTypeId,
    this.nativePlace,
    this.brothersCount,
    this.sistersCount,
    this.countryId,
    this.state,
    this.city,
    this.foodPreferenceId,
    this.smokingId,
    this.drinkingId,
    this.aboutMe,
    this.hobbies,
    this.profilePhotoUrl,
    this.additionalPhotoUrls,
    this.hideMobile,
    this.hideEmail,
    this.showHoroscope,
    this.profileVisibilityId,
    this.profileCompleted = false,
    this.termsAccepted,
    this.welcomeEmailSent = false,
    this.createdFor,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'].toString(),
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String? ?? '',
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      heightInches: json['height_inches']?.toInt(),
      maritalStatusId: json['marital_status_id'] as int?,
      motherTongueId: json['mother_tongue_id'] as int?,
      casteId: json['caste_id'] as int?,
      subCaste: json['sub_caste'] as String?,
      gothramId: json['gothram_id'] as int?,
      pravara: json['pravara'] as String?,
      vedaShakhaId: json['veda_shakha_id'] as int?,
      nakshatraId: json['nakshatra_id'] as int?,
      rashiId: json['rashi_id'] as int?,
      padaId: json['pada_id'] as int?,
      horoscopeUrl: json['horoscope_url'] as String?,
      kujaDosham: json['kuja_dosham'] as String?,
      highestEducationId: json['highest_education_id'] as int?,
      college: json['college'] as String?,
      occupationId: json['occupation_id'] as int?,
      company: json['company'] as String?,
      annualIncomeId: json['annual_income_id'] as int?,
      workLocation: json['work_location'] as String?,
      fatherName: json['father_name'] as String?,
      fatherOccupation: json['father_occupation'] as String?,
      motherName: json['mother_name'] as String?,
      motherOccupation: json['mother_occupation'] as String?,
      familyTypeId: json['family_type_id'] as int?,
      nativePlace: json['native_place'] as String?,
      brothersCount: json['brothers_count'] as int?,
      sistersCount: json['sisters_count'] as int?,
      countryId: json['country_id'] as int?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      foodPreferenceId: json['food_preference_id'] as int?,
      smokingId: json['smoking_id'] as int?,
      drinkingId: json['drinking_id'] as int?,
      aboutMe: json['about_me'] as String?,
      hobbies: json['hobbies'] != null
          ? List<String>.from(json['hobbies'])
          : null,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      additionalPhotoUrls: json['additional_photo_urls'] != null
          ? List<String>.from(json['additional_photo_urls'])
          : null,
      hideMobile: json['hide_mobile'] as bool?,
      hideEmail: json['hide_email'] as bool?,
      showHoroscope: json['show_horoscope'] as bool?,
      profileVisibilityId: json['profile_visibility_id'] as int?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      termsAccepted: json['terms_accepted'] as bool?,
      welcomeEmailSent: json['welcome_email_sent'] as bool? ?? false,
      createdFor: json['created_for'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'phone': phone,
      'height_inches': heightInches,
      'marital_status_id': maritalStatusId,
      'mother_tongue_id': motherTongueId,
      'caste_id': casteId,
      'sub_caste': subCaste,
      'gothram_id': gothramId,
      'pravara': pravara,
      'veda_shakha_id': vedaShakhaId,
      'nakshatra_id': nakshatraId,
      'rashi_id': rashiId,
      'pada_id': padaId,
      'horoscope_url': horoscopeUrl,
      'kuja_dosham': kujaDosham,
      'highest_education_id': highestEducationId,
      'college': college,
      'occupation_id': occupationId,
      'company': company,
      'annual_income_id': annualIncomeId,
      'work_location': workLocation,
      'father_name': fatherName,
      'father_occupation': fatherOccupation,
      'mother_name': motherName,
      'mother_occupation': motherOccupation,
      'family_type_id': familyTypeId,
      'native_place': nativePlace,
      'brothers_count': brothersCount,
      'sisters_count': sistersCount,
      'country_id': countryId,
      'state': state,
      'city': city,
      'food_preference_id': foodPreferenceId,
      'smoking_id': smokingId,
      'drinking_id': drinkingId,
      'about_me': aboutMe,
      'hobbies': hobbies,
      'profile_photo_url': profilePhotoUrl,
      'additional_photo_urls': additionalPhotoUrls,
      'hide_mobile': hideMobile,
      'hide_email': hideEmail,
      'show_horoscope': showHoroscope,
      'profile_visibility_id': profileVisibilityId,
      'terms_accepted': termsAccepted,
      'welcome_email_sent': welcomeEmailSent,
      'created_for': createdFor,
      'is_verified': isVerified,
    };
  }

  int get completionScore {
    final requiredFields = [
      fullName,
      gender,
      dateOfBirth,
      heightInches,
      maritalStatusId,
      motherTongueId,
      casteId,
      phone,
      email,
      createdFor,
      highestEducationId,
      occupationId,
      workLocation,
      countryId,
      state,
      city,
      fatherName,
      motherName,
      nativePlace,
      profilePhotoUrl,
    ];
    int filled = 0;
    for (final field in requiredFields) {
      if (field != null && field.toString().trim().isNotEmpty) {
        filled++;
      }
    }
    return ((filled / requiredFields.length) * 100).toInt();
  }
}

class LookupOption {
  final int id;
  final String label;

  LookupOption({required this.id, required this.label});

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    return LookupOption(id: json['id'] as int, label: json['label'] as String);
  }
}
