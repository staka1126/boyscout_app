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

    test('30枚で3本授与待ち（0本授与済み）', () {
      final scout = _makeScout(leafBadges: 30, twigBadges: 0);
      expect(scout.pendingTwigBadges, 3);
    });

    test('30枚で1本授与待ち（2本授与済み）', () {
      final scout = _makeScout(leafBadges: 30, twigBadges: 2);
      expect(scout.pendingTwigBadges, 1);
    });
  });

  // ─── 小枝章 N本まとめて授与のロジック ─────────────────────
  group('小枝章 N本まとめて授与', () {
    test('授与後に twigBadges が pendingTwigBadges 分増加する', () {
      // 30枚取得・0本授与済み → 3本待ち
      final before = _makeScout(leafBadges: 30, twigBadges: 0);
      expect(before.pendingTwigBadges, 3);

      // N本授与後の状態をモデルで再現（DB更新後のスカウト）
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

    test('1本待ちの場合は授与後に1本増加する', () {
      final before = _makeScout(leafBadges: 10, twigBadges: 0);
      expect(before.pendingTwigBadges, 1);

      final after = _makeScout(leafBadges: 10, twigBadges: before.twigBadges + before.pendingTwigBadges);
      expect(after.twigBadges, 1);
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

  // ─── EventStatus.label ─────────────────────────────────────
  group('EventStatus.label', () {
    test('planned のラベルは「予定」', () {
      expect(EventStatus.planned.label, '予定');
    });

    test('completed のラベルは「確定」', () {
      expect(EventStatus.completed.label, '確定');
    });

    test('cancelled のラベルは「非開催」', () {
      expect(EventStatus.cancelled.label, '非開催');
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
