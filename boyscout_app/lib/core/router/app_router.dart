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
import '../../features/settings/troop_members_page.dart';
import '../../features/settings/invite_codes_page.dart';
import '../../features/settings/user_form_page.dart';
import '../../features/settings/users_list_page.dart';
import '../../features/settings/guardians_list_page.dart';
import '../../features/settings/committee_list_page.dart';
import '../../features/settings/committee_form_page.dart';
import '../../features/settings/user_detail_page.dart';
import '../../features/settings/guardian_detail_page.dart';
import '../../features/settings/committee_detail_page.dart';
import '../../features/settings/phonebook_page.dart';
import '../../features/settings/allergy_list_page.dart';
import '../../features/settings/onboarding_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/auth_provider.dart';
import '../../data/providers/app_state_provider.dart';
import '../../features/scouts/guardian_form_page.dart';
import '../../features/settings/batch_register_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isSignedIn = ref.read(isSignedInProvider);
      final location = state.matchedLocation;
      final troopInit = ref.read(initTroopProvider);
      final troopId = ref.read(currentTroopIdProvider);

      if (!isSignedIn) {
        if (location == '/login') return null;
        return '/login';
      }

      if (troopInit.isLoading) return null;
      if (location == '/login') return null;

      if (troopId == null) {
        if (location == '/onboarding') return null;
        if (location.startsWith('/settings')) return null;
        return '/onboarding';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
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
                    builder: (c, s) => ScoutFormPage(scoutId: s.pathParameters['id']),
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
                builder: (c, s) => EventDetailPage(
                  key: ValueKey(s.pathParameters['id']),
                  id: s.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (c, s) => EventFormPage(eventId: s.pathParameters['id']),
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (c, s) => AttendancePage(eventId: s.pathParameters['id']!),
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
              GoRoute(path: 'members', builder: (c, s) => const TroopMembersPage()),
              GoRoute(path: 'invite-codes', builder: (c, s) => const InviteCodesPage()),
              GoRoute(
                path: 'users',
                builder: (c, s) => const UsersListPage(),
                routes: [
                  GoRoute(path: 'new', builder: (c, s) => const UserFormPage()),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => UserDetailPage(id: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (c, s) => UserFormPage(userId: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'guardians',
                builder: (c, s) => const GuardiansListPage(),
                routes: [
                  GoRoute(path: 'new', builder: (c, s) => const GuardianFormPage()),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => GuardianDetailPage(id: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (c, s) => GuardianFormPage(guardianId: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'committee',
                builder: (c, s) => const CommitteeListPage(),
                routes: [
                  GoRoute(path: 'new', builder: (c, s) => const CommitteeFormPage()),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => CommitteeDetailPage(id: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (c, s) => CommitteeFormPage(memberId: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(path: 'phonebook', builder: (c, s) => const PhonebookPage()),
              GoRoute(path: 'allergy', builder: (c, s) => const AllergyListPage()),
              GoRoute(path: 'batch-register', builder: (c, s) => const BatchRegisterPage()),
            ],
          ),
        ],
      ),
    ],
  );
  return router;
});

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(currentTroopIdProvider, (_, __) => notifyListeners());
    ref.listen(initTroopProvider, (_, __) => notifyListeners());
    ref.listen(isSignedInProvider, (prev, next) {
      if (prev == true && next == false) notifyListeners();
    });
  }
}

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
