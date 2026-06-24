#!/bin/bash
# BeaverLog iOS ビルド＋実機インストールスクリプト
# 事前に ios-deploy が必要: brew install ios-deploy

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

# ios-deploy の確認
if ! command -v ios-deploy &> /dev/null; then
  echo "エラー: ios-deploy が見つかりません"
  echo "  brew install ios-deploy"
  exit 1
fi

# 接続デバイスの確認
DEVICE_ID=$(ios-deploy --detect --timeout 5 2>/dev/null | grep -oE '[0-9A-Fa-f]{40}' | head -1)
if [ -z "$DEVICE_ID" ]; then
  echo "エラー: 接続されているiOSデバイスが見つかりません"
  echo "デバイスをUSB接続して再実行してください"
  exit 1
fi
echo "デバイス検出: $DEVICE_ID"

echo ""
echo "=== iOS IPA ビルド開始 ==="
flutter build ipa --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

IPA_PATH=$(ls "$SCRIPT_DIR/build/ios/ipa/"*.ipa 2>/dev/null | head -1)
if [ -z "$IPA_PATH" ]; then
  echo "エラー: IPAファイルが見つかりません"
  exit 1
fi

echo ""
echo "=== ビルド完了 ==="
ls -lh "$IPA_PATH"

echo ""
echo "=== 実機インストール開始 ==="
ios-deploy --id "$DEVICE_ID" --bundle "$IPA_PATH"

echo ""
echo "=== インストール完了 ==="
