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
    final location  = GoRouterState.of(context).matchedLocation;
    final isGuest   = ref.watch(isGuestModeProvider);
    final session   = ref.watch(guestSessionProvider);
    final theme     = Theme.of(context);

    final currentIndex = _locationToIndex(location, isGuest);

    return Scaffold(
      body: Stack(
        children: [
          child,
          // ── Guest banner ───────────────────────────
          if (isGuest)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1DB954).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 15, color: Color(0xFF1DB954)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode Keluarga — ${session?.ownerName ?? 'Pemilik Gelang'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1DB954),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _confirmLeave(context, ref),
                        child: Text(
                          'Keluar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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