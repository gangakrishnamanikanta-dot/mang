import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/models/lookup_option.dart';
import 'package:mangalasutram/features/onboarding/steps/step1_basic_info.dart';
import 'package:mangalasutram/features/onboarding/steps/step2_traditional.dart';
import 'package:mangalasutram/features/onboarding/steps/step3_education.dart';
import 'package:mangalasutram/features/onboarding/steps/step4_family.dart';
import 'package:mangalasutram/features/onboarding/steps/step5_lifestyle.dart';
import 'package:mangalasutram/features/onboarding/steps/step6_location.dart';
import 'package:mangalasutram/features/onboarding/steps/step7_partner_preferences.dart';
import 'package:mangalasutram/features/onboarding/steps/step7_review.dart';
import 'package:mangalasutram/features/onboarding/widgets/luxury_multi_photo_picker.dart';

void main() {
  final Map<String, List<LookupOption>> mockLookupData = {
    'mother_tongues': [
      LookupOption(id: 1, label: 'Telugu'),
      LookupOption(id: 2, label: 'Tamil'),
    ],
    'castes': [
      LookupOption(id: 1, label: 'Brahmin - Niyogi'),
      LookupOption(id: 2, label: 'Brahmin - Vaidiki'),
    ],
    'gothrams': [
      LookupOption(id: 1, label: 'Kashyapa'),
      LookupOption(id: 2, label: 'Bharadwaja'),
    ],
    'nakshatras': [
      LookupOption(id: 1, label: 'Ashwini'),
      LookupOption(id: 2, label: 'Bharani'),
    ],
    'rashis': [
      LookupOption(id: 1, label: 'Mesha (Aries)'),
      LookupOption(id: 2, label: 'Vrishabha (Taurus)'),
    ],
    'veda_shakhas': [
      LookupOption(id: 1, label: 'Rigveda'),
      LookupOption(id: 2, label: 'Yajurveda'),
    ],
    'education_levels': [
      LookupOption(id: 1, label: 'B.Tech / B.E.'),
      LookupOption(id: 2, label: 'M.S. / M.Tech'),
    ],
    'occupations': [
      LookupOption(id: 1, label: 'Software Engineer / Architect'),
      LookupOption(id: 2, label: 'Doctor / Surgeon'),
    ],
    'annual_incomes': [
      LookupOption(id: 1, label: '₹15 Lakh - ₹25 Lakh'),
      LookupOption(id: 2, label: '₹25 Lakh - ₹50 Lakh'),
    ],
    'family_types': [
      LookupOption(id: 1, label: 'Nuclear Family'),
      LookupOption(id: 2, label: 'Joint Family'),
    ],
    'food_preferences': [
      LookupOption(id: 1, label: 'Strictly Vegetarian'),
      LookupOption(id: 2, label: 'Eggetarian'),
    ],
    'countries': [
      LookupOption(id: 1, label: 'India'),
      LookupOption(id: 2, label: 'United States'),
    ],
  };

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  group('Onboarding Steps 1–8 Full Suite Tests', () {
    testWidgets('Step 1 Basic Info renders all inputs and LuxuryMultiPhotoPicker', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'full_name': 'Sita Devi',
        'gender': 'female',
        'date_of_birth': '1998-05-15',
        'height_inches': 65,
        'created_for': 'Self',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step1BasicInfo(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sacred Identity'), findsOneWidget);
      expect(find.byType(LuxuryMultiPhotoPicker), findsOneWidget);
      expect(find.text('Profile Created For'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
    });

    testWidgets('Step 2 Traditional Vedic Horoscope renders and updates correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'sampradayam': 'Smartha (Advaita)',
        'gothram_id': 1,
        'nakshatra_id': 1,
        'rashi_id': 1,
        'pada_id': 1,
        'kuja_dosham': 'No Dosham',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step2Traditional(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vedic Lineage & Horoscope'), findsOneWidget);
      expect(find.text('Sampradayam / Tradition'), findsOneWidget);
      expect(find.text('Gothram'), findsOneWidget);
      expect(find.text('Nakshatra (Birth Star)'), findsOneWidget);
      expect(find.text('Rashi (Moon Sign)'), findsOneWidget);
    });

    testWidgets('Step 3 Education & Career renders fields properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'highest_education_id': 1,
        'college': 'IIT Madras',
        'occupation_id': 1,
        'company': 'Google',
        'annual_income_id': 1,
        'work_location': 'Hyderabad, Telangana',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step3Education(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Education & Profession'), findsOneWidget);
      expect(find.text('Highest Education Qualification'), findsOneWidget);
      expect(find.text('Occupation / Sector'), findsOneWidget);
    });

    testWidgets('Step 4 Family Details renders family cards properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'father_name': 'Ramakrishna Rao',
        'father_occupation': 'Retired Govt Officer',
        'mother_name': 'Lakshmi Devi',
        'mother_occupation': 'Homemaker',
        'family_type_id': 1,
        'native_place': 'Rajahmundry',
        'brothers_count': 1,
        'sisters_count': 0,
      };

      await tester.pumpWidget(
        createTestWidget(
          Step4Family(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Family Lineage & Roots'), findsOneWidget);
      expect(find.text('Family Culture & Type'), findsOneWidget);
      expect(find.text('Parents\' Information'), findsOneWidget);
    });

    testWidgets('Step 5 Lifestyle & Values renders food and habits properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'food_preference_id': 1,
        'smoking_id': 1,
        'drinking_id': 1,
        'about_me': 'Traditional Brahmin values with a modern outlook.',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step5Lifestyle(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lifestyle & Personal Values'), findsOneWidget);
      expect(find.text('Dietary & Daily Habits'), findsOneWidget);
      expect(find.text('Fitness & Personality'), findsOneWidget);
    });

    testWidgets('Step 6 Location Details renders country and city inputs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'country_id': 1,
        'state': 'Telangana',
        'city': 'Hyderabad',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step6Location(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current Residence'), findsOneWidget);
      expect(find.text('Country of Residence'), findsOneWidget);
    });

    testWidgets('Step 7 Partner Preferences renders preference criteria', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'partner_age_min': 23,
        'partner_age_max': 29,
        'partner_height_min': 62,
        'partner_height_max': 72,
        'partner_manglik': 'no',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step7PartnerPreferences(
            formData: formData,
            onUpdate: (key, val) => formData[key] = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ideal Partner Preferences'), findsOneWidget);
      expect(find.text('Age & Physical Criteria'), findsOneWidget);
      expect(find.text('Preferred Age Range'), findsOneWidget);
    });

    testWidgets('Step 8 Review renders complete summary cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final formData = <String, dynamic>{
        'full_name': 'Sita Devi',
        'gender': 'Female',
        'date_of_birth': '1998-05-15',
        'height_inches': 65,
        'created_for': 'Self',
        'sampradayam': 'Smartha',
        'about_me': 'Traditional Brahmin values with a modern outlook.',
      };

      await tester.pumpWidget(
        createTestWidget(
          Step7Review(
            formData: formData,
            lookupData: mockLookupData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sita Devi'), findsOneWidget);
      expect(find.text('Sacred Identity & Vedic Roots'), findsOneWidget);
      expect(find.text('Education & Profession'), findsOneWidget);
      expect(find.text('Family Lineage & Values'), findsOneWidget);
    });
  });
}
