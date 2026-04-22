// // lib/features/dashboard/providers/dashboard_provider.dart
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// import '../../auth/providers/auth_provider.dart';

// // ── Models ────────────────────────────────────────────────────
// class HeartRateData {
//   final int bpm;
//   final int spo2;
//   final DateTime recordedAt;
//   const HeartRateData({required this.bpm, required this.spo2, required this.recordedAt});

//   factory HeartRateData.fromMap(Map<String, dynamic> m) => HeartRateData(
//     bpm:        m['bpm'] as int,
//     spo2:       m['spo2'] as int,
//     recordedAt: DateTime.parse(m['recorded_at']),
//   );
// }

// class DeviceStatus {
//   final String id;
//   final String name;
//   final bool isOnline;
//   final int batteryPct;
//   final DateTime? lastSeenAt;
//   const DeviceStatus({
//     required this.id, required this.name,
//     required this.isOnline, required this.batteryPct,
//     this.lastSeenAt,
//   });

//   factory DeviceStatus.fromMap(Map<String, dynamic> m) => DeviceStatus(
//     id:          m['id'],
//     name:        m['name'] ?? 'Gelangku',
//     isOnline:    m['is_online'] ?? false,
//     batteryPct:  m['battery_pct'] ?? 0,
//     lastSeenAt:  m['last_seen_at'] != null ? DateTime.parse(m['last_seen_at']) : null,
//   );
// }

// // ── Device list provider ──────────────────────────────────────
// final deviceListProvider = FutureProvider<List<DeviceStatus>>((ref) async {
//   final supabase = ref.watch(supabaseProvider);
//   final user = supabase.auth.currentUser;
//   if (user == null) return [];

//   final res = await supabase
//       .from('devices')
//       .select()
//       .eq('owner_id', user.id)
//       .order('created_at');

//   return (res as List).map((e) => DeviceStatus.fromMap(e)).toList();
// });

// // ── Selected device id ────────────────────────────────────────
// class SelectedDeviceIdNotifier extends Notifier<String?> {
//   @override
//   String? build() {
//     // Auto-select device pertama
//     final devices = ref.watch(deviceListProvider).asData?.value;
//     if (devices != null && devices.isNotEmpty) return devices.first.id;
//     return null;
//   }

//   void select(String? deviceId) => state = deviceId;
// }

// final selectedDeviceIdProvider = NotifierProvider<SelectedDeviceIdNotifier, String?>(
//   SelectedDeviceIdNotifier.new,
// );

// // ── Latest heart rate (realtime) ──────────────────────────────
// final latestHeartRateProvider = StreamProvider<HeartRateData?>((ref) {
//   final deviceId = ref.watch(selectedDeviceIdProvider);
//   if (deviceId == null) return Stream.value(null);

//   final supabase = ref.watch(supabaseProvider);
//   return supabase
//       .from('heart_rate_logs')
//       .stream(primaryKey: ['id'])
//       .eq('device_id', deviceId)
//       .order('recorded_at', ascending: false)
//       .limit(1)
//       .map((rows) => rows.isEmpty ? null : HeartRateData.fromMap(rows.first));
// });

// // ── Heart rate history (last 20 readings untuk mini chart) ────
// final heartRateHistoryProvider = FutureProvider<List<HeartRateData>>((ref) async {
//   final deviceId = ref.watch(selectedDeviceIdProvider);
//   if (deviceId == null) return [];

//   final supabase = ref.watch(supabaseProvider);
//   final res = await supabase
//       .from('heart_rate_logs')
//       .select()
//       .eq('device_id', deviceId)
//       .order('recorded_at', ascending: false)
//       .limit(20);

//   return (res as List).map((e) => HeartRateData.fromMap(e)).toList().reversed.toList();
// });

// // ── Today's activity (latest steps) ──────────────────────────
// final todayStepsProvider = StreamProvider<int>((ref) {
//   final deviceId = ref.watch(selectedDeviceIdProvider);
//   if (deviceId == null) return Stream.value(0);

