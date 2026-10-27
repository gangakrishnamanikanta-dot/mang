import 'dart:math';

/// Representation of an individual Koota in the Ashta-Koota system.
class KootScore {
  final String name;
  final double score;
  final double maxScore;
  final String description;

  const KootScore({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.description,
  });

  bool get isFullScore => score >= maxScore;
}

/// Comprehensive result of an authentic 36-Guna Ashtakoot calculation.
class AshtakootResult {
  final double totalScore;
  final double maxScore;
  final String verdict;
  final bool isAuspicious;
  final bool nadiDosha;
  final bool nadiDoshaCancelled;
  final bool bhakootDoshaCancelled;
  final Map<String, KootScore> breakdown;

  const AshtakootResult({
    required this.totalScore,
    this.maxScore = 36.0,
    required this.verdict,
    required this.isAuspicious,
    required this.nadiDosha,
    required this.nadiDoshaCancelled,
    required this.bhakootDoshaCancelled,
    required this.breakdown,
  });

  int get roundedScore => totalScore.round();
}

/// Canonical Vedic Astrology Service implementing Brihat Parashara Hora Shastra
/// and Muhurta Chintamani Ashta-Koota Guna Milan rules.
class VedicAstrologyService {
  VedicAstrologyService._();

  // ── Canonical Data Tables ──

  // 12 Rashis Varna (1: Shudra, 2: Vaishya, 3: Kshatriya, 4: Brahmin)
  static const List<int> _rashiVarna = [
    3, 2, 1, 4, 3, 2, 1, 4, 3, 2, 1, 4,
  ];

  // 27 Nakshatras Gana (0: Deva, 1: Manushya, 2: Rakshasa)
  static const List<int> _nakshatraGana = [
    0, 1, 2, 1, 0, 1, 0, 0, 2,
    2, 1, 1, 0, 2, 0, 2, 0, 2,
    2, 1, 1, 0, 2, 2, 1, 1, 0,
  ];

  // 27 Nakshatras Nadi (0: Adi/Vata, 1: Madhya/Pitta, 2: Antya/Kapha) - Serpentine Wave
  static const List<int> _nakshatraNadi = [
    0, 1, 2, 2, 1, 0, 0, 1, 2,
    0, 1, 2, 2, 1, 0, 0, 1, 2,
    0, 1, 2, 2, 1, 0, 0, 1, 2,
  ];

  // 27 Nakshatras Yoni Animal (1 to 14)
  static const List<int> _nakshatraYoni = [
    1,  2,  3,  4,  4,  5,  6,  3,  6,
    7,  7,  8,  9, 10,  9, 10, 11, 11,
    5, 12, 13, 12, 14,  1, 14,  8,  2,
  ];

  // 12 Rashis Planetary Lord normalized (1:Sun, 2:Moon, 3:Mars, 4:Mercury, 5:Jupiter, 6:Venus, 7:Saturn)
  static const List<int> _rashiLordNorm = [
    3, 6, 4, 2, 1, 4, 6, 3, 5, 7, 7, 5,
  ];

  // Sworn Enemies Yoni Pairs
  static const List<List<int>> _yoniSwornEnemies = [
    [1, 9],  // Horse vs Buffalo
    [2, 14], // Elephant vs Lion
    [3, 12], // Sheep vs Monkey
    [4, 13], // Serpent vs Mongoose
    [5, 11], // Dog vs Deer
    [6, 7],  // Cat vs Rat
    [8, 10], // Cow vs Tiger
  ];

