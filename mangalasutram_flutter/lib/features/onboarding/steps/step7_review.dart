import 'package:flutter/material.dart';
import '../../../models/lookup_option.dart';

class Step7Review extends StatelessWidget {
  final Map<String, dynamic> formData;
  final Map<String, dynamic>? lookupData;

  const Step7Review({super.key, required this.formData, this.lookupData});

  String _formatHeight(dynamic inches) {
    if (inches == null) return 'Not Specified';
    final int h = int.tryParse(inches.toString()) ?? 0;
    if (h == 0) return 'Not Specified';
    final feet = h ~/ 12;
    final remainingInches = h % 12;
    return "$feet'$remainingInches\" (${(h * 2.54).round()} cm)";
  }

  String _getLookupLabel(String table, dynamic id) {
    if (id == null || lookupData == null) return 'Not Specified';
    final list = lookupData![table] as List<LookupOption>?;
    if (list == null) return 'Not Specified';
    try {
      final match = list.firstWhere((item) => item.id == id);
      return match.label;
    } catch (_) {
      return 'Not Specified';
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADBCE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E1732).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFC99A4B)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6E1732),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF4EFEA), height: 1),
          const SizedBox(height: 14),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String? value) {
    final display = (value != null && value.trim().isNotEmpty) ? value : 'Not Specified';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8B7355),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C1810),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = formData['profile_photo_url']?.toString();
    final fullName = formData['full_name']?.toString() ?? 'Devotee';
    final gender = formData['gender']?.toString() ?? '';
    final dob = formData['date_of_birth']?.toString();
    final heightStr = _formatHeight(formData['height_inches']);

    final gothram = _getLookupLabel('gothrams', formData['gothram_id']);
    final nakshatra = _getLookupLabel('nakshatras', formData['nakshatra_id']);
    final rashi = _getLookupLabel('rashis', formData['rashi_id']);
    final pada = _getLookupLabel('padas', formData['pada_id']);
    final education = _getLookupLabel('education_levels', formData['highest_education_id']);
    final occupation = _getLookupLabel('occupations', formData['occupation_id']);
    final income = _getLookupLabel('annual_incomes', formData['annual_income_id']);
    final country = _getLookupLabel('countries', formData['country_id']);

    final prefs = formData['preferences'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Auspicious Seal & Heading
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC99A4B), width: 2),
                color: const Color(0xFFFBF8F1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC99A4B).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover))
                  : const Center(
                      child: Icon(
                        Icons.verified_rounded,
                        size: 46,
                        color: Color(0xFFC99A4B),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E1732),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$gender • $gothram • $nakshatra',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // Auspicious Guarantee Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF9EE), Color(0xFFFDF4E3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC99A4B).withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars_rounded, size: 26, color: Color(0xFFC99A4B)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sacred Verification Ready: Your profile will be authenticated with authentic Guna Milan algorithms upon publishing.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5C3A1E),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 1. Basic & Astrological Details Card
          _buildSummaryCard(
            title: 'Sacred Identity & Vedic Roots',
            icon: Icons.temple_hindu_rounded,
            rows: [
              _buildDataRow('Profile Created For', formData['created_for']?.toString()),
              _buildDataRow('Gender', gender),
              _buildDataRow('Date of Birth', dob),
              _buildDataRow('Height', heightStr),
              _buildDataRow('Gothram', gothram),
              _buildDataRow('Nakshatra', nakshatra),
              _buildDataRow('Rashi / Moon Sign', rashi),
              _buildDataRow('Pada', pada),
              _buildDataRow('Kuja Dosham', formData['kuja_dosham']?.toString()),
              _buildDataRow('Time of Birth', formData['time_of_birth']?.toString()),
              _buildDataRow('Place of Birth', formData['place_of_birth']?.toString()),
            ],
          ),

          // 2. Education & Profession Card
          _buildSummaryCard(
            title: 'Education & Profession',
            icon: Icons.school_rounded,
            rows: [
              _buildDataRow('Qualification', education),
              _buildDataRow('College', formData['college']?.toString()),
              _buildDataRow('Occupation', occupation),
              _buildDataRow('Company', formData['company']?.toString()),
              _buildDataRow('Work Location', formData['work_location']?.toString()),
              _buildDataRow('Annual Income', income),
              _buildDataRow('Work Type', formData['work_type']?.toString()),
            ],
          ),

          // 3. Family Lineage Card
          _buildSummaryCard(
            title: 'Family Lineage & Values',
            icon: Icons.family_restroom_rounded,
            rows: [
              _buildDataRow('Family Values', formData['family_values']?.toString()),
              _buildDataRow('Father\'s Name', formData['father_name']?.toString()),
              _buildDataRow('Father\'s Occupation', formData['father_occupation']?.toString()),
              _buildDataRow('Mother\'s Name', formData['mother_name']?.toString()),
              _buildDataRow('Mother\'s Occupation', formData['mother_occupation']?.toString()),
              _buildDataRow('Brothers', formData['brothers_count']?.toString() ?? '0'),
              _buildDataRow('Sisters', formData['sisters_count']?.toString() ?? '0'),
              _buildDataRow('Native Place', formData['native_place']?.toString()),
            ],
          ),

          // 4. Lifestyle & Location Card
          _buildSummaryCard(
            title: 'Lifestyle, Location & Preferences',
            icon: Icons.favorite_rounded,
            rows: [
              _buildDataRow('Diet Preference', _getLookupLabel('food_preferences', formData['food_preference_id'])),
              _buildDataRow('Country', country),
              _buildDataRow('City / State', '${formData['city'] ?? ''}, ${formData['state'] ?? ''}'),
              _buildDataRow('Partner Age Range', '${prefs['min_age'] ?? 21} – ${prefs['max_age'] ?? 32} Yrs'),
              _buildDataRow('Partner Height', '${_formatHeight(prefs['min_height_inches'])} – ${_formatHeight(prefs['max_height_inches'])}'),
              _buildDataRow('Dosham Preference', prefs['kuja_dosham_preference']?.toString()),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
