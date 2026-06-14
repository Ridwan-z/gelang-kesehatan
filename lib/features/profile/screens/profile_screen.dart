// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gelang_kesehatan/features/profile/screens/notification_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';

// ── Model ─────────────────────────────────────────────────────
class ProfileData {
  final String fullName;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final int stepGoal;
  final int calorieGoal;

  const ProfileData({
    required this.fullName,
    this.age,
    this.weightKg,
    this.heightCm,
    this.stepGoal    = 10000,
    this.calorieGoal = 2000,
  });

  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm! <= 0) return null;
    final hm = heightCm! / 100;
    return weightKg! / (hm * hm);
  }

  String get bmiLabel {
    final b = bmi;
    if (b == null) return '-';
    if (b < 18.5) return 'Kurus';
    if (b < 25)   return 'Normal';
    if (b < 30)   return 'Gemuk';
    return 'Obesitas';
  }

  Color bmiColor(BuildContext context) {
    final b = bmi;
    if (b == null) return Colors.grey;
    if (b < 18.5) return const Color(0xFF0A84FF);
    if (b < 25)   return const Color(0xFF1DB954);
    if (b < 30)   return const Color(0xFFFF9F0A);
    return const Color(0xFFFF3B30);
  }
}

// ── Provider ──────────────────────────────────────────────────
final profileDataProvider = FutureProvider<ProfileData>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user     = supabase.auth.currentUser;
  if (user == null) return const ProfileData(fullName: 'Pengguna');

  final res = await supabase
      .from('profiles')
      .select('full_name, age, weight_kg, height_cm, step_goal, calorie_goal')
      .eq('id', user.id)
      .maybeSingle();

  if (res == null) return const ProfileData(fullName: 'Pengguna');

  return ProfileData(
    fullName:    res['full_name'] as String? ?? 'Pengguna',
    age:         res['age'] as int?,
    weightKg:    (res['weight_kg'] as num?)?.toDouble(),
    heightCm:    (res['height_cm'] as num?)?.toDouble(),
    stepGoal:    res['step_goal'] as int? ?? 10000,
    calorieGoal: res['calorie_goal'] as int? ?? 2000,
  );
});

// ── Screen ────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user         = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileDataProvider);
    final fullName     = user?.userMetadata?['full_name'] ?? 'Pengguna';
    final email        = user?.email ?? '';
    final theme        = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            _ProfileHero(
              fullName: profile.fullName.isNotEmpty
                  ? profile.fullName
                  : fullName,
              email:   email,
              profile: profile,
              onEditTap: () => _showEditSheet(context, ref, profile),
            ),
            const SizedBox(height: 24),

            // ── Notifikasi ───────────────────────────
            _MenuItem(
              icon:     Icons.notifications_outlined,
              label:    'Notifikasi',
              subtitle: 'Atur push notification & quiet hours',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationScreen()),
              ),
            ),

            // ── Toggle Tema — di bawah card notifikasi ─
            _ThemeToggleTile(),

            const SizedBox(height: 20),

            // ── Logout ──────────────────────────────────
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Keluar',
                        style:
                            TextStyle(fontWeight: FontWeight.w700)),
                    content: Text(
                        'Apakah kamu yakin ingin keluar?',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.7))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Batal',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5)))),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('Keluar',
                            style: TextStyle(
                                fontWeight: FontWeight.w600))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .logout();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(
                        color: Colors.red, width: 0.5)),
              ),
              child: const Text('Keluar',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, ProfileData current) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) =>
          _EditProfileSheet(current: current, ref: ref),
    );
  }
}

// ── Profile hero ──────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final String fullName;
  final String email;
  final ProfileData profile;
  final VoidCallback onEditTap;

  const _ProfileHero({
    required this.fullName,
    required this.email,
    required this.profile,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        // ── Top: avatar + name ─────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(children: [
                Container(
                  width: 72, height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [Color(0xFF1DB954), Color(0xFF0A84FF)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      fullName.isNotEmpty
                          ? fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          fontSize:   28,
                          fontWeight: FontWeight.w800,
                          color:      Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color:  const Color(0xFF1DB954),
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.surface, width: 2),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const SizedBox(height: 4),
                  Text(fullName,
                      style: const TextStyle(
                          fontSize:      20,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.45)),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onEditTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF1DB954)
                                .withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              size:  13,
                              color: Color(0xFF1DB954)),
                          SizedBox(width: 4),
                          Text('Edit Profil',
                              style: TextStyle(
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600,
                                  color:      Color(0xFF1DB954))),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),

        // ── Divider ───────────────────────────────
        Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withOpacity(0.07)),

        // ── Stats row ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            _StatItem(
                label: 'Usia',
                value: profile.age != null ? '${profile.age}' : '-',
                unit:  profile.age != null ? 'tahun' : ''),
            _StatDivider(),
            _StatItem(
                label: 'Berat',
                value: profile.weightKg != null
                    ? profile.weightKg!.toStringAsFixed(1)
                    : '-',
                unit:  profile.weightKg != null ? 'kg' : ''),
            _StatDivider(),
            _StatItem(
                label: 'Tinggi',
                value: profile.heightCm != null
                    ? '${profile.heightCm!.toInt()}'
                    : '-',
                unit:  profile.heightCm != null ? 'cm' : ''),
            _StatDivider(),
            _StatItem(
                label:      'BMI',
                value:      profile.bmi != null
                    ? profile.bmi!.toStringAsFixed(1)
                    : '-',
                unit:       profile.bmi != null ? profile.bmiLabel : '',
                valueColor: profile.bmi != null
                    ? profile.bmiColor(context)
                    : null),
          ]),
        ),

        // ── Target row ────────────────────────────
        Container(
          margin:  const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        theme.colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.flag_outlined,
                size:  14,
                color: theme.colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(width: 6),
            Text('Target: ',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4))),
            Text(
              _fmt(profile.stepGoal) + ' langkah',
              style: const TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFF1DB954)),
            ),
            Text('  •  ',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.3))),
            Text(
              '${profile.calorieGoal} kkal',
              style: const TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFFFF9F0A)),
            ),
          ]),
        ),
      ]),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

