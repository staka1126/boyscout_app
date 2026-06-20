# ビーバーログ 仕様書

## 1. 目的

ボーイスカウトのビーバー隊のリーダーが隊務の管理を行うためのアプリケーション「ビーバーログ」です。
スカウトや活動、表彰の管理を行います。

## 2. 技術構成

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter |
| 対応プラットフォーム | Linux デスクトップ、Android、iOS |
| データベース（ローカル） | SQLite（sqflite + sqflite_common_ffi） |
| クラウドバックエンド | Supabase（マルチユーザー同期・認証） |
| 状態管理 | flutter_riverpod |
| ルーティング | go_router |
| 電話・メール起動 | url_launcher |
| DBパス（Linux） | `~/.local/share/boyscout_app/boyscout.db` |
| ウィンドウサイズ | 390×844（スマホ縦長、iPhone 14相当） |

## 3. 画面構成

BottomNavigationBar で以下の5タブを切り替える。

| タブ | パス | 説明 |
|---|---|---|
| ホーム | `/dashboard` | ダッシュボード |
| スカウト | `/scouts` | スカウト一覧・詳細・追加・編集 |
| イベント | `/events` | イベント一覧・詳細・追加・編集 |
| 表彰 | `/badges` | 入隊・小枝章・木の葉章・皆勤賞 |
| 設定 | `/settings` | 団情報・リーダー・スカウト・保護者・団委員ほか・イベント・表彰管理 |

## 4. 主要機能

### 4.1 ダッシュボード
- 今月のイベント数、スカウト数、平均出席率、小枝章授与待ち数を表示
- 団名はSupabaseから取得して表示（`{団名} ビーバー隊`）
- 直近2ヶ月のイベントを一覧表示（近い日付が上）
  - 各カードには日付・タイトル・場所・開始時間・ステータスチップを表示（event_type は非表示）
- 小枝章授与待ちがある場合はカード表示
- 今月誕生日のスカウトを日付順で表示（氏名・日付・年齢）
- イベント追加FAB（右下）

### 4.2 スカウト管理
- スカウト一覧（氏名・分類・木の葉章枚数・小枝章授与待ち表示）
- 氏名検索・分類フィルタ
- スカウト追加FAB（右下）
- スカウト追加・編集フォーム：
  - 氏名は「氏」「名」の2フィールド（横並び・両方必須）、保存時は半角スペースで結合
  - 性別はラジオボタン（男性・女性）。新規追加時のデフォルトは「男性」
  - 学年はドロップダウン（小2・小1・年長・年中・年少・未就学・その他、デフォルト：小1）
  - 誕生日（日付ピッカー）
  - アレルギー：11種類のチップで複数選択（鶏卵・牛乳・乳製品・小麦・ソバ・ピーナッツ・甲殻類・木の実類・果物類・魚類・肉類・その他）
  - 特記事項（複数行テキスト）
  - 保存はAppBar右上の保存アイコン（`Icons.save_outlined`）。保存中はインジケーター表示
- 編集画面を抜ける際、未保存変更がある場合は確認ダイアログを表示
  - AppBar左上の戻るボタンにも明示的に確認ダイアログを紐付け（`PopScope` + `leading` の二重対策）
- スカウト詳細：
  - 基本情報（氏名・性別・学年・誕生日・入隊日・小学校入学年度）
  - 木の葉章・小枝章情報（活動取得・入隊時補正・合計・小枝章授与済み・授与待ち）
  - 木の葉章進捗（10枚ごとのプログレスバー）
  - アレルギー・特記（アレルゲン一覧・特記事項）
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
- イベント一覧（年度ドロップダウン・ステータスフィルタ）
  - 年度は4月始まり。データのある年度のみドロップダウンに表示
  - 年度ドロップダウン下に「実施N件　予定N件　非開催N件」のサマリーを表示
  - 各カードには日付・タイトル・場所・時間・ステータスチップを表示（event_type は非表示）
