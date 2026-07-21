import 'package:flutter_test/flutter_test.dart';
import 'package:boyscout_app/data/models/models.dart';
import 'package:boyscout_app/core/constants/app_constants.dart';
import 'package:boyscout_app/core/wbgt_prefecture_master.dart';

// 熱中症危険度判定（heat-alerts-sync Edge Function の classifyLevel をDartで再現）
String classifyHeatLevel(double wbgt) {
  if (wbgt >= 31) return 'danger';
  if (wbgt >= 28) return 'severe_caution';
  if (wbgt >= 25) return 'caution_high';
  if (wbgt >= 21) return 'caution';
  return 'safe';
}

// fiscal year helper (copied from events_page.dart)
int fiscalYear(DateTime date) =>
    date.month >= 4 ? date.year : date.year - 1;

/// 出席率計算（getRates の純粋関数版）
/// 分子: present数、分母: present+absent数（未定は含まない）
double calcAttendanceRate(int present, int total) {
  if (total == 0) return 0.0;
  return present / total;
}

/// 皆勤賞判定（getPerfectAttendance の純粋関数版）
/// eventIds: 対象の確定済みイベントIDリスト
/// attendances: {scoutId: [出席したeventIdのSet]}
bool isPerfectAttendance({
  required String scoutId,
  required List<String> eventIds,
  required Map<String, Set<String>> presentEventsByScout,
}) {
  if (eventIds.isEmpty) return false;
  final present = presentEventsByScout[scoutId] ?? {};
  return eventIds.every((id) => present.contains(id));
}

