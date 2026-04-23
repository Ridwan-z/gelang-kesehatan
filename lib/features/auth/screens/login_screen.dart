// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../../guest/screens/guest_join_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).login(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    state.whenOrNull(
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login')) return 'Email atau password salah';
    if (raw.contains('network'))       return 'Tidak ada koneksi internet';
    return 'Terjadi kesalahan, coba lagi';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ── Logo / icon ──────────────────────────
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.monitor_heart,
                    color: Color(0xFF1DB954),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Selamat datang',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Login untuk pantau kesehatan kamu',
                  style: TextStyle(fontSize: 14,
                      color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 40),

                // ── Email ────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@'))       return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password ─────────────────────────────
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    if (v.length < 6)           return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ── Login button ─────────────────────────
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text('Masuk'),
                ),
                const SizedBox(height: 20),

                // ── Register link ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5)),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text(
                        'Daftar sekarang',
                        style: TextStyle(
                          color: Color(0xFF1DB954),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Divider ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'atau',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.1))),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Gabung keluarga ──────────────────────
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const GuestJoinScreen()),
                  ),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Lihat Kondisi Keluarga'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: Colors.white.withOpacity(0.2)),
                    foregroundColor: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}