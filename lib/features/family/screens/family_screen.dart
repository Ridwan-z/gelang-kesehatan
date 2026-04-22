// lib/features/family/screens/family_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/family_provider.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final groupAsync = ref.watch(myFamilyGroupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keluarga'),
        actions: [
          groupAsync.when(
            data: (group) => group == null
                ? TextButton.icon(
                    onPressed: () => _showCreateOrJoinSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Grup'),
                  )
                : const SizedBox(),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (group) => group == null
            ? _EmptyGroupState(
                onTap: () => _showCreateOrJoinSheet(context, ref))
            : _GroupContent(group: group),
      ),
    );
  }

  void _showCreateOrJoinSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CreateOrJoinSheet(),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyGroupState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyGroupState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline, size: 40,
                color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('Belum ada grup keluarga',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Buat grup baru atau bergabung dengan kode undangan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('Buat atau Gabung Grup'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group content ─────────────────────────────────────────────
class _GroupContent extends ConsumerWidget {
  final FamilyGroup group;
  const _GroupContent({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final members = ref.watch(familyMembersProvider);
    final devices = ref.watch(familyDevicesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Info grup ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.people,
                      color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name,
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('Grup Keluarga',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Kode undangan
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Text('Kode: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    Text(group.inviteCode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 2)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: group.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kode disalin!'),
                            duration: Duration(seconds: 1)));
                      },
                      child: Icon(Icons.copy, size: 16,
                        color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Anggota ────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Anggota',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            members.when(
              data: (m) => Text('${m.length} orang',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        members.when(
          loading: () => const _SkeletonBox(height: 80),
          error: (_, __) => const Center(child: Text('Gagal memuat')),
          data: (list) => Column(
            children: list.map((m) => _MemberTile(member: m)).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // ── Monitoring kesehatan gelang anggota ────
        const Text('Pantau Kesehatan Anggota',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Hanya gelang yang dibagikan ke grup yang tampil',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.4))),
        const SizedBox(height: 10),
        devices.when(
          loading: () => const _SkeletonBox(height: 120),
          error: (_, __) => const Center(child: Text('Gagal memuat')),
          data: (list) => list.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.watch_off_outlined,
                        color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada gelang yang dibagikan ke grup ini',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: list
                      .map((d) => _DeviceHealthCard(device: d))
                      .toList(),
                ),
        ),
        const SizedBox(height: 20),

        // ── Keluar grup ────────────────────────────
        TextButton(
          onPressed: () => _confirmLeave(context, ref),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.red, width: 0.5)),
          ),
          child: const Text('Keluar dari Grup',
            style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Grup',
          style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Kamu yakin ingin keluar dari grup keluarga ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(familyGroupNotifierProvider.notifier)
                  .leaveGroup(group.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Keluar',
              style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ── Device health card — tampilkan data kesehatan realtime ─────
class _DeviceHealthCard extends ConsumerWidget {
  final FamilyDevice device;
  const _DeviceHealthCard({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final health = ref.watch(memberHealthProvider(device.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? const Color(0xFF1DB954).withOpacity(0.1)
                      : theme.colorScheme.onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.watch, size: 20,
                  color: device.isOnline
                      ? const Color(0xFF1DB954)
                      : theme.colorScheme.onSurface.withOpacity(0.3)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.ownerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(device.deviceName,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
              // Online badge
              Row(
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline
                          ? const Color(0xFF1DB954)
                          : Colors.red),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    device.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: device.isOnline
                          ? const Color(0xFF1DB954)
                          : Colors.red)),
                ],
              ),
            ],
          ),

          // Health data
          const SizedBox(height: 12),
          health.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text('Tidak dapat memuat data',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
            data: (data) => data == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Belum ada data kesehatan',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                  )
                : Row(
                    children: [
                      // BPM
                      Expanded(
                        child: _HealthMetric(
                          icon: Icons.favorite,
                          color: _bpmColor(data['bpm']),
                          value: '${data['bpm']}',
                          unit: 'BPM',
                        ),
                      ),
                      // SpO2
                      Expanded(
                        child: _HealthMetric(
                          icon: Icons.air,
                          color: _spo2Color(data['spo2']),
                          value: '${data['spo2']}',
                          unit: 'SpO2%',
                        ),
                      ),
                      // Steps
                      Expanded(
                        child: _HealthMetric(
                          icon: Icons.directions_walk,
                          color: const Color(0xFF0A84FF),
                          value: NumberFormat('#,###').format(data['steps']),
                          unit: 'Langkah',
                        ),
                      ),
                      // Baterai
                      if (device.batteryPct != null)
                        Expanded(
                          child: _HealthMetric(
                            icon: Icons.battery_std,
                            color: _batteryColor(device.batteryPct!),
                            value: '${device.batteryPct}',
                            unit: 'Baterai%',
                          ),
                        ),
                    ],
                  ),
          ),

          // Waktu update terakhir
          health.whenData((data) {
            if (data == null) return const SizedBox();
            final time = DateTime.tryParse(data['recorded_at'] ?? '');
            if (time == null) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Update: ${DateFormat('HH:mm').format(time.toLocal())}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.3))),
            );
          }).value ?? const SizedBox(),
        ],
      ),
    );
  }

  Color _bpmColor(dynamic bpm) {
    if (bpm == null) return Colors.grey;
    final v = bpm as int;
    if (v > 150 || v < 45) return const Color(0xFFFF3B30);
    if (v > 120 || v < 55) return const Color(0xFFFF9F0A);
    return const Color(0xFF1DB954);
  }

  Color _spo2Color(dynamic spo2) {
    if (spo2 == null) return Colors.grey;
    final v = spo2 as int;
    if (v < 90) return const Color(0xFFFF3B30);
    if (v < 95) return const Color(0xFFFF9F0A);
    return const Color(0xFF1DB954);
  }

  Color _batteryColor(int pct) {
    if (pct < 20) return const Color(0xFFFF3B30);
    if (pct < 50) return const Color(0xFFFF9F0A);
    return const Color(0xFF1DB954);
  }
}

