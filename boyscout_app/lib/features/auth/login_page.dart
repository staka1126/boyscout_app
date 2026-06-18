import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/wood_grain_background.dart';
import '../../core/supabase_config.dart';
import '../../data/sync/sync_service.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../auth/auth_provider.dart';
import 'auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscureLogin = true;
  bool _obscureSignup = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _loginEmailCtrl.text.trim();
    final password = _loginPasswordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signIn(email: email, password: password);
      if (!mounted) return;

      final troopId = await _resolveTroopId();
      if (!mounted) return;

      if (troopId != null) {
        await SyncService.instance.syncToSupabase(troopId);
        if (!mounted) return;
        await SyncService.instance.syncFromSupabase(troopId);
        if (!mounted) return;
        ref.read(currentTroopIdProvider.notifier).state = troopId;
        context.go('/dashboard');
      } else {
        context.go('/onboarding');
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      if (mounted) _showError('ログインに失敗しました。メールアドレスとパスワードを確認してください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _resolveTroopId() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString('troop_id');
    if (saved != null) {
      final troops = await ref.read(troopRepositoryProvider).getAll();
      if (troops.any((t) => t.id == saved)) {
        debugPrint('_resolveTroopId: found in local prefs=$saved');
        return saved;
      }
    }

    final user = SupabaseConfig.currentUser;
    if (user == null) return null;

    try {
      final member = await SupabaseConfig.client
          .from('troop_members')
          .select('troop_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (member != null) {
        final troopId = member['troop_id']?.toString();
        if (troopId != null) {
          await prefs.setString('troop_id', troopId);
          debugPrint('_resolveTroopId: found in Supabase troopId=$troopId');
          return troopId;
        }
      }
    } catch (e) {
      debugPrint('_resolveTroopId error: $e');
    }

    debugPrint('_resolveTroopId: not found');
    return null;
  }

  Future<void> _signUp() async {
    final name = _signupNameCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim();
    final password = _signupPasswordCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('すべての項目を入力してください');
      return;
    }
    if (password.length < 8) {
      _showError('パスワードは8文字以上にしてください');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (mounted) {
        _showMessage('登録が完了しました。ログインしてください。');
        _tabController.animateTo(0);
      }
    } catch (e) {
      _showError('登録に失敗しました。すでに登録済みのメールアドレスの可能性があります。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const WoodGrainBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nature_people,
                            size: 56, color: Colors.brown),
                        const SizedBox(height: 8),
                        Text(
                          'ビーバーログ',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'ログイン'),
                            Tab(text: '新規登録'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 280,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoginForm(),
                              _buildSignupForm(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _loginEmailCtrl,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPasswordCtrl,
          decoration: InputDecoration(
            labelText: 'パスワード',
            prefixIcon: const Icon(Icons.lock_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureLogin ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
            ),
          ),
          obscureText: _obscureLogin,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ログイン'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      children: [
        TextField(
          controller: _signupNameCtrl,
          decoration: const InputDecoration(
            labelText: '氏名',
            prefixIcon: Icon(Icons.person_outlined),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupEmailCtrl,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupPasswordCtrl,
          decoration: InputDecoration(
            labelText: 'パスワード（8文字以上）',
            prefixIcon: const Icon(Icons.lock_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureSignup ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscureSignup = !_obscureSignup),
            ),
          ),
          obscureText: _obscureSignup,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signUp(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _signUp,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('登録する'),
          ),
        ),
      ],
    );
  }
}
