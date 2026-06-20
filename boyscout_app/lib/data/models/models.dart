import '../../core/constants/app_constants.dart';

// ─── Troop ────────────────────────────────────────────────────
class Troop {
  final String id;
  final String name;
  final String? location;
  final String? contact;
  final String? troopCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Troop({
    required this.id, required this.name, this.location, this.contact,
    this.troopCode, required this.createdAt, required this.updatedAt,
  });

  factory Troop.fromMap(Map<String, dynamic> m) => Troop(
        id: m['id'] as String, name: m['name'] as String,
        location: m['location'] as String?, contact: m['contact'] as String?,
        troopCode: m['troop_code'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'location': location, 'contact': contact,
        'troop_code': troopCode,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()};

  Troop copyWith({String? name, String? location, String? contact, String? troopCode}) =>
      Troop(id: id, name: name ?? this.name, location: location ?? this.location,
          contact: contact ?? this.contact, troopCode: troopCode ?? this.troopCode,
          createdAt: createdAt, updatedAt: DateTime.now());
}

// ─── AppUser ──────────────────────────────────────────────────
class AppUser {
  final String id;
  final String troopId;
  final String name;
  final String? gender;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final bool isRetired;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id, required this.troopId, required this.name, this.gender,
    required this.email, this.phone, required this.role, this.isActive = true,
    this.isRetired = false,
    required this.createdAt, required this.updatedAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String, troopId: m['troop_id'] as String,
        name: m['name'] as String, gender: m['gender'] as String?,
        email: m['email'] as String, phone: m['phone'] as String?,
        role: UserRole.fromValue(m['role'] as String),
        isActive: (m['is_active'] as int? ?? 1) == 1,
        isRetired: (m['is_retired'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'troop_id': troopId, 'name': name, 'gender': gender,
        'email': email, 'phone': phone, 'role': role.value,
        'is_active': isActive ? 1 : 0,
        'is_retired': isRetired ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()};

  AppUser copyWith({String? name, String? gender, String? phone, UserRole? role, bool? isActive, bool? isRetired}) =>
      AppUser(id: id, troopId: troopId, name: name ?? this.name, gender: gender ?? this.gender,
          email: email, phone: phone ?? this.phone, role: role ?? this.role,
          isActive: isActive ?? this.isActive, isRetired: isRetired ?? this.isRetired,
          createdAt: createdAt, updatedAt: DateTime.now());
}

// ─── Scout ───────────────────────────────────────────────────
class Scout {
  final String id;
  final String troopId;
  final String name;
  final String? gender;
  final String? grade;
  final ScoutCategory category;
  final int? enrollmentYear;
  final DateTime? joinedAt;
  final DateTime? birthday;
  final List<AllergyType> allergies;
  final String? specialNotes;
  final int leafBadges;
  final int leafBadgeOffset;
  final int twigBadges;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Scout({
    required this.id, required this.troopId, required this.name, this.gender,
    this.grade, required this.category, this.enrollmentYear, this.joinedAt,
    this.birthday, this.allergies = const [], this.specialNotes,
    this.leafBadges = 0, this.leafBadgeOffset = 0, this.twigBadges = 0,
    this.isActive = true, required this.createdAt, required this.updatedAt,
  });

  int get totalLeafBadges => leafBadges - leafBadgeOffset;
  int get pendingTwigBadges => (totalLeafBadges ~/ 10) - twigBadges;
  bool get isTwigBadgeEligible => category.isTwigBadgeEligible;

  static List<AllergyType> _parseAllergies(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((v) => AllergyType.fromValue(v.trim())).toList();
  }

