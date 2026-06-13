// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/mqtt_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id', null);

  await Supabase.initialize(
    url:     AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: GelangSehatApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class GelangSehatApp extends ConsumerStatefulWidget {
  const GelangSehatApp({super.key});

  @override
  ConsumerState<GelangSehatApp> createState() => _GelangSehatAppState();
}

class _GelangSehatAppState extends ConsumerState<GelangSehatApp> {
  @override
  void initState() {
    super.initState();
    // Inisialisasi MQTT service saat app pertama kali jalan
    // Provider akan otomatis connect ke broker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mqttServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
    );
  }
}