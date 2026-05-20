// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/guest/providers/guest_session_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationToIndex(String location, bool isGuest) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/history'))   return 1;
    if (location.startsWith('/alerts'))    return 2;
    if (!isGuest) {
      if (location.startsWith('/family'))  return 3;
      if (location.startsWith('/profile')) return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location     = GoRouterState.of(context).matchedLocation;
    final isGuest      = ref.watch(isGuestModeProvider);
    final session      = ref.watch(guestSessionProvider);
    final theme        = Theme.of(context);
    final currentIndex = _locationToIndex(location, isGuest);

    return Scaffold(
      // Banner diletakkan sebagai bagian body Column,
      // bukan Stack — supaya tidak nabrak konten di bawahnya
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Guest banner (hanya muncul saat mode keluarga) ──
            if (isGuest)
              _GuestBanner(
                ownerName: session?.ownerName ?? 'Pemilik Gelang',
                onLeave: () => _confirmLeave(context, ref),
              ),

            // ── Konten halaman utama ─────────────────────────
            Expanded(child: child),
          ],
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
        onDestinationSelected: (i) {
          if (isGuest) {
            switch (i) {
              case 0: context.go('/dashboard'); break;
              case 1: context.go('/history');   break;
              case 2: context.go('/alerts');    break;
            }
          } else {
            switch (i) {
              case 0: context.go('/dashboard'); break;
              case 1: context.go('/history');   break;
              case 2: context.go('/alerts');    break;
              case 3: context.go('/family');    break;
              case 4: context.go('/profile');   break;
            }
          }
        },
        destinations: isGuest
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Riwayat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Alert',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Riwayat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Alert',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Keluarga',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Mode Keluarga',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Kamu akan keluar dari mode keluarga dan kembali ke halaman login.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(guestSessionProvider.notifier).leave();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Keluar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Guest banner widget ───────────────────────────────────────
class _GuestBanner extends StatelessWidget {
  final String ownerName;
  final VoidCallback onLeave;

  const _GuestBanner({
    required this.ownerName,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.12),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF1DB954).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 15,
              color: Color(0xFF1DB954),
            ),
          ),
          const SizedBox(width: 8),

          // Teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mode Pemantauan Keluarga',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1DB954),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  ownerName,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF1DB954).withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Tombol keluar
          GestureDetector(
            onTap: onLeave,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.red.withOpacity(0.25), width: 1),
              ),
              child: const Text(
                'Keluar',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}