#!/bin/bash
# BVS隊務管理 Excel → ビーバーログ インポートスクリプト
# 使い方: ./tools/run_import.sh <Excelファイルパス>

set -e

EXCEL_PATH="${1}"
DB_PATH="${HOME}/.local/share/boyscout_app/boyscout.db"
DB_DIR="$(dirname "$DB_PATH")"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
DATE_PREFIX="$(date +%Y%m%d)"

# 引数チェック
if [ -z "$EXCEL_PATH" ]; then
  echo "使い方: $0 <Excelファイルパス>"
  echo "例:     $0 ~/Downloads/BVS隊務管理.xlsx"
  exit 1
fi

if [ ! -f "$EXCEL_PATH" ]; then
  echo "❌ ファイルが見つかりません: $EXCEL_PATH"
  exit 1
fi

# DBディレクトリがなければ作成
mkdir -p "$DB_DIR"

# 既存DBをバックアップ
if [ -f "$DB_PATH" ]; then
  BACKUP_PATH="${DB_DIR}/${DATE_PREFIX}_boyscout.db"
  echo "📦 既存DBをバックアップ: $BACKUP_PATH"
  cp "$DB_PATH" "$BACKUP_PATH"
fi

# インポート先の一時DB
IMPORT_DB="/tmp/beaverlog_import_$$.db"

echo "🚀 インポート開始..."
cd "$TOOLS_DIR"
dart run import_excel.dart "$EXCEL_PATH" "$IMPORT_DB"

# アプリのDBパスにコピー
echo "📋 DBをアプリパスにコピー: $DB_PATH"
cp "$IMPORT_DB" "$DB_PATH"
rm -f "$IMPORT_DB"

echo ""
echo "✅ 完了！アプリを起動して確認してください。"
