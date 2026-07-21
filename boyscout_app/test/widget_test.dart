import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boyscout_app/data/models/models.dart';
import 'package:boyscout_app/core/constants/app_constants.dart';
import 'package:boyscout_app/core/wbgt_prefecture_master.dart';

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

// ─── 熱中症アラート： 団情報画面の都道府県→地点 2段階ドロップダウンのテスト用ウィジェット ───
// troop_setup_page.dartの選択ロジックを再現

class _PrefPointDropdownTest extends StatefulWidget {
  final String? initialPref;
  final String? initialPoint;
  const _PrefPointDropdownTest({this.initialPref, this.initialPoint});

  @override
  State<_PrefPointDropdownTest> createState() => _PrefPointDropdownTestState();
}

class _PrefPointDropdownTestState extends State<_PrefPointDropdownTest> {
  String? _prefCode;
  String? _pointCode;

  @override
  void initState() {
    super.initState();
    _prefCode = widget.initialPref;
    _pointCode = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    final pref = wbgtPrefectureMaster.where((e) => e.prefCode == _prefCode);
    final points = pref.isEmpty ? const <WbgtPoint>[] : pref.first.points;
    final enabled = points.length > 1;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        key: const ValueKey('prefDropdown'),
        value: _prefCode,
        decoration: const InputDecoration(labelText: '都道府県'),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('未設定')),
          ...wbgtPrefectureMaster.map(
            (p) => DropdownMenuItem<String>(value: p.prefCode, child: Text(p.prefName)),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _prefCode = v;
            final newPref = wbgtPrefectureMaster.where((e) => e.prefCode == v);
            _pointCode = newPref.isEmpty ? null : newPref.first.points.first.pointCode;
          });
        },
      ),
      DropdownButtonFormField<String>(
        key: const ValueKey('pointDropdown'),
        value: _pointCode,
        decoration: const InputDecoration(labelText: '地点'),
        items: points
            .map((pt) => DropdownMenuItem<String>(value: pt.pointCode, child: Text(pt.pointName)))
            .toList(),
        onChanged: enabled ? (v) => setState(() => _pointCode = v) : null,
      ),
      Text('pref:${_prefCode ?? "none"} point:${_pointCode ?? "none"}'),
    ]);
  }
}

// ─── 熱中症アラート： ダッシュボードの危険度バッジ表示ロジック ───
// dashboard_page.dart の _HeatAlertInfo/_EventListTile の表示ロジックを再現

Color _heatAlertColor(String level) {
  switch (level) {
    case 'danger': return const Color(0xFFD32F2F);
    case 'severe_caution': return const Color(0xFFE65100);
    case 'caution_high': return const Color(0xFFF9A825);
    case 'caution': return const Color(0xFF64B5F6);
    default: return const Color(0xFF9E9E9E);
  }
}

String _heatAlertLabel(String level) {
  switch (level) {
    case 'danger': return '危険';
    case 'severe_caution': return '厳重警戒';
    case 'caution_high': return '警戒';
    case 'caution': return '注意';
    default: return 'ほぼ安全';
  }
}