//   final supabase = ref.watch(supabaseProvider);
//   final today = DateTime.now().toIso8601String().split('T')[0];

//   return supabase
//       .from('activity_logs')
//       .stream(primaryKey: ['id'])
//       .eq('device_id', deviceId)
//       .order('recorded_at', ascending: false)
//       .limit(1)
//       .map((rows) => rows.isEmpty ? 0 : (rows.first['steps'] as int? ?? 0));
// });

// // ── Today's daily summary ─────────────────────────────────────
// final todaySummaryProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
//   final deviceId = ref.watch(selectedDeviceIdProvider);
//   if (deviceId == null) return null;

//   final supabase = ref.watch(supabaseProvider);
//   final today = DateTime.now().toIso8601String().split('T')[0];

//   final res = await supabase
//       .from('daily_summaries')
//       .select()
//       .eq('device_id', deviceId)
//       .eq('summary_date', today)
//       .maybeSingle();

//   return res;
// });
// lib/features/dashboard/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

// ── DUMMY DATA ────────────────────────────────────────────────

// Device dummy
final deviceListProvider = FutureProvider<List<DeviceStatus>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500)); // simulasi loading
  return [
    DeviceStatus(
      id: 'dummy-device-1',
      name: 'Gelangku',
      isOnline: true,
      batteryPct: 78,
      lastSeenAt: DateTime.now(),
    ),
  ];
});

// Selected device
class SelectedDeviceIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final devices = ref.watch(deviceListProvider).asData?.value;
    if (devices != null && devices.isNotEmpty) return devices.first.id;
    return null;
  }

  void select(String? deviceId) => state = deviceId;
}

final selectedDeviceIdProvider = NotifierProvider<SelectedDeviceIdNotifier, String?>(
  SelectedDeviceIdNotifier.new,
);

// Latest heart rate dummy
final latestHeartRateProvider = StreamProvider<HeartRateData?>((ref) async* {
  // Simulasi data realtime — update tiap 3 detik
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    final bpm  = 60 + (DateTime.now().second % 40); // 60–99
    final spo2 = 95 + (DateTime.now().second % 5);  // 95–99
    yield HeartRateData(
      bpm: bpm,
      spo2: spo2,
      recordedAt: DateTime.now(),
    );
  }
});

// Heart rate history dummy (20 data)
final heartRateHistoryProvider = FutureProvider<List<HeartRateData>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 800));
  final now = DateTime.now();
  // Generate 20 titik data dengan variasi natural
  final List<int> bpmValues = [
    72, 75, 73, 78, 80, 76, 74, 79, 82, 80,
    77, 75, 73, 76, 78, 74, 72, 70, 73, 75,
  ];
  return List.generate(20, (i) => HeartRateData(
    bpm: bpmValues[i],
    spo2: 96 + (i % 3),
    recordedAt: now.subtract(Duration(minutes: (20 - i) * 5)),
  ));
});

// Steps dummy
final todayStepsProvider = StreamProvider<int>((ref) async* {
  int steps = 4250;
  while (true) {
    yield steps;
    await Future.delayed(const Duration(seconds: 5));
    steps += 10; // simulasi tambah langkah
  }
});

// Daily summary dummy
final todaySummaryProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  return {
    'calories_burned': 312,
    'active_minutes': 45,
    'distance_km': 3.2,
  };
});

// Tambah model SleepData
class SleepData {
  final DateTime sleepStart;
  final DateTime? sleepEnd;
  final int? durationMin;
  final int? qualityScore;
  final int? avgBpm;

  const SleepData({
    required this.sleepStart,
    this.sleepEnd,
    this.durationMin,
    this.qualityScore,
    this.avgBpm,
  });
}

// Tambah provider di bawah todaySummaryProvider
final lastSleepProvider = FutureProvider<SleepData?>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  // dummy data
  return SleepData(
    sleepStart: DateTime.now().subtract(const Duration(hours: 8)),
    sleepEnd: DateTime.now().subtract(const Duration(hours: 1)),
    durationMin: 420, // 7 jam
    qualityScore: 82,
    avgBpm: 62,
  );
});