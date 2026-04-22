// lib/features/history/providers/history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/providers/dashboard_provider.dart';

// ── Filter periode ────────────────────────────────────────────
enum HistoryPeriod { week, month }

class HistoryPeriodNotifier extends Notifier<HistoryPeriod> {
  @override
  HistoryPeriod build() => HistoryPeriod.week;

  void set(HistoryPeriod period) => state = period;
}

final historyPeriodProvider = NotifierProvider<HistoryPeriodNotifier, HistoryPeriod>(
  HistoryPeriodNotifier.new,
);

// ── Model daily summary ───────────────────────────────────────
class DailySummaryData {
  final DateTime date;
  final int avgBpm;
  final int maxBpm;
  final int minBpm;
  final int avgSpo2;
  final int totalSteps;
  final int caloriesBurned;
  final double? sleepHours;
  final int activeMinutes;

  const DailySummaryData({
    required this.date,
    required this.avgBpm,
    required this.maxBpm,
    required this.minBpm,
    required this.avgSpo2,
    required this.totalSteps,
    required this.caloriesBurned,
    this.sleepHours,
    required this.activeMinutes,
  });
}

// ── Model sleep log ───────────────────────────────────────────
class SleepLogData {
  final DateTime sleepStart;
  final DateTime? sleepEnd;
  final int? durationMin;
  final int? qualityScore;
  final int? avgBpm;

  const SleepLogData({
    required this.sleepStart,
    this.sleepEnd,
    this.durationMin,
    this.qualityScore,
    this.avgBpm,
  });
}

// ── Dummy daily summaries (7 hari / 30 hari) ─────────────────
final dailySummariesProvider = FutureProvider<List<DailySummaryData>>((ref) async {
  final period = ref.watch(historyPeriodProvider);
  final days   = period == HistoryPeriod.week ? 7 : 30;
  await Future.delayed(const Duration(milliseconds: 600));

  final now = DateTime.now();
  final List<int> bpmBase   = [72, 75, 70, 78, 74, 76, 73, 71, 77, 75,
                                80, 74, 72, 76, 78, 73, 70, 75, 77, 74,
                                72, 76, 78, 74, 73, 75, 71, 77, 74, 76];
  final List<int> stepsBase = [8200, 6500, 9100, 7800, 10200, 5400, 8900,
                                7200, 9500, 6800, 8100, 7600, 9200, 8400,
                                6100, 9800, 7300, 8700, 6900, 9100, 7500,
                                8300, 6700, 9400, 7100, 8600, 9000, 7400,
                                8800, 6300];

  return List.generate(days, (i) {
    final date = now.subtract(Duration(days: days - 1 - i));
    final bpm  = bpmBase[i % bpmBase.length];
    return DailySummaryData(
      date:           date,
      avgBpm:         bpm,
      maxBpm:         bpm + 20 + (i % 15),
      minBpm:         bpm - 10 - (i % 8),
      avgSpo2:        96 + (i % 3),
      totalSteps:     stepsBase[i % stepsBase.length],
      caloriesBurned: 250 + (stepsBase[i % stepsBase.length] ~/ 30),
      sleepHours:     6.0 + (i % 4) * 0.5,
      activeMinutes:  30 + (i % 40),
    );
  });
});

// ── Dummy sleep logs ──────────────────────────────────────────
final sleepLogsProvider = FutureProvider<List<SleepLogData>>((ref) async {
  final period = ref.watch(historyPeriodProvider);
  final days   = period == HistoryPeriod.week ? 7 : 30;
  await Future.delayed(const Duration(milliseconds: 500));

  final now = DateTime.now();
  final List<int> durations = [420, 390, 450, 360, 480, 400, 430,
                                410, 370, 460, 440, 380, 420, 450,
                                390, 470, 400, 430, 360, 450, 410,
                                380, 440, 420, 390, 460, 400, 430,
                                370, 450];
  final List<int> scores    = [82, 75, 88, 65, 90, 72, 85,
                                78, 68, 86, 80, 70, 84, 88,
                                73, 91, 76, 83, 66, 87, 79,
                                71, 85, 82, 74, 89, 77, 84,
                                69, 88];

  return List.generate(days, (i) {
    final sleepStart = DateTime(
      now.year, now.month, now.day,
    ).subtract(Duration(days: days - 1 - i)).add(const Duration(hours: 22));
    return SleepLogData(
      sleepStart:   sleepStart,
      sleepEnd:     sleepStart.add(Duration(minutes: durations[i % durations.length])),
      durationMin:  durations[i % durations.length],
      qualityScore: scores[i % scores.length],
      avgBpm:       58 + (i % 10),
    );
  });
});