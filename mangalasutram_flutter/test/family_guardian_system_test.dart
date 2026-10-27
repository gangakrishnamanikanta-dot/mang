import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mangalasutram/models/profile.dart';
import 'package:mangalasutram/features/family/services/family_service.dart';

void main() {
  group('Family Guardian System - Unit & Widget Tests', () {
    test('Profile model detects accountType, isGuardian, and isCandidate correctly', () {
      final candidateProfile = Profile(
        id: 'c-1',
        email: 'son@mangalasutram.in',
        fullName: 'Aditya Varma',
        accountType: 'candidate',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      expect(candidateProfile.accountType, 'candidate');
      expect(candidateProfile.isCandidate, isTrue);
      expect(candidateProfile.isGuardian, isFalse);

      final guardianProfile = Profile(
        id: 'g-1',
        email: 'father@mangalasutram.in',
        fullName: 'Ram Mohan Varma (Father)',
        accountType: 'guardian',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      expect(guardianProfile.accountType, 'guardian');
      expect(guardianProfile.isGuardian, isTrue);
      expect(guardianProfile.isCandidate, isFalse);

      final json = guardianProfile.toJson();
      expect(json['account_type'], 'guardian');

      final reconstructed = Profile.fromJson(json);
      expect(reconstructed.accountType, 'guardian');
      expect(reconstructed.isGuardian, isTrue);
    });

    test('CandidateContextModel correctly deserializes from Supabase RPC response', () {
      final json = {
        'candidate_id': 'c-100',
        'candidate_name': 'Kavya Sharma',
        'gender': 'female',
        'caste_id': 1,
        'sub_caste': 'Smartha',
        'gothram_id': 5,
        'nakshatra_id': 12,
        'rashi_id': 6,
        'photo_url': 'https://example.com/photo.jpg',
        'circle_id': 'fc-888',
        'guardian_role': 'Father',
      };

      final context = CandidateContextModel.fromJson(json);
      expect(context.candidateId, 'c-100');
      expect(context.candidateName, 'Kavya Sharma');
      expect(context.gender, 'female');
      expect(context.subCaste, 'Smartha');
      expect(context.gothramId, 5);
      expect(context.nakshatraId, 12);
      expect(context.rashiId, 6);
      expect(context.guardianRole, 'Father');
    });

    test('FamilyReviewModel properly maps reactions and profile details', () {
      final json = {
        'id': 'rev-1',
        'family_circle_id': 'fc-1',
        'target_profile_id': 'tp-1',
        'reviewed_by': 'g-1',
        'reaction': 'shortlist',
        'note': 'Noble family with compatible horoscope.',
        'created_at': DateTime.now().toIso8601String(),
        'profiles': {
          'full_name': 'Sneha Rao',
          'profile_photo_url': 'https://example.com/sneha.jpg',
          'city': 'Bengaluru',
        },
      };

      final review = FamilyReviewModel.fromJson(json);
      expect(review.id, 'rev-1');
      expect(review.reaction, 'shortlist');
      expect(review.note, 'Noble family with compatible horoscope.');
      expect(review.candidateName, 'Sneha Rao');
      expect(review.candidateCity, 'Bengaluru');
    });

    testWidgets('Chat Transparency Badge Widget - Renders Guardian Talking Badge for Recipient', (tester) async {
      const senderRole = "Groom's Father (Ramesh)";

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC99A4B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC99A4B).withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏷️ ', style: TextStyle(fontSize: 10)),
                  Text(
                    '$senderRole is talking to you',
                    key: const Key('guardian_chat_badge'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6E1732),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('guardian_chat_badge')), findsOneWidget);
      expect(find.text("Groom's Father (Ramesh) is talking to you"), findsOneWidget);
    });

    testWidgets('Chat Transparency Badge Widget - Renders Guardian Tag for Sender', (tester) async {
      const senderRole = 'Father';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC99A4B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC99A4B).withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏷️ ', style: TextStyle(fontSize: 10)),
                  Text(
                    'You ($senderRole)',
                    key: const Key('guardian_chat_badge'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6E1732),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('guardian_chat_badge')), findsOneWidget);
      expect(find.text('You (Father)'), findsOneWidget);
    });

    testWidgets('Matches Tab Guardian Banner Widget - Renders Delegated Seeking Notice', (tester) async {
      const candidateName = 'Aditya Varma';
      const guardianRole = 'Father';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6E1732), Color(0xFF8B2643)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Text('🪔', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Seeking Alliances for $candidateName',
                          key: const Key('guardian_banner_title'),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$guardianRole Mode — All matches & compatibility calibrated to child\'s horoscope',
                          key: const Key('guardian_banner_sub'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFFF6EFE6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('guardian_banner_title')), findsOneWidget);
      expect(find.text('Seeking Alliances for Aditya Varma'), findsOneWidget);
      expect(find.text('Father Mode — All matches & compatibility calibrated to child\'s horoscope'), findsOneWidget);
    });

    testWidgets('Family Room Review Card - Interactive Deliberation Chips Render & Respond', (tester) async {
      String currentReaction = 'discuss';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            Widget buildVoteChip({
              required String label,
              required IconData icon,
              required bool selected,
              required Color activeColor,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                child: Container(
                  key: Key('chip_$label'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: selected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(icon, size: 13, color: selected ? activeColor : Colors.grey),
                      Text(label, style: TextStyle(color: selected ? activeColor : Colors.black87)),
                    ],
                  ),
                ),
              );
            }

              return MaterialApp(
                home: Scaffold(
                  body: Row(
                    children: [
                      buildVoteChip(
                        label: 'Agree',
                        icon: Icons.check_circle_outline_rounded,
                        selected: currentReaction == 'shortlist',
                        activeColor: const Color(0xFF2E7D32),
                        onTap: () => setState(() => currentReaction = 'shortlist'),
                      ),
                      buildVoteChip(
                        label: 'Discuss',
                        icon: Icons.chat_bubble_outline_rounded,
                        selected: currentReaction == 'discuss',
                        activeColor: const Color(0xFFC99A4B),
                        onTap: () => setState(() => currentReaction = 'discuss'),
                      ),
                      buildVoteChip(
                        label: 'Pass',
                        icon: Icons.close_rounded,
                        selected: currentReaction == 'decline',
                        activeColor: const Color(0xFFD32F2F),
                        onTap: () => setState(() => currentReaction = 'decline'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

      expect(find.byKey(const Key('chip_Agree')), findsOneWidget);
      expect(find.byKey(const Key('chip_Discuss')), findsOneWidget);
      expect(find.byKey(const Key('chip_Pass')), findsOneWidget);

      expect(currentReaction, 'discuss');

      await tester.tap(find.byKey(const Key('chip_Agree')));
      await tester.pump();
      expect(currentReaction, 'shortlist');

      await tester.tap(find.byKey(const Key('chip_Pass')));
      await tester.pump();
      expect(currentReaction, 'decline');
    });
  });
}
