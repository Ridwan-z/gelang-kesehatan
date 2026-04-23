// lib/features/profile/screens/device_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Model ─────────────────────────────────────────────────────
class DeviceDetail {
  final String id;
  final String deviceUid;
  final String name;
  final bool isOnline;
  final int batteryPct;
  final String? firmwareVersion;
  final DateTime? lastSeenAt;
  // Config
  final int bpmMax;
  final int bpmMin;
  final int spo2Min;
  final bool buzzerLocal;
  // Latest data
  final int? latestBpm;
  final int? latestSpo2;
  // Share
  final bool isSharedToFamily;

  const DeviceDetail({
    required this.id,
    required this.deviceUid,
    required this.name,
    required this.isOnline,
    required this.batteryPct,
    this.firmwareVersion,
    this.lastSeenAt,
    required this.bpmMax,
    required this.bpmMin,
    required this.spo2Min,
    required this.buzzerLocal,
    this.latestBpm,
    this.latestSpo2,
    required this.isSharedToFamily,
  });

  DeviceDetail copyWith({
    String? name,
    int? bpmMax,
    int? bpmMin,
    int? spo2Min,
    bool? buzzerLocal,
    bool? isSharedToFamily,
  }) =>
      DeviceDetail(
        id: id,
        deviceUid: deviceUid,
        name: name ?? this.name,
        isOnline: isOnline,
        batteryPct: batteryPct,
        firmwareVersion: firmwareVersion,
        lastSeenAt: lastSeenAt,
        bpmMax: bpmMax ?? this.bpmMax,
        bpmMin: bpmMin ?? this.bpmMin,
        spo2Min: spo2Min ?? this.spo2Min,
        buzzerLocal: buzzerLocal ?? this.buzzerLocal,
        latestBpm: latestBpm,
        latestSpo2: latestSpo2,
        isSharedToFamily: isSharedToFamily ?? this.isSharedToFamily,
      );
}

// ── Provider ──────────────────────────────────────────────────
class DeviceNotifier extends Notifier<AsyncValue<List<DeviceDetail>>> {
  @override
  AsyncValue<List<DeviceDetail>> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 600));
    state = AsyncValue.data([
      DeviceDetail(
        id: 'dummy-device-1',
        deviceUid: 'GELANG-001',
        name: 'Gelangku',
        isOnline: true,
        batteryPct: 78,
        firmwareVersion: 'v1.0.2',
        lastSeenAt: DateTime.now(),
        bpmMax: 150,
        bpmMin: 45,
        spo2Min: 95,
        buzzerLocal: true,
        latestBpm: 76,
        latestSpo2: 98,
        isSharedToFamily: false,
      ),
    ]);
  }

  Future<void> addDevice(String uid, String name) async {
    final current = state.asData?.value ?? [];
    // Cek duplikat
    if (current.any((d) => d.deviceUid == uid)) {
      throw Exception('Device UID sudah terdaftar');
    }
    final newDevice = DeviceDetail(
      id: 'dummy-${DateTime.now().millisecondsSinceEpoch}',
      deviceUid: uid,
      name: name,
      isOnline: false,
      batteryPct: 0,
      bpmMax: 150,
      bpmMin: 45,
      spo2Min: 95,
      buzzerLocal: true,
      isSharedToFamily: false,
    );
    state = AsyncValue.data([...current, newDevice]);
  }

  Future<void> updateDevice(String id, {
    String? name,
    int? bpmMax,
    int? bpmMin,
    int? spo2Min,
    bool? buzzerLocal,
    bool? isSharedToFamily,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final current = state.asData?.value ?? [];
    state = AsyncValue.data(current.map((d) {
      if (d.id != id) return d;
      return d.copyWith(
        name: name,
        bpmMax: bpmMax,
        bpmMin: bpmMin,
        spo2Min: spo2Min,
        buzzerLocal: buzzerLocal,
        isSharedToFamily: isSharedToFamily,
      );
    }).toList());
  }

  Future<void> deleteDevice(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = state.asData?.value ?? [];
    state = AsyncValue.data(current.where((d) => d.id != id).toList());
  }
}

final deviceNotifierProvider =
    NotifierProvider<DeviceNotifier, AsyncValue<List<DeviceDetail>>>(
        DeviceNotifier.new);

