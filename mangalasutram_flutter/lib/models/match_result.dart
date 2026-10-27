import 'profile.dart';

class MatchResult {
  final String profileId;
  final String fullName;
  final int? age;
  final String? profilePhotoUrl;
  final String? city;
  final String? state;
  final String? gender;
  final double matchScore;
  final int? gothramId;
  final int? nakshatraId;
  final int? rashiId;
  final int? casteId;
  final String? subCaste;
  final int? motherTongueId;
  final int? highestEducationId;
  final int? occupationId;
  final bool isVerified;
  final int? gunaScore;
  final bool isOnline;
  final String? lastActiveLabel;
  final String? createdAt;
  final String? updatedAt;

  MatchResult({
    required this.profileId,
    required this.fullName,
    this.age,
    this.profilePhotoUrl,
    this.city,
    this.state,
    this.gender,
    required this.matchScore,
    this.gothramId,
    this.nakshatraId,
    this.rashiId,
    this.casteId,
    this.subCaste,
    this.motherTongueId,
    this.highestEducationId,
    this.occupationId,
    this.isVerified = false,
    this.gunaScore,
    this.isOnline = false,
    this.lastActiveLabel,
    this.createdAt,
    this.updatedAt,
  });

  Profile get profile => Profile(
        id: profileId,
        email: '',
        fullName: fullName,
        gender: gender,
        heightInches: null,
        motherTongueId: motherTongueId,
        casteId: casteId,
        subCaste: subCaste,
        gothramId: gothramId,
        nakshatraId: nakshatraId,
        rashiId: rashiId,
        highestEducationId: highestEducationId,
        occupationId: occupationId,
        state: state,
        city: city,
        profilePhotoUrl: profilePhotoUrl,
        isVerified: isVerified,
        createdAt: createdAt ?? '',
        updatedAt: updatedAt ?? '',
      );

  double get totalScore => matchScore;

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      profileId: json['profile_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      gender: json['gender']?.toString(),
      matchScore: (json['score'] as num?)?.toDouble() ??
          (json['match_score'] as num?)?.toDouble() ??
          0.0,
      gothramId: (json['gothram_id'] as num?)?.toInt(),
      nakshatraId: (json['nakshatra_id'] as num?)?.toInt(),
      rashiId: (json['rashi_id'] as num?)?.toInt(),
      casteId: (json['caste_id'] as num?)?.toInt(),
      subCaste: json['sub_caste']?.toString(),
      motherTongueId: (json['mother_tongue_id'] as num?)?.toInt(),
      highestEducationId: (json['highest_education_id'] as num?)?.toInt(),
      occupationId: (json['occupation_id'] as num?)?.toInt(),
      isVerified: json['is_verified'] == true,
      gunaScore: (json['guna_score'] as num?)?.toInt(),
      isOnline: json['is_online'] == true,
      lastActiveLabel: json['last_active_label']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
