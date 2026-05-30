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
  ScoutCategory category = ScoutCategory.beaver,
  List<AllergyType> allergies = const [],
  String? specialNotes,
  DateTime? birthday,
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
    allergies: allergies,
    specialNotes: specialNotes,
    birthday: birthday,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

// シンプルなウィジェットをProviderScopeでラップするヘルパー
Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

// ─── _GenderRadio風のテスト用ウィジェット ─────────────────────

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
    Widget _statusChip(EventStatus status) {
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
        body: _statusChip(EventStatus.planned),
      )));
      expect(find.text('予定'), findsOneWidget);
    });

    testWidgets('完了ステータスのラベルが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: _statusChip(EventStatus.completed),
      )));
      expect(find.text('完了'), findsOneWidget);
    });

    testWidgets('非開催ステータスのラベルが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: _statusChip(EventStatus.cancelled),
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
            ? FilledButton(
                onPressed: () {},
                child: const Text('授与'),
              )
            : const Text('授与待ちなし'),
      )));
      expect(find.text('授与'), findsOneWidget);
    });

    testWidgets('授与待ちがない場合ボタンが表示されない', (tester) async {
      final scout = _makeScout(leafBadges: 9, twigBadges: 0);
      final pending = scout.pendingTwigBadges;

      await tester.pumpWidget(_wrap(Scaffold(
        body: pending > 0
            ? FilledButton(
                onPressed: () {},
                child: const Text('授与'),
              )
            : const Text('授与待ちなし'),
      )));
      expect(find.text('授与待ちなし'), findsOneWidget);
      expect(find.text('授与'), findsNothing);
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
