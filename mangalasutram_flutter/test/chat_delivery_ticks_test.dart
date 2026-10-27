import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTickIcon({required bool isRead, required bool isDelivered}) {
    if (isRead) {
      return const Icon(
        Icons.done_all_rounded,
        key: Key('tick_read'),
        size: 14,
        color: Color(0xFFFDE68A),
      );
    } else if (isDelivered) {
      return const Icon(
        Icons.done_all_rounded,
        key: Key('tick_delivered'),
        size: 14,
        color: Colors.white70,
      );
    } else {
      return const Icon(
        Icons.done_rounded,
        key: Key('tick_sent'),
        size: 14,
        color: Colors.white60,
      );
    }
  }

  group('3-State WhatsApp Tick System Widget Tests', () {
    testWidgets('State 1: Sent (Single Tick)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildTickIcon(isRead: false, isDelivered: false),
          ),
        ),
      );

      expect(find.byKey(const Key('tick_sent')), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });

    testWidgets('State 2: Delivered (Double Grey Tick)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildTickIcon(isRead: false, isDelivered: true),
          ),
        ),
      );

      expect(find.byKey(const Key('tick_delivered')), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      final icon = tester.widget<Icon>(find.byKey(const Key('tick_delivered')));
      expect(icon.color, Colors.white70);
    });

    testWidgets('State 3: Read / Seen (Double Gold Tick)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildTickIcon(isRead: true, isDelivered: true),
          ),
        ),
      );

      expect(find.byKey(const Key('tick_read')), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      final icon = tester.widget<Icon>(find.byKey(const Key('tick_read')));
      expect(icon.color, const Color(0xFFFDE68A));
    });
  });
}
