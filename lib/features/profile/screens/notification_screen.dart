// lib/features/profile/screens/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────────
class NotificationSettings {
  final bool pushEnabled;
  final bool alertHighBpm;
  final bool alertLowBpm;
  final bool alertLowSpo2;
  final bool alertInactivity;
  final TimeOfDay? quietFrom;
  final TimeOfDay? quietTo;

  const NotificationSettings({
    this.pushEnabled     = true,
    this.alertHighBpm    = true,
    this.alertLowBpm     = true,
    this.alertLowSpo2    = true,
    this.alertInactivity = true,
    this.quietFrom,
    this.quietTo,
  });

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? alertHighBpm,
    bool? alertLowBpm,
    bool? alertLowSpo2,
    bool? alertInactivity,
    TimeOfDay? quietFrom,
    TimeOfDay? quietTo,
    bool clearQuietFrom = false,
    bool clearQuietTo   = false,
  }) =>
      NotificationSettings(
        pushEnabled:     pushEnabled     ?? this.pushEnabled,
        alertHighBpm:    alertHighBpm    ?? this.alertHighBpm,
        alertLowBpm:     alertLowBpm     ?? this.alertLowBpm,
        alertLowSpo2:    alertLowSpo2    ?? this.alertLowSpo2,
        alertInactivity: alertInactivity ?? this.alertInactivity,
        quietFrom: clearQuietFrom ? null : (quietFrom ?? this.quietFrom),
        quietTo:   clearQuietTo  ? null : (quietTo   ?? this.quietTo),
      );
}

// ── Provider ──────────────────────────────────────────────────
final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        NotificationSettingsNotifier.new);

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final supabase = ref.watch(supabaseProvider);
    final user     = supabase.auth.currentUser;
    if (user == null) return const NotificationSettings();

    final res = await supabase
        .from('notification_settings')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (res == null) return const NotificationSettings();

    TimeOfDay? parseTime(dynamic val) {
      if (val == null) return null;
      final parts = (val as String).split(':');
      if (parts.length < 2) return null;
      return TimeOfDay(
          hour:   int.parse(parts[0]),
          minute: int.parse(parts[1]));
    }

    return NotificationSettings(
      pushEnabled:     res['push_enabled']     as bool? ?? true,
      alertHighBpm:    res['alert_high_bpm']   as bool? ?? true,
      alertLowBpm:     res['alert_low_bpm']    as bool? ?? true,
      alertLowSpo2:    res['alert_low_spo2']   as bool? ?? true,
      alertInactivity: res['alert_inactivity'] as bool? ?? true,
      quietFrom:       parseTime(res['quiet_from']),
      quietTo:         parseTime(res['quiet_to']),
    );
  }

  Future<void> save(NotificationSettings s) async {
    // Optimistic update — UI langsung berubah tanpa tunggu DB
    state = AsyncValue.data(s);

    final supabase = ref.read(supabaseProvider);
    final user     = supabase.auth.currentUser;
    if (user == null) return;

    String? fmt(TimeOfDay? t) => t == null
        ? null
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    await supabase.from('notification_settings').upsert({
      'user_id':          user.id,
      'push_enabled':     s.pushEnabled,
      'alert_high_bpm':   s.alertHighBpm,
      'alert_low_bpm':    s.alertLowBpm,
      'alert_low_spo2':   s.alertLowSpo2,
      'alert_inactivity': s.alertInactivity,
      'quiet_from':       fmt(s.quietFrom),
      'quiet_to':         fmt(s.quietTo),
      'updated_at':       DateTime.now().toIso8601String(),
    });
  }
}

// ── Screen ────────────────────────────────────────────────────
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Gagal memuat: $e')),
        data:    (s) => _Body(settings: s),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────
class _Body extends ConsumerWidget {
  final NotificationSettings settings;
  const _Body({required this.settings});

