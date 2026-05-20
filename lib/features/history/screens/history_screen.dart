// lib/features/history/screens/history_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter    = ref.watch(historyFilterProvider);
    final summaries = ref.watch(dailySummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.date_range_outlined),
            tooltip: 'Pilih rentang tanggal',
            onPressed: () => _showDateRangePicker(context, ref, filter),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ────────────────────────────────
          _FilterBar(filter: filter),

          // ── Info rentang aktif ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size:  13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4)),
              const SizedBox(width: 6),
              Text(
                '${DateFormat('d MMM yyyy', 'id').format(filter.startDate)}'
                ' – '
                '${DateFormat('d MMM yyyy', 'id').format(filter.endDate)}'
                '  (${filter.totalDays} hari)',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45)),
              ),
            ]),
          ),

          // ── Konten ────────────────────────────────────
          Expanded(
            child: summaries.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Gagal memuat data')),
              data: (data) => _buildContent(context, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<DailySummaryData> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_outlined,
              size:  56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.2)),
          const SizedBox(height: 12),
          Text('Tidak ada data untuk rentang ini',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4))),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // BPM
        _SectionTitle(title: 'Detak Jantung', icon: Icons.favorite),
        const SizedBox(height: 8),
        _BpmHistoryChart(summaries: data),
        const SizedBox(height: 8),
        _BpmStatsRow(summaries: data),
        const SizedBox(height: 20),

        // SpO2
        _SectionTitle(title: 'Saturasi O₂', icon: Icons.air),
        const SizedBox(height: 8),
        _Spo2Chart(summaries: data),
        const SizedBox(height: 20),

        // Langkah
        _SectionTitle(
            title: 'Langkah Kaki', icon: Icons.directions_walk),
        const SizedBox(height: 8),
        _StepsChart(summaries: data),
        const SizedBox(height: 8),
        _StepsStatsRow(summaries: data),
        const SizedBox(height: 20),

        // Kalori
        _SectionTitle(
            title: 'Kalori & Aktivitas',
            icon: Icons.local_fire_department),
        const SizedBox(height: 8),
        _CaloriesChart(summaries: data),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _showDateRangePicker(
      BuildContext context, WidgetRef ref, HistoryFilter filter) async {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context:   context,
      firstDate: today.subtract(const Duration(days: 365 * 2)),
      lastDate:  today,
      initialDateRange: filter.preset == HistoryPreset.custom &&
              filter.customStart != null &&
              filter.customEnd != null
          ? DateTimeRange(
              start: filter.customStart!, end: filter.customEnd!)
          : DateTimeRange(
              start: filter.startDate, end: filter.endDate),
      locale:      const Locale('id', 'ID'),
      helpText:    'Pilih Rentang Tanggal',
      cancelText:  'Batal',
      confirmText: 'Terapkan',
      saveText:    'Terapkan',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary:   const Color(0xFF1DB954),
                onPrimary: Colors.black,
              ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      ref
          .read(historyFilterProvider.notifier)
          .setCustomRange(picked.start, picked.end);
    }
  }
}

// ── Filter bar ────────────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  final HistoryFilter filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final presets = [
      (HistoryPreset.week,        '7H'),
      (HistoryPreset.month,       '30H'),
      (HistoryPreset.threeMonths, '3B'),
      (HistoryPreset.sixMonths,   '6B'),
      (HistoryPreset.year,        '1T'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                final isSelected = filter.preset == p.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => ref
                        .read(historyFilterProvider.notifier)
                        .setPreset(p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.12)),
                      ),
                      child: Text(
                        p.$2,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.black
                              : theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Custom chip
        if (filter.preset == HistoryPreset.custom) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color:        theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.date_range, size: 13, color: Colors.black),
              const SizedBox(width: 4),
              Text(filter.label,
                  style: const TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      Colors.black)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── BPM chart ─────────────────────────────────────────────────
