import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import 'auth_service.dart';

/// 現在のセッション（ログイン状態）を監視するプロバイダー
/// null = 未ログイン
final authSessionProvider = StreamProvider<Session?>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange.map((e) => e.session);
});

/// ログイン済みかどうかを返す便利プロバイダー
final isSignedInProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider);
  return session.maybeWhen(
    data: (s) => s != null,
    orElse: () => false,
  );
});

/// AuthService のインスタンスプロバイダー
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});