- イベント追加FAB（右下）
- 新規作成時のデフォルト時間：開始09:30・終了 12:00
- イベントフォーム：
  - タイトル・開催日・開始時間・終了時間・場所・備考を入力
  - event_type はUI上に存在せず、新規作成時は `other` を固定値として保存
  - 保存はAppBar右上の保存アイコン（`Icons.save_outlined`）。保存中はインジケーター表示
- イベント詳細：
  - ステータス選択（予定・確定・非開催の3ボタン）
  - 基本情報（日付・時間・場所・備考）
  - 木の葉章配布設定（5種別をON/OFFで設定）
  - 出欠管理（リーダー・スカウト・その他セクション）
  - 出席者追加FAB（右下、確定済みは非表示）
  - 編集・削除ボタン

#### イベント種別

DBには `event_type` カラムが存在するが、UI上は完全に非表示。新規作成時は `other` を固定値として保存。

#### イベントステータス

UI上の表示ラベルと DB 格納値は異なる。

| DB値 | 表示ラベル | 説明 |
|---|---|---|
| planned | 予定 | デフォルト |
| completed | 確定 | 木の葉章を出席スカウトへ反映・編集不可 |
| cancelled | 非開催 | 木の葉章に影響なし、確定済みからは変更不可 |

#### 確定処理
1. ステータスを「確定」に変更すると確認ダイアログ
2. OKで出席スカウト全員に木の葉章を加算（ONの種別数分）
3. 小枝章権利（10枚ごと）が発生していれば `twig_badge_history` を生成
4. 確定→他ステータス戻し時：木の葉章を減算・`twig_badge_history` を削除

#### 出欠管理
- デフォルト出席者：登録リーダー全員・スカウト（デフォルト出席分類のみ）
- 出席者追加：リーダー・スカウト・保護者・団委員ほかの4タブから選択
  - **リーダー**：引退者はデフォルト非表示。「すべて表示」オンで表示
  - **スカウト**：上進・退団・入隊せずはデフォルト非表示。「すべて表示」オンで表示
  - **保護者**：ビーバー・ビッグビーバーの保護者、および既に出席者リストに入っているスカウトの保護者のみデフォルト表示。「すべて表示」オンで全保護者を表示
  - **団委員ほか**：引退者はデフォルト非表示。「すべて表示」オンで表示
- 出席ステータス：出席（✓）・欠席（×）・未定（—）のアイコントグル
- 出席者削除：確認ダイアログ付き（確定済みは不可）

#### 木の葉章配布設定
- 健康（赤）・表現（オレンジ）・生活（黄）・自然（緑）・社会（青）
- 各種別をON/OFFで設定（count = 1 or 0）
- 確定後は編集不可

### 4.4 表彰管理（4タブ）

#### 入隊タブ
- 表示条件：ビーバーまたはビッグビーバー かつ 入隊日未入力
- 「入隊式未入力」バッジを表示

#### 小枝章タブ
- 表示条件：ビーバー・ビッグビーバーかつ `pendingTwigBadges > 0`
- 授与ボタン → 確認ダイアログ → pending の `twig_badge_history` を全件 awarded に更新・`twig_badges` +1
- 分類が小枝章対象外の場合は表示しない（木の葉章データは保持）
- 上進後にビーバーになった場合、蓄積分が一括表示される

#### 木の葉章タブ
- デフォルト出席対象スカウトを木の葉章合計降順で表示
- 10枚ごとのプログレスバー

#### 皆勤賞タブ
- 対象：ビーバー・ビッグビーバーのみ
- 期間：各年度 4/1〜翌3/31（年度ドロップダウンで過去5年度まで切り替え可能）
- 条件：期間内の**確定済みイベントすべて**（DB値 `status = 'completed'`）に `status = 'present'` で出席
- 出席者リストに登録されていない場合は欠席扱い
- 該当者がいない場合は「該当するスカウトはいません」と表示

### 4.5 設定

設定画面の先頭に団名・ログインユーザー名・ロールバッジを表示。

