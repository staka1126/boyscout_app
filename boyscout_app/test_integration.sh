#!/bin/bash
# BeaverLog 統合テスト実行スクリプト
# .env ファイルから環境変数を読み込んで flutter test を実行する

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "エラー: .env ファイルが見つかりません: $ENV_FILE"
  echo ""
  echo ".env ファイルを作成してください："
  echo "  SUPABASE_URL=https://xxxx.supabase.co"
  echo "  SUPABASE_ANON_KEY=eyJ..."
  echo "  TEST_EMAIL=test@example.com"
  echo "  TEST_PASSWORD=password"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "エラー: .env に SUPABASE_URL または SUPABASE_ANON_KEY が設定されていません"
  exit 1
fi

if [ -z "$TEST_EMAIL" ] || [ -z "$TEST_PASSWORD" ]; then
  echo "エラー: .env に TEST_EMAIL または TEST_PASSWORD が設定されていません"
  exit 1
fi

echo "=== 統合テスト開始 ==="
flutter test integration_test/app_test.dart \
  -d linux \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=TEST_EMAIL="$TEST_EMAIL" \
  --dart-define=TEST_PASSWORD="$TEST_PASSWORD" \
  "$@"
