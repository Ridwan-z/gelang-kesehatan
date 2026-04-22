// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme     = Theme.of(context); // ← tambah ini
    final user      = ref.watch(currentUserProvider);
    final devices   = ref.watch(deviceListProvider);
    final latestHR  = ref.watch(latestHeartRateProvider);
    final steps     = ref.watch(todayStepsProvider);
    final hrHistory = ref.watch(heartRateHistoryProvider);
    final summary   = ref.watch(todaySummaryProvider);
    final firstName = user?.userMetadata?['full_name']?.toString().split(' ').first ?? 'Pengguna';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(deviceListProvider);
            ref.invalidate(heartRateHistoryProvider);
            ref.invalidate(todaySummaryProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, $firstName 👋',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id').format(DateTime.now()),
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      devices.when(
                        data: (devs) => devs.isEmpty
                            ? const SizedBox()
                            : _DeviceStatusBadge(device: devs.first),
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),

              if (devices.asData?.value.isEmpty == true)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.watch_off_outlined, size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('Belum ada gelang terpasang',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Pasangkan gelang di menu Profil',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                ),

              if (devices.asData?.value.isNotEmpty == true) ...[
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      latestHR.when(
                        data: (data) => Row(
                          children: [
                            Expanded(child: _MetricCard(
                              label: 'Detak Jantung',
                              value: data?.bpm.toString() ?? '--',
                              unit: 'BPM',
                              icon: Icons.favorite,
                              color: _bpmColor(data?.bpm),
                              isAlert: data != null && (data.bpm > 150 || data.bpm < 45),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _MetricCard(
                              label: 'Saturasi O₂',
                              value: data?.spo2.toString() ?? '--',
                              unit: '%',
                              icon: Icons.air,
                              color: _spo2Color(data?.spo2),
                              isAlert: data != null && data.spo2 < 95,
                            )),
                          ],
                        ),
                        loading: () => const _MetricCardsSkeleton(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(child: steps.when(
                            data: (s) => _MetricCard(
                              label: 'Langkah',
                              value: NumberFormat('#,###').format(s),
                              unit: 'steps',
                              icon: Icons.directions_walk,
                              color: const Color(0xFF0A84FF),
                            ),
                            loading: () => const _SmallCardSkeleton(),
                            error: (_, __) => const SizedBox(),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: summary.when(
                            data: (s) => _MetricCard(
                              label: 'Kalori',
                              value: s?['calories_burned']?.toString() ?? '--',
                              unit: 'kkal',
                              icon: Icons.local_fire_department,
                              color: const Color(0xFFFF9F0A),
                            ),
                            loading: () => const _SmallCardSkeleton(),
                            error: (_, __) => const SizedBox(),
                          )),
                        ],
                      ),
                      const SizedBox(height: 20),

                      hrHistory.when(
                        data: (history) => history.isEmpty
                            ? const SizedBox()
                            : _BpmChart(history: history),
                        loading: () => const _ChartSkeleton(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 20),

                      const _ActivityCard(),

                      // Tambah di bagian SliverChildListDelegate setelah _ActivityCard()
const SizedBox(height: 12),
ref.watch(lastSleepProvider).when(
  data: (sleep) => sleep == null
      ? const SizedBox()
      : _SleepCard(sleep: sleep),
  loading: () => const _ChartSkeleton(),
  error: (_, __) => const SizedBox(),
),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _bpmColor(int? bpm) {
    if (bpm == null) return Colors.grey;
    if (bpm > 150 || bpm < 45) return const Color(0xFFFF3B30);
    if (bpm > 120 || bpm < 55) return const Color(0xFFFF9F0A);
    return const Color(0xFF1DB954);
  }

  Color _spo2Color(int? spo2) {
    if (spo2 == null) return Colors.grey;
    if (spo2 < 90) return const Color(0xFFFF3B30);
    if (spo2 < 95) return const Color(0xFFFF9F0A);
    return const Color(0xFF1DB954);
  }
}

// ── Metric card ───────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final bool isAlert;

  const _MetricCard({
    required this.label, required this.value,
    required this.unit,  required this.icon,
    required this.color, this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // ← tambah ini
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isAlert ? Border.all(color: const Color(0xFFFF3B30), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('!',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: color)),
          Text(unit,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }
}

// ── BPM line chart ────────────────────────────────────────────
class _BpmChart extends StatelessWidget {
  final List<HeartRateData> history;
  const _BpmChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // ← tambah ini
    final spots = history.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), e.value.bpm.toDouble())).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Detak Jantung',
                style: TextStyle(fontWeight: FontWeight.w600)),
              Text('20 data terakhir',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.4))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: 40, maxY: 160,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) =>
                      LineTooltipItem('${s.y.toInt()} BPM',
                        const TextStyle(color: Colors.white, fontSize: 12))).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF1DB954),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1DB954).withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity card ─────────────────────────────────────────────
class _ActivityCard extends ConsumerWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme    = Theme.of(context); // ← tambah ini
    final deviceId = ref.watch(selectedDeviceIdProvider);
    if (deviceId == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.directions_walk,
              color: Color(0xFF0A84FF), size: 26),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aktivitas',
                style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Berjalan',
                style: TextStyle(color: Color(0xFF0A84FF), fontSize: 13)),
            ],
          ),
          const Spacer(),
          Text('Aktif',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }
}

// ── Device status badge ───────────────────────────────────────
class _DeviceStatusBadge extends StatelessWidget {
  final DeviceStatus device;
  const _DeviceStatusBadge({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // ← tambah ini
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.isOnline ? const Color(0xFF1DB954) : Colors.red,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            device.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: device.isOnline ? const Color(0xFF1DB954) : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.battery_std, size: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.5)),
          Text(
            '${device.batteryPct}%',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────
class _MetricCardsSkeleton extends StatelessWidget {
  const _MetricCardsSkeleton();
  @override
  Widget build(BuildContext context) => const Row(children: [
    Expanded(child: _SkeletonBox(height: 100)),
    SizedBox(width: 12),
    Expanded(child: _SkeletonBox(height: 100)),
  ]);
}

class _SmallCardSkeleton extends StatelessWidget {
  const _SmallCardSkeleton();
  @override
  Widget build(BuildContext context) => const _SkeletonBox(height: 90);
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();
  @override
  Widget build(BuildContext context) => const _SkeletonBox(height: 160);
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // ← tambah ini
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── Sleep card ────────────────────────────────────────────────
class _SleepCard extends StatelessWidget {
  final SleepData sleep;
  const _SleepCard({required this.sleep});

  String _formatDuration(int? minutes) {
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}j ${m}m';
  }

  Color _qualityColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 80) return const Color(0xFF1DB954);
    if (score >= 60) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF3B30);
  }

  String _qualityLabel(int? score) {
    if (score == null) return '--';
    if (score >= 80) return 'Baik';
    if (score >= 60) return 'Cukup';
    return 'Kurang';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qualColor = _qualityColor(sleep.qualityScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime, color: const Color(0xFF0A84FF), size: 18),
              const SizedBox(width: 6),
              Text('Tidur Terakhir',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: qualColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _qualityLabel(sleep.qualityScore),
                  style: TextStyle(
                    fontSize: 11,
                    color: qualColor,
                    fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Durasi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDuration(sleep.durationMin),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A84FF)),
                    ),
                    Text('Durasi',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
              // Quality score
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sleep.qualityScore ?? '--'}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: qualColor),
                    ),
                    Text('Skor Kualitas',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
              // Avg BPM saat tidur
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sleep.avgBpm ?? '--'}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface),
                    ),
                    Text('BPM rata-rata',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}