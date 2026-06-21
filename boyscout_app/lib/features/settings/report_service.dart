import '../../data/local/database_helper.dart';

/// イベント1件分のレポートレコード
class EventReportRecord {
  final String troopName;
  final String eventDate;
  final String title;
  final String location;
  final String startTime;
  final String endTime;
  final String status;
  // 出席
  final int leaderMale;
  final int leaderFemale;
  final int guardianMale;
  final int guardianFemale;
  final int committeeMale;
  final int committeeFemale;
  final int bigBeaverMale;
  final int bigBeaverFemale;
  final int beaverMale;
  final int beaverFemale;
  final int provisionalMale;
  final int provisionalFemale;
  final int experienceMale;
  final int experienceFemale;
  final int siblingMale;
  final int siblingFemale;
  final int otherChildMale;
  final int otherChildFemale;
  // 欠席
  final int leaderMaleAbsent;
  final int leaderFemaleAbsent;
  final int bigBeaverMaleAbsent;
  final int bigBeaverFemaleAbsent;
  final int beaverMaleAbsent;
  final int beaverFemaleAbsent;
  final int provisionalMaleAbsent;
  final int provisionalFemaleAbsent;

  const EventReportRecord({
    required this.troopName,
    required this.eventDate,
    required this.title,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.leaderMale,
    required this.leaderFemale,
    required this.guardianMale,
    required this.guardianFemale,
    required this.committeeMale,
    required this.committeeFemale,
    required this.bigBeaverMale,
    required this.bigBeaverFemale,
    required this.beaverMale,
    required this.beaverFemale,
    required this.provisionalMale,
    required this.provisionalFemale,
    required this.experienceMale,
    required this.experienceFemale,
    required this.siblingMale,
    required this.siblingFemale,
    required this.otherChildMale,
    required this.otherChildFemale,
    required this.leaderMaleAbsent,
    required this.leaderFemaleAbsent,
    required this.bigBeaverMaleAbsent,
    required this.bigBeaverFemaleAbsent,
    required this.beaverMaleAbsent,
    required this.beaverFemaleAbsent,
    required this.provisionalMaleAbsent,
    required this.provisionalFemaleAbsent,
  });

  static const csvHeaders = [
    '団名', '日付', 'タイトル', '場所', '開始時間', '終了時間', 'ステータス',
    // 出席
    '指導者（男・出席）', '指導者（女・出席）',
    '保護者（男・出席）', '保護者（女・出席）',
    '団委員（男・出席）', '団委員（女・出席）',
    'BBV（男・出席）', 'BBV（女・出席）',
    'BV（男・出席）', 'BV（女・出席）',
    '仮入隊（男・出席）', '仮入隊（女・出席）',
    '体験（男・出席）', '体験（女・出席）',
    '兄弟姉妹（男・出席）', '兄弟姉妹（女・出席）',
    'その他児童（男・出席）', 'その他児童（女・出席）',
    // 欠席
    '指導者（男・欠席）', '指導者（女・欠席）',
    'BBV（男・欠席）', 'BBV（女・欠席）',
    'BV（男・欠席）', 'BV（女・欠席）',
    '仮入隊（男・欠席）', '仮入隊（女・欠席）',
  ];

  List<String> toCsvRow() => [
    troopName, eventDate, title, location, startTime, endTime, status,
    // 出席
    '$leaderMale', '$leaderFemale',
    '$guardianMale', '$guardianFemale',
    '$committeeMale', '$committeeFemale',
    '$bigBeaverMale', '$bigBeaverFemale',
    '$beaverMale', '$beaverFemale',
    '$provisionalMale', '$provisionalFemale',
    '$experienceMale', '$experienceFemale',
    '$siblingMale', '$siblingFemale',
    '$otherChildMale', '$otherChildFemale',
    // 欠席
    '$leaderMaleAbsent', '$leaderFemaleAbsent',
    '$bigBeaverMaleAbsent', '$bigBeaverFemaleAbsent',
    '$beaverMaleAbsent', '$beaverFemaleAbsent',
    '$provisionalMaleAbsent', '$provisionalFemaleAbsent',
  ];
}