class _StatItem extends StatelessWidget {
  final String label, value, unit;
  final Color? valueColor;
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      valueColor ?? theme.colorScheme.onSurface)),
        if (unit.isNotEmpty)
          Text(unit,
              style: TextStyle(
                  fontSize:   10,
                  color:      valueColor?.withOpacity(0.7) ??
                      theme.colorScheme.onSurface.withOpacity(0.4),
                  fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
      ]),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width:  1,
      height: 36,
      color:  Theme.of(context)
          .colorScheme
          .onSurface
          .withOpacity(0.08));
}

// ── Menu item ─────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color:        theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.onSurface.withOpacity(0.3)),
        onTap: onTap,
      ),
    );
  }
}

// ── Theme toggle tile ─────────────────────────────────────────
class _ThemeToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    final theme  = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: (isDark ? Colors.indigo : Colors.orange)
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: isDark ? Colors.indigo[300] : Colors.orange,
            size:  20,
          ),
        ),
        title: Text(
          isDark ? 'Mode Gelap' : 'Mode Terang',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isDark ? 'Tampilan gelap aktif' : 'Tampilan terang aktif',
          style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.4)),
        ),
        trailing: Switch(
          value:       isDark,
          activeColor: theme.colorScheme.primary,
          onChanged:   (_) =>
              ref.read(themeModeProvider.notifier).toggle(),
        ),
      ),
    );
  }
}

// ── Edit Profile Bottom Sheet ─────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final ProfileData current;
  final WidgetRef ref;
  const _EditProfileSheet({required this.current, required this.ref});

  @override
  ConsumerState<_EditProfileSheet> createState() =>
      _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _nameCtrl    = TextEditingController();
  final _ageCtrl     = TextEditingController();
  final _weightCtrl  = TextEditingController();
  final _heightCtrl  = TextEditingController();
  final _stepCtrl    = TextEditingController();
  final _calorieCtrl = TextEditingController();
  bool _isSaving     = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text    = widget.current.fullName;
    _ageCtrl.text     = widget.current.age?.toString() ?? '';
    _weightCtrl.text  = widget.current.weightKg?.toString() ?? '';
    _heightCtrl.text  = widget.current.heightCm?.toString() ?? '';
    _stepCtrl.text    = widget.current.stepGoal.toString();
    _calorieCtrl.text = widget.current.calorieGoal.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _stepCtrl.dispose();
    _calorieCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Edit Profil',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          if (_errorMsg != null)
            Container(
              margin:  const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:  Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13))),
              ]),
            ),

          _buildField(
            controller:  _nameCtrl,
            label:       'Nama Lengkap',
            icon:        Icons.person_outline,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: _buildField(
                controller:  _ageCtrl,
                label:       'Usia (tahun)',
                icon:        Icons.cake_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                controller:  _weightCtrl,
                label:       'Berat (kg)',
                icon:        Icons.monitor_weight_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          _buildField(
            controller:  _heightCtrl,
            label:       'Tinggi (cm)',
            icon:        Icons.height,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
          ),
          const SizedBox(height: 20),

          Text('TARGET HARIAN',
              style: TextStyle(
                  fontSize:      11,
                  fontWeight:    FontWeight.w700,
                  color:         theme.colorScheme.onSurface
                      .withOpacity(0.4),
                  letterSpacing: 1)),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: _buildField(
                controller:  _stepCtrl,
                label:       'Target Langkah',
                icon:        Icons.directions_walk,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                controller:  _calorieCtrl,
                label:       'Target Kalori',
                icon:        Icons.local_fire_department_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ]),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black))
                : const Text('Simpan Perubahan'),
          ),
        ]),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller:  controller,
      keyboardType: keyboardType,
      decoration:  InputDecoration(
          labelText:  label,
          prefixIcon: Icon(icon, size: 18)),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() =>
          _errorMsg = 'Nama lengkap tidak boleh kosong');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final user     = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Sesi habis, silakan login ulang');
      }

      final age     = int.tryParse(_ageCtrl.text.trim());
      final weight  = double.tryParse(_weightCtrl.text.trim());
      final height  = double.tryParse(_heightCtrl.text.trim());
      final steps   = int.tryParse(_stepCtrl.text.trim()) ?? 10000;
      final calorie = int.tryParse(_calorieCtrl.text.trim()) ?? 2000;
      final name    = _nameCtrl.text.trim();

      await supabase.from('profiles').upsert({
        'id':           user.id,
        'full_name':    name,
        'age':          age,
        'weight_kg':    weight,
        'height_cm':    height,
        'step_goal':    steps,
        'calorie_goal': calorie,
        'updated_at':   DateTime.now().toIso8601String(),
      });

      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': name}),
      );

      ref.invalidate(profileDataProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 10),
              Text('Profil berhasil diperbarui'),
            ]),
            backgroundColor: const Color(0xFF1DB954),
            duration:        const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMsg = 'Gagal menyimpan: '
            '${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }
}