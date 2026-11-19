import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utils/helpers/helper_function.dart';

class WaterRepository extends GetxController {
  static WaterRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  String get _uid => _supabase.auth.currentUser!.id;

  /// -- Logs of one day, newest first
  Future<List<Map<String, dynamic>>> fetchLogs(DateTime date) async {
    return _supabase
        .from('water_logs')
        .select('id, amount_ml, logged_at')
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .eq('log_date', XHelperFunctions.toDbDate(date))
        .order('logged_at', ascending: false);
  }

  /// -- Total ml per day between two days (inclusive). Key = yyyy-MM-dd
  Future<Map<String, int>> fetchDailyTotals(DateTime from, DateTime to) async {
    final rows = await _supabase
        .from('water_logs')
        .select('log_date, amount_ml')
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .gte('log_date', XHelperFunctions.toDbDate(from))
        .lte('log_date', XHelperFunctions.toDbDate(to));
    final totals = <String, int>{};
    for (final row in rows) {
      final day = row['log_date'] as String;
      totals[day] = (totals[day] ?? 0) + (row['amount_ml'] as num).toInt();
    }
    return totals;
  }

  Future<void> addLog(DateTime date, int amountMl) async {
    await _supabase.from('water_logs').insert({
      'owner_id': _uid,
      'log_date': XHelperFunctions.toDbDate(date),
      'amount_ml': amountMl,
    });
  }

  Future<void> deleteLog(String id) async {
    await _supabase.from('water_logs').delete().eq('id', id);
  }
}
