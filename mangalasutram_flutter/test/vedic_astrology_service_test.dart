import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/features/shared/services/vedic_astrology_service.dart';

void main() {
  group('VedicAstrologyService - Canonical 36-Guna Ashtakoot Engine', () {
    test('Returns null when any mandatory astrological detail is missing or invalid', () {
      expect(
        VedicAstrologyService.calculate(
          boyRashiId: null,
          boyNakshatraId: 1,
          girlRashiId: 2,
          girlNakshatraId: 3,
        ),
        isNull,
      );

      expect(
        VedicAstrologyService.calculate(
          boyRashiId: 1,
          boyNakshatraId: null,
          girlRashiId: 2,
          girlNakshatraId: 3,
        ),
        isNull,
      );

      expect(
        VedicAstrologyService.calculate(
          boyRashiId: 13, // Out of bounds
          boyNakshatraId: 1,
          girlRashiId: 2,
          girlNakshatraId: 3,
        ),
        isNull,
      );

      expect(
        VedicAstrologyService.calculate(
          boyRashiId: 1,
          boyNakshatraId: 28, // Out of bounds
          girlRashiId: 2,
          girlNakshatraId: 3,
        ),
        isNull,
      );
    });

    test('Computes score within authentic 0..36 bounds', () {
      final result = VedicAstrologyService.calculate(
        boyRashiId: 4, // Cancer (Pushya)
        boyNakshatraId: 8,
        girlRashiId: 6, // Virgo (Uttara Phalguni)
        girlNakshatraId: 12,
      );

      expect(result, isNotNull);
      expect(result!.totalScore, greaterThanOrEqualTo(0.0));
      expect(result.totalScore, lessThanOrEqualTo(36.0));
      expect(result.breakdown.length, 8);
    });

    test('Varna Koota: Higher or equal varna yields 1.0, lower yields 0.0', () {
      // Cancer (Pushya) - Brahmin varna
      // Aries (Ashwini) - Kshatriya varna
      final higherBoy = VedicAstrologyService.calculate(
        boyRashiId: 4, // Cancer (Brahmin)
        boyNakshatraId: 8,
        girlRashiId: 1, // Aries (Kshatriya)
        girlNakshatraId: 1,
      );
      expect(higherBoy, isNotNull);
      expect(higherBoy!.breakdown['varna']!.score, 1.0);

      final lowerBoy = VedicAstrologyService.calculate(
        boyRashiId: 2, // Taurus (Vaishya)
        boyNakshatraId: 3,
        girlRashiId: 4, // Cancer (Brahmin)
        girlNakshatraId: 8,
      );
      expect(lowerBoy, isNotNull);
      expect(lowerBoy!.breakdown['varna']!.score, 0.0);
    });

    test('Identifies Nadi Dosha for same Nakshatra and Pada', () {
      // Rohini (Nakshatra 4, Rashi 2) - Antya Nadi
      final result = VedicAstrologyService.calculate(
        boyRashiId: 2,
        boyNakshatraId: 4,
        boyPada: 1,
        girlRashiId: 2,
        girlNakshatraId: 4,
        girlPada: 1,
      );

      expect(result, isNotNull);
      expect(result!.nadiDosha, isTrue);
      expect(result.nadiDoshaCancelled, isFalse);
      expect(result.breakdown['nadi']!.score, 0.0);
    });

    test('Applies authentic Nadi Dosha Parihara when Padas differ', () {
      // Rohini (Nakshatra 4, Rashi 2) with different Padas (1 and 2)
      final result = VedicAstrologyService.calculate(
        boyRashiId: 2,
        boyNakshatraId: 4,
        boyPada: 1,
        girlRashiId: 2,
        girlNakshatraId: 4,
        girlPada: 2,
      );

      expect(result, isNotNull);
      expect(result!.nadiDosha, isTrue);
      expect(result.nadiDoshaCancelled, isTrue);
      expect(result.breakdown['nadi']!.score, 8.0);
    });

    test('Assigns 0 for sworn enemy Yonis (Cat vs Rat)', () {
      // Punarvasu (Nakshatra 7, Cat) vs Magha (Nakshatra 10, Rat)
      final result = VedicAstrologyService.calculate(
        boyRashiId: 4,
        boyNakshatraId: 7,
        girlRashiId: 5,
        girlNakshatraId: 10,
      );

      expect(result, isNotNull);
      expect(result!.breakdown['yoni']!.score, 0.0);
    });

    test('Calculates auspicious score for Pushya and Uttara Phalguni', () {
      final result = VedicAstrologyService.calculate(
        boyRashiId: 4, // Cancer (Pushya)
        boyNakshatraId: 8,
        girlRashiId: 6, // Virgo (Uttara Phalguni)
        girlNakshatraId: 12,
      );

      expect(result, isNotNull);
      expect(result!.isAuspicious, isTrue);
      expect(result.totalScore, greaterThanOrEqualTo(28.0));
      expect(result.verdict, contains('Uttama'));
    });

    test('Tara Koota evaluates synchronized 1-indexed Parashara formula', () {
      // Ashwini (1) to Ashwini (1)
      final sameStar = VedicAstrologyService.calculate(
        boyRashiId: 1,
        boyNakshatraId: 1,
        girlRashiId: 1,
        girlNakshatraId: 1,
      );
      expect(sameStar, isNotNull);
      expect(sameStar!.breakdown['tara']!.score, greaterThanOrEqualTo(0.0));
      expect(sameStar.breakdown['tara']!.score, lessThanOrEqualTo(3.0));
    });

    test('Bhakoot Dosha and Planetary Friendship Cancellation', () {
      // Rashi 1 (Aries - Mars) vs Rashi 8 (Scorpio - Mars): 1/8 position has same lord (Mars)
      final sameLordBhakoot = VedicAstrologyService.calculate(
        boyRashiId: 1, // Aries
        boyNakshatraId: 1,
        girlRashiId: 8, // Scorpio
        girlNakshatraId: 17, // Anuradha
      );
      expect(sameLordBhakoot, isNotNull);
      // Even with 6/8 distance, same planetary lord (Mars) cancels Bhakoot Dosha
      expect(sameLordBhakoot!.bhakootDoshaCancelled, isTrue);
      expect(sameLordBhakoot.breakdown['bhakoot']!.score, 7.0);
    });
  });
}
