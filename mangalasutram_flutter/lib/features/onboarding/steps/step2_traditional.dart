import 'package:flutter/material.dart';
import '../../../shared/widgets/luxury_time_picker.dart';
import '../../../models/lookup_option.dart';
import '../widgets/luxury_dropdown_field.dart';
import '../widgets/luxury_text_field.dart';

class Step2Traditional extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step2Traditional({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step2Traditional> createState() => _Step2TraditionalState();
}

class _Step2TraditionalState extends State<Step2Traditional> {
  late TextEditingController _pravaraController;
  late TextEditingController _kuladevataController;
  late TextEditingController _placeOfBirthController;

  List<LookupOption> get _gothrams => widget.lookupData?['gothrams'] ?? [];
  List<LookupOption> get _vedaShakhas => widget.lookupData?['veda_shakhas'] ?? [];
  List<LookupOption> get _nakshatras => widget.lookupData?['nakshatras'] ?? [];
  List<LookupOption> get _rashis => widget.lookupData?['rashis'] ?? [];
  List<LookupOption> get _padas => widget.lookupData?['padas'] ?? [];

  static const List<String> _sampradayamOptions = [
    'Smartha (Advaita)',
    'Sri Vaishnava (Tenkalai)',
    'Sri Vaishnava (Vadakalai)',
    'Madhwa (Dvaita)',
    'Niyogi',
    'Vaidiki',
    'Other Brahmin Tradition',
  ];

  static const List<String> _kujaDoshamOptions = [
    'No Dosham',
    'Kuja Dosham / Manglik',
    'Don\'t Know',
  ];

  static const List<String> _sandhyavandanamOptions = [
    'Daily (Trikala)',
    'Once daily (Pratah)',
    'Occasional / Weekends',
    'Rarely / Not Practiced',
  ];

  static const List<String> _dailyPoojaOptions = [
    'Daily Morning & Evening',
    'Daily Morning Pooja',
    'Festivals & Weekends',
    'Occasional',
  ];

  static const List<String> _slokaOptions = [
    'Regular (Daily Stotrams)',
    'Occasional Chanting',
    'Learning / Interested',
    'None',
  ];

  static const List<String> _templeOptions = [
    'Daily / Multiple times a week',
    'Weekly on auspicious days',
    'Monthly visits',
    'On major festivals & functions',
  ];

  @override
  void initState() {
    super.initState();
    _pravaraController = TextEditingController(
      text: widget.formData['pravara'] ?? '',
    );
    _kuladevataController = TextEditingController(
      text: widget.formData['kuladevata'] ?? '',
    );
    _placeOfBirthController = TextEditingController(
      text: widget.formData['place_of_birth'] ?? '',
    );
  }

  @override
  void dispose() {
    _pravaraController.dispose();
    _kuladevataController.dispose();
    _placeOfBirthController.dispose();
    super.dispose();
  }

  void _pickTimeOfBirth() async {
    FocusScope.of(context).unfocus();
    TimeOfDay initialTime = TimeOfDay.now();
    final currentStr = widget.formData['time_of_birth'] as String?;
    if (currentStr != null && currentStr.isNotEmpty) {
      try {
        final parts = currentStr.split(':');
        int hour = int.parse(parts[0]);
        final minPeriod = parts[1].split(' ');
        int minute = int.parse(minPeriod[0]);
        if (minPeriod.length > 1 && minPeriod[1].toUpperCase() == 'PM' && hour < 12) {
          hour += 12;
        } else if (minPeriod.length > 1 && minPeriod[1].toUpperCase() == 'AM' && hour == 12) {
          hour = 0;
        }
        initialTime = TimeOfDay(hour: hour, minute: minute);
      } catch (_) {}
    }

    final picked = await LuxuryTimePicker.show(
      context: context,
      initialTime: initialTime,
      title: 'Select Time of Birth',
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.pm ? 'PM' : 'AM';
      final formatted = '$hour:$minute $period';
      widget.onUpdate('time_of_birth', formatted);
      setState(() {});
    }
  }

  List<LookupOption> _toLookupOptions(List<String> list) {
    return list.asMap().entries.map((e) => LookupOption(id: e.key + 1, label: e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Lookup selected labels
    final gothramId = widget.formData['gothram_id'];
    final gothramLabel = _gothrams.firstWhere(
      (o) => o.id == gothramId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final nakshatraId = widget.formData['nakshatra_id'];
    final nakshatraLabel = _nakshatras.firstWhere(
      (o) => o.id == nakshatraId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final rashiId = widget.formData['rashi_id'];
    final rashiLabel = _rashis.firstWhere(
      (o) => o.id == rashiId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final padaId = widget.formData['pada_id'];
    final padasList = _padas.isNotEmpty
        ? _padas
        : [
            LookupOption(id: 1, label: 'Pada 1'),
            LookupOption(id: 2, label: 'Pada 2'),
            LookupOption(id: 3, label: 'Pada 3'),
            LookupOption(id: 4, label: 'Pada 4'),
          ];
    final padaLabel = padasList.firstWhere(
      (o) => o.id == padaId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final vedaShakhaId = widget.formData['veda_shakha_id'];
    final vedaShakhaLabel = _vedaShakhas.firstWhere(
      (o) => o.id == vedaShakhaId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final selectedSampradayam = widget.formData['sampradayam'] as String?;
    final selectedKujaDosham = widget.formData['kuja_dosham'] as String?;
    final selectedSandhya = widget.formData['sandhyavandanam'] as String?;
    final selectedPooja = widget.formData['daily_pooja'] as String?;
    final selectedSloka = widget.formData['sloka_chanting'] as String?;
    final selectedTemple = widget.formData['temple_visits'] as String?;
    final timeOfBirth = widget.formData['time_of_birth'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Vedic Lineage & Horoscope',
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
            'Sacred ancestry and astrological alignment for Guna Milan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // 1. Sampradayam / Tradition Dropdown
          LuxuryDropdownField(
            label: 'Sampradayam / Tradition',
            placeholder: 'Select Tradition (e.g. Smartha, Sri Vaishnava)',
            selectedValue: selectedSampradayam,
            options: _toLookupOptions(_sampradayamOptions),
            prefixIcon: const Icon(Icons.temple_hindu_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('sampradayam', opt.label);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 2. Gothram Dropdown (Searchable)
          LuxuryDropdownField(
            label: 'Gothram',
            placeholder: 'Search & Select Gothram',
            selectedValue: gothramLabel.isNotEmpty ? gothramLabel : null,
            isRequired: true,
            options: _gothrams,
            prefixIcon: const Icon(Icons.account_tree_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('gothram_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 3. Nakshatra Dropdown (Searchable)
          LuxuryDropdownField(
            label: 'Nakshatra (Birth Star)',
            placeholder: 'Search & Select 27 Birth Stars',
            selectedValue: nakshatraLabel.isNotEmpty ? nakshatraLabel : null,
            isRequired: true,
            options: _nakshatras,
            prefixIcon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('nakshatra_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 4. Rashi Dropdown
          LuxuryDropdownField(
            label: 'Rashi (Moon Sign)',
            placeholder: 'Select Moon Sign',
            selectedValue: rashiLabel.isNotEmpty ? rashiLabel : null,
            options: _rashis,
            prefixIcon: const Icon(Icons.brightness_2_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('rashi_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 5. Pada Dropdown
          LuxuryDropdownField(
            label: 'Pada / Quarter',
            placeholder: 'Select Pada (1, 2, 3, 4)',
            selectedValue: padaLabel.isNotEmpty ? padaLabel : null,
            options: padasList,
            prefixIcon: const Icon(Icons.format_list_numbered_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('pada_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 6. Kuja Dosham / Manglik Dropdown
          LuxuryDropdownField(
            label: 'Kuja Dosham / Manglik Status',
            placeholder: 'Select Manglik Status',
            selectedValue: selectedKujaDosham,
            options: _toLookupOptions(_kujaDoshamOptions),
            prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('kuja_dosham', opt.label);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 7. Time of Birth (Cupertino Luxury Wheel Card)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Time of Birth (Optional)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTimeOfBirth,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: timeOfBirth != null ? const Color(0xFFC99A4B) : const Color(0xFFE5DDD0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: Color(0xFFC99A4B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (timeOfBirth != null && timeOfBirth.isNotEmpty)
                              ? timeOfBirth
                              : 'Select Time of Birth',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: timeOfBirth != null ? FontWeight.w600 : FontWeight.w400,
                            color: timeOfBirth != null ? const Color(0xFF2C1810) : const Color(0xFFB0A294),
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B7355), size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 8. Place of Birth
          LuxuryTextField(
            label: 'Place of Birth (Optional)',
            hintText: 'e.g. Hyderabad, Chennai, Bangalore, Tirupati',
            controller: _placeOfBirthController,
            prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('place_of_birth', val),
          ),

          const SizedBox(height: 20),

          // 9. Veda Shakha Dropdown
          if (_vedaShakhas.isNotEmpty) ...[
            LuxuryDropdownField(
              label: 'Veda Shakha (Optional)',
              placeholder: 'Select Veda Shakha (e.g. Rigveda, Yajurveda)',
              selectedValue: vedaShakhaLabel.isNotEmpty ? vedaShakhaLabel : null,
              options: _vedaShakhas,
              prefixIcon: const Icon(Icons.menu_book_rounded, color: Color(0xFFC99A4B), size: 20),
              onSelected: (opt) {
                widget.onUpdate('veda_shakha_id', opt.id);
                setState(() {});
              },
            ),
            const SizedBox(height: 20),
          ],

          // 10. Pravara & Kuladevata
          LuxuryTextField(
            label: 'Pravara (Optional)',
            hintText: 'e.g. Thrayarisheya, Pancharisheya (Harithasa, Koundinya...)',
            controller: _pravaraController,
            prefixIcon: const Icon(Icons.bookmark_border_rounded, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('pravara', val),
          ),

          const SizedBox(height: 20),

          LuxuryTextField(
            label: 'Kuladevata / Family Deity (Optional)',
            hintText: 'e.g. Sri Venkateswara Swamy, Goddess Durga, Lord Shiva',
            controller: _kuladevataController,
            prefixIcon: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('kuladevata', val),
          ),

          const SizedBox(height: 24),

          // 11. Spiritual Practices Dropdowns
          const Text(
            'Spiritual Practices & Routine',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E1732),
            ),
          ),
          const SizedBox(height: 14),

          LuxuryDropdownField(
            label: 'Sandhyavandanam Practice',
            placeholder: 'Select Sandhyavandanam Routine',
            selectedValue: selectedSandhya,
            options: _toLookupOptions(_sandhyavandanamOptions),
            prefixIcon: const Icon(Icons.self_improvement_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('sandhyavandanam', opt.label);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          LuxuryDropdownField(
            label: 'Daily Pooja Practice',
            placeholder: 'Select Daily Pooja Routine',
            selectedValue: selectedPooja,
            options: _toLookupOptions(_dailyPoojaOptions),
            prefixIcon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('daily_pooja', opt.label);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          LuxuryDropdownField(
            label: 'Sloka & Stotram Chanting',
            placeholder: 'Select Sloka Chanting Habit',
            selectedValue: selectedSloka,
            options: _toLookupOptions(_slokaOptions),
            prefixIcon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('sloka_chanting', opt.label);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          LuxuryDropdownField(
            label: 'Temple Visits',
            placeholder: 'Select Temple Visit Frequency',
            selectedValue: selectedTemple,
            options: _toLookupOptions(_templeOptions),
            prefixIcon: const Icon(Icons.nature_people_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('temple_visits', opt.label);
              setState(() {});
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
