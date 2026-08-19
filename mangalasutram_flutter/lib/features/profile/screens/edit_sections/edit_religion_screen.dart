import 'package:flutter/material.dart';
import '../../../../core/di.dart';
import '../../../../models/profile.dart';
import '../../../../shared/widgets/apple_settings_form.dart';
import '../../../../shared/widgets/bottom_sheet_selector.dart';
import '../../services/profile_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../../core/exceptions/app_exception.dart';

class EditReligionScreen extends StatefulWidget {
  const EditReligionScreen({super.key});

  @override
  State<EditReligionScreen> createState() => _EditReligionScreenState();
}

class _EditReligionScreenState extends State<EditReligionScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);

  Profile? _original;
  bool _loading = true;
  bool _saving = false;

  final _subCaste = TextEditingController();
  final _pravara = TextEditingController();

  LookupOption? _gothramOpt;
  LookupOption? _vedaShakhaOpt;
  LookupOption? _nakshatraOpt;
  LookupOption? _rashiOpt;

  Map<String, List<LookupOption>>? _lookupData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _profileService.getProfile(),
      _lookupService.fetchAllProfileLookups(),
    ]);
    if (!mounted) return;

    final profile = results[0] as Profile?;
    _lookupData = results[1] as Map<String, List<LookupOption>>?;

    if (profile == null) {
      setState(() => _loading = false);
      return;
    }
    _original = profile;

    _subCaste.text = profile.subCaste ?? '';
    _pravara.text = profile.pravara ?? '';

    _gothramOpt = profile.gothramId != null
        ? LookupOption(
            id: profile.gothramId!,
            label: _labelFor(profile.gothramId, 'gothrams'),
          )
        : null;
    _vedaShakhaOpt = profile.vedaShakhaId != null
        ? LookupOption(
            id: profile.vedaShakhaId!,
            label: _labelFor(profile.vedaShakhaId, 'veda_shakhas'),
          )
        : null;
    _nakshatraOpt = profile.nakshatraId != null
        ? LookupOption(
            id: profile.nakshatraId!,
            label: _labelFor(profile.nakshatraId, 'nakshatras'),
          )
        : null;
    _rashiOpt = profile.rashiId != null
        ? LookupOption(
            id: profile.rashiId!,
            label: _labelFor(profile.rashiId, 'rashis'),
          )
        : null;

    setState(() => _loading = false);
  }

  String _labelFor(int? id, String tableKey) {
    if (id == null || _lookupData == null) return '';
    final list = _lookupData![tableKey] ?? [];
    try {
      return list.firstWhere((e) => e.id == id).label;
    } catch (_) {
      return '';
    }
  }

  Future<void> _save() async {
    if (_original == null) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{};
    if (_subCaste.text != (_original!.subCaste ?? '')) {
      patch['sub_caste'] = _subCaste.text;
    }
    if (_pravara.text != (_original!.pravara ?? '')) {
      patch['pravara'] = _pravara.text;
    }

    if (_gothramOpt?.id != null && _gothramOpt!.id != _original!.gothramId) {
      patch['gothram_id'] = _gothramOpt!.id;
    }
    if (_vedaShakhaOpt?.id != null &&
        _vedaShakhaOpt!.id != _original!.vedaShakhaId) {
      patch['veda_shakha_id'] = _vedaShakhaOpt!.id;
    }
    if (_nakshatraOpt?.id != null &&
        _nakshatraOpt!.id != _original!.nakshatraId) {
      patch['nakshatra_id'] = _nakshatraOpt!.id;
    }
    if (_rashiOpt?.id != null && _rashiOpt!.id != _original!.rashiId) {
      patch['rashi_id'] = _rashiOpt!.id;
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

  void _showSelector(String type, void Function(LookupOption) onSelect) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _burgundy)),
    );

    String table = type;
    if (type == 'gothram') table = 'gothrams';
    if (type == 'veda_shakha') table = 'veda_shakhas';
    if (type == 'nakshatra') table = 'nakshatras';
    if (type == 'rashi') table = 'rashis';

    final options = await _lookupService.fetchTable(table);
    if (!mounted) return;
    Navigator.pop(context);

    if (!mounted) return;
    final res = await BottomSheetSelector.show(
      context: context,
      title: type.toUpperCase(),
      options: options,
    );
    if (res != null) {
      setState(() {
        onSelect(res);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Religious Background',
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
                    title: 'Community',
                    children: [
                      AppleFormRow(
                        controller: _subCaste,
                        label: 'Sub-caste',
                        hintText: 'Optional',
                      ),
                      AppleFormRow(
                        label: 'Gothram',
                        value: _gothramOpt?.label,
                        hintText: 'Select Gothram',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () =>
                            _showSelector('gothram', (o) => _gothramOpt = o),
                      ),
                      AppleFormRow(
                        controller: _pravara,
                        label: 'Pravara',
                        hintText: 'Optional',
                      ),
                      AppleFormRow(
                        label: 'Veda Shakha',
                        value: _vedaShakhaOpt?.label,
                        hintText: 'Select Shakha',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showSelector(
                          'veda_shakha',
                          (o) => _vedaShakhaOpt = o,
                        ),
                      ),
                    ],
                  ),
                  AppleFormSection(
                    title: 'Astrology',
                    children: [
                      AppleFormRow(
                        label: 'Nakshatra',
                        value: _nakshatraOpt?.label,
                        hintText: 'Select Nakshatra',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () => _showSelector(
                          'nakshatra',
                          (o) => _nakshatraOpt = o,
                        ),
                      ),
                      AppleFormRow(
                        label: 'Rashi',
                        value: _rashiOpt?.label,
                        hintText: 'Select Rashi',
                        isReadOnly: true,
                        showChevron: true,
                        onTap: () =>
                            _showSelector('rashi', (o) => _rashiOpt = o),
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
