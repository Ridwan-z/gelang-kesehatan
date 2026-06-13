// lib/features/dashboard/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/mqtt_service.dart';
import '../../auth/providers/auth_provider.dart';

export '../../../core/services/mqtt_service.dart'
    show HeartRateData, ActivityData, DeviceStatusData;

// ── Device info ───────────────────────────────────────────────
class DeviceInfo {
  final String id;
  final String name;
  final bool isOnline;
  final int batteryPct;
  final DateTime? lastSeenAt;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.isOnline,
    required this.batteryPct,
    this.lastSeenAt,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> m) => DeviceInfo(
        id:         m['id'] as String,
        name:       m['name'] as String? ?? 'Gelangku',
        isOnline:   m['is_online'] as bool? ?? false,
        batteryPct: (m['battery_pct'] as num?)?.toInt() ?? 0,
        lastSeenAt: m['last_seen_at'] != null
            ? DateTime.parse(m['last_seen_at'])
            : null,
      );
}

// ── Device list ───────────────────────────────────────────────
final deviceListProvider = FutureProvider<List<DeviceInfo>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user     = supabase.auth.currentUser;
  if (user == null) return [];

  final res = await supabase
      .from('devices')
      .select('id, name, is_online, battery_pct, last_seen_at')
      .eq('owner_id', user.id)
      .order('created_at');

  return (res as List).map((e) => DeviceInfo.fromMap(e)).toList();
});

// ── Selected device ───────────────────────────────────────────
class SelectedDeviceIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final devices = ref.watch(deviceListProvider).asData?.value;
    if (devices != null && devices.isNotEmpty) return devices.first.id;
    return null;
  }

  void select(String? id) => state = id;
}

final selectedDeviceIdProvider =
    NotifierProvider<SelectedDeviceIdNotifier, String?>(
        SelectedDeviceIdNotifier.new);

// ── Latest HR — MQTT realtime, fallback data terakhir Supabase ─
final latestHeartRateProvider = StreamProvider<HeartRateData?>((ref) async* {
  final mqtt     = ref.watch(mqttServiceProvider);
  final supabase = ref.watch(supabaseProvider);
  final deviceId = ref.watch(selectedDeviceIdProvider);

  // Ambil data terakhir dari Supabase dulu sebagai initial value
  if (deviceId != null) {
    try {
      final res = await supabase
          .from('heart_rate_logs')
          .select('bpm, spo2, recorded_at')
          .eq('device_id', deviceId)
          .order('recorded_at', ascending: false)
          .limit(1);

      if ((res as List).isNotEmpty) {
        yield HeartRateData.fromJson(res.first);
      }
    } catch (e) {
      print('[Dashboard] fallback heartrate error: $e');
    }
  }

  // Lanjut listen MQTT stream
  await for (final data in mqtt.heartRateStream) {
    yield data;
  }
});

// ── Latest activity — MQTT realtime, fallback data terakhir ───
final latestActivityProvider = StreamProvider<ActivityData?>((ref) async* {
  final mqtt     = ref.watch(mqttServiceProvider);
  final supabase = ref.watch(supabaseProvider);
  final deviceId = ref.watch(selectedDeviceIdProvider);

  // Ambil data activity terakhir hari ini dari Supabase sebagai initial
  if (deviceId != null) {
    try {
      final now      = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final res = await supabase
          .from('activity_logs')
          .select('steps, calories_burned, active_minutes, distance_km, activity_type, recorded_at')
          .eq('device_id', deviceId)
          .gte('recorded_at', '${todayStr}T00:00:00Z')
          .order('recorded_at', ascending: false)
          .limit(1);

      if ((res as List).isNotEmpty) {
        yield ActivityData.fromJson(res.first);
      }
    } catch (e) {
      print('[Dashboard] fallback activity error: $e');
    }
  }

  // Lanjut listen MQTT stream
  await for (final data in mqtt.activityStream) {
    yield data;
  }
});

// ── Device status — MQTT stream ───────────────────────────────
final deviceStatusStreamProvider = StreamProvider<DeviceStatusData?>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  return mqtt.deviceStatusStream;
});

// ── HR history — 20 data terakhir dari Supabase ───────────────
final heartRateHistoryProvider =
    FutureProvider<List<HeartRateData>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return [];

  final res = await supabase
      .from('heart_rate_logs')
      .select('bpm, spo2, recorded_at')
      .eq('device_id', deviceId)
      .order('recorded_at', ascending: false)
      .limit(20);

  return (res as List)
      .map((e) => HeartRateData.fromJson(e))
      .toList()
      .reversed
      .toList();
});

// ── Steps HARI INI — dijumlah dari semua activity_logs hari ini
// Ambil nilai steps tertinggi hari ini (karena Arduino kirim
// steps kumulatif, bukan delta)
final todayStepsProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return 0;

  final now      = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final res = await supabase
      .from('activity_logs')
      .select('steps')
      .eq('device_id', deviceId)
      .gte('recorded_at', '${todayStr}T00:00:00Z')
      .lte('recorded_at', '${todayStr}T23:59:59Z')
      .order('recorded_at', ascending: false)
      .limit(1); // ambil yang terbaru = nilai kumulatif tertinggi

  if ((res as List).isEmpty) return 0;
  return (res.first['steps'] as num?)?.toInt() ?? 0;
});

// ── Kalori HARI INI — sama, ambil nilai terbaru (kumulatif) ───
final todayCaloriesProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return 0;

  final now      = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final res = await supabase
      .from('activity_logs')
      .select('calories_burned')
      .eq('device_id', deviceId)
      .gte('recorded_at', '${todayStr}T00:00:00Z')
      .lte('recorded_at', '${todayStr}T23:59:59Z')
      .order('recorded_at', ascending: false)
      .limit(1); // ambil yang terbaru = nilai kumulatif tertinggi

  if ((res as List).isEmpty) return 0;
  return (res.first['calories_burned'] as num?)?.toInt() ?? 0;
});