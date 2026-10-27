import 'package:flutter/material.dart';
import '../../../models/lookup_option.dart';
import '../widgets/luxury_selection_chip.dart';
import '../widgets/luxury_text_field.dart';

class Step5Lifestyle extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step5Lifestyle({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step5Lifestyle> createState() => _Step5LifestyleState();
}

class _Step5LifestyleState extends State<Step5Lifestyle> {
  late TextEditingController _aboutMeController;

  List<LookupOption> get _foodOptions => widget.lookupData?['food_preferences'] ?? [];
  List<LookupOption> get _smokingOptions => widget.lookupData?['smoking_habits'] ?? [];
  List<LookupOption> get _drinkingOptions => widget.lookupData?['drinking_habits'] ?? [];

  static const List<String> _fitnessOptions = [
    'Daily Yoga / Pranayama 🧘',
    'Morning Walking 🚶',
    'Gym & Fitness 🏋️',
    'Sports & Outdoor 🏸',
    'Casual / Occasional',
  ];

  static const List<String> _personalityOptions = [
    'Introvert',
    'Ambivert',
    'Extrovert',
  ];

  static const List<String> _culturalInterestOptions = [
    'Carnatic Music 🎵',
    'Sanskrit Stotrams 📜',
    'Vedic Heritage 🪔',
    'Temple Architecture 🏛️',
    'Classical Dance 💃',
    'Traditional Cooking 🍲',
    'Pilgrimages 🌄',
    'Reading & Philosophy 📖',
  ];

  late List<String> _selectedCulturalInterests;

  @override
  void initState() {
    super.initState();
    _aboutMeController = TextEditingController(
      text: widget.formData['about_me'] ?? '',
    );
    final rawList = widget.formData['cultural_interests'];
    if (rawList is List) {
      _selectedCulturalInterests = List<String>.from(rawList);
    } else {
      _selectedCulturalInterests = [];
    }
  }

  @override
  void dispose() {
    _aboutMeController.dispose();
    super.dispose();
  }

  void _toggleCulturalInterest(String interest) {
    setState(() {
      if (_selectedCulturalInterests.contains(interest)) {
        _selectedCulturalInterests.remove(interest);
      } else {
        _selectedCulturalInterests.add(interest);
      }
      widget.onUpdate('cultural_interests', _selectedCulturalInterests);
    });
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodPrefId = widget.formData['food_preference_id'];
    final smokingId = widget.formData['smoking_id'];
    final drinkingId = widget.formData['drinking_id'];
    final selectedFitness = widget.formData['fitness_habits'] as String?;
    final selectedPersonality = widget.formData['personality_type'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Lifestyle & Personal Values',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E1732),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your daily habits, diet, personality, and cultural passions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // Card 1: Dietary & Personal Habits
          _buildSectionContainer(
            title: 'Dietary & Daily Habits',
            icon: Icons.restaurant_rounded,
            children: [
              const Text(
                'Food / Diet Preference',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _foodOptions.map((opt) {
                  final isSelected = foodPrefId == opt.id;
                  String? emoji = '🌿';
                  if (opt.label.toLowerCase().contains('egg')) emoji = '🥚';
                  if (opt.label.toLowerCase().contains('non')) emoji = '🍗';
                  if (opt.label.toLowerCase().contains('pure')) emoji = '🌱';

                  return LuxurySelectionChip(
                    label: opt.label,
                    isSelected: isSelected,
                    emoji: emoji,
                    onSelected: () {
                      widget.onUpdate('food_preference_id', opt.id);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Smoking Habit',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _smokingOptions.map((opt) {
                  final isSelected = smokingId == opt.id;
                  return LuxurySelectionChip(
                    label: opt.label,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('smoking_id', opt.id);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Drinking Habit',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _drinkingOptions.map((opt) {
                  final isSelected = drinkingId == opt.id;
                  return LuxurySelectionChip(
                    label: opt.label,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('drinking_id', opt.id);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 2: Fitness & Personality
          _buildSectionContainer(
            title: 'Fitness & Personality',
            icon: Icons.fitness_center_rounded,
            children: [
              const Text(
                'Personality Type',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _personalityOptions.map((opt) {
                  final isSelected = selectedPersonality == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('personality_type', opt);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Fitness Routine',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _fitnessOptions.map((opt) {
                  final isSelected = selectedFitness == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('fitness_habits', opt);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 3: Cultural Interests & Hobbies (Multi-Select)
          _buildSectionContainer(
            title: 'Cultural Passions & Hobbies',
            icon: Icons.music_note_rounded,
            children: [
              const Text(
                'Select your passions and traditions (Tap all that apply)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8B7355),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _culturalInterestOptions.map((opt) {
                  final isSelected = _selectedCulturalInterests.contains(opt);
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () => _toggleCulturalInterest(opt),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 4: About Myself
          _buildSectionContainer(
            title: 'About Myself',
            icon: Icons.auto_stories_rounded,
            children: [
              LuxuryTextField(
                label: 'Auspicious Bio & Life Vision',
                hintText: 'Share a few words about your values, worldview, and what you cherish in a sacred union...',
                controller: _aboutMeController,
                maxLines: 4,
                onChanged: (val) => widget.onUpdate('about_me', val),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
