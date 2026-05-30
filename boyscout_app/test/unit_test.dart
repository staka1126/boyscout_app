import 'package:flutter_test/flutter_test.dart';
import 'package:boyscout_app/data/models/models.dart';
import 'package:boyscout_app/core/constants/app_constants.dart';

// fiscal year helper (copied from events_page.dart)
int fiscalYear(DateTime date) =>
    date.month >= 4 ? date.year : date.year - 1;

Scout _makeScout({
  int leafBadges = 0,
  int leafBadgeOffset = 0,
  int twigBadges = 0,
  ScoutCategory category = ScoutCategory.beaver,
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

    test('上進は小枝章対象外', () {
      final scout = _makeScout(category: ScoutCategory.promoted);
      expect(scout.isTwigBadgeEligible, false);
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

  // ─── AllergyType.fromValue ─────────────────────────────────
  group('AllergyType.fromValue', () {
    test('egg を正しく変換', () {
      expect(AllergyType.fromValue('egg'), AllergyType.egg);
    });

    test('dairy を正しく変換', () {
      expect(AllergyType.fromValue('dairy'), AllergyType.dairy);
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
  });
}
