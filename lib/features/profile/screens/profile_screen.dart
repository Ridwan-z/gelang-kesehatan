// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = user?.userMetadata?['full_name'] ?? 'Pengguna';
    final email    = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF1DB954).withOpacity(0.15),
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  color: Color(0xFF1DB954),
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
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ),
          const SizedBox(height: 32),

          // Menu items
          _MenuItem(icon: Icons.watch_outlined,      label: 'Kelola Gelang',       onTap: () {}),
          _MenuItem(icon: Icons.people_outline,       label: 'Grup Keluarga',       onTap: () {}),
          _MenuItem(icon: Icons.notifications_outlined,label: 'Notifikasi',         onTap: () {}),
          _MenuItem(icon: Icons.tune,                 label: 'Batas Alert',         onTap: () {}),
          const SizedBox(height: 16),

          // Logout
          TextButton(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.red, width: 0.5),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w600)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
