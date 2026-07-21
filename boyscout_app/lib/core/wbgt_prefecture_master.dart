// 熱中症警戒アラート機能：都道府県 → 地点候補マスタ
//
// 出典：環境省熱中症予防情報サイト「情報提供地点マスタ」
//   https://www.wbgt.env.go.jp/man15NH/wbgt_point_master-20260515.csv
//
// - prefCode は環境省API（getForecastData / getSurveyData）の pref_cds
//   パラメータにそのまま使える値（地点番号の先頭2桁と一致）。
// - 各都道府県の points 先頭要素が「デフォルト代表地点」（気象庁 地方気象台等、
//   環境省の実測地点に指定されている観測所）。
// - 気候差が大きい一部県のみ、離島・地方ブロックの追加候補を収録。
//   （北海道は道内主要7地点、他は必要最小限）
// - 地点番号(pointCode)は wbgt_nos パラメータにそのまま使える。
//
// 団情報画面では「都道府県ドロップダウン」選択後、
// 候補が2件以上ある場合のみ「地点ドロップダウン」を活性化する想定。

class WbgtPoint {
  final String pointCode; // 地点番号（wbgt_nos）
  final String pointName; // 地点名（表示用）
  const WbgtPoint(this.pointCode, this.pointName);
}

class WbgtPrefecture {
  final String prefCode; // 環境省 pref_cds（地点番号の先頭2桁）
  final String prefName; // 都道府県名
  final List<WbgtPoint> points; // [0] = デフォルト代表地点
  const WbgtPrefecture(this.prefCode, this.prefName, this.points);
}

const List<WbgtPrefecture> wbgtPrefectureMaster = [
  WbgtPrefecture('14', '北海道', [
    WbgtPoint('14163', '札幌'), // デフォルト（実測地点）
    WbgtPoint('11016', '稚内'),
    WbgtPoint('12442', '旭川'),
    WbgtPoint('17521', '北見'),
    WbgtPoint('19432', '釧路'),
    WbgtPoint('18273', '根室'),
    WbgtPoint('20432', '帯広'),
    WbgtPoint('23232', '函館'),
  ]),
  WbgtPrefecture('31', '青森県', [WbgtPoint('31312', '青森')]),
  WbgtPrefecture('32', '秋田県', [WbgtPoint('32402', '秋田')]),
  WbgtPrefecture('33', '岩手県', [WbgtPoint('33431', '盛岡')]),
  WbgtPrefecture('34', '宮城県', [WbgtPoint('34392', '仙台')]),
  WbgtPrefecture('35', '山形県', [WbgtPoint('35426', '山形')]),
  WbgtPrefecture('36', '福島県', [WbgtPoint('36127', '福島')]),
  WbgtPrefecture('40', '茨城県', [WbgtPoint('40201', '水戸')]),
  WbgtPrefecture('41', '栃木県', [WbgtPoint('41277', '宇都宮')]),
  WbgtPrefecture('42', '群馬県', [WbgtPoint('42251', '前橋')]),
  WbgtPrefecture('43', '埼玉県', [WbgtPoint('43056', '熊谷')]),
  WbgtPrefecture('44', '東京都', [
    WbgtPoint('44132', '東京'), // デフォルト（本土・小石川植物園）
    WbgtPoint('44172', '大島'),
    WbgtPoint('44263', '八丈島'),
    WbgtPoint('44301', '父島'),
  ]),
  WbgtPrefecture('45', '千葉県', [WbgtPoint('45147', '銚子')]),
  WbgtPrefecture('46', '神奈川県', [WbgtPoint('46106', '横浜')]),
  WbgtPrefecture('48', '長野県', [WbgtPoint('48156', '長野')]),
  WbgtPrefecture('49', '山梨県', [WbgtPoint('49142', '甲府')]),
  WbgtPrefecture('50', '静岡県', [WbgtPoint('50331', '静岡')]),
  WbgtPrefecture('51', '愛知県', [WbgtPoint('51106', '名古屋')]),
  WbgtPrefecture('52', '岐阜県', [WbgtPoint('52586', '岐阜')]),
  WbgtPrefecture('53', '三重県', [WbgtPoint('53133', '津')]),
  WbgtPrefecture('54', '新潟県', [WbgtPoint('54232', '新潟')]),
  WbgtPrefecture('55', '富山県', [WbgtPoint('55102', '富山')]),
  WbgtPrefecture('56', '石川県', [WbgtPoint('56227', '金沢')]),
  WbgtPrefecture('57', '福井県', [WbgtPoint('57066', '福井')]),
  WbgtPrefecture('60', '滋賀県', [WbgtPoint('60131', '彦根')]),
  WbgtPrefecture('61', '京都府', [WbgtPoint('61286', '京都')]),
  WbgtPrefecture('62', '大阪府', [WbgtPoint('62078', '大阪')]),
  WbgtPrefecture('63', '兵庫県', [WbgtPoint('63518', '神戸')]),
  WbgtPrefecture('64', '奈良県', [WbgtPoint('64036', '奈良')]),
  WbgtPrefecture('65', '和歌山県', [WbgtPoint('65042', '和歌山')]),
  WbgtPrefecture('66', '岡山県', [WbgtPoint('66408', '岡山')]),
  WbgtPrefecture('67', '広島県', [WbgtPoint('67437', '広島')]),
  WbgtPrefecture('68', '島根県', [
    WbgtPoint('68132', '松江'), // デフォルト
    WbgtPoint('68022', '西郷（隠岐）'),
  ]),
  WbgtPrefecture('69', '鳥取県', [WbgtPoint('69122', '鳥取')]),
  WbgtPrefecture('71', '徳島県', [WbgtPoint('71106', '徳島')]),
  WbgtPrefecture('72', '香川県', [WbgtPoint('72086', '高松')]),
  WbgtPrefecture('73', '愛媛県', [WbgtPoint('73166', '松山')]),
  WbgtPrefecture('74', '高知県', [WbgtPoint('74182', '高知')]),
  WbgtPrefecture('81', '山口県', [WbgtPoint('81428', '下関')]),
  WbgtPrefecture('82', '福岡県', [WbgtPoint('82182', '福岡')]),
  WbgtPrefecture('83', '大分県', [WbgtPoint('83216', '大分')]),
  WbgtPrefecture('84', '長崎県', [
    WbgtPoint('84496', '長崎'), // デフォルト
    WbgtPoint('84072', '厳原（対馬）'),
    WbgtPoint('84536', '福江（五島）'),
  ]),
  WbgtPrefecture('85', '佐賀県', [WbgtPoint('85142', '佐賀')]),
  WbgtPrefecture('86', '熊本県', [WbgtPoint('86141', '熊本')]),
  WbgtPrefecture('87', '宮崎県', [WbgtPoint('87376', '宮崎')]),
  WbgtPrefecture('88', '鹿児島県', [
    WbgtPoint('88317', '鹿児島'), // デフォルト（本土）
    WbgtPoint('88612', '種子島'),
    WbgtPoint('88686', '屋久島'),
    WbgtPoint('88836', '名瀬（奄美）'),
  ]),
  WbgtPrefecture('91', '沖縄県', [
    WbgtPoint('91197', '那覇'), // デフォルト（沖縄本島）
    WbgtPoint('93041', '宮古島'),
    WbgtPoint('94081', '石垣島'),
    WbgtPoint('94017', '与那国島'),
  ]),
];
