// lib/features/profile/screens/alert_threshold_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

// ── Model ─────────────────────────────────────────────────────
class AlertThreshold {
  final int bpmMax;
  final int bpmMin;
  final int spo2Min;
  final bool buzzerLocal;

  const AlertThreshold({
    this.bpmMax      = 150,
    this.bpmMin      = 45,
    this.spo2Min     = 95,
    this.buzzerLocal = true,
  });

  AlertThreshold copyWith({
    int?  bpmMax,
    int?  bpmMin,
    int?  spo2Min,
    bool? buzzerLocal,
  }) =>
      AlertThreshold(
        bpmMax:      bpmMax      ?? this.bpmMax,
        bpmMin:      bpmMin      ?? this.bpmMin,
        spo2Min:     spo2Min     ?? this.spo2Min,
        buzzerLocal: buzzerLocal ?? this.buzzerLocal,
      );
}

// ── Provider ──────────────────────────────────────────────────
final alertThresholdProvider =
    AsyncNotifierProvider<AlertThresholdNotifier, AlertThreshold>(
        AlertThresholdNotifier.new);

class AlertThresholdNotifier extends AsyncNotifier<AlertThreshold> {
  @override
  Future<AlertThreshold> build() async {
    final supabase = ref.watch(supabaseProvider);
    final user     = supabase.auth.currentUser;
    if (user == null) return const AlertThreshold();

    final devices = await supabase
        .from('devices')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1);

    if ((devices as List).isEmpty) return const AlertThreshold();
    final deviceId = devices.first['id'] as String;

    final cfg = await supabase
        .from('device_configs')
        .select('bpm_max, bpm_min, spo2_min, buzzer_local')
        .eq('device_id', deviceId)
        .maybeSingle();

    if (cfg == null) return const AlertThreshold();

    return AlertThreshold(
      bpmMax:      cfg['bpm_max']     as int?  ?? 150,
      bpmMin:      cfg['bpm_min']     as int?  ?? 45,
      spo2Min:     cfg['spo2_min']    as int?  ?? 95,
      buzzerLocal: cfg['buzzer_local'] as bool? ?? true,
    );
  }

  Future<void> save(AlertThreshold t) async {
    state = AsyncValue.data(t);

    final supabase = ref.read(supabaseProvider);
    final user     = supabase.auth.currentUser;
    if (user == null) return;

    final devices = await supabase
        .from('devices')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1);

    if ((devices as List).isEmpty) return;
    final deviceId = devices.first['id'] as String;

    await supabase.from('device_configs').upsert({
      'device_id':    deviceId,
      'bpm_max':      t.bpmMax,
      'bpm_min':      t.bpmMin,
      'spo2_min':     t.spo2Min,
      'buzzer_local': t.buzzerLocal,
      'updated_at':   DateTime.now().toIso8601String(),
    });
  }
}

// ── Screen ────────────────────────────────────────────────────
class AlertThresholdScreen extends ConsumerWidget {
  const AlertThresholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertThresholdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Batas Alert')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Gagal memuat: $e')),
        data:    (t) => _Body(saved: t),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────
class _Body extends ConsumerStatefulWidget {
  final AlertThreshold saved;
  const _Body({required this.saved});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late int  _bpmMax;
  late int  _bpmMin;
  late int  _spo2Min;
  late bool _buzzer;
  bool      _saving = false;

  @override
  void initState() {
    super.initState();
    _bpmMax  = widget.saved.bpmMax;
    _bpmMin  = widget.saved.bpmMin;
    _spo2Min = widget.saved.spo2Min;
    _buzzer  = widget.saved.buzzerLocal;
  }

