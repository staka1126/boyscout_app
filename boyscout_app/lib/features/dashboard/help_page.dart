import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使い方')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            icon: Icons.dashboard_outlined,
            title: 'ホーム（ダッシュボード）',
            items: [
              '今月のイベント数・スカウト数・出席率・小枝章授与待ち数を確認できます',
              '直近のイベントが一覧表示されます',
              '小枝章の授与待ちがある場合はカードが表示されます',
              '今月誕生日のスカウトが表示されます',
              '右下の ＋ ボタンからイベントを追加できます',
            ],
          ),
          _Section(
            icon: Icons.people_outline,
            title: 'スカウト管理',
            items: [
              '右下の ＋ ボタンからスカウトを追加できます',
              '氏・名は別々のフィールドに入力します',
              '学年・性別・誕生日・アレルギー・特記事項を登録できます',
              '保存はAppBar右上の保存アイコンをタップします',
              '未保存の変更がある場合は確認ダイアログが表示されます',
              '出欠履歴・保護者紐付けがあるスカウトは削除できません',
            ],
          ),
          _Section(
            icon: Icons.event_outlined,
            title: 'イベント管理',
            items: [
              '右下の ＋ ボタンからイベントを追加できます',
              'ステータスは「予定」→「確定」→「非開催」の順に変更できます',
              '「確定」にすると出席スカウトに木の葉章が加算されます',
              '木の葉章の種別（健康・表現・生活・自然・社会）をON/OFFで設定します',
              '出欠は ✓出席 / ×欠席 / —未定 のアイコンで切り替えます',
              '確定済みまたは出席者がいるイベントは削除できません',
            ],
          ),
          _Section(
            icon: Icons.military_tech_outlined,
            title: '表彰',
            items: [
              '【入隊】入隊日が未入力のスカウトが表示されます',
              '【小枝章】木の葉章10枚ごとに1本の授与待ちが発生します。「授与」ボタンで記録します',
              '【木の葉章】スカウトの木の葉章合計を一覧で確認できます',
              '【皆勤賞】年度内の確定済みイベントに全出席したスカウトが表示されます',
            ],
          ),
          _Section(
            icon: Icons.settings_outlined,
            title: '設定',
            items: [
              '団情報・リーダー・保護者・団委員ほかの登録・編集ができます',
              '電話帳からリーダー・保護者・団委員に電話・メールできます',
              'アレルギー情報でアレルギーのあるスカウトを一覧確認できます',
              '【管理者のみ】利用者管理でメンバーの昇格・退会ができます',
              '【管理者のみ】招待コードを発行して他のリーダーを招待できます',
              'ログアウトはAppBar右上のアイコンからできます',
            ],
          ),
          _Section(
            icon: Icons.sync_outlined,
            title: 'マルチユーザー・同期',
            items: [
              '複数のリーダーで同じ団のデータを共有できます',
              'ログイン時に自動でクラウドと同期されます',
              '招待コードは設定画面から発行できます（管理者のみ）',
              '招待コードは6桁英数字・7日間有効・使い捨てです',
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;

  const _Section({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.primary)),
          ]),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 0, indent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.circle,
                              size: 6, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(items[i],
                              style: const TextStyle(
                                  fontSize: 13, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
