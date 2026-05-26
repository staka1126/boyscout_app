# ボーイスカウト ビーバー隊 隊務管理アプリ 仕様書

## 1. 目的

ボーイスカウトのビーバー隊のリーダーが隊務の管理を行うためのアプリケーションです。
スカウトや活動、表彰の管理を行います。

対応プラットフォーム:
- デスクトップ: Ubuntu (GNOME), Windows
- モバイル: Android, iOS

## 2. 技術方針

### 2.1 推奨技術
- フロントエンド: Flutter もしくは React Native + Tauri
- バックエンド / データベース: Supabase / PostgreSQL
- 認証: Supabase Auth を利用した Google アカウント認証
- デプロイ: Supabase とともにホスティング、または Tauri/Flutter デスクトップ用バイナリ配布

### 2.2 クロスプラットフォーム戦略
- できる限り単一コードベースで UI とデータ処理を共有
- デスクトップではキーボード・マウス最適化、モバイルではタッチ最適化を考慮
- オフライン対応を検討し、イベント中の入力をローカルキャッシュに保存できる設計（後段）

- データベースをMySQLなどローカルDB化し、共有機能を廃止したバージョンも別途実装する

## 3. 利用者と権限

### 3.1 権限設計
- アクセス制御はリーダー種別によって行う

### 3.2 リーダー種別
- 隊長 (`leader`)
- 副長 (`assistant_leader`)
- 補助者（`support`）

### 3.3 権限一覧
- `leader` / `assistant_leader` :
  - ユーザー（承認・参照・追加・削除・更新）
  - スカウト（参照・追加・削除・更新）
  - 保護者（参照・追加・削除・更新）
  - 団委員（参照・追加・削除・更新）
  - 活動（参照・追加・削除・更新）
  - 出欠（参照・更新）
  - 表彰（参照・追加・削除・更新）
- `assistant_leader` :
  - ユーザー（参照）
  - スカウト（参照・追加・削除・更新）
  - 保護者（参照・追加・削除・更新）
  - 団委員（参照・追加・削除・更新）
  - 活動（参照・追加・削除・更新）
  - 出欠（参照・更新）
  - 表彰（参照・追加・削除・更新）
- `support ` :
  - ユーザー（参照）
  - スカウト（参照）
  - 保護者（参照）
  - 団委員管理（参照）
  - 活動管理（参照・更新）
  - 出欠管理（参照・更新）
  - 表彰管理（参照・更新）

## 4. 主要機能

### 4.1 団・隊・リーダー・スカウト・保護者・団委員管理
- 団: 団名、所在地、連絡先
- 隊: ビーバー（固定）
- ユーザー：
  - 隊長：氏名、性別、メールアドレス、電話番号
  - 副長：氏名、性別、メールアドレス、電話番号
  - 補助者：氏名、性別、メールアドレス、電話番号
- スカウト: 氏名、性別、学年、分類、小学校入学年度、入隊日、木の葉章枚数、木の葉章入隊時補正、小枝章本数、活性状態
　- 分類：ビッグビーバー、ビーバー、仮入隊、体験、兄弟姉妹、上進、退団、入隊せず
- 保護者: 氏名、性別、メールアドレス、電話番号、親子関係
　- 保護者とスカウトの紐付け: 多対多で管理し、同じ保護者が複数スカウトを担当、スカウトが複数保護者に紐付くケースを想定
- 団委員：氏名、性別、分類、メールアドレス、電話番号
　- 分類：団委員、他隊リーダー、他団関係者、OB、その他

### 4.2 活動管理
- イベント: タイトル、種別、状態、日付、場所、開始/終了時間、計画書、木の葉章配布数、写真、備考、出席者リスト
  - 種別: 団集会、隊集会、キャンプ、奉仕活動、その他
  - 状態: 予定、開催中、完了、中止
    - イベントクローズ時: 団委員および所属団リーダーへ完了報告のメールを発行できる
  - 木の葉章：健康（赤）、表現（オレンジ）、生活（黃）、自然（緑）、社会（青）

