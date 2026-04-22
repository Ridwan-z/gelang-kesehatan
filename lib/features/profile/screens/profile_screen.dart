// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user     = ref.watch(currentUserProvider);
    final fullName = user?.userMetadata?['full_name'] ?? 'Pengguna';
    final email    = user?.email ?? '';
    final theme    = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Center(
            child: Text(email,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
              )),
          ),
          const SizedBox(height: 32),

          _MenuItem(icon: Icons.watch_outlined,        label: 'Kelola Gelang',  onTap: () {}),
          _MenuItem(icon: Icons.people_outline,         label: 'Grup Keluarga',  onTap: () {}),
          _MenuItem(icon: Icons.notifications_outlined, label: 'Notifikasi',     onTap: () {}),
          _MenuItem(icon: Icons.tune,                   label: 'Batas Alert',    onTap: () {}),
          _ThemeToggleTile(),
          const SizedBox(height: 16),

          // Logout
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Keluar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                  content: Text(
                    'Apakah kamu yakin ingin keluar dari akun ini?',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Batal',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Keluar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authNotifierProvider.notifier).logout();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.red, width: 0.5),
              ),
            ),
            child: const Text('Keluar',
              style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.7)),
        title: Text(label),
        trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurface.withOpacity(0.3)),
        onTap: onTap,
      ),
    );
  }
}

class _ThemeToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    final theme  = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(
          isDark ? Icons.dark_mode : Icons.light_mode,
          color: isDark ? Colors.white70 : Colors.orange,
        ),
        title: Text(isDark ? 'Mode Gelap' : 'Mode Terang'),
        trailing: Switch(
          value: isDark,
          activeColor: theme.colorScheme.primary,
          onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
        ),
      ),
    );
  }
}