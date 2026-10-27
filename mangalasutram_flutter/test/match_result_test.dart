import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/models/match_result.dart';

void main() {
  group('MatchResult Model Unit Tests', () {
    test('Correctly parses match score, guna score, and online status from JSON', () {
      final json = {
        'profile_id': 'cand-999',
        'full_name': 'Gayatri Devi',
        'age': 26,
        'city': 'Vijayawada',
        'state': 'Andhra Pradesh',
        'gender': 'Female',
        'score': 88.5,
        'guna_score': 31,
        'is_verified': true,
        'is_online': true,
        'sub_caste': 'Vaidiki Velanadu',
        'gothram_id': 3,
        'nakshatra_id': 4,
      };

      final match = MatchResult.fromJson(json);
      expect(match.profileId, 'cand-999');
      expect(match.fullName, 'Gayatri Devi');
      expect(match.age, 26);
      expect(match.matchScore, 88.5);
      expect(match.totalScore, 88.5);
      expect(match.gunaScore, 31);
      expect(match.isVerified, isTrue);
      expect(match.isOnline, isTrue);
      expect(match.subCaste, 'Vaidiki Velanadu');
    });

    test('MatchResult exposes a valid Profile object representation', () {
      final match = MatchResult(
        profileId: 'cand-888',
        fullName: 'Ramakrishna Shastri',
        matchScore: 92.0,
        city: 'Guntur',
        state: 'Andhra Pradesh',
        subCaste: 'Dravida',
        isVerified: true,
        isOnline: true,
      );

      final profile = match.profile;
      expect(profile.id, 'cand-888');
      expect(profile.fullName, 'Ramakrishna Shastri');
      expect(profile.city, 'Guntur');
      expect(profile.subCaste, 'Dravida');
      expect(profile.isVerified, isTrue);
    });

    test('Handles fallback fields when keys vary (e.g. id instead of profile_id, match_score instead of score)', () {
      final json = {
        'id': 'cand-777',
        'full_name': 'Bhavani Shankar',
        'match_score': 74.0,
      };

      final match = MatchResult.fromJson(json);
      expect(match.profileId, 'cand-777');
      expect(match.matchScore, 74.0);
      expect(match.gunaScore, isNull);
      expect(match.isVerified, isFalse);
      expect(match.isOnline, isFalse);
    });
  });
}
