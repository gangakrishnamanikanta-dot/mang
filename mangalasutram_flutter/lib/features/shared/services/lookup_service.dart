import 'package:flutter/foundation.dart';
import '../../../models/profile.dart';
import '../../auth/services/supabase_service.dart';

class LookupService {
  final Map<String, String> _tableLabelColumns = {
    'marital_statuses': 'status',
    'mother_tongues': 'language',
    'castes': 'caste',
    'heights': 'display',
    'gothrams': 'gothram',
    'veda_shakhas': 'shakha',
    'nakshatras': 'nakshatra',
    'rashis': 'rashi',
    'padas': 'pada',
    'education_levels': 'level',
    'occupations': 'occupation',
    'annual_incomes': 'label',
    'family_types': 'type',
    'food_preferences': 'preference',
    'smoking_habits': 'habit',
    'drinking_habits': 'habit',
    'countries': 'country',
    'profile_visibility_options': 'option',
  };

  static Map<String, List<LookupOption>>? _cache;
  static Future<Map<String, List<LookupOption>>>? _fetchFuture;

  Future<Map<String, List<LookupOption>>> fetchAllProfileLookups() async {
    if (_cache != null) return _cache!;
    if (_fetchFuture != null) return _fetchFuture!;

    _fetchFuture = _performFetchAll();
    final result = await _fetchFuture!;
    _fetchFuture = null;
    return result;
  }

  Future<Map<String, List<LookupOption>>> _performFetchAll() async {
    final client = SupabaseService.client;
    final Map<String, List<LookupOption>> result = {};

    await Future.wait(
      _tableLabelColumns.entries.map((entry) async {
        final table = entry.key;
        final labelColumn = entry.value;
        try {
          final response = await client
              .from(table)
              .select('id, $labelColumn')
              .order('id', ascending: true);
          result[table] = (response as List)
              .map(
                (row) => LookupOption(
                  id: row['id'] as int,
                  label: row[labelColumn].toString(),
                ),
              )
              .toList();
        } catch (e) {
          debugPrint('Error fetching $table: $e');
          result[table] = [];
        }
      }),
    );

    _cache = result;
    return result;
  }

  Future<List<LookupOption>> fetchTable(String table) async {
    final labelColumn = _tableLabelColumns[table] ?? 'name';
    try {
      final response = await SupabaseService.client
          .from(table)
          .select('id, $labelColumn')
          .order('id', ascending: true);
      return (response as List)
          .map(
            (row) => LookupOption(
              id: row['id'] as int,
              label: row[labelColumn].toString(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching $table: $e');
      return [];
    }
  }

  Future<List<LookupOption>> getHeights() => fetchTable('heights');
  Future<List<LookupOption>> getEducationLevels() =>
      fetchTable('education_levels');
  Future<List<LookupOption>> getOccupations() => fetchTable('occupations');
  Future<List<LookupOption>> getAnnualIncomes() => fetchTable('annual_incomes');
  Future<List<LookupOption>> getCastes() => fetchTable('castes');
  Future<List<LookupOption>> getReligions() => fetchTable('religions');
  Future<List<LookupOption>> getEducations() => fetchTable('education_levels');
  Future<List<LookupOption>> getProfessions() => fetchTable('occupations');
}