| 項目 | 遷移先 | 表示条件 |
|---|---|---|
| 団情報 | `/settings/troop` | 全員 |
| リーダー | `/settings/users` | 全員 |
| 保護者 | `/settings/guardians` | 全員 |
| 団委員ほか | `/settings/committee` | 全員 |
| 電話帳 | `/settings/phonebook` | 全員 |
| アレルギー情報 | `/settings/allergy` | 全員 |
| 利用者管理 | `/settings/members` | 管理者のみ |
| 招待コード | `/settings/invite-codes` | 管理者のみ |
| アカウントを削除する | （ダイアログ） | 全員 |
| バージョン情報 | （画面内・10秒長押しで隠しメニュー） | 全員 |

- ログアウトはAppBar右上のアイコンボタン
- データ全削除は「バージョン情報」10秒長押しの隠しメニューに移動（二段階確認）

#### 団情報
- 団名・場所・連絡先の登録・編集
- Supabaseから自分の団情報を取得して表示（キャッシュ不整合を防ぐ）
- 保存はAppBar右上の保存アイコン（`Icons.save_outlined`）

#### リーダー管理（`/settings/users`）
- リーダー一覧（現役→引退の順、氏名・種別・メールアドレス）
- 追加FAB・編集アイコン・削除アイコン
- フォーム：氏名は「氏」「名」の2フィールド、性別はラジオボタン
- **引退フラグ**：編集画面でスイッチ切り替え
- 削除制約：出欠履歴がある場合は削除不可

#### 保護者管理
- 保護者一覧・追加・編集・削除
- 削除制約：スカウトと紐付いている場合、または出欠履歴がある場合は削除不可

#### 団委員ほか管理
- 団委員一覧・追加・編集・削除
- **引退フラグ**：編集画面でスイッチ切り替え
- 削除制約：出欠履歴がある場合は削除不可

#### 電話帳
- リーダー・保護者・団委員ほか全員を名前昇順で一覧表示
- 電話・メールボタンでアプリ起動

#### アレルギー情報
- アレルギーのあるスカウト全員のサマリーカードを表示

#### 利用者管理（管理者のみ）
- 同じ団のアプリユーザーを一覧表示（Supabase RPC `get_troop_members()` で取得）
- ロールバッジ（管理者・メンバー）を表示
- メンバー行をタップでポップアップ（管理者行は無反応）：
  - **管理者にする**：対象を管理者に昇格し、自分はメンバーに降格してログアウト
  - **退会させる**：対象を団から退会（`troop_members` から削除）
- RPC関数：`update_member_role()`・`remove_troop_member()`

#### 招待コード（管理者のみ）
- 同じ団への招待コード一覧を表示（使用済み・未使用・期限切れの状態を表示）
- 使用済みの場合は使用者名を表示
- FABから新規発行（6桁英数字・7日間有効・使い捨て）
- RPC関数：`get_invite_codes()`

#### アカウント削除
- メンバーの場合：二段階確認後にRPC `delete_own_account()` でアカウント削除
- 管理者の場合：直接削除不可。ダイアログで案内
  - 「団全員を強制退会（10秒長押し）」→「実行（10秒長押し）」でRPC `dissolve_troop()` を実行後ログアウト

## 5. データモデル

### 5.1 ローカルSQLiteテーブル

#### troops（団）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | 団名 |
| location | TEXT | 所在地 |
| contact | TEXT | 連絡先 |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### leaders（リーダー） ※旧: users
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT NOT NULL | FK → troops.id |
| name | TEXT NOT NULL | 氏名 |
| gender | TEXT | male / female / other |
| email | TEXT | メールアドレス |
| phone | TEXT | 電話番号 |
| role | TEXT NOT NULL | leader / assistant_leader / support |
| is_active | INTEGER DEFAULT 1 | 有効フラグ |
| is_retired | INTEGER DEFAULT 0 | 引退フラグ |
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
| birthday | TEXT | 誕生日 |
| allergies | TEXT | アレルゲン（カンマ区切り文字列） |
| special_notes | TEXT | 特記事項 |
| leaf_badges | INTEGER DEFAULT 0 | 木の葉章枚数（活動取得） |
| leaf_badge_offset | INTEGER DEFAULT 0 | 入隊時補正（減算値） |
| twig_badges | INTEGER DEFAULT 0 | 小枝章授与済み本数 |
| is_active | INTEGER DEFAULT 1 | 有効フラグ |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

