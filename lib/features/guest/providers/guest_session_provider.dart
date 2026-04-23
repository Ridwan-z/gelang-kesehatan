// lib/core/providers/guest_session_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ─────────────────────────────────────────────────────
class GuestSession {
  final String deviceId;
  final String groupId;
  final String inviteCode;
  final String ownerName;
  final String deviceName;

  const GuestSession({
    required this.deviceId,
    required this.groupId,
    required this.inviteCode,
    required this.ownerName,
    required this.deviceName,
  });

  Map<String, String> toMap() => {
        'deviceId': deviceId,
        'groupId': groupId,
        'inviteCode': inviteCode,
        'ownerName': ownerName,
        'deviceName': deviceName,
      };

  factory GuestSession.fromMap(Map<String, String> m) => GuestSession(
        deviceId: m['deviceId']!,
        groupId: m['groupId']!,
        inviteCode: m['inviteCode']!,
        ownerName: m['ownerName']!,
        deviceName: m['deviceName']!,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class GuestSessionNotifier extends Notifier<GuestSession?> {
  static const _prefix = 'guest_';

  @override
  GuestSession? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('${_prefix}deviceId');
    if (deviceId == null) return;

    state = GuestSession(
      deviceId:   deviceId,
      groupId:    prefs.getString('${_prefix}groupId') ?? '',
      inviteCode: prefs.getString('${_prefix}inviteCode') ?? '',
      ownerName:  prefs.getString('${_prefix}ownerName') ?? '',
      deviceName: prefs.getString('${_prefix}deviceName') ?? '',
    );
  }

  Future<void> join(GuestSession session) async {
    state = session;
    final prefs = await SharedPreferences.getInstance();
    for (final e in session.toMap().entries) {
      await prefs.setString('$_prefix${e.key}', e.value);
    }
  }

  Future<void> updateCode(String newCode) async {
    if (state == null) return;
    final updated = GuestSession(
      deviceId:   state!.deviceId,
      groupId:    state!.groupId,
      inviteCode: newCode,
      ownerName:  state!.ownerName,
      deviceName: state!.deviceName,
    );
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}inviteCode', newCode);
  }

  Future<void> leave() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'deviceId', 'groupId', 'inviteCode', 'ownerName', 'deviceName'
    ]) {
      await prefs.remove('$_prefix$key');
    }
  }
}

final guestSessionProvider =
    NotifierProvider<GuestSessionNotifier, GuestSession?>(
        GuestSessionNotifier.new);

// ── Helper provider ───────────────────────────────────────────
// true = sedang dalam mode guest
final isGuestModeProvider = Provider<bool>((ref) {
  return ref.watch(guestSessionProvider) != null;
});

// ── Service: validasi kode dari Supabase ──────────────────────
// Dummy dulu — nanti diganti query Supabase
class GuestJoinService {
  static Future<GuestSession?> joinWithCode(String code) async {
    await Future.delayed(const Duration(seconds: 1));

    // Dummy: kode valid = 'KELUARGA-001'
    // Nanti ganti dengan query:
    // SELECT fg.id, fg.invite_code, d.id as device_id,
    //        p.full_name as owner_name, d.name as device_name
    // FROM family_groups fg
    // JOIN devices d ON d.owner_id = fg.admin_id
    // JOIN profiles p ON p.id = fg.admin_id
    // WHERE fg.invite_code = $code
    // LIMIT 1

    if (code.toUpperCase() == 'KELUARGA-001') {
      return const GuestSession(
        deviceId:   'dummy-device-1',
        groupId:    'dummy-group-1',
        inviteCode: 'KELUARGA-001',
        ownerName:  'Pemilik Gelang',
        deviceName: 'Gelangku',
      );
    }

    // Kode tidak valid
    return null;
  }

  static Future<bool> validateCode(String code, String groupId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Dummy: cek apakah kode masih valid untuk grup ini
    // Nanti ganti dengan:
    // SELECT invite_code FROM family_groups WHERE id = $groupId
    // Lalu bandingkan dengan $code

    // Simulasi: kode KELUARGA-001 selalu valid untuk dummy
    return code.toUpperCase() == 'KELUARGA-001';
  }
}