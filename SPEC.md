# ビーバーログ 仕様書

## 1. 目的

ボーイスカウトのビーバー隊のリーダーが隊務の管理を行うためのアプリケーション「ビーバーログ」です。
スカウトや活動、表彰の管理を行います。

## 2. 技術構成

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter |
| 対応プラットフォーム | Linux デスクトップ、Android |
| データベース | SQLite（sqflite + sqflite_common_ffi） |
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
- 直近2ヶ月のイベントを一覧表示（近い日付が上）
- 小枝章授与待ちがある場合はカード表示
- 今月誕生日のスカウトを日付順で表示（氏名・日付・年齢）
- イベント追加FAB（右下）

### 4.2 スカウト管理
- スカウト一覧（氏名・分類・木の葉章枚数・小枝章授与待ち表示）
- 氏名検索・分類フィルタ
- スカウト追加FAB（右下）
- スカウト追加・編集フォーム：
  - 氏名は「氏」「名」の2フィールド（横並び・両方必須）、保存時は半角スペースで結合
  - 性別はラジオボタン（男性・女性）
  - 学年はドロップダウン（小2・小1・年長・年中・年少・未就学・その他、デフォルト：小1）
  - 誕生日（日付ピッカー）
  - アレルギー：11種類のチップで複数選択（鶏卵・牛乳・乳製品・小麦・ソバ・ピーナッツ・甲殻類・木の実類・果物類・魚類・肉類・その他）
  - 特記事項（複数行テキスト）
- 編集画面を抜ける際、未保存変更がある場合は確認ダイアログを表示
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
- イベント一覧（近い日付が上・ステータスフィルタ）
- イベント追加FAB（右下）
- 新規作成時のデフォルト時間：開始09:30・終了 12:00
- イベント詳細：
  - ステータス選択（予定・開催中・完了の3ボタン）
  - 基本情報（日付・時間・場所・備考）
  - 木の葉章配布設定（5種別をON/OFFで設定）
  - 出欠管理（リーダー・スカウト・その他セクション）
  - 出席者追加FAB（右下、完了済みは非表示）
  - 編集・削除ボタン

#### イベント種別

DBには `event_type` カラムが存在するが、UI上は非表示。新規作成時は `other` を固定値として保存。

#### イベントステータス
| 値 | ラベル | 説明 |
|---|---|---|
| planned | 予定 | デフォルト |
| ongoing | 開催中 | |
| completed | 完了 | 木の葉章を出席スカウトへ反映・編集不可 |
| cancelled | 非開催 | 木の葉章に影響なし、完了済みからは変更不可 |

#### 完了処理
1. ステータスを「完了」に変更すると確認ダイアログ
2. OKで出席スカウト全員に木の葉章を加算（ONの種別数分）
3. 小枝章権利（10枚ごと）が発生していれば `twig_badge_history` を生成
4. 完了→他ステータス戻し時：木の葉章を減算・`twig_badge_history` を削除

#### 出欠管理
- デフォルト出席者：登録リーダー全員・スカウト（デフォルト出席分類のみ）
- 出席者追加：リーダー・スカウト・保護者・団委員ほかの4タブから選択
  - **リーダー**：引退者はデフォルト非表示。「すべて表示」オンで表示
  - **スカウト**：上進・退団・入隊せずはデフォルト非表示。「すべて表示」オンで表示
  - **保護者**：ビーバー・ビッグビーバーの保護者、および既に出席者リストに入っているスカウトの保護者のみデフォルト表示。「すべて表示」オンで全保護者を表示
  - **団委員ほか**：引退者はデフォルト非表示。「すべて表示」オンで表示
- 出席ステータス：出席（✓）・欠席（×）・未定（—）のアイコントグル
- 出席者削除：確認ダイアログ付き（完了済みは不可）

#### 木の葉章配布設定
- 健康（赤）・表現（オレンジ）・生活（黄）・自然（緑）・社会（青）
- 各種別をON/OFFで設定（count = 1 or 0）
- 完了後は編集不可

### 4.4 表彰管理（4タブ）

#### 入隊タブ
- 表示条件：ビーバーまたはビッグビーバー かつ 入隊日未入力
- 「入隊式未入力」バッジを表示

#### 小枝章タブ
- 表示条件：ビーバー・ビッグビーバーかつ `pendingTwigBadges > 0`
- 授与ボタン → 確認ダイアログ → `twig_badge_history` を awarded に更新・`twig_badges` +1
- 分類が小枝章対象外の場合は表示しない（木の葉章データは保持）
- 上進後にビーバーになった場合、蓄積分が一括表示される

#### 木の葉章タブ
- デフォルト出席対象スカウトを木の葉章合計降順で表示
- 10枚ごとのプログレスバー

#### 皆勤賞タブ
- 対象：ビーバー・ビッグビーバーのみ
- 期間：各年度 4/1〜翌3/31（年度ドロップダウンで過去5年度まで切り替え可能）
- 条件：期間内の**完了済みイベントすべて**に `status = 'present'` で出席
- 出席者リストに登録されていない場合は欠席扱い
- 該当者がいない場合は「該当するスカウトはいません」と表示

### 4.5 設定

設定画面の先頭に団名を表示。以下の7項目、各項目は一覧画面へ遷移。

