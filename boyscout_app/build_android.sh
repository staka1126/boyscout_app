#!/bin/bash
# BeaverLog Android リリースビルド＋転送スクリプト

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

echo "=== Android APK ビルド開始 ==="
flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

APK_PATH="$SCRIPT_DIR/build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$APK_PATH" ]; then
  echo "エラー: APKが見つかりません: $APK_PATH"
  exit 1
fi

echo ""
echo "=== ビルド完了 ==="
ls -lh "$APK_PATH"

# ADB転送（デバイスが接続されていれば）
if adb devices | grep -q "device$"; then
  echo ""
  echo "=== デバイスへインストール中 ==="
  adb install -r --no-streaming "$APK_PATH"
  echo "=== インストール完了 ==="
else
  echo ""
  echo "デバイスが接続されていません。APKは以下にあります："
  echo "  $APK_PATH"
fi
