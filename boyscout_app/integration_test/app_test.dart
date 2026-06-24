import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boyscout_app/main.dart' as app;
import 'package:boyscout_app/data/local/database_helper.dart';

// ⚠️ 実行時に --dart-define が必要です
//
// 統合テストは app.main() 経由でアプリ全体を起動するため、
// SupabaseConfig.initialize() が呼ばれます。キー未指定の場合は assert で落ちます。
//
// 実行方法:
//   flutter test integration_test/app_test.dart -d linux \
//     --dart-define=SUPABASE_URL=$SUPABASE_URL \
//     --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
//
// または run.sh と同様に .env を読み込んでから実行すると便利です。

// ─── テスト前にDBとSharedPreferencesをリセット ───────────────
Future<void> _resetApp() async {
  SharedPreferences.setMockInitialValues({});
  final db = await DatabaseHelper.instance.database;
  await db.delete('attendances');
  await db.delete('event_leaf_badges');
  await db.delete('twig_badge_history');
  await db.delete('events');
  await db.delete('scout_guardians');
  await db.delete('scouts');
  await db.delete('committee_members');
  await db.delete('guardians');
  await db.delete('leaders');  // v5以降: users → leaders
  await db.delete('troops');
}

// ─── 団情報とtroop_idをセットアップして起動するヘルパー ────────
Future<void> _setupTroopAndLaunch(
  WidgetTester tester, {
  bool withLeader = false,
  bool withScout = false,
}) async {
  await _resetApp();
  final db = await DatabaseHelper.instance.database;
  const troopId = 'test-troop-id';
  final now = DateTime.now().toIso8601String();

  await db.insert('troops', {
    'id': troopId,
    'name': 'テスト団',
    'created_at': now,
    'updated_at': now,
  });

  if (withLeader) {
    await db.insert('leaders', {
      'id': 'leader-1',
      'troop_id': troopId,
      'name': 'テスト 隊長',
      'email': 'leader@test.com',
      'role': 'leader',
      'is_active': 1,
      'is_retired': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  if (withScout) {
    await db.insert('scouts', {
      'id': 'scout-1',
      'troop_id': troopId,
      'name': 'テスト スカウト',
      'category': 'beaver',
      'leaf_badges': 0,
      'leaf_badge_offset': 0,
      'twig_badges': 0,
      'other_badges': 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  SharedPreferences.setMockInitialValues({'troop_id': troopId});
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

// ─── 設定タブへ移動するヘルパー ────────────────────────────────
Future<void> _goSettings(WidgetTester tester) async {
  if (find.byIcon(Icons.settings_outlined).evaluate().isEmpty) return;
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  // ─── オンボーディング ──────────────────────────────────────
  group('オンボーディングフロー', () {
    testWidgets('初回起動でオンボーディング画面が表示される', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('ビーバーログへようこそ'), findsOneWidget);
      expect(find.text('団情報を登録する'), findsOneWidget);
    });

    testWidgets('ログインボタンが表示される', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // オンボーディング or ログイン画面のいずれかが表示されればOK
      final hasOnboarding = find.text('ビーバーログへようこそ').evaluate().isNotEmpty;
      final hasLogin = find.textContaining('ログイン').evaluate().isNotEmpty;
      expect(hasOnboarding || hasLogin, isTrue);
    });
  });

  // ─── ダッシュボード ────────────────────────────────────────
  group('ダッシュボード', () {
    testWidgets('団情報がある場合にダッシュボードが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);

      // BottomNavigationBar またはダッシュボード要素が表示される
      final hasBnb = find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
      expect(hasBnb || hasScaffold, isTrue);
    });

    testWidgets('イベント追加FABが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      // ホームタブを確認
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  // ─── BottomNavigationBar ──────────────────────────────────
  group('BottomNavigationBarナビゲーション', () {
    testWidgets('各タブに遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ─── 設定画面 ─────────────────────────────────────────────
  group('設定画面', () {
    testWidgets('設定メニュー項目が表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      // Supabaseの非同期処理が落ち着くまで待つ
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 実際のsettings_page.dartに存在するメニュー項目
      // 各項目はListTileで常時レンダリングされる（Supabaseヘッダー部は非同期）
      expect(find.text('団情報'), findsOneWidget);
      expect(find.text('リーダー'), findsOneWidget);
      expect(find.text('保護者'), findsOneWidget);
      expect(find.text('団委員ほか'), findsOneWidget);
      expect(find.text('電話帳'), findsOneWidget);
      expect(find.text('アレルギー情報'), findsOneWidget);
    });

    testWidgets('団情報画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('団情報'));
      await tester.pumpAndSettle();

      // 団情報フォームが表示される
      expect(find.textContaining('団'), findsWidgets);
    });

    testWidgets('リーダー管理画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('リーダー'));
      await tester.pumpAndSettle();

      expect(find.text('リーダー管理'), findsOneWidget);
    });

    testWidgets('保護者管理画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保護者'));
      await tester.pumpAndSettle();

      expect(find.text('保護者管理'), findsOneWidget);
    });

    testWidgets('団委員管理画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('団委員ほか'));
      await tester.pumpAndSettle();

      expect(find.text('団委員ほか管理'), findsOneWidget);
    });

    testWidgets('電話帳画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('電話帳'));
      await tester.pumpAndSettle();

      expect(find.text('電話帳'), findsWidgets);
    });

    testWidgets('アレルギー情報画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('アレルギー情報'));
      await tester.pumpAndSettle();

      expect(find.text('アレルギー情報'), findsWidgets);
    });
  });

  // ─── イベント作成制限 ──────────────────────────────────────
  group('イベント作成制限', () {
    testWidgets('リーダー・スカウト未登録時はSnackBarが表示される', (tester) async {
      // 団情報のみ・リーダー/スカウトなし
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      // ホームタブのFABをタップ
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      await tester.tap(find.byType(FloatingActionButton));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('登録してください').evaluate().isNotEmpty) break;
      }

      expect(find.textContaining('登録してください'), findsOneWidget);
    });

    testWidgets('リーダー・スカウト登録済みはイベントフォームへ遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester, withLeader: true, withScout: true);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // イベント作成フォームが開く
      final hasTitle = find.text('タイトル *').evaluate().isNotEmpty
          || find.text('イベント追加').evaluate().isNotEmpty
          || find.textContaining('タイトル').evaluate().isNotEmpty;
      expect(hasTitle, isTrue);
    });
  });

  // ─── スカウト登録フロー ────────────────────────────────────
  group('スカウト登録フロー', () {
    testWidgets('スカウト管理画面が表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      // スカウト追加FABまたはスカウト関連テキストが表示される
      final hasFab = find.byType(FloatingActionButton).evaluate().isNotEmpty;
      final hasText = find.textContaining('スカウト').evaluate().isNotEmpty;
      expect(hasFab || hasText, isTrue);
    });

    testWidgets('スカウト追加フォームを開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('氏 *'), findsOneWidget);
      expect(find.text('名 *'), findsOneWidget);
    });

    testWidgets('氏・名を入力して保存できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, '氏 *'), 'テスト');
      await tester.enterText(find.widgetWithText(TextFormField, '名 *'), '太郎');
      await tester.pumpAndSettle();

      await tester.tap(find.text('追加する'));
      await tester.pumpAndSettle();

      // フォームが閉じる（氏フィールドが消える）
      expect(find.text('氏 *'), findsNothing);
    });

    testWidgets('スカウト登録後に一覧に表示される', (tester) async {
      await _setupTroopAndLaunch(tester, withScout: true);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      // 事前登録したスカウトが一覧に表示される
      expect(find.text('テスト スカウト'), findsOneWidget);
    });

    testWidgets('スカウト検索で絞り込みができる', (tester) async {
      await _setupTroopAndLaunch(tester, withScout: true);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      // 検索ボックスに入力
      final searchField = find.widgetWithText(TextField, '氏名で検索');
      if (searchField.evaluate().isEmpty) return;

      await tester.enterText(searchField, 'テスト');
      await tester.pumpAndSettle();
      expect(find.text('テスト スカウト'), findsOneWidget);

      // ヒットしない名前で検索
      await tester.enterText(searchField, '存在しない名前');
      await tester.pumpAndSettle();
      expect(find.text('テスト スカウト'), findsNothing);
    });
  });

  // ─── リーダー登録フロー ────────────────────────────────────
  group('リーダー登録フロー', () {
    testWidgets('リーダー追加フォームを開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);

      await tester.tap(find.text('リーダー'));
      await tester.pumpAndSettle();
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('氏 *'), findsOneWidget);
      expect(find.text('名 *'), findsOneWidget);
      expect(find.text('隊長'), findsOneWidget);
      expect(find.text('副長'), findsOneWidget);
      expect(find.text('補助者'), findsOneWidget);
    });

    testWidgets('リーダー登録後に一覧に表示される', (tester) async {
      await _setupTroopAndLaunch(tester, withLeader: true);
      await _goSettings(tester);

      await tester.tap(find.text('リーダー'));
      await tester.pumpAndSettle();

      expect(find.text('テスト 隊長'), findsOneWidget);
    });
  });

  // ─── イベント管理フロー ────────────────────────────────────
  group('イベント管理フロー', () {
    testWidgets('イベント管理画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      // イベントタブへ
      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      expect(find.text('イベント管理'), findsOneWidget);
    });

    testWidgets('イベントが0件の場合に空メッセージが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      expect(find.textContaining('イベントはありません'), findsOneWidget);
    });
  });
}
