final dashboardProvider = FutureProvider<_DashboardData>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return _DashboardData.empty();

  // 団名はSupabaseから取得（ローカルDBにキャッシュされた別の団の名前を避けるため）
  String? troopName;
  try {
    final troopData = await SupabaseConfig.client
        .from('troops')
        .select('name')
        .eq('id', troopId)
        .maybeSingle();
    troopName = troopData?['name'] as String?;
  } catch (_) {
    // オフライン時はローカルから取得
    final troop = await ref.read(troopRepositoryProvider).getFirst();
    troopName = troop?.name;
  }

  final events = await ref.read(eventRepositoryProvider).getRecent(troopId);
  final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
  final rates = await ref.read(attendanceRepositoryProvider).getRates(troopId);
  final now = DateTime.now();
  final thisMonthCount = events
      .where((e) => e.eventDate.month == now.month && e.eventDate.year == now.year)
      .length;
  double avgRate = 0;
  if (rates.isNotEmpty) avgRate = rates.values.reduce((a, b) => a + b) / rates.length;
  return _DashboardData(events: events, scouts: scouts, thisMonthCount: thisMonthCount, avgAttendanceRate: avgRate, troopName: troopName);
});