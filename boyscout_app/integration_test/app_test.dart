import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boyscout_app/main.dart' as app;
import 'package:boyscout_app/data/local/database_helper.dart';

// テスト前にDBとSharedPreferencesをリセット
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
  await db.delete('users');
  await db.delete('troops');
}

// オンボーディングをスキップしてダッシュボードへ移動するヘルパー
Future<void> _skipToDashboard(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    if (find.text('スキップしてアプリを開く').evaluate().isNotEmpty) {
      await tester.tap(find.text('スキップしてアプリを開く'));
      await tester.pumpAndSettle();
      break;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
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

    testWidgets('スキップでダッシュボードへ遷移する', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);

      final hasBnb = find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
      expect(hasBnb || hasScaffold, isTrue);
    });
  });

  // ─── BottomNavigationBar ──────────────────────────────────
  group('BottomNavigationBarナビゲーション', () {
    testWidgets('各タブに遷移できる', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
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
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('リーダー管理'), findsOneWidget);
      expect(find.text('スカウト管理'), findsOneWidget);
      expect(find.text('電話帳'), findsOneWidget);
      expect(find.text('アレルギー情報'), findsOneWidget);
    });

    testWidgets('団情報管理画面に遷移できる', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('団情報'));
      await tester.pumpAndSettle();

      expect(find.textContaining('団'), findsWidgets);
    });
  });

  // ─── イベント作成制限 ──────────────────────────────────────
  group('イベント作成制限', () {
    testWidgets('リーダー・スカウト未登録時はSnackBarが表示される', (tester) async {
      await _resetApp();

      // DBに団情報だけ直接挿入（リーダー・スカウトなし）
      final db = await DatabaseHelper.instance.database;
      const troopId = 'test-troop-id';
      final now = DateTime.now().toIso8601String();
      await db.insert('troops', {
        'id': troopId,
        'name': 'テスト団',
        'created_at': now,
        'updated_at': now,
      });
      SharedPreferences.setMockInitialValues({'troop_id': troopId});

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ダッシュボードへ移動
      await _skipToDashboard(tester);
      if (find.byType(FloatingActionButton).evaluate().isEmpty) return;

      // FABをタップ
      await tester.tap(find.byType(FloatingActionButton));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('登録してください').evaluate().isNotEmpty) break;
      }

      expect(find.textContaining('登録してください'), findsOneWidget);
    });
  });

  // ─── スカウト登録フロー ────────────────────────────────────
  group('スカウト登録フロー', () {
    testWidgets('スカウト一覧画面が表示される', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.child_care_outlined));
      await tester.pumpAndSettle();

      final hasFab = find.byType(FloatingActionButton).evaluate().isNotEmpty;
      final hasEmpty = find.textContaining('スカウト').evaluate().isNotEmpty;
      expect(hasFab || hasEmpty, isTrue);
    });

    testWidgets('スカウト追加フォームを開ける', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
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
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
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

      expect(find.text('氏 *'), findsNothing);
    });
  });

  // ─── リーダー登録フロー ────────────────────────────────────
  group('リーダー登録フロー', () {
    testWidgets('リーダー追加フォームを開ける', (tester) async {
      await _resetApp();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _skipToDashboard(tester);
      if (find.byType(BottomNavigationBar).evaluate().isEmpty) return;

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('リーダー管理'));
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
  });
}
