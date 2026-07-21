// supabase/functions/heat-alerts-sync/index.ts
//
// 熱中症アラート同期 Edge Function
// -----------------------------------------------------------------------
// - 環境省 熱中症予防情報サイト API（getForecastData）から、地点マスタに登録
//   された各代表地点の暑さ指数(WBGT)予測値（当日〜翌々日）を取得する
// - 1日単位の最高値を算出し、危険度(level)を付与して heat_alerts に upsert
// - target_date が今日より前のレコードを削除し、テーブルを常に
//   「当日〜翌々日 × 地点数」の小さなローリングテーブルに保つ
//
// 【重要な注意点】
// 環境省の熱中症警戒アラート／特別警戒アラートの「発表」自体は、本Edge
// Functionが呼んでいる getForecastData / getSurveyData の JSON API には
// 含まれていません（公式発表情報は別途CSV提供のみで、JSON API仕様書には
// 記載がありませんでした）。そのため本実装では、WBGT予測値をもとに
// classifyLevel() で算出した5段階の危険度のみを扱い、"熱中症警戒アラート
// が発表されたかどうか" という公式フラグは持ちません。将来的に公式発表
// 情報のCSVを別途取り込む場合は、このEdge Functionとは別処理として追加
// してください。
//
// 【スケジュール】
// Supabase Cron（pg_cron + pg_net）から1日数回呼び出す想定。
// 例: 毎日 05:10 JST・17:10 JST（アラート発表タイミングに合わせる）
//   SQL Editorで以下のように登録：
//     select cron.schedule(
//       'heat_alerts_sync_morning',
//       '10 20 * * *', -- UTC基準。JST 05:10 = UTC前日20:10
//       $$ select net.http_post(
//            url := 'https://<project>.supabase.co/functions/v1/heat-alerts-sync',
//            headers := jsonb_build_object('Authorization', 'Bearer ' || '<anon or service key>')
//          ) $$
//     );
//
// 【運用期間】
// 環境省サービスは例年4月下旬〜10月下旬のみ稼働。運用期間外はAPIが
// エラーまたは空応答を返す想定のため、呼び出し自体は通年スケジュール
// のままでよい（エラー時は heat_alerts を変更しないだけ）。

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// --- 地点マスタ ---------------------------------------------------------
// lib/core/wbgt_prefecture_master.dart と内容を同期させること。
// 都道府県ごとの代表地点＋一部県の追加候補（離島・地方区分）を含む。
interface WbgtPointMaster {
  pointCode: string; // 地点番号（wbgt_nos）
  pointName: string;
  prefCode: string; // 環境省 pref_cds（参考値。今回は地点別取得のため未使用）
  prefName: string;
}

