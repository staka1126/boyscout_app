# ビーバー隊 隊務管理アプリ 仕様書

## 1. 目的

ボーイスカウトのビーバー隊のリーダーが隊務の管理を行うためのアプリケーションです。
スカウトや活動、表彰の管理を行います。

## 2. 技術構成

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter |
| 対応プラットフォーム | Linux デスクトップ、Android |
| データベース | SQLite（sqflite + sqflite_common_ffi） |
| 状態管理 | flutter_riverpod |
| ルーティング | go_router |
| DBパス（Linux） | `~/.local/share/boyscout_app/boyscout.db` |
| ウィンドウサイズ | 390×844（スマホ縦長、iPhone 14相当） |

## 3. 画面構成

BottomNavigationBar で以下の5タブを切り替える。

| タブ | パス | 説明 |
|---|---|---|
| ホーム | `/dashboard` | ダッシュボード |
| スカウト | `/scouts` | スカウト一覧・詳細・追加・編集 |
| イベント | `/events` | イベント一覧・詳細・追加・編集 |
| 表彰 | `/badges` | 入隊・小枝章・木の葉章 |
| 設定 | `/settings` | 団情報・リーダー・保護者管理 |

## 4. 主要機能

### 4.1 ダッシュボード
- 今月のイベント数、スカウト数、平均出席率、小枝章授与待ち数を表示
- 直近2ヶ月のイベントを一覧表示（近い日付が上）
- 小枝章授与待ちがある場合はカード表示
- イベント追加FAB（右下）

### 4.2 スカウト管理
- スカウト一覧（氏名・分類・木の葉章枚数・小枝章授与待ち表示）
- 氏名検索・分類フィルタ
- スカウト追加FAB（右下）
- スカウト詳細：
  - 基本情報（氏名・性別・学年・入隊日・小学校入学年度）
  - 木の葉章・小枝章情報（活動取得・入隊時補正・合計・小枝章授与済み・授与待ち）
  - 木の葉章進捗（10枚ごとのプログレスバー）
  - 保護者紐付け（一覧表示・紐付け追加・解除）
  - 編集・削除ボタン
- スカウト削除制約：出欠履歴または保護者紐付けがある場合は削除不可

#### スカウト分類
| 値 | ラベル | デフォルト出席 | 小枝章対象 |
|---|---|---|---|
| big_beaver | ビッグビーバー | ○ | ○ |
| beaver | ビーバー | ○ | ○ |
| provisional | 仮入隊 | ○ | × |
| experience | 体験 | ○ | × |
| sibling | 兄弟姉妹 | ○ | × |
| promoted | 上進 | × | × |
| withdrawn | 退団 | × | × |
| not_joined | 入隊せず | × | × |

### 4.3 イベント管理
- イベント一覧（近い日付が上・ステータスフィルタ）
- イベント追加FAB（右下）
- イベント詳細：
  - ステータス選択（予定・開催中・完了の3ボタン）
  - 基本情報（種別・日付・時間・場所・備考）
  - 木の葉章配布設定（5種別をON/OFFで設定）
  - 出欠管理（リーダー・スカウト・その他セクション）
  - 出席者追加FAB（右下、完了済みは非表示）
  - 編集・削除ボタン

#### イベント種別
| 値 | ラベル |
|---|---|
| group_meeting | 団集会 |
| troop_meeting | 隊集会 |
| camp | キャンプ |
| service | 奉仕活動 |
| other | その他 |

#### イベントステータス
| 値 | ラベル | 説明 |
|---|---|---|
| planned | 予定 | デフォルト |
| ongoing | 開催中 | |
| completed | 完了 | 木の葉章を出席スカウトへ反映・編集不可 |

#### 完了処理
1. ステータスを「完了」に変更すると確認ダイアログ
2. OKで出席スカウト全員に木の葉章を加算（ONの種別数分）
3. 小枝章権利（10枚ごと）が発生していれば `twig_badge_history` を生成
4. 完了→他ステータス戻し時：木の葉章を減算・`twig_badge_history` を削除