**計算値**
- `totalLeafBadges = leaf_badges - leaf_badge_offset`
- `pendingTwigBadges = (totalLeafBadges ~/ 10) - twig_badges`

#### guardians（保護者）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT | FK（NULL許容） |
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
| is_retired | INTEGER DEFAULT 0 | 引退フラグ |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### events（イベント）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| troop_id | TEXT NOT NULL | FK → troops.id |
| title | TEXT NOT NULL | タイトル |
| event_type | TEXT NOT NULL | 種別（UI非表示・固定値 `other`） |
| status | TEXT DEFAULT 'planned' | planned / completed / cancelled |
| event_date | TEXT NOT NULL | 開催日 |
| location | TEXT | 場所 |
| start_time | TEXT | 開始時間（HH:MM） |
| end_time | TEXT | 終了時間（HH:MM） |
| notes | TEXT | 備考 |
| completed_at | TEXT | 確定日時 |
| created_at | TEXT | 作成日時 |
| updated_at | TEXT | 更新日時 |

#### event_leaf_badges・attendances・twig_badge_history
（変更なし・旧SPEC参照）

### 5.2 DBスキーマ変更履歴

```sql
-- v2
ALTER TABLE users ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0;
ALTER TABLE committee_members ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0;
-- v3
ALTER TABLE scouts ADD COLUMN birthday TEXT;
ALTER TABLE scouts ADD COLUMN allergies TEXT;
ALTER TABLE scouts ADD COLUMN special_notes TEXT;
-- v4
ALTER TABLE guardians ADD COLUMN troop_id TEXT;
-- v5
ALTER TABLE users RENAME TO leaders;
```

`onUpgrade` は try-catch で重複エラーを吸収。DBバージョンは現在 **5**。

### 5.3 Supabaseスキーマ

#### profiles
| カラム | 型 | 説明 |
|---|---|---|
| id | UUID PK | auth.users.id |
| name | TEXT | 表示名 |
| email | TEXT | メールアドレス |

#### troops
| カラム | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| name | TEXT | 団名 |
| location | TEXT | 所在地 |
| contact | TEXT | 連絡先 |
| created_by | UUID | FK → profiles.id |

#### troop_members
| カラム | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| user_id | UUID | FK → profiles.id |
| troop_id | UUID | FK → troops.id |
| role | TEXT | admin / member / readonly |

#### invite_codes
| カラム | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| code | TEXT | 6桁英数字（0/O・1/I除外） |
| troop_id | UUID | FK → troops.id |
| created_by | UUID | FK → profiles.id |
| expires_at | TIMESTAMPTZ | 7日間有効 |
| used_by | UUID | 使用者（NULL=未使用） |

### 5.4 RLSポリシー概要

- `troop_members`：自分の行のみSELECT可（再帰防止）
- `leaders/scouts/events`等：SELECT は所属団のデータ全員可、INSERT/UPDATE/DELETE は admin・member のみ
- `profiles`：自分 OR 同じ団のメンバーが参照可
- 管理者操作（メンバー一覧・ロール変更・退会）はすべて `SECURITY DEFINER` のRPC関数経由

### 5.5 主要RPC関数

| 関数名 | 説明 |
|---|---|
| `get_troop_members()` | 管理者が団メンバー全員を取得 |
| `update_member_role(p_member_id, p_new_role)` | ロール変更 |
| `remove_troop_member(p_member_id)` | メンバー退会 |
| `get_invite_codes()` | 招待コード一覧（使用者名含む） |
| `delete_own_account()` | 自分のauth.usersを削除 |
| `dissolve_troop()` | 団の全データ削除・全メンバー退会 |

