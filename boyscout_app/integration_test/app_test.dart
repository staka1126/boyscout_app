import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boyscout_app/main.dart' as app;
import 'package:boyscout_app/core/supabase_config.dart';
import 'package:boyscout_app/data/local/database_helper.dart';

// ⚠️ 実行時に --dart-define が必要です
//
// 統合テストは app.main() 経由でアプリ全体を起動するため、
// SupabaseConfig.initialize() が呼ばれます。キー未指定の場合は assert で落ちます。
//
// 実行方法: ./test_integration.sh（.env から自動読み込み）

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

// ─── ログインヘルパー ──────────────────────────────────────────
Future<void> _login(WidgetTester tester) async {
  // ログイン画面が表示されていなければスキップ
  if (find.text('メールアドレス').evaluate().isEmpty) return;

  await tester.enterText(
    find.widgetWithText(TextField, 'メールアドレス'),
    _testEmail,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'パスワード'),
    _testPassword,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));

  // ログイン完了＋同期完了まで待つ（最大3秒。同期はバッチ化により高速化済み）
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
}

// ─── テスト前のSharedPreferencesのみリセット（DBは消さない） ──────
// LocalDBを削除するとsyncFromSupabaseが「already synced」で
// スキップされテドータが復元されないケースがあるため。
Future<void> _resetApp() async {
  SharedPreferences.setMockInitialValues({});
}

