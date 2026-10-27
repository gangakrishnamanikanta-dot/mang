import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/match_result.dart';
import '../../../models/profile.dart';
import '../../home/services/home_service.dart';
import '../../shared/services/vedic_astrology_service.dart';

/// Authentic Brihat Parashara 36-Guna Ashta-Koota Detailed Milan Screen
class DetailedGunaMilanScreen extends StatefulWidget {
  final MatchResult match;

  const DetailedGunaMilanScreen({super.key, required this.match});

  @override
  State<DetailedGunaMilanScreen> createState() =>
      _DetailedGunaMilanScreenState();
}

class _DetailedGunaMilanScreenState extends State<DetailedGunaMilanScreen> {
  Profile? _myProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    final myP = await HomeService.instance.getMyProfile();
    if (mounted) {
      setState(() {
        _myProfile = myP;
        _loading = false;
      });
    }
  }

  AshtakootResult? _computeFullResult() {
    final isMale = _myProfile?.gender?.toLowerCase() == 'male';
    return VedicAstrologyService.calculate(
      boyRashiId: isMale ? _myProfile?.rashiId : widget.match.rashiId,
      boyNakshatraId: isMale ? _myProfile?.nakshatraId : widget.match.nakshatraId,
      boyPada: isMale ? _myProfile?.padaId : 1,
      girlRashiId: isMale ? widget.match.rashiId : _myProfile?.rashiId,
      girlNakshatraId: isMale ? widget.match.nakshatraId : _myProfile?.nakshatraId,
      girlPada: isMale ? 1 : _myProfile?.padaId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidateName = widget.match.fullName;
    final fullResult = _computeFullResult();
    final hasValidCalculation = fullResult != null;
    final totalScore = hasValidCalculation
        ? fullResult.totalScore
        : (widget.match.gunaScore ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF6F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF4A121A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Guna Milan',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A121A),
              ),
            ),
            Text(
              'Ashtakoot System · 8 Kootas',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF8C7A6B),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B1E2D)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Score Ring Card ─────────────────────────────────
                  _buildHeroScoreCard(
                    totalScore: totalScore,
                    hasValidCalculation: hasValidCalculation,
                    candidateName: candidateName,
                    fullResult: fullResult,
                  ),
                  const SizedBox(height: 16),

                  // ── Nakshatra / Rashi Row ────────────────────────────────
                  if (hasValidCalculation) ...[
                    _buildProfileAstrologyRow(candidateName),
                    const SizedBox(height: 16),
                  ],

                  // ── Dosha Alert Banners ──────────────────────────────────
                  if (fullResult != null) ...[
                    if (fullResult.nadiDosha && !fullResult.nadiDoshaCancelled)
                      _buildDoshaBanner(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFD32F2F),
                        bgColor: const Color(0xFFFFF0F0),
                        borderColor: const Color(0xFFFFCDD2),
                        title: 'Nadi Dosha Detected',
                        subtitle:
                            'Same Nadi (energy current) — may affect genetic compatibility. Consult a Vedic astrologer for Parihara.',
                      ),
                    if (fullResult.nadiDosha && fullResult.nadiDoshaCancelled)
                      _buildDoshaBanner(
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF2E7D32),
                        bgColor: const Color(0xFFF0FFF4),
                        borderColor: const Color(0xFFA5D6A7),
                        title: 'Nadi Dosha — Parihara Applied',
                        subtitle:
                            'Nadi Dosha exists, but is nullified by different Nakshatra Padas or Rashi difference.',
                      ),
                    if ((fullResult.breakdown['bhakoot']?.score ?? 1) == 0 &&
                        !fullResult.bhakootDoshaCancelled)
                      _buildDoshaBanner(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFE65100),
                        bgColor: const Color(0xFFFFF8F0),
                        borderColor: const Color(0xFFFFCC80),
                        title: 'Bhakoot Dosha Detected',
                        subtitle:
                            'Rashi difference creates unfavourable Bhakoot — may affect emotional bonding.',
                      ),
                    if (fullResult.bhakootDoshaCancelled)
                      _buildDoshaBanner(
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF1565C0),
                        bgColor: const Color(0xFFF0F4FF),
                        borderColor: const Color(0xFF90CAF9),
                        title: 'Bhakoot Dosha — Parihara Applied',
                        subtitle:
                            'Cancelled by mutual planetary friendship. Full 7 points awarded.',
                      ),
                    const SizedBox(height: 4),
                  ],

                  // ── Section Title ────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.flare_rounded, color: Color(0xFFC99A4B), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Ashtakoot 8-Guna Breakdown',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF231F20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Maximum 36 Gunas across 8 Kootas',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8C7A6B)),
                  ),
                  const SizedBox(height: 12),

                  // ── 8 Koota Cards ─────────────────────────────────────────
                  _buildKootCard(
                    number: 1,
                    name: 'Varna Koota',
                    sanskritName: 'वर्ण',
                    icon: '🕉️',
                    score: fullResult?.breakdown['varna']?.score ?? 0,
                    maxScore: 1,
                    description:
                        'Measures spiritual development and natural temperament. Groom\'s Varna must be ≥ Bride\'s.',
                    interpretation: _getVarnaInterp(
                        fullResult?.breakdown['varna']?.score ?? 0),
                    hasDosha: false,
                    doshaCancelled: false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 2,
                    name: 'Vashya Koota',
                    sanskritName: 'वश्य',
                    icon: '🌙',
                    score: fullResult?.breakdown['vashya']?.score ?? 0,
                    maxScore: 2,
                    description:
                        'Assesses mutual attraction and natural influence in the relationship.',
                    interpretation: _getVashyaInterp(
                        fullResult?.breakdown['vashya']?.score ?? 0),
                    hasDosha: false,
                    doshaCancelled: false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 3,
                    name: 'Tara Koota',
                    sanskritName: 'तारा',
                    icon: '⭐',
                    score: fullResult?.breakdown['tara']?.score ?? 0,
                    maxScore: 3,
                    description:
                        'Determines destiny, health and longevity connection between partners.',
                    interpretation:
                        _getTaraInterp(fullResult?.breakdown['tara']?.score ?? 0),
                    hasDosha: false,
                    doshaCancelled: false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 4,
                    name: 'Yoni Koota',
                    sanskritName: 'योनि',
                    icon: '🐃',
                    score: fullResult?.breakdown['yoni']?.score ?? 0,
                    maxScore: 4,
                    description:
                        'Physical and biological compatibility based on Nakshatra animal symbols.',
                    interpretation:
                        _getYoniInterp(fullResult?.breakdown['yoni']?.score ?? 0),
                    hasDosha: false,
                    doshaCancelled: false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 5,
                    name: 'Graha Maitri',
                    sanskritName: 'ग्रह मैत्री',
                    icon: '🪐',
                    score: fullResult?.breakdown['maitri']?.score ?? 0,
                    maxScore: 5,
                    description:
                        'Intellectual bond and psychological harmony based on Moon Sign Lords.',
                    interpretation: _getMaitriInterp(
                        fullResult?.breakdown['maitri']?.score ?? 0),
                    hasDosha: false,
                    doshaCancelled: false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 6,
                    name: 'Gana Koota',
                    sanskritName: 'गण',
                    icon: '🌟',
                    score: fullResult?.breakdown['gana']?.score ?? 0,
                    maxScore: 6,
                    description:
                        'Temperament and personality type — Deva (divine), Manushya (human) or Rakshasa (fierce).',
                    interpretation:
                        _getGanaInterp(fullResult?.breakdown['gana']?.score ?? 0),
                    hasDosha: false,
                    doshaCancelled: false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 7,
                    name: 'Bhakoot Koota',
                    sanskritName: 'भकूट',
                    icon: '♥️',
                    score: fullResult?.breakdown['bhakoot']?.score ?? 0,
                    maxScore: 7,
                    description:
                        'Governs emotional happiness, family prosperity and marital well-being.',
                    interpretation: _getBhakootInterp(
                        fullResult?.breakdown['bhakoot']?.score ?? 0),
                    hasDosha: (fullResult?.breakdown['bhakoot']?.score ?? 1) == 0,
                    doshaCancelled: fullResult?.bhakootDoshaCancelled ?? false,
                    hasValidData: hasValidCalculation,
                  ),
                  _buildKootCard(
                    number: 8,
                    name: 'Nadi Koota',
                    sanskritName: 'नाडी',
                    icon: '🔬',
                    score: fullResult?.breakdown['nadi']?.score ?? 0,
                    maxScore: 8,
                    description:
                        'The most critical koota — genetic compatibility and health of future children.',
                    interpretation: _getNadiInterp(
                        fullResult?.breakdown['nadi']?.score ?? 0, fullResult),
                    hasDosha: fullResult?.nadiDosha ?? false,
                    doshaCancelled: fullResult?.nadiDoshaCancelled ?? false,
                    hasValidData: hasValidCalculation,
                    isHighlighted: true,
                  ),

                  const SizedBox(height: 20),

                  // ── Vedic Disclaimer ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8DFD5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: Color(0xFF8C7A6B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Computed per Brihat Parashara Hora Shastra. A score ≥ 18/36 is recommended for marriage. Consult a qualified Jyotishi for complete matching.',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF8C7A6B),
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF54121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Back to Match',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Hero Score Ring ──────────────────────────────────────────────────────────
  Widget _buildHeroScoreCard({
    required double totalScore,
    required bool hasValidCalculation,
    required String candidateName,
    required AshtakootResult? fullResult,
  }) {
    Color scoreColor;
    String verdict;
    Color verdictColor;
    Color bgStart;
    Color bgEnd;

    if (!hasValidCalculation) {
      scoreColor = const Color(0xFF8C7A6B);
      verdict = 'Horoscope Details Incomplete';
      verdictColor = const Color(0xFFB45309);
      bgStart = const Color(0xFFFFF9EE);
      bgEnd = const Color(0xFFFAF6F0);
    } else if (totalScore >= 28) {
      scoreColor = const Color(0xFF1B5E20);
      verdict = 'Uttama Milan ✨ — Highly Auspicious';
      verdictColor = const Color(0xFF1B5E20);
      bgStart = const Color(0xFFF0FFF4);
      bgEnd = const Color(0xFFE8F5E9);
    } else if (totalScore >= 18) {
      scoreColor = const Color(0xFF8B1E2D);
      verdict = 'Madhyama Milan — Good Compatibility';
      verdictColor = const Color(0xFF6E1732);
      bgStart = const Color(0xFFFFF8F0);
      bgEnd = const Color(0xFFFAF6F0);
    } else {
      scoreColor = const Color(0xFFC62828);
      verdict = 'Alpa Milan — Low Astrological Match';
      verdictColor = const Color(0xFFC62828);
      bgStart = const Color(0xFFFFF0F0);
      bgEnd = const Color(0xFFFAF6F0);
    }

    final pct = hasValidCalculation ? (totalScore / 36.0).clamp(0.0, 1.0) : 0.0;
    final scoreStr = hasValidCalculation
        ? (totalScore == totalScore.roundToDouble()
            ? totalScore.toInt().toString()
            : totalScore.toStringAsFixed(1))
        : '—';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgStart, bgEnd]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE4D8)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFF6E1732),
                Color(0xFFC99A4B),
                Color(0xFF6E1732)
              ]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 7,
                              color: const Color(0xFFECE4D8))),
                      SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                              value: pct,
                              strokeWidth: 7,
                              color: scoreColor,
                              strokeCap: StrokeCap.round)),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(scoreStr,
                            style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                                height: 1.0)),
                        Text('/36',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8C7A6B))),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(verdict,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: verdictColor,
                              height: 1.3)),
                      const SizedBox(height: 6),
                      Text(
                        hasValidCalculation
                            ? 'Compatibility with $candidateName'
                            : 'Add Nakshatra & Rashi to unlock',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF6B5E55),
                            height: 1.3),
                      ),
                      if (hasValidCalculation) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          _legendDot(const Color(0xFF1B5E20), '≥28'),
                          const SizedBox(width: 8),
                          _legendDot(const Color(0xFF8B1E2D), '18–27'),
                          const SizedBox(width: 8),
                          _legendDot(const Color(0xFFC62828), '<18'),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 3),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B5E55))),
    ]);
  }

  // ── Nakshatra / Rashi Profile Row ─────────────────────────────────────────
  Widget _buildProfileAstrologyRow(String candidateName) {
    const nak = [
      'Ashwini',
      'Bharani',
      'Krittika',
      'Rohini',
      'Mrigashira',
      'Ardra',
      'Punarvasu',
      'Pushya',
      'Ashlesha',
      'Magha',
      'Purva Phalguni',
      'Uttara Phalguni',
      'Hasta',
      'Chitra',
      'Swati',
      'Vishakha',
      'Anuradha',
      'Jyeshtha',
      'Mula',
      'Purva Ashadha',
      'Uttara Ashadha',
      'Shravana',
      'Dhanishtha',
      'Shatabhisha',
      'Purva Bhadrapada',
      'Uttara Bhadrapada',
      'Revati',
    ];
    const ras = [
      'Mesha',
      'Vrishabha',
      'Mithuna',
      'Karka',
      'Simha',
      'Kanya',
      'Tula',
      'Vrishchika',
      'Dhanu',
      'Makara',
      'Kumbha',
      'Meena',
    ];
    String n(int? id) => (id != null && id >= 1 && id <= 27) ? nak[id - 1] : '—';
    String r(int? id) => (id != null && id >= 1 && id <= 12) ? ras[id - 1] : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE4D8)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _astroCol('🌙', _myProfile?.fullName ?? 'You',
                  n(_myProfile?.nakshatraId), r(_myProfile?.rashiId))),
          Container(
              height: 50,
              width: 1,
              color: const Color(0xFFECE4D8),
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
              child: _astroCol('✨', candidateName, n(widget.match.nakshatraId),
                  r(widget.match.rashiId))),
        ],
      ),
    );
  }

  Widget _astroCol(String emoji, String name, String nakshatra, String rashi) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 3),
      Text(name,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A121A)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(nakshatra,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6E1732))),
      Text(rashi,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8C7A6B))),
    ]);
  }

  // ── Dosha Banner ──────────────────────────────────────────────────────────
  Widget _buildDoshaBanner({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF5D4A3A),
                      height: 1.3)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Individual Koota Card ──────────────────────────────────────────────────
  Widget _buildKootCard({
    required int number,
    required String name,
    required String sanskritName,
    required String icon,
    required double score,
    required int maxScore,
    required String description,
    required String interpretation,
    required bool hasDosha,
    required bool doshaCancelled,
    required bool hasValidData,
    bool isHighlighted = false,
  }) {
    final fraction = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    final isFull = score >= maxScore;
    final isZero = score == 0;

    Color barColor;
    Color scoreColor;
    if (!hasValidData) {
      barColor = const Color(0xFFD4C4B5);
      scoreColor = const Color(0xFF8C7A6B);
    } else if (isFull) {
      barColor = const Color(0xFF2E7D32);
      scoreColor = const Color(0xFF2E7D32);
    } else if (isZero) {
      barColor = const Color(0xFFC62828);
      scoreColor = const Color(0xFFC62828);
    } else if (fraction >= .5) {
      barColor = const Color(0xFFF59E0B);
      scoreColor = const Color(0xFF92650A);
    } else {
      barColor = const Color(0xFFE65100);
      scoreColor = const Color(0xFFE65100);
    }

    final scoreStr = hasValidData
        ? (score == score.roundToDouble()
            ? score.toInt().toString()
            : score.toStringAsFixed(1))
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFFC99A4B).withValues(alpha: 0.5)
              : const Color(0xFFECE4D8),
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                      color: Color(0xFF6E1732), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('$number',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(icon, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Expanded(
                  child:
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF231F20))),
                    Text(sanskritName,
                        style: GoogleFonts.inter(
                            fontSize: 10.5, color: const Color(0xFF8C7A6B))),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  RichText(
                      text: TextSpan(children: [
                    TextSpan(
                        text: scoreStr,
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: scoreColor)),
                    TextSpan(
                        text: '/$maxScore',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8C7A6B))),
                  ])),
                  if (hasValidData)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        isFull ? 'Full' : (isZero ? 'None' : 'Partial'),
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: barColor),
                      ),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: hasValidData ? fraction : 0.0,
                minHeight: 8,
                backgroundColor: const Color(0xFFECE4D8),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(description,
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: const Color(0xFF6B5E55), height: 1.35)),
          ),
          if (hasValidData && (hasDosha || doshaCancelled)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: doshaCancelled
                      ? const Color(0xFFF0FFF4)
                      : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: doshaCancelled
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFFCDD2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    doshaCancelled
                        ? Icons.check_circle_outline_rounded
                        : Icons.report_outlined,
                    size: 13,
                    color: doshaCancelled
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      doshaCancelled
                          ? 'Dosha — Parihara (Cancelled)'
                          : 'Dosha Present',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: doshaCancelled
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          if (hasValidData) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F0),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.auto_awesome,
                    size: 12, color: Color(0xFFC99A4B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(interpretation,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF5D4A3A),
                          height: 1.35,
                          fontStyle: FontStyle.italic)),
                ),
              ]),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Interpretation Helpers ────────────────────────────────────────────────
  String _getVarnaInterp(double s) {
    if (s >= 1) {
      return 'Spiritual compatibility is strong. Natural temperament alignment favors marital harmony.';
    }
    return 'Spiritual temperament differs. Minor factor — compensated by higher Kootas.';
  }

  String _getVashyaInterp(double s) {
    if (s >= 2) {
      return 'Strong mutual attraction. Natural influence is balanced — excellent emotional flow.';
    }
    if (s >= 1) {
      return 'Moderate attraction. Relationship requires conscious effort to maintain mutual respect.';
    }
    return 'Weak attraction alignment. Different natural pulls — effort and understanding required.';
  }

  String _getTaraInterp(double s) {
    if (s >= 3) {
      return 'Excellent Tara — auspicious birth star relationship. Mutual longevity and health well-supported.';
    }
    if (s >= 1.5) {
      return 'One direction of Tara is auspicious. Partial health compatibility — moderate outcome.';
    }
    return 'Both Tara positions unfavourable. Navagraha Shanti or Tara Bala remedy recommended.';
  }

  String _getYoniInterp(double s) {
    if (s >= 4) {
      return 'Same Yoni animal — highest physical and instinctual compatibility. Exceptional biological harmony.';
    }
    if (s >= 2) {
      return 'Compatible Yoni animals. Good physical and emotional compatibility.';
    }
    return 'Sworn enemy Yoni — deep instinctual incompatibility. Shaanti or Shukra remedy recommended.';
  }

  String _getMaitriInterp(double s) {
    if (s >= 5) {
      return 'Moon lords are mutual friends — excellent psychological bond and mental harmony.';
    }
    if (s >= 3) {
      return 'Moderate intellectual harmony. Partners can communicate well with some adjustment.';
    }
    return 'Moon lords neutral or enemies — intellectual friction possible. Communication effort needed.';
  }

  String _getGanaInterp(double s) {
    if (s >= 6) {
      return 'Same or compatible Gana — temperaments align beautifully. Daily life harmony will be high.';
    }
    if (s >= 5) {
      return 'Deva–Manushya compatibility — largely harmonious with minor adjustments.';
    }
    if (s >= 1) {
      return 'Partial Gana match. Personality types differ — patience and tolerance needed.';
    }
    return 'Rakshasa Gana mismatch — strong personality differences. Behavioral adjustment is critical.';
  }

  String _getBhakootInterp(double s) {
    if (s >= 7) {
      return 'Excellent Bhakoot — emotional bonds and family prosperity strongly supported astrologically.';
    }
    return 'Bhakoot Dosha present. Major dosha — without Parihara, emotional well-being may be affected.';
  }

  String _getNadiInterp(double s, AshtakootResult? r) {
    if (s >= 8 && r?.nadiDosha == false) {
      return 'Different Nadi — the most auspicious result. Excellent genetic compatibility. Children\'s health well-supported.';
    }
    if (s >= 8 && r?.nadiDoshaCancelled == true) {
      return 'Nadi Dosha cancelled by Parihara (different Pada or Rashi). Considered auspicious.';
    }
    return 'Nadi Dosha — same energy current. Highest weighted dosha. Nadi Dosha Nivarana Puja strongly recommended.';
  }
}