### 4.3 出欠管理
- イベントごとに出席者を管理できる
- 出席者リストはイベント登録時に作成される
  - 以下のメンバはデフォルトで出席者リストに表示される
  　- リーダー
  　- スカウト（上進、退団、入隊せず以外）
- 出席者リストにはあとから都度追加することができる
　- スカウト（上進、退団、入隊せず）
　- 保護者（参加スカウトに親子関係がある場合のみ）
　- 団委員
　- その他
- 出席者リストに表示されていても、欠席というステータスを設定することができる

### 4.4 小枝章履歴管理
  - スカウトごとに小枝章の取得記録を保存
  - 取得年月日、章番号、内容などを詳細に記録する
  - 章番号は1～9までで、それぞれ以下の内容を示す
- 小枝章は、木の葉章10枚ごとに1本授与する必要がある
　- 授与予定（権利発生）、授与済みの状態がリストで確認できる

### 4.5 レポート集計機能
  - スカウトの活動実績レポート
    - 参加した活動、受賞状況、小枝章取得状況などを可視化
  - 木の葉章配布状況レポート
    - 各種別の木の葉章の配布数や分布をグラフ化
  - 保護者参加状況レポート
    - 活動への保護者の参加状況をまとめる
- 出席率：リーダー・スカウト別の出席率
　- 出席率は各リーダー・スカウトごとの出席リストに登録されている 出席数/(出席数+欠席数) から計算する
- 小枝章： 各スカウトの獲得枚数の一覧
- 木の葉章レポート: 獲得枚数の推移をスカウトごとに表示
- CSVエクスポート: 出欠リスト、スカウト一覧をCSV形式で出力

## 5. ユースケース

### 5.1 団の登録（全体管理者）
1. 隊長が団の基本情報を入力する
2. 団名、所在地、連絡先、団コード、主要責任者を登録する

### 5.2 リーダー登録
1. 隊長が副長以下のリーダーを登録する
2. リーダー種別（`assistant_leader` / `support`）を割り当てる

### 5.3 スカウト登録
1. 隊長もしくは副長がスカウト情報を登録する
2. 必要な情報を入力する
3. 保護者が登録されていれば、対応する保護者との親子関係を紐付ける

### 5.4 保護者登録
1. 隊長もしくは副長が保護者情報を登録する
2. 必要な情報を入力する
3. スカウトが登録されていれば、対応するスカウトとの親子関係を紐付ける

### 5.5 団委員登録
1. 隊長もしくは副長が保護者情報を登録する
2. 必要な情報を入力する

### 5.5 イベント登録
1. 隊長もしくは副長がイベントを作成する
2. タイトル、種別、日付、対象隊、場所、開始/終了時間、備考などを登録する

### 5.6 各種情報参照
1. リーダー・スカウト・保護者・団委員・イベントごとに一覧で参照することができる
2. さらに個別の情報を参照することができる

### 5.7 各種情報削除
1. リーダー・スカウト・保護者・団委員・イベントを個別に削除することができる
2. ただし、イベントについては開催済みだったり、出席情報が登録されている場合は削除できない
2. それ以外については、紐付いている親子関係やイベント出席履歴がある場合は削除できない

### 5.8 出欠管理
1. 隊長、副長もしくは補助者が、出席者リストの追加・削除ができる
2. リーダーについてはすべてデフォルトで出席者リストに表示される
3. スカウトについてはビッグビーバー、ビーバー、仮入隊、体験、兄弟姉妹のみがデフォルトで出席者リストに表示される
　- 上記以外のスカウトは個別に出席者リストへ追加することができる
4. 団委員については個別に出席者リストへ追加することができる

### 5.9 イベント完了処理
1. イベントの終了後にイベント状態を `完了` に更新する
2. 同時に木の葉章のスナップショットが確定して保存される
3. リーダーおよび団委員に対して完了報告メールを発行する

### 5.10 ダッシュボード
1. 当月のイベント数、出席率、スカウト数を表示する
2. 直近2ヶ月のイベントを表示する（そこから各イベントの出欠管理が行える）

### 5.11 ログイン認証
1. Google認証を利用する
2. リーダー（隊長・副長・補助者）のみがログイン可能
3. それぞれの役割に応じて権限が設定される