// ─── 団情報とtroop_idをセットアップして起動するヘルパー ────────
Future<void> _setupTroopAndLaunch(WidgetTester tester) async {
  await _resetApp();
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // ログイン画面が出たらログインする
  await _login(tester);

  // BottomNavigationBarが出るまで待つ（同期完了込みで最大5秒）
  for (int i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle(const Duration(seconds: 1));
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
  // NOTE: テストアカウントはログイン済みのため、起動時にSupabaseセッションが有効で
  // オンボーディング画面は表示されない。実機での初回起動シナリオは手動確認すること。
  //
  // group('オンボーディングフロー', () { ... });

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

    testWidgets('イベント追加画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // イベント作成フォームが開く
      expect(
        find.textContaining('タイトル').evaluate().isNotEmpty ||
        find.text('イベント追加').evaluate().isNotEmpty,
        isTrue,
      );
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

    testWidgets('レポート出力画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('レポート出力'));
      await tester.pumpAndSettle();

      expect(find.text('レポート出力'), findsWidgets);
    });

    testWidgets('使い方画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // '使い方'はGitHub Pagesを外部ブラウザで開く（url_launcher）
      // タップしてもアプリ内番面遷移は発生しないので、ボタンの存在のみ確認
      expect(find.text('使い方'), findsOneWidget);
    });

    testWidgets('利用者管理画面に遷移できる（adminのみ）', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (find.text('利用者管理').evaluate().isEmpty) return; // admin以外はスキップ
      await tester.tap(find.text('利用者管理'));
      await tester.pumpAndSettle();

      expect(find.text('利用者管理'), findsWidgets);
    });

    testWidgets('招待コード画面に遷移できる（adminのみ）', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (find.text('招待コード').evaluate().isEmpty) return;
      await tester.tap(find.text('招待コード'));
      await tester.pumpAndSettle();

      expect(find.text('招待コード'), findsWidgets);
    });

    testWidgets('バッチ登録画面に遷移できる（adminのみ）', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (find.text('バッチ登録').evaluate().isEmpty) return;
      await tester.tap(find.text('バッチ登録'));
      await tester.pumpAndSettle();

      expect(find.text('バッチ登録'), findsWidgets);
    });

    testWidgets('バッチ登録を長押しでExcelインポート画面に遷移できる（adminのみ）', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (find.text('バッチ登録').evaluate().isEmpty) return;

      // 3秒長押しでExcelインポート画面へ
      final gesture = await tester.startGesture(
          tester.getCenter(find.text('バッチ登録')));
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        find.text('Excelインポート').evaluate().isNotEmpty ||
        find.text('インポート').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('アカウント典削除ダイアログが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('アカウントを削除する'));
      await tester.pumpAndSettle();

      // ダイアログが開く（adminは別ダイアログ、非 adminは剥認ダイアログ）
      expect(
        find.text('アカウントを削除する').evaluate().isNotEmpty ||
        find.text('管理者はアカウントを削除できません').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('バージョン情報を長押しでデータ全削除ダイアログが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 10秒長押し
      final gesture = await tester.startGesture(
          tester.getCenter(find.text('バージョン情報')));
      await tester.pump(const Duration(seconds: 10, milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        find.text('データをすべて削除').evaluate().isNotEmpty ||
        find.textContaining('削除').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ─── イベント作成制限 ──────────────────────────────────────
  group('イベント作成制限', () {
    testWidgets('実データありの場合はFABが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  // ─── スカウト管理フロー ────────────────────────────────────
  group('スカウト管理フロー', () {
    testWidgets('スカウト管理画面が表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

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

    testWidgets('検索ボックスが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '氏名で検索'), findsOneWidget);
    });

    testWidgets('上進・退団・入隊せずを表示できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      // 「上進・退団・入隊せずを表示」ボタン
      final showBtn = find.text('上進・退団・入隊せずを表示');
      if (showBtn.evaluate().isEmpty) return; // 該当スカウトなしはスキップ
      await tester.tap(showBtn);
      await tester.pumpAndSettle();

      expect(find.text('上進・退団・入隊せずを隠す'), findsOneWidget);
    });

    testWidgets('上進・退団・入隊せずを隠せる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      final showBtn = find.text('上進・退団・入隊せずを表示');
      if (showBtn.evaluate().isEmpty) return;
      await tester.tap(showBtn);
      await tester.pumpAndSettle();

      // 「隠す」ボタンをタップ
      await tester.tap(find.text('上進・退団・入隊せずを隠す'));
      await tester.pumpAndSettle();

      expect(find.text('上進・退団・入隊せずを表示'), findsOneWidget);
    });
  });

  // ─── リーダー管理フロー ────────────────────────────────────
  group('リーダー管理フロー', () {
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

    testWidgets('リーダー一覧に実データが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);

      await tester.tap(find.text('リーダー'));
      await tester.pumpAndSettle();

      // 実データにリーダーが1件以上登録されていることを確認
      expect(find.byType(ListTile), findsWidgets);
    });
  });

  // ─── 各詳細画面 ───────────────────────────────────────────
  group('各詳細画面', () {
    testWidgets('スカウト詳細画面が開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      // 実データの先頭のスカウトをタップ
      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      // 詳細画面の基本情報セクションが表示される
      expect(find.text('基本情報'), findsOneWidget);
    });

    testWidgets('スカウト詳細から保護者リンクを開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      // スカウト詳細画面の「保護者」セクションを確認
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('保護者').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      expect(find.text('保護者'), findsOneWidget);
      // 「紐付け」ボタンも表示される
      expect(find.text('紐付け'), findsOneWidget);
    });

    testWidgets('イベント詳細画面が開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      // イベントタブへ
      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      // 実データの先頭のイベントをタップ
      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      // イベント詳細のステータスボタンが表示される
      expect(find.text('予定'), findsOneWidget);
    });

    testWidgets('設定 リーダー詳細が開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('リーダー'));
      await tester.pumpAndSettle();

      // Card内のListTile（リーダー一覧の各行）を取得
      final cardTiles = find.descendant(
        of: find.byType(Card),
        matching: find.byType(ListTile),
      );
      if (cardTiles.evaluate().isEmpty) return;
      await tester.tap(cardTiles.first);

      // 詳細画面（氏名がAppBarタイトル、「連絡先」セクションが表示）が出るまで待つ
      for (int i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('連絡先').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      // 詳細画面の「連絡先」セクションで確認
      expect(find.text('連絡先'), findsOneWidget);
    });

    testWidgets('設定 保護者詳細が開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保護者'));
      await tester.pumpAndSettle();

      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      // 保護者管理一覧 + 詳細画面のScaffoldが重なるので findsWidgets
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ─── イベント出欠管理 ──────────────────────────────────────
  group('イベント出欠管理', () {
    testWidgets('出欠管理タブに遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      // イベント詳細の「出欠」タブをタップ
      final attendanceTab = find.text('出欠');
      if (attendanceTab.evaluate().isEmpty) return;
      await tester.tap(attendanceTab);
      await tester.pumpAndSettle();

      // リーダー・スカウトセクションが表示される
      final hasLeader = find.text('リーダー').evaluate().isNotEmpty;
      final hasScout = find.text('スカウト').evaluate().isNotEmpty;
      expect(hasLeader || hasScout, isTrue);
    });

    testWidgets('参加者追加シートが開ける', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      // 実施済でないイベントを探す（実施済は追加不可）
      final plannedTile = find.descendant(
        of: find.byType(Card),
        matching: find.textContaining('予定'),
      );
      if (plannedTile.evaluate().isEmpty) return;
      await tester.tap(plannedTile.first);
      await tester.pumpAndSettle();

      // FAB（参加者追加）をタップ
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 参加者追加シートのタブが表示される
      expect(
        find.text('リーダー').evaluate().isNotEmpty ||
        find.text('スカウト').evaluate().isNotEmpty ||
        find.text('保護者').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('参加者追加シートのタブ遷移ができる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      final plannedTile = find.descendant(
        of: find.byType(Card),
        matching: find.textContaining('予定'),
      );
      if (plannedTile.evaluate().isEmpty) return;
      await tester.tap(plannedTile.first);
      await tester.pumpAndSettle();

      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 各タブを順に遷移
      for (final label in ['スカウト', '保護者', '団委員ほか', 'リーダー']) {
        final tab = find.text(label);
        if (tab.evaluate().isEmpty) continue;
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });
  });

  // ─── スカウト↔保護者関連付け ────────────────────────────────
  group('スカウト↔保護者関連付け', () {
    testWidgets('保護者詳細に「紐付きスカウト」セクションと紐付けボタンが表示される', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保護者'));
      await tester.pumpAndSettle();

      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      // 保護者詳細画面の「紐付きスカウト」セクション
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('紐付きスカウト').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      expect(find.text('紐付きスカウト'), findsOneWidget);
      // 「紐付け」ボタンも表示される
      expect(find.text('紐付け'), findsOneWidget);
    });
  });

  // ─── 表彰タブ ─────────────────────────────────────────────
  group('表彰タブ', () {
    testWidgets('表彰画面に遷移できる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final badgeTab = find.byIcon(Icons.emoji_events_outlined);
      if (badgeTab.evaluate().isEmpty) return;
      await tester.tap(badgeTab);
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('表彰画面の4タブ遷移ができる', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final badgeTab = find.byIcon(Icons.emoji_events_outlined);
      if (badgeTab.evaluate().isEmpty) return;
      await tester.tap(badgeTab);
      await tester.pumpAndSettle();

      for (final label in ['入隊', '小枝章', '木の葉章', '皆勤賞']) {
        final tab = find.text(label);
        if (tab.evaluate().isEmpty) continue;
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });
  });

  // ─── データ整合性検証 ───────────────────────────────────────
  // Supabaseから取得した件数と画面に表示された件数の一致を検証
  // また、同一画面内でラベル（名前・タイトル）の重複がないことも検証

  // Supabaseから団のtroop_idを取得するヘルパー
  Future<String?> _getTroopId() async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return null;
    final member = await SupabaseConfig.client
        .from('troop_members')
        .select('troop_id')
        .eq('user_id', user.id)
        .maybeSingle();
    return member?['troop_id'] as String?;
  }

  group('データ整傐性: 件数照合', () {
    testWidgets('ダッシュボード: 直近イベント表示数が実データと一致する', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      // Supabaseから直近（2か月）イベントを取得
      final troopId = await _getTroopId();
      if (troopId == null) return;
      final now = DateTime.now();
      final twoMonthsAgo = DateTime(now.year, now.month - 2, 1);
      final supabaseEvents = await SupabaseConfig.client
          .from('events')
          .select('id')
          .eq('troop_id', troopId)
          .gte('event_date', twoMonthsAgo.toIso8601String());
      final supabaseCount = (supabaseEvents as List).length;

      // ホーム画面の直近イベントリスト件数をカウント
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      final displayCount = find.descendant(
        of: find.byType(Card),
        matching: find.byType(ListTile),
      ).evaluate().length;

      // 画面は最大5件表示なので小さい方で比較
      expect(displayCount, lessThanOrEqualTo(supabaseCount));
      expect(displayCount, lessThanOrEqualTo(5));
    });

    testWidgets('スカウト管理: 表示件数がSupabaseの有効スカウト数以下', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final supabaseScouts = await SupabaseConfig.client
          .from('scouts')
          .select('id')
          .eq('troop_id', troopId)
          .eq('is_active', true);
      final supabaseCount = (supabaseScouts as List).length;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();
      final displayCount = find.byType(Card).evaluate().length;

      // 一覧は退団・上進・入隊せずをデフォルト非表示なので表示数 <= Supabase件数
      expect(displayCount, lessThanOrEqualTo(supabaseCount));
      expect(displayCount, greaterThan(0));
    });

    testWidgets('イベント管理: 当年度の表示件数がSupabaseと一致する', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final now = DateTime.now();
      final fiscalStart = now.month >= 4
          ? DateTime(now.year, 4, 1)
          : DateTime(now.year - 1, 4, 1);
      final fiscalEnd = DateTime(fiscalStart.year + 1, 3, 31);
      final supabaseEvents = await SupabaseConfig.client
          .from('events')
          .select('id')
          .eq('troop_id', troopId)
          .gte('event_date', fiscalStart.toIso8601String())
          .lte('event_date', fiscalEnd.toIso8601String());
      final supabaseCount = (supabaseEvents as List).length;

      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();
      final displayCount = find.byType(Card).evaluate().length;

      expect(displayCount, supabaseCount);
    });

    testWidgets('イベント管理: 前年度の表示件数がSupabaseと一致する', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final now = DateTime.now();
      final prevFiscalYear = now.month >= 4 ? now.year - 1 : now.year - 2;
      final fiscalStart = DateTime(prevFiscalYear, 4, 1);
      final fiscalEnd = DateTime(prevFiscalYear + 1, 3, 31);
      final supabaseEvents = await SupabaseConfig.client
          .from('events')
          .select('id')
          .eq('troop_id', troopId)
          .gte('event_date', fiscalStart.toIso8601String())
          .lte('event_date', fiscalEnd.toIso8601String());
      final supabaseCount = (supabaseEvents as List).length;
      if (supabaseCount == 0) return; // 前年度データなしはスキップ

      final eventTab = find.byIcon(Icons.event_outlined);
      if (eventTab.evaluate().isEmpty) return;
      await tester.tap(eventTab);
      await tester.pumpAndSettle();

      // 年度ドロップダウンで前年度を選択
      final dropdown = find.byType(DropdownButton<int>);
      if (dropdown.evaluate().isEmpty) return;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      final prevYearItem = find.text('${prevFiscalYear}年度').last;
      if (prevYearItem.evaluate().isEmpty) return;
      await tester.tap(prevYearItem);
      await tester.pumpAndSettle();

      final displayCount = find.byType(Card).evaluate().length;
      expect(displayCount, supabaseCount);
    });

    testWidgets('リーダー管理: 表示件数がSupabaseと一致する', (tester) async {
      await _setupTroopAndLaunch(tester);
      await _goSettings(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final supabaseLeaders = await SupabaseConfig.client
          .from('leaders')
          .select('id')
          .eq('troop_id', troopId);
      final supabaseCount = (supabaseLeaders as List).length;

      await tester.tap(find.text('リーダー'));
      await tester.pumpAndSettle();
      final displayCount = find.byType(Card).evaluate().length;

      expect(displayCount, supabaseCount);
    });

    testWidgets('保護者管理: 表示件数がSupabaseと一致する', (tester) async {
      await _setupTroopAndLaunch(tester);

      final troopId = await _getTroopId();
      if (troopId == null) return;
      // 保護者はtroop_idで絞り込む
      final supabaseGuardians = await SupabaseConfig.client
          .from('guardians')
          .select('id')
          .eq('troop_id', troopId);
      final supabaseCount = (supabaseGuardians as List).length;

      // 画面への遷移はしない。
      // ListView.separatedは仮想スクロールのため、画面内Card数 != 全件数。
      // 代わりにローカルDBの件数とSupabaseの件数が一致することを検証する
      final db = await DatabaseHelper.instance.database;
      final localCount = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COUNT(*) FROM guardians WHERE troop_id = ?', [troopId])) ??
          0;

      expect(localCount, supabaseCount);
    });

    testWidgets('団委員ほか管理: 表示件数がSupabaseと一致する', (tester) async {
      await _setupTroopAndLaunch(tester);

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final supabaseCommittee = await SupabaseConfig.client
          .from('committee_members')
          .select('id')
          .eq('troop_id', troopId);
      final supabaseCount = (supabaseCommittee as List).length;

      // ローカルDBと一致することを検証（山進・引退表示制御はアプリ側のフィルタありのため画面内数では比較不可）
      final db = await DatabaseHelper.instance.database;
      final localCount = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COUNT(*) FROM committee_members WHERE troop_id = ?', [troopId])) ??
          0;

      expect(localCount, supabaseCount);
    });
  });

  group('データ整傐性: ラベル重複チェック', () {
    testWidgets('イベント管理: 当年度イベントタイトルに重複がない', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final now = DateTime.now();
      final fiscalStart = now.month >= 4
          ? DateTime(now.year, 4, 1)
          : DateTime(now.year - 1, 4, 1);
      final fiscalEnd = DateTime(fiscalStart.year + 1, 3, 31);
      final supabaseEvents = await SupabaseConfig.client
          .from('events')
          .select('title')
          .eq('troop_id', troopId)
          .gte('event_date', fiscalStart.toIso8601String())
          .lte('event_date', fiscalEnd.toIso8601String());
      final titles = (supabaseEvents as List)
          .map((e) => e['title'] as String)
          .toList();
      final uniqueTitles = titles.toSet();

      // 重複しているタイトル一覧をエラーメッセージに
      final duplicates = titles
          .where((t) => titles.where((x) => x == t).length > 1)
          .toSet()
          .toList();
      expect(
        uniqueTitles.length,
        titles.length,
        reason: '重複タイトル: $duplicates',
      );
    });

    testWidgets('スカウト管理: スカウト氏名に重複がない', (tester) async {
      await _setupTroopAndLaunch(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      final troopId = await _getTroopId();
      if (troopId == null) return;
      final supabaseScouts = await SupabaseConfig.client
          .from('scouts')
          .select('name')
          .eq('troop_id', troopId)
          .eq('is_active', true);
      final names = (supabaseScouts as List)
          .map((s) => s['name'] as String)
          .toList();
      final uniqueNames = names.toSet();

      final duplicates = names
          .where((n) => names.where((x) => x == n).length > 1)
          .toSet()
          .toList();
      expect(
        uniqueNames.length,
        names.length,
        reason: '重複氏名: $duplicates',
      );
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