#### 出欠管理
- デフォルト出席者：登録リーダー全員・スカウト（デフォルト出席分類のみ）
- 出席者追加：リーダー・スカウト・団委員・その他から選択
- 出席ステータス：出席（✓）・欠席（×）・未定（—）のアイコントグル
- 出席者削除：確認ダイアログ付き（完了済みは不可）

#### 木の葉章配布設定
- 健康（赤）・表現（オレンジ）・生活（黄）・自然（緑）・社会（青）
- 各種別をON/OFFで設定（count = 1 or 0）
- 完了後は編集不可

### 4.4 表彰管理（3タブ）

#### 入隊タブ
- 表示条件：ビーバーまたはビッグビーバー かつ 入隊日未入力
- 「入隊式未入力」バッジを表示

#### 小枝章タブ
- 表示条件：ビーバー・ビッグビーバーかつ `pendingTwigBadges > 0`
- 授与ボタン → 確認ダイアログ → `twig_badge_history` を awarded に更新・`twig_badges` +1
- 分類が小枝章対象外の場合は表示しない（木の葉章データは保持）

#### 木の葉章タブ
- デフォルト出席対象スカウトを木の葉章合計降順で表示
- 10枚ごとのプログレスバー

### 4.5 設定

#### 団情報
- 団名・場所・連絡先・団コードの登録・編集

#### リーダー管理
- リーダー一覧（氏名・種別・メールアドレス）
- 追加FAB・編集アイコン・削除アイコン
- メールアドレスは必須・重複時はダイアログで通知
- 削除制約：出欠履歴がある場合は削除不可

#### 保護者管理
- 保護者一覧（氏名・連絡先）
- 追加FAB・編集アイコン・削除アイコン
- 削除制約：スカウトと紐付いている場合は削除不可

## 5. データモデル（SQLite）

### 5.1 テーブル一覧

#### troops（団）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | 団名 |
| location | TEXT | 所在地 |
| contact | TEXT | 連絡先 |
| troop_code | TEXT UNIQUE | 団コード |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### users（リーダー）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT NOT NULL | FK → troops.id |
| name | TEXT NOT NULL | 氏名 |
| gender | TEXT | male / female / other |
| email | TEXT NOT NULL | メールアドレス（アプリ側で重複チェック） |
| phone | TEXT | 電話番号 |
| role | TEXT NOT NULL | leader / assistant_leader / support |
| is_active | INTEGER DEFAULT 1 | 有効フラグ |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### scouts（スカウト）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT NOT NULL | FK → troops.id |
| name | TEXT NOT NULL | 氏名 |
| gender | TEXT | male / female / other |
| grade | TEXT | 学年 |
| category | TEXT NOT NULL | 分類 |
| enrollment_year | INTEGER | 小学校入学年度 |
| joined_at | TEXT | 入隊日 |
| leaf_badges | INTEGER DEFAULT 0 | 木の葉章枚数（活動取得） |
| leaf_badge_offset | INTEGER DEFAULT 0 | 入隊時補正 |
| twig_badges | INTEGER DEFAULT 0 | 小枝章授与済み本数 |
| is_active | INTEGER DEFAULT 1 | 有効フラグ |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

**計算値**
- `totalLeafBadges = leaf_badges + leaf_badge_offset`
- `pendingTwigBadges = (totalLeafBadges ~/ 10) - twig_badges`

#### guardians（保護者）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | 氏名 |
| gender | TEXT | male / female / other |
| email | TEXT | メールアドレス |
| phone | TEXT | 電話番号 |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### scout_guardians（スカウト↔保護者）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| scout_id | TEXT NOT NULL | FK → scouts.id |
| guardian_id | TEXT NOT NULL | FK → guardians.id |
| relationship | TEXT | father / mother / other |

