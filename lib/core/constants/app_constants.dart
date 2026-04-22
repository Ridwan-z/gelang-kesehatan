// lib/core/constants/app_constants.dart

class AppConstants {
  // ── Supabase ──────────────────────────────────────────────
  // Ganti dengan URL dan publishable key project kamu
  static const supabaseUrl = 'https://wayffltceetbjwbwajov.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_u62dCmF7QRKDoJ-P7N52jw_PODVv_7w';

  // ── MQTT ──────────────────────────────────────────────────
  static const mqttBroker = 'broker.hivemq.com'; // ganti jika pakai broker sendiri
  static const mqttPort = 1883;

  // ── Alert thresholds (default) ────────────────────────────
  static const defaultBpmMax = 150;
  static const defaultBpmMin = 45;
  static const defaultSpo2Min = 95;

  // ── App info ──────────────────────────────────────────────
  static const appName = 'Gelang Sehat';
  static const deepLinkScheme = 'io.supabase.gelangsehat';
}