### 5.6 削除制約まとめ

| 対象 | 削除不可条件 |
|---|---|
| リーダー | attendances に記録がある（member_type='user'） |
| スカウト | attendances に記録がある または scout_guardians に記録がある |
| 保護者 | scout_guardians に記録がある、または attendances に記録がある |
| 団委員 | attendances に記録がある |
| イベント | status = 'completed' または attendances が空でない |

## 6. マルチユーザー・クラウド同期

### 同期方針
- **Supabaseがマスター**、ローカルSQLiteはオフラインキャッシュ（Last-Write-Wins）
- ログイン時：Supabase → ローカル（syncFromSupabase）
- 各CRUD操作後：ローカル → Supabase（syncToSupabase）

### 認証フロー
1. 新規登録 → `profiles` にINSERT
2. 団を新規登録 → `troops` にINSERT → `troop_members` に admin で登録
3. 招待コードで参加 → `troop_members` に member で登録 → syncFromSupabase
4. ログアウト → SharedPreferences の troop_id をクリア

### 起動時の整合性チェック
- `initTroopProvider` 起動時に `troop_members` の存在を確認
- レコードがない場合はローカルDBをリセットしてオンボーディングへ遷移（DB不整合対策）

### 招待コード仕様
- 6桁英数字（0/O・1/I除外）
- 7日間有効・使い捨て
- 管理者のみ発行可能

## 7. 状態管理・Provider

| Provider | 説明 |
|---|---|
| `currentTroopIdProvider` | 現在の団ID（SharedPreferences + DB復元） |
| `initTroopProvider` | 起動時に団IDを復元・troop_membersの存在確認 |
| `isSignedInProvider` | ログイン状態の監視 |
| `currentUserProvider` | 現在のユーザー |
| `dashboardProvider` | ダッシュボードデータ |

画面間のデータ更新は `ref.invalidate()` で行う。

## 8. ビジネスロジック

### イベント確定時
1. `events.status` → `'completed'`、`completed_at` = 現在日時
2. `event_leaf_badges` の合計（ONの種別数）を取得
3. 出席（present）スカウト全員に `leaf_badges += 合計`
4. 加算後の `pendingTwigBadges > 0` であれば `twig_badge_history` を生成

### 確定取り消し時
1. 確認ダイアログ
2. 出席スカウト全員の `leaf_badges -= 合計`（MAX(0, ...)で0未満防止）
3. `twig_badge_history` のうち `event_id` 一致レコードを削除
4. `events.status` を新ステータスに更新、`completed_at` = null

### 小枝章授与時
1. 該当スカウトの `twig_badge_history` のうち pending 全件を awarded に更新
2. `scouts.twig_badges += 1`

### 出席率の計算

```
出席率 = 出席数 / (出席数 + 欠席数)
```

- **分子**：`status = 'present'` の件数
- **分母**：`status IN ('present', 'absent')` の件数
- **「未定」は分母に含まない**
- **対象**：リーダー・スカウトのみ（`member_type IN ('user', 'scout')`）

### 皆勤賞判定

- **対象**：ビーバー・ビッグビーバー（`is_active = 1`）
- **期間**：`year/4/1` 〜 `(year+1)/3/31`
- **条件**：期間内の確定済みイベントすべてに `status = 'present'` で出席
- **確定済みイベントが0件の場合**：空リストを返す

## 9. 開発・運用メモ

- **環境変数**：`SUPABASE_URL`・`SUPABASE_ANON_KEY` を `--dart-define` 経由で渡す（`run.sh` + `.env`）
- **APIキー形式**：新形式（`sb_publishable_`）
- **スーパー管理者**：アプリ内管理画面なし。Supabaseダッシュボードを直接操作
- **デバッグ用**：ログイン画面に `[DEV] DBリセット＋同期` ボタン（`kDebugMode` のみ表示）
- **applicationId**：`jp.tshub.beaverlog`
- **プライバシーポリシー**：`https://staka1126.github.io/boyscout_app/`
