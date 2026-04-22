// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider((ref) => Supabase.instance.client);

// ── Current session ───────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

// ── Current user ──────────────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseProvider).auth.currentUser;
});

// ── Auth notifier (login, register, logout) ───────────────────
class AuthNotifier extends AsyncNotifier<void> {
  late SupabaseClient _supabase;

  @override
  Future<void> build() async {
    _supabase = ref.watch(supabaseProvider);
  }

 Future<void> register({
  required String email,
  required String password,
  required String fullName,
}) async {
  state = const AsyncValue.loading();
  try {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Buat profile di tabel profiles
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
      });
    }

    state = const AsyncValue.data(null);
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);