| 項目 | 遷移先 |
|---|---|
| 団情報 | `/settings/troop` |
| リーダー管理 | `/settings/users` |
| スカウト管理 | `/scouts` |
| 保護者管理 | `/settings/guardians` |
| 団委員ほか管理 | `/settings/committee` |
| イベント管理 | `/events` |
| 表彰管理 | `/badges` |
| 電話帳 | `/settings/phonebook` |
| アレルギー情報 | `/settings/allergy` |

スカウト管理・イベント管理・表彰管理の AppBar には「設定」へ戻るボタンを表示。

リーダー管理・保護者管理・団委員ほか管理は団情報未登録時に登録誘導画面を表示。

#### 団情報
- 団名・場所・連絡先の登録・編集（団コードなし）

#### リーダー管理
- リーダー一覧（現役→引退の順、氏名・種別・メールアドレス）
- 追加FAB・編集アイコン・削除アイコン
- フォーム：氏名は「氏」「名」の2フィールド（横並び・両方必須）、性別はラジオボタン（男性・女性）
- 編集画面を抜ける際、未保存変更がある場合は確認ダイアログを表示
- メールアドレスは必須・重複時はダイアログで通知
- **引退フラグ**：編集画面でスイッチ切り替え。引退者はグレーアウト表示・出席者追加の対象外
- 削除制約：出欠履歴がある場合は削除不可

#### スカウト管理
- `/scouts`（スカウト一覧）へ遷移
- 削除制約：出欠履歴がある場合は削除不可

#### 保護者管理
- 保護者一覧（氏名・連絡先）
- 追加FAB・編集アイコン・削除アイコン
- フォーム：氏名は「氏」「名」の2フィールド（横並び・両方必須）、性別はラジオボタン（男性・女性）
- 編集画面を抜ける際、未保存変更がある場合は確認ダイアログを表示
- 編集画面でスカウトとの紐付け編集（追加・解除）が可能
- 削除制約：スカウトと紐付いている場合は削除不可
- 削除制約：出欠履歴がある場合は削除不可

#### 団委員ほか管理
- 団委員一覧（現役→引退の順、氏名・分類・連絡先）
- 追加FAB・編集アイコン・削除アイコン
- フォーム：氏名は「氏」「名」の2フィールド（横並び・両方必須）、性別はラジオボタン（男性・女性）
- 編集画面を抜ける際、未保存変更がある場合は確認ダイアログを表示
- **引退フラグ**：編集画面でスイッチ切り替え。引退者はグレーアウト表示・出席者追加の対象外
- 削除制約：出欠履歴がある場合は削除不可

#### 電話帳
- リーダー・保護者・団委員ほか全員を名前昇順で一覧表示
- 氏名検索
- 電話番号がある場合は緑の✆ボタン→タップで電話アプリ起動
- メールがある場合は青の✉ボタン→タップでメールアプリ起動

#### アレルギー情報
- アレルギーのあるスカウト全員のサマリーカードを表示
- アレルゲンごとに該当スカウトを列挙（名前・分類・特記事項）
- 該当者なしの場合は「アレルギーのあるスカウトはいません」と表示

#### イベント管理・表彰管理
- それぞれ `/events`・`/badges` へ遷移

## 5. データモデル（SQLite）

### 5.1 テーブル一覧

#### troops（団）
| カラム | 型 | 説明 |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | 団名 |
| location | TEXT | 所在地 |
| contact | TEXT | 連絡先 |
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
| member_type | TEXT NOT NULL | user / scout / guardian / committee / other |
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

### 5.2 DBスキーマ変更履歴（ALTER TABLE）

既存DBへの追加が必要なカラム：

```sql
-- v2
ALTER TABLE users ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0;
ALTER TABLE committee_members ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0;
-- v3
ALTER TABLE scouts ADD COLUMN birthday TEXT;
ALTER TABLE scouts ADD COLUMN allergies TEXT;
ALTER TABLE scouts ADD COLUMN special_notes TEXT;
```

`onUpgrade` は try-catch で重複エラーを吸収。DBバージョンは現在 **3**。

### 5.3 削除制約まとめ

| 対象 | 削除不可条件 |
|---|---|
| リーダー | attendances に記録がある（member_type='user'） |
| スカウト | attendances に記録がある（member_type='scout'）または scout_guardians に記録がある |
| 保護者 | scout_guardians に記録がある、または attendances に記録がある（member_type='guardian'） |
| 団委員 | attendances に記録がある（member_type='committee'） |
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

### 出席率の計算

`AttendanceRepository.getRates()` で算出。

```
出席率 = 出席数 / (出席数 + 欠席数)
```

- **分子**：`status = 'present'`（出席）の件数
- **分母**：`status IN ('present', 'absent')`（出席 + 欠席）の件数
- **「未定」は分母に含まない**（未入力は計算対象外）
- **対象**：リーダー・スカウトのみ（`member_type IN ('user', 'scout')`）
- **ダッシュボードの平均出席率**：全メンバーの出席率を平均した値

### 皆勤賞判定

`AttendanceRepository.getPerfectAttendance({troopId, year})` で算出。

- **対象**：ビーバー・ビッグビーバー（`is_active = 1`）
- **期間**：`year/4/1` 〜 `(year+1)/3/31`
- **条件**：期間内の完了済みイベント（`status = 'completed'`）すべてに `status = 'present'` で出席
- **欠席扱い**：出席者リストに登録されていない場合も欠席とみなす
- **完了済みイベントが0件の場合**：対象者なしとして空リストを返す
