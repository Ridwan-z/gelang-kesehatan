// lib/core/services/mqtt_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _broker    = '0725e73107aa44e99a6212a36486dc23.s1.eu.hivemq.cloud';
const _port      = 8883;
const _user      = 'gelang';
const _pass      = 'Gelang123';
const _deviceUid = 'gelang_user_01';

// ── Models ────────────────────────────────────────────────────
class HeartRateData {
  final int bpm;
  final int spo2;
  final DateTime recordedAt;
  const HeartRateData({required this.bpm, required this.spo2, required this.recordedAt});
  factory HeartRateData.fromJson(Map<String, dynamic> j) => HeartRateData(
    bpm:        (j['bpm'] as num).toInt(),
    spo2:       (j['spo2'] as num).toInt(),
    recordedAt: j['recorded_at'] != null ? DateTime.parse(j['recorded_at']) : DateTime.now(),
  );
}

class ActivityData {
  final int steps;
  final int caloriesBurned;
  final int activeMinutes;
  final double distanceKm;
  final String activityType;
  final DateTime recordedAt;
  const ActivityData({
    required this.steps, required this.caloriesBurned,
    required this.activeMinutes, required this.distanceKm,
    required this.activityType, required this.recordedAt,
  });
  factory ActivityData.fromJson(Map<String, dynamic> j) => ActivityData(
    steps:          (j['steps'] as num?)?.toInt() ?? 0,
    caloriesBurned: (j['calories_burned'] as num?)?.toInt() ?? 0,
    activeMinutes:  (j['active_minutes'] as num?)?.toInt() ?? 0,
    distanceKm:     (j['distance_km'] as num?)?.toDouble() ?? 0.0,
    activityType:   j['activity_type'] as String? ?? 'walking',
    recordedAt: j['recorded_at'] != null ? DateTime.parse(j['recorded_at']) : DateTime.now(),
  );
}

class DeviceStatusData {
  final bool isOnline;
  final int batteryPct;
  final String? firmwareVersion;
  const DeviceStatusData({required this.isOnline, required this.batteryPct, this.firmwareVersion});
  factory DeviceStatusData.fromJson(Map<String, dynamic> j) => DeviceStatusData(
    isOnline:        j['is_online'] as bool? ?? true,
    batteryPct:      (j['battery_pct'] as num?)?.toInt() ?? 0,
    firmwareVersion: j['firmware_version'] as String?,
  );
}

// ── MQTT Service ──────────────────────────────────────────────
class MqttService {
  MqttServerClient? _client;
  final _supabase = Supabase.instance.client;

  String? _cachedDeviceId;

  // FIX: gunakan StreamSubscription agar bisa cancel sebelum register ulang
  StreamSubscription? _messageSubscription;

  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;
  int _reconnectAttempts = 0;
  static const int _maxAttempts = 5;

  final _heartRateCtrl    = StreamController<HeartRateData>.broadcast();
  final _activityCtrl     = StreamController<ActivityData>.broadcast();
  final _deviceStatusCtrl = StreamController<DeviceStatusData>.broadcast();
  final _alertCtrl        = StreamController<Map<String, dynamic>>.broadcast();