  factory Scout.fromMap(Map<String, dynamic> m) => Scout(
        id: m['id'] as String, troopId: m['troop_id'] as String,
        name: m['name'] as String, gender: m['gender'] as String?,
        grade: m['grade'] as String?,
        category: ScoutCategory.fromValue(m['category'] as String),
        enrollmentYear: m['enrollment_year'] as int?,
        joinedAt: m['joined_at'] != null ? DateTime.parse(m['joined_at'] as String) : null,
        birthday: m['birthday'] != null ? DateTime.parse(m['birthday'] as String) : null,
        allergies: _parseAllergies(m['allergies'] as String?),
        specialNotes: m['special_notes'] as String?,
        leafBadges: m['leaf_badges'] as int? ?? 0,
        leafBadgeOffset: m['leaf_badge_offset'] as int? ?? 0,
        twigBadges: m['twig_badges'] as int? ?? 0,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'troop_id': troopId, 'name': name, 'gender': gender,
        'grade': grade, 'category': category.value, 'enrollment_year': enrollmentYear,
        'joined_at': joinedAt?.toIso8601String().split('T').first,
        'birthday': birthday?.toIso8601String().split('T').first,
        'allergies': allergies.isEmpty ? null : allergies.map((a) => a.value).join(','),
        'special_notes': specialNotes,
        'leaf_badges': leafBadges, 'leaf_badge_offset': leafBadgeOffset,
        'twig_badges': twigBadges, 'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()};

  Scout copyWith({
    String? name, String? gender, String? grade, ScoutCategory? category,
    int? enrollmentYear, DateTime? joinedAt, DateTime? birthday,
    List<AllergyType>? allergies, String? specialNotes,
    int? leafBadges, int? leafBadgeOffset, int? twigBadges, bool? isActive,
  }) => Scout(
        id: id, troopId: troopId, name: name ?? this.name, gender: gender ?? this.gender,
        grade: grade ?? this.grade, category: category ?? this.category,
        enrollmentYear: enrollmentYear ?? this.enrollmentYear,
        joinedAt: joinedAt ?? this.joinedAt, birthday: birthday ?? this.birthday,
        allergies: allergies ?? this.allergies, specialNotes: specialNotes ?? this.specialNotes,
        leafBadges: leafBadges ?? this.leafBadges,
        leafBadgeOffset: leafBadgeOffset ?? this.leafBadgeOffset,
        twigBadges: twigBadges ?? this.twigBadges, isActive: isActive ?? this.isActive,
        createdAt: createdAt, updatedAt: DateTime.now());
}

// ─── Guardian ────────────────────────────────────────────────
class Guardian {
  final String id;
  final String? troopId;
  final String name;
  final String? gender;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Guardian({
    required this.id, this.troopId, required this.name, this.gender, this.email, this.phone,
    required this.createdAt, required this.updatedAt,
  });

  factory Guardian.fromMap(Map<String, dynamic> m) => Guardian(
        id: m['id'] as String, troopId: m['troop_id'] as String?,
        name: m['name'] as String,
        gender: m['gender'] as String?, email: m['email'] as String?,
        phone: m['phone'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'troop_id': troopId, 'name': name, 'gender': gender, 'email': email, 'phone': phone,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()};

  Guardian copyWith({String? troopId, String? name, String? gender, String? email, String? phone}) =>
      Guardian(id: id, troopId: troopId ?? this.troopId, name: name ?? this.name, gender: gender ?? this.gender,
          email: email ?? this.email, phone: phone ?? this.phone,
          createdAt: createdAt, updatedAt: DateTime.now());
}

// ─── ScoutGuardian ───────────────────────────────────────────
class ScoutGuardian {
  final String id;
  final String scoutId;
  final String guardianId;
  final String? relationship;

  const ScoutGuardian({required this.id, required this.scoutId, required this.guardianId, this.relationship});

  factory ScoutGuardian.fromMap(Map<String, dynamic> m) => ScoutGuardian(
        id: m['id'] as String, scoutId: m['scout_id'] as String,
        guardianId: m['guardian_id'] as String, relationship: m['relationship'] as String?);

  Map<String, dynamic> toMap() => {
        'id': id, 'scout_id': scoutId, 'guardian_id': guardianId, 'relationship': relationship};
}

// ─── CommitteeMember ─────────────────────────────────────────
class CommitteeMember {
  final String id;
  final String troopId;
  final String name;
  final String? gender;
  final CommitteeCategory category;
  final String? email;
  final String? phone;
  final bool isRetired;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommitteeMember({
    required this.id, required this.troopId, required this.name, this.gender,
    required this.category, this.email, this.phone, this.isRetired = false,
    required this.createdAt, required this.updatedAt,
  });

  factory CommitteeMember.fromMap(Map<String, dynamic> m) => CommitteeMember(
        id: m['id'] as String, troopId: m['troop_id'] as String,
        name: m['name'] as String, gender: m['gender'] as String?,
        category: CommitteeCategory.fromValue(m['category'] as String),
        email: m['email'] as String?, phone: m['phone'] as String?,
        isRetired: (m['is_retired'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'troop_id': troopId, 'name': name, 'gender': gender,
        'category': category.value, 'email': email, 'phone': phone,
        'is_retired': isRetired ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()};

  CommitteeMember copyWith({String? name, String? gender, CommitteeCategory? category, String? email, String? phone, bool? isRetired}) =>
      CommitteeMember(id: id, troopId: troopId, name: name ?? this.name, gender: gender ?? this.gender,
          category: category ?? this.category, email: email ?? this.email, phone: phone ?? this.phone,
          isRetired: isRetired ?? this.isRetired,
          createdAt: createdAt, updatedAt: DateTime.now());
}

// ─── Event ───────────────────────────────────────────────────
class Event {
  final String id;
  final String troopId;
  final String title;
  final EventType eventType;
  final EventStatus status;
  final DateTime eventDate;
  final String? location;
  final String? startTime;
  final String? endTime;
  final String? notes;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id, required this.troopId, required this.title,
    required this.eventType, required this.status, required this.eventDate,
    this.location, this.startTime, this.endTime, this.notes, this.completedAt,
    required this.createdAt, required this.updatedAt,
  });

