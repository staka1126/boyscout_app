# ビーバー隊 隊務管理アプリ

## セットアップ

### 必要環境
- Flutter 3.22以上
- Android SDK 21以上 (Android 5.0+)

### 依存パッケージのインストール
```bash
cd boyscout_app
flutter pub get
```

### 実行
```bash
# Android実機 or エミュレータ
flutter run

# リリースビルド
flutter build apk --release
```

---

## プロジェクト構成

```
lib/
├── main.dart                          # エントリポイント
├── core/
│   ├── constants/app_constants.dart   # Enum定義（UserRole, ScoutCategory, EventType…）
│   ├── router/app_router.dart         # GoRouter + BottomNavigationBar Shell
│   └── theme/app_theme.dart           # Material3テーマ（ライト/ダーク）
├── data/
│   ├── local/database_helper.dart     # SQLite スキーマ定義・初期化
│   ├── models/models.dart             # 全データモデル（Troop, Scout, Event…）
│   ├── repositories/repositories.dart # CRUD操作（全エンティティ）
│   └── providers/app_state_provider.dart # 現在の団ID・ユーザー状態
└── features/
    ├── dashboard/dashboard_page.dart   # ダッシュボード（サマリ・直近イベント）
    ├── scouts/
    │   ├── scouts_page.dart            # スカウト一覧（検索・フィルタ）
    │   ├── scout_form_page.dart        # スカウト追加・編集フォーム
    │   ├── scout_detail_page.dart      # スカウト詳細（木の葉章進捗）
    │   └── guardian_form_page.dart     # 保護者追加・スカウト紐付け
    ├── events/
    │   ├── events_page.dart            # イベント一覧
    │   ├── event_form_page.dart        # イベント追加・編集フォーム
    │   └── event_detail_page.dart      # イベント詳細（完了処理・木の葉章設定）
    ├── attendance/attendance_page.dart  # 出欠管理（リーダー・スカウト・その他）
    ├── badges/badges_page.dart          # 小枝章授与 / 木の葉章一覧
    └── settings/
        ├── settings_page.dart          # 設定トップ
        ├── troop_setup_page.dart       # 団情報編集
        └── user_form_page.dart         # リーダー追加・編集
```

---

## 主要な仕様対応

| 機能 | 実装状況 |
|---|---|
| スカウト CRUD（8分類） | ✅ |
| 保護者 CRUD + 多対多紐付け | ✅ |
| リーダー CRUD（3種別） | ✅ |
| 団委員 CRUD（5分類） | ✅ |
| イベント CRUD（5種別・4状態） | ✅ |
| イベント作成時にデフォルト出席者自動生成 | ✅ |
| 出欠管理（出席/欠席/未定 3択） | ✅ |
| 出席者リスト追加（スカウト/団委員/その他） | ✅ |
| 木の葉章配布数の設定（5色） | ✅ |
| イベント完了処理→木の葉章をスカウトに反映 | ✅ |
| 小枝章権利チェック（10枚ごとに1本） | ✅ |
| 小枝章授与処理 | ✅ |
| ダッシュボード（サマリ・直近イベント） | ✅ |
| 出席率集計 | ✅ |
| 削除制約（履歴ありは削除不可） | ✅ |
| SQLiteローカルDB | ✅ |
| Material3 ライト/ダークテーマ | ✅ |
| Android対応 | ✅ |
| Google認証（Supabase） | 未実装（MVP後対応） |
| CSVエクスポート | 未実装（MVP後対応） |

---

## データベース

SQLite（sqflite）を使用。`boyscout.db` に以下のテーブルを作成します。

- `troops` 団情報
- `users` リーダー
- `scouts` スカウト
- `guardians` 保護者
- `scout_guardians` スカウト↔保護者（多対多）
- `committee_members` 団委員
- `events` イベント
- `event_leaf_badges` イベント別木の葉章配布数
- `attendances` 出欠
- `twig_badge_history` 小枝章履歴
