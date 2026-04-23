// lib/features/family/providers/family_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────
class FamilyGroup {
  final String id;
  final String name;
  final String adminId;
  final String inviteCode;

  const FamilyGroup({
    required this.id,
    required this.name,
    required this.adminId,
    required this.inviteCode,
  });

  factory FamilyGroup.fromMap(Map<String, dynamic> m) => FamilyGroup(
    id:         m['id'],
    name:       m['name'],
    adminId:    m['admin_id'],
    inviteCode: m['invite_code'] ?? '',
  );
}

class FamilyMember {
  final String id;
  final String userId;
  final String fullName;
  final String role;
  final DateTime joinedAt;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.joinedAt,
  });
}

class FamilyDevice {
  final String id;
  final String deviceName;
  final String ownerName;
  final String permission;
  final bool isOnline;
  final int? batteryPct;

  const FamilyDevice({
    required this.id,
    required this.deviceName,
    required this.ownerName,
    required this.permission,
    required this.isOnline,
    this.batteryPct,
  });

  factory FamilyDevice.fromMap(Map<String, dynamic> m) => FamilyDevice(
    id:         m['id'],
    deviceName: m['device_name'] ?? 'Gelang',
    ownerName:  m['owner_name'] ?? '',
    permission: m['permission'] ?? 'alert',
    isOnline:   m['is_online'] ?? false,
    batteryPct: m['battery_pct'],
  );
}

// ── Providers ─────────────────────────────────────────────────

// Grup milik / diikuti user
final myFamilyGroupProvider = FutureProvider<FamilyGroup?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user     = supabase.auth.currentUser;
  if (user == null) return null;

  // Cek apakah user adalah admin grup (ambil 1 saja)
  final adminRes = await supabase
      .from('family_groups')
      .select()
      .eq('admin_id', user.id)
      .order('created_at', ascending: false)
      .limit(1);  // ← pakai limit, bukan maybeSingle

  if (adminRes.isNotEmpty) return FamilyGroup.fromMap(adminRes.first);

  // Cek apakah user adalah member
  final memberRes = await supabase
      .from('family_members')
      .select('group_id, family_groups(*)')
      .eq('user_id', user.id)
      .order('joined_at', ascending: false)
      .limit(1);  // ← pakai limit, bukan maybeSingle

  if (memberRes.isNotEmpty && memberRes.first['family_groups'] != null) {
    return FamilyGroup.fromMap(memberRes.first['family_groups']);
  }

  return null;
});

// Anggota grup
final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final group = await ref.watch(myFamilyGroupProvider.future);
  if (group == null) return [];

  final supabase = ref.watch(supabaseProvider);

  final res = await supabase
      .from('family_members')
      .select('id, user_id, role, joined_at, profiles(full_name)')
      .eq('group_id', group.id)
      .order('joined_at');

  return (res as List).map((e) => FamilyMember(
    id:        e['id'],
    userId:    e['user_id'],
    fullName:  e['profiles']?['full_name'] ?? 'Anggota',
    role:      e['role'] ?? 'member',
    joinedAt:  DateTime.parse(e['joined_at']),
  )).toList();
});

// Gelang yang dishare ke grup (dari v_family_devices)
final familyDevicesProvider = FutureProvider<List<FamilyDevice>>((ref) async {
  final group = await ref.watch(myFamilyGroupProvider.future);
  if (group == null) return [];

  final supabase = ref.watch(supabaseProvider);

  final res = await supabase
      .from('v_family_devices')
      .select()
      .eq('group_name', group.name);

  return (res as List).map((e) => FamilyDevice.fromMap(e)).toList();
});

// Latest health data per device untuk monitoring
final memberHealthProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, deviceId) async {
    final supabase = ref.watch(supabaseProvider);

    // Latest heart rate
    final hrRes = await supabase
        .from('heart_rate_logs')
        .select()
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // Latest steps
    final actRes = await supabase
        .from('activity_logs')
        .select()
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (hrRes == null) return null;

    return {
      'bpm':        hrRes['bpm'],
      'spo2':       hrRes['spo2'],
      'recorded_at': hrRes['recorded_at'],
      'steps':      actRes?['steps'] ?? 0,
    };
  },
);

// Notifier untuk aksi grup
class FamilyGroupNotifier extends AsyncNotifier<void> {
  late SupabaseClient _supabase;

  @override
  Future<void> build() async {
    _supabase = ref.watch(supabaseProvider);
  }

  // Buat grup baru
  Future<void> createGroup(String name) async {
    state = const AsyncValue.loading();
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Tidak terautentikasi');

      // Insert grup
      final group = await _supabase
          .from('family_groups')
          .insert({'name': name, 'admin_id': user.id})
          .select()
          .single();

      // Insert diri sendiri sebagai admin member
      await _supabase.from('family_members').insert({
        'group_id': group['id'],
        'user_id':  user.id,
        'role':     'admin',
      });

      // Invalidate provider
      ref.invalidate(myFamilyGroupProvider);
      ref.invalidate(familyMembersProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Gabung grup dengan kode
  Future<void> joinGroup(String inviteCode) async {
    state = const AsyncValue.loading();
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Tidak terautentikasi');

      // Cari grup dengan kode
      final group = await _supabase
          .from('family_groups')
          .select()
          .eq('invite_code', inviteCode.toUpperCase())
          .maybeSingle();

      if (group == null) throw Exception('Kode undangan tidak valid');

      // Cek sudah member belum
      final existing = await _supabase
          .from('family_members')
          .select()
          .eq('group_id', group['id'])
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) throw Exception('Kamu sudah bergabung di grup ini');

      // Join
      await _supabase.from('family_members').insert({
        'group_id': group['id'],
        'user_id':  user.id,
        'role':     'member',
      });

      ref.invalidate(myFamilyGroupProvider);
      ref.invalidate(familyMembersProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Keluar grup
  Future<void> leaveGroup(String groupId) async {
    state = const AsyncValue.loading();
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Tidak terautentikasi');

      await _supabase
          .from('family_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', user.id);

      ref.invalidate(myFamilyGroupProvider);
      ref.invalidate(familyMembersProvider);
      ref.invalidate(familyDevicesProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final familyGroupNotifierProvider =
    AsyncNotifierProvider<FamilyGroupNotifier, void>(FamilyGroupNotifier.new);