// lib/features/alerts/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────────
class AlertItem {
  final String id;
  final String alertType;
  final double value;
  final double threshold;
  final bool buzzerTriggered;
  final bool notifSent;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;

  const AlertItem({
    required this.id,
    required this.alertType,
    required this.value,
    required this.threshold,
    required this.buzzerTriggered,
    required this.notifSent,
    required this.triggeredAt,
    this.resolvedAt,
  });

  bool get isResolved => resolvedAt != null;

  factory AlertItem.fromMap(Map<String, dynamic> m) => AlertItem(
        id:             m['id'] as String,
        alertType:      m['alert_type'] as String,
        value:          (m['value'] as num?)?.toDouble() ?? 0,
        threshold:      (m['threshold'] as num?)?.toDouble() ?? 0,
        buzzerTriggered: m['buzzer_triggered'] as bool? ?? false,
        notifSent:      m['notif_sent'] as bool? ?? false,
        triggeredAt:    DateTime.parse(m['triggered_at']).toLocal(),
        resolvedAt:     m['resolved_at'] != null
            ? DateTime.parse(m['resolved_at']).toLocal()
            : null,
      );
}

// ── Filter ────────────────────────────────────────────────────
enum AlertFilter { all, unresolved, resolved }

class AlertFilterNotifier extends Notifier<AlertFilter> {
  @override
  AlertFilter build() => AlertFilter.all;
  void set(AlertFilter f) => state = f;
}

final alertFilterProvider =
    NotifierProvider<AlertFilterNotifier, AlertFilter>(
        AlertFilterNotifier.new);

// ── Provider — query dari Supabase ────────────────────────────
final alertsProvider = FutureProvider<List<AlertItem>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user     = supabase.auth.currentUser;
  if (user == null) return [];

  final devRes = await supabase
      .from('devices')
      .select('id')
      .eq('owner_id', user.id)
      .limit(1);

  print('User ID: ${user.id}');
  print('Devices result: $devRes');
  
  if ((devRes as List).isEmpty) {
    print('No devices found for user');
    return [];
  }
  
  final deviceId = devRes.first['id'] as String;
  print('Device ID used: $deviceId');
  
  final res = await supabase
      .from('alerts_log')
      .select('...')
      .eq('device_id', deviceId)
      .order('triggered_at', ascending: false)
      .limit(100);
      
  print('Alerts found: ${(res as List).length}');
  
  return (res as List).map((e) => AlertItem.fromMap(e)).toList();
});

// ── Screen ────────────────────────────────────────────────────
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme       = Theme.of(context);
    final filter      = ref.watch(alertFilterProvider);
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert'),
        actions: [
          // Tombol refresh
          IconButton(
            icon:    const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(alertsProvider),
          ),
          // Badge jumlah aktif
          alertsAsync.when(
            data: (alerts) {
              final count = alerts.where((a) => !a.isResolved).length;
              if (count == 0) return const SizedBox();
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count aktif',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   12,
                        fontWeight: FontWeight.w600)),
              );
            },
            loading: () => const SizedBox(),
            error:   (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: Column(children: [
        // ── Summary ───────────────────────────────────
        alertsAsync.when(
          data:    (a) => _SummaryRow(alerts: a),
          loading: () => const SizedBox(height: 90),
          error:   (_, __) => const SizedBox(),
        ),

        // ── Filter tabs ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color:        theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _FilterTab(
                label:    'Semua',
                selected: filter == AlertFilter.all,
                onTap: () => ref.read(alertFilterProvider.notifier)
                    .set(AlertFilter.all),
              ),
              _FilterTab(
                label:    'Aktif',
                selected: filter == AlertFilter.unresolved,
                onTap: () => ref.read(alertFilterProvider.notifier)
                    .set(AlertFilter.unresolved),
              ),
              _FilterTab(
                label:    'Selesai',
                selected: filter == AlertFilter.resolved,
                onTap: () => ref.read(alertFilterProvider.notifier)
                    .set(AlertFilter.resolved),
              ),
            ]),
          ),
        ),

        // ── List ──────────────────────────────────────
        Expanded(
          child: alertsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(message: e.toString()),
            data: (alerts) {
              final filtered = _applyFilter(alerts, filter);
              if (filtered.isEmpty) {
                return _EmptyState(filter: filter);
              }
              final grouped = _groupByDate(filtered);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(alertsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: grouped.length,
                  itemBuilder: (ctx, i) {
                    final entry = grouped[i];
                    if (entry is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(entry,
                            style: TextStyle(
                                fontSize:     12,
                                fontWeight:   FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.4),
                                letterSpacing: 0.5)),
                      );
                    }
                    return _AlertCard(alert: entry as AlertItem);
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  List<AlertItem> _applyFilter(
      List<AlertItem> alerts, AlertFilter filter) {
    switch (filter) {
      case AlertFilter.all:        return alerts;
      case AlertFilter.unresolved: return alerts.where((a) => !a.isResolved).toList();
      case AlertFilter.resolved:   return alerts.where((a) => a.isResolved).toList();
    }
  }

  List<dynamic> _groupByDate(List<AlertItem> alerts) {
    final result = <dynamic>[];
    String? lastDate;
    for (final alert in alerts) {
      final dateStr = _dateLabel(alert.triggeredAt);
      if (dateStr != lastDate) {
        result.add(dateStr);
        lastDate = dateStr;
      }
      result.add(alert);
    }
    return result;
  }

  String _dateLabel(DateTime dt) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date      = DateTime(dt.year, dt.month, dt.day);

    if (date == today)     return 'HARI INI';
    if (date == yesterday) return 'KEMARIN';
    return DateFormat('EEEE, d MMMM yyyy', 'id').format(dt).toUpperCase();
  }
}

