import 'package:flutter/material.dart';
import '../../../models/profile.dart';

class Step7Review extends StatelessWidget {
  final Map<String, dynamic> formData;
  final Map<String, dynamic>? lookupData;

  const Step7Review({super.key, required this.formData, this.lookupData});

  @override
  Widget build(BuildContext context) {
    final criticalFields = [
      'full_name',
      'gender',
      'date_of_birth',
      'height_inches',
      'marital_status_id',
      'mother_tongue_id',
      'caste_id',
      'created_for',
    ];

    int filled = 0;
    for (final field in criticalFields) {
      final value = formData[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        filled++;
      }
    }
    final isReady = filled == criticalFields.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Final Review',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your profile information before finalizing.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isReady
                  ? const Color(0xFFE8F8EE)
                  : const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isReady
                    ? const Color(0xFF34C759).withValues(alpha: 0.3)
                    : const Color(0xFFFF3B30).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.warning_rounded,
                  color: isReady
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF3B30),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isReady
                        ? 'Great! You have provided all 8 critical fields. Your profile is ready to be published.'
                        : 'Your profile is missing some of the 8 critical fields (Name, Gender, DOB, Height, Marital Status, Mother Tongue, Caste, Created For). Please go back and fill them.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isReady
                          ? const Color(0xFF1B6A2E)
                          : const Color(0xFF991913),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildProfilePreview(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfilePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Preview',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic
              _buildSectionHeader('Basic Info'),
              _buildPreviewRow('Name', formData['full_name']?.toString()),
              _buildPreviewRow('Email', formData['email']?.toString()),
              _buildPreviewRow('Phone', formData['phone']?.toString()),
              _buildPreviewRow('Gender', formData['gender']?.toString()),
              _buildPreviewRow(
                'Date of Birth',
                formData['date_of_birth']?.toString(),
              ),
              _buildPreviewRow(
                'Marital Status',
                _resolveLookup(
                  'marital_statuses',
                  formData['marital_status_id'],
                ),
              ),
              _buildPreviewRow(
                'Mother Tongue',
                _resolveLookup('mother_tongues', formData['mother_tongue_id']),
              ),
              _buildPreviewRow(
                'Caste',
                _resolveLookup('castes', formData['caste_id']),
              ),

              // Traditional
              _buildSectionHeader('Traditional Info'),
              _buildPreviewRow('Sub-caste', formData['sub_caste']?.toString()),
              _buildPreviewRow(
                'Gothram',
                _resolveLookup('gothrams', formData['gothram_id']),
              ),
              _buildPreviewRow('Pravara', formData['pravara']?.toString()),
              _buildPreviewRow(
                'Veda/Shakha',
                _resolveLookup('veda_shakhas', formData['veda_shakha_id']),
              ),
              _buildPreviewRow(
                'Nakshatram',
                _resolveLookup('nakshatras', formData['nakshatra_id']),
              ),
              _buildPreviewRow(
                'Rashi',
                _resolveLookup('rashis', formData['rashi_id']),
              ),
              _buildPreviewRow(
                'Pada',
                _resolveLookup('padas', formData['pada_id']),
              ),

              // Education & Career
              _buildSectionHeader('Education & Career'),
              _buildPreviewRow(
                'Height',
                _resolveLookup('heights', formData['height_inches']),
              ),
              _buildPreviewRow(
                'Education',
                _resolveLookup(
                  'education_levels',
                  formData['highest_education_id'],
                ),
              ),
              _buildPreviewRow('College', formData['college']?.toString()),
              _buildPreviewRow(
                'Occupation',
                _resolveLookup('occupations', formData['occupation_id']),
              ),
              _buildPreviewRow('Company', formData['company']?.toString()),
              _buildPreviewRow(
                'Annual Income',
                _resolveLookup('annual_incomes', formData['annual_income_id']),
              ),
              _buildPreviewRow(
                'Work Location',
                formData['work_location']?.toString(),
              ),

              // Family
              _buildSectionHeader('Family Info'),
              _buildPreviewRow(
                'Father\'s Name',
                formData['father_name']?.toString(),
              ),
              _buildPreviewRow(
                'Father\'s Occupation',
                formData['father_occupation']?.toString(),
              ),
              _buildPreviewRow(
                'Mother\'s Name',
                formData['mother_name']?.toString(),
              ),
              _buildPreviewRow(
                'Mother\'s Occupation',
                formData['mother_occupation']?.toString(),
              ),
              _buildPreviewRow(
                'Family Type',
                _resolveLookup('family_types', formData['family_type_id']),
              ),

              // Preferences
              _buildSectionHeader('Lifestyle'),
              _buildPreviewRow(
                'Food Preference',
                _resolveLookup(
                  'food_preferences',
                  formData['food_preference_id'],
                ),
              ),
              _buildPreviewRow(
                'Smoking Habit',
                _resolveLookup('smoking_habits', formData['smoking_id']),
              ),
              _buildPreviewRow(
                'Drinking Habit',
                _resolveLookup('drinking_habits', formData['drinking_id']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6E1732),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveLookup(String table, int? id) {
    if (id == null || lookupData == null || !lookupData!.containsKey(table)) {
      return 'Not Provided';
    }
    final options = lookupData![table] as List<LookupOption>;
    final match = options.where((opt) => opt.id == id);
    if (match.isEmpty) return 'Not Provided';
    return match.first.label;
  }
}