  void _upd(WidgetRef ref, NotificationSettings s) =>
      ref.read(notificationSettingsProvider.notifier).save(s);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [

        // ── Master toggle ─────────────────────────────
        _Label('PENGATURAN UMUM'),
        const SizedBox(height: 8),
        _MasterCard(
          value:     settings.pushEnabled,
          onChanged: (v) => _upd(ref, settings.copyWith(pushEnabled: v)),
        ),
        const SizedBox(height: 20),

        // ── Per-jenis alert ───────────────────────────
        _Label('JENIS PERINGATAN'),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity:  settings.pushEnabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: AbsorbPointer(
            absorbing: !settings.pushEnabled,
            child: Container(
              decoration: BoxDecoration(
                color:        theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                _AlertRow(
                  icon:      Icons.favorite,
                  color:     const Color(0xFFFF3B30),
                  title:     'BPM Terlalu Tinggi',
                  subtitle:  'Notif saat detak jantung melampaui batas atas',
                  tag:       'high_bpm',
                  value:     settings.alertHighBpm,
                  onChanged: (v) => _upd(ref, settings.copyWith(alertHighBpm: v)),
                  isLast:    false,
                ),
                _AlertRow(
                  icon:      Icons.favorite_border,
                  color:     const Color(0xFFFF9F0A),
                  title:     'BPM Terlalu Rendah',
                  subtitle:  'Notif saat detak jantung di bawah batas bawah',
                  tag:       'low_bpm',
                  value:     settings.alertLowBpm,
                  onChanged: (v) => _upd(ref, settings.copyWith(alertLowBpm: v)),
                  isLast:    false,
                ),
                _AlertRow(
                  icon:      Icons.air,
                  color:     const Color(0xFF0A84FF),
                  title:     'SpO2 Rendah',
                  subtitle:  'Notif saat saturasi oksigen di bawah batas',
                  tag:       'low_spo2',
                  value:     settings.alertLowSpo2,
                  onChanged: (v) => _upd(ref, settings.copyWith(alertLowSpo2: v)),
                  isLast:    false,
                ),
                _AlertRow(
                  icon:      Icons.directions_walk,
                  color:     const Color(0xFF1DB954),
                  title:     'Tidak Aktif',
                  subtitle:  'Notif saat tidak ada gerakan terlalu lama',
                  tag:       'inactivity',
                  value:     settings.alertInactivity,
                  onChanged: (v) => _upd(ref, settings.copyWith(alertInactivity: v)),
                  isLast:    true,
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Quiet hours ───────────────────────────────
        _Label('JAM TENANG'),
        const SizedBox(height: 4),
        Text(
          'Notifikasi tidak akan muncul selama rentang jam ini',
          style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.45)),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          opacity:  settings.pushEnabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: AbsorbPointer(
            absorbing: !settings.pushEnabled,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                // Status + reset
                Row(children: [
                  _QuietChip(settings: settings),
                  const Spacer(),
                  if (settings.quietFrom != null || settings.quietTo != null)
                    GestureDetector(
                      onTap: () => _upd(ref,
                          settings.copyWith(
                              clearQuietFrom: true, clearQuietTo: true)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:        Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Reset',
                            style: TextStyle(
                                fontSize: 12,
                                color:      Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),

                // Time pickers
                Row(children: [
                  Expanded(
                    child: _TimePick(
                      label:       'Mulai',
                      icon:        Icons.bedtime_outlined,
                      time:        settings.quietFrom,
                      activeColor: const Color(0xFF6B5BCD),
                      onPick:      (t) => _upd(ref, settings.copyWith(quietFrom: t)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(children: [
                      Icon(Icons.arrow_forward,
                          size:  14,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 2),
                      Text('s/d',
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withOpacity(0.35))),
                    ]),
                  ),
                  Expanded(
                    child: _TimePick(
                      label:       'Selesai',
                      icon:        Icons.wb_sunny_outlined,
                      time:        settings.quietTo,
                      activeColor: const Color(0xFFFF9F0A),
                      onPick:      (t) => _upd(ref, settings.copyWith(quietTo: t)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Info ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        theme.colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size:  15,
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Perubahan disimpan otomatis. Pengaturan buzzer fisik pada gelang ada di menu Kelola Gelang.',
                  style: TextStyle(
                      fontSize: 12,
                      height:   1.5,
                      color:    theme.colorScheme.onSurface.withOpacity(0.45)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize:    11,
          fontWeight:  FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)));
}

class _MasterCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MasterCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: value
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface)
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            value
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: value
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.4),
            size: 20,
          ),
        ),
        title: const Text('Aktifkan Notifikasi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          value ? 'Semua peringatan aktif' : 'Semua peringatan dimatikan',
          style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.45)),
        ),
        trailing: Switch(
            value: value,
            activeColor: theme.colorScheme.primary,
            onChanged: onChanged),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, tag;
  final bool value, isLast;
  final ValueChanged<bool> onChanged;

  const _AlertRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.value,
    required this.isLast,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Flexible(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tag,
                      style: TextStyle(
                          fontSize:   9,
                          fontWeight: FontWeight.w700,
                          color:      color)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.45))),
            ]),
          ),
          Switch(
              value:       value,
              activeColor: theme.colorScheme.primary,
              onChanged:   onChanged),
        ]),
      ),
      if (!isLast)
        Divider(
            height: 1,
            indent: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.07)),
    ]);
  }
}

class _QuietChip extends StatelessWidget {
  final NotificationSettings settings;
  const _QuietChip({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isActive = settings.quietFrom != null && settings.quietTo != null;
    final color    = isActive ? const Color(0xFF6B5BCD) : Colors.grey;
    final label    = isActive
        ? 'Aktif ${_f(settings.quietFrom!)} – ${_f(settings.quietTo!)}'
        : 'Belum diatur';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.do_not_disturb_on_outlined, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      color)),
      ]),
    );
  }

  String _f(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimePick extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay? time;
  final Color activeColor;
  final ValueChanged<TimeOfDay> onPick;

  const _TimePick({
    required this.label,
    required this.icon,
    required this.time,
    required this.activeColor,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = time != null;
    final h     = time?.hour.toString().padLeft(2, '0') ?? '--';
    final m     = time?.minute.toString().padLeft(2, '0') ?? '--';

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSet
              ? activeColor.withOpacity(0.08)
              : theme.colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet
                ? activeColor.withOpacity(0.3)
                : theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        child: Column(children: [
          Icon(icon,
              size:  18,
              color: isSet
                  ? activeColor
                  : theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 6),
          Text('$h:$m',
              style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                  color: isSet
                      ? activeColor
                      : theme.colorScheme.onSurface.withOpacity(0.3))),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.4))),
        ]),
      ),
    );
  }
}