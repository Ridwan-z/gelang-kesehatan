// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/dashboard_provider.dart';
import '../../../core/services/mqtt_service.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final user       = ref.watch(currentUserProvider);
    final devices    = ref.watch(deviceListProvider);
    final latestHR   = ref.watch(latestHeartRateProvider);
    final latestAct  = ref.watch(latestActivityProvider);
    final devStatus  = ref.watch(deviceStatusStreamProvider);
    final hrHistory  = ref.watch(heartRateHistoryProvider);
    final todaySteps = ref.watch(todayStepsProvider);
    final todayCal   = ref.watch(todayCaloriesProvider);

    final firstName = user?.userMetadata?['full_name']
            ?.toString().split(' ').first ??
        'Pengguna';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(deviceListProvider);
            ref.invalidate(heartRateHistoryProvider);
            ref.invalidate(todayStepsProvider);
            ref.invalidate(todayCaloriesProvider);
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, $firstName 👋',
                              style: const TextStyle(
                                  fontSize:   22,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'id')
                                .format(DateTime.now()),
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                    // devices.when(
                    //   data: (devs) => devs.isEmpty
                    //       ? const SizedBox()
                    //       : _DeviceBadge(
                    //           device:     devs.first,
                    //           mqttStatus: devStatus.asData?.value,
                    //         ),
                    //   loading: () => const SizedBox(),
                    //   error:   (_, __) => const SizedBox(),
                    // ),
                  ]),
                ),
              ),

              // ── Empty state ──────────────────────────────
              if (devices.asData?.value.isEmpty == true)
                SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.watch_off_outlined,
                          size:  64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('Belum ada gelang terpasang',
                          style: TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Pasangkan gelang di menu Profil',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5))),
                    ]),
                  ),
                ),

              // ── Content ──────────────────────────────────
              if (devices.asData?.value.isNotEmpty == true ||
                  devices.isLoading)
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── BPM & SpO2 ────────────────────────
                      // MQTT realtime → fallback data terakhir Supabase
                      latestHR.when(
                        data: (data) => Row(children: [
                          Expanded(child: _MetricCard(
                            label:    'Detak Jantung',
                            value:    data != null ? '${data.bpm}' : '--',
                            unit:     'BPM',
                            icon:     Icons.favorite,
                            color:    _bpmColor(data?.bpm),
                            isAlert:  data != null &&
                                (data.bpm > 150 || data.bpm < 45),
                            isStale:  data != null && _isStale(data.recordedAt),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _MetricCard(
                            label:    'Saturasi O₂',
                            value:    data != null ? '${data.spo2}' : '--',
                            unit:     '%',
                            icon:     Icons.air,
                            color:    _spo2Color(data?.spo2),
                            isAlert:  data != null && data.spo2 < 95,
                            isStale:  data != null && _isStale(data.recordedAt),
                          )),
                        ]),
                        loading: () => const _MetricCardsSkeleton(),
                        error:   (_, __) => Row(children: [
                          Expanded(child: _MetricCard(
                              label: 'Detak Jantung', value: '--',
                              unit: 'BPM', icon: Icons.favorite,
                              color: Colors.grey)),
                          const SizedBox(width: 12),
                          Expanded(child: _MetricCard(
                              label: 'Saturasi O₂', value: '--',
                              unit: '%', icon: Icons.air,
                              color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(height: 12),

                      // ── Langkah & Kalori HARI INI ──────────
                      // MQTT stream → update realtime
                      // Supabase query → nilai awal & saat refresh
                      Row(children: [
                        Expanded(child: _DailyMetricCard(
                          label:         'Langkah',
                          unit:          'steps',
                          icon:          Icons.directions_walk,
                          color:         const Color(0xFF0A84FF),
                          mqttAsync:     latestAct,
                          supabaseAsync: todaySteps,
                          mqttValue:     (a) => a.steps,
                          supabaseValue: (v) => v,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _DailyMetricCard(
                          label:         'Kalori',
                          unit:          'kkal',
                          icon:          Icons.local_fire_department,
                          color:         const Color(0xFFFF9F0A),
                          mqttAsync:     latestAct,
                          supabaseAsync: todayCal,
                          mqttValue:     (a) => a.caloriesBurned,
                          supabaseValue: (v) => v,
                        )),
                      ]),
                      const SizedBox(height: 20),

                      // ── BPM Chart — 20 data terakhir ──────
                      hrHistory.when(
                        data: (history) => history.isEmpty
                            ? _InfoCard(
                                icon:    Icons.show_chart,
                                message: 'Belum ada data grafik BPM')
                            : _BpmChart(history: history),
                        loading: () => const _ChartSkeleton(),
                        error:   (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 20),

                      // ── MQTT connection status ─────────────
                      _MqttStatusBar(),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Data dianggap stale jika lebih dari 10 menit yang lalu
  bool _isStale(DateTime recordedAt) =>
      DateTime.now().difference(recordedAt).inMinutes > 10;

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

// ── Device badge ──────────────────────────────────────────────
class _DeviceBadge extends StatelessWidget {
  final DeviceInfo device;
  final DeviceStatusData? mqttStatus;
  const _DeviceBadge({required this.device, this.mqttStatus});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final isOnline = mqttStatus?.isOnline  ?? device.isOnline;
    final battPct  = mqttStatus?.batteryPct ?? device.batteryPct;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? const Color(0xFF1DB954) : Colors.red,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: TextStyle(
              fontSize:   12,
              color:      isOnline
                  ? const Color(0xFF1DB954) : Colors.red,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Icon(Icons.battery_std,
            size:  14,
            color: theme.colorScheme.onSurface.withOpacity(0.5)),
        Text('$battPct%',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5))),
      ]),
    );
  }
}

// ── Metric card biasa (BPM, SpO2) ────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final bool isAlert;
  final bool isStale; // data lama > 10 menit

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.isAlert = false,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isAlert
            ? Border.all(color: const Color(0xFFFF3B30), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                overflow: TextOverflow.ellipsis),
          ),
          if (isAlert)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('!',
                  style: TextStyle(
                      color:      Color(0xFFFF3B30),
                      fontSize:   11,
                      fontWeight: FontWeight.w700)),
            ),
          // Indicator data lama
          if (isStale && !isAlert)
            Tooltip(
              message: 'Data terakhir (gelang tidak aktif)',
              child: Icon(Icons.history,
                  size:  13,
                  color: theme.colorScheme.onSurface.withOpacity(0.3)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize:   28,
                fontWeight: FontWeight.w700,
                color: isStale ? color.withOpacity(0.5) : color)),
        Text(unit,
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
      ]),
    );
  }
}

