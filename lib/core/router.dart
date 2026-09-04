// go_router configuration. Routes to worker flow or owner dashboard.
//
// Routing is driven by the Firebase custom claim `role` (set by
// functions/set-roles.js), NOT by platform. It used to branch on `kIsWeb`,
// which meant any worker who opened the dashboard URL landed on the owner
// dashboard and could read every visit and the day's revenue — and an owner on
// an Android phone was dropped into the worker capture flow with no way to
// reach their own dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/wash_draft.dart';
import '../providers/auth_provider.dart';
import '../providers/wash_session_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/owner/dashboard_screen.dart';
import '../screens/owner/rates_screen.dart';
import '../screens/owner/reports_screen.dart';
import '../screens/owner/visit_detail_screen.dart';
import '../screens/worker/capture_front_screen.dart';
import '../screens/worker/capture_plate_screen.dart';
import '../screens/worker/confirm_plate_screen.dart';
import '../screens/worker/phone_paid_screen.dart';
import '../screens/worker/today_washes_screen.dart';
import '../screens/worker/type_package_screen.dart';
import 'constants.dart';

const _ownerHome = '/owner';
const _workerHome = '/worker/capture-plate';

/// Screens in the worker flow are handed their data through
/// `GoRouterState.extra`. That object does not survive a browser reload or a
/// cold deep link, so opening one of these directly used to throw a null cast.
/// They bounce back to the start of the flow instead.
String? _requireExtra(GoRouterState state) =>
    state.extra is Map<String, dynamic> ? null : _workerHome;

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final roleAsync = ref.watch(userRoleProvider);
  final washSession = ref.watch(washSessionProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Still resolving the session — stay put rather than flashing /login.
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';

      if (user == null) return isLoggingIn ? null : '/login';

      // Signed in, but the role claim has not arrived yet. Hold on the current
      // screen; this redirect re-runs as soon as the claim resolves.
      if (roleAsync.isLoading) return null;

      final isOwner = roleAsync.valueOrNull == UserRole.owner;
      final home = isOwner ? _ownerHome : _workerHome;

      if (isLoggingIn) return home;

      // Owner-only area. Workers are sent back to their own flow.
      if (location.startsWith('/owner') && !isOwner) return _workerHome;

      return null;
    },
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Worker flow (Android) ──────────────────────────────────────
      GoRoute(
        path: '/worker/capture-plate',
        builder: (context, state) => CapturePlateScreen(
          key: ValueKey('capture-plate-$washSession'),
        ),
      ),
      GoRoute(
        path: '/worker/today',
        builder: (context, state) => const TodayWashesScreen(),
      ),
      GoRoute(
        path: '/worker/confirm-plate',
        redirect: (context, state) => _requireExtra(state),
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return ConfirmPlateScreen(
            imageBytes: extra['imageBytes'] as List<int>,
            ocrText: extra['ocrText'] as String,
          );
        },
      ),
      GoRoute(
        path: '/worker/capture-front',
        redirect: (context, state) => _requireExtra(state),
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return CaptureFrontScreen(
            plate: extra['plate'] as String,
            plateImageBytes: extra['plateImageBytes'] as List<int>,
          );
        },
      ),
      GoRoute(
        path: '/worker/type-package',
        redirect: (context, state) => _requireExtra(state),
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return TypePackageScreen(
            plate: extra['plate'] as String,
            plateImageBytes: extra['plateImageBytes'] as List<int>,
            frontImageBytes: extra['frontImageBytes'] as List<int>,
          );
        },
      ),
      GoRoute(
        path: '/worker/phone-paid',
        redirect: (context, state) => _requireExtra(state),
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return PhonePaidScreen(draft: extra['draft'] as WashDraft);
        },
      ),

      // ── Owner dashboard (Web + Android) ───────────────────────────
      GoRoute(
        path: '/owner',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'rates',
            builder: (context, state) => const RatesScreen(),
          ),
          GoRoute(
            path: 'visit/:visitId',
            builder: (context, state) => VisitDetailScreen(
              visitId: state.pathParameters['visitId']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// Replaces go_router's default red error screen for unknown URLs.
class _RouteNotFound extends ConsumerWidget {
  final String location;
  const _RouteNotFound({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(userRoleProvider).valueOrNull == UserRole.owner;
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off_rounded,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Page not found', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(location, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () =>
                      context.go(isOwner ? _ownerHome : _workerHome),
                  child: const Text('Go back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