const WBGT_POINTS: WbgtPointMaster[] = [
  { pointCode: "14163", pointName: "札幌", prefCode: "14", prefName: "北海道" },
  { pointCode: "11016", pointName: "稚内", prefCode: "14", prefName: "北海道" },
  { pointCode: "12442", pointName: "旭川", prefCode: "14", prefName: "北海道" },
  { pointCode: "17521", pointName: "北見", prefCode: "14", prefName: "北海道" },
  { pointCode: "19432", pointName: "釧路", prefCode: "14", prefName: "北海道" },
  { pointCode: "18273", pointName: "根室", prefCode: "14", prefName: "北海道" },
  { pointCode: "20432", pointName: "帯広", prefCode: "14", prefName: "北海道" },
  { pointCode: "23232", pointName: "函館", prefCode: "14", prefName: "北海道" },
  { pointCode: "31312", pointName: "青森", prefCode: "31", prefName: "青森県" },
  { pointCode: "32402", pointName: "秋田", prefCode: "32", prefName: "秋田県" },
  { pointCode: "33431", pointName: "盛岡", prefCode: "33", prefName: "岩手県" },
  { pointCode: "34392", pointName: "仙台", prefCode: "34", prefName: "宮城県" },
  { pointCode: "35426", pointName: "山形", prefCode: "35", prefName: "山形県" },
  { pointCode: "36127", pointName: "福島", prefCode: "36", prefName: "福島県" },
  { pointCode: "40201", pointName: "水戸", prefCode: "40", prefName: "茨城県" },
  { pointCode: "41277", pointName: "宇都宮", prefCode: "41", prefName: "栃木県" },
  { pointCode: "42251", pointName: "前橋", prefCode: "42", prefName: "群馬県" },
  { pointCode: "43056", pointName: "熊谷", prefCode: "43", prefName: "埼玉県" },
  { pointCode: "44132", pointName: "東京", prefCode: "44", prefName: "東京都" },
  { pointCode: "44172", pointName: "大島", prefCode: "44", prefName: "東京都" },
  { pointCode: "44263", pointName: "八丈島", prefCode: "44", prefName: "東京都" },
  { pointCode: "44301", pointName: "父島", prefCode: "44", prefName: "東京都" },
  { pointCode: "45147", pointName: "銚子", prefCode: "45", prefName: "千葉県" },
  { pointCode: "46106", pointName: "横浜", prefCode: "46", prefName: "神奈川県" },
  { pointCode: "48156", pointName: "長野", prefCode: "48", prefName: "長野県" },
  { pointCode: "49142", pointName: "甲府", prefCode: "49", prefName: "山梨県" },
  { pointCode: "50331", pointName: "静岡", prefCode: "50", prefName: "静岡県" },
  { pointCode: "51106", pointName: "名古屋", prefCode: "51", prefName: "愛知県" },
  { pointCode: "52586", pointName: "岐阜", prefCode: "52", prefName: "岐阜県" },
  { pointCode: "53133", pointName: "津", prefCode: "53", prefName: "三重県" },
  { pointCode: "54232", pointName: "新潟", prefCode: "54", prefName: "新潟県" },
  { pointCode: "55102", pointName: "富山", prefCode: "55", prefName: "富山県" },
  { pointCode: "56227", pointName: "金沢", prefCode: "56", prefName: "石川県" },
  { pointCode: "57066", pointName: "福井", prefCode: "57", prefName: "福井県" },
  { pointCode: "60131", pointName: "彦根", prefCode: "60", prefName: "滋賀県" },
  { pointCode: "61286", pointName: "京都", prefCode: "61", prefName: "京都府" },
  { pointCode: "62078", pointName: "大阪", prefCode: "62", prefName: "大阪府" },
  { pointCode: "63518", pointName: "神戸", prefCode: "63", prefName: "兵庫県" },
  { pointCode: "64036", pointName: "奈良", prefCode: "64", prefName: "奈良県" },
  { pointCode: "65042", pointName: "和歌山", prefCode: "65", prefName: "和歌山県" },
  { pointCode: "66408", pointName: "岡山", prefCode: "66", prefName: "岡山県" },
  { pointCode: "67437", pointName: "広島", prefCode: "67", prefName: "広島県" },
  { pointCode: "68132", pointName: "松江", prefCode: "68", prefName: "島根県" },
  { pointCode: "68022", pointName: "西郷（隠岐）", prefCode: "68", prefName: "島根県" },
  { pointCode: "69122", pointName: "鳥取", prefCode: "69", prefName: "鳥取県" },
  { pointCode: "71106", pointName: "徳島", prefCode: "71", prefName: "徳島県" },
  { pointCode: "72086", pointName: "高松", prefCode: "72", prefName: "香川県" },
  { pointCode: "73166", pointName: "松山", prefCode: "73", prefName: "愛媛県" },
  { pointCode: "74182", pointName: "高知", prefCode: "74", prefName: "高知県" },
  { pointCode: "81428", pointName: "下関", prefCode: "81", prefName: "山口県" },
  { pointCode: "82182", pointName: "福岡", prefCode: "82", prefName: "福岡県" },
  { pointCode: "83216", pointName: "大分", prefCode: "83", prefName: "大分県" },
  { pointCode: "84496", pointName: "長崎", prefCode: "84", prefName: "長崎県" },
  { pointCode: "84072", pointName: "厳原（対馬）", prefCode: "84", prefName: "長崎県" },
  { pointCode: "84536", pointName: "福江（五島）", prefCode: "84", prefName: "長崎県" },
  { pointCode: "85142", pointName: "佐賀", prefCode: "85", prefName: "佐賀県" },
  { pointCode: "86141", pointName: "熊本", prefCode: "86", prefName: "熊本県" },
  { pointCode: "87376", pointName: "宮崎", prefCode: "87", prefName: "宮崎県" },
  { pointCode: "88317", pointName: "鹿児島", prefCode: "88", prefName: "鹿児島県" },
  { pointCode: "88612", pointName: "種子島", prefCode: "88", prefName: "鹿児島県" },
  { pointCode: "88686", pointName: "屋久島", prefCode: "88", prefName: "鹿児島県" },
  { pointCode: "88836", pointName: "名瀬（奄美）", prefCode: "88", prefName: "鹿児島県" },
  { pointCode: "91197", pointName: "那覇", prefCode: "91", prefName: "沖縄県" },
  { pointCode: "93041", pointName: "宮古島", prefCode: "91", prefName: "沖縄県" },
  { pointCode: "94081", pointName: "石垣島", prefCode: "91", prefName: "沖縄県" },
  { pointCode: "94017", pointName: "与那国島", prefCode: "91", prefName: "沖縄県" },
];