  Stream<HeartRateData>        get heartRateStream    => _heartRateCtrl.stream;
  Stream<ActivityData>         get activityStream     => _activityCtrl.stream;
  Stream<DeviceStatusData>     get deviceStatusStream => _deviceStatusCtrl.stream;
  Stream<Map<String, dynamic>> get alertStream        => _alertCtrl.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  // ── Cache device_id ────────────────────────────────────────
  Future<String?> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId;
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final res = await _supabase
        .from('devices')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();
    if (res == null) return null;
    _cachedDeviceId = res['id'] as String;
    return _cachedDeviceId;
  }

  // ── Connect ────────────────────────────────────────────────
  Future<void> connect() async {
    // FIX: pakai _isConnecting bukan _isReconnecting
    // agar tidak ada dua connect() berjalan bersamaan
    if (isConnected || _isConnecting) return;
    _isConnecting = true;

    // FIX: cancel listener lama sebelum buat client baru
    await _messageSubscription?.cancel();
    _messageSubscription = null;

    try {
      try { _client?.disconnect(); } catch (_) {}
      _client = null;

      final clientId = 'flutter_gelang_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient.withPort(_broker, clientId, _port);
      _client!.secure               = true;
      _client!.securityContext      = SecurityContext.defaultContext;
      _client!.autoReconnect        = false;
      _client!.keepAlivePeriod      = 20;
      _client!.connectTimeoutPeriod = 30000;
      _client!.logging(on:          false);

      // FIX: jangan set onDisconnected di sini, set setelah connect berhasil
      // agar tidak trigger saat koneksi belum established
      _client!.onConnected    = _onConnected;
      _client!.onSubscribed   = (t) => print('[MQTT] subscribed: $t');
      _client!.onSubscribeFail = (t) => print('[MQTT] subscribe fail: $t');

      _client!.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(_user, _pass)
          .withWillQos(MqttQos.atLeastOnce)
          .withWillTopic('gelang/$_deviceUid/status')
          .withWillMessage('{"is_online": false, "battery_pct": 0}')
          .startClean();

      print('[MQTT] Connecting...');
      final status = await _client!.connect();

      if (status?.state == MqttConnectionState.connected) {
        print('[MQTT] Connected');
        _isConnecting      = false;
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();

        // Set disconnect callback setelah berhasil connect
        _client!.onDisconnected = _onDisconnected;

        await Future.delayed(const Duration(milliseconds: 300));

        _subscribe('gelang/$_deviceUid/heartrate');
        _subscribe('gelang/$_deviceUid/activity');
        _subscribe('gelang/$_deviceUid/status');
        _subscribe('gelang/$_deviceUid/alert');

        // FIX: simpan subscription agar bisa cancel nanti
        _messageSubscription = _client!.updates!.listen(_onMessage);

        _startKeepAlive();
      } else {
        print('[MQTT] Connect failed: ${status?.returnCode}');
        _isConnecting = false;
        _scheduleReconnect();
      }
    } catch (e) {
      print('[MQTT] Connect error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _onConnected() {
    print('[MQTT] onConnected callback');
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
  }

  void _onDisconnected() {
    print('[MQTT] Disconnected');
    _keepAliveTimer?.cancel();
    // FIX: cancel subscription lama agar tidak ada ghost listener
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    // FIX: jangan schedule jika sedang connecting
    if (_isConnecting) return;
    if (_reconnectTimer?.isActive == true) return;

    final delay = Duration(seconds: 5 * (1 << _reconnectAttempts.clamp(0, 4)));
    if (_reconnectAttempts < _maxAttempts) _reconnectAttempts++;

    print('[MQTT] Reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null; // FIX: reset timer sebelum connect
      connect();
    });
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isConnected && !_isConnecting) {
        print('[MQTT] Keep-alive: not connected, reconnecting...');
        _scheduleReconnect();
      }
    });
  }

  void _subscribe(String topic) {
    if (!isConnected) return;
    _client!.subscribe(topic, MqttQos.atLeastOnce);
  }

  // ── Handle pesan masuk ─────────────────────────────────────
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic   = msg.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
          (msg.payload as MqttPublishMessage).payload.message);
      print('[MQTT] $topic : $payload');
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        if (topic.endsWith('/heartrate'))    _handleHeartrate(json);
        else if (topic.endsWith('/activity')) _handleActivity(json);
        else if (topic.endsWith('/status'))   _handleStatus(json);
        else if (topic.endsWith('/alert'))    _handleAlert(json);
      } catch (e) {
        print('[MQTT] Parse error on $topic: $e');
      }
    }
  }

  // ── Handler heartrate ──────────────────────────────────────
  Future<void> _handleHeartrate(Map<String, dynamic> json) async {
    final data = HeartRateData.fromJson(json);

    // Validasi data sebelum proses
    if (data.bpm <= 0 || data.spo2 <= 0 || data.bpm > 300 || data.spo2 > 100) {
      print('[MQTT] skip invalid heartrate: bpm=${data.bpm} spo2=${data.spo2}');
      return;
    }

    _heartRateCtrl.add(data);
    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) return;
      await _supabase.from('heart_rate_logs').insert({
        'device_id':   deviceId,
        'bpm':         data.bpm,
        'spo2':        data.spo2,
        'recorded_at': data.recordedAt.toIso8601String(),
      });
      print('[MQTT] heartrate inserted OK');
    } catch (e) {
      print('[MQTT] insert heartrate error: $e');
    }
  }

  // ── Kalkulator kalori & jarak (rumus MET ACSM) ───────────────
  _ActivityCalc _calculateActivity(int steps, Map<String, dynamic> profile) {
    final heightCm = (profile['height_cm'] as num?)?.toDouble() ?? 165.0;
    final weightKg = (profile['weight_kg'] as num?)?.toDouble() ?? 60.0;
    final gender   = profile['gender'] as String? ?? 'male';
    final birthDate = profile['birth_date'] as String?;

    // Faktor gender
    final strideFactor = gender == 'female' ? 0.413 : 0.415;
    final calGenderFactor = gender == 'female' ? 0.95 : 1.00;

    // Hitung usia
    int age = 25;
    if (birthDate != null) {
      try {
        final dob = DateTime.parse(birthDate);
        age = DateTime.now().difference(dob).inDays ~/ 365;
      } catch (_) {}
    }

    // Faktor koreksi usia
    final double ageFactor;
    if (age < 30)       ageFactor = 1.00;
    else if (age < 50)  ageFactor = 0.97;
    else if (age < 65)  ageFactor = 0.93;
    else                ageFactor = 0.88;

    // Hitung stride & jarak
    final strideM  = heightCm * strideFactor / 100;
    final distanceKm = strideM * steps / 1000;

    // Estimasi kecepatan → MET
    final speedKmh = strideM * 100 * 0.06;
    final double met;
    if (speedKmh < 3.0)       met = 2.5;
    else if (speedKmh < 5.0)  met = 3.5;
    else if (speedKmh < 6.5)  met = 4.5;
    else                      met = 6.0;

    // Hitung kalori
    final calRaw     = met * weightKg * 0.000175 * steps;
    final calGender  = calRaw * calGenderFactor;
    final totalCal   = (calGender * ageFactor).round();

    // Estimasi active_minutes dari steps (asumsi 100 langkah/menit)
    final activeMinutes = (steps / 100).round();

    print('[Calc] steps=$steps height=${heightCm}cm weight=${weightKg}kg '
        'gender=$gender age=$age stride=${strideM.toStringAsFixed(3)}m '
        'speed=${speedKmh.toStringAsFixed(1)}km/h MET=$met '
        'cal=$totalCal dist=${distanceKm.toStringAsFixed(2)}km');

    return _ActivityCalc(
      calories:    totalCal,
      distanceKm:  double.parse(distanceKm.toStringAsFixed(2)),
      activeMinutes: activeMinutes,
    );
  }

  // Cache profil user agar tidak query tiap pesan
  Map<String, dynamic>? _cachedProfile;

  Future<Map<String, dynamic>?> _getUserProfile() async {
  if (_cachedProfile != null) return _cachedProfile;
  final user = _supabase.auth.currentUser;
  if (user == null) return null;
  try {
    final res = await _supabase
        .from('profiles')
        .select('height_cm, weight_kg, age') // ← hapus gender dari query
        .eq('id', user.id)
        .maybeSingle();
    if (res != null) {
      _cachedProfile = {
        ...res,
        'gender': 'male', // ← hardcode male
      };
    }
    return _cachedProfile;
  } catch (e) {
    print('[MQTT] get profile error: $e');
    return null;
  }
}

  // ── Handler activity ───────────────────────────────────────
  Future<void> _handleActivity(Map<String, dynamic> json) async {
    final data = ActivityData.fromJson(json);

    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) {
        print('[MQTT] activity: device not found, skip insert');
        return;
      }

      // Ambil profil user untuk kalkulasi kalori & jarak
      final profile = await _getUserProfile();
      final calc    = profile != null
          ? _calculateActivity(data.steps, profile)
          : _ActivityCalc(
              calories:     data.caloriesBurned,
              distanceKm:   data.distanceKm,
              activeMinutes: data.activeMinutes,
            );

      // Update ActivityData dengan nilai kalkulasi sebelum push ke stream
      final computed = ActivityData(
        steps:          data.steps,
        caloriesBurned: calc.calories,
        activeMinutes:  calc.activeMinutes,
        distanceKm:     calc.distanceKm,
        activityType:   data.activityType,
        recordedAt:     data.recordedAt,
      );
      _activityCtrl.add(computed);

      await _supabase.from('activity_logs').insert({
        'device_id':       deviceId,
        'steps':           data.steps,
        'activity_type':   data.activityType,
        'calories_burned': calc.calories,       // ← hasil kalkulasi
        'active_minutes':  calc.activeMinutes,  // ← hasil kalkulasi
        'distance_km':     calc.distanceKm,     // ← hasil kalkulasi
        'accel_x':         (json['accel_x'] as num?)?.toInt(),
        'accel_y':         (json['accel_y'] as num?)?.toInt(),
        'accel_z':         (json['accel_z'] as num?)?.toInt(),
        'recorded_at':     data.recordedAt.toIso8601String(),
      });
      print('[MQTT] activity inserted OK — ${calc.calories}kkal ${calc.distanceKm}km');
    } catch (e) {
      print('[MQTT] insert activity error: $e');
    }
  }

  // ── Handler status ─────────────────────────────────────────
  Future<void> _handleStatus(Map<String, dynamic> json) async {
    final data = DeviceStatusData.fromJson(json);
    _deviceStatusCtrl.add(data);
    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) return;
      await _supabase.from('devices').update({
        'is_online':        data.isOnline,
        'battery_pct':      data.batteryPct,
        'firmware_version': data.firmwareVersion,
        'last_seen_at':     DateTime.now().toIso8601String(),
      }).eq('id', deviceId);
    } catch (e) {
      print('[MQTT] update status error: $e');
    }
  }

  // ── Handler alert ──────────────────────────────────────────
  Future<void> _handleAlert(Map<String, dynamic> json) async {
    _alertCtrl.add(json);
    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) return;
      await _supabase.from('alerts_log').insert({
        'device_id':        deviceId,
        'alert_type':       json['alert_type'],
        'value':            json['value'],
        'threshold':        json['threshold'],
        'buzzer_triggered': json['buzzer_triggered'] ?? true,
        'notif_sent':       false,
        'triggered_at':     json['triggered_at'] ?? DateTime.now().toIso8601String(),
      });
      print('[MQTT] alert inserted OK');
    } catch (e) {
      print('[MQTT] insert alert error: $e');
    }
  }

  void disconnect() {
    _keepAliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _isConnecting    = false;
    _cachedProfile   = null; // reset agar profil terbaru dipakai saat reconnect
    _client?.disconnect();
    _client = null;
  }

  void dispose() {
    disconnect();
    _heartRateCtrl.close();
    _activityCtrl.close();
    _deviceStatusCtrl.close();
    _alertCtrl.close();
  }
}

// ── Helper kalkulasi ──────────────────────────────────────────
class _ActivityCalc {
  final int calories;
  final int activeMinutes;
  final double distanceKm;

  const _ActivityCalc({
    required this.calories,
    required this.activeMinutes,
    required this.distanceKm,
  });
}

// ── Provider ──────────────────────────────────────────────────
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  Future.delayed(const Duration(milliseconds: 500), service.connect);
  ref.onDispose(service.dispose);
  return service;
});