### 5.12 システム設定
1. アプリ設定を管理する（主に見た目）
2. 団情報設定
3. メールテンプレート設定
4. 必要に応じて運用ルールを調整する

## 6. データモデル（Supabase / PostgreSQL）

### 6.1 テーブル設計

#### troops（団）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | 団ID |
| name | varchar(100) | NOT NULL | 団名 |
| location | varchar(200) | | 所在地 |
| contact | varchar(200) | | 連絡先 |
| troop_code | varchar(20) | UNIQUE | 団コード |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

#### users（リーダー）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, references auth.users | Supabase Auth UID |
| troop_id | uuid | FK → troops.id, NOT NULL | 所属団ID |
| name | varchar(100) | NOT NULL | 氏名 |
| gender | varchar(10) | | 性別（male / female / other） |
| email | varchar(200) | NOT NULL, UNIQUE | メールアドレス |
| phone | varchar(20) | | 電話番号 |
| role | varchar(30) | NOT NULL | 種別（leader / assistant_leader / support） |
| is_active | boolean | NOT NULL, default true | 有効フラグ |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

#### scouts（スカウト）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | スカウトID |
| troop_id | uuid | FK → troops.id, NOT NULL | 所属団ID |
| name | varchar(100) | NOT NULL | 氏名 |
| gender | varchar(10) | | 性別（male / female / other） |
| grade | varchar(20) | | 学年 |
| category | varchar(30) | NOT NULL | 分類（big_beaver / beaver / provisional / experience / sibling / promoted / withdrawn / not_joined） |
| enrollment_year | integer | | 小学校入学年度 |
| joined_at | date | | 入隊日 |
| leaf_badges | integer | NOT NULL, default 0 | 木の葉章枚数（累計） |
| leaf_badge_offset | integer | NOT NULL, default 0 | 木の葉章入隊時補正枚数 |
| twig_badges | integer | NOT NULL, default 0 | 小枝章本数 |
| is_active | boolean | NOT NULL, default true | 活性状態 |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

#### guardians（保護者）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | 保護者ID |
| name | varchar(100) | NOT NULL | 氏名 |
| gender | varchar(10) | | 性別（male / female / other） |
| email | varchar(200) | | メールアドレス |
| phone | varchar(20) | | 電話番号 |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

#### scout_guardians（スカウト↔保護者 中間テーブル）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | ID |
| scout_id | uuid | FK → scouts.id, NOT NULL | スカウトID |
| guardian_id | uuid | FK → guardians.id, NOT NULL | 保護者ID |
| relationship | varchar(20) | | 続柄（father / mother / other） |

- UNIQUE(scout_id, guardian_id)

#### committee_members（団委員）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | 団委員ID |
| troop_id | uuid | FK → troops.id, NOT NULL | 所属団ID |
| name | varchar(100) | NOT NULL | 氏名 |
| gender | varchar(10) | | 性別（male / female / other） |
| category | varchar(30) | NOT NULL | 分類（committee / other_leader / other_troop / ob / other） |
| email | varchar(200) | | メールアドレス |
| phone | varchar(20) | | 電話番号 |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

#### events（イベント）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | イベントID |
| troop_id | uuid | FK → troops.id, NOT NULL | 所属団ID |
| title | varchar(200) | NOT NULL | タイトル |
| event_type | varchar(30) | NOT NULL | 種別（group_meeting / troop_meeting / camp / service / other） |
| status | varchar(20) | NOT NULL, default 'planned' | 状態（planned / ongoing / completed / cancelled） |
| event_date | date | NOT NULL | 開催日 |
| location | varchar(200) | | 場所 |
| start_time | time | | 開始時間 |
| end_time | time | | 終了時間 |
| plan_doc_url | text | | 計画書URL |
| photo_urls | text[] | | 写真URL配列 |
| notes | text | | 備考 |
| completed_at | timestamptz | | 完了日時 |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

#### event_leaf_badges（イベント別 木の葉章配布数）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | ID |
| event_id | uuid | FK → events.id, NOT NULL | イベントID |
| badge_type | varchar(20) | NOT NULL | 種別（health / expression / life / nature / society） |
| count | integer | NOT NULL, default 0 | 配布枚数 |

