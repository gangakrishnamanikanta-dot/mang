import 'package:flutter/material.dart';

class MandalaAvatarPicker extends StatelessWidget {
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onPickPhoto;

  const MandalaAvatarPicker({
    super.key,
    this.imageUrl,
    this.isUploading = false,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: isUploading
            ? null
            : () {
                Feedback.forTap(context);
                onPickPhoto();
              },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glowing Vedic Mandala Ring Outer Decoration
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC99A4B).withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC99A4B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Inner Photo Avatar
            ClipOval(
              child: Container(
                width: 116,
                height: 116,
                color: const Color(0xFFF5F0E8),
                child: isUploading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6E1732),
                          strokeWidth: 3,
                        ),
                      )
                    : (imageUrl != null && imageUrl!.isNotEmpty)
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
              ),
            ),

            // Gold Camera Badge
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC99A4B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_rounded,
          size: 48,
          color: Color(0xFFC99A4B),
        ),
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
