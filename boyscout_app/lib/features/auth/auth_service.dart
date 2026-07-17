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
      data: {'name': name},
    );

    if (res.user != null) {
      try {
        await _client.from('profiles').insert({
          'id': res.user!.id,
          'name': name,
          'email': email,
        });
      } catch (e) {
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
    if (res.user != null) {
      try {
        final existing = await _client
            .from('profiles')
            .select('name')
            .eq('id', res.user!.id)
            .maybeSingle();

        if (existing == null) {
          // プロフィール未作成の場合のみ、メタデータ名 or メールの@左側で補完
          await _client.from('profiles').upsert({
            'id': res.user!.id,
            'name': res.user!.userMetadata?['name'] ?? email.split('@').first,
            'email': email,
          }, onConflict: 'id');
        } else {
          // 既存の登録名は上書きしない。emailのみ最新化
          await _client
              .from('profiles')
              .update({'email': email}).eq('id', res.user!.id);
        }
      } catch (e) {
        debugPrint('profiles upsert error: $e');
      }
    }
    return res;
  }

  // ─────────────────────────────────────────────
  // パスワードリセットメール送信
  // ─────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://staka1126.github.io/boyscout_app/reset-password.html',
    );
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

  // ──────────────────────────────────────
  // 表示名の編集
  // ──────────────────────────────────────
  Future<void> updateDisplayName(String name) async {
    final user = currentUser;
    if (user == null) throw Exception('ログインが必要です');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('氏名を入力してください');

    await _client.from('profiles').update({'name': trimmed}).eq('id', user.id);

    try {
      await _client.auth.updateUser(UserAttributes(data: {'name': trimmed}));
    } catch (e) {
      debugPrint('updateUser metadata error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 招待コード使用
  // ─────────────────────────────────────────────
  Future<String> joinWithInviteCode(String code) async {
    final user = currentUser;
    if (user == null) throw Exception('ログインが必要です');

    final invite = await _client
        .from('invite_codes')
        .select('id, troop_id, expires_at, used_by, role')
        .eq('code', code.toUpperCase())
        .maybeSingle();

    if (invite == null) throw Exception('招待コードが見つかりません');
    if (invite['used_by'] != null) throw Exception('この招待コードはすでに使用されています');

    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) throw Exception('招待コードの有効期限が切れています');

    final troopId = invite['troop_id'] as String;
    final inviteId = invite['id'] as String;
    final role = invite['role'] as String? ?? 'member';

    // すでに同じ団に所属していないか確認
    final existing = await _client
        .from('troop_members')
        .select('id')
        .eq('user_id', user.id)
        .eq('troop_id', troopId)
        .maybeSingle();
    if (existing != null) throw Exception('すでにこの団に参加しています');

    // profilesが存在しない場合に備えてinsertで保証（既存の登録名は上書きしない）
    final existingProfile = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existingProfile == null) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'name': user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'user',
        'email': user.email,
      }, onConflict: 'id');
    }

    await _client.from('troop_members').insert({
      'user_id': user.id,
      'troop_id': troopId,
      'role': role,
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
  Future<String> generateInviteCode(String troopId, {String role = 'member'}) async {
    final user = currentUser;
    if (user == null) throw Exception('ログインが必要です');

    final code = _generateCode();

    await _client.from('invite_codes').insert({
      'code': code,
      'troop_id': troopId,
      'created_by': user.id,
      'role': role,
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
