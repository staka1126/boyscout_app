import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 初期化設定
///
/// URL と ANON KEY は --dart-define で渡してください。
///
/// 実行例:
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL が設定されていません');
    assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY が設定されていません');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static bool get isSignedIn => currentUser != null;
}