// ── Summary row ───────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<AlertItem> alerts;
  const _SummaryRow({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final today      = DateTime.now();
    final todayCount = alerts.where((a) {
      final d = a.triggeredAt;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).length;

    final unresolved = alerts.where((a) => !a.isResolved).length;
    final highBpm    = alerts.where((a) => a.alertType == 'high_bpm').length;
    final lowSpo2    = alerts.where((a) => a.alertType == 'low_spo2').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        Expanded(child: _SummaryCard(
          label: 'Aktif',
          value: '$unresolved',
          color: unresolved > 0
              ? const Color(0xFFFF3B30)
              : const Color(0xFF1DB954),
          icon: Icons.warning_amber_rounded,
        )),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(
          label: 'Hari Ini',
          value: '$todayCount',
          color: const Color(0xFFFF9F0A),
          icon:  Icons.today,
        )),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(
          label: 'BPM Tinggi',
          value: '$highBpm',
          color: const Color(0xFFFF3B30),
          icon:  Icons.favorite,
        )),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(
          label: 'SpO2 Rendah',
          value: '$lowSpo2',
          color: const Color(0xFF0A84FF),
          icon:  Icons.air,
        )),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      color)),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.onSurface.withOpacity(0.5)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Alert card ────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final AlertItem alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info  = _alertInfo(alert.alertType, alert.value, alert.threshold);

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: alert.isResolved
            ? null
            : Border.all(
                color: info.color.withOpacity(0.4), width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        info.color.withOpacity(
                alert.isResolved ? 0.08 : 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(info.icon,
              color: alert.isResolved
                  ? info.color.withOpacity(0.5)
                  : info.color,
              size: 20),
        ),
        const SizedBox(width: 12),

        // Konten
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(children: [
              Expanded(
                child: Text(info.title,
                    style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color: alert.isResolved
                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                            : theme.colorScheme.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: alert.isResolved
                      ? const Color(0xFF1DB954).withOpacity(0.1)
                      : const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.isResolved ? 'Selesai' : 'Aktif',
                  style: TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.w600,
                      color: alert.isResolved
                          ? const Color(0xFF1DB954)
                          : const Color(0xFFFF3B30)),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(info.description,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 8),

            // Meta
            Row(children: [
              Icon(Icons.access_time,
                  size:  11,
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(width: 3),
              Text(_formatTime(alert.triggeredAt),
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4))),
              const Spacer(),
              if (alert.buzzerTriggered)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Buzzer aktif',
                    child: Icon(Icons.vibration,
                        size:  13,
                        color: info.color.withOpacity(0.7)),
                  ),
                ),
              if (alert.notifSent)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Notifikasi terkirim',
                    child: Icon(Icons.notifications_active,
                        size:  13,
                        color: info.color.withOpacity(0.7)),
                  ),
                ),
            ]),

            // Durasi jika selesai
            if (alert.isResolved && alert.resolvedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Durasi: ${_duration(alert.triggeredAt, alert.resolvedAt!)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF1DB954).withOpacity(0.8)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  _AlertInfo _alertInfo(String type, double value, double threshold) {
    switch (type) {
      case 'high_bpm':
        return _AlertInfo(
          title:       'Detak Jantung Terlalu Tinggi',
          description: '${value.toInt()} BPM (batas: ${threshold.toInt()} BPM)',
          icon:        Icons.favorite,
          color:       const Color(0xFFFF3B30),
        );
      case 'low_bpm':
        return _AlertInfo(
          title:       'Detak Jantung Terlalu Rendah',
          description: '${value.toInt()} BPM (batas: ${threshold.toInt()} BPM)',
          icon:        Icons.favorite_border,
          color:       const Color(0xFFFF9F0A),
        );
      case 'low_spo2':
        return _AlertInfo(
          title:       'Saturasi Oksigen Rendah',
          description: '${value.toInt()}% SpO2 (batas: ${threshold.toInt()}%)',
          icon:        Icons.air,
          color:       const Color(0xFF0A84FF),
        );
      case 'fall':
        return _AlertInfo(
          title:       'Terdeteksi Jatuh',
          description: 'Sensor mendeteksi benturan keras',
          icon:        Icons.personal_injury_outlined,
          color:       const Color(0xFFFF3B30),
        );
      default:
        return _AlertInfo(
          title:       type,
          description: 'Nilai: ${value.toInt()} | Batas: ${threshold.toInt()}',
          icon:        Icons.warning_amber,
          color:       const Color(0xFFFF9F0A),
        );
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24)   return '${diff.inHours} jam lalu';
    return DateFormat('HH:mm', 'id').format(dt);
  }

  String _duration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inMinutes < 1)  return '< 1 menit';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit';
    return '${diff.inHours}j ${diff.inMinutes % 60}m';
  }
}

class _AlertInfo {
  final String title, description;
  final IconData icon;
  final Color color;
  const _AlertInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ── Filter tab ────────────────────────────────────────────────
class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected
                      ? Colors.black
                      : theme.colorScheme.onSurface.withOpacity(0.5))),
        ),
      ),
    );
  }
}

// ── Empty & Error state ───────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final AlertFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg   = filter == AlertFilter.unresolved
        ? 'Tidak ada alert aktif\nSemua kondisi normal 👍'
        : filter == AlertFilter.resolved
            ? 'Belum ada alert yang selesai'
            : 'Belum ada alert sama sekali\nGelang belum mengirim data';

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline,
            size:  56,
            color: theme.colorScheme.onSurface.withOpacity(0.2)),
        const SizedBox(height: 16),
        Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(
                color:   theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 14)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Gagal memuat alert',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
        ]),
      ),
    );
  }
}