class _BpmHistoryChart extends StatelessWidget {
  final List<DailySummaryData> summaries;
  const _BpmHistoryChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final display  = summaries.length > 60
        ? summaries.sublist(summaries.length - 60)
        : summaries;
    final interval = display.length <= 7
        ? 1.0
        : display.length <= 30
            ? 5.0
            : display.length <= 90
                ? 15.0
                : 30.0;

    final spots    = display.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgBpm.toDouble()))
        .toList();
    final maxSpots = display.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.maxBpm.toDouble()))
        .toList();
    final minSpots = display.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.minBpm.toDouble()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          _LegendDot(color: const Color(0xFF1DB954), label: 'Rata-rata'),
          const SizedBox(width: 12),
          _LegendDot(color: const Color(0xFFFF3B30), label: 'Maks'),
          const SizedBox(width: 12),
          _LegendDot(color: const Color(0xFF0A84FF), label: 'Min'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color:       theme.colorScheme.onSurface.withOpacity(0.08),
                  strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles:   true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4))),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles:   true,
                  reservedSize: 24,
                  interval:     interval,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= display.length)
                      return const SizedBox();
                    return Text(
                      DateFormat('d/M').format(display[i].date),
                      style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4)),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots:    spots,
                isCurved: true,
                color:    const Color(0xFF1DB954),
                barWidth: 2.5,
                dotData:  FlDotData(show: false),
                belowBarData: BarAreaData(
                    show:  true,
                    color: const Color(0xFF1DB954).withOpacity(0.06)),
              ),
              LineChartBarData(
                spots:      maxSpots,
                isCurved:   true,
                color:      const Color(0xFFFF3B30).withOpacity(0.6),
                barWidth:   1.5,
                dotData:    FlDotData(show: false),
                dashArray:  [4, 4],
              ),
              LineChartBarData(
                spots:      minSpots,
                isCurved:   true,
                color:      const Color(0xFF0A84FF).withOpacity(0.6),
                barWidth:   1.5,
                dotData:    FlDotData(show: false),
                dashArray:  [4, 4],
              ),
            ],
          )),
        ),
      ]),
    );
  }
}

// ── BPM stats ─────────────────────────────────────────────────
class _BpmStatsRow extends StatelessWidget {
  final List<DailySummaryData> summaries;
  const _BpmStatsRow({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final avg = summaries.isEmpty
        ? 0
        : summaries.map((e) => e.avgBpm).reduce((a, b) => a + b) ~/
            summaries.length;
    final max = summaries.isEmpty
        ? 0
        : summaries.map((e) => e.maxBpm).reduce((a, b) => a > b ? a : b);
    final min = summaries.isEmpty
        ? 0
        : summaries.map((e) => e.minBpm).reduce((a, b) => a < b ? a : b);

    return Row(children: [
      Expanded(child: _StatChip(
          label: 'Rata-rata', value: '$avg', unit: 'bpm',
          color: const Color(0xFF1DB954))),
      const SizedBox(width: 8),
      Expanded(child: _StatChip(
          label: 'Tertinggi', value: '$max', unit: 'bpm',
          color: const Color(0xFFFF3B30))),
      const SizedBox(width: 8),
      Expanded(child: _StatChip(
          label: 'Terendah', value: '$min', unit: 'bpm',
          color: const Color(0xFF0A84FF))),
    ]);
  }
}

// ── SpO2 chart ────────────────────────────────────────────────
class _Spo2Chart extends StatelessWidget {
  final List<DailySummaryData> summaries;
  const _Spo2Chart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final display  = summaries.length > 60
        ? summaries.sublist(summaries.length - 60)
        : summaries;
    final interval = display.length <= 7 ? 1.0
        : display.length <= 30 ? 5.0
        : display.length <= 90 ? 15.0 : 30.0;
    final spots    = display.asMap().entries
        .map((e) =>
            FlSpot(e.key.toDouble(), e.value.avgSpo2.toDouble()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 120,
        child: LineChart(LineChartData(
          minY: 90, maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color:       theme.colorScheme.onSurface.withOpacity(0.08),
                strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.4))),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 24,
                interval:     interval,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= display.length)
                    return const SizedBox();
                  return Text(
                      DateFormat('d/M').format(display[i].date),
                      style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4)));
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots:    spots,
              isCurved: true,
              color:    const Color(0xFF0A84FF),
              barWidth: 2.5,
              dotData:  FlDotData(show: false),
              belowBarData: BarAreaData(
                  show:  true,
                  color: const Color(0xFF0A84FF).withOpacity(0.08)),
            ),
          ],
        )),
      ),
    );
  }
}

