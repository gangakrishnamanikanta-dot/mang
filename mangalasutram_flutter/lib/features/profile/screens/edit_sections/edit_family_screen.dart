import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../services/profile_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditFamilyScreen extends StatefulWidget {
  const EditFamilyScreen({super.key});

  @override
  State<EditFamilyScreen> createState() => _EditFamilyScreenState();
}

class _EditFamilyScreenState extends State<EditFamilyScreen> {
  final ProfileService _profileService = getIt<ProfileService>();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _fatherName = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _motherName = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _brothers = TextEditingController();
  final _sisters = TextEditingController();
  final _nativePlace = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileService.getProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }
    _original = profile;
    _fatherName.text = profile.fatherName ?? '';
    _fatherOccupation.text = profile.fatherOccupation ?? '';
    _motherName.text = profile.motherName ?? '';
    _motherOccupation.text = profile.motherOccupation ?? '';
    _brothers.text = (profile.brothersCount ?? '').toString();
    _sisters.text = (profile.sistersCount ?? '').toString();
    _nativePlace.text = profile.nativePlace ?? '';

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{};
    if (_fatherName.text != (_original!.fatherName ?? '')) {
      patch['father_name'] = _fatherName.text;
    }
    if (_fatherOccupation.text != (_original!.fatherOccupation ?? '')) {
      patch['father_occupation'] = _fatherOccupation.text;
    }
    if (_motherName.text != (_original!.motherName ?? '')) {
      patch['mother_name'] = _motherName.text;
    }
    if (_motherOccupation.text != (_original!.motherOccupation ?? '')) {
      patch['mother_occupation'] = _motherOccupation.text;
    }
    if (_nativePlace.text != (_original!.nativePlace ?? '')) {
      patch['native_place'] = _nativePlace.text;
    }

    final br = int.tryParse(_brothers.text);
    if (br != null && br != _original!.brothersCount) {
      patch['brothers_count'] = br;
    }

    final sr = int.tryParse(_sisters.text);
    if (sr != null && sr != _original!.sistersCount) {
      patch['sisters_count'] = sr;
    }

    if (patch.isEmpty) {
      setState(() => _saving = false);
      Navigator.pop(context);
      return;
    }

    try {
      await _profileService.saveProfile(patch);
      if (mounted) Navigator.pop(context);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Family Details',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: _burgundy),
        actions: [
          _saving
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
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: _burgundy,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : SingleChildScrollView(
              child: Column(
                children: [
                  AppleFormSection(
                    title: 'Parents',
                    children: [
                      AppleFormRow(
                        controller: _fatherName,
                        label: "Father's Name",
                        hintText: 'Required',
                      ),
                      AppleFormRow(
                        controller: _fatherOccupation,
                        label: "Occupation",
                        hintText: 'Father\'s Occupation',
                      ),
                      AppleFormRow(
                        controller: _motherName,
                        label: "Mother's Name",
                        hintText: 'Required',
                      ),
                      AppleFormRow(
                        controller: _motherOccupation,
                        label: "Occupation",
                        hintText: 'Mother\'s Occupation',
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Siblings',
                    children: [
                      AppleFormRow(
                        controller: _brothers,
                        label: 'Brothers',
                        hintText: '0',
                        keyboardType: TextInputType.number,
                      ),
                      AppleFormRow(
                        controller: _sisters,
                        label: 'Sisters',
                        hintText: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Location',
                    children: [
                      AppleFormRow(
                        controller: _nativePlace,
                        label: 'Native Place',
                        hintText: 'City, State',
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
