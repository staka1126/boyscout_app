import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/scouts/scouts_page.dart';
import '../../features/scouts/scout_form_page.dart';
import '../../features/scouts/scout_detail_page.dart';
import '../../features/events/events_page.dart';
import '../../features/events/event_form_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/attendance/attendance_page.dart';
import '../../features/badges/badges_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/troop_setup_page.dart';
import '../../features/settings/user_form_page.dart';
import '../../features/scouts/guardian_form_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (c, s) => const DashboardPage()),
          GoRoute(
            path: '/scouts',
            builder: (c, s) => const ScoutsPage(),
            routes: [
              GoRoute(path: 'new', builder: (c, s) => const ScoutFormPage()),
              GoRoute(
                path: ':id',
                builder: (c, s) => ScoutDetailPage(id: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (c, s) =>
                        ScoutFormPage(scoutId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/events',
            builder: (c, s) => const EventsPage(),
            routes: [
              GoRoute(path: 'new', builder: (c, s) => const EventFormPage()),
              GoRoute(
                path: ':id',
                builder: (c, s) => EventDetailPage(id: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (c, s) =>
                        EventFormPage(eventId: s.pathParameters['id']),
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (c, s) =>
                        AttendancePage(eventId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: '/badges', builder: (c, s) => const BadgesPage()),
          GoRoute(
            path: '/settings',
            builder: (c, s) => const SettingsPage(),
            routes: [
              GoRoute(path: 'troop', builder: (c, s) => const TroopSetupPage()),
              GoRoute(
                path: 'users/new',
                builder: (c, s) => const UserFormPage(),
              ),
              GoRoute(
                path: 'users/:id/edit',
                builder: (c, s) =>
                    UserFormPage(userId: s.pathParameters['id']),
              ),
              GoRoute(
                path: 'guardians/new',
                builder: (c, s) => const GuardianFormPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ─── Shell（BottomNavigationBar） ────────────────────────────
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    '/dashboard',
    '/scouts',
    '/events',
    '/badges',
    '/settings',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    int idx = _tabs.indexWhere((t) => location.startsWith(t));
    if (idx < 0) idx = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'ホーム'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'スカウト'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'イベント'),
          NavigationDestination(
              icon: Icon(Icons.military_tech_outlined),
              selectedIcon: Icon(Icons.military_tech),
              label: '表彰'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '設定'),
        ],
      ),
    );
  }
}
