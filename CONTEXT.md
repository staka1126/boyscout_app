# スカウト出欠管理アプリ コンテキストサマリー

このファイルは、Claude との会話コンテキストが切れた際に引き継ぐための情報です。

---

## プロジェクト概要

- **目的**: ボーイスカウトのリーダーが出欠・木の葉章・メンバーを管理するデスクトップアプリ
- **技術スタック**: 未定 + Supabase（クラウドDB）
- **対応OS**: Ubuntu (GNOME) / Windows / Android / iOS
- **配置場所**: `/home/takaaki/git-work/BoyScout
- **認証**: Googleアカウントでの認証
---

## DBスキーマ（Supabase / PostgreSQL）

### テーブル一覧

| テーブル | 説明 |
|---------|------|
| `profiles` | 団委員・リーダー・保護者情報（auth.usersと1:1）|
| `groups` | 団（= Scout Groups。複数団対応）|
| `group_members` | リーダーと隊の中間テーブル |
| `troops` | 隊（ローバー、ベンチャー、ボーイ、カブなど）|
| `scouts` | スカウト（隊員）|
| `events` | イベント・集会 |
| `attendance` | 出欠記録 |
| `event_leaf_settings` | イベントごとの木の葉章デフォルト配布枚数（ビーバーのみ） |
| `leaf_badge_grants` | 木の葉章付与記録（ビーバーのみ・累積のみ・消費あり）|
| `leaf_badge_snapshots` | イベントクローズ時の累計スナップショット |

### profiles の主要カラム

```sql
id                   uuid  -- auth.users.id と同一
group_id             uuid  -- 所属団
troop_id             uuid  -- 所属隊(ローバー/ベンチャー/ボーイ/カブ/ビーバー)
role                 text  -- 団委員/リーダー/保護者/その他
display_name         text
role                 text  -- 'admin' | 'leader' | 'assistant_leader' | 'den_leader' | 'parent' | 'committee'
gender               text  -- 'male' | 'female'
email                text  -- 招待時にアプリ側で保存
telephone            text  -- 電話番号
active               bool
must_change_password bool  -- 初回ログイン時 true
```

### scouts の主要カラム

```sql
id          uuid
group_id    uuid  -- 所属団
troop_id   uuid  -- 所属班
name        text
gender      text  -- 'male' | 'female'
section     text  -- 'くま' | 'しか' | 'りす' | 'うさぎ' （所属班など）
grade       text
birth_date  date
active      bool
```

### events の主要カラム

```sql
id             uuid
group_id       uuid
title          text
event_type     text  -- 'meeting' | 'camp' | 'service' | 'ceremony' | 'other'
event_date     date
target_troop   text  -- '全体' | 'ビーバー' | 'カブ' | 'ボーイ' | 'ベンチャー' | 'ローバー'
is_closed      bool
```

---

## 実装上の重要な決定事項

### 権限設計
- 全体管理者: 全団の追加・編集・削除・参照ほか、すべての操作が可能
- 隊長・副長 (leader/assistant_leader): 所属団に関する追加・編集・削除・参照可能
- デンリーダー・団委員: 自分の所属団のみ参照可能

---

## UI設計
・起動時にGoogleアカウントで認証
　- アプリ内にアカウントが登録されていなければ利用不可
　- 未登録の場合、全体管理者と隊長/副長がメールにより承認する
・起動後は、その権限の範囲で情報を参照できる
　- 全体管理者は、全団・全隊の情報にアクセスできる
　- それ以外は自分の所属隊の情報のみにアクセスできる
・全体管理者がアクセスする際に、団の切り替えはプルダウン等でできるようにする
・出欠管理は target_troop のスコープで行う
　- 全員の名前が表示され、出席/欠席をチェックしていく
　- 所属隊が
・木の葉章の管理
　- 