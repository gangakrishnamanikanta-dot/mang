import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mangalasutram/constants/theme.dart';
import '../../profile/services/profile_service.dart';
import 'package:mangalasutram/core/exceptions/app_exception.dart';

class LuxuryMultiPhotoPicker extends StatefulWidget {
  final String? mainPhotoUrl;
  final List<String> additionalPhotoUrls;
  final Function(String mainUrl, List<String> additionalUrls) onPhotosChanged;

  final ProfileService? profileService;

  const LuxuryMultiPhotoPicker({
    super.key,
    this.mainPhotoUrl,
    this.additionalPhotoUrls = const [],
    required this.onPhotosChanged,
    this.profileService,
  });

  @override
  State<LuxuryMultiPhotoPicker> createState() => _LuxuryMultiPhotoPickerState();
}

class _LuxuryMultiPhotoPickerState extends State<LuxuryMultiPhotoPicker> {
  ProfileService? _localProfileService;
  ProfileService get _profileService => widget.profileService ?? (_localProfileService ??= ProfileService());
  bool _isUploading = false;
  int? _uploadingIndex; // -1 for main, 0..4 for additionals

  void _showSourceSelector({required bool isMain}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D8CC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                isMain ? 'Upload Profile Photo' : 'Add to Sacred Gallery',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E1732),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please upload clear, modest photos in traditional or formal attire.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF8B7355),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(ImageSource.camera, isMain: isMain);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'From Gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(ImageSource.gallery, isMain: isMain);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEADBCE)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF6E1732)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3E2723),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source, {required bool isMain}) async {
    setState(() {
      _isUploading = true;
      _uploadingIndex = isMain ? -1 : widget.additionalPhotoUrls.length;
    });

    try {
      final url = isMain
          ? await _profileService.pickAndUploadProfilePhoto(source: source)
          : await _profileService.pickAndUploadAdditionalPhoto(source: source);

      if (url != null && mounted) {
        if (isMain) {
          widget.onPhotosChanged(url, widget.additionalPhotoUrls);
        } else {
          final updated = List<String>.from(widget.additionalPhotoUrls)..add(url);
          widget.onPhotosChanged(widget.mainPhotoUrl ?? '', updated);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMain ? 'Sacred profile photo updated!' : 'Photo added to your gallery!',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Photo upload failed. Please try again.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingIndex = null;
        });
      }
    }
  }

  void _deleteAdditionalPhoto(int index) {
    HapticFeedback.mediumImpact();
    final photoUrl = widget.additionalPhotoUrls[index];
    final updated = List<String>.from(widget.additionalPhotoUrls)..removeAt(index);
    widget.onPhotosChanged(widget.mainPhotoUrl ?? '', updated);
    _profileService.deletePhoto(photoUrl);
  }

  void _setAsMainPhoto(int index) {
    HapticFeedback.mediumImpact();
    final oldMain = widget.mainPhotoUrl;
    final newMain = widget.additionalPhotoUrls[index];
    final updatedAdditionals = List<String>.from(widget.additionalPhotoUrls)..removeAt(index);
    if (oldMain != null && oldMain.isNotEmpty) {
      updatedAdditionals.insert(0, oldMain);
    }
    widget.onPhotosChanged(newMain, updatedAdditionals);
  }

  @override
  Widget build(BuildContext context) {
    final hasMain = widget.mainPhotoUrl != null && widget.mainPhotoUrl!.isNotEmpty;

    return Column(
      children: [
        // 1. Primary Avatar (Mandala Ring)
        Center(
          child: GestureDetector(
            onTap: _isUploading
                ? null
                : () => _showSourceSelector(isMain: true),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Mandala Ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Main Image
                ClipOval(
                  child: Container(
                    width: 118,
                    height: 118,
                    color: const Color(0xFFF5F0E8),
                    child: (_isUploading && _uploadingIndex == -1)
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6E1732),
                              strokeWidth: 2.5,
                            ),
                          )
                        : hasMain
                            ? Image.network(
                                widget.mainPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildMainPlaceholder(),
                              )
                            : _buildMainPlaceholder(),
                  ),
                ),

                // Camera Action Badge
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6E1732),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.gold,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          hasMain ? 'Main Profile Photo' : 'Tap to Add Main Photo',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8B7355),
          ),
        ),

        const SizedBox(height: 20),

        // 2. Additional Gallery Photos Header (Max 5)
        Row(
          children: [
            const Icon(Icons.collections_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              'Additional Photos (${widget.additionalPhotoUrls.length}/5)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3E39),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Gallery Horizontal Scroll / Grid
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: (widget.additionalPhotoUrls.length < 5)
                ? widget.additionalPhotoUrls.length + 1
                : 5,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == widget.additionalPhotoUrls.length && widget.additionalPhotoUrls.length < 5) {
                // Add Photo Button
                return GestureDetector(
                  onTap: _isUploading ? null : () => _showSourceSelector(isMain: false),
                  child: Container(
                    width: 76,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFC99A4B).withValues(alpha: 0.6),
                        style: BorderStyle.solid,
                        width: 1.2,
                      ),
                    ),
                    child: (_isUploading && _uploadingIndex == widget.additionalPhotoUrls.length)
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6E1732),
                              ),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, color: AppColors.gold, size: 26),
                              SizedBox(height: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B7355),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }

              // Uploaded Additional Photo Slot
              final photoUrl = widget.additionalPhotoUrls[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 76,
                      height: 90,
                      color: const Color(0xFFF5F0E8),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_rounded, size: 24, color: Color(0xFFC99A4B)),
                        ),
                      ),
                    ),
                  ),

                  // Actions menu / Make Primary & Delete
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _deleteAdditionalPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: GestureDetector(
                      onTap: () => _setAsMainPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E1732).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Make Main',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_rounded, size: 44, color: Color(0xFFC99A4B)),
        SizedBox(height: 2),
        Text(
          'Add Photo',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B7355),
          ),
        ),
      ],
    );
  }
}
