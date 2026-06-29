import 'package:flutter/material.dart';

// ─── DB ─────────────────────────────────────────────────────
class AppConstants {
  static const String dbName = 'boyscout.db';
  static const int dbVersion = 9;
}

// ─── ユーザー種別 ─────────────────────────────────────────────
enum UserRole {
  leader('leader', '隊長'),
  assistantLeader('assistant_leader', '副長'),
  support('support', '補助者');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => UserRole.support);

  bool get canEdit => this == leader || this == assistantLeader;
  bool get canManageUsers => this == leader;
}

// ─── スカウト分類 ─────────────────────────────────────────────
enum ScoutCategory {
  bigBeaver('big_beaver', 'ビッグビーバー'),
  beaver('beaver', 'ビーバー'),
  provisional('provisional', '仮入隊'),
  experience('experience', '体験'),
  sibling('sibling', '兄弟姉妹'),
  promoted('promoted', '上進'),
  withdrawn('withdrawn', '退団'),
  notJoined('not_joined', '入隊せず');

  const ScoutCategory(this.value, this.label);
  final String value;
  final String label;

  bool get isDefaultAttendee =>
      this == bigBeaver ||
      this == beaver ||
      this == provisional;

  bool get isTwigBadgeEligible =>
      this == bigBeaver || this == beaver;

  static ScoutCategory fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => ScoutCategory.beaver);
}

// ─── イベント種別 ─────────────────────────────────────────────
enum EventType {
  groupMeeting('group_meeting', '団集会'),
  troopMeeting('troop_meeting', '隊集会'),
  camp('camp', 'キャンプ'),
  service('service', '奉仕活動'),
  other('other', 'その他');

  const EventType(this.value, this.label);
  final String value;
  final String label;

  static EventType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => EventType.other);
}

// ─── イベント状態 ─────────────────────────────────────────────
enum EventStatus {
  planned('planned', '予定'),
  completed('completed', '実施済'),
  cancelled('cancelled', '非開催');

  const EventStatus(this.value, this.label);
  final String value;
  final String label;

  static EventStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => EventStatus.planned);
}

// ─── 出欠状態 ─────────────────────────────────────────────────
enum AttendanceStatus {
  present('present', '出席'),
  absent('absent', '欠席'),
  pending('pending', '未定');

  const AttendanceStatus(this.value, this.label);
  final String value;
  final String label;

  static AttendanceStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => AttendanceStatus.pending);
}

// ─── 木の葉章種別 ─────────────────────────────────────────────
enum LeafBadgeType {
  health('health', '健康', Color(0xFFE53935)),
  expression('expression', '表現', Color(0xFFFB8C00)),
  life('life', '生活', Color(0xFFFDD835)),
  nature('nature', '自然', Color(0xFF43A047)),
  society('society', '社会', Color(0xFF1E88E5));

  const LeafBadgeType(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static LeafBadgeType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => LeafBadgeType.health);
}

// ─── 出欠メンバー種別 ─────────────────────────────────────────
enum MemberType {
  user('user', 'リーダー'),
  scout('scout', 'スカウト'),
  guardian('guardian', '保護者'),
  committee('committee', '団委員'),
  other('other', 'その他');

  const MemberType(this.value, this.label);
  final String value;
  final String label;

  static MemberType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => MemberType.other);
}

// ─── 団委員分類 ─────────────────────────────────────────────
enum CommitteeCategory {
  committee('committee', '団委員'),
  otherLeader('other_leader', '他隊リーダー'),
  otherTroop('other_troop', '他団関係者'),
  ob('ob', 'OB'),
  other('other', 'その他');

  const CommitteeCategory(this.value, this.label);
  final String value;
  final String label;

  static CommitteeCategory fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => CommitteeCategory.other);
}

// ─── アレルギー ────────────────────────────────────────────────
enum AllergyType {
  egg('egg', '鶏卵'),
  dairy('dairy', '牛乳・乳製品'),
  wheat('wheat', '小麦'),
  soba('soba', 'ソバ'),
  peanut('peanut', 'ピーナッツ'),
  shellfish('shellfish', '甲殻類'),
  treeNut('tree_nut', '木の実類'),
  fruit('fruit', '果物類'),
  fish('fish', '魚類'),
  meat('meat', '肉類'),
  other('other', 'その他');

  const AllergyType(this.value, this.label);
  final String value;
  final String label;

  static AllergyType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => AllergyType.other);
}
