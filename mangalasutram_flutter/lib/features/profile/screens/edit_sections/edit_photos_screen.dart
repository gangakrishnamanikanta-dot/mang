import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../services/profile_service.dart';

class EditPhotosScreen extends StatefulWidget {
  const EditPhotosScreen({super.key});

  @override
  State<EditPhotosScreen> createState() => _EditPhotosScreenState();
}

class _EditPhotosScreenState extends State<EditPhotosScreen> {
  final ProfileService _profileService = getIt<ProfileService>();

  static const Color _burgundy = Color(0xFF6E1732);
  static const Color _gold = Color(0xFFC99A4B);
  static const Color _bgCream = Color(0xFFFBF8F1);

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
    FocusScope.of(context).unfocus();
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
    FocusScope.of(context).unfocus();
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
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      await _profileService.updateProfileFields({
        'profile_photo_url': _mainPhotoUrl,
        'additional_photo_urls': _additionalPhotos,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photos saved successfully! ✨'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
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
      backgroundColor: _bgCream,
      appBar: AppBar(
        title: Text(
          'Manage Photos',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF2B0912),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _bgCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _burgundy),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _burgundy,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveChanges,
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: _burgundy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
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
                  Text(
                    'Primary Portrait',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This is the first portrait prospective matches and families see.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A6A5E),
                      fontSize: 13.5,
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
                          width: 144,
                          height: 144,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: _gold, width: 2.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image: _mainPhotoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_mainPhotoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _mainPhotoUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 60,
                                  color: _burgundy,
                                )
                              : null,
                        ),
                        if (_isUploadingMain)
                          Container(
                            width: 144,
                            height: 144,
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
                              color: _burgundy,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gallery Portraits',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add up to $_maxAdditionalPhotos additional photos.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7A6A5E),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
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
                      if (index == _additionalPhotos.length &&
                          _additionalPhotos.length < _maxAdditionalPhotos) {
                        return GestureDetector(
                          onTap: _isUploadingAdditional
                              ? null
                              : _uploadAdditionalPhoto,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5D5C5),
                              ),
                            ),
                            child: _isUploadingAdditional
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: _burgundy,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_a_photo_rounded,
                                      color: _burgundy,
                                      size: 30,
                                    ),
                                  ),
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE6DFD5),
                              ),
                              image: DecorationImage(
                                image: NetworkImage(_additionalPhotos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => _removeAdditionalPhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
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
              color: _bgCream,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _burgundy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Photos',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
    );
  }
}