  bool get _changed =>
      _bpmMax  != widget.saved.bpmMax  ||
      _bpmMin  != widget.saved.bpmMin  ||
      _spo2Min != widget.saved.spo2Min ||
      _buzzer  != widget.saved.buzzerLocal;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(alertThresholdProvider.notifier).save(AlertThreshold(
      bpmMax:      _bpmMax,
      bpmMin:      _bpmMin,
      spo2Min:     _spo2Min,
      buzzerLocal: _buzzer,
    ));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.black),
          SizedBox(width: 10),
          Text('Batas alert berhasil disimpan'),
        ]),
        backgroundColor: const Color(0xFF1DB954),
        duration:        const Duration(seconds: 2),
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final latestHR = ref.watch(latestHeartRateProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [

        // ── Preview kondisi saat ini ──────────────────
        _PreviewCard(
          bpmMax:   _bpmMax,
          bpmMin:   _bpmMin,
          spo2Min:  _spo2Min,
          latestHR: latestHR,
        ),
        const SizedBox(height: 20),

        // ── BPM Max ───────────────────────────────────
        _Label('BATAS ATAS DETAK JANTUNG'),
        const SizedBox(height: 8),
        _SliderCard(
          icon:        Icons.arrow_upward,
          iconColor:   const Color(0xFFFF3B30),
          title:       'BPM Maksimum',
          subtitle:    'Alert saat BPM melebihi nilai ini',
          value:       _bpmMax.toDouble(),
          min:         100,
          max:         200,
          divisions:   20,
          unit:        'BPM',
          color:       const Color(0xFFFF3B30),
          statusLabel: _bpmMax >= 180 ? 'Sangat tinggi'
              : _bpmMax >= 160 ? 'Tinggi' : 'Aman',
          statusColor: _bpmMax >= 180
              ? const Color(0xFFFF3B30)
              : _bpmMax >= 160
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFF1DB954),
          onChanged: (v) => setState(() => _bpmMax = v.toInt()),
        ),
        const SizedBox(height: 16),

        // ── BPM Min ───────────────────────────────────
        _Label('BATAS BAWAH DETAK JANTUNG'),
        const SizedBox(height: 8),
        _SliderCard(
          icon:        Icons.arrow_downward,
          iconColor:   const Color(0xFFFF9F0A),
          title:       'BPM Minimum',
          subtitle:    'Alert saat BPM di bawah nilai ini',
          value:       _bpmMin.toDouble(),
          min:         30,
          max:         60,
          divisions:   15,
          unit:        'BPM',
          color:       const Color(0xFFFF9F0A),
          statusLabel: _bpmMin <= 35 ? 'Sangat rendah'
              : _bpmMin <= 45 ? 'Rendah' : 'Aman',
          statusColor: _bpmMin <= 35
              ? const Color(0xFFFF3B30)
              : _bpmMin <= 45
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFF1DB954),
          onChanged: (v) => setState(() => _bpmMin = v.toInt()),
        ),
        const SizedBox(height: 16),

        // ── SpO2 Min ──────────────────────────────────
        _Label('BATAS BAWAH SATURASI OKSIGEN'),
        const SizedBox(height: 8),
        _SliderCard(
          icon:        Icons.air,
          iconColor:   const Color(0xFF0A84FF),
          title:       'SpO2 Minimum',
          subtitle:    'Alert saat SpO2 di bawah nilai ini',
          value:       _spo2Min.toDouble(),
          min:         85,
          max:         98,
          divisions:   13,
          unit:        '%',
          color:       const Color(0xFF0A84FF),
          statusLabel: _spo2Min <= 88 ? 'Sangat rendah'
              : _spo2Min <= 93 ? 'Rendah' : 'Aman',
          statusColor: _spo2Min <= 88
              ? const Color(0xFFFF3B30)
              : _spo2Min <= 93
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFF1DB954),
          onChanged: (v) => setState(() => _spo2Min = v.toInt()),
        ),
        const SizedBox(height: 20),

        // ── Buzzer toggle ─────────────────────────────
        _Label('BUZZER GELANG'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color:        theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (_buzzer
                        ? const Color(0xFFFF9F0A)
                        : theme.colorScheme.onSurface)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.vibration,
                  color: _buzzer
                      ? const Color(0xFFFF9F0A)
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                  size: 20),
            ),
            title: const Text('Buzzer Aktif',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _buzzer
                  ? 'Gelang berbunyi saat kondisi darurat'
                  : 'Gelang tidak berbunyi (hanya notif HP)',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.45)),
            ),
            trailing: Switch(
                value:       _buzzer,
                activeColor: const Color(0xFFFF9F0A),
                onChanged:   (v) => setState(() => _buzzer = v)),
          ),
        ),
        const SizedBox(height: 28),

        // ── Tombol simpan ─────────────────────────────
        ElevatedButton(
          onPressed: (_changed && !_saving) ? _save : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black))
              : Text(
                  _changed ? 'Simpan Perubahan' : 'Tidak Ada Perubahan',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
        ),

        if (_changed) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _bpmMax  = widget.saved.bpmMax;
              _bpmMin  = widget.saved.bpmMin;
              _spo2Min = widget.saved.spo2Min;
              _buzzer  = widget.saved.buzzerLocal;
            }),
            child: Text('Reset ke Nilai Tersimpan',
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.4))),
          ),
        ],
      ],
    );
  }
}

