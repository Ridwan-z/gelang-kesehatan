// lib/features/family/screens/family_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/providers/auth_provider.dart';

// ── Provider: ambil atau buat family group dari Supabase ──────
final familyGroupProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Tidak terautentikasi');

  // Cek apakah user sudah punya grup (sebagai admin)
  final existing = await supabase
      .from('family_groups')
      .select('id, name, invite_code, created_at')
      .eq('admin_id', user.id)
      .limit(1);

  if ((existing as List).isNotEmpty) {
    return existing.first as Map<String, dynamic>;
  }

  // Belum ada grup → buat otomatis
  // invite_code sudah punya default di DB: substr(md5(random()::text), 1, 8)
  final profile = await supabase
      .from('profiles')
      .select('full_name')
      .eq('id', user.id)
      .maybeSingle();

  final groupName = profile != null
      ? 'Keluarga ${(profile['full_name'] as String).split(' ').first}'
      : 'Keluargaku';

  final created = await supabase
      .from('family_groups')
      .insert({'admin_id': user.id, 'name': groupName})
      .select('id, name, invite_code, created_at')
      .single();

  return created as Map<String, dynamic>;
});

// ── Screen ────────────────────────────────────────────────────
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(familyGroupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keluarga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(familyGroupProvider),
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Gagal memuat data.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(familyGroupProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (group) => _FamilyContent(group: group),
      ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────
class _FamilyContent extends StatelessWidget {
  final Map<String, dynamic> group;
  const _FamilyContent({required this.group});

  @override
  Widget build(BuildContext context) {
    final code = group['invite_code'] as String? ?? '-';
    final name = group['name'] as String? ?? 'Keluarga';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBanner(groupName: name),
          const SizedBox(height: 24),
          _QrCard(code: code),
          const SizedBox(height: 16),
          _CodeCard(code: code),
          const SizedBox(height: 24),
          _HowToUseSection(),
          const SizedBox(height: 24),
          _ComingSoonSection(),
        ],
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final String groupName;
  const _InfoBanner({required this.groupName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.people_outline,
                color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bagikan kode atau QR di bawah kepada anggota keluarga agar mereka bisa melihat data kesehatan gelang kamu secara real-time.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── QR Card ───────────────────────────────────────────────────
class _QrCard extends StatelessWidget {
  final String code;
  const _QrCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrData = 'gelangsehat://join?code=$code';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'QR Code Keluarga',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan QR ini untuk bergabung memantau gelang',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.45)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Latar putih supaya QR terbaca di dark mode
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF000000)),
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1DB954),
                letterSpacing: 2),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _share(context, code),
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Bagikan QR & Kode'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, String code) async {
    await Share.share(
      'Gunakan kode ini untuk melihat kondisi kesehatanku via Gelang Sehat:\n\nKode: $code\n\nBuka app → "Lihat Kondisi Keluarga" → masukkan kode.',
      subject: 'Kode Pemantauan Gelang Sehat',
    );
  }
}

// ── Kode card ─────────────────────────────────────────────────
class _CodeCard extends StatelessWidget {
  final String code;
  const _CodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.vpn_key_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text('Kode Keluarga',
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: theme.colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle, color: Colors.black),
                    SizedBox(width: 10),
                    Text('Kode disalin!'),
                  ]),
                  backgroundColor: const Color(0xFF1DB954),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              },
              child: Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.copy_rounded,
                    color: Colors.black, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Share.share(
                  'Gunakan kode ini untuk melihat kondisi kesehatanku via Gelang Sehat:\n\nKode: $code\n\nBuka app → "Lihat Kondisi Keluarga" → masukkan kode.',
                  subject: 'Kode Pemantauan Gelang Sehat',
                );
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Bagikan Kode'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cara pakai ────────────────────────────────────────────────
class _HowToUseSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cara Pakai',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(children: [
            _StepItem(
              step: '1',
              icon: Icons.share_outlined,
              title: 'Bagikan kode atau QR',
              desc: 'Kirim kode atau screenshot QR kepada anggota keluarga.',
              isLast: false,
            ),
            _StepItem(
              step: '2',
              icon: Icons.phone_android_outlined,
              title: 'Keluarga buka app',
              desc: 'Pilih "Lihat Kondisi Keluarga" di halaman login, lalu masukkan kode.',
              isLast: false,
            ),
            _StepItem(
              step: '3',
              icon: Icons.monitor_heart_outlined,
              title: 'Pantau bersama',
              desc: 'Mereka bisa melihat detak jantung, SpO2, langkah kaki, dan riwayat kesehatan secara real-time.',
              isLast: true,
            ),
          ]),
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String desc;
  final bool isLast;
  const _StepItem({
    required this.step,
    required this.icon,
    required this.title,
    required this.desc,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(step,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withOpacity(0.55))),
            ]),
          ),
        ]),
      ),
      if (!isLast)
        Divider(
            height: 1,
            indent: 62,
            color: theme.colorScheme.onSurface.withOpacity(0.07)),
    ]);
  }
}

// ── Coming soon ───────────────────────────────────────────────
class _ComingSoonSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Segera Hadir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9F0A).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Dalam Pengembangan',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9F0A))),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(children: [
            _ComingFeature(
              icon: Icons.favorite_outline,
              title: 'Monitor Kesehatan Real-time',
              desc: 'Lihat detak jantung & SpO2 anggota keluarga secara langsung',
              isLast: false,
            ),
            _ComingFeature(
              icon: Icons.bar_chart_outlined,
              title: 'Riwayat Kesehatan Keluarga',
              desc: 'Akses grafik dan statistik kesehatan harian/mingguan',
              isLast: false,
            ),
            _ComingFeature(
              icon: Icons.notifications_outlined,
              title: 'Notifikasi Darurat',
              desc: 'Terima alert jika kondisi anggota keluarga melampaui batas normal',
              isLast: false,
            ),
            _ComingFeature(
              icon: Icons.people_outline,
              title: 'Manajemen Anggota',
              desc: 'Kelola siapa saja yang bisa melihat data kesehatanmu',
              isLast: true,
            ),
          ]),
        ),
      ],
    );
  }
}

class _ComingFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool isLast;
  const _ComingFeature({
    required this.icon,
    required this.title,
    required this.desc,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.35)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.35),
                      height: 1.4)),
            ]),
          ),
          Icon(Icons.lock_outline,
              size: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.2)),
        ]),
      ),
      if (!isLast)
        Divider(
            height: 1,
            indent: 68,
            color: theme.colorScheme.onSurface.withOpacity(0.06)),
    ]);
  }
}