Scout _makeScout({
  int leafBadges = 0,
  int leafBadgeOffset = 0,
  int twigBadges = 0,
  int otherBadges = 0,
  ScoutCategory category = ScoutCategory.beaver,
  DateTime? birthday,
  DateTime? joinedAt,
}) {
  final now = DateTime.now();
  return Scout(
    id: 'test-id',
    troopId: 'troop-id',
    name: 'テスト スカウト',
    category: category,
    leafBadges: leafBadges,
    leafBadgeOffset: leafBadgeOffset,
    twigBadges: twigBadges,
    otherBadges: otherBadges,
    birthday: birthday,
    joinedAt: joinedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // ─── Scout.totalLeafBadges ─────────────────────────────────
  group('Scout.totalLeafBadges', () {
    test('補正なしの場合は活動取得枚数がそのまま合計になる', () {
      final scout = _makeScout(leafBadges: 15, leafBadgeOffset: 0);
      expect(scout.totalLeafBadges, 15);
    });

    test('補正枚数は合計から減算される', () {
      final scout = _makeScout(leafBadges: 15, leafBadgeOffset: 5);
      expect(scout.totalLeafBadges, 10);
    });

    test('補正枚数が活動取得より多い場合は負になる', () {
      final scout = _makeScout(leafBadges: 3, leafBadgeOffset: 5);
      expect(scout.totalLeafBadges, -2);
    });

    test('両方0の場合は0', () {
      final scout = _makeScout(leafBadges: 0, leafBadgeOffset: 0);
      expect(scout.totalLeafBadges, 0);
    });
  });

  // ─── Scout.pendingTwigBadges ───────────────────────────────
  group('Scout.pendingTwigBadges', () {
    test('10枚で小枝章1本授与待ち', () {
      final scout = _makeScout(leafBadges: 10, twigBadges: 0);
      expect(scout.pendingTwigBadges, 1);
    });

    test('9枚では授与待ちなし', () {
      final scout = _makeScout(leafBadges: 9, twigBadges: 0);
      expect(scout.pendingTwigBadges, 0);
    });

    test('25枚で2本授与待ち（1本授与済み）', () {
      final scout = _makeScout(leafBadges: 25, twigBadges: 1);
      expect(scout.pendingTwigBadges, 1);
    });

    test('補正を考慮して計算される', () {
      // 活動15枚 - 補正5枚 = 合計10枚 → 1本授与待ち
      final scout = _makeScout(leafBadges: 15, leafBadgeOffset: 5, twigBadges: 0);
      expect(scout.pendingTwigBadges, 1);
    });

    test('すべて授与済みの場合は0', () {
      final scout = _makeScout(leafBadges: 20, twigBadges: 2);
      expect(scout.pendingTwigBadges, 0);
    });

    test('30枚で3本授与待ち（0本授与済み）', () {
      final scout = _makeScout(leafBadges: 30, twigBadges: 0);
      expect(scout.pendingTwigBadges, 3);
    });

    test('30枚で1本授与待ち（2本授与済み）', () {
      final scout = _makeScout(leafBadges: 30, twigBadges: 2);
      expect(scout.pendingTwigBadges, 1);
    });
  });

  // ─── Scout.pendingOtherBadges ──────────────────────────────
  group('Scout.pendingOtherBadges（他分類用）', () {
    // otherBadges = leafBadges ~/ 10 - otherBadges（offsetなし）
    test('10枚で1本待ち', () {
      final scout = _makeScout(leafBadges: 10, otherBadges: 0,
          category: ScoutCategory.provisional);
      expect(scout.pendingOtherBadges, 1);
    });

    test('9枚では待ちなし', () {
      final scout = _makeScout(leafBadges: 9, otherBadges: 0,
          category: ScoutCategory.provisional);
      expect(scout.pendingOtherBadges, 0);
    });

    test('20枚で2本待ち（0本授与済み）', () {
      final scout = _makeScout(leafBadges: 20, otherBadges: 0,
          category: ScoutCategory.experience);
      expect(scout.pendingOtherBadges, 2);
    });

    test('20枚で1本待ち（1本授与済み）', () {
      final scout = _makeScout(leafBadges: 20, otherBadges: 1,
          category: ScoutCategory.sibling);
      expect(scout.pendingOtherBadges, 1);
    });

    test('leafBadgeOffsetはotherBadgesに影響しない', () {
      // otherBadges = leafBadges ~/ 10 （offsetを使わない）
      final scout = _makeScout(leafBadges: 15, leafBadgeOffset: 5, otherBadges: 0,
          category: ScoutCategory.provisional);
      expect(scout.pendingOtherBadges, 1); // 15 ~/ 10 = 1
    });
  });

  // ─── 小枝章 N本まとめて授与のロジック ─────────────────────
  group('小枝章 N本まとめて授与', () {
    test('授与後に twigBadges が pendingTwigBadges 分増加する', () {
      // 30枚取得・0本授与済み → 3本待ち
      final before = _makeScout(leafBadges: 30, twigBadges: 0);
      expect(before.pendingTwigBadges, 3);

      final after = _makeScout(leafBadges: 30, twigBadges: before.twigBadges + before.pendingTwigBadges);
      expect(after.twigBadges, 3);
      expect(after.pendingTwigBadges, 0);
    });

    test('1本授与済みの状態から残り2本を授与すると合計3本になる', () {
      final before = _makeScout(leafBadges: 30, twigBadges: 1);
      expect(before.pendingTwigBadges, 2);

      final after = _makeScout(leafBadges: 30, twigBadges: before.twigBadges + before.pendingTwigBadges);
      expect(after.twigBadges, 3);
      expect(after.pendingTwigBadges, 0);
    });

    test('授与後に pendingTwigBadges が必ず 0 になる', () {
      for (final leafBadges in [10, 20, 30, 45, 100]) {
        final before = _makeScout(leafBadges: leafBadges, twigBadges: 0);
        final pending = before.pendingTwigBadges;
        final after = _makeScout(leafBadges: leafBadges, twigBadges: before.twigBadges + pending);
        expect(after.pendingTwigBadges, 0,
            reason: 'leafBadges=$leafBadges のとき授与後に pending が残ってはいけない');
      }
    });
  });

  // ─── Scout.isTwigBadgeEligible ─────────────────────────────
  group('Scout.isTwigBadgeEligible', () {
    test('ビーバーは小枝章対象', () {
      final scout = _makeScout(category: ScoutCategory.beaver);
      expect(scout.isTwigBadgeEligible, true);
    });

    test('ビッグビーバーは小枝章対象', () {
      final scout = _makeScout(category: ScoutCategory.bigBeaver);
      expect(scout.isTwigBadgeEligible, true);
    });

    test('仮入隊は小枝章対象外', () {
      final scout = _makeScout(category: ScoutCategory.provisional);
      expect(scout.isTwigBadgeEligible, false);
    });

    test('体験は小枝章対象外', () {
      final scout = _makeScout(category: ScoutCategory.experience);
      expect(scout.isTwigBadgeEligible, false);
    });

    test('兄弟姉妹は小枝章対象外', () {
      final scout = _makeScout(category: ScoutCategory.sibling);
      expect(scout.isTwigBadgeEligible, false);
    });

    test('上進は小枝章対象外', () {
      final scout = _makeScout(category: ScoutCategory.promoted);
      expect(scout.isTwigBadgeEligible, false);
    });

    test('退団は小枝章対象外', () {
      final scout = _makeScout(category: ScoutCategory.withdrawn);
      expect(scout.isTwigBadgeEligible, false);
    });
  });

  // ─── ScoutCategory.isDefaultAttendee ───────────────────────
  group('ScoutCategory.isDefaultAttendee', () {
    test('ビーバーはデフォルト出席', () {
      expect(ScoutCategory.beaver.isDefaultAttendee, true);
    });

    test('ビッグビーバーはデフォルト出席', () {
      expect(ScoutCategory.bigBeaver.isDefaultAttendee, true);
    });

    test('仮入隊はデフォルト出席', () {
      expect(ScoutCategory.provisional.isDefaultAttendee, true);
    });

    test('体験はデフォルト出席でない（コードの実装通り）', () {
      // SPECでは○だがコードは false → コードの実態を記録
      expect(ScoutCategory.experience.isDefaultAttendee, false);
    });

    test('兄弟姉妹はデフォルト出席でない（コードの実装通り）', () {
      // SPECでは○だがコードは false → コードの実態を記録
      expect(ScoutCategory.sibling.isDefaultAttendee, false);
    });

    test('上進はデフォルト出席でない', () {
      expect(ScoutCategory.promoted.isDefaultAttendee, false);
    });

    test('退団はデフォルト出席でない', () {
      expect(ScoutCategory.withdrawn.isDefaultAttendee, false);
    });

    test('入隊せずはデフォルト出席でない', () {
      expect(ScoutCategory.notJoined.isDefaultAttendee, false);
    });
  });

  // ─── UserRole ──────────────────────────────────────────────
  group('UserRole', () {
    test('leader は canEdit = true', () {
      expect(UserRole.leader.canEdit, true);
    });

    test('assistantLeader は canEdit = true', () {
      expect(UserRole.assistantLeader.canEdit, true);
    });

    test('support は canEdit = false', () {
      expect(UserRole.support.canEdit, false);
    });

    test('leader のみ canManageUsers = true', () {
      expect(UserRole.leader.canManageUsers, true);
      expect(UserRole.assistantLeader.canManageUsers, false);
      expect(UserRole.support.canManageUsers, false);
    });

    test('fromValue: leader', () {
      expect(UserRole.fromValue('leader'), UserRole.leader);
    });

    test('fromValue: assistant_leader', () {
      expect(UserRole.fromValue('assistant_leader'), UserRole.assistantLeader);
    });

    test('不明な値は support にフォールバック', () {
      expect(UserRole.fromValue('unknown'), UserRole.support);
    });
  });

  // ─── EventStatus.fromValue ─────────────────────────────────
  group('EventStatus.fromValue', () {
    test('planned を正しく変換', () {
      expect(EventStatus.fromValue('planned'), EventStatus.planned);
    });

    test('completed を正しく変換', () {
      expect(EventStatus.fromValue('completed'), EventStatus.completed);
    });

    test('cancelled を正しく変換', () {
      expect(EventStatus.fromValue('cancelled'), EventStatus.cancelled);
    });

    test('不明な値は planned にフォールバック', () {
      expect(EventStatus.fromValue('unknown'), EventStatus.planned);
    });
  });

  // ─── EventStatus.label ─────────────────────────────────────
  group('EventStatus.label', () {
    test('planned のラベルは「予定」', () {
      expect(EventStatus.planned.label, '予定');
    });

    test('completed のラベルは「実施済」（DB=completed、表示=実施済）', () {
      // NOTE: SPECには「確定」と書かれているが、コードの実装は「実施済」
      // SPEC側を要確認
      expect(EventStatus.completed.label, '実施済');
    });

    test('cancelled のラベルは「非開催」', () {
      expect(EventStatus.cancelled.label, '非開催');
    });
  });

  // ─── AllergyType ───────────────────────────────────────────
  group('AllergyType.fromValue', () {
    test('egg を正しく変換', () {
      expect(AllergyType.fromValue('egg'), AllergyType.egg);
    });

    test('dairy を正しく変換', () {
      expect(AllergyType.fromValue('dairy'), AllergyType.dairy);
    });

    test('wheat を正しく変換', () {
      expect(AllergyType.fromValue('wheat'), AllergyType.wheat);
    });

    test('不明な値は other にフォールバック', () {
      expect(AllergyType.fromValue('unknown'), AllergyType.other);
    });
  });

  // ─── Scout アレルギーパース ────────────────────────────────
  group('Scout アレルギーパース', () {
    test('カンマ区切りの文字列を正しくパース', () {
      final now = DateTime.now();
      final scout = Scout.fromMap({
        'id': 'id', 'troop_id': 'tid', 'name': 'テスト',
        'category': 'beaver', 'allergies': 'egg,dairy,wheat',
        'leaf_badges': 0, 'leaf_badge_offset': 0, 'twig_badges': 0,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(scout.allergies, [AllergyType.egg, AllergyType.dairy, AllergyType.wheat]);
    });

    test('アレルギーなしの場合は空リスト', () {
      final now = DateTime.now();
      final scout = Scout.fromMap({
        'id': 'id', 'troop_id': 'tid', 'name': 'テスト',
        'category': 'beaver', 'allergies': null,
        'leaf_badges': 0, 'leaf_badge_offset': 0, 'twig_badges': 0,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(scout.allergies, isEmpty);
    });

    test('空文字列の場合も空リスト', () {
      final now = DateTime.now();
      final scout = Scout.fromMap({
        'id': 'id', 'troop_id': 'tid', 'name': 'テスト',
        'category': 'beaver', 'allergies': '',
        'leaf_badges': 0, 'leaf_badge_offset': 0, 'twig_badges': 0,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(scout.allergies, isEmpty);
    });

    test('全アレルギー種別を含む文字列をパース', () {
      final now = DateTime.now();
      final scout = Scout.fromMap({
        'id': 'id', 'troop_id': 'tid', 'name': 'テスト',
        'category': 'beaver',
        'allergies': 'egg,dairy,wheat,soba,peanut,shellfish,tree_nut,fruit,fish,meat,other',
        'leaf_badges': 0, 'leaf_badge_offset': 0, 'twig_badges': 0,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(scout.allergies.length, AllergyType.values.length);
    });
  });

  // ─── Scout toMap / fromMap ラウンドトリップ ───────────────
  group('Scout toMap/fromMap ラウンドトリップ', () {
    test('基本フィールドが往復変換で一致する', () {
      final now = DateTime(2025, 6, 1, 12, 0, 0);
      final original = Scout(
        id: 'abc-123',
        troopId: 'troop-456',
        name: '田中 花子',
        gender: 'female',
        grade: '小1',
        category: ScoutCategory.bigBeaver,
        leafBadges: 15,
        leafBadgeOffset: 5,
        twigBadges: 1,
        otherBadges: 0,
        allergies: [AllergyType.egg, AllergyType.wheat],
        specialNotes: '特記事項あり',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      final restored = Scout.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.category, original.category);
      expect(restored.leafBadges, original.leafBadges);
      expect(restored.leafBadgeOffset, original.leafBadgeOffset);
      expect(restored.twigBadges, original.twigBadges);
      expect(restored.allergies, original.allergies);
      expect(restored.specialNotes, original.specialNotes);
      expect(restored.isActive, original.isActive);
    });

    test('アレルギーなしの場合も往復変換できる', () {
      final now = DateTime.now();
      final original = Scout(
        id: 'id1', troopId: 'tid', name: '鈴木 次郎',
        category: ScoutCategory.beaver,
        allergies: [],
        leafBadges: 0, leafBadgeOffset: 0, twigBadges: 0,
        createdAt: now, updatedAt: now,
      );
      final map = original.toMap();
      final restored = Scout.fromMap(map);
      expect(restored.allergies, isEmpty);
    });

    test('is_active=0 で isActive=false になる', () {
      final now = DateTime.now();
      final scout = Scout.fromMap({
        'id': 'id', 'troop_id': 'tid', 'name': 'テスト',
        'category': 'promoted',
        'leaf_badges': 0, 'leaf_badge_offset': 0, 'twig_badges': 0,
        'is_active': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(scout.isActive, false);
    });
  });

  // ─── 出席率計算 ────────────────────────────────────────────
  group('出席率計算（calcAttendanceRate）', () {
    test('出席3 / 合計3 = 100%', () {
      expect(calcAttendanceRate(3, 3), 1.0);
    });

    test('出席1 / 合計2 = 50%', () {
      expect(calcAttendanceRate(1, 2), 0.5);
    });

    test('出席0 / 合計3 = 0%', () {
      expect(calcAttendanceRate(0, 3), 0.0);
    });

    test('合計0のとき 0%（ゼロ除算しない）', () {
      expect(calcAttendanceRate(0, 0), 0.0);
    });

    test('未定は分母に含まない（present=2, total=3 は pending1件分を除いた結果）', () {
      // present=2（出席2件）、absent=1（欠席1件）、pending=1（未定）
      // → total=3 (2+1)、rate=2/3
      expect(calcAttendanceRate(2, 3), closeTo(0.667, 0.001));
    });
  });

  // ─── 皆勤賞判定 ────────────────────────────────────────────
  group('皆勤賞判定（isPerfectAttendance）', () {
    test('全イベントに出席していれば皆勤', () {
      expect(isPerfectAttendance(
        scoutId: 's1',
        eventIds: ['e1', 'e2', 'e3'],
        presentEventsByScout: {'s1': {'e1', 'e2', 'e3'}},
      ), true);
    });

    test('1イベントでも欠席があれば皆勤でない', () {
      expect(isPerfectAttendance(
        scoutId: 's1',
        eventIds: ['e1', 'e2', 'e3'],
        presentEventsByScout: {'s1': {'e1', 'e2'}},
      ), false);
    });

    test('出席記録がまったくない場合は皆勤でない', () {
      expect(isPerfectAttendance(
        scoutId: 's1',
        eventIds: ['e1', 'e2'],
        presentEventsByScout: {},
      ), false);
    });

    test('確定済みイベントが0件の場合は皆勤でない', () {
      expect(isPerfectAttendance(
        scoutId: 's1',
        eventIds: [],
        presentEventsByScout: {'s1': {'e1'}},
      ), false);
    });

    test('出席が多くても対象イベント外は無関係', () {
      // e9（別のイベント）の出席は評価に影響しない
      expect(isPerfectAttendance(
        scoutId: 's1',
        eventIds: ['e1', 'e2'],
        presentEventsByScout: {'s1': {'e1', 'e2', 'e9'}},
      ), true);
    });

    test('別のスカウトの出席は自分の皆勤に影響しない', () {
      expect(isPerfectAttendance(
        scoutId: 's1',
        eventIds: ['e1', 'e2'],
        presentEventsByScout: {
          's1': {'e1'}, // s1はe2欠席
          's2': {'e1', 'e2'},
        },
      ), false);
    });
  });

  // ─── LeafBadgeType ─────────────────────────────────────────
  group('LeafBadgeType', () {
    test('全5種別が存在する', () {
      expect(LeafBadgeType.values.length, 5);
    });

    test('fromValue: health', () {
      expect(LeafBadgeType.fromValue('health'), LeafBadgeType.health);
    });

    test('fromValue: society', () {
      expect(LeafBadgeType.fromValue('society'), LeafBadgeType.society);
    });

    test('不明な値は health にフォールバック', () {
      expect(LeafBadgeType.fromValue('unknown'), LeafBadgeType.health);
    });

    test('各種別のラベルが正しい', () {
      expect(LeafBadgeType.health.label, '健康');
      expect(LeafBadgeType.expression.label, '表現');
      expect(LeafBadgeType.life.label, '生活');
      expect(LeafBadgeType.nature.label, '自然');
      expect(LeafBadgeType.society.label, '社会');
    });
  });

  // ─── 年度計算 ───────────────────────────────────────────────
  group('fiscalYear（4月始まり）', () {
    test('4月は同年の年度', () {
      expect(fiscalYear(DateTime(2025, 4, 1)), 2025);
    });

    test('3月は前年の年度', () {
      expect(fiscalYear(DateTime(2026, 3, 31)), 2025);
    });

    test('1月は前年の年度', () {
      expect(fiscalYear(DateTime(2026, 1, 1)), 2025);
    });

    test('12月は同年の年度', () {
      expect(fiscalYear(DateTime(2025, 12, 31)), 2025);
    });

    test('3月31日は前年度', () {
      expect(fiscalYear(DateTime(2025, 3, 31)), 2024);
    });

    test('4月1日は当年度', () {
      expect(fiscalYear(DateTime(2025, 4, 1)), 2025);
    });
  });

  // ─── CommitteeCategory ─────────────────────────────────────
  group('CommitteeCategory.fromValue', () {
    test('committee を正しく変換', () {
      expect(CommitteeCategory.fromValue('committee'), CommitteeCategory.committee);
    });

    test('ob を正しく変換', () {
      expect(CommitteeCategory.fromValue('ob'), CommitteeCategory.ob);
    });

    test('不明な値は other にフォールバック', () {
      expect(CommitteeCategory.fromValue('unknown'), CommitteeCategory.other);
    });
  });

  // ─── MemberType ────────────────────────────────────────────
  group('MemberType', () {
    test('scout を正しく変換', () {
      expect(MemberType.fromValue('scout'), MemberType.scout);
    });

    test('user（リーダー）を正しく変換', () {
      expect(MemberType.fromValue('user'), MemberType.user);
    });

    test('不明な値は other にフォールバック', () {
      expect(MemberType.fromValue('unknown'), MemberType.other);
    });
  });

  // ─── AttendanceStatus ──────────────────────────────────────
  group('AttendanceStatus', () {
    test('present を正しく変換', () {
      expect(AttendanceStatus.fromValue('present'), AttendanceStatus.present);
    });

    test('absent を正しく変換', () {
      expect(AttendanceStatus.fromValue('absent'), AttendanceStatus.absent);
    });

    test('pending を正しく変換', () {
      expect(AttendanceStatus.fromValue('pending'), AttendanceStatus.pending);
    });

    test('不明な値は pending にフォールバック', () {
      expect(AttendanceStatus.fromValue('unknown'), AttendanceStatus.pending);
    });
  });

  // ─── 熱中症アラート： Troop toMap/fromMap ラウンドトリップ ───
  group('Troop toMap/fromMap ラウンドトリップ（熱中症アラート項目）', () {
    test('prefectureCode/pointCode が往復変換で一致する', () {
      final now = DateTime(2026, 7, 1, 9, 0, 0);
      final original = Troop(
        id: 'troop-1',
        name: '杉並第3団',
        location: '東京都杉並区',
        contact: '000-0000-0000',
        prefectureCode: '44',
        pointCode: '44132',
        createdAt: now,
        updatedAt: now,
      );
      final map = original.toMap();
      final restored = Troop.fromMap(map);
      expect(restored.prefectureCode, '44');
      expect(restored.pointCode, '44132');
    });

    test('prefectureCode/pointCode が null でも往復変換できる（未設定団）', () {
      final now = DateTime.now();
      final original = Troop(
        id: 'troop-2', name: '未設定団',
        createdAt: now, updatedAt: now,
      );
      final map = original.toMap();
      final restored = Troop.fromMap(map);
      expect(restored.prefectureCode, isNull);
      expect(restored.pointCode, isNull);
    });

    test('copyWith で prefectureCode/pointCode のみ更新できる', () {
      final now = DateTime.now();
      final original = Troop(
        id: 'troop-3', name: 'テスト団',
        createdAt: now, updatedAt: now,
      );
      final updated = original.copyWith(prefectureCode: '44', pointCode: '44172');
      expect(updated.prefectureCode, '44');
      expect(updated.pointCode, '44172');
      expect(updated.name, original.name); // 他の項目は変化しない
    });
  });

  // ─── 熱中症アラート： wbgtPrefectureMaster の整合性 ───
  group('wbgtPrefectureMaster', () {
    test('47都道府県すべてが含まれている', () {
      expect(wbgtPrefectureMaster.length, 47);
    });

    test('prefCodeは重複しない', () {
      final codes = wbgtPrefectureMaster.map((p) => p.prefCode).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('各都道府県に少なくとも1地点は存在する', () {
      for (final pref in wbgtPrefectureMaster) {
        expect(pref.points, isNotEmpty, reason: '${pref.prefName} に地点がない');
      }
    });

    test('地点番号（pointCode）は全体で重複しない', () {
      final allCodes = wbgtPrefectureMaster.expand((p) => p.points).map((pt) => pt.pointCode).toList();
      expect(allCodes.toSet().length, allCodes.length);
    });

    test('東京都は本土・大島・八丈島・父島の4地点を持ち、デフォルトは東京（44132）', () {
      final tokyo = wbgtPrefectureMaster.firstWhere((p) => p.prefName == '東京都');
      expect(tokyo.points.length, 4);
      expect(tokyo.points.first.pointCode, '44132');
      expect(tokyo.points.map((pt) => pt.pointName), containsAll(['東京', '大島', '八丈島', '父島']));
    });

    test('埼玉県は単一地点（熊谷）のみ', () {
      final saitama = wbgtPrefectureMaster.firstWhere((p) => p.prefName == '埼玉県');
      expect(saitama.points.length, 1);
      expect(saitama.points.first.pointName, '熊谷');
    });

    test('長崎県は本土・対馬・五島の3地点', () {
      final nagasaki = wbgtPrefectureMaster.firstWhere((p) => p.prefName == '長崎県');
      expect(nagasaki.points.length, 3);
    });
  });

  // ─── 熱中症アラート： WBGT危険度判定（classifyHeatLevel） ───
  group('classifyHeatLevel（WBGT危険度判定）', () {
    test('31以上は danger', () {
      expect(classifyHeatLevel(31.0), 'danger');
      expect(classifyHeatLevel(35.0), 'danger');
    });

    test('28以上31未満は severe_caution', () {
      expect(classifyHeatLevel(28.0), 'severe_caution');
      expect(classifyHeatLevel(30.9), 'severe_caution');
    });

    test('25以上28未満は caution_high', () {
      expect(classifyHeatLevel(25.0), 'caution_high');
      expect(classifyHeatLevel(27.9), 'caution_high');
    });

    test('21以上25未満は caution', () {
      expect(classifyHeatLevel(21.0), 'caution');
      expect(classifyHeatLevel(24.9), 'caution');
    });

    test('21未満は safe', () {
      expect(classifyHeatLevel(20.9), 'safe');
      expect(classifyHeatLevel(0.0), 'safe');
    });

    test('境界値が正しく切り替わる（実データ式：東京2026年7月21日分）', () {
      // 実際にデプロイ後に取得できた値（東京 34.0/35.0/33.0/26.0）で確認
      expect(classifyHeatLevel(34.0), 'danger');
      expect(classifyHeatLevel(35.0), 'danger');
      expect(classifyHeatLevel(33.0), 'danger');
      expect(classifyHeatLevel(26.0), 'caution_high');
    });
  });
}
