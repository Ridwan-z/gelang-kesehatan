// lib/features/guest/screens/guest_join_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guest/providers/guest_session_provider.dart';

class GuestJoinScreen extends ConsumerStatefulWidget {
  /// Kalau true, ini dipanggil dari popup "kode expired" — bukan dari login
  final bool isRevalidate;
  const GuestJoinScreen({super.key, this.isRevalidate = false});

  @override
  ConsumerState<GuestJoinScreen> createState() => _GuestJoinScreenState();
}

class _GuestJoinScreenState extends ConsumerState<GuestJoinScreen> {
  final _codeCtrl   = TextEditingController();
  bool _isLoading   = false;
  String? _errorMsg;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.isRevalidate
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Icon ──────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: Color(0xFF1DB954),
                  size: 34,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                widget.isRevalidate
                    ? 'Masukkan Kode Baru'
                    : 'Lihat Kondisi Keluarga',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isRevalidate
                    ? 'Kode sebelumnya sudah tidak berlaku.\nMinta kode baru dari pemilik gelang.'
                    : 'Masukkan kode yang diberikan oleh anggota keluarga yang memakai gelang.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // ── Input kode ────────────────────────────
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXX-XXX',
                  hintStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 4,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  errorText: _errorMsg,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_outlined),
                    tooltip: 'Tempel dari clipboard',
                    onPressed: _pasteFromClipboard,
                  ),
                ),
                onChanged: (_) {
                  if (_errorMsg != null) {
                    setState(() => _errorMsg = null);
                  }
                },
              ),
              const SizedBox(height: 12),

              // ── Info kode ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kode didapat dari menu Keluarga milik pengguna gelang. '
                        'Kode bisa berubah sewaktu-waktu.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit button ─────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black),
                      )
                    : Text(widget.isRevalidate ? 'Verifikasi Kode' : 'Masuk'),
              ),

              if (!widget.isRevalidate) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Kembali ke Login',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _codeCtrl.text = data!.text!.trim().toUpperCase();
    }
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = 'Kode tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg  = null;
    });

    try {
      if (widget.isRevalidate) {
        // Validasi kode baru untuk grup yang sama
        final session = ref.read(guestSessionProvider);
        final valid = await GuestJoinService.validateCode(
            code, session?.groupId ?? '');

        if (!mounted) return;

        if (valid) {
          await ref.read(guestSessionProvider.notifier).updateCode(code);
          if (mounted) Navigator.pop(context); // tutup dialog
        } else {
          setState(() => _errorMsg = 'Kode tidak valid atau sudah kadaluarsa');
        }
      } else {
        // Join baru
        final session = await GuestJoinService.joinWithCode(code);

        if (!mounted) return;

        if (session != null) {
          await ref.read(guestSessionProvider.notifier).join(session);
          if (mounted) {
            // Router akan otomatis redirect ke guest dashboard
            Navigator.pop(context);
          }
        } else {
          setState(() => _errorMsg = 'Kode tidak valid atau sudah kadaluarsa');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Terjadi kesalahan, coba lagi');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Code Expired Dialog ───────────────────────────────────────
/// Dipanggil ketika kode expired saat guest sedang aktif
class CodeExpiredDialog extends ConsumerWidget {
  const CodeExpiredDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CodeExpiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final session = ref.watch(guestSessionProvider);

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock,
                  color: Color(0xFFFF9F0A),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kode Sudah Diperbarui',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pemilik gelang memperbarui kode akses.\n'
                'Minta kode baru untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Input kode baru langsung di dialog
              _InlineCodeInput(groupId: session?.groupId ?? ''),

              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await ref.read(guestSessionProvider.notifier).leave();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  'Keluar',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineCodeInput extends ConsumerStatefulWidget {
  final String groupId;
  const _InlineCodeInput({required this.groupId});

  @override
  ConsumerState<_InlineCodeInput> createState() =>
      _InlineCodeInputState();
}

class _InlineCodeInputState extends ConsumerState<_InlineCodeInput> {
  final _ctrl     = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            hintText: 'Masukkan kode baru',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isLoading ? null : _verify,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Text('Verifikasi'),
        ),
      ],
    );
  }

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Kode tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading = true;
      _error     = null;
    });

    final valid = await GuestJoinService.validateCode(code, widget.groupId);

    if (!mounted) return;

    if (valid) {
      await ref.read(guestSessionProvider.notifier).updateCode(code);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _isLoading = false;
        _error     = 'Kode tidak valid';
      });
    }
  }
}