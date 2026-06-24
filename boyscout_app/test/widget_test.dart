import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boyscout_app/data/models/models.dart';
import 'package:boyscout_app/core/constants/app_constants.dart';

// ─── テスト用ヘルパー ─────────────────────────────────────────

Scout _makeScout({
  String id = 'scout-1',
  String name = 'テスト 太郎',
  int leafBadges = 0,
  int leafBadgeOffset = 0,
  int twigBadges = 0,
  int otherBadges = 0,
  ScoutCategory category = ScoutCategory.beaver,
  List<AllergyType> allergies = const [],
  String? specialNotes,
  DateTime? birthday,
  bool isActive = true,
}) {
  final now = DateTime.now();
  return Scout(
    id: id,
    troopId: 'troop-1',
    name: name,
    category: category,
    leafBadges: leafBadges,
    leafBadgeOffset: leafBadgeOffset,
    twigBadges: twigBadges,
    otherBadges: otherBadges,
    allergies: allergies,
    specialNotes: specialNotes,
    birthday: birthday,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

// ─── 性別ラジオボタンのテスト用ウィジェット ───────────────────

class _GenderRadioTest extends StatefulWidget {
  final String? initial;
  const _GenderRadioTest({this.initial});

  @override
  State<_GenderRadioTest> createState() => _GenderRadioTestState();
}

class _GenderRadioTestState extends State<_GenderRadioTest> {
  String? _gender;

  @override
  void initState() {
    super.initState();
    _gender = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('性別'),
        Row(children: [
          Radio<String>(
            value: 'male',
            groupValue: _gender,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const Text('男性'),
          Radio<String>(
            value: 'female',
            groupValue: _gender,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const Text('女性'),
        ]),
        if (_gender != null) Text('selected:$_gender'),
      ],
    );
  }
}

// ─── 小枝章授与ダイアログのテスト用ウィジェット ───────────────

class _TwigAwardDialogTest extends StatelessWidget {
  final Scout scout;
  final int pendingCount;
  const _TwigAwardDialogTest({required this.scout, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(builder: (ctx) => FilledButton(
        onPressed: () => showDialog(
          context: ctx,
          builder: (dlgCtx) => AlertDialog(
            title: const Text('小枝章を授与'),
            content: Text('${scout.name} に小枝章を ${pendingCount}本 授与しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dlgCtx).pop(true),
                child: const Text('授与する'),
              ),
            ],
          ),
        ),
        child: const Text('授与'),
      )),
    );
  }
}

// ─── テスト ───────────────────────────────────────────────────

void main() {
  // ─── 性別ラジオボタン ──────────────────────────────────────
  group('性別ラジオボタン', () {
    testWidgets('男性・女性の選択肢が表示される', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _GenderRadioTest(),
      )));
      expect(find.text('男性'), findsOneWidget);
      expect(find.text('女性'), findsOneWidget);
    });

    testWidgets('初期値なしではラジオが未選択', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _GenderRadioTest(),
      )));
      expect(find.text('selected:male'), findsNothing);
      expect(find.text('selected:female'), findsNothing);
    });

    testWidgets('デフォルト male を渡すと男性が選択済みになる', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _GenderRadioTest(initial: 'male'),
      )));
      expect(find.text('selected:male'), findsOneWidget);
    });

    testWidgets('男性をタップすると選択される', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _GenderRadioTest(),
      )));
      await tester.tap(find.byType(Radio<String>).first);
      await tester.pump();
      expect(find.text('selected:male'), findsOneWidget);
    });

    testWidgets('初期値 female が反映される', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _GenderRadioTest(initial: 'female'),
      )));
      expect(find.text('selected:female'), findsOneWidget);
    });
  });

  // ─── Scout情報の表示 ───────────────────────────────────────
  group('スカウト情報表示', () {
    testWidgets('スカウト名が表示される', (tester) async {
      final scout = _makeScout(name: '笹野 隆昭');
      await tester.pumpWidget(_wrap(Scaffold(
        body: ListTile(
          title: Text(scout.name),
          subtitle: Text(scout.category.label),
        ),
      )));
      expect(find.text('笹野 隆昭'), findsOneWidget);
      expect(find.text('ビーバー'), findsOneWidget);
    });

    testWidgets('木の葉章の合計枚数が表示される（補正後）', (tester) async {
      final scout = _makeScout(leafBadges: 15, leafBadgeOffset: 5);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text('合計 ${scout.totalLeafBadges}枚'),
      )));
      expect(find.text('合計 10枚'), findsOneWidget);
    });

    testWidgets('アレルギーチップが表示される', (tester) async {
      final scout = _makeScout(allergies: [AllergyType.egg, AllergyType.dairy]);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Wrap(
          children: scout.allergies
              .map((a) => Chip(label: Text(a.label)))
              .toList(),
        ),
      )));
      expect(find.text('鶏卵'), findsOneWidget);
      expect(find.text('牛乳・乳製品'), findsOneWidget);
    });

    testWidgets('アレルギーなしの場合チップが表示されない', (tester) async {
      final scout = _makeScout(allergies: []);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Wrap(
          children: scout.allergies
              .map((a) => Chip(label: Text(a.label)))
              .toList(),
        ),
      )));
      expect(find.byType(Chip), findsNothing);
    });
  });

  // ─── イベントステータスチップ ──────────────────────────────
  group('イベントステータス表示', () {
    Widget statusChip(EventStatus status) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(status.label),
      );
    }

    testWidgets('予定ステータスのラベルが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: statusChip(EventStatus.planned),
      )));
      expect(find.text('予定'), findsOneWidget);
    });

    testWidgets('実施済ステータスのラベルが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: statusChip(EventStatus.completed),
      )));
      expect(find.text('実施済'), findsOneWidget);
    });

    testWidgets('非開催ステータスのラベルが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: statusChip(EventStatus.cancelled),
      )));
      expect(find.text('非開催'), findsOneWidget);
    });
  });

  // ─── 小枝章授与ボタン ─────────────────────────────────────
  group('小枝章授与ボタン', () {
    testWidgets('授与待ちがある場合ボタンが表示される', (tester) async {
      final scout = _makeScout(leafBadges: 10, twigBadges: 0);
      final pending = scout.pendingTwigBadges;

      await tester.pumpWidget(_wrap(Scaffold(
        body: pending > 0
            ? FilledButton(onPressed: () {}, child: const Text('授与'))
            : const Text('授与待ちなし'),
      )));
      expect(find.text('授与'), findsOneWidget);
    });

    testWidgets('授与待ちがない場合ボタンが表示されない', (tester) async {
      final scout = _makeScout(leafBadges: 9, twigBadges: 0);
      final pending = scout.pendingTwigBadges;

      await tester.pumpWidget(_wrap(Scaffold(
        body: pending > 0
            ? FilledButton(onPressed: () {}, child: const Text('授与'))
            : const Text('授与待ちなし'),
      )));
      expect(find.text('授与待ちなし'), findsOneWidget);
      expect(find.text('授与'), findsNothing);
    });
  });

  // ─── 小枝章 N本授与ダイアログ ─────────────────────────────
  group('小枝章 N本授与ダイアログ', () {
    testWidgets('1本授与待ちのときダイアログに「1本」と表示される', (tester) async {
      final scout = _makeScout(name: '田中 花子', leafBadges: 10, twigBadges: 0);
      final pending = scout.pendingTwigBadges; // 1

      await tester.pumpWidget(_wrap(_TwigAwardDialogTest(
        scout: scout,
        pendingCount: pending,
      )));
      await tester.tap(find.text('授与'));
      await tester.pumpAndSettle();

      expect(find.text('小枝章を授与'), findsOneWidget);
      expect(find.textContaining('1本'), findsOneWidget);
      expect(find.textContaining('田中 花子'), findsOneWidget);
    });

    testWidgets('3本授与待ちのときダイアログに「3本」と表示される', (tester) async {
      final scout = _makeScout(name: '鈴木 一郎', leafBadges: 30, twigBadges: 0);
      final pending = scout.pendingTwigBadges; // 3

      await tester.pumpWidget(_wrap(_TwigAwardDialogTest(
        scout: scout,
        pendingCount: pending,
      )));
      await tester.tap(find.text('授与'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3本'), findsOneWidget);
    });

    testWidgets('2本授与待ちのときダイアログに「2本」と表示される', (tester) async {
      // 30枚取得・1本授与済み → 2本待ち
      final scout = _makeScout(name: '佐藤 次郎', leafBadges: 30, twigBadges: 1);
      final pending = scout.pendingTwigBadges; // 2

      await tester.pumpWidget(_wrap(_TwigAwardDialogTest(
        scout: scout,
        pendingCount: pending,
      )));
      await tester.tap(find.text('授与'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2本'), findsOneWidget);
    });

    testWidgets('キャンセルでダイアログが閉じる', (tester) async {
      final scout = _makeScout(leafBadges: 10, twigBadges: 0);

      await tester.pumpWidget(_wrap(_TwigAwardDialogTest(
        scout: scout,
        pendingCount: scout.pendingTwigBadges,
      )));
      await tester.tap(find.text('授与'));
      await tester.pumpAndSettle();

      expect(find.text('小枝章を授与'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('小枝章を授与'), findsNothing);
    });
  });

  // ─── 確認ダイアログ ────────────────────────────────────────
  group('確認ダイアログ', () {
    testWidgets('削除確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => showDialog(
            context: ctx,
            builder: (_) => AlertDialog(
              title: const Text('削除しますか？'),
              actions: [
                TextButton(onPressed: () {}, child: const Text('キャンセル')),
                FilledButton(onPressed: () {}, child: const Text('削除')),
              ],
            ),
          ),
          child: const Text('削除'),
        )),
      )));

      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      expect(find.text('削除しますか？'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('キャンセルでダイアログが閉じる', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => showDialog(
            context: ctx,
            builder: (dlgCtx) => AlertDialog(
              title: const Text('削除しますか？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
          child: const Text('開く'),
        )),
      )));

      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      expect(find.text('削除しますか？'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('削除しますか？'), findsNothing);
    });
  });

  // ─── スカウト分類ラベル ────────────────────────────────────
  group('ScoutCategory ラベル表示', () {
    testWidgets('ビーバーのラベルが正しく表示される', (tester) async {
      final scout = _makeScout(category: ScoutCategory.beaver);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(scout.category.label),
      )));
      expect(find.text('ビーバー'), findsOneWidget);
    });

    testWidgets('ビッグビーバーのラベルが正しく表示される', (tester) async {
      final scout = _makeScout(category: ScoutCategory.bigBeaver);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(scout.category.label),
      )));
      expect(find.text('ビッグビーバー'), findsOneWidget);
    });

    testWidgets('上進のラベルが正しく表示される', (tester) async {
      final scout = _makeScout(category: ScoutCategory.promoted, isActive: false);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(scout.category.label),
      )));
      expect(find.text('上進'), findsOneWidget);
    });

    testWidgets('退団のラベルが正しく表示される', (tester) async {
      final scout = _makeScout(category: ScoutCategory.withdrawn, isActive: false);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(scout.category.label),
      )));
      expect(find.text('退団'), findsOneWidget);
    });
  });

  // ─── アレルギーラベル ─────────────────────────────────────
  group('AllergyType ラベル表示', () {
    testWidgets('全アレルギー種別のラベルがチップとして表示される', (tester) async {
      final allAllergies = AllergyType.values;
      final scout = _makeScout(allergies: allAllergies);
      await tester.pumpWidget(_wrap(Scaffold(
        body: SingleChildScrollView(
          child: Wrap(
            children: scout.allergies
                .map((a) => Chip(label: Text(a.label)))
                .toList(),
          ),
        ),
      )));
      expect(find.text('鶏卵'), findsOneWidget);
      expect(find.text('牛乳・乳製品'), findsOneWidget);
      expect(find.text('小麦'), findsOneWidget);
      expect(find.text('ソバ'), findsOneWidget);
      expect(find.text('ピーナッツ'), findsOneWidget);
      expect(find.text('甲殻類'), findsOneWidget);
      expect(find.text('木の実類'), findsOneWidget);
      expect(find.text('果物類'), findsOneWidget);
      expect(find.text('魚類'), findsOneWidget);
      expect(find.text('肉類'), findsOneWidget);
      expect(find.text('その他'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(allAllergies.length));
    });
  });

  // ─── 出席ステータスアイコン ──────────────────────────────────
  group('出席ステータス表示', () {
    Widget attendanceIcon(AttendanceStatus status) {
      final icon = switch (status) {
        AttendanceStatus.present => Icons.check_circle,
        AttendanceStatus.absent  => Icons.cancel,
        AttendanceStatus.pending => Icons.remove_circle_outline,
      };
      return Icon(icon);
    }

    testWidgets('present のラベルは「出席」', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(AttendanceStatus.present.label),
      )));
      expect(find.text('出席'), findsOneWidget);
    });

    testWidgets('absent のラベルは「欠席」', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(AttendanceStatus.absent.label),
      )));
      expect(find.text('欠席'), findsOneWidget);
    });

    testWidgets('pending のラベルは「未定」', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Text(AttendanceStatus.pending.label),
      )));
      expect(find.text('未定'), findsOneWidget);
    });

    testWidgets('出席アイコンがレンダリングされる', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: attendanceIcon(AttendanceStatus.present),
      )));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('欠席アイコンがレンダリングされる', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: attendanceIcon(AttendanceStatus.absent),
      )));
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('未定アイコンがレンダリングされる', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: attendanceIcon(AttendanceStatus.pending),
      )));
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });
  });

  // ─── 未保存変更確認ダイアログ ────────────────────────────────
  group('未保存変更確認ダイアログ', () {
    // 実際のPopScopeは画面遷移を伴うため、ダイアログのUIのみ検証する
    Widget _unsavedDialog(BuildContext ctx) => AlertDialog(
          title: const Text('変更を破棄しますか？'),
          content: const Text('保存されていない変更があります。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('破棄する'),
            ),
          ],
        );

    testWidgets('未保存ダイアログが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => showDialog(
            context: ctx,
            builder: _unsavedDialog,
          ),
          child: const Text('戻る'),
        )),
      )));
      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      expect(find.text('変更を破棄しますか？'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('破棄する'), findsOneWidget);
    });

    testWidgets('キャンセルでダイアログが閉じる', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => showDialog(
            context: ctx,
            builder: _unsavedDialog,
          ),
          child: const Text('戻る'),
        )),
      )));
      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('変更を破棄しますか？'), findsNothing);
    });
  });

  // ─── 皆勤賞「該当なし」表示 ──────────────────────────────────
  group('皆勤賞「該当なし」表示', () {
    testWidgets('該当スカウトがいない場合のメッセージが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48),
            SizedBox(height: 8),
            Text('皆勤賞に該当するスカウトはいません'),
          ],
        )),
      )));
      expect(find.text('皆勤賞に該当するスカウトはいません'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });
  });

  // ─── 進捗バー ─────────────────────────────────────────────
  group('木の葉章進捗バー', () {
    testWidgets('10枚中5枚で50%の進捗', (tester) async {
      final scout = _makeScout(leafBadges: 5);
      final progress = (scout.totalLeafBadges % 10) / 10.0;

      await tester.pumpWidget(_wrap(Scaffold(
        body: Column(children: [
          LinearProgressIndicator(value: progress),
          Text('${scout.totalLeafBadges % 10}/10'),
        ]),
      )));

      expect(find.text('5/10'), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicator.value, 0.5);
    });

    testWidgets('10枚達成で進捗0にリセット', (tester) async {
      final scout = _makeScout(leafBadges: 10, twigBadges: 1);
      final progress = (scout.totalLeafBadges % 10) / 10.0;

      await tester.pumpWidget(_wrap(Scaffold(
        body: Text('${scout.totalLeafBadges % 10}/10'),
      )));

      expect(find.text('0/10'), findsOneWidget);
      expect(progress, 0.0);
    });
  });
}
