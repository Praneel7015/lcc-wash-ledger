// go_router configuration. Routes to worker flow or owner dashboard
// depending on Firebase Auth.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/wash_draft.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/owner/dashboard_screen.dart';
import '../screens/owner/rates_screen.dart';
import '../screens/owner/reports_screen.dart';
import '../screens/owner/settings_screen.dart';
import '../screens/owner/visit_detail_screen.dart';
import '../screens/worker/capture_front_screen.dart';
import '../screens/worker/capture_plate_screen.dart';
import '../screens/worker/confirm_plate_screen.dart';
import '../screens/worker/phone_paid_screen.dart';
import '../screens/worker/type_package_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isLoggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }
      if (isLoggingIn) {
        return kIsWeb ? '/owner' : '/worker/capture-plate';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Worker flow (Android) ─────────────────────────────────────────
      GoRoute(
        path: '/worker/capture-plate',
        builder: (context, state) => const CapturePlateScreen(),
      ),
      GoRoute(
        path: '/worker/confirm-plate',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ConfirmPlateScreen(
            imageBytes: extra['imageBytes'] as List<int>,
            ocrText: extra['ocrText'] as String,
          );
        },
      ),
      GoRoute(
        path: '/worker/capture-front',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CaptureFrontScreen(
            plate: extra['plate'] as String,
            plateImageBytes: extra['plateImageBytes'] as List<int>,
          );
        },
      ),
      GoRoute(
        path: '/worker/type-package',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TypePackageScreen(
            plate: extra['plate'] as String,
            plateImageBytes: extra['plateImageBytes'] as List<int>,
            frontImageBytes: extra['frontImageBytes'] as List<int>,
          );
        },
      ),
      GoRoute(
        path: '/worker/phone-paid',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PhonePaidScreen(draft: extra['draft'] as WashDraft);
        },
      ),

      // ── Owner dashboard (Web + Android) ───────────────────────────────
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
            path: 'settings',
            builder: (context, state) => const OwnerSettingsScreen(),
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