  factory Event.fromMap(Map<String, dynamic> m) => Event(
        id: m['id'] as String, troopId: m['troop_id'] as String,
        title: m['title'] as String,
        eventType: EventType.fromValue(m['event_type'] as String),
        status: EventStatus.fromValue(m['status'] as String),
        eventDate: DateTime.parse(m['event_date'] as String),
        location: m['location'] as String?, startTime: m['start_time'] as String?,
        endTime: m['end_time'] as String?, notes: m['notes'] as String?,
        completedAt: m['completed_at'] != null ? DateTime.parse(m['completed_at'] as String) : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'troop_id': troopId, 'title': title, 'event_type': eventType.value,
        'status': status.value, 'event_date': eventDate.toIso8601String().split('T').first,
        'location': location, 'start_time': startTime, 'end_time': endTime, 'notes': notes,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()};

  Event copyWith({
    String? title, EventType? eventType, EventStatus? status, DateTime? eventDate,
    String? location, String? startTime, String? endTime, String? notes, DateTime? completedAt,
  }) => Event(
        id: id, troopId: troopId, title: title ?? this.title,
        eventType: eventType ?? this.eventType, status: status ?? this.status,
        eventDate: eventDate ?? this.eventDate, location: location ?? this.location,
        startTime: startTime ?? this.startTime, endTime: endTime ?? this.endTime,
        notes: notes ?? this.notes, completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt, updatedAt: DateTime.now());
}

// ─── EventLeafBadge ──────────────────────────────────────────
class EventLeafBadge {
  final String id;
  final String eventId;
  final LeafBadgeType badgeType;
  final int count;

  const EventLeafBadge({required this.id, required this.eventId, required this.badgeType, required this.count});

  factory EventLeafBadge.fromMap(Map<String, dynamic> m) => EventLeafBadge(
        id: m['id'] as String, eventId: m['event_id'] as String,
        badgeType: LeafBadgeType.fromValue(m['badge_type'] as String),
        count: m['count'] as int? ?? 0);

  Map<String, dynamic> toMap() => {
        'id': id, 'event_id': eventId, 'badge_type': badgeType.value, 'count': count};
}

// ─── Attendance ──────────────────────────────────────────────
class Attendance {
  final String id;
  final String eventId;
  final MemberType memberType;
  final String? memberId;
  final String memberName;
  final AttendanceStatus status;
  final bool isDefault;
  final String? notes;

  const Attendance({
    required this.id, required this.eventId, required this.memberType,
    this.memberId, required this.memberName, required this.status,
    this.isDefault = false, this.notes,
  });

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
        id: m['id'] as String, eventId: m['event_id'] as String,
        memberType: MemberType.fromValue(m['member_type'] as String),
        memberId: m['member_id'] as String?,
        memberName: m['member_name'] as String? ?? '',
        status: AttendanceStatus.fromValue(m['status'] as String),
        isDefault: (m['is_default'] as int? ?? 0) == 1,
        notes: m['notes'] as String?);

  Map<String, dynamic> toMap() => {
        'id': id, 'event_id': eventId, 'member_type': memberType.value,
        'member_id': memberId, 'member_name': memberName, 'status': status.value,
        'is_default': isDefault ? 1 : 0, 'notes': notes};

  Attendance copyWith({AttendanceStatus? status, String? notes}) => Attendance(
        id: id, eventId: eventId, memberType: memberType, memberId: memberId,
        memberName: memberName, isDefault: isDefault,
        status: status ?? this.status, notes: notes ?? this.notes);
}

// ─── TwigBadgeHistory ────────────────────────────────────────
class TwigBadgeHistory {
  final String id;
  final String scoutId;
  final String scoutName;
  final String? eventId;
  final String status;
  final DateTime? awardedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TwigBadgeHistory({
    required this.id, required this.scoutId, required this.scoutName,
    this.eventId, required this.status, this.awardedAt,
    required this.createdAt, required this.updatedAt,
  });

  bool get isAwarded => status == 'awarded';

  factory TwigBadgeHistory.fromMap(Map<String, dynamic> m) => TwigBadgeHistory(
        id: m['id'] as String, scoutId: m['scout_id'] as String,
        scoutName: m['scout_name'] as String? ?? '',
        eventId: m['event_id'] as String?, status: m['status'] as String,
        awardedAt: m['awarded_at'] != null ? DateTime.parse(m['awarded_at'] as String) : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String));

  Map<String, dynamic> toMap() => {
        'id': id, 'scout_id': scoutId, 'scout_name': scoutName, 'event_id': eventId,
        'status': status, 'awarded_at': awardedAt?.toIso8601String().split('T').first,
        'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()};
}