class ReportService {
  /// 確定済みイベント全件を event_stats と結合してレコード一覧を返す
  static Future<List<EventReportRecord>> generateEventRecords() async {
    final db = await DatabaseHelper.instance.database;

    final troopRow = await db.query('troops', limit: 1);
    final troopName = troopRow.isNotEmpty ? (troopRow.first['name'] as String? ?? '') : '';

    final rows = await db.rawQuery('''
      SELECT
        e.title, e.event_date, e.location, e.start_time, e.end_time, e.status,
        COALESCE(s.leader_male, 0)              AS leader_male,
        COALESCE(s.leader_female, 0)            AS leader_female,
        COALESCE(s.guardian_male, 0)            AS guardian_male,
        COALESCE(s.guardian_female, 0)          AS guardian_female,
        COALESCE(s.committee_male, 0)           AS committee_male,
        COALESCE(s.committee_female, 0)         AS committee_female,
        COALESCE(s.big_beaver_male, 0)          AS big_beaver_male,
        COALESCE(s.big_beaver_female, 0)        AS big_beaver_female,
        COALESCE(s.beaver_male, 0)              AS beaver_male,
        COALESCE(s.beaver_female, 0)            AS beaver_female,
        COALESCE(s.provisional_male, 0)         AS provisional_male,
        COALESCE(s.provisional_female, 0)       AS provisional_female,
        COALESCE(s.experience_male, 0)          AS experience_male,
        COALESCE(s.experience_female, 0)        AS experience_female,
        COALESCE(s.sibling_male, 0)             AS sibling_male,
        COALESCE(s.sibling_female, 0)           AS sibling_female,
        COALESCE(s.other_child_male, 0)         AS other_child_male,
        COALESCE(s.other_child_female, 0)       AS other_child_female,
        COALESCE(s.leader_male_absent, 0)       AS leader_male_absent,
        COALESCE(s.leader_female_absent, 0)     AS leader_female_absent,
        COALESCE(s.big_beaver_male_absent, 0)   AS big_beaver_male_absent,
        COALESCE(s.big_beaver_female_absent, 0) AS big_beaver_female_absent,
        COALESCE(s.beaver_male_absent, 0)       AS beaver_male_absent,
        COALESCE(s.beaver_female_absent, 0)     AS beaver_female_absent,
        COALESCE(s.provisional_male_absent, 0)  AS provisional_male_absent,
        COALESCE(s.provisional_female_absent, 0) AS provisional_female_absent
      FROM events e
      LEFT JOIN event_stats s ON s.event_id = e.id
      WHERE e.status = 'completed'
      ORDER BY e.event_date ASC
    ''');

    return rows.map((r) => EventReportRecord(
      troopName: troopName,
      eventDate: r['event_date'] as String? ?? '',
      title: r['title'] as String? ?? '',
      location: r['location'] as String? ?? '',
      startTime: r['start_time'] as String? ?? '',
      endTime: r['end_time'] as String? ?? '',
      status: r['status'] as String? ?? '',
      leaderMale: (r['leader_male'] as int?) ?? 0,
      leaderFemale: (r['leader_female'] as int?) ?? 0,
      guardianMale: (r['guardian_male'] as int?) ?? 0,
      guardianFemale: (r['guardian_female'] as int?) ?? 0,
      committeeMale: (r['committee_male'] as int?) ?? 0,
      committeeFemale: (r['committee_female'] as int?) ?? 0,
      bigBeaverMale: (r['big_beaver_male'] as int?) ?? 0,
      bigBeaverFemale: (r['big_beaver_female'] as int?) ?? 0,
      beaverMale: (r['beaver_male'] as int?) ?? 0,
      beaverFemale: (r['beaver_female'] as int?) ?? 0,
      provisionalMale: (r['provisional_male'] as int?) ?? 0,
      provisionalFemale: (r['provisional_female'] as int?) ?? 0,
      experienceMale: (r['experience_male'] as int?) ?? 0,
      experienceFemale: (r['experience_female'] as int?) ?? 0,
      siblingMale: (r['sibling_male'] as int?) ?? 0,
      siblingFemale: (r['sibling_female'] as int?) ?? 0,
      otherChildMale: (r['other_child_male'] as int?) ?? 0,
      otherChildFemale: (r['other_child_female'] as int?) ?? 0,
      leaderMaleAbsent: (r['leader_male_absent'] as int?) ?? 0,
      leaderFemaleAbsent: (r['leader_female_absent'] as int?) ?? 0,
      bigBeaverMaleAbsent: (r['big_beaver_male_absent'] as int?) ?? 0,
      bigBeaverFemaleAbsent: (r['big_beaver_female_absent'] as int?) ?? 0,
      beaverMaleAbsent: (r['beaver_male_absent'] as int?) ?? 0,
      beaverFemaleAbsent: (r['beaver_female_absent'] as int?) ?? 0,
      provisionalMaleAbsent: (r['provisional_male_absent'] as int?) ?? 0,
      provisionalFemaleAbsent: (r['provisional_female_absent'] as int?) ?? 0,
    )).toList();
  }
}