- UNIQUE(event_id, badge_type)

#### attendances（出欠）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | 出欠ID |
| event_id | uuid | FK → events.id, NOT NULL | イベントID |
| member_type | varchar(20) | NOT NULL | 種別（user / scout / guardian / committee / other） |
| member_id | uuid | | メンバーID（member_type が other の場合は NULL） |
| member_name | varchar(100) | | 氏名（member_type が other の場合に使用） |
| status | varchar(20) | NOT NULL, default 'pending' | 出欠状態（present / absent / pending） |
| is_default | boolean | NOT NULL, default false | デフォルト表示フラグ |
| notes | text | | 備考 |

- UNIQUE(event_id, member_type, member_id)

#### twig_badge_history（小枝章履歴）
| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | uuid | PK, default gen_random_uuid() | ID |
| scout_id | uuid | FK → scouts.id, NOT NULL | スカウトID |
| event_id | uuid | FK → events.id | 権利発生イベントID |
| status | varchar(20) | NOT NULL | 状態（pending / awarded） |
| awarded_at | date | | 授与日 |
| created_at | timestamptz | NOT NULL, default now() | 作成日時 |
| updated_at | timestamptz | NOT NULL, default now() | 更新日時 |

---

### 6.2 関係図

```
troops
  │
  ├──< users（リーダー）
  │
  ├──< scouts（スカウト）
  │       │
  │       ├──< scout_guardians >──── guardians（保護者）
  │       │         [多対多]
  │       └──< twig_badge_history（小枝章履歴）
  │
  ├──< committee_members（団委員）
  │
  └──< events（イベント）
          │
          ├──< event_leaf_badges（木の葉章配布数）
          │
          ├──< attendances（出欠）
          │       ├── member_type=user       → users
          │       ├── member_type=scout      → scouts
          │       ├── member_type=guardian   → guardians
          │       ├── member_type=committee  → committee_members
          │       └── member_type=other      （氏名のみ）
          │
          └──< twig_badge_history（小枝章権利発生元）
```

#### 主なリレーション一覧

| テーブル | 参照先 | 種別 | 説明 |
|---|---|---|---|
| users | troops | N:1 | リーダーは1つの団に所属 |
| scouts | troops | N:1 | スカウトは1つの団に所属 |
| committee_members | troops | N:1 | 団委員は1つの団に所属 |
| events | troops | N:1 | イベントは1つの団に属する |
| scout_guardians | scouts / guardians | N:M | スカウト↔保護者の多対多 |
| event_leaf_badges | events | N:1 | イベントごとの木の葉章種別・枚数 |
| attendances | events | N:1 | イベントに対する出欠レコード |
| twig_badge_history | scouts, events | N:1 | スカウトごとの小枝章授与履歴 |

#### 設計メモ

- **attendances の多態参照**: `member_type` + `member_id` の組み合わせでリーダー・スカウト・保護者・団委員・その他を1テーブルで管理する。アプリ側で `member_type` に応じたJOINを行う。
- **木の葉章の累計管理**: `scouts.leaf_badges` はイベント完了時にアプリ側で加算する。`leaf_badge_offset` は入隊前取得分の補正値。小枝章の権利は `(leaf_badges + leaf_badge_offset) / 10` の整数部から既授与数を引いた値で判定する。
- **イベント完了スナップショット**: `events.status` を `completed` に更新した時点で `event_leaf_badges` の配布数を確定し、各スカウトの `leaf_badges` へ反映する。
- **削除制約**: `attendances` や `scout_guardians` に紐付くレコードが存在する場合、親レコードの削除はアプリ側で拒否する（物理削除禁止）。
- **RLS（Row Level Security）**: Supabase 利用時は `troop_id` を基準にポリシーを設定し、他団のデータへのアクセスを遮断する。

## 7. UI / UX 要件

### 7.1 共通要件
- シンプルで視認性の高い一覧表示
- 権限に応じた情報フィルタ
- 重要な操作は確認ダイアログを表示
- モバイルでは縦スクロール中心、デスクトップではテーブル表示を活用
