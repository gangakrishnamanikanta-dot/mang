import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/features/matching/widgets/match_celebration_dialog.dart';
import 'package:mangalasutram/models/profile.dart';

void main() {
  final myProfile = Profile(
    id: 'user-groom-1',
    email: 'groom@example.com',
    fullName: 'Venkat Raman',
    gender: 'Male',
    nakshatraId: 8, // Pushya
    rashiId: 4,     // Karka
    padaId: 2,
    city: 'Hyderabad',
    state: 'Telangana',
    createdAt: '2026-09-14T00:00:00Z',
    updatedAt: '2026-09-14T00:00:00Z',
  );

  final matchedProfile = Profile(
    id: 'user-bride-1',
    email: 'bride@example.com',
    fullName: 'Sowmya Iyer',
    gender: 'Female',
    nakshatraId: 12, // Uttara Phalguni
    rashiId: 6,      // Kanya
    padaId: 2,
    subCaste: 'Vaidiki Velanadu',
    city: 'Chennai',
    state: 'Tamil Nadu',
    createdAt: '2026-09-14T00:00:00Z',
    updatedAt: '2026-09-14T00:00:00Z',
  );

  group('MatchCelebrationDialog Widget Tests (Day 12 Match Screen)', () {
    testWidgets('Renders Shubhamastu header and matched candidate info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchCelebrationDialog(
              myProfile: myProfile,
              matchedProfile: matchedProfile,
            ),
          ),
        ),
      );

      // Verify Headers
      expect(find.text('Shubhamastu!'), findsOneWidget);
      expect(find.text("It's a Sacred Match!"), findsOneWidget);
      expect(find.text('AUSPICIOUS ALLIANCE'), findsOneWidget);

      // Verify Candidate Info
      expect(find.text('Sowmya Iyer'), findsOneWidget);
      expect(find.text('Vaidiki Velanadu • Chennai, Tamil Nadu'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Start Sacred Chat'), findsOneWidget);
      expect(find.text('Keep Exploring'), findsOneWidget);

      // Verify Guna Milan calculation badge rendered (Pushya + Uttara Phalguni)
      expect(find.textContaining('Gunas Compatible'), findsOneWidget);
    });

    testWidgets('Dismisses when Keep Exploring is tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => MatchCelebrationDialog.show(
                  ctx,
                  myProfile: myProfile,
                  matchedProfile: matchedProfile,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Shubhamastu!'), findsOneWidget);

      // Tap Keep Exploring
      await tester.tap(find.text('Keep Exploring'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed
      expect(find.text('Shubhamastu!'), findsNothing);
    });
  });
}