const WBGT_API_BASE = "https://www.wbgt.env.go.jp/api/v1";

// WBGT危険度の5段階判定（日本生気象学会の基準に準拠。単位: ℃）
type HeatLevel = "safe" | "caution" | "caution_high" | "severe_caution" | "danger";

function classifyLevel(wbgt: number): HeatLevel {
  if (wbgt >= 31) return "danger"; // 危険
  if (wbgt >= 28) return "severe_caution"; // 厳重警戒
  if (wbgt >= 25) return "caution_high"; // 警戒
  if (wbgt >= 21) return "caution"; // 注意
  return "safe"; // ほぼ安全
}

function formatDate14(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}${m}${day}000000`;
}

function toYmd(dateLike: string): string {
  // API の forecast_time は "2023/05/01 03:00:00" 形式で返る
  return dateLike.slice(0, 10).replaceAll("/", "-");
}

interface HeatAlertRow {
  point_code: string;
  point_name: string;
  prefecture_code: string;
  target_date: string; // YYYY-MM-DD
  max_wbgt: number;
  level: HeatLevel;
  fetched_at: string;
}

Deno.serve(async (_req: Request) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const now = new Date();
  const from = new Date(now);
  from.setHours(0, 0, 0, 0);
  const to = new Date(from);
  to.setDate(to.getDate() + 3); // 当日+翌々日をカバーするため+3日分を要求

  const rows: HeatAlertRow[] = [];
  const errors: string[] = [];
  const fetchedAt = now.toISOString();

  for (const point of WBGT_POINTS) {
    try {
      const url =
        `${WBGT_API_BASE}/getForecastData` +
        `?location_type=1&wbgt_nos=${point.pointCode}` +
        `&date_search_type=1` +
        `&range_date_from=${formatDate14(from)}` +
        `&range_date_to=${formatDate14(to)}`;

      const res = await fetch(url);
      const json = await res.json();

      if (json.status !== "success") {
        // 運用期間外（4月下旬〜10月下旬以外）はここに入る想定。異常ではないので
        // ログのみ残し処理は継続する。
        errors.push(`${point.pointName}(${point.pointCode}): ${json.errMsg ?? "no data"}`);
        continue;
      }

      // forecast_time（3時間毎など）を日付単位に丸め、その日の最大値を採用
      const dailyMax = new Map<string, number>();
      for (const item of json.data ?? []) {
        const date = toYmd(String(item.forecast_time));
        const val = Number(item.forecast_val) / 10; // 0.1℃刻みの想定。実データで要検証
        if (Number.isNaN(val)) continue;
        if (!dailyMax.has(date) || dailyMax.get(date)! < val) {
          dailyMax.set(date, val);
        }
      }

      for (const [date, maxWbgt] of dailyMax) {
        rows.push({
          point_code: point.pointCode,
          point_name: point.pointName,
          prefecture_code: point.prefCode,
          target_date: date,
          max_wbgt: maxWbgt,
          level: classifyLevel(maxWbgt),
          fetched_at: fetchedAt,
        });
      }
    } catch (e) {
      errors.push(`${point.pointName}(${point.pointCode}): ${String(e)}`);
    }
  }

  let upserted = 0;
  if (rows.length > 0) {
    const { error, count } = await supabase
      .from("heat_alerts")
      .upsert(rows, { onConflict: "point_code,target_date", count: "exact" });
    if (error) {
      errors.push(`upsert failed: ${error.message}`);
    } else {
      upserted = count ?? rows.length;
    }
  }

  // 期限切れ（今日より前）のレコードを削除し、テーブルを小さく保つ
  const todayYmd = formatDate14(from).slice(0, 8); // YYYYMMDD
  const todayIso = `${todayYmd.slice(0, 4)}-${todayYmd.slice(4, 6)}-${todayYmd.slice(6, 8)}`;
  const { error: deleteError } = await supabase
    .from("heat_alerts")
    .delete()
    .lt("target_date", todayIso);
  if (deleteError) errors.push(`cleanup failed: ${deleteError.message}`);

  return new Response(
    JSON.stringify({
      status: errors.length === 0 ? "success" : "partial_error",
      pointsProcessed: WBGT_POINTS.length,
      rowsUpserted: upserted,
      errors,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