// ── Steps chart ───────────────────────────────────────────────
class _StepsChart extends StatelessWidget {
  final List<DailySummaryData> summaries;
  const _StepsChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final display = summaries.length > 30
        ? summaries.sublist(summaries.length - 30)
        : summaries;
    final barW    = display.length <= 7
        ? 18.0
        : display.length <= 14
            ? 12.0
            : 8.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 140,
        child: BarChart(BarChartData(
          maxY: 12000,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color:       theme.colorScheme.onSurface.withOpacity(0.08),
                strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                    v >= 1000
                        ? '${(v / 1000).toStringAsFixed(0)}k'
                        : '${v.toInt()}',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.4))),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= display.length)
                    return const SizedBox();
                  return Text(
                      DateFormat('d/M').format(display[i].date),
                      style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4)));
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: display.asMap().entries
              .map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.totalSteps.toDouble(),
                        color: e.value.totalSteps >= 10000
                            ? const Color(0xFF1DB954)
                            : const Color(0xFF0A84FF),
                        width:        barW,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ))
              .toList(),
        )),
      ),
    );
  }
}

// ── Steps stats ───────────────────────────────────────────────
class _StepsStatsRow extends StatelessWidget {
  final List<DailySummaryData> summaries;
  const _StepsStatsRow({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final total = summaries.isEmpty
        ? 0
        : summaries.map((e) => e.totalSteps).reduce((a, b) => a + b);
    final avg  = summaries.isEmpty ? 0 : total ~/ summaries.length;
    final best = summaries.isEmpty
        ? 0
        : summaries
            .map((e) => e.totalSteps)
            .reduce((a, b) => a > b ? a : b);
    final fmt  = NumberFormat('#,###');

    return Row(children: [
      Expanded(child: _StatChip(
          label: 'Total', value: fmt.format(total), unit: 'langkah',
          color: const Color(0xFF0A84FF))),
      const SizedBox(width: 8),
      Expanded(child: _StatChip(
          label: 'Rata-rata', value: fmt.format(avg), unit: '/hari',
          color: const Color(0xFF1DB954))),
      const SizedBox(width: 8),
      Expanded(child: _StatChip(
          label: 'Terbaik', value: fmt.format(best), unit: 'langkah',
          color: const Color(0xFFFF9F0A))),
    ]);
  }
}

// ── Calories chart ────────────────────────────────────────────
class _CaloriesChart extends StatelessWidget {
  final List<DailySummaryData> summaries;
  const _CaloriesChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final display = summaries.length > 30
        ? summaries.sublist(summaries.length - 30)
        : summaries;
    final barW    = display.length <= 7
        ? 18.0
        : display.length <= 14
            ? 12.0
            : 8.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 140,
        child: BarChart(BarChartData(
          maxY: 600,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color:       theme.colorScheme.onSurface.withOpacity(0.08),
                strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.4))),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= display.length)
                    return const SizedBox();
                  return Text(
                      DateFormat('d/M').format(display[i].date),
                      style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4)));
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: display.asMap().entries
              .map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY:          e.value.caloriesBurned.toDouble(),
                        color:        const Color(0xFFFF9F0A),
                        width:        barW,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ))
              .toList(),
        )),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 16, color: theme.colorScheme.primary),
      const SizedBox(width: 6),
      Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Helper widgets ────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.5))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      color)),
        Text(unit,
            style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width:  8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6))),
    ]);
  }
}