// ── Screen ────────────────────────────────────────────────────
class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme       = Theme.of(context);
    final devicesAsync = ref.watch(deviceNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Gelang'),
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (devices) => devices.isEmpty
            ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...devices.map((d) => _DeviceCard(
                        device: d,
                        onEdit: () => _showEditSheet(context, ref, d),
                        onDelete: () => _confirmDelete(context, ref, d),
                      )),
                  const SizedBox(height: 8),
                  // Tombol tambah lagi (jika sudah ada device)
                  OutlinedButton.icon(
                    onPressed: () => _showAddSheet(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Daftarkan Gelang Lain'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDeviceSheet(ref: ref),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, DeviceDetail device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDeviceSheet(device: device, ref: ref),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, DeviceDetail device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Gelang',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Hapus "${device.name}"? Semua data yang terkait akan tetap tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(deviceNotifierProvider.notifier)
                  .deleteDevice(device.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gelang dihapus')));
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Device card ───────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  final DeviceDetail device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeviceCard({
    required this.device,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: device.isOnline
            ? Border.all(
                color: const Color(0xFF1DB954).withOpacity(0.3),
                width: 1)
            : null,
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon gelang
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: device.isOnline
                        ? const Color(0xFF1DB954).withOpacity(0.1)
                        : theme.colorScheme.onSurface.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.watch,
                    size: 26,
                    color: device.isOnline
                        ? const Color(0xFF1DB954)
                        : theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'UID: ${device.deviceUid}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4),
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (device.firmwareVersion != null)
                        Text(
                          'Firmware ${device.firmwareVersion}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.35),
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Hapus',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Status bar ──────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Online status
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: device.isOnline
                        ? const Color(0xFF1DB954)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  device.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: device.isOnline
                        ? const Color(0xFF1DB954)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                // Baterai
                Icon(
                  _batteryIcon(device.batteryPct),
                  size: 14,
                  color: _batteryColor(device.batteryPct),
                ),
                const SizedBox(width: 4),
                Text(
                  '${device.batteryPct}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _batteryColor(device.batteryPct),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Latest BPM & SpO2
                if (device.latestBpm != null) ...[
                  Icon(Icons.favorite,
                      size: 12, color: const Color(0xFFFF3B30)),
                  const SizedBox(width: 3),
                  Text(
                    '${device.latestBpm} BPM',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                ],
                if (device.latestSpo2 != null) ...[
                  Icon(Icons.air,
                      size: 12, color: const Color(0xFF0A84FF)),
                  const SizedBox(width: 3),
                  Text(
                    '${device.latestSpo2}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // ── Config chips ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ConfigChip(
                  label: 'BPM ${device.bpmMin}–${device.bpmMax}',
                  icon: Icons.favorite_outline,
                  color: const Color(0xFFFF3B30),
                ),
                _ConfigChip(
                  label: 'SpO2 ≥${device.spo2Min}%',
                  icon: Icons.air,
                  color: const Color(0xFF0A84FF),
                ),
                if (device.buzzerLocal)
                  _ConfigChip(
                    label: 'Buzzer ON',
                    icon: Icons.vibration,
                    color: const Color(0xFFFF9F0A),
                  ),
                if (device.isSharedToFamily)
                  _ConfigChip(
                    label: 'Dishare ke Keluarga',
                    icon: Icons.people_outline,
                    color: const Color(0xFF1DB954),
                  ),
              ],
            ),
          ),

          // ── Edit button ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Atur Gelang'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _batteryIcon(int pct) {
    if (pct >= 80) return Icons.battery_full;
    if (pct >= 50) return Icons.battery_4_bar;
    if (pct >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _batteryColor(int pct) {
    if (pct >= 50) return const Color(0xFF1DB954);
    if (pct >= 20) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF3B30);
  }
}

class _ConfigChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _ConfigChip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Add device sheet ──────────────────────────────────────────
class _AddDeviceSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddDeviceSheet({required this.ref});

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _uidCtrl  = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _uidCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Daftarkan Gelang',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Masukkan kode unik yang tertera pada gelang',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _uidCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Device UID',
                hintText: 'Contoh: GELANG-001',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Gelang',
                hintText: 'Contoh: Gelangku',
                prefixIcon: Icon(Icons.watch_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black))
                  : const Text('Daftarkan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_uidCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UID dan nama wajib diisi')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await widget.ref
          .read(deviceNotifierProvider.notifier)
          .addDevice(_uidCtrl.text.trim(), _nameCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 10),
              Text('Gelang berhasil didaftarkan!'),
            ]),
            backgroundColor: Color(0xFF1DB954),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Edit device sheet ─────────────────────────────────────────
class _EditDeviceSheet extends StatefulWidget {
  final DeviceDetail device;
  final WidgetRef ref;
  const _EditDeviceSheet(
      {required this.device, required this.ref});

  @override
  State<_EditDeviceSheet> createState() => _EditDeviceSheetState();
}

class _EditDeviceSheetState extends State<_EditDeviceSheet> {
  final _nameCtrl = TextEditingController();
  late int _bpmMax;
  late int _bpmMin;
  late int _spo2Min;
  late bool _buzzerLocal;
  late bool _isShared;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.device.name;
    _bpmMax      = widget.device.bpmMax;
    _bpmMin      = widget.device.bpmMin;
    _spo2Min     = widget.device.spo2Min;
    _buzzerLocal = widget.device.buzzerLocal;
    _isShared    = widget.device.isSharedToFamily;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Atur ${widget.device.name}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Nama
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Gelang',
                prefixIcon: Icon(Icons.watch_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // ── Threshold section ──────────────────
            _sectionLabel('BATAS ALERT'),
            const SizedBox(height: 12),

            // BPM Max
            _SliderRow(
              label: 'BPM Maksimum',
              value: _bpmMax.toDouble(),
              min: 100,
              max: 200,
              divisions: 20,
              color: const Color(0xFFFF3B30),
              displayValue: '$_bpmMax BPM',
              onChanged: (v) => setState(() => _bpmMax = v.toInt()),
            ),
            const SizedBox(height: 12),

            // BPM Min
            _SliderRow(
              label: 'BPM Minimum',
              value: _bpmMin.toDouble(),
              min: 30,
              max: 60,
              divisions: 15,
              color: const Color(0xFFFF9F0A),
              displayValue: '$_bpmMin BPM',
              onChanged: (v) => setState(() => _bpmMin = v.toInt()),
            ),
            const SizedBox(height: 12),

            // SpO2 Min
            _SliderRow(
              label: 'SpO2 Minimum',
              value: _spo2Min.toDouble(),
              min: 85,
              max: 98,
              divisions: 13,
              color: const Color(0xFF0A84FF),
              displayValue: '$_spo2Min%',
              onChanged: (v) => setState(() => _spo2Min = v.toInt()),
            ),
            const SizedBox(height: 20),

            // ── Toggle section ─────────────────────
            _sectionLabel('PENGATURAN'),
            const SizedBox(height: 8),

            _ToggleRow(
              icon: Icons.vibration,
              label: 'Buzzer di Gelang',
              subtitle: 'Gelang bergetar saat kondisi darurat',
              value: _buzzerLocal,
              onChanged: (v) => setState(() => _buzzerLocal = v),
            ),
            _ToggleRow(
              icon: Icons.people_outline,
              label: 'Bagikan ke Keluarga',
              subtitle: 'Anggota keluarga bisa monitor kondisi kamu',
              value: _isShared,
              onChanged: (v) => setState(() => _isShared = v),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
      );

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await widget.ref
        .read(deviceNotifierProvider.notifier)
        .updateDevice(
          widget.device.id,
          name: _nameCtrl.text.trim(),
          bpmMax: _bpmMax,
          bpmMin: _bpmMin,
          spo2Min: _spo2Min,
          buzzerLocal: _buzzerLocal,
          isSharedToFamily: _isShared,
        );
    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.black),
            SizedBox(width: 10),
            Text('Pengaturan gelang disimpan'),
          ]),
          backgroundColor: Color(0xFF1DB954),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ── Slider row ────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label, displayValue;
  final double value, min, max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(displayValue,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
              inactiveTrackColor: color.withOpacity(0.15),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            size: 22),
        title: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.4))),
        trailing: Switch(
          value: value,
          activeColor: const Color(0xFF1DB954),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.watch_outlined,
                  size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('Belum ada gelang',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Daftarkan gelang untuk mulai memantau kesehatan',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                      theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Daftarkan Gelang'),
            ),
          ],
        ),
      ),
    );
  }
}