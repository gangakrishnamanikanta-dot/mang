import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brahmin 20-Field Profile Gate Validation', () {
    // Pure validator function matching the logic implemented in ProfileBuilderLayout
    List<String> getMissingRequiredFields(Map<String, dynamic> formData) {
      final missing = <String>[];

      // Basic & Personal
      if ((formData['full_name'] as String?)?.trim().isEmpty ?? true) missing.add('Full Name');
      if ((formData['gender'] as String?)?.trim().isEmpty ?? true) missing.add('Gender');
      if ((formData['date_of_birth'] as String?)?.trim().isEmpty ?? true) missing.add('Date of Birth');
      if (formData['height_inches'] == null) missing.add('Height');
      if (formData['marital_status_id'] == null) missing.add('Marital Status');
      if (formData['mother_tongue_id'] == null) missing.add('Mother Tongue');
      if ((formData['created_for'] as String?)?.trim().isEmpty ?? true) missing.add('Profile Created For');

      // Traditional & Vedic Astrology (Mandatory for Brahmin community)
      if (formData['caste_id'] == null) missing.add('Caste / Sect');
      if (formData['gothram_id'] == null) missing.add('Gothram');
      if (formData['veda_shakha_id'] == null) missing.add('Veda Shakha');
      if (formData['nakshatra_id'] == null) missing.add('Nakshatra (Birth Star)');
      if (formData['rashi_id'] == null) missing.add('Rashi (Moon Sign)');

      // Education & Career
      if (formData['highest_education_id'] == null) missing.add('Education');
      if (formData['occupation_id'] == null) missing.add('Occupation');
      if (formData['annual_income_id'] == null) missing.add('Annual Income');

      // Location
      if (formData['country_id'] == null) missing.add('Country');
      if ((formData['state'] as String?)?.trim().isEmpty ?? true) missing.add('State');
      if ((formData['city'] as String?)?.trim().isEmpty ?? true) missing.add('City');

      return missing;
    }

    Map<String, dynamic> getCompleteProfileData() {
      return {
        'full_name': 'Krishna Manikanta',
        'gender': 'Male',
        'date_of_birth': '1995-05-15',
        'height_inches': 70,
        'marital_status_id': 1,
        'mother_tongue_id': 1,
        'created_for': 'Self',
        'caste_id': 1,
        'gothram_id': 3,
        'veda_shakha_id': 1,
        'nakshatra_id': 8, // Pushya
        'rashi_id': 4, // Cancer
        'highest_education_id': 2,
        'occupation_id': 1,
        'annual_income_id': 3,
        'country_id': 1,
        'state': 'Telangana',
        'city': 'Hyderabad',
      };
    }

    test('Valid complete Brahmin profile has zero missing fields', () {
      final data = getCompleteProfileData();
      final missing = getMissingRequiredFields(data);
      expect(missing, isEmpty);
    });

    test('Missing Brahmin fields (Gothram, Nakshatra, Rashi, Veda Shakha) are strictly caught', () {
      final data = getCompleteProfileData();
      data.remove('gothram_id');
      data.remove('veda_shakha_id');
      data.remove('nakshatra_id');
      data.remove('rashi_id');

      final missing = getMissingRequiredFields(data);
      expect(missing, contains('Gothram'));
      expect(missing, contains('Veda Shakha'));
      expect(missing, contains('Nakshatra (Birth Star)'));
      expect(missing, contains('Rashi (Moon Sign)'));
      expect(missing.length, 4);
    });

    test('Empty strings or whitespace are rejected as invalid', () {
      final data = getCompleteProfileData();
      data['full_name'] = '   ';
      data['state'] = '';
      data['city'] = null;

      final missing = getMissingRequiredFields(data);
      expect(missing, contains('Full Name'));
      expect(missing, contains('State'));
      expect(missing, contains('City'));
    });

    test('Missing education or career fields are detected', () {
      final data = getCompleteProfileData();
      data.remove('highest_education_id');
      data.remove('annual_income_id');

      final missing = getMissingRequiredFields(data);
      expect(missing, contains('Education'));
      expect(missing, contains('Annual Income'));
    });
  });
}
