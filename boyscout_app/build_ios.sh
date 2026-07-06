#!/bin/bash
# BeaverLog iOS ビルドスクリプト
# Usage:
#   ./build_ios.sh          # 実機インストール（デフォルト）
#   ./build_ios.sh --store  # App Store Connect用 IPA ビルド＋アップロード

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

DART_DEFINES="--dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

security unlock-keychain ~/Library/Keychains/login.keychain-db

# --- App Store Connect 用 IPA ビルド ---
if [ "$1" = "--store" ]; then
  echo "=== App Store Connect 用 IPA ビルド開始 ==="
  flutter build ipa --release $DART_DEFINES
  IPA_PATH=$(find "$SCRIPT_DIR/build/ios/ipa" -name "*.ipa" | head -1)
  echo "IPA: $IPA_PATH"

  echo "=== App Store Connect へアップロード ==="
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "${APP_STORE_API_KEY:-}" \
    --apiIssuer "${APP_STORE_API_ISSUER:-}" \
    2>&1 | tail -5

  echo "=== 完了 ==="
  exit 0
fi

# --- 実機インストール ---
DEVICE_ID=$(flutter devices 2>/dev/null | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -1)
if [ -z "$DEVICE_ID" ]; then
  echo "エラー: iOSデバイスが見つかりません"
  exit 1
fi
echo "デバイス: $DEVICE_ID"

echo "=== iOS ビルド＋インストール開始 ==="
flutter run --release --device-id "$DEVICE_ID" $DART_DEFINES

echo "=== 完了 ==="
