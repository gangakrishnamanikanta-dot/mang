class PartnerPreference {
  final String? id;
  final String profileId;
  final int? minAge;
  final int? maxAge;
  final int? minHeightInches;
  final int? maxHeightInches;
  final String? kujaDoshamPreference;
  final bool? excludeSameGotra;
  final List<int>? preferredEducationIds;
  final List<int>? preferredOccupationIds;
  final List<int>? preferredFamilyTypeIds;
  final List<int>? preferredSmokingIds;
  final List<int>? preferredDrinkingIds;
  final String? locationPreference;
  final int? preferredAnnualIncomeId;
  final List<int>? preferredMaritalStatusIds;
  final List<int>? preferredMotherTongueIds;
  final List<int>? preferredCasteIds;
  final List<int>? preferredFoodIds;

  PartnerPreference({
    this.id,
    required this.profileId,
    this.minAge,
    this.maxAge,
    this.minHeightInches,
    this.maxHeightInches,
    this.kujaDoshamPreference,
    this.excludeSameGotra,
    this.preferredEducationIds,
    this.preferredOccupationIds,
    this.preferredFamilyTypeIds,
    this.preferredSmokingIds,
    this.preferredDrinkingIds,
    this.locationPreference,
    this.preferredAnnualIncomeId,
    this.preferredMaritalStatusIds,
    this.preferredMotherTongueIds,
    this.preferredCasteIds,
    this.preferredFoodIds,
  });

  factory PartnerPreference.fromJson(Map<String, dynamic> json) {
    return PartnerPreference(
      id: json['id']?.toString(),
      profileId: json['profile_id'].toString(),
      minAge: json['min_age'] as int?,
      maxAge: json['max_age'] as int?,
      minHeightInches: json['min_height_inches'] as int?,
      maxHeightInches: json['max_height_inches'] as int?,
      kujaDoshamPreference: json['kuja_dosham_preference'] as String?,
      excludeSameGotra: json['exclude_same_gotra'] as bool?,
      preferredEducationIds:
          (json['preferred_education_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      preferredOccupationIds:
          (json['preferred_occupation_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      preferredFamilyTypeIds:
          (json['preferred_family_type_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      preferredSmokingIds:
          (json['preferred_smoking_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      preferredDrinkingIds:
          (json['preferred_drinking_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      locationPreference: json['location_preference'] as String?,
      preferredAnnualIncomeId: json['preferred_annual_income_id'] as int?,
      preferredMaritalStatusIds:
          (json['preferred_marital_status_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      preferredMotherTongueIds:
          (json['preferred_mother_tongue_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      preferredCasteIds: (json['preferred_caste_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      preferredFoodIds: (json['preferred_food_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'min_age': minAge,
      'max_age': maxAge,
      'min_height_inches': minHeightInches,
      'max_height_inches': maxHeightInches,
      'kuja_dosham_preference': kujaDoshamPreference,
      'exclude_same_gotra': excludeSameGotra ?? true,
      if (preferredEducationIds != null)
        'preferred_education_ids': preferredEducationIds,
      if (preferredOccupationIds != null)
        'preferred_occupation_ids': preferredOccupationIds,
      if (preferredFamilyTypeIds != null)
        'preferred_family_type_ids': preferredFamilyTypeIds,
      if (preferredSmokingIds != null)
        'preferred_smoking_ids': preferredSmokingIds,
      if (preferredDrinkingIds != null)
        'preferred_drinking_ids': preferredDrinkingIds,
      'location_preference': locationPreference ?? 'any',
      'preferred_annual_income_id': preferredAnnualIncomeId,
      if (preferredMaritalStatusIds != null)
        'preferred_marital_status_ids': preferredMaritalStatusIds,
      if (preferredMotherTongueIds != null)
        'preferred_mother_tongue_ids': preferredMotherTongueIds,
      if (preferredCasteIds != null) 'preferred_caste_ids': preferredCasteIds,
      if (preferredFoodIds != null) 'preferred_food_ids': preferredFoodIds,
    };
  }
}