// ── Preview card ──────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final int bpmMax, bpmMin, spo2Min;
  final AsyncValue<HeartRateData?> latestHR;
  const _PreviewCard({
    required this.bpmMax,
    required this.bpmMin,
    required this.spo2Min,
    required this.latestHR,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return latestHR.when(
      loading: () => const SizedBox(),
      error:   (_, __) => const SizedBox(),
      data: (hr) {
        if (hr == null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.watch_off_outlined,
                  size:  16,
                  color: theme.colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(width: 10),
              Text('Gelang belum terhubung — preview tidak tersedia',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.4))),
            ]),
          );
        }

        final bpmOk  = hr.bpm >= bpmMin && hr.bpm <= bpmMax;
        final spo2Ok = hr.spo2 >= spo2Min;
        final allOk  = bpmOk && spo2Ok;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: allOk
                ? const Color(0xFF1DB954).withOpacity(0.08)
                : const Color(0xFFFF3B30).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: allOk
                  ? const Color(0xFF1DB954).withOpacity(0.25)
                  : const Color(0xFFFF3B30).withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Status baris atas
            Row(children: [
              Icon(
                allOk
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                size:  15,
                color: allOk
                    ? const Color(0xFF1DB954)
                    : const Color(0xFFFF3B30),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  allOk
                      ? 'Kondisi saat ini NORMAL dengan batas ini'
                      : 'Kondisi saat ini MELAMPAUI batas yang diset',
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color: allOk
                          ? const Color(0xFF1DB954)
                          : const Color(0xFFFF3B30)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Metric row
            Row(children: [
              _PreviewMetric(
                label:  'BPM Sekarang',
                value:  '${hr.bpm}',
                range:  '$bpmMin – $bpmMax BPM',
                isOk:   bpmOk,
                isWarn: !bpmOk &&
                    (hr.bpm > bpmMax - 10 || hr.bpm < bpmMin + 5),
              ),
              const SizedBox(width: 10),
              _PreviewMetric(
                label:  'SpO2 Sekarang',
                value:  '${hr.spo2}%',
                range:  '≥ $spo2Min%',
                isOk:   spo2Ok,
                isWarn: !spo2Ok && hr.spo2 >= spo2Min - 2,
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label, value, range;
  final bool isOk, isWarn;
  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.range,
    required this.isOk,
    required this.isWarn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOk
        ? const Color(0xFF1DB954)
        : isWarn
            ? const Color(0xFFFF9F0A)
            : const Color(0xFFFF3B30);
    final icon = isOk
        ? Icons.check_circle_outline
        : isWarn
            ? Icons.warning_amber_outlined
            : Icons.error_outline;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 4),
          Row(children: [
            Text(value,
                style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                    color:      color)),
            const Spacer(),
            Icon(icon, color: color, size: 16),
          ]),
          Text('Batas: $range',
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.45))),
        ]),
      ),
    );
  }
}

// ── Slider card ───────────────────────────────────────────────
class _SliderCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, color;
  final String title, subtitle, unit, statusLabel;
  final Color statusColor;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    required this.icon,
    required this.iconColor,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.statusLabel,
    required this.statusColor,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.45))),
            ]),
          ),
          // Nilai + status
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${value.toInt()} $unit',
                  style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w800,
                      color:      color)),
            ),
            const SizedBox(height: 2),
            Text(statusLabel,
                style: TextStyle(
                    fontSize:   10,
                    fontWeight: FontWeight.w600,
                    color:      statusColor)),
          ]),
        ]),
        const SizedBox(height: 4),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   color,
            thumbColor:         color,
            overlayColor:       color.withOpacity(0.15),
            inactiveTrackColor: color.withOpacity(0.15),
            trackHeight:        3,
          ),
          child: Slider(
            value:     value,
            min:       min,
            max:       max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),

        // Min/max label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Text('${min.toInt()} $unit',
                style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.35))),
            Text('${max.toInt()} $unit',
                style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.35))),
          ]),
        ),
      ]),
    );
  }
}

// ── Label section ─────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize:     11,
          fontWeight:   FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)));
}