// lib/features/dashboard/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Models ────────────────────────────────────────────────────
class HeartRateData {
  final int bpm;
  final int spo2;
  final DateTime recordedAt;
  const HeartRateData({
    required this.bpm,
    required this.spo2,
    required this.recordedAt,
  });

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
    required this.id,
    required this.name,
    required this.isOnline,
    required this.batteryPct,
    this.lastSeenAt,
  });
}

// ── DUMMY DATA ────────────────────────────────────────────────

// Device dummy
final deviceListProvider = FutureProvider<List<DeviceStatus>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    DeviceStatus(
      id:          'dummy-device-1',
      name:        'Gelangku',
      isOnline:    true,
      batteryPct:  78,
      lastSeenAt:  DateTime.now(),
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

final selectedDeviceIdProvider =
    NotifierProvider<SelectedDeviceIdNotifier, String?>(
        SelectedDeviceIdNotifier.new);

// Latest heart rate dummy
final latestHeartRateProvider = StreamProvider<HeartRateData?>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    final bpm  = 60 + (DateTime.now().second % 40);
    final spo2 = 95 + (DateTime.now().second % 5);
    yield HeartRateData(
      bpm:        bpm,
      spo2:       spo2,
      recordedAt: DateTime.now(),
    );
  }
});

// Heart rate history dummy (20 data)
final heartRateHistoryProvider =
    FutureProvider<List<HeartRateData>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 800));
  final now = DateTime.now();
  final List<int> bpmValues = [
    72, 75, 73, 78, 80, 76, 74, 79, 82, 80,
    77, 75, 73, 76, 78, 74, 72, 70, 73, 75,
  ];
  return List.generate(
    20,
    (i) => HeartRateData(
      bpm:        bpmValues[i],
      spo2:       96 + (i % 3),
      recordedAt: now.subtract(Duration(minutes: (20 - i) * 5)),
    ),
  );
});

// Steps dummy
final todayStepsProvider = StreamProvider<int>((ref) async* {
  int steps = 4250;
  while (true) {
    yield steps;
    await Future.delayed(const Duration(seconds: 5));
    steps += 10;
  }
});

// Daily summary dummy
final todaySummaryProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  return {
    'calories_burned': 312,
    'active_minutes':  45,
    'distance_km':     3.2,
  };
});