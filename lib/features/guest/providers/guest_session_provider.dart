// lib/features/guest/providers/guest_session_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
final isGuestModeProvider = Provider<bool>((ref) {
  return ref.watch(guestSessionProvider) != null;
});

// ── Service: query ke Supabase ────────────────────────────────
class GuestJoinService {
  static final _supabase = Supabase.instance.client;

  static Future<GuestSession?> joinWithCode(String code) async {
  try {
    final cleanCode = code.trim().toLowerCase();
    print('=== DEBUG joinWithCode ===');
    print('Input code: "$code"');
    print('Clean code: "$cleanCode"');
    print('Code length: ${cleanCode.length}');

    final groupRes = await _supabase
        .from('family_groups')
        .select('id, name, admin_id, invite_code')
        .eq('invite_code', cleanCode)
        .limit(1);

    print('groupRes: $groupRes');
    print('groupRes type: ${groupRes.runtimeType}');
    print('groupRes length: ${(groupRes as List).length}');

    if (groupRes.isEmpty) {
      print('ERROR: group tidak ditemukan!');
      return null;
    }

    final group      = groupRes.first as Map<String, dynamic>;
    final groupId    = group['id'] as String;
    final adminId    = group['admin_id'] as String;
    print('groupId: $groupId');
    print('adminId: $adminId');

    final profileRes = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', adminId)
        .limit(1);

    print('profileRes: $profileRes');

    final ownerName = (profileRes as List).isNotEmpty
        ? (profileRes.first['full_name'] as String? ?? 'Pemilik')
        : 'Pemilik';

    final deviceRes = await _supabase
        .from('devices')
        .select('id, name')
        .eq('owner_id', adminId)
        .limit(1);

    print('deviceRes: $deviceRes');

    String deviceId;
    String deviceName;

    if ((deviceRes as List).isNotEmpty) {
      deviceId   = deviceRes.first['id'] as String;
      deviceName = deviceRes.first['name'] as String? ?? 'Gelang';
    } else {
      deviceId   = groupId;
      deviceName = 'Gelang';
    }

    print('=== SUCCESS: session dibuat ===');
    return GuestSession(
      deviceId:   deviceId,
      groupId:    groupId,
      inviteCode: cleanCode,
      ownerName:  ownerName,
      deviceName: deviceName,
    );
  } catch (e, st) {
    print('=== ERROR joinWithCode ===');
    print('Error: $e');
    print('Stacktrace: $st');
    return null;
  }
}

  static Future<bool> validateCode(String code, String groupId) async {
    try {
      final res = await _supabase
          .from('family_groups')
          .select('invite_code')
          .eq('id', groupId)
          .limit(1);

      if (res == null || (res as List).isEmpty) return false;

      final dbCode = res.first['invite_code'] as String? ?? '';
      return dbCode == code.trim().toLowerCase();
    } catch (e) {
      return false;
    }
  }
}