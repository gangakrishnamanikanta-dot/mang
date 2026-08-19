import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../services/profile_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/theme.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditPhotosScreen extends StatefulWidget {
  const EditPhotosScreen({super.key});

  @override
  State<EditPhotosScreen> createState() => _EditPhotosScreenState();
}

class _EditPhotosScreenState extends State<EditPhotosScreen> {
  final ProfileService _profileService = getIt<ProfileService>();

  bool _loading = true;
  bool _isSaving = false;
  bool _isUploadingMain = false;
  bool _isUploadingAdditional = false;

  String? _mainPhotoUrl;
  List<String> _additionalPhotos = [];

  final int _maxAdditionalPhotos = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileService.getProfile();
    if (mounted && profile != null) {
      setState(() {
        _mainPhotoUrl = profile.profilePhotoUrl;
        _additionalPhotos = List<String>.from(
          profile.additionalPhotoUrls ?? [],
        );
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadMainPhoto() async {
    setState(() => _isUploadingMain = true);
    try {
      final url = await _profileService.pickAndUploadProfilePhoto();
      if (url != null && mounted) {
        setState(() {
          _mainPhotoUrl = url;
        });
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMain = false);
    }
  }

  Future<void> _uploadAdditionalPhoto() async {
    setState(() => _isUploadingAdditional = true);
    try {
      final url = await _profileService.pickAndUploadAdditionalPhoto();
      if (url != null && mounted) {
        setState(() {
          _additionalPhotos.add(url);
        });
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAdditional = false);
    }
  }

  void _removeAdditionalPhoto(int index) {
    setState(() {
      _additionalPhotos.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await _profileService.updateProfileFields({
        'profile_photo_url': _mainPhotoUrl,
        'additional_photo_urls': _additionalPhotos,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photos saved successfully!')),
        );
        Navigator.pop(context);
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      appBar: AppBar(
        title: Text(
          'Manage Photos',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFFFF8F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main Photo Section
                  Text(
                    'Main Profile Photo',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is the first photo people see on your profile.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: _isUploadingMain ? null : _uploadMainPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFDECDA),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            image: _mainPhotoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_mainPhotoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _mainPhotoUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        if (_isUploadingMain)
                          Container(
                            width: 140,
                            height: 140,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (!_isUploadingMain)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Additional Photos Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Additional Photos',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add up to $_maxAdditionalPhotos more photos to show your personality.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grid of Additional Photos
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemCount: _additionalPhotos.length < _maxAdditionalPhotos
                        ? _additionalPhotos.length + 1
                        : _maxAdditionalPhotos,
                    itemBuilder: (context, index) {
                      // If it's the last item and we haven't reached the max, show the Add button
                      if (index == _additionalPhotos.length &&
                          _additionalPhotos.length < _maxAdditionalPhotos) {
                        return GestureDetector(
                          onTap: _isUploadingAdditional
                              ? null
                              : _uploadAdditionalPhoto,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECDA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5D5C5),
                              ),
                            ),
                            child: _isUploadingAdditional
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_a_photo_rounded,
                                      color: AppColors.primary,
                                      size: 32,
                                    ),
                                  ),
                          ),
                        );
                      }

                      // Otherwise show the photo
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(_additionalPhotos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeAdditionalPhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
      bottomSheet: _loading
          ? null
          : Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Photos',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
    );
  }
}
