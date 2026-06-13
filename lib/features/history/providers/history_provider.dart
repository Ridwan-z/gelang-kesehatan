// lib/features/history/providers/history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ── Filter periode ────────────────────────────────────────────
enum HistoryPreset { week, month, threeMonths, sixMonths, year, custom }

class HistoryFilter {
  final HistoryPreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  const HistoryFilter({
    this.preset      = HistoryPreset.week,
    this.customStart,
    this.customEnd,
  });

  DateTime get startDate {
    if (preset == HistoryPreset.custom && customStart != null) {
      return DateTime(customStart!.year, customStart!.month, customStart!.day);
    }
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    switch (preset) {
      case HistoryPreset.week:        return today.subtract(const Duration(days: 6));
      case HistoryPreset.month:       return today.subtract(const Duration(days: 29));
      case HistoryPreset.threeMonths: return today.subtract(const Duration(days: 89));
      case HistoryPreset.sixMonths:   return today.subtract(const Duration(days: 179));
      case HistoryPreset.year:        return today.subtract(const Duration(days: 364));
      default:                        return today.subtract(const Duration(days: 6));
    }
  }

  DateTime get endDate {
    if (preset == HistoryPreset.custom && customEnd != null) {
      return DateTime(
          customEnd!.year, customEnd!.month, customEnd!.day, 23, 59, 59);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  int get totalDays => endDate.difference(startDate).inDays + 1;

  String get label {
    switch (preset) {
      case HistoryPreset.week:        return '7 Hari';
      case HistoryPreset.month:       return '30 Hari';
      case HistoryPreset.threeMonths: return '3 Bulan';
      case HistoryPreset.sixMonths:   return '6 Bulan';
      case HistoryPreset.year:        return '1 Tahun';
      case HistoryPreset.custom:
        if (customStart != null && customEnd != null) {
          return '${customStart!.day}/${customStart!.month}/${customStart!.year}'
              ' – '
              '${customEnd!.day}/${customEnd!.month}/${customEnd!.year}';
        }
        return 'Custom';
    }
  }
}

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  void setPreset(HistoryPreset p) => state = HistoryFilter(preset: p);

  void setCustomRange(DateTime start, DateTime end) => state = HistoryFilter(
        preset:      HistoryPreset.custom,
        customStart: start,
        customEnd:   end,
      );
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
        HistoryFilterNotifier.new);

// ── Model ─────────────────────────────────────────────────────
class DailySummaryData {
  final DateTime date;
  final int avgBpm;
  final int maxBpm;
  final int minBpm;
  final int avgSpo2;
  final int totalSteps;
  final int caloriesBurned;
  final int activeMinutes;

  const DailySummaryData({
    required this.date,
    required this.avgBpm,
    required this.maxBpm,
    required this.minBpm,
    required this.avgSpo2,
    required this.totalSteps,
    required this.caloriesBurned,
    required this.activeMinutes,
  });
}

// ── Provider: agregasi dari heart_rate_logs & activity_logs ───
// Karena daily_summaries belum terisi, kita agregasi langsung
// dari raw logs per hari dalam rentang filter
final dailySummariesProvider =
    FutureProvider<List<DailySummaryData>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final filter   = ref.watch(historyFilterProvider);
  final user     = supabase.auth.currentUser;
  if (user == null) return [];

  // Ambil device milik user
  final devRes = await supabase
      .from('devices')
      .select('id')
      .eq('owner_id', user.id)
      .limit(1);

  if ((devRes as List).isEmpty) return [];
  final deviceId = devRes.first['id'] as String;

  final startStr = filter.startDate.toIso8601String();
  final endStr   = filter.endDate.toIso8601String();

  // Query heart_rate_logs
  final hrRes = await supabase
      .from('heart_rate_logs')
      .select('bpm, spo2, recorded_at')
      .eq('device_id', deviceId)
      .gte('recorded_at', startStr)
      .lte('recorded_at', endStr)
      .order('recorded_at');

  // Query activity_logs
  final actRes = await supabase
      .from('activity_logs')
      .select('steps, calories_burned, active_minutes, recorded_at')
      .eq('device_id', deviceId)
      .gte('recorded_at', startStr)
      .lte('recorded_at', endStr)
      .order('recorded_at');

  // Agregasi per hari
  final Map<String, _DayAgg> aggMap = {};

  for (final row in (hrRes as List)) {
    final dt  = DateTime.parse(row['recorded_at']).toLocal();
    final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
    aggMap.putIfAbsent(key, () => _DayAgg(dt));
    aggMap[key]!.bpmList.add((row['bpm'] as num).toInt());
    aggMap[key]!.spo2List.add((row['spo2'] as num).toInt());
  }

  for (final row in (actRes as List)) {
    final dt  = DateTime.parse(row['recorded_at']).toLocal();
    final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
    aggMap.putIfAbsent(key, () => _DayAgg(dt));
    // Ambil nilai tertinggi steps & kalori hari itu (data terakhir)
    final steps = (row['steps'] as num?)?.toInt() ?? 0;
    final cal   = (row['calories_burned'] as num?)?.toInt() ?? 0;
    final act   = (row['active_minutes'] as num?)?.toInt() ?? 0;
    if (steps > (aggMap[key]!.maxSteps)) aggMap[key]!.maxSteps = steps;
    if (cal   > (aggMap[key]!.maxCal))   aggMap[key]!.maxCal   = cal;
    if (act   > (aggMap[key]!.maxAct))   aggMap[key]!.maxAct   = act;
  }

  // Konversi ke DailySummaryData
  final result = aggMap.entries.map((e) {
    final agg = e.value;
    final avgBpm  = agg.bpmList.isEmpty ? 0
        : agg.bpmList.reduce((a, b) => a + b) ~/ agg.bpmList.length;
    final maxBpm  = agg.bpmList.isEmpty ? 0
        : agg.bpmList.reduce((a, b) => a > b ? a : b);
    final minBpm  = agg.bpmList.isEmpty ? 0
        : agg.bpmList.reduce((a, b) => a < b ? a : b);
    final avgSpo2 = agg.spo2List.isEmpty ? 0
        : agg.spo2List.reduce((a, b) => a + b) ~/ agg.spo2List.length;

    return DailySummaryData(
      date:           agg.date,
      avgBpm:         avgBpm,
      maxBpm:         maxBpm,
      minBpm:         minBpm,
      avgSpo2:        avgSpo2,
      totalSteps:     agg.maxSteps,
      caloriesBurned: agg.maxCal,
      activeMinutes:  agg.maxAct,
    );
  }).toList();

  // Sort by date
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
});

// Helper agregasi per hari
class _DayAgg {
  final DateTime date;
  final List<int> bpmList  = [];
  final List<int> spo2List = [];
  int maxSteps = 0;
  int maxCal   = 0;
  int maxAct   = 0;

  _DayAgg(this.date);
}

