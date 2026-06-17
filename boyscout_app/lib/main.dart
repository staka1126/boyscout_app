import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase_config.dart';
import 'data/local/database_helper.dart';
import 'data/providers/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ja');

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await SupabaseConfig.initialize();
  await DatabaseHelper.instance.database;
  runApp(const ProviderScope(child: BoyScoutApp()));
}

class BoyScoutApp extends ConsumerWidget {
  const BoyScoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final troopInit = ref.watch(initTroopProvider);
    final router = ref.watch(appRouterProvider);

    // initTroopProvider の完了を待ってからルーターを起動
    // （完了前はスプラッシュを表示）
    if (troopInit.isLoading) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 完了後はルーターの redirect に任せる
    return MaterialApp.router(
      title: 'ビーバーログ',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
    );
  }
}