- UNIQUE(scout_id, guardian_id)

#### committee_members（団委員）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT NOT NULL | FK → troops.id |
| name | TEXT NOT NULL | 氏名 |
| gender | TEXT | male / female / other |
| category | TEXT NOT NULL | committee / other_leader / other_troop / ob / other |
| email | TEXT | メールアドレス |
| phone | TEXT | 電話番号 |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### events（イベント）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT NOT NULL | FK → troops.id |
| title | TEXT NOT NULL | タイトル |
| event_type | TEXT NOT NULL | 種別 |
| status | TEXT DEFAULT 'planned' | planned / ongoing / completed |
| event_date | TEXT NOT NULL | 開催日 |
| location | TEXT | 場所 |
| start_time | TEXT | 開始時間（HH:MM） |
| end_time | TEXT | 終了時間（HH:MM） |
| notes | TEXT | 備考 |
| completed_at | TEXT | 完了日時 |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### event_leaf_badges（木の葉章配布設定）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| event_id | TEXT NOT NULL | FK → events.id |
| badge_type | TEXT NOT NULL | health / expression / life / nature / society |
| count | INTEGER DEFAULT 0 | 0=OFF, 1=ON |

- UNIQUE(event_id, badge_type)

#### attendances（出欠）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| event_id | TEXT NOT NULL | FK → events.id |
| member_type | TEXT NOT NULL | user / scout / committee / other |
| member_id | TEXT | メンバーID（other は NULL） |
| member_name | TEXT NOT NULL | 氏名 |
| status | TEXT DEFAULT 'pending' | present / absent / pending |
| is_default | INTEGER DEFAULT 0 | デフォルト追加フラグ |
| notes | TEXT | 備考 |

- UNIQUE(event_id, member_type, member_id)

#### twig_badge_history（小枝章履歴）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| scout_id | TEXT NOT NULL | FK → scouts.id |
| scout_name | TEXT NOT NULL | 氏名スナップショット |
| event_id | TEXT | FK → events.id（権利発生イベント） |
| status | TEXT DEFAULT 'pending' | pending / awarded |
| awarded_at | TEXT | 授与日 |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

### 5.2 削除制約まとめ

| 対象 | 削除不可条件 |
|---|---|
| リーダー | attendances に記録がある |
| スカウト | attendances または scout_guardians に記録がある |
| 保護者 | scout_guardians に記録がある |
| イベント | status = completed または attendances が空でない |

## 6. 状態管理・Provider

| Provider | 説明 |
|---|---|
| `currentTroopIdProvider` | 現在の団ID（SharedPreferences + DB復元） |
| `initTroopProvider` | 起動時に団IDを復元 |
| `currentUserProvider` | 現在のユーザー |
| `dashboardProvider` | ダッシュボードデータ（public） |
| `eventsProvider` | イベント一覧（public） |
| `scoutsProvider` | スカウト一覧（public） |
| `badgesProvider` | 表彰データ（public） |

画面間のデータ更新は `ref.invalidate()` で行う。  
`push` + `await` で戻ったタイミングに invalidate するパターンを統一。

## 7. ビジネスロジック

### イベント完了時
1. `events.status` → `completed`、`completed_at` = 現在日時
2. `event_leaf_badges` の合計（ONの種別数）を取得
3. 出席（present）スカウト全員に `leaf_badges += 合計`
4. 加算後の `pendingTwigBadges > 0` であれば `twig_badge_history` を生成

### 完了取り消し時
1. 確認ダイアログ
2. 出席スカウト全員の `leaf_badges -= 合計`（MAX(0, ...)で0未満防止）
3. `twig_badge_history` のうち `event_id` 一致レコードを削除
4. `events.status` を新ステータスに更新、`completed_at` = null

### 小枝章授与時
1. `twig_badge_history` の pending レコードを awarded に更新
2. `scouts.twig_badges += 1`
