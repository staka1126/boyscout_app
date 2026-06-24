# ビーバーログ（BeaverLog）

ボーイスカウト ビーバー隊の隊務管理アプリ。

---

## 技術スタック

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter |
| 対応プラットフォーム | Android / Linux デスクトップ / iOS |
| データベース（ローカル） | SQLite（sqflite + sqflite_common_ffi） |
| クラウドバックエンド | Supabase（マルチユーザー同期・認証） |
| 状態管理 | flutter_riverpod |
| ルーティング | go_router |
| 電話・メール起動 | url_launcher |
| DBバージョン | 8 |

---

## ディレクトリ構成

```
boyscout_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/       # enum定義・DBバージョン
│   │   ├── router/          # GoRouter設定
│   │   └── theme/           # テーマ設定
│   ├── data/
│   │   ├── import/          # Excelインポート・バッチ登録
│   │   ├── local/           # DatabaseHelper・EventStatsService
│   │   ├── models/          # データモデル
│   │   ├── providers/       # Riverpod Provider
│   │   ├── repositories/    # DB操作
│   │   └── sync/            # Supabase同期サービス
│   └── features/
│       ├── attendance/      # 出欠管理
│       ├── auth/            # 認証・ログイン
│       ├── badges/          # 表彰管理
│       ├── dashboard/       # ダッシュボード
│       ├── events/          # イベント管理
│       ├── scouts/          # スカウト管理
│       └── settings/        # 設定・各種管理画面
├── test/
│   ├── unit_test.dart       # Unitテスト
│   └── widget_test.dart     # Widgetテスト
└── integration_test/
    └── app_test.dart        # 統合テスト
```

---

## セットアップ

```bash
cp .env.example .env        # SUPABASE_URL・SUPABASE_ANON_KEY を設定
flutter pub get
```

### 実行

```bash
./run.sh                    # Linux（--dart-define 付きで起動）
flutter run -d android      # Android
```

### Android リリースビルド

```bash
./build_android.sh          # APKビルド＋デバイスへ転送
adb install -r --no-streaming app-release.apk  # Xiaomiデバイス向け
```

### iOS リリースビルド

```bash
chmod +x build_ios.sh
./build_ios.sh              # IPAビルド
```

App Store Connect へのアップロードは Xcode Organizer から手動で行う。

---

## テスト

### Unit テスト

```bash
flutter test test/unit_test.dart
```

| グループ | 内容 |
|---|---|
| `Scout.totalLeafBadges` | 補正なし・減算・負値・両方0 |
| `Scout.pendingTwigBadges` | 10枚ごとの小枝章計算・補正考慮・授与済み |
| `Scout.pendingOtherBadges` | 他分類用表彰数（offset不使用） |
| 小枝章 N本まとめて授与 | 授与後に pending=0 になること |
| `Scout.isTwigBadgeEligible` | 各分類の小枝章対象判定 |
| `ScoutCategory.isDefaultAttendee` | 全8分類のデフォルト出席判定 |
| `UserRole` | canEdit / canManageUsers / fromValue |
| `EventStatus.fromValue` / `.label` | planned / completed / cancelled の変換・ラベル |
| `AllergyType.fromValue` | 変換・不明値フォールバック |
| Scout アレルギーパース | カンマ区切り・null・空文字・全種別 |
| Scout toMap/fromMap | ラウンドトリップ・全カテゴリパース |
| 出席率計算 | ゼロ除算・未定を分母に含まない |
| 皆勤賞判定 | 全出席・1欠席・記録なし・イベント0件 |
| `LeafBadgeType` / `MemberType` / `CommitteeCategory` / `AttendanceStatus` | fromValue・ラベル |
| `fiscalYear`（年度計算） | 4月始まりの境界値 |

### Widget テスト

```bash
flutter test test/widget_test.dart
```

| グループ | 内容 |
|---|---|
| 性別ラジオボタン | 表示・未選択・初期値・タップ選択 |
| スカウト情報表示 | 氏名・分類・木の葉章合計・アレルギーチップ |
| イベントステータス表示 | 予定・実施済・非開催のラベル |
| ScoutCategory ラベル表示 | 各分類のラベル |
| AllergyType ラベル表示 | 全11種別のチップ表示 |
| 出席ステータス表示 | 出席・欠席・未定のラベルとアイコン |
| 小枝章授与ボタン | 授与待ちあり（ボタン表示）・なし（非表示） |
| 小枝章 N本授与ダイアログ | 1本・2本・3本・キャンセル |
| 未保存変更確認ダイアログ | 表示・キャンセルで閉じる |
| 皆勤賞「該当なし」表示 | メッセージとアイコン |
| 確認ダイアログ | 削除確認・キャンセルで閉じる |
| 木の葉章進捗バー | 50%進捗・10枚達成で0にリセット |

### 統合テスト

> **注意**: 統合テストは `app.main()` 経由でアプリ全体を起動するため、`SUPABASE_URL` / `SUPABASE_ANON_KEY` の `--dart-define` 指定が必須です。未指定の場合は assert で落ちます。

```bash
chmod +x test_integration.sh
./test_integration.sh       # .env を自動読み込みして実行
```

| グループ | 内容 |
|---|---|
| オンボーディングフロー | 初回起動でウェルカム画面表示 |
| ダッシュボード | 団情報あり時の表示・FAB表示 |
| BottomNavigationBar | 各タブへの遷移 |
| 設定画面 | 団情報・リーダー・保護者・団委員・電話帳・アレルギー各画面への遷移 |
| イベント作成制限 | リーダー/スカウト未登録時のSnackBar警告・登録済み時のフォーム遷移 |
| スカウト登録フロー | 一覧表示・フォーム・保存・検索絞り込み |
| リーダー登録フロー | フォーム・保存後の一覧表示 |
| イベント管理フロー | 画面遷移・0件時の空メッセージ |

---

## DBスキーマ変更履歴

| バージョン | 変更内容 |
|---|---|
| v1 | 初期スキーマ |
| v2 | `users` / `committee_members` に `is_retired` カラム追加 |
| v3 | `scouts` に `birthday` / `allergies` / `special_notes` カラム追加 |
| v4 | `guardians` に `troop_id` カラム追加 |
| v5 | `users` テーブルを `leaders` にリネーム |
| v6 | `scouts` に `other_badges` カラム追加 |
| v7 | `event_stats` テーブル追加 |
| v8 | `event_stats` に各分類の欠席数カラム追加 |

`onUpgrade` は try-catch で重複エラーを吸収。

---

## SPEC

詳細仕様は `SPEC.md` を参照。
