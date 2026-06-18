#!/bin/bash
# BeaverLog 開発用起動スクリプト
# .env ファイルから環境変数を読み込んで flutter run を実行する

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "エラー: .env ファイルが見つかりません: $ENV_FILE"
  echo ""
  echo ".env ファイルを作成してください："
  echo "  SUPABASE_URL=https://xxxx.supabase.co"
  echo "  SUPABASE_ANON_KEY=eyJ..."
  exit 1
fi

# .env を読み込む
export $(grep -v '^#' "$ENV_FILE" | xargs)

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "エラー: .env に SUPABASE_URL または SUPABASE_ANON_KEY が設定されていません"
  exit 1
fi

echo "Supabase URL: $SUPABASE_URL"
echo "起動中..."

flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  "$@"
