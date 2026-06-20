import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

/// 認証・プロフィール操作をまとめたサービスクラス
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _client = SupabaseConfig.client;

  // ─────────────────────────────────────────────
  // 新規登録
  // ─────────────────────────────────────────────
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name}, // userMetadataに名前を保存
    );

    if (res.user != null) {
      try {
        await _client.from('profiles').insert({
          'id': res.user!.id,
          'name': name,
          'email': email,
        });
      } catch (e) {
        // メール確認が必要な場合はセッションがないためINSERTできないことがある
        // signIn時にupsertでフォールバック
        debugPrint('profiles insert skipped: $e');
      }
    }

    return res;
  }

  // ─────────────────────────────────────────────
  // ログイン
  // ─────────────────────────────────────────────
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // ログイン成功後、profilesが存在しない場合は作成（新規登録時にメール認証でスキップされた場合のフォールバック）
    if (res.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': res.user!.id,
          'name': res.user!.userMetadata?['name'] ?? email.split('@').first,
          'email': email,
        }, onConflict: 'id');
      } catch (e) {
        debugPrint('profiles upsert error: $e');
      }
    }
    return res;
  }

  // ─────────────────────────────────────────────
  // ログアウト
  // ─────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─────────────────────────────────────────────
  // 現在のユーザー情報
  // ─────────────────────────────────────────────
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<String?> fetchDisplayName() async {
    final user = currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();
    return data?['name'] as String?;
  }

  // ─────────────────────────────────────────────
  // 招待コード使用
  // ─────────────────────────────────────────────
  Future<String> joinWithInviteCode(String code) async {
    final user = currentUser;
    if (user == null) throw Exception('ログインが必要です');


    final invite = await _client
        .from('invite_codes')
        .select('id, troop_id, expires_at, used_by')
        .eq('code', code.toUpperCase())
        .maybeSingle();


    if (invite == null) throw Exception('招待コードが見つかりません');
    if (invite['used_by'] != null) throw Exception('この招待コードはすでに使用されています');

    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) throw Exception('招待コードの有効期限が切れています');

    final troopId = invite['troop_id'] as String;
    final inviteId = invite['id'] as String;

    // profilesが存在しない場合に備えてupsertで保証
    await _client.from('profiles').upsert({
      'id': user.id,
      'name': user.email?.split('@').first ?? 'user',
      'email': user.email,
    }, onConflict: 'id');

    await _client.from('troop_members').insert({
      'user_id': user.id,
      'troop_id': troopId,
      'role': 'member',
    });


    await _client.from('invite_codes').update({
      'used_by': user.id,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', inviteId);


    return troopId;
  }

  // ─────────────────────────────────────────────
  // 招待コード発行（管理者のみ）
  // ─────────────────────────────────────────────
  Future<String> generateInviteCode(String troopId) async {
    final user = currentUser;
    if (user == null) throw Exception('ログインが必要です');

    final code = _generateCode();

    await _client.from('invite_codes').insert({
      'code': code,
      'troop_id': troopId,
      'created_by': user.id,
      'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    });

    return code;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var seed = DateTime.now().microsecondsSinceEpoch;
    final result = StringBuffer();
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      result.write(chars[seed % chars.length]);
    }
    return result.toString();
  }
}
