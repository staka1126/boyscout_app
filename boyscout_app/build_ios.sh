#!/bin/bash
# BeaverLog iOS ビルド＋実機インストールスクリプト（ワイヤレス対応）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# .env 読み込み
if [ ! -f "$ENV_FILE" ]; then
  echo "エラー: .env ファイルが見つかりません"
  exit 1
fi
export $(grep -v '^#' "$ENV_FILE" | xargs)

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "エラー: SUPABASE_URL または SUPABASE_ANON_KEY が未設定です"
  exit 1
fi

# 接続デバイスの確認（USB・ワイヤレス両対応）
DEVICE_ID=$(flutter devices 2>/dev/null | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -1)
if [ -z "$DEVICE_ID" ]; then
  echo "エラー: iOSデバイスが見つかりません"
  echo "デバイスを接続（USB or ワイヤレス）して再実行してください"
  exit 1
fi
echo "デバイス検出: $DEVICE_ID"

echo ""
echo "=== iOS ビルド＋インストール開始 ==="
flutter run --release \
  --device-id "$DEVICE_ID" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo ""
echo "=== 完了 ==="
