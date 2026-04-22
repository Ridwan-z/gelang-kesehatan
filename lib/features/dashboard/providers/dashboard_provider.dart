// lib/features/dashboard/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────
class HeartRateData {
  final int bpm;
  final int spo2;
  final DateTime recordedAt;
  const HeartRateData({required this.bpm, required this.spo2, required this.recordedAt});

  factory HeartRateData.fromMap(Map<String, dynamic> m) => HeartRateData(
    bpm:        m['bpm'] as int,
    spo2:       m['spo2'] as int,
    recordedAt: DateTime.parse(m['recorded_at']),
  );
}

class DeviceStatus {
  final String id;
  final String name;
  final bool isOnline;
  final int batteryPct;
  final DateTime? lastSeenAt;
  const DeviceStatus({
    required this.id, required this.name,
    required this.isOnline, required this.batteryPct,
    this.lastSeenAt,
  });

  factory DeviceStatus.fromMap(Map<String, dynamic> m) => DeviceStatus(
    id:          m['id'],
    name:        m['name'] ?? 'Gelangku',
    isOnline:    m['is_online'] ?? false,
    batteryPct:  m['battery_pct'] ?? 0,
    lastSeenAt:  m['last_seen_at'] != null ? DateTime.parse(m['last_seen_at']) : null,
  );
}

// ── Device list provider ──────────────────────────────────────
final deviceListProvider = FutureProvider<List<DeviceStatus>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final res = await supabase
      .from('devices')
      .select()
      .eq('owner_id', user.id)
      .order('created_at');

  return (res as List).map((e) => DeviceStatus.fromMap(e)).toList();
});

// ── Selected device id ────────────────────────────────────────
class SelectedDeviceIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Auto-select device pertama
    final devices = ref.watch(deviceListProvider).asData?.value;
    if (devices != null && devices.isNotEmpty) return devices.first.id;
    return null;
  }

  void select(String? deviceId) => state = deviceId;
}

final selectedDeviceIdProvider = NotifierProvider<SelectedDeviceIdNotifier, String?>(
  SelectedDeviceIdNotifier.new,
);

// ── Latest heart rate (realtime) ──────────────────────────────
final latestHeartRateProvider = StreamProvider<HeartRateData?>((ref) {
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return Stream.value(null);

  final supabase = ref.watch(supabaseProvider);
  return supabase
      .from('heart_rate_logs')
      .stream(primaryKey: ['id'])
      .eq('device_id', deviceId)
      .order('recorded_at', ascending: false)
      .limit(1)
      .map((rows) => rows.isEmpty ? null : HeartRateData.fromMap(rows.first));
});

// ── Heart rate history (last 20 readings untuk mini chart) ────
final heartRateHistoryProvider = FutureProvider<List<HeartRateData>>((ref) async {
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return [];

  final supabase = ref.watch(supabaseProvider);
  final res = await supabase
      .from('heart_rate_logs')
      .select()
      .eq('device_id', deviceId)
      .order('recorded_at', ascending: false)
      .limit(20);

  return (res as List).map((e) => HeartRateData.fromMap(e)).toList().reversed.toList();
});

// ── Today's activity (latest steps) ──────────────────────────
final todayStepsProvider = StreamProvider<int>((ref) {
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return Stream.value(0);

  final supabase = ref.watch(supabaseProvider);
  final today = DateTime.now().toIso8601String().split('T')[0];

  return supabase
      .from('activity_logs')
      .stream(primaryKey: ['id'])
      .eq('device_id', deviceId)
      .order('recorded_at', ascending: false)
      .limit(1)
      .map((rows) => rows.isEmpty ? 0 : (rows.first['steps'] as int? ?? 0));
});

// ── Today's daily summary ─────────────────────────────────────
final todaySummaryProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return null;

  final supabase = ref.watch(supabaseProvider);
  final today = DateTime.now().toIso8601String().split('T')[0];

  final res = await supabase
      .from('daily_summaries')
      .select()
      .eq('device_id', deviceId)
      .eq('summary_date', today)
      .maybeSingle();

  return res;
});