Widget _heatAlertBadge(String? level) {
  if (level == null || level == 'safe') return const SizedBox.shrink();
  final color = _heatAlertColor(level);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.thermostat, size: 14, color: color),
      const SizedBox(width: 2),
      Text(_heatAlertLabel(level), style: TextStyle(fontSize: 10, color: color)),
    ]),
  );
}

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

  // ─── ロール別UI表示制御 ────────────────────────────────────
  // 設定画面・FAB・詳細画面の編集削除ボタンをロール別にWidgetで検証。
  // Supabase不要：ロール文字列を直接渡してUIを構築する。

  // 設定メニューの表示制御を再現するヘルパーWidget
  Widget _settingsMenu(String role) {
    final isAdmin = role == 'admin';
    final isLimited = role == 'limited';
    return _wrap(Scaffold(
      body: ListView(children: [
        if (!isLimited) const ListTile(title: Text('団情報')),
        const ListTile(title: Text('リーダー')),
        if (!isLimited) ...[
          const ListTile(title: Text('保護者')),
          const ListTile(title: Text('団委員ほか')),
          const ListTile(title: Text('電話帳')),
          const ListTile(title: Text('アレルギー情報')),
          const ListTile(title: Text('レポート出力')),
          const ListTile(title: Text('使い方')),
        ],
        if (isAdmin) ...[
          const ListTile(title: Text('利用者管理')),
          const ListTile(title: Text('招待コード')),
          const ListTile(title: Text('バッチ登録')),
        ],
        const ListTile(title: Text('アカウントを削除する')),
        const ListTile(title: Text('バージョン情報')),
      ]),
    ));
  }

  // FABの表示制御を再現するヘルパーWidget
  Widget _scoutPageFab(String role) {
    final isLimited = role == 'limited';
    return _wrap(Scaffold(
      body: const SizedBox(),
      floatingActionButton: !isLimited
          ? const FloatingActionButton(onPressed: null, child: Icon(Icons.add))
          : null,
    ));
  }

  // 詳細画面右上の編集・削除ボタンを再現するヘルパーWidget
  Widget _detailAppBar(String role) {
    final isLimited = role == 'limited';
    return _wrap(Scaffold(
      appBar: AppBar(
        title: const Text('詳細'),
        actions: [
          if (!isLimited) ...[
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: null),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: null),
          ],
        ],
      ),
    ));
  }

  group('ロール別UI: 設定メニュー', () {
    testWidgets('admin: 全メニューが表示される', (tester) async {
      await tester.pumpWidget(_settingsMenu('admin'));
      expect(find.text('団情報'), findsOneWidget);
      expect(find.text('リーダー'), findsOneWidget);
      expect(find.text('保護者'), findsOneWidget);
      expect(find.text('団委員ほか'), findsOneWidget);
      expect(find.text('電話帳'), findsOneWidget);
      expect(find.text('アレルギー情報'), findsOneWidget);
      expect(find.text('レポート出力'), findsOneWidget);
      expect(find.text('使い方'), findsOneWidget);
      expect(find.text('利用者管理'), findsOneWidget);
      expect(find.text('招待コード'), findsOneWidget);
      expect(find.text('バッチ登録'), findsOneWidget);
    });

    testWidgets('member: 管理者専用メニューが非表示', (tester) async {
      await tester.pumpWidget(_settingsMenu('member'));
      expect(find.text('団情報'), findsOneWidget);
      expect(find.text('リーダー'), findsOneWidget);
      expect(find.text('保護者'), findsOneWidget);
      expect(find.text('電話帳'), findsOneWidget);
      expect(find.text('利用者管理'), findsNothing);
      expect(find.text('招待コード'), findsNothing);
      expect(find.text('バッチ登録'), findsNothing);
    });

    testWidgets('limited: 閲覧限定メニューのみ表示', (tester) async {
      await tester.pumpWidget(_settingsMenu('limited'));
      expect(find.text('リーダー'), findsOneWidget);
      expect(find.text('団情報'), findsNothing);
      expect(find.text('保護者'), findsNothing);
      expect(find.text('団委員ほか'), findsNothing);
      expect(find.text('電話帳'), findsNothing);
      expect(find.text('アレルギー情報'), findsNothing);
      expect(find.text('レポート出力'), findsNothing);
      expect(find.text('使い方'), findsNothing);
      expect(find.text('利用者管理'), findsNothing);
      expect(find.text('招待コード'), findsNothing);
      expect(find.text('バッチ登録'), findsNothing);
    });
  });

  group('ロール別UI: FAB', () {
    testWidgets('admin: FABが表示される', (tester) async {
      await tester.pumpWidget(_scoutPageFab('admin'));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('member: FABが表示される', (tester) async {
      await tester.pumpWidget(_scoutPageFab('member'));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('limited: FABが非表示', (tester) async {
      await tester.pumpWidget(_scoutPageFab('limited'));
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('ロール別UI: 詳細画面の編集・削除ボタン', () {
    testWidgets('admin: 編集・削除ボタンが表示される', (tester) async {
      await tester.pumpWidget(_detailAppBar('admin'));
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('member: 編集・削除ボタンが表示される', (tester) async {
      await tester.pumpWidget(_detailAppBar('member'));
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('limited: 編集・削除ボタンが非表示', (tester) async {
      await tester.pumpWidget(_detailAppBar('limited'));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  // ─── ロール別UI: タップ反応 ───────────────────────────────────────
  // 編集・削除ボタンは表示の有無だけでなく、タップで実際にコールバックが呼ばれるかも検証する。
  // FABの onPressed も同様に検証する。

  // 編集・削除ボタンのタップ反応を検証するヘルパーWidget
  Widget _detailAppBarWithCallbacks(String role, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final isLimited = role == 'limited';
    return _wrap(Scaffold(
      appBar: AppBar(
        title: const Text('詳細'),
        actions: [
          if (!isLimited) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    ));
  }

  // FABのタップ反応を検証するヘルパーWidget
  Widget _scoutPageFabWithCallback(String role, {required VoidCallback onTap}) {
    final isLimited = role == 'limited';
    return _wrap(Scaffold(
      body: const SizedBox(),
      floatingActionButton: !isLimited
          ? FloatingActionButton(onPressed: onTap, child: const Icon(Icons.add))
          : null,
    ));
  }

  group('ロール別UI: タップ反応', () {
    testWidgets('admin: 編集ボタンタップでコールバックが呼ばれる', (tester) async {
      bool editCalled = false;
      bool deleteCalled = false;
      await tester.pumpWidget(_detailAppBarWithCallbacks(
        'admin',
        onEdit: () => editCalled = true,
        onDelete: () => deleteCalled = true,
      ));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(editCalled, isTrue);
      expect(deleteCalled, isTrue);
    });

    testWidgets('member: 編集ボタンタップでコールバックが呼ばれる', (tester) async {
      bool editCalled = false;
      bool deleteCalled = false;
      await tester.pumpWidget(_detailAppBarWithCallbacks(
        'member',
        onEdit: () => editCalled = true,
        onDelete: () => deleteCalled = true,
      ));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(editCalled, isTrue);
      expect(deleteCalled, isTrue);
    });

    testWidgets('limited: ボタンがないのでタップしてもコールバックが呼ばれない', (tester) async {
      bool editCalled = false;
      bool deleteCalled = false;
      await tester.pumpWidget(_detailAppBarWithCallbacks(
        'limited',
        onEdit: () => editCalled = true,
        onDelete: () => deleteCalled = true,
      ));
      // ボタン自体が存在しないのでタップが発生しない
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(editCalled, isFalse);
      expect(deleteCalled, isFalse);
    });

    testWidgets('admin: FABタップでコールバックが呼ばれる', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_scoutPageFabWithCallback(
        'admin',
        onTap: () => tapped = true,
      ));
      await tester.tap(find.byType(FloatingActionButton));
      expect(tapped, isTrue);
    });

    testWidgets('member: FABタップでコールバックが呼ばれる', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_scoutPageFabWithCallback(
        'member',
        onTap: () => tapped = true,
      ));
      await tester.tap(find.byType(FloatingActionButton));
      expect(tapped, isTrue);
    });

    testWidgets('limited: FABがないのでタップしてもコールバックが呼ばれない', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_scoutPageFabWithCallback(
        'limited',
        onTap: () => tapped = true,
      ));
      // FAB自体が存在しないのでタップが発生しない
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tapped, isFalse);
    });

    testWidgets('limited: 設定メニューの非表示項目はタップできない', (tester) async {
      bool troopTapped = false;
      bool guardianTapped = false;
      final isLimited = true;
      await tester.pumpWidget(_wrap(Scaffold(
        body: ListView(children: [
          if (!isLimited)
            ListTile(
              title: const Text('団情報'),
              onTap: () => troopTapped = true,
            ),
          const ListTile(title: Text('リーダー')),
          if (!isLimited)
            ListTile(
              title: const Text('保護者'),
              onTap: () => guardianTapped = true,
            ),
        ]),
      )));
      // limitedでは団情報・保護者自体が表示されない
      expect(find.text('団情報'), findsNothing);
      expect(find.text('保護者'), findsNothing);
      expect(troopTapped, isFalse);
      expect(guardianTapped, isFalse);
      // limitedでもリーダーは表示される
      expect(find.text('リーダー'), findsOneWidget);
    });
  });

  // ─── イベント: ステータスボタン ──────────────────────────────────
  // _StatusSelectorのロジックをWidgetとして検証する
  // 選択中・ disabled時はコールバックが呼ばれない

  // _StatusSelector相当のWidgetヘルパー
  Widget _statusSelector({
    required EventStatus current,
    required bool enabled,
    required ValueChanged<EventStatus> onChanged,
  }) {
    return _wrap(Scaffold(
      body: Row(
        children: EventStatus.values.map((s) {
          final isSelected = s == current;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: (isSelected || !enabled) ? null : () => onChanged(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(s.label, textAlign: TextAlign.center),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ));
  }

  group('イベント: ステータスボタン', () {
    testWidgets('く当初「予定」が選択中の場合、他ボタンタップでコールバックが呼ばれる', (tester) async {
      EventStatus? changed;
      await tester.pumpWidget(_statusSelector(
        current: EventStatus.planned,
        enabled: true,
        onChanged: (s) => changed = s,
      ));
      // 「実施済」タップ → コールバック呼び出し
      await tester.tap(find.text('実施済'));
      expect(changed, EventStatus.completed);
    });

    testWidgets('「予定」が選択中の場合、「予定」タップではコールバックが呼ばれない', (tester) async {
      EventStatus? changed;
      await tester.pumpWidget(_statusSelector(
        current: EventStatus.planned,
        enabled: true,
        onChanged: (s) => changed = s,
      ));
      // 同じボタン（選択中）をタップしてもコールバックは呼ばれない
      await tester.tap(find.text('予定'));
      expect(changed, isNull);
    });

    testWidgets('enabled=falseの場合、タップしてもコールバックが呼ばれない（limitedロール相当）', (tester) async {
      EventStatus? changed;
      await tester.pumpWidget(_statusSelector(
        current: EventStatus.planned,
        enabled: false,
        onChanged: (s) => changed = s,
      ));
      await tester.tap(find.text('実施済'));
      await tester.tap(find.text('非開催'));
      expect(changed, isNull);
    });

    testWidgets('全ステータスラベルが表示される', (tester) async {
      await tester.pumpWidget(_statusSelector(
        current: EventStatus.planned,
        enabled: true,
        onChanged: (_) {},
      ));
      expect(find.text('予定'), findsOneWidget);
      expect(find.text('実施済'), findsOneWidget);
      expect(find.text('非開催'), findsOneWidget);
    });
  });

  // ─── イベント: 出席トグル ──────────────────────────────────────
  // _ToggleGroup / _BtnのロジックをWidgetとして検証する
  // onChanged==null（実施済）の場合はタップ不可

  // _ToggleGroup相当のWidgetヘルパー
  Widget _attendanceToggle({
    required AttendanceStatus current,
    ValueChanged<AttendanceStatus>? onChanged,
  }) {
    return _wrap(Scaffold(
      body: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onChanged == null ? null : () => onChanged(AttendanceStatus.present),
          child: const Icon(Icons.check, key: ValueKey('present')),
        ),
        GestureDetector(
          onTap: onChanged == null ? null : () => onChanged(AttendanceStatus.absent),
          child: const Icon(Icons.close, key: ValueKey('absent')),
        ),
        GestureDetector(
          onTap: onChanged == null ? null : () => onChanged(AttendanceStatus.pending),
          child: const Icon(Icons.remove, key: ValueKey('pending')),
        ),
      ]),
    ));
  }

  group('イベント: 出席トグル', () {
    testWidgets('出席ボタンタップで present に変更される', (tester) async {
      AttendanceStatus? changed;
      await tester.pumpWidget(_attendanceToggle(
        current: AttendanceStatus.pending,
        onChanged: (s) => changed = s,
      ));
      await tester.tap(find.byKey(const ValueKey('present')));
      expect(changed, AttendanceStatus.present);
    });

    testWidgets('欠席ボタンタップで absent に変更される', (tester) async {
      AttendanceStatus? changed;
      await tester.pumpWidget(_attendanceToggle(
        current: AttendanceStatus.pending,
        onChanged: (s) => changed = s,
      ));
      await tester.tap(find.byKey(const ValueKey('absent')));
      expect(changed, AttendanceStatus.absent);
    });

    testWidgets('未定ボタンタップで pending に変更される', (tester) async {
      AttendanceStatus? changed;
      await tester.pumpWidget(_attendanceToggle(
        current: AttendanceStatus.present,
        onChanged: (s) => changed = s,
      ));
      await tester.tap(find.byKey(const ValueKey('pending')));
      expect(changed, AttendanceStatus.pending);
    });

    testWidgets('onChanged==null（実施済イベント）はタップしても変更されない', (tester) async {
      AttendanceStatus? changed;
      await tester.pumpWidget(_attendanceToggle(
        current: AttendanceStatus.present,
        onChanged: null, // 実施済は null
      ));
      await tester.tap(find.byKey(const ValueKey('absent')));
      await tester.tap(find.byKey(const ValueKey('pending')));
      expect(changed, isNull);
    });

    testWidgets('limitedロール（onChanged==null）でも同様にタップ不可', (tester) async {
      AttendanceStatus? changed;
      // limitedは isCompletedと同様に onChanged=null として渡す
      await tester.pumpWidget(_attendanceToggle(
        current: AttendanceStatus.pending,
        onChanged: null,
      ));
      await tester.tap(find.byKey(const ValueKey('present')));
      expect(changed, isNull);
    });
  });

  // ─── 熱中症アラート： 団情報画面の都道府県→地点 2段階ドロップダウン ───
  group('熱中症アラート： 都道府県→地点 2段階ドロップダウン', () {
    testWidgets('初期状態では地点ドロップダウンが無効（都道府県未選択）', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _PrefPointDropdownTest(),
      )));
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('pointDropdown')));
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('東京都を選択すると地点がデフォルト（東京）になり、地点ドロップダウンが活性化する', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _PrefPointDropdownTest(initialPref: '44', initialPoint: '44132'),
      )));
      expect(find.text('pref:44 point:44132'), findsOneWidget);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('pointDropdown')));
      expect(dropdown.onChanged, isNotNull); // 東京都は4地点あるので有効
    });

    testWidgets('埼玉県（単一地点）を選択すると地点ドロップダウンは無効のまま（選択肢が1つしかないため）', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _PrefPointDropdownTest(initialPref: '43', initialPoint: '43056'),
      )));
      expect(find.text('pref:43 point:43056'), findsOneWidget);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('pointDropdown')));
      expect(dropdown.onChanged, isNull); // 埼玉県は1地点のみなので無効
    });

    testWidgets('都道府県を変えると地点は新しい都道府県のデフォルトにリセットされる', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: _PrefPointDropdownTest(initialPref: '44', initialPoint: '44172'), // 東京都・大島選択中
      )));
      expect(find.text('pref:44 point:44172'), findsOneWidget);

      // ドロップダウンは47都道府県分あり、実際のオーバーレイUIをタップで開くと
      // 画面外の項目がビルドされずテストが不安定になるため、onChangedを直接呼び出す
      final prefDropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('prefDropdown')));
      prefDropdown.onChanged!('43'); // 埼玉県に変更
      await tester.pumpAndSettle();

      // 埼玉県に変えたら地点はデフォルト（熊谷）にリセットされる
      expect(find.text('pref:43 point:43056'), findsOneWidget);
    });
  });

  group('熱中症アラート： ダッシュボードの危険度バッジ', () {
    testWidgets('level=danger で「危険」バッジが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: _heatAlertBadge('danger'),
      )));
      expect(find.text('危険'), findsOneWidget);
      expect(find.byIcon(Icons.thermostat), findsOneWidget);
    });

    testWidgets('level=caution_high で「警戒」バッジが表示される', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: _heatAlertBadge('caution_high'),
      )));
      expect(find.text('警戒'), findsOneWidget);
    });

    testWidgets('level=safe のときは何も表示されない', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: _heatAlertBadge('safe'),
      )));
      expect(find.byIcon(Icons.thermostat), findsNothing);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('level=null（データなし）のときは何も表示されない', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: _heatAlertBadge(null),
      )));
      expect(find.byIcon(Icons.thermostat), findsNothing);
    });

    testWidgets('全レベルのラベルが正しい', (tester) async {
      for (final entry in {
        'danger': '危険',
        'severe_caution': '厳重警戒',
        'caution_high': '警戒',
        'caution': '注意',
      }.entries) {
        await tester.pumpWidget(_wrap(Scaffold(
          body: _heatAlertBadge(entry.key),
        )));
        expect(find.text(entry.value), findsOneWidget, reason: 'level=${entry.key}');
      }
    });
  });
}