  /// Calculates canonical Ashta-Koota compatibility between Groom and Bride.
  /// Returns `null` if any mandatory birth detail is missing or invalid.
  static AshtakootResult? calculate({
    required int? boyRashiId,
    required int? boyNakshatraId,
    int? boyPada,
    required int? girlRashiId,
    required int? girlNakshatraId,
    int? girlPada,
  }) {
    if (boyRashiId == null ||
        girlRashiId == null ||
        boyNakshatraId == null ||
        girlNakshatraId == null ||
        boyRashiId < 1 ||
        boyRashiId > 12 ||
        girlRashiId < 1 ||
        girlRashiId > 12 ||
        boyNakshatraId < 1 ||
        boyNakshatraId > 27 ||
        girlNakshatraId < 1 ||
        girlNakshatraId > 27) {
      return null;
    }

    final bPada = boyPada ?? 1;
    final gPada = girlPada ?? 1;

    // 1. Varna Koota (1 pt max)
    final boyVarna = _rashiVarna[boyRashiId - 1];
    final girlVarna = _rashiVarna[girlRashiId - 1];
    final double varnaScore = boyVarna >= girlVarna ? 1.0 : 0.0;

    // 2. Vashya Koota (2 pts max)
    double vashyaScore = 1.0;
    if (boyRashiId == girlRashiId) {
      vashyaScore = 2.0;
    } else if (([1, 2].contains(boyRashiId) && [1, 2].contains(girlRashiId)) ||
        ([3, 6, 7, 11].contains(boyRashiId) && [3, 6, 7, 11].contains(girlRashiId)) ||
        ([4, 12].contains(boyRashiId) && [4, 12].contains(girlRashiId))) {
      vashyaScore = 2.0;
    } else if (([1, 2].contains(boyRashiId) && [3, 6, 7, 11].contains(girlRashiId)) ||
        ([3, 6, 7, 11].contains(boyRashiId) && [1, 2].contains(girlRashiId)) ||
        ([3, 6, 7, 11].contains(boyRashiId) && [4, 12].contains(girlRashiId)) ||
        ([4, 12].contains(boyRashiId) && [3, 6, 7, 11].contains(girlRashiId))) {
      vashyaScore = 1.0;
    } else if (([1, 2].contains(boyRashiId) && [4, 12].contains(girlRashiId)) ||
        ([4, 12].contains(boyRashiId) && [1, 2].contains(girlRashiId))) {
      vashyaScore = 0.5;
    } else if (boyRashiId == 5 || girlRashiId == 5) {
      vashyaScore = (boyRashiId == 7 || girlRashiId == 7) ? 1.0 : 0.0;
    } else if (boyRashiId == 8 || girlRashiId == 8) {
      vashyaScore = (boyRashiId == 4 || girlRashiId == 4) ? 1.0 : 0.0;
    }

    // 3. Tara Koota (3 pts max) - Classical Brihat Parashara 1-Indexed Inclusive
    final taraGtoB = (((boyNakshatraId - girlNakshatraId + 27) % 27) % 9) + 1;
    final taraBtoG = (((girlNakshatraId - boyNakshatraId + 27) % 27) % 9) + 1;

    const inauspiciousTaras = [3, 5, 7];
    final gToBOk = !inauspiciousTaras.contains(taraGtoB);
    final bToGOk = !inauspiciousTaras.contains(taraBtoG);
    double taraScore = 0.0;
    if (gToBOk && bToGOk) {
      taraScore = 3.0;
    } else if (gToBOk || bToGOk) {
      taraScore = 1.5;
    } else {
      taraScore = 0.0;
    }

    // 4. Yoni Koota (4 pts max)
    final boyYoni = _nakshatraYoni[boyNakshatraId - 1];
    final girlYoni = _nakshatraYoni[girlNakshatraId - 1];
    double yoniScore = 2.0;

    if (boyYoni == girlYoni) {
      yoniScore = 4.0;
    } else {
      final isEnemy = _yoniSwornEnemies.any((pair) =>
          (boyYoni == pair[0] && girlYoni == pair[1]) ||
          (boyYoni == pair[1] && girlYoni == pair[0]));
      yoniScore = isEnemy ? 0.0 : 2.0;
    }

    // 5. Graha Maitri (5 pts max)
    final boyLord = _rashiLordNorm[boyRashiId - 1];
    final girlLord = _rashiLordNorm[girlRashiId - 1];
    double maitriScore = 3.0;

    if (boyLord == girlLord) {
      maitriScore = 5.0;
    } else if ([1, 2, 3, 5].contains(boyLord) && [1, 2, 3, 5].contains(girlLord)) {
      maitriScore = 5.0;
    } else if ([4, 6, 7].contains(boyLord) && [4, 6, 7].contains(girlLord)) {
      maitriScore = 5.0;
    } else if ((boyLord == 4 && girlLord == 1) || (boyLord == 1 && girlLord == 4)) {
      maitriScore = 4.0;
    } else if (([1, 2].contains(boyLord) && [6, 7].contains(girlLord)) ||
        ([6, 7].contains(boyLord) && [1, 2].contains(girlLord))) {
      maitriScore = 0.5;
    } else if ((boyLord == 3 && girlLord == 4) || (boyLord == 4 && girlLord == 3)) {
      maitriScore = 0.5;
    }

    // 6. Gana Koota (6 pts max)
    final boyGana = _nakshatraGana[boyNakshatraId - 1];
    final girlGana = _nakshatraGana[girlNakshatraId - 1];
    double ganaScore = 0.0;

    if (boyGana == girlGana) {
      ganaScore = 6.0;
    } else if (boyGana == 0 && girlGana == 1) {
      ganaScore = 6.0;
    } else if (boyGana == 1 && girlGana == 0) {
      ganaScore = 5.0;
    } else if (boyGana == 0 && girlGana == 2) {
      ganaScore = 1.0;
    } else {
      ganaScore = 0.0;
    }

    // 7. Bhakoot Koota (7 pts max)
    final rashiDiff = (boyRashiId - girlRashiId).abs();
    double bhakootScore = 0.0;
    bool bhakootParihara = false;

    if ([0, 6, 2, 10, 3, 9].contains(rashiDiff)) {
      bhakootScore = 7.0;
    } else {
      if (boyLord == girlLord || maitriScore >= 4.0) {
        bhakootScore = 7.0;
        bhakootParihara = true;
      } else {
        bhakootScore = 0.0;
      }
    }

    // 8. Nadi Koota (8 pts max)
    final boyNadi = _nakshatraNadi[boyNakshatraId - 1];
    final girlNadi = _nakshatraNadi[girlNakshatraId - 1];
    double nadiScore = 8.0;
    bool nadiDosha = false;
    bool nadiParihara = false;

    if (boyNadi != girlNadi) {
      nadiScore = 8.0;
    } else {
      nadiDosha = true;
      if (boyNakshatraId != girlNakshatraId) {
        if (boyRashiId != girlRashiId && maitriScore >= 4.0) {
          nadiScore = 8.0;
          nadiParihara = true;
        } else {
          nadiScore = 0.0;
        }
      } else if (bPada != gPada) {
        nadiScore = 8.0;
        nadiParihara = true;
      } else {
        nadiScore = 0.0;
      }
    }

    final rawTotal = varnaScore +
        vashyaScore +
        taraScore +
        yoniScore +
        maitriScore +
        ganaScore +
        bhakootScore +
        nadiScore;
    final totalScore = max(0.0, min(36.0, (rawTotal * 10).roundToDouble() / 10));

    String verdict = 'Madhyama Milan (Good Match)';
    if (totalScore >= 28.0) {
      verdict = 'Uttama Milan (Highly Auspicious Match)';
    } else if (totalScore < 18.0) {
      verdict = 'Alpa Milan (Low Astrological Compatibility)';
    }

    final breakdown = {
      'varna': KootScore(
        name: 'Varna',
        score: varnaScore,
        maxScore: 1.0,
        description: 'Spiritual ego and natural inclinations',
      ),
      'vashya': KootScore(
        name: 'Vashya',
        score: vashyaScore,
        maxScore: 2.0,
        description: 'Mutual attraction and harmonious influence',
      ),
      'tara': KootScore(
        name: 'Tara',
        score: taraScore,
        maxScore: 3.0,
        description: 'Health, longevity, and well-being',
      ),
      'yoni': KootScore(
        name: 'Yoni',
        score: yoniScore,
        maxScore: 4.0,
        description: 'Physical harmony and biological compatibility',
      ),
      'maitri': KootScore(
        name: 'Graha Maitri',
        score: maitriScore,
        maxScore: 5.0,
        description: 'Psychological bond and intellectual harmony',
      ),
      'gana': KootScore(
        name: 'Gana',
        score: ganaScore,
        maxScore: 6.0,
        description: 'Temperament, nature, and social compatibility',
      ),
      'bhakoot': KootScore(
        name: 'Bhakoot',
        score: bhakootScore,
        maxScore: 7.0,
        description: 'Emotional happiness and family prosperity',
      ),
      'nadi': KootScore(
        name: 'Nadi',
        score: nadiScore,
        maxScore: 8.0,
        description: 'Genetic compatibility and progeny health',
      ),
    };

    return AshtakootResult(
      totalScore: totalScore,
      verdict: verdict,
      isAuspicious: totalScore >= 18.0,
      nadiDosha: nadiDosha,
      nadiDoshaCancelled: nadiParihara,
      bhakootDoshaCancelled: bhakootParihara,
      breakdown: breakdown,
    );
  }
}