// ── Health metric item ────────────────────────────────────────
class _HealthMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  const _HealthMetric({
    required this.icon, required this.color,
    required this.value, required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color)),
        Text(unit,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.4))),
      ],
    );
  }
}

// ── Member tile ───────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final FamilyMember member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isAdmin = member.role == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
            child: Text(
              member.fullName[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(_formatDate(member.joinedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4))),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Admin',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary)),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Bergabung hari ini';
    if (diff < 30) return 'Bergabung $diff hari lalu';
    return 'Bergabung ${diff ~/ 30} bulan lalu';
  }
}

// ── Create or join sheet ──────────────────────────────────────
class _CreateOrJoinSheet extends ConsumerStatefulWidget {
  const _CreateOrJoinSheet();

  @override
  ConsumerState<_CreateOrJoinSheet> createState() => _CreateOrJoinSheetState();
}

class _CreateOrJoinSheetState extends ConsumerState<_CreateOrJoinSheet> {
  bool _isCreate = true;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final notifier  = ref.watch(familyGroupNotifierProvider);
    final isLoading = notifier.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Toggle
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _SheetTab(
                    label: 'Buat Grup',
                    selected: _isCreate,
                    onTap: () => setState(() => _isCreate = true),
                  ),
                  _SheetTab(
                    label: 'Gabung Grup',
                    selected: !_isCreate,
                    onTap: () => setState(() => _isCreate = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isCreate) ...[
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Grup',
                  hintText: 'Contoh: Keluarga Besar Zaini',
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (_nameCtrl.text.isEmpty) return;
                  await ref
                      .read(familyGroupNotifierProvider.notifier)
                      .createGroup(_nameCtrl.text.trim());

                  if (!context.mounted) return;
                  final state = ref.read(familyGroupNotifierProvider);
                  if (state.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.error.toString()),
                      backgroundColor: Colors.red));
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Grup berhasil dibuat! 🎉'),
                        backgroundColor: Color(0xFF1DB954)));
                  }
                },
                child: isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black))
                    : const Text('Buat Grup'),
              ),
            ] else ...[
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode Undangan',
                  hintText: 'Contoh: AB12CD34',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (_codeCtrl.text.isEmpty) return;
                  await ref
                      .read(familyGroupNotifierProvider.notifier)
                      .joinGroup(_codeCtrl.text.trim());

                  if (!context.mounted) return;
                  final state = ref.read(familyGroupNotifierProvider);
                  if (state.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.error.toString()),
                      backgroundColor: Colors.red));
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Berhasil bergabung ke grup! 🎉'),
                        backgroundColor: Color(0xFF1DB954)));
                  }
                },
                child: isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black))
                    : const Text('Gabung Grup'),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SheetTab({
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
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

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}