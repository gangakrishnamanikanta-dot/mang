import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/apple_text_field.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../models/profile.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/exceptions/app_exception.dart';

class Step1BasicInfo extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step1BasicInfo({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step1BasicInfo> createState() => _Step1BasicInfoState();
}

class _Step1BasicInfoState extends State<Step1BasicInfo> {
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  final List<LookupOption> _heightOptions = List.generate(48, (index) {
    final inches = 48 + index;
    final ft = inches ~/ 12;
    final ins = inches % 12;
    return LookupOption(id: inches, label: "$ft'$ins\"");
  });

  final List<LookupOption> _createdForOptions = [
    LookupOption(id: 1, label: 'Self'),
    LookupOption(id: 2, label: 'Son'),
    LookupOption(id: 3, label: 'Daughter'),
    LookupOption(id: 4, label: 'Brother'),
    LookupOption(id: 5, label: 'Sister'),
    LookupOption(id: 6, label: 'Friend'),
    LookupOption(id: 7, label: 'Relative'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.formData['full_name'] ?? '',
    );
    _dobController = TextEditingController(
      text: widget.formData['date_of_birth'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.formData['phone'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.formData['email'] ?? '',
    );

    _dobController.addListener(_onDobChanged);
  }

  void _onDobChanged() {
    final raw = _dobController.text.replaceAll('-', '');
    if (raw.length <= 8) {
      String formatted = '';
      for (int i = 0; i < raw.length && i < 8; i++) {
        if (i == 4 || i == 6) formatted += '-';
        formatted += raw[i];
      }
      if (formatted != _dobController.text) {
        _dobController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      widget.formData['date_of_birth'] = formatted;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final profileService = ProfileService();
    try {
      final url = await profileService.pickAndUploadProfilePhoto();
      if (url != null && mounted) {
        widget.onUpdate('profile_photo_url', url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded!'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException
                  ? e.message
                  : 'Something went wrong. Please try again.',
            ),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadAdditionalPhoto() async {
    final profileService = ProfileService();
    try {
      final url = await profileService.pickAndUploadAdditionalPhoto();
      if (url != null && mounted) {
        final currentUrls = List<String>.from(
          widget.formData['additional_photo_urls'] ?? [],
        );
        currentUrls.add(url);
        widget.onUpdate('additional_photo_urls', currentUrls);

        // Auto-save to database immediately
        try {
          await profileService.updateProfileFields({
            'additional_photo_urls': currentUrls,
          });
        } catch (e) {
          debugPrint('Failed to auto-save additional photos: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Additional photo uploaded!'),
              backgroundColor: Color(0xFF34C759),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException
                  ? e.message
                  : 'Something went wrong. Please try again.',
            ),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _deleteAdditionalPhoto(int index) async {
    final currentUrls = List<String>.from(
      widget.formData['additional_photo_urls'] ?? [],
    );
    if (index >= 0 && index < currentUrls.length) {
      currentUrls.removeAt(index);
      widget.onUpdate('additional_photo_urls', currentUrls);

      // Auto-save to database immediately
      try {
        await ProfileService().updateProfileFields({
          'additional_photo_urls': currentUrls,
        });
      } catch (e) {
        debugPrint('Failed to auto-save after deleting photo: $e');
      }
    }
  }

  Widget _buildPhotoItem({
    required String? url,
    required bool isMain,
    required VoidCallback? onTap,
    required VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
              ),
              child: url != null && url.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Image.network failed to load: $url');
                          debugPrint('Error: $error');
                          return const Icon(
                            Icons.camera_alt,
                            color: Color(0xFF8E8E93),
                            size: 32,
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF8E8E93),
                        size: 32,
                      ),
                    ),
            ),
            if (isMain)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Text(
                    'Main',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (onDelete != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickAndUploadAdditionalPhoto,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: const Center(
          child: Icon(Icons.add_a_photo, color: Color(0xFF8E8E93), size: 32),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }

  Widget _buildDropdownContainer(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFC7C7CC)),
        ],
      ),
    );
  }

  Widget _buildSelectField(
    String label,
    String fieldKey,
    List<LookupOption> options,
  ) {
    final valueId = widget.formData[fieldKey];
    final selectedOption = options.firstWhere(
      (opt) => opt.id == valueId,
      orElse: () => LookupOption(id: -1, label: 'Not Provided'),
    );

    return GestureDetector(
      onTap: () async {
        final result = await BottomSheetSelector.show(
          context: context,
          title: 'Select $label',
          options: options,
          selectedOption: selectedOption.id == -1 ? null : selectedOption,
        );
        if (result != null) {
          widget.onUpdate(fieldKey, result.id);
        }
      },
      child: _buildDropdownContainer(
        selectedOption.id == -1 ? 'Select $label' : selectedOption.label,
      ),
    );
  }

  Widget _buildSelectFieldForString(
    String label,
    String fieldKey,
    List<LookupOption> options,
  ) {
    final valueStr = widget.formData[fieldKey];
    final selectedOption = options.firstWhere(
      (opt) => opt.label == valueStr,
      orElse: () => LookupOption(id: -1, label: 'Not Provided'),
    );

    return GestureDetector(
      onTap: () async {
        final result = await BottomSheetSelector.show(
          context: context,
          title: 'Select $label',
          options: options,
          selectedOption: selectedOption.id == -1 ? null : selectedOption,
        );
        if (result != null) {
          widget.onUpdate(fieldKey, result.label);
        }
      },
      child: _buildDropdownContainer(
        selectedOption.id == -1 ? 'Select $label' : selectedOption.label,
      ),
    );
  }

  Widget _buildGenderSelector() {
    final gender = widget.formData['gender'] ?? '';
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onUpdate('gender', 'Male'),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: gender == 'Male' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: gender == 'Male'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Male',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: gender == 'Male'
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: gender == 'Male'
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFF8E8E93),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onUpdate('gender', 'Female'),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: gender == 'Female' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: gender == 'Female'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Female',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: gender == 'Female'
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: gender == 'Female'
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFF8E8E93),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.formData['profile_photo_url']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Photos (Max 6)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Main Photo
                _buildPhotoItem(
                  url: photoUrl,
                  isMain: true,
                  onTap: _pickAndUploadPhoto,
                  onDelete: null,
                ),
                // Additional Photos
                ...List.generate(
                  (widget.formData['additional_photo_urls'] as List?)?.length ??
                      0,
                  (index) {
                    final urls = List<String>.from(
                      widget.formData['additional_photo_urls'] ?? [],
                    );
                    return _buildPhotoItem(
                      url: urls[index],
                      isMain: false,
                      onTap: null, // don't replace, just delete and add new
                      onDelete: () => _deleteAdditionalPhoto(index),
                    );
                  },
                ),
                // Add button if under 5 additional photos (6 total)
                if (((widget.formData['additional_photo_urls'] as List?)
                            ?.length ??
                        0) <
                    5)
                  _buildAddPhotoButton(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Basic Details',
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
            'Let\'s start with your fundamental information.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

          const SizedBox(height: 16),

          _buildSectionLabel('Profile created for'),
          _buildSelectFieldForString(
            'Profile created for',
            'created_for',
            _createdForOptions,
          ),

          _buildSectionLabel('Full Name'),
          AppleTextField(
            controller: _nameController,
            hintText: 'Full Name',
            prefixIcon: Icons.person_outline,
            onChanged: (val) => widget.formData['full_name'] = val,
          ),

          _buildSectionLabel('Gender'),
          _buildGenderSelector(),

          _buildSectionLabel('Date of Birth'),
          AppleTextField(
            controller: _dobController,
            hintText: 'YYYY-MM-DD',
            prefixIcon: Icons.calendar_today_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: (val) => widget.formData['date_of_birth'] = val,
          ),

          _buildSectionLabel('Height'),
          _buildSelectField('Height', 'height_inches', _heightOptions),

          _buildSectionLabel('Mobile Number'),
          AppleTextField(
            controller: _phoneController,
            hintText: 'Phone Number',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            onChanged: (val) => widget.formData['phone'] = val,
          ),

          _buildSectionLabel('Email Address'),
          AppleTextField(
            controller: _emailController,
            hintText: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            onChanged: (val) => widget.formData['email'] = val,
          ),

          if (widget.lookupData != null) ...[
            _buildSectionLabel('Marital Status'),
            _buildSelectField(
              'Marital Status',
              'marital_status_id',
              widget.lookupData!['marital_statuses'] ?? [],
            ),

            _buildSectionLabel('Mother Tongue'),
            _buildSelectField(
              'Mother Tongue',
              'mother_tongue_id',
              widget.lookupData!['mother_tongues'] ?? [],
            ),

            _buildSectionLabel('Caste'),
            _buildSelectField(
              'Caste',
              'caste_id',
              widget.lookupData!['castes'] ?? [],
            ),
          ],

          _buildSectionLabel('Sub Caste'),
          AppleTextField(
            hintText: 'Sub Caste',
            prefixIcon: Icons.people_outline,
            onChanged: (val) => widget.formData['sub_caste'] = val,
            controller: TextEditingController(
              text: widget.formData['sub_caste'] ?? '',
            ),
          ),

          const SizedBox(height: 32), // Bottom padding before CTA
        ],
      ),
    );
  }
}
