# ビーバーログ（BeaverLog）

ボーイスカウト ビーバー隊の隊務管理アプリ。

---

## 技術スタック

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter |
| 対応プラットフォーム | Android / Linux デスクトップ |
| データベース | SQLite（sqflite + sqflite_common_ffi） |
| 状態管理 | flutter_riverpod |
| ルーティング | go_router |
| 電話・メール起動 | url_launcher |
| DBバージョン | 3 |

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
│   │   ├── local/           # DatabaseHelper
│   │   ├── models/          # データモデル
│   │   ├── providers/       # Riverpod Provider
│   │   └── repositories/    # DB操作
│   └── features/
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
flutter pub get
flutter run -d linux        # Linux
flutter run -d android      # Android
```

### Android ビルド

```bash
flutter build apk --debug
adb install android/app/build/outputs/flutter-apk/app-debug.apk
```

### DB マイグレーション（Linux既存DB）

```bash
sqlite3 ~/.local/share/boyscout_app/boyscout.db << 'SQL'
ALTER TABLE users ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0;
ALTER TABLE committee_members ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0;
ALTER TABLE scouts ADD COLUMN birthday TEXT;
ALTER TABLE scouts ADD COLUMN allergies TEXT;
ALTER TABLE scouts ADD COLUMN special_notes TEXT;
SQL
```

---

## テスト

### Unit テスト

ビジネスロジック・モデルの計算ロジックをテストします。

```bash
flutter test test/unit_test.dart
```

| グループ | テスト数 | 内容 |
|---|---|---|
| `Scout.totalLeafBadges` | 4件 | 補正なし・減算・負値・両方0 |
| `Scout.pendingTwigBadges` | 5件 | 10枚ごとの小枝章計算・補正考慮・授与済み |
| `Scout.isTwigBadgeEligible` | 3件 | ビーバー/ビッグビーバー（対象）・上進（対象外） |
| `EventStatus.fromValue` | 4件 | planned / completed / cancelled の変換・不明値フォールバック |
| `AllergyType.fromValue` | 3件 | egg / dairy の変換・不明値フォールバック |
| アレルギーパース | 2件 | カンマ区切り文字列のパース・null の場合空リスト |
| `fiscalYear`（年度計算） | 4件 | 4月始まりの年度（4月・3月・1月・12月） |

### Widget テスト

UIコンポーネントの表示・操作をテストします。DBや外部依存なし。

```bash
flutter test test/widget_test.dart
```

| グループ | テスト数 | 内容 |
|---|---|---|
| 性別ラジオボタン | 4件 | 男性・女性の表示、未選択状態、タップ選択、初期値反映 |
| スカウト情報表示 | 4件 | 氏名・分類の表示、木の葉章合計（補正後）、アレルギーチップ表示・非表示 |
| イベントステータス表示 | 3件 | 予定・完了・非開催のラベル表示 |
| 小枝章授与ボタン | 2件 | 授与待ちあり（ボタン表示）・なし（非表示） |
| 確認ダイアログ | 2件 | ダイアログ表示、キャンセルで閉じる |
| 木の葉章進捗バー | 2件 | 50%進捗の表示、10枚達成で0にリセット |

### 統合テスト

実際のアプリを起動してフローをE2Eテストします。各テストは事前にDBとSharedPreferencesをリセットして独立した状態で実行されます。

```bash
flutter pub get
flutter test integration_test/app_test.dart -d linux
```

| グループ | テスト数 | 内容 |
|---|---|---|
| オンボーディングフロー | 2件 | 初回起動（DB空）でウェルカム画面表示、スキップでダッシュボードへ遷移 |
| BottomNavigationBarナビゲーション | 1件 | スカウト・ダッシュボード・設定タブへの遷移 |
| 設定画面 | 2件 | メニュー項目（リーダー管理・スカウト管理・電話帳・アレルギー情報）の表示、団情報画面への遷移 |
| イベント作成制限 | 1件 | 団情報あり・リーダー/スカウト未登録の状態でFABタップ時にSnackBarで警告 |
| スカウト登録フロー | 3件 | 一覧画面の表示、追加フォームを開く、氏・名を入力して保存 |
| リーダー登録フロー | 1件 | 追加フォームを開く、種別ラジオボタン（隊長・副長・補助者）の表示確認 |

> 各テストは `_resetApp()` でDBの全テーブルをクリアし、`SharedPreferences.setMockInitialValues({})` でキャッシュをリセットした状態で実行します。イベント作成制限テストのみ、団情報だけを直接DBに挿入した状態でテストします。

---

## DBスキーマ変更履歴

| バージョン | 変更内容 |
|---|---|
| v1 | 初期スキーマ |
| v2 | `users` / `committee_members` に `is_retired` カラム追加 |
| v3 | `scouts` に `birthday` / `allergies` / `special_notes` カラム追加 |

`onUpgrade` は try-catch で重複エラーを吸収。

---

## SPEC

詳細仕様は `SPEC.md` を参照。
