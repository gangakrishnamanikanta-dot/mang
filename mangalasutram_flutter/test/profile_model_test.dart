import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/models/profile.dart';

void main() {
  group('Profile Model Unit Tests', () {
    test('Calculates age accurately from dateOfBirth', () {
      final now = DateTime.now();
      final birthYear = now.year - 28;
      // Exact birthday today minus 28 years
      final dobStr = '$birthYear-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final profile = Profile(
        id: 'p-1',
        email: 'test@mangalasutram.in',
        fullName: 'Krishna Sharma',
        dateOfBirth: dobStr,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );

      expect(profile.age, 28);
      expect(profile.computedAge, 28);
    });

    test('Handles null or invalid dateOfBirth gracefully', () {
      final profileNull = Profile(
        id: 'p-2',
        email: 'test@mangalasutram.in',
        fullName: 'Ananya Rao',
        dateOfBirth: null,
        createdAt: '',
        updatedAt: '',
      );

      expect(profileNull.age, isNull);
      expect(profileNull.computedAge, 0);

      final profileInvalid = Profile(
        id: 'p-3',
        email: 'test@mangalasutram.in',
        fullName: 'Ananya Rao',
        dateOfBirth: 'invalid-date-string',
        createdAt: '',
        updatedAt: '',
      );

      expect(profileInvalid.age, isNull);
      expect(profileInvalid.computedAge, 0);
    });

    test('isOnline getter correctly detects active presence window (< 15 mins)', () {
      final nowUtc = DateTime.now().toUtc();
      
      // Active 3 minutes ago
      final activeRecent = Profile(
        id: 'p-4',
        email: 'online@mangalasutram.in',
        fullName: 'Srinivas Murthy',
        lastActiveAt: nowUtc.subtract(const Duration(minutes: 3)).toIso8601String(),
        createdAt: '',
        updatedAt: '',
      );
      expect(activeRecent.isOnline, isTrue);

      // Inactive 2 hours ago
      final inactiveOld = Profile(
        id: 'p-5',
        email: 'offline@mangalasutram.in',
        fullName: 'Srinivas Murthy',
        lastActiveAt: nowUtc.subtract(const Duration(hours: 2)).toIso8601String(),
        createdAt: '',
        updatedAt: '',
      );
      expect(inactiveOld.isOnline, isFalse);

      // Null lastActiveAt
      final noTimestamp = Profile(
        id: 'p-6',
        email: 'null@mangalasutram.in',
        fullName: 'Srinivas Murthy',
        lastActiveAt: null,
        createdAt: '',
        updatedAt: '',
      );
      expect(noTimestamp.isOnline, isFalse);
    });

    test('completionScore accurately calculates filled percentage of required fields', () {
      final emptyProfile = Profile(
        id: 'p-7',
        email: 'test@mangalasutram.in',
        fullName: '',
        createdAt: '',
        updatedAt: '',
      );
      // Only email is filled (1 / 20) -> 5%
      expect(emptyProfile.completionScore, equals(5));

      final completeProfile = Profile(
        id: 'p-8',
        email: 'full@mangalasutram.in',
        phone: '+919876543210',
        fullName: 'Venkata Raman',
        gender: 'Male',
        dateOfBirth: '1995-06-15',
        heightInches: 70,
        maritalStatusId: 1,
        motherTongueId: 1,
        casteId: 1,
        createdFor: 'Self',
        highestEducationId: 1,
        occupationId: 1,
        workLocation: 'Hyderabad',
        countryId: 1,
        state: 'Telangana',
        city: 'Hyderabad',
        fatherName: 'Subba Rao',
        motherName: 'Lakshmi',
        nativePlace: 'Vijayawada',
        profilePhotoUrl: 'https://example.com/photo.jpg',
        createdAt: '',
        updatedAt: '',
      );
      // All 20 required fields filled -> 100%
      expect(completeProfile.completionScore, equals(100));
    });

    test('Profile serializes to and from JSON correctly', () {
      final jsonMap = {
        'id': 'uuid-1234',
        'email': 'padma@mangalasutram.in',
        'full_name': 'Padmavathi Somayajula',
        'gender': 'Female',
        'sub_caste': 'Niyogi',
        'city': 'Visakhapatnam',
        'is_verified': true,
        'profile_completed': true,
        'last_active_at': '2026-08-28T10:00:00.000Z',
        'created_at': '2026-08-01T00:00:00.000Z',
        'updated_at': '2026-08-28T10:00:00.000Z',
      };

      final profile = Profile.fromJson(jsonMap);
      expect(profile.id, 'uuid-1234');
      expect(profile.fullName, 'Padmavathi Somayajula');
      expect(profile.subCaste, 'Niyogi');
      expect(profile.isVerified, isTrue);
      expect(profile.lastActiveAt, '2026-08-28T10:00:00.000Z');

      final serialized = profile.toJson();
      expect(serialized['full_name'], 'Padmavathi Somayajula');
      expect(serialized['sub_caste'], 'Niyogi');
      expect(serialized['last_active_at'], '2026-08-28T10:00:00.000Z');
    });
  });
}
