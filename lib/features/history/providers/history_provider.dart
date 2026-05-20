// lib/features/history/providers/history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      return DateTime(
          customStart!.year, customStart!.month, customStart!.day);
    }
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
          final s =
              '${customStart!.day}/${customStart!.month}/${customStart!.year}';
          final e =
              '${customEnd!.day}/${customEnd!.month}/${customEnd!.year}';
          return '$s – $e';
        }
        return 'Custom';
    }
  }

  HistoryFilter copyWith({
    HistoryPreset? preset,
    DateTime?      customStart,
    DateTime?      customEnd,
  }) =>
      HistoryFilter(
        preset:      preset      ?? this.preset,
        customStart: customStart ?? this.customStart,
        customEnd:   customEnd   ?? this.customEnd,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  void setPreset(HistoryPreset preset) =>
      state = HistoryFilter(preset: preset);

  void setCustomRange(DateTime start, DateTime end) =>
      state = HistoryFilter(
        preset:      HistoryPreset.custom,
        customStart: start,
        customEnd:   end,
      );
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
        HistoryFilterNotifier.new);

// ── Model daily summary ───────────────────────────────────────
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

// ── Dummy daily summaries ─────────────────────────────────────
final dailySummariesProvider =
    FutureProvider<List<DailySummaryData>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  await Future.delayed(const Duration(milliseconds: 400));

  final days  = filter.totalDays;
  final start = filter.startDate;

  final List<int> bpmBase = [
    72, 75, 70, 78, 74, 76, 73, 71, 77, 75,
    80, 74, 72, 76, 78, 73, 70, 75, 77, 74,
    72, 76, 78, 74, 73, 75, 71, 77, 74, 76,
  ];
  final List<int> stepsBase = [
    8200, 6500, 9100, 7800, 10200, 5400, 8900,
    7200, 9500, 6800, 8100, 7600, 9200, 8400,
    6100, 9800, 7300, 8700, 6900, 9100, 7500,
    8300, 6700, 9400, 7100, 8600, 9000, 7400,
    8800, 6300,
  ];

  return List.generate(days, (i) {
    final date = start.add(Duration(days: i));
    final idx  = i % bpmBase.length;
    final bpm  = bpmBase[idx];
    return DailySummaryData(
      date:           date,
      avgBpm:         bpm,
      maxBpm:         bpm + 20 + (i % 15),
      minBpm:         bpm - 10 - (i % 8),
      avgSpo2:        96 + (i % 3),
      totalSteps:     stepsBase[i % stepsBase.length],
      caloriesBurned: 250 + (stepsBase[i % stepsBase.length] ~/ 30),
      activeMinutes:  30 + (i % 40),
    );
  });
});