// ── Daily metric card (Langkah & Kalori) ─────────────────────
// Prioritas: MQTT stream → Supabase today query → 0
class _DailyMetricCard extends StatelessWidget {
  final String label, unit;
  final IconData icon;
  final Color color;
  final AsyncValue<ActivityData?> mqttAsync;
  final AsyncValue<int> supabaseAsync;
  final int Function(ActivityData) mqttValue;
  final int Function(int) supabaseValue;

  const _DailyMetricCard({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.mqttAsync,
    required this.supabaseAsync,
    required this.mqttValue,
    required this.supabaseValue,
  });

  @override
  Widget build(BuildContext context) {
    // Ambil nilai dari MQTT jika ada
    final mqttData = mqttAsync.asData?.value;
    if (mqttData != null) {
      return _MetricCard(
        label: label,
        value: NumberFormat('#,###').format(mqttValue(mqttData)),
        unit:  unit,
        icon:  icon,
        color: color,
      );
    }

    // Fallback ke Supabase query
    return supabaseAsync.when(
      loading: () => const _SmallCardSkeleton(),
      error:   (_, __) => _MetricCard(
        label: label, value: '0', unit: unit, icon: icon, color: color),
      data: (v) => _MetricCard(
        label: label,
        value: NumberFormat('#,###').format(supabaseValue(v)),
        unit:  unit,
        icon:  icon,
        color: color,
      ),
    );
  }
}

// ── BPM Chart ─────────────────────────────────────────────────
class _BpmChart extends StatelessWidget {
  final List<HeartRateData> history;
  const _BpmChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.bpm.toDouble()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Detak Jantung',
              style: TextStyle(fontWeight: FontWeight.w600)),
          Text('${history.length} data terakhir',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.4))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: LineChart(LineChartData(
            gridData:   FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minY: 40, maxY: 160,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) =>
                    LineTooltipItem('${s.y.toInt()} BPM',
                        const TextStyle(
                            color: Colors.white, fontSize: 12))).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots:    spots,
                isCurved: true,
                color:    const Color(0xFF1DB954),
                barWidth: 2,
                dotData:  FlDotData(show: false),
                belowBarData: BarAreaData(
                    show:  true,
                    color: const Color(0xFF1DB954).withOpacity(0.08)),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}

// ── MQTT status bar ───────────────────────────────────────────
class _MqttStatusBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme     = Theme.of(context);
    final mqtt      = ref.watch(mqttServiceProvider);
    final connected = mqtt.isConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        theme.colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected
                ? const Color(0xFF1DB954)
                : const Color(0xFFFF9F0A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            connected
                ? 'MQTT terhubung — menunggu data gelang'
                : 'MQTT menghubungkan...',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.45)),
          ),
        ),
        if (!connected)
          GestureDetector(
            onTap: () => ref.read(mqttServiceProvider).connect(),
            child: Text('Hubungkan',
                style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      theme.colorScheme.primary)),
          ),
      ]),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _InfoCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height:  72,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon,
            size:  18,
            color: theme.colorScheme.onSurface.withOpacity(0.3)),
        const SizedBox(width: 12),
        Text(message,
            style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
      ]),
    );
  }
}

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
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
            color:        Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16)));
}