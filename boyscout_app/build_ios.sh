#!/bin/bash
# BeaverLog iOS リリースビルドスクリプト
# App Store Connect へのアップロードは Xcode Organizer から手動で行う

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

echo "=== iOS IPA ビルド開始 ==="
flutter build ipa --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

IPA_DIR="$SCRIPT_DIR/build/ios/ipa"

echo ""
echo "=== ビルド完了 ==="
ls -lh "$IPA_DIR"/*.ipa 2>/dev/null || echo "IPAファイルが見つかりません: $IPA_DIR"

echo ""
echo "App Store Connect へのアップロードは以下のいずれかで行ってください："
echo "  1. Xcode → Window → Organizer から手動アップロード"
echo "  2. xcrun altool または xcrun notarytool（要 API キー設定）"
